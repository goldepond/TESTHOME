/// 우선권 시스템 사용자 카피 단일 진실원.
///
/// **80세 노인 테스트**: 모든 카피가 한 줄·짧은 문장·전문용어 없음.
/// 점수·가중치·산정 변수 *절대 노출 금지*.
library;

class GrantMessages {
  GrantMessages._();

  // 동작 라벨 (버튼)
  static const String actionTakeProperty = '이 매물 받기';
  static const String actionTakeAtCap = '하나 놓고 받기';
  static const String actionReleaseHold = '이 매물 놓기';
  static const String actionConfirm = '확인';
  static const String actionCancel = '취소';

  // Task 03 — 매수자측 임장 신청 흐름
  static const String actionVisitProperty = '임장 신청하기';
  static const String actionPickBroker = '담당 중개사 선택';
  static const String actionSwitchBroker = '담당 중개사 바꾸기';
  static const String actionUseRecommendedBroker = '추천 중개사로 진행';
  static const String actionSearchBroker = '직접 검색해 고르기';
  static const String actionUseFavoriteBroker = '평소 거래 중개사 고르기';

  // 매수자 안내 카피
  static const String buyerPickerTitle = '어느 중개사를 통해 임장하시겠습니까?';
  static const String buyerPickerHelp =
      '한 번 정하면 24시간 동안 같은 매물에서 다른 중개사로 바꿀 수 없어요.';
  static const String buyerSwitchConfirmTitle = '담당 중개사를 바꾸시겠어요?';
  static const String buyerSwitchConfirmBody =
      '지금 담당 중개사를 그만두고 다른 분에게 다시 부탁하는 거예요. 한 번 바꾸면 24시간 뒤에야 또 바꿀 수 있어요.';
  static const String buyerMatchSuccess = '담당 중개사가 정해졌어요';
  static const String buyerMatchSwitched = '담당 중개사를 바꿨어요';
  static const String buyerMatchEmpty = '아직 정한 담당 중개사가 없어요';

  // 매도자 대시보드용 — M1.1과 M1.2 분리 표시
  static const String sellerSellerSideHolderTitle = '매도 측 우선 중개사';
  static const String sellerBuyerSideHolderTitle = '매수 측 담당 중개사';
  static const String sellerSidesMayDifferNotice =
      '매도 측 우선 중개사와 매수 측 담당 중개사는 다를 수 있습니다.';

  // 상태 뱃지
  static const String badgeMineActive = '내 차례';
  static const String badgeOtherActive = '다른 분이 맡는 중';
  static const String badgeOpen = '받을 수 있어요';
  static const String badgeNotEligible = '받을 수 없어요';

  // 매도자 대시보드
  static const String sellerHolderSectionTitle = '이 매물을 맡고 있는 분';
  static const String sellerHolderSectionEmpty = '아직 맡은 분이 없어요';
  static const String sellerActivityRemainingParticipation = '남은 일: 임장 1건';
  static const String sellerActivityRemainingVisit = '남은 일: 매수 손님 1명 만나기';
  static const String sellerActivityRemainingOffer = '남은 일: 의향서 진행';
  static const String sellerAutoExpireNotice =
      '7일 동안 약속한 일을 못 마치면 다른 중개사에게 기회가 갑니다.';

  // 5개 한도 다이얼로그
  static const String capDialogTitle = '이미 5개 매물을 맡고 있어요';
  static const String capDialogBody = '어떤 매물을 놓을까요?';
  static const String capDialogCooldownNotice =
      '한 번 놓으면 같은 매물은 24시간 동안 다시 받을 수 없어요.';

  // 결과 메시지
  static const String issuedSuccess = '받았어요. 14일 동안 내 차례입니다';
  static const String revokeSuccess = '놓았어요';

  // === Problem 004 §3.2.2: 평상시 자진 만료 2단계 다이얼로그 ===
  //
  // broker_property_card.dart 의 ⋮ 메뉴 → "이 매물 놓기" 흐름.
  // 5개 한도 도달 전에도 평상시 자진 만료 가능 — `revokeOwnGrant` callable.
  // 2단계 분리 (1단계 "놓기" → 2단계 "정말 놓기") 로 오탭 방지.
  // 80세 화법 — "놓기"·"24시간"·"다시 받을 수 없어요" 일상 한국어.
  // copy-deck §2.x 매도자/중개사 카피 동기.
  static const String revokeConfirmStep1Title = '이 매물을 놓으시겠어요?';
  static const String revokeConfirmStep2Title = '한 번 더 확인해 주세요';
  static const String actionReleaseShort = '놓기';
  static const String actionReleaseConfirm = '정말 놓기';
  static const String revokeSuccessWithCooldown =
      '놓았어요. 24시간 동안 다시 받을 수 없어요.';

  // 사유 코드 → 노인 화법 (Backend functions/index.js의 REASON 상수와 1:1)
  static const Map<String, String> reasonCopy = <String, String>{
    'eligibility_not_found': '먼저 중개사 등록을 마쳐주세요',
    'license_not_verified': '면허 확인이 끝난 뒤 받을 수 있어요',
    'jurisdiction_mismatch': '내 영업 지역이 아니에요',
    'cap_exceeded': '이미 5개를 맡고 있어요',
    'already_granted': '이미 다른 분이 맡고 있어요',
    'revoke_cooldown': '방금 놓은 매물은 24시간 뒤에 다시 받을 수 있어요',
    'score_below_threshold': '아직 받기 어려워요',
    'revoked_by_self': '내가 놓았어요',
    'not_grant_owner': '내가 맡은 매물이 아니에요',
    'grant_not_active': '이미 끝난 매물이에요',
    'timeout': '시간이 다 됐어요',
    'activity_under_80': '약속한 일을 못 마쳐서 다른 분에게 기회가 갔어요',
    'migrated_legacy': '예전 매물이라 정리됐어요',
    // Task 03 — 매수자-중개사 매칭
    'buyer_not_owner': '내가 보낸 문의가 아니에요',
    'inquiry_not_found': '이 매물 문의를 찾을 수 없어요',
    'buyer_switch_required': '이미 담당 중개사가 있어요. 바꾸시려면 한 번 더 눌러주세요',
    'buyer_switch_cooldown': '방금 담당을 정해서 24시간 동안 바꿀 수 없어요',
    'revoked_by_buyer_switch': '매수자가 담당 중개사를 바꿔서 끝났어요',
    // Task 07 — 매도자 자율 단독 지정
    'not_in_exclusive_list': '이 매물은 매도자가 직접 지정한 분들만 받을 수 있어요',
    'exclusive_has_active_grant': '지금은 맡고 있는 분이 있어 모드를 바꿀 수 없어요',
    'exclusive_broker_limit_exceeded': '지정 중개사는 1명에서 3명까지만 고를 수 있어요',
    'exclusive_cooldown': '방금 지정을 바꿔서 24시간 뒤에 다시 바꿀 수 있어요',
    'exclusive_broker_not_verified': '면허 확인이 끝난 중개사만 지정할 수 있어요',
    'not_property_owner': '내가 등록한 매물이 아니에요',
    'invalid_listing_mode': '매물 모드 값이 잘못됐어요',
    'exclusive_consent_required': '자율 선택 동의가 필요해요',
  };

