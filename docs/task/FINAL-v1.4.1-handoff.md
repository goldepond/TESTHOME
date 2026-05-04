# MyHome v1.4.1 — 최종 핸드오프

> **상태**: 코드 작업 100% 완료 / 운영 게이트 통과 시 정식 출시
> **작성**: 2026-05-03 (총괄 책임자 / Sr. Architect)
> **상위 목표**: [`../goal/multi_agent_competition_solutions_cross_industry.md`](../goal/multi_agent_competition_solutions_cross_industry.md)
> **단순성 헌장**: [`08-simplicity-doctrine.md`](08-simplicity-doctrine.md) (80세 노인 테스트 — 모든 PR 횡단 게이트)

---

## 0. 한 줄 정의

> **MyHome v1.4.1 = "한국 부동산에 부재했던 *시간기록 기반 우선권 시스템*을 코드로 강제하는 첫 플랫폼 — 80세 노인도 따라 할 수 있는 단순함으로."**

---

## 1. v1.2.1 → v1.4.1 변경 요약 (8 task + 3 라운드)

### 1.1 Task 01~08 (MVP 핵심)

| # | Task | 핵심 산출물 |
|---|---|---|
| [01](01-data-model.md) | Firestore 데이터 모델 — 5 컬렉션 신설 | `priority_grants` / `priority_appeals` / `broker_participations` / `broker_eligibility` / `audit_log` |
| [02](02-m1-seller-broker.md) | M1.1 매도자-중개사 선등록 우선권 | 자격필터(§32·§33) + 80% 활동 룰 + 5개 동시 한도 + Dynamic Matching |
| [03](03-m1-buyer-broker.md) | M1.2 매수자-중개사 매물별 매칭 | `buyer_match` grant + 매물별 1:1 우선권 |
| [04](04-tiered-release.md) | 단계 노출 (1km→동→인접동→광역) | GeoHash precision 7 / 활성 grant 시 단계 정지 |
| [05](05-m2-disclosure.md) | M2 시간기록 공개 — `broker_participations` 가시화 | 매도자/공개 비식별 view (P1-5 publicView 트리거) |
| [06](06-transparency.md) | 알고리즘 투명성 — 룰북·이의제기·점유율 | `/rulebook` v1.5.0 + `priority_appeals` + 점유율 텔레메트리 |
| [07](07-seller-autonomy.md) | 매도자 자율 단독 지정 (`listingMode`) | exclusive 모드 + 모드 전환 다이얼로그 + 이력 |
| [08](08-simplicity-doctrine.md) | **단순성 원칙 — 80세 노인 테스트** (횡단 게이트) | [`copy-deck.md`](../common/copy-deck.md) + [`simplicity-checklist.md`](../common/simplicity-checklist.md) + [`PRIORITY_RULEBOOK.md`](../public/PRIORITY_RULEBOOK.md) |

### 1.2 라운드 2 — 21 sub-task (운영 강화)

P0 (5): seed runbook · region runbook · participations backfill runbook · copy doctrine gate · audit copy-deck
P1 (12): activity score trigger · grant fulfillment · publicView 트리거 · MLS property model fields · platform alert webhook · appeal resolution push · appeal listing-mode 통합 · listing-mode history · priority-holder seller guard · 외 3건
P2 (5): material vs doctrine matrix · simplicity i18n · scoring failure human copy · admin district chart · brokerStats counters

### 1.3 라운드 3 — 10 sub-task (보안·UI 마감)

| Sub-task | 내용 | 상태 |
|---|---|:---:|
| P0-8 | mls_property_service 레거시 `targetBrokerIds` 쿼리 → `priority_grants` 기반 교체 (3 메서드) | ✅ |
| P0-9 | `bulkVerifyBrokerEligibility` callable 신설 (admin-only) | ✅ |
| P0-10 | region 정합성 분석 → 옵션 A 권고 (v1.5 phase) | ✅ |
| P0-11 | `broker_participations` publicView 백필 스크립트 | ✅ |
| P0-12 | `release_tier_badge` raw 카피 → `GrantMessages.tierExclusiveBadgeLabel` | ✅ |
| P1-19 | `notifications` Rules `__admin__` 폴백 토큰 | ✅ |
| P1-20 | 매도자 fulfillment 모델·서비스·카피 + `fulfillGrantViaFunction` | ✅ |
| P1-20.1 | **매도자 dashboard `_buildFulfillmentAction` UI** (round 3E) | ✅ |
| P1-21 | 이의 카테고리 라디오 모델·카피 (P1-12에서 통합 완료) | ✅ |
| P1-21.1 | **broker `priority_appeal_page.dart` 신설 + 카테고리 라디오** (round 3D) | ✅ |
| P1-22 | `brokerStats` Rules write `if false` (admin SDK only) | ✅ |
| P1-23 | functions 단위 테스트 인프라 + scoring 테스트 1건 | ✅ |

---

## 2. 최종 코드 인벤토리

### 2.1 Firestore 보안

- [`firestore.rules`](../../firestore.rules) — 33 컬렉션 / 496줄
- [`firestore.indexes.json`](../../firestore.indexes.json) — 25 복합 인덱스

