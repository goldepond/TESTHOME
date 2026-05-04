import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/constants/grant_messages.dart';
import 'package:property/constants/spacing.dart';
import 'package:property/constants/typography.dart';
import 'package:property/models/priority_grant.dart';

/// 우선권 상태 뱃지.
///
/// 80세 노인 테스트: 점수·가중치·전문용어 절대 노출 금지.
/// 활성 grant·본인 여부·자격 여부에 따라 4가지 상태로 표현한다.
class PriorityGrantBadge extends StatelessWidget {
  /// 뱃지에 표시할 라벨 (예: '내 차례', '받을 수 있어요').
  final String label;

  /// 뱃지 배경/테두리 색상.
  final Color color;

  /// 뱃지 텍스트 색상.
  final Color textColor;

  /// 잔여일 보조 텍스트 (있을 때만 표시).
  final String? trailing;

  const PriorityGrantBadge({
    required this.label,
    required this.color,
    required this.textColor,
    super.key,
    this.trailing,
  });

  /// 활성 grant 목록과 현재 사용자 정보를 받아 적절한 상태 뱃지를 만든다.
  ///
  /// - 본인 활성 grant 있음 → '내 차례' (녹색)
  /// - 다른 사람 활성 grant 있음 → '다른 분이 맡는 중' (회색 + 잔여일)
  /// - 활성 grant 없음 + 자격 있음 → '받을 수 있어요' (코랄)
  /// - 활성 grant 없음 + 자격 없음 → '받을 수 없어요' (회색)
  factory PriorityGrantBadge.fromGrants({
    required List<PriorityGrant> activeGrants,
    required String currentBrokerUid,
    Key? key,
    bool currentUserEligible = true,
  }) {
    // 활성 상태인 grant만 추린다.
    final List<PriorityGrant> activeOnly = activeGrants
        .where((PriorityGrant g) => g.status == PriorityGrantStatus.active)
        .toList();

    if (activeOnly.isEmpty) {
      if (currentUserEligible) {
        return PriorityGrantBadge(
          key: key,
          label: GrantMessages.badgeOpen,
          color: AirbnbColors.primary,
          textColor: AirbnbColors.textWhite,
        );
      }
      return PriorityGrantBadge(
        key: key,
        label: GrantMessages.badgeNotEligible,
        color: AirbnbColors.borderLight,
        textColor: AirbnbColors.textSecondary,
      );
    }

    // 활성 grant 중 본인 명의가 있는지 확인.
    PriorityGrant? mine;
    for (final PriorityGrant g in activeOnly) {
      if (g.brokerUid == currentBrokerUid) {
        mine = g;
        break;
      }
    }

    if (mine != null) {
      final int days = mine.expiresAt.difference(DateTime.now()).inDays;
      return PriorityGrantBadge(
        key: key,
        label: GrantMessages.badgeMineActive,
        color: AirbnbColors.success,
        textColor: AirbnbColors.textWhite,
        trailing: GrantMessages.describeDaysLeft(days),
      );
    }

    // 다른 중개사가 맡고 있음 — 가장 최근 grant의 잔여일을 보조로 보여준다.
    final PriorityGrant other = activeOnly.first;
    final int days = other.expiresAt.difference(DateTime.now()).inDays;
    return PriorityGrantBadge(
      key: key,
      label: GrantMessages.badgeOtherActive,
      color: AirbnbColors.borderLight,
      textColor: AirbnbColors.textSecondary,
      trailing: GrantMessages.describeDaysLeft(days),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: AppTypography.withColor(AppTypography.caption, textColor)
                .copyWith(fontWeight: FontWeight.w600),
          ),
          if (trailing != null && trailing!.isNotEmpty) ...<Widget>[
            const SizedBox(width: AppSpacing.xs),
            Text(
              '· $trailing',
              style: AppTypography.withColor(AppTypography.caption, textColor),
            ),
          ],
        ],
      ),
    );
  }
}
