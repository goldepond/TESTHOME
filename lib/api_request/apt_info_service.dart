import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:property/constants/app_constants.dart';

class AptInfoService {
  /// 아파트 기본정보 조회
  static Future<Map<String, dynamic>?> getAptBasisInfo(String kaptCode) async {
    try {
      print('🏢 [AptInfoService] 아파트 기본정보 조회 시작 - 단지코드: $kaptCode');
      
      final uri = Uri.parse('${ApiConstants.aptInfoAPIBaseUrl}?ServiceKey=${ApiConstants.data_go_kr_serviceKey}&kaptCode=$kaptCode');

      print('🏢 [AptInfoService] 요청 URL: ${uri.toString()}');

      final response = await http.get(uri);
      
      print('🏢 [AptInfoService] 응답 상태코드: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        print('🏢 [AptInfoService] 응답 데이터 길이: ${responseBody.length}');
        print('🏢 [AptInfoService] 응답 데이터: $responseBody');
        
        final data = json.decode(responseBody);
        print('🏢 [AptInfoService] 파싱된 데이터: $data');
        
        // 응답 구조 확인
        if (data['response'] != null && data['response']['body'] != null) {
          final body = data['response']['body'];
          print('🏢 [AptInfoService] 응답 body: $body');
          
          if (body['items'] != null && body['items']['item'] != null) {
            final item = body['items']['item'];
            print('✅ [AptInfoService] 아파트 기본정보 조회 성공 - item: $item');
            return _parseAptInfo(item);
          } else {
            print('⚠️ [AptInfoService] 아파트 정보가 없습니다 - body: $body');
            return null;
          }
        } else {
          print('❌ [AptInfoService] 응답 구조 오류: $data');
          return null;
        }
      } else {
        print('❌ [AptInfoService] API 요청 실패 - 상태코드: ${response.statusCode}');
        print('❌ [AptInfoService] 응답 내용: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ [AptInfoService] 아파트 기본정보 조회 오류: $e');
      return null;
    }
  }

  /// 아파트 정보 파싱
  static Map<String, dynamic> _parseAptInfo(dynamic item) {
    final Map<String, dynamic> aptInfo = {};
    
    try {
      // 기본 정보
      aptInfo['kaptCode'] = item['kaptCode'] ?? ''; // 단지코드
      aptInfo['kaptName'] = item['kaptName'] ?? ''; // 단지명
      
      // 관리 정보
      aptInfo['codeMgr'] = item['codeMgr'] ?? ''; // 관리방식
      aptInfo['kaptMgrCnt'] = item['kaptMgrCnt'] ?? ''; // 관리사무소 수
      aptInfo['kaptCcompany'] = item['kaptCcompany'] ?? ''; // 관리업체
      
      // 보안 정보
      aptInfo['codeSec'] = item['codeSec'] ?? ''; // 보안관리방식
      aptInfo['kaptdScnt'] = item['kaptdScnt'] ?? ''; // 보안인력 수
      aptInfo['kaptdSecCom'] = item['kaptdSecCom'] ?? ''; // 보안업체
      
      // 청소 정보
      aptInfo['codeClean'] = item['codeClean'] ?? ''; // 청소관리방식
      aptInfo['kaptdClcnt'] = item['kaptdClcnt'] ?? ''; // 청소인력 수
      aptInfo['codeGarbage'] = item['codeGarbage'] ?? ''; // 쓰레기 수거방식
      
      // 소독 정보
      aptInfo['codeDisinf'] = item['codeDisinf'] ?? ''; // 소독관리방식
      aptInfo['kaptdDcnt'] = item['kaptdDcnt'] ?? ''; // 소독인력 수
      aptInfo['disposalType'] = item['disposalType'] ?? ''; // 소독방식
      
      // 건물 정보
      aptInfo['codeStr'] = item['codeStr'] ?? ''; // 건물구조
      aptInfo['kaptdEcapa'] = item['kaptdEcapa'] ?? ''; // 전기용량
      aptInfo['codeEcon'] = item['codeEcon'] ?? ''; // 전기계약방식
      aptInfo['codeEmgr'] = item['codeEmgr'] ?? ''; // 전기관리방식
      
      // 소방 정보
      aptInfo['codeFalarm'] = item['codeFalarm'] ?? ''; // 화재경보기 타입
      
      // 급수 정보
      aptInfo['codeWsupply'] = item['codeWsupply'] ?? ''; // 급수방식
      
      // 엘리베이터 정보
      aptInfo['codeElev'] = item['codeElev'] ?? ''; // 엘리베이터 관리방식
      aptInfo['kaptdEcnt'] = item['kaptdEcnt'] ?? ''; // 엘리베이터 수
      
      // 주차 정보
      aptInfo['kaptdPcnt'] = item['kaptdPcnt'] ?? ''; // 지상주차장 수
      aptInfo['kaptdPcntu'] = item['kaptdPcntu'] ?? ''; // 지하주차장 수
      
      // 통신 정보
      aptInfo['codeNet'] = item['codeNet'] ?? ''; // 인터넷 설치여부
      aptInfo['kaptdCccnt'] = item['kaptdCccnt'] ?? ''; // CCTV 수
      
      // 편의시설
      aptInfo['welfareFacility'] = item['welfareFacility'] ?? ''; // 복리시설
      
      // 교통 정보
      aptInfo['kaptdWtimebus'] = item['kaptdWtimebus'] ?? ''; // 버스 도보시간
      aptInfo['subwayLine'] = item['subwayLine'] ?? ''; // 지하철 노선
      aptInfo['subwayStation'] = item['subwayStation'] ?? ''; // 지하철역
      aptInfo['kaptdWtimesub'] = item['kaptdWtimesub'] ?? ''; // 지하철 도보시간
      
      // 주변시설
      aptInfo['convenientFacility'] = item['convenientFacility'] ?? ''; // 편의시설
      aptInfo['educationFacility'] = item['educationFacility'] ?? ''; // 교육시설
      
      // 전기차 충전기
      aptInfo['groundElChargerCnt'] = item['groundElChargerCnt'] ?? ''; // 지상 전기차 충전기 수
      aptInfo['undergroundElChargerCnt'] = item['undergroundElChargerCnt'] ?? ''; // 지하 전기차 충전기 수
      
      // 사용여부
      aptInfo['useYn'] = item['useYn'] ?? ''; // 사용여부
      
      print('✅ [AptInfoService] 아파트 정보 파싱 완료: ${aptInfo['kaptName']}');
      
    } catch (e) {
      print('❌ [AptInfoService] 아파트 정보 파싱 오류: $e');
    }
    
    return aptInfo;
  }

  /// 단지코드 추출 (주소에서 추출하거나 기본값 사용)
  /// 
  /// 주의: 현재는 제한적인 매칭만 지원합니다.
  /// 공동주택인 경우 주소에서 건물명을 추출하여 단지코드를 찾습니다.
  static String extractKaptCodeFromAddress(String address) {
    if (address.isEmpty) return '';
    
    // 주소에서 단지코드를 추출하는 로직
    // 실제로는 주소 매칭 API나 데이터베이스가 필요할 수 있음
    
    // 우성아파트 관련 주소 매칭
    if (address.contains('우성아파트') || 
        address.contains('서현시범우성') ||
        (address.contains('분당구') && address.contains('서현'))) {
      return 'A46377309'; // 우성아파트 단지코드
    }
    
    // 추가 단지 코드 매칭 로직을 여기에 추가할 수 있습니다
    // 예: if (address.contains('단지명')) return '단지코드';
    
    // 매칭 실패 시 빈 문자열 반환 (기본값 반환하지 않음)
    return '';
  }
  
  /// 주소에서 단지코드 목록 조회 시도 (향후 확장용)
  /// 
  /// 공동주택 관리정보 시스템 API를 사용하여 주소로 단지코드를 검색할 수 있습니다.
  /// 현재는 미구현 상태입니다.
  static Future<List<String>> searchKaptCodeByAddress(String address) async {
    // TODO: 공동주택 관리정보 시스템 API로 주소 검색 구현
    // 예: getAptListByName 또는 getAptListByAddress API 활용
    return [];
  }

  /// 테스트용 메서드 - API 호출 테스트
  static Future<void> testApiCall() async {
    print('🧪 [AptInfoService] API 테스트 시작');
    final result = await getAptBasisInfo('A46377309');
    print('🧪 [AptInfoService] API 테스트 결과: $result');
  }
}
