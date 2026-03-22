import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../api_request/real_transaction_service.dart';
import '../constants/apple_design_system.dart';

/// 월별 평균가 추이 그래프
class PriceTrendChart extends StatelessWidget {
  final List<RealTransaction> transactions;
  final String transactionType;
  final int months;

  const PriceTrendChart({
    required this.transactions,
    required this.transactionType,
    super.key,
    this.months = 12,
  });

  @override
  Widget build(BuildContext context) {
    final monthlyData = _calculateMonthlyAverages();

    if (monthlyData.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppleSpacing.lg),
        decoration: BoxDecoration(
          color: AppleColors.secondarySystemGroupedBackground,
          borderRadius: BorderRadius.circular(AppleRadius.lg),
        ),
        child: Center(
          child: Text(
            '그래프를 표시할 데이터가 부족합니다.',
            style: AppleTypography.footnote.copyWith(
              color: AppleColors.secondaryLabel,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppleSpacing.md),
      decoration: BoxDecoration(
        color: AppleColors.secondarySystemGroupedBackground,
        borderRadius: BorderRadius.circular(AppleRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.show_chart,
                size: 18,
                color: AppleColors.systemBlue,
              ),
              const SizedBox(width: AppleSpacing.xs),
              Text(
                '월별 평균가 추이',
                style: AppleTypography.headline.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '최근 $months개월',
                style: AppleTypography.caption1.copyWith(
                  color: AppleColors.secondaryLabel,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppleSpacing.md),
          SizedBox(
            height: 200,
            child: _buildChart(monthlyData),
          ),
          const SizedBox(height: AppleSpacing.sm),
          _buildLegend(monthlyData),
        ],
      ),
    );
  }

  /// 월별 평균가 계산 (12개월 전체 표시, 데이터 없는 월은 null)
  List<_MonthlyAverage> _calculateMonthlyAverages() {
    // 최근 months개월의 월 목록 생성
    final now = DateTime.now();
    final List<_MonthlyAverage> result = [];

    // 월별로 그룹핑
    final Map<String, List<int>> monthlyPrices = {};

    for (final t in transactions) {
      final key = '${t.dealYear}-${t.dealMonth.toString().padLeft(2, '0')}';
      monthlyPrices.putIfAbsent(key, () => []);

      // 월세의 경우 보증금 사용
      final price = transactionType == '월세' ? (t.deposit ?? t.dealAmount) : t.dealAmount;
      monthlyPrices[key]!.add(price);
    }

    // months개월 전체에 대해 데이터 생성 (과거 → 현재 순)
    for (int i = months - 1; i >= 0; i--) {
      final targetDate = DateTime(now.year, now.month - i);
      final key = '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}';

      if (monthlyPrices.containsKey(key)) {
        final prices = monthlyPrices[key]!;
        final avg = prices.reduce((a, b) => a + b) ~/ prices.length;
        result.add(_MonthlyAverage(
          year: targetDate.year,
          month: targetDate.month,
          average: avg,
          count: prices.length,
        ));
      } else {
        // 데이터 없는 월도 포함 (average = null로 표시)
        result.add(_MonthlyAverage(
          year: targetDate.year,
          month: targetDate.month,
          average: null,
          count: 0,
        ));
      }
    }

    return result;
  }

  Widget _buildChart(List<_MonthlyAverage> data) {
    // 데이터가 있는 월만 필터링
    final dataWithValues = data.where((d) => d.hasData).toList();

    if (dataWithValues.length < 2) {
      return Center(
        child: Text(
          '그래프를 그리려면 최소 2개월 데이터가 필요합니다.',
          style: AppleTypography.footnote.copyWith(
            color: AppleColors.secondaryLabel,
          ),
        ),
      );
    }

    // 데이터 있는 월만 spots으로 변환 (x축은 전체 데이터 기준 인덱스)
    final spots = <FlSpot>[];
    for (int i = 0; i < data.length; i++) {
      if (data[i].hasData) {
        spots.add(FlSpot(i.toDouble(), data[i].average!.toDouble()));
      }
    }

    final validAverages = dataWithValues.map((d) => d.average!).toList();
    final minY = validAverages.reduce((a, b) => a < b ? a : b) * 0.9;
    final maxY = validAverages.reduce((a, b) => a > b ? a : b) * 1.1;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: (maxY - minY) / 4,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: AppleColors.separator.withValues(alpha: 0.5),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= data.length) {
                  return const SizedBox.shrink();
                }
                // 너무 많으면 일부만 표시
                if (data.length > 6 && index % 2 != 0) {
                  return const SizedBox.shrink();
                }
                final item = data[index];
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${item.month}월',
                    style: AppleTypography.caption2.copyWith(
                      color: AppleColors.secondaryLabel,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 55,
              getTitlesWidget: (value, meta) {
                return Text(
                  _formatShortPrice(value.toInt()),
                  style: AppleTypography.caption2.copyWith(
                    color: AppleColors.secondaryLabel,
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (data.length - 1).toDouble(),
        minY: minY,
        maxY: maxY,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (spot) => AppleColors.label,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.toInt();
                if (index < 0 || index >= data.length) return null;
                final item = data[index];
                if (!item.hasData) return null;
                return LineTooltipItem(
                  '${item.year}.${item.month}월\n${RealTransaction.formatKoreanPrice(item.average!)}\n(${item.count}건)',
                  AppleTypography.caption1.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: AppleColors.systemBlue,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              getDotPainter: (spot, percent, bar, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: Colors.white,
                  strokeWidth: 2,
                  strokeColor: AppleColors.systemBlue,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppleColors.systemBlue.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(List<_MonthlyAverage> data) {
    // 데이터가 있는 월만 필터링
    final dataWithValues = data.where((d) => d.hasData).toList();
    if (dataWithValues.isEmpty) return const SizedBox.shrink();

    final first = dataWithValues.first;
    final last = dataWithValues.last;
    final change = last.average! - first.average!;
    final changePercent = first.average! > 0 ? (change / first.average! * 100) : 0;
    final isUp = change > 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 기간
        Text(
          '${first.year}.${first.month}월 → ${last.year}.${last.month}월',
          style: AppleTypography.caption1.copyWith(
            color: AppleColors.secondaryLabel,
          ),
        ),
        // 변동
        Row(
          children: [
            Icon(
              isUp ? Icons.trending_up : Icons.trending_down,
              size: 16,
              color: isUp ? AppleColors.systemRed : AppleColors.systemBlue,
            ),
            const SizedBox(width: 4),
            Text(
              '${isUp ? '+' : ''}${changePercent.toStringAsFixed(1)}%',
              style: AppleTypography.footnote.copyWith(
                color: isUp ? AppleColors.systemRed : AppleColors.systemBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatShortPrice(int manwon) {
    if (manwon >= 10000) {
      final uk = manwon / 10000;
      return '${uk.toStringAsFixed(1)}억';
    }
    return '$manwon만';
  }
}

class _MonthlyAverage {
  final int year;
  final int month;
  final int? average; // null이면 해당 월 데이터 없음
  final int count;

  _MonthlyAverage({
    required this.year,
    required this.month,
    required this.average,
    required this.count,
  });

  bool get hasData => average != null;
}
