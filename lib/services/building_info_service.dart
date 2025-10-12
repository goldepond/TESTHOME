import 'dart:convert';
import 'package:http/http.dart' as http;

class BuildingInfoService {
  static const String _baseUrl = 'https://apis.data.go.kr/1613000/ArchPmsServiceV2';
  static const String _serviceKey = 'lkFNy5FKYttNQrsdPfqBSmg8frydGZUlWeH5sHrmuILv0cwLvMSCDh+Tl1KORZJXQTqih1BTBLpxfdixxY0mUQ==';

  /// 건축물대장 총괄표제부 조회
  static Future<Map<String, dynamic>?> getBuildingInfo({
    required String sigunguCd,
    required String bjdongCd,
    String platGbCd = '0',
    required String bun,
    String ji = '',
  }) async {
    try {
      print('🏗️ [BuildingInfoService] 건축물대장 조회 시작');
      print('🏗️ [BuildingInfoService] sigunguCd: $sigunguCd, bjdongCd: $bjdongCd, bun: $bun, ji: $ji');
      
      final uri = Uri.parse('$_baseUrl/getBrRecapTitleInfo?ServiceKey=$_serviceKey&sigunguCd=$sigunguCd&bjdongCd=$bjdongCd&platGbCd=$platGbCd&bun=$bun&ji=$ji&_type=json&numOfRows=10&pageNo=1');

      print('🏗️ [BuildingInfoService] 요청 URL: ${uri.toString()}');

      final response = await http.get(uri);
      
      print('🏗️ [BuildingInfoService] 응답 상태코드: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        print('🏗️ [BuildingInfoService] 응답 데이터 길이: ${responseBody.length}');
        print('🏗️ [BuildingInfoService] 응답 데이터: $responseBody');
        
        final data = json.decode(responseBody);
        print('🏗️ [BuildingInfoService] 파싱된 데이터: $data');
        
        // 응답 구조 확인
        if (data['response'] != null && data['response']['body'] != null) {
          final body = data['response']['body'];
          print('🏗️ [BuildingInfoService] 응답 body: $body');
          
          if (body['items'] != null) {
            if (body['items']['item'] != null) {
              // 단일 아이템인 경우
              final item = body['items']['item'];
              print('✅ [BuildingInfoService] 건축물대장 조회 성공 - 단일 아이템: $item');
              return _parseBuildingInfo(item);
            } else if (body['items'] is List && (body['items'] as List).isNotEmpty) {
              // 여러 아이템인 경우 첫 번째 아이템 사용
              final item = (body['items'] as List).first;
              print('✅ [BuildingInfoService] 건축물대장 조회 성공 - 첫 번째 아이템: $item');
              return _parseBuildingInfo(item);
            } else {
              print('⚠️ [BuildingInfoService] 건축물 정보가 없습니다 - items: ${body['items']}');
              return null;
            }
          } else {
            print('⚠️ [BuildingInfoService] items가 없습니다 - body: $body');
            return null;
          }
        } else {
          print('❌ [BuildingInfoService] 응답 구조 오류: ${data}');
          return null;
        }
      } else {
        print('❌ [BuildingInfoService] API 요청 실패 - 상태코드: ${response.statusCode}');
        print('❌ [BuildingInfoService] 응답 내용: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ [BuildingInfoService] 건축물대장 조회 오류: $e');
      return null;
    }
  }

  /// 건축물 정보 파싱
  static Map<String, dynamic> _parseBuildingInfo(dynamic item) {
    final Map<String, dynamic> buildingInfo = {};
    
    try {
      // 기본 정보
      buildingInfo['platPlc'] = item['platPlc'] ?? ''; // 대지위치
      buildingInfo['newPlatPlc'] = item['newPlatPlc'] ?? ''; // 새주소
      buildingInfo['bldNm'] = item['bldNm'] ?? ''; // 건물명
      buildingInfo['splotNm'] = item['splotNm'] ?? ''; // 특수지구명
      
      // 면적 정보
      buildingInfo['platArea'] = item['platArea'] ?? ''; // 대지면적
      buildingInfo['archArea'] = item['archArea'] ?? ''; // 건축면적
      buildingInfo['totArea'] = item['totArea'] ?? ''; // 연면적
      buildingInfo['bcRat'] = item['bcRat'] ?? ''; // 건폐율
      buildingInfo['vlRat'] = item['vlRat'] ?? ''; // 용적율
      
      // 용도 정보
      buildingInfo['mainPurpsCdNm'] = item['mainPurpsCdNm'] ?? ''; // 주용도명
      buildingInfo['etcPurps'] = item['etcPurps'] ?? ''; // 기타용도
      
      // 세대 정보
      buildingInfo['hhldCnt'] = item['hhldCnt'] ?? ''; // 세대수
      buildingInfo['fmlyCnt'] = item['fmlyCnt'] ?? ''; // 가구수
      buildingInfo['hoCnt'] = item['hoCnt'] ?? ''; // 호수
      
      // 건물 정보
      buildingInfo['mainBldCnt'] = item['mainBldCnt'] ?? ''; // 주건축물수
      buildingInfo['atchBldCnt'] = item['atchBldCnt'] ?? ''; // 부속건축물수
      buildingInfo['atchBldArea'] = item['atchBldArea'] ?? ''; // 부속건축물면적
      
      // 주차 정보
      buildingInfo['totPkngCnt'] = item['totPkngCnt'] ?? ''; // 총주차수
      buildingInfo['indrMechUtcnt'] = item['indrMechUtcnt'] ?? ''; // 지하기계식주차수
      buildingInfo['indrMechArea'] = item['indrMechArea'] ?? ''; // 지하기계식주차면적
      buildingInfo['oudrMechUtcnt'] = item['oudrMechUtcnt'] ?? ''; // 지상기계식주차수
      buildingInfo['oudrMechArea'] = item['oudrMechArea'] ?? ''; // 지상기계식주차면적
      buildingInfo['indrAutoUtcnt'] = item['indrAutoUtcnt'] ?? ''; // 지하자동식주차수
      buildingInfo['indrAutoArea'] = item['indrAutoArea'] ?? ''; // 지하자동식주차면적
      buildingInfo['oudrAutoUtcnt'] = item['oudrAutoUtcnt'] ?? ''; // 지상자동식주차수
      buildingInfo['oudrAutoArea'] = item['oudrAutoArea'] ?? ''; // 지상자동식주차면적
      
      // 허가 정보
      buildingInfo['pmsDay'] = item['pmsDay'] ?? ''; // 허가일
      buildingInfo['stcnsDay'] = item['stcnsDay'] ?? ''; // 착공일
      buildingInfo['useAprDay'] = item['useAprDay'] ?? ''; // 사용승인일
      buildingInfo['pmsnoKikCdNm'] = item['pmsnoKikCdNm'] ?? ''; // 허가관리기관명
      buildingInfo['pmsnoGbCdNm'] = item['pmsnoGbCdNm'] ?? ''; // 허가구분명
      
      // 에너지 정보
      buildingInfo['engrGrade'] = item['engrGrade'] ?? ''; // 에너지등급
      buildingInfo['engrRat'] = item['engrRat'] ?? ''; // 에너지비율
      buildingInfo['engrEpi'] = item['engrEpi'] ?? ''; // 에너지성능지수
      buildingInfo['gnBldGrade'] = item['gnBldGrade'] ?? ''; // 그린건축인증등급
      buildingInfo['gnBldCert'] = item['gnBldCert'] ?? ''; // 그린건축인증일
      
      // 기타 정보
      buildingInfo['regstrGbCdNm'] = item['regstrGbCdNm'] ?? ''; // 등기부등본구분명
      buildingInfo['regstrKindCdNm'] = item['regstrKindCdNm'] ?? ''; // 등기부등본종류명
      buildingInfo['bylotCnt'] = item['bylotCnt'] ?? ''; // 필지수
      
      print('✅ [BuildingInfoService] 건축물 정보 파싱 완료: ${buildingInfo['bldNm']}');
      
    } catch (e) {
      print('❌ [BuildingInfoService] 건축물 정보 파싱 오류: $e');
    }
    
    return buildingInfo;
  }

  /// 주소에서 건축물대장 조회 파라미터 추출 (테스트용 하드코딩)
  static Map<String, String> extractBuildingParamsFromAddress(String address) {
    // 테스트용으로 분당구 우성아파트 정보 사용
    return {
      'sigunguCd': '41135', // 성남시분당구
      'bjdongCd': '10500', // 서현동
      'platGbCd': '0', // 대지
      'bun': '0096', // 96번지
      'ji': '', // 지
    };
  }

  /// 테스트용 메서드 - API 호출 테스트
  static Future<void> testApiCall() async {
    print('🧪 [BuildingInfoService] API 테스트 시작');
    final params = extractBuildingParamsFromAddress('');
    final result = await getBuildingInfo(
      sigunguCd: params['sigunguCd']!,
      bjdongCd: params['bjdongCd']!,
      platGbCd: params['platGbCd']!,
      bun: params['bun']!,
      ji: params['ji']!,
    );
    print('🧪 [BuildingInfoService] API 테스트 결과: $result');
  }
}
