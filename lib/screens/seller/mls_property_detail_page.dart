import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/mls_property.dart';
import '../../models/broker_offer.dart';
import '../../api_request/mls_property_service.dart';
import '../../api_request/firebase_service.dart';
import '../../utils/formatters.dart';
import '../../constants/apple_design_system.dart';
import '../../constants/app_constants.dart';
import '../../widgets/broker_profile_sheet.dart';
import 'mls_property_edit_page.dart';
import 'negotiation_section.dart';

/// 매물 상세 페이지 (통합)
/// - 매물 정보
/// - 중개사 참여 현황
/// - 수정/삭제 기능
class MLSPropertyDetailPage extends StatefulWidget {
  final MLSProperty property;

  const MLSPropertyDetailPage({required this.property, super.key});

  @override
  State<MLSPropertyDetailPage> createState() => _MLSPropertyDetailPageState();
}

class _MLSPropertyDetailPageState extends State<MLSPropertyDetailPage> {
  final _mlsService = MLSPropertyService();
  late MLSProperty _property;
  String _requestFilter = 'pending'; // 'pending', 'approved', 'all'

  /// 현재 사용자가 매물 소유자인지 확인
  bool get _isOwner {
    final currentUser = FirebaseAuth.instance.currentUser;
    return currentUser != null && currentUser.uid == _property.userId;
  }

