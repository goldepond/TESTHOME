# Copy Deck — 80세 노인 테스트 통과 카피 단일 진실원

> **상위 문서**: [../task/08-simplicity-doctrine.md](../task/08-simplicity-doctrine.md)
> **버전**: v1.0.0 (Task 08 도입, 2026-05-03)
> **유지 책임**: 모든 PR 작성자는 *신규 사용자 노출 카피를 본 문서에 등록*해야 한다. 화면별 파편화 금지.
> **구현 거울**: [lib/constants/grant_messages.dart](../../lib/constants/grant_messages.dart) — 본 문서와 1:1 대응. 코드 변경 시 본 문서 동시 업데이트.

---

## 0. 사용 규칙

1. **이 문서는 사용자 노출 카피만 다룬다.** 운영자 화면(admin) 카피는 §6 별도 처리.
2. **신규 화면·새 기능을 추가할 때**: 사용자 노출 라벨/문구를 본 문서에 먼저 등록 → `GrantMessages` 상수로 추가 → 화면에서 *상수만 참조*. 화면에 raw 문자열 박지 말 것.
3. **수정할 때**: 본 문서를 우선 갱신. 코드 변경은 그 다음. PR 본문에 본 문서 갱신 라인을 첨부.
4. **금지**: 같은 동작에 화면마다 다른 단어 ("등록"/"올리기"/"신청") — 본 문서 §1.3 통일 라벨 표 강제.

---

## 1. 핵심 원칙 (요약 — 자세한 사항은 [08-simplicity-doctrine.md](../task/08-simplicity-doctrine.md))

### 1.1 금지 단어 → 대체 단어 (필수)

| 금지 단어 | 사유 | 대체 단어 |
|---|---|---|
| 우선권, 권리, grant | 법률 용어 같음 | "내 차례", "맡은 매물" |
| 가중치, 점수, score | 게임 같음 | (UI에 노출 *절대* 금지) |
| 자격 필터, eligibility | 한자 사전 필요 | "이 동네에서 일하는 중개사" |
| Tier, 단계, 계층 | 영어 직역체 | "오늘", "이번 주", "다음 주", 또는 [tierProgressCopy](../../lib/constants/grant_messages.dart) 사용 |
| 유효기간, 만료 | 보험 약관체 | "남은 날: 12일", "오늘이 마지막" |
| 매칭, matching | 외래어 | "연결", "맡기" |
| 인콰이어리, inquiry | 외래어 | "문의" |
| 활동률 80% | 백분율 추상 | "남은 일: 임장 1번" |
| 시간기록 | 한자 합성 | "○○월 ○○일 ○○시 시작" |
| 단독 매물 | 정확하나 모호 | "단독 지정 받은 매물" |

### 1.2 한 화면 = 한 결정

- 의사결정 ≤2개. 라디오·토글·드롭다운이 한 화면에 5개 이상 금지.
- 작은 (?) 도움말 아이콘 금지. 핵심 정보는 본문에.

### 1.3 통일 라벨 (같은 동작에 같은 단어)

| 동작 | 통일 라벨 | 어긋남 (금지) |
|---|---|---|
| 매물 게시 | **올리기** 또는 **매물 등록** | 신청, 제출 |
| 매도자 측 우선권 받기 | **이 매물 받기** | 참여 등록, 수락 |
| 매도자 측 우선권 놓기 | **이 매물 놓기** | 취소, 해제, 포기 |
| 임장 신청 (매수자) | **임장 신청하기** | 방문 신청, 보러 가기 |
| 담당 중개사 결정 (매수자) | **담당 중개사 선택** | 매칭, 연결 |
| 담당 중개사 변경 (매수자) | **담당 중개사 바꾸기** | 변경, 교체 |
| 이의 제기 | **이상해요 (이의 제기)** | 항의, 컴플레인 |
| 매물 모드 변경 (매도자) | **매물 모드 바꾸기** | 변경, 전환 |
| 단독 지정 (매도자) | **특정 중개사 1~3명 단독 지정** | 독점, exclusive, 전속 |

### 1.4 알림 ≤30자 / 흐름 ≤3 탭 / 백분율·점수·코드 0건

- 푸시·인앱 알림은 **한 줄, 30자 이내**.
- 어떤 작업도 **3 탭 이내** 완료. "더 보기" 안에 핵심 기능 숨기지 말 것.
- 백분율(%) UI 노출 *절대 금지*. 점수·가중치 *절대 금지*. 사유 코드 *절대 노출 금지*.

### 1.5 색상·아이콘

- 신호등 3색(빨/주/녹)만 상태 신호. 다른 색은 장식.
- 아이콘은 **글씨와 함께만**. 아이콘 단독으로 의미 전달 금지.
- WCAG AA — `AirbnbColors.textLight` 단독으로 핵심 정보 표시 금지.

### 1.6 에러 메시지 = 원인 + 해결법

- "Network error: 503" ❌ → "지금 인터넷이 약해요. 잠시 후 다시 해보세요" ✅
- 모든 사유 코드는 [grant_messages.dart::reasonCopy](../../lib/constants/grant_messages.dart) 한 줄 한국어로 변환.

---

## 2. 통합 카피 (영역별 단일 진실원)

> 모든 카피는 [lib/constants/grant_messages.dart](../../lib/constants/grant_messages.dart) 의 상수로 노출. 본 표는 *원본 문구 + 사용처* 기록.

### 2.1 매도자 (Seller)

