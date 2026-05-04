// =============================================================================
// P0-2: broker_eligibility 시드 1회 스크립트 (운영자 수동 실행)
// =============================================================================
//
// 목적:
//   Task 01(데이터 모델) 완료 후 broker_eligibility 컬렉션은 비어 있다.
//   issuePriorityGrant Cloud Function 은 broker_eligibility 문서 존재를
//   자격 검증 전제로 한다 (handoff §5.3 #11). 운영 적용 직후 모든 brokers 에
//   대해 broker_eligibility 문서를 1회 시드해야 한다.
//
//   본 스크립트는 brokers 컬렉션을 전체 스캔하여 각 broker 에
//   broker_eligibility 문서를 멱등적으로 생성한다.
//
// 초기값 (handoff §5.3 #11 + broker_eligibility.dart 명세 기준):
//   - licenseStatus  : 'pending' (운영자가 별도로 admin UI 에서 'verified' 전환)
//   - licenseNumber  : brokers.licenseNumber (있으면) 또는 빈 문자열
//   - jurisdictions  : [] (P0-5 region 비정규화 → 추후 채움)
//   - geofence       : { lat, lng, radiusKm: 5 } — brokers.latitude/longitude 사용
//                      좌표 미입력 시 lat=0, lng=0 (geohash 생략)
//   - activeGrantsCount : 0
//   - activeGrantsCap   : 5 (DEFAULT_ACTIVE_GRANTS_CAP)
//   - updatedAt      : serverTimestamp (Timestamp.now())
//
// 안전장치:
//   - 멱등: 기본은 skip (이미 broker_eligibility 문서가 있으면 건드리지 않음)
//           --force 옵션 시 서버 측 set + merge 로 update (activeGrantsCount 보존)
//   - dryRun: --dry 옵션으로 실제 쓰기 없이 통계만 출력
//   - throttle: writes/sec < 100 (배치 단위 sleep)
//   - 진행률 로깅: 100건마다 stdout
//   - checkpoint: lastProcessedBrokerId 저장 → 실패 시 재실행으로 재개
//   - 취소(SIGINT) 시 현재 batch flush 후 checkpoint 기록 후 종료
//   - 외부 면허 검증 API 호출 0 (licenseStatus 는 항상 'pending' 시드)
//   - Cloud Functions 호출 0 (admin SDK 직접 쓰기)
//
// 사용법:
//   cd D:/Project
//   GOOGLE_APPLICATION_CREDENTIALS=./functions/<service-account>.json \
//   NODE_PATH=D:/Project/functions/node_modules \
//     node tools/seed_broker_eligibility.js [--dry] [--force] [--batch=100] [--reset]
//
// 옵션:
//   --dry        실제 쓰기 없이 통계만 출력 (read-only)
//   --force      이미 있는 broker_eligibility 도 update (merge=true)
//                ⚠️ activeGrantsCount/activeGrantsCap 은 보존하고 면허/지오펜스/jurisdictions 만 갱신
//   --batch=N    단일 batch 크기 (기본 100, 최대 500)
//   --reset      기존 checkpoint 무시하고 처음부터 재시작
//
// 산출물:
//   tools/logs/seed_broker_eligibility.log (append)
//   tools/logs/seed_broker_eligibility.checkpoint.json
//
// 사후 검증:
//   firebase firestore: count(broker_eligibility) == count(brokers) 확인
//   (D:/Project/docs/task/2026-05-03-P0-2-seed-runbook.md §4 참조)
//
// 주의:
//   - 운영자가 직접 실행. 어떤 자동화에도 연결되지 않음.
//   - 서비스 계정 키는 절대 git 에 커밋하지 말 것.
//   - 운영 환경 실행 전 반드시 `--dry` 로 1회 검증.
//   - recomputeBrokerEligibility (Cloud Function, callable) 와 차이:
//       이 시드 스크립트는 시작점 데이터만 만든다. licenseStatus 검증 로직이나
//       activeGrantsCount 정합 보정은 하지 않는다 (운영 적용 후 별도 callable
//       을 admin UI 에서 호출).
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
const isReset = argv.includes("--reset");
const batchSize = (() => {
  const flag = argv.find((a) => a.startsWith("--batch"));
  if (!flag) return 100;
  const eqIdx = flag.indexOf("=");
  if (eqIdx >= 0) {
    const v = parseInt(flag.slice(eqIdx + 1), 10);
    return Number.isFinite(v) && v > 0 && v <= 500 ? v : 100;
  }
  const next = argv[argv.indexOf(flag) + 1];
  const v = parseInt(next, 10);
  return Number.isFinite(v) && v > 0 && v <= 500 ? v : 100;
})();

