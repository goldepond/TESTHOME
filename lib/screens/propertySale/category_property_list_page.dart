import 'package:flutter/material.dart';
import '../../models/property.dart';
import '../../services/firebase_service.dart';
import '../../constants/app_constants.dart';
import '../../utils/address_utils.dart';
import 'house_detail_page.dart';

class CategoryPropertyListPage extends StatefulWidget {
  final String categoryTitle;
  final List<String> buildingTypes;
  final String? userName;
  final String? selectedRegion;

  const CategoryPropertyListPage({
    Key? key,
    required this.categoryTitle,
    required this.buildingTypes,
    this.userName,
    this.selectedRegion,
  }) : super(key: key);

  @override
  State<CategoryPropertyListPage> createState() => _CategoryPropertyListPageState();
}

class _CategoryPropertyListPageState extends State<CategoryPropertyListPage> {
  final FirebaseService _firebaseService = FirebaseService();
  List<Property> _properties = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadProperties();
  }

  Future<void> _loadProperties() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      // 모든 매물을 가져온 후 buildingType과 지역으로 필터링
      final allProperties = await _firebaseService.getAllPropertiesList();
      
      // buildingType, 지역, 상태가 매칭되는 매물들만 필터링
      final filteredProperties = allProperties.where((property) {
        // 예약 상태와 보류 상태는 매물 목록에서 제외
        if (property.contractStatus == '예약' || property.contractStatus == '보류') {
          return false;
        }
        
        // buildingType 필터링
        final buildingType = property.buildingType?.toLowerCase() ?? '';
        final buildingTypeMatch = widget.buildingTypes.any((type) => 
          buildingType.contains(type.toLowerCase()) ||
          type.toLowerCase().contains(buildingType)
        );
        
        // 지역 필터링
        bool regionMatch = true;
        if (widget.selectedRegion != null && widget.selectedRegion != '전체 지역') {
          regionMatch = AddressUtils.isRegionMatch(property.addressCity, widget.selectedRegion!);
        }
        
        return buildingTypeMatch && regionMatch;
      }).toList();

      setState(() {
        _properties = filteredProperties;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '매물을 불러오는 중 오류가 발생했습니다: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          widget.categoryTitle,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: AppColors.kBrown,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha:0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${_properties.length}개',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.kBrown),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              style: TextStyle(
                fontSize: 16,
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

    if (_properties.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.home_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '${widget.categoryTitle} 매물이 없습니다',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '다른 카테고리를 확인해보세요',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProperties,
      color: AppColors.kBrown,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _properties.length,
        itemBuilder: (context, index) {
          final property = _properties[index];
          return _buildPropertyCard(property);
        },
      ),
    );
  }

  Widget _buildPropertyCard(Property property) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => HouseDetailPage(
                  property: property,
                  imagePath: '',
                  currentUserId: widget.userName ?? '',
                  currentUserName: widget.userName ?? '',
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 상태 및 가격
                Row(
                  children: [
                    _buildStatusChip(property.contractStatus),
                    const Spacer(),
                    Text(
                      _formatPrice(property.price),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.kBrown,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // 주소
                Text(
                  property.address,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C3E50),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                
                // 건물 타입 및 거래 유형
                Row(
                  children: [
                    if (property.buildingType != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          property.buildingType!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.kBrown.withValues(alpha:0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _getTransactionTypeText(property.transactionType),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.kBrown,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // 계약자 정보
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
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
                    const Spacer(),
                    Text(
                      _formatDate(property.createdAt),
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
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;
    IconData icon;

    switch (status) {
      case '작성 완료':
        backgroundColor = Colors.green[100]!;
        textColor = Colors.green[700]!;
        icon = Icons.check_circle_outline;
        break;
      case '보류':
        backgroundColor = Colors.orange[100]!;
        textColor = Colors.orange[700]!;
        icon = Icons.pause_circle_outline;
        break;
      case '진행중':
        backgroundColor = Colors.blue[100]!;
        textColor = Colors.blue[700]!;
        icon = Icons.play_circle_outline;
        break;
      case '예약':
        backgroundColor = Colors.purple[100]!;
        textColor = Colors.purple[700]!;
        icon = Icons.event_available_outlined;
        break;
      default:
        backgroundColor = Colors.grey[100]!;
        textColor = Colors.grey[700]!;
        icon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: textColor,
          ),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              fontSize: 12,
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(int price) {
    if (price >= 100000000) {
      return '${(price / 100000000).toStringAsFixed(1)}억원';
    } else if (price >= 10000) {
      return '${(price / 10000).toStringAsFixed(0)}만원';
    } else {
      return '${price.toString()}원';
    }
  }

  String _getTransactionTypeText(String type) {
    switch (type) {
      case 'jeonse':
        return '전세';
      case 'monthly':
        return '월세';
      case 'sale':
        return '매매';
      default:
        return type;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}일 전';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}시간 전';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}분 전';
    } else {
      return '방금 전';
    }
  }
}