| 상수명 | 카피 | 사용처 |
|---|---|---|
| `actionTakeProperty` | 이 매물 받기 | 중개사 카드 (매도자 측 매물) |
| `actionReleaseHold` | 이 매물 놓기 | 중개사 카드 (이미 받은 매물) |
| `sellerSellerSideHolderTitle` | 매도 측 우선 중개사 | 매도자 대시보드 카드 |
| `sellerBuyerSideHolderTitle` | 매수 측 담당 중개사 | 매도자 대시보드 카드 |
| `sellerHolderSectionTitle` | 이 매물을 맡고 있는 분 | 매도자 카드 섹션 |
| `sellerHolderSectionEmpty` | 아직 맡은 분이 없어요 | 빈 상태 |
| `sellerActivityRemainingParticipation` | 남은 일: 임장 1건 | 활동 잔여 |
| `sellerActivityRemainingVisit` | 남은 일: 매수 손님 1명 만나기 | 활동 잔여 |
| `sellerActivityRemainingOffer` | 남은 일: 의향서 진행 | 활동 잔여 |
| `sellerAutoExpireNotice` | 7일 동안 약속한 일을 못 마치면 다른 중개사에게 기회가 갑니다 | 활동 만료 안내 |
| `sellerExclusiveSelectedTitle` | 내가 직접 지정한 중개사 | 단독 지정 매물 카드 |
| `sellerExclusiveCountSuffix` | 명 단독 지정 | 카드 표기 |

### 2.2 중개사 (Broker)

| 상수명 | 카피 | 사용처 |
|---|---|---|
| `actionTakeProperty` | 이 매물 받기 | 매물 카드 |
| `actionTakeAtCap` | 하나 놓고 받기 | 5개 한도 다이얼로그 |
| `actionReleaseHold` | 이 매물 놓기 | 받은 매물 카드 |
| `badgeMineActive` | 내 차례 | 뱃지 (받은 상태) |
| `badgeOtherActive` | 다른 분이 맡는 중 | 뱃지 |
| `badgeOpen` | 받을 수 있어요 | 뱃지 |
| `badgeNotEligible` | 받을 수 없어요 | 뱃지 |
| `capDialogTitle` | 이미 5개 매물을 맡고 있어요 | 한도 다이얼로그 |
| `capDialogBody` | 어떤 매물을 놓을까요? | 한도 다이얼로그 |
| `capDialogCooldownNotice` | 한 번 놓으면 같은 매물은 24시간 동안 다시 받을 수 없어요 | 한도 다이얼로그 |
| `issuedSuccess` | 받았어요. 14일 동안 내 차례입니다 | 성공 SnackBar |
| `revokeSuccess` | 놓았어요 | 성공 SnackBar |
| **★ Task 08 신설** | | |
| `brokerTabBuyerLeads` | 매수 손님 | 대시보드 탭 라벨 (구 "매수자 매칭") |
| `brokerBuyerLeadsEmpty` | 아직 연결된 매수 손님이 없어요 | 매수 손님 탭 빈 상태 |
| `brokerNotificationGrantIssuedSuffix` | 내 차례 받음 | 알림 ListTile suffix (구 "우선권 부여됨") |
| `appealSelectGrantPrompt` | 어느 매물 차례에 대해 신청할지 골라주세요 | 이의 제기 입력 가드 |
| `appealNoEligibleGrants` | 지금 신청할 수 있는 맡은 매물이 없어요 | 이의 제기 빈 상태 |
| `appealTargetLabel` | 신청할 매물 | 이의 제기 드롭다운 라벨 |
| **★ Task 08 §5.4 #29 신설** | | |
| `holderBadgeForBrokerView` | 현재 맡은 분이 있어요 | `priority_holder_section.dart` broker 시야 (담당이 본인이 아닐 때 — copy-deck §5 정책상 "우선권" 단어 금지 대체) |

### 2.3 매수자 (Buyer)

| 상수명 | 카피 | 사용처 |
|---|---|---|
| `actionVisitProperty` | 임장 신청하기 | 매수자 매물 상세 |
| `actionPickBroker` | 담당 중개사 선택 | 임장 흐름 |
| `actionSwitchBroker` | 담당 중개사 바꾸기 | 임장 흐름 |
| `buyerPickerTitle` | 어느 중개사를 통해 임장하시겠습니까? | 다이얼로그 제목 |
| `buyerPickerHelp` | 한 번 정하면 24시간 동안 같은 매물에서 다른 중개사로 바꿀 수 없어요 | 다이얼로그 안내 |
| `buyerSwitchConfirmTitle` | 담당 중개사를 바꾸시겠어요? | 확인 다이얼로그 |
| `buyerSwitchConfirmBody` | 지금 담당 중개사를 그만두고 다른 분에게 다시 부탁하는 거예요. 한 번 바꾸면 24시간 뒤에야 또 바꿀 수 있어요 | 확인 다이얼로그 |
| `buyerMatchSuccess` | 담당 중개사가 정해졌어요 | 성공 SnackBar |
| `buyerMatchSwitched` | 담당 중개사를 바꿨어요 | 성공 SnackBar |
| `buyerMatchEmpty` | 아직 정한 담당 중개사가 없어요 | 빈 상태 |

### 2.4 매물 모드 (Listing Mode — Open / Exclusive)

