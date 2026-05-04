# migrateTargetBrokerIds 운영 절차 (Runbook)

> **대상 함수**: `functions/index.js` `exports.migrateTargetBrokerIds` (onRequest, asia-northeast3)
> **연관 컬렉션**: `mlsProperties` (read), `priority_grants` / `priority_audit_logs` (write)
> **배포 환경**: 프로덕션 1회용 — 실행 후 함수 코드 자체는 [핸드오프 §5.3 #9](../docs/task/2026-04-29-task-01-data-model-handoff.md) 가이드에 따라 제거 권장
> **연관 스크립트**: `scripts/p0-migration/migrate-target-broker-ids.sh` (대화형 dryRun→실 실행 헬퍼)
> **본 문서 절대 변경 금지 대상**: `functions/index.js` (절차 문서이며 함수 코드 변경 0)

---

## 0. TL;DR

```
[사전 점검] count → backup → 코드 의존 제거(필수)
    ↓
[dryRun]   GET ?dryRun=true   → JSON 통계 검토
    ↓
[실 실행]  GET ?dryRun=false  → priority_grants 일괄 생성(status=expired)
    ↓
[사후 검증] grant 수 일치 / audit log grant_issued 1:1 매칭
    ↓
[인덱스 정리] targetBrokerIds 인덱스 2건 삭제 → indexes 재배포
```

**중대 선결 조건**: 본 마이그레이션은 *데이터*만 변환한다. `lib/api_request/mls_property_service.dart`의 3개 메서드(`getPropertiesBroadcastedToBroker` / `getPropertiesBroadcastedToBrokerStream` / `getPropertiesBroadcastedToBrokerFast`)가 여전히 `targetBrokerIds × arrayContains` 쿼리를 사용한다. **인덱스 삭제 단계는 위 3개 메서드를 priority_grants 기반으로 교체한 뒤에 진행한다.** (자세히는 §6 참조)

---

## 1. 사전 점검

### 1.1 카운트 — 영향 범위 산출

Firebase 콘솔 또는 Firestore CLI에서 다음 카운트를 측정한다. 운영 카운트는 dryRun 결과 검증 기준선이 된다.

```bash
# 활성 매물 총수 (dryRun이 스캔할 대상 모집단)
gcloud firestore documents list \
  --collection-path=mlsProperties \
  --filter="isDeleted=false AND isActive=true" \
  --format="value(name)" | wc -l

# 위와 동등한 Cloud Logging 쿼리 (콘솔 → Logs Explorer)
#   resource.type="firestore_database"
#   protoPayload.methodName="google.firestore.v1.Firestore/RunQuery"
```

또는 관리자 노트북에서 admin SDK로 직접 카운트:

```js
// scripts/p0-migration/count-target-broker-ids.js (1회용 헬퍼, 권장)
const admin = require('firebase-admin');
admin.initializeApp({ credential: admin.credential.applicationDefault() });
const db = admin.firestore();

(async () => {
  const snap = await db.collection('mlsProperties')
    .where('isDeleted', '==', false)
    .where('isActive', '==', true)
    .get();
  let total = snap.size;
  let withTargets = 0;
  let withSeller = 0;
  let totalGrantsToCreate = 0;
  snap.forEach(doc => {
    const d = doc.data();
    const t = Array.isArray(d.targetBrokerIds) ? d.targetBrokerIds : [];
    if (t.length > 0) withTargets += 1;
    if (d.userId) withSeller += 1;
    totalGrantsToCreate += t.filter(b => typeof b === 'string').length;
  });
  console.log({ total, withTargets, withSeller, totalGrantsToCreate });
})();
```

**기록 의무**: 위 4개 값을 [docs/task/2026-05-03-p0-migration-execution.md](../docs/task/2026-05-03-p0-migration-execution.md) §사전점검 절에 적는다 (없으면 해당 파일 신설).

### 1.2 Firestore 백업 (필수, 권고 아님)

본 마이그레이션은 `targetBrokerIds`를 *덮어쓰지 않는다*. 그러나 `priority_grants` 컬렉션에 대량 쓰기를 수행하므로, 롤백 시점의 baseline 확보 차원에서 두 컬렉션을 GCS로 export 한다.

```bash
# 사전: GCS 버킷 준비 (1회만)
gsutil mb -l asia-northeast3 gs://houseproject-18f44-firestore-backups

# Export
gcloud firestore export gs://houseproject-18f44-firestore-backups/$(date +%Y%m%d-%H%M%S)-pre-migrate-tbi \
  --collection-ids=mlsProperties,priority_grants,priority_audit_logs

# 출력 폴더명 기록 (롤백 import 시 필요)
```

**원칙**: export 완료 폴더 경로(`gs://.../YYYYMMDD-HHMMSS-pre-migrate-tbi`)를 실행 로그에 명시 보존한다.

### 1.3 코드 의존 제거 — *마이그레이션 자체와 별개의 필수 선결*

본 마이그레이션은 데이터를 priority_grants로 옮기지만, 클라이언트 쿼리는 여전히 `targetBrokerIds`를 읽고 있다 (위 §0 노트). **본 단계 §1.3을 §6(인덱스 삭제) 전까지 처리한다.** §1.3을 건너뛰고 인덱스만 삭제하면 중개사 대시보드 3개 호출이 *실패*한다.

대상 (확인 시점 기준):
| 파일 | 라인 | 메서드 |
|---|---|---|
| `lib/api_request/mls_property_service.dart` | 357 | `getPropertiesBroadcastedToBroker` |
| `lib/api_request/mls_property_service.dart` | 384 | `getPropertiesBroadcastedToBrokerStream` |
| `lib/api_request/mls_property_service.dart` | 470 | `getPropertiesBroadcastedToBrokerFast` |

교체 방향: `priority_grants`(brokerId == X, status in [active, expired])에서 propertyId를 모은 뒤 `mlsProperties` documentId-IN 조회. 본 작업은 본 runbook의 범위가 아니며, [Task 02 핸드오프](../docs/task/2026-04-30-task-02-m1-seller-broker-handoff.md) 후속 작업으로 처리.

---

## 2. dryRun 호출 절차

### 2.1 환경 변수

```bash
export ADMIN_SECRET="<Firebase Functions secret 'ADMIN_SECRET' 값>"
export FUNCTIONS_REGION_HOST="asia-northeast3-houseproject-18f44.cloudfunctions.net"
```

`ADMIN_SECRET`은 Functions 배포 시 등록한 secret 값이다 (`functions/index.js:28` `defineSecret("ADMIN_SECRET")`). 콘솔 → Secret Manager에서 조회 가능.

### 2.2 호출 명령 (단일 curl)

```bash
curl -sS -G "https://${FUNCTIONS_REGION_HOST}/migrateTargetBrokerIds" \
  --data-urlencode "secret=${ADMIN_SECRET}" \
  --data-urlencode "dryRun=true" \
  -o scripts/p0-migration/logs/migrate-target-broker-ids-dryrun.json
```

또는 대화형 헬퍼 스크립트 사용:

```bash
bash scripts/p0-migration/migrate-target-broker-ids.sh
# → dryRun 결과 출력 후 yes/no 입력 시 실 실행으로 진행
```

### 2.3 안전 기본값 확인

함수 코드 (`functions/index.js:2056`):
```
const dryRun = String(req.query.dryRun || "true").toLowerCase() !== "false";
```
`dryRun` 파라미터가 누락되거나 오타가 있으면 자동으로 dryRun으로 동작한다. 실 실행은 *반드시 명시적인* `dryRun=false`만 트리거.

---

## 3. dryRun 결과 검토

### 3.1 응답 스키마

```json
{
  "dryRun": true,
  "migratedProperties": 123,
  "createdGrants": 456,
  "skippedNoTargets": 78,
  "skippedNoSellerUid": 2,
  "totalScanned": 201,
  "sampleProperties": [
    { "propertyId": "...", "sellerUid": "...", "targetBrokerCount": 3 },
    ...최대 5건
  ]
}
```

### 3.2 검증 체크리스트

- `totalScanned` ≈ §1.1에서 측정한 활성 매물 수 (오차 < 1%, 동시성 차이는 허용)
- `migratedProperties + skippedNoTargets == totalScanned`
- `createdGrants` ≈ §1.1 헬퍼의 `totalGrantsToCreate` (동일해야 함)
- **`skippedNoSellerUid == 0`이 이상적**. 0보다 크면 해당 매물의 grant는 생성되지만 `sellerUid=null` 상태로 저장되어 *매도자가 본인 매물의 grant를 조회 불가*. 0이 아닐 경우:
  1. 어느 propertyId가 `userId` 누락인지 식별 (sampleProperties에 sellerUid=null인 항목 또는 별도 헬퍼 스크립트로 전수 추출)
  2. 매도자 백필 작업 후 재검토. *마이그레이션 진행 보류*.
- `sampleProperties[*].sellerUid` 5건 모두 정상 uid (28자 영숫자) 인지 확인.

### 3.3 분할 실행 권고 (운영 부담 완화)

전국 단위로 한 번에 실행하면 priority_grants에 수천~수만 건이 일시 생성되어 인덱스 빌드/Cloud Functions cold-start 비용이 집중된다. 운영 부담을 줄이려면 다음을 권장:

- **시군구(`region` 필드) 단위 분할 실행**: 함수에 `region` 파라미터를 *추가하지 않고*, 운영 단계에서는 야간(트래픽 저점) 1회 실행으로 충분. 대신 dryRun에서 `createdGrants > 5000`이면 운영 매뉴얼에 분할 실행 필요성을 명시하고, 함수 본체에 `region` 파라미터를 도입하는 후속 task를 등록한다 (본 runbook은 함수 변경 금지).
- **시간대**: 한국 새벽 02:00~05:00 KST 권장 (`recomputeBrokerEligibilityScheduled`가 03:00 KST에 동작하므로 01:00 KST 또는 06:00 KST 직후를 회피해 04:00 KST 권장).

---

## 4. 실 실행 절차

### 4.1 호출 명령

```bash
curl -sS -G "https://${FUNCTIONS_REGION_HOST}/migrateTargetBrokerIds" \
  --data-urlencode "secret=${ADMIN_SECRET}" \
  --data-urlencode "dryRun=false" \
  -o scripts/p0-migration/logs/migrate-target-broker-ids-real.json
```

권장: 위 단일 curl 대신 헬퍼 스크립트(`bash scripts/p0-migration/migrate-target-broker-ids.sh`)를 통해 dryRun 결과를 한 번 더 본 뒤 yes 입력으로 진행.

### 4.2 진행률 모니터링 (Cloud Logging)

함수가 한 매물씩 batch.commit()을 호출하기 때문에 진행 도중에는 별도 진행률 로그를 출력하지 않는다. 완료 후 단일 로그 라인이 출력된다 (`functions/index.js:2188`):

```
[migrateTargetBrokerIds] dryRun=false migratedProperties=N createdGrants=M skippedNoTargets=K skippedNoSellerUid=L
```

진행 중 모니터링은 Cloud Logging에서:

```
resource.type="cloud_run_revision"
resource.labels.service_name="migratetargetbrokerids"
severity>=DEFAULT
```

타임아웃: onRequest 함수는 default 60s. 매물 수천 건 + grant 수만 건이면 60s를 초과할 수 있다. 그럴 경우 함수 옵션에 `timeoutSeconds: 540` 추가가 필요하나 *본 runbook은 함수 변경 금지*. 운영 시점에 timeout으로 실패하면 §7 롤백 절차로 되돌리고, 함수 코드 변경(timeout/region 분할)은 별도 PR로 처리한다.

### 4.3 응답 스키마 (실 실행)

dryRun 응답에서 `sampleProperties`만 빠진다.

```json
{
  "dryRun": false,
  "migratedProperties": 123,
  "createdGrants": 456,
  "skippedNoTargets": 78,
  "skippedNoSellerUid": 0,
  "totalScanned": 201
}
```

---

## 5. 사후 검증

### 5.1 priority_grants 신규 문서 카운트 일치

```js
// scripts/p0-migration/verify-grants-count.js
const snap = await db.collection('priority_grants')
  .where('statusReason', '==', 'migrated_legacy')
  .get();
console.log({ migratedGrantsTotal: snap.size });
```

응답의 `createdGrants` 값과 일치해야 한다. 일치하지 않으면 §7 부분 롤백 검토.

### 5.2 audit log 정합성

함수는 매물별 grant마다 1건의 `grant_issued` audit log를 트랜잭션 내가 *아닌* 동일 batch에 기록한다 (`functions/index.js:2142`).

**주의 — 명세 정정**: 본 함수에는 `migration_completed` 단일 마스터 audit log가 *생성되지 않는다*. 사용자/이전 명세에 "migration_completed 1건" 검증이 적혀 있다면, 실제 검증 항목은 **`grant_issued` × N건** (N == createdGrants) 이다.

```js
const snap = await db.collection('priority_audit_logs')
  .where('rulebookVersion', '==', 'legacy_migration')
  .where('outputs.statusReason', '==', 'migrated_legacy')
  .get();
console.log({ legacyAuditLogs: snap.size });
// 기대: == createdGrants
```

> ⚠️ `priority_audit_logs.outputs.statusReason` 인덱스가 없을 수 있다. 인덱스 미가용 시 `.where('rulebookVersion', '==', 'legacy_migration')`로 1차 필터 후 클라이언트에서 검사.

차이가 0이 아니면: priority_grants 트랜잭션은 성공했지만 audit log는 누락된 케이스(매우 드물지만 batch 부분 실패 가능). 누락 grant에 대해 audit log를 사후 보정하는 별도 백필 스크립트가 필요.

### 5.3 단일 매물 샘플 검증

dryRun `sampleProperties[0].propertyId`를 골라 콘솔에서 직접 확인:
- `priority_grants` 컬렉션에 `pg_legacy_{propertyId}_{brokerId}` 형식의 문서가 `targetBrokerCount`만큼 존재하는가
- 각 문서의 `status == "expired"`, `statusReason == "migrated_legacy"`, `sellerUid` 정상 채워짐

---

## 6. targetBrokerIds 인덱스 2건 삭제 절차

### 6.1 선결 조건 — 코드 의존 제거 완료 확인 (재확인)

§1.3에서 처리한 `lib/api_request/mls_property_service.dart`의 3개 메서드가 priority_grants 기반으로 교체되었음을 git diff로 확인. 미처리 시 인덱스 삭제 금지.

```bash
# Flutter 코드에 targetBrokerIds 쿼리가 남아있는지 검증
grep -rn "where('targetBrokerIds'" lib/
# 기대: 출력 없음 (model의 필드 정의와 toMap/fromMap만 남는 것은 OK)
```

### 6.2 삭제 대상 인덱스 (firestore.indexes.json)

현재 2건 (`firestore.indexes.json:257-296`):

| # | collectionGroup | fields |
|---|---|---|
| 1 | `mlsProperties` | `targetBrokerIds (CONTAINS)` + `isDeleted (ASC)` + `broadcastedAt (DESC)` |
| 2 | `mlsProperties` | `targetBrokerIds (CONTAINS)` + `isActive (ASC)` + `isDeleted (ASC)` + `broadcastedAt (DESC)` |

> ℹ️ Firestore 인덱스에는 사람이 부여하는 "이름"이 없다. 식별은 (collectionGroup, fields 조합)으로 한다. 콘솔에서는 indexId(자동 생성)가 보이지만 코드에서는 fields 조합이 단일 진실 원본.

### 6.3 삭제 절차

1. `firestore.indexes.json` 편집: 위 2개 객체를 indexes 배열에서 제거.
2. JSON 유효성 확인:
   ```bash
   python -m json.tool firestore.indexes.json > /dev/null && echo OK
   ```
3. 인덱스 수 확인 (현재 31개 → 29개):
   ```bash
   python -c "import json; print(len(json.load(open('firestore.indexes.json'))['indexes']))"
   ```
4. 배포:
   ```bash
   firebase deploy --only firestore:indexes
   ```
5. Firebase 콘솔(Firestore → Indexes)에서 두 인덱스가 *삭제 진행 중* → *제거됨* 상태가 되는지 확인 (수 분~수십 분 소요).

### 6.4 인덱스 삭제 후 영향 검증

기대: 영향 없음 (코드 의존이 §1.3에서 제거되었으므로).

검증:
- 중개사 대시보드 (배포된 매물 탭) 정상 로드
- 빠른 초기 로딩 메서드 정상 응답
- Cloud Logging에 `FAILED_PRECONDITION: The query requires an index` 에러가 새로 발생하지 않는지 1시간 모니터링

발생 시: 해당 쿼리가 §1.3에서 누락된 케이스. 즉시 인덱스 복원(`firestore.indexes.json` 되돌리고 `firebase deploy --only firestore:indexes`).

---

## 7. 롤백 시나리오

### 7.1 즉시 롤백 (실 실행 직후 ~ 24h 이내)

신규 생성된 `priority_grants` 문서만 일괄 삭제하면 baseline 복원. `targetBrokerIds` 자체는 변경되지 않았으므로 백업 import 불필요.

```js
// scripts/p0-migration/rollback-migrate-target-broker-ids.js (1회용 헬퍼)
const admin = require('firebase-admin');
admin.initializeApp({ credential: admin.credential.applicationDefault() });
const db = admin.firestore();

(async () => {
  const grantsSnap = await db.collection('priority_grants')
    .where('statusReason', '==', 'migrated_legacy')
    .get();
  console.log(`[rollback] target grants: ${grantsSnap.size}`);

  // 동일 grantId의 audit log도 함께 정리
  const auditSnap = await db.collection('priority_audit_logs')
    .where('rulebookVersion', '==', 'legacy_migration')
    .get();
  console.log(`[rollback] target audit logs: ${auditSnap.size}`);

  // batch 한도(500) 보호
  const allRefs = [...grantsSnap.docs, ...auditSnap.docs].map(d => d.ref);
  for (let i = 0; i < allRefs.length; i += 400) {
    const batch = db.batch();
    allRefs.slice(i, i + 400).forEach(ref => batch.delete(ref));
    await batch.commit();
    console.log(`[rollback] deleted ${Math.min(i + 400, allRefs.length)} / ${allRefs.length}`);
  }
})();
```

실행 전 `dryRun` 모드 분기 추가 권장 (위 스니펫은 즉시 삭제하므로 운영 적용 시 1차로 카운트만 출력하는 분기 추가).

### 7.2 인덱스 삭제 이후 발견된 문제 — 인덱스만 복원

`firestore.indexes.json`의 §6.2 두 객체를 git revert 또는 수동 복구 후:
```bash
firebase deploy --only firestore:indexes
```
인덱스 빌드까지 수 분~수십 분 소요. 그 사이 §1.3에서 교체한 priority_grants 기반 쿼리는 여전히 동작하므로 사용자 영향은 없다.

### 7.3 데이터 손상 — 백업 import (최후의 수단)

`targetBrokerIds`가 어떤 사고로 *수정/삭제*된 경우(본 마이그레이션은 그럴 일이 없으나 동시 운영 사고 가정). §1.2에서 export 한 GCS 경로로 import:

```bash
gcloud firestore import gs://houseproject-18f44-firestore-backups/YYYYMMDD-HHMMSS-pre-migrate-tbi \
  --collection-ids=mlsProperties
```

**경고**: import는 import 시점의 *전체 컬렉션을 덮어쓴다*. import 직전~시점에 발생한 신규 매물 등록/수정이 사라진다. 운영팀과 합의 후 트래픽 차단(Cloud Run 또는 Hosting maintenance page) 상태에서만 실행.

---

## 8. 실행 후 산출물 보존

| 산출물 | 위치 |
|---|---|
| dryRun 결과 JSON | `scripts/p0-migration/logs/migrate-target-broker-ids-dryrun.json` |
| 실 실행 결과 JSON | `scripts/p0-migration/logs/migrate-target-broker-ids-real.json` |
| 사전점검 카운트 | `docs/task/2026-05-03-p0-migration-execution.md` (신설 가능) |
| GCS export 경로 | 위 동일 문서에 명시 보존 |
| Cloud Logging 완료 로그 | 자동 보존 (Stackdriver) — 텍스트로 발췌해 위 문서에 첨부 권장 |

---

## 9. 미해결 의문점 (운영자 결정 필요)

1. **함수 timeout 60s 충분한가?** — 매물 수가 수천을 넘으면 timeout 위험. dryRun 결과의 `totalScanned`로 사전 판단 후, 위험 시 *함수 변경 PR 별도 진행* (본 runbook은 코드 변경 금지). 잠정 가이드: `totalScanned > 1000`이면 timeout 540s 옵션 추가 PR을 먼저 머지.
2. **`migration_completed` 마스터 audit log 추가 여부** — 현재 함수는 grant별 audit log만 기록. 운영 적합성은 audit 정책 담당자 결정. 추가가 필요하면 후속 PR.
3. **분할 실행 시 region 파라미터** — 본 runbook은 함수 변경 금지로 region 파라미터 없이 단일 호출 권장. 매물 수가 5000건을 초과하면 region 파라미터 도입 후 시군구별 호출이 안전.

---

**작성일**: 2026-05-03
**상위 문서**: [docs/task/2026-05-03-MASTER-v1.3-mvp-handoff.md](../docs/task/2026-05-03-MASTER-v1.3-mvp-handoff.md)
**관련 핸드오프**: [docs/task/2026-04-29-task-01-data-model-handoff.md](../docs/task/2026-04-29-task-01-data-model-handoff.md) §3·§5
