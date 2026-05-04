# P2-8 — 33% Contribution Recognition (WGA 모델 차용) 제안서

> **상위 문서**: [`2026-05-03-MASTER-v1.3-mvp-handoff.md`](2026-05-03-MASTER-v1.3-mvp-handoff.md) §3.3
> **목표 근거**: [`docs/goal/multi_agent_competition_solutions_cross_industry.md`](../goal/multi_agent_competition_solutions_cross_industry.md) §4.3
> **법무 근거**: [`docs/common/platform_commission_intervention_legal_check.md`](../common/platform_commission_intervention_legal_check.md) §32 / §33
> **사례 카탈로그**: [`docs/common/cross_industry_anti_poaching_complete_catalog.md`](../common/cross_industry_anti_poaching_complete_catalog.md) §C.2
> **단순성 doctrine**: [`08-simplicity-doctrine.md`](08-simplicity-doctrine.md) §3.4
> **카피 단일 진실원**: [`docs/common/copy-deck.md`](../common/copy-deck.md)
> **버전**: v1.0.0 (P2-8, 2026-05-03)
> **상태**: **제안서** — 코드 변경 0. 알고리즘·UI 카피·도입 게이트만 정의.

---

## 0. 결론 한 줄

> **한 거래에 단계별로 기여한 broker들에게 *기여도 33% 이상* 시 "이 거래 인정 마크"를 자동 부여. 보수 분배 0건. 사용자 화면에 점수·% 노출 0건. 인정 카운트만 누적.**

목표 문서 §4.3 한 줄 인용:

> **"분배 없음 → §32·§33 무관, **인정만 자동 시스템화**"**

`brokerStats.markedDealsCount` 카운트 누적이 평판 강화로 흐른다. 별도 점수·등급 X — *순수 마크 카운트*만.

**도입 게이트**: 거래 성사 누적 1,000건 + 다중 broker 거래 200건 이상 형성 후. **현재 데이터 0 — 즉시 도입 불가, N/A.**

---

## 1. WGA 모델 핵심 — 무엇을 차용하는가

### 1.1 WGA Writing Credit Determination (1941~)

영화·드라마 한 시나리오에 5~10명 작가가 거치며 누가 "Written by" 크레딧을 받을지 결정하는 75년 운영 룰. 핵심 구조:

| 차원 | WGA 룰 |
|---|---|
| **정량 임계값** | 제3 작가 이후는 *작품에 33% 이상 기여* 입증 시에만 크레딧 |
| **판정 단위** | 작품 1건 단위 (영화 1편 / 시나리오 1개) |
| **기여 측정** | 페이지·장면·캐릭터 비율 등 정량 (Statement 24시간 제출이 유일 증거) |
| **결과** | 33% 미달 → 크레딧 0 / 33% 이상 → 크레딧 부여 (분배 X, 부여 O) |
| **분쟁 절차** | 3인 익명 Arbitration Committee 위원회 판정 — 영화제작자도 *불복 불가* |
| **법적 위치** | 미국 WGA 단체협약. 영화 제작자가 양도 못하는 *권리 인정 시스템* |

### 1.2 차용할 핵심 4개

| # | WGA 요소 | MyHome 차용 |
|---|---|---|
| 1 | **33% 정량 임계값** | 한 거래의 *기여도 비중* 33% 이상 broker에게 마크 부여 |
| 2 | **분배 X 인정 O** | 보수 분배 0건. 마크 카운트만 누적 (`markedDealsCount`) |
| 3 | **거래 1건 단위 판정** | propertyId 1건 = 마크 산정 단위 (multi-broker 거래 시 0~3명 마크) |
| 4 | **알고리즘 결정 + 이의 제기** | WGA는 위원회 판정. MyHome은 *자동 알고리즘* + Task 06 이의 제기 흐름 |

### 1.3 차용하지 않는 것 (의도적)

- ❌ 익명 위원회 판정 — *사람 판단*은 시스템 강제 불가능. 자동 알고리즘으로 대체
- ❌ Statement 24시간 제출 — 별도 입력 부담 X. 시스템 *자동 로그*만 사용
- ❌ "Separated Rights" 권리 양도 불가 조항 — 한국 §32 강행규정과 무관 영역
- ❌ 단체협약 의무화 — *옵트인* 구조 유지 (§33①9호 단체결성 회피)

---

## 2. MyHome 적용 — 한 거래에 단계별 기여

### 2.1 단계 구조 (이미 보유)