| 상수명 | 카피 | 사용처 |
|---|---|---|
| `listingModeSectionTitle` | 어떤 분이 매물을 봐주실까요? | 등록 화면 섹션 제목 |
| `listingModeOpenLabel` | 모든 중개사 공개 (권장) | 라디오 옵션 |
| `listingModeExclusiveLabel` | 특정 중개사 1~3명 단독 지정 | 라디오 옵션 |
| `exclusiveSelfAttestationLabel` | 이 지정은 내 자율 선택이며 MyHome은 추천하지 않았음을 확인합니다 | 자율 동의 체크박스 (법무 라인) |
| `exclusiveOnlyVerifiedNotice` | 면허 확인이 끝난 중개사만 보여드려요. 자율 선택을 위해 추천 순서가 아닌 가나다 순입니다 | 검색 모달 안내 |
| `listingExclusiveBadge` | 단독 지정 | 카드 뱃지 |
| `listingExclusiveSellerSelectedNotice` | 이 매물은 매도자가 직접 단독 중개사를 지정한 매물입니다. 참여 등록은 받지 않습니다 | 비지정 중개사 안내 |
| `listingExclusiveBuyerNeutralNotice` | 이 매물은 매도자 측이 단독 중개사와 함께 진행 중입니다. 매수 문의는 평소처럼 가능합니다 | 매수자/비로그인 안내 |
| `listingExclusiveAssignedBadge` | 단독 지정 받은 매물 | 지정 중개사 카드 |
| `listingModeChangeMenuTitle` | 매물 모드 바꾸기 | 매도자 대시보드 |
| `listingModeChanged` | 매물 모드를 바꿨어요 | 성공 SnackBar |
| **★ P1-11 신설 — 운영자→사용자 통지 (operator-to-user-copy-gate.md §3 7원칙 통과)** | | |
| `adminOverrideListingModeNotificationTitle` | 관리자가 매물 모드를 변경했어요 | `adminOverrideListingMode` callable 매도자 푸시·인앱 알림 제목 |
| `adminOverrideListingModeNotificationBodyTemplate` | {prev} → {next} (분쟁 사유 함께) | 매도자 푸시·인앱 알림 본문 템플릿 (`buildAdminOverrideListingModeBody` 헬퍼로 한국어 모드 라벨 치환). 30자 한도 통과. "분쟁 사유 함께" 표현으로 *MyHome 의지 개입* 인상 차단 — 사유 본문은 별도 필드(`overrideReason`) |

### 2.5 단계 노출 (Tiered Release)

| 상수명 | 카피 | 사용처 |
|---|---|---|
| `tierBadgeT1` | 1km 신규 | 뱃지 |
| `tierBadgeT2` | 같은 동 | 뱃지 |
| `tierBadgeT3` | 인접 동 | 뱃지 |
| `tierBadgeT4` | 시·군 전체 | 뱃지 (구 "시군구" — 한자어 회피, 80세 화법) |
| `tierProgressT1` | 오늘은 우리 동네 중개사들이 봅니다 | 매도자 진행 안내 |
| `tierProgressT2` | 이제 같은 동 중개사들도 봅니다 | 매도자 진행 안내 |
| `tierProgressT3` | 인접 동까지 확대됐습니다 | 매도자 진행 안내 |
| `tierProgressT4` | 시·군 전체에 공개됐습니다 | 매도자 진행 안내 (구 "시군구 전체" — 한자어 회피) |
| `tierExclusiveLabel` | 단독으로 맡긴 매물이라 단계 확대를 하지 않습니다 | 매도자 진행 안내 |
| `tierExclusiveBadgeLabel` | 단독 매물 | release_tier_badge.dart 카드 짧은 라벨 (P0-12 raw 교체) |
| `tierPausedByGrant` | 담당 중개사가 활동 중이라 단계 확대를 잠시 멈췄어요 | 매도자 진행 안내 |
| `tierNotifTitle` | 신규 매물 알림 | 푸시 알림 제목 |

### 2.6 시간기록 / 참여 (Disclosure / Participation)

| 상수명 | 카피 | 사용처 |
|---|---|---|
| `participationTimelineTitle` | 중개사 활동 기록 | 매도자 대시보드 섹션 |
| `participationStageDeclared` | 참여 등록 | 단계 라벨 |
| `participationStageVisitScheduled` | 임장 예정 | 단계 라벨 |
| `participationStageOfferMade` | 의향서 제출 | 단계 라벨 |
| `participationHolderBadge` | 현재 우선권 보유 | 보유자 강조 (※ "우선권" 단어는 *유일한 예외* — 매도자에게 사실 전달 필수, 매수자/중개사 화면 노출 금지) |
| `participationEmptyState` | 아직 참여한 중개사가 없습니다 | 빈 상태 |
| `participationPublicCountSuffix` | 명의 중개사가 참여 중 | 비로그인 공개 페이지 |

### 2.7 이의 제기 (Appeals)

