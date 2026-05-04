// =============================================================================
// P0-5: broker_eligibility.region 비정규화 백필 스크립트 (1회성, 운영자 수동 실행)
// =============================================================================
//
// 목적:
//   Task 04(tiered-release) 의 advanceReleaseTierScheduled / fetchEligibleBrokersForTier
//   에서 tier2_dong / tier3_adjacent 단계 broker 후보 필터링 시 brokers 컬렉션을
//   broker 1명당 1회씩 lookup(N+1) 한다.
//   broker_eligibility 에 region 필드를 비정규화하면 단일 query 로 단축 가능하다.
//   (functions/index.js §2.4 fetchEligibleBrokersForTier · filterByMatchingRegion ·
//    filterByDifferentRegion 참조)
//
//   본 스크립트는 broker_eligibility 전체 문서를 스캔해 region 필드를 enrich 한다.
//   region 추출 우선순위:
//     1) jurisdictions[0] 시군구 코드 → 명 정적 매핑 (LAWD_CODE_TO_NAME)
//     2) brokers/{brokerId}.officeAddress 정규식 파싱 ("강남구 역삼동" → "역삼동")
//     3) (선택) geofence.lat/lng → kakao reverse geocoding
//        ※ 비용·rate-limit 발생. 기본 비활성. --enableKakao 명시 시에만 호출
//
//   매핑 실패 시 region='UNKNOWN' 으로 set + 실패 broker ID 별도 로그.
//
// 안전장치:
//   - dryRun 기본 OFF — `--dry` 옵션으로 명시할 때만 read-only 실행
//   - 멱등성: 이미 region 필드 있고 'UNKNOWN' 이 아니면 skip (기본).
//             `--force` 로 모든 문서 재계산.
//   - throttle: writes/sec < 100 (batch 400 ops 후 4.5초 sleep)
//   - 진행률: 100 docs 마다 stdout
//   - 다른 필드 손상 0: update 시 { region } 단일 필드 + updatedAt 만 변경.
//                       다른 필드(licenseStatus, jurisdictions, geofence, activeGrantsCount …)
//                       에는 절대 손대지 않는다.
//   - 카카오 호출은 기본 비활성. --enableKakao 옵션 + KAKAO_REST_API_KEY 환경변수
//     모두 갖추어야 호출.
//
// 사용법:
//   cd D:/Project
//   GOOGLE_APPLICATION_CREDENTIALS=./functions/<service-account>.json \
//   NODE_PATH=D:/Project/functions/node_modules \
//     node tools/migrate_broker_eligibility_region.js [options]
//
// 옵션:
//   --dry               read-only (write 0)
//   --force             이미 region 있는 문서도 재계산
//   --batch=N           batch 크기 (기본 400, 최대 500)
//   --enableKakao       우선순위 3 (kakao reverse geocoding) 활성화
//                       ※ KAKAO_REST_API_KEY 환경변수 필요
//                       ※ 비용·rate-limit 책임은 운영자
//   --lawdMap=path.json 시군구 코드 → 명 매핑 JSON 경로 (기본 ./tools/data/lawd_codes.json)
//
// 산출물:
//   tools/logs/migrate_broker_eligibility_region.log (append)
//   tools/logs/migrate_broker_eligibility_region_unknown.json (UNKNOWN broker ID 목록)
//
// 결과 카운트:
//   processed       전체 broker_eligibility 문서 수
//   updated         region 새로 set 한 문서 수
//   skipped         이미 region 있어 skip 한 문서 수
//   unknown         3가지 시도 모두 실패 → 'UNKNOWN' set 문서 수
//   failed          에러 발생 문서 수
//
// 절대 지킬 것:
//   - 운영자 수동 실행만. 자동 트리거(scheduled / onCall) 0.
//   - P0-2 broker_eligibility 시드 *완료 후* 실행 (의존 직렬).
//   - 운영 환경 실행 전 반드시 `--dry` 로 1회 검증.
//   - 서비스 계정 키는 절대 git에 커밋하지 말 것.
// =============================================================================

const path = require("path");
const fs = require("fs");
const admin = require("firebase-admin");