// throttle: writes/sec < 100. batch 단위 sleep.
// batch=100 기준 약 1.2초 sleep → 약 83 writes/sec (안전 마진).
const THROTTLE_WPS_TARGET = 83;
const throttleMsPerBatch = Math.max(
  0,
  Math.ceil((batchSize / THROTTLE_WPS_TARGET) * 1000)
);

// 기본값 상수 (functions/index.js 와 일치)
const DEFAULT_ACTIVE_GRANTS_CAP = 5;
const DEFAULT_GEOFENCE_RADIUS_KM = 5;

// ----------------------------------------------------------------------------
// 로그·체크포인트 경로
// ----------------------------------------------------------------------------
const LOG_DIR = path.join(__dirname, "logs");
if (!fs.existsSync(LOG_DIR)) fs.mkdirSync(LOG_DIR, { recursive: true });
const LOG_FILE = path.join(LOG_DIR, "seed_broker_eligibility.log");
const CHECKPOINT_FILE = path.join(
  LOG_DIR,
  "seed_broker_eligibility.checkpoint.json"
);

const logStream = fs.createWriteStream(LOG_FILE, { flags: "a" });
function log(msg) {
  const line = `[${new Date().toISOString()}] ${msg}`;
  console.log(line);
  logStream.write(line + "\n");
}

function loadCheckpoint() {
  if (isReset) {
    log("checkpoint reset by --reset flag");
    return null;
  }
  if (!fs.existsSync(CHECKPOINT_FILE)) return null;
  try {
    const raw = fs.readFileSync(CHECKPOINT_FILE, "utf8");
    const parsed = JSON.parse(raw);
    log(
      `checkpoint loaded: lastProcessedBrokerId=${parsed.lastProcessedBrokerId} processedCount=${parsed.processedCount}`
    );
    return parsed;
  } catch (e) {
    log(`[WARN] failed to parse checkpoint, starting fresh: ${e.message}`);
    return null;
  }
}

function saveCheckpoint(state) {
  try {
    fs.writeFileSync(
      CHECKPOINT_FILE,
      JSON.stringify(state, null, 2),
      "utf8"
    );
  } catch (e) {
    log(`[WARN] failed to write checkpoint: ${e.message}`);
  }
}

function clearCheckpoint() {
  if (fs.existsSync(CHECKPOINT_FILE)) {
    try {
      fs.unlinkSync(CHECKPOINT_FILE);
      log("checkpoint cleared (run completed)");
    } catch (e) {
      log(`[WARN] failed to clear checkpoint: ${e.message}`);
    }
  }
}

// ----------------------------------------------------------------------------
// Firestore 초기화
// ----------------------------------------------------------------------------
admin.initializeApp();
const db = admin.firestore();
const Timestamp = admin.firestore.Timestamp;

