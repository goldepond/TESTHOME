// 웹 전용 import (조건부)
import 'broker_map_view_stub.dart'
    if (dart.library.html) 'broker_map_view_web.dart' as broker_map;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/models/mls_property.dart';
import 'package:property/constants/typography.dart';

/// 중개사 매물 탐색 지도 위젯
///
/// VWorld OpenLayers API를 사용하여 매물 위치를 마커로 표시합니다.
/// 마커 클릭 시 매물 정보 팝업을 표시합니다.
class BrokerMapView extends StatefulWidget {
  final List<MLSProperty> properties;
  final ValueChanged<MLSProperty>? onPropertyTapped;

  const BrokerMapView({
    required this.properties,
    this.onPropertyTapped,
    super.key,
  });

  @override
  State<BrokerMapView> createState() => _BrokerMapViewState();
}

class _BrokerMapViewState extends State<BrokerMapView> {
  bool _isInitialized = false;
  bool _isLoadingLocation = true;
  static int _mapCounter = 0;
  late final String _mapId;

  double? _latitude;
  double? _longitude;

  static String get _apiKey =>
      const String.fromEnvironment('VWORLD_MAP_API_KEY');

  static const double _defaultLat = 37.5665;
  static const double _defaultLng = 126.9780;

  @override
  void initState() {
    super.initState();
    _mapId = 'broker_map_${_mapCounter++}';
    if (kIsWeb) {
      _getCurrentLocation();
    }
  }

  @override
  void didUpdateWidget(BrokerMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 매물 목록이 변경되면 마커 업데이트
    if (oldWidget.properties.length != widget.properties.length && _isInitialized) {
      _updateMarkers();
    }
  }

