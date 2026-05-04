// =============================================================================
// P0-4: priority_audit_logs sellerUid 백필 스크립트 (1회성, 운영자 수동 실행)
// =============================================================================
//
// 목적:
//   Task 06 이전(2026-05-02 이전) 적재된 priority_audit_logs 문서는 sellerUid
//   필드가 없다. firestore.rules `priority_audit_logs` read 정책은
//   `sellerUid == request.auth.uid` 조건을 사용하므로, 백필이 없으면 매도자가
//   본인 매물 관련 과거 audit log 를 열람할 수 없다.
//
//   본 스크립트는 다음 순서로 sellerUid 를 enrichment 한다:
//     1) 문서에 sellerUid 가 이미 있으면 skip (멱등성)
//     2) propertyId 가 있으면 mlsProperties/{propertyId}.userId 조회
//     3) propertyId 가 없으면 grantId 또는 relatedGrantId 로 priority_grants 조회
//        → grant.sellerUid 또는 grant.propertyId → mlsProperties.userId fallback
//     4) 둘 다 실패하면 propertyNotFound 카운트 증가 후 skip
//
// 안전장치:
//   - dryRun 기본 OFF — `--dry` 옵션으로 명시할 때만 read-only 실행
//   - 멱등: 이미 sellerUid 있는 문서는 update 호출 자체를 안 함
//   - throttle: writes/sec < 100 (배치 400 ops 후 4.5초 sleep)
//   - 진행률: 1000 docs 마다 stdout
//   - checkpoint: logs/backfill_audit_log_seller_uid.checkpoint.json 에
//     마지막 처리 doc id 저장. 재실행 시 그 이후부터 재개.
//   - 취소(SIGINT) 시 현재 batch flush 후 checkpoint 기록 후 종료
//
// 사용법:
//   cd D:/Project
//   GOOGLE_APPLICATION_CREDENTIALS=./functions/<service-account>.json \
//   NODE_PATH=D:/Project/functions/node_modules \
//     node tools/backfill_audit_log_seller_uid.js [--dry] [--batch=400] [--reset]
//
// 옵션:
//   --dry       실제 쓰기 없이 통계만 출력 (read-only)
//   --batch=N   단일 batch 크기 (기본 400, 최대 500). throttle은 batch 단위
//   --reset     기존 checkpoint 파일 무시하고 처음부터 재시작
//
// 산출물:
//   tools/logs/backfill_audit_log_seller_uid.log (append)
//   tools/logs/backfill_audit_log_seller_uid.checkpoint.json
//
// 주의:
//   - 운영자가 직접 실행해야 한다. 본 스크립트는 어떤 자동화에도 연결되지 않는다.
//   - 서비스 계정 키는 절대 git에 커밋하지 말 것.
//   - 운영 환경 실행 전 반드시 `--dry` 로 1회 검증.
// =============================================================================

const path = require("path");
const fs = require("fs");
const admin = require("firebase-admin");

// ----------------------------------------------------------------------------
// 인자 파싱
// ----------------------------------------------------------------------------
const argv = process.argv.slice(2);
const isDryRun = argv.includes("--dry") || argv.includes("--dry-run");
const isReset = argv.includes("--reset");
const batchSize = (() => {
  const flag = argv.find((a) => a.startsWith("--batch"));
  if (!flag) return 400;
  // --batch=400 또는 --batch 400 모두 허용
  const eqIdx = flag.indexOf("=");
  if (eqIdx >= 0) {
    const v = parseInt(flag.slice(eqIdx + 1), 10);
    return Number.isFinite(v) && v > 0 && v <= 500 ? v : 400;
  }
  const next = argv[argv.indexOf(flag) + 1];
  const v = parseInt(next, 10);
  return Number.isFinite(v) && v > 0 && v <= 500 ? v : 400;
})();

// throttle: writes/sec < 100. batch 단위로 sleep 한다.
// batch=400 기준 4.5초 sleep → 약 88 writes/sec.
const THROTTLE_WPS_TARGET = 90; // 안전 마진 포함 (요건은 < 100)
const throttleMsPerBatch = Math.max(
  0,
  Math.ceil((batchSize / THROTTLE_WPS_TARGET) * 1000)
);

