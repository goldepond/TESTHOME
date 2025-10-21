import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_naver_map/flutter_naver_map.dart' as mNmap;
import 'naver_map_web_stub.dart' if (dart.library.html) 'package:flutter_naver_map_web/flutter_naver_map_web.dart' as wNmap;

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage>  {
  static const String _clientId = 'eb18xjawdk';
  static const double _initialLat = 37.5666;
  static const double _initialLng = 126.9784;

  static const int numPins = 2000;
  static const double radiusKm = 10.0; // Smaller radius = denser pins

  late List<mNmap.NMarker> _mMarkers;
  late List<wNmap.Place> _wMarkers;
  mNmap.NaverMapController? _mNmapController;
  bool _initialized = false;

  Future<void> _initializeMobileNaverMapLib() async {
    await mNmap.FlutterNaverMap().init(
      clientId: _clientId,
      onAuthFailed: (ex) {
        switch (ex) {
          case mNmap.NQuotaExceededException(:final message):
            print("사용량 초과 (message: $message)");
            break;
          case mNmap.NUnauthorizedClientException() ||
          mNmap.NClientUnspecifiedException() ||
          mNmap.NAnotherAuthFailedException():
            print("인증 실패: $ex");
            break;
        }
      },
    );
    if (mounted) {
      setState(() {
        _initialized = true;
      });
    }
  }

  void _generateMarkers() {
    final rng = math.Random();
    const centerLat = _initialLat;
    const centerLng = _initialLng;
    final deltaLat = radiusKm / 111.0;
    final deltaLng = radiusKm / (111.0 * math.cos(centerLat * math.pi / 180));

    _mMarkers = [];
    _wMarkers = [];

    for (int i = 0; i < numPins; i++) {
      final lat = centerLat + (rng.nextDouble() - 0.5) * 2 * deltaLat;
      final lng = centerLng + (rng.nextDouble() - 0.5) * 2 * deltaLng;

      _mMarkers.add(mNmap.NMarker(
        id: i.toString(),
        position: mNmap.NLatLng(lat, lng),
        caption: mNmap.NOverlayCaption(text: 'Pin $i'),
      ));

      _wMarkers.add(wNmap.Place(
        id: i.toString(),
        name: 'Pin $i',
        latitude: lat,
        longitude: lng,
      ));
    }
  }

  void _onMapReady(mNmap.NaverMapController controller) {
    _mNmapController = controller;
    for (final marker in _mMarkers) {
      controller.addOverlay(marker);
    }
  }

  @override
  void initState() {
    super.initState();
    _generateMarkers();
    // defaultTargetPlatform 은 web 플랫폼에서도 브라우저 UA 따라 안드로이드/iOS 로 설정될수 있음.
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _initializeMobileNaverMapLib());
    }
  }

  @override
  Widget build(BuildContext context) {
    // Wait till Mobile library initializes, by setState in _initializeMobileNaverMapLib
    if (!kIsWeb && !_initialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (kIsWeb) {
      return Scaffold(
        body: Stack(
          children: [
            // 지도 (전체 화면)
            SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: wNmap.NaverMapWeb(
                clientId: _clientId,
                initialLatitude: _initialLat,
                initialLongitude: _initialLng,
                initialZoom: 12,
                places: _wMarkers,
              ),
            ),
            // 상태 표시
            Positioned(
              top: 20,
              left: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '📍 마커 성능 테스트',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text('마커 개수: ${_wMarkers.length}개'),
                    Text('상태: 로딩 완료'),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      return Scaffold(
        body: mNmap.NaverMap(
          onMapReady: _onMapReady,
          options: const mNmap.NaverMapViewOptions(
            initialCameraPosition: mNmap.NCameraPosition(
              target: mNmap.NLatLng(_initialLat, _initialLng),
              zoom: 14,
            ),
          ),
        ),
      );
    } else { // TODO: Add webview for map in desktop environment
      return Scaffold(
        body: const Center(
          child: Icon(Icons.error, size: 100, color: Colors.red),
        ),
      );
    }
  }

  @override
  void dispose() {
    _mNmapController?.dispose();
    _mNmapController = null;
    super.dispose();
  }
}