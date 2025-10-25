import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:property/constants/app_constants.dart';

/// VWorld 부동산중개업WFS조회 API 서비스
class BrokerService {
  /// 주변 공인중개사 검색
  /// 
  /// [latitude] 위도
  /// [longitude] 경도
  /// [radiusMeters] 검색 반경 (미터), 기본값 1000m (1km)
  static Future<List<Broker>> searchNearbyBrokers({
    required double latitude,
    required double longitude,
    int radiusMeters = 1000,
    bool shouldAutoRetry = true,
    bool isRecursive = false,
  }) async {
    try {
      List<Broker> brokers = [];
      print('\n🏘️ [BrokerService] 공인중개사 검색 시작');
      print('   📍 중심 좌표: ($latitude, $longitude)');
      print('   📏 검색 반경: ${radiusMeters}m');
      
      // BBOX 생성 (EPSG:4326 기준)
      final bbox = _generate_EPSG4326_BBOX(latitude, longitude, radiusMeters);
      print('   📐 BBOX: $bbox');
      
      final uri = Uri.parse(VWorldApiConstants.brokerQueryBaseUrl).replace(queryParameters: {
        'key': VWorldApiConstants.apiKey,
        'typename': VWorldApiConstants.brokerQueryTypeName,
        'bbox': bbox,
        'resultType': 'results',
        'srsName': VWorldApiConstants.srsName,
        'output': 'application/json',
        'maxFeatures': VWorldApiConstants.brokerMaxFeatures.toString(),
        'domain' : VWorldApiConstants.domainCORSParam,
      });
      
      print('   🌐 요청 URL: ${uri.toString()}');
      
      final response = await http.get(uri).timeout(
        const Duration(seconds: ApiConstants.requestTimeoutSeconds),
        onTimeout: () {
          print('⏱️ [BrokerService] API 타임아웃');
          throw Exception('API 타임아웃');
        },
      );
      
      print('   📥 응답 상태코드: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final jsonText = utf8.decode(response.bodyBytes);
        // XML 파싱
        brokers = _parseJSON(jsonText, latitude, longitude);
        print('   ✅ 공인중개사 검색 완료: ${brokers.length}개');
      } else {
        print('   ❌ HTTP 오류: ${response.statusCode}');
        return [];
      }

      // 10KM 이하일 때, 결과값이 0이면 10KM 까지 넒혀가며 3회 재시도. 파라미터가 더러워서 정리가 필요할수도
      if (!isRecursive && shouldAutoRetry && brokers.isEmpty && radiusMeters < 10000) {
        const int step = 3;
        final int remaining = 10000 - radiusMeters;
        final int increment = remaining ~/ step;

        for (int attempt = 0; attempt < step; attempt++) {
          final int searchRadius = attempt < step
              ? radiusMeters + (attempt * increment)
              : 10000;
          brokers = await searchNearbyBrokers(latitude: latitude, longitude: longitude, radiusMeters: searchRadius, isRecursive: true);
          if (brokers.isNotEmpty) break;
        }
      }
      return brokers;
    } catch (e) {
      print('❌ [BrokerService] 공인중개사 검색 오류: $e');
      return [];
    }
  }
  
  /// BBOX 생성 (검색 범위)
  static String _generate_EPSG4326_BBOX(double lat, double lon, int radiusMeters) {
    final latDelta = radiusMeters / 111000.0;
    final lonDelta = radiusMeters / (111000.0 * cos(lat * pi / 180));
    
    final ymin = lat - latDelta;
    final xmin = lon - lonDelta;
    final ymax = lat + latDelta;
    final xmax = lon + lonDelta;
    
    return '$ymin,$xmin,$ymax,$xmax,EPSG:4326';
  }

