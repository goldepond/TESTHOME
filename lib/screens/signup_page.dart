import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/constants/typography.dart';
import 'package:property/constants/spacing.dart';
import 'package:property/widgets/common_design_system.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/widgets/home_logo_button.dart';
import 'package:property/utils/validation_utils.dart';
import 'package:property/screens/main_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordConfirmController = TextEditingController();
  bool _isLoading = false;
  bool _agreeToTerms = false;
  bool _agreeToPrivacy = false;
  bool _agreeToMarketing = false;
  final FirebaseService _firebaseService = FirebaseService();

  // 각 필드별 에러 메시지
  String? _emailError;
  String? _phoneError;
  String? _passwordError;
  String? _passwordConfirmError;

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }
  
  Color _getPasswordStrengthColor(int strength) {
    if (strength <= 1) return AirbnbColors.error;
    if (strength == 2) return AirbnbColors.warning;
    if (strength == 3) return AirbnbColors.primary;
    return AirbnbColors.success;
  }

  Future<void> _signup() async {
    // 더블 클릭 방지
    if (_isLoading) {
      return;
    }

    // 모든 에러 초기화
    setState(() {
      _emailError = null;
      _phoneError = null;
      _passwordError = null;
      _passwordConfirmError = null;
    });
    
    bool hasError = false;
    
    // 이메일 검증
    if (_emailController.text.isEmpty) {
      setState(() {
        _emailError = '이메일을 입력해주세요';
      });
      hasError = true;
    } else if (!ValidationUtils.isValidEmail(_emailController.text)) {
      setState(() {
        _emailError = '올바른 이메일 형식이 아닙니다 (예: user@example.com)';
      });
      hasError = true;
    }
    
    // 휴대폰 번호 검증 (입력된 경우만)
    if (_phoneController.text.isNotEmpty) {
      final phone = _phoneController.text.replaceAll('-', '').replaceAll(' ', '');
      if (!RegExp(r'^01[0-9]{8,9}$').hasMatch(phone)) {
        setState(() {
          _phoneError = '올바른 휴대폰 번호를 입력해주세요 (예: 01012345678)';
        });
        hasError = true;
      }
    }

    // 비밀번호 검증
    if (_passwordController.text.isEmpty) {
      setState(() {
        _passwordError = '비밀번호를 입력해주세요';
      });
      hasError = true;
    } else if (!ValidationUtils.isValidPasswordLength(_passwordController.text)) {
      setState(() {
        _passwordError = '비밀번호는 6자 이상이어야 합니다';
      });
      hasError = true;
    }

    // 비밀번호 확인 검증
    if (_passwordConfirmController.text.isEmpty) {
      setState(() {
        _passwordConfirmError = '비밀번호 확인을 입력해주세요';
      });
      hasError = true;
    } else if (!ValidationUtils.doPasswordsMatch(_passwordController.text, _passwordConfirmController.text)) {
      setState(() {
        _passwordConfirmError = '비밀번호가 일치하지 않습니다';
      });
      hasError = true;
    }
    
    // 약관 동의 확인
    if (!_agreeToTerms || !_agreeToPrivacy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('필수 약관에 동의해주세요'),
          backgroundColor: AirbnbColors.error,
          duration: Duration(seconds: 2),
        ),
      );
      hasError = true;
    }
    
    // 에러가 있으면 중단
    if (hasError) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 이메일에서 ID 추출 (@ 앞부분)
      final id = _emailController.text.split('@')[0];
      
      // 휴대폰 번호 (입력된 경우만)
      final phone = _phoneController.text.isNotEmpty 
          ? _phoneController.text.replaceAll('-', '').replaceAll(' ', '')
          : null;
      
      // 기본 이름 (이메일 앞부분 사용)
      final name = id;
      
      final success = await _firebaseService.registerUser(
        id,
        _passwordController.text,
        name,
        email: _emailController.text,
        phone: phone,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('회원가입이 완료되었습니다!'),
            backgroundColor: AirbnbColors.success,
            duration: Duration(seconds: 2),
          ),
        );

        // 현재 로그인된 사용자의 UID 가져오기
        final currentUser = FirebaseAuth.instance.currentUser;
        final uid = currentUser?.uid ?? '';

        // 메인 페이지로 직접 이동 (AuthGate 타이밍 문제 방지)
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => MainPage(
              userId: uid,
              userName: name,
            ),
          ),
          (route) => false, // 모든 이전 라우트 제거
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('이미 존재하는 이메일입니다.'),
            backgroundColor: AirbnbColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('회원가입 중 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.'),
            backgroundColor: AirbnbColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && FocusScope.of(context).hasFocus) {
          FocusScope.of(context).unfocus();
          await Future.delayed(const Duration(milliseconds: 100));
        }
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
      backgroundColor: AirbnbColors.surface,
        resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AirbnbColors.background,
        foregroundColor: AirbnbColors.textPrimary,
        elevation: 0.5,
        title: HomeLogoButton(
          fontSize: AppTypography.h4.fontSize!,
          color: AirbnbColors.primary,
        ),
      ),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 제목
            Text(
              '일반 회원가입',
              style: AppTypography.withColor(
                AppTypography.display.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.5,
                  height: 1.1,
                ),
                AirbnbColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              '이메일과 비밀번호로 간단하게 가입하세요',
              style: AppTypography.withColor(
                AppTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.w400,
                  height: 1.6,
                ),
                AirbnbColors.textSecondary,
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // 회원가입 폼
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: CommonDesignSystem.cardDecoration(
                color: AirbnbColors.surface,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '기본 정보',
                    style: AppTypography.withColor(
                      AppTypography.h4.copyWith(fontWeight: FontWeight.bold),
                      AirbnbColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  
                  // 이메일 입력 (필수)
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (value) {
                      if (_emailError != null) {
                        setState(() {
                          _emailError = null;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      labelText: '이메일 *',
                      hintText: '예: user@example.com',
                      prefixIcon: const Icon(Icons.email),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _emailError != null ? AirbnbColors.error : AirbnbColors.border,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _emailError != null ? AirbnbColors.error : AirbnbColors.primary, 
                          width: 2,
                        ),
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
                      fillColor: AirbnbColors.textSecondary.withValues(alpha: 0.05),
                      errorText: _emailError,
                      errorStyle: AppTypography.caption,
                      helperText: _emailError == null ? '이메일이 로그인 ID로 사용됩니다' : null,
                      helperStyle: AppTypography.withColor(
                        AppTypography.caption,
                        AirbnbColors.textLight,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  
                  // 휴대폰 번호 입력 (선택)
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9]')), // 숫자만 입력
                    ],
                    onChanged: (value) {
                      if (_phoneError != null) {
                        setState(() {
                          _phoneError = null;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      labelText: '휴대폰 번호',
                      hintText: '예: 01012345678',
                      prefixIcon: const Icon(Icons.phone),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _phoneError != null ? AirbnbColors.error : AirbnbColors.border,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _phoneError != null ? AirbnbColors.error : AirbnbColors.primary, 
                          width: 2,
                        ),
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
                      fillColor: AirbnbColors.textSecondary.withValues(alpha: 0.05),
                      errorText: _phoneError,
                      errorStyle: AppTypography.caption,
                      helperText: _phoneError == null ? '본인 확인 및 비밀번호 찾기에 사용됩니다' : null,
                      helperStyle: AppTypography.withColor(
                        AppTypography.caption,
                        AirbnbColors.textLight,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 비밀번호 입력
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    onChanged: (value) {
                      setState(() {
                        if (_passwordError != null) {
                          _passwordError = null;
                        }
                      });
                    },
                    decoration: InputDecoration(
                      labelText: '비밀번호 *',
                      hintText: '6자 이상 (영문, 숫자, 특수문자 조합 권장)',
                      prefixIcon: const Icon(Icons.lock),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _passwordError != null ? AirbnbColors.error : AirbnbColors.border,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _passwordError != null ? AirbnbColors.error : AirbnbColors.primary, 
                          width: 2,
                        ),
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
                      fillColor: AirbnbColors.textSecondary.withValues(alpha: 0.05),
                      errorText: _passwordError,
                      errorStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                  
                  // 비밀번호 강도 표시
                  if (_passwordController.text.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: ValidationUtils.getPasswordStrength(_passwordController.text) / 4,
                            backgroundColor: AirbnbColors.border,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _getPasswordStrengthColor(ValidationUtils.getPasswordStrength(_passwordController.text)),
                            ),
                            minHeight: 4,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          ValidationUtils.getPasswordStrengthText(ValidationUtils.getPasswordStrength(_passwordController.text)),
                          style: AppTypography.withColor(
                            AppTypography.caption.copyWith(fontWeight: FontWeight.w600),
                            _getPasswordStrengthColor(ValidationUtils.getPasswordStrength(_passwordController.text)),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                    ),
                  ],
                  
                  const SizedBox(height: AppSpacing.md),
                  
                  // 비밀번호 확인 입력
                  TextField(
                    controller: _passwordConfirmController,
                    obscureText: true,
                    onChanged: (value) {
                      if (_passwordConfirmError != null) {
                        setState(() {
                          _passwordConfirmError = null;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      labelText: '비밀번호 확인 *',
                      hintText: '비밀번호를 다시 입력하세요',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _passwordConfirmError != null ? AirbnbColors.error : AirbnbColors.border,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _passwordConfirmError != null ? AirbnbColors.error : AirbnbColors.primary, 
                          width: 2,
                        ),
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
                      fillColor: AirbnbColors.textSecondary.withValues(alpha: 0.05),
                      errorText: _passwordConfirmError,
                      errorStyle: AppTypography.caption,
                    ),
                  ),
                  
                  const SizedBox(height: AppSpacing.lg),
                  
                  // 약관 동의
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: CommonDesignSystem.smallCardDecoration(
                      color: AirbnbColors.surface,
                    ).copyWith(
                      border: Border.all(color: AirbnbColors.border),
                    ),
                    child: Column(
                      children: [
                        CheckboxListTile(
                          value: _agreeToTerms,
                          onChanged: (value) => setState(() => _agreeToTerms = value ?? false),
                          title: const Text(
                            '서비스 이용약관 동의 (필수)',
                            style: AppTypography.bodySmall,
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                          activeColor: AirbnbColors.primary,
                        ),
                        CheckboxListTile(
                          value: _agreeToPrivacy,
                          onChanged: (value) => setState(() => _agreeToPrivacy = value ?? false),
                          title: const Text(
                            '개인정보 처리방침 동의 (필수)',
                            style: AppTypography.bodySmall,
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                          activeColor: AirbnbColors.primary,
                        ),
                        CheckboxListTile(
                          value: _agreeToMarketing,
                          onChanged: (value) => setState(() => _agreeToMarketing = value ?? false),
                          title: const Text(
                            '마케팅 정보 수신 동의 (선택)',
                            style: AppTypography.bodySmall,
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                          activeColor: AirbnbColors.primary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // 회원가입 버튼
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _signup,
                icon: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AirbnbColors.background),
                        ),
                      )
                    : const Icon(Icons.person_add, size: 24),
                label: Text(
                  _isLoading ? '가입 중...' : '회원가입',
                  style: AppTypography.button,
                ),
                style: CommonDesignSystem.primaryButtonStyle(),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // 로그인으로 이동
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  '이미 계정이 있으신가요? 로그인',
                  style: AppTypography.withColor(
                    AppTypography.bodySmall,
                    AirbnbColors.primary,
                  ),
                ),
              ),
            ),
          ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}