// ----------------------------------------------------------------------------
// 시드 데이터 빌더
// ----------------------------------------------------------------------------
//
// brokers/{brokerId} 의 데이터를 받아 broker_eligibility/{brokerId} 에
// 저장할 초기 문서를 만든다. 다음 규칙을 지킨다:
//   - licenseStatus 는 항상 'pending' (외부 검증 미구현 — 운영자 수동 전환)
//   - jurisdictions 는 [] (P0-5 에서 비정규화 후 채움)
//   - geofence.geohash 는 lat/lng 가 모두 유효할 때만 포함 (recompute 함수와 동일)
//     단, 본 시드 스크립트는 geohash 패키지 의존을 피하기 위해 항상 생략한다.
//     (geohash 는 운영 적용 후 recomputeBrokerEligibility callable 호출로 채워진다.)
function buildEligibilitySeed(brokerId, brokerData, now) {
  const lat = Number(brokerData.latitude || 0);
  const lng = Number(brokerData.longitude || 0);
  const hasCoords = lat !== 0 && lng !== 0;

  return {
    brokerId,
    brokerUid: brokerData.uid || brokerData.brokerUid || brokerId,
    licenseNumber: brokerData.licenseNumber || "",
    licenseVerifiedAt: null,
    licenseStatus: "pending",
    jurisdictions: [],
    geofence: hasCoords
      ? { lat, lng, radiusKm: DEFAULT_GEOFENCE_RADIUS_KM }
      : { lat: 0, lng: 0, radiusKm: DEFAULT_GEOFENCE_RADIUS_KM },
    activeGrantsCount: 0,
    activeGrantsCap:
      Number(brokerData.activeGrantsCap) || DEFAULT_ACTIVE_GRANTS_CAP,
    updatedAt: now,
  };
}

// --force 모드 전용: 기존 활성 카운터(activeGrantsCount/Cap)를 보존하면서
// 면허/지오펜스/jurisdictions 만 갱신한다. activeGrantsCount 정합 보정은
// 별도의 recomputeBrokerEligibility callable 의 책임 (handoff §5.3 #11).
function buildForceUpdate(brokerId, brokerData, existingData, now) {
  const seed = buildEligibilitySeed(brokerId, brokerData, now);
  return {
    ...seed,
    // 보존
    activeGrantsCount:
      typeof existingData.activeGrantsCount === "number"
        ? existingData.activeGrantsCount
        : 0,
    activeGrantsCap:
      typeof existingData.activeGrantsCap === "number"
        ? existingData.activeGrantsCap
        : seed.activeGrantsCap,
    // licenseStatus 도 보존 — 이미 verified 인 broker 를 pending 으로 되돌리면 안 됨
    licenseStatus: existingData.licenseStatus || seed.licenseStatus,
    licenseVerifiedAt:
      existingData.licenseVerifiedAt || seed.licenseVerifiedAt,
    // jurisdictions 가 이미 채워져 있으면 보존 (P0-5 결과 보호)
    jurisdictions:
      Array.isArray(existingData.jurisdictions) &&
      existingData.jurisdictions.length > 0
        ? existingData.jurisdictions
        : seed.jurisdictions,
  };
}