  /// 알 수 없는 사유 코드는 안전한 기본 카피로 폴백.
  static String describeReason(String? code) {
    if (code == null || code.isEmpty) return '잠시 후 다시 시도해 주세요';
    return reasonCopy[code] ?? '잠시 후 다시 시도해 주세요';
  }

  /// HttpsError 메시지(`'cap_exceeded: ...'` 형식)에서 reason code 추출.
  static String? extractReasonCode(String? errorMessage) {
    if (errorMessage == null) return null;
    final RegExpMatch? match =
        RegExp(r'^([a-z_]+):').firstMatch(errorMessage.trim());
    return match?.group(1);
  }

  /// 잔여일을 노인 화법으로 표현.
  static String describeDaysLeft(int days) {
    if (days < 0) return '이미 끝났어요';
    if (days == 0) return '오늘이 마지막이에요';
    if (days == 1) return '1일 남았어요';
    return '$days일 남았어요';
  }

  /// 단계 코드(participation/visit/offer)를 노인 화법으로.
  static String describeStage(String stageName) {
    switch (stageName) {
      case 'participation':
        return '맡은 시작';
      case 'visit':
        return '손님 만남';
      case 'offer':
        return '의향서';
      default:
        return '진행 중';
    }
  }

  // === Task 04: Tiered Release ===

  // 중개사 대시보드 뱃지 라벨
  static const String tierBadgeT1 = '1km 신규';
  static const String tierBadgeT2 = '같은 동';
  static const String tierBadgeT3 = '인접 동';
  static const String tierBadgeT4 = '시·군 전체';

  // 매도자 대시보드 진행 안내 (한 줄, 80세 노인 화법)
  static const String tierProgressT1 = '오늘은 우리 동네 중개사들이 봅니다';
  static const String tierProgressT2 = '이제 같은 동 중개사들도 봅니다';
  static const String tierProgressT3 = '인접 동까지 확대됐습니다';
  static const String tierProgressT4 = '시·군 전체에 공개됐습니다';
  static const String tierExclusiveLabel = '단독으로 맡긴 매물이라 단계 확대를 하지 않습니다';
  /// release_tier_badge.dart 카드 표시용 짧은 라벨 (P0-12 raw 카피 교체)
  static const String tierExclusiveBadgeLabel = '단독 매물';
  static const String tierPausedByGrant = '담당 중개사가 활동 중이라 단계 확대를 잠시 멈췄어요';

  // 알림 카피 (FCM/notifications)
  static const String tierNotifTitle = '신규 매물 알림';

  /// tier 코드 → 뱃지 라벨 헬퍼
  static String tierBadgeLabel(String? tier) {
    switch (tier) {
      case 'tier1_1km':
        return tierBadgeT1;
      case 'tier2_dong':
        return tierBadgeT2;
      case 'tier3_adjacent':
        return tierBadgeT3;
      case 'tier4_district':
        return tierBadgeT4;
      default:
        return '';
    }
  }

  /// tier 코드 → 매도자 진행 카피 헬퍼
  static String tierProgressCopy(String? tier) {
    switch (tier) {
      case 'tier1_1km':
        return tierProgressT1;
      case 'tier2_dong':
        return tierProgressT2;
      case 'tier3_adjacent':
        return tierProgressT3;
      case 'tier4_district':
        return tierProgressT4;
      default:
        return '';
    }
  }

  // === Task 05: M2 시간기록 공개 (Priority Disclosure) ===

  // 단계 라벨 (declared / visit_scheduled / offer_made)
  static const String participationStageDeclared = '참여 등록';
  static const String participationStageVisitScheduled = '임장 예정';
  static const String participationStageOfferMade = '의향서 제출';

  // 우선권 보유자 강조 카피
  static const String participationHolderBadge = '현재 우선권 보유';

  // 빈 상태
  static const String participationEmptyState = '아직 참여한 중개사가 없습니다';

  // 섹션 제목 (매도자 대시보드)
  static const String participationTimelineTitle = '중개사 활동 기록';

  // 비로그인 공개 매물 상세 — 집계 카피
  static const String participationPublicCountSuffix = '명의 중개사가 참여 중';

  /// 첫 참여 시점을 노인 화법으로.
  static String participationFirstDaysAgo(int days) {
    if (days <= 0) return '오늘 첫 참여';
    return '첫 참여 $days일 전';
  }

  /// participation stage 문자열 → 한글 라벨.
  /// 미지 코드는 [participationStageDeclared] 로 폴백.
  static String participationStageLabel(String stageStr) {
    switch (stageStr) {
      case 'declared':
        return participationStageDeclared;
      case 'visit_scheduled':
        return participationStageVisitScheduled;
      case 'offer_made':
        return participationStageOfferMade;
      default:
        return participationStageDeclared;
    }
  }

