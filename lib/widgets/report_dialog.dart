import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/constants/typography.dart';
import 'package:property/constants/spacing.dart';
import 'package:property/models/report.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/utils/snackbar_utils.dart';

/// 중개사 신고 다이얼로그
///
/// 사용법:
/// ```dart
/// final result = await showReportDialog(
///   context: context,
///   reporterId: userId,
///   reporterName: userName,
///   brokerId: broker['id'],
///   brokerName: broker['name'],
/// );
/// if (result == true) {
///   // 신고 성공
/// }
/// ```
Future<bool?> showReportDialog({
  required BuildContext context,
  required String reporterId,
  required String reporterName,
  required String brokerId,
  required String brokerName,
  String? brokerRegistrationNumber,
  String? propertyId,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => ReportDialog(
      reporterId: reporterId,
      reporterName: reporterName,
      brokerId: brokerId,
      brokerName: brokerName,
      brokerRegistrationNumber: brokerRegistrationNumber,
      propertyId: propertyId,
    ),
  );
}

class ReportDialog extends StatefulWidget {
  final String reporterId;
  final String reporterName;
  final String brokerId;
  final String brokerName;
  final String? brokerRegistrationNumber;
  final String? propertyId;

  const ReportDialog({
    required this.reporterId,
    required this.reporterName,
    required this.brokerId,
    required this.brokerName,
    this.brokerRegistrationNumber,
    this.propertyId,
    super.key,
  });

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _descriptionController = TextEditingController();

  ReportReason _selectedReason = ReportReason.appBypass;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    setState(() => _isSubmitting = true);

    try {
      final report = Report(
        reporterId: widget.reporterId,
        reporterName: widget.reporterName,
        brokerId: widget.brokerId,
        brokerName: widget.brokerName,
        brokerRegistrationNumber: widget.brokerRegistrationNumber,
        reason: _selectedReason,
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        propertyId: widget.propertyId,
      );

      final reportId = await _firebaseService.submitReport(report);

      if (!mounted) return;

      if (reportId != null) {
        Navigator.of(context).pop(true);
        AppSnackBar.success(context, '신고가 접수되었습니다. 검토 후 조치하겠습니다.');
      } else {
        AppSnackBar.error(context, '신고 접수에 실패했습니다. 다시 시도해주세요.');
        setState(() => _isSubmitting = false);
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, '오류가 발생했습니다: $e');
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AirbnbColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      title: Row(
        children: [
          const Icon(
            Icons.flag_rounded,
            color: AirbnbColors.red,
            size: 24,
          ),
          const SizedBox(width: 12.0),
          Text(
            '중개사 신고',
            style: AppTypography.h4.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 신고 대상
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AirbnbColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.person_rounded,
                    color: AirbnbColors.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Text(
                      widget.brokerName,
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20.0),

            // 신고 사유 선택
            Text(
              '신고 사유를 선택해주세요',
              style: AppTypography.bodySmall.copyWith(
                color: AirbnbColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 신고 사유 라디오 버튼들
            ...ReportReason.values.map((reason) => _buildReasonTile(reason)),

            const SizedBox(height: 20.0),

            // 상세 내용 입력
            Text(
              '상세 내용 (선택)',
              style: AppTypography.bodySmall.copyWith(
                color: AirbnbColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12.0),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: '추가로 알려주실 내용이 있으면 입력해주세요',
                hintStyle: AppTypography.body.copyWith(
                  color: AirbnbColors.textLight,
                ),
                filled: true,
                fillColor: AirbnbColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: const BorderSide(
                    color: AirbnbColors.primary,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.all(AppSpacing.md),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: Text(
            '취소',
            style: AppTypography.body.copyWith(
              color: AirbnbColors.textSecondary,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitReport,
          style: ElevatedButton.styleFrom(
            backgroundColor: AirbnbColors.red,
            foregroundColor: AirbnbColors.background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 12.0,
            ),
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AirbnbColors.background,
                  ),
                )
              : const Text('신고하기'),
        ),
      ],
    );
  }

  Widget _buildReasonTile(ReportReason reason) {
    final isSelected = _selectedReason == reason;

    return GestureDetector(
      onTap: () => setState(() => _selectedReason = reason),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12.0),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected
              ? AirbnbColors.red.withValues(alpha: 0.1)
              : AirbnbColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected
                ? AirbnbColors.red
                : AirbnbColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected
                  ? AirbnbColors.red
                  : AirbnbColors.textLight,
              size: 22,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reason.label,
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AirbnbColors.red
                          : AirbnbColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    reason.description,
                    style: AppTypography.caption.copyWith(
                      color: AirbnbColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
