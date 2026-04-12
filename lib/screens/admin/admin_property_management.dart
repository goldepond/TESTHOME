import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/constants/responsive_constants.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/api_request/mls_property_service.dart';
import 'package:property/models/mls_property.dart';
import 'package:intl/intl.dart';
import '../../models/broker_offer.dart';
import 'admin_proxy_registration_page.dart';
import 'package:property/constants/typography.dart';
import 'package:property/utils/snackbar_utils.dart';

/// 관리자 - MLS 매물 관리 페이지
class AdminPropertyManagement extends StatefulWidget {
  final String userId;
  final String userName;

  const AdminPropertyManagement({
    required this.userId, required this.userName, super.key,
  });

  @override
  State<AdminPropertyManagement> createState() => _AdminPropertyManagementState();
}

class _AdminPropertyManagementState extends State<AdminPropertyManagement> {
  final FirebaseService _firebaseService = FirebaseService();
  final MLSPropertyService _mlsService = MLSPropertyService();
  List<MLSProperty> _properties = [];
  bool _isLoading = true;
  String? _error;
  String _searchKeyword = '';
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'all'; // all, pending, active, negotiating, contracted
  StreamSubscription<List<MLSProperty>>? _subscription;

  @override
  void initState() {
    super.initState();
    _loadProperties();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _subscription?.cancel();
    super.dispose();
  }

