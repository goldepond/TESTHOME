import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../constants/spacing.dart';
import 'package:property/constants/typography.dart';

/// 모바일용 주소 지도 위젯 (VWorld Static Map API 사용)
class AddressMapWidgetMobile extends StatefulWidget {
  final double? latitude;
  final double? longitude;
  final double height;

  const AddressMapWidgetMobile({
    super.key,
    this.latitude,
    this.longitude,
    this.height = 300,
  });

  @override
  State<AddressMapWidgetMobile> createState() => _AddressMapWidgetMobileState();
}

class _AddressMapWidgetMobileState extends State<AddressMapWidgetMobile> {
  // VWorld API 인증키
  static String get _apiKey => const String.fromEnvironment(
      'VWORLD_MAP_API_KEY',
      defaultValue: 'FA0D6750-3DC2-3389-B8F1-0385C5976B96');

  // 기본 위치 (서울시청)
  static const double _defaultLat = 37.5665;
  static const double _defaultLng = 126.9780;

  // 고정 이미지 크기 (API 요청 최적화)
  static const int _mapWidth = 600;
  static const int _mapHeight = 400;

  // 캐시된 URL
  String? _cachedUrl;
  double? _cachedLat;
  double? _cachedLng;

  /// VWorld Static Map API URL 생성 (캐싱 적용)
  String _getMapUrl(double lat, double lng) {
    // 좌표가 같으면 캐시된 URL 반환
    if (_cachedUrl != null && _cachedLat == lat && _cachedLng == lng) {
      return _cachedUrl!;
    }

    // 새 URL 생성 및 캐싱
    _cachedUrl = 'https://api.vworld.kr/req/image'
        '?service=image'
        '&request=getmap'
        '&key=$_apiKey'
        '&basemap=GRAPHIC'
        '&center=$lng,$lat'
        '&zoom=16'
        '&size=$_mapWidth,$_mapHeight'
        '&marker=point:$lng $lat|image:https://map.vworld.kr/images/marker/marker_red.png';
    _cachedLat = lat;
    _cachedLng = lng;

    return _cachedUrl!;
  }

  @override
  Widget build(BuildContext context) {
    final lat = widget.latitude ?? _defaultLat;
    final lng = widget.longitude ?? _defaultLng;
    final mapUrl = _getMapUrl(lat, lng);

    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              mapUrl,
              fit: BoxFit.cover,
              cacheWidth: _mapWidth,
              cacheHeight: _mapHeight,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  return child;
                }
                // 로딩 진행률 표시
                final progress = loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null;
                return Container(
                  color: AirbnbColors.background,
                  child: Center(
                    child: CircularProgressIndicator(value: progress),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: AirbnbColors.background,
                  child:   Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.map_outlined,
                          color: AirbnbColors.textLight,
                          size: 32,
                        ),
                        SizedBox(height: 8),
                        Text(
                          '지도를 불러올 수 없습니다',
                          style: AppTypography.withColor(AppTypography.bodySmall, AirbnbColors.textLight),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            // 지도 위 위치 표시 오버레이
            Positioned(
              bottom: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AirbnbColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
