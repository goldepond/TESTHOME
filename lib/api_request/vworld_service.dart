import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:property/constants/app_constants.dart';

/// VWorld API 서비스
/// Geocoder API: 주소 → 좌표 변환
class VWorldService {
  /// 주소를 좌표로 변환 (Geocoder API)
  /// 
  /// [address] 도로명주소 또는 지번주소
  /// 
  /// 반환: {
  ///   'x': '경도',
  ///   'y': '위도',
  ///   'level': '정확도 레벨'
  /// }
  static Future<Map<String, dynamic>?> getCoordinatesFromAddress(String address) async {
    try {

      final uri = Uri.parse(VWorldApiConstants.geocoderBaseUrl).replace(queryParameters: {
        'service': 'address',
        'request': 'getCoord',
        'version': '2.0',
        'crs': VWorldApiConstants.srsName,
        'address': address,
        'refine': 'true',
        'simple': 'false',
        'format': 'json',
        'type': 'ROAD',
        'key': VWorldApiConstants.geocoderApiKey,
      });


      final response = await http.get(uri).timeout(
        const Duration(seconds: ApiConstants.requestTimeoutSeconds),
        onTimeout: () {
          throw Exception('Geocoder API 타임아웃');
        },
      );
      

      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        
        final data = json.decode(responseBody);
        
        if (data['response'] != null && 
            data['response']['status'] == 'OK' &&
            data['response']['result'] != null) {
          
          final result = data['response']['result'];
          
          // point가 있는 경우
          if (result['point'] != null) {
            final point = result['point'];
            
            return {
              'x': point['x'], // 경도 (longitude)
              'y': point['y'], // 위도 (latitude)
              'level': result['level'] ?? '0',
              'address': address,
            };
          }
          
          return null;
        } else {
          print('❌ [VWorldService] 응답 구조 오류: $data');
          return null;
        }
      } else {
        print('❌ [VWorldService] HTTP 오류: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ [VWorldService] Geocoder API 오류: $e');
      return null;
    }
  }

  /// 주소를 좌표로 변환 (Geocoder API)
  /// 
  /// [address] 도로명주소 또는 지번주소
  /// 
  /// 반환: {
  ///   'x': '경도',
  ///   'y': '위도',
  ///   'level': '정확도 레벨'
  /// }
  static Future<Map<String, dynamic>?> getLandInfoFromAddress(String address) async {
    try {
      
      final coordinates = await getCoordinatesFromAddress(address);
      
      if (coordinates == null) {
        print('❌ [VWorldService] 좌표 변환 실패');
        return null;
      }
      
      
      return {
        'coordinates': coordinates,
      };
    } catch (e) {
      print('❌ [VWorldService] 주소 → 좌표 변환 오류: $e');
      return null;
    }
  }

  /// 테스트용 메서드
  static Future<void> testApis() async {
    
    // Geocoder API 테스트
    const testAddress = '경기도 성남시 분당구 중앙공원로 54';
    await getCoordinatesFromAddress(testAddress);
    
  }
}

