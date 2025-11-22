import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/widgets/home_logo_button.dart';
import 'package:property/utils/validation_utils.dart';
import 'package:property/screens/login_page.dart';

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

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }
  
  Color _getPasswordStrengthColor(int strength) {
    if (strength <= 1) return Colors.red;
    if (strength == 2) return Colors.orange;
    if (strength == 3) return Colors.blue;
    return Colors.green;
  }

  Future<void> _signup() async {
    // 필수 입력 검증 (이메일, 비밀번호만)
    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _passwordConfirmController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이메일과 비밀번호를 입력해주세요.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // 이메일 형식 검증
    if (!ValidationUtils.isValidEmail(_emailController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('올바른 이메일 형식을 입력해주세요.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // 휴대폰 번호 형식 검증 (입력된 경우만)
    if (_phoneController.text.isNotEmpty) {
      final phone = _phoneController.text.replaceAll('-', '').replaceAll(' ', '');
      if (!RegExp(r'^01[0-9]{8,9}$').hasMatch(phone)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('올바른 휴대폰 번호를 입력해주세요. (예: 010-1234-5678)'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    // 비밀번호 길이 검증 (6자 이상)
    if (!ValidationUtils.isValidPasswordLength(_passwordController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('비밀번호는 6자 이상 입력해주세요.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 비밀번호 일치 확인
    if (!ValidationUtils.doPasswordsMatch(_passwordController.text, _passwordConfirmController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('비밀번호가 일치하지 않습니다.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // 약관 동의 확인
    if (!_agreeToTerms || !_agreeToPrivacy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('필수 약관에 동의해주세요.'),
          backgroundColor: Colors.red,
        ),
      );
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
        role: 'user', // 모든 사용자는 일반 사용자로 등록
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('회원가입이 완료되었습니다. 로그인해주세요.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const LoginPage(returnResult: false),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('이미 존재하는 이메일입니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('회원가입 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
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
    return Scaffold(
      backgroundColor: AppColors.kBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.kPrimary,
        elevation: 0.5,
        title: const HomeLogoButton(
          fontSize: 18,
          color: AppColors.kPrimary,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 제목
            const Text(
              '일반 회원가입',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.kTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '이메일과 비밀번호로 간단하게 가입하세요',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.kTextLight,
              ),
            ),

            const SizedBox(height: 32),

            // 회원가입 폼
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.kSurface,
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
                      color: AppColors.kTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // 이메일 입력 (필수)
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: '이메일 *',
                      hintText: '예: user@example.com',
                      prefixIcon: const Icon(Icons.email),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.kPrimary, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.grey.withValues(alpha: 0.05),
                      helperText: '이메일이 로그인 ID로 사용됩니다',
                      helperStyle: TextStyle(fontSize: 12, color: AppColors.kTextLight),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 휴대폰 번호 입력 (선택)
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: '휴대폰 번호',
                      hintText: '예: 010-1234-5678',
                      prefixIcon: const Icon(Icons.phone),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.kPrimary, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.grey.withValues(alpha: 0.05),
                      helperText: '본인 확인 및 비밀번호 찾기에 사용됩니다',
                      helperStyle: TextStyle(fontSize: 12, color: AppColors.kTextLight),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 비밀번호 입력
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    onChanged: (value) => setState(() {}), // 강도 표시 업데이트
                    decoration: InputDecoration(
                      labelText: '비밀번호 *',
                      hintText: '6자 이상 (영문, 숫자, 특수문자 조합 권장)',
                      prefixIcon: const Icon(Icons.lock),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.kPrimary, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.grey.withValues(alpha: 0.05),
                    ),
                  ),
                  
                  // 비밀번호 강도 표시
                  if (_passwordController.text.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const SizedBox(width: 12),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: ValidationUtils.getPasswordStrength(_passwordController.text) / 4,
                            backgroundColor: Colors.grey[300],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _getPasswordStrengthColor(ValidationUtils.getPasswordStrength(_passwordController.text)),
                            ),
                            minHeight: 4,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          ValidationUtils.getPasswordStrengthText(ValidationUtils.getPasswordStrength(_passwordController.text)),
                          style: TextStyle(
                            fontSize: 12,
                            color: _getPasswordStrengthColor(ValidationUtils.getPasswordStrength(_passwordController.text)),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                    ),
                  ],
                  
                  const SizedBox(height: 16),
                  
                  // 비밀번호 확인 입력
                  TextField(
                    controller: _passwordConfirmController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: '비밀번호 확인 *',
                      hintText: '비밀번호를 다시 입력하세요',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.kPrimary, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.grey.withValues(alpha: 0.05),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // 약관 동의
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      children: [
                        CheckboxListTile(
                          value: _agreeToTerms,
                          onChanged: (value) => setState(() => _agreeToTerms = value ?? false),
                          title: const Text('서비스 이용약관 동의 (필수)', style: TextStyle(fontSize: 14)),
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                          activeColor: AppColors.kPrimary,
                        ),
                        CheckboxListTile(
                          value: _agreeToPrivacy,
                          onChanged: (value) => setState(() => _agreeToPrivacy = value ?? false),
                          title: const Text('개인정보 처리방침 동의 (필수)', style: TextStyle(fontSize: 14)),
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                          activeColor: AppColors.kPrimary,
                        ),
                        CheckboxListTile(
                          value: _agreeToMarketing,
                          onChanged: (value) => setState(() => _agreeToMarketing = value ?? false),
                          title: const Text('마케팅 정보 수신 동의 (선택)', style: TextStyle(fontSize: 14)),
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                          activeColor: AppColors.kPrimary,
                        ),
                      ],
                    ),
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
                onPressed: _isLoading ? null : _signup,
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
    );
  }
}

