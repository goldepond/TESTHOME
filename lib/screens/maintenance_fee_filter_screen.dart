import 'package:flutter/material.dart';
import 'package:property/models/maintenance_fee.dart';
import 'package:property/constants/app_constants.dart';

class MaintenanceFeeFilterScreen extends StatefulWidget {
  final MaintenanceFeeFilter? initialFilter;
  final Function(MaintenanceFeeFilter) onFilterApplied;

  const MaintenanceFeeFilterScreen({
    Key? key,
    this.initialFilter,
    required this.onFilterApplied,
  }) : super(key: key);

  @override
  State<MaintenanceFeeFilterScreen> createState() => _MaintenanceFeeFilterScreenState();
}

class _MaintenanceFeeFilterScreenState extends State<MaintenanceFeeFilterScreen> {
  double? maxAmount;
  List<String> selectedItems = [];
  MaintenanceFeeLevel? maxLevel;

  final List<String> availableItems = [
    '전기',
    '가스',
    '수도',
    '난방',
    '엘리베이터',
    '경비',
    '청소',
    '주차',
    '수도',
    '인터넷',
    'TV',
    '공용시설',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialFilter != null) {
      maxAmount = widget.initialFilter!.maxAmount;
      selectedItems = widget.initialFilter!.requiredItems ?? [];
      maxLevel = widget.initialFilter!.maxLevel;
    }
  }

  void _applyFilter() {
    final filter = MaintenanceFeeFilter(
      maxAmount: maxAmount,
      requiredItems: selectedItems.isNotEmpty ? selectedItems : null,
      maxLevel: maxLevel,
    );
    widget.onFilterApplied(filter);
    Navigator.of(context).pop();
  }

  void _resetFilter() {
    setState(() {
      maxAmount = null;
      selectedItems.clear();
      maxLevel = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('관리비 필터'),
        backgroundColor: AppColors.kBrown,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _resetFilter,
            child: const Text(
              '초기화',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 관리비 최대 금액
            const Text(
              '관리비 최대 금액',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          maxAmount != null 
                              ? '${maxAmount!.toStringAsFixed(0)}만원 이하'
                              : '제한 없음',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (maxAmount != null)
                        IconButton(
                          onPressed: () {
                            setState(() {
                              maxAmount = null;
                            });
                          },
                          icon: const Icon(Icons.clear),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: maxAmount ?? 200,
                    min: 0,
                    max: 200,
                    divisions: 20,
                    label: '${(maxAmount ?? 200).toStringAsFixed(0)}만원',
                    onChanged: (value) {
                      setState(() {
                        maxAmount = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 관리비 수준
            const Text(
              '관리비 수준',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                children: [
                  _buildLevelOption(MaintenanceFeeLevel.low, '낮음'),
                  _buildLevelOption(MaintenanceFeeLevel.normal, '보통'),
                  _buildLevelOption(MaintenanceFeeLevel.high, '높음'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 포함 항목 필터
            const Text(
              '포함 항목 필터',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '선택한 항목이 모두 포함된 매물만 표시됩니다.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: availableItems.map((item) => 
                  FilterChip(
                    label: Text(item),
                    selected: selectedItems.contains(item),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          selectedItems.add(item);
                        } else {
                          selectedItems.remove(item);
                        }
                      });
                    },
                    selectedColor: AppColors.kBrown.withValues(alpha:0.2),
                    checkmarkColor: AppColors.kBrown,
                  ),
                ).toList(),
              ),
            ),
            const SizedBox(height: 24),

            // 필터 요약
            if (maxAmount != null || selectedItems.isNotEmpty || maxLevel != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha:0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '적용된 필터',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (maxAmount != null)
                      Text('• 관리비 ${maxAmount!.toStringAsFixed(0)}만원 이하'),
                    if (maxLevel != null)
                      Text('• 관리비 수준: ${maxLevel!.displayName} 이하'),
                    if (selectedItems.isNotEmpty)
                      Text('• 포함 항목: ${selectedItems.join(', ')}'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha:0.2),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                  side: BorderSide(color: Colors.grey[300]!),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('취소'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _applyFilter,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.kBrown,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('필터 적용'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelOption(MaintenanceFeeLevel level, String label) {
    final isSelected = maxLevel == level;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          maxLevel = isSelected ? null : level;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? level.color.withValues(alpha:0.1) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? level.color : Colors.grey[300]!,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isSelected ? level.color : Colors.grey[400],
            ),
            const SizedBox(width: 12),
            Icon(
              level.icon,
              color: level.color,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? level.color : Colors.black,
              ),
            ),
            const Spacer(),
            if (isSelected)
              Icon(
                Icons.check,
                color: level.color,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}


