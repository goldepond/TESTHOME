import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/mls_property.dart';
import '../../api_request/mls_property_service.dart';
import '../../constants/apple_design_system.dart';
import '../../utils/logger.dart';
import '../../utils/formatters.dart';
import '../../widgets/visit_request_quick_sheet.dart';
import 'mls_property_detail_page.dart';

/// 매도인 MLS 대시보드 - 방문 요청 관리 중심
///
/// 핵심 컨셉: 중개사가 매수 희망자를 데리고 방문 요청
/// - 방문 요청 현황 (대기/승인/완료)
/// - 승인 시 연락처 상호 교환 → 앱 역할 종료
/// - 연락처는 승인 전까지 비공개
class MLSSellerDashboardPage extends StatefulWidget {
  const MLSSellerDashboardPage({super.key});

  @override
  State<MLSSellerDashboardPage> createState() => _MLSSellerDashboardPageState();
}

class _MLSSellerDashboardPageState extends State<MLSSellerDashboardPage> {
  final _mlsService = MLSPropertyService();

  List<MLSProperty> _properties = [];
  bool _isLoading = true;
  StreamSubscription<List<MLSProperty>>? _subscription;

  // 캐시된 통계 (성능 최적화 - 빌드마다 재계산 방지)
  _OverallStats? _cachedStats;

  @override
  void initState() {
    super.initState();
    // 첫 프레임 렌더링 후 데이터 로드 (UI 먼저 표시)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadProperties();
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _loadProperties() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_properties.isEmpty) {
      setState(() => _isLoading = true);
    }

