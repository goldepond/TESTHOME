import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';
import '../../models/property.dart';
import '../../services/firebase_service.dart';
import '../../utils/address_utils.dart';
import '../../widgets/empty_state.dart';
import 'category_property_list_page.dart';

class HouseMarketPage extends StatefulWidget {
  final String userName;

  const HouseMarketPage({
    required this.userName,
    super.key,
  });

  @override
  State<HouseMarketPage> createState() => _HouseMarketPageState();
}

class _HouseMarketPageState extends State<HouseMarketPage> {
  final FirebaseService _firebaseService = FirebaseService();
  List<Property> _properties = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  String? _selectedRegion;
  String? _selectedProvince;

  @override
  void initState() {
    super.initState();
    _loadProperties();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProperties() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final allProperties = await _firebaseService.getAllPropertiesList();
      
      // 지역 필터링 및 상태 필터링 적용
      List<Property> filteredProperties = allProperties.where((property) {
        // 예약 상태와 보류 상태는 매물 목록에서 제외
        if (property.contractStatus == '예약' || property.contractStatus == '보류') {
          return false;
        }
        return true;
      }).toList();
      
      if (_selectedRegion != null && _selectedRegion != '전체 지역') {
        filteredProperties = filteredProperties.where((property) {
          return AddressUtils.isRegionMatch(property.addressCity, _selectedRegion!);
        }).toList();
      }
      
      if (mounted) {
        setState(() {
          _properties = filteredProperties;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '매물을 불러오는 중 오류가 발생했습니다: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 검색바
            _buildSearchBar(),
            
            // 메인 콘텐츠
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? _buildErrorWidget()
                      : _buildMainContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegionSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.location_on_outlined,
                color: AppColors.kBrown,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                '지역 선택',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _showRegionPicker,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedRegion ?? '전체 지역',
                      style: TextStyle(
                        fontSize: 14,
                        color: _selectedRegion != null ? Colors.black87 : Colors.grey[600],
                        fontWeight: _selectedRegion != null ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.grey[600],
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search,
            color: Colors.grey[600],
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '지역, 지하철, 대학교 검색',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // 지역 선택
          _buildRegionSelector(),
          
          const SizedBox(height: 20),
          
          // 매물 카테고리 카드들
          _buildCategoryCards(),
          
          const SizedBox(height: 20),
          
          // 맞춤 방 찾기 배너
          _buildCustomSearchBanner(),
          
          const SizedBox(height: 20),
          
          // 메이트/직거래 옵션
          _buildFeatureOptions(),
          
          const SizedBox(height: 20),
          
          // 매물 목록
          _buildPropertyList(),
          
          const SizedBox(height: 20),
          
          // 광고 배너
          _buildAdBanner(),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildCategoryCards() {
    final categories = [
      {
        'title': '원룸 / 투룸',
        'subtitle': '1~2인 가구\n최적의 선택',
        'icon': Icons.home_outlined,
        'color': Colors.blue[100]!,
        'iconColor': Colors.blue[600]!,
        'buildingTypes': ['원룸', '투룸', '원룸텔', '고시원'],
      },
      {
        'title': '빌라 / 투룸+',
        'subtitle': '3~4인 가구\n넓은 공간',
        'icon': Icons.home_work_outlined,
        'color': Colors.green[100]!,
        'iconColor': Colors.green[600]!,
        'buildingTypes': ['빌라', '투룸+', '쓰리룸', '포룸'],
      },
      {
        'title': '오피스텔',
        'subtitle': '사무공간\n거주공간',
        'icon': Icons.business_outlined,
        'color': Colors.purple[100]!,
        'iconColor': Colors.purple[600]!,
        'buildingTypes': ['오피스텔', '상가', '사무실'],
      },
      {
        'title': '아파트',
        'subtitle': '가족형 주거\n안전한 환경',
        'icon': Icons.apartment_outlined,
        'color': Colors.orange[100]!,
        'iconColor': Colors.orange[600]!,
        'buildingTypes': ['아파트', 'APT', '아파트형공장'],
      },
      {
        'title': '쉐어하우스',
        'subtitle': '함께 살기\n경제적 선택',
        'icon': Icons.people_outline,
        'color': Colors.red[100]!,
        'iconColor': Colors.red[600]!,
        'buildingTypes': ['쉐어하우스', '코리빙', '하우스쉐어'],
      },
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '매물 카테고리',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return _buildCategoryCard(category);
            },
          ),
        ],
      ),
    );
  }

  void _navigateToCategoryPage(Map<String, dynamic> category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryPropertyListPage(
          categoryTitle: category['title'],
          buildingTypes: List<String>.from(category['buildingTypes']),
          userName: widget.userName,
          selectedRegion: _selectedRegion,
        ),
      ),
    );
  }

  void _showRegionPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildProvincePicker(),
    );
  }

  Widget _buildProvincePicker() {
    final provinces = _getProvinces();
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.kBrown,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                const Text(
                  '지역 선택',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
          
          // 도/특별시 목록
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              physics: const BouncingScrollPhysics(),
              itemCount: provinces.length,
              itemBuilder: (context, index) {
                final province = provinces[index];
                return _buildProvinceItem(province);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCityPicker(String province) {
    final cities = _getCitiesByProvince(province);
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.kBrown,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    '$province 시 선택',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
          
          // 시 목록
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              physics: const BouncingScrollPhysics(),
              itemCount: cities.length,
              itemBuilder: (context, index) {
                final city = cities[index];
                return _buildCityItem(city, province);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProvinceItem(Map<String, dynamic> province) {
    final isSelected = _selectedProvince == province['name'];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            if (province['type'] == 'special') {
              // 특별시/광역시는 바로 선택
              setState(() {
                _selectedRegion = province['name'];
                _selectedProvince = province['name'];
              });
              Navigator.pop(context);
              _loadProperties();
            } else {
              // 도 단위는 시 선택으로 이동
              Navigator.pop(context);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => _buildCityPicker(province['name']),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.kBrown.withValues(alpha:0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isSelected ? Border.all(color: AppColors.kBrown, width: 1) : null,
            ),
            child: Row(
              children: [
                if (isSelected) ...[
                  Icon(
                    Icons.check_circle,
                    color: AppColors.kBrown,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        province['name'],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? AppColors.kBrown : Colors.black87,
                        ),
                      ),
                      if (province['count'] != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${province['count']}개 시',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[500],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCityItem(String city, String province) {
    final isSelected = _selectedRegion == city;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            setState(() {
              _selectedRegion = city;
              _selectedProvince = province;
            });
            Navigator.pop(context);
            _loadProperties();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.kBrown.withValues(alpha:0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isSelected ? Border.all(color: AppColors.kBrown, width: 1) : null,
            ),
            child: Row(
              children: [
                if (isSelected) ...[
                  Icon(
                    Icons.check_circle,
                    color: AppColors.kBrown,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    city,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? AppColors.kBrown : Colors.black87,
                    ),
                  ),
                ),
                Icon(
                  Icons.location_on,
                  size: 16,
                  color: Colors.grey[500],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getProvinces() {
    return [
      {'name': '전체 지역', 'count': null, 'type': 'all'},
      
      // 특별시/광역시
      {'name': '서울특별시', 'count': null, 'type': 'special'},
      {'name': '부산광역시', 'count': null, 'type': 'special'},
      {'name': '대구광역시', 'count': null, 'type': 'special'},
      {'name': '인천광역시', 'count': null, 'type': 'special'},
      {'name': '광주광역시', 'count': null, 'type': 'special'},
      {'name': '대전광역시', 'count': null, 'type': 'special'},
      {'name': '울산광역시', 'count': null, 'type': 'special'},
      {'name': '세종특별자치시', 'count': null, 'type': 'special'},
      
      // 도 단위
      {'name': '경기도', 'count': 28, 'type': 'province'},
      {'name': '강원도', 'count': 7, 'type': 'province'},
      {'name': '경상남도', 'count': 8, 'type': 'province'},
      {'name': '경상북도', 'count': 10, 'type': 'province'},
      {'name': '전라남도', 'count': 5, 'type': 'province'},
      {'name': '전라북도', 'count': 6, 'type': 'province'},
      {'name': '제주특별자치도', 'count': 2, 'type': 'province'},
      {'name': '충청남도', 'count': 8, 'type': 'province'},
      {'name': '충청북도', 'count': 3, 'type': 'province'},
    ];
  }

  List<String> _getCitiesByProvince(String province) {
    switch (province) {
      case '경기도':
        return [
          '고양시', '과천시', '광명시', '광주시', '구리시', '군포시', '김포시', '남양주시',
          '동두천시', '부천시', '성남시', '수원시', '시흥시', '안산시', '안성시', '안양시',
          '양주시', '여주시', '오산시', '용인시', '의왕시', '의정부시', '이천시', '파주시',
          '평택시', '포천시', '하남시', '화성시'
        ];
      case '강원도':
        return ['강릉시', '동해시', '삼척시', '속초시', '원주시', '춘천시', '태백시'];
      case '경상남도':
        return ['거제시', '김해시', '밀양시', '사천시', '양산시', '진주시', '창원시', '통영시'];
      case '경상북도':
        return ['경산시', '경주시', '구미시', '김천시', '문경시', '상주시', '안동시', '영주시', '영천시', '포항시'];
      case '전라남도':
        return ['광양시', '나주시', '목포시', '순천시', '여수시'];
      case '전라북도':
        return ['군산시', '김제시', '남원시', '익산시', '전주시', '정읍시'];
      case '제주특별자치도':
        return ['서귀포시', '제주시'];
      case '충청남도':
        return ['계룡시', '공주시', '논산시', '당진시', '보령시', '서산시', '아산시', '천안시'];
      case '충청북도':
        return ['제천시', '청주시', '충주시'];
      default:
        return [];
    }
  }

  Widget _buildCategoryCard(Map<String, dynamic> category) {
    return GestureDetector(
      onTap: () {
        _navigateToCategoryPage(category);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: category['color'],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              category['icon'],
              color: category['iconColor'],
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              category['title'],
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            if (category['subtitle'].isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                category['subtitle'],
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  height: 1.2,
                ),
              ),
            ],
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: Colors.grey[500],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomSearchBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      '맞춤 방 찾기',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Beta',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '원하는 조건의 맞춤 방을 찾아보세요!',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.checklist_outlined,
            color: Colors.grey[600],
            size: 24,
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureOptions() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    color: Colors.blue[600],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '메이트',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.handshake_outlined,
                    color: Colors.green[600],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '직거래',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyList() {
    if (_properties.isEmpty) {
      return const EmptyState(
        icon: Icons.home_outlined,
        title: '등록된 매물이 없습니다',
        message: '아직 판매 중인 매물이 없습니다.\n매물이 등록되면 여기에 표시됩니다.',
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '등록된 매물',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _properties.length,
            itemBuilder: (context, index) {
              final property = _properties[index];
              return _buildPropertyCard(property);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyCard(Property property) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  property.address,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(property.contractStatus).withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  property.contractStatus,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(property.contractStatus),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.attach_money,
                size: 16,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                '${property.price.toStringAsFixed(0)}원',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                Icons.person,
                size: 16,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                property.mainContractor,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          if (property.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              property.description,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple[400]!, Colors.purple[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'CU·이마트24 편의점택배',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '최대 반값 할인받으세요!',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha:0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.local_shipping,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[400],
          ),
          const SizedBox(height: 16),
          Text(
            '오류가 발생했습니다',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadProperties,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.kBrown,
              foregroundColor: Colors.white,
            ),
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case '작성 완료':
        return Colors.green;
      case '보류':
        return Colors.orange;
      case '진행중':
        return Colors.blue;
      case '예약':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}