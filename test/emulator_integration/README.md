# Emulator 통합 테스트 — Task 02·03·04·05·06·07 시나리오

> **작성**: 2026-05-03 / 총괄 책임자 직접 작성 (sub-agent 사용량 한계 후 인계)
> **원천**: [Task 04·05·06·07 §7.3 공통](../../docs/task/2026-04-30-task-04-tiered-release-handoff.md) — Emulator 통합 테스트 자동화
> **상태**: ⚠️ **scaffold + 1 sample 시나리오 + 6 placeholder**. 풀 구현은 후속 phase (P3 권고 — 본 task 범위 외).

---

## 0. 한 줄 요약

Firebase emulator로 Task 02·03·04·05·06·07의 callable·트리거 통합 흐름을 자동 검증. 본 phase는 **scaffold + `01_m1_seller_broker.test.js` 1개 샘플 + 나머지 6개 placeholder**. 풀 구현은 운영 직전 또는 P0 게이트 통과 후 별도 phase.

---

## 1. 7개 시나리오

| # | 파일 | Task | 흐름 |
|---|---|:---:|---|
| 01 | `01_m1_seller_broker.test.js` | 02 | broker [이 매물 받기] → grant 14일 발급 → 7일 후 활동 0 → 만료 |
| 02 | `02_m1_buyer_broker.test.js` | 03 | 매수자 임장 신청 → 중개사 선택 → buyer_match grant 30일 + 24h 쿨다운 |
| 03 | `03_tiered_release.test.js` | 04 | 매물 등록 → 1km 알림 → 24h 후 같은 동 → 활성 grant 시 정지 |
| 04 | `04_m2_disclosure.test.js` | 05 | broker_participations 자동 displayName + 트리거 단계 전이 |
| 05 | `05_appeal_full_cycle.test.js` | 06 | 이의 제기 → 자동 replay → admin resolve → 통보 |
| 06 | `06_metrics_alert.test.js` | 06 | computeDailyMetricsScheduled → red alertLevel |
| 07 | `07_exclusive_listing.test.js` | 07 | exclusive 모드 → 비지정 broker 거절 → 모드 변경 24h 쿨다운 |

본 PR에서 **#01만 풀 구현**, #02~07은 *placeholder* (TODO 주석 + 시나리오 한 줄 설명).

---

## 2. 사전 요구

### 2.1 Firebase emulator 설치
```bash
npm install -g firebase-tools
firebase login
firebase init emulators  # 처음 1회. functions / firestore / auth 선택.
```

### 2.2 의존성
```bash
cd functions && npm install --save-dev @firebase/rules-unit-testing mocha chai
```

`functions/package.json` devDependencies에 추가 (PR 통합 시):
```json
"devDependencies": {
  "@firebase/rules-unit-testing": "^4.0.0",
  "mocha": "^10.0.0",
  "chai": "^4.3.0"
}
```

---

## 3. 실행 절차

### 3.1 단일 시나리오
```bash
cd functions
firebase emulators:exec --only firestore,auth,functions \
  "npx mocha ../test/emulator_integration/01_m1_seller_broker.test.js"
```

### 3.2 전체 7건
```bash
cd functions
firebase emulators:exec --only firestore,auth,functions \
  "npx mocha ../test/emulator_integration/*.test.js --timeout 30000"
```

### 3.3 GitHub Actions 통합 (P3 후속)
`.github/workflows/emulator-integration.yml` 신설 권고:
- PR 트리거 (functions/index.js 또는 firestore.rules 변경 시)
- Node 20 + Firebase CLI 설치
- `firebase emulators:exec` 위 명령
- 실패 시 PR 거절

---

## 4. 시간 시뮬레이션 패턴

대부분 시나리오에서 *14일·24h·30일 등 시간 진행* 필요. emulator는 실시간이라 직접 대기 불가. 다음 패턴 채택:

```javascript
// 직접 timestamp 주입 (admin SDK)
const grantRef = db.collection('priority_grants').doc(grantId);
await grantRef.update({
  expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() - 1) // 1ms 전
});

// 그 후 expireGrantsScheduled 수동 트리거
await admin.firestore().runTransaction(async tx => { ... });

// 또는 callable 직접 호출 (Cloud Functions 측 시뮬레이션)
const wrapped = test.wrap(myFunctions.expireGrantsScheduled);
await wrapped();
```

---

## 5. 데이터 격리

각 테스트는 *clean state*에서 시작:
```javascript
beforeEach(async () => {
  await testEnv.clearFirestore();
});
```

테스트 간 의존성 **0**. 각 시나리오는 자체 데이터 setup → 검증 → cleanup.

---

## 6. 알려진 제약

### 6.1 emulator 한계
- Cloud Tasks 트리거 미지원 → schedule 트리거는 수동 호출
- FCM push 알림 미지원 → notifications 컬렉션 생성만 검증
- `algorithm_config/active` bootstrap은 첫 호출 시 자동 — 명시적 시드 필요

### 6.2 Java 의존성
emulator는 Java 11+ 필요. 운영 머신에 설치 안 된 경우:
```bash
# Windows: choco install openjdk
# macOS: brew install openjdk@11
# Linux: apt install openjdk-11-jre-headless
```

### 6.3 본 phase 범위 외
- TestContainers 기반 *완전 격리* 환경 — P3 별도
- Firestore Rules unit test (별도 — `@firebase/rules-unit-testing`) — P3 별도
- 통합 테스트 vs 단위 테스트 — 본 디렉토리는 *통합*만

---

## 7. 트러블슈팅

### 7.1 `firebase emulators:exec` 실행 실패
- Java 미설치 — §6.2 참조
- 포트 충돌 (8080·9099·5001) — `firebase.json`에서 포트 변경
- `firebase init emulators` 미수행

### 7.2 `Cannot find module '@firebase/rules-unit-testing'`
```bash
cd functions && npm install --save-dev @firebase/rules-unit-testing
```

### 7.3 timeout
- mocha `--timeout 30000` 옵션 추가
- 개별 테스트 `this.timeout(60000)` 명시

---

## 8. 후속 phase 권고

### 8.1 #02~07 풀 구현
본 PR은 #01만 sample. 풀 구현 시 각 시나리오:
- setup: 사용자·broker·매물 시드
- act: callable·트리거 호출 + 시간 시뮬레이션
- assert: Firestore 상태 + audit log + 알림 검증
- cleanup: clearFirestore

### 8.2 CI 통합 (P3)
GitHub Actions로 PR 자동 검증. 본 README §3.3 참조.

### 8.3 부하 테스트 (P4)
emulator는 *정합성* 검증용. 실 부하·동시성 검증은 *staging Firestore 별도 프로젝트* + 부하 시뮬레이션 도구 필요.

---

## 9. 변경 통계

| 항목 | 값 |
|---|---|
| 신규 파일 | 본 README + 01 sample = 2건 |
| placeholder 파일 (TODO) | 6건 |
| 의존성 추가 권고 | 3종 (@firebase/rules-unit-testing, mocha, chai) |
| 풀 구현 phase | 후속 (P3) |
