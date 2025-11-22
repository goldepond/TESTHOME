import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/models/property.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/utils/address_utils.dart';
import 'package:property/widgets/empty_state.dart';
import 'package:property/widgets/loading_overlay.dart';
import 'package:property/constants/status_constants.dart';
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
  List<Property> _allProperties = [];
  List<Property> _properties = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProperties();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadProperties() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final allProperties = await _firebaseService.getAllPropertiesList();

      // 예약/보류 상태 제외만 먼저 적용
      List<Property> baseProperties = allProperties.where((property) {
        if (property.contractStatus == '예약' || property.contractStatus == '보류') {
          return false;
        }
        return true;
      }).toList();

      if (mounted) {
        setState(() {
          _allProperties = baseProperties;
          _applyFiltersAndSort();
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

  /// 정렬만 적용 (지역 필터 삭제됨)
  void _applyFiltersAndSort() {
    List<Property> filtered = List<Property>.from(_allProperties);

    // 정렬
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    _properties = filtered;
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      message: '매물 정보를 불러오는 중...',
      child: Scaffold(
        backgroundColor: AppColors.kBackground,
        body: SafeArea(
          child: _errorMessage != null
              ? Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: _buildErrorWidget(),
                  ),
                )
              : _buildMainContent(),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    const double maxContentWidth = 900;
    const double bannerHeight = 360;
    const double overlapHeight = 80; // 배너와 겹치는 높이 (40 -> 80으로 증가)

    return SingleChildScrollView(
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // 히어로 배너
          _buildBuyHeroBanner(),

          // 메인 컨텐츠
          Padding(
            padding: const EdgeInsets.only(top: bannerHeight - overlapHeight),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: maxContentWidth),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // 매물 카테고리 카드들
                    _buildCategoryCards(),

                    const SizedBox(height: 20),
                    
                    // 매물 목록
                    _buildPropertyList(),
                    
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuyHeroBanner() {
    return Container(
      height: 360,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF5B21B6),
            Color(0xFF1E3A8A),
          ],
        ),
        borderRadius: BorderRadius.zero,
        boxShadow: const [
          BoxShadow(
            color: Color(0x405B21B6),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '검증된 실매물을\n한눈에 확인하세요',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '원하는 조건의 매물을 쉽고 빠르게 찾을 수 있습니다',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          // 카테고리 카드와 겹치는 부분 고려하여 텍스트 위치 상향 조정
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildCategoryCards() {
    final categories = [
      {
        'title': '아파트',
        'icon': Icons.apartment_outlined,
        'buildingTypes': ['아파트', 'APT', '아파트형공장'],
      },
      {
        'title': '빌라 · 투룸+',
        'icon': Icons.home_work_outlined,
        'buildingTypes': ['빌라', '투룸+', '쓰리룸', '포룸'],
      },
      {
        'title': '원룸',
        'icon': Icons.home_outlined,
        'buildingTypes': ['원룸', '투룸', '원룸텔', '고시원'],
      },
      {
        'title': '오피스텔',
        'icon': Icons.business_outlined,
        'buildingTypes': ['오피스텔', '상가', '사무실'],
      },
      {
        'title': '상가 · 사무실',
        'icon': Icons.storefront_outlined,
        'buildingTypes': ['상가', '사무실', '상업시설'],
      },
      {
        'title': '쉐어하우스',
        'icon': Icons.people_outline,
        'buildingTypes': ['쉐어하우스', '코리빙', '하우스쉐어'],
      },
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 화면 너비가 좁을 경우 (예: 600px 미만) 2줄로 배치
          if (constraints.maxWidth < 600) {
            return Column(
              children: [
                Row(
                  children: [
                    for (int i = 0; i < 3; i++) ...[
                      Expanded(
                        child: _CategoryButton(
                          title: categories[i]['title'] as String,
                          icon: categories[i]['icon'] as IconData,
                          onTap: () => _navigateToCategoryPage(categories[i]),
                        ),
                      ),
                      if (i < 2) const SizedBox(width: 4),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (int i = 3; i < 6; i++) ...[
                      Expanded(
                        child: _CategoryButton(
                          title: categories[i]['title'] as String,
                          icon: categories[i]['icon'] as IconData,
                          onTap: () => _navigateToCategoryPage(categories[i]),
                        ),
                      ),
                      if (i < 5) const SizedBox(width: 4),
                    ],
                  ],
                ),
              ],
            );
          }
          
          // 화면이 충분히 넓으면 기존대로 1줄 배치
          return Row(
            children: [
              for (int i = 0; i < categories.length; i++) ...[
                Expanded(
                  child: _CategoryButton(
                    title: categories[i]['title'] as String,
                    icon: categories[i]['icon'] as IconData,
                    onTap: () => _navigateToCategoryPage(categories[i]),
                  ),
                ),
                if (i != categories.length - 1) const SizedBox(width: 4),
              ],
            ],
          );
        },
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
          selectedRegion: null, // 지역 선택 기능이 사라졌으므로 null 전달
        ),
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
    final lifecycle = PropertyLifecycleStatus.fromProperty(property);
    final lifecycleColor = PropertyLifecycleStatus.color(lifecycle);
    final lifecycleLabel = PropertyLifecycleStatus.label(lifecycle);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
                  color: lifecycleColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  lifecycleLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: lifecycleColor,
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
}

class _CategoryButton extends StatelessWidget {
  const _CategoryButton({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.kPrimary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: AppColors.kPrimary,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
