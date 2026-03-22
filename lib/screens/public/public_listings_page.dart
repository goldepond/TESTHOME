import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants/app_constants.dart';
import '../../utils/formatters.dart';
import '../../constants/property_constants.dart';
import '../../models/mls_property.dart';
import '../../widgets/home_logo_button.dart';
import '../user_type_selection_page.dart';
import 'public_property_detail_page.dart';

/// 공개 매물 목록 페이지
///
/// 로그인 없이 접근 가능한 매물 목록 웹 페이지.
/// 중개사에게 공유할 수 있는 URL: /listings
class PublicListingsPage extends StatefulWidget {
  const PublicListingsPage({super.key});

  @override
  State<PublicListingsPage> createState() => _PublicListingsPageState();
}

class _PublicListingsPageState extends State<PublicListingsPage> {
  final _firestore = FirebaseFirestore.instance;
  String? _selectedRegion;
  String _selectedTransactionType = '전체';

  static const List<String> _transactionTypes = PropertyConstants.transactionTypes;

  static const Map<String, String> _regionLabels = PropertyConstants.filterRegions;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Scaffold(
      backgroundColor: AirbnbColors.surface,
      body: Column(
        children: [
          _buildTopBar(isMobile),
          _buildFilters(),
          Expanded(child: _buildPropertyGrid(isMobile)),
          _buildCtaBanner(isMobile),
        ],
      ),
    );
  }

  Widget _buildTopBar(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 40,
        vertical: 16,
      ),
      decoration: const BoxDecoration(
        color: AirbnbColors.background,
        border: Border(
          bottom: BorderSide(color: AirbnbColors.border),
        ),
      ),
      child: Row(
        children: [
          LogoWithText(
            logoHeight: 40,
            textColor: AirbnbColors.primary,
            onTap: () {},
          ),
          const Spacer(),
          Text(
            '현재 등록 매물',
            style: TextStyle(
              fontSize: isMobile ? 14 : 18,
              fontWeight: FontWeight.w600,
              color: AirbnbColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AirbnbColors.background,
      child: Column(
        children: [
          // 지역 필터
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('전체 지역', _selectedRegion == null, () {
                  setState(() => _selectedRegion = null);
                }),
                const SizedBox(width: 8),
                ..._regionLabels.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildFilterChip(
                      entry.value,
                      _selectedRegion == entry.key,
                      () => setState(() => _selectedRegion = entry.key),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 거래유형 필터
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _transactionTypes.map((type) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildFilterChip(
                    type,
                    _selectedTransactionType == type,
                    () => setState(() => _selectedTransactionType = type),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AirbnbColors.primary : AirbnbColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AirbnbColors.primary : AirbnbColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? Colors.white : AirbnbColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildPropertyGrid(bool isMobile) {
    Query query = _firestore
        .collection('mlsProperties')
        .where('status', isEqualTo: 'active')
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true);

    if (_selectedRegion != null) {
      query = query.where('region', isEqualTo: _selectedRegion);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.home_outlined, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                const Text(
                  '등록된 매물이 없습니다',
                  style: TextStyle(
                    fontSize: 16,
                    color: AirbnbColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        List<MLSProperty> properties = snapshot.data!.docs
            .map((doc) =>
                MLSProperty.fromMap(doc.data() as Map<String, dynamic>))
            .toList();

        // 거래유형 필터 (클라이언트 사이드)
        if (_selectedTransactionType != '전체') {
          properties = properties
              .where((p) => p.transactionType == _selectedTransactionType)
              .toList();
        }

        if (properties.isEmpty) {
          return const Center(
            child: Text(
              '조건에 맞는 매물이 없습니다',
              style: TextStyle(color: AirbnbColors.textSecondary),
            ),
          );
        }

        final crossAxisCount = isMobile ? 1 : (MediaQuery.of(context).size.width ~/ 350).clamp(2, 4);

        return GridView.builder(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: isMobile ? 1.3 : 0.85,
          ),
          itemCount: properties.length,
          itemBuilder: (context, index) =>
              _buildPropertyCard(properties[index], isMobile),
        );
      },
    );
  }

  Widget _buildPropertyCard(MLSProperty property, bool isMobile) {
    // 주소에서 동/호수 제거 (개인정보 보호)
    final displayAddress = _sanitizeAddress(property.address);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                PublicPropertyDetailPage(propertyId: property.id),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AirbnbColors.background,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 사진
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                child: property.thumbnailUrl != null
                    ? Image.network(
                        property.thumbnailUrl!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                      )
                    : _buildPlaceholder(),
              ),
            ),

            // 정보
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 거래유형 + 가격
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AirbnbColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            property.transactionType,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AirbnbColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _formatPrice(property.desiredPrice),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AirbnbColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // 주소
                    Text(
                      displayAddress,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AirbnbColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // 면적/층수
                    Text(
                      _buildPropertyMeta(property),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AirbnbColors.textLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AirbnbColors.surface,
      child: const Center(
        child:
            Icon(Icons.home_outlined, size: 40, color: AirbnbColors.textLight),
      ),
    );
  }

  Widget _buildCtaBanner(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 40,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: AirbnbColors.primary.withValues(alpha: 0.05),
        border: const Border(
          top: BorderSide(color: AirbnbColors.border),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '중개사님이신가요?',
                  style: TextStyle(
                    fontSize: isMobile ? 15 : 17,
                    fontWeight: FontWeight.w700,
                    color: AirbnbColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '가입하시면 매물 상세정보 확인 및 방문 요청이 가능합니다',
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 14,
                    color: AirbnbColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UserTypeSelectionPage(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AirbnbColors.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('가입하기', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // === 유틸 ===

  /// 주소에서 동/호수 제거 (개인정보 보호)
  String _sanitizeAddress(String address) {
    // "xxx동 xxx호" 패턴 제거
    return address
        .replaceAll(RegExp(r'\d+동\s*\d+호'), '')
        .replaceAll(RegExp(r'\d+호'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _formatPrice(double price) => PriceFormatter.format(price);

  String _buildPropertyMeta(MLSProperty property) {
    final parts = <String>[];
    if (property.area != null) {
      parts.add('${property.area!.toStringAsFixed(1)}m²');
    }
    if (property.floor != null) {
      parts.add('${property.floor}층');
    }
    if (property.rooms != null) {
      parts.add('${property.rooms}룸');
    }
    if (property.buildingName.isNotEmpty) {
      parts.add(property.buildingName);
    }
    return parts.join(' · ');
  }
}