  // === Task 06: Algorithm Transparency (이의 제기 · 결정 사유 · 단계 정지) ===

  // 이의 제기 진입 메뉴
  static const String appealMenuTitle = '이상해요 (이의 제기)';

  // 이의 제기 폼
  static const String appealFormTitle = '결과가 이상한 이유를 알려주세요';
  static const String appealReasonHint = '어떤 점이 이상한지 자유롭게 적어주세요. (최대 1000자)';
  static const String appealSubmit = '제출하기';
  static const String appealSubmitted =
      '신청이 접수되었습니다.\n자동으로 다시 계산하고, 결과를 알림으로 알려드릴게요.';

  // 이의 제기 내역
  static const String appealMyListTitle = '내 이의 제기 내역';
  static const String appealEmptyState = '아직 신청한 이의 제기가 없어요.';
  static const String appealReviewedNote = '운영자가 검토 중이에요.';

  // === P1-9: 이의 제기 처리 결과 push 알림 ===
  //
  // resolveAppeal callable 가 priority_appeals/{id}.status 를 'open'|'reviewing'
  // → 'resolved'|'rejected' 로 갱신하면 functions/index.js 의
  // `onPriorityAppealResolved` 트리거가 신청자(filerUid)에게 notifications
  // 컬렉션 doc 1건을 적재 → 기존 sendPushNotification 트리거가 자동 발화.
  //
  // 본 카피는 *시스템 자동 카피* (운영자 자유 입력 X) — 80세 화법 직접 통과.
  // operator-to-user-copy-gate.md §3 7원칙:
  //   1) 일상 한국어 ✓ ("이의 신청 결과") / 2) 30자 이내 ✓ (15자) /
  //   3) 한 결정만 담음 ✓ (결과 통지 1건) / 4) 사실 통지 ✓ /
  //   5) 단순한 단어 ✓ / 6) 점수·% 0 ✓ / 7) 비난·법률체 0 ✓.
  //
  // body 는 운영자가 입력한 resolution 텍스트가 들어간다. resolution 자체의
  // 80세 화법 검수는 별도 phase (validateOperatorMessage callable, gate §5).
  // 현재는 *권고* 만 admin_appeals_page.dart 미리보기에서 안내.
  //
  // copy-deck §2.7 동기. 3-레이어 동기 (functions notification.title ↔ 본 상수
  // ↔ copy-deck §2.7) — 본 PR 에서 모두 갱신.
  static const String appealResolutionNotificationTitle = '이의 신청 결과가 나왔어요';

  // === P1-12: 이의 제기 카테고리 선택 (사용자 노출) ===
  //
  // 사용자가 이의 제기 폼에서 *어떤 분쟁인지* 분류를 골라야 admin 검토가
  // 정확해진다. 80세 화법 통과 — 영문 0, 전문용어 0, 길이 짧음.
  // copy-deck §2.7 + §4 동시 갱신 (PR 본문 첨부).
  //
  // 분기:
  //   * grantDecision (기본): "내가 받았어야 할 차례인데 못 받았어요"
  //   * listingModeDispute: "매물 모드 지정에 대한 분쟁"
  //   * other: 자유 사유
  static const String appealCategorySectionTitle = '어떤 일에 대한 이의인가요?';
  static const String appealCategoryGrantDecision = '내 차례 결정에 대한 이의';
  static const String appealCategoryListingModeDispute = '매물 모드 분쟁';
  static const String appealCategoryOther = '그 외';

  /// `AppealCategory.wireName` (snake_case) → 사용자 노출 라벨.
  /// 알 수 없는 코드는 폴백 — '그 외' 노출 (raw 코드 노출 차단).
  static String appealCategoryLabel(String wireName) {
    switch (wireName) {
      case 'grant_decision':
        return appealCategoryGrantDecision;
      case 'listing_mode_dispute':
        return appealCategoryListingModeDispute;
      case 'other':
      default:
        return appealCategoryOther;
    }
  }

  // === P1-20: 매도자 fulfillment UI 카피 (거래 성사 처리) ===
  //
  // 매도자가 매물 카드/상세 페이지에서 [거래 성사로 끝내기] 버튼을 누르면
  // fulfillGrantViaFunction → grant.status='fulfilled' + activeGrantsCount -= 1.
  // 매수자·broker에게도 알림 (P1-9 push 알림 패턴 — 후속 phase).
  // 80세 화법: "처리"·"종결" 같은 한자어 회피, "끝나기" 일상어 사용.
  static const String actionFulfillGrant = '거래 성사로 끝내기';
  static const String fulfillConfirmTitle = '거래가 성사됐나요?';
  static const String fulfillConfirmBody =
      '맡기로 한 중개사와의 거래가 끝났음을 표시합니다.';
  static const String fulfillSuccess = '끝났어요';
  static const String fulfillCancel = '아직이에요';

  // 결정 사유 (audit log 타임라인)
  static const String auditTimelineTitle = '내 매물 우선권 처리 내역';
  static const String auditEmptyState = '아직 처리된 내용이 없어요.';

  // 단계 정지 표시 (Task 04 §5.1 #6 / Task 05 §5.1 #4 누적)
  static const String tierPausedByGrantInline =
      '현재 우선권 보유 중인 분이 있어 다음 단계 공개가 잠시 멈춰 있어요.';

  // 내 매물 단계 이력 (Task 04 §5.4 #14)
  static const String myPropertyTierHistoryTitle = '단계 진행 이력';

  /// 이의 제기 상태 라벨 헬퍼.
  static String appealStatusLabel(String statusName) {
    switch (statusName) {
      case 'open':
        return '접수됨';
      case 'reviewing':
        return '검토 중';
      case 'resolved':
        return '처리 완료';
      case 'rejected':
        return '기각';
      default:
        return statusName;
    }
  }