  void _updateMarkers() {
    if (!kIsWeb || !_isInitialized) return;
    final iframe = broker_map.findBrokerMapIframe(_mapId);
    if (iframe != null) {
      broker_map.postMessageToBrokerMap(iframe, {
        'type': 'UPDATE_MARKERS',
        'markers': widget.properties
            .where((p) => p.latitude != null && p.longitude != null)
            .map((p) => {
                  'id': p.id,
                  'lat': p.latitude,
                  'lng': p.longitude,
                  'title': p.address,
                  'price': p.desiredPrice,
                  'type': p.propertyType ?? '',
                })
            .toList(),
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    if (!kIsWeb) {
      _setDefaultLocation();
      return;
    }

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _setDefaultLocation();
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _setDefaultLocation();
        return;
      }

      final bool serviceEnabled =
          await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _setDefaultLocation();
        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
          _isLoadingLocation = false;
        });
        _initializeMap();
      }
    } catch (e) {
      if (mounted) {
        _setDefaultLocation();
      }
    }
  }

  void _setDefaultLocation() {
    setState(() {
      _latitude = _defaultLat;
      _longitude = _defaultLng;
      _isLoadingLocation = false;
    });
    _initializeMap();
  }

  void _initializeMap() {
    if (!kIsWeb) {
      setState(() {
        _isInitialized = true;
        _isLoadingLocation = false;
      });
      return;
    }

    final lat = _latitude ?? _defaultLat;
    final lng = _longitude ?? _defaultLng;

    final htmlContent = _buildHtmlContent(lat, lng);
    final iframe = broker_map.createBrokerMapIframe();
    broker_map.setupBrokerMapIframe(iframe, htmlContent);
    broker_map.registerBrokerMapView(_mapId, iframe);

    setState(() {
      _isInitialized = true;
    });
  }

  String _buildMarkersJson() {
    final markers = widget.properties
        .where((p) => p.latitude != null && p.longitude != null)
        .map((p) {
      final title = p.address
          .replaceAll("'", "\\'")
          .replaceAll('"', '\\"');
      final price = p.desiredPrice;
      final priceText = price >= 10000
          ? '${(price / 10000).toStringAsFixed(0)}억'
          : price >= 1000
              ? '${(price / 1000).toStringAsFixed(1)}천만'
              : '${price.toStringAsFixed(0)}만';
      final type = (p.propertyType ?? '').replaceAll("'", "\\'");
      return '{"id":"${p.id}","lat":${p.latitude},"lng":${p.longitude},"title":"$title","price":"$priceText","type":"$type"}';
    }).toList();
    return '[${markers.join(",")}]';
  }

  String _buildHtmlContent(double lat, double lng) {
    final latStr = lat.toString();
    final lngStr = lng.toString();
    final markersJson = _buildMarkersJson();

    return '''
<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body { width: 100%; height: 100%; overflow: hidden; }
    #vmap { width: 100%; height: 100%; }
    .loading {
      position: absolute; top: 50%; left: 50%;
      transform: translate(-50%, -50%); color: #666;
      font-family: -apple-system, sans-serif; z-index: 1000;
      background: rgba(255,255,255,0.9); padding: 10px 20px;
      border-radius: 8px;
    }
    .marker-label {
      background: #E07A5F; color: #fff; padding: 3px 8px;
      border-radius: 12px; font-size: 11px; font-weight: 600;
      white-space: nowrap; box-shadow: 0 2px 6px rgba(0,0,0,0.2);
      font-family: -apple-system, sans-serif;
    }
    .property-popup {
      background: #fff; border-radius: 12px; padding: 12px 16px;
      box-shadow: 0 4px 12px rgba(0,0,0,0.15); min-width: 180px;
      font-family: -apple-system, sans-serif; cursor: pointer;
    }
    .popup-title { font-size: 13px; font-weight: 600; color: #1a1a1a; margin-bottom: 4px; }
    .popup-price { font-size: 15px; font-weight: 700; color: #E07A5F; }
    .popup-type { font-size: 11px; color: #8e8e93; margin-top: 2px; }
  </style>
  <script type="text/javascript" src="https://map.vworld.kr/js/vworldMapInit.js.do?version=2.0&apiKey=$_apiKey"></script>
</head>
<body>
  <div id="vmap"></div>
  <div class="loading" id="loading">지도를 불러오는 중...</div>
  <script type="text/javascript">
    var targetLat = $latStr;
    var targetLng = $lngStr;
    var propertyMarkers = $markersJson;
    var vmap = null;
    var markerLayer = null;
    var retryCount = 0;
    var maxRetries = 50;
    var mapInitialized = false;

    function initializeMap() {
      if (mapInitialized && vmap !== null) return;
      try {
        if (typeof vw === 'undefined' || typeof vw.ol3 === 'undefined') {
          retryCount++;
          if (retryCount < maxRetries) { setTimeout(initializeMap, 100); return; }
          document.getElementById('loading').textContent = '지도 로드 시간 초과';
          return;
        }

        // 매물이 있으면 매물 중심, 없으면 GPS 위치
        var centerLat = targetLat;
        var centerLng = targetLng;
        var initZoom = 14;

        if (propertyMarkers.length > 0) {
          var sumLat = 0, sumLng = 0;
          propertyMarkers.forEach(function(m) { sumLat += m.lat; sumLng += m.lng; });
          centerLat = sumLat / propertyMarkers.length;
          centerLng = sumLng / propertyMarkers.length;
          initZoom = propertyMarkers.length === 1 ? 16 : 13;
        }

        var initPosition = null;
        try {
          initPosition = new vw.ol3.CameraPosition({ longitude: centerLng, latitude: centerLat, zoom: initZoom });
        } catch(e) {
          initPosition = { longitude: centerLng, latitude: centerLat, zoom: initZoom };
        }

        vw.ol3.MapOptions = {
          basemapType: vw.ol3.BasemapType.GRAPHIC,
          controlDensity: vw.ol3.DensityType.EMPTY,
          interactionDensity: vw.ol3.DensityType.BASIC,
          controlsAutoArrange: true,
          initPosition: initPosition
        };

        vmap = new vw.ol3.Map("vmap", vw.ol3.MapOptions);

        if (vmap) {
          setTimeout(function() {
            addPropertyMarkers();
            mapInitialized = true;
            var el = document.getElementById('loading');
            if (el) el.style.display = 'none';
          }, 2000);
        }
      } catch(e) {
        console.error('[지도 초기화 오류]', e);
        var el = document.getElementById('loading');
        if (el) { el.textContent = '지도 로드 실패'; el.style.color = '#f00'; }
      }
    }

    function addPropertyMarkers() {
      if (!vmap) return;
      try {
        markerLayer = new vw.ol3.layer.Marker(vmap);
        propertyMarkers.forEach(function(m) {
          markerLayer.addMarker({
            x: m.lng, y: m.lat, epsg: 'EPSG:4326',
            title: m.title,
            contents: '<div class="property-popup" onclick="selectProperty(\\'' + m.id + '\\')">' +
              '<div class="popup-title">' + m.title + '</div>' +
              '<div class="popup-price">' + m.price + '</div>' +
              (m.type ? '<div class="popup-type">' + m.type + '</div>' : '') +
              '</div>',
            iconUrl: 'https://map.vworld.kr/images/marker/marker_red.png'
          });
        });
      } catch(e) {
        console.error('[마커 추가 오류]', e);
      }
    }

    function selectProperty(id) {
      if (window.parent && window.parent !== window) {
        window.parent.postMessage({ type: 'PROPERTY_SELECTED', propertyId: id }, '*');
      }
    }

    // 매물 마커 업데이트 메시지 리스너
    window.addEventListener('message', function(event) {
      if (event.data && event.data.type === 'UPDATE_MARKERS') {
        propertyMarkers = event.data.markers || [];
        if (markerLayer && vmap) {
          try { markerLayer.clear(); } catch(e) {}
        }
        addPropertyMarkers();
      }
    });

    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', function() { setTimeout(initializeMap, 500); });
    } else {
      setTimeout(initializeMap, 500);
    }
  </script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: AirbnbColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text(
            '지도는 웹에서만 지원됩니다.',
            style: TextStyle(color: AirbnbColors.textSecondary),
          ),
        ),
      );
    }

    if (!_isInitialized || _isLoadingLocation) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: AirbnbColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                _isLoadingLocation ? '위치 정보를 가져오는 중...' : '지도를 불러오는 중...',
                style:  AppTypography.withColor(AppTypography.bodySmall, AirbnbColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: HtmlElementView(
        viewType: _mapId,
      ),
    );
  }
}