| 상수명 | 카피 | 사용처 |
|---|---|---|
| `appealMenuTitle` | 이상해요 (이의 제기) | 진입 메뉴 |
| `appealFormTitle` | 결과가 이상한 이유를 알려주세요 | 폼 제목 |
| `appealReasonHint` | 어떤 점이 이상한지 자유롭게 적어주세요. (최대 1000자) | 입력 힌트 |
| `appealSubmit` | 제출하기 | 버튼 |
| `appealSubmitted` | 신청이 접수되었습니다.\n자동으로 다시 계산하고, 결과를 알림으로 알려드릴게요 | 성공 안내 |
| `appealMyListTitle` | 내 이의 제기 내역 | 내역 탭 |
| `appealEmptyState` | 아직 신청한 이의 제기가 없어요 | 빈 상태 |
| `appealReviewedNote` | 운영자가 검토 중이에요 | 상태 안내 |
| `appealCategorySectionTitle` | 어떤 일에 대한 이의인가요? | P1-12 카테고리 선택 헤더 |
| `appealCategoryGrantDecision` | 내 차례 결정에 대한 이의 | P1-12 카테고리 — `grant_decision` (기본) |
| `appealCategoryListingModeDispute` | 매물 모드 분쟁 | P1-12 카테고리 — `listing_mode_dispute` (exclusive 모드 진입/지정 분쟁, grantId 부재 허용) |
| `appealCategoryOther` | 그 외 | P1-12 카테고리 — `other` |
| `appealResolutionNotificationTitle` | 이의 신청 결과가 나왔어요 | **P1-9 신설** — `onPriorityAppealResolved` 트리거가 신청자(filerUid)에게 발송하는 push/인앱 알림의 *고정 title*. body 는 운영자가 `resolveAppeal({resolution})` 에 입력한 텍스트. 시스템 자동 카피로 80세 화법 직접 통과(15자, 일상 한국어, 점수·% 0). 운영자 입력 `resolution` 의 80세 화법 검수는 [operator-to-user-copy-gate.md §3](operator-to-user-copy-gate.md) 7원칙 *권고* — 자동 게이트는 별도 phase (`validateOperatorMessage` callable). |
| **★ Problem 004 §2.5.1 신설 — 매도자 측 이의 제기 진입점 (옵션 A 일반화)** | | |
| `appealNoEligibleGrantsForSeller` | 이 매물에 아직 차례를 받은 분이 없어요 | `PriorityAppealPage(role: seller)` 빈 상태 — broker 의 `appealNoEligibleGrants` 와 분기 |
| `sellerAppealTargetLabel` | 어느 매물에 대해 신청할까요 | `PriorityAppealPage(role: seller)` 매물 드롭다운 라벨 — broker 의 `appealTargetLabel` 와 분기 |
| `auditRowAppealActionLabel` | 이상해요로 알리기 | 매도자 audit timeline 행 단위 텍스트 버튼 + bottom sheet 제출 버튼 |
| `auditRowAppealConfirmTitle` | 이 결정이 이상하다고 알리시겠어요? | 매도자 audit row 진입 bottom sheet 타이틀 |
| `auditRowAppealConfirmBody` | 받은 신청은 자동으로 다시 한 번 계산해 봅니다. 결과는 알림으로 알려드릴게요. | 매도자 audit row 진입 bottom sheet 본문 — `onPriorityAppealCreated` 자동 replay + `onPriorityAppealResolved` 알림 흐름의 사용자 안내 |

### 2.7.1 평상시 자진 만료 2단계 다이얼로그 (Problem 004 §3.2.2)

> `PriorityCapDialog` (5개 한도 도달 시 *여러 매물 중 1건 골라 놓기*) 와는 의도가 다른
> *지정된 1건 자진 만료* 흐름. `broker_property_card.dart` 의 ⋮ 메뉴 → "이 매물 놓기" 진입.
> `RevokeOwnGrantConfirmDialog` 위젯이 1단계 → 2단계를 *명시적 두 번 탭* 으로 분리해 오탭 방지
> (Code-level Enforcement). 단계 사이 자동 chain 금지.

| 상수명 | 카피 | 사용처 |
|---|---|---|
| `revokeConfirmStep1Title` | 이 매물을 놓으시겠어요? | 1단계 다이얼로그 타이틀 |
| `actionReleaseShort` | 놓기 | 1단계 다이얼로그 confirm 버튼 (1단계는 짧게 — 2단계와 차별화) |
| `revokeConfirmStep2Title` | 한 번 더 확인해 주세요 | 2단계 다이얼로그 타이틀 |
| `actionReleaseConfirm` | 정말 놓기 | 2단계 다이얼로그 confirm 버튼 (1단계 "놓기" 와 라벨 차별화로 반복 탭 방어) |
| `revokeSuccessWithCooldown` | 놓았어요. 24시간 동안 다시 받을 수 없어요. | 자진 만료 성공 SnackBar — `revokeSuccess` + `capDialogCooldownNotice` 결합본 |
| 재사용 `capDialogCooldownNotice` | 한 번 놓으면 같은 매물은 24시간 동안 다시 받을 수 없어요 | 2단계 다이얼로그 본문 안내 (한도 다이얼로그와 공유) |
| 재사용 `actionReleaseHold` | 이 매물 놓기 | ⋮ 메뉴 항목 라벨 (broker_property_card.dart) |

### 2.8 JurisdictionPicker — 중개사 영업 지역 셀프-서비스 (Task 003)

> 출처: [docs/task/2026-05-04_003-broker-jurisdictions-self-service.md](../task/2026-05-04_003-broker-jurisdictions-self-service.md) §2.1.4 / §2.1.5
>
> **금지 단어** (한자어): "관할", "행정구역", "법정동", "코드", "관할구역", "지자체"
> **허용 단어** (일상): "동네", "지역", "시·군·구"
> **수치 노출 0**: 5자리 법정동코드 자체는 *내부 저장 전용*. UI 에는 표시명만.

