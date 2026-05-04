# P2-7 — 임장 신용점수 페널티 (Trust Score) 제안서

> **상위 문서**: [`2026-05-03-MASTER-v1.3-mvp-handoff.md`](2026-05-03-MASTER-v1.3-mvp-handoff.md) §3.3
> **목표 근거**: [`docs/goal/multi_agent_competition_solutions_cross_industry.md`](../goal/multi_agent_competition_solutions_cross_industry.md) §4.1
> **법무 게이트**: [`docs/common/platform_commission_intervention_legal_check.md`](../common/platform_commission_intervention_legal_check.md) §32·§33
> **노출 화법**: [`docs/task/08-simplicity-doctrine.md`](08-simplicity-doctrine.md) §3.4 (점수 노출 절대 금지)
> **카피 단일 진실원**: [`docs/common/copy-deck.md`](../common/copy-deck.md)
> **버전**: v1.1.0 (P2-7, 2026-05-03)
> **상태**: **제안서 — 코드 변경 0**. 데이터 누적 게이트 충족 후 별도 phase에서 코드 작성.

---

## 0. 결론 한 줄

> **broker 단위 *누적 행동 점수* (0~100, 초기값 70 중립). 노쇼·약속 불이행 시 차감 → M1 매칭 가중치 반영. 사용자 화면에 *점수 숫자* 노출 0건. *3단계 카테고리 라벨* 만 노출. 즉시 도입 X — 임장 5,000건 + 활성 broker 100명 게이트 충족 후 도입.**

---

## 1. 배경 — 왜 행동 데이터 기반 페널티인가

### 1.1 노쇼 주범은 매수자측 "임장 크루"

- 한국 부동산 현장에서 노쇼·약속 불이행의 다수는 **매수자측이 broker 동행 임장을 "아이쇼핑"용으로 소비**하는 패턴에서 발생. 매도자·broker 시간 손실이 누적되어 *플랫폼 신뢰* 자체가 훼손됨.
- 다만 broker도 *매수자 일정 변경 핑계로* 노쇼 → 매도자에 손해 떠넘기는 케이스 존재. **양방향 행동 추적**이 필요.

### 1.2 §32·§33 충돌 회피 — 행동 데이터는 보수 분배 X

[`platform_commission_intervention_legal_check.md`](../common/platform_commission_intervention_legal_check.md) 핵심 결론:
- **§32 강행규정**: 보수 약정 강제 — 본 메커니즘은 *보수 산정에 일절 관여 X*. 매물 노출 순서만 영향. **무관**.
- **§33①3호 "보수 외 금품 수수 금지"**: 본 메커니즘은 *점수 = 보수 X, 우대 = 금품 X*. **무관**.
- **§33①9호 "단체결성 부당 영향"**: broker 점수는 *개별 행동 데이터*. 단체 결성 X. **무관**.
- **§33② "누구든지"**: 가격에 영향 X, 보수에 영향 X. **무관**.

→ 본 메커니즘은 §32·§33과 *완전 무관*. 단 후술 §6 broker 명예훼손 우려는 별도 차단.

### 1.3 데이터 누적 0 = 의미 0

> *출시 직후엔 모든 broker `trustScore = 70` → 매칭 가중치 효과 0. 페널티 차이가 형성되려면 누적 행동 데이터 필요.*

본 task는 **설계만 정의**. 코드 작성·배포는 §8 게이트 충족 후 별도 phase.

---

## 2. 점수 모델

### 2.1 기본 정의

| 항목 | 값 |
|---|---:|
| 점수 단위 | broker 단위 누적 |
| 범위 | `[0, 100]` (clamp) |
| 초기값 | **70 (중립)** |
| 저장 위치 | `broker_eligibility.trustScore` (P0-2 시드와 통합) |
| 갱신 주기 | 일 1회 batch (`recomputeTrustScore` scheduled function) — 즉시 반영 X |
| **점수 표시 게이트** | broker × visit 누적 ≥ **N=20건** 충족 후 표시. 미달 시 **"신뢰도 평가 중"** |

### 2.2 초기값 70인 이유

