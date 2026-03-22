import 'package:flutter/material.dart';
import 'package:property/constants/apple_design_system.dart';
import 'package:property/models/report.dart';
import 'package:property/api_request/firebase_service.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('신고가 접수되었습니다. 검토 후 조치하겠습니다.'),
            backgroundColor: AppleColors.systemGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('신고 접수에 실패했습니다. 다시 시도해주세요.'),
            backgroundColor: AppleColors.systemRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isSubmitting = false);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('오류가 발생했습니다: $e'),
          backgroundColor: AppleColors.systemRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppleColors.systemBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppleRadius.lg),
      ),
      title: Row(
        children: [
          const Icon(
            Icons.flag_rounded,
            color: AppleColors.systemRed,
            size: 24,
          ),
          const SizedBox(width: AppleSpacing.sm),
          Text(
            '중개사 신고',
            style: AppleTypography.headline.copyWith(
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
              padding: const EdgeInsets.all(AppleSpacing.md),
              decoration: BoxDecoration(
                color: AppleColors.secondarySystemBackground,
                borderRadius: BorderRadius.circular(AppleRadius.md),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.person_rounded,
                    color: AppleColors.secondaryLabel,
                    size: 20,
                  ),
                  const SizedBox(width: AppleSpacing.sm),
                  Expanded(
                    child: Text(
                      widget.brokerName,
                      style: AppleTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppleSpacing.lg),

            // 신고 사유 선택
            Text(
              '신고 사유를 선택해주세요',
              style: AppleTypography.subheadline.copyWith(
                color: AppleColors.secondaryLabel,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppleSpacing.md),

            // 신고 사유 라디오 버튼들
            ...ReportReason.values.map((reason) => _buildReasonTile(reason)),

            const SizedBox(height: AppleSpacing.lg),

            // 상세 내용 입력
            Text(
              '상세 내용 (선택)',
              style: AppleTypography.subheadline.copyWith(
                color: AppleColors.secondaryLabel,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppleSpacing.sm),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: '추가로 알려주실 내용이 있으면 입력해주세요',
                hintStyle: AppleTypography.body.copyWith(
                  color: AppleColors.tertiaryLabel,
                ),
                filled: true,
                fillColor: AppleColors.secondarySystemBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppleRadius.md),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppleRadius.md),
                  borderSide: const BorderSide(
                    color: AppleColors.systemBlue,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.all(AppleSpacing.md),
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
            style: AppleTypography.body.copyWith(
              color: AppleColors.secondaryLabel,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitReport,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppleColors.systemRed,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppleRadius.md),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppleSpacing.lg,
              vertical: AppleSpacing.sm,
            ),
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
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
        margin: const EdgeInsets.only(bottom: AppleSpacing.sm),
        padding: const EdgeInsets.all(AppleSpacing.md),
        decoration: BoxDecoration(
          color: isSelected
              ? AppleColors.systemRed.withValues(alpha: 0.1)
              : AppleColors.secondarySystemBackground,
          borderRadius: BorderRadius.circular(AppleRadius.md),
          border: Border.all(
            color: isSelected
                ? AppleColors.systemRed
                : AppleColors.separator,
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
                  ? AppleColors.systemRed
                  : AppleColors.tertiaryLabel,
              size: 22,
            ),
            const SizedBox(width: AppleSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reason.label,
                    style: AppleTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppleColors.systemRed
                          : AppleColors.label,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    reason.description,
                    style: AppleTypography.caption1.copyWith(
                      color: AppleColors.secondaryLabel,
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
