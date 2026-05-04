import 'package:flutter/material.dart';
import 'package:property/api_request/priority_grant_service.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/constants/grant_messages.dart';
import 'package:property/constants/spacing.dart';
import 'package:property/constants/typography.dart';
import 'package:property/models/priority_grant.dart';
import 'package:property/utils/cloud_functions_guard.dart';

/// 5개 한도 도달 시 "어떤 매물을 놓을까요?" 선택 다이얼로그.
///
/// 80세 노인 테스트: 점수·가중치·전문용어 절대 노출 금지.
/// 사용자는 본인이 맡고 있는 활성 grant 중 1건을 골라 자진 만료(revoke)한다.
class PriorityCapDialog extends StatefulWidget {
  /// 본인이 보유한 활성 grant 목록 (5개).
  final List<PriorityGrant> myActiveGrants;

  /// 선택된 grant를 자진 만료하는 콜백.
  /// 일반적으로 [PriorityGrantService.revokeOwnGrantViaFunction]을 호출한다.
  final Future<void> Function(String grantId) onRevoke;

  const PriorityCapDialog({
    required this.myActiveGrants,
    required this.onRevoke,
    super.key,
  });

  /// 다이얼로그를 띄우고 revoke 성공 시 true를 반환한다.
  ///
  /// 취소·실패 시에는 false 또는 null이 반환될 수 있다.
  static Future<bool> show({
    required BuildContext context,
    required List<PriorityGrant> myActiveGrants,
    required Future<void> Function(String grantId) onRevoke,
  }) async {
    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) => PriorityCapDialog(
        myActiveGrants: myActiveGrants,
        onRevoke: onRevoke,
      ),
    );
    return result ?? false;
  }

  @override
  State<PriorityCapDialog> createState() => _PriorityCapDialogState();
}

class _PriorityCapDialogState extends State<PriorityCapDialog> {
  String? _selectedGrantId;
  bool _isProcessing = false;

  Future<void> _handleRelease() async {
    final String? grantId = _selectedGrantId;
    if (grantId == null) return;

    setState(() => _isProcessing = true);
    try {
      await widget.onRevoke(grantId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on CloudFunctionsUserFacingException catch (e) {
      // problem 002 가드 — NOT_FOUND 등은 한국어 카피로 변환된 상태로 도착.
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.userMessage),
          backgroundColor: AirbnbColors.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      final String? code = GrantMessages.extractReasonCode(e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(GrantMessages.describeReason(code)),
          backgroundColor: AirbnbColors.error,
        ),
      );
    }
  }

  String _summarize(PriorityGrant g) {
    final String shortId = g.propertyId.length >= 6
        ? g.propertyId.substring(g.propertyId.length - 6)
        : g.propertyId;
    final int days = g.expiresAt.difference(DateTime.now()).inDays;
    final String stage = GrantMessages.describeStage(g.stage.name);
    return '매물 …$shortId · $stage · ${GrantMessages.describeDaysLeft(days)}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      backgroundColor: AirbnbColors.background,
      title: Text(
        GrantMessages.capDialogTitle,
        style: AppTypography.withColor(
          AppTypography.h4,
          AirbnbColors.textPrimary,
        ),
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              GrantMessages.capDialogBody,
              style: AppTypography.withColor(
                AppTypography.body,
                AirbnbColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Flexible(
              child: RadioGroup<String>(
                groupValue: _selectedGrantId,
                onChanged: (String? v) {
                  if (_isProcessing) return;
                  setState(() => _selectedGrantId = v);
                },
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.myActiveGrants.length,
                  itemBuilder: (BuildContext _, int index) {
                    final PriorityGrant g = widget.myActiveGrants[index];
                    return RadioListTile<String>(
                      value: g.id,
                      activeColor: AirbnbColors.primary,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(
                        _summarize(g),
                        style: AppTypography.withColor(
                          AppTypography.bodySmall,
                          AirbnbColors.textPrimary,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              GrantMessages.capDialogCooldownNotice,
              style: AppTypography.withColor(
                AppTypography.caption,
                AirbnbColors.textLight,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isProcessing
              ? null
              : () => Navigator.of(context).pop(false),
          child: Text(
            GrantMessages.actionCancel,
            style: AppTypography.withColor(
              AppTypography.button,
              AirbnbColors.textSecondary,
            ),
          ),
        ),
        if (_isProcessing)
          const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          ElevatedButton(
            onPressed: _selectedGrantId == null ? null : _handleRelease,
            style: ElevatedButton.styleFrom(
              backgroundColor: AirbnbColors.primary,
              foregroundColor: AirbnbColors.textWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              GrantMessages.actionReleaseHold,
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