### 2.2 Cloud Functions

- [`functions/index.js`](../../functions/index.js) — 6,317줄 / **33 exports**
- 핵심: `issuePriorityGrant` · `fulfillGrant` · `revokeOwnGrant` · `resolveAppeal` · `bulkVerifyBrokerEligibility` · `onPriorityAppealCreated` · `onContractCreated` · `proxy` · `sendPushNotification` 외 24
- 단위 테스트: [`test/functions_unit/`](../../test/functions_unit/) (P1-23 기반)

### 2.3 Flutter 클라이언트 핵심

| 영역 | 파일 |
|---|---|
| 모델 | [`priority_grant.dart`](../../lib/models/priority_grant.dart) · [`priority_appeal.dart`](../../lib/models/priority_appeal.dart) · [`broker_participation.dart`](../../lib/models/broker_participation.dart) · [`mls_property.dart`](../../lib/models/mls_property.dart) |
| 서비스 | [`priority_grant_service.dart`](../../lib/api_request/priority_grant_service.dart) · [`priority_appeal_service.dart`](../../lib/api_request/priority_appeal_service.dart) · [`mls_property_service.dart`](../../lib/api_request/mls_property_service.dart) · [`priority_audit_log_service.dart`](../../lib/api_request/priority_audit_log_service.dart) |
| 매도자 | [`mls_seller_dashboard_page.dart`](../../lib/screens/seller/mls_seller_dashboard_page.dart) (fulfillment 버튼 포함) · [`mls_property_detail_page.dart`](../../lib/screens/seller/mls_property_detail_page.dart) · [`mls_property_registration_page.dart`](../../lib/screens/seller/mls_property_registration_page.dart) |
| 중개사 | [`mls_broker_dashboard_page.dart`](../../lib/screens/broker/mls_broker_dashboard_page.dart) · [`priority_appeal_page.dart`](../../lib/screens/broker/priority_appeal_page.dart) (P1-21.1) |
| 관리자 | [`admin_appeals_page.dart`](../../lib/screens/admin/admin_appeals_page.dart) · [`admin_dashboard.dart`](../../lib/screens/admin/admin_dashboard.dart) |
| 카피 | [`grant_messages.dart`](../../lib/constants/grant_messages.dart) — 740+줄, 모든 사용자 노출 문구 단일 진실원 |

### 2.4 거버넌스 인프라 (Task 08 산출물)

- 카피 단일 진실원: [`../common/copy-deck.md`](../common/copy-deck.md) — 영역별 카피 + 사유 코드 26종 + audit eventType 17종
- PR 자가 점검: [`../common/simplicity-checklist.md`](../common/simplicity-checklist.md) — 21 항목 + 80세 가상 인터뷰 6 질문
- 공개 룰북: [`../public/PRIORITY_RULEBOOK.md`](../public/PRIORITY_RULEBOOK.md) — `/rulebook` v1.5.0
- 운영 검증: [`usability-test-protocol.md`](usability-test-protocol.md) — 60대 시연 가이드 (운영 phase 사용 중)

---

## 3. 출시 게이트 — 운영팀 작업 (코드 작업 0건 잔여)

| # | 작업 | 자료 |
|---|---|---|
| **P0-7** | 60대 비전문가 3명 시연 — 등록·이의·우선권 흐름 검증 | [`usability-test-protocol.md`](usability-test-protocol.md) |
| P0-1 | broker_eligibility 초기 시드 (공인중개사 명부) | runbook 기반 |
| P0-2 | 기존 매물 데이터 마이그레이션 | runbook 기반 |
| P0-4 | priority_grants 백필 (활성 매물 대상) | runbook 기반 |
| P0-5 | region 정합성 패치 (시군구 + 동) | runbook 기반 |
| P0-6 | broker_participations 백필 (publicView 포함) | [`tools/backfill_broker_participations_public.js`](../../tools/backfill_broker_participations_public.js) |

> **참고**: P0-1~P0-6 runbook 본문은 마이그레이션 phase 종료 후 보관용 별도 저장소로 이전됨. 코드 진입점은 [`functions/index.js`](../../functions/index.js) 의 admin-only callable 와 [`tools/`](../../tools/) 백필 스크립트.

---

## 4. 운영 배포 절차

```bash
# 1. Firestore Rules + Indexes
firebase deploy --only firestore

# 2. Cloud Functions (Node 20)
cd functions && npm install && npm run deploy && cd ..

# 3. publicView 트리거 안정화 후 백필 1회 (--dry → 검토 → 실 실행)
GOOGLE_APPLICATION_CREDENTIALS=./functions/<key>.json \
  node tools/backfill_broker_participations_public.js --dry

# 4. 메인 웹 빌드 + 배포
flutter build web --release \
  --dart-define=JUSO_API_KEY=xxx \
  --dart-define=DATA_GO_KR_SERVICE_KEY=yyy
firebase deploy --only hosting:main

# 5. 관리자 콘솔 빌드 + 배포 (별도 바이너리)
flutter build web --release \
  --target=lib/main_admin.dart \
  --output=build/web_admin
firebase deploy --only hosting:admin

# 6. P0-1 admin 일괄 면허 검증 (Cloud Functions shell)
firebase functions:shell
> bulkVerifyBrokerEligibility({ all: true })
```

