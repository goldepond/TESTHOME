import 'dart:async';
import 'package:flutter/material.dart';
import 'package:property/constants/apple_design_system.dart';
import 'package:property/constants/responsive_constants.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/api_request/log_service.dart';
import 'package:property/api_request/mls_property_service.dart';
import 'package:property/utils/logger.dart';
import 'package:property/widgets/home_logo_button.dart';
import 'package:property/widgets/offline_banner.dart';
import 'login_page.dart';
import 'auth/auth_landing_page.dart';
import 'broker/mls_broker_dashboard_page.dart';
import 'seller/mls_seller_dashboard_page.dart';
import 'seller/mls_quick_registration_page.dart';
import 'market_price/market_price_page.dart';
import 'public/public_listings_page.dart';
import 'notification/notification_page.dart';
import 'userInfo/personal_info_page.dart';

class MainPage extends StatefulWidget {
  final String userId;
  final String userName;
  final int initialTabIndex;

  const MainPage({
    required this.userId,
    required this.userName,
    this.initialTabIndex = -1, // -1 = 컨텍스트 기반 자동 결정
    super.key,
  });

  @override
  State<MainPage> createState() => MainPageState();
}

// LandingPage에서 접근할 수 있도록 public으로 변경
class MainPageState extends State<MainPage> {
  final FirebaseService _firebaseService = FirebaseService();
  final MLSPropertyService _mlsPropertyService = MLSPropertyService();
  final LogService _logService = LogService();
  int _currentIndex = 0; // 현재 선택된 탭 인덱스

  bool _isBroker = false;
  Map<String, dynamic>? _brokerData;

  // 알림 배지용 읽지 않은 알림 개수
  int _unreadNotificationCount = 0;
  StreamSubscription<int>? _notificationSubscription;

  // 로드된 페이지 캐시 (상태 유지)
  final Map<int, Widget> _pageCache = {};

