import 'package:flutter/material.dart';

import 'package:property/constants/app_constants.dart';
import 'package:property/constants/grant_messages.dart';
import 'package:property/constants/spacing.dart';
import 'package:property/constants/typography.dart';

/// 중개사 jurisdictions 가 비어있을 때 노출되는 경고 배너.
///
/// 사용 위치 (Task 003 §2.1.4):
///   1) 본인 정보 페이지 상단 (인증 완료 + jurisdictions 빈 상태)
///   2) 중개사 대시보드 헤더 (인증 완료 + jurisdictions 빈 상태)
///
/// **노출 가드 (호출자 책임)**:
///   - `verified == false` 인 경우는 *인증 안내 배너가 우선* — 본 배너 숨김.
///     (의사결정 1로 유지 — 80세 노인 테스트)
class JurisdictionEmptyBanner extends StatelessWidget {
  const JurisdictionEmptyBanner({
    required this.onPressEdit,
    super.key,
  });

  /// "지금 등록하기" 또는 "지역 추가/편집" 버튼을 눌렀을 때 호출.
  /// 호출자가 [showJurisdictionPicker] 다이얼로그를 띄운 후 결과를 저장한다.
  final VoidCallback onPressEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AirbnbColors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AirbnbColors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.error_outline,
            color: AirbnbColors.orange,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              GrantMessages.jurisdictionEmptyBanner,
              style: AppTypography.captionLarge.copyWith(
                color: AirbnbColors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          ElevatedButton(
            onPressed: onPressEdit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AirbnbColors.orange,
              foregroundColor: AirbnbColors.background,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              GrantMessages.jurisdictionEmptyBannerCta,
              style: AppTypography.caption.copyWith(
                color: AirbnbColors.background,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
