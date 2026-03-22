import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/apple_design_system.dart';

/// 억/만원 분리 입력 위젯
///
/// 가격 또는 보증금 입력 시 억 단위와 만원 단위를 나란히 입력받습니다.
/// [ukController]에 억, [manController]에 만원 단위 값이 입력되며,
/// 둘 중 하나라도 변경되면 [onChanged]가 호출됩니다.
class PriceInputWidget extends StatelessWidget {
  const PriceInputWidget({
    required this.ukController,
    required this.manController,
    required this.onChanged,
    super.key,
    this.focusNode,
    this.onSubmitted,
  });

  final TextEditingController ukController;
  final TextEditingController manController;
  final VoidCallback onChanged;
  final FocusNode? focusNode;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // 억 단위 입력
        Expanded(
          flex: 2,
          child: TextFormField(
            controller: ukController,
            focusNode: focusNode,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3), // 최대 999억
            ],
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: AppleTypography.title2.copyWith(
                color: AppleColors.tertiaryLabel,
              ),
              filled: true,
              fillColor: AppleColors.secondarySystemGroupedBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppleRadius.md),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppleSpacing.sm,
                vertical: AppleSpacing.md,
              ),
              suffixText: '억',
              suffixStyle: AppleTypography.body.copyWith(
                color: AppleColors.secondaryLabel,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: AppleTypography.title2.copyWith(
              color: AppleColors.label,
              fontWeight: FontWeight.w600,
            ),
            onChanged: (_) => onChanged(),
          ),
        ),
        const SizedBox(width: AppleSpacing.sm),
        // 만원 단위 입력
        Expanded(
          flex: 3,
          child: TextFormField(
            controller: manController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4), // 최대 9999만원
            ],
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: AppleTypography.title2.copyWith(
                color: AppleColors.tertiaryLabel,
              ),
              filled: true,
              fillColor: AppleColors.secondarySystemGroupedBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppleRadius.md),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppleSpacing.sm,
                vertical: AppleSpacing.md,
              ),
              suffixText: '만원',
              suffixStyle: AppleTypography.body.copyWith(
                color: AppleColors.secondaryLabel,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: AppleTypography.title2.copyWith(
              color: AppleColors.label,
              fontWeight: FontWeight.w600,
            ),
            onChanged: (_) => onChanged(),
            onFieldSubmitted: (_) => onSubmitted?.call(),
          ),
        ),
      ],
    );
  }
}
