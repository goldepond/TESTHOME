import 'package:flutter/material.dart';

import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:property/constants/app_constants.dart';
import 'package:property/api_request/broker_service.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/api_request/vworld_service.dart';
import 'package:property/models/quote_request.dart';
import 'package:property/screens/quote_history_page.dart';
import 'package:property/screens/login_page.dart';
import 'package:property/widgets/home_logo_button.dart';

/// 공인중개사 찾기 페이지
class BrokerListPage extends StatefulWidget {
  final String address;
  final double latitude;
  final double longitude;
  final String userName; // 로그인 사용자 이름
  final String? propertyArea; // 토지 면적 (자동)
  final String? userId; // 로그인 사용자 ID (자주 가는 위치 조회용)

  const BrokerListPage({
    required this.address,
    required this.latitude,
    required this.longitude,
    this.userName = '', // 기본값: 비로그인
    this.propertyArea, // 기본값: null
    this.userId,
    super.key,
  });

  @override
  State<BrokerListPage> createState() => _BrokerListPageState();
}

class _BrokerListPageState extends State<BrokerListPage> with SingleTickerProviderStateMixin {
  // 원본 보관
  List<Broker> propertyBrokers = [];
  List<Broker> frequentBrokers = [];
  // 현재 표시/필터 대상
  List<Broker> brokers = [];
  List<Broker> filteredBrokers = []; // 필터링된 목록
  bool isLoading = true;
  String? error;
  final FirebaseService _firebaseService = FirebaseService();
  bool isFrequentLoading = false;
  String? frequentError;
  late TabController _tabController;
  bool get _isLoggedIn => (widget.userId != null && widget.userId!.isNotEmpty);

  // 페이지네이션 상태
  final int _pageSize = 10;
  int _currentPage = 0;
  
