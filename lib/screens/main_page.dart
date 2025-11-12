import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/api_request/firebase_service.dart';
import 'home_page.dart';
import 'propertySale/house_market_page.dart'; // 내집사기 페이지
import 'userInfo/personal_info_page.dart';
import 'propertyMgmt/house_management_page.dart';
import 'quote_history_page.dart';
import 'login_page.dart';
import 'broker/broker_dashboard_page.dart';

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
      HomePage(userId: widget.userId, userName: widget.userName), // 내집팔기
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isVerySmallScreen = screenWidth < 360;
    final buttonWidth = isVerySmallScreen ? 120.0 : 140.0;

    final List<Widget> items = [];

    if (widget.userName.isNotEmpty) {
      items.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: isVerySmallScreen
              ? SizedBox(
                  width: 44,
                  height: 44,
                  child: IconButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => QuoteHistoryPage(
                            userName: widget.userName,
                            userId: widget.userId,
                          ),
                        ),
                      );
                    },
                    tooltip: '현황 보기',
                    icon: const Icon(Icons.history, color: AppColors.kPrimary, size: 20),
                  ),
                )
              : OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => QuoteHistoryPage(
                          userName: widget.userName,
                          userId: widget.userId,
                        ),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.kPrimary,
                    side: const BorderSide(color: AppColors.kPrimary),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text('현황 보기', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
        ),
      );
    }

    items.addAll([
      SizedBox(
        width: buttonWidth,
        child: _buildNavButton('내집팔기', 0, Icons.add_home_rounded, isMobile: true, showLabelOnly: !isVerySmallScreen),
      ),
      SizedBox(width: isVerySmallScreen ? 6 : 8),
      SizedBox(
        width: buttonWidth,
        child: _buildNavButton('내집사기', 1, Icons.list_alt_rounded, isMobile: true, showLabelOnly: !isVerySmallScreen),
      ),
      SizedBox(width: isVerySmallScreen ? 6 : 8),
      SizedBox(
        width: buttonWidth,
        child: _buildNavButton('내집관리', 2, Icons.home_work_rounded, isMobile: true, showLabelOnly: !isVerySmallScreen),
      ),
      SizedBox(width: isVerySmallScreen ? 6 : 8),
      SizedBox(
        width: buttonWidth,
        child: _buildNavButton('내 정보', 3, Icons.person_rounded, isMobile: true, showLabelOnly: !isVerySmallScreen),
      ),
    ]);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: items,
      ),
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
        const SizedBox(width: 24),
        if (isLoggedIn)
          Padding(
            padding: const EdgeInsets.only(right: 24),
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => QuoteHistoryPage(
                      userName: widget.userName,
                      userId: widget.userId,
                    ),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.kPrimary,
                side: const BorderSide(color: AppColors.kPrimary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              icon: const Icon(Icons.history, size: 18),
              label: const Text('현황 보기'),
            ),
          ),
        const SizedBox(width: 36),
        
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
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
    
    // 사용자가 뒤로가기로 취소한 경우 (result가 null)
    if (result == null) {
      // 취소한 경우는 아무 메시지도 표시하지 않음
      return;
    }
    
    // 로그인 성공 시 사용자 정보를 받아서 페이지 새로고침
    if (result is Map &&
        ((result['userId'] is String && (result['userId'] as String).isNotEmpty) ||
         (result['userName'] is String && (result['userName'] as String).isNotEmpty))) {
      final String userId = (result['userId'] is String && (result['userId'] as String).isNotEmpty)
          ? result['userId']
          : result['userName'];
      final String userName = (result['userName'] is String && (result['userName'] as String).isNotEmpty)
          ? result['userName']
          : result['userId'];
      
      
      // 공인중개사 로그인인 경우 BrokerDashboardPage로 이동
      if (result['userType'] == 'broker' && result['brokerData'] != null) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => BrokerDashboardPage(
                brokerId: userId,
                brokerName: userName,
                brokerData: result['brokerData'],
              ),
            ),
          );
        }
        return;
      }
      
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => MainPage(
              userId: userId,
              userName: userName,
            ),
          ),
        );
      }
    } else {
      // 로그인 실패 (result가 있지만 유효한 데이터가 없는 경우)
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

  Widget _buildNavButton(String label, int index, IconData icon, {bool isMobile = false, bool showLabelOnly = true}) {
    final isSelected = _currentIndex == index;
    final isLoggedIn = widget.userName.isNotEmpty;
    
    return InkWell(
      onTap: () {
        // 로그인이 필요한 페이지 (현재 탭 구성: 0=내집팔기, 1=내집사기, 2=내집관리, 3=내 정보)
        if (!isLoggedIn && index >= 2) { // 내집관리, 내 정보만 로그인 필요
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
            if (showLabelOnly) ...[
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
          ],
        ),
      ),
    );
  }
}