  void _loadProperties() {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    _subscription?.cancel();
    _subscription = _mlsService.getAllPropertiesForAdmin().listen(
      (properties) {
        if (mounted) {
          setState(() {
            _properties = properties;
            _isLoading = false;
          });
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() {
            _error = '매물 목록을 불러오는데 실패했습니다: $e';
            _isLoading = false;
          });
        }
      },
    );
  }

  /// 대리 등록 페이지 열기
  Future<void> _openProxyRegistration() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const AdminProxyRegistrationPage(),
      ),
    );

    if (result == true) {
      // 등록 성공 시 목록 새로고침
      _loadProperties();
    }
  }

  /// 매물 수정 페이지 열기
  Future<void> _editProperty(MLSProperty property) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AdminProxyRegistrationPage(
          existingProperty: property,
        ),
      ),
    );

    if (result == true) {
      // 수정 성공 시 목록 새로고침
      _loadProperties();
    }
  }

  List<MLSProperty> get _filteredProperties {
    List<MLSProperty> filtered = _properties;

    // 상태 필터
    if (_statusFilter != 'all') {
      filtered = filtered.where((p) => p.status.name == _statusFilter).toList();
    }

    // 검색 키워드 필터
    if (_searchKeyword.isNotEmpty) {
      final keyword = _searchKeyword.toLowerCase();
      filtered = filtered.where((p) {
        final address = p.roadAddress.toLowerCase();
        final region = p.region.toLowerCase();
        final id = p.id.toLowerCase();

        return address.contains(keyword) ||
               region.contains(keyword) ||
               id.contains(keyword);
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AirbnbColors.surface,
        resizeToAvoidBottomInset: true,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openProxyRegistration,
          backgroundColor: AirbnbColors.primary,
          foregroundColor: AirbnbColors.background,
          icon: const Icon(Icons.add),
          label: const Text('대리 등록'),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: ResponsiveHelper.getMaxWidth(context)),
            child: SafeArea(
          child: Column(
            children: [
          // 검색 및 필터 바
          Container(
            padding: const EdgeInsets.all(16),
            color: AirbnbColors.background,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '주소, 지역, 매물ID로 검색',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchKeyword.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchKeyword = '';
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AirbnbColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AirbnbColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AirbnbColors.primary, width: 2),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchKeyword = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                // 상태 필터
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('all', '전체'),
                      const SizedBox(width: 8),
                      _buildFilterChip('pending', '대기중'),
                      const SizedBox(width: 8),
                      _buildFilterChip('active', '배포중'),
                      const SizedBox(width: 8),
                      _buildFilterChip('underOffer', '협의중'),
                      const SizedBox(width: 8),
                      _buildFilterChip('sold', '거래완료'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 통계 카드
          Container(
            padding: const EdgeInsets.all(16),
            color: AirbnbColors.background,
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    '전체',
                    _properties.length.toString(),
                    AirbnbColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    '검색 결과',
                    _filteredProperties.length.toString(),
                    AirbnbColors.primary,
                  ),
                ),
              ],
            ),
          ),

          // 목록
          Expanded(
            child: _buildPropertyList(),
          ),
            ],
          ),
        ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _statusFilter == value;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      onSelected: (selected) {
        setState(() {
          _statusFilter = value;
        });
      },
      selectedColor: AirbnbColors.primary.withValues(alpha: 0.2),
      checkmarkColor: AirbnbColors.primary,
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTypography.withColor(AppTypography.h2, color),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AirbnbColors.error.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              _error!,
              style:  AppTypography.withColor(AppTypography.body, AirbnbColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadProperties,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (_filteredProperties.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.home_outlined,
              size: 80,
              color: AirbnbColors.border,
            ),
            const SizedBox(height: 24),
            Text(
              _searchKeyword.isEmpty && _statusFilter == 'all'
                  ? '등록된 매물이 없습니다'
                  : '검색 결과가 없습니다',
              style:  AppTypography.withColor(AppTypography.h4, AirbnbColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredProperties.length,
      itemBuilder: (context, index) {
        return _buildPropertyCard(_filteredProperties[index]);
      },
    );
  }

  Widget _buildPropertyCard(MLSProperty property) {
    final priceFormat = NumberFormat('#,###');
    final dateFormat = DateFormat('yyyy-MM-dd');

    final priceText = '${priceFormat.format(property.desiredPrice)}만원';

    // 상태 색상
    Color statusColor;
    String statusText;
    switch (property.status) {
      case PropertyStatus.draft:
        statusColor = AirbnbColors.textSecondary;
        statusText = '임시저장';
        break;
      case PropertyStatus.pending:
        statusColor = AirbnbColors.warning;
        statusText = '검증대기';
        break;
      case PropertyStatus.rejected:
        statusColor = AirbnbColors.error;
        statusText = '검증거절';
        break;
      case PropertyStatus.active:
        statusColor = AirbnbColors.success;
        statusText = '배포중';
        break;
      case PropertyStatus.inquiry:
        statusColor = AirbnbColors.info;
        statusText = '문의중';
        break;
      case PropertyStatus.underOffer:
        statusColor = AirbnbColors.primary;
        statusText = '협의중';
        break;
      case PropertyStatus.depositTaken:
        statusColor = AirbnbColors.purple;
        statusText = '가계약';
        break;
      case PropertyStatus.sold:
        statusColor = AirbnbColors.textSecondary;
        statusText = '거래완료';
        break;
      case PropertyStatus.cancelled:
        statusColor = AirbnbColors.error;
        statusText = '취소됨';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AirbnbColors.background,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AirbnbColors.textPrimary.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AirbnbColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.home,
                    color: AirbnbColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        property.roadAddress,
                        style:  AppTypography.body.copyWith(color: AirbnbColors.textPrimary, fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        priceText,
                        style:  AppTypography.body.copyWith(color: AirbnbColors.primary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                // 상태 배지
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    statusText,
                    style: AppTypography.caption.copyWith(color: statusColor, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.tag, '매물ID', property.id),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.location_city, '지역', property.region),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.person, '등록자ID', property.userId),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.calendar_today,
              '등록일',
              dateFormat.format(property.createdAt),
            ),
            if (property.targetBrokerIds.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.people,
                '배포 중개사',
                '${property.targetBrokerIds.length}명',
              ),
            ],
            // 배지 영역 (대리 등록 / 외부 매물)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (property.toMap()['isProxyRegistration'] == true)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AirbnbColors.info.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AirbnbColors.info.withValues(alpha: 0.3)),
                    ),
                    child:   Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.admin_panel_settings, size: 14, color: AirbnbColors.info),
                        SizedBox(width: 4),
                        Text(
                          '관리자 대리 등록',
                          style: AppTypography.caption.copyWith(color: AirbnbColors.info, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                if (property.isExternalListing)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AirbnbColors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AirbnbColors.orange.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.open_in_new, size: 14, color: AirbnbColors.orange),
                        const SizedBox(width: 4),
                        Text(
                          '외부 매물 · ${property.externalSource ?? ''}',
                          style:  AppTypography.caption.copyWith(color: AirbnbColors.orange, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                if (property.isExternalListing && property.linkedUserId != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AirbnbColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AirbnbColors.success.withValues(alpha: 0.3)),
                    ),
                    child:   Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.link, size: 14, color: AirbnbColors.success),
                        SizedBox(width: 4),
                        Text(
                          '사용자 연결됨',
                          style: AppTypography.caption.copyWith(color: AirbnbColors.success, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            // 중개 제안 카운트
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('brokerOffers')
                  .where('propertyId', isEqualTo: property.id)
                  .snapshots(),
              builder: (context, offerSnapshot) {
                final offers = offerSnapshot.data?.docs ?? [];
                final pendingCount = offers.where((d) => (d.data() as Map)['status'] == 'pending').length;
                final selectedCount = offers.where((d) => (d.data() as Map)['status'] == 'selected').length;
                if (offers.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: InkWell(
                    onTap: () => _showOffersDialog(property),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: selectedCount > 0
                            ? AirbnbColors.success.withValues(alpha: 0.08)
                            : AirbnbColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selectedCount > 0
                              ? AirbnbColors.success.withValues(alpha: 0.3)
                              : AirbnbColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selectedCount > 0 ? Icons.check_circle : Icons.handshake_rounded,
                            size: 16,
                            color: selectedCount > 0 ? AirbnbColors.success : AirbnbColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            selectedCount > 0
                                ? '중개사 선정 완료 (총 ${offers.length}건)'
                                : '중개 제안 $pendingCount건 대기',
                            style: AppTypography.caption.copyWith(color: selectedCount > 0 ? AirbnbColors.success : AirbnbColors.primary, fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 12,
                            color: selectedCount > 0 ? AirbnbColors.success : AirbnbColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            // 수정/삭제/연결 버튼
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                // 제안 보기 버튼
                OutlinedButton.icon(
                  onPressed: () => _showOffersDialog(property),
                  icon: const Icon(Icons.handshake_outlined, size: 18),
                  label: const Text('제안'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AirbnbColors.primary,
                    side: const BorderSide(color: AirbnbColors.primary),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                // 외부 매물이고 아직 연결 안 된 경우 "사용자 연결" 버튼
                if (property.isExternalListing && property.linkedUserId == null)
                  OutlinedButton.icon(
                    onPressed: () => _showLinkUserDialog(property),
                    icon: const Icon(Icons.person_add_alt, size: 18),
                    label: const Text('연결'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AirbnbColors.orange,
                      side: const BorderSide(color: AirbnbColors.orange),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: () => _editProperty(property),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('수정'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AirbnbColors.primary,
                    side: const BorderSide(color: AirbnbColors.primary),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showDeleteConfirmDialog(property),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('삭제'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AirbnbColors.error,
                    foregroundColor: AirbnbColors.background,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AirbnbColors.textSecondary),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style:  AppTypography.captionLarge.copyWith(color: AirbnbColors.textSecondary, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style:  AppTypography.withColor(AppTypography.captionLarge, AirbnbColors.textPrimary),
          ),
        ),
      ],
    );
  }

  /// 매물 삭제 확인 다이얼로그 (사유 입력 포함)
  Future<void> _showDeleteConfirmDialog(MLSProperty property) async {
    final propertyName = property.roadAddress;
    final reasonController = TextEditingController();
    String selectedReason = '허위 정보';

    final result = await showDialog<String?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('매물 삭제'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('정말로 "$propertyName" 매물을 삭제하시겠습니까?'),
                const SizedBox(height: 16),
                  Text(
                  '삭제 사유 선택',
                  style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                // 사유 선택 드롭다운
                DropdownButtonFormField<String>(
                  initialValue: selectedReason,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: '허위 정보', child: Text('허위 정보')),
                    DropdownMenuItem(value: '중복 등록', child: Text('중복 등록')),
                    DropdownMenuItem(value: '부적절한 내용', child: Text('부적절한 내용')),
                    DropdownMenuItem(value: '연락 불가', child: Text('연락 불가')),
                    DropdownMenuItem(value: '기타', child: Text('기타 (직접 입력)')),
                  ],
                  onChanged: (value) {
                    setDialogState(() => selectedReason = value ?? '허위 정보');
                  },
                ),
                // 기타 선택 시 직접 입력
                if (selectedReason == '기타') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonController,
                    decoration: InputDecoration(
                      hintText: '삭제 사유를 입력하세요',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    maxLines: 2,
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AirbnbColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AirbnbColors.warning.withValues(alpha: 0.3)),
                  ),
                  child:   Row(
                    children: [
                      Icon(Icons.info_outline, color: AirbnbColors.warning, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '삭제 시 매물 등록자에게 알림이 전송됩니다.',
                          style: AppTypography.withColor(AppTypography.captionLarge, AirbnbColors.warning),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                final reason = selectedReason == '기타'
                    ? (reasonController.text.trim().isEmpty ? '기타' : reasonController.text.trim())
                    : selectedReason;
                Navigator.pop(context, reason);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AirbnbColors.error,
                foregroundColor: AirbnbColors.background,
              ),
              child: const Text('삭제'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      await _deleteProperty(property, result);
    }
  }

  /// 매물 삭제 (알림 전송 포함)
  Future<void> _deleteProperty(MLSProperty property, String reason) async {
    try {
      final propertyId = property.id;
      if (propertyId.isEmpty) {
        if (mounted) {
          AppSnackBar.error(context, '매물 ID를 찾을 수 없습니다.');
        }
        return;
      }

      // 삭제 전에 소유자 정보 저장
      final ownerId = property.userId;
      final propertyName = property.roadAddress;

      // MLS 매물 삭제 (소프트 삭제)
      await _mlsService.updateProperty(propertyId, {
        'isDeleted': true,
        'isActive': false,
        'deletedAt': DateTime.now().toIso8601String(),
        'deletedReason': reason,
      });

      if (mounted) {
        // 소유자에게 알림 전송
        if (ownerId.isNotEmpty) {
          await _firebaseService.sendNotification(
            userId: ownerId,
            title: '매물 삭제 알림',
            message: '등록하신 매물 "$propertyName"이(가) 관리자에 의해 삭제되었습니다.\n\n사유: $reason',
            type: 'property_deleted',
            relatedId: propertyId,
          );
        }

        if (mounted) {
          AppSnackBar.success(context, '매물이 삭제되고 알림이 전송되었습니다.');
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, '일시적인 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.');
      }
    }
  }

  /// 중개 제안 목록 보기 + 선정 다이얼로그
  Future<void> _showOffersDialog(MLSProperty property) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.handshake_rounded, color: AirbnbColors.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      Text('중개 제안 목록', style: AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
                    Text(
                      property.roadAddress,
                      style:  AppTypography.withColor(AppTypography.caption, AirbnbColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.6,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('brokerOffers')
                  .where('propertyId', isEqualTo: property.id)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return   Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, size: 48, color: AirbnbColors.textLight),
                        SizedBox(height: 12),
                        Text('아직 제안이 없습니다', style: TextStyle(color: AirbnbColors.textSecondary)),
                        SizedBox(height: 4),
                        Text(
                          '공개 매물 페이지에서 중개사가 제안을 보낼 수 있습니다',
                          style: AppTypography.withColor(AppTypography.caption, AirbnbColors.textLight),
                        ),
                      ],
                    ),
                  );
                }

                final offers = docs.map((d) => BrokerOffer.fromMap(d.data() as Map<String, dynamic>)).toList();

                return ListView.separated(
                  itemCount: offers.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final offer = offers[index];
                    final isSelected = offer.status == BrokerOfferStatus.selected;
                    final isRejected = offer.status == BrokerOfferStatus.rejected;

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AirbnbColors.success.withValues(alpha: 0.05)
                            : isRejected
                                ? AirbnbColors.textSecondary.withValues(alpha: 0.05)
                                : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 상단: 이름 + 상태 배지
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: isSelected
                                    ? AirbnbColors.success.withValues(alpha: 0.1)
                                    : AirbnbColors.primary.withValues(alpha: 0.1),
                                child: Icon(
                                  isSelected ? Icons.check : Icons.person,
                                  size: 18,
                                  color: isSelected ? AirbnbColors.success : AirbnbColors.primary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      offer.brokerName,
                                      style: AppTypography.body.copyWith(color: isRejected ? AirbnbColors.textLight : AirbnbColors.textPrimary, fontWeight: FontWeight.w600),
                                    ),
                                    if (offer.brokerCompany != null)
                                      Text(
                                        offer.brokerCompany!,
                                        style: AppTypography.withColor(AppTypography.caption, isRejected ? AirbnbColors.textLight : AirbnbColors.textSecondary),
                                      ),
                                  ],
                                ),
                              ),
                              // 상태 배지
                              if (isSelected)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AirbnbColors.success,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child:   Text('선정', style: AppTypography.caption.copyWith(color: AirbnbColors.background, fontWeight: FontWeight.w600)),
                                )
                              else if (isRejected)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AirbnbColors.textSecondary,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child:   Text('미선정', style: AppTypography.caption.copyWith(color: AirbnbColors.background, fontWeight: FontWeight.w600)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // 전화번호
                          Row(
                            children: [
                              Icon(Icons.phone_outlined, size: 14, color: isRejected ? AirbnbColors.textLight : AirbnbColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                offer.brokerPhone,
                                style: AppTypography.withColor(AppTypography.captionLarge, isRejected ? AirbnbColors.textLight : AirbnbColors.textPrimary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),

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
                              style: AppTypography.captionLarge.copyWith(color: isRejected ? AirbnbColors.textLight : AirbnbColors.textPrimary, height: 1.4),
                            ),
                          ),
                          const SizedBox(height: 6),

                          // 제출 시각 + 선정 버튼
                          Row(
                            children: [
                              Text(
                                DateFormat('MM/dd HH:mm').format(offer.createdAt),
                                style:  AppTypography.withColor(AppTypography.caption, AirbnbColors.textLight),
                              ),
                              const Spacer(),
                              if (offer.status == BrokerOfferStatus.pending)
                                TextButton.icon(
                                  onPressed: () => _selectBrokerOffer(property, offer, offers),
                                  icon: const Icon(Icons.check_circle_outline, size: 16),
                                  label: const Text('이 중개사 선정'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AirbnbColors.success,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('닫기'),
            ),
          ],
        ),
      ),
    );
  }

  /// 중개사 선정 처리
  Future<void> _selectBrokerOffer(MLSProperty property, BrokerOffer selected, List<BrokerOffer> allOffers) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('중개사 선정'),
        content: Text(
          '${selected.brokerName}${selected.brokerCompany != null ? ' (${selected.brokerCompany})' : ''}을(를) 선정하시겠습니까?\n\n'
          '선정 후 다른 제안은 미선정 처리됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AirbnbColors.success,
              foregroundColor: AirbnbColors.background,
            ),
            child: const Text('선정'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final batch = FirebaseFirestore.instance.batch();

      // 선정된 제안: selected
      batch.update(
        FirebaseFirestore.instance.collection('brokerOffers').doc(selected.id),
        {
          'status': 'selected',
          'selectedAt': DateTime.now().toIso8601String(),
        },
      );

      // 나머지 제안: rejected
      for (final offer in allOffers) {
        if (offer.id != selected.id && offer.status == BrokerOfferStatus.pending) {
          batch.update(
            FirebaseFirestore.instance.collection('brokerOffers').doc(offer.id),
            {'status': 'rejected'},
          );
        }
      }

      // 매물의 selectedBrokerId 업데이트
      batch.update(
        FirebaseFirestore.instance.collection('mlsProperties').doc(property.id),
        {
          'finalBrokerId': selected.brokerId ?? selected.brokerName,
          'updatedAt': DateTime.now().toIso8601String(),
        },
      );

      await batch.commit();

      // 선정된 중개사에게 알림 (brokerId가 있는 경우)
      if (selected.brokerId != null) {
        FirebaseService().sendNotification(
          userId: selected.brokerId!,
          title: '축하합니다! 중개 제안이 선정되었습니다',
          message: '${property.roadAddress} 매물의 중개사로 선정되었습니다. 곧 매물 소유자와 연결해드리겠습니다.',
          type: 'broker_selected',
          relatedId: property.id,
        );
      }

      // 미선정된 중개사에게 알림 (brokerId가 있는 경우)
      for (final offer in allOffers) {
        if (offer.id != selected.id &&
            offer.status == BrokerOfferStatus.pending &&
            offer.brokerId != null) {
          FirebaseService().sendNotification(
            userId: offer.brokerId!,
            title: '중개 제안 결과 안내',
            message: '${property.roadAddress} 매물에 다른 중개사가 선정되었습니다. 다른 매물도 확인해보세요.',
            type: 'broker_rejected',
            relatedId: property.id,
          );
        }
      }

      if (mounted) {
        AppSnackBar.success(context, '${selected.brokerName}님이 선정되었습니다');
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, '선정에 실패했습니다. 잠시 후 다시 시도해 주세요.');
      }
    }
  }

  /// 외부 매물을 앱 사용자에게 연결하는 다이얼로그
  Future<void> _showLinkUserDialog(MLSProperty property) async {
    final searchController = TextEditingController();
    List<Map<String, dynamic>> searchResults = [];
    bool isSearching = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('사용자 연결', style: TextStyle(fontWeight: FontWeight.w600)),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 매물 정보
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AirbnbColors.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AirbnbColors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        property.roadAddress,
                        style:  AppTypography.captionLarge.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '외부 집주인: ${property.externalSellerName ?? ""}',
                        style:  AppTypography.withColor(AppTypography.caption, AirbnbColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 사용자 검색
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: '사용자 이름 또는 이메일로 검색',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    isDense: true,
                  ),
                  onChanged: (query) async {
                    if (query.length < 2) {
                      setDialogState(() => searchResults = []);
                      return;
                    }
                    setDialogState(() => isSearching = true);
                    try {
                      final snapshot = await FirebaseFirestore.instance
                          .collection('users')
                          .limit(50)
                          .get();
                      final queryLower = query.toLowerCase();
                      final results = snapshot.docs
                          .where((doc) {
                            final data = doc.data();
                            final name = (data['name'] ?? '').toString().toLowerCase();
                            final email = (data['email'] ?? '').toString().toLowerCase();
                            return name.contains(queryLower) || email.contains(queryLower);
                          })
                          .take(5)
                          .map((doc) => {'id': doc.id, ...doc.data()})
                          .toList();
                      setDialogState(() {
                        searchResults = results;
                        isSearching = false;
                      });
                    } catch (e) {
                      setDialogState(() => isSearching = false);
                    }
                  },
                ),
                const SizedBox(height: 8),

                // 검색 결과
                if (isSearching)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else if (searchResults.isNotEmpty)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: searchResults.length,
                      itemBuilder: (context, i) {
                        final user = searchResults[i];
                        final name = user['name'] ?? '이름 없음';
                        final email = user['email'] ?? '';
                        final uid = user['id'] ?? user['uid'] ?? '';
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: AirbnbColors.primary.withValues(alpha: 0.1),
                            child: const Icon(Icons.person, size: 18, color: AirbnbColors.primary),
                          ),
                          title: Text(name, style:  AppTypography.bodySmall),
                          subtitle: Text(email, style:  AppTypography.caption),
                          onTap: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                title: const Text('연결 확인'),
                                content: Text(
                                  '외부 매물 "${property.externalSellerName}"을\n'
                                  '앱 사용자 "$name"에게 연결하시겠습니까?\n\n'
                                  '연결 후 해당 사용자가 매물을 관리할 수 있게 됩니다.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('취소'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AirbnbColors.primary,
                                      foregroundColor: AirbnbColors.background,
                                    ),
                                    child: const Text('연결'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true) {
                              try {
                                await _mlsService.linkExternalPropertyToUser(
                                  propertyId: property.id,
                                  userId: uid,
                                  userName: name,
                                );
                                if (dialogContext.mounted) Navigator.pop(dialogContext);
                                if (mounted) {
                                  AppSnackBar.success(this.context, '$name님에게 매물이 연결되었습니다');
                                }
                              } catch (e) {
                                if (mounted) {
                                  AppSnackBar.error(this.context, '연결에 실패했습니다. 잠시 후 다시 시도해 주세요.');
                                }
                              }
                            }
                          },
                        );
                      },
                    ),
                  )
                else if (searchController.text.length >= 2)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        '검색 결과가 없습니다',
                        style: TextStyle(color: AirbnbColors.textSecondary),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('닫기'),
            ),
          ],
        ),
      ),
    );
  }
}