| 상수명 | 카피 | 사용처 |
|---|---|---|
| `jurisdictionEmptyBanner` | 영업 지역을 등록해야 매물을 받을 수 있어요 | 본인 정보 페이지 + 중개사 대시보드 헤더 (verified=true && jurisdictions=[] 일 때만) |
| `jurisdictionEmptyBannerCta` | 지금 등록하기 | 빈 상태 배너의 행동 버튼 |
| `jurisdictionSectionTitle` | 영업 가능 지역 | 본인 정보 페이지 — 섹션 헤더 |
| `jurisdictionSectionHint` | 내가 영업할 동네를 골라주세요. 최대 5개까지 고를 수 있어요 | 섹션 부가 안내 (한 줄) |
| `jurisdictionEditCta` | 지역 추가/편집 | "JurisdictionPicker 다이얼로그 열기" 버튼 (섹션 + 가입 폼 칩 추가 모두 공유) |
| `jurisdictionSaved` | 영업 지역이 저장되었어요. 최대 30초 안에 반영돼요 | 저장 성공 SnackBar — race 완화 안내 동봉 (`onBrokerJurisdictionsUpdated` 트리거가 비동기 발화) |
| `jurisdictionSaveFailed` | 저장 중 문제가 있어요. 잠시 후 다시 해 주세요 | 저장 실패 SnackBar — 원인+해결법 (사유 코드 raw 노출 0) |
| `jurisdictionSignupLabel` | 주 영업 지역 | 가입 폼 영업 지역 섹션 라벨 (실 화면에서 *를 부착하여 필수 표시) |
| `jurisdictionSignupRequired` | 영업 가능 지역을 1개 이상 골라주세요 | 가입 폼 — 미선택 상태에서 제출 시 에러 |
| `jurisdictionSignupEmptyPlaceholder` | 아직 고른 지역이 없어요 | 가입 폼 칩 영역 + 본인 정보 페이지 칩 영역 빈 상태 placeholder |

**JurisdictionPicker 다이얼로그 내부 카피** (위젯 내장):

| 위치 | 카피 | 비고 |
|---|---|---|
| 다이얼로그 헤더 | 영업할 동네 고르기 | h3 |
| 부제 | 최대 N개까지 고를 수 있어요 | N = `maxCount` (기본 5) |
| 단계 1 라벨 | 시·도 선택 | h4 (스텝 인디케이터 1) |
| 단계 2 라벨 | 시·군·구 선택 (고른 곳: N개) | h4 (스텝 인디케이터 2) |
| 칩 섹션 라벨 | 지금 고른 동네 | captionLarge |
| 한도 초과 경고 | 지역은 최대 N개까지 고를 수 있어요 | 6번째 체크 시도 시 |
| 최소 미달 경고 | 지역을 N개 이상 골라주세요 | 0개 저장 시도 시 |
| 액션 — 취소 | 취소 | OutlinedButton |
| 액션 — 저장 | 저장 | ElevatedButton (primary) |

**80세 노인 테스트 통과 근거** (Task 003 §6):
- Q1 한 행동: "내가 영업할 동네 고르기"
- Q2 모르는 단어: 0 (한자어 회피)
- Q3 3초 이내 알림 이해: Yes — 30자 이내 (`jurisdictionEmptyBanner` 22자)
- Q4 되돌리기: Yes — [취소] / 저장 후에도 [지역 추가/편집] 으로 재편집
- Q5 의사결정 ≤ 2: Yes — ① 시·도 1개 ② 시·군·구 N개
- Q6 점수·코드 노출: 0 — 표시명만 (5자리 코드는 내부 저장 전용)

**catalog 데이터 단일 진실원**: [lib/constants/jurisdictions.dart](../../lib/constants/jurisdictions.dart) — 시·도 → 시·군·구 트리. v1.4.1 기준 약 90개 항목 (서울 25 + 6대 광역시 + 경기 31 + 세종). v1.5 운영 phase 에서 250+ 전체 시·군·구로 확장 예정.

---

## 3. 사유 코드 → 한국어 매핑 (전체 26종, [grant_messages.dart::reasonCopy](../../lib/constants/grant_messages.dart) 와 1:1)

> Backend `functions/index.js` 의 `REASON` 상수 ↔ 본 표 ↔ `describeReason` 폴백. 3-레이어 동기화 필수.

| 코드 | 한국어 카피 | 정책 출처 |
|---|---|---|
| `eligibility_not_found` | 먼저 중개사 등록을 마쳐주세요 | Task 02 |
| `license_not_verified` | 면허 확인이 끝난 뒤 받을 수 있어요 | Task 02 |
| `jurisdiction_mismatch` | 내 영업 지역이 아니에요 | Task 02 |
| `cap_exceeded` | 이미 5개를 맡고 있어요 | Task 02 |
| `already_granted` | 이미 다른 분이 맡고 있어요 | Task 02 |
| `revoke_cooldown` | 방금 놓은 매물은 24시간 뒤에 다시 받을 수 있어요 | Task 02 |
| `score_below_threshold` | 아직 받기 어려워요 | Task 02 |
| `revoked_by_self` | 내가 놓았어요 | Task 02 |
| `not_grant_owner` | 내가 맡은 매물이 아니에요 | Task 02 |
| `grant_not_active` | 이미 끝난 매물이에요 | Task 02 |
| `timeout` | 시간이 다 됐어요 | Task 02 |
| `activity_under_80` | 약속한 일을 못 마쳐서 다른 분에게 기회가 갔어요 | Task 02 |
| `migrated_legacy` | 예전 매물이라 정리됐어요 | Task 01 |
| `buyer_not_owner` | 내가 보낸 문의가 아니에요 | Task 03 |
| `inquiry_not_found` | 이 매물 문의를 찾을 수 없어요 | Task 03 |
| `buyer_switch_required` | 이미 담당 중개사가 있어요. 바꾸시려면 한 번 더 눌러주세요 | Task 03 |
| `buyer_switch_cooldown` | 방금 담당을 정해서 24시간 동안 바꿀 수 없어요 | Task 03 |
| `revoked_by_buyer_switch` | 매수자가 담당 중개사를 바꿔서 끝났어요 | Task 03 |
| `not_in_exclusive_list` | 이 매물은 매도자가 직접 지정한 분들만 받을 수 있어요 | Task 07 |
| `exclusive_has_active_grant` | 지금은 맡고 있는 분이 있어 모드를 바꿀 수 없어요 | Task 07 |
| `exclusive_broker_limit_exceeded` | 지정 중개사는 1명에서 3명까지만 고를 수 있어요 | Task 07 |
| `exclusive_cooldown` | 방금 지정을 바꿔서 24시간 뒤에 다시 바꿀 수 있어요 | Task 07 |
| `exclusive_broker_not_verified` | 면허 확인이 끝난 중개사만 지정할 수 있어요 | Task 07 |
| `not_property_owner` | 내가 등록한 매물이 아니에요 | Task 07 |
| `invalid_listing_mode` | 매물 모드 값이 잘못됐어요 | Task 07 |
| `exclusive_consent_required` | 자율 선택 동의가 필요해요 | Task 07 |
| (폴백) | 잠시 후 다시 시도해 주세요 | Task 02 |