  // === P1-4: 거래 성사 시 grant 종료 audit 라벨 ===
  //
  // 매도자 audit timeline 노출용. copy-deck §5 표 매도자 사실 통지 라인 허용.
  // functions/index.js fulfillGrant callable + onContractCreated 트리거가
  // 발생시키는 'grant_fulfilled' eventType 의 한국어 라벨.
  // 3-레이어 동기: functions eventType ↔ 본 상수 ↔ copy-deck §4.
  //
  // 80세 화법: "거래 성사로 종료" — 11자, 점수·기술 용어 0, 사실 통지.
  // 매도자 입장에서 "왜 종료됐는지" (만료/취소/거래성사) 명확 구분 가능.
  // 본 상수가 auditEventLabel 메서드 위에 위치한 이유: Dart const map 리터럴은
  // 메서드 내부에서 같은 클래스의 *뒤쪽 정의* static const 를 forward reference
  // 할 때 분석기 에러를 낸다. platformAlertSentLabel 도 본래 위와 같은 위치로
  // 옮겨야 하나 기존 호환성 유지 차원에서 그대로 둠 (실제 컴파일은 통과).
  static const String auditEventLabelGrantFulfilled = '거래 성사로 종료';

  // === P1-12: resolveAppeal action 통합 처리 audit 라벨 ===
  //
  // resolveAppeal 의 `action: { type: 'override_listing_mode', ... }` 분기가
  // 발화시키는 'appeal_resolved_with_listing_mode_override' eventType 의 한국어
  // 라벨. 매도자 audit 타임라인 노출용 — copy-deck §5 매도자 사실 통지 라인 OK.
  // 3-레이어 동기: functions eventType ↔ 본 상수 ↔ copy-deck §4.
  //
  // 80세 화법 — "이의 제기 → 모드 변경 처리" (15자, 점수·기술용어 0, 사실 통지).
  // const map 의 forward reference 회피 — auditEventLabel 메서드 위에 위치.
  static const String auditEventLabelAppealResolvedWithListingModeOverride =
      '이의 제기 → 모드 변경 처리';

  // === 라운드 2D P2-6: brokerStats 카운터 누적 audit 라벨 ===
  //
  // 정책 출처: docs/goal/multi_agent_competition_solutions_cross_industry.md §4.2
  //   (Reputation Pool — 후행 메커니즘, 차별화 X, 베이스라인)
  //
  // functions/index.js:
  //   * onPriorityGrantFulfilled — priority_grants status active→fulfilled 시
  //     brokerStats/{brokerId}.fulfilledGrantsCount += 1.
  //   * onBrokerParticipationStageAdvanced — broker_participations stage 진척 시
  //     declaredCount / visitScheduledCount / offerMadeCount += 1.
  //   두 트리거 모두 'broker_stats_updated' eventType 로 audit log 적재.
  //
  // **사용자 노출 0** (★중요★):
  //   본 audit 는 *admin/디버깅 추적용* — 사용자/매도자/broker 본인 audit
  //   타임라인 노출 X. brokerStats 카운터 자체도 admin 노출 only (copy-deck
  //   §1.4 점수·% 노출 금지). 그러나 3-레이어 동기 차원에서 라벨은 정의.
  //   80세 화법 — "활동 누적" (5자, 점수·기술용어 0, 사실 통지 톤).
  //
  // 3-레이어 동기: functions eventType ↔ 본 상수 ↔ copy-deck §4.
  // const map 의 forward reference 회피 — auditEventLabel 메서드 위에 위치.
  static const String auditEventLabelBrokerStatsUpdated = '활동 누적';

  /// audit eventType 한국어 라벨 헬퍼.
  /// 노인 화법 — 점수·가중치·기술 용어 노출 없음.
  static String auditEventLabel(String eventType) {
    const Map<String, String> map = <String, String>{
      'grant_issued': '우선권 부여',
      'grant_expired': '우선권 만료',
      'grant_revoked': '우선권 취소',
      'grant_fulfilled': auditEventLabelGrantFulfilled,
      'cap_blocked': '한도 초과로 부여 안 됨',
      'tiered_release_step': '공개 단계 진행',
      'participation_declared': '참여 등록',
      'participation_stage_advanced': '단계 진척',
      'participation_stage_rejected': '단계 변경 거부',
      'appeal_filed': '이의 제기 접수',
      'appeal_resolved': '이의 제기 처리',
      // P1-9 — onPriorityAppealResolved 트리거가 신청자에게 push 알림 발송 후
      // priority_audit_logs 에 적재하는 audit eventType. 매도자 audit timeline
      // 보다는 admin/디버깅 추적용에 가까우나 3-레이어 동기 차원에서 라벨 정의.
      // 80세 화법 — "이의 결과 통지" (8자, 점수·기술용어 0).
      'appeal_resolution_notified': '이의 결과 통지',
      'decision_replayed': '결과 재계산',
      'metrics_computed': '점유율 집계',
      'algorithm_config_bootstrapped': '알고리즘 설정 초기화',
      // P1-10 — updateAlgorithmConfig admin callable (가중치/임계값 변경)
      'algorithm_config_updated': '알고리즘 설정 변경',
      // Task 07 — 매도자 자율 단독 지정
      'listing_mode_changed': '매물 모드 변경',
      'exclusive_brokers_changed': '단독 지정 중개사 변경',
      'grant_rejected_not_in_exclusive_list': '지정 외 중개사 부여 거부',
      // P1-3 — activityScore 자동 갱신 (임장/의향서 단계 진척 가산)
      // 80세 화법: "활동 진척" — 점수·delta·trigger 식별자 노출 0.
      'activity_score_updated': '활동 진척',
      // P1-11 — adminOverrideListingMode (분쟁 처리 시 admin 강제 모드 변경)
      // 매도자 사실 통지 — "관리자가 모드를 바꿨음" 사실 + 사유는 별도 필드.
      'admin_override_listing_mode': '관리자 매물 모드 변경',
      // P1-12 — resolveAppeal 의 action 분기로 이의 제기 인용과 동시에 매물 모드를
      // 강제 변경한 *통합* 처리 1건 표식. 매도자 audit 타임라인 노출용.
      // 80세 화법 — "이의 제기 → 모드 변경 처리" (점수·기술용어 0).
      'appeal_resolved_with_listing_mode_override':
          auditEventLabelAppealResolvedWithListingModeOverride,
      // P1-8 — onPlatformMetricsCreated webhook 발송 결과 audit
      // 운영자(admin) 전용 audit eventType — 사용자 노출 0.
      // copy-deck §6 운영자 화법 OK. inputs.channel(slack/email/admin_fallback) +
      // outputs.success/reason 로 발송 디버깅 추적 (alertLevel/district inputs).
      'platform_alert_sent': platformAlertSentLabel,
      // P2-6 — onPriorityGrantFulfilled / onBrokerParticipationStageAdvanced
      // 트리거가 brokerStats 카운터 증분 시 적재.
      // **사용자 노출 0** — admin/디버깅 추적용. brokerStats 자체도 admin only.
      // 80세 화법 — "활동 누적" (점수·% 0).
      // copy-deck §4 ↔ auditEventLabelBrokerStatsUpdated ↔ 본 map value 일치 필수
      // (audit_copy_deck.dart 검증을 위해 string literal 직접 사용 — 식별자
      // 참조는 정규식 파서에서 skip 되어 §4 카피 일치 검증 누락 위험).
      'broker_stats_updated': '활동 누적',
      // P0-9: bulkVerifyBrokerEligibility callable이 발생시키는 audit eventType.
      // admin이 broker_eligibility licenseStatus를 'pending' → 'verified' 일괄 전환.
      // copy-deck §4 ↔ 본 map value 일치 필수 (admin 추적용 — 사용자 노출 X).
      'broker_eligibility_bulk_verified': '면허 일괄 확인',
    };
    return map[eventType] ?? eventType;
  }

