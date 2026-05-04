import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api_request/firebase_service.dart';
import '../constants/app_constants.dart';
import '../constants/grant_messages.dart';
import '../constants/spacing.dart';
import '../constants/typography.dart';
import '../screens/broker/broker_verification_apply_page.dart';

/// Task 001 §D: 중개사 인증 신청 상태 배너.
///
/// `watchMyVerificationRequest` 결과별 노출 분기:
///
/// | status         | 배너 |
/// |----------------|------|
/// | 신청 없음 + verified=false | (현재 그대로 — 부모 인증 안내 시트가 처리) → 본 위젯 미노출 |
/// | pending        | "신청을 받았어요. 관리자 확인 중입니다." |
/// | rejected       | "다시 신청해 주세요. {rejectionReason}" + [다시 신청] 버튼 |
/// | approved       | 1회용 토스트 — 24h dismiss (SharedPreferences 키: verify_approved_dismissed_$brokerUid) |
///
/// 80세 노인 테스트:
///   - 영문 식별자 0 (verified / pending / approved 노출 없음)
///   - 한 줄, 일상 한국어
///   - rejected 의 사유는 admin 입력 텍스트 그대로 표기 — placeholder 가이드(§6.1) 가
///     운영자 측에서 80세 화법 통과 책임 (operator-to-user-copy-gate.md §3 7원칙).
class BrokerVerificationStatusBanner extends StatefulWidget {
  const BrokerVerificationStatusBanner({
    required this.brokerUid,
    required this.verified,
    super.key,
  });

  final String brokerUid;

  /// brokers.verified 현재 값. true 면 1회용 approved 토스트 분기.
  final bool verified;

  @override
  State<BrokerVerificationStatusBanner> createState() =>
      _BrokerVerificationStatusBannerState();
}

class _BrokerVerificationStatusBannerState
    extends State<BrokerVerificationStatusBanner> {
  final FirebaseService _firebaseService = FirebaseService();

  String get _approvedDismissKey =>
      'verify_approved_dismissed_${widget.brokerUid}';

  Future<bool> _isApprovedDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    final tsMillis = prefs.getInt(_approvedDismissKey);
    if (tsMillis == null) return false;
    final dismissedAt =
        DateTime.fromMillisecondsSinceEpoch(tsMillis);
    return DateTime.now().difference(dismissedAt).inHours < 24;
  }

  Future<void> _markApprovedDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        _approvedDismissKey, DateTime.now().millisecondsSinceEpoch);
  }

  void _openApplyPage() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            BrokerVerificationApplyPage(brokerUid: widget.brokerUid),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream:
          _firebaseService.watchMyVerificationRequest(widget.brokerUid),
      builder: (context, snapshot) {
        // 로딩/에러는 조용히 — UI 흔들림 방지.
        if (!snapshot.hasData && !snapshot.hasError) {
          return const SizedBox.shrink();
        }
        final request = snapshot.data;

        // 신청이 한 번도 없음 → 부모(미인증 시트)가 처리 → 미노출.
        if (request == null) return const SizedBox.shrink();

        final status = (request['status'] ?? '').toString();

        if (status == 'pending') return _buildPendingBanner();
        if (status == 'rejected') {
          final reason =
              (request['rejectionReason'] ?? '').toString();
          return _buildRejectedBanner(reason);
        }
        if (status == 'approved' && widget.verified) {
          return _ApprovedToast(
            isDismissed: _isApprovedDismissed,
            onDismiss: _markApprovedDismissed,
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildPendingBanner() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AirbnbColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AirbnbColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.hourglass_empty,
              size: 20, color: AirbnbColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              GrantMessages.verifyBannerPending,
              style: AppTypography.captionLarge.copyWith(
                color: AirbnbColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRejectedBanner(String reason) {
    final reasonText = reason.isEmpty
        ? '관리자에게 문의해 주세요'
        : reason;
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AirbnbColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AirbnbColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(Icons.error_outline,
                  size: 20, color: AirbnbColors.warning),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '${GrantMessages.verifyBannerRejectedPrefix}$reasonText',
                  style: AppTypography.captionLarge.copyWith(
                    color: AirbnbColors.warning,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _openApplyPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: AirbnbColors.warning,
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
                GrantMessages.verifyBannerRetryButton,
                style: AppTypography.caption.copyWith(
                  color: AirbnbColors.background,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 승인 1회용 토스트 — 24h SharedPreferences dismiss 기록.
///
/// StatefulWidget 으로 분리한 이유: 상위 [BrokerVerificationStatusBanner] 의
/// StreamBuilder 가 매 snapshot 마다 rebuild — 상태 토글 로직을 자체 격리.
class _ApprovedToast extends StatefulWidget {
  const _ApprovedToast({
    required this.isDismissed,
    required this.onDismiss,
  });

  final Future<bool> Function() isDismissed;
  final Future<void> Function() onDismiss;

  @override
  State<_ApprovedToast> createState() => _ApprovedToastState();
}

class _ApprovedToastState extends State<_ApprovedToast> {
  bool? _shouldShow;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final dismissed = await widget.isDismissed();
      if (!mounted) return;
      setState(() {
        _shouldShow = !dismissed;
      });
    });
  }

  Future<void> _onClose() async {
    await widget.onDismiss();
    if (!mounted) return;
    setState(() {
      _shouldShow = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_shouldShow != true) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AirbnbColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AirbnbColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.check_circle_outline,
              size: 20, color: AirbnbColors.success),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              GrantMessages.verifyBannerApprovedToast,
              style: AppTypography.captionLarge.copyWith(
                color: AirbnbColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            tooltip: '닫기',
            iconSize: 18,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(4),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close,
                color: AirbnbColors.success),
            onPressed: _onClose,
          ),
        ],
      ),
    );
  }
}
