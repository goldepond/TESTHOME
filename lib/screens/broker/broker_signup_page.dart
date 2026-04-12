import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/constants/responsive_constants.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/widgets/home_logo_button.dart';
import 'package:property/utils/validation_utils.dart';
import 'package:property/screens/broker/mls_broker_dashboard_page.dart';
import 'package:property/constants/typography.dart';
import 'package:property/utils/snackbar_utils.dart';

/// 공인중개사 회원가입 페이지
class BrokerSignupPage extends StatefulWidget {
  const BrokerSignupPage({super.key});

  @override
  State<BrokerSignupPage> createState() => _BrokerSignupPageState();
}

class _BrokerSignupPageState extends State<BrokerSignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _registrationNumberController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;

  final FirebaseService _firebaseService = FirebaseService();

  // 각 필드별 에러 메시지
  String? _emailError;
  String? _passwordError;
  String? _passwordConfirmError;
  String? _businessNameError;
  String? _registrationNumberError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _registrationNumberController.dispose();
    _ownerNameController.dispose();
    _businessNameController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  /// 회원가입 제출
  Future<void> _submitSignup() async {
    // 더블 클릭 방지
    if (_isLoading) return;

    // 모든 에러 초기화 + 로딩 상태 즉시 설정
    setState(() {
      _isLoading = true;
      _emailError = null;
      _passwordError = null;
      _passwordConfirmError = null;
      _businessNameError = null;
      _registrationNumberError = null;
    });

    bool hasError = false;

    // 등록번호 검증 (필수)
    if (_registrationNumberController.text.trim().isEmpty) {
      setState(() => _registrationNumberError = '중개업 등록번호를 입력해주세요');
      hasError = true;
    }

    // 이메일 검증
    if (_emailController.text.isEmpty) {
      setState(() => _emailError = '이메일을 입력해주세요');
      hasError = true;
    } else if (!ValidationUtils.isValidEmail(_emailController.text)) {
      setState(() => _emailError = '올바른 이메일 형식이 아닙니다');
      hasError = true;
    }

    // 비밀번호 검증
    if (_passwordController.text.isEmpty) {
      setState(() => _passwordError = '비밀번호를 입력해주세요');
      hasError = true;
    } else if (!ValidationUtils.isValidPasswordLength(_passwordController.text)) {
      setState(() => _passwordError = '비밀번호는 6자 이상이어야 합니다');
      hasError = true;
    }

    // 비밀번호 확인 검증
    if (_passwordConfirmController.text.isEmpty) {
      setState(() => _passwordConfirmError = '비밀번호 확인을 입력해주세요');
      hasError = true;
    } else if (!ValidationUtils.doPasswordsMatch(_passwordController.text, _passwordConfirmController.text)) {
      setState(() => _passwordConfirmError = '비밀번호가 일치하지 않습니다');
      hasError = true;
    }

    // 소유자 이름 검증
    if (_ownerNameController.text.isEmpty) {
      AppSnackBar.info(context, '대표자명을 입력해주세요');
      hasError = true;
    }

    // 사무소명 검증
    if (_businessNameController.text.isEmpty) {
      setState(() => _businessNameError = '사무소명을 입력해주세요');
      hasError = true;
    }

    // 전화번호 검증
    if (_phoneNumberController.text.isEmpty) {
      AppSnackBar.info(context, '전화번호를 입력해주세요');
      hasError = true;
    }

    if (hasError) {
      setState(() => _isLoading = false);
      return;
    }

    if (!_formKey.currentState!.validate()) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final brokerInfo = {
        'brokerRegistrationNumber': _registrationNumberController.text.trim(),
        'ownerName': _ownerNameController.text.trim(),
        'businessName': _businessNameController.text.trim(),
        'phoneNumber': _phoneNumberController.text.trim(),
        'verified': false,
      };

      final errorMessage = await _firebaseService.registerBroker(
        brokerId: _emailController.text.trim(),
        password: _passwordController.text,
        brokerInfo: brokerInfo,
      );

      setState(() {
        _isLoading = false;
      });

      if (errorMessage == null && mounted) {
        AppSnackBar.success(context, '회원가입이 완료되었습니다!');

        final currentUser = FirebaseAuth.instance.currentUser;
        final uid = currentUser?.uid ?? '';

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => MLSBrokerDashboardPage(
              brokerId: uid,
              brokerName: _ownerNameController.text.trim().isNotEmpty
                  ? _ownerNameController.text.trim()
                  : '공인중개사',
              brokerData: {
                ...brokerInfo,
                'uid': uid,
                'email': _emailController.text.trim(),
                'userType': 'broker',
              },
            ),
          ),
          (route) => false,
        );
      } else if (mounted) {
        AppSnackBar.error(context, errorMessage ?? '회원가입에 실패했습니다. 다시 시도해주세요.');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        AppSnackBar.error(context, '일시적인 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.');
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
            foregroundColor: AirbnbColors.primary,
            elevation: 0.5,
            title: const HomeLogoButton(
              fontSize: 18,
              color: AirbnbColors.primary,
            ),
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: ResponsiveHelper.getMaxWidth(context)),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 제목
                          Text(
                          '공인중개사 회원가입',
                          style: AppTypography.withColor(AppTypography.h1, AirbnbColors.textPrimary),
                        ),
                        const SizedBox(height: 8),
                          Text(
                          '정보를 입력하고 회원가입을 완료하세요',
                          style: AppTypography.withColor(AppTypography.bodySmall, AirbnbColors.textSecondary),
                        ),

                        const SizedBox(height: 32),

                        // 중개사 정보 섹션
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AirbnbColors.background,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AirbnbColors.textPrimary.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Row(
                                children: [
                                  Icon(
                                    Icons.business_outlined,
                                    color: AirbnbColors.primary,
                                    size: 24,
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    '중개사 정보',
                                    style: AppTypography.withColor(AppTypography.h4, AirbnbColors.textPrimary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                controller: _registrationNumberController,
                                onChanged: (value) {
                                  if (_registrationNumberError != null) {
                                    setState(() => _registrationNumberError = null);
                                  }
                                },
                                decoration: InputDecoration(
                                  labelText: '중개업 등록번호 *',
                                  hintText: '예: 11230202200144',
                                  prefixIcon: const Icon(Icons.badge),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: _registrationNumberError != null ? AirbnbColors.error : AirbnbColors.border,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: _registrationNumberError != null ? AirbnbColors.error : AirbnbColors.primary,
                                      width: 2,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: AirbnbColors.textSecondary.withValues(alpha: 0.05),
                                  errorText: _registrationNumberError,
                                  errorStyle:  AppTypography.caption,
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                                ],
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return '등록번호를 입력해주세요.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _ownerNameController,
                                decoration: InputDecoration(
                                  labelText: '대표자명 *',
                                  hintText: '예: 김중개',
                                  prefixIcon: const Icon(Icons.person),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: AirbnbColors.textSecondary.withValues(alpha: 0.05),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return '대표자명을 입력해주세요.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _businessNameController,
                                onChanged: (value) {
                                  if (_businessNameError != null) {
                                    setState(() => _businessNameError = null);
                                  }
                                },
                                decoration: InputDecoration(
                                  labelText: '사업자상호 *',
                                  hintText: '예: ○○부동산',
                                  prefixIcon: const Icon(Icons.business),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: AirbnbColors.textSecondary.withValues(alpha: 0.05),
                                  errorText: _businessNameError,
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return '사업자상호를 입력해주세요.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _phoneNumberController,
                                decoration: InputDecoration(
                                  labelText: '전화번호 *',
                                  hintText: '예: 0212345678',
                                  prefixIcon: const Icon(Icons.phone),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: AirbnbColors.textSecondary.withValues(alpha: 0.05),
                                ),
                                keyboardType: TextInputType.phone,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                                ],
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return '전화번호를 입력해주세요.';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // 계정 정보 섹션
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AirbnbColors.background,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AirbnbColors.textPrimary.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Row(
                                children: [
                                  Icon(
                                    Icons.account_circle_outlined,
                                    color: AirbnbColors.primary,
                                    size: 24,
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    '계정 정보',
                                    style: AppTypography.withColor(AppTypography.h4, AirbnbColors.textPrimary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                controller: _emailController,
                                onChanged: (value) {
                                  if (_emailError != null) {
                                    setState(() => _emailError = null);
                                  }
                                },
                                decoration: InputDecoration(
                                  labelText: '이메일 *',
                                  hintText: '예: broker@example.com',
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
                                  filled: true,
                                  fillColor: AirbnbColors.textSecondary.withValues(alpha: 0.05),
                                  errorText: _emailError,
                                  errorStyle:  AppTypography.caption,
                                ),
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return '이메일을 입력해주세요';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordController,
                                onChanged: (value) {
                                  if (_passwordError != null) {
                                    setState(() => _passwordError = null);
                                  }
                                },
                                decoration: InputDecoration(
                                  labelText: '비밀번호 *',
                                  hintText: '6자 이상',
                                  prefixIcon: const Icon(Icons.lock),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
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
                                  filled: true,
                                  fillColor: AirbnbColors.textSecondary.withValues(alpha: 0.05),
                                  errorText: _passwordError,
                                  errorStyle:  AppTypography.caption,
                                ),
                                obscureText: _obscurePassword,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return '비밀번호를 입력해주세요';
                                  }
                                  if (!ValidationUtils.isValidPasswordLength(value)) {
                                    return '비밀번호는 6자 이상이어야 합니다';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordConfirmController,
                                onChanged: (value) {
                                  if (_passwordConfirmError != null) {
                                    setState(() => _passwordConfirmError = null);
                                  }
                                },
                                decoration: InputDecoration(
                                  labelText: '비밀번호 확인 *',
                                  hintText: '비밀번호를 다시 입력하세요',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePasswordConfirm
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePasswordConfirm = !_obscurePasswordConfirm;
                                      });
                                    },
                                  ),
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
                                  filled: true,
                                  fillColor: AirbnbColors.textSecondary.withValues(alpha: 0.05),
                                  errorText: _passwordConfirmError,
                                  errorStyle:  AppTypography.caption,
                                ),
                                obscureText: _obscurePasswordConfirm,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return '비밀번호 확인을 입력해주세요';
                                  }
                                  if (!ValidationUtils.doPasswordsMatch(_passwordController.text, value)) {
                                    return '비밀번호가 일치하지 않습니다';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // 회원가입 버튼
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _submitSignup,
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
                              style: AppTypography.h4,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AirbnbColors.primary,
                              foregroundColor: AirbnbColors.background,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // 로그인으로 이동
                        Center(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child:   Text(
                              '이미 계정이 있으신가요? 로그인',
                              style: AppTypography.withColor(AppTypography.bodySmall, AirbnbColors.primary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