---

### 3.1 `score_below_threshold` 보조 분석 카피 (P2-4)

> `score_below_threshold` 사유 발생 시 [reasonCopy](../../lib/constants/grant_messages.dart) 의 "아직 받기 어려워요" 1줄로는 *원인·해결법* 안내가 부족하다. Task 02 §5.5 #8 권고에 따라 `priority_grants.scoringInputs.rawInputs` 를 클라이언트가 파싱해 *가장 큰 부족 요인* 1줄을 보조 카피로 표시한다.
>
> - 백엔드: `functions/index.js::serializeRawInputs` 가 HttpsError message 끝에 `inputs:k=v;...` 직렬 첨부.
> - 클라이언트: [`GrantMessages.extractScoringInputs`](../../lib/constants/grant_messages.dart) 가 파싱 → [`GrantMessages.describeScoringFailure`](../../lib/constants/grant_messages.dart) 가 분기 매칭.
> - **점수·가중치·% 노출 0**. 영문 식별자 노출 0. 본 표 카피는 [audit_copy_deck.dart](../../tools/audit_copy_deck.dart) §2 검증의 일부 (§2.8 신규 영역).
>
> 분기 우선순위: jurisdiction → license → cap → activity → distance → time → 일반.

| 분기 식별자 | 카피 | 분기 조건 |
|---|---|---|
| `scoringFailJurisdiction` | 내 영업 지역이 아니에요 — 본인 영업 지역만 받을 수 있어요 | `jurisdictionMatch` = false/0 |
| `scoringFailLicense` | 면허 확인이 안 되어서 받기 어려워요 | `licenseStatus` ≠ 'verified' |
| `scoringFailCap` | 이미 5개를 맡고 있어요 | `capHeadroom` ≤ 0 |
| `scoringFailActivity` | 최근 활동이 부족해요 — 받은 매물 활동을 진행하면 다음 차례에 유리해요 | `activityScore` < 0.3 |
| `scoringFailDistance` | 매물에서 너무 멀어요 — 가까운 매물부터 받아보세요 | `distance` < 0.3 |
| `scoringFailTime` | 먼저 받은 분들이 있어요 — 다음 새 매물을 빠르게 받아보세요 | `timeRank` < 0.3 |
| `scoringFailGeneric` | 아직 받기 어려워요 | (모든 변수가 임계 이상이지만 합산이 threshold 미달) |

---

## 4. Audit 이벤트 → 한국어 라벨 ([grant_messages.dart::auditEventLabel](../../lib/constants/grant_messages.dart))

> 매도자가 자기 매물의 처리 내역을 조회할 때 노출. 점수·가중치·기술 용어 0건.