- 50 (정중앙) 아닌 **70**: 신규 broker가 *불공정한 페널티 상태*로 시작하지 않도록 약간 양의 중립.
- 70 + 거래 1건 성사 (+5) = 75. 노쇼 1건 (-3) = 67. → 충분한 *상하 여백*.
- 페널티만으로는 0까지 가지 않도록 (자연 회복 없이 -10 페널티 7회 = 0) 게이트 가드와 결합.

### 2.3 점수 변동 룰 (6개)

> **즉시 반영 X — 일 1회 batch로 누적 적용. 변동성 차단.**

| # | 이벤트 | 변동 | 트리거 (도입 시 구현) |
|---|---|---:|---|
| 1 | **노쇼** (방문 약속 후 broker 측 미참석) | **-3** | `no_show_reports.status='confirmed'` (매수자 신고 + 매도자 확인) |
| 2 | **시간 지각** (10분 이상) | **-1** | `visitRequests` `actualArrivalAt - scheduledAt > 600s` |
| 3 | **매수자 무리한 변경** (24h 쿨다운 범위 외 변경 강요) | **-2** | `visitRequests.changeRequests` count *and* 매도자 동의 X |
| 4 | **단계 진척 성공** (declared → visit_scheduled → offer_made) | **+1** | `participation_stages` 단계 transition 당 (단계당 +1, 누적 최대 +3) |
| 5 | **거래 성사** (`grant.status='fulfilled'`) | **+5** | `priority_grants.status` transition |
| 6 | **분쟁 발생** (이의 제기 인정) | **-10** | `priority_appeals.status='accepted'` |

**핵심 원칙**:
- 페널티 합 = -16/사이클. 보상 합 = +9/사이클. **약간 페널티 우위** (현장 노쇼 비용이 크기 때문).
- 단일 이벤트 *큰 페널티* (-10 분쟁 인정) — 이의 제기 *인정* 단계까지 도달한 경우만. *접수만으로* 페널티 X.
- *상호 확인* 필수: 노쇼는 매수자 신고 + 매도자 확인 *둘 다*. 한쪽 신고만으론 -3 적용 X.

### 2.4 데이터 모델 (제안)

`broker_eligibility/{brokerId}` 에 필드 추가 (P0-2 시드 컬렉션과 통합):

```json
{
  "brokerId": "broker-uuid",
  "licenseStatus": "verified",
  "jurisdictionMatch": ["11680"],

  "trustScore": 70,
  "trustScoreLastComputedAt": "2026-05-03T...",
  "trustEventsCount": 12,
  "trustVisitCount": 35,
  "trustNoShowCount": 1,
  "trustDeltaHistory": [
    { "eventType": "no_show_confirmed", "delta": -3, "scoreAfter": 67, "at": "2026-05-01T..." },
    { "eventType": "stage_offer_made",   "delta": +1, "scoreAfter": 68, "at": "2026-05-02T..." }
  ],
  "trustRulebookVersion": "v1.5.0"
}
```

**Firestore Rules** (도입 시):
```
match /broker_eligibility/{brokerId} {
  // trustScore 필드 본인·admin 만 읽기. 매도자/매수자에겐 *서버 변환된 카테고리* 만 노출
  allow read: if isAuthenticated() && (request.auth.uid == brokerId || isAdmin());
  allow create, update, delete: if false;  // Functions만
}
```

### 2.5 일 1회 batch 산정 — `recomputeTrustScore` scheduled function

```
스케줄: 매일 03:00 KST
입력: priority_audit_logs 의 *전일 행동 이벤트*
산정:
  1. eventType별 점수 변동 합산
  2. broker_eligibility.trustScore 에 clamp(0, 100) 적용
  3. trustDeltaHistory append (최근 90건 유지)
  4. trustVisitCount, trustNoShowCount 누적 갱신
즉시 반영 X 이유: broker 즉각 항의 차단, *변동성으로 인한 신뢰 훼손* 차단
```

---

## 3. 데이터 흐름

```
[broker 행동 이벤트]
   ↓ (priority_audit_logs 누적 — Task 06)
[일 1회 03:00 KST recomputeTrustScore scheduled function]
   ↓
[broker_eligibility.trustScore 갱신 (clamp 0-100)]
   ↓
[다음 매물 grant 산정 시 scoringInputs.rawInputs.trustScore 로 흘러감]
   ↓
[Dynamic Matching 가중치 적용 (§5)]
   ↓
[grant 우선순위 결정]
```

