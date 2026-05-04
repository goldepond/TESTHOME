import 'package:flutter/material.dart';

import '../../api_request/firebase_service.dart';
import '../../constants/app_constants.dart';
import '../../constants/grant_messages.dart';
import '../../constants/jurisdictions.dart';
import '../../constants/spacing.dart';
import '../../constants/typography.dart';
import '../../utils/cloud_functions_guard.dart';
import '../../utils/snackbar_utils.dart';
import '../../widgets/jurisdiction_picker/jurisdiction_picker.dart';

/// Task 001 §C: 중개사 인증 신청 페이지.
///
/// **한 화면 = 한 결정** 원칙:
///   - 사무소 정보(read-only) 확인 + 영업 지역 선택 → "신청 보내기" 1개 CTA.
///   - 사용자가 결정해야 할 것: jurisdictions 만 (사무소 정보는 이전에 등록 끝).
///
/// 80세 노인 테스트:
///   - 영문 식별자 0 (verified / pending / approved 노출 없음)
///   - 한자어 최소화: "사무소", "영업 지역", "신청 보내기"
///   - 의사결정 1 — jurisdictions 선택 1회 + 제출 1회
///   - submit 실패 시 사유 코드 raw 노출 차단 ([CloudFunctionsUserFacingException]
///     또는 도메인 메시지를 일상 한국어로 변환)
class BrokerVerificationApplyPage extends StatefulWidget {
  const BrokerVerificationApplyPage({
    required this.brokerUid,
    super.key,
  });

  /// brokers/{uid} doc id (= Auth uid).
  final String brokerUid;

  @override
  State<BrokerVerificationApplyPage> createState() =>
      _BrokerVerificationApplyPageState();
}

