import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextEditingValue, TextInputFormatter;
import '../../../constants/apple_design_system.dart';
import '../../../utils/formatters.dart';

/// 가격 필터 바텀시트
///
/// [currentRange]: 현재 선택된 가격 범위 (만원 단위)
/// [isActive]: 현재 가격 필터 활성 여부
/// [presets]: 빠른 선택 프리셋 목록 (`PropertyConstants.pricePresets` 사용)
/// [onApply]: 적용 시 콜백 - 선택된 범위와 활성 여부를 반환
class BrokerPriceFilterSheet extends StatefulWidget {
  final RangeValues currentRange;
  final bool isActive;
  final List<Map<String, dynamic>> presets;
  final Function(RangeValues range, bool isActive) onApply;

  const BrokerPriceFilterSheet({
    required this.currentRange,
    required this.isActive,
    required this.presets,
    required this.onApply,
    super.key,
  });

  @override
  State<BrokerPriceFilterSheet> createState() => _BrokerPriceFilterSheetState();
}

class _BrokerPriceFilterSheetState extends State<BrokerPriceFilterSheet> {
  late RangeValues _range;
  late bool _isActive;
  int _selectedPresetIndex = 0;

  @override
  void initState() {
    super.initState();
    _range = widget.currentRange;
    _isActive = widget.isActive;

    // 현재 범위와 일치하는 프리셋 찾기
    for (int i = 0; i < widget.presets.length; i++) {
      final preset = widget.presets[i];
      if (_range.start == preset['min'] && _range.end == preset['max']) {
        _selectedPresetIndex = i;
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppleColors.systemBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 핸들
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: AppleColors.opaqueSeparator,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
            // 헤더
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '가격대 설정',
                    style: AppleTypography.headline.copyWith(fontWeight: FontWeight.w600),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _range = const RangeValues(0, 500000);
                        _isActive = false;
                        _selectedPresetIndex = 0;
                      });
                    },
                    child: Text(
                      '초기화',
                      style: AppleTypography.subheadline.copyWith(
                        color: AppleColors.systemBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 0.5, color: AppleColors.separator),

            // 프리셋 버튼들
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '빠른 선택',
                    style: AppleTypography.subheadline.copyWith(
                      color: AppleColors.secondaryLabel,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(widget.presets.length, (index) {
                      final preset = widget.presets[index];
                      final isSelected = _selectedPresetIndex == index;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedPresetIndex = index;
                            _range = RangeValues(
                              (preset['min'] as num).toDouble(),
                              (preset['max'] as num).toDouble(),
                            );
                            _isActive = index != 0;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? AppleColors.systemBlue : AppleColors.tertiarySystemFill,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            preset['label'] as String,
                            style: AppleTypography.subheadline.copyWith(
                              color: isSelected ? Colors.white : AppleColors.label,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),

            // 현재 선택된 범위 표시
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppleColors.tertiarySystemFill,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _formatRangeValue(_range.start),
                      style: AppleTypography.title3.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppleColors.systemBlue,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '~',
                        style: AppleTypography.title3.copyWith(
                          color: AppleColors.secondaryLabel,
                        ),
                      ),
                    ),
                    Text(
                      _formatRangeValue(_range.end),
                      style: AppleTypography.title3.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppleColors.systemBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 적용 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onApply(_range, _isActive);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppleColors.systemBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    '적용하기',
                    style: AppleTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatRangeValue(double value) {
    if (value >= 500000) return '50억+';
    if (value >= 10000) {
      return '${(value / 10000).toStringAsFixed(0)}억';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}천만';
    }
    return PriceFormatter.format(value);
  }
}

/// 천단위 콤마 구분 포매터 (예: 10000 → 10,000)
class ThousandsSeparatorFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(',', '');
    if (text.isEmpty) return newValue;

    final number = int.tryParse(text);
    if (number == null) return oldValue;

    final formatted = _formatWithCommas(text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _formatWithCommas(String text) {
    final buffer = StringBuffer();
    final length = text.length;
    for (int i = 0; i < length; i++) {
      if (i > 0 && (length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(text[i]);
    }
    return buffer.toString();
  }
}
