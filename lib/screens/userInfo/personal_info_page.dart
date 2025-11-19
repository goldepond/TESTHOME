import 'dart:async';
import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/screens/main_page.dart';
import 'package:property/screens/change_password_page.dart';
import 'package:property/screens/policy/privacy_policy_page.dart';
import 'package:property/screens/policy/terms_of_service_page.dart';

class PersonalInfoPage extends StatefulWidget {
  final String userId;
  final String userName;

  const PersonalInfoPage({
    required this.userId,
    required this.userName,
    super.key,
  });

  @override
  State<PersonalInfoPage> createState() => _PersonalInfoPageState();
}

class _PersonalInfoPageState extends State<PersonalInfoPage> {
  final FirebaseService _firebaseService = FirebaseService();
  
  // 사용자 정보 관련 변수들
  Map<String, dynamic>? _userData;
  bool _isLoadingUserData = true;
  

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  
  Future<void> _loadUserData() async {
    if (mounted) {
      setState(() {
        _isLoadingUserData = true;
      });
    }
    
    try {
      final userData = await _firebaseService.getUser(widget.userId);
      if (mounted) {
        setState(() {
          _userData = userData;
          _isLoadingUserData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingUserData = false;
        });
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }


  // 로그아웃 기능
  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Firebase 로그아웃
      await _firebaseService.signOut();
      
      // 로그인 페이지로 이동하고 모든 이전 페이지 스택 제거
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const MainPage(
              userId: '',
              userName: '',
            ),
          ),
          (route) => false,
        );
      }
    }
  }

  // 회원탈퇴 기능
  Future<void> _deleteAccount(BuildContext context) async {
    // 첫 번째 확인 다이얼로그
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('회원탈퇴'),
        content: const Text(
          '정말 회원탈퇴를 하시겠습니까?\n\n'
          '탈퇴 시 모든 데이터가 삭제되며 복구할 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('탈퇴하기'),
          ),
        ],
      ),
    );

    if (firstConfirm != true) return;

    // 두 번째 확인 다이얼로그 (최종 확인)
    final finalConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          '⚠️ 최종 확인',
          style: TextStyle(color: Colors.red),
        ),
        content: const Text(
          '회원탈퇴를 진행하시겠습니까?\n\n'
          '이 작업은 되돌릴 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text(
              '탈퇴하기',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (finalConfirm != true) return;

    // 로딩 다이얼로그 표시
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('회원탈퇴 처리 중...'),
          ],
        ),
      ),
    );

    try {
      final errorMessage = await _firebaseService.deleteUserAccount(widget.userId);

      if (!context.mounted) return;
      Navigator.of(context).pop(); // 로딩 다이얼로그 닫기

      if (errorMessage == null) {
        // 성공
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('회원탈퇴가 완료되었습니다.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );

          // 메인 페이지로 이동하고 모든 스택 제거
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const MainPage(
                userId: '',
                userName: '',
              ),
            ),
            (route) => false,
          );
        }
      } else {
        // 실패
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop(); // 로딩 다이얼로그 닫기
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('회원탈퇴 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kBackground,
      body: SafeArea(
        child: Column(
          children: [
            // 상단 헤더 영역 (home_page와 통일)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              decoration: BoxDecoration(
                gradient: AppGradients.primaryDiagonal,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.kPrimary.withValues(alpha: 0.3),
                    offset: const Offset(0, 4),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.person_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '내 정보',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '내 계정 정보를 확인하고 관리하세요',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            // 메인 콘텐츠
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 사용자 정보 카드
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: Colors.white,
                      shadowColor: Colors.black.withValues(alpha: 0.06),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '내 정보',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.kBrown,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const ChangePasswordPage(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.password, color: Colors.white),
                                label: const Text(
                                  '비밀번호 변경',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
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
                            const SizedBox(height: 12),
                            if (_isLoadingUserData)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(20),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else ...[
                              if (_userData?['email'] != null) ...[
                                const SizedBox(height: 12),
                                _buildInfoRow(
                                  Icons.email_outlined, 
                                  '이메일', 
                                  _userData!['email'],
                                ),
                              ],
                              if (_userData?['phone'] != null && _userData!['phone'].toString().isNotEmpty) ...[
                                const SizedBox(height: 12),
                                _buildInfoRow(
                                  Icons.phone_outlined, 
                                  '전화번호', 
                                  _userData!['phone'],
                                ),
                              ],
                              const SizedBox(height: 12),
                              _buildInfoRow(
                                Icons.person, 
                                '이름', 
                                _userData?['name'] ?? widget.userName,
                              ),
                              const SizedBox(height: 12),
                              _buildInfoRow(
                                Icons.badge_outlined, 
                                '역할', 
                                _getRoleDisplayName(_userData?['role'] ?? 'user'),
                              ),
                            ],
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 계정 정보 섹션
                    if (_userData != null && !_isLoadingUserData) ...[
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        color: Colors.white,
                        shadowColor: Colors.black.withValues(alpha: 0.06),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '계정 정보',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.kBrown,
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (_userData?['createdAt'] != null) ...[
                                _buildInfoRow(
                                  Icons.calendar_today_outlined,
                                  '가입일',
                                  _formatDate(_userData!['createdAt']),
                                ),
                                const SizedBox(height: 12),
                              ],
                              if (_userData?['updatedAt'] != null && _userData!['updatedAt'] != _userData!['createdAt']) ...[
                                _buildInfoRow(
                                  Icons.update_outlined,
                                  '최종 수정일',
                                  _formatDate(_userData!['updatedAt']),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    
                    // 정책 및 도움말 섹션
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: Colors.white,
                      shadowColor: Colors.black.withValues(alpha: 0.06),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              child: Text(
                                '정책 및 도움말',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.kBrown,
                                ),
                              ),
                            ),
                            ListTile(
                              leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.kPrimary),
                              title: const Text('개인정보 처리방침'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
                                );
                              },
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.description_outlined, color: AppColors.kPrimary),
                              title: const Text('이용약관'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const TermsOfServicePage()),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // 로그아웃 섹션
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: Colors.white,
                      shadowColor: Colors.black.withValues(alpha: 0.06),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '계정 관리',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.kBrown,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: () => _logout(context),
                                icon: const Icon(Icons.logout, color: Colors.white),
                                label: const Text(
                                  '로그아웃',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: OutlinedButton.icon(
                                onPressed: () => _deleteAccount(context),
                                icon: const Icon(Icons.delete_forever, color: Colors.red),
                                label: const Text(
                                  '회원탈퇴',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red, width: 2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRoleDisplayName(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return '관리자';
      case 'broker':
        return '공인중개사';
      case 'user':
      default:
        return '일반 사용자';
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return '-';
    
    try {
      DateTime dateTime;
      if (date is String) {
        dateTime = DateTime.parse(date);
      } else if (date is DateTime) {
        dateTime = date;
      } else {
        return '-';
      }
      
      final year = dateTime.year;
      final month = dateTime.month.toString().padLeft(2, '0');
      final day = dateTime.day.toString().padLeft(2, '0');
      return '$year년 $month월 $day일';
    } catch (e) {
      return '-';
    }
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: AppColors.kBrown,
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 90,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.kDarkBrown,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.kDarkBrown,
            ),
          ),
        ),
      ],
    );
  }

} 