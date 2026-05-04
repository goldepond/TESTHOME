import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/constants/grant_messages.dart';
import 'package:property/constants/spacing.dart';
import 'package:property/constants/typography.dart';
import 'package:property/models/priority_grant.dart';
import 'package:property/utils/logger.dart';

/// 호출 시야 — Task 08 §5.4 #29: 매도자 전용 가드.
///
/// [PriorityHolderSection] 위젯은 *매도자 시야* 카드로 만들어졌으나, 향후
/// 위젯이 broker/public 자리에 재사용될 가능성을 *컴파일 타임에 차단*하기
/// 위해 호출자에게 시야를 명시적으로 선언하도록 강제한다.
///
/// - [seller]: 매도자 대시보드 (현재 유일한 의도된 호출 시야)
/// - [broker]: 중개사 대시보드 — copy-deck §5 정책상 "우선권" 단어 금지,
///   대체 라벨([GrantMessages.holderBadgeForBrokerView]) 사용.
/// - [publicView]: 비로그인 공개 페이지 — M2 비식별 정책상 displayName
///   노출 금지, 집계만([GrantMessages.holderBadgeForPublicView]).
enum PriorityHolderViewerRole {
  seller,
  broker,
  publicView,
}

/// 매도자 대시보드용 "이 매물을 맡고 있는 분" 카드 섹션.
///
/// 80세 노인 테스트: 점수·가중치·전문용어 절대 노출 금지.
/// M2 비식별 원칙: 중개사 실명 대신 공개 표시명만 노출, 없으면 마스킹.
///
/// Task 03 — [grantType]을 지정하면 해당 타입의 활성 grant만 표시.
/// `seller_match`(M1.1) / `buyer_match`(M1.2) / null(레거시 — 첫 번째 active grant).
///
/// Task 08 §5.4 #29 — [viewerRole] 필수. 매도자 외 시야는 카피가 자동 분기되며,
/// copy-deck §5 ("우선권" 단어 정책) 위반을 컴파일 타임에 차단한다.
class PriorityHolderSection extends StatefulWidget {
  /// 표시 대상 매물 ID (mlsProperties/{id}).
  final String propertyId;

  /// 호출 시야 — 매도자/중개사/비로그인 공개. required.
  final PriorityHolderViewerRole viewerRole;

  /// 표시할 grant 타입. null이면 type 무관 첫 active grant.
  final String? grantType;

  /// 카드 제목 오버라이드 (생략 시 기본 카피).
  final String? titleOverride;

  /// 빈 상태 카피 오버라이드 (생략 시 기본 카피).
  final String? emptyOverride;

  const PriorityHolderSection({
    required this.propertyId,
    required this.viewerRole,
    super.key,
    this.grantType,
    this.titleOverride,
    this.emptyOverride,
  });

  @override
  State<PriorityHolderSection> createState() => _PriorityHolderSectionState();
}