| 단계 | 데이터 출처 | 보유 여부 |
|---|---|---|
| **declared** (참여 등록) | `broker_participations.participationStage='declared'` | ✅ M1.1 (Task 02) |
| **visit_scheduled** (방문 일정) | `broker_participations.participationStage='visit_scheduled'` | ✅ M2 (Task 05) |
| **offer_made** (의향서 제출) | `broker_participations.participationStage='offer_made'` | ✅ M2 (Task 05) |
| **fulfilled** (거래 성사) | `priority_grants.status='fulfilled'` | ✅ P1-4 (예정) |

**핵심**: 한 거래(propertyId)에 *여러 broker가 단계별로 기여*. 같은 broker가 여러 단계를 모두 거쳐도 OK. 다른 broker가 단계마다 다르게 진입해도 OK.

### 2.2 시나리오 예시

#### 시나리오 A — 단일 broker 거래

```
broker X: declared → visit_scheduled → offer_made → fulfilled
```

→ broker X가 100% 기여 → 마크 1개 (X에게)

#### 시나리오 B — 단계별 다른 broker

```
broker X: declared (10%)
broker Y: visit_scheduled (25%)
broker Z: offer_made (35%) + fulfilled (30%)
```

→ broker Z 65% / broker Y 25% / broker X 10%
→ 33% 임계값 통과: Z 1명만 → **마크 1개 (Z에게)**

#### 시나리오 C — 둘이 박빙

```
broker X: declared (10%) + visit_scheduled (25%) = 35%
broker Y: offer_made (35%) + fulfilled (30%) = 65%
```

→ X 35% / Y 65% → 모두 33% 통과 → **마크 2개 (X·Y 각 1개씩)**

#### 시나리오 D — 셋 모두

```
broker X: declared (10%) + offer_made (35%) = 45%
broker Y: visit_scheduled (25%)
broker Z: fulfilled (30%)
```

→ X 45% / Z 30% / Y 25% → X만 33% 통과 → **마크 1개 (X에게)**

### 2.3 마크 부여 가능 인원

거래 1건당 마크 부여 가능 인원: **0명 ~ 3명**.

- **3명 가능 이유**: 가중치 4단계 합 100% — 33% 임계값 시 최대 3명 (각 33%+α)
- **0명 시나리오**: 4단계가 4명에 분산되어 모두 33% 미만 (최대 가중치 35%지만 단일 단계만 가진 broker는 35%+ 못 넘음 — 단, 단일 단계 35%인 offer_made broker는 통과 가능 → 이 경우 1명)
- **실제로는** 1~2명 마크가 가장 많은 분포로 예상

---

## 3. 기여도 산정 알고리즘

### 3.1 단계별 가중치 4종

| 단계 | 가중치 | 사유 |
|---|---:|---|
| **declared** (참여 등록) | **10%** | 진입 의사 표명 — 가장 약한 기여 |
| **visit_scheduled** (방문 일정) | **25%** | 매수자 동원 + 시간 투자 — 중간 기여 |
| **offer_made** (의향서 제출) | **35%** | 가장 큰 단일 기여 — 매수자 의사 끌어낸 핵심 행위 |
| **fulfilled** (거래 성사) | **30%** | 최종 클로징 — 끝마무리 기여 |
| **합** | **100%** | 한 거래 분포 |

**가중치 합 = 100%** 보장 — 한 거래의 100% 분포가 broker별 비중으로 누적.

**왜 offer_made가 가장 높나**: 매수자에게 의향서 제출까지 끌어낸 것이 한국 부동산 거래에서 가장 노동 집약적 단계. WGA에서도 "스토리 라인을 처음 짠 작가"가 가장 높은 가중치를 가지는 것과 같은 논리.

### 3.2 산정 룰

```
한 propertyId의 fulfilled 시점:
  for each broker_participations 레코드 (해당 propertyId):
    contribution[brokerId] += 단계별 가중치
  + priority_grants.status='fulfilled' 의 holderBrokerId 에 fulfilled 가중치(30%) 가산

  for each broker:
    if contribution[brokerId] >= 0.33:
      → marked_credits/{id} 생성
      → brokerStats[brokerId].markedDealsCount++
```

**중요**:
- 같은 broker가 여러 단계를 거치면 *합산*. 한 broker가 declared·visit_scheduled·offer_made 모두 했으면 70% 가중치.
- *최대 비중자가 fulfilled를 영구 그대로 받음* (다중 broker는 단계가 다를 때만 합산 분리). fulfilled의 30%는 *실제 거래를 종결한 broker* 1명에게만 귀속.

