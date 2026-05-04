import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/constants/grant_messages.dart';
import 'package:property/constants/jurisdictions.dart';
import 'package:property/constants/responsive_constants.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/constants/spacing.dart';
import 'package:property/constants/typography.dart';
import 'package:property/utils/snackbar_utils.dart';
import 'package:property/widgets/jurisdiction_picker/jurisdiction_empty_banner.dart';
import 'package:property/widgets/jurisdiction_picker/jurisdiction_picker.dart';

/// 공인중개사 본인 정보 관리 페이지
class BrokerSettingsPage extends StatefulWidget {
  final String brokerId;
  final String brokerName;

  const BrokerSettingsPage({
    required this.brokerId, required this.brokerName, super.key,
  });

  @override
  State<BrokerSettingsPage> createState() => _BrokerSettingsPageState();
}

class _BrokerSettingsPageState extends State<BrokerSettingsPage> {
  final FirebaseService _firebaseService = FirebaseService();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isVerified = false;

  // 중개업자 정보 필드들
  final TextEditingController _brokerNameController = TextEditingController();
  final TextEditingController _brokerPhoneController = TextEditingController();
  final TextEditingController _brokerLicenseNumberController = TextEditingController();
  final TextEditingController _brokerOfficeNameController = TextEditingController();
  final TextEditingController _brokerOfficeAddressController = TextEditingController();
  final TextEditingController _brokerIntroductionController = TextEditingController();

  // Task 003: 영업 가능 시·군·구 (5자리 법정동코드)
  List<String> _jurisdictionCodes = <String>[];
  bool _isSavingJurisdictions = false;

  @override
  void initState() {
    super.initState();
    _loadBrokerInfo();
  }

  @override
  void dispose() {
    _brokerNameController.dispose();
    _brokerPhoneController.dispose();
    _brokerLicenseNumberController.dispose();
    _brokerOfficeNameController.dispose();
    _brokerOfficeAddressController.dispose();
    _brokerIntroductionController.dispose();
    super.dispose();
  }

  Future<void> _loadBrokerInfo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      
      // brokers 컬렉션에서 정보 가져오기
      final brokerData = await _firebaseService.getBroker(widget.brokerId);
      
