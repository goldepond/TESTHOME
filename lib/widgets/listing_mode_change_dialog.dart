import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:property/api_request/mls_property_service.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/constants/grant_messages.dart';
import 'package:property/constants/typography.dart';
import 'package:property/models/mls_property.dart';
import 'package:property/utils/cloud_functions_guard.dart';
import 'package:property/utils/logger.dart';
import 'package:property/utils/snackbar_utils.dart';
import 'package:property/widgets/listing_mode_section.dart';

/// Task 07 — 매도자 대시보드/편집 화면에서 사용하는 모드 전환 다이얼로그.
///
/// 매도자가 자율적으로 매물 모드(open ↔ exclusive)를 변경한다.
/// 내부적으로 [MLSPropertyService.changeListingMode] 를 호출.
///
/// 거절 사유는 [REASON] 코드를 [GrantMessages.describeReason] 으로 한국어 매핑.
///
/// 반환값:
///   - true: 모드가 성공적으로 변경됨 (호출처가 매물 다시 fetch 또는 stream 갱신).
///   - false: 사용자 취소 또는 변경 실패.
class ListingModeChangeDialog extends StatefulWidget {
  const ListingModeChangeDialog({required this.property, super.key});

  final MLSProperty property;

  static Future<bool> show(BuildContext context, MLSProperty property) async {
    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) => ListingModeChangeDialog(property: property),
    );
    return result ?? false;
  }

  @override
  State<ListingModeChangeDialog> createState() =>
      _ListingModeChangeDialogState();
}

class _ListingModeChangeDialogState extends State<ListingModeChangeDialog> {
  final MLSPropertyService _service = MLSPropertyService();
  late String _mode;
  late List<String> _ids;
  late Map<String, String> _labels;
  bool _consent = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _mode = widget.property.listingMode;
    _ids = List<String>.from(widget.property.exclusiveBrokerIds);
    _labels = <String, String>{
      for (final String id in _ids) id: id,
    };
    // 이미 exclusive 인 경우 자율 동의는 이전에 받았으므로 기본 true.
    // open → exclusive 신규 진입 시 false 부터 시작 (자발 의사 재확인).
    _consent = _mode == 'exclusive';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(GrantMessages.listingModeChangeMenuTitle),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                widget.property.listingMode == 'exclusive'
                    ? GrantMessages.listingModeCurrentExclusive
                    : GrantMessages.listingModeCurrentOpen,
                style: AppTypography.withColor(
                  AppTypography.bodySmall,
                  AirbnbColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                GrantMessages.listingModeChangeCooldownNotice,
                style: AppTypography.caption,
              ),
              const SizedBox(height: 16),
              ListingModeSection(
                listingMode: _mode,
                exclusiveBrokerIds: _ids,
                exclusiveBrokerLabels: _labels,
                consentSelfAttested: _consent,
                onChanged: (String mode, List<String> ids,
                    Map<String, String> labels, bool consent) {
                  setState(() {
                    _mode = mode;
                    _ids = ids;
                    _labels = labels;
                    _consent = consent;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
          child: const Text(GrantMessages.actionCancel),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AirbnbColors.primary,
            foregroundColor: Colors.white,
          ),
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(GrantMessages.actionConfirm),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    // 사전 검증 — exclusive 인 경우 1~3명 + 자율 동의 필수.
    if (_mode == 'exclusive') {
      if (_ids.isEmpty) {
        AppSnackBar.info(context, GrantMessages.exclusiveAtLeastOneRequired);
        return;
      }
      if (_ids.length > 3) {
        AppSnackBar.info(context, GrantMessages.exclusiveLimitWarning);
        return;
      }
      if (!_consent) {
        AppSnackBar.info(
            context, GrantMessages.exclusiveSelfAttestationRequired);
        return;
      }
    }

    setState(() => _submitting = true);
    try {
      await _service.changeListingMode(
        propertyId: widget.property.id,
        listingMode: _mode,
        exclusiveBrokerIds: _ids,
        consent: _consent,
      );
      if (!mounted) return;
      AppSnackBar.success(
        context,
        _mode != widget.property.listingMode
            ? GrantMessages.listingModeChanged
            : GrantMessages.exclusiveBrokersChanged,
      );
      Navigator.pop(context, true);
    } on CloudFunctionsUserFacingException catch (e) {
      // problem 002 가드 — NOT_FOUND 등은 한국어 카피로 변환된 상태로 도착.
      Logger.warning(
        'changeListingMode guarded',
        metadata: <String, dynamic>{
          'functionName': e.functionName,
          'firebaseCode': e.firebaseCode,
        },
      );
      if (!mounted) return;
      AppSnackBar.error(context, e.userMessage);
    } catch (e) {
      Logger.error('changeListingMode failed', error: e);
      if (!mounted) return;
      String? code;
      if (e is FirebaseFunctionsException) {
        code = GrantMessages.extractReasonCode(e.message);
      }
      AppSnackBar.error(context, GrantMessages.describeReason(code));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
