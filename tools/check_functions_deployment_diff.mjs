#!/usr/bin/env node
// check_functions_deployment_diff.mjs
//
// problem 002 (2026-05-04 functions 대량 미배포) 재발 방지 모니터.
// `functions/index.js`의 `exports.*` 정의와 Firebase 서버에 실제 배포된 함수
// 인벤토리를 비교한다. CI/PR/사후 검증 3 모드를 지원한다.
//
// 사용법:
//   node tools/check_functions_deployment_diff.mjs --pre-deploy
//   node tools/check_functions_deployment_diff.mjs --post-deploy
//   node tools/check_functions_deployment_diff.mjs --ci
//   node tools/check_functions_deployment_diff.mjs --help
//
// Exit codes:
//   0  코드와 서버가 일치 (또는 --pre-deploy 에서 신규 export 만 있는 경우)
//   1  코드/서버 차이 발견 (--post-deploy 또는 --ci 모드에서만 실패)
//   2  firebase CLI 미설치 또는 실행 불가
//   3  잘못된 인자 / 입력 파일 누락
//
// 의존성:
//   - Node 20+ (built-in: fs, path, child_process, url)
//   - firebase-tools CLI (글로벌 또는 npx) — 미설치 시 친화적 에러 + exit 2
//
// 본 스크립트는 npm 의존성을 *추가하지 않는다* (Node 빌트인만 사용).