// ----------------------------------------------------------------------------
// 인자 파싱
// ----------------------------------------------------------------------------
const argv = process.argv.slice(2);
const isDryRun = argv.includes("--dry") || argv.includes("--dry-run");
const isForce = argv.includes("--force");
const isKakaoEnabled = argv.includes("--enableKakao");
const batchSize = (() => {
  const flag = argv.find((a) => a.startsWith("--batch"));
  if (!flag) return 400;
  const eqIdx = flag.indexOf("=");
  if (eqIdx >= 0) {
    const v = parseInt(flag.slice(eqIdx + 1), 10);
    return Number.isFinite(v) && v > 0 && v <= 500 ? v : 400;
  }
  const next = argv[argv.indexOf(flag) + 1];
  const v = parseInt(next, 10);
  return Number.isFinite(v) && v > 0 && v <= 500 ? v : 400;
})();
const lawdMapPath = (() => {
  const flag = argv.find((a) => a.startsWith("--lawdMap"));
  if (!flag) return path.join(__dirname, "data", "lawd_codes.json");
  const eqIdx = flag.indexOf("=");
  if (eqIdx >= 0) return path.resolve(flag.slice(eqIdx + 1));
  const next = argv[argv.indexOf(flag) + 1];
  return next ? path.resolve(next) : path.join(__dirname, "data", "lawd_codes.json");
})();

const THROTTLE_WPS_TARGET = 90;
const throttleMsPerBatch = Math.max(
  0,
  Math.ceil((batchSize / THROTTLE_WPS_TARGET) * 1000)
);

// ----------------------------------------------------------------------------
// 로그
// ----------------------------------------------------------------------------
const LOG_DIR = path.join(__dirname, "logs");
if (!fs.existsSync(LOG_DIR)) fs.mkdirSync(LOG_DIR, { recursive: true });
const LOG_FILE = path.join(LOG_DIR, "migrate_broker_eligibility_region.log");
const UNKNOWN_FILE = path.join(
  LOG_DIR,
  "migrate_broker_eligibility_region_unknown.json"
);

const logStream = fs.createWriteStream(LOG_FILE, { flags: "a" });
function log(msg) {
  const line = `[${new Date().toISOString()}] ${msg}`;
  console.log(line);
  logStream.write(line + "\n");
}

// ----------------------------------------------------------------------------
// 시군구 코드 → 명 매핑 로드
// ----------------------------------------------------------------------------
// 형식: { "11680": "강남구", "11650": "서초구", ... }
// 출처: 행정안전부 법정동 코드. tools/data/lawd_codes.json (또는 --lawdMap 으로 지정)
let LAWD_CODE_TO_NAME = {};
function loadLawdMap() {
  if (!fs.existsSync(lawdMapPath)) {
    log(
      `[WARN] LAWD code map not found at ${lawdMapPath}. ` +
        `우선순위 1 (jurisdictions[0] → 명) 비활성. ` +
        `행정안전부 법정동 코드를 다운받아 ${lawdMapPath} 에 배치하세요. ` +
        `형식: { "11680": "강남구", ... }`
    );
    LAWD_CODE_TO_NAME = {};
    return;
  }
  try {
    const raw = fs.readFileSync(lawdMapPath, "utf8");
    LAWD_CODE_TO_NAME = JSON.parse(raw);
    log(
      `LAWD code map loaded: ${Object.keys(LAWD_CODE_TO_NAME).length} entries from ${lawdMapPath}`
    );
  } catch (e) {
    log(`[WARN] failed to parse LAWD code map: ${e.message}`);
    LAWD_CODE_TO_NAME = {};
  }
}

// ----------------------------------------------------------------------------
// region 추출 함수들
// ----------------------------------------------------------------------------

/**
 * 우선순위 1: jurisdictions[0] 시군구 코드 → 명 매핑.
 * 매핑 실패(코드가 사전에 없음) 시 null 반환.
 */
function regionFromJurisdiction(jurisdictions) {
  if (!Array.isArray(jurisdictions) || jurisdictions.length === 0) return null;
  const code = String(jurisdictions[0]).trim();
  if (!code) return null;
  // 매핑 적중. 코드 자체가 명일 수도 있으므로(예: "강남구") fallback.
  if (LAWD_CODE_TO_NAME[code]) return LAWD_CODE_TO_NAME[code];
  // 5자리 숫자 외(이미 한글명) → 그대로 사용
  if (!/^\d+$/.test(code)) return code;
  return null;
}

/**
 * 우선순위 2: brokers/{brokerId}.officeAddress 정규식 파싱.
 * "서울특별시 강남구 역삼동 ..." → "강남구" (시군구 추출).
 * 동/읍/면이 아니라 *시군구* 우선 추출 — region 필드 정의가 시군구 단위이기 때문.
 *
 * functions/index.js extractDongFromAddress 와는 의도적으로 다르다.
 * (extractDongFromAddress 는 동 단위, 본 함수는 시군구 단위)
 */
