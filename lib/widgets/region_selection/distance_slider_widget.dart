import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/constants/typography.dart';
import 'package:property/constants/spacing.dart';

/// 거리 슬라이더 위젯
/// 
/// 반경을 선택할 수 있는 슬라이더입니다.
/// 300m, 500m, 1km, 1.5km 중 선택 가능합니다.
class DistanceSliderWidget extends StatefulWidget {
  /// 현재 선택된 거리 (미터 단위)
  final double distanceMeters;
  
  /// 거리 변경 콜백
  final ValueChanged<double> onDistanceChanged;

  const DistanceSliderWidget({
    required this.distanceMeters, required this.onDistanceChanged, super.key,
  });

  @override
  State<DistanceSliderWidget> createState() => _DistanceSliderWidgetState();
}

class _DistanceSliderWidgetState extends State<DistanceSliderWidget> {
  @override
  void initState() {
    super.initState();
  }
  
  @override
  void didUpdateWidget(DistanceSliderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  /// 거리를 표시 형식으로 변환
  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toInt()}m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)}km';
    }
  }
  
  /// 슬라이더 값을 가장 가까운 선택 가능한 값으로 스냅
  /// 300m, 500m, 1000m, 1500m 중 하나로 스냅
  double _snapToValue(double value) {
    final allowedValues = [300.0, 500.0, 1000.0, 1500.0];
    double closest = allowedValues[0];
    double minDiff = (value - allowedValues[0]).abs();
    
    for (final allowedValue in allowedValues) {
      final diff = (value - allowedValue).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closest = allowedValue;
      }
    }
    
    return closest;
  }
  
  /// 슬라이더 값 변경 처리
  void _onSliderChanged(double value) {
    final snappedValue = _snapToValue(value);
    
    // 즉시 UI 업데이트
    setState(() {
      // 슬라이더 값이 변경되었음을 표시하기 위해 상태 업데이트
    });
    
    // 부모 위젯에 변경 사항 전달
    widget.onDistanceChanged(snappedValue);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AirbnbColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AirbnbColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 라벨과 현재 값
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '거리',
                style: AppTypography.caption.copyWith(
                  color: AirbnbColors.textSecondary,
                ),
              ),
              Text(
                _formatDistance(widget.distanceMeters),
                style: AppTypography.body.copyWith(
                  color: AirbnbColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          
          // 슬라이더
          Slider(
            value: widget.distanceMeters,
            min: 300,
            max: 1500,
            divisions: 3, // 300m, 500m, 1km, 1.5km (4개 선택지)
            activeColor: AirbnbColors.primary,
            inactiveColor: AirbnbColors.border,
            onChanged: _onSliderChanged,
          ),
          
          // 거리 레이블 (4개)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '300m',
                style: AppTypography.caption.copyWith(color: widget.distanceMeters == 300 ? AirbnbColors.primary : AirbnbColors.textSecondary,
                  fontWeight: widget.distanceMeters == 300 ? FontWeight.w600 : FontWeight.normal),
              ),
              Text(
                '500m',
                style: AppTypography.caption.copyWith(color: widget.distanceMeters == 500 ? AirbnbColors.primary : AirbnbColors.textSecondary,
                  fontWeight: widget.distanceMeters == 500 ? FontWeight.w600 : FontWeight.normal),
              ),
              Text(
                '1km',
                style: AppTypography.caption.copyWith(color: widget.distanceMeters == 1000 ? AirbnbColors.primary : AirbnbColors.textSecondary,
                  fontWeight: widget.distanceMeters == 1000 ? FontWeight.w600 : FontWeight.normal),
              ),
              Text(
                '1.5km',
                style: AppTypography.caption.copyWith(color: widget.distanceMeters == 1500 ? AirbnbColors.primary : AirbnbColors.textSecondary,
                  fontWeight: widget.distanceMeters == 1500 ? FontWeight.w600 : FontWeight.normal),
              ),
            ],
          ),
          
          const SizedBox(height: AppSpacing.xs),
          
          // TIP 메시지
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: AirbnbColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 14,
                  color: AirbnbColors.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    '지도에서 선택한 위치 기준 반경입니다',
                    style: AppTypography.caption.copyWith(color: AirbnbColors.primary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