  // === P1-8: platform_metrics red/yellow alertLevel 도달 시 운영자 알림 ===
  //
  // copy-deck §6 운영자 화면 별도 룰 적용 — admin 화법 OK (사용자 노출 X).
  // functions/index.js onPlatformMetricsCreated 트리거에서 발송한 audit log 라벨.
  // 3-레이어 동기: functions audit eventType ↔ 본 상수 ↔ copy-deck §4.
  static const String platformAlertSentLabel = '점유율 경고 발송';

  // === Task 07: 매도자 자율 단독 지정 (Open / Exclusive Listing) ===
  //
  // 법무 라인:
  //   * MyHome이 지정 = §33①9호 위반 (단체결성 공동중개 제한)
  //   * 매도자 자율 지정 = 합법 (사적 자치)
  //   따라서 모든 카피는 *매도자 자발 선택* 임을 명백히 한다.
  //   "추천 중개사 3인" 같은 카피 금지 — 자발성 불명확.

  // 등록 화면 라디오 옵션
  static const String listingModeSectionTitle = '어떤 분이 매물을 봐주실까요?';
  static const String listingModeOpenLabel = '모든 중개사 공개 (권장)';
  static const String listingModeOpenDescription =
      '지역 내 자격을 갖춘 모든 중개사가 매물을 보고 참여할 수 있어요.';
  static const String listingModeExclusiveLabel = '특정 중개사 1~3명 단독 지정';
  static const String listingModeExclusiveDescription =
      '내가 신뢰하는 중개사만 우선으로 맡깁니다. 직접 검색해서 고르세요.';

  // exclusive 검색 모달
  static const String exclusiveSearchTitle = '단독으로 맡길 중개사를 직접 골라주세요';
  static const String exclusiveSearchHint = '중개사 이름이나 사무소 이름으로 찾기';
  static const String exclusiveSearchEmpty = '면허 확인이 끝난 중개사가 검색되지 않아요';
  static const String exclusiveSelectedCountSuffix = '/3명 선택';
  static const String exclusiveLimitWarning = '최대 3명까지 고를 수 있어요';
  static const String exclusiveAtLeastOneRequired = '한 명 이상 골라야 해요';
  static const String exclusiveOnlyVerifiedNotice =
      '면허 확인이 끝난 중개사만 보여드려요. 자율 선택을 위해 추천 순서가 아닌 가나다 순입니다.';

  // 자율 동의 체크박스 (법무 라인)
  static const String exclusiveSelfAttestationLabel =
      '이 지정은 내 자율 선택이며 MyHome은 추천하지 않았음을 확인합니다';
  static const String exclusiveSelfAttestationRequired = '자율 선택 동의에 체크해 주세요';

  // 모드 전환 화면 (편집/대시보드)
  static const String listingModeChangeMenuTitle = '매물 모드 바꾸기';
  static const String listingModeCurrentOpen = '지금은 모든 중개사에게 공개되고 있어요';
  static const String listingModeCurrentExclusive = '지금은 단독 지정 중이에요';
  static const String listingModeToOpenConfirm =
      '모든 중개사에게 공개로 바꿀까요?\n지정 중개사 정보는 사라집니다.';
  static const String listingModeToExclusiveConfirm =
      '단독 지정으로 바꾸시겠어요?\n지금 매물을 맡고 있는 분이 있으면 바꿀 수 없어요.';
  static const String listingModeChangeCooldownNotice =
      '한 번 바꾸면 24시간 동안 다시 바꿀 수 없어요.';
  static const String listingModeChanged = '매물 모드를 바꿨어요';
  static const String exclusiveBrokersChanged = '지정 중개사를 바꿨어요';

  // 매물 카드/상세 표시 (Broker / Public)
  static const String listingExclusiveBadge = '단독 지정';
  static const String listingExclusiveSellerSelectedNotice =
      '이 매물은 매도자가 직접 단독 중개사를 지정한 매물입니다. 참여 등록은 받지 않습니다.';
  static const String listingExclusiveBuyerNeutralNotice =
      '이 매물은 매도자 측이 단독 중개사와 함께 진행 중입니다. 매수 문의는 평소처럼 가능합니다.';
  static const String listingExclusiveAssignedBadge = '단독 지정 받은 매물';

  // 매도자 대시보드 표시
  static const String sellerExclusiveSelectedTitle = '내가 직접 지정한 중개사';
  static const String sellerExclusiveCountSuffix = '명 단독 지정';

