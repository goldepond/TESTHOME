import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:property/api_request/admin_priority_service.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/constants/responsive_constants.dart';
import 'package:property/constants/spacing.dart';
import 'package:property/constants/typography.dart';
import 'package:property/models/platform_metric.dart';

/// 관리자 - 점유율 모니터링 페이지 (Task 06 + P2-5).
///
/// 상단 카드 4개 (오늘 통계) + 30일 총합 추이 라인 차트(yellow/red 임계 기준선)
/// + 우측 패널의 최근 red 알림 이벤트 리스트
/// + 시군구별 30일 추이 라인 차트 + 시군구 다중 선택 드롭다운 + 7일 평균 패널.
///
/// admin 화면은 80세 doctrine 면제 — copy-deck §6 운영자 직무 효율 우선.
/// 외부 노출 시 부연 설명: docs/common/admin-external-disclosure-guide.md §3.1
/// (점유율 / alertLevel = "MyHome 자체 카카오 패턴 회피 텔레메트리").
class AdminMetricsPage extends StatefulWidget {
  final String userId;
  final String userName;

  const AdminMetricsPage({
    required this.userId,
    required this.userName,
    super.key,
  });

  @override
  State<AdminMetricsPage> createState() => _AdminMetricsPageState();
}

class _AdminMetricsPageState extends State<AdminMetricsPage> {
  final AdminPriorityService _service = AdminPriorityService();
  final NumberFormat _intFmt = NumberFormat('#,###');
  final NumberFormat _pctFmt = NumberFormat.percentPattern('ko_KR')
    ..maximumFractionDigits = 2;

  /// yellow 임계 (점유율 30%)
  static const double _yellowThreshold = 0.30;

  /// red 임계 (점유율 40%)
  static const double _redThreshold = 0.40;

  /// P2-5 시군구 차트 색상 팔레트 (선택된 시군구 ≤ 6개 가정).
  static const List<Color> _districtPalette = [
    Color(0xFF3b82f6), // blue
    Color(0xFF8b5cf6), // purple
    Color(0xFF10b981), // green
    Color(0xFFf59e0b), // orange
    Color(0xFFec4899), // pink
    Color(0xFF14b8a6), // teal
  ];

  /// 사용자가 선택한 시군구 집합. 빈 집합이면 *상위 3개 시군구* 자동 표시.
  final Set<String> _selectedDistricts = <String>{};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AirbnbColors.surface,
      body: Center(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxWidth: ResponsiveHelper.getMaxWidth(context)),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: StreamBuilder<List<PlatformMetric>>(
              stream: _service.watchPlatformMetrics(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _errorBanner(snapshot.error);
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final metrics = snapshot.data!;
                if (metrics.isEmpty) {
                  return Center(
                    child: Text(
                      '아직 점유율 메트릭 데이터가 없습니다.',
                      style: AppTypography.body
                          .copyWith(color: AirbnbColors.textSecondary),
                    ),
                  );
                }

                // 가장 최신 = list 첫 항목 (date DESC).
                final latest = metrics.first;
                // 차트는 시간순(왼→오) 표시를 위해 정순으로 뒤집는다.
                final chronological = metrics.reversed.toList();
                final redEvents = metrics
                    .where((m) => m.alertLevel == AlertLevel.red)
                    .toList();

                // 시군구 마스터 — 30일 누적 매물수 DESC 정렬.
                final districtTotals = <String, int>{};
                for (final m in metrics) {
                  m.districtCounts.forEach((district, count) {
                    districtTotals[district] =
                        (districtTotals[district] ?? 0) + count;
                  });
                }
                final allDistricts = districtTotals.keys.toList()
                  ..sort((a, b) =>
                      (districtTotals[b] ?? 0).compareTo(districtTotals[a] ?? 0));

                // 선택된 시군구 — 빈 집합이면 상위 3개 자동.
                final activeDistricts = _selectedDistricts.isEmpty
                    ? allDistricts.take(3).toList()
                    : _selectedDistricts.toList();

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: AppSpacing.md),
                      _buildSummaryCards(latest),
                      const SizedBox(height: AppSpacing.md),
                      _buildAlertHeroAndTrend(latest, metrics),
                      const SizedBox(height: AppSpacing.md),
                      SizedBox(
                        height: 360,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: _buildChartCard(chronological),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              flex: 2,
                              child: _buildRedAlertsPanel(redEvents),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _buildDistrictSection(
                        chronological: chronological,
                        latest: latest,
                        allDistricts: allDistricts,
                        activeDistricts: activeDistricts,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(Icons.insights, color: AirbnbColors.primary, size: 28),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '점유율 모니터링',
          style: AppTypography.h2.copyWith(color: AirbnbColors.textPrimary),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(
          '관리자: ${widget.userName}',
          style: AppTypography.caption
              .copyWith(color: AirbnbColors.textSecondary),
        ),
      ],
    );
  }

