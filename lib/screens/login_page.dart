import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/api_request/firebase_service.dart';
import 'forgot_password_page.dart';
import 'user_type_selection_page.dart';

/// 통합 로그인 페이지 (일반 사용자/공인중개사 자동 구분)
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // 로그인 필드
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  final FirebaseService _firebaseService = FirebaseService();

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 통합 로그인 (일반 사용자/공인중개사 자동 구분)
  Future<void> _login() async {
    if (_idController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('아이디와 비밀번호를 입력해주세요.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _firebaseService.authenticateUnified(
        _idController.text.trim(),
        _passwordController.text,
      );

      if (result != null && mounted) {
        final userType = result['userType'] ?? 'user';
        
        if (userType == 'broker') {
          // 공인중개사 로그인
          final brokerId = result['brokerId'] ?? result['uid'];
          final brokerName = result['ownerName'] ?? result['businessName'] ?? '공인중개사';
          
          Navigator.of(context).pop({
            'userId': brokerId,
            'userName': brokerName,
            'userType': 'broker',
            'brokerData': result,
          });
        } else {
          // 일반 사용자 로그인
          final userId = result['uid'] ?? result['id'] ?? _idController.text;
          final userName = result['name'] ?? userId;
          
          Navigator.of(context).pop({
            'userId': userId,
            'userName': userName,
            'userType': 'user',
          });
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('로그인에 실패했습니다. 아이디와 비밀번호를 확인해주세요.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = '로그인에 실패했습니다.';
      
      switch (e.code) {
        case 'user-not-found':
          errorMessage = '등록되지 않은 이메일입니다.\n회원가입을 먼저 진행해주세요.';
          break;
        case 'wrong-password':
          errorMessage = '비밀번호가 올바르지 않습니다.';
          break;
        case 'invalid-email':
          errorMessage = '이메일 형식이 올바르지 않습니다.';
          break;
        default:
          errorMessage = '로그인 중 오류가 발생했습니다.';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('로그인 중 오류가 발생했습니다: ${e.toString()}'),
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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.kPrimary,
        elevation: 2,
        toolbarHeight: 70,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: InkWell(
          onTap: () {
            // 메인 페이지로 이동
            Navigator.of(context).pop();
          },
          borderRadius: BorderRadius.circular(8),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              'MyHome',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.kPrimary,
              ),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.kPrimary, AppColors.kSecondary],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 480),
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      offset: const Offset(0, 8),
                      blurRadius: 24,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 타이틀 섹션
                    Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.kPrimary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.lock_outline,
                              size: 32,
                              color: AppColors.kPrimary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            '로그인',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppColors.kTextPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '계정에 로그인하여 서비스를 이용하세요',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.kTextSecondary,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    
                    // 아이디 입력
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '아이디',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.kTextSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _idController,
                          style: const TextStyle(fontSize: 16),
                          decoration: InputDecoration(
                            hintText: '아이디를 입력하세요',
                            hintStyle: TextStyle(
                              color: AppColors.kTextLight,
                              fontSize: 15,
                            ),
                            prefixIcon: Icon(
                              Icons.person_outline,
                              color: AppColors.kTextSecondary,
                              size: 20,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
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
                            fillColor: Colors.grey[50],
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // 비밀번호 입력
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '비밀번호',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.kTextSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: const TextStyle(fontSize: 16),
                          decoration: InputDecoration(
                            hintText: '비밀번호를 입력하세요',
                            hintStyle: TextStyle(
                              color: AppColors.kTextLight,
                              fontSize: 15,
                            ),
                            prefixIcon: Icon(
                              Icons.lock_outline,
                              color: AppColors.kTextSecondary,
                              size: 20,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                size: 20,
                                color: AppColors.kTextSecondary,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
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
                            fillColor: Colors.grey[50],
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    
                    // 로그인 버튼
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                        child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.kPrimary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                '로그인',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // 회원가입 안내 섹션
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.kPrimary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.kPrimary.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '계정이 없으신가요? ',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.kTextSecondary,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const UserTypeSelectionPage(),
                                ),
                              );
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              '회원가입',
                              style: TextStyle(
                                color: AppColors.kPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // 링크들 (아이디 찾기 | 비밀번호 찾기)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('아이디 찾기 기능은 준비 중입니다.'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          child: Text(
                            '아이디 찾기',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 12,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ForgotPasswordPage(),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          child: Text(
                            '비밀번호 찾기',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
