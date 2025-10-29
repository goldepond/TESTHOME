import 'dart:convert';
import 'package:http/http.dart' as http;

/// 건축물대장 API 서비스
/// 공공데이터포털(data.go.kr) 건축물대장 API 연동
class BuildingRegisterService {
  // API 키 (공공데이터포털에서 발급받아야 함)
  static const String _apiKey = 'YOUR_API_KEY_HERE';
  
  // API 엔드포인트
  static const String _baseUrl = 'http://apis.data.go.kr/1613000/BldRgstService';
  
  /// 건축물대장 총괄표제부 조회
  /// 
  /// [sigunguCd] 시군구코드 (5자리)
  /// [bjdongCd] 법정동코드 (5자리)
  /// [bun] 번
  /// [ji] 지
  /// 
  /// 예시: 경기도 성남시 분당구 → 시군구코드: 41135
  ///      백현동 → 법정동코드: 10700
  ///      542번지 → bun: 0542, ji: 0000
  static Future<Map<String, dynamic>?> getBuildingRegister({
    required String sigunguCd,
    required String bjdongCd,
    required String bun,
    String ji = '0000',
  }) async {
    try {
      print('🏢 [BuildingRegisterService] 건축물대장 조회 시작');
      print('   시군구코드: $sigunguCd, 법정동코드: $bjdongCd, 번: $bun, 지: $ji');
      
      final uri = Uri.parse('$_baseUrl/getBrRecapTitleInfo').replace(queryParameters: {
        'serviceKey': _apiKey,
        'sigunguCd': sigunguCd,
        'bjdongCd': bjdongCd,
        'bun': bun,
        'ji': ji,
        'numOfRows': '10',
        'pageNo': '1',
        '_type': 'json',
      });
      
      print('🏢 [BuildingRegisterService] 요청 URL: ${uri.toString()}');
      
      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('⏱️ [BuildingRegisterService] API 타임아웃');
          throw Exception('건축물대장 API 타임아웃');
        },
      );
      
      print('🏢 [BuildingRegisterService] 응답 상태코드: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        print('🏢 [BuildingRegisterService] 응답 데이터 길이: ${responseBody.length}');
        
        final data = json.decode(responseBody);
        
        if (data['response'] != null && 
            data['response']['body'] != null &&
            data['response']['body']['items'] != null) {
          
          final items = data['response']['body']['items'];
          final item = items is List && items.isNotEmpty 
              ? items[0] 
              : items['item'];
          
          if (item != null) {
            print('✅ [BuildingRegisterService] 건축물대장 조회 성공');
            print('   건축물명: ${item['bldNm'] ?? ''}');
            print('   건축면적: ${item['archArea'] ?? ''}');
            print('   연면적: ${item['totArea'] ?? ''}');
            print('   층수: ${item['grndFlrCnt'] ?? ''}층 / 지하 ${item['ugrndFlrCnt'] ?? ''}층');
            print('   건축년도: ${item['useAprDay'] ?? ''}');
            
            return item as Map<String, dynamic>;
          }
        }
        
        print('⚠️ [BuildingRegisterService] 데이터가 없습니다');
        return null;
      } else {
        print('❌ [BuildingRegisterService] HTTP 오류: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ [BuildingRegisterService] 오류: $e');
      return null;
    }
  }
  
  /// 주소로부터 시군구코드, 법정동코드, 번지 추출
  /// 
  /// [address] 도로명주소 또는 지번주소
  /// 
  /// 반환: {
  ///   'sigunguCd': '41135',
  ///   'bjdongCd': '10700',
  ///   'bun': '0542',
  ///   'ji': '0000'
  /// }
  static Map<String, String>? parseAddressForBuildingRegister(String address) {
    try {
      print('📍 [BuildingRegisterService] 주소 파싱 시작: $address');
      
      // TODO: 주소를 시군구코드, 법정동코드, 번지로 변환하는 로직 구현
      // 현재는 임시 데이터 반환
      
      return null; // 임시로 null 반환
    } catch (e) {
      print('❌ [BuildingRegisterService] 주소 파싱 오류: $e');
      return null;
    }
  }
  
  /// 건축물대장 표제부 조회
  /// (상세 정보 - 건물명, 층별 면적, 구조 등)
  static Future<Map<String, dynamic>?> getBuildingTitle({
    required String sigunguCd,
    required String bjdongCd,
    required String bun,
    String ji = '0000',
  }) async {
    try {
      print('🏢 [BuildingRegisterService] 건축물대장 표제부 조회 시작');
      
      final uri = Uri.parse('$_baseUrl/getBrTitleInfo').replace(queryParameters: {
        'serviceKey': _apiKey,
        'sigunguCd': sigunguCd,
        'bjdongCd': bjdongCd,
        'bun': bun,
        'ji': ji,
        'numOfRows': '10',
        'pageNo': '1',
        '_type': 'json',
      });
      
      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
      );
      
      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        final data = json.decode(responseBody);
        
        if (data['response'] != null && 
            data['response']['body'] != null &&
            data['response']['body']['items'] != null) {
          
          final items = data['response']['body']['items'];
          final item = items is List && items.isNotEmpty 
              ? items[0] 
              : items['item'];
          
          if (item != null) {
            print('✅ [BuildingRegisterService] 표제부 조회 성공');
            return item as Map<String, dynamic>;
          }
        }
        
        return null;
      } else {
        print('❌ [BuildingRegisterService] HTTP 오류: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ [BuildingRegisterService] 오류: $e');
      return null;
    }
  }
  
  /// 건축물대장 층별개요 조회
  static Future<List<Map<String, dynamic>>?> getBuildingFloorInfo({
    required String sigunguCd,
    required String bjdongCd,
    required String bun,
    String ji = '0000',
  }) async {
    try {
      print('🏢 [BuildingRegisterService] 건축물대장 층별개요 조회 시작');
      
      final uri = Uri.parse('$_baseUrl/getBrFlrOulnInfo').replace(queryParameters: {
        'serviceKey': _apiKey,
        'sigunguCd': sigunguCd,
        'bjdongCd': bjdongCd,
        'bun': bun,
        'ji': ji,
        'numOfRows': '100',
        'pageNo': '1',
        '_type': 'json',
      });
      
      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
      );
      
      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        final data = json.decode(responseBody);
        
        if (data['response'] != null && 
            data['response']['body'] != null &&
            data['response']['body']['items'] != null) {
          
          final items = data['response']['body']['items'];
          
          if (items is List) {
            print('✅ [BuildingRegisterService] 층별개요 조회 성공: ${items.length}개');
            return items.cast<Map<String, dynamic>>();
          } else if (items['item'] != null) {
            final item = items['item'];
            if (item is List) {
              return item.cast<Map<String, dynamic>>();
            } else {
              return [item as Map<String, dynamic>];
            }
          }
        }
        
        return null;
      } else {
        print('❌ [BuildingRegisterService] HTTP 오류: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ [BuildingRegisterService] 오류: $e');
      return null;
    }
  }
}