class _BrokerVerificationApplyPageState
    extends State<BrokerVerificationApplyPage> {
  final FirebaseService _firebaseService = FirebaseService();

  Map<String, dynamic>? _brokerData;
  bool _isLoading = true;
  String? _loadError;

  /// 선택된 jurisdictions (5자리 코드). brokers.jurisdictions 가 이미 있으면 prefill.
  List<String> _selectedJurisdictions = const <String>[];

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadBrokerProfile();
    });
  }

  Future<void> _loadBrokerProfile() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final data = await _firebaseService.getBroker(widget.brokerUid,
          useCache: false);
      if (!mounted) return;
      if (data == null) {
        setState(() {
          _isLoading = false;
          _loadError = '사무소 정보를 먼저 등록해 주세요';
        });
        return;
      }
      // jurisdictions prefill
      final raw = data['jurisdictions'];
      List<String> initial = const <String>[];
      if (raw is List) {
        initial = raw.whereType<String>().toList();
      }
      setState(() {
        _brokerData = data;
        _selectedJurisdictions = initial;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = '사무소 정보를 불러올 수 없어요. 잠시 후 다시 해 주세요';
      });
    }
  }

  Future<void> _openJurisdictionPicker() async {
    final picked = await showJurisdictionPicker(
      context,
      initialCodes: _selectedJurisdictions,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedJurisdictions = picked;
    });
  }

  Future<void> _onSubmit() async {
    if (_isSubmitting) return;
    if (_selectedJurisdictions.isEmpty) {
      AppSnackBar.warning(context, GrantMessages.jurisdictionSignupRequired);
      return;
    }
    setState(() {
      _isSubmitting = true;
    });

    try {
      await _firebaseService.submitBrokerVerificationRequest(
        jurisdictions: _selectedJurisdictions,
      );
      if (!mounted) return;
      await _showSuccessSheet();
      if (!mounted) return;
      Navigator.of(context).pop();
    } on CloudFunctionsUserFacingException catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, e.userMessage);
    } catch (e) {
      if (!mounted) return;
      // 도메인 에러 분기 — duplicate_pending / missing_broker_profile / already_verified
      final msg = e.toString();
      if (msg.contains('duplicate_pending')) {
        AppSnackBar.warning(context, GrantMessages.verifyDuplicatePending);
      } else if (msg.contains('missing_broker_profile')) {
        AppSnackBar.error(context, '사무소 정보를 먼저 등록해 주세요');
      } else if (msg.contains('already_verified')) {
        AppSnackBar.warning(context, '이미 인증이 끝난 계정이에요');
      } else if (msg.contains('invalid_jurisdictions')) {
        AppSnackBar.warning(
            context, '영업 지역은 1개에서 5개까지 고를 수 있어요');
      } else {
        AppSnackBar.error(
            context, GrantMessages.genericRetryNotice);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _showSuccessSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AirbnbColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: AirbnbColors.border,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              const SizedBox(height: 24),
              const Icon(Icons.check_circle_outline,
                  size: 48, color: AirbnbColors.success),
              const SizedBox(height: 16),
              Text(
                GrantMessages.verifyApplySuccessTitle,
                style: AppTypography.h3
                    .copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                GrantMessages.verifyApplySuccessBody,
                style: AppTypography.withColor(
                    AppTypography.body, AirbnbColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AirbnbColors.primary,
                    foregroundColor: AirbnbColors.background,
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(
                    GrantMessages.actionConfirm,
                    style: AppTypography.body
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AirbnbColors.surface,
      appBar: AppBar(
        backgroundColor: AirbnbColors.background,
        foregroundColor: AirbnbColors.textPrimary,
        elevation: 0,
        title: Text(
          GrantMessages.verifyApplyTitle,
          style: AppTypography.h4
              .copyWith(color: AirbnbColors.textPrimary),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(Icons.error_outline,
                  size: 48, color: AirbnbColors.warning),
              const SizedBox(height: 16),
              Text(
                _loadError!,
                style: AppTypography.body
                    .copyWith(color: AirbnbColors.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _loadBrokerProfile,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildHelperBlock(),
          const SizedBox(height: AppSpacing.lg),
          _buildOfficeInfoCard(),
          const SizedBox(height: AppSpacing.lg),
          _buildJurisdictionSection(),
          const SizedBox(height: AppSpacing.xl),
          _buildSubmitButton(),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }

  Widget _buildHelperBlock() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AirbnbColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AirbnbColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.info_outline,
              size: 20, color: AirbnbColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              GrantMessages.verifyApplyHelper,
              style: AppTypography.body.copyWith(
                color: AirbnbColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficeInfoCard() {
    final data = _brokerData ?? const <String, dynamic>{};
    final businessName = (data['businessName']
            ?? data['name']
            ?? '사무소 이름 없음')
        .toString();
    final ownerName =
        (data['ownerName'] ?? '대표자명 없음').toString();
    final registrationNumber = (data['brokerRegistrationNumber']
            ?? data['registrationNumber']
            ?? '등록번호 없음')
        .toString();
    final phone =
        (data['phoneNumber'] ?? data['phone'] ?? '연락처 없음').toString();
    final address = (data['roadAddress']
            ?? data['officeAddress']
            ?? data['address']
            ?? '주소 없음')
        .toString();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AirbnbColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AirbnbColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.business,
                  size: 20, color: AirbnbColors.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  businessName,
                  style: AppTypography.h4
                      .copyWith(color: AirbnbColors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _buildInfoRow('대표자', ownerName),
          const SizedBox(height: AppSpacing.sm),
          _buildInfoRow('등록번호', registrationNumber),
          const SizedBox(height: AppSpacing.sm),
          _buildInfoRow('연락처', phone),
          const SizedBox(height: AppSpacing.sm),
          _buildInfoRow('주소', address),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: AppTypography.captionLarge.copyWith(
              color: AirbnbColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTypography.captionLarge.copyWith(
              color: AirbnbColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildJurisdictionSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AirbnbColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AirbnbColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            GrantMessages.jurisdictionSectionTitle,
            style: AppTypography.h4
                .copyWith(color: AirbnbColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            GrantMessages.jurisdictionSectionHint,
            style: AppTypography.bodySmall
                .copyWith(color: AirbnbColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildJurisdictionChips(),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: _openJurisdictionPicker,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text(GrantMessages.jurisdictionEditCta),
            style: OutlinedButton.styleFrom(
              foregroundColor: AirbnbColors.primary,
              side: const BorderSide(color: AirbnbColors.primary),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJurisdictionChips() {
    if (_selectedJurisdictions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: AirbnbColors.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          GrantMessages.jurisdictionSignupEmptyPlaceholder,
          style: AppTypography.bodySmall
              .copyWith(color: AirbnbColors.textSecondary),
        ),
      );
    }
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        for (final code in _selectedJurisdictions)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AirbnbColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color:
                      AirbnbColors.primary.withValues(alpha: 0.3)),
            ),
            child: Text(
              JurisdictionCatalog.toDisplayName(code) ?? '알 수 없는 지역',
              style: AppTypography.captionLarge.copyWith(
                color: AirbnbColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    final canSubmit =
        _selectedJurisdictions.isNotEmpty && !_isSubmitting;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: canSubmit ? _onSubmit : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AirbnbColors.primary,
          foregroundColor: AirbnbColors.background,
          disabledBackgroundColor:
              AirbnbColors.primary.withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      AirbnbColors.background),
                ),
              )
            : Text(
                GrantMessages.verifyApplySubmit,
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AirbnbColors.background,
                ),
              ),
      ),
    );
  }
}