import { readFileSync, existsSync, appendFileSync } from 'node:fs';
import { dirname, resolve as pathResolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = pathResolve(__dirname, '..');
const FUNCTIONS_INDEX = pathResolve(REPO_ROOT, 'functions', 'index.js');
const FIREBASE_PROJECT = 'houseproject-18f44';

const MODE = {
  PRE: 'pre-deploy',
  POST: 'post-deploy',
  CI: 'ci',
};

// ── CLI 파싱 ────────────────────────────────────────────────────────────────

function parseArgs(argv) {
  const args = argv.slice(2);
  const result = { mode: null, help: false };
  for (const a of args) {
    if (a === '--help' || a === '-h') {
      result.help = true;
    } else if (a === '--pre-deploy') {
      result.mode = MODE.PRE;
    } else if (a === '--post-deploy') {
      result.mode = MODE.POST;
    } else if (a === '--ci') {
      result.mode = MODE.CI;
    } else {
      console.error(`알 수 없는 인자: ${a}`);
      result.unknown = a;
    }
  }
  return result;
}

function printHelp() {
  console.log(`
check_functions_deployment_diff.mjs
  functions/index.js의 exports와 Firebase 배포 인벤토리를 비교한다.

사용법:
  node tools/check_functions_deployment_diff.mjs [모드]

모드:
  --pre-deploy    PR 단계용 — 코드 신규 export 는 정상 (배포 전이므로 실패 X).
                  코드 삭제(서버에만 존재)는 orphan 경고로 표시.
  --post-deploy   배포 직후 검증용 — 양방향 일치 검사. 차이 1건이라도 exit 1.
  --ci            cron/모니터 모드 — --post-deploy 와 동일하지만 GitHub Step
                  Summary 형식(Markdown)으로 추가 출력.
  --help, -h      본 도움말 출력 후 exit 0.

Exit codes:
  0  일치 (또는 pre-deploy에서 신규 export만 있는 경우)
  1  불일치 (post-deploy / ci 모드에서만)
  2  firebase CLI 미설치 / 실행 불가
  3  잘못된 인자 / 입력 파일 누락

예시:
  # 로컬에서 코드 vs 배포 차이 확인
  node tools/check_functions_deployment_diff.mjs --post-deploy

  # PR 단계 사전 점검
  node tools/check_functions_deployment_diff.mjs --pre-deploy
`);
}

// ── functions/index.js exports 추출 ──────────────────────────────────────────

function extractCodeExports(filePath) {
  if (!existsSync(filePath)) {
    console.error(`[ERR] functions/index.js를 찾을 수 없습니다: ${filePath}`);
    process.exit(3);
  }
  const src = readFileSync(filePath, 'utf8');
  // `exports.<이름> = ` 형태만 추출. 주석 처리된 라인은 제외.
  const re = /^[\t ]*exports\.([A-Za-z_$][A-Za-z0-9_$]*)\s*=/gm;
  const found = new Set();
  let m;
  while ((m = re.exec(src)) !== null) {
    found.add(m[1]);
  }
  return found;
}

// ── firebase functions:list 호출 ─────────────────────────────────────────────

function fetchDeployedFunctions(project) {
  // firebase CLI 존재 검증 (Windows/POSIX 양쪽 호환)
  const isWin = process.platform === 'win32';
  const cmd = isWin ? 'firebase.cmd' : 'firebase';
  const args = ['functions:list', '--json', '--project', project];

  const result = spawnSync(cmd, args, {
    encoding: 'utf8',
    shell: isWin, // Windows에서 firebase.cmd resolution을 위해
  });

  if (result.error && result.error.code === 'ENOENT') {
    console.error(`
[ERR] firebase CLI를 찾을 수 없습니다.
      다음 중 하나로 설치해 주세요:
        npm install -g firebase-tools
        또는 npx firebase-tools functions:list ...
`);
    process.exit(2);
  }

  if (result.status !== 0) {
    console.error(`[ERR] firebase functions:list 실행 실패 (exit ${result.status}).`);
    if (result.stderr) console.error(result.stderr);
    if (result.stdout) console.error(result.stdout);
    process.exit(2);
  }

  let parsed;
  try {
    parsed = JSON.parse(result.stdout);
  } catch (e) {
    console.error('[ERR] firebase functions:list 결과를 JSON 파싱하지 못했습니다.');
    console.error(e.message);
    process.exit(2);
  }

  // CLI 응답 형식이 버전마다 다를 수 있어 두 가지 형식 모두 지원:
  // 1) { result: [{id, region, ...}, ...] }
  // 2) [{id, region, ...}, ...]
  const list = Array.isArray(parsed) ? parsed : (parsed.result || []);
  const byName = new Map(); // name → [{ region, ... }]
  for (const fn of list) {
    const name = fn.id || fn.name || fn.functionName;
    if (!name) continue;
    const region = fn.region || fn.location || 'unknown';
    if (!byName.has(name)) byName.set(name, []);
    byName.get(name).push({ region });
  }
  return byName;
}

// ── 비교 / 출력 ──────────────────────────────────────────────────────────────

function diff(codeExports, deployedByName) {
  const codeSet = new Set(codeExports);
  const deployedSet = new Set(deployedByName.keys());

  const codeOnly = [...codeSet].filter((n) => !deployedSet.has(n)).sort();
  const serverOnly = [...deployedSet].filter((n) => !codeSet.has(n)).sort();

  // 리전 mismatch — 코드는 단일 리전을 정적으로 추론하기 어려우므로 정보성으로 처리
  const multiRegion = [];
  for (const [name, regions] of deployedByName.entries()) {
    if (regions.length > 1) {
      multiRegion.push({ name, regions: regions.map((r) => r.region) });
    }
  }

  return { codeOnly, serverOnly, multiRegion };
}

function formatPlain(result, mode) {
  const { codeOnly, serverOnly, multiRegion } = result;
  const lines = [];
  lines.push(`mode: ${mode}`);
  lines.push(`코드만 (서버에 미배포): ${codeOnly.length}개`);
  for (const n of codeOnly) lines.push(`  + ${n}`);
  lines.push(`서버만 (코드에 없음 / orphan): ${serverOnly.length}개`);
  for (const n of serverOnly) lines.push(`  - ${n}`);
  lines.push(`멀티 리전 배포 (정보): ${multiRegion.length}개`);
  for (const m of multiRegion) {
    lines.push(`  ! ${m.name} → [${m.regions.join(', ')}]`);
  }
  return lines.join('\n');
}

function formatMarkdown(result, mode) {
  const { codeOnly, serverOnly, multiRegion } = result;
  const lines = [];
  lines.push('## Cloud Functions 배포 일치 검사');
  lines.push('');
  lines.push(`- mode: \`${mode}\``);
  lines.push(`- 코드만 (서버 미배포): **${codeOnly.length}개**`);
  lines.push(`- 서버만 (orphan 위험): **${serverOnly.length}개**`);
  lines.push(`- 멀티 리전 배포: **${multiRegion.length}개**`);
  lines.push('');
  if (codeOnly.length > 0) {
    lines.push('### 신규/미배포 함수');
    for (const n of codeOnly) lines.push(`- \`${n}\``);
    lines.push('');
  }
  if (serverOnly.length > 0) {
    lines.push('### Orphan 의심 (서버에만 존재)');
    for (const n of serverOnly) lines.push(`- \`${n}\``);
    lines.push('');
  }
  if (multiRegion.length > 0) {
    lines.push('### 멀티 리전 (정보)');
    for (const m of multiRegion) {
      lines.push(`- \`${m.name}\` → ${m.regions.join(', ')}`);
    }
    lines.push('');
  }
  return lines.join('\n');
}

// ── main ────────────────────────────────────────────────────────────────────

function main() {
  const args = parseArgs(process.argv);
  if (args.help) {
    printHelp();
    process.exit(0);
  }
  if (args.unknown) {
    printHelp();
    process.exit(3);
  }
  if (!args.mode) {
    console.error('[ERR] 모드를 지정해 주세요 (--pre-deploy / --post-deploy / --ci)');
    printHelp();
    process.exit(3);
  }

  console.log(`[info] functions/index.js exports 추출: ${FUNCTIONS_INDEX}`);
  const codeExports = extractCodeExports(FUNCTIONS_INDEX);
  console.log(`[info] 코드에서 발견된 exports: ${codeExports.size}개`);

  console.log(`[info] firebase functions:list 호출 (project=${FIREBASE_PROJECT})…`);
  const deployedByName = fetchDeployedFunctions(FIREBASE_PROJECT);
  console.log(`[info] 서버에 배포된 함수: ${deployedByName.size}개`);

  const result = diff(codeExports, deployedByName);
  console.log('\n' + formatPlain(result, args.mode));

  // GitHub Step Summary 자동 출력 (CI 모드)
  if (args.mode === MODE.CI) {
    const stepSummary = process.env.GITHUB_STEP_SUMMARY;
    if (stepSummary) {
      try {
        const md = formatMarkdown(result, args.mode);
        appendFileSync(stepSummary, md + '\n');
        console.log('[info] GITHUB_STEP_SUMMARY에 결과를 첨부했습니다.');
      } catch (e) {
        console.warn(`[warn] GITHUB_STEP_SUMMARY 작성 실패: ${e.message}`);
      }
    }
  }

  // 모드별 exit 결정
  const totalDiff = result.codeOnly.length + result.serverOnly.length;

  if (args.mode === MODE.PRE) {
    // PR 단계: 신규 export(=codeOnly)는 정상. orphan(=serverOnly)만 경고로 노출하나
    // exit 1 까지 가지 않음 (배포 전 단계이므로 차단하지 않음).
    if (result.serverOnly.length > 0) {
      console.warn(`[warn] orphan 의심 함수가 ${result.serverOnly.length}개 있습니다 — 배포 시 --force 정리 필요.`);
    }
    process.exit(0);
  }

  // post-deploy / ci: 양방향 일치 강제
  if (totalDiff === 0) {
    console.log('\n[OK] 코드와 서버가 일치합니다.');
    process.exit(0);
  }
  console.error(`\n[FAIL] 차이 ${totalDiff}건 발견 — 배포 검증 실패.`);
  process.exit(1);
}

main();