**P0-2 (broker_eligibility 시드) 와 통합**:
- 별도 컬렉션 `broker_trust_score` 신설 X. 기존 `broker_eligibility` 에 `trustScore` 필드 추가.
- 한 broker 의 *자격 + 신뢰* 정보 단일 문서 — 운영자 admin 화면에서 한눈에 확인.

**Task 06 (priority_audit_logs) 와 통합**:
- 행동 이벤트는 audit log 에 이미 기록됨. trustScore 산정용 *별도 이벤트 컬렉션 X*.
- 일 1회 scheduled function 이 audit log 에서 전일분만 read.

---

## 4. 노출 정책 — 80세 화법 적용

### 4.1 핵심 원칙 — doctrine §3.4 점수 노출 *절대 금지*

[`08-simplicity-doctrine.md`](08-simplicity-doctrine.md) §3.4:
> *"점수 노출 절대 금지"*

→ 사용자 화면 어디에도 `trustScore: 67` 같은 표기 **0건**.

### 4.2 3단계 카테고리화 — *상위 N% 표시*

매도자/매수자 화면에는 **3단계 라벨**만 노출. 점수 *직접 노출 0*.

| 카테고리 | 임계값 (상위 %) | 표시 카피 (제안) |
|---|---:|---|
| **A — 활동 많음** | 상위 30% | "이 동네 활동 많은 분" |
| **B — 보통** | 상위 30~70% | "이 동네 활동 중인 분" |
| **C — 시작** | 하위 30% | "이 동네 활동 시작하는 분" |
| **(미달)** | 임장 누적 < 20건 | "신뢰도 평가 중" |

**임계값 동적 산정**: 각 시군구별로 *해당 시군구 broker 점수 분포* 기준. 시군구 별 컷오프 다름. *전국 단일 컷오프 X* (시장별 broker 풀 다름).

**카테고리 산정 함수** (서버 측):
```
getCategoryLabel(brokerId, regionCode):
  if brokerId.trustVisitCount < 20: return "신뢰도 평가 중"
  scores = broker_eligibility 중 jurisdictionMatch contains regionCode 의 trustScore[]
  pct = percentile(scores, brokerId.trustScore)
  if pct >= 70: return "이 동네 활동 많은 분"
  if pct >= 30: return "이 동네 활동 중인 분"
  return "이 동네 활동 시작하는 분"
```

### 4.3 노출 영역별 카피

#### 4.3.1 매도자 화면 — 단계 라벨만, 점수 숫자 X

| 영역 | 카피 (제안) |
|---|---|
| 매물 받은 broker 카드 (배지) | "이 동네 활동 많은 분" / "이 동네 활동 시작하는 분" / "신뢰도 평가 중" |
| 노쇼 발생 후 매도자 화면 | "○○월 ○○일 ○○시 임장에 안 오셨어요. 다음 매물부터 다른 분에게 기회가 갑니다" (사실 통지) |

> *broker 이름 + 신용점수 숫자* 같은 조합 절대 X — 명예훼손 위험 (§6 참고).

#### 4.3.2 매수자 화면 — 카테고리 라벨

| 영역 | 카피 |
|---|---|
| 임장 동행 broker 카드 | "이 동네 활동 많은 분" |
| 노쇼 신고 confirm | "신고를 받았어요. 매도자 확인 후 처리됩니다" |

#### 4.3.3 broker 본인 화면 — *본인 한정* 절대값 노출 허용

본인은 *자기 점수* 알아야 개선 가능. 단, 도입 시 *80세 화법으로 변환*:

| 영역 | 카피 |
|---|---|
| 대시보드 상단 — 점수 양호 시 | "내 활동 점수: 78점 (이 동네 상위 20%) — 새 매물 받기가 쉬워졌어요" |
| 대시보드 상단 — 점수 낮음 | "내 활동 점수: 55점 — 최근 약속을 못 지킨 게 있어요. 새 매물부터 다시 잘 진행하시면 자연스럽게 회복돼요" |
| 점수 변동 알림 | "최근 60일 약속을 모두 잘 지켰어요. 새 매물 받기가 쉬워졌습니다" |
| 평가 데이터 부족 | "임장 20건 채우면 점수가 표시돼요. 지금까지 ○건" |

