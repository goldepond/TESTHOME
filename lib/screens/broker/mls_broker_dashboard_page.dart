import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/broker_participation.dart';
import '../../models/mls_property.dart';
import '../../models/broker_offer.dart';
import '../../models/priority_grant.dart';
import '../../api_request/mls_property_service.dart';
import '../../api_request/priority_grant_service.dart';
import 'priority_appeal_page.dart';
import '../../models/buyer_inquiry.dart';
import '../../api_request/firebase_service.dart';
import '../../constants/app_constants.dart';
import '../../constants/grant_messages.dart';
import '../../constants/typography.dart';
import '../../constants/spacing.dart';
import '../../constants/responsive_constants.dart';
import '../../utils/cloud_functions_guard.dart';
import '../../utils/logger.dart';
import '../../utils/formatters.dart';
import '../../constants/property_constants.dart';
import '../../utils/commission_calculator.dart';
import '../../widgets/home_logo_button.dart';
import '../../widgets/offline_banner.dart';
import '../../widgets/priority_cap_dialog.dart';
import '../../widgets/broker/broker_map_view.dart';
import '../../widgets/broker_verification_status_banner.dart';
import '../../widgets/jurisdiction_picker/jurisdiction_empty_banner.dart';
import '../../widgets/jurisdiction_picker/jurisdiction_picker.dart';
import 'broker_settings_page.dart';
import 'broker_verification_apply_page.dart';
import '_widgets/broker_price_filter_sheet.dart';
import '_widgets/broker_property_card.dart';
import '../auth/auth_landing_page.dart';
import '../notification/notification_page.dart';
import '../seller/mls_property_detail_page.dart';
import '../userInfo/personal_info_page.dart';
import 'package:property/utils/snackbar_utils.dart';

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
  int _selectedLeadStatusIndex = 0; // 0: 전체, 1: 신규, 2: 응답함, 3: 완료
  bool _isMapView = false; // 리스트/지도 토글

  String _getRegionDisplayName(String region) => RegionDisplayNames.of(region);

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
      filtered = filtered.where((p) => p.status == PropertyStatus.inquiry).toList();
    } else if (_selectedStatusIndex == 3) {
      filtered = filtered.where((p) => p.status == PropertyStatus.underOffer).toList();
    } else if (_selectedStatusIndex == 4) {
      filtered = filtered.where((p) => p.status == PropertyStatus.depositTaken).toList();
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
      backgroundColor: AirbnbColors.background,
      body: SafeArea(
        child: OfflineBanner(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                children: [
                  _buildHeader(),
                  _buildVerificationStatusBannerIfNeeded(),
                  _buildJurisdictionEmptyBannerIfNeeded(),
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

  /// Task 001 §E: 인증 신청 상태 배너 (pending/rejected/approved 1회용 토스트).
  ///
  /// 인증 신청을 한 번도 한 적이 없는 경우 본 배너는 미노출 — 부모 인증 안내 시트가 처리.
  Widget _buildVerificationStatusBannerIfNeeded() {
    final brokerData = widget.brokerData;
    if (brokerData == null) return const SizedBox.shrink();
    final verified = brokerData['verified'] as bool? ?? false;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: BrokerVerificationStatusBanner(
        brokerUid: widget.brokerId,
        verified: verified,
      ),
    );
  }

  /// Task 003: 인증 완료 + jurisdictions 빈 상태일 때 경고 배너 노출.
  /// 인증 미완료 (verified=false) 인 경우는 인증 안내 배너가 우선 → 본 배너 숨김.
  Widget _buildJurisdictionEmptyBannerIfNeeded() {
    final brokerData = widget.brokerData;
    if (brokerData == null) return const SizedBox.shrink();
    final isVerified = brokerData['verified'] as bool? ?? false;
    if (!isVerified) return const SizedBox.shrink();
    final raw = brokerData['jurisdictions'];
    final isEmpty = raw == null ||
        (raw is List && raw.isEmpty);
    if (!isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: JurisdictionEmptyBanner(
        onPressEdit: _openJurisdictionPickerFromBanner,
      ),
    );
  }

  /// Task 003: 대시보드 빈 상태 배너에서 picker 열기 (즉시 저장).
  Future<void> _openJurisdictionPickerFromBanner() async {
    final picked = await showJurisdictionPicker(
      context,
      initialCodes: const <String>[],
    );
    if (picked == null || !mounted) return;
    final success = await FirebaseService()
        .updateBrokerJurisdictions(widget.brokerId, picked);
    if (!mounted) return;
    if (success) {
      AppSnackBar.success(context, GrantMessages.jurisdictionSaved);
      // brokerData 미러링 갱신 — 다음 build 시 배너 자동 숨김
      setState(() {
        widget.brokerData?['jurisdictions'] = picked;
      });
    } else {
      // 본인 정보 페이지로 유도 (재시도 경로 단순화)
      AppSnackBar.error(context, GrantMessages.jurisdictionSaveFailed);
      if (mounted) {
        Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => BrokerSettingsPage(
              brokerId: widget.brokerId,
              brokerName: widget.brokerName,
            ),
          ),
        );
      }
    }
  }

  /// 상단 헤더 (로고 + 액션 버튼) - MainPage와 통일된 스타일
  /// 순서: [알림] [설정] [모드전환(primary)] [로그아웃]
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AirbnbColors.background,
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
          // 1-1. 이의 제기 (Task 06)
          _buildHeaderActionButton(
            icon: Icons.report_problem_outlined,
            tooltip: GrantMessages.appealMenuTitle,
            onPressed: _openAppealCenter,
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
              style: TextStyle(color: AirbnbColors.red),
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
              color: isPrimary ? AirbnbColors.primary.withValues(alpha: 0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isPrimary ? AirbnbColors.primary.withValues(alpha: 0.3) : AirbnbColors.border,
              ),
            ),
            child: Icon(
              icon,
              size: 18,
              color: isPrimary ? AirbnbColors.primary : AirbnbColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  /// iOS 스타일 세그먼트 컨트롤
  Widget _buildSegmentedControl() {
    return Container(
      color: AirbnbColors.background,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: AirbnbColors.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            _buildSegment(0, '매물'),
            _buildSegment(1, '관심 매물', badge: _myCompetingProperties.length),
            _buildSegment(2, '방문 요청'),
            _buildSegment(3, '성과'),
            _buildSegment(4, GrantMessages.brokerTabBuyerLeads),
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
            color: isSelected ? AirbnbColors.background : Colors.transparent,
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
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? AirbnbColors.textPrimary : AirbnbColors.textSecondary,
                  ),
                ),
                if (badge > 0) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AirbnbColors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$badge',
                      style: AppTypography.caption.copyWith(
                        color: AirbnbColors.background,
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

  /// Tab 4: 매수자 매칭 — 배정 + 매수자 직접 선택 인콰이어리 통합 목록.
  ///
  /// Task 03: assignedBrokerId(레거시 자동 배정)와 selectedBrokerId(buyer_match)를
  /// 모두 노출. 카드 내 뱃지로 출처 구분.
  Widget _buildBuyerLeadsTab() {
    return StreamBuilder<List<BuyerInquiry>>(
      stream:
          MLSPropertyService().watchBuyerLeadsAndMatches(widget.brokerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        final inquiries = snapshot.data ?? <BuyerInquiry>[];

        if (inquiries.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.people_outline, size: 56, color: AirbnbColors.textLight),
                const SizedBox(height: 16),
                Text(GrantMessages.brokerBuyerLeadsEmpty,
                    style: AppTypography.body.copyWith(color: AirbnbColors.textSecondary)),
                const SizedBox(height: 8),
                Text(GrantMessages.brokerBuyerLeadsHint,
                    style: AppTypography.captionLarge.copyWith(color: AirbnbColors.textLight),
                    textAlign: TextAlign.center),
              ],
            ),
          );
        }

        final filtered = _filterBuyerLeads(inquiries);
        final int directPickCount = inquiries
            .where((BuyerInquiry i) =>
                i.selectedBrokerId == widget.brokerId)
            .length;

        return Column(
          children: [
            // 상태 필터 칩
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildLeadStatusChip(0, '전체', inquiries.length),
                    const SizedBox(width: 8),
                    _buildLeadStatusChip(1, '신규', inquiries.where((i) =>
                        i.status == BuyerInquiryStatus.pending || i.status == BuyerInquiryStatus.brokerAssigned).length),
                    const SizedBox(width: 8),
                    _buildLeadStatusChip(2, '응답함', inquiries.where((i) =>
                        i.status == BuyerInquiryStatus.contacted || i.status == BuyerInquiryStatus.visiting).length),
                    const SizedBox(width: 8),
                    _buildLeadStatusChip(3, '완료', inquiries.where((i) =>
                        i.status == BuyerInquiryStatus.completed || i.status == BuyerInquiryStatus.cancelled).length),
                    const SizedBox(width: 8),
                    _buildLeadStatusChip(4, '매수자 선택', directPickCount),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                itemCount: filtered.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final inquiry = filtered[index];
                  return _buildBuyerLeadCard(inquiry);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  List<BuyerInquiry> _filterBuyerLeads(List<BuyerInquiry> inquiries) {
    if (_selectedLeadStatusIndex == 0) return inquiries;
    if (_selectedLeadStatusIndex == 1) {
      return inquiries.where((i) =>
          i.status == BuyerInquiryStatus.pending || i.status == BuyerInquiryStatus.brokerAssigned).toList();
    }
    if (_selectedLeadStatusIndex == 2) {
      return inquiries.where((i) =>
          i.status == BuyerInquiryStatus.contacted || i.status == BuyerInquiryStatus.visiting).toList();
    }
    if (_selectedLeadStatusIndex == 3) {
      return inquiries.where((i) =>
          i.status == BuyerInquiryStatus.completed || i.status == BuyerInquiryStatus.cancelled).toList();
    }
    // index 4: 매수자 직접 선택 (Task 03 — buyer_match)
    return inquiries
        .where((i) => i.selectedBrokerId == widget.brokerId)
        .toList();
  }

  Widget _buildLeadStatusChip(int index, String label, int count) {
    final isSelected = _selectedLeadStatusIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedLeadStatusIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AirbnbColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: isSelected ? null : Border.all(color: AirbnbColors.border),
        ),
        child: Text(
          '$label $count',
          style: AppTypography.bodySmall.copyWith(
            color: isSelected ? Colors.white : AirbnbColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildBuyerLeadCard(BuyerInquiry inquiry) {
    final statusColor = switch (inquiry.status) {
      BuyerInquiryStatus.pending => AirbnbColors.orange,
      BuyerInquiryStatus.brokerAssigned => AirbnbColors.primary,
      BuyerInquiryStatus.contacted => AirbnbColors.green,
      BuyerInquiryStatus.visiting => AirbnbColors.teal,
      BuyerInquiryStatus.completed => AirbnbColors.textSecondary,
      BuyerInquiryStatus.cancelled => AirbnbColors.red,
    };

    // Task 03: 본인이 매수자가 직접 선택한 buyer_match 중개사인지 표시.
    final bool isBuyerSelected =
        inquiry.selectedBrokerId == widget.brokerId;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AirbnbColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isBuyerSelected
              ? AirbnbColors.primary.withValues(alpha: 0.5)
              : AirbnbColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline, size: 16, color: AirbnbColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(inquiry.buyerName,
                    style: AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(inquiry.status.label,
                    style: AppTypography.caption.copyWith(
                        color: statusColor, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          if (isBuyerSelected) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AirbnbColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AirbnbColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.handshake_outlined,
                      size: 14, color: AirbnbColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    '매수자 직접 선택',
                    style: AppTypography.caption.copyWith(
                      color: AirbnbColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (inquiry.buyerPhone != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.phone_outlined, size: 14, color: AirbnbColors.textLight),
                const SizedBox(width: 6),
                Text(inquiry.buyerPhone!,
                    style: AppTypography.bodySmall.copyWith(color: AirbnbColors.textPrimary)),
              ],
            ),
          ],
          if (inquiry.buyerMessage != null && inquiry.buyerMessage!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(inquiry.buyerMessage!,
                style: AppTypography.captionLarge.copyWith(color: AirbnbColors.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 8),
          Text(
            '문의일: ${inquiry.createdAt.month}/${inquiry.createdAt.day}',
            style: AppTypography.caption.copyWith(color: AirbnbColors.textLight),
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
          const Icon(Icons.error_outline, size: 48, color: AirbnbColors.red),
          const SizedBox(height: 16),
          Text(_errorMessage!, style: AppTypography.body.copyWith(color: AirbnbColors.textSecondary)),
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
              : _isMapView
                  ? BrokerMapView(
                      properties: _allProperties,
                      onPropertyTapped: (property) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MLSPropertyDetailPage(
                              property: property,
                            ),
                          ),
                        );
                      },
                    )
                  : RefreshIndicator(
                      onRefresh: () async => _subscribeToProperties(),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                        itemCount: _allProperties.length,
                        itemBuilder: (context, index) {
                          final property = _allProperties[index];
                          return BrokerPropertyCard(
                            property: property,
                            brokerId: widget.brokerId,
                            isVerifiedBroker: _isVerifiedBroker,
                            onTap: () => _showPropertyDetail(property),
                            onPropose: () => _isVerifiedBroker
                                ? _showQuickProposalSheet(property)
                                : _showVerificationGuideSheet(),
                            onProposalModify: () => _showQuickProposalSheet(property),
                            currentBrokerUid:
                                FirebaseAuth.instance.currentUser?.uid,
                            onTakeProperty: () => _handleTakeProperty(property),
                          );
                        },
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
      color: AirbnbColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 구분선
          Container(height: 0.5, color: AirbnbColors.border),

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
                const SizedBox(width: 8),
                // 리스트/지도 토글
                GestureDetector(
                  onTap: () => setState(() => _isMapView = !_isMapView),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _isMapView
                          ? AirbnbColors.primary.withValues(alpha: 0.1)
                          : AirbnbColors.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _isMapView ? Icons.list : Icons.map_outlined,
                      size: 20,
                      color: _isMapView ? AirbnbColors.primary : AirbnbColors.textSecondary,
                    ),
                  ),
                ),
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
                          color: AirbnbColors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.close, size: 14, color: AirbnbColors.red),
                            const SizedBox(width: 4),
                            Text(
                              '초기화',
                              style: AppTypography.caption.copyWith(
                                color: AirbnbColors.red,
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
          color: isActive ? AirbnbColors.primary : AirbnbColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? Colors.white : AirbnbColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: isActive ? Colors.white : AirbnbColors.textPrimary,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: isActive ? Colors.white : AirbnbColors.textSecondary,
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
      builder: (context) => BrokerPriceFilterSheet(
        currentRange: _priceRange,
        isActive: _isPriceFilterActive,
        presets: PropertyConstants.pricePresets,
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
          color: AirbnbColors.background,
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
                color: AirbnbColors.border,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
            // 타이틀
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '매물 유형',
                style: AppTypography.h4.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Container(height: 0.5, color: AirbnbColors.border),
            // 옵션 리스트
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  _buildPropertyTypeOption(null, '전체'),
                  ...PropertyConstants.propertyTypes.map((type) => _buildPropertyTypeOption(type, type)),
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
        color: isSelected ? AirbnbColors.primary : AirbnbColors.textSecondary,
      ),
      title: Text(
        label,
        style: AppTypography.body.copyWith(
          color: isSelected ? AirbnbColors.primary : AirbnbColors.textPrimary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check, color: AirbnbColors.primary, size: 20)
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
          color: AirbnbColors.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: AirbnbColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: AirbnbColors.textSecondary,
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
          color: AirbnbColors.background,
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
                color: AirbnbColors.border,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
            // 타이틀
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '지역 선택',
                style: AppTypography.h4.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Container(height: 0.5, color: AirbnbColors.border),
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
        style: AppTypography.body.copyWith(
          color: isSelected ? AirbnbColors.primary : AirbnbColors.textPrimary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check, color: AirbnbColors.primary, size: 20)
          : null,
    );
  }

  Widget _buildStatusFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildStatusPill(0, '전체'),
          const SizedBox(width: 8),
          _buildStatusPill(1, '신규'),
          const SizedBox(width: 8),
          _buildStatusPill(2, '문의중'),
          const SizedBox(width: 8),
          _buildStatusPill(3, '협상중'),
          const SizedBox(width: 8),
          _buildStatusPill(4, '가계약'),
        ],
      ),
    );
  }

  Widget _buildStatusPill(int index, String label) {
    final isSelected = _selectedStatusIndex == index;
    return GestureDetector(
      onTap: () => _onStatusChanged(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AirbnbColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: isSelected ? null : Border.all(color: AirbnbColors.border),
        ),
        child: Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: isSelected ? Colors.white : AirbnbColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }


  Widget _buildStatusBadge(PropertyStatus status) {
    final (label, color) = switch (status) {
      PropertyStatus.active => ('신규', AirbnbColors.green),
      PropertyStatus.inquiry => ('문의중', AirbnbColors.primary),
      PropertyStatus.underOffer => ('협상중', AirbnbColors.orange),
      PropertyStatus.depositTaken => ('가계약', AirbnbColors.purple),
      PropertyStatus.sold => ('완료', AirbnbColors.textSecondary),
      _ => ('', AirbnbColors.textSecondary),
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
        style: AppTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  bool get _isVerifiedBroker => widget.brokerData?['verified'] as bool? ?? false;

  void _showVerificationGuideSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AirbnbColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: AirbnbColors.border,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              const SizedBox(height: 24),
              const Icon(Icons.verified_outlined, size: 48, color: AirbnbColors.primary),
              const SizedBox(height: 16),
              Text(
                '인증하면 더 많은 기능을 쓸 수 있어요',
                style: AppTypography.h3.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              _buildGuideRow(Icons.handshake_outlined, '매물 방문 요청'),
              _buildGuideRow(Icons.contacts_outlined, '판매자 연락처 교환'),
              _buildGuideRow(Icons.insights_outlined, '성과 리포트 확인'),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => BrokerVerificationApplyPage(brokerUid: widget.brokerId)),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AirbnbColors.primary,
                    foregroundColor: AirbnbColors.background,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('인증 신청하기', style: AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuideRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AirbnbColors.green),
          const SizedBox(width: 12),
          Text(text, style: AppTypography.body),
        ],
      ),
    );
  }


  Widget _buildSecondaryButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: AppTypography.bodySmall.copyWith(
          color: AirbnbColors.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// Tab 1: 내 참여
  Widget _buildMyCompetingTab() {
    if (_myCompetingProperties.isEmpty) {
      return _buildEmptyState('참여 중인 매물이 없습니다', '매물 탭에서 관심 있는 매물을 선택하세요');
    }

    return RefreshIndicator(
      onRefresh: () async => _subscribeToProperties(),
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _myCompetingProperties.length + 2, // +1 header, +1 participations
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '내가 확인하고 관심을 표시한 매물',
                    style: AppTypography.bodySmall.copyWith(color: AirbnbColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_myCompetingProperties.length}건 진행 중',
                    style: AppTypography.h4.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            );
          }
          if (index == 1) {
            // Task 05 — 본인 참여(broker_participations) 활동 기록.
            return _buildMyParticipationsSection();
          }
          return _buildCompetingCard(_myCompetingProperties[index - 2]);
        },
      ),
    );
  }

  /// Task 05 — 중개사 본인의 broker_participations 목록.
  ///
  /// callable [MLSPropertyService.getMyParticipations] 결과를 매물별로
  /// 한 줄씩 [ListTile]로 표시. relatedGrantId가 있으면 "우선권 부여됨" 보조 텍스트.
  Widget _buildMyParticipationsSection() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: FutureBuilder<List<BrokerParticipation>>(
        future: _mlsService.getMyParticipations(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox.shrink();
          }
          if (snapshot.hasError) {
            Logger.warning(
              'getMyParticipations failed (broker tab)',
              metadata: <String, dynamic>{
                'error': snapshot.error.toString(),
              },
            );
            return const SizedBox.shrink();
          }
          final List<BrokerParticipation> items =
              snapshot.data ?? const <BrokerParticipation>[];
          if (items.isEmpty) return const SizedBox.shrink();

          return Container(
            decoration: BoxDecoration(
              color: AirbnbColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AirbnbColors.border),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    GrantMessages.participationTimelineTitle,
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AirbnbColors.textPrimary,
                    ),
                  ),
                ),
                for (final BrokerParticipation p in items)
                  _buildMyParticipationTile(p),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMyParticipationTile(BrokerParticipation p) {
    final String stageLabel = GrantMessages.participationStageLabel(
      BrokerParticipation.stageToString(p.stage),
    );
    String? declaredText;
    final DateTime? at = p.declaredAt;
    if (at != null) {
      declaredText =
          '${at.year}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')} '
          '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    }
    return ListTile(
      dense: true,
      title: Text(
        '${p.displayName} · $stageLabel',
        style: AppTypography.bodySmall.copyWith(
          color: AirbnbColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (declaredText != null)
            Text(
              declaredText,
              style: AppTypography.caption.copyWith(
                color: AirbnbColors.textLight,
              ),
            ),
          if (p.relatedGrantId != null && p.relatedGrantId!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                GrantMessages.brokerNotificationGrantIssuedSuffix,
                style: AppTypography.caption.copyWith(
                  color: AirbnbColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCompetingCard(MLSProperty property) {
    final myResponse = property.brokerResponses[widget.brokerId];
    final myStage = myResponse?.stage ?? BrokerStage.received;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AirbnbColors.background,
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
                  style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _formatPrice(property.desiredPrice),
                  style: AppTypography.h3.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AirbnbColors.primary,
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
                        const Icon(Icons.percent, size: 12, color: AirbnbColors.textLight),
                        const SizedBox(width: 4),
                        Text(
                          '법정 최고 $maxRate% (${CommissionCalculator.formatCommission(maxCommission)})',
                          style: AppTypography.caption.copyWith(
                            color: AirbnbColors.textLight,
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
                    const Icon(Icons.person_outline, size: 14, color: AirbnbColors.textLight),
                    const SizedBox(width: 4),
                    Text(
                      property.userName.isNotEmpty ? property.userName : '매도인',
                      style: AppTypography.caption.copyWith(color: AirbnbColors.textSecondary),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.schedule_outlined, size: 14, color: AirbnbColors.textLight),
                    const SizedBox(width: 4),
                    Text(
                      _formatRelativeTime(property.createdAt),
                      style: AppTypography.caption.copyWith(color: AirbnbColors.textLight),
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
                        style: AppTypography.caption.copyWith(color: AirbnbColors.textSecondary),
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
      BrokerStage.received => ('수신', AirbnbColors.textSecondary),
      BrokerStage.viewed => ('열람', AirbnbColors.primary),
      BrokerStage.requested => ('요청', AirbnbColors.orange),
      BrokerStage.approved => ('승인', AirbnbColors.green),
      BrokerStage.completed => ('완료', AirbnbColors.purple),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '내가 보낸 방문 요청 및 중개 제안',
                      style: AppTypography.bodySmall.copyWith(color: AirbnbColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Row(
                  children: [
                    Text(
                      '총 ${offers.length}건',
                      style: AppTypography.h4.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    if (pendingCount > 0)
                      _buildBadge('대기 $pendingCount', AirbnbColors.orange),
                    if (pendingCount > 0 && selectedCount > 0)
                      const SizedBox(width: 6),
                    if (selectedCount > 0)
                      _buildBadge('선정 $selectedCount', AirbnbColors.green),
                  ],
                ),
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
      BrokerOfferStatus.pending => ('대기중', AirbnbColors.orange),
      BrokerOfferStatus.selected => ('선정됨', AirbnbColors.green),
      BrokerOfferStatus.rejected => ('미선정', AirbnbColors.textSecondary),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AirbnbColors.background,
        borderRadius: BorderRadius.circular(12),
        border: offer.status == BrokerOfferStatus.selected
            ? Border.all(color: AirbnbColors.green.withValues(alpha: 0.4))
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
                    style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
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
                color: AirbnbColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                offer.pitch,
                style: AppTypography.bodySmall.copyWith(
                  color: offer.status == BrokerOfferStatus.rejected
                      ? AirbnbColors.textLight
                      : AirbnbColors.textPrimary,
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
                const Icon(Icons.schedule_outlined, size: 14, color: AirbnbColors.textLight),
                const SizedBox(width: 4),
                Text(
                  _formatTimeAgo(offer.createdAt),
                  style: AppTypography.caption.copyWith(color: AirbnbColors.textLight),
                ),
                if (offer.status == BrokerOfferStatus.selected && offer.selectedAt != null) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.check_circle_outline, size: 14, color: AirbnbColors.green),
                  const SizedBox(width: 4),
                  Text(
                    '${offer.selectedAt!.month}/${offer.selectedAt!.day} 선정',
                    style: AppTypography.caption.copyWith(
                      color: AirbnbColors.green,
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
        color: AirbnbColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isVerified ? AirbnbColors.green.withValues(alpha: 0.3) : AirbnbColors.border,
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
                  color: AirbnbColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(
                  Icons.store_rounded,
                  color: AirbnbColors.primary,
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
                            style: AppTypography.h3.copyWith(
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
                                ? AirbnbColors.green.withValues(alpha: 0.1)
                                : AirbnbColors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isVerified ? Icons.verified : Icons.pending_outlined,
                                size: 14,
                                color: isVerified ? AirbnbColors.green : AirbnbColors.orange,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isVerified ? '인증' : '미인증',
                                style: AppTypography.caption.copyWith(
                                  color: isVerified ? AirbnbColors.green : AirbnbColors.orange,
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
                      style: AppTypography.bodySmall.copyWith(
                        color: AirbnbColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          Container(height: 0.5, color: AirbnbColors.border),
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
          Icon(icon, size: 18, color: AirbnbColors.textSecondary),
          const SizedBox(width: 12),
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: AirbnbColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodySmall.copyWith(
                color: AirbnbColors.textPrimary,
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
      style: AppTypography.h4.copyWith(fontWeight: FontWeight.w600),
    );
  }

  Widget _buildResultCard(MLSProperty property, {required bool isWon}) {
    final color = isWon ? AirbnbColors.green : AirbnbColors.purple;
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
        color: AirbnbColors.background,
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
                  style: AppTypography.body.copyWith(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _formatPrice(property.finalPrice ?? property.desiredPrice),
                  style: AppTypography.bodySmall.copyWith(color: color, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '수수료 ${CommissionCalculator.formatCommission(estimatedCommission)} ($maxRate%)',
                  style: AppTypography.caption.copyWith(color: AirbnbColors.textLight),
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
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: AirbnbColors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AirbnbColors.green.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule, size: 16, color: AirbnbColors.green),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '판매자 방문 가능 시간',
                style: AppTypography.caption.copyWith(
                  color: AirbnbColors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...scheduleInfo.map((info) => Padding(
            padding: const EdgeInsets.only(left: 24, top: 2),
            child: Text(
              info,
              style: AppTypography.caption.copyWith(
                color: AirbnbColors.green.withValues(alpha: 0.9),
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildAvailableSlotsPreview(Map<String, List<TimeSlot>> slots) {
    // 향후 7일 이내의 슬롯만 필터
    final now = DateTime.now();
    final upcoming = <String, List<TimeSlot>>{};
    for (final entry in slots.entries) {
      final date = DateTime.tryParse(entry.key);
      if (date != null && date.isAfter(now.subtract(const Duration(days: 1))) &&
          date.isBefore(now.add(const Duration(days: 8)))) {
        final available = entry.value.where((s) => s.isAvailable).toList();
        if (available.isNotEmpty) upcoming[entry.key] = available;
      }
    }

    if (upcoming.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: AirbnbColors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AirbnbColors.green.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.schedule, size: 16, color: AirbnbColors.green),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                '판매자가 설정한 방문 가능 시간이 있습니다',
                style: AppTypography.caption.copyWith(color: AirbnbColors.green),
              ),
            ),
          ],
        ),
      );
    }

    final sortedKeys = upcoming.keys.toList()..sort();
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: AirbnbColors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AirbnbColors.green.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule, size: 16, color: AirbnbColors.green),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '방문 가능 시간',
                style: AppTypography.caption.copyWith(
                  color: AirbnbColors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...sortedKeys.take(5).map((dateStr) {
            final date = DateTime.parse(dateStr);
            final slots = upcoming[dateStr]!;
            final timeStr = slots.map((s) => '${s.startTime}~${s.endTime}').join(', ');
            return Padding(
              padding: const EdgeInsets.only(left: 24, top: 2),
              child: Text(
                '${date.month}/${date.day} $timeStr',
                style: AppTypography.caption.copyWith(
                  color: AirbnbColors.green.withValues(alpha: 0.9),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inbox_outlined, size: 56, color: AirbnbColors.textLight),
          const SizedBox(height: 16),
          Text(
            title,
            style: AppTypography.h4.copyWith(color: AirbnbColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AppTypography.bodySmall.copyWith(color: AirbnbColors.textLight),
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

  /// '이 매물 받기' 처리.
  ///
  /// Cloud Function `issuePriorityGrant`를 호출해 우선권 발급을 시도하고,
  /// 5개 한도(`cap_exceeded`) 도달 시 [PriorityCapDialog]로 1건 만료 후 1회 재시도한다.
  /// 그 외 거절 사유는 [GrantMessages.describeReason]으로 노인 화법 변환해 SnackBar 노출.
  Future<void> _handleTakeProperty(
    MLSProperty property, {
    bool isRetry = false,
  }) async {
    final service = PriorityGrantService();
    try {
      await service.requestGrantViaFunction(
        propertyId: property.id,
        brokerId: widget.brokerId,
        type: 'seller_match',
        stage: 'participation',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(GrantMessages.issuedSuccess),
          backgroundColor: AirbnbColors.success,
        ),
      );
    } on CloudFunctionsUserFacingException catch (e) {
      // problem 002 가드 — 서비스 레이어에서 NOT_FOUND 등을 한국어로 변환한 예외.
      Logger.warning(
        'take property failed (guarded)',
        metadata: <String, dynamic>{
          'propertyId': property.id,
          'functionName': e.functionName,
          'firebaseCode': e.firebaseCode,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.userMessage),
          backgroundColor: AirbnbColors.error,
        ),
      );
      return;
    } catch (e, stack) {
      Logger.warning(
        'take property failed (MLSBrokerDashboardPage)',
        metadata: <String, dynamic>{
          'propertyId': property.id,
          'isRetry': isRetry,
          'error': e.toString(),
          'stack': stack.toString(),
        },
      );
      final String? code = GrantMessages.extractReasonCode(e.toString());

      // cap_exceeded → 5개 한도 다이얼로그로 안내, revoke 성공 시 1회 재시도.
      if (code == 'cap_exceeded' && !isRetry) {
        final String? brokerUid = FirebaseAuth.instance.currentUser?.uid;
        if (brokerUid == null || brokerUid.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(GrantMessages.describeReason(code)),
              backgroundColor: AirbnbColors.error,
            ),
          );
          return;
        }

        try {
          final List<PriorityGrant> myActive =
              await service.watchByBroker(brokerUid).first;
          if (!mounted) return;
          final bool revoked = await PriorityCapDialog.show(
            context: context,
            myActiveGrants: myActive,
            onRevoke: (String grantId) =>
                service.revokeOwnGrantViaFunction(grantId),
          );
          if (revoked && mounted) {
            await _handleTakeProperty(property, isRetry: true);
          }
        } catch (e2, stack2) {
          Logger.error(
            'cap dialog flow failed',
            error: e2,
            stackTrace: stack2,
            context: 'MLSBrokerDashboardPage',
          );
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(GrantMessages.describeReason(null)),
              backgroundColor: AirbnbColors.error,
            ),
          );
        }
        return;
      }

      // P2-4: score_below_threshold 는 reasonCopy("아직 받기 어려워요") 만으로
      // 부족하다 — Task 02 §5.5 #8 권고에 따라 scoringInputs.rawInputs 를 파싱해
      // 가장 큰 부족 요인 1줄(80세 화법)을 안내한다. 점수/가중치 노출 0.
      String message = GrantMessages.describeReason(code);
      if (code == 'score_below_threshold') {
        final Map<String, dynamic> rawInputs =
            GrantMessages.extractScoringInputs(e.toString());
        if (rawInputs.isNotEmpty) {
          message = GrantMessages.describeScoringFailure(rawInputs);
        }
      }

      // 그 외 사유 → 단일 SnackBar.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AirbnbColors.error,
        ),
      );
    }
  }

  /// 방문 요청 - 매수자 정보 + 희망가 + 방문 희망 일시
  Future<void> _showQuickProposalSheet(MLSProperty property) async {
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
            color: AirbnbColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
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
                    color: AirbnbColors.border,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),

              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    20.0,
                    AppSpacing.md,
                    20.0,
                    MediaQuery.of(context).viewInsets.bottom + 20.0,
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
                              color: AirbnbColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.calendar_today_rounded,
                              color: AirbnbColors.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '방문 요청',
                                  style: AppTypography.h2.copyWith(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  property.roadAddress,
                                  style: AppTypography.caption.copyWith(color: AirbnbColors.textSecondary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20.0),

                      // 매도 희망가 표시
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AirbnbColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.home_rounded, size: 20, color: AirbnbColors.textSecondary),
                            const SizedBox(width: 12.0),
                            Text(
                              '매도 희망가',
                              style: AppTypography.bodySmall.copyWith(color: AirbnbColors.textSecondary),
                            ),
                            const Spacer(),
                            Text(
                              _formatPrice(property.desiredPrice),
                              style: AppTypography.h4.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AirbnbColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20.0),

                      // 1. 희망가 (필수)
                      const Text('희망가 *', style: AppTypography.h4),
                      const SizedBox(height: 12.0),
                      TextField(
                        controller: priceController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          ThousandsSeparatorFormatter(),
                        ],
                        style: AppTypography.h2.copyWith(fontWeight: FontWeight.w600),
                        onChanged: (_) => setSheetState(() {}), // 버튼 활성화 상태 업데이트
                        decoration: InputDecoration(
                          hintText: '0',
                          hintStyle: AppTypography.h2.copyWith(color: AirbnbColors.textLight),
                          suffixText: '만원',
                          suffixStyle: AppTypography.body.copyWith(color: AirbnbColors.textSecondary),
                          filled: true,
                          fillColor: AirbnbColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.md,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20.0),

                      // 3. 방문 희망 일시 (필수)
                      const Text('방문 희망 일시 *', style: AppTypography.h4),
                      const SizedBox(height: 12.0),

                      // 판매자 가용 시간대 안내 (주간 블록 또는 날짜별)
                      if (property.weeklyTimeBlocks.isNotEmpty) ...[
                        _buildWeeklyTimeBlocksInfo(property.weeklyTimeBlocks),
                        const SizedBox(height: 12.0),
                      ] else if (property.availableSlots.isNotEmpty) ...[
                        _buildAvailableSlotsPreview(property.availableSlots),
                        const SizedBox(height: 12.0),
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
                                padding: const EdgeInsets.all(AppSpacing.md),
                                decoration: BoxDecoration(
                                  color: AirbnbColors.surface,
                                  borderRadius: BorderRadius.circular(AppRadius.sm),
                                  border: selectedDate != null
                                      ? Border.all(color: AirbnbColors.primary)
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      size: 18,
                                      color: selectedDate != null
                                          ? AirbnbColors.primary
                                          : AirbnbColors.textSecondary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      selectedDate != null
                                          ? '${selectedDate!.month}/${selectedDate!.day}'
                                          : '날짜 선택',
                                      style: AppTypography.body.copyWith(
                                        color: selectedDate != null
                                            ? AirbnbColors.textPrimary
                                            : AirbnbColors.textLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12.0),
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
                                padding: const EdgeInsets.all(AppSpacing.md),
                                decoration: BoxDecoration(
                                  color: AirbnbColors.surface,
                                  borderRadius: BorderRadius.circular(AppRadius.sm),
                                  border: selectedTime != null
                                      ? Border.all(color: AirbnbColors.primary)
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: 18,
                                      color: selectedTime != null
                                          ? AirbnbColors.primary
                                          : AirbnbColors.textSecondary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      selectedTime != null
                                          ? selectedTime!.format(context)
                                          : '시간 선택',
                                      style: AppTypography.body.copyWith(
                                        color: selectedTime != null
                                            ? AirbnbColors.textPrimary
                                            : AirbnbColors.textLight,
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
                        const SizedBox(height: AppSpacing.md),
                        Builder(
                          builder: (context) {
                            final dateKey = '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}';
                            final slots = property.availableSlots[dateKey] ?? [];
                            final availableSlots = slots.where((s) => s.isAvailable).toList();

                            if (availableSlots.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(12.0),
                                decoration: BoxDecoration(
                                  color: AirbnbColors.surface,
                                  borderRadius: BorderRadius.circular(AppRadius.sm),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline, size: 16, color: AirbnbColors.textSecondary),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Text(
                                        '이 날짜에 설정된 가능 시간대가 없습니다. 원하는 시간을 선택해주세요.',
                                        style: AppTypography.caption.copyWith(color: AirbnbColors.textSecondary),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return Container(
                              padding: const EdgeInsets.all(12.0),
                              decoration: BoxDecoration(
                                color: AirbnbColors.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                                border: Border.all(color: AirbnbColors.primary.withValues(alpha: 0.2)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.check_circle, size: 16, color: AirbnbColors.primary),
                                      const SizedBox(width: AppSpacing.sm),
                                      Text(
                                        '판매자 가능 시간',
                                        style: AppTypography.caption.copyWith(
                                          color: AirbnbColors.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  Wrap(
                                    spacing: AppSpacing.sm,
                                    runSpacing: AppSpacing.sm,
                                    children: availableSlots.map((slot) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12.0,
                                        vertical: AppSpacing.sm,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AirbnbColors.primary.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4.0),
                                      ),
                                      child: Text(
                                        '${slot.startTime} - ${slot.endTime}',
                                        style: AppTypography.caption.copyWith(
                                          color: AirbnbColors.primary,
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

                      const SizedBox(height: 20.0),

                      // 3. 추가 메시지 (선택)
                      const Text('추가 메시지', style: AppTypography.h4),
                      const SizedBox(height: 12.0),
                      TextField(
                        controller: messageController,
                        maxLines: 3,
                        maxLength: 200,
                        decoration: InputDecoration(
                          hintText: '판매자에게 전달할 메시지 (선택)',
                          hintStyle: AppTypography.body.copyWith(color: AirbnbColors.textLight),
                          filled: true,
                          fillColor: AirbnbColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(AppSpacing.md),
                          counterStyle: AppTypography.caption.copyWith(color: AirbnbColors.textLight),
                        ),
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      // 방문 요청 버튼
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (priceController.text.isNotEmpty && selectedDate != null && selectedTime != null)
                              ? () => Navigator.pop(context, {
                                    'price': double.tryParse(priceController.text.replaceAll(',', '')) ?? 0,
                                    'date': selectedDate,
                                    'time': selectedTime,
                                    'message': messageController.text,
                                  })
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AirbnbColors.primary,
                            foregroundColor: AirbnbColors.background,
                            disabledBackgroundColor: AirbnbColors.surface,
                            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                          ),
                          child: Text(
                            '방문 요청하기',
                            style: AppTypography.body.copyWith(
                              fontWeight: FontWeight.w600,
                              color: (priceController.text.isNotEmpty && selectedDate != null && selectedTime != null)
                                  ? AirbnbColors.background
                                  : AirbnbColors.textLight,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12.0),

                      // 안내 문구
                      Center(
                        child: Text(
                          '판매자가 승인하면 연락처가 교환됩니다',
                          style: AppTypography.caption.copyWith(color: AirbnbColors.textLight),
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
          AppSnackBar.success(context, '방문 요청을 보냈습니다! 판매자 승인을 기다려주세요.');
          // 내 참여 탭으로 자동 전환
          _tabController.animateTo(1);
        }
      } catch (e) {
        if (mounted) {
          AppSnackBar.error(context, '요청에 실패했습니다. 잠시 후 다시 시도해 주세요.');
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
      AppSnackBar.info(context, '다음 단계는 판매자 승인이 필요합니다');
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
        AppSnackBar.success(context, '매물 확인 완료');
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, '처리에 실패했습니다. 잠시 후 다시 시도해 주세요.');
      }
    }
  }

  // ========== Helpers ==========

  String _formatPrice(double? price) => PriceFormatter.format(price);

  String _formatTimeAgo(DateTime dateTime) => DateTimeFormatter.timeAgo(dateTime);

  /// Task 06 / P1-21.1 — 이의 제기 페이지로 이동.
  /// Problem 004 — `PriorityAppealPage` 가 `actorUid` / `role` 일반화됨.
  /// 본 broker 진입은 default `AppealActorRole.broker` 그대로 호환.
  void _openAppealCenter() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PriorityAppealPage(actorUid: widget.brokerId),
      ),
    );
  }
}