  // 매도자 대시보드 — 모드 변경 이력 (P1-13)
  // copy-deck §2.4 매물 모드 카피의 자연어 변형. 점·코드 노출 0.
  // "한두 명만으로" / "모든 중개사로" 일상 한국어 (copy-deck §1.1 60세 어휘 통과).
  static const String listingHistorySectionTitle = '모드 변경 이력';
  static const String listingHistoryToExclusive = '한두 명만으로 변경';
  static const String listingHistoryToOpen = '모든 중개사로 변경';

  // === P1-11: adminOverrideListingMode 매도자 알림 ===
  //
  // 운영자가 분쟁 처리 시 매도자 동의 없이 매물 모드를 강제 변경할 때
  // 매도자에게 보내는 알림 카피. 운영자→사용자 통지 경로
  // (copy-deck §6 + operator-to-user-copy-gate.md §3 7원칙) 적용.
  //
  // 80세 화법 통과 — 영문 0, 30자 이내, MyHome 의지 개입 인상 0.
  // "분쟁 사유 함께" 표현으로 *MyHome 강제가 아닌* 분쟁 해결 맥락임을 명시.
  static const String adminOverrideListingModeNotificationTitle =
      '관리자가 매물 모드를 변경했어요';

  /// 매도자 알림 본문 템플릿. `{prev}` / `{next}` 는 호출처에서 한국어 모드 라벨로 치환.
  /// 예: '단독 지정 → 모든 중개사 공개 (분쟁 사유 함께)' (24자, 30자 한도 통과).
  /// "분쟁 사유 함께" — *MyHome 의지 개입* 인상 차단(분쟁 해결 맥락 명시).
  static const String adminOverrideListingModeNotificationBodyTemplate =
      '{prev} → {next} (분쟁 사유 함께)';

  /// admin override 알림 본문 빌더. previousMode / newMode 코드 → 한국어 라벨로 치환.
  /// 푸시·인앱 알림 양쪽에 동일하게 사용. 사유 본문은 별도 필드(overrideReason)로 분리.
  static String buildAdminOverrideListingModeBody(
    String previousMode,
    String newMode,
  ) {
    final String prev = listingModeLabel(previousMode);
    final String next = listingModeLabel(newMode);
    return adminOverrideListingModeNotificationBodyTemplate
        .replaceAll('{prev}', prev)
        .replaceAll('{next}', next);
  }

  /// `listing_mode_changed` audit 의 inputs.newMode → 한국어 자연어 라벨.
  /// 예: 'exclusive' → '한두 명만으로 변경', 'open' → '모든 중개사로 변경'.
  static String listingHistoryDirectionLabel(String? newMode) {
    switch (newMode) {
      case 'exclusive':
        return listingHistoryToExclusive;
      case 'open':
        return listingHistoryToOpen;
      default:
        // 폴백: 코드 raw 노출 차단 — 일반 라벨로.
        return auditEventLabel('listing_mode_changed');
    }
  }

  /// listingMode 코드 → 한국어 라벨.
  static String listingModeLabel(String? mode) {
    switch (mode) {
      case 'exclusive':
        return '단독 지정';
      case 'open':
      default:
        return '모든 중개사 공개';
    }
  }

  // === Task 08: 단순성 원칙 (80세 노인 테스트) — 횡단 적용 ===
  //
  // 본 블록은 화면 raw 문자열을 docs/common/copy-deck.md 의 통일 라벨로 끌어올린
  // *재정렬* 카피이다. 새 정책 0건. 기존 위반 라인을 일상 한국어로 교체.
  //
  // 운영자 화면(lib/screens/admin/*) 은 본 블록 대상 외 (copy-deck §6).

  // 중개사 대시보드 — 매수 손님 탭 (구 "매수자 매칭")
  static const String brokerTabBuyerLeads = '매수 손님';
  static const String brokerBuyerLeadsEmpty = '아직 연결된 매수 손님이 없어요';
  static const String brokerBuyerLeadsHint = '매수자가 임장 신청을 하면 여기에 표시됩니다';

  // 중개사 대시보드 — 알림/리스트 보조 라벨 (구 "우선권 부여됨")
  static const String brokerNotificationGrantIssuedSuffix = '내 차례 받음';

  // 이의 제기 입력 가드 (구 "먼저 대상 우선권을 골라주세요")
  static const String appealSelectGrantPrompt = '어느 매물 차례에 대해 신청할지 골라주세요';

  // 이의 제기 빈 상태 (구 "지금 신청할 수 있는 우선권이 없어요.")
  static const String appealNoEligibleGrants = '지금 신청할 수 있는 맡은 매물이 없어요';

  // 이의 제기 드롭다운 라벨 (구 "대상 우선권")
  static const String appealTargetLabel = '신청할 매물';

  // === Problem 004 §2.5.1: 매도자 측 이의 제기 진입점 (옵션 A 일반화) ===
  //
  // PriorityAppealPage 가 broker / seller 양 actor 호출이라
  // role == seller 분기에서 사용할 카피 4종.
  // 80세 화법 — "차례", "이 결정", "이상하다", "다시 한 번 계산" 일상 한국어.
  // copy-deck §2.7 동기.
  static const String appealNoEligibleGrantsForSeller =
      '이 매물에 아직 차례를 받은 분이 없어요';
  static const String sellerAppealTargetLabel = '어느 매물에 대해 신청할까요';
  static const String auditRowAppealActionLabel = '이상해요로 알리기';
  static const String auditRowAppealConfirmTitle =
      '이 결정이 이상하다고 알리시겠어요?';
  static const String auditRowAppealConfirmBody =
      '받은 신청은 자동으로 다시 한 번 계산해 봅니다. 결과는 알림으로 알려드릴게요.';

  // 이의 제기 입력 길이 안내 (사유 코드 raw 노출 차단)
  static String appealReasonTooLong(int maxLength) =>
      '이유는 최대 $maxLength자까지 적을 수 있어요';