function regionFromAddress(address) {
  if (!address || typeof address !== "string") return null;
  // 시군구 패턴: ([가-힣]+(시|군|구)) — 단, "특별시"/"광역시"/"도" 같은 광역은 배제
  const matches = address.match(/([가-힣]+(시|군|구))/g);
  if (!matches || matches.length === 0) return null;
  // 광역(특별시/광역시) 이후의 시군구 우선
  for (const m of matches) {
    if (m.endsWith("특별시") || m.endsWith("광역시") || m.endsWith("특별자치시")) continue;
    return m;
  }
  return matches[0];
}

/**
 * 우선순위 3 (선택): geofence.lat/lng → kakao reverse geocoding.
 * --enableKakao 옵션 + KAKAO_REST_API_KEY 환경변수 모두 있어야 호출.
 *
 * 비용·rate-limit:
 *   - kakao 로컬 API 무료 quota 일 30만 호출. 초과 시 비용 발생.
 *   - rate-limit: 초당 최대 약 30 req. 본 스크립트는 throttle 없이 순차 호출하므로
 *     대량 broker(>1000) 시 별도 sleep 필요.
 *
 * 반환: 시군구명 (예: "강남구") 또는 null
 */
async function regionFromGeocoding(lat, lng) {
  if (!isKakaoEnabled) return null;
  const key = process.env.KAKAO_REST_API_KEY;
  if (!key) {
    log("[WARN] --enableKakao set but KAKAO_REST_API_KEY env missing. skip geocoding.");
    return null;
  }
  if (!lat || !lng || lat === 0 || lng === 0) return null;
  try {
    // Node 18+ 내장 fetch
    const url = `https://dapi.kakao.com/v2/local/geo/coord2regioncode.json?x=${lng}&y=${lat}`;
    const res = await fetch(url, {
      headers: { Authorization: `KakaoAK ${key}` },
    });
    if (!res.ok) {
      log(`[WARN] kakao geocoding non-OK: ${res.status} for ${lat},${lng}`);
      return null;
    }
    const json = await res.json();
    const docs = Array.isArray(json.documents) ? json.documents : [];
    // region_type='B' (법정동) 우선, 없으면 'H' (행정동)
    const doc =
      docs.find((d) => d.region_type === "B") ||
      docs.find((d) => d.region_type === "H") ||
      docs[0];
    if (!doc) return null;
    // region_2depth_name 이 시군구. 예: "강남구"
    return doc.region_2depth_name || null;
  } catch (e) {
    log(`[WARN] kakao geocoding error: ${e.message}`);
    return null;
  }
}

// ----------------------------------------------------------------------------
// Firestore admin 초기화
// ----------------------------------------------------------------------------
function initFirestore() {
  if (admin.apps.length > 0) return admin.firestore();
  const credPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (!credPath) {
    throw new Error(
      "GOOGLE_APPLICATION_CREDENTIALS 환경변수 필수. 서비스 계정 키 경로를 지정하세요."
    );
  }
  if (!fs.existsSync(credPath)) {
    throw new Error(`서비스 계정 키 파일 없음: ${credPath}`);
  }
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
  });
  return admin.firestore();
}

