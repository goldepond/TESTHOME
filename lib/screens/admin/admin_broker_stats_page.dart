import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/constants/responsive_constants.dart';
import 'package:property/api_request/broker_stats_service.dart';
import 'package:property/models/broker_stats.dart';
import 'package:property/constants/typography.dart';

/// 관리자용 중개사 통계 페이지
///
/// 행동 데이터 기반의 중개사 성과 지표를 모니터링합니다.
class AdminBrokerStatsPage extends StatefulWidget {
  final String userId;
  final String userName;

  const AdminBrokerStatsPage({
    required this.userId,
    required this.userName,
    super.key,
  });

  @override
  State<AdminBrokerStatsPage> createState() => _AdminBrokerStatsPageState();
}

class _AdminBrokerStatsPageState extends State<AdminBrokerStatsPage> {
  final BrokerStatsService _statsService = BrokerStatsService();
  bool _isLoading = true;
  Map<String, dynamic> _overallStats = {};
  List<BrokerStats> _brokerStats = [];
  String _sortBy = 'completedDeals';
  bool _sortDescending = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final overall = await _statsService.getOverallStatsSummary();
      final brokers = await _statsService.getAllBrokerStats();

      if (mounted) {
        setState(() {
          _overallStats = overall;
          _brokerStats = brokers;
          _sortBrokers();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _sortBrokers() {
    _brokerStats.sort((a, b) {
      int comparison;
      switch (_sortBy) {
        case 'completedDeals':
          comparison = a.completedDeals.compareTo(b.completedDeals);
          break;
        case 'visitSuccessRate':
          comparison = a.visitSuccessRate.compareTo(b.visitSuccessRate);
          break;
        case 'noShowRate':
          comparison = a.noShowRate.compareTo(b.noShowRate);
          break;
        case 'reliabilityScore':
          comparison = a.reliabilityScore.compareTo(b.reliabilityScore);
          break;
        case 'totalRequests':
          comparison = a.totalRequests.compareTo(b.totalRequests);
          break;
        default:
          comparison = a.completedDeals.compareTo(b.completedDeals);
      }
      return _sortDescending ? -comparison : comparison;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AirbnbColors.surface,
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: ResponsiveHelper.getMaxWidth(context)),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildOverallStats(),
                        const SizedBox(height: 24),
                        _buildBrokerList(),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildOverallStats() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AirbnbColors.background,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AirbnbColors.textPrimary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AirbnbColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.analytics_rounded,
                  color: AirbnbColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
                Text(
                '전체 통계 요약',
                style: AppTypography.withColor(AppTypography.h4, AirbnbColors.textPrimary),
              ),
              const Spacer(),
              IconButton(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: '새로고침',
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildStatCard(
                '총 중개사',
                '${_overallStats['totalBrokers'] ?? 0}명',
                Icons.people_rounded,
                AirbnbColors.primary,
              ),
              _buildStatCard(
                '총 방문 요청',
                '${_overallStats['totalRequests'] ?? 0}건',
                Icons.send_rounded,
                AirbnbColors.info,
              ),
              _buildStatCard(
                '총 승인',
                '${_overallStats['totalApproved'] ?? 0}건',
                Icons.check_circle_rounded,
                AirbnbColors.green,
              ),
              _buildStatCard(
                '총 거래 완료',
                '${_overallStats['totalDeals'] ?? 0}건',
                Icons.handshake_rounded,
                AirbnbColors.orange,
              ),
              _buildStatCard(
                '총 노쇼',
                '${_overallStats['totalNoShows'] ?? 0}건',
                Icons.person_off_rounded,
                AirbnbColors.red,
              ),
              _buildStatCard(
                '평균 방문 성사율',
                '${((_overallStats['avgVisitSuccessRate'] ?? 0.0) * 100).toStringAsFixed(1)}%',
                Icons.trending_up_rounded,
                AirbnbColors.green,
              ),
              _buildStatCard(
                '평균 노쇼율',
                '${((_overallStats['avgNoShowRate'] ?? 0.0) * 100).toStringAsFixed(1)}%',
                Icons.trending_down_rounded,
                AirbnbColors.red,
              ),
              _buildStatCard(
                '총 거래 금액',
                _formatAmount(_overallStats['totalDealAmount'] ?? 0.0),
                Icons.attach_money_rounded,
                AirbnbColors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTypography.withColor(AppTypography.h3, color),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style:  AppTypography.withColor(AppTypography.caption, AirbnbColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildBrokerList() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AirbnbColors.background,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AirbnbColors.textPrimary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
                Text(
                '중개사별 성과 지표',
                style: AppTypography.withColor(AppTypography.h4, AirbnbColors.textPrimary),
              ),
              const SizedBox(width: 8),
              Text(
                '(${_brokerStats.length}명)',
                style:  AppTypography.withColor(AppTypography.bodySmall, AirbnbColors.textSecondary),
              ),
              const Spacer(),
              _buildSortDropdown(),
            ],
          ),
          const SizedBox(height: 16),
          if (_brokerStats.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  '아직 수집된 통계가 없습니다',
                  style: TextStyle(color: AirbnbColors.textSecondary),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _brokerStats.length,
              separatorBuilder: (_, _) => const Divider(height: 24),
              itemBuilder: (context, index) => _buildBrokerItem(_brokerStats[index], index + 1),
            ),
        ],
      ),
    );
  }

  Widget _buildSortDropdown() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('정렬: ', style: AppTypography.caption),
        DropdownButton<String>(
          value: _sortBy,
          underline: const SizedBox(),
          isDense: true,
          items: const [
            DropdownMenuItem(value: 'completedDeals', child: Text('거래 완료')),
            DropdownMenuItem(value: 'reliabilityScore', child: Text('신뢰도 점수')),
            DropdownMenuItem(value: 'visitSuccessRate', child: Text('방문 성사율')),
            DropdownMenuItem(value: 'noShowRate', child: Text('노쇼율')),
            DropdownMenuItem(value: 'totalRequests', child: Text('총 요청')),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _sortBy = value;
                _sortBrokers();
              });
            }
          },
        ),
        IconButton(
          onPressed: () {
            setState(() {
              _sortDescending = !_sortDescending;
              _sortBrokers();
            });
          },
          icon: Icon(
            _sortDescending ? Icons.arrow_downward : Icons.arrow_upward,
            size: 18,
          ),
          tooltip: _sortDescending ? '내림차순' : '오름차순',
        ),
      ],
    );
  }

  Widget _buildBrokerItem(BrokerStats stats, int rank) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: rank <= 3 ? AirbnbColors.primary.withValues(alpha: 0.03) : null,
        borderRadius: BorderRadius.circular(12),
        border: rank <= 3
            ? Border.all(color: AirbnbColors.primary.withValues(alpha: 0.1))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더: 순위 + 이름 + 회사
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _getRankColor(rank),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style:  AppTypography.bodySmall.copyWith(color: AirbnbColors.background, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stats.brokerName,
                      style:  AppTypography.body.copyWith(color: AirbnbColors.textPrimary, fontWeight: FontWeight.w600),
                    ),
                    if (stats.brokerCompany != null)
                      Text(
                        stats.brokerCompany!,
                        style:  AppTypography.withColor(AppTypography.caption, AirbnbColors.textSecondary),
                      ),
                  ],
                ),
              ),
              // 신뢰도 점수 배지
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getScoreColor(stats.reliabilityScore),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(stats.reliabilityScore * 100).toStringAsFixed(0)}점',
                  style:  AppTypography.caption.copyWith(color: AirbnbColors.background, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 지표 그리드
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildMetricChip(
                '방문 요청',
                '${stats.totalRequests}건',
                Icons.send_outlined,
              ),
              _buildMetricChip(
                '승인',
                '${stats.approvedRequests}건',
                Icons.check_circle_outline,
              ),
              _buildMetricChip(
                '방문 성사율',
                '${(stats.visitSuccessRate * 100).toStringAsFixed(1)}%',
                Icons.trending_up,
                isHighlight: stats.visitSuccessRate >= 0.7,
                isWarning: stats.visitSuccessRate < 0.4,
              ),
              _buildMetricChip(
                '노쇼율',
                '${(stats.noShowRate * 100).toStringAsFixed(1)}%',
                Icons.person_off_outlined,
                isHighlight: stats.noShowRate <= 0.05,
                isWarning: stats.noShowRate > 0.15,
              ),
              _buildMetricChip(
                '거래 완료',
                '${stats.completedDeals}건',
                Icons.handshake_outlined,
              ),
              _buildMetricChip(
                '평균 응답',
                stats.avgResponseTimeFormatted,
                Icons.timer_outlined,
                isHighlight: stats.avgResponseTimeSeconds < 3600,
              ),
              _buildMetricChip(
                '제안가 정직도',
                '${(stats.avgPriceDeviation * 100).toStringAsFixed(0)}%',
                Icons.price_check,
                isHighlight: stats.avgPriceDeviation >= 0.95,
                isWarning: stats.avgPriceDeviation < 0.85,
              ),
            ],
          ),

          // 지역별 거래 (있는 경우)
          if (stats.dealsByRegion.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: stats.dealsByRegion.entries.map((e) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AirbnbColors.textLight.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${e.key} ${e.value}건',
                    style:  AppTypography.withColor(AppTypography.caption, AirbnbColors.textSecondary),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricChip(
    String label,
    String value,
    IconData icon, {
    bool isHighlight = false,
    bool isWarning = false,
  }) {
    Color bgColor = AirbnbColors.surface;
    Color textColor = AirbnbColors.textPrimary;

    if (isWarning) {
      bgColor = AirbnbColors.red.withValues(alpha: 0.1);
      textColor = AirbnbColors.red;
    } else if (isHighlight) {
      bgColor = AirbnbColors.green.withValues(alpha: 0.1);
      textColor = AirbnbColors.green;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            '$label: ',
            style: AppTypography.withColor(AppTypography.caption, textColor.withValues(alpha: 0.7)),
          ),
          Text(
            value,
            style: AppTypography.caption.copyWith(color: textColor, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return AirbnbColors.orange;
      case 2:
        return AirbnbColors.textSecondary;
      case 3:
        return AirbnbColors.primary;
      default:
        return AirbnbColors.textLight;
    }
  }

  Color _getScoreColor(double score) {
    if (score >= 0.8) return AirbnbColors.green;
    if (score >= 0.6) return AirbnbColors.info;
    if (score >= 0.4) return AirbnbColors.orange;
    return AirbnbColors.red;
  }

  String _formatAmount(double amount) {
    if (amount >= 10000) {
      final billions = (amount / 10000).floor();
      return '$billions억+';
    }
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}천만';
    }
    return '${amount.toStringAsFixed(0)}만';
  }
}