  static List<Broker> _parseJSON(String jsonText, double baseLat, double baseLon) {
    final brokers = <Broker>[];

    try {
      final data = json.decode(jsonText);
      final List<dynamic> features = data['features'] ?? [];

      print('   📊 공인중개사 피처: ${features.length}개');

      int idx = 0;
      for (final dynamic featureRaw in features) {
        idx++;
        final feature = featureRaw as Map<String, dynamic>;
        final properties = feature['properties'] as Map<String, dynamic>? ?? {};

        // 각 필드 추출
        final name = properties['bsnm_cmpnm']?.toString() ?? '';
        final roadAddr = properties['rdnmadr']?.toString() ?? '';
        final jibunAddr = properties['mnnmadr']?.toString() ?? '';
        final registNo = properties['brkpg_regist_no']?.toString() ?? '';
        final etcAddr = properties['etc_adres']?.toString() ?? '';
        final employeeCount = properties['emplym_co']?.toString() ?? '';
        final registDate = properties['frst_regist_dt']?.toString().replaceAll('Z', '') ?? '';

        // 디버그: 첫 3개만 로그
        if (idx <= 3) {
          print('\n   🔍 [Broker #$idx]');
          print('      이름: "$name"');
          print('      도로명주소: "$roadAddr"');
          print('      지번주소: "$jibunAddr"');
        }

        // 좌표 추출 (geometry.coordinates에서 [lon, lat])
        double? brokerLat;
        double? brokerLon;
        double? distance;

        final geometry = feature['geometry'] as Map<String, dynamic>? ?? {};
        final coordinates = geometry['coordinates'] as List?;
        if (coordinates != null && coordinates.length >= 2) {
          try {
            brokerLon = double.parse(coordinates[0].toString());
            brokerLat = double.parse(coordinates[1].toString());
            distance = _calculateHaversineDistance(baseLat, baseLon, brokerLat, brokerLon);

            if (idx <= 3) {
              print('      좌표: ($brokerLat, $brokerLon)');
              print('      거리: ${distance?.toStringAsFixed(0)}m');
            }
          } catch (e) {
            print('   ⚠️ 좌표 파싱 실패: $name - $coordinates');
          }
        }

        brokers.add(Broker(
          name: name,
          roadAddress: roadAddr,
          jibunAddress: jibunAddr,
          registrationNumber: registNo,
          etcAddress: etcAddr,
          employeeCount: employeeCount,
          registrationDate: registDate,
          latitude: brokerLat,
          longitude: brokerLon,
          distance: distance,
        ));
      }

      // 거리순 정렬
      brokers.sort((a, b) {
        if (a.distance == null) return 1;
        if (b.distance == null) return -1;
        return a.distance!.compareTo(b.distance!);
      });

      print('   ✅ 거리순 정렬 완료');
      if (brokers.isNotEmpty) {
        print('   📊 가장 가까운 3곳:');
        final maxCount = brokers.length < 3 ? brokers.length : 3;
        for (int i = 0; i < maxCount; i++) {
          final b = brokers[i];
          final distText = b.distance != null ? '${b.distance!.toStringAsFixed(0)}m' : '-';
          print('      ${i + 1}. ${b.name} ($distText)');
        }
      }

    } catch (e) {
      print('   ❌ JSON 파싱 오류: $e');
    }

    return brokers;
  }
  
  /// XML 태그에서 값 추출
  static String _extractTag(String xml, String tagName) {
    // 네임스페이스를 무시하고 태그 내용 추출
    // 예: <bsnm_cmpnm> 또는 <sop:bsnm_cmpnm> 모두 매칭
    final pattern = RegExp('<[^:]*:?$tagName[^>]*>(.*?)</[^:]*:?$tagName>');
    final match = pattern.firstMatch(xml);
    return match?.group(1)?.trim() ?? '';
  }
  
  /// Haversine 공식으로 거리 계산 (미터)
  static double _calculateHaversineDistance(double lat1, double lon1, double lat2, double lon2) {
    // EPSG:5186 (TM 좌표)인 경우 유클리드 거리
    if (lon1 > 1000 && lon2 > 1000) {
      final dx = lon2 - lon1;
      final dy = lat2 - lat1;
      return sqrt(dx * dx + dy * dy);
    }
    
    // WGS84 좌표인 경우 Haversine 공식
    const R = 6371000.0; // 지구 반지름 (미터)
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
              cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
              sin(dLon / 2) * sin(dLon / 2);
    
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }
}

/// 공인중개사 정보 모델
class Broker {
  final String name;                // 상호명
  final String roadAddress;         // 도로명주소
  final String jibunAddress;        // 지번주소
  final String registrationNumber;  // 등록번호
  final String etcAddress;          // 기타주소 (동/호수)
  final String employeeCount;       // 고용인원
  final String registrationDate;    // 등록일
  final double? latitude;           // 위도
  final double? longitude;          // 경도
  final double? distance;           // 거리 (미터)
  
  Broker({
    required this.name,
    required this.roadAddress,
    required this.jibunAddress,
    required this.registrationNumber,
    required this.etcAddress,
    required this.employeeCount,
    required this.registrationDate,
    this.latitude,
    this.longitude,
    this.distance,
  });
  
  /// 거리를 읽기 쉬운 형태로 변환
  String get distanceText {
    if (distance == null) return '-';
    if (distance! >= 1000) {
      return '${(distance! / 1000).toStringAsFixed(1)}km';
    }
    return '${distance!.toStringAsFixed(0)}m';
  }
  
  /// 전체 주소 (도로명 + 기타)
  String get fullAddress {
    if (etcAddress.isEmpty || etcAddress == '-') {
      return roadAddress;
    }
    return '$roadAddress $etcAddress';
  }
}

