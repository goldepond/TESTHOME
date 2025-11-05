import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:property/constants/app_constants.dart';

class BuildingInfoService {
  /// 건축물대장 총괄표제부 조회
  static Future<Map<String, dynamic>?> getBuildingInfo({
    required String sigunguCd,
    required String bjdongCd,
    String platGbCd = '0',
    required String bun,
    String ji = '',
  }) async {
    try {
      final uri = Uri.parse('${ApiConstants.buildingInfoAPIBaseUrl}/getBrRecapTitleInfo?ServiceKey=${ApiConstants.data_go_kr_serviceKey}&sigunguCd=$sigunguCd&bjdongCd=$bjdongCd&platGbCd=$platGbCd&bun=$bun&ji=$ji&_type=json&numOfRows=10&pageNo=1');


      final response = await http.get(uri);
      
      
      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        
        final data = json.decode(responseBody);
        
        // 응답 구조 확인
        if (data['response'] != null && data['response']['body'] != null) {
          final body = data['response']['body'];
          
          if (body['items'] != null) {
            if (body['items']['item'] != null) {
              // 단일 아이템인 경우
              final item = body['items']['item'];
              return _parseBuildingInfo(item);
            } else if (body['items'] is List && (body['items'] as List).isNotEmpty) {
              // 여러 아이템인 경우 첫 번째 아이템 사용
              final item = (body['items'] as List).first;
              return _parseBuildingInfo(item);
            } else {
              return null;
            }
          } else {
            return null;
          }
        } else {
          return null;
        }
      } else {
        return null;
      }
    } catch (e) {
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
      
      
    } catch (e) {
    }
    
    return buildingInfo;
  }

  /// 주소에서 건축물대장 조회 파라미터 추출
  static Map<String, String> extractBuildingParamsFromAddress(String address) {
    return {
      'sigunguCd': '41135', // 성남시분당구
      'bjdongCd': '10500', // 서현동
      'platGbCd': '0', // 대지
      'bun': '0096', // 96번지
      'ji': '', // 지
    };
  }
}