### 3.3 임계값 산정 근거

**33%**: WGA 룰 그대로 차용. 변경 시 본 doctrine 위반.

> **임계값 변경 권한**: `algorithm_config/active.contributionThreshold` 외부화. 단 변경 시 영향 측정 후 룰북 v 업데이트 필수 (Task 06 §6).

---

## 4. 마크 노출 — 80세 화법 (단순성 doctrine §3.4)

### 4.1 노출 정책 3종

| 사용자 | 노출 형태 | 점수·% 노출 |
|---|---|---|
| **broker 본인 화면** | "이 거래에 도움 준 분으로 인정" 라벨 + 거래 1건 카드 | **0** |
| **매도자 화면** (거래 완료 후) | "도움 준 중개사" 섹션 — displayName + "도움" 라벨 | **0** |
| **비로그인 공개 페이지** | "이 거래는 N명의 중개사가 함께 한 거래" *집계만* | **0** |

### 4.2 카피 시안 (`copy-deck.md` 등록 대상)

#### broker 본인 화면 (broker dashboard "내 활동" 섹션)

```
┌─────────────────────────────────┐
│ 도움 준 거래                       │
│                                 │
│ 압구정동 35평 아파트                │
│ 4월 12일 거래 성사                  │
│ ✓ 도움 준 분으로 인정              │
└─────────────────────────────────┘
```

**금지**: "33%", "기여도", "Contribution Mark", "Credit"

#### 매도자 화면 (거래 완료 다이얼로그 또는 매물 결과 화면)

```
┌─────────────────────────────────┐
│ 거래가 끝났어요                     │
│                                 │
│ 도움 준 중개사:                    │
│   • 김중개 부동산   [도움]          │
│   • 압구정 중개사   [도움]          │
└─────────────────────────────────┘
```

**금지**: 점수, 비율, "1등/2등", "기여도", 백분율

#### 비로그인 공개 페이지 (선택)

```
이 매물은 2명의 중개사가 함께 한 거래입니다.
```

**금지**: 누가·얼만큼·점수 — *집계 N명*만.

### 4.3 카운트 노출

broker 프로필 (broker 본인·관리자 view):

```
도움 준 거래 누적: 12건
```

**금지**: "랭킹", "TOP 10", "% 통과", "별 5개" — *순수 카운트만*.

---

## 5. `brokerStats` 통합

### 5.1 신규 필드

```
brokerStats/{brokerId}:
  ...
  markedDealsCount: int      // 신규 — 마크 누적 카운트
  markedDealsLast90d: int    // 신규 — 최근 90일 마크 (decay 효과)
  lastMarkedAt: timestamp    // 신규 — 최근 마크 시점
```

### 5.2 별도 점수 X — 순수 카운트

마크는 **별도 점수화 안 함**. 그냥 *몇 건 인정받았는지*만 누적. 이유:

- 점수화하면 80세 doctrine §3.4 위반 (점수 노출 0건 룰)
- 단순 카운트만이 "도움 준 거래 12건"으로 자연스럽게 표현 가능
- 가중치·등급화 없음 → 알고리즘 투명성 (카카오 회피)

### 5.3 평판 강화 흐름

```
[fulfilled 거래] → [기여도 33% 통과] → [marked_credits/{id} 생성]
                                  → [brokerStats.markedDealsCount++]
                                  → [broker 프로필 노출]
```

**중요**: P2-7 (Trust Score)와 **별개 메트릭**. Trust Score는 *행동 페널티 누적* 정량점수, MarkedDeals는 *결과 인정 카운트*. 둘 다 별개로 broker 평판에 기여.

---

## 6. 데이터 흐름 — 트리거 + 신규 컬렉션

### 6.1 신규 컬렉션 `marked_credits`

```
marked_credits/{creditId}:
  propertyId: string
  brokerId: string
  contributionStages: [string]   // ['declared', 'offer_made'] 등
  thresholdPassed: bool
  createdAt: timestamp
  rulebookVersion: string
  fulfilledGrantId: string       // priority_grants 연결
```

**Firestore Rules**:
```
match /marked_credits/{creditId} {
  allow read: if isAuthenticated() && (
    request.auth.uid == resource.data.brokerId ||
    isPropertyOwner(resource.data.propertyId) ||
    isAdmin()
  );
  allow create, update, delete: if false;  // Functions만
}
```

### 6.2 트리거 흐름