// ----------------------------------------------------------------------------
// throttle 헬퍼
// ----------------------------------------------------------------------------
function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// ----------------------------------------------------------------------------
// 메인 루프
// ----------------------------------------------------------------------------
async function main() {
  log(
    `start dryRun=${isDryRun} force=${isForce} batchSize=${batchSize} throttleMsPerBatch=${throttleMsPerBatch} reset=${isReset}`
  );

  const checkpoint = loadCheckpoint();
  let lastProcessedBrokerId = checkpoint
    ? checkpoint.lastProcessedBrokerId
    : null;
  let cumulativeProcessed = checkpoint ? checkpoint.processedCount || 0 : 0;
  let cumulativeCreated = checkpoint ? checkpoint.createdCount || 0 : 0;
  let cumulativeUpdated = checkpoint ? checkpoint.updatedCount || 0 : 0;
  let cumulativeSkipped = checkpoint ? checkpoint.skippedCount || 0 : 0;

  let shouldStop = false;
  process.on("SIGINT", () => {
    log("[SIGINT] received, will flush current batch and exit");
    shouldStop = true;
  });

  const PAGE_SIZE = 200; // brokers 페이지 단위 (eligibility 존재 체크 read 동반)
  let cursor = null;

  if (lastProcessedBrokerId) {
    cursor = await db.collection("brokers").doc(lastProcessedBrokerId).get();
    if (!cursor.exists) {
      log(
        `[WARN] checkpoint broker ${lastProcessedBrokerId} not found, restarting from beginning`
      );
      cursor = null;
    } else {
      log(`resuming after lastProcessedBrokerId=${lastProcessedBrokerId}`);
    }
  }

  let pageCount = 0;

  while (!shouldStop) {
    let query = db
      .collection("brokers")
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(PAGE_SIZE);

    if (cursor) {
      query = query.startAfter(cursor);
    }

    const snapshot = await query.get();
    if (snapshot.empty) {
      log(`page ${pageCount} empty — scan complete`);
      break;
    }
    pageCount += 1;

    let batch = db.batch();
    let opsInBatch = 0;
    let pageCreated = 0;
    let pageUpdated = 0;
    let pageSkipped = 0;

    for (const brokerDoc of snapshot.docs) {
      if (shouldStop) break;
      cumulativeProcessed += 1;

      const brokerId = brokerDoc.id;
      const brokerData = brokerDoc.data() || {};
      const eligibilityRef = db.collection("broker_eligibility").doc(brokerId);
      const eligibilitySnap = await eligibilityRef.get();
      const now = Timestamp.now();

      if (eligibilitySnap.exists && !isForce) {
        cumulativeSkipped += 1;
        pageSkipped += 1;
      } else if (eligibilitySnap.exists && isForce) {
        const updateData = buildForceUpdate(
          brokerId,
          brokerData,
          eligibilitySnap.data() || {},
          now
        );
        if (!isDryRun) {
          batch.set(eligibilityRef, updateData, { merge: true });
          opsInBatch += 1;
        }
        cumulativeUpdated += 1;
        pageUpdated += 1;
      } else {
        const seedData = buildEligibilitySeed(brokerId, brokerData, now);
        if (!isDryRun) {
          batch.set(eligibilityRef, seedData);
          opsInBatch += 1;
        }
        cumulativeCreated += 1;
        pageCreated += 1;
      }

      lastProcessedBrokerId = brokerId;

      // 진행률 (100건마다)
      if (cumulativeProcessed % 100 === 0) {
        log(
          `progress processed=${cumulativeProcessed} created=${cumulativeCreated} updated=${cumulativeUpdated} skipped=${cumulativeSkipped}`
        );
      }

      // batch 도달 시 commit + throttle
      if (!isDryRun && opsInBatch >= batchSize) {
        await batch.commit();
        log(
          `commit batch (${opsInBatch} ops, throttle ${throttleMsPerBatch}ms)`
        );
        batch = db.batch();
        opsInBatch = 0;

        saveCheckpoint({
          lastProcessedBrokerId,
          processedCount: cumulativeProcessed,
          createdCount: cumulativeCreated,
          updatedCount: cumulativeUpdated,
          skippedCount: cumulativeSkipped,
          updatedAt: new Date().toISOString(),
        });

        if (throttleMsPerBatch > 0) await sleep(throttleMsPerBatch);
      }
    }

    // 페이지 종료 시 잔여 batch flush
    if (!isDryRun && opsInBatch > 0) {
      await batch.commit();
      log(`commit page-end batch (${opsInBatch} ops)`);
      if (throttleMsPerBatch > 0) await sleep(throttleMsPerBatch);
    }

    log(
      `page ${pageCount} done size=${snapshot.size} created=${pageCreated} updated=${pageUpdated} skipped=${pageSkipped}`
    );

    saveCheckpoint({
      lastProcessedBrokerId,
      processedCount: cumulativeProcessed,
      createdCount: cumulativeCreated,
      updatedCount: cumulativeUpdated,
      skippedCount: cumulativeSkipped,
      updatedAt: new Date().toISOString(),
    });

    cursor = snapshot.docs[snapshot.docs.length - 1];

    if (snapshot.size < PAGE_SIZE) {
      log("last page reached");
      break;
    }
  }

  log(
    `done dryRun=${isDryRun} force=${isForce} totalProcessed=${cumulativeProcessed} created=${cumulativeCreated} updated=${cumulativeUpdated} skipped=${cumulativeSkipped} stopped=${shouldStop}`
  );

  if (!shouldStop) {
    clearCheckpoint();
  }

  await admin.app().delete();
  logStream.end();
  process.exit(shouldStop ? 130 : 0);
}

main().catch((err) => {
  log(`[FATAL] ${err.stack || err.message || err}`);
  // 비정상 종료 시 checkpoint 보존 (재실행 시 재개 가능)
  logStream.end(() => process.exit(1));
});