  // 필터 & 검색 상태
  String searchKeyword = '';
  bool showOnlyWithPhone = false;
  bool showOnlyOpen = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 로그인 여부에 따라 탭 개수 결정
    _tabController = TabController(length: _isLoggedIn ? 2 : 1, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) return;
      _setActiveSource(_tabController.index);
    });
    _searchBrokers();
    _loadFrequentBrokersIfPossible();
  }

  void _setActiveSource(int tabIndex) {
    setState(() {
      if (tabIndex == 0) {
        brokers = List<Broker>.from(propertyBrokers);
      } else {
        brokers = List<Broker>.from(frequentBrokers);
      }
      _sortBySystemRegNo(brokers);
      _applyFilters();
    });
  }

  Future<void> _loadFrequentBrokersIfPossible() async {
    if ((widget.userId == null) || widget.userId!.isEmpty) {
      return;
    }
    try {
      setState(() {
        isFrequentLoading = true;
        frequentError = null;
      });
      final userData = await _firebaseService.getUser(widget.userId!);
      final String? location = userData?['firstZone'] ?? userData?['frequentLocation'];
      if (location == null || location.isEmpty) {
        setState(() {
          isFrequentLoading = false;
          frequentBrokers = [];
        });
        return;
      }

      final coord = await VWorldService.getCoordinatesFromAddress(location);
      if (coord == null) {
        setState(() {
          isFrequentLoading = false;
          frequentError = '자주 가는 위치 좌표를 가져오지 못했습니다.';
        });
        return;
      }
      final lat = double.tryParse('${coord['y']}');
      final lon = double.tryParse('${coord['x']}');
      if (lat == null || lon == null) {
        setState(() {
          isFrequentLoading = false;
          frequentError = '자주 가는 위치 좌표 형식이 올바르지 않습니다.';
        });
        return;
      }

      final results = await BrokerService.searchNearbyBrokers(
        latitude: lat,
        longitude: lon,
        radiusMeters: 1000,
      );
      if (!mounted) return;
      setState(() {
        frequentBrokers = results;
        _sortBySystemRegNo(frequentBrokers);
        isFrequentLoading = false;
        if (_tabController.index == 1) {
          brokers = List<Broker>.from(frequentBrokers);
          _applyFilters();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        frequentError = '자주 가는 위치 주변 중개사 조회 중 오류가 발생했습니다.';
        isFrequentLoading = false;
      });
    }
  }

  /// 공인중개사 검색
  Future<void> _searchBrokers() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final searchResults = await BrokerService.searchNearbyBrokers(
        latitude: widget.latitude,
        longitude: widget.longitude,
        radiusMeters: 1000, // 1km 반경
      );

      if (!mounted) return; // 위젯이 dispose된 경우 setState 호출 방지

      setState(() {
        propertyBrokers = searchResults;
        _sortBySystemRegNo(propertyBrokers);
        brokers = List<Broker>.from(propertyBrokers);
        filteredBrokers = List<Broker>.from(brokers); // 초기에는 정렬 반영된 전체
        isLoading = false;
        _resetPagination();
      });
    } catch (e) {
      if (!mounted) return; // 위젯이 dispose된 경우 setState 호출 방지

      setState(() {
        error = '공인중개사 정보를 불러오는 중 오류가 발생했습니다.';
        isLoading = false;
      });
    }
  }
  
  /// 필터링 적용
  void _applyFilters() {
    setState(() {
      filteredBrokers = brokers.where((broker) {
        // 검색어 필터
        if (searchKeyword.isNotEmpty) {
          final keyword = searchKeyword.toLowerCase();
          final name = broker.name.toLowerCase();
          final road = broker.roadAddress.toLowerCase();
          final jibun = broker.jibunAddress.toLowerCase();
          
          if (!name.contains(keyword) && 
              !road.contains(keyword) && 
              !jibun.contains(keyword)) {
            return false;
          }
        }
        
        // 전화번호 필터
        if (showOnlyWithPhone) {
          if (broker.phoneNumber == null || 
              broker.phoneNumber!.isEmpty || 
              broker.phoneNumber == '-') {
            return false;
          }
        }
        
        // 영업상태 필터
        if (showOnlyOpen) {
          if (broker.businessStatus == null || 
              broker.businessStatus != '영업중') {
            return false;
          }
        }
        
        return true;
      }).toList();
      _sortBySystemRegNo(filteredBrokers);
      _resetPagination();
    });
  }

  // 시스템등록번호 기준 정렬 (오름차순, null은 후순위)
  void _sortBySystemRegNo(List<Broker> list) {
    int? toNumeric(String? s) {
      if (s == null) return null;
      final digits = s.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.isEmpty) return null;
      return int.tryParse(digits);
    }
    list.sort((a, b) {
      final an = toNumeric(a.systemRegNo);
      final bn = toNumeric(b.systemRegNo);
      if (an == null && bn == null) return 1; // 둘 다 없으면 상대적 순서 유지에 가깝게
      if (an == null) return 1; // a가 null이면 뒤로
      if (bn == null) return -1; // b가 null이면 뒤로
      return an.compareTo(bn);
    });
  }

  // 페이지네이션 유틸
  List<Broker> _visiblePage() {
    final start = _currentPage * _pageSize;
    if (start >= filteredBrokers.length) return const [];
    final end = start + _pageSize;
    return filteredBrokers.sublist(start, end > filteredBrokers.length ? filteredBrokers.length : end);
  }

  int get _totalPages => (filteredBrokers.isEmpty) ? 1 : ((filteredBrokers.length + _pageSize - 1) ~/ _pageSize);

  void _resetPagination() {
    _currentPage = 0;
  }

  @override
  Widget build(BuildContext context) {
    // 웹 최적화: 최대 너비 제한
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = screenWidth > 800;
    final maxWidth = isWeb ? 900.0 : screenWidth;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          // 웹 스타일 헤더
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: Colors.white,
            foregroundColor: AppColors.kPrimary,
            elevation: 0,
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
              ],
            ),
            leadingWidth: 56,
            title: const HomeLogoButton(fontSize: 18),
            centerTitle: false,
            actions: [
              // 로그인 버튼 (비로그인 상태)
              if (widget.userName.isEmpty)
                IconButton(
                  icon: const Icon(Icons.login, color: Colors.white),
                  tooltip: '로그인',
                  onPressed: () async {
                    print('🔐 [BrokerListPage] 상단 로그인 버튼 클릭');
                    // 로그인 페이지로 이동
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginPage()),
                    );
                    
                    print('🔙 [BrokerListPage] 로그인 페이지에서 돌아옴');
                    print('   result: $result');
                    
                    // 로그인 성공 시 - 공인중개사 페이지를 새로운 userName으로 다시 열기
                    if (mounted && result is Map &&
                        ((result['userName'] is String && (result['userName'] as String).isNotEmpty) ||
                         (result['userId'] is String && (result['userId'] as String).isNotEmpty))) {
                      // ✅ 안전하게 사용자명 계산
                      final String userName = (result['userName'] is String && (result['userName'] as String).isNotEmpty)
                          ? result['userName']
                          : result['userId'];
                      final String userId = (result['userId'] is String) ? result['userId'] as String : '';
                      
                      print('✅ [BrokerListPage] 로그인 성공!');
                      print('   UserName: $userName');
                      
                      // 현재 페이지를 닫고
                      Navigator.pop(context);
                      
                      // 새로운 userName으로 공인중개사 페이지 다시 열기
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BrokerListPage(
                            address: widget.address,
                            latitude: widget.latitude,
                            longitude: widget.longitude,
                            userName: userName, // 로그인된 사용자
                            userId: userId,
                            propertyArea: widget.propertyArea,
                          ),
                        ),
                      );
                    } else {
                      print('⚠️ [BrokerListPage] 로그인 취소 또는 실패');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('로그인에 실패했습니다. 이메일/비밀번호를 확인해주세요.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                ),
              // 견적문의 내역 버튼 (로그인 상태)
              if (widget.userName.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.history, color: Colors.white),
                  tooltip: '내 문의 내역',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => QuoteHistoryPage(userName: widget.userName),
                      ),
                    );
                  },
                ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.kPrimary, AppColors.kSecondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Container(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 40),
                        const Row(
                          children: [
                            Icon(Icons.business, color: Colors.white, size: 40),
                            SizedBox(width: 16),
                            Text(
                              '주변 공인중개사 찾기',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '선택한 주소 주변의 공인중개사 정보를 확인하세요',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 컨텐츠
          SliverToBoxAdapter(
            child: Center(
              child: Container(
                constraints: BoxConstraints(maxWidth: maxWidth),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 주소 요약 카드 - 웹 스타일
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.grey.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [AppColors.kPrimary, AppColors.kSecondary],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Text(
                                  '검색 기준 주소',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2C3E50),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.kPrimary.withValues(alpha: 0.1),
                                  AppColors.kSecondary.withValues(alpha: 0.1),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.kPrimary.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.address,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.kPrimary,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.my_location,
                                      size: 16,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '좌표: ${widget.latitude.toStringAsFixed(6)}, ${widget.longitude.toStringAsFixed(6)}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // 공인중개사 목록 헤더 - 웹 스타일
                    if (!isLoading && brokers.isNotEmpty) ...[
                      // 검색 및 필터 UI
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 헤더
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.kSecondary, // 남색 단색
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.business, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                        '공인중개사 ${filteredBrokers.length}곳',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                                if (filteredBrokers.length < brokers.length) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '/ 전체 ${brokers.length}곳',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // 검색창
                            TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: '중개사명, 주소로 검색',
                                prefixIcon: const Icon(Icons.search, color: AppColors.kPrimary),
                                suffixIcon: searchKeyword.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 20),
                                        onPressed: () {
                                          _searchController.clear();
                                          searchKeyword = '';
                                          _applyFilters();
                                        },
                                      )
                                    : null,
                                filled: true,
                                fillColor: Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppColors.kPrimary, width: 2),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                              onChanged: (value) {
                                searchKeyword = value;
                                _applyFilters();
                              },
                            ),
                            
                            const SizedBox(height: 12),
                            
                            // 필터 버튼들
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilterChip(
                                  label: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.phone, size: 16),
                                      SizedBox(width: 4),
                                      Text('전화번호 있음'),
                                    ],
                                  ),
                                  selected: showOnlyWithPhone,
                                  onSelected: (selected) {
                                    setState(() {
                                      showOnlyWithPhone = selected;
                                      _applyFilters();
                                    });
                                  },
                                  selectedColor: AppColors.kPrimary.withValues(alpha: 0.2),
                                  checkmarkColor: AppColors.kPrimary,
                                  backgroundColor: Colors.grey[100],
                                  labelStyle: TextStyle(
                                    color: showOnlyWithPhone ? AppColors.kPrimary : Colors.grey[700],
                                    fontWeight: showOnlyWithPhone ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                FilterChip(
                                  label: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle, size: 16),
                                      SizedBox(width: 4),
                                      Text('영업중'),
                                    ],
                                  ),
                                  selected: showOnlyOpen,
                                  onSelected: (selected) {
                                    setState(() {
                                      showOnlyOpen = selected;
                                      _applyFilters();
                                    });
                                  },
                                  selectedColor: Colors.green.withValues(alpha: 0.2),
                                  checkmarkColor: Colors.green,
                                  backgroundColor: Colors.grey[100],
                                  labelStyle: TextStyle(
                                    color: showOnlyOpen ? Colors.green[700] : Colors.grey[700],
                                    fontWeight: showOnlyOpen ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                if (showOnlyWithPhone || showOnlyOpen || searchKeyword.isNotEmpty)
                                  ActionChip(
                                    label: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.refresh, size: 16),
                                        SizedBox(width: 4),
                                        Text('초기화'),
                                      ],
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        showOnlyWithPhone = false;
                                        showOnlyOpen = false;
                                        searchKeyword = '';
                                        _searchController.clear();
                                        _applyFilters();
                                      });
                                    },
                                    backgroundColor: Colors.orange[100],
                                    labelStyle: TextStyle(
                                      color: Colors.orange[700],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    // 탭 전환: 선택된 주소 주변 / 자주 가는 위치 주변
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        labelColor: AppColors.kPrimary,
                        unselectedLabelColor: Colors.grey[700],
                        indicatorColor: AppColors.kPrimary,
        tabs: [
          const Tab(icon: Icon(Icons.my_location), text: '선택된 주소 주변'),
          if (_isLoggedIn)
            const Tab(icon: Icon(Icons.place), text: '자주 가는 위치 주변'),
        ],
                      ),
                    ),
                    const SizedBox(height: 16),
    if (_isLoggedIn && _tabController.index == 1)
                      Builder(
                        builder: (context) {
                          if (isFrequentLoading) {
                            return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
                          }
                          if (frequentError != null) {
                            return _buildErrorCard(frequentError!);
                          }
                          if (frequentBrokers.isEmpty) {
                            return _buildNoResultsCard(message: '자주 가는 위치 주변 결과가 없습니다.');
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],

                    // 로딩 / 에러 / 결과 표시
                    if (isLoading)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(60),
                          child: const CircularProgressIndicator(
                            strokeWidth: 3,
                          ),
                        ),
                      )
                    else if (error != null)
                      _buildErrorCard(error!)
                    else if (brokers.isEmpty)
                        _buildNoResultsCard()
                      else if (filteredBrokers.isEmpty)
                        _buildNoFilterResultsCard()
                      else ...[
                        // 웹 그리드 레이아웃 (페이지네이션 적용)
                        _buildBrokerGrid(isWeb, _visiblePage()),
                        const SizedBox(height: 16),
                        _buildPaginationControls(),
                      ],

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 웹 최적화 그리드 레이아웃
  Widget _buildBrokerGrid(bool isWeb, List<Broker> pageItems) {
    final crossAxisCount = isWeb ? 2 : 1;
    return MasonryGridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: 20,
      crossAxisSpacing: 20,
      itemCount: pageItems.length,
      itemBuilder: (context, index) {
        final card = _buildBrokerCard(pageItems[index]);
        return ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 400.0),
          child: card,
        );
      },
    );
  }

  Widget _buildPaginationControls() {
    if (filteredBrokers.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        OutlinedButton(
          onPressed: _currentPage > 0
              ? () => setState(() => _currentPage -= 1)
              : null,
          child: const Text('이전'),
        ),
        const SizedBox(width: 12),
        Text('${_currentPage + 1} / $_totalPages', style: TextStyle(color: Colors.grey[700]!, fontWeight: FontWeight.w600)),
        const SizedBox(width: 12),
        OutlinedButton(
          onPressed: (_currentPage < _totalPages - 1)
              ? () => setState(() => _currentPage += 1)
              : null,
          child: const Text('다음'),
        ),
      ],
    );
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  // FIXME
  // 1. 낮은 해상도에서 Column 이 너무 작아져서 카드가 깨지는 현상
  // 2. 높은 Width 에서 백색 Spacing 이 비대해지는 현상
  /// 공인중개사 카드
  Widget _buildBrokerCard(Broker broker) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppColors.kSecondary, // 남색 단색
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.business,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    broker.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (broker.distance != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      broker.distanceText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 상세 정보 - 웹 스타일
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 주소 정보 그룹
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildBrokerInfo(Icons.location_on, '도로명주소', broker.fullAddress),
                      const SizedBox(height: 12),
                      _buildBrokerInfo(Icons.pin_drop, '지번주소', broker.jibunAddress),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 기본 정보
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBrokerInfo(Icons.business_center, '사업자상호', broker.businessName),
                      const SizedBox(height: 12),
                      _buildBrokerInfo(Icons.person, '대표자명', broker.ownerName),
                      const SizedBox(height: 12),
                      _buildBrokerInfo(Icons.phone, '전화번호', broker.phoneNumber),
                      const SizedBox(height: 12),
                      _buildBrokerInfo(
                        Icons.store, 
                        '영업상태', 
                        broker.businessStatus,
                        statusColor: broker.businessStatus == '영업중' ? Colors.green[700] : Colors.orange[700],
                      ),
                      const SizedBox(height: 12),
                      _buildBrokerInfo(Icons.badge, '등록번호', broker.registrationNumber),
                      if (broker.employeeCount.isNotEmpty && broker.employeeCount != '-' && broker.employeeCount != '0') ...[
                        const SizedBox(height: 12),
                        _buildBrokerInfo(Icons.people, '고용인원', '${broker.employeeCount}명'),
                      ],
                    ],
                  ),
                ),
                
                // 행정처분 정보 (있는 경우만 표시)
                if ((broker.penaltyStartDate != null && broker.penaltyStartDate!.isNotEmpty) ||
                    (broker.penaltyEndDate != null && broker.penaltyEndDate!.isNotEmpty)) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 18),
                            const SizedBox(width: 8),
                            Text(
                              '행정처분 이력',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.orange[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (broker.penaltyStartDate != null && broker.penaltyStartDate!.isNotEmpty)
                          _buildInfoRow('처분 시작일', broker.penaltyStartDate!),
                        if (broker.penaltyEndDate != null && broker.penaltyEndDate!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _buildInfoRow('처분 종료일', broker.penaltyEndDate!),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 액션 버튼들 - 웹 스타일
          Container(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Colors.grey.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Column(
                children: [
                  // 첫 번째 줄: 길찾기
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _findRoute(broker.roadAddress),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.kPrimary,
                        side: const BorderSide(color: AppColors.kPrimary, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.map, size: 20),
                      label: const Text('길찾기', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // 두 번째 줄: 전화문의, 비대면문의
                  Row(
                    children: [
                      // 전화문의 버튼
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _makePhoneCall(broker),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[600],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                            shadowColor: Colors.green.withValues(alpha: 0.3),
                          ),
                          icon: const Icon(Icons.phone, size: 20),
                          label: const Text('전화문의', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      
                  const SizedBox(width: 12),
                      
                      // 비대면 문의 버튼
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // 로그인 체크
                        if (widget.userName.isEmpty) {
                              _showLoginRequiredDialog(broker);
                          return;
                        }
                            _requestQuote(broker);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.kPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                        shadowColor: AppColors.kPrimary.withValues(alpha: 0.3),
                      ),
                      icon: const Icon(Icons.chat_bubble, size: 20),
                          label: const Text('비대면문의', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 간단한 정보 행 (행정처분 등에 사용)
  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF2C3E50),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  /// 공인중개사 정보 행 - 웹 스타일
  Widget _buildBrokerInfo(
    IconData icon, 
    String label, 
    String? value, 
    {Color? statusColor}
  ) {
    final displayValue = value != null && value.isNotEmpty ? value : '-';
    final valueColor = statusColor ?? const Color(0xFF2C3E50);
    final iconColor = statusColor ?? AppColors.kPrimary;
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ),
        Expanded(
          child: Text(
            displayValue,
            style: TextStyle(
              fontSize: 13,
              color: valueColor,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  /// 에러 카드 - 웹 스타일
  Widget _buildErrorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline, color: Colors.orange, size: 48),
            ),
            const SizedBox(height: 20),
            Text(
              '오류 발생',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[700],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// 결과 없음 카드 - 웹 스타일
  Widget _buildNoResultsCard({String message = '공인중개사를 찾을 수 없습니다'}) {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off, size: 64, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '주변에 등록된 공인중개사가 없습니다.\n검색 반경을 넓혀보세요.',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// 필터 결과 없음 카드
  Widget _buildNoFilterResultsCard() {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.filter_alt_off, size: 64, color: Colors.orange),
            ),
            const SizedBox(height: 24),
            const Text(
              '검색 조건에 맞는 중개사가 없습니다',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '필터를 초기화하거나 검색 조건을 변경해보세요.',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  showOnlyWithPhone = false;
                  showOnlyOpen = false;
                  searchKeyword = '';
                  _searchController.clear();
                  _applyFilters();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text('필터 초기화', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  /// 길찾기 (카카오맵/네이버맵/구글맵 선택)
  void _findRoute(String address) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.map, color: AppColors.kPrimary, size: 28),
            SizedBox(width: 12),
            Text('길찾기', style: TextStyle(fontSize: 20)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '목적지',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              address,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.kPrimary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '지도 앱을 선택하세요',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            
            // 카카오맵
            _buildMapButton(
              icon: Icons.map,
              label: '카카오맵',
              color: const Color(0xFFFEE500),
              textColor: Colors.black87,
              onPressed: () {
                Navigator.pop(context);
                _launchKakaoMap(address);
              },
            ),
            const SizedBox(height: 8),
            
            // 네이버 지도
            _buildMapButton(
              icon: Icons.navigation,
              label: '네이버 지도',
              color: const Color(0xFF03C75A),
              textColor: Colors.white,
              onPressed: () {
                Navigator.pop(context);
                _launchNaverMap(address);
              },
            ),
            const SizedBox(height: 8),
            
            // 구글 지도
            _buildMapButton(
              icon: Icons.place,
              label: '구글 지도',
              color: const Color(0xFF4285F4),
              textColor: Colors.white,
              onPressed: () {
                Navigator.pop(context);
                _launchGoogleMap(address);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(fontSize: 15)),
          ),
        ],
      ),
    );
  }

  /// 지도 앱 버튼 위젯
  Widget _buildMapButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color textColor,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 1,
        ),
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
  
  /// 카카오맵 열기
  Future<void> _launchKakaoMap(String address) async {
    final encodedAddress = Uri.encodeComponent(address);
    final kakaoUrl = Uri.parse('kakaomap://search?q=$encodedAddress');
    final webUrl = Uri.parse('https://map.kakao.com/link/search/$encodedAddress');
    
    try {
      // 앱이 설치되어 있으면 앱 실행
      if (await canLaunchUrl(kakaoUrl)) {
        await launchUrl(kakaoUrl, mode: LaunchMode.externalApplication);
        print('✅ 카카오맵 앱 실행: $address');
      } else {
        // 앱이 없으면 웹 버전 실행
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
        print('✅ 카카오맵 웹 실행: $address');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('카카오맵 실행 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('❌ 카카오맵 실행 오류: $e');
    }
  }
  
  /// 네이버 지도 열기
  Future<void> _launchNaverMap(String address) async {
    final encodedAddress = Uri.encodeComponent(address);
    final naverUrl = Uri.parse('nmap://search?query=$encodedAddress');
    final webUrl = Uri.parse('https://map.naver.com/v5/search/$encodedAddress');
    
    try {
      // 앱이 설치되어 있으면 앱 실행
      if (await canLaunchUrl(naverUrl)) {
        await launchUrl(naverUrl, mode: LaunchMode.externalApplication);
        print('✅ 네이버 지도 앱 실행: $address');
      } else {
        // 앱이 없으면 웹 버전 실행
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
        print('✅ 네이버 지도 웹 실행: $address');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('네이버 지도 실행 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('❌ 네이버 지도 실행 오류: $e');
    }
  }
  
  /// 구글 지도 열기
  Future<void> _launchGoogleMap(String address) async {
    final encodedAddress = Uri.encodeComponent(address);
    final googleUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encodedAddress');
    
    try {
      await launchUrl(googleUrl, mode: LaunchMode.externalApplication);
      print('✅ 구글 지도 실행: $address');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('구글 지도 실행 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('❌ 구글 지도 실행 오류: $e');
    }
  }

  /// 전화 문의
  void _makePhoneCall(Broker broker) {
    // 전화번호 확인
    final phoneNumber = broker.phoneNumber?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
    
    if (phoneNumber.isEmpty || phoneNumber == '-') {
    showDialog(
      context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.orange, size: 28),
              SizedBox(width: 12),
              Text('전화번호 없음', style: TextStyle(fontSize: 20)),
            ],
          ),
          content: Text(
            '${broker.name}의 전화번호 정보가 없습니다.\n비대면 문의를 이용해주세요.',
            style: const TextStyle(fontSize: 15, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인', style: TextStyle(fontSize: 15)),
            ),
          ],
        ),
      );
      return;
    }
    
    // 전화 걸기 확인 다이얼로그
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.phone, color: Colors.green, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('전화 문의', style: TextStyle(fontSize: 20)),
          ],
        ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
              broker.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.phone, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                Text(
                    broker.phoneNumber ?? '',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '전화를 걸어 직접 문의하시겠습니까?',
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(fontSize: 15)),
            ),
          ElevatedButton.icon(
              onPressed: () async {
              Navigator.pop(context);
              
              // 전화 걸기
              final telUri = Uri(scheme: 'tel', path: phoneNumber);
              
              try {
                if (await canLaunchUrl(telUri)) {
                  await launchUrl(telUri);
                  print('📞 전화 걸기 성공: ${broker.phoneNumber}');
                } else {
                  // 전화 걸기를 지원하지 않는 환경 (웹 등)
                  if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('📞 ${broker.phoneNumber}\n\n위 번호로 직접 전화해주세요.'),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 4),
                        action: SnackBarAction(
                          label: '복사',
                          textColor: Colors.white,
                          onPressed: () {
                            // TODO: 클립보드 복사 기능
                          },
                        ),
                      ),
                    );
                  }
                  print('⚠️ 전화 걸기 미지원 환경: ${broker.phoneNumber}');
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('전화 걸기 실패: $e'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
                print('❌ 전화 걸기 오류: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            icon: const Icon(Icons.phone, size: 18),
            label: const Text('전화 걸기', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  /// 로그인 필요 다이얼로그
  void _showLoginRequiredDialog(Broker broker) async {
    final shouldLogin = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_outline, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('로그인 필요', style: TextStyle(fontSize: 20)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '비대면 문의는 로그인 후 이용 가능합니다.',
              style: TextStyle(fontSize: 15, height: 1.5),
            ),
            SizedBox(height: 12),
            Text(
              '우측 상단의 로그인 버튼을 눌러주세요.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소', style: TextStyle(fontSize: 15)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.kPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            icon: const Icon(Icons.login, size: 18),
            label: const Text('로그인하러 가기', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    
    // 로그인하러 가기를 선택한 경우
    if (shouldLogin == true && mounted) {
      print('🔐 [BrokerListPage] 비대면 문의 - 로그인 다이얼로그에서 로그인 선택');
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
      
      print('🔙 [BrokerListPage] 로그인 페이지에서 돌아옴');
      print('   result: $result');
      
      // 로그인 성공 시 - 공인중개사 페이지를 새로운 userName으로 다시 열기
      if (mounted && result is Map &&
          ((result['userName'] is String && (result['userName'] as String).isNotEmpty) ||
           (result['userId'] is String && (result['userId'] as String).isNotEmpty))) {
        // ✅ 안전하게 사용자명 계산
        final String userName = (result['userName'] is String && (result['userName'] as String).isNotEmpty)
            ? result['userName']
            : result['userId'];
        
        print('✅ [BrokerListPage] 로그인 성공!');
        print('   UserName: $userName');
        
        // 현재 페이지를 닫고
                Navigator.pop(context);

        // 새로운 userName으로 공인중개사 페이지 다시 열기
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BrokerListPage(
              address: widget.address,
              latitude: widget.latitude,
              longitude: widget.longitude,
              userName: userName, // 로그인된 사용자
              propertyArea: widget.propertyArea,
            ),
          ),
        );
      } else {
        print('⚠️ [BrokerListPage] 로그인 취소 또는 실패');
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
  }

  /// 비대면 견적 문의 (매도자 입찰카드)
  void _requestQuote(Broker broker) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _QuoteRequestFormPage(
          broker: broker,
          userName: widget.userName,
          userId: widget.userId ?? '',
          propertyAddress: widget.address, // 조회한 주소 전달
          propertyArea: widget.propertyArea, // 토지 면적 전달
        ),
        fullscreenDialog: true,
      ),
    );
  }
}

/// 견적문의 폼 페이지 (매도자 입찰카드)
class _QuoteRequestFormPage extends StatefulWidget {
  final Broker broker;
  final String userName;
  final String userId;
  final String propertyAddress;
  final String? propertyArea;
  
  const _QuoteRequestFormPage({
    required this.broker,
    required this.userName,
    required this.userId,
    required this.propertyAddress,
    this.propertyArea,
  });
  
  @override
  State<_QuoteRequestFormPage> createState() => _QuoteRequestFormPageState();
}

class _QuoteRequestFormPageState extends State<_QuoteRequestFormPage> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseService _firebaseService = FirebaseService();
  
  // 1️⃣ 기본정보 (자동)
  String propertyType = '아파트';
  late String propertyAddress;
  late String propertyArea; // 자동 입력됨
  
  // 3️⃣ 특이사항 (판매자 입력)
  bool hasTenant = false;
  final TextEditingController _desiredPriceController = TextEditingController();
  final TextEditingController _targetPeriodController = TextEditingController();
  final TextEditingController _specialNotesController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    propertyAddress = widget.propertyAddress;
    propertyArea = widget.propertyArea ?? '정보 없음';
  }
  
  @override
  void dispose() {
    _desiredPriceController.dispose();
    _targetPeriodController.dispose();
    _specialNotesController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8EAF0), // 배경을 더 진하게
      appBar: AppBar(
        title: const AppBarTitle(title: '매도자 입찰카드'),
        backgroundColor: AppColors.kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // 제목
            const Text(
              '🏠 중개 제안 요청서',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '중개업자에게 정확한 정보를 전달하여 최적의 제안을 받으세요',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // ========== 1️⃣ 특이사항 ==========
            _buildSectionTitle('1️⃣ 특이사항', '선택 입력', Colors.orange),
            const SizedBox(height: 16),
            _buildCard([
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '세입자 여부 *',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                  ),
                  Switch(
                    value: hasTenant,
                    onChanged: (value) {
                      setState(() {
                        hasTenant = value;
                      });
                    },
                    activeColor: AppColors.kPrimary,
                  ),
                  Text(
                    hasTenant ? '있음' : '없음',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField(
                label: '희망가',
                controller: _desiredPriceController,
                hint: '예: 11억 / 협의 가능',
                keyboardType: TextInputType.text,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                label: '목표기간',
                controller: _targetPeriodController,
                hint: '예: 2~3개월 내',
                keyboardType: TextInputType.text,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                label: '특이사항 (300자 이내)',
                controller: _specialNotesController,
                hint: '기타 요청사항이나 특이사항을 입력하세요',
                maxLines: 4,
                maxLength: 300,
              ),
            ]),
            
            const SizedBox(height: 40),
            
            // 제출 버튼
            SizedBox(
              height: 60,
              child: ElevatedButton.icon(
                onPressed: _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.kPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 6, // 그림자 강화
                  shadowColor: AppColors.kPrimary.withOpacity(0.4),
                ),
                icon: const Icon(Icons.send, size: 24),
                label: const Text(
                  '중개 제안 요청하기',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
  
  /// 섹션 제목
  Widget _buildSectionTitle(String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white, // 흰색 배경으로 변경
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4), width: 2), // 테두리 강화
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15), // 색상 그림자 추가
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.info_outline,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  /// 카드
  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(24), // 패딩 증가
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!, width: 1), // 테두리 추가
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1), // 그림자 강화
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
  
  /// 텍스트 필드
  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    int? maxLength,
    String? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          maxLength: maxLength,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400]),
            suffixText: suffix,
            filled: true,
            fillColor: Colors.white, // 흰색 배경
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5), // 명확한 테두리
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5), // 기본 상태 테두리
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.kPrimary, width: 2.5), // 포커스 시 더 두껍게
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
  
  /// 제출
  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    // 견적문의 객체 생성
                final quoteRequest = QuoteRequest(
      id: '',
                  userId: widget.userId,
                  userName: widget.userName,
      userEmail: '${widget.userName}@example.com',
      brokerName: widget.broker.name,
      brokerRegistrationNumber: widget.broker.registrationNumber,
      brokerRoadAddress: widget.broker.roadAddress,
      brokerJibunAddress: widget.broker.jibunAddress,
      message: '매도자 입찰카드 제안 요청',
                  status: 'pending',
                  requestDate: DateTime.now(),
      // 1️⃣ 기본정보
      propertyType: propertyType,
      propertyAddress: propertyAddress,
      propertyArea: propertyArea != '정보 없음' ? propertyArea : null,
      // 3️⃣ 특이사항
      hasTenant: hasTenant,
      desiredPrice: _desiredPriceController.text.trim().isNotEmpty ? _desiredPriceController.text.trim() : null,
      targetPeriod: _targetPeriodController.text.trim().isNotEmpty ? _targetPeriodController.text.trim() : null,
      specialNotes: _specialNotesController.text.trim().isNotEmpty ? _specialNotesController.text.trim() : null,
    );
    
    // Firebase 저장
                final requestId = await _firebaseService.saveQuoteRequest(quoteRequest);

    if (requestId != null && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
          content: Text('${widget.broker.name}에 제안 요청이 전송되었습니다!'),
                        backgroundColor: AppColors.kSuccess,
                        duration: const Duration(seconds: 3),
                      ),
                    );
      Navigator.pop(context);
      print('✅ 매도자 입찰카드 저장 성공');
    } else if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
          content: Text('제안 요청 전송에 실패했습니다.'),
                        backgroundColor: Colors.red,
                      ),
                    );
      print('❌ 매도자 입찰카드 저장 실패');
    }
  }
}
