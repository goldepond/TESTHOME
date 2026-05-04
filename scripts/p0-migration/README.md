# P0 출시 직전 마이그레이션 스크립트 모음

> **상위 문서**: [docs/task/2026-05-03-MASTER-v1.3-mvp-handoff.md](../../docs/task/2026-05-03-MASTER-v1.3-mvp-handoff.md) §3.1 P0 1·2·4·5·6
> **작성일**: 2026-05-03
> **실행 환경**: Node 20 + firebase-admin (functions/ 디렉토리에서 실행)

본 디렉토리의 스크립트는 **모두 1회용**이며, MyHome v1.3 출시 직전 한 번만 실행한다.
운영 후 본 디렉토리는 archive 처리해도 된다.

## 실행 순서 (의존성 그래프)

```
[1] firebase deploy --only firestore:indexes  (P0-3 — 사전 적용)
        ↓
[2] seed-broker-eligibility.js  (P0-2 + P0-5 통합 — region 비정규화 포함)
        ↓
[3] migrate-target-broker-ids.sh  (P0-1 dryRun → 검토 → 실행)
        ↓
[4] backfill-audit-log-seller-uid.js  (P0-4)
        ↓
[5] seed-adjacent-dongs.js  (P0-6)
        ↓
[6] firebase deploy --only firestore:indexes  (targetBrokerIds 인덱스 2건 *삭제* 후 재배포)
```

## 사전 준비

```bash
cd D:/Project/functions
npm install
# 서비스 계정 키는 functions/houseproject-18f44-firebase-adminsdk-fbsvc-3cd1e6b129.json 사용
export GOOGLE_APPLICATION_CREDENTIALS="D:/Project/functions/houseproject-18f44-firebase-adminsdk-fbsvc-3cd1e6b129.json"
```

각 스크립트는 본인 헤더에 별도 환경 변수·인자 명세 포함. 본 README가 진입점.

## 실행 후 산출물

각 스크립트 실행 결과는 콘솔 로그 + `scripts/p0-migration/logs/{YYYY-MM-DD-task}.log` 에 보존.
실행자는 결과 요약을 [docs/task/2026-05-03-p0-migration-execution.md](../../docs/task/2026-05-03-p0-migration-execution.md) 에 기록한다.
