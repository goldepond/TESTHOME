import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../services/firebase_service.dart';
import 'main_page.dart';
import 'admin/admin_dashboard.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  final FirebaseService _firebaseService = FirebaseService();

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

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
      final userData = await _firebaseService.authenticateUser(
        _idController.text,
        _passwordController.text,
      );

      if (userData != null && mounted) {
        // admin 사용자인지 확인
        final userRole = userData['role'] ?? 'user';
        final userId = _idController.text;
        final userName = userData['name'] ?? userId;
        
        if (userRole == 'admin') {
          // 관리자 페이지로 이동
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => AdminDashboard(
                userId: userId,
                userName: userName,
              ),
            ),
          );
        } else {
          // 일반 사용자 페이지로 이동
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => MainPage(
                userId: userId,
                userName: userName,
              ),
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('로그인에 실패했습니다. 아이디와 비밀번호를 확인해주세요.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('로그인 중 오류가 발생했습니다: $e'),
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.kGradientStart, AppColors.kGradientEnd],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 로고 영역
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha:0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: const [
                        Text(
                          '🏠',
                          style: TextStyle(fontSize: 80),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'HouseMVP',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.kPrimary,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '안전하고 편리한 부동산 거래',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.kDarkBrown,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // 로그인 폼
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha:0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          '로그인',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.kBrown,
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // 아이디 입력
                        TextField(
                          controller: _idController,
                          decoration: const InputDecoration(
                            labelText: '아이디',
                            prefixIcon: Icon(Icons.person, color: AppColors.kBrown),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide(color: AppColors.kBrown, width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // 비밀번호 입력
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: '비밀번호',
                            prefixIcon: Icon(Icons.lock, color: AppColors.kBrown),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide(color: AppColors.kBrown, width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // 로그인 버튼
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.kBrown,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text('로그인'),
                          ),
                        ),
                      ],
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