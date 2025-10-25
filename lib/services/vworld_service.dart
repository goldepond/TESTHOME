import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:property/constants/app_constants.dart';

/// VWorld API 서비스
/// 1. Geocoder API: 주소 → 좌표 변환
/// 2. 토지특성 API: 토지 정보 조회
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
      print('🗺️ [VWorldService] Geocoder API 호출 시작');
      print('🗺️ [VWorldService] 주소: $address');

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

      print('🗺️ [VWorldService] 요청 URL: ${uri.toString()}');

      final response = await http.get(uri).timeout(
        const Duration(seconds: ApiConstants.requestTimeoutSeconds),
        onTimeout: () {
          print('⏱️ [VWorldService] Geocoder API 타임아웃');
          throw Exception('Geocoder API 타임아웃');
        },
      );
      
      print('🗺️ [VWorldService] 응답 상태코드: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        print('🗺️ [VWorldService] 응답 데이터: $responseBody');
        
        final data = json.decode(responseBody);
        
        if (data['response'] != null && 
            data['response']['status'] == 'OK' &&
            data['response']['result'] != null) {
          
          final result = data['response']['result'];
          
          // point가 있는 경우
          if (result['point'] != null) {
            final point = result['point'];
            print('✅ [VWorldService] 좌표 변환 성공');
            print('   경도(x): ${point['x']}, 위도(y): ${point['y']}');
            
            return {
              'x': point['x'], // 경도 (longitude)
              'y': point['y'], // 위도 (latitude)
              'level': result['level'] ?? '0',
              'address': address,
            };
          }
          
          print('⚠️ [VWorldService] point 데이터가 없습니다');
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

  /// 좌표로 토지 특성 정보 조회 (토지특성 API)
  /// 
  /// [longitude] 경도
  /// [latitude] 위도
  /// [radiusMeters] 검색 반경 (미터), 기본값 50m
  /// 
  /// 반환: {
  ///   'landUse': '토지 용도',
  ///   'landArea': '토지 면적',
  ///   'landCategory': '토지 지목',
  ///   'landRatio': '토지 비율',
  ///   ...
  /// }
  static Future<Map<String, dynamic>?> getLandCharacteristics({
    required String longitude,
    required String latitude,
    int radiusMeters = 50, // 기본 50m 범위
  }) async {
    try {
      print('🏞️ [VWorldService] 토지특성 API 호출 시작');
      print('🏞️ [VWorldService] 좌표: ($longitude, $latitude), 범위: ${radiusMeters}m');

      // BBOX 생성 (D:\houseMvpProject의 generateBBOX 로직)
      final double lon = double.parse(longitude);
      final double lat = double.parse(latitude);
      
      // 1도 = 약 111km, 50m = 약 0.00045도
      final double delta = radiusMeters / 111000.0;
      
      final String minX = (lon - delta).toStringAsFixed(9);
      final String minY = (lat - delta).toStringAsFixed(9);
      final String maxX = (lon + delta).toStringAsFixed(9);
      final String maxY = (lat + delta).toStringAsFixed(9);
      
      final String bbox = '$minX,$minY,$maxX,$maxY';
      
      print('🏞️ [VWorldService] BBOX 범위: $bbox');

      final uri = Uri.parse(VWorldApiConstants.landBaseUrl).replace(queryParameters: {
        'key': VWorldApiConstants.apiKey,
        'typename': VWorldApiConstants.landQueryTypeName,
        'bbox': bbox, // 범위 검색
        'srsName': VWorldApiConstants.srsName,
        'output': 'application/json',
        'maxFeatures': '10',
        'resultType': 'results',
        'domain' : VWorldApiConstants.domainCORSParam
      });

      print('🏞️ [VWorldService] 요청 URL: ${uri.toString()}');

      final response = await http.get(uri).timeout(
        const Duration(seconds: ApiConstants.requestTimeoutSeconds),
        onTimeout: () {
          print('⏱️ [VWorldService] 토지특성 API 타임아웃');
          throw Exception('토지특성 API 타임아웃');
        },
      );
      
      print('🏞️ [VWorldService] 응답 상태코드: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        print('🏞️ [VWorldService] 응답 데이터 길이: ${responseBody.length}');
        
        // GeoJSON 또는 JSON 형식 파싱
        try {
          final data = json.decode(responseBody);
          
          if (data['features'] != null && (data['features'] as List).isNotEmpty) {
            final feature = (data['features'] as List).first;
            final properties = feature['properties'];
            
            print('✅ [VWorldService] 토지 특성 조회 성공 (JSON)');
            print('   전체 properties 키: ${properties?.keys?.toList()}');
            
            // 실제 API 응답 필드명 + D:\houseMvpProject 스타일
            final landUse = properties['lndcgr_code_nm'] ??    // 실제 필드명!
                           properties['JIMOK_NM'] ?? 
                           properties['jimok_nm'] ?? 
                           properties['land_use'] ?? 
                           properties['지목'] ?? 
                           properties['jimokNm'] ?? '';
            
            final landArea = properties['lndpcl_ar'] ??        // 실제 필드명!
                            properties['AREA'] ?? 
                            properties['area'] ?? 
                            properties['LNDPCLR'] ??  // 지적면적
                            properties['lndpclr'] ??
                            properties['면적'] ?? '';
            
            final landCategory = properties['lndcgr_code'] ??  // 실제 필드명!
                                properties['JIMOK_CD'] ?? 
                                properties['jimok_cd'] ?? 
                                properties['jimokCd'] ?? '';
            
            final pnu = properties['pnu'] ??                   // 실제 필드명!
                       properties['PNU'] ?? 
                       properties['LAND_CODE'] ?? '';
            
            final address = properties['mnnm'] ??              // 본번
                           properties['slno'] ??               // 부번
                           properties['JIBUN'] ?? 
                           properties['jibun'] ?? 
                           properties['ADDR'] ?? 
                           properties['addr'] ?? '';
            
            // 추가 정보
            final prposArea1Nm = properties['prpos_area_1_nm'] ?? '';  // 용도지역1
            final prposArea2Nm = properties['prpos_area_2_nm'] ?? '';  // 용도지역2
            final ladUseSittnNm = properties['lad_use_sittn_nm'] ?? ''; // 토지이용상황명
            final tpgrphHgCodeNm = properties['tpgrph_hg_code_nm'] ?? ''; // 지형높이명
            final tpgrphFrmCodeNm = properties['tpgrph_frm_code_nm'] ?? ''; // 지형형상명
            
            print('   🏞️ 토지 용도: $landUse');
            print('   📐 토지 면적: $landArea');
            print('   🔢 PNU: $pnu');
            print('   📍 지번: $address');
            print('   🏙️ 용도지역1: $prposArea1Nm');
            print('   🏙️ 용도지역2: $prposArea2Nm');
            print('   🌳 토지이용상황: $ladUseSittnNm');
            
            return {
              'landUse': landUse,
              'landArea': landArea,
              'landCategory': landCategory,
              'pnu': pnu,
              'address': address,
              // 추가 정보
              'prposArea1Nm': prposArea1Nm,      // 용도지역1
              'prposArea2Nm': prposArea2Nm,      // 용도지역2
              'ladUseSittnNm': ladUseSittnNm,    // 토지이용상황
              'tpgrphHgCodeNm': tpgrphHgCodeNm,  // 지형높이
              'tpgrphFrmCodeNm': tpgrphFrmCodeNm, // 지형형상
              'rawData': properties,
            };
          }
          
          print('⚠️ [VWorldService] features가 비어있습니다');
          return null;
        } catch (jsonError) {
          // JSON 파싱 실패 → XML/GML 형식 (D:\houseMvpProject 스타일)
          print('⚠️ [VWorldService] JSON 파싱 실패, XML/GML 형식으로 처리');
          
          // 빈 응답 체크 (D:\houseMvpProject의 로직)
          if (responseBody.contains('boundedBy') && responseBody.contains('-1,-1 0,0')) {
            print('   ⚠️ XML 응답: 데이터 없음 (boundedBy: -1,-1 0,0)');
            print('   원인: 해당 좌표 범위 내 토지특성 데이터 없음');
            return null;
          }
          
          print('   ✅ XML 응답: 데이터 있음 (${responseBody.length} bytes)');
          print('   📄 응답 미리보기: ${responseBody.substring(0, responseBody.length > 300 ? 300 : responseBody.length)}...');
          
          // XML 파싱 (정규식 사용 - D:\houseMvpProject 스타일)
          final landUseMatch = RegExp(r'<(?:JIMOK_NM|jimok_nm)>(.*?)</(?:JIMOK_NM|jimok_nm)>', caseSensitive: false).firstMatch(responseBody);
          final landAreaMatch = RegExp(r'<(?:AREA|area|LNDPCLR|lndpclr)>(.*?)</(?:AREA|area|LNDPCLR|lndpclr)>', caseSensitive: false).firstMatch(responseBody);
          final pnuMatch = RegExp(r'<(?:PNU|pnu)>(.*?)</(?:PNU|pnu)>', caseSensitive: false).firstMatch(responseBody);
          final jibunMatch = RegExp(r'<(?:JIBUN|jibun)>(.*?)</(?:JIBUN|jibun)>', caseSensitive: false).firstMatch(responseBody);
          
          final landUse = landUseMatch?.group(1)?.trim() ?? '';
          final landArea = landAreaMatch?.group(1)?.trim() ?? '';
          final pnu = pnuMatch?.group(1)?.trim() ?? '';
          final jibun = jibunMatch?.group(1)?.trim() ?? '';
          
          print('   🏞️ 토지 용도 (XML): $landUse');
          print('   📐 토지 면적 (XML): $landArea');
          print('   🔢 PNU (XML): $pnu');
          print('   📍 지번 (XML): $jibun');
          
          if (landUse.isNotEmpty || landArea.isNotEmpty) {
            return {
              'landUse': landUse,
              'landArea': landArea,
              'pnu': pnu,
              'address': jibun,
              'rawData': responseBody.substring(0, responseBody.length > 1000 ? 1000 : responseBody.length),
            };
          }
          
          print('   ⚠️ XML에서 유효한 데이터를 추출하지 못했습니다');
          return null;
        }
      } else {
        print('❌ [VWorldService] HTTP 오류: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ [VWorldService] 토지특성 API 오류: $e');
      return null;
    }
  }

  /// 주소로 토지 특성 정보 조회 (Geocoder + 토지특성 API 통합)
  /// 
  /// [address] 도로명주소 또는 지번주소
  /// 
  /// 반환: {
  ///   'coordinates': { 'x': '경도', 'y': '위도' },
  ///   'landInfo': { 'landUse': '토지 용도', ... }
  /// }
  static Future<Map<String, dynamic>?> getLandInfoFromAddress(String address) async {
    try {
      print('🔍 [VWorldService] 주소 → 토지정보 조회 시작');
      
      // 1단계: 주소 → 좌표 변환
      final coordinates = await getCoordinatesFromAddress(address);
      
      if (coordinates == null) {
        print('❌ [VWorldService] 좌표 변환 실패');
        return null;
      }
      
      // 2단계: 좌표 → 토지 특성 조회
      final landInfo = await getLandCharacteristics(
        longitude: coordinates['x'],
        latitude: coordinates['y'],
      );
      
      if (landInfo == null) {
        print('⚠️ [VWorldService] 토지 특성 조회 실패 (좌표는 성공)');
        return {
          'coordinates': coordinates,
          'landInfo': null,
        };
      }
      
      print('✅ [VWorldService] 주소 → 토지정보 조회 완료');
      
      return {
        'coordinates': coordinates,
        'landInfo': landInfo,
      };
    } catch (e) {
      print('❌ [VWorldService] 주소 → 토지정보 조회 오류: $e');
      return null;
    }
  }

  /// 테스트용 메서드
  static Future<void> testApis() async {
    print('🧪 [VWorldService] API 테스트 시작');
    
    // 1. Geocoder API 테스트
    print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('📍 Geocoder API 테스트');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    final testAddress = '경기도 성남시 분당구 중앙공원로 54';
    final coordinates = await getCoordinatesFromAddress(testAddress);
    print('결과: $coordinates');
    
    if (coordinates != null) {
      // 2. 토지특성 API 테스트
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('🏞️ 토지특성 API 테스트');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      final landInfo = await getLandCharacteristics(
        longitude: coordinates['x'],
        latitude: coordinates['y'],
      );
      print('결과: $landInfo');
    }
    
    // 3. 통합 API 테스트
    print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🔍 통합 API 테스트');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    final fullInfo = await getLandInfoFromAddress(testAddress);
    print('결과: $fullInfo');
    
    print('\n🧪 [VWorldService] API 테스트 완료');
  }
}

