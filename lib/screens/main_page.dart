import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/api_request/firebase_service.dart';
import 'home_page.dart';
import 'userInfo/personal_info_page.dart';
import 'propertyMgmt/house_management_page.dart';
import 'propertySale/house_market_page.dart';
import 'login_page.dart';
import 'broker/broker_dashboard_page.dart';
import 'notification/notification_page.dart';

class MainPage extends StatefulWidget {
  final String userId;
  final String userName;
  final int initialTabIndex;

  const MainPage({
    required this.userId,
    required this.userName,
    this.initialTabIndex = 0,
    super.key,
  });

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = true;
  int _currentIndex = 0; // 현재 선택된 탭 인덱스

  bool _isBroker = false;
  Map<String, dynamic>? _brokerData;

  // 탭별 페이지들
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _initializePages();
    _checkBrokerRole();
    final initialIndex = widget.initialTabIndex;
    if (initialIndex >= 0 && initialIndex < _pages.length) {
      _currentIndex = initialIndex;
    } else {
      _currentIndex = 0;
    }
  }

  Future<void> _checkBrokerRole() async {
    if (widget.userId.isEmpty) return;
    try {
      final data = await _firebaseService.getBroker(widget.userId);
      if (!mounted) return;
      if (data != null) {
        setState(() {
          _isBroker = true;
          _brokerData = data;
        });
      }
    } catch (_) {
      // 브로커 아님 또는 오류는 무시
    }
  }

  void _initializePages() {
    // 메인 탭 구성
    // 0: 내집팔기
    // 1: 내집구매 (구매자용 내집사기/내집구매)
    // 2: 내집관리
    // 3: 내 정보
    _pages = [
      HomePage(userId: widget.userId, userName: widget.userName), // 내집팔기
      HouseMarketPage(
        userName: widget.userName,
      ), // 내집구매
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
      body: IndexedStack(index: _currentIndex, children: _pages),
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
      title: isMobile ? _buildMobileHeader() : _buildDesktopHeader(),
      actions: [
        if (widget.userId.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.black87),
            tooltip: '알림',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NotificationPage(userId: widget.userId),
                ),
              );
            },
          ),
        if (_isBroker)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: () {
                final brokerId = _brokerData?['brokerId'] as String? ??
                    widget.userId;
                final brokerName =
                    _brokerData?['ownerName'] as String? ??
                        _brokerData?['businessName'] as String? ??
                        widget.userName;
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => BrokerDashboardPage(
                      brokerId: brokerId,
                      brokerName: brokerName,
                      brokerData: {
                        ...?_brokerData,
                        'uid': widget.userId,
                        'brokerId': brokerId,
                      },
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.business, size: 20, color: AppColors.kPrimary),
              label: const Text(
                '중개사 대시보드',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.kPrimary,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMobileHeader() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isVerySmallScreen = screenWidth < 360;
    final horizontalGap = isVerySmallScreen ? 4.0 : 6.0;

    // 모바일에서는 항상 화면 폭 안에 3개의 탭이 모두 보이도록
    // 가로 스크롤을 없애고 Expanded 로 균등 분배한다.
    // 아주 좁은 화면에서는 아이콘만 보이도록 처리해 가독성을 유지한다.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: _buildNavButton(
              '내집팔기',
              0,
              Icons.add_home_rounded,
              isMobile: true,
              showLabelOnly: !isVerySmallScreen,
            ),
          ),
          SizedBox(width: horizontalGap),
          Expanded(
            child: _buildNavButton(
              '내집구매',
              1,
              Icons.search_rounded,
              isMobile: true,
              showLabelOnly: !isVerySmallScreen,
            ),
          ),
          SizedBox(width: horizontalGap),
          Expanded(
            child: _buildNavButton(
              '내집관리',
              2,
              Icons.home_work_rounded,
              isMobile: true,
              showLabelOnly: !isVerySmallScreen,
            ),
          ),
          SizedBox(width: horizontalGap),
          Expanded(
            child: _buildNavButton(
              '내 정보',
              3,
              Icons.person_rounded,
              isMobile: true,
              showLabelOnly: !isVerySmallScreen,
            ),
          ),
        ],
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

        // 네비게이션 메뉴
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: _buildNavButton('내집팔기', 0, Icons.add_home_rounded),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: _buildNavButton('내집구매', 1, Icons.search_rounded),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: _buildNavButton('내집관리', 2, Icons.home_work_rounded),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: _buildNavButton('내 정보', 3, Icons.person_rounded),
              ),
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

  Future<void> _login({int? targetIndex}) async {
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
        ((result['userId'] is String &&
                (result['userId'] as String).isNotEmpty) ||
            (result['userName'] is String &&
                (result['userName'] as String).isNotEmpty))) {
      final String userId =
          (result['userId'] is String &&
              (result['userId'] as String).isNotEmpty)
          ? result['userId']
          : result['userName'];
      final String userName =
          (result['userName'] is String &&
              (result['userName'] as String).isNotEmpty)
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
              initialTabIndex: targetIndex ?? 0,
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
                  builder: (context) =>
                      const MainPage(userId: '', userName: ''),
                ),
              );
            },
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton(
    String label,
    int index,
    IconData icon, {
    bool isMobile = false,
    bool showLabelOnly = true,
  }) {
    final isSelected = _currentIndex == index;
    final isLoggedIn = widget.userName.isNotEmpty;

    return InkWell(
      onTap: () {
        // 로그인이 필요한 페이지 (현재 탭 구성: 0=내집팔기, 1=내집구매, 2=내집관리, 3=내 정보)
        // 내집구매(1번 탭)는 비로그인도 사용 가능, 내집관리/내 정보(2,3)는 로그인 필요
        if (!isLoggedIn && index >= 2) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('로그인이 필요한 서비스입니다.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
          _login(targetIndex: index);
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
          vertical: isMobile ? 6 : 10,
        ),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.kPrimary.withValues(alpha: 0.7) : Colors.transparent,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.kPrimary : Colors.grey[700],
              size: isMobile ? 22 : 20,
            ),
            if (showLabelOnly) ...[
              SizedBox(width: isMobile ? 4 : 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? AppColors.kPrimary : Colors.grey[700],
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: isMobile ? 13 : 15,
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