  Widget _errorBanner(Object? error) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AirbnbColors.error.withValues(alpha: 0.08),
          border: Border.all(color: AirbnbColors.error),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Text(
          '메트릭을 불러오지 못했습니다: $error',
          style: AppTypography.body.copyWith(color: AirbnbColors.error),
        ),
      ),
    );
  }

  Widget _buildSummaryCards(PlatformMetric latest) {
    final shareText = _pctFmt.format(latest.estimatedRegionMarketShare);
    final alertColor = _alertColor(latest.alertLevel);
    final alertLabel = _alertLabel(latest.alertLevel);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 900;
        final cards = <Widget>[
          _summaryCard(
            icon: Icons.home_work_outlined,
            label: '활성 매물',
            value: _intFmt.format(latest.totalActiveListings),
            color: AirbnbColors.primary,
          ),
          _summaryCard(
            icon: Icons.business_rounded,
            label: '활성 중개사',
            value: _intFmt.format(latest.totalActiveBrokers),
            color: AirbnbColors.primary,
          ),
          _summaryCard(
            icon: Icons.pie_chart_outline,
            label: '추정 지역 점유율',
            value: shareText,
            color: alertColor,
          ),
          _summaryCard(
            icon: Icons.notifications_active_outlined,
            label: '경보 단계',
            value: alertLabel,
            color: alertColor,
          ),
        ];

        if (isNarrow) {
          return Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: cards
                .map((c) => SizedBox(
                      width: (constraints.maxWidth - AppSpacing.sm) / 2,
                      child: c,
                    ))
                .toList(),
          );
        }
        return Row(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              Expanded(child: cards[i]),
              if (i < cards.length - 1)
                const SizedBox(width: AppSpacing.sm),
            ],
          ],
        );
      },
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AirbnbColors.background,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: AirbnbColors.textPrimary.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.caption
                      .copyWith(color: AirbnbColors.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTypography.h3.copyWith(color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(List<PlatformMetric> chronological) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AirbnbColors.background,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: AirbnbColors.textPrimary.withValues(alpha: 0.05),
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
              Text(
                '30일 점유율 추이',
                style: AppTypography.h4
                    .copyWith(color: AirbnbColors.textPrimary),
              ),
              const Spacer(),
              _legendDot(Colors.orange, 'yellow ≥ 30%'),
              const SizedBox(width: AppSpacing.sm),
              _legendDot(Colors.red, 'red ≥ 40%'),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(child: _buildLineChart(chronological)),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTypography.caption
              .copyWith(color: AirbnbColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildLineChart(List<PlatformMetric> chronological) {
    if (chronological.isEmpty) {
      return Center(
        child: Text(
          '데이터 없음',
          style: AppTypography.bodySmall
              .copyWith(color: AirbnbColors.textSecondary),
        ),
      );
    }

    final spots = <FlSpot>[];
    for (var i = 0; i < chronological.length; i++) {
      final share = chronological[i].estimatedRegionMarketShare;
      spots.add(FlSpot(i.toDouble(), share));
    }

    final maxYRaw = spots.map((s) => s.y).fold<double>(0.0,
        (prev, curr) => curr > prev ? curr : prev);
    final maxY = (maxYRaw < _redThreshold + 0.05)
        ? _redThreshold + 0.10
        : (maxYRaw + 0.10).clamp(0.0, 1.0);

    final lastIndex = (chronological.length - 1).toDouble();

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: lastIndex,
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          horizontalInterval: 0.1,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AirbnbColors.textLight.withValues(alpha: 0.3),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(
            color: AirbnbColors.textLight.withValues(alpha: 0.4),
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: 0.1,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    '${(value * 100).toStringAsFixed(0)}%',
                    style: AppTypography.caption
                        .copyWith(color: AirbnbColors.textSecondary),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: (chronological.length / 6).ceilToDouble().clamp(1, 10),
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= chronological.length) {
                  return const SizedBox.shrink();
                }
                final dateStr = chronological[i].date;
                final short = dateStr.length >= 10
                    ? dateStr.substring(5, 10)
                    : dateStr;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    short,
                    style: AppTypography.caption
                        .copyWith(color: AirbnbColors.textSecondary),
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(),
          topTitles: const AxisTitles(),
        ),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: _yellowThreshold,
              color: Colors.orange,
              strokeWidth: 1.5,
              dashArray: [6, 4],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
                labelResolver: (_) => 'yellow 30%',
              ),
            ),
            HorizontalLine(
              y: _redThreshold,
              color: Colors.red,
              strokeWidth: 1.5,
              dashArray: [6, 4],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
                labelResolver: (_) => 'red 40%',
              ),
            ),
          ],
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AirbnbColors.primary,
            barWidth: 2.5,
            dotData: FlDotData(
              getDotPainter: (spot, percent, barData, index) {
                final metric = chronological[index];
                final color = _alertColor(metric.alertLevel);
                return FlDotCirclePainter(
                  radius: 3.5,
                  color: color,
                  strokeColor: color,
                  strokeWidth: 1.5,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AirbnbColors.primary.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRedAlertsPanel(List<PlatformMetric> redEvents) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AirbnbColors.background,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: AirbnbColors.textPrimary.withValues(alpha: 0.05),
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
              const Icon(Icons.report_outlined,
                  color: Colors.red, size: 20),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '최근 red 경보',
                style: AppTypography.h4
                    .copyWith(color: AirbnbColors.textPrimary),
              ),
              const SizedBox(width: AppSpacing.xs),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${redEvents.length}건',
                  style: AppTypography.caption.copyWith(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: redEvents.isEmpty
                ? Center(
                    child: Text(
                      'red 경보 이력 없음',
                      style: AppTypography.bodySmall
                          .copyWith(color: AirbnbColors.textSecondary),
                    ),
                  )
                : ListView.separated(
                    itemCount: redEvents.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final m = redEvents[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.warning_amber_rounded,
                            color: Colors.red),
                        title: Text(
                          m.date,
                          style: AppTypography.body.copyWith(
                              color: AirbnbColors.textPrimary,
                              fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '점유율 ${_pctFmt.format(m.estimatedRegionMarketShare)} '
                          '/ 매물 ${_intFmt.format(m.totalActiveListings)} '
                          '/ 중개사 ${_intFmt.format(m.totalActiveBrokers)}',
                          style: AppTypography.caption
                              .copyWith(color: AirbnbColors.textSecondary),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Color _alertColor(AlertLevel level) {
    return switch (level) {
      AlertLevel.green => Colors.green,
      AlertLevel.yellow => Colors.orange,
      AlertLevel.red => Colors.red,
    };
  }

  String _alertLabel(AlertLevel level) {
    return switch (level) {
      AlertLevel.green => '정상',
      AlertLevel.yellow => '경고',
      AlertLevel.red => '위험',
    };
  }

  // ============================================================
  // P2-5 — 시군구별 점유율 차트 + alertLevel 큰 라벨 + 7일 평균
  // ============================================================

  /// 현재 alertLevel 큰 라벨 + 최근 7일 평균 점유율을 한 행에 표시.
  /// metrics는 date DESC 정렬되어 있다고 가정.
  Widget _buildAlertHeroAndTrend(
    PlatformMetric latest,
    List<PlatformMetric> metricsDesc,
  ) {
    final alertColor = _alertColor(latest.alertLevel);
    final alertLabel = _alertLabel(latest.alertLevel);

    // 최근 7일 평균 (보유 데이터가 7일 미만이면 보유분 평균).
    final window = metricsDesc.take(7).toList();
    final avgShare = window.isEmpty
        ? 0.0
        : window.fold<double>(
              0.0,
              (sum, m) => sum + m.estimatedRegionMarketShare,
            ) /
            window.length;
    final windowDays = window.length;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AirbnbColors.background,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: alertColor.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: alertColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 700;
          final children = <Widget>[
            Expanded(child: _buildAlertHero(latest, alertColor, alertLabel)),
            isNarrow
                ? const SizedBox(height: AppSpacing.md)
                : const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: _buildAvgPanel(avgShare, windowDays),
            ),
          ];
          return isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children
                      .map((c) => c is Expanded ? c.child : c)
                      .toList(),
                )
              : Row(
                  children: children,
                );
        },
      ),
    );
  }

  Widget _buildAlertHero(PlatformMetric latest, Color color, String label) {
    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Icon(
            switch (latest.alertLevel) {
              AlertLevel.green => Icons.check_circle_outline,
              AlertLevel.yellow => Icons.warning_amber_rounded,
              AlertLevel.red => Icons.report_problem_rounded,
            },
            color: color,
            size: 36,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '현재 경보 단계',
                style: AppTypography.caption
                    .copyWith(color: AirbnbColors.textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTypography.h1.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '오늘 점유율 ${_pctFmt.format(latest.estimatedRegionMarketShare)} '
                '· ${latest.date}',
                style: AppTypography.caption
                    .copyWith(color: AirbnbColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvgPanel(double avgShare, int days) {
    final avgColor = avgShare >= _redThreshold
        ? Colors.red
        : avgShare >= _yellowThreshold
            ? Colors.orange
            : Colors.green;
    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: avgColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Icon(Icons.trending_up_rounded, color: avgColor, size: 36),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '최근 ${days == 0 ? 7 : days}일 평균 점유율',
                style: AppTypography.caption
                    .copyWith(color: AirbnbColors.textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                _pctFmt.format(avgShare),
                style: AppTypography.h1.copyWith(
                  color: avgColor,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                'yellow ≥ 30% / red ≥ 40% 임계 기준',
                style: AppTypography.caption
                    .copyWith(color: AirbnbColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 시군구 다중 선택 + 시계열 라인 차트 카드.
  Widget _buildDistrictSection({
    required List<PlatformMetric> chronological,
    required PlatformMetric latest,
    required List<String> allDistricts,
    required List<String> activeDistricts,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AirbnbColors.background,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: AirbnbColors.textPrimary.withValues(alpha: 0.05),
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
              const Icon(Icons.map_outlined,
                  color: AirbnbColors.primary, size: 22),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '시군구별 30일 점유율 추이',
                style: AppTypography.h4
                    .copyWith(color: AirbnbColors.textPrimary),
              ),
              const Spacer(),
              if (_selectedDistricts.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    if (mounted) {
                      setState(() => _selectedDistricts.clear());
                    }
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('상위 3개로 초기화'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (allDistricts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(
                child: Text(
                  '시군구별 집계 데이터가 아직 없습니다.\n'
                  '(Cloud Function computeDailyMetricsScheduled 첫 실행 후 적재)',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall
                      .copyWith(color: AirbnbColors.textSecondary),
                ),
              ),
            )
          else ...[
            _buildDistrictSelector(allDistricts),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 320,
              child: _buildDistrictLineChart(chronological, activeDistricts),
            ),
            const SizedBox(height: AppSpacing.md),
            _buildDistrictAvgTable(chronological, activeDistricts, latest),
          ],
        ],
      ),
    );
  }

  /// 시군구 선택 — Wrap+FilterChip 다중 토글. 선택 해제 시 빈 집합 → 상위 3개 자동.
  Widget _buildDistrictSelector(List<String> allDistricts) {
    // admin은 운영 효율 우선이므로 30개 이내 시군구를 한 화면에 노출.
    // 30개 초과 시 상위 30개만 노출 (활동 기준).
    final visible = allDistricts.length > 30
        ? allDistricts.take(30).toList()
        : allDistricts;

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final district in visible)
          FilterChip(
            label: Text(district),
            selected: _selectedDistricts.contains(district),
            onSelected: (isSelected) {
              if (!mounted) return;
              setState(() {
                if (isSelected) {
                  _selectedDistricts.add(district);
                } else {
                  _selectedDistricts.remove(district);
                }
              });
            },
            selectedColor: AirbnbColors.primary.withValues(alpha: 0.15),
            checkmarkColor: AirbnbColors.primary,
            labelStyle: AppTypography.caption.copyWith(
              color: _selectedDistricts.contains(district)
                  ? AirbnbColors.primary
                  : AirbnbColors.textSecondary,
              fontWeight: _selectedDistricts.contains(district)
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }

  /// 시군구별 점유율(`districtListings / max(totalActiveBrokers*5, 1)`) 시계열 라인 차트.
  Widget _buildDistrictLineChart(
    List<PlatformMetric> chronological,
    List<String> activeDistricts,
  ) {
    if (chronological.isEmpty || activeDistricts.isEmpty) {
      return Center(
        child: Text(
          '표시할 시군구를 선택하세요',
          style: AppTypography.bodySmall
              .copyWith(color: AirbnbColors.textSecondary),
        ),
      );
    }

    // 시군구별 spots.
    final lineBars = <LineChartBarData>[];
    double maxYRaw = 0;
    for (var i = 0; i < activeDistricts.length; i++) {
      final district = activeDistricts[i];
      final color = _districtPalette[i % _districtPalette.length];
      final spots = <FlSpot>[];
      for (var j = 0; j < chronological.length; j++) {
        final m = chronological[j];
        final share = m.districtShare(district);
        if (share > maxYRaw) maxYRaw = share;
        spots.add(FlSpot(j.toDouble(), share));
      }
      lineBars.add(
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: color,
          barWidth: 2.5,
          dotData: FlDotData(
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 2.5,
                color: color,
                strokeColor: color,
                strokeWidth: 1.0,
              );
            },
          ),
        ),
      );
    }

    final maxY = (maxYRaw < _redThreshold + 0.05)
        ? _redThreshold + 0.10
        : (maxYRaw + 0.10).clamp(0.0, 1.0);
    final lastIndex = (chronological.length - 1).toDouble();

    return Column(
      children: [
        // 범례.
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: 4,
          children: [
            for (var i = 0; i < activeDistricts.length; i++)
              _legendDot(
                _districtPalette[i % _districtPalette.length],
                activeDistricts[i],
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: lastIndex,
              minY: 0,
              maxY: maxY,
              gridData: FlGridData(
                horizontalInterval: 0.1,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: AirbnbColors.textLight.withValues(alpha: 0.3),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(
                  color: AirbnbColors.textLight.withValues(alpha: 0.4),
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    interval: 0.1,
                    getTitlesWidget: (value, meta) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          '${(value * 100).toStringAsFixed(0)}%',
                          style: AppTypography.caption
                              .copyWith(color: AirbnbColors.textSecondary),
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    interval:
                        (chronological.length / 6).ceilToDouble().clamp(1, 10),
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= chronological.length) {
                        return const SizedBox.shrink();
                      }
                      final dateStr = chronological[i].date;
                      final short = dateStr.length >= 10
                          ? dateStr.substring(5, 10)
                          : dateStr.length >= 8
                              ? '${dateStr.substring(4, 6)}-${dateStr.substring(6, 8)}'
                              : dateStr;
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          short,
                          style: AppTypography.caption
                              .copyWith(color: AirbnbColors.textSecondary),
                        ),
                      );
                    },
                  ),
                ),
                rightTitles: const AxisTitles(),
                topTitles: const AxisTitles(),
              ),
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: _yellowThreshold,
                    color: Colors.orange,
                    strokeWidth: 1.0,
                    dashArray: [4, 4],
                  ),
                  HorizontalLine(
                    y: _redThreshold,
                    color: Colors.red,
                    strokeWidth: 1.0,
                    dashArray: [4, 4],
                  ),
                ],
              ),
              lineBarsData: lineBars,
            ),
          ),
        ),
      ],
    );
  }

  /// 선택된 시군구별 *오늘 점유율* + *최근 7일 평균* 표.
  Widget _buildDistrictAvgTable(
    List<PlatformMetric> chronological,
    List<String> activeDistricts,
    PlatformMetric latest,
  ) {
    if (activeDistricts.isEmpty) return const SizedBox.shrink();

    // 최근 7일 = 시간순 chronological 의 *마지막* 7개.
    final tail = chronological.length <= 7
        ? chronological
        : chronological.sublist(chronological.length - 7);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Text(
            '시군구별 현재값 / 7일 평균',
            style: AppTypography.bodySmall
                .copyWith(color: AirbnbColors.textSecondary),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AirbnbColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: AirbnbColors.border,
            ),
          ),
          child: Column(
            children: [
              for (var i = 0; i < activeDistricts.length; i++)
                _buildDistrictAvgRow(
                  district: activeDistricts[i],
                  color: _districtPalette[i % _districtPalette.length],
                  todayShare: latest.districtShare(activeDistricts[i]),
                  todayCount: latest.districtCounts[activeDistricts[i]] ?? 0,
                  avgShare: tail.isEmpty
                      ? 0
                      : tail.fold<double>(
                            0,
                            (sum, m) => sum + m.districtShare(activeDistricts[i]),
                          ) /
                          tail.length,
                  isLast: i == activeDistricts.length - 1,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDistrictAvgRow({
    required String district,
    required Color color,
    required double todayShare,
    required int todayCount,
    required double avgShare,
    required bool isLast,
  }) {
    final todayAlertColor = todayShare >= _redThreshold
        ? Colors.red
        : todayShare >= _yellowThreshold
            ? Colors.orange
            : AirbnbColors.textPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: AirbnbColors.border.withValues(alpha: 0.6),
                ),
              ),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 3,
            child: Text(
              district,
              style: AppTypography.body
                  .copyWith(color: AirbnbColors.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '오늘 ${_pctFmt.format(todayShare)}'
              ' (${_intFmt.format(todayCount)}건)',
              style: AppTypography.bodySmall.copyWith(
                color: todayAlertColor,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.end,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 2,
            child: Text(
              '7일 평균 ${_pctFmt.format(avgShare)}',
              style: AppTypography.caption
                  .copyWith(color: AirbnbColors.textSecondary),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