> 본인 한정 노출은 *심리적 자기 결정권* (개선 가능) 보장. 매도자/매수자 노출은 *명예훼손 차단* 위해 카테고리 라벨만.

#### 4.3.4 admin 화면 — 절대값 + 변동 이력 + 수동 조정

운영자는 점수 절대값 + `trustDeltaHistory` 전체 + 수동 조정 권한.

### 4.4 [`copy-deck.md`](../common/copy-deck.md) 신규 카피 추가 (도입 시)

```markdown
## §3 신용점수 카테고리 라벨 (P2-7)
| 코드 | 카피 |
|---|---|
| `trust_category_high`  | 이 동네 활동 많은 분 |
| `trust_category_mid`   | 이 동네 활동 중인 분 |
| `trust_category_start` | 이 동네 활동 시작하는 분 |
| `trust_category_pending` | 신뢰도 평가 중 |

## §3 신용점수 사실 통지 (P2-7)
| 코드 | 카피 |
|---|---|
| `trust_no_show_reported`  | 약속에 안 오셨다는 신고가 들어왔어요 |
| `trust_no_show_confirmed` | 매도자가 확인했어요. 다음 매물부터 다른 분에게 기회가 갑니다 |
| `trust_recovery_positive` | 최근 60일 약속을 모두 잘 지켰어요. 새 매물 받기가 쉬워졌습니다 |
```

---

## 5. 알고리즘 매칭 통합 — *별도 phase*

### 5.1 현재 (v1.3) 6변수

[`02-m1-seller-broker.md`](02-m1-seller-broker.md) §3 의 Dynamic Matching 6변수.

### 5.2 P2-7 도입 후 — 7번째 변수 추가 검토

> **핵심 결정**: 7번째 변수 가중치 *별도 phase* 에서 결정. 본 task에서는 **trustScore 산정만 정의**, 매칭 가중치 통합은 *후속*.

**이유**:
- 데이터 누적 부족 시 trustScore 분산 작음 → 가중치 부여해도 효과 0
- 시군구별 broker 풀이 다르므로 *전국 단일 가중치 X*. `algorithm_config` 외부화 필수
- 가중치 변경은 카카오 257억 패턴 위험 — 점진적 외부화 (§7)

### 5.3 단계적 도입 절차

| 단계 | 시점 | `algorithm_config.weights.trustScore` | UI 노출 |
|---|---|---:|---|
| **shadow** | 임장 누적 1,000건 도달 | **0.0** (계산만, 매칭 영향 X) | X |
| **gradual** | 임장 5,000건 + broker 100명 도달 (§8 게이트) | **0.05** | 카테고리 라벨만 |
| **steady** | 임장 10,000건+ 안정화 후 | **0.10** | 정식 노출 |

**가중치 변경은 `algorithm_config/active.weights` 단일 진실원** — 코드 상수 0. Task 06의 `replayDecision` 으로 *시점값 + 가중치* 재현 가능.

---

## 6. 카카오 회피 — 본 메커니즘이 §32·§33 위반하지 않는 이유 + broker 명예훼손 차단

### 6.1 §32·§33 충돌 표

| 위험 | 본 메커니즘 영향 |
|---|---|
| §33①3호 (보수 외 금품 수수 금지) | **0** — 점수와 보수 무관. 점수 = 매물 노출 순서 영향 X 보수 산정 X |
| §33①9호 (단체결성 부당 영향) | **0** — broker 점수는 개별 행동 데이터. 단체 결성 X |
| §33② "누구든지" | **0** — 가격에 영향 X |
| §32 강행규정 | **0** — 보수 약정 강제 영역 무관 |
| 카카오 257억 패턴 (고정 우대) | **회피** — Dynamic Matching 7변수 *동시* 적용. trustScore 단독 우대 X |

### 6.2 동적 회복 룰 — 카카오 패턴 회피 핵심

> *고정 우대 패턴* 형성 시 카카오 257억 패턴 위반. 동적 회복 룰 필수.