  // 통신 실패 폴백 (사유 코드 raw 노출 차단)
  static const String genericRetryNotice = '잠시 후 다시 시도해 주세요';

  // === Task 08 §5.4 #29: PriorityHolderSection viewerRole 분기 카피 ===
  //
  // priority_holder_section.dart 가 매도자 외 시야(broker/public)에 *재사용*
  // 될 때 노출할 대체 라벨. copy-deck §5 정책상 "우선권" 단어는 매도자 사실
  // 통지 라인 외 금지이므로, broker/public 시야에서는 본 const 로 대체한다.
  //
  // - 'broker' 시야: 담당 중개사가 *다른 분*일 때 "현재 맡은 분이 있어요"
  //   (자기 자신이면 GrantMessages.badgeMineActive='내 차례' 사용)
  // - 'public' 시야: 비식별 집계만 — "참여 중인 중개사 N명"
  //   (M2 비식별 정책 [Task 05 §5.1] 준수, displayName 노출 0)

  // 중개사 시야 — 보유자 강조 대체 (담당이 본인이 아닐 때)
  static const String holderBadgeForBrokerView = '현재 맡은 분이 있어요';

  // 비로그인 공개 시야 — 집계만 (N은 인자)
  static String holderBadgeForPublicView(int count) =>
      '참여 중인 중개사 $count명';

  // === P2-4: scoringInputs 기반 거절 사유 인간 화법 변환 ===
  //
  // Task 02 §5.5 #8 — `priority_grants.scoringInputs` 의 *내부 감사 데이터* 를
  // 80세 노인 화법으로 1줄 변환. 점수·% 노출 0건. score_below_threshold 사유
  // 발생 시 functions/index.js 가 error message 에 첨부한 `inputs:k=v;...` 를
  // 클라이언트가 [extractScoringInputs] 로 파싱 → [describeScoringFailure] 로
  // 가장 큰 부족 요인 1개를 골라 SnackBar 노출.
  //
  // 정책 출처: copy-deck §3.1 (사유 코드 26종 표 외 보조 분석 카피).
  // 점수/가중치/% 노출 0
  // "가중치"/"점수" 단어 0
  // 영문 식별자 0
  // 원인 + 해결법 (Task 08 §3.7)
  // 한 줄 50자 이내

  static const String scoringFailJurisdiction =
      '내 영업 지역이 아니에요 — 본인 영업 지역만 받을 수 있어요';
  static const String scoringFailLicense =
      '면허 확인이 안 되어서 받기 어려워요';
  static const String scoringFailCap = '이미 5개를 맡고 있어요';
  static const String scoringFailActivity =
      '최근 활동이 부족해요 — 받은 매물 활동을 진행하면 다음 차례에 유리해요';
  static const String scoringFailDistance =
      '매물에서 너무 멀어요 — 가까운 매물부터 받아보세요';
  static const String scoringFailTime =
      '먼저 받은 분들이 있어요 — 다음 새 매물을 빠르게 받아보세요';
  static const String scoringFailGeneric = '아직 받기 어려워요';

  /// `priority_grants.scoringInputs` (또는 백엔드가 error message 에 첨부한
  /// `rawInputs` 분석 데이터) 를 받아 *가장 큰 부족 요인 1줄* 노인 화법으로 변환.
  ///
  /// 입력 키 (모두 0~1 정규화):
  ///   - `jurisdictionMatch` (bool 또는 0/1) — 지역 관할 일치 여부
  ///   - `licenseStatus` (string 'verified' 외) 또는 `license` (0~1)
  ///   - `capHeadroom` (0~1) — 0 이면 cap 도달
  ///   - `activityScore` 또는 `activity` (0~1)
  ///   - `distanceKm` 또는 `distance` (0~1, 1이 가까움)
  ///   - `timeRank` 또는 `time` (0~1, 1이 가장 빠름)
  ///
  /// 우선순위: jurisdiction → license → cap → activity → distance → time → 일반.
  /// (가장 *치명적* 인 결격부터 안내.)
  ///
  /// 점수 *값* 자체는 절대 노출하지 않는다.
  static String describeScoringFailure(Map<String, dynamic>? scoringInputs) {
    if (scoringInputs == null || scoringInputs.isEmpty) {
      return scoringFailGeneric;
    }

    // rawInputs 가 nested 로 들어온 경우(서버 직렬 형식) 평탄화.
    final Map<String, dynamic> raw = scoringInputs['rawInputs'] is Map
        ? Map<String, dynamic>.from(scoringInputs['rawInputs'] as Map)
        : scoringInputs;

    // 1) 지역 관할 — 가장 치명적.
    final dynamic jurisdiction =
        raw['jurisdictionMatch'] ?? raw['jurisdiction'];
    final bool jurisdictionFailed =
        jurisdiction == false || jurisdiction == 0 || jurisdiction == 0.0;
    if (jurisdictionFailed) return scoringFailJurisdiction;

    // 2) 면허 — verified 가 아니면 결격.
    final dynamic license = raw['licenseStatus'] ?? raw['license'];
    final bool licenseFailed = license is String
        ? license != 'verified'
        : (license is num && license < 1.0);
    if (licenseFailed && license != null) return scoringFailLicense;

    // 3) cap — 0 이면 한도 도달.
    final dynamic capRaw = raw['capHeadroom'];
    if (capRaw is num && capRaw <= 0) return scoringFailCap;

    // 4) activity — 0.3 미만이면 활동 부족.
    final dynamic activityRaw = raw['activityScore'] ?? raw['activity'];
    if (activityRaw is num && activityRaw < 0.3) return scoringFailActivity;

    // 5) distance — 0.3 미만이면 너무 멀다.
    final dynamic distanceRaw = raw['distance'] ?? raw['distanceKm'];
    if (distanceRaw is num && distanceRaw < 0.3) return scoringFailDistance;

    // 6) time — 0.3 미만이면 늦은 참여.
    final dynamic timeRaw = raw['timeRank'] ?? raw['time'];
    if (timeRaw is num && timeRaw < 0.3) return scoringFailTime;

    return scoringFailGeneric;
  }