// ----------------------------------------------------------------------------
// 로그·체크포인트 경로
// ----------------------------------------------------------------------------
const LOG_DIR = path.join(__dirname, "logs");
if (!fs.existsSync(LOG_DIR)) fs.mkdirSync(LOG_DIR, { recursive: true });
const LOG_FILE = path.join(LOG_DIR, "backfill_audit_log_seller_uid.log");
const CHECKPOINT_FILE = path.join(
  LOG_DIR,
  "backfill_audit_log_seller_uid.checkpoint.json"
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
    log(`checkpoint loaded: lastProcessedId=${parsed.lastProcessedId} processedCount=${parsed.processedCount}`);
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

// ----------------------------------------------------------------------------
// sellerUid 해석 — 캐시
// ----------------------------------------------------------------------------
const propertySellerUidCache = new Map(); // propertyId → sellerUid | null
const grantSellerUidCache = new Map(); // grantId → { sellerUid, propertyId } | null

async function resolveSellerUidByPropertyId(propertyId) {
  if (!propertyId) return null;
  if (propertySellerUidCache.has(propertyId)) {
    return propertySellerUidCache.get(propertyId);
  }
  const snap = await db.collection("mlsProperties").doc(propertyId).get();
  const sellerUid = snap.exists ? snap.data().userId || null : null;
  propertySellerUidCache.set(propertyId, sellerUid);
  return sellerUid;
}

async function resolveSellerUidByGrantId(grantId) {
  if (!grantId) return null;
  if (grantSellerUidCache.has(grantId)) {
    const cached = grantSellerUidCache.get(grantId);
    return cached ? cached.sellerUid : null;
  }
  const snap = await db.collection("priority_grants").doc(grantId).get();
  if (!snap.exists) {
    grantSellerUidCache.set(grantId, null);
    return null;
  }
  const data = snap.data();
  let sellerUid = data.sellerUid || null;
  // grant 자체에 sellerUid 가 없으면 propertyId 로 fallback
  if (!sellerUid && data.propertyId) {
    sellerUid = await resolveSellerUidByPropertyId(data.propertyId);
  }
  grantSellerUidCache.set(grantId, {
    sellerUid,
    propertyId: data.propertyId || null,
  });
  return sellerUid;
}

// audit log 문서에서 sellerUid 후보를 추출하는 통합 해석기.
// 우선순위: propertyId > grantId > relatedGrantId > inputs.propertyId > inputs.grantId
async function resolveSellerUidForAuditDoc(data) {
  // 1) 직접 propertyId
  if (data.propertyId) {
    const v = await resolveSellerUidByPropertyId(data.propertyId);
    if (v) return v;
  }
  // 2) grantId
  if (data.grantId) {
    const v = await resolveSellerUidByGrantId(data.grantId);
    if (v) return v;
  }
  // 3) relatedGrantId (issue/expire/revoke 이벤트 패턴)
  if (data.relatedGrantId) {
    const v = await resolveSellerUidByGrantId(data.relatedGrantId);
    if (v) return v;
  }
  // 4) inputs 내 nested 값
  const inputs = data.inputs || {};
  if (inputs.propertyId) {
    const v = await resolveSellerUidByPropertyId(inputs.propertyId);
    if (v) return v;
  }
  if (inputs.grantId) {
    const v = await resolveSellerUidByGrantId(inputs.grantId);
    if (v) return v;
  }
  return null;
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
    `start dryRun=${isDryRun} batchSize=${batchSize} throttleMsPerBatch=${throttleMsPerBatch} reset=${isReset}`
  );

  const checkpoint = loadCheckpoint();
  let lastProcessedId = checkpoint ? checkpoint.lastProcessedId : null;
  let cumulativeProcessed = checkpoint ? checkpoint.processedCount || 0 : 0;
  let cumulativeUpdated = checkpoint ? checkpoint.updatedCount || 0 : 0;
  let cumulativeAlreadyOk = checkpoint ? checkpoint.alreadyOkCount || 0 : 0;
  let cumulativeUnresolved = checkpoint ? checkpoint.unresolvedCount || 0 : 0;

  // SIGINT 처리: 현재 batch flush 후 checkpoint 기록
  let shouldStop = false;
  let inProgressBatch = null;
  let inProgressBatchOps = 0;

  process.on("SIGINT", () => {
    log("[SIGINT] received, will flush current batch and exit");
    shouldStop = true;
  });

  const PAGE_SIZE = 500; // Firestore admin SDK page 크기
  let cursor = null;

  // checkpoint 가 있으면 startAfter 로 재개
  if (lastProcessedId) {
    cursor = await db
      .collection("priority_audit_logs")
      .doc(lastProcessedId)
      .get();
    if (!cursor.exists) {
      log(
        `[WARN] checkpoint doc ${lastProcessedId} not found, restarting from beginning`
      );
      cursor = null;
    } else {
      log(`resuming after lastProcessedId=${lastProcessedId}`);
    }
  }

  let pageCount = 0;

  while (!shouldStop) {
    let query = db
      .collection("priority_audit_logs")
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
    let pageUpdated = 0;
    let pageAlreadyOk = 0;
    let pageUnresolved = 0;

    for (const doc of snapshot.docs) {
      if (shouldStop) break;
      cumulativeProcessed += 1;

      const data = doc.data();

      if (data.sellerUid) {
        cumulativeAlreadyOk += 1;
        pageAlreadyOk += 1;
      } else {
        const sellerUid = await resolveSellerUidForAuditDoc(data);
        if (!sellerUid) {
          cumulativeUnresolved += 1;
          pageUnresolved += 1;
          // verbose log only when unresolved (잔여건 디버깅용)
          if (cumulativeUnresolved <= 20) {
            log(
              `[UNRESOLVED] auditId=${doc.id} eventType=${data.eventType} propertyId=${data.propertyId || "-"} grantId=${data.grantId || data.relatedGrantId || "-"}`
            );
          }
        } else if (!isDryRun) {
          batch.update(doc.ref, { sellerUid });
          opsInBatch += 1;
          pageUpdated += 1;
          cumulativeUpdated += 1;
        } else {
          // dryRun: 카운트만
          pageUpdated += 1;
          cumulativeUpdated += 1;
        }
      }

      lastProcessedId = doc.id;

      // 진행률 (1000건마다)
      if (cumulativeProcessed % 1000 === 0) {
        log(
          `progress processed=${cumulativeProcessed} updated=${cumulativeUpdated} alreadyOk=${cumulativeAlreadyOk} unresolved=${cumulativeUnresolved}`
        );
      }

      // batchSize 도달 시 commit + throttle
      if (!isDryRun && opsInBatch >= batchSize) {
        inProgressBatch = batch;
        inProgressBatchOps = opsInBatch;
        await batch.commit();
        log(`commit batch (${opsInBatch} ops, throttle ${throttleMsPerBatch}ms)`);
        inProgressBatch = null;
        inProgressBatchOps = 0;
        batch = db.batch();
        opsInBatch = 0;

        // checkpoint 기록 (commit 직후)
        saveCheckpoint({
          lastProcessedId,
          processedCount: cumulativeProcessed,
          updatedCount: cumulativeUpdated,
          alreadyOkCount: cumulativeAlreadyOk,
          unresolvedCount: cumulativeUnresolved,
          updatedAt: new Date().toISOString(),
        });

        // throttle: writes/sec < 100 보장
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
      `page ${pageCount} done size=${snapshot.size} updated=${pageUpdated} alreadyOk=${pageAlreadyOk} unresolved=${pageUnresolved}`
    );

    saveCheckpoint({
      lastProcessedId,
      processedCount: cumulativeProcessed,
      updatedCount: cumulativeUpdated,
      alreadyOkCount: cumulativeAlreadyOk,
      unresolvedCount: cumulativeUnresolved,
      updatedAt: new Date().toISOString(),
    });

    // 다음 페이지 cursor 설정
    cursor = snapshot.docs[snapshot.docs.length - 1];

    // PAGE_SIZE 미만이면 마지막 페이지
    if (snapshot.size < PAGE_SIZE) {
      log("last page reached");
      break;
    }
  }

  log(
    `done dryRun=${isDryRun} totalProcessed=${cumulativeProcessed} updated=${cumulativeUpdated} alreadyOk=${cumulativeAlreadyOk} unresolved=${cumulativeUnresolved} stopped=${shouldStop}`
  );

  // 정상 완료 시 checkpoint 정리 (재시작용 데이터 불필요)
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