```
[priority_grants/{grantId} onUpdate]
   │
   ├─ if status: pending → fulfilled
   │   │
   │   ├─ 1. propertyId 추출
   │   ├─ 2. broker_participations.where(propertyId).get() → 모든 단계 데이터
   │   ├─ 3. priority_grants.where(propertyId).where(status='fulfilled').get() → fulfilled holder
   │   ├─ 4. brokerId별 contribution 합산 (§3.1 가중치 적용)
   │   ├─ 5. for each broker if contribution >= 0.33:
   │   │     ├─ marked_credits/{id} 트랜잭션 생성
   │   │     ├─ brokerStats[brokerId].markedDealsCount++ (트랜잭션 동기)
   │   │     └─ priority_audit_logs/{id} 1:1 audit (Task 06)
   │   └─ 6. 노출은 클라이언트 stream 자동 업데이트
   │
   └─ else: skip
```

### 6.3 데이터 무결성

- **중복 방지**: `marked_credits` 복합키 `{propertyId}_{brokerId}` — 같은 거래에 같은 broker는 1마크만
- **재계산 방지**: fulfilled 트리거는 status 전이 시점에만 1회 작동. 재진입 시 멱등 (이미 존재하면 skip)
- **롤백**: 거래 취소(`status='cancelled'`) 시 `marked_credits` *유지*. WGA도 영화 흥행 실패와 무관하게 크레딧 유지. 단 거래 자체가 *무효*로 판정되면 수동 admin 삭제 가능 (이의 제기 흐름)

---

## 7. 법무 검증 — 4건 모두 무관

`docs/common/platform_commission_intervention_legal_check.md` 매트릭스 적용:

| 법령 | 무관 사유 |
|---|---|
| **§32** (중개보수 발생·귀속) | **무관** — 보수 분배 0건. 마크는 *인정 카운트*만. 의뢰인 보수 흐름 무접촉 |
| **§33①3호** (보수 초과 금품) | **무관** — 금품 수수 0건. 마크는 *시스템 기록*만. 플랫폼→중개사 자원 이동 0 |
| **§33①9호** (단체결성 공동중개 제한) | **무관** — 마크 *부여*는 자동 알고리즘. 미부여자도 매물 노출 동등. 단체화 X |
| **§33②4호** (업무방해) | **무관** — 시세 영향 0. 광고·매물 노출에 영향 없음. 마크는 거래 *결과 표시*만 |

### 7.1 약관규제법 §6 검증

마크 부여 룰 약관 명시:
- ① 분배 강제 X (§6②1호 무관)
- ② 룰북 공개 (§6②2호 — 예상 가능성 보장)
- ③ 이의 제기 절차 (§6① 신의성실 충족)
- ④ 가입 약관에 *마크 동의*를 매물 노출의 전제 X (§33①9호 + §6 회피)

### 7.2 카카오 회피 — 알고리즘 투명성

| 카카오 패턴 | MyHome 회피 |
|---|---|
| 콜택시 "특정 가맹점에 고정 우대" | **마크는 거래마다 새로 산정** — 고정 우대 패턴 X |
| 알고리즘 비공개 | **룰북 공개**: 33% 임계값·4단계 가중치 (§7 / Task 06) |
| 시장 점유 후 룰 변경 | **`algorithm_config` 버전 관리** + 변경 시 사용자 통지 |

### 7.3 §33①9호 단체결성 회피 핵심

WGA는 단체협약이지만 MyHome은 옵트인. 마크 미부여 broker도 매물 노출·거래 진입에 *제약 0*. 따라서 "단체 미가입자 차별" 구조 X → §33①9호 무관.

---

## 8. WGA 분쟁 절차 차용 — Task 06 이의 제기와 통합

### 8.1 WGA 원본

WGA는 마크 분쟁 시 **3인 익명 Arbitration Committee 위원회 판정**. 영화제작자도 불복 불가.

### 8.2 MyHome 차용 — 자동 알고리즘 + 이의 제기

자동 알고리즘이 1차 결정 → 분쟁 시 **Task 06 이의 제기 흐름**으로 처리.

| 단계 | WGA | MyHome |
|---|---|---|
| 1차 결정 | 위원회 합의 | 자동 알고리즘 (§3) |
| 1차 정보 | Statement 24h 제출 | 시스템 *자동 로그* (broker_participations·priority_grants) |
| 분쟁 시 | 위원회 재판정 | **이의 제기 흐름**: broker 또는 매도자가 *마크 결정에 이의* → admin 확인 → algorithm_config 버전 기준 *replay* → 결과 변경 시 `marked_credits` 수정 + audit log |
| 최종 결정 | 위원회 (불복 X) | admin 결정 (불복 시 한공협 등 외부 채널) |

