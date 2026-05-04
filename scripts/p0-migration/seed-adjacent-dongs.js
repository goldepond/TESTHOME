// =============================================================================
// P0-6: adjacent_dongs Firestore 적재 스크립트
// =============================================================================
//
// data/adjacent_dongs/*.json 의 인접동 매핑을 Firestore adjacent_dongs/{lawdCd}
// 컬렉션에 1회 batch 적재한다. JSON Schema 검증 후 batch 단위로 commit.
//
// 사용법:
//   cd D:/Project
//   GOOGLE_APPLICATION_CREDENTIALS=./functions/houseproject-18f44-firebase-adminsdk-fbsvc-3cd1e6b129.json \
//   NODE_PATH=D:/Project/functions/node_modules \
//     node scripts/p0-migration/seed-adjacent-dongs.js [--file path] [--dry-run]
//
// 옵션:
//   --file       JSON 파일 경로 (기본: data/adjacent_dongs/sample-adjacent-dongs.json)
//   --dry-run    실제 쓰기 없이 검증·통계만 출력 (안전 기본 권장)
//
// 산출물:
//   logs/seed-adjacent-dongs.log
//
// 주의:
//   본 스크립트는 멱등(idempotent) 이다. 같은 JSON 으로 두 번 실행하면 갱신만 발생.
//   다른 sido/district 데이터를 누적 적재하려면 매번 다른 --file 로 호출.
// =============================================================================

const path = require("path");
const fs = require("fs");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();
const { Timestamp } = admin.firestore;

const args = process.argv.slice(2);
const isDryRun = args.includes("--dry-run");
const fileArg = (() => {
  const idx = args.indexOf("--file");
  if (idx >= 0) return args[idx + 1];
  return path.join(__dirname, "..", "..", "data", "adjacent_dongs", "sample-adjacent-dongs.json");
})();

const LOG_DIR = path.join(__dirname, "logs");
if (!fs.existsSync(LOG_DIR)) fs.mkdirSync(LOG_DIR, { recursive: true });
const LOG_FILE = path.join(LOG_DIR, "seed-adjacent-dongs.log");
const logStream = fs.createWriteStream(LOG_FILE, { flags: "a" });

function log(msg) {
  const line = `[${new Date().toISOString()}] ${msg}`;
  console.log(line);
  logStream.write(line + "\n");
}

function validateItem(item, idx) {
  const errors = [];
  if (!item.lawdCd || !/^[0-9]{10}$/.test(item.lawdCd)) {
    errors.push(`item[${idx}] invalid lawdCd: ${item.lawdCd}`);
  }
  if (!item.dongName || typeof item.dongName !== "string") {
    errors.push(`item[${idx}] invalid dongName`);
  }
  if (!item.district || typeof item.district !== "string") {
    errors.push(`item[${idx}] invalid district`);
  }
  if (!item.sido || typeof item.sido !== "string") {
    errors.push(`item[${idx}] invalid sido`);
  }
  if (!Array.isArray(item.neighbors)) {
    errors.push(`item[${idx}] neighbors not array`);
  } else {
    item.neighbors.forEach((n, ni) => {
      if (!/^[0-9]{10}$/.test(n)) {
        errors.push(`item[${idx}].neighbors[${ni}] invalid lawdCd: ${n}`);
      }
    });
  }
  if (!item.source || typeof item.source !== "string") {
    errors.push(`item[${idx}] missing source`);
  }
  return errors;
}

(async function main() {
  log(`start dryRun=${isDryRun} file=${fileArg}`);
  if (!fs.existsSync(fileArg)) {
    log(`[ERROR] file not found: ${fileArg}`);
    process.exit(1);
  }

  const raw = JSON.parse(fs.readFileSync(fileArg, "utf8"));
  const items = Array.isArray(raw.items) ? raw.items : [];
  log(`loaded ${items.length} item(s) from ${fileArg}`);

  // 검증
  const allErrors = [];
  items.forEach((it, idx) => {
    const errs = validateItem(it, idx);
    allErrors.push(...errs);
  });
  if (allErrors.length > 0) {
    log(`[ERROR] validation failed (${allErrors.length} errors):`);
    allErrors.slice(0, 20).forEach((e) => log(`  - ${e}`));
    process.exit(1);
  }
  log(`validation passed`);

  // 인접 정합성 점검: A.neighbors 에 B 가 있으면 B.neighbors 에 A 도 있어야 함 (대칭).
  // 본 데이터셋이 cross-district 일 때 누락된 항목은 경고만.
  const itemsByCode = new Map(items.map((it) => [it.lawdCd, it]));
  let asymmetricCount = 0;
  for (const it of items) {
    for (const n of it.neighbors) {
      const partner = itemsByCode.get(n);
      if (partner && !partner.neighbors.includes(it.lawdCd)) {
        asymmetricCount += 1;
        log(`[WARN] asymmetric: ${it.lawdCd}(${it.dongName}) → ${n} 인데 ${n} → ${it.lawdCd} 미등록`);
      }
    }
  }
  log(`asymmetric pairs (in-dataset): ${asymmetricCount}`);

  if (isDryRun) {
    log(`[DRY-RUN] would write ${items.length} document(s) to adjacent_dongs/`);
    await admin.app().delete();
    logStream.end();
    return;
  }

  // batch 적재
  const now = Timestamp.now();
  let batch = db.batch();
  let opsInBatch = 0;
  let written = 0;

  for (const it of items) {
    const ref = db.collection("adjacent_dongs").doc(it.lawdCd);
    batch.set(
      ref,
      {
        lawdCd: it.lawdCd,
        dongName: it.dongName,
        district: it.district,
        sido: it.sido,
        neighbors: it.neighbors,
        source: it.source,
        updatedAt: now,
      },
      { merge: true }
    );
    opsInBatch += 1;
    written += 1;
    if (opsInBatch >= 400) {
      await batch.commit();
      log(`commit batch (${opsInBatch} ops)`);
      batch = db.batch();
      opsInBatch = 0;
    }
  }
  if (opsInBatch > 0) {
    await batch.commit();
    log(`commit final batch (${opsInBatch} ops)`);
  }
  log(`done written=${written}`);

  await admin.app().delete();
  logStream.end();
})();