    _subscription?.cancel();
    _subscription = _mlsService.getPropertiesByUser(user.uid).listen(
      (properties) {
        if (mounted) {
          // 데이터가 변경되었을 때만 setState
          if (_shouldUpdate(properties)) {
            setState(() {
              _properties = properties;
              _cachedStats = _computeStats(properties); // 통계 캐싱
              _isLoading = false;
            });
          } else if (_isLoading) {
            setState(() => _isLoading = false);
          }
        }
      },
      onError: (error) {
        Logger.error('Failed to load properties', error: error);
        if (mounted) setState(() => _isLoading = false);
      },
    );
  }

  bool _shouldUpdate(List<MLSProperty> newList) {
    if (_properties.length != newList.length) return true;
    for (int i = 0; i < _properties.length; i++) {
      if (_properties[i].id != newList[i].id ||
          _properties[i].updatedAt != newList[i].updatedAt) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = AppleResponsive.isMobile(context);

    return Scaffold(
      backgroundColor: AppleColors.systemGroupedBackground,
      // MainPage에서 AppBar를 제공하므로 여기서는 제거
      body: SafeArea(
        top: false,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppleColors.systemBlue),
                ),
              )
            : _properties.isEmpty
                ? _buildEmptyState()
                : _buildPropertyList(isMobile),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppleSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppleColors.systemBlue.withValues(alpha: 0.15),
                    AppleColors.systemBlue.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.rocket_launch_rounded,
                size: 52,
                color: AppleColors.systemBlue,
              ),
            ),
            const SizedBox(height: AppleSpacing.xxl),
            Text(
              '첫 매물을 등록해보세요!',
              style: AppleTypography.largeTitle.copyWith(
                fontWeight: FontWeight.w700,
                color: AppleColors.label,
                fontSize: 28,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppleSpacing.md),
            Text(
              '등록하면 주변 중개사에게 자동 배포되고\n방문 요청을 한눈에 관리하세요',
              style: AppleTypography.body.copyWith(
                color: AppleColors.secondaryLabel,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildPropertyList(bool isMobile) {
    // 캐시된 통계 사용 (없으면 계산)
    final stats = _cachedStats ?? _computeStats(_properties);

    return ListView.builder(
      padding: EdgeInsets.all(isMobile ? AppleSpacing.md : AppleSpacing.lg),
      itemCount: _properties.length + 1, // +1 for stats header
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppleSpacing.lg),
            child: _buildStatsDashboard(stats, isMobile),
          );
        }
        final property = _properties[index - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppleSpacing.md),
          child: _buildPropertyCard(property),
        );
      },
    );
  }

  /// 전체 통계 계산 - 방문 요청 중심 (파라미터로 받아서 캐싱 가능)
  _OverallStats _computeStats(List<MLSProperty> properties) {
    int pendingRequests = 0; // 대기 중인 방문 요청
    int approvedRequests = 0; // 승인된 방문 요청
    int completedRequests = 0; // 완료된 방문 (연락처 교환 완료)
    double? highestOffer;
    int activeProperties = 0;
    int completedProperties = 0;

    for (final property in properties) {
      // 방문 요청별 집계
      for (final request in property.visitRequests) {
        switch (request.status) {
          case VisitRequestStatus.pending:
            pendingRequests++;
            if (highestOffer == null || request.proposedPrice > highestOffer) {
              highestOffer = request.proposedPrice;
            }
            break;
          case VisitRequestStatus.approved:
            if (request.contactExchangedAt != null) {
              completedRequests++;
            } else {
              approvedRequests++;
            }
            break;
          case VisitRequestStatus.reschedule:
            pendingRequests++; // 다른 시간 제안도 대기 중으로 취급
            break;
          default:
            break;
        }
      }

      // 매물 상태별 집계
      switch (property.status) {
        case PropertyStatus.active:
        case PropertyStatus.inquiry:
        case PropertyStatus.underOffer:
          activeProperties++;
          break;
        case PropertyStatus.depositTaken:
        case PropertyStatus.sold:
          completedProperties++;
          break;
        default:
          break;
      }
    }

    return _OverallStats(
      totalProperties: properties.length,
      activeProperties: activeProperties,
      completedProperties: completedProperties,
      pendingRequests: pendingRequests,
      approvedRequests: approvedRequests,
      completedRequests: completedRequests,
      highestOffer: highestOffer,
    );
  }

  /// 통계 대시보드
  Widget _buildStatsDashboard(_OverallStats stats, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 헤더
        Padding(
          padding: const EdgeInsets.only(bottom: AppleSpacing.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '내 매물 현황',
                style: AppleTypography.title2.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppleColors.systemBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '총 ${stats.totalProperties}건',
                  style: AppleTypography.subheadline.copyWith(
                    color: AppleColors.systemBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        // 메인 통계 카드 - 방문 요청 중심
        Container(
          padding: const EdgeInsets.all(AppleSpacing.md),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFFCD6B55), // 진한 코랄
                Color(0xFFB55A45), // 더 진한 코랄
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppleRadius.lg),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildMainStatItem(
                      icon: Icons.schedule_rounded,
                      value: '${stats.pendingRequests}건',
                      label: '응답 대기',
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 50,
                    color: Colors.white24,
                  ),
                  Expanded(
                    child: _buildMainStatItem(
                      icon: Icons.check_circle_rounded,
                      value: '${stats.approvedRequests}건',
                      label: '승인 완료',
                    ),
                  ),
                ],
              ),
              if (stats.highestOffer != null) ...[
                const SizedBox(height: AppleSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppleSpacing.sm),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppleRadius.sm),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.trending_up, color: Colors.amber, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '최고 희망가 ${_formatPrice(stats.highestOffer!)}',
                        style: AppleTypography.caption1.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),


        const SizedBox(height: AppleSpacing.lg),
        const Divider(),
        const SizedBox(height: AppleSpacing.sm),

        // 매물 목록 헤더
        Text(
          '등록 매물',
          style: AppleTypography.headline.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildMainStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: AppleSpacing.xs),
        Text(
          value,
          style: AppleTypography.title2.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: AppleTypography.caption1.copyWith(
            color: Colors.white70,
          ),
        ),
      ],
    );
  }


  Widget _buildPropertyCard(MLSProperty property) {
    // 방문 요청 현황 계산
    final summary = _calculateVisitRequestSummary(property);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MLSPropertyDetailPage(property: property),
          ),
        ).then((_) {
          // 상세 페이지에서 돌아오면 목록 새로고침
          _loadProperties();
        });
      },
      child: AppleCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 매물 이미지 + 상태 뱃지
            Stack(
              children: [
                if (property.thumbnailUrl != null || property.imageUrls.isNotEmpty)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppleRadius.lg),
                    ),
                    child: Image.network(
                      property.thumbnailUrl ?? property.imageUrls.first,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      // 메모리 최적화: 캐시 크기 제한
                      cacheWidth: 400,
                      cacheHeight: 360,
                      errorBuilder: (_, _, _) => Container(
                        height: 180,
                        color: AppleColors.tertiarySystemFill,
                        child: const Icon(Icons.image_not_supported,
                          color: AppleColors.tertiaryLabel, size: 48),
                      ),
                    ),
                  )
                else
                  Container(
                    height: 180,
                    decoration: const BoxDecoration(
                      color: AppleColors.tertiarySystemFill,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(AppleRadius.lg),
                      ),
                    ),
                    child: const Center(
                      child: Icon(Icons.home_outlined,
                        color: AppleColors.tertiaryLabel, size: 64),
                    ),
                  ),
                // 이미지 개수 표시 (2장 이상일 때)
                if (property.imageUrls.length > 1)
                  Positioned(
                    bottom: AppleSpacing.sm,
                    right: AppleSpacing.sm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppleSpacing.sm,
                        vertical: AppleSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(AppleRadius.sm),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.photo_library, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '${property.imageUrls.length}장',
                            style: AppleTypography.caption1.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // 상태 뱃지
                Positioned(
                  top: AppleSpacing.sm,
                  left: AppleSpacing.sm,
                  child: _buildStatusBadge(property.status),
                ),
                // 대기 중인 방문 요청이 있으면 하이라이트
                if (summary.pendingRequests > 0)
                  Positioned(
                    top: AppleSpacing.sm,
                    right: AppleSpacing.sm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppleSpacing.sm,
                        vertical: AppleSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: AppleColors.systemOrange,
                        borderRadius: BorderRadius.circular(AppleRadius.sm),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.notifications_active,
                            color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '방문 요청 ${summary.pendingRequests}건',
                            style: AppleTypography.caption1.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            // 매물 정보
            Padding(
              padding: const EdgeInsets.all(AppleSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 주소
                  Text(
                    property.roadAddress,
                    style: AppleTypography.headline.copyWith(
                      color: AppleColors.label,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (property.buildingName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      property.buildingName,
                      style: AppleTypography.subheadline.copyWith(
                        color: AppleColors.secondaryLabel,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppleSpacing.sm),

                  // 가격
                  Text(
                    '희망가 ${_formatPrice(property.desiredPrice)}',
                    style: AppleTypography.title3.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppleColors.label,
                    ),
                  ),


                  // 최고 희망가 (있을 경우)
                  if (summary.highestOffer != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.trending_up,
                          size: 16, color: AppleColors.systemGreen),
                        const SizedBox(width: 4),
                        Text(
                          '최고 희망가 ${_formatPrice(summary.highestOffer!)}',
                          style: AppleTypography.subheadline.copyWith(
                            color: AppleColors.systemGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: AppleSpacing.md),

                  // 방문 요청 현황 바
                  _buildVisitRequestBar(summary),

                  const SizedBox(height: AppleSpacing.sm),

                  // 방문 요청 현황 숫자
                  _buildVisitRequestStats(summary),

                  // 대기 중인 요청이 있으면 퀵액션 버튼 표시
                  if (summary.pendingRequests > 0) ...[
                    const SizedBox(height: AppleSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showVisitRequestSheet(property),
                        icon: const Icon(Icons.schedule, size: 18),
                        label: Text('요청 관리 (${summary.pendingRequests}건)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppleColors.systemOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppleRadius.sm),
                          ),
                        ),
                      ),
                    ),
                  ],

                  // 상태 전환 버튼 (inquiry, underOffer, depositTaken 단계에서 표시)
                  if (_getNextStatus(property.status) != null) ...[
                    const SizedBox(height: AppleSpacing.sm),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showStatusTransitionDialog(property),
                        icon: const Icon(Icons.arrow_forward, size: 18),
                        label: Text(_getNextStatusLabel(property.status)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppleColors.systemBlue,
                          side: const BorderSide(color: AppleColors.systemBlue),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppleRadius.sm),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 방문 요청 관리 바텀시트 표시
  void _showVisitRequestSheet(MLSProperty property) {
    VisitRequestQuickSheet.show(
      context,
      property: property,
      onUpdated: () => _loadProperties(),
    );
  }

  /// 방문 요청 현황 계산
  _VisitRequestSummary _calculateVisitRequestSummary(MLSProperty property) {
    final int totalBrokers = property.brokerResponses.length;
    int viewedBrokers = 0;
    int pendingRequests = 0;
    int approvedRequests = 0;
    double? highestOffer;
    String? highestOfferBroker;

    // 중개사 열람 현황
    for (final response in property.brokerResponses.values) {
      if (response.hasViewed) {
        viewedBrokers++;
      }
    }

    // 방문 요청 현황
    for (final request in property.visitRequests) {
      switch (request.status) {
        case VisitRequestStatus.pending:
        case VisitRequestStatus.reschedule:
          pendingRequests++;
          if (highestOffer == null || request.proposedPrice > highestOffer) {
            highestOffer = request.proposedPrice;
            highestOfferBroker = request.brokerName;
          }
          break;
        case VisitRequestStatus.approved:
          approvedRequests++;
          break;
        default:
          break;
      }
    }

    return _VisitRequestSummary(
      totalBrokers: totalBrokers,
      viewedBrokers: viewedBrokers,
      pendingRequests: pendingRequests,
      approvedRequests: approvedRequests,
      highestOffer: highestOffer,
      highestOfferBroker: highestOfferBroker,
    );
  }

  /// 방문 요청 현황 프로그레스 바
  Widget _buildVisitRequestBar(_VisitRequestSummary summary) {
    final total = summary.pendingRequests + summary.approvedRequests + summary.viewedBrokers;
    if (total == 0) {
      return Container(
        height: 8,
        decoration: BoxDecoration(
          color: AppleColors.tertiarySystemFill,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Text(
            '중개사 배포 대기중',
            style: AppleTypography.caption2.copyWith(
              color: AppleColors.tertiaryLabel,
            ),
          ),
        ),
      );
    }

    return Container(
      height: 8,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Row(
          children: [
            if (summary.pendingRequests > 0)
              Expanded(
                flex: summary.pendingRequests,
                child: Container(color: AppleColors.systemOrange),
              ),
            if (summary.approvedRequests > 0)
              Expanded(
                flex: summary.approvedRequests,
                child: Container(color: AppleColors.systemGreen),
              ),
            if (summary.viewedBrokers > 0)
              Expanded(
                flex: summary.viewedBrokers,
                child: Container(color: AppleColors.systemBlue),
              ),
            if (summary.totalBrokers - summary.viewedBrokers > 0)
              Expanded(
                flex: summary.totalBrokers - summary.viewedBrokers,
                child: Container(color: AppleColors.tertiarySystemFill),
              ),
          ],
        ),
      ),
    );
  }

  /// 방문 요청 현황 숫자 표시
  Widget _buildVisitRequestStats(_VisitRequestSummary summary) {
    return Wrap(
      spacing: AppleSpacing.sm,
      runSpacing: AppleSpacing.xxs,
      children: [
        if (summary.pendingRequests > 0)
          _buildStatChip('방문요청', summary.pendingRequests, AppleColors.systemOrange),
        if (summary.approvedRequests > 0)
          _buildStatChip('승인', summary.approvedRequests, AppleColors.systemGreen),
        if (summary.viewedBrokers > 0)
          _buildStatChip('열람', summary.viewedBrokers, AppleColors.systemBlue),
      ],
    );
  }

  Widget _buildStatChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppleSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppleRadius.xs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$label $count',
            style: AppleTypography.caption1.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(PropertyStatus status) {
    final text = _getStatusText(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppleSpacing.xs,
        vertical: AppleSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppleRadius.sm),
      ),
      child: Text(
        text,
        style: AppleTypography.caption1.copyWith(
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  String _formatPrice(double price) => PriceFormatter.format(price);

  /// 다음 상태 반환 (전환 가능한 경우만)
  PropertyStatus? _getNextStatus(PropertyStatus status) {
    return switch (status) {
      PropertyStatus.inquiry => PropertyStatus.underOffer,
      PropertyStatus.underOffer => PropertyStatus.depositTaken,
      PropertyStatus.depositTaken => PropertyStatus.sold,
      _ => null,
    };
  }

  /// 다음 상태 전환 버튼 라벨
  String _getNextStatusLabel(PropertyStatus status) {
    return switch (status) {
      PropertyStatus.inquiry => '협의 진행으로 변경',
      PropertyStatus.underOffer => '가계약 완료로 변경',
      PropertyStatus.depositTaken => '거래 완료 처리',
      _ => '',
    };
  }

  /// 상태 전환 다이얼로그
  Future<void> _showStatusTransitionDialog(MLSProperty property) async {
    final nextStatus = _getNextStatus(property.status);
    if (nextStatus == null) return;

    // 거래 완료(sold)로 전환 시 최종 중개사/가격 입력 필요
    if (nextStatus == PropertyStatus.sold) {
      await _showCompleteTransactionDialog(property);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('상태 변경'),
        content: Text(
          '매물 상태를 "${_getStatusText(property.status)}"에서 "${_getStatusText(nextStatus)}"(으)로 변경하시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppleColors.systemBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('변경'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _mlsService.updateStatus(
          propertyId: property.id,
          newStatus: nextStatus,
          changedBy: property.userId,
          reason: '판매자가 상태를 변경했습니다',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('상태가 "${_getStatusText(nextStatus)}"(으)로 변경되었습니다.'),
              backgroundColor: AppleColors.systemGreen,
            ),
          );
        }
      } catch (e) {
        Logger.error('[SellerDashboard] 매물 상태 변경 실패', error: e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('상태 변경에 실패했습니다. 잠시 후 다시 시도해 주세요.'),
              backgroundColor: AppleColors.systemRed,
            ),
          );
        }
      }
    }
  }

  /// 거래 완료 다이얼로그 (최종 중개사 선택 + 최종 가격 입력)
  Future<void> _showCompleteTransactionDialog(MLSProperty property) async {
    // 승인된 방문 요청 목록에서 최종 중개사 선택
    final approvedRequests = property.visitRequests
        .where((r) => r.status == VisitRequestStatus.approved)
        .toList();

    if (approvedRequests.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('승인된 방문 요청이 없습니다. 먼저 방문 요청을 승인해주세요.'),
            backgroundColor: AppleColors.systemOrange,
          ),
        );
      }
      return;
    }

    String? selectedBrokerId;
    final priceController = TextEditingController(
      text: property.desiredPrice.toStringAsFixed(0),
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('거래 완료 처리'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('최종 중개사 선택',
                  style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ...approvedRequests.map((request) {
                  final isSelected = selectedBrokerId == request.brokerId;
                  return InkWell(
                    onTap: () => setDialogState(() => selectedBrokerId = request.brokerId),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: isSelected ? AppleColors.systemBlue.withValues(alpha: 0.1) : null,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? AppleColors.systemBlue : AppleColors.separator,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.check_circle : Icons.circle_outlined,
                            color: isSelected ? AppleColors.systemBlue : AppleColors.tertiaryLabel,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(request.brokerName, style: const TextStyle(fontWeight: FontWeight.w500)),
                                Text('제안가: ${_formatPrice(request.proposedPrice)}',
                                  style: const TextStyle(fontSize: 13, color: AppleColors.secondaryLabel)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),
                const Text('최종 거래가 (만원)',
                  style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    suffixText: '만원',
                    hintText: '최종 거래 금액',
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
              onPressed: selectedBrokerId == null
                  ? null
                  : () {
                      final price = double.tryParse(priceController.text);
                      if (price == null || price <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('올바른 금액을 입력해주세요.')),
                        );
                        return;
                      }
                      Navigator.pop(context, {
                        'brokerId': selectedBrokerId,
                        'price': price,
                      });
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppleColors.systemBlue,
                foregroundColor: Colors.white,
              ),
              child: const Text('거래 완료'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      try {
        await _mlsService.completeTransaction(
          propertyId: property.id,
          finalBrokerId: result['brokerId'] as String,
          finalPrice: result['price'] as double,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('거래가 완료되었습니다.'),
              backgroundColor: AppleColors.systemGreen,
            ),
          );
        }
      } catch (e) {
        Logger.error('[SellerDashboard] 거래 완료 처리 실패', error: e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('거래 완료 처리에 실패했습니다. 잠시 후 다시 시도해 주세요.'),
              backgroundColor: AppleColors.systemRed,
            ),
          );
        }
      }
    }

    priceController.dispose();
  }

  String _getStatusText(PropertyStatus status) {
    switch (status) {
      case PropertyStatus.draft:
        return '임시저장';
      case PropertyStatus.pending:
        return '검증 대기';
      case PropertyStatus.rejected:
        return '검증 거절';
      case PropertyStatus.active:
        return '진행중';
      case PropertyStatus.inquiry:
        return '문의중';
      case PropertyStatus.underOffer:
        return '협의중';
      case PropertyStatus.depositTaken:
        return '가계약';
      case PropertyStatus.sold:
        return '거래완료';
      case PropertyStatus.cancelled:
        return '취소';
    }
  }

}

/// 전체 통계 요약 데이터 - 방문 요청 중심
class _OverallStats {
  final int totalProperties;
  final int activeProperties;
  final int completedProperties;
  final int pendingRequests; // 대기 중인 방문 요청
  final int approvedRequests; // 승인된 방문 요청
  final int completedRequests; // 완료된 방문
  final double? highestOffer;

  _OverallStats({
    required this.totalProperties,
    required this.activeProperties,
    required this.completedProperties,
    required this.pendingRequests,
    required this.approvedRequests,
    required this.completedRequests,
    this.highestOffer,
  });
}

/// 방문 요청 현황 요약 데이터
class _VisitRequestSummary {
  final int totalBrokers; // 배포받은 중개사 수
  final int viewedBrokers; // 열람한 중개사 수
  final int pendingRequests; // 대기 중인 방문 요청
  final int approvedRequests; // 승인된 방문 요청
  final double? highestOffer; // 최고 희망가
  final String? highestOfferBroker; // 최고 희망가 중개사

  _VisitRequestSummary({
    required this.totalBrokers,
    required this.viewedBrokers,
    required this.pendingRequests,
    required this.approvedRequests,
    this.highestOffer,
    this.highestOfferBroker,
  });
}

