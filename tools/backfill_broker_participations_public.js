// =============================================================================
// P0-11: broker_participations → broker_participations_public 백필 스크립트
// =============================================================================
//
// 목적:
//   P1-5에서 신설된 onBrokerParticipationWrittenSyncPublicView 트리거는 *신규
//   broker_participation* 생성 시 자동 미러를 만든다. 이 스크립트는 *기존*
//   broker_participations 도큐먼트를 broker_participations_public으로 1회 백필.
//
// 멱등성:
//   - 이미 미러 존재 + mirroredAt이 동일/더 신규면 skip
//   - --force 옵션으로 강제 덮어쓰기 가능 (운영 데이터 보호 의도적 강제용)
//
// 사용법:
//   GOOGLE_APPLICATION_CREDENTIALS=./functions/<key>.json node tools/backfill_broker_participations_public.js --dry
//   GOOGLE_APPLICATION_CREDENTIALS=./functions/<key>.json node tools/backfill_broker_participations_public.js
//   GOOGLE_APPLICATION_CREDENTIALS=./functions/<key>.json node tools/backfill_broker_participations_public.js --force
//
// 옵션:
//   --dry / --dry-run    write 0건, 통계만
//   --force              이미 존재하는 미러도 덮어쓰기
//   --batch=N            한 번에 처리할 문서 수 (기본 100, 최대 500)
//   --reset              checkpoint 무시하고 처음부터 다시
//
// =============================================================================

const admin = require("firebase-admin");
const fs = require("fs");
const path = require("path");

// CLI 인자 파싱
const argv = process.argv.slice(2);
const isDryRun = argv.includes("--dry") || argv.includes("--dry-run");
const isForce = argv.includes("--force");
const isReset = argv.includes("--reset");
const batchArg = argv.find((a) => a.startsWith("--batch="));
const BATCH_SIZE = batchArg
  ? Math.min(500, Math.max(10, parseInt(batchArg.split("=")[1], 10) || 100))
  : 100;
const THROTTLE_MS = 600; // 약 100 writes/sec 미만

// admin SDK 초기화
if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();

// 로그 파일
const logDir = path.join(__dirname, "logs");
if (!fs.existsSync(logDir)) fs.mkdirSync(logDir, { recursive: true });
const logFile = path.join(
  logDir,
  `backfill_participations_public_${Date.now()}.log`
);
const logStream = fs.createWriteStream(logFile, { flags: "a" });

function log(msg) {
  const line = `[${new Date().toISOString()}] ${msg}`;
  console.log(line);
  logStream.write(line + "\n");
}

// 체크포인트
const checkpointFile = path.join(
  logDir,
  ".backfill_participations_public_checkpoint.json"
);
function loadCheckpoint() {
  if (isReset) return null;
  if (!fs.existsSync(checkpointFile)) return null;
  try {
    return JSON.parse(fs.readFileSync(checkpointFile, "utf-8"));
  } catch {
    return null;
  }
}
function saveCheckpoint(data) {
  fs.writeFileSync(checkpointFile, JSON.stringify(data, null, 2));
}
function clearCheckpoint() {
  if (fs.existsSync(checkpointFile)) fs.unlinkSync(checkpointFile);
}

// 미러로 변환 (PII 제거 — P1-5 §2 spec)
function toPublicView(participation) {
  return {
    displayName: participation.displayName ?? null,
    participationStage: participation.participationStage ?? null,
    declaredAt: participation.declaredAt ?? null,
    visitScheduledAt: participation.visitScheduledAt ?? null,
    offerMadeAt: participation.offerMadeAt ?? null,
    publiclyVisibleAt: participation.publiclyVisibleAt ?? null,
    mirroredAt: admin.firestore.FieldValue.serverTimestamp(),
    // 절대 포함 X: brokerId, brokerUid, 실명, 연락처, relatedGrantId
  };
}

let counters = { scanned: 0, mirrored: 0, skipped: 0, failed: 0, force: 0 };
let shouldStop = false;
process.on("SIGINT", () => {
  log("[SIGINT] 중단 요청 — 현재 batch 완료 후 종료");
  shouldStop = true;
});

async function main() {
  log(
    `=== broker_participations_public 백필 시작 (dry=${isDryRun}, force=${isForce}, batch=${BATCH_SIZE}) ===`
  );

  const checkpoint = loadCheckpoint();
  let lastDocPath = checkpoint?.lastDocPath ?? null;
  if (lastDocPath) log(`[checkpoint] 재개: ${lastDocPath}`);

  // collectionGroup 횡단 스캔
  let processedThisRun = 0;
  while (!shouldStop) {
    let q = db.collectionGroup("broker_participations").orderBy(admin.firestore.FieldPath.documentId());
    if (lastDocPath) {
      const lastSnap = await db.doc(lastDocPath).get();
      if (lastSnap.exists) q = q.startAfter(lastSnap);
    }
    q = q.limit(BATCH_SIZE);

    const snap = await q.get();
    if (snap.empty) {
      log("[done] 더 이상 처리할 문서 없음");
      break;
    }

    for (const doc of snap.docs) {
      counters.scanned++;
      const data = doc.data();
      const participationId = doc.id;
      const propertyId = doc.ref.parent.parent?.id;
      if (!propertyId) {
        log(`[skip:no-property] ${doc.ref.path}`);
        counters.skipped++;
        continue;
      }

      const publicRef = db
        .collection("mlsProperties")
        .doc(propertyId)
        .collection("broker_participations_public")
        .doc(participationId);

      try {
        if (!isForce) {
          const existing = await publicRef.get();
          if (existing.exists) {
            counters.skipped++;
            continue;
          }
        } else {
          counters.force++;
        }

        if (!isDryRun) {
          await publicRef.set(toPublicView(data));
        }
        counters.mirrored++;
        lastDocPath = doc.ref.path;

        // throttle
        await new Promise((r) => setTimeout(r, THROTTLE_MS / BATCH_SIZE));
      } catch (err) {
        log(`[fail] ${doc.ref.path}: ${err.message}`);
        counters.failed++;
      }
    }

    processedThisRun += snap.docs.length;
    saveCheckpoint({ lastDocPath, processedThisRun, counters });
    log(
      `[progress] 누적 scanned=${counters.scanned} mirrored=${counters.mirrored} skipped=${counters.skipped} failed=${counters.failed}`
    );

    if (snap.docs.length < BATCH_SIZE) {
      log("[done] 마지막 batch 처리 완료");
      break;
    }
  }

  // 최종 보고
  log("=== 백필 종료 ===");
  log(`scanned: ${counters.scanned}`);
  log(`mirrored: ${counters.mirrored} (dry-run=${isDryRun})`);
  log(`skipped (이미 존재): ${counters.skipped}`);
  log(`force-overwrite: ${counters.force}`);
  log(`failed: ${counters.failed}`);

  if (!shouldStop && counters.failed === 0 && !isDryRun) {
    clearCheckpoint();
    log("[checkpoint] 정상 완료 — 체크포인트 삭제");
  }

  await admin.app().delete();
  logStream.end();
  process.exit(shouldStop ? 130 : counters.failed > 0 ? 1 : 0);
}

main().catch((err) => {
  log(`[FATAL] ${err.stack || err.message || err}`);
  logStream.end(() => process.exit(1));
});
