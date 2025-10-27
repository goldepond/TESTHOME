import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:property/models/maintenance_fee.dart';
import 'package:property/constants/app_constants.dart';

class MaintenanceFeeCard extends StatelessWidget {
  final MaintenanceFee maintenanceFee;
  final bool isCompact; // 컴팩트 모드 (카드용)
  final VoidCallback? onTap; // 클릭 시 상세 화면으로 이동

  const MaintenanceFeeCard({
    Key? key,
    required this.maintenanceFee,
    this.isCompact = false,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return _buildCompactCard(context);
    } else {
      return _buildDetailedCard(context);
    }
  }

  // 컴팩트 카드 (매물 목록용)
  Widget _buildCompactCard(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: maintenanceFee.hasWarning 
                ? Colors.red.withValues(alpha:0.3) 
                : Colors.grey.withValues(alpha:0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha:0.1),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더 (배지 + 금액)
            Row(
              children: [
                // 관리비 수준 배지
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: maintenanceFee.level.color.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: maintenanceFee.level.color),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        maintenanceFee.level.icon,
                        size: 12,
                        color: maintenanceFee.level.color,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '관리비 ${maintenanceFee.level.displayName}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: maintenanceFee.level.color,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // 관리비 금액
                Text(
                  '${maintenanceFee.amount.toStringAsFixed(0)}원',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // 포함/제외 항목 칩들
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                // 포함 항목
                ...maintenanceFee.includedItems.take(3).map((item) => 
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withValues(alpha:0.3)),
                    ),
                    child: Text(
                      '$item 포함',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                // 제외 항목
                ...maintenanceFee.excludedItems.take(2).map((item) => 
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withValues(alpha:0.3)),
                    ),
                    child: Text(
                      '$item 제외',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            // 경고 메시지
            if (maintenanceFee.hasWarning) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red.withValues(alpha:0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, size: 14, color: Colors.red),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        maintenanceFee.warningMessage,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 상세 카드 (매물 상세 화면용)
  Widget _buildDetailedCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              children: [
                const Icon(Icons.account_balance_wallet, color: AppColors.kBrown),
                const SizedBox(width: 8),
                const Text(
                  '관리비 투명성',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // 관리비 수준 배지
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: maintenanceFee.level.color.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: maintenanceFee.level.color),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        maintenanceFee.level.icon,
                        size: 16,
                        color: maintenanceFee.level.color,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '관리비 ${maintenanceFee.level.displayName}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: maintenanceFee.level.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 관리비 정보
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${maintenanceFee.amount.toStringAsFixed(0)}원',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '면적당 ${maintenanceFee.amountPerArea.toStringAsFixed(0)}원/㎡',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                // 지역 평균 대비
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withValues(alpha:0.3)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        '지역 평균 대비',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        maintenanceFee.regionComparisonText,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 포함/제외 항목
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '포함 항목',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: maintenanceFee.includedItems.map((item) => 
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha:0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.withValues(alpha:0.3)),
                            ),
                            child: Text(
                              item,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.green,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '제외 항목',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: maintenanceFee.excludedItems.map((item) => 
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha:0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.withValues(alpha:0.3)),
                            ),
                            child: Text(
                              item,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            // 경고 메시지
            if (maintenanceFee.hasWarning) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha:0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        maintenanceFee.warningMessage,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // 월별 변동 내역 그래프
            if (maintenanceFee.monthlyHistory.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                '최근 1년간 관리비 변동 내역',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(show: true),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              '${value.toInt()}만',
                              style: const TextStyle(fontSize: 10),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          getTitlesWidget: (value, meta) {
                            if (value.toInt() >= 0 && 
                                value.toInt() < maintenanceFee.monthlyHistory.length) {
                              final date = maintenanceFee.monthlyHistory[value.toInt()].date;
                              return Text(
                                '${date.month}월',
                                style: const TextStyle(fontSize: 10),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: true),
                    lineBarsData: [
                      LineChartBarData(
                        spots: maintenanceFee.monthlyHistory.asMap().entries.map((entry) {
                          return FlSpot(entry.key.toDouble(), entry.value.amount);
                        }).toList(),
                        isCurved: true,
                        color: AppColors.kBrown,
                        barWidth: 3,
                        dotData: FlDotData(show: true),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