---

## 5. 횡단 설계 원칙 (모든 후속 PR 자가 점검)

| 원칙 | 의미 | 점검 |
|---|---|---|
| **80세 노인 테스트 (P0)** | 모든 화면·문구·결정이 80세 노인이 이해 가능 | [`simplicity-checklist.md`](../common/simplicity-checklist.md) 100% 통과 없이 PR 거절 |
| **Code-level Enforcement** | 약관·자율약정 금지. Firestore Rules + Cloud Functions로 강제 | Rules 패치 없는 PR 금지 |
| **Dynamic Matching** | 단순 시간 외 다중 변수 (지역·면허·활동률) 가중 — *내부* 산정만, 사용자에겐 단순 표현 | UI엔 가중치·점수 *절대 노출 금지* |
| **Use-it-or-Lose-it** | 활동 80% 미달 시 자동 만료 | scheduled function 필수 |
| **Threshold Recognition** | 분배·크레딧 X. *마크·인정만* | 보수 분배 코드 절대 금지 |
| **§32·§33 무관성** | 보수 분배·차감 코드 금지 | 모든 PR 법무 자가 점검 표 첨부 |
| **카카오 회피** | 점유율 30% 도달 시 외부 감사 | 점유율 텔레메트리 (06) |
| **3-레이어 카피 동기** | functions REASON ↔ grant_messages reasonCopy ↔ copy-deck §3 | 새 audit eventType 추가 시 3 레이어 모두 동기화 |

### 절대 금지 패턴 (PR 거절 사유)

1. 약관·UI 안내문으로만 강제 — Firestore Rules 또는 Cloud Functions 강제 없으면 무효
2. 보수에 손대는 어떤 코드 (`commission`, `fee_share`, `payout_split` 신설 금지)
3. `targetBrokerIds` 직접 변형으로 우선권 표현 — 우선권은 별도 `priority_grants` 컬렉션
4. 선착순 단일 변수만으로 우선권 부여 — Dynamic Matching 위반 (카카오 패턴)
5. 이의 제기 채널 없는 자동 결정
6. 테스트 케이스 없는 만료 로직 — Use-it-or-Lose-it 시간 시뮬레이션 필수
7. 80세 노인이 이해 못 하는 화면·문구 (점수·가중치·복잡 용어 노출, 한 화면 의사결정 ≥3개, 한 줄에 안 들어가는 알림)

---

## 6. 후속 phase 백로그 (v1.5+)

### 6.1 분석 완료 — 구현 phase 대기

- [`p0-10-region-definition-analysis.md`](p0-10-region-definition-analysis.md) — region 시군구·동 정합 (옵션 A: `dong` 필드 추가)
- [`p1-7-broker-batch-get-analysis.md`](p1-7-broker-batch-get-analysis.md) — N+1 0 issues 확인 완료
- [`p1-14-geohash-precision-analysis.md`](p1-14-geohash-precision-analysis.md) — precision 7 retain 권고

### 6.2 제안 — 우선순위 결정 대기

- [`p2-7-trust-score-proposal.md`](p2-7-trust-score-proposal.md) — 중개사 신뢰 점수 (브로커 카테고리화 UI 결합)
- [`p2-8-contribution-recognition-proposal.md`](p2-8-contribution-recognition-proposal.md) — WGA 33% 기여 인정 패턴

### 6.3 운영 데이터 누적 후 검토

- 32 functions 풀 단위 테스트 커버리지 확장 (P1-23 인프라 기반)
- brokerStats 카테고리화 UI (P2-7 패턴 적용)
- functions tier2·tier3 매칭 단위 변경 (P0-10 옵션 A 적용 시)

---

## 7. 다음 세션 진입 가이드

```
다음 세션:
"60대 시연 결과 보고" 또는 "v1.5 백로그 phase 진입"

총괄 책임자(나)는 본 문서 §3 게이트 통과 결과 / §6 백로그 우선순위에 따라
sub-agent 디스패치 또는 직접 작업으로 처리한다.

단, 다음 phase에서도 §5 횡단 원칙 100% 보존 의무는 동일.
```

---

## 8. 정리 변경 이력

본 문서는 다음을 통합한 *최종* 단일 진입점이다:

- `MASTER-v1.3-mvp-handoff.md` (Task 01~08 통합)
- `MASTER-v2-round2-complete-handoff.md` (라운드 2 21 sub-task)
- `MASTER-v3-round3-complete-handoff.md` (라운드 3 10 sub-task)

위 3개 마스터 + 38개 개별 task 핸드오프 + `docs/test/` 폴더 7개 테스트 명세는 본 문서로 갈음·정리 완료 (2026-05-03).

---

**작성**: 총괄 책임자 (Sr. Architect)
**상태**: 코드 작업 100% 완료 / 운영 게이트 통과 시 v1.4.1 정식 출시
**다음 핸드오프 트리거**: 60대 시연 결과 + 운영 마이그 결과 수령 시점