**시간 경과 정규화** (도입 시):
- 90일 무행동 broker 의 trustScore → 70 (초기값) 으로 천천히 회귀 (decay)
- decay 공식: `newScore = trustScore + (70 - trustScore) × 0.05` (월 1회 적용)
- 결과: 노쇼 1회 받은 broker도 *행동 회복 시 점수 회복* — *영구 페널티 X*

### 6.3 broker 명예훼손 차단

> **broker 본인 신용점수 + broker 이름 조합을 매도자/매수자에게 노출 X.** 카테고리 라벨만.

**원천 데이터 공개 차단**:
- `trustDeltaHistory` 매도자/매수자 노출 X. 본인·admin 만 read.
- "○○ 부동산 점수 43점" 같은 표기 절대 X
- 시군구별 점수 분포 *집계 데이터* 만 공개 가능 — 개별 broker 식별 X

**이의 제기 권리** (도입 시):
- broker 가 자기 점수 변동에 이의 제기 → admin 검토 → 수동 조정 가능
- `priority_appeals` 컬렉션 활용 (Task 06)

---

## 7. 도입 시점 게이트 — *현재 N/A*

### 7.1 게이트 충족 조건

본 메커니즘 도입 전 **모든 조건 충족 필수**:

| 조건 | 임계값 | 현재 (2026-05-03) |
|---|---:|---:|
| 활성 broker 수 | ≥ **100명** | 0 (출시 전) |
| 임장 누적 건수 | ≥ **5,000건** | 0 |
| broker × 노쇼 누적 | ≥ **50건** (전체의 1% 가정) | 0 |
| trustScore 분산 (std dev) | > **8** (의미 있는 차이 형성) | N/A |
| Task 06 audit log 안정 운영 | **3개월 이상** | 미시행 |

### 7.2 게이트 미달 상태에서의 표시

- **임장 < 20건 broker**: "신뢰도 평가 중" 라벨
- **전체 임장 < 5,000건 (시스템 전체)**: P2-7 *전체 비활성화* — 매칭 가중치 0, 라벨 노출 X
- **시군구별 broker < 5명**: 해당 시군구만 카테고리 산정 비활성화 (분포 형성 불가)

### 7.3 phase 도입 순서 (제안)

```
[현재] P2-7 설계 문서만 (본 문서)
   ↓ (출시 후 6개월)
[shadow] 임장 1,000건 도달 — 산정만, UI 노출 0, 가중치 0
   ↓
[gradual] 임장 5,000건 + broker 100명 — 카테고리 라벨 노출, 가중치 0.05
   ↓
[steady] 임장 10,000건+ — 정식 운영, 가중치 0.10
```

---

## 8. 법무 검토 결과

### 8.1 §32·§33 무관 — 보수 분배 X

본 메커니즘:
- 점수 = 보수 X. 점수 변동은 *매물 노출 순서*에만 영향.
- 보수 약정 강제 영역 무관 (§32).
- 금품 수수 금지 영역 무관 (§33①3).
- 단체 결성 영역 무관 (§33①9).
- "누구든지" 영역 무관 (§33②).

### 8.2 broker 명예훼손 우려 — 원천 데이터 공개 차단

> **점수 원천 데이터** (개별 노쇼 사례, 점수 절대값) **매도자/매수자에게 공개 X**.

차단 메커니즘:
1. `trustDeltaHistory` 컬렉션 *본인 + admin 만 read*
2. 매도자/매수자 화면엔 *카테고리 라벨* 만 노출
3. broker 이름 + 점수 숫자 조합 *절대 X*
4. 이의 제기 권리 보장 (admin 수동 조정 가능)

### 8.3 §33①8 비밀유지 의무 — 무관

broker 가 알게 된 *고객 비밀* 유출 영역. 본 메커니즘은 broker *자신의 행동* 평가 — 무관.

### 8.4 향후 추가 검토 항목

| 항목 | 검토 시점 |
|---|---|
| 개인정보보호법 — broker 점수가 "민감 정보" 인지 | 도입 phase 진입 전 법무 자문 |
| 시장 진출국 별 페널티 calibration | i18n phase 와 결합 |
| broker 단체 (지역 협회) 단체 항의 시 대응 | shadow 단계 모니터링 |

