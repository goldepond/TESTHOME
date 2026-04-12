import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_constants.dart';
import '../constants/typography.dart';
import '../constants/spacing.dart';

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
              hintStyle: AppTypography.h2.copyWith(
                color: AirbnbColors.textLight,
              ),
              filled: true,
              fillColor: AirbnbColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: AppSpacing.md,
              ),
              suffixText: '억',
              suffixStyle: AppTypography.body.copyWith(
                color: AirbnbColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: AppTypography.h2.copyWith(
              color: AirbnbColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            onChanged: (_) => onChanged(),
          ),
        ),
        const SizedBox(width: 12.0),
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
              hintStyle: AppTypography.h2.copyWith(
                color: AirbnbColors.textLight,
              ),
              filled: true,
              fillColor: AirbnbColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: AppSpacing.md,
              ),
              suffixText: '만원',
              suffixStyle: AppTypography.body.copyWith(
                color: AirbnbColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: AppTypography.h2.copyWith(
              color: AirbnbColors.textPrimary,
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
