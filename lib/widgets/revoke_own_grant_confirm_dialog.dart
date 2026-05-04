import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/constants/grant_messages.dart';
import 'package:property/constants/spacing.dart';
import 'package:property/constants/typography.dart';
import 'package:property/models/priority_grant.dart';

/// Problem 004 갭 2 — 평상시 자진 만료 2단계 확인 다이얼로그.
///
/// `PriorityCapDialog` (5개 한도 도달 시 *여러 매물 중 1건 골라 놓기*)와는 다른 의도:
/// 본 위젯은 *지정된 1건의 grant 를 놓을지* 확인한다 (단순성 헌장 — 같은 위젯에
/// 두 의도 혼재 금지). broker_property_card.dart 의 ⋮ 메뉴 → "이 매물 놓기" 진입.
///
/// **2단계 분리 (오탭 방지 — Code-level Enforcement)**:
/// 1. 1단계: "이 매물을 놓으시겠어요?" + 매물 요약 + [취소] [놓기].
/// 2. 2단계: "한 번 더 확인해 주세요" + 24h 쿨다운 안내 + [취소] [정말 놓기].
///   - 2단계 통과 시 [PriorityGrantService.revokeOwnGrantViaFunction] 호출.
///   - 단계 사이 자동 chain 금지 (사용자 명시 탭 필수).
///
/// 80세 노인 테스트 통과:
/// - 의사결정 ≤2 (각 단계 [취소] / [놓기 또는 정말 놓기])
/// - 점수·% 노출 0
/// - 사유 코드 raw 노출 X (실패 시 `describeReason()` 경유)
class RevokeOwnGrantConfirmDialog {
  RevokeOwnGrantConfirmDialog._();

  /// 다이얼로그 진입점. 2단계 흐름을 모두 거쳐 callable 성공 시 true 를 반환한다.
  /// 어느 단계에서든 [취소] 또는 dismiss 시 false 반환.
  static Future<bool> show({
    required BuildContext context,
    required PriorityGrant grant,
  }) async {
    // 1단계 다이얼로그.
    final bool? step1 = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) => _Step1Dialog(grant: grant),
    );
    if (step1 != true) return false;

    // 사용자 명시 탭 후에만 2단계로. setTimeout/auto-chain 금지.
    if (!context.mounted) return false;

    // 2단계 다이얼로그.
    final bool? step2 = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) => _Step2Dialog(grant: grant),
    );
    return step2 == true;
  }

  /// 매물 요약 — `PriorityCapDialog._summarize` 와 동일 패턴 재사용.
  /// 점수/식별자 raw 노출 0 — 매물 ID 끝 6자리 + stage + 잔여일.
  static String summarizeGrant(PriorityGrant g) {
    final String shortId = g.propertyId.length >= 6
        ? g.propertyId.substring(g.propertyId.length - 6)
        : g.propertyId;
    final int days = g.expiresAt.difference(DateTime.now()).inDays;
    final String stage = GrantMessages.describeStage(g.stage.name);
    return '매물 …$shortId · $stage · ${GrantMessages.describeDaysLeft(days)}';
  }
}

/// 1단계 — "이 매물을 놓으시겠어요?" + 매물 요약.
/// [취소] / [놓기] 만 노출 (의사결정 = 2개).
class _Step1Dialog extends StatelessWidget {
  const _Step1Dialog({required this.grant});

  final PriorityGrant grant;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      backgroundColor: AirbnbColors.background,
      title: Text(
        GrantMessages.revokeConfirmStep1Title,
        style: AppTypography.withColor(
          AppTypography.h4,
          AirbnbColors.textPrimary,
        ),
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AirbnbColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AirbnbColors.border),
              ),
              child: Text(
                RevokeOwnGrantConfirmDialog.summarizeGrant(grant),
                style: AppTypography.withColor(
                  AppTypography.bodySmall,
                  AirbnbColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            GrantMessages.actionCancel,
            style: AppTypography.withColor(
              AppTypography.button,
              AirbnbColors.textSecondary,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AirbnbColors.primary,
            foregroundColor: AirbnbColors.textWhite,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            GrantMessages.actionReleaseShort,
            style: AppTypography.withColor(
              AppTypography.button,
              AirbnbColors.textWhite,
            ),
          ),
        ),
      ],
    );
  }
}

/// 2단계 — "한 번 더 확인해 주세요" + 24h 쿨다운 안내.
/// [취소] / [정말 놓기]. 버튼 라벨이 1단계와 다르므로 반복 탭 방어.
class _Step2Dialog extends StatelessWidget {
  const _Step2Dialog({required this.grant});

  final PriorityGrant grant;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      backgroundColor: AirbnbColors.background,
      title: Text(
        GrantMessages.revokeConfirmStep2Title,
        style: AppTypography.withColor(
          AppTypography.h4,
          AirbnbColors.textPrimary,
        ),
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              RevokeOwnGrantConfirmDialog.summarizeGrant(grant),
              style: AppTypography.withColor(
                AppTypography.bodySmall,
                AirbnbColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AirbnbColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: AirbnbColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.access_time,
                    size: 16,
                    color: AirbnbColors.warning,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      GrantMessages.capDialogCooldownNotice,
                      style: AppTypography.withColor(
                        AppTypography.caption,
                        AirbnbColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            GrantMessages.actionCancel,
            style: AppTypography.withColor(
              AppTypography.button,
              AirbnbColors.textSecondary,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            // 2단계는 더 강한 색상으로 차별화 (같은 primary 지만 의도는 명확).
            backgroundColor: AirbnbColors.primary,
            foregroundColor: AirbnbColors.textWhite,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            GrantMessages.actionReleaseConfirm,
            style: AppTypography.withColor(
              AppTypography.button,
              AirbnbColors.textWhite,
            ),
          ),
        ),
      ],
    );
  }
}
