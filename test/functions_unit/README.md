# Cloud Functions 단위 테스트 인프라

> **작성**: 2026-05-03 / P1-23
> **상태**: ⚠️ scaffold + sample 1. 32 exports 풀 커버리지는 후속 phase.

---

## 0. 한 줄 요약

functions/index.js 32 exports의 *내부 헬퍼·순수 함수* 단위 테스트 인프라. P2-3 (Emulator 통합 테스트)과 별도 — 본 디렉토리는 *오프라인 단위 테스트*.

---

## 1. 프레임워크

- **Mocha + Chai** — 가장 단순. functions/package.json devDependencies 추가
- 의존성:
  ```json
  "devDependencies": {
    "mocha": "^10.0.0",
    "chai": "^4.3.0",
    "sinon": "^17.0.0",
    "firebase-functions-test": "^3.1.0"
  }
  ```

P2-3 emulator 통합 테스트와 *별개*. 본 디렉토리는 외부 의존성 없는 *순수 함수* 단위 테스트.

---

## 2. 실행 방법

```bash
cd functions && npm install --save-dev mocha chai sinon firebase-functions-test
cd ..
npx mocha test/functions_unit/*.test.js
```

또는 functions/package.json scripts에 추가:
```json
"scripts": {
  "test:unit": "mocha ../test/functions_unit/*.test.js"
}
```

---

## 3. 테스트 파일

| 파일 | 검증 대상 | 상태 |
|---|---|:---:|
| `scoring.test.js` | P2-4 `serializeRawInputs` regression | ✅ sample |
| `audit.test.js` | audit log 1:1 동기 패턴 | ⏳ placeholder |
| `copy_codes.test.js` | REASON ↔ reasonCopy 1:1 (JS 측 검증, P1-2와 별도) | ⏳ placeholder |
| `weights.test.js` | MATCHING_WEIGHTS 합 1.0 ± 0.001 | ⏳ placeholder |
| `tier_advancement.test.js` | tier 진척 결정 룰 | ⏳ placeholder |
| `eligibility.test.js` | broker_eligibility 검증 분기 | ⏳ placeholder |

본 PR에서 **scoring.test.js만 풀 구현**. 나머지 5건 placeholder.

---

## 4. P2-3 emulator 통합 테스트와의 차이

| | 본 디렉토리 (단위) | test/emulator_integration (통합) |
|---|---|---|
| 외부 의존성 | 0 (sinon mock) | Firebase emulator |
| 속도 | 빠름 (msec) | 느림 (sec~min) |
| 검증 범위 | 헬퍼·순수 함수 | callable·트리거 풀 흐름 |
| 시나리오 | 1 함수 in/out | M1.1·M1.2·tier·M2 등 흐름 |

---

## 5. 후속 phase 권고

- 32 exports 풀 커버리지 — 본 phase는 *인프라 + sample 1*
- CI 통합 (.github/workflows/functions-unit.yml) — PR 트리거 자동 실행
- coverage report (nyc 또는 c8)

---

## 6. 안전성

- functions/index.js *수정 0* — 테스트만 신설
- 운영 의존성 추가 X (devDependencies만 — 빌드 영향 0)
- 의존성 *권고만* — 실제 추가는 별도 PR

---

## 7. 미해결 의문점

- 의존성 추가는 별도 PR 권고 — functions 빌드에 영향 미미하나 분리 안전
- coverage report 도구 선택 — nyc vs c8 (Node 20 환경 c8 권장)
- CI 통합 시점 — P1-1 (PR CI 게이트)와 통합 가능