  /// HttpsError message 형식 `'<reason>: <text> | inputs:k=v;k=v;...'` 에서
  /// `inputs:` 뒤 `k=v` 페어를 파싱해 `Map<String, dynamic>` 으로 반환.
  ///
  /// 값 파싱 규칙:
  ///   - 'true'/'false' → bool
  ///   - 숫자 문자열 → double
  ///   - 그 외 → String
  ///
  /// 매칭이 없으면 빈 Map 반환.
  static Map<String, dynamic> extractScoringInputs(String? errorMessage) {
    if (errorMessage == null || errorMessage.isEmpty) {
      return <String, dynamic>{};
    }
    final RegExpMatch? match =
        RegExp(r'inputs:([^|]+)').firstMatch(errorMessage);
    if (match == null) return <String, dynamic>{};
    final String body = match.group(1)!.trim();
    final Map<String, dynamic> result = <String, dynamic>{};
    for (final String pair in body.split(';')) {
      final int eqIdx = pair.indexOf('=');
      if (eqIdx <= 0) continue;
      final String key = pair.substring(0, eqIdx).trim();
      final String value = pair.substring(eqIdx + 1).trim();
      if (key.isEmpty) continue;
      if (value == 'true') {
        result[key] = true;
      } else if (value == 'false') {
        result[key] = false;
      } else {
        final double? asDouble = double.tryParse(value);
        result[key] = asDouble ?? value;
      }
    }
    return result;
  }

  // === Task 003: 중개사 영업 동네(jurisdictions) 셀프-서비스 ===
  //
  // 80세 노인 테스트 — "관할", "행정구역", "법정동", "코드" 한자어 노출 0.
  // 화면에는 "동네", "지역", "시·군·구" 만 사용. copy-deck.md §JurisdictionPicker 동기.

  /// 본인 정보 페이지 + 대시보드 헤더 — jurisdictions 가 비어있을 때 노출.
  /// 30자 이내 한 줄. 60세 이상도 3초 안에 의미 이해.
  static const String jurisdictionEmptyBanner =
      '영업 지역을 등록해야 매물을 받을 수 있어요';

  /// 빈 상태 배너의 행동 버튼 라벨.
  static const String jurisdictionEmptyBannerCta = '지금 등록하기';

  /// 본인 정보 페이지 — 영업 지역 섹션 헤더.
  static const String jurisdictionSectionTitle = '영업 가능 지역';

  /// 본인 정보 페이지 — 섹션 부가 안내 (한 줄).
  static const String jurisdictionSectionHint =
      '내가 영업할 동네를 골라주세요. 최대 5개까지 고를 수 있어요';

  /// "지역 추가/편집" 버튼 라벨 (섹션 안 + 빈 상태 배너 모두 공유).
  static const String jurisdictionEditCta = '지역 추가/편집';

  /// 저장 성공 SnackBar — race 완화 안내 포함 (트리거 비동기).
  static const String jurisdictionSaved =
      '영업 지역이 저장되었어요. 최대 30초 안에 반영돼요';

  /// 저장 실패 SnackBar — 원인 + 해결법 (사유 코드 raw 노출 0).
  static const String jurisdictionSaveFailed =
      '저장 중 문제가 있어요. 잠시 후 다시 해 주세요';

  /// 가입 폼 — 영업 지역 섹션 라벨 (필수 표시 *는 화면에서 추가).
  static const String jurisdictionSignupLabel = '주 영업 지역';

  /// 가입 폼 — 영업 지역 미선택 에러.
  static const String jurisdictionSignupRequired =
      '영업 가능 지역을 1개 이상 골라주세요';

  /// 가입 폼 — 미선택 상태 빈 placeholder.
  static const String jurisdictionSignupEmptyPlaceholder = '아직 고른 지역이 없어요';

  // === Task 001: 중개사 인증 신청·승인 ===
  //
  // 80세 노인 테스트 통과 — 영문 식별자 0, 한자어 최소화, 한 줄 ≤ 30자.
  // copy-deck.md §6.1 (운영자→사용자 통지 가이드) 동기.
  // 3-레이어 동기: callable error message ↔ 본 상수 ↔ copy-deck.

  // 신청 페이지 (broker_verification_apply_page.dart)
  static const String verifyApplyTitle = '인증 신청';
  static const String verifyApplyHelper =
      '사무소 정보를 확인했어요. 영업하시는 동네만 골라 주시면 신청이 끝나요.';
  static const String verifyApplySubmit = '신청 보내기';
  static const String verifyApplySuccessTitle = '신청을 받았어요';
  static const String verifyApplySuccessBody =
      '관리자가 확인하면 알림으로 알려드릴게요. 보통 1영업일 안에 끝나요.';
  static const String verifyDuplicatePending = '이미 신청이 접수되었어요';

  // 상태 배너 (broker_verification_status_banner.dart)
  static const String verifyBannerPending = '신청을 받았어요. 관리자 확인 중입니다.';
  static const String verifyBannerRejectedPrefix = '다시 신청해 주세요. ';
  static const String verifyBannerApprovedToast = '인증이 끝났어요. 매물을 받을 수 있어요.';
  static const String verifyBannerRetryButton = '다시 신청';

  // 관리자 카피 (admin_broker_management.dart 인증 신청 탭)
  // copy-deck §6 운영자 화면 별도 룰 적용 — admin 화법 OK.
  // 단, 반려 사유 placeholder 는 *사용자 노출 카피* 가이드 (§6.1) 톤으로 작성.
  static const String verifyAdminApprove = '승인';
  static const String verifyAdminReject = '반려';
  static const String verifyAdminRejectReasonLabel = '반려 사유';
  static const String verifyAdminRejectReasonPlaceholder =
      '예: 면허번호가 등록증 사진과 달라요. 다시 확인 후 신청 부탁드립니다.';
  static const String verifyAdminApproveSuccess = '승인되었어요';
  static const String verifyAdminRejectSuccess = '반려되었어요';
  static const String verifyAdminPendingCount = '인증 신청 대기';
}
