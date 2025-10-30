import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/models/property.dart';
import 'package:property/models/quote_request.dart';
import 'package:property/widgets/empty_state.dart';
import 'package:property/widgets/loading_overlay.dart';
import 'package:property/widgets/home_logo_button.dart';
import 'package:intl/intl.dart';

class HouseManagementPage extends StatefulWidget {
  final String userId;
  final String userName;

  const HouseManagementPage({
    required this.userId,
    required this.userName,
    super.key,
  });

  @override
  State<HouseManagementPage> createState() => _HouseManagementPageState();
}

class _HouseManagementPageState extends State<HouseManagementPage> with SingleTickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  List<Property> _myProperties = [];
  List<QuoteRequest> _myQuotes = [];
  bool _isLoading = true;
  
  // 탭 컨트롤러
  late TabController _tabController;
  
  // 매물 상태 필터
  String _statusFilter = '전체';
  final List<String> _statusOptions = ['전체', '임대중', '공실', '수리중', '계약만료예정'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    // 내집목록은 MVP 제외: 불필요한 로드 방지
    // _loadMyProperties();
    _loadMyQuotes();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMyProperties() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final properties = await _firebaseService.getPropertiesByUserId(widget.userId);
      
      // testcase.json 기반 샘플 데이터 추가 (실제 데이터가 없을 때)
      if (properties.isEmpty) {
        _myProperties = _getSampleProperties();
      } else {
        _myProperties = properties;
      }
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('내 집 목록 로드 오류: $e');
      // 오류 발생 시에도 샘플 데이터 표시
      _myProperties = _getSampleProperties();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _loadMyQuotes() async {
    try {
      print('📋 [내집관리] 내 요청 목록 로드 시작 - userId: ${widget.userId}');
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }
      
      // Stream으로 실시간 데이터 수신
      _firebaseService.getQuoteRequestsByUser(widget.userId).listen((quotes) {
        if (mounted) {
          setState(() {
            _myQuotes = quotes;
            _isLoading = false; // ✅ 최초/갱신 수신 시 로딩 해제
          });
          print('✅ [내집관리] 내 요청 ${quotes.length}개 로드됨');
        }
      });
    } catch (e) {
      print('❌ [내집관리] 내 요청 목록 로드 오류: $e');
      if (mounted) {
        setState(() {
          _myQuotes = [];
          _isLoading = false; // ✅ 오류 시에도 로딩 해제
        });
      }
    }
  }
  
  /// 견적문의 삭제
  Future<void> _deleteQuote(String quoteId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('삭제 확인', style: TextStyle(fontSize: 20)),
          ],
        ),
        content: const Text(
          '이 요청을 삭제하시겠습니까?\n삭제된 내역은 복구할 수 없습니다.',
          style: TextStyle(fontSize: 15, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소', style: TextStyle(fontSize: 15)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('삭제', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      final success = await _firebaseService.deleteQuoteRequest(quoteId);
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('요청이 삭제되었습니다.'),
            backgroundColor: AppColors.kSuccess,
          ),
        );
      } else if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('삭제에 실패했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Property> _getSampleProperties() {
    return [
      Property(
        address: '서울특별시 강남구 역삼동 123-45',
        transactionType: '월세',
        price: 1500,
        description: '강남역 도보 5분, 깔끔한 원룸',
        buildingName: '강남원룸타워 301호',
        buildingType: '원룸',
        totalFloors: 5,
        floor: 3,
        area: 28.5,
        structure: '철근콘크리트',
        ownerName: '김원룸',
        status: '임대중',
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        mainContractor: widget.userName,
        contractor: widget.userName,
        registeredBy: widget.userId,
        registeredByName: widget.userName,
      ),
      Property(
        address: '서울특별시 홍대입구역 456-78',
        transactionType: '월세',
        price: 1200,
        description: '홍대 근처 젊은 층 선호 원룸',
        buildingName: '홍대원룸빌 502호',
        buildingType: '원룸',
        totalFloors: 6,
        floor: 5,
        area: 25.3,
        structure: '철근콘크리트',
        ownerName: widget.userName,
        status: '임대중',
        createdAt: DateTime.now().subtract(const Duration(days: 15)),
        mainContractor: widget.userName,
        contractor: widget.userName,
        registeredBy: widget.userId,
        registeredByName: widget.userName,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      message: '내 집 정보를 불러오는 중...',
      child: Scaffold(
        appBar: AppBar(
          title: const AppBarTitle(title: '내집관리'),
          backgroundColor: AppColors.kPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            labelStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            unselectedLabelColor: Colors.white.withOpacity(0.7),
            unselectedLabelStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.normal,
            ),
            tabs: const [
              Tab(
                icon: Icon(Icons.request_quote),
                text: '내 요청',
              ),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // 내 요청 탭만 유지 (MVP)
            _buildMyRequestsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.home_work_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '등록된 집이 없습니다',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '새로운 매물을 등록해보세요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // 매물 등록 페이지로 이동
              Navigator.of(context).pushNamed('/contract-step1');
            },
            icon: const Icon(Icons.add),
            label: const Text('매물 등록하기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.kBrown,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return _buildPropertyListTab();
  }

  Widget _buildPropertyListTab() {
    final filteredProperties = _getFilteredProperties();
    
    return Column(
      children: [
        // 상단 통계 카드
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _buildStatCard('총 매물', '${_myProperties.length}', Icons.home_work, Colors.blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard('임대중', '${_myProperties.where((p) => p.status == '임대중').length}', Icons.check_circle, Colors.green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard('공실', '${_myProperties.where((p) => p.status == '공실').length}', Icons.cancel, Colors.red),
              ),
            ],
          ),
        ),
        
        // 필터 섹션
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Text('상태 필터:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _statusOptions.map((status) => 
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(status),
                          selected: _statusFilter == status,
                          onSelected: (selected) {
                            setState(() {
                              _statusFilter = status;
                            });
                          },
                          selectedColor: AppColors.kBrown.withValues(alpha:0.3),
                          checkmarkColor: AppColors.kBrown,
                        ),
                      ),
                    ).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // 매물 목록
        Expanded(
          child: filteredProperties.isEmpty 
            ? _buildNoPropertiesMessage()
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filteredProperties.length,
                itemBuilder: (context, index) {
                  final property = filteredProperties[index];
                  return _buildPropertyCard(property);
                },
              ),
        ),
      ],
    );
  }

  Widget _buildRentalManagementTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 임대 현황 요약
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.assignment, color: AppColors.kBrown),
                      SizedBox(width: 8),
                      Text(
                        '임대 현황 요약',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.kBrown,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildRentalStatCard('월 임대료 수입', '1,500만원', Icons.attach_money, Colors.green),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildRentalStatCard('임대율', '75%', Icons.pie_chart, Colors.blue),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 임대인 관리
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.people, color: AppColors.kBrown),
                      const SizedBox(width: 8),
                      const Text(
                        '임대인 관리',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.kBrown,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _showAddTenantDialog,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('임대인 추가'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTenantList(),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 계약 관리
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.description, color: AppColors.kBrown),
                      SizedBox(width: 8),
                      Text(
                        '계약 관리',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.kBrown,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildContractList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 수리 요청 카드
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.build_rounded, color: AppColors.kBrown),
                      SizedBox(width: 8),
                      Text(
                        '수리 요청',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '매물의 수리가 필요하신가요?',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _showRepairRequestDialog();
                      },
                      icon: const Icon(Icons.build_rounded),
                      label: const Text('수리 요청하기'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.kBrown,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 수리 내역 카드
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.history_rounded, color: AppColors.kBrown),
                      SizedBox(width: 8),
                      Text(
                        '수리 내역',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildRepairHistoryList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 필터링된 매물 목록 반환
  List<Property> _getFilteredProperties() {
    if (_statusFilter == '전체') {
      return _myProperties;
    }
    return _myProperties.where((property) => property.status == _statusFilter).toList();
  }

  // 통계 카드 위젯
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha:0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color.withValues(alpha:0.8),
            ),
          ),
        ],
      ),
    );
  }

  // 매물 카드 위젯
  Widget _buildPropertyCard(Property property) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          // 매물 상세 페이지로 이동
          Navigator.of(context).pushNamed(
            '/house-detail',
            arguments: {
              'property': property,
              'currentUserId': widget.userId,
            },
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      property.buildingName ?? property.address,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.kBrown,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(property.status ?? '미정'),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      property.status ?? '미정',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                property.address,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '${property.price.toStringAsFixed(0)}만원',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.kBrown,
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (property.area != null) ...[
                    Text(
                      '${property.area}㎡',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    '등록일: ${_formatDate(property.createdAt)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 상태에 따른 색상 반환
  Color _getStatusColor(String status) {
    switch (status) {
      case '임대중':
        return Colors.green;
      case '공실':
        return Colors.red;
      case '수리중':
        return Colors.orange;
      case '계약만료예정':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  // 매물이 없을 때 메시지
  Widget _buildNoPropertiesMessage() {
    return const EmptyState(
      icon: Icons.home_work_outlined,
      title: '등록된 매물이 없습니다',
      message: '내집팔기에서 매물을 등록하시면\n여기에서 확인하실 수 있습니다.',
    );
  }

  Widget _buildRentalStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha:0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: color.withValues(alpha:0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTenantList() {
    final sampleTenants = [
      {'name': '김민수', 'property': '강남원룸타워 301호', 'phone': '010-1234-5678', 'rent': '150만원'},
      {'name': '이영희', 'property': '홍대원룸빌 502호', 'phone': '010-9876-5432', 'rent': '120만원'},
    ];

    return Column(
      children: sampleTenants.map((tenant) => 
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.kBrown.withValues(alpha:0.1),
                child: Text(
                  tenant['name']![0],
                  style: TextStyle(
                    color: AppColors.kBrown,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tenant['name']!,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      tenant['property']!,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      tenant['phone']!,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    tenant['rent']!,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.kBrown,
                    ),
                  ),
                  TextButton(
                    onPressed: () => _showTenantDetailDialog(tenant),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      '상세보기',
                      style: TextStyle(fontSize: 10),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ).toList(),
    );
  }

  Widget _buildContractList() {
    final sampleContracts = [
      {'property': '강남원룸타워 301호', 'tenant': '김민수', 'endDate': '2024-12-31', 'status': '계약중'},
      {'property': '홍대원룸빌 502호', 'tenant': '이영희', 'endDate': '2024-11-15', 'status': '만료예정'},
    ];

    return Column(
      children: sampleContracts.map((contract) => 
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: contract['status'] == '만료예정' ? Colors.amber.withValues(alpha:0.1) : Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: contract['status'] == '만료예정' ? Colors.amber : Colors.grey[300]!,
            ),
          ),
          child: Row(
            children: [
              Icon(
                contract['status'] == '만료예정' ? Icons.warning : Icons.check_circle,
                color: contract['status'] == '만료예정' ? Colors.amber : Colors.green,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contract['property']!,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '임대인: ${contract['tenant']}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '만료일: ${contract['endDate']}',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: contract['status'] == '만료예정' ? Colors.amber : Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  contract['status']!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ).toList(),
    );
  }

  Widget _buildRepairHistoryList() {
    final repairHistory = [
      {
        'date': '2024-02-15',
        'building': '강남원룸타워 301호',
        'issue': '화장실 수도꼭지 고장',
        'status': '완료',
      },
      {
        'date': '2024-01-28',
        'building': '홍대원룸빌 502호',
        'issue': '냉장고 문 손상',
        'status': '완료',
      },
    ];

    if (repairHistory.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            '수리 내역이 없습니다',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return Column(
      children: repairHistory.map((repair) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      repair['building']!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      repair['issue']!,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '요청일: ${repair['date']}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  repair['status']!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // 임대인 추가 다이얼로그
  void _showAddTenantDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('임대인 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: '임대인 이름',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: '연락처',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: '임대료 (만원)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: '매물 선택',
                border: OutlineInputBorder(),
              ),
              items: _myProperties.map((property) => 
                DropdownMenuItem(
                  value: property.buildingName ?? property.address,
                  child: Text(property.buildingName ?? property.address),
                ),
              ).toList(),
              onChanged: (value) {},
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('임대인이 추가되었습니다')),
              );
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  // 임대인 상세 다이얼로그
  void _showTenantDetailDialog(Map<String, String> tenant) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${tenant['name']} 상세정보'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('매물', tenant['property']!),
            _buildDetailRow('연락처', tenant['phone']!),
            _buildDetailRow('임대료', tenant['rent']!),
            _buildDetailRow('계약 시작일', '2024-01-01'),
            _buildDetailRow('계약 만료일', '2024-12-31'),
            _buildDetailRow('보증금', '500만원'),
            _buildDetailRow('관리비', '10만원'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showEditTenantDialog(tenant);
            },
            child: const Text('수정'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  // 임대인 수정 다이얼로그
  void _showEditTenantDialog(Map<String, String> tenant) {
    final nameController = TextEditingController(text: tenant['name']);
    final phoneController = TextEditingController(text: tenant['phone']);
    final rentController = TextEditingController(text: tenant['rent']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('임대인 정보 수정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '임대인 이름',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: '연락처',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: rentController,
              decoration: const InputDecoration(
                labelText: '임대료',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('임대인 정보가 수정되었습니다')),
              );
            },
            child: const Text('수정'),
          ),
        ],
      ),
    );
  }

  void _showRepairRequestDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('수리 요청'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            TextField(
              decoration: InputDecoration(
                labelText: '수리 내용',
                hintText: '예: 화장실 수도꼭지 고장',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                labelText: '상세 설명',
                hintText: '문제 상황을 자세히 설명해주세요',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('수리 요청이 접수되었습니다'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.kBrown,
              foregroundColor: Colors.white,
            ),
            child: const Text('요청하기'),
          ),
        ],
      ),
    );
  }
  
  /// 내 요청 탭
  Widget _buildMyRequestsTab() {
    if (_myQuotes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.inbox,
                size: 64,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '보낸 요청이 없습니다',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '공인중개사에게 제안 요청을 보내보세요!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _myQuotes.length,
      itemBuilder: (context, index) {
        final quote = _myQuotes[index];
        return _buildQuoteCard(quote);
      },
    );
  }
  
  /// 견적문의 카드
  Widget _buildQuoteCard(QuoteRequest quote) {
    final dateFormat = DateFormat('yyyy.MM.dd HH:mm');
    final isPending = quote.status == 'pending';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isPending 
                  ? Colors.orange.withOpacity(0.1) 
                  : Colors.green.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isPending ? Colors.orange : Colors.green,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isPending ? Icons.schedule : Icons.check_circle,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quote.brokerName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateFormat.format(quote.requestDate),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isPending ? Colors.orange : Colors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isPending ? '답변대기' : '답변완료',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 내용
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 매물 정보
                if (quote.propertyAddress != null) ...[
                  _buildQuoteInfoRow(Icons.location_on, '매물 주소', quote.propertyAddress!),
                  const SizedBox(height: 8),
                ],
                if (quote.propertyType != null) ...[
                  _buildQuoteInfoRow(Icons.home, '매물 유형', quote.propertyType!),
                  const SizedBox(height: 8),
                ],
                if (quote.propertyArea != null) ...[
                  _buildQuoteInfoRow(Icons.square_foot, '전용면적', '${quote.propertyArea} ㎡'),
                  const SizedBox(height: 8),
                ],
                
                // 내가 입력한 정보
                if (quote.desiredPrice != null && quote.desiredPrice!.isNotEmpty) ...[
                  const Divider(height: 24),
                  _buildQuoteInfoRow(Icons.attach_money, '희망가', quote.desiredPrice!),
                  const SizedBox(height: 8),
                ],
                if (quote.targetPeriod != null && quote.targetPeriod!.isNotEmpty) ...[
                  _buildQuoteInfoRow(Icons.schedule, '목표기간', quote.targetPeriod!),
                  const SizedBox(height: 8),
                ],
                if (quote.hasTenant != null) ...[
                  _buildQuoteInfoRow(
                    Icons.people, 
                    '세입자', 
                    quote.hasTenant! ? '있음' : '없음',
                  ),
                  const SizedBox(height: 8),
                ],
                
                // 중개 제안 (중개업자가 작성한 경우)
                if (quote.recommendedPrice != null || quote.minimumPrice != null) ...[
                  const Divider(height: 24),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.campaign, size: 16, color: Colors.green[700]),
                            const SizedBox(width: 8),
                            Text(
                              '중개 제안',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (quote.recommendedPrice != null && quote.recommendedPrice!.isNotEmpty)
                          _buildQuoteInfoRow(Icons.monetization_on, '권장 매도가', quote.recommendedPrice!),
                        if (quote.minimumPrice != null && quote.minimumPrice!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _buildQuoteInfoRow(Icons.price_check, '최저수락가', quote.minimumPrice!),
                        ],
                        if (quote.commissionRate != null && quote.commissionRate!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _buildQuoteInfoRow(Icons.percent, '수수료율', quote.commissionRate!),
                        ],
                      ],
                    ),
                  ),
                ],
                
                // 액션 버튼
                const Divider(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _deleteQuote(quote.id),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.delete, size: 18),
                    label: const Text('요청 삭제', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  /// 견적문의 정보 행
  Widget _buildQuoteInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
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
}