---

## 9. 도입 시 체크리스트 (코드 작업 시 본 표 기준 PR 생성)

### 9.1 데이터 모델

- [ ] `broker_eligibility` 에 `trustScore`, `trustScoreLastComputedAt`, `trustEventsCount`, `trustVisitCount`, `trustNoShowCount`, `trustDeltaHistory[]`, `trustRulebookVersion` 필드 추가
- [ ] `firestore.rules` `broker_eligibility.trustScore` 본인+admin 읽기 룰
- [ ] `firestore.indexes.json` 인덱스 (jurisdictionMatch + trustScore desc)
- [ ] `no_show_reports/{reportId}` 신규 컬렉션 (filerUid, brokerId, visitRequestId, status, evidenceRefs[])

### 9.2 Cloud Functions

- [ ] `recomputeTrustScore` (scheduled, 매일 03:00 KST) — 일 1회 batch 산정
- [ ] `confirmNoShowReport` (callable, admin/매도자) → -3 적용
- [ ] `decayTrustScore` (scheduled, 월 1회) — 동적 회복 룰

### 9.3 Dynamic Matching 통합 (별도 phase)

- [ ] `algorithm_config.weights.trustScore` 0.05 (shadow) → 0.10 (steady)
- [ ] `issuePriorityGrant` 의 `scoringInputs.rawInputs.trustScore` 산정
- [ ] `replayDecision` 에서 trustScore 시점값 복구

### 9.4 UI 카피 (사용자) — 80세 화법

- [ ] [`copy-deck.md`](../common/copy-deck.md) §3 카테고리 라벨 4개 + 사실 통지 3개 추가
- [ ] `grant_messages.dart` 신용점수 관련 상수 추가
- [ ] [`simplicity-checklist.md`](../common/simplicity-checklist.md) 21항목 통과
- [ ] 80세 가상 인터뷰 6질문 답변
- [ ] 매도자/매수자 화면 *점수 숫자 노출 0건* 검수
- [ ] broker 본인 화면 절대값 노출 — *80세 화법으로 변환* 검수

### 9.5 운영자 화면

- [ ] `admin_broker_trust_page.dart` 신규 — broker별 점수 + 변동 이력 + 수동 조정
- [ ] `admin_no_show_reports_page.dart` 신규 — pending 신고 큐 + confirm/reject

---

## 10. 미해결 의문점

| 항목 | 후속 결정 |
|---|---|
| 시군구별 broker 풀이 작은 지역 (broker < 5명) — 카테고리 산정 어떻게? | 지역 광역화 (시도 단위) 검토 — 데이터 누적 후 |
| 익명 신고 vs 실명 신고 | 매수자 보복 우려 vs 신고 남용 — 정책 결정 |
| 7번째 변수 가중치 (0.05? 0.10? 0.15?) | shadow phase 데이터 보고 결정 |
| broker 단체 (지역 협회) 항의 시 대응 | shadow 단계 모니터링 |
| 점수 임계 미달 broker 자동 비활성화? | 점수 < 30 자동 일시 정지 vs 수동 admin 결정 — 운영 부담 검토 |
| 한 broker 가 여러 시군구에서 활동 시 카테고리 라벨 다르게? | shadow 단계 — 시군구별 분포 보고 결정 |
| decay 공식 (월 5%) calibration | 데이터 보고 결정 |

---

## 11. 변경 이력

| 일자 | 버전 | 변경 |
|---|---|---|
| 2026-05-03 | v1.0.0 | 초안 — 8개 점수 룰, 초기값 50, 가중치 7변수 통합 |
| 2026-05-03 | v1.1.0 | **사양 재정의** — 점수 룰 6개 단순화 (-3/-1/-2/+1/+5/-10), 초기값 70 (중립), 점수 표시 게이트 N=20, 노출 정책 3단계 카테고리화 ("이 동네 활동 많은 분"), broker 본인 한정 절대값 노출, 도입 게이트 임장 5,000건 + broker 100명 명시, 매칭 가중치 통합은 별도 phase, 동적 회복 룰 (decay) 추가, broker 명예훼손 차단 강화 |