### 8.3 이의 제기 사유 카테고리

`priority_appeals` 컬렉션에 신규 `appealType: 'marked_credit'` 추가:

| 사유 | 설명 |
|---|---|
| **단계 누락** | "내가 visit_scheduled를 했는데 기록 안 됨" |
| **단계 오기록** | "다른 broker의 활동이 내 것으로 기록됨" |
| **거래 자체 무효** | "이 거래는 실제 성사 안 됨 / 사기 거래" |
| **기타** | 자유 텍스트 + 사진 1장 (Task 06 §3.4 흐름 그대로) |

---

## 9. 도입 게이트 — 데이터 누적 후

### 9.1 게이트 조건

| 게이트 | 임계값 | 사유 |
|---|---:|---|
| **거래 성사 누적** | 1,000건 | 마크 분포 형성에 충분한 표본 |
| **다중 broker 거래** | 200건 이상 | 33% 임계값이 *의미를 가지려면* 단계가 broker별로 갈라지는 거래가 일정 수 필요 |
| **broker 활성화** | 100명+ | 마크가 *차별화*가 되려면 broker 풀 규모 필요 |

### 9.2 현재 상태 (2026-05-03)

- 거래 성사 누적: **0건**
- 다중 broker 거래: **0건**
- 활성 broker: 시드 단계

→ **게이트 미충족. 즉시 도입 X. 본 task는 *설계만*.**

### 9.3 도입 시 calibration 작업

게이트 충족 시 다음 작업:
1. 실제 데이터로 4단계 가중치 재검증 (10/25/35/30 분포가 적정한지)
2. 33% 임계값 영향 분석 (마크 부여 broker 분포가 *너무 적으면* 의미 X / *너무 많으면* 차별화 X)
3. 데이터 분포 형성 후 `algorithm_config` 외부화 적용 (`contributionWeights`·`contributionThreshold`)
4. UI 카피 시안 사용성 테스트 (60대+ 3명 — Task 08 §5.3)

---

## 10. 도입 시 체크리스트 (게이트 충족 후 작성)

### 10.1 데이터 모델
- [ ] `marked_credits/{creditId}` 컬렉션 신설
- [ ] `marked_credits` Firestore Rules (`Functions만`)
- [ ] `brokerStats.markedDealsCount`·`markedDealsLast90d`·`lastMarkedAt` 필드 추가
- [ ] 복합키 `{propertyId}_{brokerId}` 멱등성 인덱스
- [ ] `priority_appeals.appealType='marked_credit'` 추가

### 10.2 알고리즘
- [ ] `algorithm_config/active`에 `contributionWeights` (10/25/35/30) + `contributionThreshold` (0.33) 추가
- [ ] Cloud Function `onPriorityGrantFulfilled` 트리거 — fulfilled 시점 마크 산정
- [ ] 트랜잭션: `marked_credits` 생성 + `brokerStats` 동기 + `priority_audit_logs` 1:1
- [ ] 멱등성: 이미 마크 존재 시 skip
- [ ] 룰북 v 업데이트 (Task 06 §6.1)

### 10.3 UI (단순성 doctrine §3.4 절대 준수)
- [ ] broker dashboard "도움 준 거래" 섹션 (점수·% 노출 0)
- [ ] 매도자 거래 완료 화면 "도움 준 중개사" 섹션 (displayName + "도움" 라벨만)
- [ ] 비로그인 공개 페이지 *집계 N명*만 (선택)
- [ ] 카피 `copy-deck.md` 등록 (화면별 파편화 금지)
- [ ] 80세 가상 인터뷰 6개 질문 답변 (Task 08 §5.1)

### 10.4 이의 제기
- [ ] `priority_appeals` UI에 marked_credit 사유 카테고리 추가
- [ ] admin 화면 마크 결정 *replay* 기능
- [ ] replay 결과 변경 시 marked_credits 수정 + audit log

### 10.5 검증
- [ ] 단일 broker 거래 시나리오 (시나리오 A) — 마크 1개
- [ ] 단계별 다른 broker 시나리오 (B) — 마크 1개
- [ ] 박빙 시나리오 (C) — 마크 2개
- [ ] 셋 분산 시나리오 (D) — 마크 1개
- [ ] 0명 시나리오 (모두 33% 미만) — 마크 0개
- [ ] 거래 취소 시 마크 *유지* (관리자 수동 개입 가능)

---

