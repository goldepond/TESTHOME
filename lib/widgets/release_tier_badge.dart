import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/constants/grant_messages.dart';
import 'package:property/constants/typography.dart';

/// 매물 단계(Tier) 뱃지.
///
/// 중개사 카드와 매도자 대시보드에서 함께 사용한다.
/// 80세 노인 화법: '1km 신규' / '같은 동' / '인접 동' / '시·군 전체'.
/// 단독 매물(`listingMode == 'exclusive'`)은 단계 확대를 하지 않으므로 별도 라벨로 표시한다.
class ReleaseTierBadge extends StatelessWidget {
  const ReleaseTierBadge({
    required this.tier,
    super.key,
    this.listingMode,
    this.compact = true,
  });

  /// 매물의 release tier 코드 (예: 'tier1_1km'). null/빈 값이면 비표시.
  final String? tier;

  /// 매물 listing mode. 'exclusive'면 tier 무시하고 '단독 매물' 라벨 출력.
  final String? listingMode;

  /// 카드용 작은 크기 여부. 기본 true.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // 단독 매물은 tier 진행과 무관 — 단독 매물 라벨로 분기.
    if (listingMode == 'exclusive') {
      return _badge(
        GrantMessages.tierExclusiveBadgeLabel,
        AirbnbColors.textSecondary,
      );
    }
    if (tier == null || tier!.isEmpty) {
      return const SizedBox.shrink();
    }
    final String label = GrantMessages.tierBadgeLabel(tier);
    if (label.isEmpty) {
      return const SizedBox.shrink();
    }
    return _badge(label, _tierColor(tier!));
  }

  /// 신호등 3색 원칙(단순성 §3.5) — tier1=좁고 최우선(녹색),
  /// tier2=코랄(주력), tier3=경고색, tier4=평범(보조 텍스트색).
  /// AirbnbColors의 기존 시맨틱 색상만 사용한다.
  Color _tierColor(String t) {
    switch (t) {
      case 'tier1_1km':
        return AirbnbColors.green;
      case 'tier2_dong':
        return AirbnbColors.primary;
      case 'tier3_adjacent':
        return AirbnbColors.warning;
      case 'tier4_district':
        return AirbnbColors.textSecondary;
      default:
        return AirbnbColors.textSecondary;
    }
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
