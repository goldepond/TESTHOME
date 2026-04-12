import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/constants/typography.dart';
import 'package:property/constants/spacing.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/utils/logger.dart';
import 'package:property/utils/phone_utils.dart';
import 'package:property/utils/snackbar_utils.dart';

/// 소셜 로그인 후 필수 정보 입력 페이지
/// 이름과 전화번호를 입력받아 프로필을 완성합니다.
class ProfileCompletionPage extends StatefulWidget {
  final String userId;
  final String? currentName;
  final VoidCallback onComplete;

  const ProfileCompletionPage({
    required this.userId,
    required this.onComplete, this.currentName,
    super.key,
  });

  @override
  State<ProfileCompletionPage> createState() => _ProfileCompletionPageState();
}

class _ProfileCompletionPageState extends State<ProfileCompletionPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // 기존 이름이 기본값이 아니면 미리 채움
    if (widget.currentName != null &&
        !_isDefaultName(widget.currentName!)) {
      _nameController.text = widget.currentName!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  /// 기본 이름인지 확인 (소셜 로그인 기본값)
  bool _isDefaultName(String name) {
    const defaultNames = [
      '카카오 사용자',
      '구글 사용자',
      '네이버 사용자',
      '사용자',
      'Google 사용자',
      'Kakao 사용자',
      'Naver 사용자',
    ];
    if (defaultNames.contains(name)) return true;

    // 소셜 로그인 ID 형식 체크 (예: kakao_4719204516, google_xxx, naver_xxx)
    final lowerName = name.toLowerCase();
    if (lowerName.startsWith('kakao_') ||
        lowerName.startsWith('google_') ||
        lowerName.startsWith('naver_')) {
      return true;
    }

    return false;
  }

  /// 전화번호 유효성 검사
  String? _validatePhone(String? value) => PhoneUtils.validate(value);

  /// 이름 유효성 검사
  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '이름을 입력해주세요';
    }
    if (value.trim().length < 2) {
      return '이름은 2글자 이상 입력해주세요';
    }
    if (_isDefaultName(value.trim())) {
      return '실제 이름을 입력해주세요';
    }
    return null;
  }

  /// 전화번호 포맷팅 (010-1234-5678 형식)
  String _formatPhoneNumber(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 11) {
      return '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7)}';
    } else if (digits.length == 10) {
      return '${digits.substring(0, 3)}-${digits.substring(3, 6)}-${digits.substring(6)}';
    }
    return phone;
  }

  /// 프로필 저장
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final name = _nameController.text.trim();
      final phone = _formatPhoneNumber(_phoneController.text.trim());

      Logger.info('[프로필 완성] 저장 시도 - userId: ${widget.userId}, name: $name, phone: $phone');

      // Firestore 업데이트
      final success = await _firebaseService.updateUser(widget.userId, {
        'name': name,
        'phone': phone,
        'profileCompleted': true,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      if (!success) {
        throw Exception('Firestore 업데이트 실패');
      }

      Logger.info('[프로필 완성] 저장 성공');

      if (mounted) {
        // 성공 메시지 표시
        AppSnackBar.success(context, '프로필이 저장되었습니다');

        // 완료 콜백 호출
        widget.onComplete();
      }
    } catch (e) {
      Logger.error('[프로필 완성] 저장 실패: $e');
      if (mounted) {
        AppSnackBar.error(context, '저장에 실패했습니다. 잠시 후 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AirbnbColors.background,
      appBar: AppBar(
        backgroundColor: AirbnbColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          '프로필 완성',
          style: AppTypography.h4,
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 안내 텍스트
                    _buildHeader(),
                    const SizedBox(height: 40.0),

                    // 이름 입력
                    _buildNameField(),
                    const SizedBox(height: 20.0),

                    // 전화번호 입력
                    _buildPhoneField(),
                    const SizedBox(height: 40.0),

                    // 저장 버튼
                    _buildSaveButton(),
                    const SizedBox(height: 20.0),

                    // 개인정보 안내
                    _buildPrivacyNotice(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AirbnbColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.person_outline,
            size: 40,
            color: AirbnbColors.primary,
          ),
        ),
        const SizedBox(height: 20.0),
        Text(
          '마지막 단계입니다!',
          style: AppTypography.h1.copyWith(
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12.0),
        Text(
          '서비스 이용을 위해\n이름과 연락처를 입력해주세요',
          style: AppTypography.body.copyWith(
            color: AirbnbColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '이름',
          style: AppTypography.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            color: AirbnbColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: _nameController,
          validator: _validateName,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: '실명을 입력해주세요',
            hintStyle: AppTypography.body.copyWith(
              color: AirbnbColors.textLight,
            ),
            filled: true,
            fillColor: AirbnbColors.borderLight,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            prefixIcon: const Icon(
              Icons.badge_outlined,
              color: AirbnbColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '전화번호',
          style: AppTypography.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            color: AirbnbColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: _phoneController,
          validator: _validatePhone,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
          ],
          decoration: InputDecoration(
            hintText: '01012345678',
            hintStyle: AppTypography.body.copyWith(
              color: AirbnbColors.textLight,
            ),
            filled: true,
            fillColor: AirbnbColors.borderLight,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            prefixIcon: const Icon(
              Icons.phone_outlined,
              color: AirbnbColors.textSecondary,
            ),
          ),
          onFieldSubmitted: (_) => _saveProfile(),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: AirbnbColors.primary,
          foregroundColor: AirbnbColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AirbnbColors.background,
                ),
              )
            : Text(
                '시작하기',
                style: AppTypography.body.copyWith(
                  color: AirbnbColors.background,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildPrivacyNotice() {
    return Text(
      '입력하신 정보는 서비스 제공 목적으로만 사용되며,\n제3자에게 제공되지 않습니다.',
      style: AppTypography.caption.copyWith(
        color: AirbnbColors.textLight,
      ),
      textAlign: TextAlign.center,
    );
  }
}