| eventType | 한국어 라벨 |
|---|---|
| `grant_issued` | 우선권 부여 (※ 매도자 사실 통지용 — *내가 누구에게 줬는지* 필요) |
| `grant_expired` | 우선권 만료 |
| `grant_revoked` | 우선권 취소 |
| `grant_fulfilled` | 거래 성사로 종료 (※ P1-4 — `fulfillGrant` callable + `onContractCreated` 트리거. 매도자/admin 명시 호출 또는 contracts 신규 시 자동 fulfillment. inputs: `grantId`/`contractId`/`fulfillmentSource`(manual\|trigger)/`actorRole`. outputs: `previousStatus`/`newStatus`/`fulfilledAt`. broker_eligibility.activeGrantsCount -=1 동반) |
| `cap_blocked` | 한도 초과로 부여 안 됨 |
| `tiered_release_step` | 공개 단계 진행 |
| `participation_declared` | 참여 등록 |
| `participation_stage_advanced` | 단계 진척 |
| `participation_stage_rejected` | 단계 변경 거부 |
| `appeal_filed` | 이의 제기 접수 |
| `appeal_resolved` | 이의 제기 처리 |
| `appeal_resolution_notified` | 이의 결과 통지 (※ P1-9 — `onPriorityAppealResolved` 트리거가 `priority_appeals.status` 'open'\|'reviewing' → 'resolved'\|'rejected' 전이를 감지해 신청자(filerUid)에게 `notifications` 컬렉션 doc 1건 적재 → 기존 `sendPushNotification` 트리거가 자동 FCM 발송. inputs: `appealId`/`decision`/`filerUid`. outputs: `notificationId`/`titleSent`. 통지 카피 출처: 운영자 입력 `resolution` (operator-to-user-copy-gate.md §3 7원칙 *권고*, 자동 게이트는 별도 phase)) |
| `decision_replayed` | 결과 재계산 |
| `metrics_computed` | 점유율 집계 |
| `algorithm_config_bootstrapped` | 알고리즘 설정 초기화 |
| `algorithm_config_updated` | 알고리즘 설정 변경 (※ P1-10 — admin 가중치/임계값 갱신) |
| `listing_mode_changed` | 매물 모드 변경 |
| `exclusive_brokers_changed` | 단독 지정 중개사 변경 |
| `grant_rejected_not_in_exclusive_list` | 지정 외 중개사 부여 거부 |
| `activity_score_updated` | 활동 진척 (※ P1-3 — 임장/의향서 진척 시 자동 가산) |
| `admin_override_listing_mode` | 관리자 매물 모드 변경 (※ P1-11 — 분쟁 처리 시 admin 강제 변경. 사유는 audit `inputs.reason`) |
| `appeal_resolved_with_listing_mode_override` | 이의 제기 → 모드 변경 처리 (※ P1-12 — `resolveAppeal` 의 `action: { type: 'override_listing_mode', ... }` 분기로 *이의 제기 인용 + 매물 모드 강제 변경* 동시 처리. 본 audit 외에 `appeal_resolved` + `admin_override_listing_mode` 도 함께 적재되어 3-레이어 흔적 보존. inputs: `appealId`/`decision`/`actionType`/`newMode`/`reason`(200자 절단). outputs: `modeChanged`/`newListingMode`/`exclusiveBrokerCount`) |
| `platform_alert_sent` | 점유율 경고 발송 (※ P1-8 — `onPlatformMetricsCreated` 트리거가 red/yellow alertLevel 시 Slack/Email/admin_fallback 채널로 운영자 알림 발송. inputs: `alertLevel`/`district`/`channel`/`metricsDate`. outputs: `success`/`reason`. **운영자 전용** — 사용자 노출 0, copy-deck §6 admin 화법 OK) |
| `broker_stats_updated` | 활동 누적 (※ 라운드 2D P2-6 — `onPriorityGrantFulfilled` 트리거(priority_grants status active→fulfilled 전이)가 `brokerStats/{brokerId}.fulfilledGrantsCount += 1` + `lastFulfilledAt`. `onBrokerParticipationStageAdvanced` 트리거(broker_participations stage rank 증가)가 `declaredCount` / `visitScheduledCount` / `offerMadeCount` += 1. inputs: `trigger`(grant_fulfilled\|participation_stage_advanced)/`stage`/`grantId`/`propertyId`/`brokerId`. outputs: `counterField`/`delta`. **사용자 노출 0 — admin/디버깅 추적용**. brokerStats 자체도 admin only — copy-deck §1.4 점수·% 노출 금지 준수. 본 phase 는 *데이터 누적 기반 골격*만; 상대평가 산식·정렬 알고리즘·카테고리화는 P2-7 후행 phase 분리 — 차별화 X, 베이스라인 (목표 §4.2)) |
| `broker_eligibility_bulk_verified` | 면허 일괄 확인 (※ 라운드 3 P0-9 — `bulkVerifyBrokerEligibility` admin callable이 broker_eligibility licenseStatus를 'pending' → 'verified' 일괄 전환. P0-2 시드 후 모든 broker가 pending 상태로 시작 → admin 수동 검증 후 본 callable로 일괄 활성화. inputs: `mode`(all_pending\|explicit_ids)/`requestedCount`. outputs: `verifiedCount`/`skippedCount`/`failedCount`/`verifiedBrokerIds`(50건 절단). **admin 전용** — 사용자 노출 0) |

---

## 5. "우선권" 단어 정책 (단순성 vs 사실 통지 충돌)

매도자가 *자기 매물의 처리 내역*을 볼 때, "우선권 부여" / "우선권 취소" 같은 사실은 **반드시 사실 그대로** 통지해야 한다 — 매도자의 권리이며 *법무 감사 라인*. 따라서:

| 화면 | "우선권" 사용 | 대체 표현 |
|---|:---:|---|
| **매도자 audit timeline** ([auditEventLabel](../../lib/constants/grant_messages.dart)) | ✅ 허용 | 사실 통지 — 다른 표현 불가 |
| **매도자 보유자 강조** ([participationHolderBadge](../../lib/constants/grant_messages.dart)) | ✅ 허용 (1건) | "현재 우선권 보유" — 매도자에게 *현재 누가 차례인지* 명시 |
| **중개사 화면** | ❌ 금지 | "내 차례" / "맡은 매물" 사용 — `priority_holder_section.dart` broker 시야는 [`holderBadgeForBrokerView`](../../lib/constants/grant_messages.dart) ("현재 맡은 분이 있어요") 사용 |
| **매수자 화면** | ❌ 금지 | "담당 중개사" 사용 |
| **푸시 알림** | ❌ 금지 | "○○동 매물, 14일 동안 내 차례입니다" |
| **공개 페이지** | ❌ 금지 | "활동 기록" / "참여 중" 사용 — `priority_holder_section.dart` public 시야는 [`holderBadgeForPublicView(int)`](../../lib/constants/grant_messages.dart) ("참여 중인 중개사 N명") 사용 |

