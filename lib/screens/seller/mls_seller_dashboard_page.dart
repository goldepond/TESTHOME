import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/broker_participation.dart';
import '../../models/mls_property.dart';
import '../../models/priority_grant.dart';
import '../../api_request/mls_property_service.dart';
import '../../api_request/firebase_service.dart';
import '../../api_request/priority_audit_log_service.dart';
import '../../api_request/priority_grant_service.dart';
import '../../constants/app_constants.dart';
import '../../constants/spacing.dart';
import '../../constants/responsive_constants.dart';
import '../../constants/apple_design_system.dart';
import '../../utils/logger.dart';
import '../../utils/formatters.dart';
import '../../constants/grant_messages.dart';
import '../../widgets/listing_mode_change_dialog.dart';
import '../../widgets/participation_timeline.dart';
import '../../widgets/priority_holder_section.dart';
import '../../widgets/release_tier_badge.dart';
import '../../widgets/visit_request_quick_sheet.dart';
import '../broker/priority_appeal_page.dart';
import 'mls_property_detail_page.dart';
import 'package:property/constants/typography.dart';
import 'package:property/utils/snackbar_utils.dart';

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
  String? _errorMessage;
  StreamSubscription<List<MLSProperty>>? _subscription;

  // 상태 필터
  int _selectedStatusFilter = 0; // 0: 전체

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
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = '매물을 불러올 수 없습니다';
          });
        }
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
    final isMobile = ResponsiveHelper.isMobile(context);

    return Scaffold(
      backgroundColor: AirbnbColors.surface,
      // MainPage에서 AppBar를 제공하므로 여기서는 제거
      body: SafeArea(
        top: false,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AirbnbColors.primary),
                ),
              )
            : _errorMessage != null
                ? _buildErrorState()
                : _properties.isEmpty
                    ? _buildEmptyState()
                    : _buildPropertyList(isMobile),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 52,
              color: AirbnbColors.textSecondary,
            ),
            const SizedBox(height: 20.0),
            Text(
              _errorMessage ?? '오류가 발생했습니다',
              style: AppTypography.body.copyWith(
                color: AirbnbColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20.0),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                  _isLoading = true;
                });
                _loadProperties();
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('다시 시도'),
              style: TextButton.styleFrom(
                foregroundColor: AirbnbColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AirbnbColors.primary.withValues(alpha: 0.15),
                    AirbnbColors.primary.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.rocket_launch_rounded,
                size: 52,
                color: AirbnbColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              '첫 매물을 등록해보세요!',
              style: AppTypography.h1.copyWith(
                color: AirbnbColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '등록하면 주변 중개사에게 자동 배포되고\n방문 요청을 한눈에 관리하세요',
              style: AppTypography.body.copyWith(
                color: AirbnbColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }


  /// 상태 필터 적용된 매물 목록
  List<MLSProperty> get _filteredProperties {
    if (_selectedStatusFilter == 0) return _properties;

    final targetStatuses = switch (_selectedStatusFilter) {
      1 => [PropertyStatus.active, PropertyStatus.inquiry], // 활성
      2 => [PropertyStatus.pending, PropertyStatus.draft], // 대기
      3 => [PropertyStatus.underOffer, PropertyStatus.depositTaken], // 협의중
      4 => [PropertyStatus.sold], // 거래완료
      5 => [PropertyStatus.cancelled, PropertyStatus.rejected], // 종료
      _ => <PropertyStatus>[],
    };

    return _properties.where((p) => targetStatuses.contains(p.status)).toList();
  }

  /// 상태 필터 탭
  Widget _buildStatusFilterTabs() {
    final statusCounts = <int, int>{};
    for (final property in _properties) {
      // 활성
      if (property.status == PropertyStatus.active || property.status == PropertyStatus.inquiry) {
        statusCounts[1] = (statusCounts[1] ?? 0) + 1;
      }
      // 대기
      if (property.status == PropertyStatus.pending || property.status == PropertyStatus.draft) {
        statusCounts[2] = (statusCounts[2] ?? 0) + 1;
      }
      // 협의중
      if (property.status == PropertyStatus.underOffer || property.status == PropertyStatus.depositTaken) {
        statusCounts[3] = (statusCounts[3] ?? 0) + 1;
      }
      // 거래완료
      if (property.status == PropertyStatus.sold) {
        statusCounts[4] = (statusCounts[4] ?? 0) + 1;
      }
      // 종료
      if (property.status == PropertyStatus.cancelled || property.status == PropertyStatus.rejected) {
        statusCounts[5] = (statusCounts[5] ?? 0) + 1;
      }
    }

    final filters = [
      ('전체', _properties.length),
      ('활성', statusCounts[1] ?? 0),
      ('대기', statusCounts[2] ?? 0),
      ('협의중', statusCounts[3] ?? 0),
      ('완료', statusCounts[4] ?? 0),
      ('종료', statusCounts[5] ?? 0),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: List.generate(filters.length, (index) {
          final (label, count) = filters[index];
          final isSelected = _selectedStatusFilter == index;
          return Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: GestureDetector(
              onTap: () {
                if (_selectedStatusFilter != index) {
                  setState(() => _selectedStatusFilter = index);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AirbnbColors.primary
                      : AirbnbColors.pillSecondary,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  count > 0 ? '$label $count' : label,
                  style: AppTypography.bodySmall.copyWith(
                    color: isSelected ? AirbnbColors.background : AirbnbColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPropertyList(bool isMobile) {
    // 캐시된 통계 사용 (없으면 계산)
    final stats = _cachedStats ?? _computeStats(_properties);
    final filtered = _filteredProperties;

    return ListView.builder(
      padding: EdgeInsets.all(isMobile ? AppSpacing.md : 20.0),
      itemCount: filtered.length + 2, // +1 stats header, +1 filter tabs
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: _buildStatsDashboard(stats, isMobile),
          );
        }
        if (index == 1) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _buildStatusFilterTabs(),
          );
        }
        final property = filtered[index - 2];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
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
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '내 매물 현황',
                style: AppTypography.h2.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // Problem 004 갭 1 — 매도자 측 이의 제기 진입.
                  // PRIORITY_RULEBOOK 1부 §2.6 약속 "이상해요로 알려주세요" 의 매도자 노출 진입점.
                  // 본 매도자 헤더에 broker 헤더와 동일 패턴 IconButton 1개 추가.
                  IconButton(
                    icon: const Icon(Icons.report_problem_outlined),
                    color: AirbnbColors.textSecondary,
                    tooltip: GrantMessages.appealMenuTitle,
                    onPressed: _openSellerAppealCenter,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AirbnbColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '총 ${stats.totalProperties}건',
                      style: AppTypography.bodySmall.copyWith(
                        color: AirbnbColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // 메인 통계 카드 - 방문 요청 중심
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AirbnbColors.surfaceDark,
            borderRadius: BorderRadius.circular(16),
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
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.trending_up, color: AirbnbColors.orange, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '최고 희망가 ${_formatPrice(stats.highestOffer!)}',
                        style: AppTypography.caption.copyWith(
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


        const SizedBox(height: 20.0),
        const Divider(),
        const SizedBox(height: 12.0),

        // 매물 목록 헤더
        Text(
          '등록 매물',
          style: AppTypography.h4.copyWith(
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
        const SizedBox(height: AppSpacing.sm),
        Text(
          value,
          style: AppTypography.h2.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: AppTypography.caption.copyWith(
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
                      top: Radius.circular(AppRadius.lg),
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
                        color: AirbnbColors.pillSecondary,
                        child: const Icon(Icons.image_not_supported,
                          color: AirbnbColors.textLight, size: 48),
                      ),
                    ),
                  )
                else
                  Container(
                    height: 180,
                    decoration: const BoxDecoration(
                      color: AirbnbColors.pillSecondary,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(AppRadius.lg),
                      ),
                    ),
                    child: const Center(
                      child: Icon(Icons.home_outlined,
                        color: AirbnbColors.textLight, size: 64),
                    ),
                  ),
                // 이미지 개수 표시 (2장 이상일 때)
                if (property.imageUrls.length > 1)
                  Positioned(
                    bottom: 12.0,
                    right: 12.0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.photo_library, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '${property.imageUrls.length}장',
                            style: AppTypography.caption.copyWith(
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
                  top: 12.0,
                  left: 12.0,
                  child: _buildStatusBadge(property.status),
                ),
                // 대기 중인 방문 요청이 있으면 하이라이트
                if (summary.pendingRequests > 0)
                  Positioned(
                    top: 12.0,
                    right: 12.0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: AirbnbColors.orange,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.notifications_active,
                            color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '방문 요청 ${summary.pendingRequests}건',
                            style: AppTypography.caption.copyWith(
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
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 주소
                  Text(
                    property.roadAddress,
                    style: AppTypography.h4.copyWith(
                      color: AirbnbColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (property.buildingName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      property.buildingName,
                      style: AppTypography.bodySmall.copyWith(
                        color: AirbnbColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12.0),

                  // 가격
                  Text(
                    '희망가 ${_formatPrice(property.desiredPrice)}',
                    style: AppTypography.h3.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AirbnbColors.textPrimary,
                    ),
                  ),


                  // 최고 희망가 (있을 경우)
                  if (summary.highestOffer != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.trending_up,
                          size: 16, color: AirbnbColors.green),
                        const SizedBox(width: 4),
                        Text(
                          '최고 희망가 ${_formatPrice(summary.highestOffer!)}',
                          style: AppTypography.bodySmall.copyWith(
                            color: AirbnbColors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // 관심도 (조회수 + 북마크 수 + 문의 수)
                  _buildInterestIndicator(property),

                  const SizedBox(height: AppSpacing.md),

                  // 방문 요청 현황 바
                  _buildVisitRequestBar(summary),

                  const SizedBox(height: 12.0),

                  // 방문 요청 현황 숫자
                  _buildVisitRequestStats(summary),

                  // 단계(tier) 진행 안내 — 80세 노인 화법 한 줄.
                  _buildTierProgressSection(property),

                  // 우선권 보유자 표시 — Task 03: M1.1(매도측)과 M1.2(매수측) 분리.
                  const SizedBox(height: AppSpacing.md),
                  PriorityHolderSection(
                    propertyId: property.id,
                    viewerRole: PriorityHolderViewerRole.seller,
                    grantType: 'seller_match',
                    titleOverride: GrantMessages.sellerSellerSideHolderTitle,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  PriorityHolderSection(
                    propertyId: property.id,
                    viewerRole: PriorityHolderViewerRole.seller,
                    grantType: 'buyer_match',
                    titleOverride: GrantMessages.sellerBuyerSideHolderTitle,
                    emptyOverride: GrantMessages.buyerMatchEmpty,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                    ),
                    child: Text(
                      GrantMessages.sellerSidesMayDifferNotice,
                      style: AppTypography.withColor(
                        AppTypography.caption,
                        AirbnbColors.textLight,
                      ),
                    ),
                  ),

                  // Task 06 — 활성 grant 시 단계 정지 안내 (Task 04/05 누적).
                  _buildTierPausedNotice(property),

                  // Task 05 — M2 시간기록 공개: 중개사 활동 타임라인.
                  const SizedBox(height: AppSpacing.md),
                  _buildParticipationTimelineSection(property),

                  // Task 06 — 결정 사유 (audit timeline) + 단계 진행 이력.
                  const SizedBox(height: AppSpacing.md),
                  _buildAuditTimelineSection(property),

                  // Task 07 — 매도자 자율 단독 지정 표시 + 모드 전환 진입점.
                  const SizedBox(height: AppSpacing.md),
                  _buildListingModeSection(property),

                  // P1-13 — 모드 변경 이력 (audit log 기반, 0건이면 미표시).
                  _buildListingHistorySection(property),

                  // 대기 중인 요청이 있으면 퀵액션 버튼 표시
                  if (summary.pendingRequests > 0) ...[
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showVisitRequestSheet(property),
                        icon: const Icon(Icons.schedule, size: 18),
                        label: Text('요청 관리 (${summary.pendingRequests}건)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AirbnbColors.primary,
                          foregroundColor: AirbnbColors.background,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                      ),
                    ),
                  ],

                  // P1-20.1 — 활성 grant 보유 시 [거래 성사로 끝내기] 진입.
                  _buildFulfillmentAction(property),

                  // 상태 전환 버튼 (inquiry, underOffer, depositTaken 단계에서 표시)
                  if (_getNextStatus(property.status) != null) ...[
                    const SizedBox(height: 12.0),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showStatusTransitionDialog(property),
                        icon: const Icon(Icons.arrow_forward, size: 18),
                        label: Text(_getNextStatusLabel(property.status)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AirbnbColors.primary,
                          side: const BorderSide(color: AirbnbColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100),
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

  /// P1-20.1 — 활성 grant 보유 시 [거래 성사로 끝내기] 버튼 노출.
  ///
  /// `priority_grants` 에서 propertyId + status='active' 가 1건 이상이면
  /// 작은 텍스트 버튼 노출. 누르면 확인 다이얼로그 → 모든 활성 grant 를
  /// `fulfillGrantViaFunction` 으로 fulfilled 처리. 80세 화법 — 점수·% 0.
  Widget _buildFulfillmentAction(MLSProperty property) {
    return StreamBuilder<List<PriorityGrant>>(
      stream: PriorityGrantService().watchByProperty(property.id),
      builder: (context, snapshot) {
        final List<PriorityGrant> active =
            (snapshot.data ?? const <PriorityGrant>[])
                .where((g) => g.status == PriorityGrantStatus.active)
                .toList(growable: false);
        if (active.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () => _confirmAndFulfill(property, active),
              icon: const Icon(
                Icons.handshake_outlined,
                size: 18,
                color: AirbnbColors.green,
              ),
              label: Text(
                GrantMessages.actionFulfillGrant,
                style: AppTypography.bodySmall.copyWith(
                  color: AirbnbColors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                  side: BorderSide(
                    color: AirbnbColors.green.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// P1-20.1 — 거래 성사 확인 다이얼로그 + fulfillGrantViaFunction 일괄 호출.
  Future<void> _confirmAndFulfill(
    MLSProperty property,
    List<PriorityGrant> activeGrants,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text(GrantMessages.fulfillConfirmTitle),
          content: const Text(GrantMessages.fulfillConfirmBody),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text(GrantMessages.fulfillCancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AirbnbColors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text(GrantMessages.fulfillSuccess),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    if (!mounted) return;

    final PriorityGrantService grantService = PriorityGrantService();
    int successCount = 0;
    for (final PriorityGrant g in activeGrants) {
      try {
        await grantService.fulfillGrantViaFunction(grantId: g.id);
        successCount += 1;
      } catch (e, stack) {
        Logger.error(
          'fulfillGrant call failed',
          error: e,
          stackTrace: stack,
          context: 'MLSSellerDashboardPage._confirmAndFulfill',
          metadata: <String, dynamic>{
            'propertyId': property.id,
            'grantId': g.id,
          },
        );
      }
    }
    if (!mounted) return;
    if (successCount == activeGrants.length) {
      AppSnackBar.success(context, GrantMessages.fulfillSuccess);
    } else if (successCount > 0) {
      AppSnackBar.info(context, '일부만 처리됐어요. 잠시 후 다시 시도해 주세요.');
    } else {
      AppSnackBar.error(context, '처리에 실패했어요. 잠시 후 다시 시도해 주세요.');
    }
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

  /// 관심도 표시 (북마크 수 + 문의 수)
  Widget _buildInterestIndicator(MLSProperty property) {
    return FutureBuilder<List<int>>(
      future: Future.wait([
        FirebaseService().getPropertyBookmarkCount(property.id),
        MLSPropertyService()
            .getBuyerInquiriesForProperty(property.id)
            .first
            .then((list) => list.length),
      ]),
      builder: (context, snapshot) {
        final views = property.viewCount;
        final bookmarks = snapshot.data?[0] ?? 0;
        final inquiries = snapshot.data?[1] ?? 0;
        if (views == 0 && bookmarks == 0 && inquiries == 0) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(top: 12.0),
          child: Row(
            children: [
              if (views > 0) ...[
                const Icon(Icons.visibility, size: 14, color: AirbnbColors.textSecondary),
                const SizedBox(width: 3),
                Text('조회 $views',
                    style: AppTypography.caption
                        .copyWith(color: AirbnbColors.textSecondary)),
              ],
              if (views > 0 && (bookmarks > 0 || inquiries > 0)) const SizedBox(width: 12),
              if (bookmarks > 0) ...[
                const Icon(Icons.bookmark, size: 14, color: AirbnbColors.warning),
                const SizedBox(width: 3),
                Text('관심 $bookmarks',
                    style: AppTypography.caption
                        .copyWith(color: AirbnbColors.textSecondary)),
              ],
              if (bookmarks > 0 && inquiries > 0) const SizedBox(width: 12),
              if (inquiries > 0) ...[
                const Icon(Icons.mail_outline, size: 14, color: AirbnbColors.green),
                const SizedBox(width: 3),
                Text('문의 $inquiries',
                    style: AppTypography.caption
                        .copyWith(color: AirbnbColors.textSecondary)),
              ],
            ],
          ),
        );
      },
    );
  }

  /// 단계(tier) 진행 안내 한 줄.
  ///
  /// 80세 노인 화법: 점수·가중치 노출 없이 "지금 어디까지 보였는지"만 알려준다.
  /// - exclusive: 단독 매물 라벨 + 단계 확대 안 한다는 안내.
  /// - tier 코드별 [GrantMessages.tierProgressCopy] 카피 한 줄.
  /// 활성 grant로 단계가 정지된 상태인지 여부는 본 task 범위 밖
  /// (Task 06 투명성에서 [GrantMessages.tierPausedByGrant]로 보강 예정).
  Widget _buildTierProgressSection(MLSProperty property) {
    final mode = property.listingMode;

    if (mode == 'exclusive') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            ReleaseTierBadge(tier: null, listingMode: mode),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                GrantMessages.tierExclusiveLabel,
                style: AppTypography.caption.copyWith(
                  color: AirbnbColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final tier = property.releaseTier;
    if (tier == null || tier.isEmpty) {
      return const SizedBox.shrink();
    }
    final progress = GrantMessages.tierProgressCopy(tier);
    if (progress.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          ReleaseTierBadge(tier: tier, listingMode: mode),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              progress,
              style: AppTypography.caption.copyWith(
                color: AirbnbColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Task 05 — 중개사 활동 타임라인 섹션.
  ///
  /// 매도자(또는 admin)가 본인 매물의 broker_participations 비식별 view를 본다.
  /// callable [MLSPropertyService.getBrokerParticipationsForSeller] 호출.
  /// 80세 노인 화법 — 점수/% 노출 0, displayName + 단계 카피만.
  Widget _buildParticipationTimelineSection(MLSProperty property) {
    return FutureBuilder<List<BrokerParticipation>>(
      future: _mlsService.getBrokerParticipationsForSeller(property.id),
      builder: (context, snapshot) {
        final Widget header = Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(
            GrantMessages.participationTimelineTitle,
            style: AppTypography.h4.copyWith(
              fontWeight: FontWeight.w600,
              color: AirbnbColors.textPrimary,
            ),
          ),
        );

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              header,
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ],
          );
        }

        if (snapshot.hasError) {
          Logger.warning(
            'Participation timeline load failed',
            metadata: <String, dynamic>{
              'propertyId': property.id,
              'error': snapshot.error.toString(),
            },
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              header,
              Text(
                '정보를 불러오지 못했습니다',
                style: AppTypography.caption.copyWith(
                  color: AirbnbColors.textSecondary,
                ),
              ),
            ],
          );
        }

        final List<BrokerParticipation> participants =
            snapshot.data ?? const <BrokerParticipation>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            header,
            ParticipationTimeline(participants: participants),
          ],
        );
      },
    );
  }

  /// Task 06 — 활성 우선권 보유 시 단계 공개 정지 안내.
  ///
  /// `priority_grants` 에서 propertyId + status='active' 가 1건이라도 있으면
  /// 한 줄 안내(노인 화법) 노출. 점수·% 노출 0건.
  Widget _buildTierPausedNotice(MLSProperty property) {
    return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('priority_grants')
          .where('propertyId', isEqualTo: property.id)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final QuerySnapshot<Map<String, dynamic>>? data = snapshot.data;
        if (data == null || data.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AirbnbColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AirbnbColors.warning.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(
                  Icons.info_outline,
                  size: 18,
                  color: AirbnbColors.warning,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    GrantMessages.tierPausedByGrantInline,
                    style: AppTypography.caption.copyWith(
                      color: AirbnbColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Task 06 — 매도자용 audit log 타임라인 (결정 사유 + 단계 이력).
  ///
  /// 본인 매물의 `priority_audit_logs` 를 시간 역순으로 노출.
  /// 80세 노인 화법 — eventType 한국어 라벨 + 상대시간만.
  /// inputs/outputs 등 점수·가중치는 *절대 노출 금지*.
  /// `tiered_release_step` 이벤트는 별도 ExpansionTile 단계 진행 이력에 모아 표시.
  /// Task 07 — 매물 모드(open/exclusive) 표시 + 변경 다이얼로그 진입점.
  ///
  /// 매도자 자율 선택임을 명백히 한다 (§33①9호 회피).
  /// "추천" 어휘 0건. exclusive 인 경우 지정한 중개사 ID 일부 노출(라벨이 없으면 원시 ID).
  Widget _buildListingModeSection(MLSProperty property) {
    final bool isExclusive = property.listingMode == 'exclusive';
    final List<String> ids = property.exclusiveBrokerIds;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isExclusive
            ? AirbnbColors.primary.withValues(alpha: 0.06)
            : AirbnbColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isExclusive ? AirbnbColors.primary : AirbnbColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                isExclusive ? Icons.verified_user : Icons.public,
                size: 18,
                color: isExclusive
                    ? AirbnbColors.primary
                    : AirbnbColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isExclusive
                      ? GrantMessages.listingModeCurrentExclusive
                      : GrantMessages.listingModeCurrentOpen,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AirbnbColors.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {
                  final bool changed =
                      await ListingModeChangeDialog.show(context, property);
                  if (changed && mounted) {
                    _loadProperties();
                  }
                },
                child: const Text(GrantMessages.listingModeChangeMenuTitle),
              ),
            ],
          ),
          if (isExclusive && ids.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Text(
                '${ids.length}${GrantMessages.sellerExclusiveCountSuffix}',
                style: AppTypography.bodySmall.copyWith(
                  color: AirbnbColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// P1-13 — 모드 변경 이력 섹션.
  ///
  /// `priority_audit_logs` collectionGroup 에서 propertyId + sellerUid 본인 일치 +
  /// `eventType == 'listing_mode_changed'` 이벤트만 필터링해 ExpansionTile 로 표시.
  ///
  /// 0건 → `SizedBox.shrink()` (조용한 빈 상태 — task 지시 #4).
  /// 표시 형식: '4월 12일 오후 2시 — 한두 명만으로 변경' (copy-deck §2.4 자연어 변형).
  /// 카피는 모두 [GrantMessages] 참조. raw 문자열·코드 노출 0.
  ///
  /// 쿼리는 [_buildAuditTimelineSection] 의 `getPropertyAuditLogs` 를 그대로 재사용
  /// (FutureBuilder 별도 호출 — 캐싱 X, dashboard 카드 빌드 빈도가 낮아 비용 무시).
  Widget _buildListingHistorySection(MLSProperty property) {
    return FutureBuilder<List<PriorityAuditLogEntry>>(
      future: PriorityAuditLogService().getPropertyAuditLogs(property.id),
      builder: (
        BuildContext context,
        AsyncSnapshot<List<PriorityAuditLogEntry>> snapshot,
      ) {
        if (snapshot.connectionState != ConnectionState.done) {
          // 로딩 중에는 자리 차지 0 — 위 audit timeline 섹션이 자체 로딩 표시 담당.
          return const SizedBox.shrink();
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const SizedBox.shrink();
        }

        // listing_mode_changed 만 필터 (exclusive_brokers_changed 는 같은 모드 내
        // 중개사 swap 으로 본 task 의 *모드 변경* 정의 외).
        final List<PriorityAuditLogEntry> modeChanges = snapshot.data!
            .where(
              (PriorityAuditLogEntry e) =>
                  e.eventType == 'listing_mode_changed',
            )
            .toList(growable: false);

        if (modeChanges.isEmpty) {
          // 변경 이력 0건 → 섹션 미표시 (task 지시 #4).
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: Container(
              decoration: BoxDecoration(
                color: AirbnbColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AirbnbColors.border),
              ),
              child: ExpansionTile(
                tilePadding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                title: Text(
                  GrantMessages.listingHistorySectionTitle,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                children: <Widget>[
                  for (final PriorityAuditLogEntry entry in modeChanges)
                    _buildListingHistoryRow(entry),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 모드 변경 이력 한 줄.
  /// "4월 12일 오후 2시 — 한두 명만으로 변경" 형식.
  /// inputs.newMode 만 읽어 방향 라벨 결정 (다른 inputs 필드는 UI 노출 0).
  Widget _buildListingHistoryRow(PriorityAuditLogEntry entry) {
    final String? newMode = entry.inputs['newMode'] as String?;
    final String directionLabel =
        GrantMessages.listingHistoryDirectionLabel(newMode);
    final String dateLabel = DateTimeFormatter.koreanAbsolute(entry.createdAt);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        4,
        AppSpacing.md,
        8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.swap_horiz,
            size: 16,
            color: AirbnbColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '$dateLabel — $directionLabel',
              style: AppTypography.bodySmall.copyWith(
                color: AirbnbColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditTimelineSection(MLSProperty property) {
    return FutureBuilder<List<PriorityAuditLogEntry>>(
      future: PriorityAuditLogService().getPropertyAuditLogs(property.id),
      builder: (context, snapshot) {
        final Widget header = Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(
            GrantMessages.auditTimelineTitle,
            style: AppTypography.h4.copyWith(
              fontWeight: FontWeight.w600,
              color: AirbnbColors.textPrimary,
            ),
          ),
        );

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              header,
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ],
          );
        }

        if (snapshot.hasError) {
          Logger.warning(
            'Audit timeline load failed',
            metadata: <String, dynamic>{
              'propertyId': property.id,
              'error': snapshot.error.toString(),
            },
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              header,
              Text(
                '내역을 불러오지 못했어요',
                style: AppTypography.caption.copyWith(
                  color: AirbnbColors.textSecondary,
                ),
              ),
            ],
          );
        }

        final List<PriorityAuditLogEntry> all =
            snapshot.data ?? const <PriorityAuditLogEntry>[];
        if (all.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              header,
              Text(
                GrantMessages.auditEmptyState,
                style: AppTypography.caption.copyWith(
                  color: AirbnbColors.textSecondary,
                ),
              ),
            ],
          );
        }

        // 단계 진행 이력만 분리 (Task 04 §5.4 #14)
        final List<PriorityAuditLogEntry> tierSteps = all
            .where(
              (PriorityAuditLogEntry e) => e.eventType == 'tiered_release_step',
            )
            .toList(growable: false);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            header,
            for (final PriorityAuditLogEntry entry in all)
              _buildAuditRow(entry),
            if (tierSteps.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              _buildTierHistoryExpansion(tierSteps),
            ],
          ],
        );
      },
    );
  }

  /// Problem 004 §2.3.2 — audit row 액션 시트 노출 대상 eventType 화이트리스트.
  /// grant 결정 결과로 매도자가 "이상해요" 이의를 걸 수 있는 사건만 진입 가능.
  /// participation/algorithm_config 같은 정보성 사건은 노출 X (의사결정 ≤2 유지).
  static const Set<String> _appealableEventTypes = <String>{
    'grant_issued',
    'grant_expired',
    'grant_revoked',
    'cap_blocked',
    'tiered_release_step',
    'appeal_resolved_with_listing_mode_override',
  };

  Widget _buildAuditRow(PriorityAuditLogEntry e) {
    final IconData icon = _auditEventIcon(e.eventType);
    final bool canAppeal = _appealableEventTypes.contains(e.eventType);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: AirbnbColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  GrantMessages.auditEventLabel(e.eventType),
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AirbnbColors.textPrimary,
                  ),
                ),
                Text(
                  DateTimeFormatter.timeAgo(e.createdAt),
                  style: AppTypography.caption.copyWith(
                    color: AirbnbColors.textLight,
                  ),
                ),
              ],
            ),
          ),
          // Problem 004 §2.3.2 — 행 단위 "이상해요로 알리기" 진입.
          if (canAppeal)
            TextButton(
              onPressed: () => _showAuditRowAppealSheet(e),
              style: TextButton.styleFrom(
                foregroundColor: AirbnbColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                GrantMessages.auditRowAppealActionLabel,
                style: AppTypography.caption.copyWith(
                  color: AirbnbColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Problem 004 갭 1 — 매도자 헤더 진입.
  /// PriorityAppealPage 의 옵션 A 일반화 — `role: AppealActorRole.seller`.
  void _openSellerAppealCenter() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PriorityAppealPage(
          actorUid: user.uid,
          role: AppealActorRole.seller,
        ),
      ),
    );
  }

  /// Problem 004 갭 1 — audit row 단위 진입 (bottom sheet 확인 1단계).
  ///
  /// 점수·기술 용어 노출 0 — 라벨은 `auditEventLabel(entry.eventType)` 만 사용.
  /// "이 결정이 이상하다고 알리시겠어요?" 한 줄로 결정 요약을 묻고
  /// 시트 [알리기] 탭 시 PriorityAppealPage 로 이동하면서 grantId 사전 선택.
  void _showAuditRowAppealSheet(PriorityAuditLogEntry entry) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final String? grantId = entry.grantId;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AirbnbColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AirbnbColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  GrantMessages.auditRowAppealConfirmTitle,
                  style: AppTypography.h4.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AirbnbColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                // 결정 요약 — eventType 한국어 라벨만 (점수/식별자 노출 0).
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AirbnbColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AirbnbColors.border),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        _auditEventIcon(entry.eventType),
                        size: 18,
                        color: AirbnbColors.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          GrantMessages.auditEventLabel(entry.eventType),
                          style: AppTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AirbnbColors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        DateTimeFormatter.timeAgo(entry.createdAt),
                        style: AppTypography.caption.copyWith(
                          color: AirbnbColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  GrantMessages.auditRowAppealConfirmBody,
                  style: AppTypography.bodySmall.copyWith(
                    color: AirbnbColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AirbnbColors.textSecondary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: AirbnbColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(GrantMessages.actionCancel),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) => PriorityAppealPage(
                                actorUid: user.uid,
                                role: AppealActorRole.seller,
                                preselectedGrantId: grantId,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AirbnbColors.primary,
                          foregroundColor: AirbnbColors.background,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          GrantMessages.auditRowAppealActionLabel,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _auditEventIcon(String eventType) {
    switch (eventType) {
      case 'grant_issued':
        return Icons.verified_user_outlined;
      case 'grant_expired':
      case 'grant_revoked':
        return Icons.history_toggle_off;
      case 'grant_fulfilled':
        return Icons.check_circle_outline;
      case 'cap_blocked':
        return Icons.block;
      case 'tiered_release_step':
        return Icons.share_outlined;
      case 'participation_declared':
      case 'participation_stage_advanced':
        return Icons.handshake_outlined;
      case 'appeal_filed':
      case 'appeal_resolved':
        return Icons.report_problem_outlined;
      case 'decision_replayed':
        return Icons.replay_outlined;
      default:
        return Icons.fiber_manual_record;
    }
  }

  Widget _buildTierHistoryExpansion(List<PriorityAuditLogEntry> steps) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        decoration: BoxDecoration(
          color: AirbnbColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AirbnbColors.border),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          title: Text(
            GrantMessages.myPropertyTierHistoryTitle,
            style: AppTypography.body.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          children: <Widget>[
            for (final PriorityAuditLogEntry s in steps)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  4,
                  AppSpacing.md,
                  8,
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.east,
                      size: 14,
                      color: AirbnbColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _tierStepLabel(s),
                        style: AppTypography.bodySmall,
                      ),
                    ),
                    Text(
                      DateTimeFormatter.timeAgo(s.createdAt),
                      style: AppTypography.caption.copyWith(
                        color: AirbnbColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// `outputs.toTier` 코드 → 한국어 라벨. 없으면 일반 진행 카피.
  String _tierStepLabel(PriorityAuditLogEntry e) {
    final dynamic raw = e.outputs['toTier'];
    final String? toTier = raw is String ? raw : null;
    if (toTier == null || toTier.isEmpty) {
      return GrantMessages.auditEventLabel(e.eventType);
    }
    final String label = GrantMessages.tierProgressCopy(toTier);
    if (label.isEmpty) return GrantMessages.auditEventLabel(e.eventType);
    return label;
  }

  /// 방문 요청 현황 프로그레스 바
  Widget _buildVisitRequestBar(_VisitRequestSummary summary) {
    final total = summary.pendingRequests + summary.approvedRequests + summary.viewedBrokers;
    if (total == 0) {
      return Container(
        height: 8,
        decoration: BoxDecoration(
          color: AirbnbColors.pillSecondary,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Text(
            '중개사 배포 대기중',
            style: AppTypography.caption.copyWith(
              color: AirbnbColors.textLight,
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
                child: Container(color: AirbnbColors.orange),
              ),
            if (summary.approvedRequests > 0)
              Expanded(
                flex: summary.approvedRequests,
                child: Container(color: AirbnbColors.green),
              ),
            if (summary.viewedBrokers > 0)
              Expanded(
                flex: summary.viewedBrokers,
                child: Container(color: AirbnbColors.primary),
              ),
            if (summary.totalBrokers - summary.viewedBrokers > 0)
              Expanded(
                flex: summary.totalBrokers - summary.viewedBrokers,
                child: Container(color: AirbnbColors.pillSecondary),
              ),
          ],
        ),
      ),
    );
  }

  /// 방문 요청 현황 숫자 표시
  Widget _buildVisitRequestStats(_VisitRequestSummary summary) {
    return Wrap(
      spacing: 12.0,
      runSpacing: AppSpacing.xs,
      children: [
        if (summary.pendingRequests > 0)
          _buildStatChip('방문요청', summary.pendingRequests, AirbnbColors.orange),
        if (summary.approvedRequests > 0)
          _buildStatChip('승인', summary.approvedRequests, AirbnbColors.green),
        if (summary.viewedBrokers > 0)
          _buildStatChip('열람', summary.viewedBrokers, AirbnbColors.primary),
      ],
    );
  }

  Widget _buildStatChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4.0),
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
            style: AppTypography.caption.copyWith(
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
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(
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
              backgroundColor: AirbnbColors.primary,
              foregroundColor: AirbnbColors.background,
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
          AppSnackBar.success(context, '상태가 "${_getStatusText(nextStatus)}"(으)로 변경되었습니다.');
        }
      } catch (e) {
        Logger.error('[SellerDashboard] 매물 상태 변경 실패', error: e);
        if (mounted) {
          AppSnackBar.error(context, '상태 변경에 실패했습니다. 잠시 후 다시 시도해 주세요.');
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
        AppSnackBar.warning(context, '승인된 방문 요청이 없습니다. 먼저 방문 요청을 승인해주세요.');
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
                        color: isSelected ? AirbnbColors.primary.withValues(alpha: 0.1) : null,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? AirbnbColors.primary : AirbnbColors.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.check_circle : Icons.circle_outlined,
                            color: isSelected ? AirbnbColors.primary : AirbnbColors.textLight,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(request.brokerName, style: const TextStyle(fontWeight: FontWeight.w500)),
                                Text('제안가: ${_formatPrice(request.proposedPrice)}',
                                  style:  AppTypography.withColor(AppTypography.captionLarge, AirbnbColors.textSecondary)),
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
                        AppSnackBar.info(context, '올바른 금액을 입력해주세요.');
                        return;
                      }
                      Navigator.pop(context, {
                        'brokerId': selectedBrokerId,
                        'price': price,
                      });
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AirbnbColors.primary,
                foregroundColor: AirbnbColors.background,
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
          AppSnackBar.success(context, '거래가 완료되었습니다.');
        }
      } catch (e) {
        Logger.error('[SellerDashboard] 거래 완료 처리 실패', error: e);
        if (mounted) {
          AppSnackBar.error(context, '거래 완료 처리에 실패했습니다. 잠시 후 다시 시도해 주세요.');
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