  @override
  void initState() {
    super.initState();
    _property = widget.property;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AirbnbColors.surface,
      body: CustomScrollView(
        slivers: [
          // 앱바 with 이미지
          _buildSliverAppBar(),

          // 콘텐츠
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppleSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 매물 정보 카드
                  _buildPropertyInfoCard(),

                  const SizedBox(height: AppleSpacing.lg),

                  // 중개사 참여 현황
                  _buildBrokerParticipationSection(),

                  const SizedBox(height: AppleSpacing.lg),

                  // 중개 제안 목록
                  _buildBrokerOffersSection(),

                  // 협상 현황 (underOffer 이상)
                  if (_property.negotiations.isNotEmpty) ...[
                    const SizedBox(height: AppleSpacing.lg),
                    NegotiationSection(
                      property: _property,
                      onCounterOffer: (_property.status == PropertyStatus.underOffer ||
                              _property.status == PropertyStatus.inquiry)
                          ? () => _showCounterOfferDialog()
                          : null,
                    ),
                  ],

                  const SizedBox(height: AppleSpacing.xxl),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomActions(),
    );
  }

  Widget _buildSliverAppBar() {
    final hasImages = _property.imageUrls.isNotEmpty || _property.thumbnailUrl != null;
    final imageUrl = _property.thumbnailUrl ?? (_property.imageUrls.isNotEmpty ? _property.imageUrls.first : null);

    return SliverAppBar(
      expandedHeight: hasImages ? 280 : 120,
      pinned: true,
      backgroundColor: AirbnbColors.surface,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: hasImages && imageUrl != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    // 메모리 최적화: 캐시 크기 제한
                    cacheWidth: 800,
                    cacheHeight: 600,
                    errorBuilder: (_, _, _) => Container(
                      color: AirbnbColors.pillSecondary,
                      child: const Icon(Icons.image_not_supported, color: AirbnbColors.textLight, size: 48),
                    ),
                  ),
                  // 그라데이션 오버레이
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.3),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.5),
                        ],
                      ),
                    ),
                  ),
                  // 이미지 개수
                  if (_property.imageUrls.length > 1)
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.photo_library, color: Colors.white, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${_property.imageUrls.length}장',
                              style: AppleTypography.caption1.copyWith(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // 상태 뱃지 (소유자: 매물 상태, 중개사: 본인 요청 상태)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    child: _isOwner
                        ? _buildStatusBadge(_property.status)
                        : _buildBrokerStatusBadge(),
                  ),
                ],
              )
            : Container(
                color: AirbnbColors.pillSecondary,
                child: const Center(
                  child: Icon(Icons.home_outlined, color: AirbnbColors.textLight, size: 64),
                ),
              ),
      ),
    );
  }

  Widget _buildStatusBadge(PropertyStatus status) {
    Color color;
    String text;

    switch (status) {
      case PropertyStatus.active:
        color = AppleColors.systemGreen;
        text = '진행중';
        break;
      case PropertyStatus.inquiry:
        color = AirbnbColors.primary;
        text = '문의중';
        break;
      case PropertyStatus.underOffer:
        color = AppleColors.systemOrange;
        text = '협의중';
        break;
      case PropertyStatus.depositTaken:
        color = AppleColors.systemPurple;
        text = '가계약';
        break;
      case PropertyStatus.sold:
        color = AirbnbColors.textSecondary;
        text = '거래완료';
        break;
      default:
        color = AirbnbColors.textSecondary;
        text = '대기';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: AppleTypography.caption1.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// 중개사가 볼 때 자신의 요청 상태를 기반으로 뱃지 표시
  Widget _buildBrokerStatusBadge() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return _buildStatusBadge(_property.status);

    // 현재 중개사의 방문 요청 찾기
    final myRequests = _property.visitRequests
        .where((r) => r.brokerId == currentUser.uid || r.brokerId == currentUser.email)
        .toList();

    // 요청이 없으면 기본 매물 상태 표시
    if (myRequests.isEmpty) {
      return _buildStatusBadge(_property.status);
    }

    // 가장 최근 요청의 상태에 따라 뱃지 표시
    final latestRequest = myRequests.last;
    Color color;
    String text;

    switch (latestRequest.status) {
      case VisitRequestStatus.pending:
        color = AppleColors.systemOrange;
        text = '승인 대기';
        break;
      case VisitRequestStatus.approved:
        color = AppleColors.systemGreen;
        text = '승인됨';
        break;
      case VisitRequestStatus.rejected:
        color = AppleColors.systemRed;
        text = '거절됨';
        break;
      case VisitRequestStatus.reschedule:
        color = AirbnbColors.primary;
        text = '시간 조율';
        break;
      case VisitRequestStatus.cancelled:
        color = AirbnbColors.textSecondary;
        text = '취소됨';
        break;
      case VisitRequestStatus.expired:
        color = AirbnbColors.textLight;
        text = '만료됨';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        text,
        style: AppleTypography.caption1.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildPropertyInfoCard() {
    return AppleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 주소
          Text(
            _property.roadAddress,
            style: AppleTypography.title3.copyWith(fontWeight: FontWeight.w600),
          ),
          if (_property.buildingName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                _property.buildingName,
                style: AppleTypography.subheadline.copyWith(
                  color: AirbnbColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          if (_property.jibunAddress.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _property.jibunAddress,
                style: AppleTypography.caption1.copyWith(color: AirbnbColors.textSecondary),
              ),
            ),

          const SizedBox(height: AppleSpacing.md),
          const Divider(height: 1),
          const SizedBox(height: AppleSpacing.md),

          // 가격
          Row(
            children: [
              const Icon(Icons.sell_outlined, size: 20, color: AirbnbColors.textSecondary),
              const SizedBox(width: 8),
              Text('희망가', style: AppleTypography.subheadline.copyWith(color: AirbnbColors.textSecondary)),
              const Spacer(),
              Text(
                _formatPrice(_property.desiredPrice),
                style: AppleTypography.title2.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AirbnbColors.primary,
                ),
              ),
              if (_property.negotiable)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppleColors.systemOrange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '협의가능',
                      style: AppleTypography.caption2.copyWith(
                        color: AppleColors.systemOrange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // 상세 정보 (있는 경우)
          if (_property.floor != null || _property.rooms != null || _property.bathrooms != null || _property.direction != null) ...[
            const SizedBox(height: AppleSpacing.md),
            const Divider(height: 1),
            const SizedBox(height: AppleSpacing.md),

            Text(
              '매물 정보',
              style: AppleTypography.caption1.copyWith(
                color: AirbnbColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppleSpacing.sm),

            Wrap(
              spacing: AppleSpacing.sm,
              runSpacing: AppleSpacing.sm,
              children: [
                if (_property.floor != null)
                  _buildInfoChip(Icons.layers, '${_property.floor}층'),
                if (_property.rooms != null)
                  _buildInfoChip(Icons.meeting_room, '방 ${_property.rooms}개'),
                if (_property.bathrooms != null)
                  _buildInfoChip(Icons.bathroom_outlined, '화장실 ${_property.bathrooms}개'),
                if (_property.direction != null)
                  _buildInfoChip(Icons.explore, _property.direction!),
              ],
            ),
          ],

          // 옵션 (있는 경우)
          if (_property.options.isNotEmpty) ...[
            const SizedBox(height: AppleSpacing.md),
            const Divider(height: 1),
            const SizedBox(height: AppleSpacing.md),

            Text(
              '옵션',
              style: AppleTypography.caption1.copyWith(
                color: AirbnbColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppleSpacing.sm),

            Wrap(
              spacing: AppleSpacing.xs,
              runSpacing: AppleSpacing.xs,
              children: _property.options.map((option) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AirbnbColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    option,
                    style: AppleTypography.caption1.copyWith(
                      color: AirbnbColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          // 추가 설명 (있는 경우)
          if (_property.notes != null && _property.notes!.isNotEmpty) ...[
            const SizedBox(height: AppleSpacing.md),
            const Divider(height: 1),
            const SizedBox(height: AppleSpacing.md),

            Text(
              '추가 설명',
              style: AppleTypography.caption1.copyWith(
                color: AirbnbColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppleSpacing.sm),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppleSpacing.md),
              decoration: BoxDecoration(
                color: AirbnbColors.pillSecondary,
                borderRadius: BorderRadius.circular(AppleRadius.sm),
              ),
              child: Text(
                _property.notes!,
                style: AppleTypography.body.copyWith(
                  color: AirbnbColors.textPrimary,
                  height: 1.5,
                ),
              ),
            ),
          ],

          // 방문 가능 시간 (있는 경우)
          if (_property.availableSlots.isNotEmpty) ...[
            const SizedBox(height: AppleSpacing.md),
            const Divider(height: 1),
            const SizedBox(height: AppleSpacing.md),

            Text(
              '방문 가능 시간',
              style: AppleTypography.caption1.copyWith(
                color: AirbnbColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppleSpacing.sm),

            _buildAvailabilityDisplay(),
          ],

          // 등록일
          const SizedBox(height: AppleSpacing.md),
          const Divider(height: 1),
          const SizedBox(height: AppleSpacing.sm),
          Row(
            children: [
              const Icon(Icons.access_time, size: 16, color: AirbnbColors.textLight),
              const SizedBox(width: 4),
              Text(
                '등록 ${_formatTimeAgo(_property.createdAt)}',
                style: AppleTypography.caption1.copyWith(color: AirbnbColors.textLight),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 방문 가능 시간 표시
  Widget _buildAvailabilityDisplay() {
    const weekdayNames = ['', '월', '화', '수', '목', '금', '토', '일'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 요일별 표시
        Wrap(
          spacing: AppleSpacing.xs,
          runSpacing: AppleSpacing.xs,
          children: [
            for (int i = 1; i <= 7; i++)
              if (_property.availableSlots['$i']?.isNotEmpty ?? false)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppleColors.systemGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppleColors.systemGreen.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${weekdayNames[i]}요일',
                        style: AppleTypography.caption1.copyWith(
                          color: AppleColors.systemGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_property.availableSlots['$i']!.length}개',
                        style: AppleTypography.caption2.copyWith(
                          color: AppleColors.systemGreen,
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),

        // 상세 시간대
        const SizedBox(height: AppleSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppleSpacing.sm),
          decoration: BoxDecoration(
            color: AirbnbColors.pillSecondary,
            borderRadius: BorderRadius.circular(AppleRadius.sm),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 1; i <= 7; i++)
                if (_property.availableSlots['$i']?.isNotEmpty ?? false)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 50,
                          child: Text(
                            '${weekdayNames[i]}요일',
                            style: AppleTypography.caption1.copyWith(
                              color: AirbnbColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            _property.availableSlots['$i']!
                                .map((slot) => '${slot.startTime}~${slot.endTime}')
                                .join(', '),
                            style: AppleTypography.caption1.copyWith(
                              color: AirbnbColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AirbnbColors.pillSecondary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AirbnbColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppleTypography.caption1.copyWith(color: AirbnbColors.textPrimary),
          ),
        ],
      ),
    );
  }

  /// 방문 요청 관리 섹션 (핵심 기능)
  Widget _buildBrokerParticipationSection() {
    final allRequests = _property.visitRequests;
    final pendingRequests = allRequests.where((r) =>
        r.status == VisitRequestStatus.pending ||
        r.status == VisitRequestStatus.reschedule).toList();
    final approvedRequests = allRequests.where((r) =>
        r.status == VisitRequestStatus.approved).toList();

    // 필터링
    List<VisitRequest> displayRequests;
    switch (_requestFilter) {
      case 'pending':
        displayRequests = pendingRequests;
        break;
      case 'approved':
        displayRequests = approvedRequests;
        break;
      default:
        displayRequests = allRequests.toList();
    }

    // 정렬: 희망가 높은 순, 같으면 최신순
    displayRequests.sort((a, b) {
      final priceCompare = b.proposedPrice.compareTo(a.proposedPrice);
      if (priceCompare != 0) return priceCompare;
      return b.createdAt.compareTo(a.createdAt);
    });

    // 중개사 현황 (소유자에게만 표시)
    final viewedBrokers = _property.brokerResponses.values
        .where((b) => b.hasViewed).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 중개사 현황 요약 - 소유자(판매자)에게만 표시
        if (_isOwner) ...[
          AppleCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '중개사 현황',
                  style: AppleTypography.caption1.copyWith(
                    color: AirbnbColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppleSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatColumn(
                        icon: Icons.visibility_outlined,
                        value: '$viewedBrokers',
                        label: '열람',
                        color: AppleColors.systemGreen,
                      ),
                    ),
                    Expanded(
                      child: _buildStatColumn(
                        icon: Icons.schedule_outlined,
                        value: '${pendingRequests.length}',
                        label: '대기',
                        color: AppleColors.systemOrange,
                      ),
                    ),
                    Expanded(
                      child: _buildStatColumn(
                        icon: Icons.check_circle_outline,
                        value: '${approvedRequests.length}',
                        label: '승인',
                        color: AppleColors.systemPurple,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppleSpacing.lg),

          // 배포 중개사 목록
          if (_property.brokerResponses.isNotEmpty)
            AppleCard(
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(top: 4),
                  title: Text(
                    '배포 중개사 목록 (${_property.brokerResponses.length}명)',
                    style: AppleTypography.caption1.copyWith(
                      color: AirbnbColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  children: _property.brokerResponses.values.map((broker) {
                    final displayName = broker.brokerCompany?.isNotEmpty == true
                        ? broker.brokerCompany!
                        : broker.brokerName;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            broker.hasViewed ? Icons.visibility : Icons.visibility_off_outlined,
                            size: 16,
                            color: broker.hasViewed ? AppleColors.systemGreen : AirbnbColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              displayName,
                              style: AppleTypography.callout,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            broker.hasViewed ? '열람함' : '미열람',
                            style: AppleTypography.caption2.copyWith(
                              color: broker.hasViewed ? AppleColors.systemGreen : AirbnbColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          const SizedBox(height: AppleSpacing.lg),
        ],

        // 방문 요청 섹션 (소유자에게만 표시)
        if (_isOwner) ...[
          Row(
            children: [
              Text(
                '방문 요청',
                style: AppleTypography.title3.copyWith(fontWeight: FontWeight.w600),
              ),
              if (pendingRequests.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppleColors.systemOrange,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${pendingRequests.length}',
                    style: AppleTypography.caption1.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppleSpacing.sm),

          // 필터 탭
          Row(
            children: [
              _buildFilterChip('pending', '대기중', pendingRequests.length),
              const SizedBox(width: AppleSpacing.xs),
              _buildFilterChip('approved', '승인됨', approvedRequests.length),
              const SizedBox(width: AppleSpacing.xs),
              _buildFilterChip('all', '전체', allRequests.length),
            ],
          ),
          const SizedBox(height: AppleSpacing.md),

          // 방문 요청 리스트
          if (displayRequests.isEmpty)
            Container(
              padding: const EdgeInsets.all(AppleSpacing.xl),
              decoration: BoxDecoration(
                color: AirbnbColors.pillSecondary,
                borderRadius: BorderRadius.circular(AppleRadius.md),
              ),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.schedule_outlined, size: 48, color: AirbnbColors.textLight),
                    const SizedBox(height: AppleSpacing.sm),
                    Text(
                      _requestFilter == 'pending'
                          ? '대기 중인 방문 요청이 없습니다'
                          : _requestFilter == 'approved'
                              ? '승인된 방문 요청이 없습니다'
                              : '방문 요청이 없습니다',
                      style: AppleTypography.body.copyWith(color: AirbnbColors.textSecondary),
                    ),
                    const SizedBox(height: AppleSpacing.xs),
                    Text(
                      '중개사가 매수 희망자를 데리고\n방문 요청을 보내면 여기에 표시됩니다',
                      style: AppleTypography.caption1.copyWith(color: AirbnbColors.textLight),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            ...displayRequests.map((request) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppleSpacing.sm),
                child: _buildVisitRequestCard(request),
              );
            }),
        ] else ...[
          // 중개사가 볼 때: 본인의 방문 요청 상태만 표시
          _buildMyRequestStatus(),
        ],
      ],
    );
  }

  /// 매도자 역제안 다이얼로그
  void _showCounterOfferDialog() {
    // 가장 최근 중개사 제안 찾기
    final latestBrokerLog = _property.negotiations
        .where((n) => !n.id.startsWith('counter_'))
        .lastOrNull;
    if (latestBrokerLog == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('역제안할 중개사 제안이 없습니다')),
      );
      return;
    }

    final priceController = TextEditingController();
    final conditionsController = TextEditingController();
    final messageController = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.reply, color: AirbnbColors.primary, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('역제안하기',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${latestBrokerLog.brokerName}의 제안가: ${PriceFormatter.format(latestBrokerLog.proposedPrice)}',
                  style: const TextStyle(
                      fontSize: 13, color: AirbnbColors.textSecondary),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: '역제안 가격 (만원)',
                    hintText: '예: 50000',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: conditionsController,
                  decoration: InputDecoration(
                    labelText: '조건 (선택)',
                    hintText: '잔금일, 포함 옵션 등',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: messageController,
                  decoration: InputDecoration(
                    labelText: '메시지 (선택)',
                    hintText: '중개사에게 전달할 메시지',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final priceText = priceController.text.trim();
                      if (priceText.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('가격을 입력해주세요')),
                        );
                        return;
                      }
                      final price = double.tryParse(priceText);
                      if (price == null || price <= 0) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('올바른 가격을 입력해주세요')),
                        );
                        return;
                      }
                      setDialogState(() => isSaving = true);
                      try {
                        await MLSPropertyService().addSellerCounterOffer(
                          propertyId: _property.id,
                          brokerId: latestBrokerLog.brokerId,
                          brokerName: latestBrokerLog.brokerName,
                          counterPrice: price,
                          conditions: conditionsController.text.trim().isEmpty
                              ? null
                              : conditionsController.text.trim(),
                          message: messageController.text.trim().isEmpty
                              ? null
                              : messageController.text.trim(),
                        );
                        // 성공 확인 UI를 잠시 보여준 뒤 닫기
                        setDialogState(() => isSaving = false);
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(
                              content: Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Text('역제안을 전송했습니다'),
                                ],
                              ),
                              backgroundColor: AppleColors.systemGreen,
                              duration: Duration(seconds: 2),
                            ),
                          );
                          await Future.delayed(const Duration(milliseconds: 500));
                          if (dialogContext.mounted) Navigator.pop(dialogContext);
                        }
                        if (mounted) {
                          final updated = await MLSPropertyService()
                              .getProperty(_property.id);
                          if (updated != null && mounted) {
                            setState(() => _property = updated);
                          }
                        }
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('역제안 실패: $e')),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AirbnbColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('역제안 보내기'),
            ),
          ],
        ),
      ),
    );
  }

  /// 중개 제안 목록 섹션
  Widget _buildBrokerOffersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.handshake_rounded, size: 20, color: AirbnbColors.primary),
            const SizedBox(width: 8),
            Text(
              '중개 제안',
              style: AppleTypography.headline.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('brokerOffers')
              .where('propertyId', isEqualTo: _property.id)
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(strokeWidth: 2),
              ));
            }
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AirbnbColors.pillSecondary,
                  borderRadius: BorderRadius.circular(AppleRadius.md),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.inbox_outlined, size: 36, color: AirbnbColors.textLight),
                    SizedBox(height: 8),
                    Text(
                      '아직 중개 제안이 없습니다',
                      style: TextStyle(color: AirbnbColors.textSecondary, fontSize: 14),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '공개 매물 페이지에서 중개사가 제안을 보낼 수 있습니다',
                      style: TextStyle(color: AirbnbColors.textLight, fontSize: 12),
                    ),
                  ],
                ),
              );
            }

            final offers = docs.map((d) =>
                BrokerOffer.fromMap(d.data() as Map<String, dynamic>)).toList();

            return Column(
              children: offers.map((offer) {
                final isSelected = offer.status == BrokerOfferStatus.selected;
                final isRejected = offer.status == BrokerOfferStatus.rejected;

                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppleColors.systemGreen.withValues(alpha: 0.06)
                        : AirbnbColors.pillSecondary,
                    borderRadius: BorderRadius.circular(AppleRadius.md),
                    border: isSelected
                        ? Border.all(color: AppleColors.systemGreen.withValues(alpha: 0.3))
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 이름 + 상태
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: isSelected
                                ? AppleColors.systemGreen.withValues(alpha: 0.1)
                                : AirbnbColors.primary.withValues(alpha: 0.1),
                            child: Icon(
                              isSelected ? Icons.check : Icons.person,
                              size: 16,
                              color: isSelected ? AppleColors.systemGreen : AirbnbColors.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  offer.brokerName,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: isRejected ? AirbnbColors.textLight : AirbnbColors.textPrimary,
                                  ),
                                ),
                                if (offer.brokerCompany != null)
                                  Text(
                                    offer.brokerCompany!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isRejected ? AirbnbColors.textLight : AirbnbColors.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppleColors.systemGreen,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text('선정', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                            )
                          else if (isRejected)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AirbnbColors.textLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text('미선정', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // 전화번호
                      Row(
                        children: [
                          Icon(Icons.phone_outlined, size: 13, color: isRejected ? AirbnbColors.textLight : AirbnbColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            offer.brokerPhone,
                            style: TextStyle(fontSize: 13, color: isRejected ? AirbnbColors.textLight : AirbnbColors.textPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // 어필 한마디
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AirbnbColors.surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          offer.pitch,
                          style: TextStyle(
                            fontSize: 13,
                            color: isRejected ? AirbnbColors.textLight : AirbnbColors.textPrimary,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // 제출 시각 + 선정 버튼
                      Row(
                        children: [
                          Text(
                            DateFormat('MM/dd HH:mm').format(offer.createdAt),
                            style: const TextStyle(fontSize: 11, color: AirbnbColors.textLight),
                          ),
                          const Spacer(),
                          if (offer.status == BrokerOfferStatus.pending)
                            GestureDetector(
                              onTap: () => _selectBrokerOffer(offer, offers),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppleColors.systemGreen.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppleColors.systemGreen.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  '이 중개사 선정',
                                  style: AppleTypography.caption1.copyWith(
                                    color: AppleColors.systemGreen,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  /// 매도인이 중개사 선정
  Future<void> _selectBrokerOffer(BrokerOffer selected, List<BrokerOffer> allOffers) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('중개사 선정'),
        content: Text(
          '${selected.brokerName}${selected.brokerCompany != null ? ' (${selected.brokerCompany})' : ''}을(를) 선정하시겠습니까?\n\n선정 후 다른 제안은 미선정 처리됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppleColors.systemGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('선정'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final batch = FirebaseFirestore.instance.batch();

      // 선정된 제안
      batch.update(
        FirebaseFirestore.instance.collection('brokerOffers').doc(selected.id),
        {'status': 'selected', 'selectedAt': DateTime.now().toIso8601String()},
      );

      // 나머지 제안 미선정
      for (final offer in allOffers) {
        if (offer.id != selected.id && offer.status == BrokerOfferStatus.pending) {
          batch.update(
            FirebaseFirestore.instance.collection('brokerOffers').doc(offer.id),
            {'status': 'rejected'},
          );
        }
      }

      await batch.commit();

      // 선정 중개사 알림
      final notificationService = FirebaseService();
      if (selected.brokerId != null) {
        await notificationService.sendNotification(
          userId: selected.brokerId!,
          type: 'broker_selected',
          title: '중개사 선정',
          message: '${_property.roadAddress} 매물의 중개사로 선정되었습니다.',
          relatedId: _property.id,
        );
      }

      // 미선정 중개사 알림
      for (final offer in allOffers) {
        if (offer.id != selected.id && offer.brokerId != null && offer.status == BrokerOfferStatus.pending) {
          await notificationService.sendNotification(
            userId: offer.brokerId!,
            type: 'broker_rejected',
            title: '중개 제안 결과',
            message: '${_property.roadAddress} 매물에서 다른 중개사가 선정되었습니다.',
            relatedId: _property.id,
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${selected.brokerName} 중개사가 선정되었습니다.'),
            backgroundColor: AppleColors.systemGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('선정에 실패했습니다.'), backgroundColor: AppleColors.systemRed),
        );
      }
    }
  }

  Widget _buildStatColumn({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppleTypography.title3.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: AppleTypography.caption2.copyWith(
            color: AirbnbColors.textSecondary,
          ),
        ),
      ],
    );
  }

  /// 중개사가 자신의 방문 요청 상태를 볼 때 표시
  Widget _buildMyRequestStatus() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    // 현재 사용자(중개사)의 방문 요청 찾기
    final myRequests = _property.visitRequests
        .where((r) => r.brokerId == currentUser.uid || r.brokerId == currentUser.email)
        .toList();

    if (myRequests.isEmpty) {
      // 아직 방문 요청을 하지 않은 상태
      return Container(
        padding: const EdgeInsets.all(AppleSpacing.lg),
        decoration: BoxDecoration(
          color: AirbnbColors.pillSecondary,
          borderRadius: BorderRadius.circular(AppleRadius.md),
        ),
        child: Column(
          children: [
            const Icon(Icons.home_work_outlined, size: 48, color: AirbnbColors.primary),
            const SizedBox(height: AppleSpacing.sm),
            Text(
              '매물 상세 정보',
              style: AppleTypography.headline.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppleSpacing.xs),
            Text(
              '관심이 있으시면 방문 요청을 보내보세요',
              style: AppleTypography.caption1.copyWith(color: AirbnbColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // 가장 최근 요청
    final latestRequest = myRequests.last;
    final statusInfo = _getRequestStatusInfo(latestRequest.status);

    return AppleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '나의 방문 요청',
            style: AppleTypography.headline.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppleSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppleSpacing.md),
            decoration: BoxDecoration(
              color: statusInfo.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppleRadius.sm),
            ),
            child: Row(
              children: [
                Icon(statusInfo.icon, color: statusInfo.color, size: 24),
                const SizedBox(width: AppleSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusInfo.label,
                        style: AppleTypography.subheadline.copyWith(
                          fontWeight: FontWeight.w600,
                          color: statusInfo.color,
                        ),
                      ),
                      Text(
                        statusInfo.description,
                        style: AppleTypography.caption1.copyWith(
                          color: AirbnbColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppleSpacing.md),
          // 요청 정보
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('희망가', style: AppleTypography.caption1.copyWith(color: AirbnbColors.textLight)),
                    Text(_formatPrice(latestRequest.proposedPrice), style: AppleTypography.body.copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('방문 희망일', style: AppleTypography.caption1.copyWith(color: AirbnbColors.textLight)),
                    Text(_formatDateTime(latestRequest.requestedDateTime), style: AppleTypography.body.copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          // 승인된 경우 판매자 연락처 표시 (탭하면 전화 연결)
          if (latestRequest.status == VisitRequestStatus.approved && latestRequest.sellerPhone != null) ...[
            const SizedBox(height: AppleSpacing.md),
            GestureDetector(
              onTap: () => _callSeller(latestRequest.sellerPhone!),
              child: Container(
                padding: const EdgeInsets.all(AppleSpacing.md),
                decoration: BoxDecoration(
                  color: AppleColors.systemGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppleRadius.sm),
                  border: Border.all(color: AppleColors.systemGreen.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.phone, color: AppleColors.systemGreen, size: 20),
                    const SizedBox(width: AppleSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '판매자 연락처',
                            style: AppleTypography.caption1.copyWith(
                              color: AppleColors.systemGreen,
                            ),
                          ),
                          Text(
                            latestRequest.sellerPhone!,
                            style: AppleTypography.headline.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppleColors.systemGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppleColors.systemGreen,
                        borderRadius: BorderRadius.circular(AppleRadius.sm),
                      ),
                      child: const Icon(Icons.call, color: Colors.white, size: 20),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 방문 요청 상태별 정보 반환
  ({String label, String description, IconData icon, Color color}) _getRequestStatusInfo(VisitRequestStatus status) {
    return switch (status) {
      VisitRequestStatus.pending => (
          label: '승인 대기 중',
          description: '판매자가 요청을 검토하고 있습니다',
          icon: Icons.schedule,
          color: AppleColors.systemOrange,
        ),
      VisitRequestStatus.approved => (
          label: '승인됨',
          description: '연락처가 교환되었습니다. 판매자에게 연락하세요!',
          icon: Icons.check_circle,
          color: AppleColors.systemGreen,
        ),
      VisitRequestStatus.rejected => (
          label: '거절됨',
          description: '판매자가 요청을 거절했습니다',
          icon: Icons.cancel,
          color: AppleColors.systemRed,
        ),
      VisitRequestStatus.reschedule => (
          label: '다른 시간 제안',
          description: '판매자가 다른 시간을 제안했습니다',
          icon: Icons.event_repeat,
          color: AirbnbColors.primary,
        ),
      VisitRequestStatus.cancelled => (
          label: '취소됨',
          description: '요청이 취소되었습니다',
          icon: Icons.remove_circle_outline,
          color: AirbnbColors.textLight,
        ),
      VisitRequestStatus.expired => (
          label: '만료됨',
          description: '요청이 만료되었습니다',
          icon: Icons.timer_off,
          color: AirbnbColors.textLight,
        ),
    };
  }

  Widget _buildFilterChip(String value, String label, int count) {
    final isSelected = _requestFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _requestFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AirbnbColors.primary : AirbnbColors.pillSecondary,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppleTypography.caption1.copyWith(
                color: isSelected ? Colors.white : AirbnbColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.3)
                      : AirbnbColors.pillSecondary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: AppleTypography.caption2.copyWith(
                    color: isSelected ? Colors.white : AirbnbColors.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 방문 요청 카드
  Widget _buildVisitRequestCard(VisitRequest request) {
    final isPending = request.status == VisitRequestStatus.pending;
    final isApproved = request.status == VisitRequestStatus.approved;
    final isReschedule = request.status == VisitRequestStatus.reschedule;

    Color statusColor;
    String statusText;
    switch (request.status) {
      case VisitRequestStatus.pending:
        statusColor = AppleColors.systemOrange;
        statusText = '응답 대기';
        break;
      case VisitRequestStatus.approved:
        statusColor = AppleColors.systemGreen;
        statusText = '승인됨';
        break;
      case VisitRequestStatus.rejected:
        statusColor = AppleColors.systemRed;
        statusText = '거절됨';
        break;
      case VisitRequestStatus.reschedule:
        statusColor = AirbnbColors.primary;
        statusText = '시간 조율';
        break;
      case VisitRequestStatus.cancelled:
        statusColor = AirbnbColors.textSecondary;
        statusText = '취소됨';
        break;
      case VisitRequestStatus.expired:
        statusColor = AirbnbColors.textLight;
        statusText = '만료됨';
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: isPending
            ? AppleColors.systemOrange.withValues(alpha: 0.05)
            : AirbnbColors.pillSecondary,
        borderRadius: BorderRadius.circular(AppleRadius.lg),
        border: isPending
            ? Border.all(color: AppleColors.systemOrange.withValues(alpha: 0.3))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppleSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더: 중개사 정보 + 상태
          Row(
            children: [
              // 중개사 프로필 (클릭 가능)
              GestureDetector(
                onTap: () => _showBrokerProfile(request),
                child: Row(
                  children: [
                    // 중개사 아이콘
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AirbnbColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_outline,
                        color: AirbnbColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppleSpacing.sm),

                    // 중개사 이름/회사
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              request.brokerName,
                              style: AppleTypography.headline.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.info_outline, size: 16, color: AirbnbColors.primary),
                          ],
                        ),
                        if (request.brokerCompany != null)
                          Text(
                            request.brokerCompany!,
                            style: AppleTypography.caption1.copyWith(color: AirbnbColors.textSecondary),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),

              // 상태 뱃지
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  statusText,
                  style: AppleTypography.caption1.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppleSpacing.md),
          const Divider(height: 1),
          const SizedBox(height: AppleSpacing.md),

          // 희망가
          Row(
            children: [
              const Icon(Icons.attach_money, size: 18, color: AirbnbColors.textSecondary),
              const SizedBox(width: 4),
              Text('희망가', style: AppleTypography.caption1.copyWith(color: AirbnbColors.textSecondary)),
              const Spacer(),
              Text(
                _formatPrice(request.proposedPrice),
                style: AppleTypography.title3.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppleColors.systemGreen,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppleSpacing.xs),

          // 방문 희망 일시
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 18, color: AirbnbColors.textSecondary),
              const SizedBox(width: 4),
              Text('희망일시', style: AppleTypography.caption1.copyWith(color: AirbnbColors.textSecondary)),
              const Spacer(),
              Text(
                _formatDateTime(request.requestedDateTime),
                style: AppleTypography.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AirbnbColors.textPrimary,
                ),
              ),
            ],
          ),

          // 메시지 (있는 경우)
          if (request.message != null && request.message!.isNotEmpty) ...[
            const SizedBox(height: AppleSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppleSpacing.sm),
              decoration: BoxDecoration(
                color: AirbnbColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppleRadius.sm),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.chat_bubble_outline, size: 16, color: AirbnbColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      request.message!,
                      style: AppleTypography.caption1.copyWith(
                        color: AirbnbColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 승인된 경우: 연락처 표시 (탭하면 전화 연결)
          if (isApproved && request.brokerPhone != null) ...[
            const SizedBox(height: AppleSpacing.md),
            GestureDetector(
              onTap: () => _callBroker(request.brokerPhone!),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppleSpacing.md),
                decoration: BoxDecoration(
                  color: AppleColors.systemGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppleRadius.md),
                  border: Border.all(color: AppleColors.systemGreen.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.phone, size: 20, color: AppleColors.systemGreen),
                    const SizedBox(width: AppleSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '중개사 연락처',
                            style: AppleTypography.caption1.copyWith(
                              color: AppleColors.systemGreen,
                            ),
                          ),
                          Text(
                            request.brokerPhone!,
                            style: AppleTypography.headline.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppleColors.systemGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppleColors.systemGreen,
                        borderRadius: BorderRadius.circular(AppleRadius.sm),
                      ),
                      child: const Icon(Icons.call, color: Colors.white, size: 20),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // 다른 시간 제안인 경우
          if (isReschedule && request.alternativeDateTime != null) ...[
            const SizedBox(height: AppleSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppleSpacing.sm),
              decoration: BoxDecoration(
                color: AirbnbColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppleRadius.sm),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule, size: 16, color: AirbnbColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    '제안 시간: ${_formatDateTime(request.alternativeDateTime!)}',
                    style: AppleTypography.caption1.copyWith(
                      color: AirbnbColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 액션 버튼 (대기 중인 경우)
          if (isPending) ...[
            const SizedBox(height: AppleSpacing.md),
            Row(
              children: [
                // 거절 버튼
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _rejectRequest(request),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppleColors.systemRed,
                      side: BorderSide(color: AppleColors.systemRed.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('거절'),
                    ),
                  ),
                ),
                const SizedBox(width: AppleSpacing.xs),

                // 다른 시간 제안 버튼
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _suggestAlternativeTime(request),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AirbnbColors.primary,
                      side: BorderSide(color: AirbnbColors.primary.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('다른 시간'),
                    ),
                  ),
                ),
                const SizedBox(width: AppleSpacing.xs),

                // 승인 버튼
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _approveRequest(request),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppleColors.systemGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('승인'),
                    ),
                  ),
                ),
              ],
            ),
          ],

          // 요청 시간
          const SizedBox(height: AppleSpacing.sm),
          Text(
            '요청: ${_formatTimeAgo(request.createdAt)}',
            style: AppleTypography.caption2.copyWith(color: AirbnbColors.textLight),
          ),
        ],
      ),
    );
  }

  /// 방문 요청 승인
  void _approveRequest(VisitRequest request) {
    final phoneController = TextEditingController();
    final messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('방문 요청 승인'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${request.brokerName} 중개사의 방문 요청을 승인하시겠습니까?'),
              const SizedBox(height: 16),

              // 요청 정보 요약
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AirbnbColors.pillSecondary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('희망가: ', style: TextStyle(color: AirbnbColors.textSecondary, fontSize: 13)),
                        Text(
                          _formatPrice(request.proposedPrice),
                          style: const TextStyle(fontWeight: FontWeight.w600, color: AppleColors.systemGreen),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text('방문일시: ', style: TextStyle(color: AirbnbColors.textSecondary, fontSize: 13)),
                        Text(
                          _formatDateTime(request.requestedDateTime),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 안내 메시지
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppleColors.systemGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: AppleColors.systemGreen),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '승인 시 연락처가 상호 교환됩니다',
                        style: TextStyle(
                          color: AppleColors.systemGreen,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 연락처 입력
              Text('내 연락처 *', style: AppleTypography.subheadline.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: '010-0000-0000',
                  filled: true,
                  fillColor: AirbnbColors.pillSecondary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),

              // 메시지 (선택)
              Text('메시지 (선택)', style: AppleTypography.subheadline.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: messageController,
                maxLines: 2,
                maxLength: 100,
                decoration: InputDecoration(
                  hintText: '중개사에게 전달할 메시지',
                  filled: true,
                  fillColor: AirbnbColors.pillSecondary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(12),
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
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              if (phoneController.text.trim().isEmpty) {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text('연락처를 입력해주세요')),
                );
                return;
              }

              Navigator.pop(context);

              try {
                await _mlsService.approveVisitRequest(
                  propertyId: _property.id,
                  requestId: request.id,
                  sellerPhone: phoneController.text.trim(),
                  sellerMessage: messageController.text.trim().isNotEmpty
                      ? messageController.text.trim()
                      : null,
                );

                // 매물 정보 새로고침
                final updated = await _mlsService.getProperty(_property.id);
                if (updated != null && mounted) {
                  setState(() => _property = updated);
                }

                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        '승인 완료! ${request.brokerName} 중개사가 곧 연락드릴 예정입니다.\n'
                        '방문 일정은 중개사와 직접 조율해 주세요.',
                      ),
                      backgroundColor: AppleColors.systemGreen,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('승인 처리에 실패했습니다. 잠시 후 다시 시도해 주세요.'),
                      backgroundColor: AppleColors.systemRed,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppleColors.systemGreen,
            ),
            child: const Text('승인'),
          ),
        ],
      ),
    );
  }

  /// 방문 요청 거절
  void _rejectRequest(VisitRequest request) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('방문 요청 거절'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${request.brokerName} 중개사의 방문 요청을 거절하시겠습니까?'),
            const SizedBox(height: 16),
            Text('거절 사유 (선택)', style: AppleTypography.subheadline.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              maxLines: 2,
              maxLength: 100,
              decoration: InputDecoration(
                hintText: '사유를 입력해주세요 (선택)',
                filled: true,
                fillColor: AirbnbColors.pillSecondary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);

              try {
                await _mlsService.rejectVisitRequest(
                  propertyId: _property.id,
                  requestId: request.id,
                  reason: reasonController.text.trim().isNotEmpty
                      ? reasonController.text.trim()
                      : null,
                );

                // 매물 정보 새로고침
                final updated = await _mlsService.getProperty(_property.id);
                if (updated != null && mounted) {
                  setState(() => _property = updated);
                }

                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('방문 요청이 거절되었습니다'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('거절 처리에 실패했습니다. 잠시 후 다시 시도해 주세요.'),
                      backgroundColor: AppleColors.systemRed,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppleColors.systemRed),
            child: const Text('거절'),
          ),
        ],
      ),
    );
  }

  /// 다른 시간 제안
  void _suggestAlternativeTime(VisitRequest request) {
    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    final messageController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: AirbnbColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppleSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 핸들바
                  Center(
                    child: Container(
                      width: 36,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AirbnbColors.border,
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppleSpacing.lg),

                  Text(
                    '다른 시간 제안',
                    style: AppleTypography.title2.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AppleSpacing.xs),
                  Text(
                    '${request.brokerName} 중개사에게 다른 방문 시간을 제안합니다',
                    style: AppleTypography.subheadline.copyWith(color: AirbnbColors.textSecondary),
                  ),

                  const SizedBox(height: AppleSpacing.lg),

                  // 기존 요청 시간
                  Container(
                    padding: const EdgeInsets.all(AppleSpacing.md),
                    decoration: BoxDecoration(
                      color: AirbnbColors.pillSecondary,
                      borderRadius: BorderRadius.circular(AppleRadius.sm),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule, size: 20, color: AirbnbColors.textSecondary),
                        const SizedBox(width: 8),
                        Text('기존 요청: ', style: AppleTypography.subheadline.copyWith(color: AirbnbColors.textSecondary)),
                        Text(
                          _formatDateTime(request.requestedDateTime),
                          style: AppleTypography.subheadline.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppleSpacing.lg),

                  // 새로운 일시 선택
                  const Text('제안할 일시 *', style: AppleTypography.headline),
                  const SizedBox(height: AppleSpacing.sm),
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
                              color: AirbnbColors.pillSecondary,
                              borderRadius: BorderRadius.circular(AppleRadius.sm),
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
                                  style: AppleTypography.body.copyWith(
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
                              color: AirbnbColors.pillSecondary,
                              borderRadius: BorderRadius.circular(AppleRadius.sm),
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
                                  style: AppleTypography.body.copyWith(
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

                  const SizedBox(height: AppleSpacing.lg),

                  // 메시지
                  const Text('메시지 (선택)', style: AppleTypography.headline),
                  const SizedBox(height: AppleSpacing.sm),
                  TextField(
                    controller: messageController,
                    maxLines: 2,
                    maxLength: 100,
                    decoration: InputDecoration(
                      hintText: '시간 변경 사유나 안내 메시지',
                      filled: true,
                      fillColor: AirbnbColors.pillSecondary,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppleRadius.sm),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(AppleSpacing.md),
                    ),
                  ),

                  const SizedBox(height: AppleSpacing.xl),

                  // 버튼
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (selectedDate != null && selectedTime != null)
                          ? () async {
                              final scaffoldMessenger = ScaffoldMessenger.of(context);
                              Navigator.pop(context);

                              try {
                                final alternativeDateTime = DateTime(
                                  selectedDate!.year,
                                  selectedDate!.month,
                                  selectedDate!.day,
                                  selectedTime!.hour,
                                  selectedTime!.minute,
                                );

                                await _mlsService.suggestAlternativeTime(
                                  propertyId: _property.id,
                                  requestId: request.id,
                                  alternativeDateTime: alternativeDateTime,
                                  message: messageController.text.trim().isNotEmpty
                                      ? messageController.text.trim()
                                      : null,
                                );

                                // 매물 정보 새로고침
                                final updated = await _mlsService.getProperty(_property.id);
                                if (updated != null && mounted) {
                                  setState(() => _property = updated);
                                }

                                if (mounted) {
                                  scaffoldMessenger.showSnackBar(
                                    SnackBar(
                                      content: Text('${request.brokerName} 중개사에게 새로운 시간을 제안했습니다'),
                                      backgroundColor: AirbnbColors.primary,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  scaffoldMessenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('제안 제출에 실패했습니다. 잠시 후 다시 시도해 주세요.'),
                                      backgroundColor: AppleColors.systemRed,
                                    ),
                                  );
                                }
                              }
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AirbnbColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AirbnbColors.pillSecondary,
                        padding: const EdgeInsets.symmetric(vertical: AppleSpacing.md),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppleRadius.sm),
                        ),
                      ),
                      child: const Text('시간 제안하기'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 전화 걸기 (공통)
  Future<void> _makePhoneCall(String phone) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    // 전화번호에서 공백, 하이픈 제거
    final cleanPhone = phone.replaceAll(RegExp(r'[\s\-]'), '');
    final uri = Uri.parse('tel:$cleanPhone');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        // 전화 앱을 열 수 없는 경우 클립보드에 복사
        if (mounted) {
          await Clipboard.setData(ClipboardData(text: phone));
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('전화번호가 복사되었습니다: $phone'),
              backgroundColor: AppleColors.systemGreen,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        // 오류 발생 시 클립보드에 복사
        await Clipboard.setData(ClipboardData(text: phone));
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('전화번호가 복사되었습니다: $phone'),
            backgroundColor: AppleColors.systemGreen,
          ),
        );
      }
    }
  }

  /// 중개사에게 전화
  void _callBroker(String phone) => _makePhoneCall(phone);

  /// 판매자에게 전화
  void _callSeller(String phone) => _makePhoneCall(phone);

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final isToday = dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day;
    final isTomorrow = dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day + 1;

    String dateStr;
    if (isToday) {
      dateStr = '오늘';
    } else if (isTomorrow) {
      dateStr = '내일';
    } else {
      dateStr = '${dateTime.month}/${dateTime.day}';
    }

    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour < 12 ? '오전' : '오후';
    final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);

    return '$dateStr $period $hour12:$minute';
  }

  Widget _buildBottomActions() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppleSpacing.md,
        AppleSpacing.sm,
        AppleSpacing.md,
        MediaQuery.of(context).padding.bottom + AppleSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: AirbnbColors.surface,
        border: Border(top: BorderSide(color: AirbnbColors.border)),
      ),
      child: _isOwner ? _buildOwnerActions() : _buildBrokerActions(),
    );
  }

  /// 소유자(판매자)용 하단 액션 버튼
  Widget _buildOwnerActions() {
    return Row(
      children: [
        // 삭제 버튼
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _confirmDelete,
            icon: const Icon(Icons.delete_outline),
            label: const Text('삭제'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppleColors.systemRed,
              side: BorderSide(color: AppleColors.systemRed.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: AppleSpacing.md),
        // 수정 버튼
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _editProperty,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('수정'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AirbnbColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 중개사용 하단 액션 버튼
  Widget _buildBrokerActions() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    // 현재 중개사의 방문 요청 확인
    final myRequests = _property.visitRequests
        .where((r) => r.brokerId == currentUser.uid || r.brokerId == currentUser.email)
        .toList();

    final hasPendingRequest = myRequests.any((r) =>
        r.status == VisitRequestStatus.pending ||
        r.status == VisitRequestStatus.reschedule);

    final hasApprovedRequest = myRequests.any((r) =>
        r.status == VisitRequestStatus.approved);

    // 승인된 요청이 있으면 연락처 표시 (탭하면 전화 연결)
    if (hasApprovedRequest) {
      final approvedRequest = myRequests.firstWhere((r) => r.status == VisitRequestStatus.approved);
      return Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: approvedRequest.sellerPhone != null
                  ? () => _callSeller(approvedRequest.sellerPhone!)
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppleColors.systemGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppleRadius.sm),
                  border: Border.all(color: AppleColors.systemGreen.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppleColors.systemGreen, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '승인 완료',
                            style: AppleTypography.caption1.copyWith(
                              color: AppleColors.systemGreen,
                            ),
                          ),
                          if (approvedRequest.sellerPhone != null)
                            Text(
                              approvedRequest.sellerPhone!,
                              style: AppleTypography.headline.copyWith(
                                color: AppleColors.systemGreen,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (approvedRequest.sellerPhone != null)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppleColors.systemGreen,
                          borderRadius: BorderRadius.circular(AppleRadius.sm),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.call, color: Colors.white, size: 18),
                            const SizedBox(width: 4),
                            Text(
                              '전화하기',
                              style: AppleTypography.subheadline.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    // 대기 중인 요청이 있으면 대기 상태 표시
    if (hasPendingRequest) {
      return Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: AppleColors.systemOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppleRadius.sm),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.schedule, color: AppleColors.systemOrange, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '판매자 승인 대기 중',
                    style: AppleTypography.body.copyWith(
                      color: AppleColors.systemOrange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // 방문 요청 버튼 (아직 요청하지 않은 경우)
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              // 방문 요청 페이지로 이동 또는 바텀시트 표시
              // 중개사 대시보드의 _showQuickProposalSheet과 유사한 기능 필요
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('중개사 대시보드에서 방문 요청을 보내주세요')),
              );
              Navigator.pop(context);
            },
            icon: const Icon(Icons.send),
            label: const Text('방문 요청하기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AirbnbColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _editProperty() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MLSPropertyEditPage(property: _property),
      ),
    );

    if (result == true) {
      // 매물 정보 새로고침
      final updated = await _mlsService.getProperty(_property.id);
      if (updated != null && mounted) {
        setState(() => _property = updated);
      }
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('매물 삭제'),
        content: const Text('정말로 이 매물을 삭제하시겠습니까?\n삭제된 매물은 복구할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteProperty();
            },
            style: TextButton.styleFrom(foregroundColor: AppleColors.systemRed),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProperty() async {
    try {
      await _mlsService.deleteProperty(_property.id, currentUserId: FirebaseAuth.instance.currentUser?.uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('매물이 삭제되었습니다'),
            backgroundColor: AppleColors.systemGreen,
          ),
        );
        Navigator.pop(context, true); // true = 삭제됨
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('삭제에 실패했습니다. 잠시 후 다시 시도해 주세요.'),
            backgroundColor: AppleColors.systemRed,
          ),
        );
      }
    }
  }

  String _formatPrice(double price) => PriceFormatter.format(price);

  String _formatTimeAgo(DateTime dateTime) => DateTimeFormatter.timeAgo(dateTime);

  /// 중개사 프로필 바텀시트 표시
  void _showBrokerProfile(VisitRequest request) {
    BrokerProfileSheet.show(
      context,
      brokerId: request.brokerId,
      brokerName: request.brokerName,
      brokerCompany: request.brokerCompany,
      brokerPhone: request.brokerPhone,
    );
  }
}