**판정 룰**: 매도자가 *자기 매물의 권리·결정*을 통지받는 자리 = 허용. 그 외 모든 자리 = 금지.

**Task 08 §5.4 #29 — `PriorityHolderSection` 매도자 전용 가드**: 본 위젯은 [`PriorityHolderViewerRole`](../../lib/widgets/priority_holder_section.dart) enum (`seller`/`broker`/`publicView`) 을 *required*로 받아 호출 시야를 컴파일 타임에 강제한다. broker/publicView 시야 호출 시 위 표의 대체 카피로 자동 분기되어 "우선권" 단어 노출 0 + M2 비식별 정책 (displayName 노출 0) 동시 보장.

---

## 6. 운영자(Admin) 화면 — *별도 룰*

[08-simplicity-doctrine.md](../task/08-simplicity-doctrine.md) §6 "Audit log vs 노인 화법 → 사용자 노출 안 함. 관리자만" 원칙에 따라:

- **운영자 화면(`lib/screens/admin/*`)** 은 80세 노인 테스트 *적용 제외*. 운영자는 직무 전문 사용자.
- 다음 화면은 기술 용어 허용:
  - `admin_dashboard.dart` — "매칭 관리", "이의 제기" 등
  - `admin_matching_page.dart` — "매칭 생성", "매칭 내역"
  - `admin_broker_stats_page.dart` — "신뢰도 점수", "활동률 80%"
  - `admin_appeals_page.dart` — "가중치 변경에 따른 점수 차이" 등 운영 디버깅 카피
  - `admin_priority_audit_page.dart` — eventType raw value 노출 가능
- **단, 운영자가 *결과를 사용자에게 전달* 하는 자리(예: 이의 제기 처리 결과 통지문)는 본 §3·§4 룰을 따름.**

### 6.1 운영자→사용자 통지 카피 가이드 (Task 001 신설)

운영자가 *자유 입력* 한 텍스트가 사용자에게 *그대로* 노출되는 자리(반려 사유, 이의 처리 결과 등)는 placeholder + 검증 로직으로 80세 노인 화법을 강제한다. [operator-to-user-copy-gate.md §3 7원칙](operator-to-user-copy-gate.md) 의 *입력 시점 가이드*에 해당.

**적용 자리** (Task 001 §F):
- `admin_broker_management.dart` — `_showRejectReasonDialog` 의 반려 사유 (`brokerVerificationRequests.rejectionReason`)
- 향후 추가될 운영자 자유 입력 자리 (이의 처리 resolution, 매물 검증 반려 사유 등)

**검증 규칙**:
- 길이: 5자 이상 200자 이하 (callable 서버 측 재검증 — `JURISDICTION_CODE_RE` 와 같은 정규식 게이트)
- placeholder: 반드시 모범 예시 1개 노출 (`GrantMessages.verifyAdminRejectReasonPlaceholder`)
- 영문 식별자 / 사유 코드 raw / 정규식 / SQL / JSON snippet 노출 금지

**모범/금지 예시 5쌍** (반려 사유):

| 좋은 예 (사용자에게 그대로 보여도 OK) | 나쁜 예 (사용자에게 보여서는 안 됨) |
|---|---|
| 면허번호가 등록증 사진과 달라요. 다시 확인 후 신청 부탁드립니다. | Eligibility verification failed: registration_number_mismatch |
| 사무소 주소를 입력하지 않으셨어요. 주소까지 적은 뒤 다시 신청해 주세요. | missing_broker_profile (officeAddress is empty) |
| 영업하실 동네를 1개 이상 골라주세요. | invalid_jurisdictions: array length must be 1~5 |
| 등록번호 사진이 흐려서 확인이 어려워요. 또렷한 사진으로 다시 신청 부탁드립니다. | OCR confidence < 0.7 — please retry |
| 이미 다른 분이 같은 사무소로 등록되어 있어요. 본인이라면 관리자에게 연락 주세요. | duplicate_registration_number on brokers/{uid} |

**3-레이어 동기 (Task 001)**:
- callable error message (`functions/index.js: invalid_reason: 5~200자`)
- ↔ `GrantMessages.verifyAdminRejectReasonPlaceholder` / `verifyAdminRejectReasonLabel`
- ↔ 본 §6.1 표

향후 자유 입력 자리 추가 시 본 §6.1 표에 *모범/금지 예시 1쌍* 을 반드시 추가한다 (PR 본문 첨부).

---

## 7. PR 시 본 문서 갱신 절차

1. **신규 카피 추가**: `lib/constants/grant_messages.dart` 에 상수 추가 → 본 §2 의 적합한 영역 표에 1행 추가.
2. **기존 카피 수정**: 본 문서를 먼저 갱신(원본 표 1행 변경) → `grant_messages.dart` 동시 변경 → PR 본문에 *수정 전·후*명시.
3. **사유 코드 추가**: §3 표에 1행 추가 → `functions/index.js REASON` ↔ `reasonCopy` ↔ 본 §3 표 *3-레이어 동시 갱신*.
4. **audit eventType 추가**: §4 표에 1행 추가 → `auditEventLabel` 동시 갱신.
5. **PR 자가 점검**: [simplicity-checklist.md](simplicity-checklist.md) 100% 통과 후 머지.

---

## 8. 문서 변경 이력

| 일자 | 버전 | 변경 |
|---|---|---|
| 2026-05-03 | v1.0.0 | Task 08 — 단순성 원칙 횡단 적용. Task 01~07 카피 통합 + 운영자 화면 별도 룰 명시 + "우선권" 단어 정책 정립. |
