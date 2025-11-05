import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/api_request/seoul_broker_service.dart';
import 'package:property/widgets/home_logo_button.dart';
import 'package:property/utils/validation_utils.dart';

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
  bool _isValidating = false;
  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;
  SeoulBrokerInfo? _validatedBrokerInfo;

  final FirebaseService _firebaseService = FirebaseService();

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

  /// 등록번호 및 대표자명 검증
  Future<void> _validateBroker() async {
    if (_registrationNumberController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('등록번호를 입력해주세요.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_ownerNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('대표자명을 입력해주세요.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isValidating = true;
      _validatedBrokerInfo = null;
    });

    try {
      // 등록번호 중복 확인
      final existingBroker = await _firebaseService.getBrokerByRegistrationNumber(
        _registrationNumberController.text.trim(),
      );

      if (existingBroker != null) {
        setState(() {
          _isValidating = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('이미 가입된 등록번호입니다. 로그인해주세요.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // API 검증
      final result = await SeoulBrokerService.validateBroker(
        registrationNumber: _registrationNumberController.text.trim(),
        ownerName: _ownerNameController.text.trim(),
      );

      setState(() {
        _isValidating = false;
      });

      if (result.isValid && result.brokerInfo != null) {
        setState(() {
          _validatedBrokerInfo = result.brokerInfo;
        });

        // 검증된 정보로 자동 채우기
        _businessNameController.text = result.brokerInfo!.businessName;
        if (result.brokerInfo!.phoneNumber.isNotEmpty) {
          _phoneNumberController.text = result.brokerInfo!.phoneNumber;
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ 검증 성공! 정보가 자동으로 입력되었습니다.'),
              backgroundColor: AppColors.kSuccess,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.errorMessage ?? '검증에 실패했습니다.'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isValidating = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('검증 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 회원가입 제출
  Future<void> _submitSignup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 비밀번호 확인
    if (!ValidationUtils.doPasswordsMatch(_passwordController.text, _passwordConfirmController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('비밀번호가 일치하지 않습니다.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 등록번호 검증 비활성화 - 검증 없이도 회원가입 가능
    // 검증 정보가 있으면 사용하고, 없으면 직접 입력한 값 사용

    setState(() {
      _isLoading = true;
    });

    try {
      // Firebase에 저장
      // 검증 정보가 있으면 사용하고, 없으면 직접 입력한 값 사용
      final errorMessage = await _firebaseService.registerBroker(
        brokerId: _emailController.text.trim(),
        password: _passwordController.text,
        brokerInfo: {
          'brokerRegistrationNumber': _validatedBrokerInfo?.registrationNumber ?? _registrationNumberController.text.trim(),
          'ownerName': _validatedBrokerInfo?.ownerName ?? _ownerNameController.text.trim(),
          'businessName': _businessNameController.text.trim(),
          'phoneNumber': _phoneNumberController.text.trim(),
          'systemRegNo': _validatedBrokerInfo?.systemRegNo,
          'address': _validatedBrokerInfo?.address,
          'verified': _validatedBrokerInfo != null, // 검증 여부
        },
      );

      setState(() {
        _isLoading = false;
      });

      if (errorMessage == null && mounted) {
        // 성공 메시지
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('회원가입이 완료되었습니다!'),
            backgroundColor: AppColors.kSuccess,
          ),
        );

        // 로그인 페이지로 이동 (성공 정보 전달)
        Navigator.pop(context, {
          'brokerId': _emailController.text.trim(),
          'password': _passwordController.text,
        });
      } else if (mounted) {
        // 에러 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage ?? '회원가입에 실패했습니다. 다시 시도해주세요.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kBackground,
      appBar: AppBar(
        title: const HomeLogoButton(fontSize: 18),
        backgroundColor: AppColors.kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 제목
              const Text(
                '공인중개사 회원가입',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '등록번호 검증은 선택사항입니다 (검증 없이도 가입 가능)',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),

              const SizedBox(height: 32),

              // 등록번호 검증 섹션
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _validatedBrokerInfo != null
                        ? AppColors.kSuccess
                        : Colors.grey.withValues(alpha: 0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
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
                          _validatedBrokerInfo != null
                              ? Icons.verified
                              : Icons.verified_user,
                          color: _validatedBrokerInfo != null
                              ? AppColors.kSuccess
                              : AppColors.kPrimary,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          '등록번호 검증',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                        if (_validatedBrokerInfo != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.kSuccess.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              '검증 완료',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.kSuccess,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _registrationNumberController,
                      decoration: InputDecoration(
                        labelText: '중개업 등록번호 *',
                        hintText: '예: 11230-2022-00144',
                        prefixIcon: const Icon(Icons.badge),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.withValues(alpha: 0.05),
                      ),
                      enabled: !_isValidating,
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
                        fillColor: Colors.grey.withValues(alpha: 0.05),
                      ),
                      enabled: !_isValidating,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '대표자명을 입력해주세요.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isValidating ? null : _validateBroker,
                        icon: _isValidating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.verified_user, size: 20),
                        label: Text(
                          _isValidating ? '검증 중...' : '등록번호 검증하기',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.kPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 기본 정보 섹션
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '기본 정보',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: '이메일 또는 ID *',
                        hintText: '예: broker@example.com 또는 broker123',
                        prefixIcon: const Icon(Icons.email),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.withValues(alpha: 0.05),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '이메일 또는 ID를 입력해주세요.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
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
                        filled: true,
                        fillColor: Colors.grey.withValues(alpha: 0.05),
                      ),
                      obscureText: _obscurePassword,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '비밀번호를 입력해주세요.';
                        }
                        if (!ValidationUtils.isValidPasswordLength(value)) {
                          return '비밀번호는 6자 이상이어야 합니다.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordConfirmController,
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
                        filled: true,
                        fillColor: Colors.grey.withValues(alpha: 0.05),
                      ),
                      obscureText: _obscurePasswordConfirm,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '비밀번호 확인을 입력해주세요.';
                        }
                        if (!ValidationUtils.doPasswordsMatch(_passwordController.text, value)) {
                          return '비밀번호가 일치하지 않습니다.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _businessNameController,
                      decoration: InputDecoration(
                        labelText: '사업자상호 *',
                        hintText: '예: ○○부동산',
                        prefixIcon: const Icon(Icons.business),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.withValues(alpha: 0.05),
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
                        labelText: '전화번호',
                        hintText: '예: 02-1234-5678',
                        prefixIcon: const Icon(Icons.phone),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.withValues(alpha: 0.05),
                      ),
                      keyboardType: TextInputType.phone,
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
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.person_add, size: 24),
                  label: Text(
                    _isLoading ? '가입 중...' : '회원가입',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.kPrimary,
                    foregroundColor: Colors.white,
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
                  child: const Text(
                    '이미 계정이 있으신가요? 로그인',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.kPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


