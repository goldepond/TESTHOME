// =============================================================================
// P0-4: 기존 priority_audit_logs 의 sellerUid 백필
// =============================================================================
//
// Task 06 이전(2026-05-02 이전 적재분)의 priority_audit_logs 문서는 sellerUid
// 필드가 없어 매도자 화면(getPropertyAuditLogs / sellerUid + createdAt 인덱스
// 쿼리)에서 가시되지 않는다. 본 스크립트는 1회 순회로 propertyId 를 통해
// mlsProperties.userId 를 조회하여 sellerUid 필드를 enrichment 한다.
//
// 사용법:
//   cd D:/Project
//   GOOGLE_APPLICATION_CREDENTIALS=./functions/houseproject-18f44-firebase-adminsdk-fbsvc-3cd1e6b129.json \
//   NODE_PATH=D:/Project/functions/node_modules \
//     node scripts/p0-migration/backfill-audit-log-seller-uid.js [--dry-run]
//
// 옵션:
//   --dry-run   실제 쓰기 없이 통계만 출력 (안전 기본값으로 권장)
//   --batch     단일 batch 크기 (default 400, 최대 500)
//
// 산출물:
//   logs/backfill-audit-log-seller-uid.log
// =============================================================================

const path = require("path");
const fs = require("fs");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

const args = process.argv.slice(2);
const isDryRun = args.includes("--dry-run");
const batchSize = (() => {
  const idx = args.indexOf("--batch");
  if (idx < 0) return 400;
  const v = parseInt(args[idx + 1], 10);
  return v > 0 && v <= 500 ? v : 400;
})();

const LOG_DIR = path.join(__dirname, "logs");
if (!fs.existsSync(LOG_DIR)) fs.mkdirSync(LOG_DIR, { recursive: true });
const LOG_FILE = path.join(LOG_DIR, "backfill-audit-log-seller-uid.log");
const logStream = fs.createWriteStream(LOG_FILE, { flags: "a" });

function log(msg) {
  const line = `[${new Date().toISOString()}] ${msg}`;
  console.log(line);
  logStream.write(line + "\n");
}

const propertySellerUidCache = new Map(); // propertyId → sellerUid | null

async function getSellerUid(propertyId) {
  if (!propertyId) return null;
  if (propertySellerUidCache.has(propertyId)) {
    return propertySellerUidCache.get(propertyId);
  }
  const snap = await db.collection("mlsProperties").doc(propertyId).get();
  const sellerUid = snap.exists ? snap.data().userId || null : null;
  propertySellerUidCache.set(propertyId, sellerUid);
  return sellerUid;
}

(async function main() {
  log(`start dryRun=${isDryRun} batchSize=${batchSize}`);

  // collectionGroup 으로 전체 priority_audit_logs 순회 (priority_audit_logs 는
  // top-level collection 이지만 향후 서브컬렉션화 가능성 대비).
  const snapshot = await db.collection("priority_audit_logs").get();
  log(`scanned ${snapshot.size} audit log doc(s)`);

  let needsBackfill = 0;
  let alreadyHasSellerUid = 0;
  let propertyNotFound = 0;
  let processed = 0;

  let batch = db.batch();
  let opsInBatch = 0;

  const sampleEnriched = [];

  for (const doc of snapshot.docs) {
    const data = doc.data();
    if (data.sellerUid) {
      alreadyHasSellerUid += 1;
      continue;
    }
    needsBackfill += 1;

    const propertyId = data.propertyId;
    const sellerUid = await getSellerUid(propertyId);
    if (!sellerUid) {
      propertyNotFound += 1;
      log(
        `[SKIP] auditId=${doc.id} propertyId=${propertyId} → mlsProperties.userId not resolvable`
      );
      continue;
    }

    if (sampleEnriched.length < 5) {
      sampleEnriched.push({
        auditId: doc.id,
        propertyId,
        sellerUid,
        eventType: data.eventType,
      });
    }

    if (isDryRun) {
      processed += 1;
      continue;
    }

    batch.update(doc.ref, { sellerUid });
    opsInBatch += 1;
    processed += 1;

    if (opsInBatch >= batchSize) {
      await batch.commit();
      log(`commit batch (${opsInBatch} ops)`);
      batch = db.batch();
      opsInBatch = 0;
    }
  }

  if (!isDryRun && opsInBatch > 0) {
    await batch.commit();
    log(`commit final batch (${opsInBatch} ops)`);
  }

  log(
    `done dryRun=${isDryRun} totalScanned=${snapshot.size} needsBackfill=${needsBackfill} alreadyHasSellerUid=${alreadyHasSellerUid} propertyNotFound=${propertyNotFound} processed=${processed}`
  );
  log(`sampleEnriched=${JSON.stringify(sampleEnriched)}`);

  await admin.app().delete();
  logStream.end();
})();