  @override
  void initState() {
    super.initState();
    // 컨텍스트 기반 초기 탭 설정
    _currentIndex = _getContextBasedInitialTab();

    // 첫 프레임 렌더링 후 데이터 로드 (UI 먼저 표시)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 사용자 정보는 백그라운드에서 로드 (UI 블로킹 없음)
      _loadUserData();
      _checkBrokerRole();
      // 알림 배지 업데이트를 위한 스트림 구독
      _subscribeToNotifications();
      // 다른 탭 페이지 미리 초기화 (현재 탭은 이미 로드됨)
      _preloadOtherPages();
    });
  }

  /// 다른 탭 페이지를 지연 초기화하여 탭 전환 시 즉시 표시
  /// 현재 탭은 _getPage에서 즉시 로드됨
  void _preloadOtherPages() {
    if (!mounted) return;

    // 현재 선택되지 않은 탭만 백그라운드에서 사전 로드
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;

      // 등록 페이지 (현재 탭이 아닌 경우만)
      if (_currentIndex != 0 && !_pageCache.containsKey(0)) {
        _pageCache[0] = MLSQuickRegistrationPage(
          key: const ValueKey('mls_quick_registration'),
          onRegistrationComplete: () {
            setCurrentTab(1);
          },
        );
      }

      // 내 매물 페이지 (현재 탭이 아닌 경우만)
      if (_currentIndex != 1 && !_pageCache.containsKey(1)) {
        _pageCache[1] = const MLSSellerDashboardPage(
          key: ValueKey('mls_seller_dashboard'),
        );
      }

      // 시세 조회 페이지 (현재 탭이 아닌 경우만)
      if (_currentIndex != 2 && !_pageCache.containsKey(2)) {
        _pageCache[2] = const MarketPricePage(
          key: ValueKey('market_price'),
        );
      }

      // 매물 탐색 페이지 (현재 탭이 아닌 경우만)
      if (_currentIndex != 3 && !_pageCache.containsKey(3)) {
        _pageCache[3] = const PublicListingsPage(
          key: ValueKey('public_listings'),
        );
      }
    });
  }

  /// 알림 개수 스트림 구독
  void _subscribeToNotifications() {
    if (widget.userId.isEmpty) return;
    _notificationSubscription = _firebaseService
        .getUnreadNotificationCount(widget.userId)
        .listen((count) {
      if (mounted) {
        setState(() {
          _unreadNotificationCount = count;
        });
      }
    });
  }

  /// 컨텍스트 기반 초기 탭 결정
  /// 항상 "등록" 탭(0)으로 시작 - 헤이딜러 스타일
  int _getContextBasedInitialTab() {
    // 명시적 initialTabIndex가 있으면 우선 사용 (0, 1, 2, 3)
    if (widget.initialTabIndex >= 0 && widget.initialTabIndex < 4) {
      return widget.initialTabIndex;
    }
    // 기본: 등록 탭 (Tab 0) - 메인 CTA
    return 0;
  }

  /// 외부에서 탭 전환을 위한 메서드
  void setCurrentTab(int index) {
    if (index >= 0 && index < 4) {
      setState(() {
        _currentIndex = index;
      });
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
    } catch (e) {
      // 브로커 확인 중 오류 발생 시 로깅
      Logger.warning(
        '브로커 정보 확인 중 오류 발생',
        metadata: {'error': e.toString()},
      );
    }
  }

  /// 지연 로딩: 탭을 선택할 때만 페이지 생성
  /// 메모리 사용량을 크게 줄이고 초기 로딩 시간 단축
  Widget _getPage(int index) {
    // 캐시에 있으면 재사용
    if (_pageCache.containsKey(index)) {
      return _pageCache[index]!;
    }

    // 페이지 생성 및 캐싱 (3탭 구조: 등록 / 내 매물 / 시세)
    Widget page;
    switch (index) {
      case 0:
        // 빠른 등록 - 메인 CTA
        page = MLSQuickRegistrationPage(
          key: const ValueKey('mls_quick_registration'),
          onRegistrationComplete: () {
            // 등록 완료 후 "내 매물" 탭으로 이동
            setCurrentTab(1);
          },
        );
        break;
      case 1:
        // 내 매물 (등록한 매물 관리)
        page = const MLSSellerDashboardPage(
          key: ValueKey('mls_seller_dashboard'),
        );
        break;
      case 2:
        // 시세 조회
        page = const MarketPricePage(
          key: ValueKey('market_price'),
        );
        break;
      case 3:
        // 매물 탐색 (구매 희망자용)
        page = const PublicListingsPage(
          key: ValueKey('public_listings'),
        );
        break;
      default:
        page = MLSQuickRegistrationPage(
          key: const ValueKey('mls_quick_registration'),
          onRegistrationComplete: () {
            setCurrentTab(1);
          },
        );
    }

    _pageCache[index] = page;
    return page;
  }

  /// 사용자 정보를 백그라운드에서 비동기로 로드
  /// UI를 블로킹하지 않고 즉시 표시
  Future<void> _loadUserData() async {
    // userId가 없으면 로드할 필요 없음
    if (widget.userId.isEmpty) {
      return;
    }

    try {
      // 백그라운드에서 사용자 정보 로드 (에러는 무시)
      await _firebaseService.getUser(widget.userId);
    } catch (e) {
      // 사용자 정보 로드 실패는 무시하고 계속 진행
      // UI는 이미 표시되었으므로 문제없음
      Logger.warning(
        '사용자 정보 로드 실패',
        metadata: {'error': e.toString()},
      );
    }

    // 명시적 initialTabIndex가 지정된 경우 동적 전환 생략
    if (widget.initialTabIndex >= 0) return;

    // 매물 유무에 따른 기본 탭 동적 결정
    await _updateInitialTabByPropertyExistence();
  }

  /// 사용자 매물이 1개 이상이면 내 매물 탭(1)으로 전환
  Future<void> _updateInitialTabByPropertyExistence() async {
    try {
      final properties = await _mlsPropertyService
          .getPropertiesByUser(widget.userId)
          .first;
      final hasProperties = properties.isNotEmpty;

      if (!mounted) return;
      if (hasProperties) {
        setState(() => _currentIndex = 1);
      }
    } catch (e) {
      // 매물 조회 실패 시 기본 탭(등록) 유지
      Logger.warning(
        '매물 존재 여부 확인 실패',
        metadata: {'error': e.toString()},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = ResponsiveHelper.getMaxWidth(context);

    return Scaffold(
      backgroundColor: AppleColors.systemBackground,
      body: SafeArea(
        child: OfflineBanner(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                children: [
                  _buildHeader(),
                  _buildSegmentedControl(),
                  Expanded(child: _getPage(_currentIndex)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 상단 헤더 (로고 + 액션 버튼) - 공인중개사 대시보드와 통일
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppleColors.systemBackground,
      child: Row(
        children: [
          // 로고
          const LogoImage(height: 36),
          const Spacer(),
          // 1. 알림 (로그인 시에만)
          if (widget.userId.isNotEmpty)
            _buildHeaderActionButton(
              icon: Icons.notifications_outlined,
              tooltip: '알림',
              badgeCount: _unreadNotificationCount,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NotificationPage(userId: widget.userId),
                  ),
                );
              },
            ),
          if (widget.userId.isNotEmpty) const SizedBox(width: 4),
          // 2. 전체 메뉴 (설정/마이페이지)
          if (widget.userId.isNotEmpty)
            _buildHeaderActionButton(
              icon: Icons.menu,
              tooltip: '전체',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PersonalInfoPage(
                      userId: widget.userId,
                      userName: widget.userName,
                    ),
                  ),
                );
              },
            ),
          if (widget.userId.isNotEmpty) const SizedBox(width: 4),
          // 3. 중개사 모드로 전환 (중개사만, Primary 스타일)
          if (_isBroker)
            _buildHeaderActionButton(
              icon: Icons.swap_horiz_rounded,
              tooltip: '중개사 모드로 전환',
              isPrimary: true,
              onPressed: () {
                final brokerId = _brokerData?['brokerId'] as String? ?? widget.userId;
                final brokerName = _brokerData?['ownerName'] as String? ??
                    _brokerData?['businessName'] as String? ?? widget.userName;
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => MLSBrokerDashboardPage(
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
            ),
          if (_isBroker) const SizedBox(width: 4),
          // 4. 로그인/로그아웃
          _buildHeaderActionButton(
            icon: widget.userName.isNotEmpty ? Icons.logout_rounded : Icons.login_rounded,
            tooltip: widget.userName.isNotEmpty ? '로그아웃' : '로그인',
            onPressed: () {
              if (widget.userName.isNotEmpty) {
                _logout();
              } else {
                _login();
              }
            },
          ),
        ],
      ),
    );
  }

  /// 통일된 헤더 액션 버튼 (공인중개사 대시보드와 동일한 스타일)
  Widget _buildHeaderActionButton({
    required IconData icon,
    required VoidCallback onPressed, String? tooltip,
    bool isPrimary = false,
    int badgeCount = 0,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 32,
                width: 32,
                decoration: BoxDecoration(
                  color: isPrimary ? AppleColors.systemBlue.withValues(alpha: 0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isPrimary ? AppleColors.systemBlue.withValues(alpha: 0.3) : AppleColors.separator,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: isPrimary ? AppleColors.systemBlue : AppleColors.secondaryLabel,
                ),
              ),
              // 알림 배지
              if (badgeCount > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppleColors.systemRed,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      badgeCount > 9 ? '9+' : '$badgeCount',
                      style: AppleTypography.caption2.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// iOS 스타일 세그먼트 컨트롤
  Widget _buildSegmentedControl() {
    final isLoggedIn = widget.userName.isNotEmpty;

    return Container(
      color: AppleColors.systemBackground,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: AppleColors.secondarySystemFill,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            _buildSegment(0, '등록', isLoggedIn: isLoggedIn),
            _buildSegment(1, '내 매물', isLoggedIn: isLoggedIn),
            _buildSegment(2, '시세', isLoggedIn: isLoggedIn),
            _buildSegment(3, '탐색', isLoggedIn: isLoggedIn, requireLogin: false),
          ],
        ),
      ),
    );
  }

  Widget _buildSegment(int index, String label, {required bool isLoggedIn, bool requireLogin = true}) {
    final isSelected = _currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (requireLogin && !isLoggedIn) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('로그인이 필요합니다.', style: AppleTypography.body.copyWith(color: Colors.white)),
                backgroundColor: AppleColors.systemOrange,
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
            _login(targetIndex: index);
            return;
          }
          setState(() => _currentIndex = index);
          final screenNames = ['MLSQuickRegistrationPage', 'MLSSellerDashboardPage', 'MarketPricePage', 'PublicListingsPage'];
          _logService.logScreenView(screenNames[index], screenClass: 'MainPageTab');
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isSelected ? AppleColors.systemBackground : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 1,
                      offset: const Offset(0, 1),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: AppleTypography.subheadline.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppleColors.label : AppleColors.secondaryLabel,
              ),
            ),
          ),
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

      // 공인중개사 로그인인 경우 MLSBrokerDashboardPage로 이동
      if (result['userType'] == 'broker' && result['brokerData'] != null) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => MLSBrokerDashboardPage(
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
              // 로그인 후 등록 탭으로 (Tab 0) - 헤이딜러 스타일
              initialTabIndex: targetIndex ?? 0,
            ),
          ),
        );
      }
    } else {
      // 로그인 실패 (result가 있지만 유효한 데이터가 없는 경우)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('로그인에 실패했습니다. 이메일과 비밀번호를 확인해주세요.', style: AppleTypography.body.copyWith(color: Colors.white)),
            backgroundColor: AppleColors.systemRed,
          ),
        );
      }
    }
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              // Firebase 로그아웃
              await FirebaseService().signOut();
              // 로그인 랜딩 페이지로 이동
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const AuthLandingPage(),
                  ),
                  (route) => false,
                );
              }
            },
            child: const Text(
              '로그아웃',
              style: TextStyle(color: AppleColors.systemRed),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // 알림 스트림 구독 취소
    _notificationSubscription?.cancel();
    // 페이지 캐시 정리
    _pageCache.clear();
    super.dispose();
  }
}
