import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/api_request/firebase_service.dart';
import 'propertySale/house_market_page.dart';
import 'home_page.dart';
import 'userInfo/personal_info_page.dart';
import 'propertyMgmt/house_management_page.dart';
import 'login_page.dart';

class MainPage extends StatefulWidget {
  final String userId;
  final String userName;

  const MainPage({
    required this.userId,
    required this.userName,
    super.key,
  });

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = true;
  int _currentIndex = 0; // 현재 선택된 탭 인덱스

  // 탭별 페이지들
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _initializePages();
  }

  void _initializePages() {
    _pages = [
      HomePage(userName: widget.userName), // 내집팔기
      HouseMarketPage(userName: widget.userName), // 내집사기
      HouseManagementPage(
        userId: widget.userId,
        userName: widget.userName,
      ), // 내집관리
      PersonalInfoPage(
        userId: widget.userId,
        userName: widget.userName,
      ), // 내 정보
    ];
  }

  Future<void> _loadUserData() async {
    try {
      // 사용자 정보 로드
      await _firebaseService.getUser(widget.userId);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('사용자 데이터 로드 오류: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.kBackground,
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.kPrimary),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.kBackground,
      appBar: _buildTopNavigationBar(),
      body: IndexedStack(index: _currentIndex, children: _pages,),
    );
  }

  PreferredSizeWidget _buildTopNavigationBar() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 2,
      toolbarHeight: 70,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      surfaceTintColor: Colors.transparent,
      title: isMobile
          ? _buildMobileHeader()
          : _buildDesktopHeader(),
    );
  }

  Widget _buildMobileHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(child: _buildNavButton('내집팔기', 0, Icons.add_home_rounded, isMobile: true)),
        const SizedBox(width: 4),
        Expanded(child: _buildNavButton('내집사기', 1, Icons.list_alt_rounded, isMobile: true)),
        const SizedBox(width: 4),
        Expanded(child: _buildNavButton('내집관리', 2, Icons.home_work_rounded, isMobile: true)),
        const SizedBox(width: 4),
        Expanded(child: _buildNavButton('내 정보', 3, Icons.person_rounded, isMobile: true)),
      ],
    );
  }

  Widget _buildDesktopHeader() {
    final isLoggedIn = widget.userName.isNotEmpty;

    return Row(
      children: [
        // 로고
        const Text(
          'MyHome',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.kPrimary,
          ),
        ),
        const SizedBox(width: 60),
        
        // 네비게이션 메뉴
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(child: _buildNavButton('내집팔기', 0, Icons.add_home_rounded)),
              const SizedBox(width: 4),
              Flexible(child: _buildNavButton('내집사기', 1, Icons.list_alt_rounded)),
              const SizedBox(width: 4),
              Flexible(child: _buildNavButton('내집관리', 2, Icons.home_work_rounded)),
              const SizedBox(width: 4),
              Flexible(child: _buildNavButton('내 정보', 3, Icons.person_rounded)),
            ],
          ),
        ),
        
        // 로그인/로그아웃 버튼
        _buildAuthButton(isLoggedIn),
      ],
    );
  }

  Widget _buildAuthButton(bool isLoggedIn) {
    return InkWell(
      onTap: () {
        if (isLoggedIn) {
          _logout();
        } else {
          _login();
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.kPrimary.withValues(alpha: 0.08), // 단색 배경
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.kPrimary.withValues(alpha: 0.3), // 테두리 강화
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isLoggedIn ? Icons.logout : Icons.login,
              color: AppColors.kPrimary,
              size: 20,
            ),
            const SizedBox(width: 6),
            Text(
              isLoggedIn ? '로그아웃' : '로그인',
              style: const TextStyle(
                color: AppColors.kPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _login() async {
    print('🚀 [MainPage] 로그인 페이지로 이동');
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
    
    print('🔙 [MainPage] 로그인 페이지에서 돌아옴');
    print('   반환된 result: $result');
    print('   result 타입: ${result.runtimeType}');
    
    // 로그인 성공 시 사용자 정보를 받아서 페이지 새로고침
    if (result is Map &&
        ((result['userId'] is String && (result['userId'] as String).isNotEmpty) ||
         (result['userName'] is String && (result['userName'] as String).isNotEmpty))) {
      print('✅ [MainPage] 로그인 데이터 수신 성공');
      final String userId = (result['userId'] is String && (result['userId'] as String).isNotEmpty)
          ? result['userId']
          : result['userName'];
      final String userName = (result['userName'] is String && (result['userName'] as String).isNotEmpty)
          ? result['userName']
          : result['userId'];
      
      print('   UserID: $userId');
      print('   UserName: $userName');
      
      if (mounted) {
        print('🔄 [MainPage] MainPage 재로드 중...');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => MainPage(
              userId: userId,
              userName: userName,
            ),
          ),
        );
        print('✅ [MainPage] MainPage 재로드 완료');
      }
    } else {
      print('⚠️ [MainPage] 로그인 취소 또는 실패');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('로그인에 실패했습니다. 이메일/비밀번호를 확인해주세요.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const MainPage(
                    userId: '',
                    userName: '',
                  ),
                ),
              );
            },
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton(String label, int index, IconData icon, {bool isMobile = false}) {
    final isSelected = _currentIndex == index;
    final isLoggedIn = widget.userName.isNotEmpty;
    
    return InkWell(
      onTap: () {
        // 로그인이 필요한 페이지 (내집관리: 2, 내 정보: 3)
        if (!isLoggedIn && (index == 2 || index == 3)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('로그인이 필요한 서비스입니다.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
          _login();
          return;
        }
        
        setState(() {
          _currentIndex = index;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 4 : 16,
          vertical: isMobile ? 6 : 12,
        ),
        decoration: BoxDecoration(
          gradient: isSelected 
            ? LinearGradient(
                colors: const [AppColors.kPrimary, AppColors.kSecondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected 
            ? [
                BoxShadow(
                  color: AppColors.kPrimary.withValues(alpha: 0.3),
                  offset: const Offset(0, 2),
                  blurRadius: 6,
                ),
              ]
            : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey[700],
              size: isMobile ? 22 : 20,
            ),
            SizedBox(width: isMobile ? 4 : 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: isMobile ? 13 : 15,
                  shadows: isSelected 
                    ? [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          offset: const Offset(0, 1),
                          blurRadius: 2,
                        ),
                      ]
                    : null,
                ),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}