// ----------------------------------------------------------------------------
// 메인
// ----------------------------------------------------------------------------
async function main() {
  log("====================================================================");
  log(`P0-5 broker_eligibility region migration start`);
  log(`  dryRun=${isDryRun}, force=${isForce}, kakao=${isKakaoEnabled}, batch=${batchSize}`);
  log("====================================================================");

  loadLawdMap();

  const db = initFirestore();

  const eligSnap = await db.collection("broker_eligibility").get();
  log(`broker_eligibility total docs: ${eligSnap.size}`);

  const stats = {
    processed: 0,
    updated: 0,
    skipped: 0,
    unknown: 0,
    failed: 0,
    bySource: { jurisdiction: 0, address: 0, kakao: 0 },
  };
  const unknownBrokers = [];

  let batch = db.batch();
  let batchOps = 0;

  for (const doc of eligSnap.docs) {
    stats.processed += 1;
    const data = doc.data();
    const brokerId = doc.id;

    try {
      // 멱등성: 이미 region 있고 UNKNOWN 이 아니고 force 아니면 skip
      if (!isForce && data.region && data.region !== "UNKNOWN") {
        stats.skipped += 1;
        continue;
      }

      // 우선순위 1: jurisdictions[0] → 명 매핑
      let region = regionFromJurisdiction(data.jurisdictions);
      let source = region ? "jurisdiction" : null;

      // 우선순위 2: brokers.officeAddress
      if (!region) {
        const brokerSnap = await db.collection("brokers").doc(brokerId).get();
        if (brokerSnap.exists) {
          const brokerData = brokerSnap.data() || {};
          // brokers.region 우선, 없으면 officeAddress 파싱
          region =
            brokerData.region ||
            regionFromAddress(brokerData.officeAddress || brokerData.address || "");
          if (region) source = "address";
        }
      }

      // 우선순위 3: kakao reverse geocoding (선택)
      if (!region && isKakaoEnabled) {
        const g = data.geofence || {};
        region = await regionFromGeocoding(g.lat, g.lng);
        if (region) source = "kakao";
      }

      // 매핑 실패 시 UNKNOWN
      if (!region) {
        region = "UNKNOWN";
        unknownBrokers.push({
          brokerId,
          jurisdictions: data.jurisdictions || [],
          geofence: data.geofence || null,
        });
        stats.unknown += 1;
      } else {
        stats.bySource[source] = (stats.bySource[source] || 0) + 1;
      }

      // 다른 필드 손상 0: { region } 단일 필드 + updatedAt 만 update.
      // merge 가 아닌 update 호출이라 명시 필드만 변경된다.
      if (!isDryRun) {
        batch.update(doc.ref, {
          region,
          updatedAt: admin.firestore.Timestamp.now(),
        });
        batchOps += 1;
      }
      stats.updated += 1;

      // batch flush + throttle
      if (batchOps >= batchSize) {
        if (!isDryRun) await batch.commit();
        log(
          `  flush batch: ops=${batchOps}, processed=${stats.processed}/${eligSnap.size}`
        );
        batch = db.batch();
        batchOps = 0;
        if (throttleMsPerBatch > 0 && !isDryRun) {
          await new Promise((r) => setTimeout(r, throttleMsPerBatch));
        }
      }

      // 진행률
      if (stats.processed % 100 === 0) {
        log(
          `  progress: ${stats.processed}/${eligSnap.size} ` +
            `(updated=${stats.updated}, skipped=${stats.skipped}, ` +
            `unknown=${stats.unknown}, failed=${stats.failed})`
        );
      }
    } catch (e) {
      stats.failed += 1;
      log(`[ERROR] brokerId=${brokerId}: ${e.message}`);
    }
  }

  // 잔여 batch flush
  if (batchOps > 0 && !isDryRun) {
    await batch.commit();
    log(`  final flush: ops=${batchOps}`);
  }

  // UNKNOWN 목록 저장
  if (unknownBrokers.length > 0) {
    fs.writeFileSync(
      UNKNOWN_FILE,
      JSON.stringify(unknownBrokers, null, 2),
      "utf8"
    );
    log(`UNKNOWN brokers list saved: ${UNKNOWN_FILE} (${unknownBrokers.length} items)`);
  }

  log("====================================================================");
  log(`P0-5 migration complete`);
  log(`  processed=${stats.processed}`);
  log(`  updated=${stats.updated} (jurisdiction=${stats.bySource.jurisdiction}, address=${stats.bySource.address}, kakao=${stats.bySource.kakao})`);
  log(`  skipped=${stats.skipped} (이미 region 있음)`);
  log(`  unknown=${stats.unknown} (3가지 시도 모두 실패 → 'UNKNOWN' set)`);
  log(`  failed=${stats.failed}`);
  if (eligSnap.size > 0) {
    const unknownRatio = ((stats.unknown / eligSnap.size) * 100).toFixed(2);
    log(`  UNKNOWN 비율: ${unknownRatio}% (권고 < 5%)`);
    if (stats.unknown / eligSnap.size > 0.05) {
      log(
        `[WARN] UNKNOWN 비율이 5% 초과. ${UNKNOWN_FILE} 검토 후 수동 처리 필요. ` +
          `(2026-05-03-P0-5-region-runbook.md §6 참조)`
      );
    }
  }
  log(`  dryRun=${isDryRun}`);
  log("====================================================================");

  logStream.end();
}

main().catch((e) => {
  log(`[FATAL] ${e.stack || e.message}`);
  logStream.end();
  process.exit(1);
});
