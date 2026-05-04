// =============================================================================
// P0-2 + P0-5: broker_eligibility 시드 + region 비정규화 통합 마이그레이션
// =============================================================================
//
// 목적:
//   1. (P0-2) 면허 검증된 모든 broker에 대해 broker_eligibility 문서 1회 batch 생성
//   2. (P0-5) broker.region (또는 officeAddress 추출) 을 broker_eligibility.region 으로 비정규화
//
// 본 스크립트는 functions/index.js 의 recomputeSingleBrokerEligibility 함수와
// 동일한 로직을 admin SDK로 1회 실행한다. 이미 functions가 region 필드를
// 포함하도록 수정되어 있으므로(P0-5), recomputeBrokerEligibility callable 을
// admin이 호출하는 방식이 더 단순하나, 본 스크립트는 admin 로그인 없이
// 서비스 계정으로 직접 실행 가능하도록 작성됨.
//
// 사용법:
//   cd D:/Project/functions
//   GOOGLE_APPLICATION_CREDENTIALS=./houseproject-18f44-firebase-adminsdk-fbsvc-3cd1e6b129.json \
//     node ../scripts/p0-migration/seed-broker-eligibility.js [--dry-run]
//
// 옵션:
//   --dry-run    실제 쓰기 없이 통계만 출력 (기본 false — 안전 기본값과 다르므로 주의)
//   --broker-id  단일 broker만 처리 (디버깅용)
//
// 산출물:
//   콘솔 로그 + scripts/p0-migration/logs/seed-broker-eligibility.log
// =============================================================================

const path = require("path");
const fs = require("fs");
const admin = require("firebase-admin");
const ngeohash = require("ngeohash");

// 환경: 본 스크립트는 functions/ 와 같은 의존성 (firebase-admin, ngeohash) 사용.
// 따라서 functions/node_modules 를 NODE_PATH 에 추가하여 실행 권장.
//   NODE_PATH=D:/Project/functions/node_modules node scripts/p0-migration/seed-broker-eligibility.js

admin.initializeApp();
const db = admin.firestore();
const { Timestamp } = admin.firestore;

// functions/index.js 와 동일한 상수
const GEOHASH_PRECISION = 7;
const DEFAULT_ACTIVE_GRANTS_CAP = 5;

const args = process.argv.slice(2);
const isDryRun = args.includes("--dry-run");
const brokerIdArg = (() => {
  const idx = args.indexOf("--broker-id");
  return idx >= 0 ? args[idx + 1] : null;
})();

const LOG_DIR = path.join(__dirname, "logs");
if (!fs.existsSync(LOG_DIR)) fs.mkdirSync(LOG_DIR, { recursive: true });
const LOG_FILE = path.join(LOG_DIR, "seed-broker-eligibility.log");
const logStream = fs.createWriteStream(LOG_FILE, { flags: "a" });

function log(msg) {
  const line = `[${new Date().toISOString()}] ${msg}`;
  console.log(line);
  logStream.write(line + "\n");
}

function extractDongFromAddress(address) {
  if (!address) return null;
  const m = address.match(/([가-힣]+(동|읍|면))/);
  return m ? m[1] : null;
}

async function recomputeOne(brokerId) {
  const brokerRef = db.collection("brokers").doc(brokerId);
  const eligibilityRef = db.collection("broker_eligibility").doc(brokerId);

  const brokerSnap = await brokerRef.get();
  const brokerData = brokerSnap.exists ? brokerSnap.data() : {};

  let licenseStatus = "pending";
  if (brokerData.licenseVerified === true) licenseStatus = "verified";
  else if (brokerData.licenseVerified === false) licenseStatus = "invalid";

  const activeGrantsSnap = await db
    .collection("priority_grants")
    .where("brokerId", "==", brokerId)
    .where("status", "==", "active")
    .get();

  const region =
    brokerData.region ||
    extractDongFromAddress(brokerData.officeAddress || "") ||
    null;

  const lat = brokerData.latitude || 0;
  const lng = brokerData.longitude || 0;
  const radiusKm = brokerData.geofenceRadiusKm || 5;
  const geohash =
    lat !== 0 && lng !== 0 ? ngeohash.encode(lat, lng, GEOHASH_PRECISION) : null;

  const now = Timestamp.now();
  const data = {
    brokerId,
    brokerUid: brokerData.uid || brokerData.brokerUid || brokerId,
    licenseNumber: brokerData.licenseNumber || "",
    licenseVerifiedAt: brokerData.licenseVerifiedAt || now,
    licenseStatus,
    region,
    jurisdictions: brokerData.jurisdictions || [],
    geofence: geohash ? { lat, lng, radiusKm, geohash } : { lat, lng, radiusKm },
    activeGrantsCount: activeGrantsSnap.size,
    activeGrantsCap: brokerData.activeGrantsCap || DEFAULT_ACTIVE_GRANTS_CAP,
    updatedAt: now,
  };

  if (isDryRun) {
    return {
      brokerId,
      licenseStatus,
      region,
      jurisdictions: data.jurisdictions.length,
      geohash: geohash || null,
      activeGrantsCount: data.activeGrantsCount,
      preview: true,
    };
  }

  await eligibilityRef.set(data, { merge: true });
  if (brokerSnap.exists) {
    await brokerRef.update({ eligibilityRefreshedAt: now });
  }
  return {
    brokerId,
    licenseStatus,
    region,
    activeGrantsCount: data.activeGrantsCount,
    written: true,
  };
}

(async function main() {
  log(`start dryRun=${isDryRun} brokerIdArg=${brokerIdArg || "(all)"}`);

  let docs;
  if (brokerIdArg) {
    const single = await db.collection("brokers").doc(brokerIdArg).get();
    docs = single.exists ? [single] : [];
  } else {
    const snap = await db.collection("brokers").get();
    docs = snap.docs;
  }

  log(`processing ${docs.length} broker(s)`);

  let success = 0;
  let failed = 0;
  let nullRegionCount = 0;
  let unverifiedCount = 0;
  for (const doc of docs) {
    try {
      const r = await recomputeOne(doc.id);
      if (!r.region) nullRegionCount += 1;
      if (r.licenseStatus !== "verified") unverifiedCount += 1;
      success += 1;
      log(JSON.stringify(r));
    } catch (e) {
      failed += 1;
      log(`[ERROR] brokerId=${doc.id} ${e.message}`);
    }
  }

  log(
    `done success=${success} failed=${failed} nullRegion=${nullRegionCount} unverified=${unverifiedCount} total=${docs.length}`
  );
  log(
    `NOTE: nullRegion>0 인 broker 는 tier2/tier3 알림 대상에서 제외됩니다. brokers.{id}.region 또는 officeAddress 입력을 매도자 운영팀에 안내해 주세요.`
  );

  await admin.app().delete();
  logStream.end();
})();
