import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:property/constants/app_constants.dart';
import 'package:property/api_request/broker_service.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/api_request/vworld_service.dart';
import 'package:property/models/quote_request.dart';
import 'package:property/screens/quote_history_page.dart';
import 'package:property/screens/login_page.dart';

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
  
  // 정렬 상태
  String _sortOption = 'systemRegNo'; // 'systemRegNo', 'distance', 'name'
  
  // 여러 중개사 선택 기능 (MVP 핵심)
  bool _isSelectionMode = false;
  Set<String> _selectedBrokerIds = {}; // 시스템등록번호로 관리
  
  // ============================================
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
      
      // 원본 데이터는 기본 정렬로 유지 (필터링 후 선택된 정렬 옵션 적용)
      _sortBySystemRegNo(brokers);
      _applyFilters(); // 필터링 및 선택된 정렬 옵션 적용
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
          _applyFilters(); // 필터링 및 정렬 적용
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

      // ========== 테스트용 공인중개사 추가 (나중에 반드시 삭제 필요함) ==========
      final testBroker = Broker(
        name: '김이택',
        roadAddress: '서울특별시 강남구 테헤란로 123',
        jibunAddress: '서울특별시 강남구 역삼동 123-45',
        registrationNumber: '22222222222222222',
        etcAddress: '',
        employeeCount: '5',
        registrationDate: '2020-01-01',
        latitude: widget.latitude,
        longitude: widget.longitude,
        distance: 0.0,
        systemRegNo: '22222222222222222',
        phoneNumber: '02-1234-5678',
        businessStatus: '정상',
      );
      // 테스트용 Broker를 리스트 맨 앞에 추가
      searchResults.insert(0, testBroker);
      // ========== 테스트용 코드 끝 ==========

      setState(() {
        propertyBrokers = searchResults;
        _sortBySystemRegNo(propertyBrokers);
        brokers = List<Broker>.from(propertyBrokers);
        isLoading = false;
        _resetPagination();
        _applyFilters(); // 필터링 및 정렬 적용
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
      
      _applySorting(filteredBrokers);
      _resetPagination();
    });
  }

  // 정렬 적용
  void _applySorting(List<Broker> list) {
    switch (_sortOption) {
      case 'distance':
        _sortByDistance(list);
        break;
      case 'name':
        _sortByName(list);
        break;
      case 'systemRegNo':
      default:
        _sortBySystemRegNo(list);
        break;
    }
  }

  // 거리순 정렬 (가까운 순서)
  void _sortByDistance(List<Broker> list) {
    list.sort((a, b) {
      if (a.distance == null && b.distance == null) return 0;
      if (a.distance == null) return 1;
      if (b.distance == null) return -1;
      return a.distance!.compareTo(b.distance!);
    });
  }

  // 이름순 정렬 (가나다 순)
  void _sortByName(List<Broker> list) {
    list.sort((a, b) {
      final nameA = a.name.trim();
      final nameB = b.name.trim();
      if (nameA.isEmpty && nameB.isEmpty) return 0;
      if (nameA.isEmpty) return 1;
      if (nameB.isEmpty) return -1;
      return nameA.compareTo(nameB);
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

  int get _totalPages {
    if (filteredBrokers.isEmpty) return 1;
    return ((filteredBrokers.length + _pageSize - 1) ~/ _pageSize);
  }

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
      // 선택 모드일 때 하단 고정 버튼 (MVP 핵심 - 매우 눈에 띄게)
      floatingActionButton: _isSelectionMode && widget.userName.isNotEmpty && _selectedBrokerIds.isNotEmpty
          ? Container(
              margin: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.kPrimary.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _requestQuoteToMultiple,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.kPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0, // Container의 shadow 사용
                ),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.send, size: 28),
                ),
                label: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_selectedBrokerIds.length}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      '곳에 일괄 견적 요청하기',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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
            actions: [
              // 로그인 상태일 때: 상위 10개 일괄 견적 요청 + 일괄 견적 요청 + 내 문의 내역 버튼
              if (widget.userName.isNotEmpty) ...[
                // 상위 10개 일괄 견적 요청 버튼
                if (filteredBrokers.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: ElevatedButton(
                      onPressed: () {
                        _requestQuoteToTop10();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.kPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text(
                        '상위 10개 일괄 요청',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                // 내 문의 내역 버튼 (일괄견적요청과 통일된 디자인)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => QuoteHistoryPage(
                            userName: widget.userName,
                            userId: widget.userId, // userId 전달
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.kPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    icon: const Icon(
                      Icons.history,
                      size: 20,
                    ),
                    label: const Text(
                      '내 문의 내역',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                // 일괄 견적 요청 버튼
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isSelectionMode = !_isSelectionMode;
                        if (!_isSelectionMode) {
                          _selectedBrokerIds.clear();
                        }
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isSelectionMode ? Colors.red : Colors.white,
                      foregroundColor: _isSelectionMode ? Colors.white : AppColors.kPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    icon: Icon(
                      _isSelectionMode ? Icons.close : Icons.checklist,
                      size: 20,
                    ),
                    label: Text(
                      _isSelectionMode ? '선택 모드 종료' : '일괄 견적 요청',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
              // 로그인 버튼 (비로그인 상태)
              if (widget.userName.isEmpty)
                IconButton(
                  icon: const Icon(Icons.login, color: Colors.white),
                  tooltip: '로그인',
                  onPressed: () async {
                    // 로그인 페이지로 이동
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginPage()),
                    );
                    
                    // 사용자가 뒤로가기로 취소한 경우 (result가 null)
                    if (result == null) {
                      // 취소한 경우는 아무 메시지도 표시하지 않음
                      return;
                    }
                    
                    // 로그인 성공 시 - 공인중개사 페이지를 새로운 userName으로 다시 열기
                    if (mounted && result is Map &&
                        ((result['userName'] is String && (result['userName'] as String).isNotEmpty) ||
                         (result['userId'] is String && (result['userId'] as String).isNotEmpty))) {
                      // ✅ 안전하게 사용자명 계산
                      final String userName = (result['userName'] is String && (result['userName'] as String).isNotEmpty)
                          ? result['userName']
                          : result['userId'];
                      final String userId = (result['userId'] is String) ? result['userId'] as String : '';
                      
                      
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
                            userId: userId.isNotEmpty ? userId : null, // userId 전달
                            propertyArea: widget.propertyArea,
                          ),
                        ),
                      );
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
                    // 주소 요약 카드 + 탭 통합 - 웹 스타일
                    Container(
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
                          // 주소 정보 섹션
                          Padding(
                            padding: const EdgeInsets.all(24),
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
                          
                          // 탭 바 섹션
                          Container(
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: Colors.grey.withValues(alpha: 0.15),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Center(
                                child: TabBar(
                                  controller: _tabController,
                                  labelColor: AppColors.kPrimary,
                                  unselectedLabelColor: Colors.grey[700],
                                  indicatorColor: AppColors.kPrimary,
                                  isScrollable: false,
                                  tabs: [
                                    const Tab(icon: Icon(Icons.my_location), text: '선택된 주소 주변'),
                                    if (_isLoggedIn)
                                      const Tab(icon: Icon(Icons.place), text: '자주 가는 위치 주변'),
                                  ],
                                ),
                              ),
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
                            
                            // 정렬 옵션
                            Row(
                              children: [
                                Text(
                                  '정렬:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      ChoiceChip(
                                        label: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.numbers, size: 16),
                                            SizedBox(width: 4),
                                            Text('등록번호순'),
                                          ],
                                        ),
                                        selected: _sortOption == 'systemRegNo',
                                        onSelected: (selected) {
                                          if (selected) {
                                            setState(() {
                                              _sortOption = 'systemRegNo';
                                              _applyFilters();
                                            });
                                          }
                                        },
                                        selectedColor: AppColors.kPrimary.withValues(alpha: 0.2),
                                        checkmarkColor: AppColors.kPrimary,
                                        backgroundColor: Colors.grey[100],
                                        labelStyle: TextStyle(
                                          color: _sortOption == 'systemRegNo' ? AppColors.kPrimary : Colors.grey[700],
                                          fontWeight: _sortOption == 'systemRegNo' ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                      ChoiceChip(
                                        label: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.near_me, size: 16),
                                            SizedBox(width: 4),
                                            Text('거리순'),
                                          ],
                                        ),
                                        selected: _sortOption == 'distance',
                                        onSelected: (selected) {
                                          if (selected) {
                                            setState(() {
                                              _sortOption = 'distance';
                                              _applyFilters();
                                            });
                                          }
                                        },
                                        selectedColor: AppColors.kPrimary.withValues(alpha: 0.2),
                                        checkmarkColor: AppColors.kPrimary,
                                        backgroundColor: Colors.grey[100],
                                        labelStyle: TextStyle(
                                          color: _sortOption == 'distance' ? AppColors.kPrimary : Colors.grey[700],
                                          fontWeight: _sortOption == 'distance' ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                      ChoiceChip(
                                        label: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.sort_by_alpha, size: 16),
                                            SizedBox(width: 4),
                                            Text('이름순'),
                                          ],
                                        ),
                                        selected: _sortOption == 'name',
                                        onSelected: (selected) {
                                          if (selected) {
                                            setState(() {
                                              _sortOption = 'name';
                                              _applyFilters();
                                            });
                                          }
                                        },
                                        selectedColor: AppColors.kPrimary.withValues(alpha: 0.2),
                                        checkmarkColor: AppColors.kPrimary,
                                        backgroundColor: Colors.grey[100],
                                        labelStyle: TextStyle(
                                          color: _sortOption == 'name' ? AppColors.kPrimary : Colors.grey[700],
                                          fontWeight: _sortOption == 'name' ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
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
                // 선택 모드일 때 체크박스
                if (_isSelectionMode && widget.userName.isNotEmpty) ...[
                  // 선택 모드일 때 더 눈에 띄는 체크박스
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _selectedBrokerIds.contains(broker.systemRegNo)
                          ? AppColors.kPrimary
                          : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _selectedBrokerIds.contains(broker.systemRegNo)
                            ? AppColors.kPrimary
                            : Colors.grey[400]!,
                        width: 3,
                      ),
                      boxShadow: _selectedBrokerIds.contains(broker.systemRegNo)
                          ? [
                              BoxShadow(
                                color: AppColors.kPrimary.withValues(alpha: 0.4),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: Checkbox(
                      value: _selectedBrokerIds.contains(broker.systemRegNo),
                      onChanged: (selected) {
                        setState(() {
                          if (selected == true) {
                            _selectedBrokerIds.add(broker.systemRegNo ?? '');
                          } else {
                            _selectedBrokerIds.remove(broker.systemRegNo);
                          }
                        });
                      },
                      checkColor: Colors.white,
                      fillColor: WidgetStateProperty.resolveWith<Color>((states) {
                        if (states.contains(WidgetState.selected)) {
                          return Colors.white;
                        }
                        return Colors.transparent;
                      }),
                      side: const BorderSide(color: Colors.white, width: 2),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
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

          // 액션 버튼들 - 웹 스타일 (선택 모드가 아닐 때만 표시)
          if (!_isSelectionMode || widget.userName.isEmpty)
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
      } else {
        // 앱이 없으면 웹 버전 실행
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
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
      } else {
        // 앱이 없으면 웹 버전 실행
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
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
    }
  }
  
  /// 구글 지도 열기
  Future<void> _launchGoogleMap(String address) async {
    final encodedAddress = Uri.encodeComponent(address);
    final googleUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encodedAddress');
    
    try {
      await launchUrl(googleUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('구글 지도 실행 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: broker.phoneNumber ?? ''));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('전화번호가 클립보드에 복사되었습니다.'),
                                  backgroundColor: Colors.blue,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    );
                  }
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
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
      
      // 사용자가 뒤로가기로 취소한 경우 (result가 null)
      if (result == null) {
        // 취소한 경우는 아무 메시지도 표시하지 않음
        return;
      }
      
      // 로그인 성공 시 - 공인중개사 페이지를 새로운 userName으로 다시 열기
      if (mounted && result is Map &&
          ((result['userName'] is String && (result['userName'] as String).isNotEmpty) ||
           (result['userId'] is String && (result['userId'] as String).isNotEmpty))) {
        // ✅ 안전하게 사용자명 계산
        final String userName = (result['userName'] is String && (result['userName'] as String).isNotEmpty)
            ? result['userName']
            : result['userId'];
        
        
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
              userId: result['userId'] as String?, // userId도 전달
              propertyArea: widget.propertyArea,
            ),
          ),
        );
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
  
  /// 상위 10개 공인중개사에게 원버튼 일괄 견적 요청
  /// 사용자에게 보여진 리스트(filteredBrokers)에서 현재 정렬 기준의 상위 10개를 자동 선택
  Future<void> _requestQuoteToTop10() async {
    if (filteredBrokers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('견적을 요청할 공인중개사가 없습니다.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // 사용자에게 보여진 리스트(filteredBrokers)에서 상위 10개 자동 선택
    // filteredBrokers는 이미 선택된 정렬 옵션에 따라 정렬되어 있음
    final top10Brokers = filteredBrokers.take(10).toList();
    
    // 일괄 견적 요청 다이얼로그 표시
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _MultipleQuoteRequestDialog(
        brokerCount: top10Brokers.length,
        address: widget.address,
        propertyArea: widget.propertyArea,
      ),
    );
    
    if (result == null) return; // 취소됨
    
    // 상위 10개 중개사에게 동일한 정보로 견적 요청
    int successCount = 0;
    int failCount = 0;
    
    // userId가 없거나 빈 문자열이면 userName 사용
    final effectiveUserId = (widget.userId?.isNotEmpty == true) ? widget.userId! : widget.userName;
    
    for (final broker in top10Brokers) {
      try {
        final quoteRequest = QuoteRequest(
          id: '',
          userId: effectiveUserId,
          userName: widget.userName,
          userEmail: '${widget.userName}@example.com',
          brokerName: broker.name,
          brokerRegistrationNumber: broker.registrationNumber,
          brokerRoadAddress: broker.roadAddress,
          brokerJibunAddress: broker.jibunAddress,
          message: '매도자 입찰카드 제안 요청',
          status: 'pending',
          requestDate: DateTime.now(),
          propertyType: result['propertyType'],
          propertyAddress: widget.address,
          propertyArea: result['propertyArea'],
          hasTenant: result['hasTenant'] as bool?,
          desiredPrice: result['desiredPrice'] as String?,
          targetPeriod: result['targetPeriod'] as String?,
          specialNotes: result['specialNotes'] as String?,
        );
        
        final requestId = await _firebaseService.saveQuoteRequest(quoteRequest);
        if (requestId != null) {
          successCount++;
        } else {
          failCount++;
        }
      } catch (e) {
        failCount++;
      }
    }
    
    if (mounted) {
      // 결과 메시지
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '상위 ${top10Brokers.length}개 공인중개사에게 견적 요청 완료${failCount > 0 ? " (${failCount}곳 실패)" : ""}',
          ),
          backgroundColor: failCount > 0 ? Colors.orange : AppColors.kSuccess,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
  
  /// 여러 공인중개사에게 일괄 견적 요청 (MVP 핵심 기능)
  Future<void> _requestQuoteToMultiple() async {
    if (_selectedBrokerIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('견적을 요청할 공인중개사를 선택해주세요.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // 선택한 중개사 목록 가져오기
    final selectedBrokers = filteredBrokers.where((broker) {
      return _selectedBrokerIds.contains(broker.systemRegNo);
    }).toList();
    
    // 일괄 견적 요청 다이얼로그 표시
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _MultipleQuoteRequestDialog(
        brokerCount: selectedBrokers.length,
        address: widget.address,
        propertyArea: widget.propertyArea,
      ),
    );
    
    if (result == null) return; // 취소됨
    
    // 선택한 모든 중개사에게 동일한 정보로 견적 요청
    int successCount = 0;
    int failCount = 0;
    
    
    // userId가 없거나 빈 문자열이면 userName 사용
    final effectiveUserId = (widget.userId?.isNotEmpty == true) ? widget.userId! : widget.userName;
    
    for (final broker in selectedBrokers) {
      try {
        
        final quoteRequest = QuoteRequest(
          id: '',
          userId: effectiveUserId, // userId가 없으면 userName 사용
          userName: widget.userName,
          userEmail: '${widget.userName}@example.com',
          brokerName: broker.name,
          brokerRegistrationNumber: broker.registrationNumber,
          brokerRoadAddress: broker.roadAddress,
          brokerJibunAddress: broker.jibunAddress,
          message: '매도자 입찰카드 제안 요청',
          status: 'pending',
          requestDate: DateTime.now(),
          propertyType: result['propertyType'],
          propertyAddress: widget.address,
          propertyArea: result['propertyArea'],
          hasTenant: result['hasTenant'] as bool?,
          desiredPrice: result['desiredPrice'] as String?,
          targetPeriod: result['targetPeriod'] as String?,
          specialNotes: result['specialNotes'] as String?,
        );
        
        
        final requestId = await _firebaseService.saveQuoteRequest(quoteRequest);
        if (requestId != null) {
          successCount++;
        } else {
          failCount++;
        }
      } catch (e) {
        failCount++;
      }
    }
    
    
    if (mounted) {
      // 선택 모드 종료
      setState(() {
        _isSelectionMode = false;
        _selectedBrokerIds.clear();
      });
      
      // 결과 메시지
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${successCount}곳에 견적 요청 완료${failCount > 0 ? " (${failCount}곳 실패)" : ""}',
          ),
          backgroundColor: failCount > 0 ? Colors.orange : AppColors.kSuccess,
          duration: const Duration(seconds: 3),
        ),
      );
    }
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
        title: const Text('매도자 입찰카드'),
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
            
            // ========== 1️⃣ 매물 정보 (자동 입력) ==========
            _buildSectionTitle('매물 정보', '자동 입력됨', Colors.blue),
            const SizedBox(height: 16),
            _buildCard([
              _buildInfoRow('주소', propertyAddress),
              if (propertyArea != '정보 없음') ...[
                const SizedBox(height: 12),
                _buildInfoRow('면적', propertyArea),
              ],
            ]),
            
            const SizedBox(height: 24),
            
            // ========== 2️⃣ 매물 유형 (필수 입력) ==========
            _buildSectionTitle('매물 유형', '필수 입력', Colors.green),
            const SizedBox(height: 16),
            _buildCard([
              DropdownButtonFormField<String>(
                value: propertyType,
                decoration: InputDecoration(
                  hintText: '매물 유형을 선택하세요',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.kPrimary, width: 2.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                items: const [
                  DropdownMenuItem(value: '아파트', child: Text('아파트')),
                  DropdownMenuItem(value: '오피스텔', child: Text('오피스텔')),
                  DropdownMenuItem(value: '원룸', child: Text('원룸')),
                  DropdownMenuItem(value: '다세대', child: Text('다세대')),
                  DropdownMenuItem(value: '주택', child: Text('주택')),
                  DropdownMenuItem(value: '상가', child: Text('상가')),
                  DropdownMenuItem(value: '기타', child: Text('기타')),
                ],
                onChanged: (value) {
                  setState(() {
                    propertyType = value ?? '아파트';
                  });
                },
              ),
            ]),
            
            const SizedBox(height: 24),
            
            // ========== 3️⃣ 특이사항 (선택 입력) ==========
            _buildSectionTitle('특이사항', '선택 입력', Colors.orange),
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
                    activeThumbColor: AppColors.kPrimary,
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
                  shadowColor: AppColors.kPrimary.withValues(alpha: 0.4),
                ),
                icon: const Icon(Icons.send, size: 24),
                label: const Text(
                  '견적 요청하기',
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
  
  // 공통 빌더 메서드 (하위 클래스에서도 사용 가능하도록 공개)
  Widget _buildSectionTitle(String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
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
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.info_outline, color: color, size: 24),
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
  
  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
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
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.kPrimary, width: 2.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF2C3E50),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
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
                  userId: widget.userId.isNotEmpty ? widget.userId : widget.userName, // userId가 없으면 userName 사용
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
    } else if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
          content: Text('제안 요청 전송에 실패했습니다.'),
                        backgroundColor: Colors.red,
                      ),
                    );
    }
  }
}

/// 여러 공인중개사에게 일괄 견적 요청 다이얼로그 (MVP 핵심 기능)
class _MultipleQuoteRequestDialog extends StatefulWidget {
  final int brokerCount;
  final String address;
  final String? propertyArea;

  const _MultipleQuoteRequestDialog({
    required this.brokerCount,
    required this.address,
    this.propertyArea,
  });

  @override
  State<_MultipleQuoteRequestDialog> createState() => _MultipleQuoteRequestDialogState();
}

class _MultipleQuoteRequestDialogState extends State<_MultipleQuoteRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _desiredPriceController = TextEditingController();
  final _targetPeriodController = TextEditingController();
  final _specialNotesController = TextEditingController();
  bool hasTenant = false;
  String? propertyType;

  @override
  void dispose() {
    _desiredPriceController.dispose();
    _targetPeriodController.dispose();
    _specialNotesController.dispose();
    super.dispose();
  }
  
  // 공통 빌더 메서드 (부모 클래스 메서드 재사용)
  Widget _buildSectionTitle(String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
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
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.info_outline, color: color, size: 24),
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
  
  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
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
  
  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    int? maxLength,
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
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.kPrimary, width: 2.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF2C3E50),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.send, color: AppColors.kPrimary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.brokerCount}곳에 견적 요청',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '선택한 공인중개사에게 동일한 정보로 견적 요청이 전송됩니다',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                
                // 매물 정보 (자동 입력) - 섹션 제목 스타일 적용
                _buildSectionTitle('매물 정보', '자동 입력됨', Colors.blue),
                const SizedBox(height: 16),
                _buildCard([
                  _buildInfoRow('주소', widget.address),
                  if (widget.propertyArea != null && widget.propertyArea != '정보 없음') ...[
                    const SizedBox(height: 12),
                    _buildInfoRow('면적', widget.propertyArea!),
                  ],
                ]),
                
                const SizedBox(height: 24),
                
                // 매물 유형
                _buildSectionTitle('매물 유형', '필수 입력', Colors.green),
                const SizedBox(height: 16),
                _buildCard([
                  DropdownButtonFormField<String>(
                    value: propertyType,
                    decoration: InputDecoration(
                      hintText: '매물 유형을 선택하세요',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.kPrimary, width: 2.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    items: const [
                      DropdownMenuItem(value: '아파트', child: Text('아파트')),
                      DropdownMenuItem(value: '오피스텔', child: Text('오피스텔')),
                      DropdownMenuItem(value: '원룸', child: Text('원룸')),
                      DropdownMenuItem(value: '다세대', child: Text('다세대')),
                      DropdownMenuItem(value: '주택', child: Text('주택')),
                      DropdownMenuItem(value: '상가', child: Text('상가')),
                      DropdownMenuItem(value: '기타', child: Text('기타')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        propertyType = value;
                      });
                    },
                  ),
                ]),
                
                const SizedBox(height: 24),
                
                // 특이사항 섹션
                _buildSectionTitle('특이사항', '선택 입력', Colors.orange),
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
                        activeThumbColor: AppColors.kPrimary,
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
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text(
            '취소',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, {
                'propertyType': propertyType,
                'propertyArea': widget.propertyArea != '정보 없음' ? widget.propertyArea : null,
                'hasTenant': hasTenant,
                'desiredPrice': _desiredPriceController.text.trim().isNotEmpty
                    ? _desiredPriceController.text.trim()
                    : null,
                'targetPeriod': _targetPeriodController.text.trim().isNotEmpty
                    ? _targetPeriodController.text.trim()
                    : null,
                'specialNotes': _specialNotesController.text.trim().isNotEmpty
                    ? _specialNotesController.text.trim()
                    : null,
              });
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.kPrimary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 6,
            shadowColor: AppColors.kPrimary.withValues(alpha: 0.4),
          ),
          icon: const Icon(Icons.send, size: 20),
          label: const Text(
            '견적 요청하기',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