class _PriorityHolderSectionState extends State<PriorityHolderSection> {
  late Future<_HolderViewModel> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadHolder();
  }

  /// 활성 grant 1건 + 해당 broker_participations.displayName을 비동기로 가져온다.
  Future<_HolderViewModel> _loadHolder() async {
    try {
      final FirebaseFirestore db = FirebaseFirestore.instance;
      Query<Map<String, dynamic>> q = db
          .collection('priority_grants')
          .where('propertyId', isEqualTo: widget.propertyId)
          .where('status', isEqualTo: 'active');
      if (widget.grantType != null && widget.grantType!.isNotEmpty) {
        q = q.where('type', isEqualTo: widget.grantType);
      }
      final QuerySnapshot<Map<String, dynamic>> grantsSnap =
          await q.limit(1).get();

      if (grantsSnap.docs.isEmpty) {
        return const _HolderViewModel.empty();
      }

      final PriorityGrant grant =
          PriorityGrant.fromFirestore(grantsSnap.docs.first);

      // 라운드 2D P1-5: broker_participations 원본은 Rules `if false` 로
      // 직접 read 차단. 비식별 미러 (broker_participations_public) 에서
      // displayName 만 조회한다. 미러는 docId 가 원본과 동일 (brokerId 키).
      String? displayName;
      try {
        final DocumentSnapshot<Map<String, dynamic>> partDoc = await db
            .collection('mlsProperties')
            .doc(widget.propertyId)
            .collection('broker_participations_public')
            .doc(grant.brokerId)
            .get();
        final Map<String, dynamic>? data = partDoc.data();
        if (data != null) {
          final dynamic raw = data['displayName'];
          if (raw is String && raw.isNotEmpty) {
            displayName = raw;
          }
        }
      } catch (e, stack) {
        // 서브컬렉션 조회 실패는 치명적이지 않다 — 마스킹 fallback으로 진행.
        Logger.warning(
          'broker_participations_public displayName fetch failed',
          metadata: <String, dynamic>{
            'context': 'PriorityHolderSection',
            'propertyId': widget.propertyId,
            'brokerId': grant.brokerId,
            'error': e.toString(),
            'stack': stack.toString(),
          },
        );
      }

      return _HolderViewModel(grant: grant, displayName: displayName);
    } catch (e, stack) {
      Logger.error(
        'PriorityHolderSection load failed',
        error: e,
        stackTrace: stack,
        context: 'PriorityHolderSection',
        metadata: <String, dynamic>{'propertyId': widget.propertyId},
      );
      return const _HolderViewModel.empty();
    }
  }

  /// 단계별 "남은 일" 안내 카피.
  String _activityNotice(PriorityGrantStage stage) {
    switch (stage) {
      case PriorityGrantStage.participation:
        return GrantMessages.sellerActivityRemainingParticipation;
      case PriorityGrantStage.visit:
        return GrantMessages.sellerActivityRemainingVisit;
      case PriorityGrantStage.offer:
        return GrantMessages.sellerActivityRemainingOffer;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HolderViewModel>(
      future: _future,
      builder: (BuildContext context,
          AsyncSnapshot<_HolderViewModel> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildShell(
            child: const SizedBox(
              height: 48,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          );
        }

        final _HolderViewModel vm = snapshot.data ?? const _HolderViewModel.empty();
        if (vm.grant == null) {
          return _buildShell(child: _buildEmpty());
        }

        return _buildShell(child: _buildFilled(vm));
      },
    );
  }

  /// 카드 외곽 데코레이션 (공통).
  Widget _buildShell({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AirbnbColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AirbnbColors.border),
        boxShadow: <BoxShadow>[AirbnbColors.cardShadowSubtle],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            widget.titleOverride ?? GrantMessages.sellerHolderSectionTitle,
            style: AppTypography.withColor(
              AppTypography.h4,
              AirbnbColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Text(
        widget.emptyOverride ?? GrantMessages.sellerHolderSectionEmpty,
        style: AppTypography.withColor(
          AppTypography.body,
          AirbnbColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildFilled(_HolderViewModel vm) {
    final PriorityGrant g = vm.grant!;
    final int days = g.expiresAt.difference(DateTime.now()).inDays;

    // viewerRole에 따라 노출 카피·식별 정보 분기.
    // copy-deck §5: "우선권" 단어는 매도자 사실 통지 라인만 허용.
    switch (widget.viewerRole) {
      case PriorityHolderViewerRole.seller:
        return _buildSellerView(g, vm.displayName, days);
      case PriorityHolderViewerRole.broker:
        return _buildBrokerView(g, days);
      case PriorityHolderViewerRole.publicView:
        return _buildPublicView();
    }
  }

  /// 매도자 시야 — 실명/공개 표시명 노출 가능 (자기 매물의 사실 통지).
  Widget _buildSellerView(PriorityGrant g, String? displayName, int days) {
    final String name = (displayName != null && displayName.isNotEmpty)
        ? displayName
        : '○○○ 중개사';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          name,
          style: AppTypography.withColor(
            AppTypography.h4,
            AirbnbColors.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${GrantMessages.describeStage(g.stage.name)} · ${GrantMessages.describeDaysLeft(days)}',
          style: AppTypography.withColor(
            AppTypography.bodySmall,
            AirbnbColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AirbnbColors.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _activityNotice(g.stage),
            style: AppTypography.withColor(
              AppTypography.bodySmall,
              AirbnbColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          GrantMessages.sellerAutoExpireNotice,
          style: AppTypography.withColor(
            AppTypography.caption,
            AirbnbColors.textLight,
          ),
        ),
      ],
    );
  }

  /// 중개사 시야 — "우선권" 단어 금지, displayName도 노출 X (담당이 본인인지
  /// 모르는 자리에서는 추가 식별 정보를 주지 않음).
  Widget _buildBrokerView(PriorityGrant g, int days) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          GrantMessages.holderBadgeForBrokerView,
          style: AppTypography.withColor(
            AppTypography.body,
            AirbnbColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          GrantMessages.describeDaysLeft(days),
          style: AppTypography.withColor(
            AppTypography.bodySmall,
            AirbnbColors.textSecondary,
          ),
        ),
      ],
    );
  }

  /// 비로그인 공개 시야 — M2 비식별 정책: displayName/grant 단계 등 일체 노출 X.
  /// 활성 grant 존재만 *집계* 형태로 알림. count는 priority_holder_section
  /// 자체가 1건만 조회하므로 1로 고정 — 실제 누적 카운트는 상위 위젯에서
  /// 별도 집계 후 [holderBadgeForPublicView] 직접 호출 권장.
  Widget _buildPublicView() {
    return Text(
      GrantMessages.holderBadgeForPublicView(1),
      style: AppTypography.withColor(
        AppTypography.body,
        AirbnbColors.textSecondary,
      ),
    );
  }
}

/// 내부 view-model — 활성 grant 1건과 그 broker의 공개 표시명을 묶는다.
class _HolderViewModel {
  final PriorityGrant? grant;
  final String? displayName;

  const _HolderViewModel({
    required this.grant,
    required this.displayName,
  });

  const _HolderViewModel.empty()
      : grant = null,
        displayName = null;
}
