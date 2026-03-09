import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/mls_property.dart';
import '../../models/broker_offer.dart';
import '../../api_request/mls_property_service.dart';
import '../../models/buyer_inquiry.dart';
import '../../api_request/firebase_service.dart';
import '../../constants/apple_design_system.dart';
import '../../constants/responsive_constants.dart';
import '../../utils/logger.dart';
import '../../utils/commission_calculator.dart';
import '../../widgets/home_logo_button.dart';
import '../../widgets/offline_banner.dart';
import '../main_page.dart';
import '../auth/auth_landing_page.dart';
import '../notification/notification_page.dart';
import '../seller/mls_property_detail_page.dart';
import '../userInfo/personal_info_page.dart';

/// MLS 중개사 대시보드 - Apple HIG 스타일
class MLSBrokerDashboardPage extends StatefulWidget {
  final String brokerId;
  final String brokerName;
  final Map<String, dynamic>? brokerData;

  const MLSBrokerDashboardPage({
    required this.brokerId,
    required this.brokerName,
    this.brokerData,
    super.key,
  });

  @override
  State<MLSBrokerDashboardPage> createState() => _MLSBrokerDashboardPageState();
}

class _MLSBrokerDashboardPageState extends State<MLSBrokerDashboardPage>
    with SingleTickerProviderStateMixin {
  final MLSPropertyService _mlsService = MLSPropertyService();
  late TabController _tabController;

  // 매물 데이터
  List<MLSProperty> _allProperties = [];
  List<MLSProperty> _myCompetingProperties = [];
  List<MLSProperty> _wonProperties = [];
  List<MLSProperty> _completedProperties = [];

  // 필터
  String? _selectedRegion;
  int _selectedStatusIndex = 0; // 0: 전체, 1: 신규, 2: 진행중
  List<String> _availableRegions = [];

  // 추가 필터
  RangeValues _priceRange = const RangeValues(0, 500000); // 만원 단위 (0 ~ 50억)
  String? _selectedPropertyType; // 매물 유형 필터
  bool _isPriceFilterActive = false;

  static const List<String> propertyTypes = [
    '아파트',
    '빌라/다세대',
    '오피스텔',
    '단독/다가구',
    '상가',
    '토지',
    '기타',
  ];

  // 지역 영문 → 한글 매핑
  static const Map<String, String> regionNameMap = {
    'SEOUL': '서울',
    'GYEONGGI': '경기',
    'INCHEON': '인천',
    'BUSAN': '부산',
    'DAEGU': '대구',
    'DAEJEON': '대전',
    'GWANGJU': '광주',
    'ULSAN': '울산',
    'SEJONG': '세종',
    'GANGWON': '강원',
    'CHUNGBUK': '충북',
    'CHUNGNAM': '충남',
    'JEONBUK': '전북',
    'JEONNAM': '전남',
    'GYEONGBUK': '경북',
    'GYEONGNAM': '경남',
    'JEJU': '제주',
  };

  String _getRegionDisplayName(String region) {
    return regionNameMap[region.toUpperCase()] ?? region;
  }

  static const List<Map<String, dynamic>> pricePresets = [
    {'label': '전체', 'min': 0.0, 'max': 500000.0},
    {'label': '1억 이하', 'min': 0.0, 'max': 10000.0},
    {'label': '1~3억', 'min': 10000.0, 'max': 30000.0},
    {'label': '3~5억', 'min': 30000.0, 'max': 50000.0},
    {'label': '5~10억', 'min': 50000.0, 'max': 100000.0},
    {'label': '10억 이상', 'min': 100000.0, 'max': 500000.0},
  ];

  // 스트림 구독
  StreamSubscription? _allPropertiesSubscription;
  StreamSubscription? _myPropertiesSubscription;
  StreamSubscription? _completedSubscription;

  // 각 탭별 로딩 상태 (병렬 로딩 지원)
  bool _isLoadingMain = true;
  bool _isLoadingMy = true;
  bool _isLoadingCompleted = true;
  String? _errorMessage;

  // 데이터 캐시용 (이전 값과 비교하여 불필요한 setState 방지)
  List<MLSProperty>? _cachedRawProperties;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_onTabChanged);
    // 첫 프레임 렌더링 후 데이터 로드 (UI 먼저 표시)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 빠른 초기 로딩: Future로 먼저 데이터 가져온 후 스트림 구독
      _loadInitialDataFast();
    });
    // 지역 목록은 비동기로 로드 (캐시된 값 먼저 사용)
    _loadRegions();
  }

  /// 빠른 초기 데이터 로딩 (Future 사용)
  Future<void> _loadInitialDataFast() async {
    // 세 개의 데이터를 병렬로 빠르게 로드
    final futures = await Future.wait([
      _mlsService.getAllBrowsablePropertiesFast(region: _selectedRegion),
      _mlsService.getPropertiesBroadcastedToBrokerFast(widget.brokerId),
      _mlsService.getCompletedPropertiesByBrokerFast(widget.brokerId),
    ]);

    if (!mounted) return;

    // 1. 메인 매물 탭
    final mainProperties = futures[0];
    final filteredMain = _filterByStatus(mainProperties);

    // 2. 내 참여 매물 탭
    final broadcastedProperties = futures[1];
    final competing = broadcastedProperties.where((p) {
      final response = p.brokerResponses[widget.brokerId];
      return response != null &&
          response.hasViewed &&
          p.status != PropertyStatus.sold &&
          p.status != PropertyStatus.depositTaken;
    }).toList();
    competing.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    // 3. 성과 탭
    final completedProperties = futures[2];
    final won = completedProperties.where((p) => p.status == PropertyStatus.depositTaken).toList();
    final completed = completedProperties.where((p) => p.status == PropertyStatus.sold).toList();

    // 한 번에 setState (렌더링 최소화)
    setState(() {
      _cachedRawProperties = mainProperties;
      _allProperties = filteredMain;
      _isLoadingMain = false;

      _myCompetingProperties = competing;
      _isLoadingMy = false;

      _wonProperties = won;
      _completedProperties = completed;
      _isLoadingCompleted = false;
    });

    // 초기 데이터 로드 후 스트림 구독 (실시간 업데이트용)
    _subscribeToMainProperties();
    _subscribeToMyProperties();
    _subscribeToCompletedProperties();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      // 탭 전환 시 해당 탭 데이터 로드
      _loadTabData(_tabController.index);
      setState(() {});
    }
  }

  void _loadTabData(int tabIndex) {
    // 이미 initState에서 모든 탭 데이터를 병렬 로드하므로
    // 여기서는 필요시 새로고침만 처리
    switch (tabIndex) {
      case 0: // 매물
        if (_allPropertiesSubscription == null) {
          _subscribeToMainProperties();
        }
        break;
      case 1: // 내 참여
        if (_myPropertiesSubscription == null) {
          _subscribeToMyProperties();
        }
        break;
      case 2: // 내 제안 (StreamBuilder 사용, 별도 구독 불필요)
        break;
      case 3: // 성과
        if (_completedSubscription == null) {
          _subscribeToCompletedProperties();
        }
        break;
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _allPropertiesSubscription?.cancel();
    _myPropertiesSubscription?.cancel();
    _completedSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadRegions() async {
    final regions = await _mlsService.getAvailableRegions();
    if (mounted && regions != _availableRegions) {
      setState(() => _availableRegions = regions);
    }
  }

  /// 메인 매물 탭 구독 (첫 번째 탭)
  void _subscribeToMainProperties({bool forceReload = false}) {
    if (forceReload) {
      _mlsService.clearBrowsableCache();
    }

    if (_allProperties.isEmpty && _isLoadingMain) {
      setState(() {
        _errorMessage = null;
      });
    }

    _allPropertiesSubscription?.cancel();
    _allPropertiesSubscription = _mlsService
        .getAllBrowsableProperties(region: _selectedRegion, limit: 30)
        .listen(
      (properties) {
        if (mounted) {
          final filtered = _filterByStatus(properties);
          if (_shouldUpdateList(_allProperties, filtered) || _isLoadingMain) {
            setState(() {
              _cachedRawProperties = properties;
              _allProperties = filtered;
              _isLoadingMain = false;
            });
          }
        }
      },
      onError: (e) {
        Logger.error('전체 매물 로드 실패', error: e);
        if (mounted && _isLoadingMain) {
          setState(() {
            _errorMessage = '매물을 불러오는데 실패했습니다.';
            _isLoadingMain = false;
          });
        }
      },
    );
  }

  /// 내 참여 매물 구독 (두 번째 탭)
  void _subscribeToMyProperties() {
    _myPropertiesSubscription?.cancel();
    _myPropertiesSubscription = _mlsService
        .getPropertiesBroadcastedToBrokerStream(widget.brokerId)
        .listen(
      (properties) {
        if (mounted) {
          final competing = properties.where((p) {
            final response = p.brokerResponses[widget.brokerId];
            return response != null &&
                response.hasViewed &&
                p.status != PropertyStatus.sold &&
                p.status != PropertyStatus.depositTaken;
          }).toList();
          competing.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          if (_shouldUpdateList(_myCompetingProperties, competing) || _isLoadingMy) {
            setState(() {
              _myCompetingProperties = competing;
              _isLoadingMy = false;
            });
          }
        }
      },
      onError: (e) {
        Logger.error('내 참여 매물 로드 실패', error: e);
        if (mounted && _isLoadingMy) {
          setState(() => _isLoadingMy = false);
        }
      },
    );
  }

  /// 성과 매물 구독 (세 번째 탭)
  void _subscribeToCompletedProperties() {
    _completedSubscription?.cancel();
    _completedSubscription = _mlsService
        .getCompletedPropertiesByBroker(widget.brokerId)
        .listen(
      (properties) {
        if (mounted) {
          final won = properties.where((p) => p.status == PropertyStatus.depositTaken).toList();
          final completed = properties.where((p) => p.status == PropertyStatus.sold).toList();
          if (_shouldUpdateList(_wonProperties, won) ||
              _shouldUpdateList(_completedProperties, completed) ||
              _isLoadingCompleted) {
            setState(() {
              _wonProperties = won;
              _completedProperties = completed;
              _isLoadingCompleted = false;
            });
          }
        }
      },
      onError: (e) {
        Logger.error('성과 매물 로드 실패', error: e);
        if (mounted && _isLoadingCompleted) {
          setState(() => _isLoadingCompleted = false);
        }
      },
    );
  }

  /// 지역 변경 시 호출 (기존 메서드 호환성 유지)
  void _subscribeToProperties({bool forceReload = false}) {
    _subscribeToMainProperties(forceReload: forceReload);
  }

  /// 리스트가 실제로 변경되었는지 확인
  bool _shouldUpdateList(List<MLSProperty> oldList, List<MLSProperty> newList) {
    if (oldList.length != newList.length) return true;
    for (int i = 0; i < oldList.length; i++) {
      if (oldList[i].id != newList[i].id ||
          oldList[i].updatedAt != newList[i].updatedAt) {
        return true;
      }
    }
    return false;
  }

  List<MLSProperty> _filterByStatus(List<MLSProperty> properties) {
    var filtered = properties;

    // 1. 상태 필터
    if (_selectedStatusIndex == 1) {
      filtered = filtered.where((p) => p.status == PropertyStatus.active).toList();
    } else if (_selectedStatusIndex == 2) {
      filtered = filtered.where((p) =>
          p.status == PropertyStatus.inquiry ||
          p.status == PropertyStatus.underOffer).toList();
    }

    // 2. 가격 필터
    if (_isPriceFilterActive) {
      final minPrice = _priceRange.start;
      final maxPrice = _priceRange.end;
      filtered = filtered.where((p) {
        final price = p.desiredPrice / 10000; // 만원 단위로 변환
        return price >= minPrice && price <= maxPrice;
      }).toList();
    }

    // 3. 매물 유형 필터
    if (_selectedPropertyType != null) {
      filtered = filtered.where((p) {
        // propertyType 필드가 있으면 사용, 없으면 기본값 '기타'
        final type = p.propertyType ?? '기타';
        return type == _selectedPropertyType;
      }).toList();
    }

    return filtered;
  }

  void _onRegionChanged(String? region) {
    if (_selectedRegion == region) return; // 동일한 지역이면 무시
    setState(() => _selectedRegion = region);
    _subscribeToProperties(forceReload: true);
  }

  void _onStatusChanged(int index) {
    if (_selectedStatusIndex == index) return; // 동일하면 무시
    setState(() {
      _selectedStatusIndex = index;
      // 재구독 없이 캐싱된 데이터에서 필터링만 수행
      if (_cachedRawProperties != null) {
        _allProperties = _filterByStatus(_cachedRawProperties!);
      }
    });
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
                  Expanded(child: _buildBody()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 상단 헤더 (로고 + 액션 버튼) - MainPage와 통일된 스타일
  /// 순서: [알림] [설정] [모드전환(primary)] [로그아웃]
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppleColors.systemBackground,
      child: Row(
        children: [
          // 로고
          const LogoImage(height: 36),
          const Spacer(),
          // 1. 알림
          _buildHeaderActionButton(
            icon: Icons.notifications_outlined,
            tooltip: '알림',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NotificationPage(userId: widget.brokerId),
                ),
              );
            },
          ),
          const SizedBox(width: 4),
          // 2. 전체 메뉴 (설정/마이페이지)
          _buildHeaderActionButton(
            icon: Icons.menu,
            tooltip: '전체',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PersonalInfoPage(
                    userId: widget.brokerId,
                    userName: widget.brokerName,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 4),
          // 3. 일반 모드로 전환 (Primary 스타일)
          _buildHeaderActionButton(
            icon: Icons.swap_horiz_rounded,
            tooltip: '일반 모드로 전환',
            isPrimary: true,
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => MainPage(
                    userId: widget.brokerId,
                    userName: widget.brokerName,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 4),
          // 4. 로그아웃
          _buildHeaderActionButton(
            icon: Icons.logout_rounded,
            tooltip: '로그아웃',
            onPressed: _logout,
          ),
        ],
      ),
    );
  }

  /// 로그아웃
  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              navigator.pop();
              await FirebaseService().signOut();
              if (mounted) {
                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthLandingPage()),
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

  /// 통일된 헤더 액션 버튼 (MainPage와 동일한 스타일)
  Widget _buildHeaderActionButton({
    required IconData icon,
    required VoidCallback onPressed, String? tooltip,
    bool isPrimary = false,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
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
        ),
      ),
    );
  }

  /// iOS 스타일 세그먼트 컨트롤
  Widget _buildSegmentedControl() {
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
            _buildSegment(0, '매물'),
            _buildSegment(1, '내 참여', badge: _myCompetingProperties.length),
            _buildSegment(2, '내 제안'),
            _buildSegment(3, '성과'),
            _buildSegment(4, '구매 리드'),
          ],
        ),
      ),
    );
  }

  Widget _buildSegment(int index, String label, {int badge = 0}) {
    final isSelected = _tabController.index == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          _tabController.animateTo(index);
          setState(() {});
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppleTypography.subheadline.copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? AppleColors.label : AppleColors.secondaryLabel,
                  ),
                ),
                if (badge > 0) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppleColors.systemRed,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$badge',
                      style: AppleTypography.caption2.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    // 현재 탭에 따른 로딩 상태 확인
    final currentTabLoading = switch (_tabController.index) {
      0 => _isLoadingMain,
      1 => _isLoadingMy,
      2 => false, // 내 제안 탭은 StreamBuilder 사용
      3 => _isLoadingCompleted,
      _ => false,
    };

    if (currentTabLoading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (_errorMessage != null && _tabController.index == 0) {
      return _buildErrorState();
    }

    return TabBarView(
      controller: _tabController,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _isLoadingMain ? const Center(child: CircularProgressIndicator.adaptive()) : _buildBrowseTab(),
        _isLoadingMy ? const Center(child: CircularProgressIndicator.adaptive()) : _buildMyCompetingTab(),
        _buildMyOffersTab(),
        _isLoadingCompleted ? const Center(child: CircularProgressIndicator.adaptive()) : _buildResultsTab(),
        _buildBuyerLeadsTab(),
      ],
    );
  }

  /// Tab 4: 구매자 리드 — 배정된 구매 문의 목록
  Widget _buildBuyerLeadsTab() {
    return StreamBuilder<List<BuyerInquiry>>(
      stream: MLSPropertyService().getMyBuyerLeads(widget.brokerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        final inquiries = snapshot.data ?? [];

        if (inquiries.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.people_outline, size: 56, color: AppleColors.tertiaryLabel),
                const SizedBox(height: 16),
                Text('아직 배정된 구매 리드가 없습니다',
                    style: AppleTypography.body.copyWith(color: AppleColors.secondaryLabel)),
                const SizedBox(height: 8),
                Text('방문 승인된 매물에 구매자가 문의하면 여기에 표시됩니다',
                    style: AppleTypography.footnote.copyWith(color: AppleColors.tertiaryLabel),
                    textAlign: TextAlign.center),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: inquiries.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final inquiry = inquiries[index];
            return _buildBuyerLeadCard(inquiry);
          },
        );
      },
    );
  }

  Widget _buildBuyerLeadCard(BuyerInquiry inquiry) {
    final statusColor = switch (inquiry.status) {
      BuyerInquiryStatus.pending => AppleColors.systemOrange,
      BuyerInquiryStatus.brokerAssigned => AppleColors.systemBlue,
      BuyerInquiryStatus.contacted => AppleColors.systemGreen,
      BuyerInquiryStatus.visiting => AppleColors.systemTeal,
      BuyerInquiryStatus.completed => AppleColors.secondaryLabel,
      BuyerInquiryStatus.cancelled => AppleColors.systemRed,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppleColors.systemBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppleColors.separator),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline, size: 16, color: AppleColors.secondaryLabel),
              const SizedBox(width: 6),
              Expanded(
                child: Text(inquiry.buyerName,
                    style: AppleTypography.body.copyWith(fontWeight: FontWeight.w600)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(inquiry.status.label,
                    style: AppleTypography.caption1.copyWith(
                        color: statusColor, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          if (inquiry.buyerPhone != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.phone_outlined, size: 14, color: AppleColors.tertiaryLabel),
                const SizedBox(width: 6),
                Text(inquiry.buyerPhone!,
                    style: AppleTypography.subheadline.copyWith(color: AppleColors.label)),
              ],
            ),
          ],
          if (inquiry.buyerMessage != null && inquiry.buyerMessage!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(inquiry.buyerMessage!,
                style: AppleTypography.footnote.copyWith(color: AppleColors.secondaryLabel),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 8),
          Text(
            '문의일: ${inquiry.createdAt.month}/${inquiry.createdAt.day}',
            style: AppleTypography.caption2.copyWith(color: AppleColors.tertiaryLabel),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppleColors.systemRed),
          const SizedBox(height: 16),
          Text(_errorMessage!, style: AppleTypography.body.copyWith(color: AppleColors.secondaryLabel)),
          const SizedBox(height: 24),
          TextButton(
            onPressed: _subscribeToProperties,
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  /// Tab 0: 매물 찾기
  Widget _buildBrowseTab() {
    return Column(
      children: [
        _buildFilterBar(),
        Expanded(
          child: _allProperties.isEmpty
              ? _buildEmptyState('등록된 매물이 없습니다', '새로운 매물이 등록되면 여기에 표시됩니다')
              : RefreshIndicator(
                  onRefresh: () async => _subscribeToProperties(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    itemCount: _allProperties.length,
                    itemBuilder: (context, index) => _buildPropertyCard(_allProperties[index]),
                  ),
                ),
        ),
      ],
    );
  }

  /// 필터 바 - 깔끔한 스타일
  Widget _buildFilterBar() {
    final activeFilterCount = _countActiveFilters();

    return Container(
      color: AppleColors.systemBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 구분선
          Container(height: 0.5, color: AppleColors.separator),

          // 1차 필터: 지역 + 상태
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Row(
              children: [
                // 지역 선택 버튼
                _buildDropdownButton(
                  label: _selectedRegion != null ? _getRegionDisplayName(_selectedRegion!) : '전체 지역',
                  onTap: () => _showRegionPicker(),
                ),
                const SizedBox(width: 12),
                // 상태 필터
                Expanded(child: _buildStatusFilter()),
              ],
            ),
          ),

          // 2차 필터: 가격대 + 매물유형 + 필터 초기화
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // 가격대 필터
                  _buildFilterChip(
                    label: _isPriceFilterActive ? _formatPriceRangeLabel() : '가격대',
                    icon: Icons.attach_money,
                    isActive: _isPriceFilterActive,
                    onTap: _showPriceFilterSheet,
                  ),
                  const SizedBox(width: 8),
                  // 매물 유형 필터
                  _buildFilterChip(
                    label: _selectedPropertyType ?? '매물유형',
                    icon: Icons.home_outlined,
                    isActive: _selectedPropertyType != null,
                    onTap: _showPropertyTypeFilterSheet,
                  ),
                  // 필터 초기화 버튼
                  if (activeFilterCount > 0) ...[
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _resetFilters,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppleColors.systemRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.close, size: 14, color: AppleColors.systemRed),
                            const SizedBox(width: 4),
                            Text(
                              '초기화',
                              style: AppleTypography.caption1.copyWith(
                                color: AppleColors.systemRed,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _countActiveFilters() {
    int count = 0;
    if (_selectedRegion != null) count++;
    if (_selectedStatusIndex != 0) count++;
    if (_isPriceFilterActive) count++;
    if (_selectedPropertyType != null) count++;
    return count;
  }

  void _resetFilters() {
    final regionChanged = _selectedRegion != null;
    setState(() {
      _selectedRegion = null;
      _selectedStatusIndex = 0;
      _isPriceFilterActive = false;
      _priceRange = const RangeValues(0, 500000);
      _selectedPropertyType = null;
      // 지역이 변경되지 않았으면 캐싱된 데이터에서 필터링만 수행
      if (!regionChanged && _cachedRawProperties != null) {
        _allProperties = _filterByStatus(_cachedRawProperties!);
      }
    });
    // 지역이 변경되었을 때만 재구독
    if (regionChanged) {
      _subscribeToProperties(forceReload: true);
    }
  }

  String _formatPriceRangeLabel() {
    final min = _priceRange.start;
    final max = _priceRange.end;

    String formatValue(double value) {
      if (value >= 10000) {
        return '${(value / 10000).toStringAsFixed(0)}억';
      }
      return '${value.toStringAsFixed(0)}만';
    }

    if (min == 0 && max >= 500000) return '전체';
    if (min == 0) return '~${formatValue(max)}';
    if (max >= 500000) return '${formatValue(min)}~';
    return '${formatValue(min)}~${formatValue(max)}';
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppleColors.systemBlue : AppleColors.tertiarySystemFill,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? Colors.white : AppleColors.secondaryLabel,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppleTypography.caption1.copyWith(
                color: isActive ? Colors.white : AppleColors.label,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: isActive ? Colors.white : AppleColors.secondaryLabel,
            ),
          ],
        ),
      ),
    );
  }

  void _showPriceFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _PriceFilterSheet(
        currentRange: _priceRange,
        isActive: _isPriceFilterActive,
        presets: pricePresets,
        onApply: (range, isActive) {
          setState(() {
            _priceRange = range;
            _isPriceFilterActive = isActive;
            // 캐싱된 원본 데이터에서 필터링 (재구독 불필요)
            if (_cachedRawProperties != null) {
              _allProperties = _filterByStatus(_cachedRawProperties!);
            }
          });
        },
      ),
    );
  }

  void _showPropertyTypeFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppleColors.systemBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 핸들
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: AppleColors.opaqueSeparator,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
            // 타이틀
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '매물 유형',
                style: AppleTypography.headline.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Container(height: 0.5, color: AppleColors.separator),
            // 옵션 리스트
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  _buildPropertyTypeOption(null, '전체'),
                  ...propertyTypes.map((type) => _buildPropertyTypeOption(type, type)),
                ],
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyTypeOption(String? value, String label) {
    final isSelected = _selectedPropertyType == value;
    return ListTile(
      onTap: () {
        Navigator.pop(context);
        setState(() {
          _selectedPropertyType = value;
          // 캐싱된 원본 데이터에서 필터링 (재구독 불필요)
          if (_cachedRawProperties != null) {
            _allProperties = _filterByStatus(_cachedRawProperties!);
          }
        });
      },
      leading: Icon(
        _getPropertyTypeIcon(value),
        color: isSelected ? AppleColors.systemBlue : AppleColors.secondaryLabel,
      ),
      title: Text(
        label,
        style: AppleTypography.body.copyWith(
          color: isSelected ? AppleColors.systemBlue : AppleColors.label,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check, color: AppleColors.systemBlue, size: 20)
          : null,
    );
  }

  IconData _getPropertyTypeIcon(String? type) {
    switch (type) {
      case '아파트':
        return Icons.apartment;
      case '빌라/다세대':
        return Icons.home_work;
      case '오피스텔':
        return Icons.business;
      case '단독/다가구':
        return Icons.house;
      case '상가':
        return Icons.storefront;
      case '토지':
        return Icons.landscape;
      default:
        return Icons.home_outlined;
    }
  }

  Widget _buildDropdownButton({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppleColors.tertiarySystemFill,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppleTypography.subheadline.copyWith(
                color: AppleColors.label,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: AppleColors.secondaryLabel,
            ),
          ],
        ),
      ),
    );
  }

  void _showRegionPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppleColors.systemBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 핸들
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: AppleColors.opaqueSeparator,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
            // 타이틀
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '지역 선택',
                style: AppleTypography.headline.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Container(height: 0.5, color: AppleColors.separator),
            // 옵션 리스트
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  _buildRegionOption(null, '전체 지역'),
                  ..._availableRegions.map((r) => _buildRegionOption(r, _getRegionDisplayName(r))),
                ],
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  Widget _buildRegionOption(String? value, String label) {
    final isSelected = _selectedRegion == value;
    return ListTile(
      onTap: () {
        Navigator.pop(context);
        _onRegionChanged(value);
      },
      title: Text(
        label,
        style: AppleTypography.body.copyWith(
          color: isSelected ? AppleColors.systemBlue : AppleColors.label,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check, color: AppleColors.systemBlue, size: 20)
          : null,
    );
  }

  Widget _buildStatusFilter() {
    return Row(
      children: [
        _buildStatusPill(0, '전체'),
        const SizedBox(width: 8),
        _buildStatusPill(1, '신규'),
        const SizedBox(width: 8),
        _buildStatusPill(2, '진행중'),
      ],
    );
  }

  Widget _buildStatusPill(int index, String label) {
    final isSelected = _selectedStatusIndex == index;
    return GestureDetector(
      onTap: () => _onStatusChanged(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppleColors.systemBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: isSelected ? null : Border.all(color: AppleColors.separator),
        ),
        child: Text(
          label,
          style: AppleTypography.subheadline.copyWith(
            color: isSelected ? Colors.white : AppleColors.secondaryLabel,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  /// 매물 카드 - 깔끔한 스타일
  Widget _buildPropertyCard(MLSProperty property) {
    final isMyCompeting = property.brokerResponses.containsKey(widget.brokerId) &&
        property.brokerResponses[widget.brokerId]!.hasViewed;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppleColors.systemBackground,
        borderRadius: BorderRadius.circular(12),
        border: isMyCompeting
            ? Border.all(color: AppleColors.systemGreen, width: 1.5)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showPropertyDetail(property),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 상단: 상태 + 검증 + 지역
                Row(
                  children: [
                    _buildStatusBadge(property.status),
                    // 검증됨 뱃지
                    if (property.verificationStatus == VerificationStatus.adminApproved) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppleColors.systemTeal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified, size: 12, color: AppleColors.systemTeal),
                            const SizedBox(width: 2),
                            Text(
                              '검증됨',
                              style: AppleTypography.caption2.copyWith(
                                color: AppleColors.systemTeal,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (isMyCompeting) ...[
                      const SizedBox(width: 6),
                      _buildBadge('참여중', AppleColors.systemGreen),
                    ],
                    const Spacer(),
                    Text(
                      property.region,
                      style: AppleTypography.caption1.copyWith(color: AppleColors.tertiaryLabel),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 주소
                Text(
                  property.address,
                  style: AppleTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppleColors.label,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // 가격
                Text(
                  _formatPrice(property.desiredPrice),
                  style: AppleTypography.title3.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppleColors.systemBlue,
                  ),
                ),
                const SizedBox(height: 6),

                // 법정 수수료 정보
                Builder(
                  builder: (context) {
                    final price = property.desiredPrice.toInt();
                    final maxRate = CommissionCalculator.getLegalMaxRate(
                      transactionPrice: price,
                      transactionType: CommissionCalculator.transactionSale,
                    );
                    final maxCommission = CommissionCalculator.calculateCommission(
                      transactionPrice: price,
                      commissionRate: maxRate,
                    );
                    return Row(
                      children: [
                        const Icon(Icons.percent, size: 12, color: AppleColors.tertiaryLabel),
                        const SizedBox(width: 4),
                        Text(
                          '법정 최고 $maxRate% (${CommissionCalculator.formatCommission(maxCommission)})',
                          style: AppleTypography.caption2.copyWith(
                            color: AppleColors.tertiaryLabel,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),

                // 하단: 판매자 + 등록일 + 버튼 (1:1 관계 강조)
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 14, color: AppleColors.tertiaryLabel),
                    const SizedBox(width: 4),
                    Text(
                      property.userName.isNotEmpty ? property.userName : '매도인',
                      style: AppleTypography.caption1.copyWith(color: AppleColors.secondaryLabel),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.access_time, size: 14, color: AppleColors.tertiaryLabel),
                    const SizedBox(width: 4),
                    Text(
                      _formatTimeAgo(property.createdAt),
                      style: AppleTypography.caption1.copyWith(color: AppleColors.tertiaryLabel),
                    ),
                    const Spacer(),
                    if (!isMyCompeting)
                      _buildPrimaryButton('조건 제안', () => _showQuickProposalSheet(property))
                    else
                      _buildSecondaryButton('제안 수정', () => _showQuickProposalSheet(property)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(PropertyStatus status) {
    final (label, color) = switch (status) {
      PropertyStatus.active => ('신규', AppleColors.systemGreen),
      PropertyStatus.inquiry => ('문의중', AppleColors.systemBlue),
      PropertyStatus.underOffer => ('협상중', AppleColors.systemOrange),
      PropertyStatus.depositTaken => ('가계약', AppleColors.systemPurple),
      PropertyStatus.sold => ('완료', AppleColors.secondaryLabel),
      _ => ('', AppleColors.secondaryLabel),
    };
    if (label.isEmpty) return const SizedBox.shrink();
    return _buildBadge(label, color);
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: AppleTypography.caption2.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildPrimaryButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: AppleColors.systemBlue,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: AppleTypography.subheadline.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: AppleTypography.subheadline.copyWith(
          color: AppleColors.systemBlue,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// Tab 1: 내 참여
  Widget _buildMyCompetingTab() {
    if (_myCompetingProperties.isEmpty) {
      return _buildEmptyState('참여 중인 매물이 없습니다', '매물 탭에서 영업할 매물을 선택하세요');
    }

    return RefreshIndicator(
      onRefresh: () async => _subscribeToProperties(),
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _myCompetingProperties.length + 1, // +1 for header
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                '${_myCompetingProperties.length}건 진행 중',
                style: AppleTypography.headline.copyWith(fontWeight: FontWeight.w600),
              ),
            );
          }
          return _buildCompetingCard(_myCompetingProperties[index - 1]);
        },
      ),
    );
  }

  Widget _buildCompetingCard(MLSProperty property) {
    final myResponse = property.brokerResponses[widget.brokerId];
    final myStage = myResponse?.stage ?? BrokerStage.received;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppleColors.systemBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showPropertyDetail(property),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 상단: 매물 상태 + 내 단계
                Row(
                  children: [
                    _buildStatusBadge(property.status),
                    const Spacer(),
                    _buildStageBadge(myStage),
                  ],
                ),
                const SizedBox(height: 12),

                // 주소 + 가격
                Text(
                  property.address,
                  style: AppleTypography.body.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _formatPrice(property.desiredPrice),
                  style: AppleTypography.title3.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppleColors.systemBlue,
                  ),
                ),
                const SizedBox(height: 6),

                // 법정 수수료 정보
                Builder(
                  builder: (context) {
                    final price = property.desiredPrice.toInt();
                    final maxRate = CommissionCalculator.getLegalMaxRate(
                      transactionPrice: price,
                      transactionType: CommissionCalculator.transactionSale,
                    );
                    final maxCommission = CommissionCalculator.calculateCommission(
                      transactionPrice: price,
                      commissionRate: maxRate,
                    );
                    return Row(
                      children: [
                        const Icon(Icons.percent, size: 12, color: AppleColors.tertiaryLabel),
                        const SizedBox(width: 4),
                        Text(
                          '법정 최고 $maxRate% (${CommissionCalculator.formatCommission(maxCommission)})',
                          style: AppleTypography.caption2.copyWith(
                            color: AppleColors.tertiaryLabel,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),

                // 판매자 정보 + 등록일 (1:1 관계 강조)
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 14, color: AppleColors.tertiaryLabel),
                    const SizedBox(width: 4),
                    Text(
                      property.userName.isNotEmpty ? property.userName : '매도인',
                      style: AppleTypography.caption1.copyWith(color: AppleColors.secondaryLabel),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.schedule_outlined, size: 14, color: AppleColors.tertiaryLabel),
                    const SizedBox(width: 4),
                    Text(
                      _formatRelativeTime(property.createdAt),
                      style: AppleTypography.caption1.copyWith(color: AppleColors.tertiaryLabel),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 하단: 나의 진행 상태 + 다음 액션
                Row(
                  children: [
                    // 나의 현재 단계 설명
                    Expanded(
                      child: Text(
                        _getMyStatusDescription(myStage),
                        style: AppleTypography.caption1.copyWith(color: AppleColors.secondaryLabel),
                      ),
                    ),
                    _buildSecondaryButton(_getNextStageAction(myStage), () => _advanceStage(property)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStageBadge(BrokerStage stage) {
    final (label, color) = switch (stage) {
      BrokerStage.received => ('수신', AppleColors.secondaryLabel),
      BrokerStage.viewed => ('열람', AppleColors.systemBlue),
      BrokerStage.requested => ('요청', AppleColors.systemOrange),
      BrokerStage.approved => ('승인', AppleColors.systemGreen),
      BrokerStage.completed => ('완료', AppleColors.systemPurple),
    };
    return _buildBadge(label, color);
  }

  String _getNextStageAction(BrokerStage stage) {
    return switch (stage) {
      BrokerStage.received => '매물 보기',
      BrokerStage.viewed => '방문 요청',
      BrokerStage.requested => '승인 대기',
      BrokerStage.approved => '연락 중',
      BrokerStage.completed => '완료',
    };
  }

  /// 나의 현재 단계에 대한 설명 (1:1 관계 강조)
  String _getMyStatusDescription(BrokerStage stage) {
    return switch (stage) {
      BrokerStage.received => '새 매물이 도착했습니다',
      BrokerStage.viewed => '매물을 확인했습니다',
      BrokerStage.requested => '방문 요청 후 판매자 응답 대기 중',
      BrokerStage.approved => '판매자가 승인! 연락처가 교환되었습니다',
      BrokerStage.completed => '거래가 완료되었습니다',
    };
  }

  /// 상대적 시간 포맷 (예: "3일 전", "방금 전")
  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inDays > 30) {
      return '${dateTime.month}/${dateTime.day}';
    } else if (diff.inDays > 0) {
      return '${diff.inDays}일 전';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}시간 전';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}분 전';
    } else {
      return '방금 전';
    }
  }

  /// Tab 2: 내 제안 (brokerOffers에서 brokerId로 조회)
  Widget _buildMyOffersTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('brokerOffers')
          .where('brokerId', isEqualTo: widget.brokerId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _buildEmptyState(
            '제출한 제안이 없습니다',
            '공개 매물 페이지에서 중개 제안을 보내보세요',
          );
        }

        final offers = docs
            .map((d) => BrokerOffer.fromMap(d.data() as Map<String, dynamic>))
            .toList();

        final pendingCount = offers.where((o) => o.status == BrokerOfferStatus.pending).length;
        final selectedCount = offers.where((o) => o.status == BrokerOfferStatus.selected).length;

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: offers.length + 1, // +1 for summary header
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Text(
                      '총 ${offers.length}건',
                      style: AppleTypography.headline.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    if (pendingCount > 0)
                      _buildBadge('대기 $pendingCount', AppleColors.systemOrange),
                    if (pendingCount > 0 && selectedCount > 0)
                      const SizedBox(width: 6),
                    if (selectedCount > 0)
                      _buildBadge('선정 $selectedCount', AppleColors.systemGreen),
                  ],
                ),
              );
            }

            final offer = offers[index - 1];
            return _buildOfferCard(offer);
          },
        );
      },
    );
  }

  Widget _buildOfferCard(BrokerOffer offer) {
    final (statusLabel, statusColor) = switch (offer.status) {
      BrokerOfferStatus.pending => ('대기중', AppleColors.systemOrange),
      BrokerOfferStatus.selected => ('선정됨', AppleColors.systemGreen),
      BrokerOfferStatus.rejected => ('미선정', AppleColors.secondaryLabel),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppleColors.systemBackground,
        borderRadius: BorderRadius.circular(12),
        border: offer.status == BrokerOfferStatus.selected
            ? Border.all(color: AppleColors.systemGreen.withValues(alpha: 0.4))
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단: 매물 주소 + 상태 배지
            Row(
              children: [
                Expanded(
                  child: Text(
                    offer.propertyAddress.isNotEmpty
                        ? offer.propertyAddress
                        : '매물 ID: ${offer.propertyId}',
                    style: AppleTypography.body.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _buildBadge(statusLabel, statusColor),
              ],
            ),
            const SizedBox(height: 10),

            // 한마디 (pitch)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppleColors.secondarySystemFill,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                offer.pitch,
                style: AppleTypography.subheadline.copyWith(
                  color: offer.status == BrokerOfferStatus.rejected
                      ? AppleColors.tertiaryLabel
                      : AppleColors.label,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),

            // 하단: 제출 시각 + 선정 시각
            Row(
              children: [
                const Icon(Icons.schedule_outlined, size: 14, color: AppleColors.tertiaryLabel),
                const SizedBox(width: 4),
                Text(
                  _formatTimeAgo(offer.createdAt),
                  style: AppleTypography.caption1.copyWith(color: AppleColors.tertiaryLabel),
                ),
                if (offer.status == BrokerOfferStatus.selected && offer.selectedAt != null) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.check_circle_outline, size: 14, color: AppleColors.systemGreen),
                  const SizedBox(width: 4),
                  Text(
                    '${offer.selectedAt!.month}/${offer.selectedAt!.day} 선정',
                    style: AppleTypography.caption1.copyWith(
                      color: AppleColors.systemGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Tab 3: 성과
  Widget _buildResultsTab() {
    return RefreshIndicator(
      onRefresh: () async => _subscribeToProperties(),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 공인중개사 프로필 카드
          _buildBrokerProfileCard(),
          const SizedBox(height: 20),

          // 가계약
          if (_wonProperties.isNotEmpty) ...[
            _buildSectionTitle('가계약 성사 ${_wonProperties.length}건'),
            const SizedBox(height: 12),
            ..._wonProperties.map((p) => _buildResultCard(p, isWon: true)),
          ],

          // 완료
          if (_completedProperties.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildSectionTitle('거래 완료 ${_completedProperties.length}건'),
            const SizedBox(height: 12),
            ..._completedProperties.map((p) => _buildResultCard(p, isWon: false)),
          ],
        ],
      ),
    );
  }

  /// 공인중개사 프로필 카드
  Widget _buildBrokerProfileCard() {
    final brokerData = widget.brokerData;
    final registrationNumber = brokerData?['brokerRegistrationNumber'] as String? ?? '';
    final businessName = brokerData?['businessName'] as String? ?? widget.brokerName;
    final ownerName = brokerData?['ownerName'] as String? ?? widget.brokerName;
    final phoneNumber = brokerData?['phoneNumber'] as String? ?? '';
    final address = brokerData?['address'] as String? ?? '';
    final isVerified = brokerData?['verified'] as bool? ?? false;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppleColors.systemBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isVerified ? AppleColors.systemGreen.withValues(alpha: 0.3) : AppleColors.separator,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더: 프로필 아이콘 + 상호명 + 검증 뱃지
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppleColors.systemBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(
                  Icons.store_rounded,
                  color: AppleColors.systemBlue,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            businessName,
                            style: AppleTypography.title3.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isVerified
                                ? AppleColors.systemGreen.withValues(alpha: 0.1)
                                : AppleColors.systemOrange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isVerified ? Icons.verified : Icons.pending_outlined,
                                size: 14,
                                color: isVerified ? AppleColors.systemGreen : AppleColors.systemOrange,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isVerified ? '인증' : '미인증',
                                style: AppleTypography.caption2.copyWith(
                                  color: isVerified ? AppleColors.systemGreen : AppleColors.systemOrange,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '대표 $ownerName',
                      style: AppleTypography.subheadline.copyWith(
                        color: AppleColors.secondaryLabel,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          Container(height: 0.5, color: AppleColors.separator),
          const SizedBox(height: 16),

          // 정보 리스트
          if (registrationNumber.isNotEmpty)
            _buildInfoRow(Icons.badge_outlined, '등록번호', registrationNumber),
          if (phoneNumber.isNotEmpty)
            _buildInfoRow(Icons.phone_outlined, '연락처', _formatPhoneNumber(phoneNumber)),
          if (address.isNotEmpty)
            _buildInfoRow(Icons.location_on_outlined, '소재지', address),
        ],
      ),
    );
  }

  /// 정보 행 위젯
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppleColors.secondaryLabel),
          const SizedBox(width: 12),
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: AppleTypography.subheadline.copyWith(
                color: AppleColors.secondaryLabel,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: AppleTypography.subheadline.copyWith(
                color: AppleColors.label,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 전화번호 포맷팅
  String _formatPhoneNumber(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 11) {
      return '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7)}';
    } else if (digits.length == 10) {
      if (digits.startsWith('02')) {
        return '${digits.substring(0, 2)}-${digits.substring(2, 6)}-${digits.substring(6)}';
      }
      return '${digits.substring(0, 3)}-${digits.substring(3, 6)}-${digits.substring(6)}';
    }
    return phone;
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppleTypography.headline.copyWith(fontWeight: FontWeight.w600),
    );
  }

  Widget _buildResultCard(MLSProperty property, {required bool isWon}) {
    final color = isWon ? AppleColors.systemGreen : AppleColors.systemPurple;
    final price = (property.finalPrice ?? property.desiredPrice).toInt();
    final maxRate = CommissionCalculator.getLegalMaxRate(
      transactionPrice: price,
      transactionType: CommissionCalculator.transactionSale,
    );
    final estimatedCommission = CommissionCalculator.calculateCommission(
      transactionPrice: price,
      commissionRate: maxRate,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppleColors.systemBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isWon ? Icons.emoji_events : Icons.check_circle,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  property.address,
                  style: AppleTypography.body.copyWith(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _formatPrice(property.finalPrice ?? property.desiredPrice),
                  style: AppleTypography.subheadline.copyWith(color: color, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '수수료 ${CommissionCalculator.formatCommission(estimatedCommission)} ($maxRate%)',
                  style: AppleTypography.caption2.copyWith(color: AppleColors.tertiaryLabel),
                ),
              ],
            ),
          ),
          _buildBadge(isWon ? '가계약' : '완료', color),
        ],
      ),
    );
  }

  /// 주간 시간 블록 정보 표시 (판매자가 설정한 요일별 가능 시간)
  Widget _buildWeeklyTimeBlocksInfo(Map<int, List<String>> weeklyBlocks) {
    const weekdayNames = ['월', '화', '수', '목', '금', '토', '일'];
    const blockLabels = {
      'morning': '오전(9-12시)',
      'afternoon': '오후(1-5시)',
      'evening': '저녁(6-8시)',
    };

    // 요일별 시간 정보 생성
    final scheduleInfo = <String>[];
    weeklyBlocks.forEach((weekday, blocks) {
      final dayName = weekdayNames[weekday - 1];
      final blockNames = blocks.map((id) => blockLabels[id] ?? id).join(', ');
      scheduleInfo.add('$dayName: $blockNames');
    });

    return Container(
      padding: const EdgeInsets.all(AppleSpacing.sm),
      decoration: BoxDecoration(
        color: AppleColors.systemGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppleRadius.sm),
        border: Border.all(color: AppleColors.systemGreen.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule, size: 16, color: AppleColors.systemGreen),
              const SizedBox(width: AppleSpacing.xs),
              Text(
                '판매자 방문 가능 시간',
                style: AppleTypography.caption1.copyWith(
                  color: AppleColors.systemGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppleSpacing.xs),
          ...scheduleInfo.map((info) => Padding(
            padding: const EdgeInsets.only(left: 24, top: 2),
            child: Text(
              info,
              style: AppleTypography.caption2.copyWith(
                color: AppleColors.systemGreen.withValues(alpha: 0.9),
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inbox_outlined, size: 56, color: AppleColors.tertiaryLabel),
          const SizedBox(height: 16),
          Text(
            title,
            style: AppleTypography.headline.copyWith(color: AppleColors.secondaryLabel),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AppleTypography.subheadline.copyWith(color: AppleColors.tertiaryLabel),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ========== Actions ==========

  void _showPropertyDetail(MLSProperty property) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MLSPropertyDetailPage(property: property),
      ),
    );
  }

  /// 방문 요청 - 매수자 정보 + 희망가 + 방문 희망 일시
  Future<void> _showQuickProposalSheet(MLSProperty property) async {
    // 미인증 중개사 게이팅
    final isVerified = widget.brokerData?['verified'] as bool? ?? false;
    if (!isVerified) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('관리자 인증을 받은 후 방문 제안이 가능합니다.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final priceController = TextEditingController();
    final messageController = TextEditingController();

    // 상태 변수들
    DateTime? selectedDate;
    TimeOfDay? selectedTime;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          decoration: const BoxDecoration(
            color: AppleColors.systemBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppleRadius.lg)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 핸들바
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppleColors.separator,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),

              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    AppleSpacing.lg,
                    AppleSpacing.md,
                    AppleSpacing.lg,
                    MediaQuery.of(context).viewInsets.bottom + AppleSpacing.lg,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 헤더
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppleColors.systemBlue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.calendar_today_rounded,
                              color: AppleColors.systemBlue,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: AppleSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '방문 요청',
                                  style: AppleTypography.title2.copyWith(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  property.roadAddress,
                                  style: AppleTypography.caption1.copyWith(color: AppleColors.secondaryLabel),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppleSpacing.lg),

                      // 매도 희망가 표시
                      Container(
                        padding: const EdgeInsets.all(AppleSpacing.md),
                        decoration: BoxDecoration(
                          color: AppleColors.tertiarySystemFill,
                          borderRadius: BorderRadius.circular(AppleRadius.sm),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.home_rounded, size: 20, color: AppleColors.secondaryLabel),
                            const SizedBox(width: AppleSpacing.sm),
                            Text(
                              '매도 희망가',
                              style: AppleTypography.subheadline.copyWith(color: AppleColors.secondaryLabel),
                            ),
                            const Spacer(),
                            Text(
                              _formatPrice(property.desiredPrice),
                              style: AppleTypography.headline.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppleColors.label,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppleSpacing.lg),

                      // 1. 희망가 (필수)
                      const Text('희망가 *', style: AppleTypography.headline),
                      const SizedBox(height: AppleSpacing.sm),
                      TextField(
                        controller: priceController,
                        keyboardType: TextInputType.number,
                        style: AppleTypography.title2.copyWith(fontWeight: FontWeight.w600),
                        onChanged: (_) => setSheetState(() {}), // 버튼 활성화 상태 업데이트
                        decoration: InputDecoration(
                          hintText: '0',
                          hintStyle: AppleTypography.title2.copyWith(color: AppleColors.tertiaryLabel),
                          suffixText: '만원',
                          suffixStyle: AppleTypography.body.copyWith(color: AppleColors.secondaryLabel),
                          filled: true,
                          fillColor: AppleColors.tertiarySystemFill,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppleRadius.sm),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppleSpacing.md,
                            vertical: AppleSpacing.md,
                          ),
                        ),
                      ),

                      const SizedBox(height: AppleSpacing.lg),

                      // 3. 방문 희망 일시 (필수)
                      const Text('방문 희망 일시 *', style: AppleTypography.headline),
                      const SizedBox(height: AppleSpacing.sm),

                      // 판매자 가용 시간대 안내 (주간 블록 또는 날짜별)
                      if (property.weeklyTimeBlocks.isNotEmpty) ...[
                        _buildWeeklyTimeBlocksInfo(property.weeklyTimeBlocks),
                        const SizedBox(height: AppleSpacing.sm),
                      ] else if (property.availableSlots.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(AppleSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppleColors.systemGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppleRadius.sm),
                            border: Border.all(color: AppleColors.systemGreen.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.schedule, size: 16, color: AppleColors.systemGreen),
                              const SizedBox(width: AppleSpacing.xs),
                              Expanded(
                                child: Text(
                                  '판매자가 설정한 방문 가능 시간이 있습니다',
                                  style: AppleTypography.caption1.copyWith(color: AppleColors.systemGreen),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppleSpacing.sm),
                      ],

                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now().add(const Duration(days: 1)),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(const Duration(days: 30)),
                                );
                                if (date != null) {
                                  setSheetState(() => selectedDate = date);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(AppleSpacing.md),
                                decoration: BoxDecoration(
                                  color: AppleColors.tertiarySystemFill,
                                  borderRadius: BorderRadius.circular(AppleRadius.sm),
                                  border: selectedDate != null
                                      ? Border.all(color: AppleColors.systemBlue)
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      size: 18,
                                      color: selectedDate != null
                                          ? AppleColors.systemBlue
                                          : AppleColors.secondaryLabel,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      selectedDate != null
                                          ? '${selectedDate!.month}/${selectedDate!.day}'
                                          : '날짜 선택',
                                      style: AppleTypography.body.copyWith(
                                        color: selectedDate != null
                                            ? AppleColors.label
                                            : AppleColors.tertiaryLabel,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppleSpacing.sm),
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                final time = await showTimePicker(
                                  context: context,
                                  initialTime: const TimeOfDay(hour: 14, minute: 0),
                                );
                                if (time != null) {
                                  setSheetState(() => selectedTime = time);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(AppleSpacing.md),
                                decoration: BoxDecoration(
                                  color: AppleColors.tertiarySystemFill,
                                  borderRadius: BorderRadius.circular(AppleRadius.sm),
                                  border: selectedTime != null
                                      ? Border.all(color: AppleColors.systemBlue)
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: 18,
                                      color: selectedTime != null
                                          ? AppleColors.systemBlue
                                          : AppleColors.secondaryLabel,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      selectedTime != null
                                          ? selectedTime!.format(context)
                                          : '시간 선택',
                                      style: AppleTypography.body.copyWith(
                                        color: selectedTime != null
                                            ? AppleColors.label
                                            : AppleColors.tertiaryLabel,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // 선택된 날짜의 가용 시간대 표시
                      if (selectedDate != null) ...[
                        const SizedBox(height: AppleSpacing.md),
                        Builder(
                          builder: (context) {
                            final dateKey = '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}';
                            final slots = property.availableSlots[dateKey] ?? [];
                            final availableSlots = slots.where((s) => s.isAvailable).toList();

                            if (availableSlots.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(AppleSpacing.sm),
                                decoration: BoxDecoration(
                                  color: AppleColors.tertiarySystemFill,
                                  borderRadius: BorderRadius.circular(AppleRadius.sm),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline, size: 16, color: AppleColors.secondaryLabel),
                                    const SizedBox(width: AppleSpacing.xs),
                                    Expanded(
                                      child: Text(
                                        '이 날짜에 설정된 가능 시간대가 없습니다. 원하는 시간을 선택해주세요.',
                                        style: AppleTypography.caption1.copyWith(color: AppleColors.secondaryLabel),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return Container(
                              padding: const EdgeInsets.all(AppleSpacing.sm),
                              decoration: BoxDecoration(
                                color: AppleColors.systemBlue.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(AppleRadius.sm),
                                border: Border.all(color: AppleColors.systemBlue.withValues(alpha: 0.2)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.check_circle, size: 16, color: AppleColors.systemBlue),
                                      const SizedBox(width: AppleSpacing.xs),
                                      Text(
                                        '판매자 가능 시간',
                                        style: AppleTypography.caption1.copyWith(
                                          color: AppleColors.systemBlue,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppleSpacing.xs),
                                  Wrap(
                                    spacing: AppleSpacing.xs,
                                    runSpacing: AppleSpacing.xs,
                                    children: availableSlots.map((slot) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppleSpacing.sm,
                                        vertical: AppleSpacing.xs,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppleColors.systemBlue.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(AppleRadius.xs),
                                      ),
                                      child: Text(
                                        '${slot.startTime} - ${slot.endTime}',
                                        style: AppleTypography.caption2.copyWith(
                                          color: AppleColors.systemBlue,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    )).toList(),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],

                      const SizedBox(height: AppleSpacing.lg),

                      // 3. 추가 메시지 (선택)
                      const Text('추가 메시지', style: AppleTypography.headline),
                      const SizedBox(height: AppleSpacing.sm),
                      TextField(
                        controller: messageController,
                        maxLines: 3,
                        maxLength: 200,
                        decoration: InputDecoration(
                          hintText: '판매자에게 전달할 메시지 (선택)',
                          hintStyle: AppleTypography.body.copyWith(color: AppleColors.tertiaryLabel),
                          filled: true,
                          fillColor: AppleColors.tertiarySystemFill,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppleRadius.sm),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(AppleSpacing.md),
                          counterStyle: AppleTypography.caption2.copyWith(color: AppleColors.tertiaryLabel),
                        ),
                      ),

                      const SizedBox(height: AppleSpacing.xl),

                      // 방문 요청 버튼
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (priceController.text.isNotEmpty && selectedDate != null && selectedTime != null)
                              ? () => Navigator.pop(context, {
                                    'price': double.tryParse(priceController.text) ?? 0,
                                    'date': selectedDate,
                                    'time': selectedTime,
                                    'message': messageController.text,
                                  })
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppleColors.systemBlue,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppleColors.tertiarySystemFill,
                            padding: const EdgeInsets.symmetric(vertical: AppleSpacing.md),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppleRadius.sm),
                            ),
                          ),
                          child: Text(
                            '방문 요청하기',
                            style: AppleTypography.body.copyWith(
                              fontWeight: FontWeight.w600,
                              color: (priceController.text.isNotEmpty && selectedDate != null && selectedTime != null)
                                  ? Colors.white
                                  : AppleColors.tertiaryLabel,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: AppleSpacing.sm),

                      // 안내 문구
                      Center(
                        child: Text(
                          '판매자가 승인하면 연락처가 교환됩니다',
                          style: AppleTypography.caption1.copyWith(color: AppleColors.tertiaryLabel),
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
    );

    if (result != null && mounted) {
      try {
        // 방문 요청 일시 생성
        final date = result['date'] as DateTime;
        final time = result['time'] as TimeOfDay;
        final requestedDateTime = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );

        // 실제 VisitRequest 생성
        await _mlsService.createVisitRequest(
          propertyId: property.id,
          brokerId: widget.brokerId,
          brokerName: widget.brokerName,
          brokerCompany: widget.brokerData?['company'] as String?,
          brokerPhone: widget.brokerData?['phone'] as String?,
          brokerUid: widget.brokerData?['uid'] as String?, // Firebase UID
          proposedPrice: result['price'] as double,
          requestedDateTime: requestedDateTime,
          message: (result['message'] as String).isNotEmpty ? result['message'] as String : null,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('방문 요청을 보냈습니다! 판매자 승인을 기다려주세요.'),
              backgroundColor: AppleColors.systemGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('요청 실패: $e'),
              backgroundColor: AppleColors.systemRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _advanceStage(MLSProperty property) async {
    final myResponse = property.brokerResponses[widget.brokerId];
    if (myResponse == null) return;

    // 새 모델에서는 received → viewed만 가능
    // requested, approved, completed는 판매자 승인 통해서만 변경
    if (myResponse.stage != BrokerStage.received) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('다음 단계는 판매자 승인이 필요합니다'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      await _mlsService.updateBrokerResponse(
        propertyId: property.id,
        brokerId: widget.brokerId,
        brokerName: widget.brokerName,
        stage: BrokerStage.viewed,
        viewed: true,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('매물 확인 완료'),
            backgroundColor: AppleColors.systemGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('실패: $e'),
            backgroundColor: AppleColors.systemRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ========== Helpers ==========

  String _formatPrice(double? price) {
    if (price == null) return '가격 미정';
    final priceInMan = price.round();
    if (priceInMan >= 10000) {
      final uk = priceInMan ~/ 10000;
      final remainder = priceInMan % 10000;
      if (remainder > 0) return '$uk억 $remainder만원';
      return '$uk억';
    }
    return '$priceInMan만원';
  }

  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${dateTime.month}/${dateTime.day}';
  }
}

/// 가격 필터 바텀 시트
class _PriceFilterSheet extends StatefulWidget {
  final RangeValues currentRange;
  final bool isActive;
  final List<Map<String, dynamic>> presets;
  final Function(RangeValues range, bool isActive) onApply;

  const _PriceFilterSheet({
    required this.currentRange,
    required this.isActive,
    required this.presets,
    required this.onApply,
  });

  @override
  State<_PriceFilterSheet> createState() => _PriceFilterSheetState();
}

class _PriceFilterSheetState extends State<_PriceFilterSheet> {
  late RangeValues _range;
  late bool _isActive;
  int _selectedPresetIndex = 0;

  @override
  void initState() {
    super.initState();
    _range = widget.currentRange;
    _isActive = widget.isActive;

    // 현재 범위와 일치하는 프리셋 찾기
    for (int i = 0; i < widget.presets.length; i++) {
      final preset = widget.presets[i];
      if (_range.start == preset['min'] && _range.end == preset['max']) {
        _selectedPresetIndex = i;
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppleColors.systemBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 핸들
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: AppleColors.opaqueSeparator,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
            // 헤더
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '가격대 설정',
                    style: AppleTypography.headline.copyWith(fontWeight: FontWeight.w600),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _range = const RangeValues(0, 500000);
                        _isActive = false;
                        _selectedPresetIndex = 0;
                      });
                    },
                    child: Text(
                      '초기화',
                      style: AppleTypography.subheadline.copyWith(
                        color: AppleColors.systemBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 0.5, color: AppleColors.separator),

            // 프리셋 버튼들
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '빠른 선택',
                    style: AppleTypography.subheadline.copyWith(
                      color: AppleColors.secondaryLabel,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(widget.presets.length, (index) {
                      final preset = widget.presets[index];
                      final isSelected = _selectedPresetIndex == index;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedPresetIndex = index;
                            _range = RangeValues(
                              (preset['min'] as num).toDouble(),
                              (preset['max'] as num).toDouble(),
                            );
                            _isActive = index != 0;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? AppleColors.systemBlue : AppleColors.tertiarySystemFill,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            preset['label'] as String,
                            style: AppleTypography.subheadline.copyWith(
                              color: isSelected ? Colors.white : AppleColors.label,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),

            // 현재 선택된 범위 표시
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppleColors.tertiarySystemFill,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _formatRangeValue(_range.start),
                      style: AppleTypography.title3.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppleColors.systemBlue,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '~',
                        style: AppleTypography.title3.copyWith(
                          color: AppleColors.secondaryLabel,
                        ),
                      ),
                    ),
                    Text(
                      _formatRangeValue(_range.end),
                      style: AppleTypography.title3.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppleColors.systemBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 적용 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onApply(_range, _isActive);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppleColors.systemBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    '적용하기',
                    style: AppleTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatRangeValue(double value) {
    if (value >= 500000) return '50억+';
    if (value >= 10000) {
      return '${(value / 10000).toStringAsFixed(0)}억';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}천만';
    }
    return '${value.toStringAsFixed(0)}만';
  }
}