## 11. 절대 지켜라 (재확인)

- ❌ **보수 분배·차감 0** — `marked_credits`는 *인정 마크*만. 의뢰인 보수 흐름 무접촉
- ❌ **사용자 노출 점수·% 0** — Doctrine §3.4 위반 시 PR 거절
- ❌ **즉시 도입 권고 X** — 게이트 (1,000 + 200 + 100명) 충족 후만
- ❌ **코드 변경 0** — 본 task는 *설계 문서만*
- ❌ **고정 우대 패턴 X** — 거래마다 새로 산정 (카카오 회피)
- ❌ **단체화 X** — 마크 미부여자도 매물 노출 동등 (§33①9호 회피)

---

## 12. 미해결 의문점

1. **단계 시간순 vs 단계 종류 가중치** — 현 설계는 *단계 종류별* 가중치만 본다. 시간순 (먼저 진입한 broker가 더 높은 가중)을 추가할지 데이터 누적 후 결정.
2. **거래 취소 시 마크 처리 정책** — 현 설계는 *유지*. WGA는 흥행 실패와 무관하게 크레딧 유지. 그러나 *사기 거래 확정* 시 마크 박탈 룰을 명문화할지 — 도입 시 결정.
3. **마크 90일 decay vs 영구** — `markedDealsCount`는 영구, `markedDealsLast90d`는 시간 가중. 둘 중 어느 것을 broker 평판 노출에 쓸지 — 도입 시 사용성 테스트.
4. **다중 매물 동일 broker 누적** — 한 broker가 여러 매물에서 마크 받은 경우 단순 합산 vs 다양성 가중 — 게이트 후 분포 보고 결정.
5. **공개 페이지 집계 노출 범위** — "N명의 중개사가 함께 한 거래" 표시 여부는 *매도자 옵션*인지 *플랫폼 자동*인지 — Task 07 자율 지정과 정합성 검토 필요.

---

## 13. 참조

### 13.1 본 프로젝트 문서

- [`docs/goal/multi_agent_competition_solutions_cross_industry.md`](../goal/multi_agent_competition_solutions_cross_industry.md) §4.3
- [`docs/common/cross_industry_anti_poaching_complete_catalog.md`](../common/cross_industry_anti_poaching_complete_catalog.md) §C.2
- [`docs/common/platform_commission_intervention_legal_check.md`](../common/platform_commission_intervention_legal_check.md)
- [`08-simplicity-doctrine.md`](08-simplicity-doctrine.md) §3.4
- [`p2-7-trust-score-proposal.md`](p2-7-trust-score-proposal.md) — 자매 후행 task

### 13.2 외부 1차 자료

- [WGA Screen Credits Manual](https://www.wga.org/contracts/credits/manuals/screen-credits-manual)
- [WGA Screenwriting Credit System — Wikipedia](https://en.wikipedia.org/wiki/WGA_screenwriting_credit_system)
- [WGAE Separated Rights](https://www.wgaeast.org/know-your-rights/separated-rights/)
- [BHBA WGA Credit Allocation](https://bhba.org/modernlawyer-posts/the-basics-of-wga-credit-allocation-and-arbitration/)

### 13.3 법령 (회피 대상)

- [공인중개사법 §32](https://casenote.kr/%EB%B2%95%EB%A0%B9/%EA%B3%B5%EC%9D%B8%EC%A4%91%EA%B0%9C%EC%82%AC%EB%B2%95/%EC%A0%9C32%EC%A1%B0)
- [공인중개사법 §33](https://casenote.kr/%EB%B2%95%EB%A0%B9/%EA%B3%B5%EC%9D%B8%EC%A4%91%EA%B0%9C%EC%82%AC%EB%B2%95/%EC%A0%9C33%EC%A1%B0)
- [약관의 규제에 관한 법률 §6](https://casenote.kr/%EB%B2%95%EB%A0%B9/%EC%95%BD%EA%B4%80%EC%9D%98_%EA%B7%9C%EC%A0%9C%EC%97%90_%EA%B4%80%ED%95%9C_%EB%B2%95%EB%A5%A0/%EC%A0%9C6%EC%A1%B0)

---

## 14. 한 줄 정의

> **MyHome P2-8 = WGA 33% 룰을 *보수 분배 없이 인정 카운트만*으로 차용. 자동 알고리즘이 거래 1건의 4단계 기여도(10/25/35/30)를 산정해 33% 이상 broker에게 마크 부여. 사용자 화면엔 점수 0건. 데이터 1,000건 후 도입.**