      if (brokerData != null) {

        _brokerNameController.text = brokerData['ownerName'] ?? brokerData['businessName'] ?? '';
        _brokerPhoneController.text = brokerData['phone'] ?? brokerData['phoneNumber'] ?? '';
        _brokerLicenseNumberController.text = brokerData['brokerRegistrationNumber'] ?? brokerData['registrationNumber'] ?? '';
        _brokerOfficeNameController.text = brokerData['businessName'] ?? brokerData['name'] ?? '';
        _brokerOfficeAddressController.text = brokerData['roadAddress'] ?? brokerData['address'] ?? '';
        _brokerIntroductionController.text = brokerData['introduction'] ?? '';
        _isVerified = brokerData['verified'] as bool? ?? false;

        // Task 003: jurisdictions (5자리 법정동코드) 로드
        final raw = brokerData['jurisdictions'];
        if (raw is List) {
          _jurisdictionCodes =
              raw.whereType<String>().toList(growable: false);
        } else {
          _jurisdictionCodes = const <String>[];
        }
      } else {
        
        // users 컬렉션의 brokerInfo에서도 확인
        final userData = await _firebaseService.getUser(widget.brokerId);
        if (userData != null && userData['brokerInfo'] != null) {
          final brokerInfo = userData['brokerInfo'];
          
          _brokerNameController.text = brokerInfo['broker_name'] ?? '';
          _brokerPhoneController.text = brokerInfo['broker_phone'] ?? '';
          _brokerLicenseNumberController.text = brokerInfo['broker_license_number'] ?? '';
          _brokerOfficeNameController.text = brokerInfo['broker_office_name'] ?? '';
          _brokerOfficeAddressController.text = brokerInfo['broker_office_address'] ?? '';
          _brokerIntroductionController.text = brokerInfo['broker_introduction'] ?? '';
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, '정보를 불러오는데 실패했습니다. 잠시 후 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Task 003: 영업 지역 picker 열기 → 즉시 저장 (낙관적 갱신).
  Future<void> _openJurisdictionPicker() async {
    if (_isSavingJurisdictions) return;

    final picked = await showJurisdictionPicker(
      context,
      initialCodes: _jurisdictionCodes,
    );
    if (picked == null) return; // 취소
    if (!mounted) return;

    // 변경 없음 (토글 후 원복)
    final before = (<String>[..._jurisdictionCodes]..sort()).join(',');
    final after = (<String>[...picked]..sort()).join(',');
    if (before == after) return;

    setState(() {
      _isSavingJurisdictions = true;
    });

    final success = await _firebaseService.updateBrokerJurisdictions(
      widget.brokerId,
      picked,
    );

    if (!mounted) return;

    if (success) {
      setState(() {
        _jurisdictionCodes = picked;
        _isSavingJurisdictions = false;
      });
      AppSnackBar.success(context, GrantMessages.jurisdictionSaved);
    } else {
      setState(() {
        _isSavingJurisdictions = false;
      });
      AppSnackBar.error(
          context, GrantMessages.jurisdictionSaveFailed);
    }
  }

  Future<void> _saveBrokerInfo() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final brokerInfo = {
        'broker_name': _brokerNameController.text.trim(),
        'broker_phone': _brokerPhoneController.text.trim(),
        // 등록번호는 수정 불가 (고정값)
        // 'broker_license_number': _brokerLicenseNumberController.text.trim(),
        'broker_office_name': _brokerOfficeNameController.text.trim(),
        'broker_office_address': _brokerOfficeAddressController.text.trim(),
        'broker_introduction': _brokerIntroductionController.text.trim(),
      };

      // brokers 컬렉션 업데이트
      final success = await _firebaseService.updateBrokerInfo(widget.brokerId, brokerInfo);
      
      if (success && mounted) {
        AppSnackBar.success(context, '정보가 성공적으로 저장되었습니다.');
        // 저장 후 정보 다시 로드
        _loadBrokerInfo();
      } else if (mounted) {
        AppSnackBar.error(context, '정보 저장에 실패했습니다.');
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, '정보 저장에 실패했습니다. 잠시 후 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AirbnbColors.surface,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final maxWidth = ResponsiveHelper.getMaxWidth(context);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
      backgroundColor: AirbnbColors.surface,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final viewInsets = MediaQuery.of(context).viewInsets;
                  final actualHeight = constraints.maxHeight - viewInsets.bottom;

                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: actualHeight - 32,
                      ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AirbnbColors.background,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AirbnbColors.primary.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      Text(
                      '내 정보 관리',
                      style: AppTypography.withColor(AppTypography.h2, AirbnbColors.background),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.brokerName}님의 정보를 관리하세요',
                      style:  AppTypography.withColor(AppTypography.body, Colors.white70),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),

              // 인증 상태 배너
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _isVerified
                      ? AirbnbColors.success.withValues(alpha: 0.1)
                      : AirbnbColors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isVerified
                        ? AirbnbColors.success.withValues(alpha: 0.3)
                        : AirbnbColors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isVerified ? Icons.verified : Icons.pending_outlined,
                      color: _isVerified ? AirbnbColors.success : AirbnbColors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _isVerified
                            ? '인증 완료'
                            : '관리자 인증 대기 중 - 인증 완료 후 방문 제안 기능을 사용할 수 있습니다',
                        style: AppTypography.captionLarge.copyWith(color: _isVerified ? AirbnbColors.success : AirbnbColors.orange, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),

              // Task 003: 영업 지역 미등록 경고 배너 — 인증 완료 + 빈 상태일 때만
              if (_isVerified && _jurisdictionCodes.isEmpty) ...<Widget>[
                const SizedBox(height: 16),
                JurisdictionEmptyBanner(
                  onPressEdit: _openJurisdictionPicker,
                ),
              ],

              const SizedBox(height: 16),

              // 기본 정보 섹션
              _buildSectionCard(
                title: '기본 정보',
                icon: Icons.person_rounded,
                color: AirbnbColors.primary,
                children: [
                  _buildTextField(
                    controller: _brokerNameController,
                    label: '중개업자 성명',
                    hint: '홍길동',
                    required: true,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _brokerPhoneController,
                    label: '연락처',
                    hint: '01012345678',
                    keyboardType: TextInputType.phone,
                    required: true,
                    numbersOnly: true, // 숫자만 입력
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // 사업자 정보 섹션
              _buildSectionCard(
                title: '사업자 정보',
                icon: Icons.business_rounded,
                color: AirbnbColors.success,
                children: [
                  _buildTextField(
                    controller: _brokerLicenseNumberController,
                    label: '중개업자 등록번호',
                    hint: '12345',
                    required: true,
                    enabled: false, // 읽기 전용
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AirbnbColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AirbnbColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: AirbnbColors.primary.withValues(alpha: 0.7), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '등록번호는 변경할 수 없습니다.',
                            style: AppTypography.withColor(AppTypography.caption, AirbnbColors.primary.withValues(alpha: 0.7)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _brokerOfficeNameController,
                    label: '사무소명',
                    hint: '강남부동산',
                    required: true,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _brokerOfficeAddressController,
                    label: '사무소 주소',
                    hint: '서울시 강남구 테헤란로 456',
                    required: true,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Task 003: 영업 가능 지역 섹션
              _buildSectionCard(
                title: GrantMessages.jurisdictionSectionTitle,
                icon: Icons.map_outlined,
                color: AirbnbColors.primary,
                children: <Widget>[
                  Text(
                    GrantMessages.jurisdictionSectionHint,
                    style: AppTypography.withColor(
                        AppTypography.bodySmall, AirbnbColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _buildJurisdictionChips(),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isSavingJurisdictions
                          ? null
                          : _openJurisdictionPicker,
                      icon: _isSavingJurisdictions
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.edit_location_alt_outlined),
                      label: const Text(GrantMessages.jurisdictionEditCta),
                      style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AirbnbColors.primary),
                        foregroundColor: AirbnbColors.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 소개 섹션
              _buildSectionCard(
                title: '소개',
                icon: Icons.description_rounded,
                color: AirbnbColors.primary,
                children: [
                  TextFormField(
                    controller: _brokerIntroductionController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: '공인중개사 소개',
                      hintText: '자신의 전문성, 경력, 특별한 서비스 등을 자유롭게 작성해주세요.\n예: 10년 이상의 경력으로 강남 지역 부동산 전문...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AirbnbColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AirbnbColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AirbnbColors.primary, width: 2),
                      ),
                      filled: true,
                      fillColor: AirbnbColors.surface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // 저장 버튼
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveBrokerInfo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AirbnbColors.primary,
                    foregroundColor: AirbnbColors.background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AirbnbColors.background),
                          ),
                        )
                      :   Text(
                          '정보 저장',
                          style: AppTypography.body.copyWith(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
                    ),
                  ),
                ),
              );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Task 003: 영업 지역 칩 리스트 (또는 빈 상태 placeholder).
  Widget _buildJurisdictionChips() {
    if (_jurisdictionCodes.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: AirbnbColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AirbnbColors.border),
        ),
        child: Text(
          GrantMessages.jurisdictionSignupEmptyPlaceholder,
          style: AppTypography.withColor(
              AppTypography.bodySmall, AirbnbColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      );
    }
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        for (final code in _jurisdictionCodes)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AirbnbColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AirbnbColors.primary.withValues(alpha: 0.3)),
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

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AirbnbColors.background,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AirbnbColors.textSecondary.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: AppTypography.withColor(AppTypography.h4, color),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    bool required = false,
    bool enabled = true,
    bool numbersOnly = false, // 숫자만 입력 허용
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      readOnly: !enabled,
      inputFormatters: numbersOnly
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9]'))]
          : null,
      decoration: InputDecoration(
        labelText: label + (required ? ' *' : ''),
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AirbnbColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AirbnbColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AirbnbColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AirbnbColors.error, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AirbnbColors.error, width: 2),
        ),
        filled: true,
        fillColor: AirbnbColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: required
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return '$label을(를) 입력해주세요';
              }
              return null;
            }
          : null,
    );
  }
}

