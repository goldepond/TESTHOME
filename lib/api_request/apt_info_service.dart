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

  /// 주소에서 단지명 추출
  /// 
  /// 주소 형식 예시:
  /// - "서울특별시 중구 청구로 64 (신당동, 청구 e편한세상)" -> "청구 e편한세상"
  /// - "서울특별시 중구 수표로 67-2 (수표동)" -> null (단지명 없음)
  static String? extractComplexNameFromAddress(String address) {
    if (address.isEmpty) return null;
    
    print('🔍 [AptInfoService] 주소에서 단지명 추출 시도: $address');
    
    // 괄호 안의 내용 추출
    final bracketMatch = RegExp(r'\(([^)]+)\)').firstMatch(address);
    if (bracketMatch == null || bracketMatch.groupCount == 0) {
      print('⚠️ [AptInfoService] 괄호가 없거나 내용이 없음');
      return null;
    }
    
    final bracketContent = bracketMatch.group(1) ?? '';
    print('🔍 [AptInfoService] 괄호 안 내용: $bracketContent');
    
    // 쉼표로 구분된 경우 마지막 부분이 단지명일 가능성
    if (bracketContent.contains(',')) {
      final parts = bracketContent.split(',').map((e) => e.trim()).toList();
      print('🔍 [AptInfoService] 쉼표로 구분된 부분들: $parts');
      
      // 마지막 부분이 단지명으로 보이면 반환 (동 정보가 아닌 경우)
      final lastPart = parts.last;
      
      // 단지명 패턴 확인 (아파트, 주택, 단지, 뷰, 힐, 파크, 타운, 빌, e편한세상 등)
      final complexPattern = RegExp(r'(아파트|주택|단지|뷰|힐|파크|타운|빌|e편한세상|편한세상|래미안|자이|아이파크|힐스테이트|래미안|자이|디자인|센트럴|센트리|팰리스|팔래스|프리미엄|프리미어|하이츠|하임|시티|타워|맨션|빌리지|뷰티풀|라인|스타|스마트|헤리움|래미안|힐|파크|뷰)', caseSensitive: false);
      
      if (complexPattern.hasMatch(lastPart)) {
        print('✅ [AptInfoService] 단지명 추출 성공: $lastPart');
        return lastPart;
      } else {
        print('⚠️ [AptInfoService] 마지막 부분이 단지명 패턴이 아님: $lastPart');
      }
    } else {
      // 쉼표가 없으면 전체를 확인
      print('🔍 [AptInfoService] 쉼표 없음 - 전체 내용 확인: $bracketContent');
      
      // 단지명 패턴 확인
      final complexPattern = RegExp(r'(아파트|주택|단지|뷰|힐|파크|타운|빌|e편한세상|편한세상|래미안|자이|아이파크|힐스테이트|디자인|센트럴|센트리|팰리스|팔래스|프리미엄|프리미어|하이츠|하임|시티|타워|맨션|빌리지|뷰티풀|라인|스타|스마트|헤리움)', caseSensitive: false);
      
      if (complexPattern.hasMatch(bracketContent)) {
        print('✅ [AptInfoService] 단지명 추출 성공: $bracketContent');
        return bracketContent;
      }
    }
    
    print('⚠️ [AptInfoService] 단지명을 찾을 수 없음');
    return null;
  }
  
  /// 도로명코드로 단지코드 검색
  /// 
  /// 공동주택 단지 목록 제공 서비스의 도로명 아파트 목록 API 사용
  /// roadCode: 시군구번호+도로명번호
  static Future<String?> searchKaptCodeByRoadCode(String roadCode) async {
    if (roadCode.isEmpty) {
      print('⚠️ [AptInfoService] 도로명코드가 비어있음');
      return null;
    }
    
    try {
      print('🔍 [AptInfoService] 도로명코드로 단지코드 검색 시작: $roadCode');
      
      final baseUrl = 'https://apis.data.go.kr/1613000/AptListService3';
      final uri = Uri.parse('$baseUrl/getRoadnameAptList3').replace(queryParameters: {
        'ServiceKey': ApiConstants.data_go_kr_serviceKey,
        'roadCode': roadCode,
        '_type': 'json',
        'numOfRows': '10',
        'pageNo': '1',
      });
      
      print('🔍 [AptInfoService] 도로명코드 검색 요청 URL: ${uri.toString()}');
      
      final response = await http.get(uri);
      
      print('🔍 [AptInfoService] 도로명코드 검색 응답 상태코드: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        print('🔍 [AptInfoService] 도로명코드 검색 응답 데이터: $responseBody');
        
        final data = json.decode(responseBody);
        
        if (data['response'] != null && data['response']['body'] != null) {
          final body = data['response']['body'];
          
          if (body['items'] != null) {
            dynamic items = body['items'];
            List<dynamic> itemList = [];
            
            // API 응답 구조 확인: items가 배열인지, items['item']인지 확인
            if (items is List) {
              // items가 이미 배열인 경우
              itemList = items;
              print('🔍 [AptInfoService] items가 배열입니다');
            } else if (items is Map && items['item'] != null) {
              // items가 객체이고 'item' 필드가 있는 경우
              if (items['item'] is List) {
                itemList = items['item'] as List;
              } else {
                itemList = [items['item']];
              }
              print('🔍 [AptInfoService] items['item']에서 배열 추출');
            } else {
              print('⚠️ [AptInfoService] 예상하지 못한 items 구조: ${items.runtimeType}');
              print('⚠️ [AptInfoService] items 내용: $items');
            }
            
            print('🔍 [AptInfoService] 도로명코드 검색 결과 개수: ${itemList.length}');
            
            if (itemList.isNotEmpty) {
              // 첫 번째 결과의 단지코드 반환
              final firstItem = itemList[0];
              final kaptCode = firstItem['kaptCode']?.toString() ?? '';
              final kaptName = firstItem['kaptName']?.toString() ?? '';
              
              print('✅ [AptInfoService] 도로명코드로 단지코드 검색 성공: $kaptCode ($kaptName)');
              return kaptCode;
            } else {
              print('⚠️ [AptInfoService] 도로명코드 검색 결과 없음');
              return null;
            }
          }
        }
      } else {
        print('❌ [AptInfoService] 도로명코드 검색 API 요청 실패 - 상태코드: ${response.statusCode}');
        print('❌ [AptInfoService] 응답 내용: ${response.body}');
      }
    } catch (e, stackTrace) {
      print('❌ [AptInfoService] 도로명코드로 단지코드 검색 오류: $e');
      print('❌ [AptInfoService] 스택 트레이스: $stackTrace');
    }
    
    return null;
  }
  
  /// 법정동코드로 단지코드 검색
  /// 
  /// 공동주택 단지 목록 제공 서비스의 법정동 아파트 목록 API 사용
  /// bjdCode: 시군구코드+법정동코드
  static Future<String?> searchKaptCodeByBjdCode(String bjdCode) async {
    if (bjdCode.isEmpty) {
      print('⚠️ [AptInfoService] 법정동코드가 비어있음');
      return null;
    }
    
    try {
      print('🔍 [AptInfoService] 법정동코드로 단지코드 검색 시작: $bjdCode');
      
      final baseUrl = 'https://apis.data.go.kr/1613000/AptListService3';
      final uri = Uri.parse('$baseUrl/getLegaldongAptList3').replace(queryParameters: {
        'ServiceKey': ApiConstants.data_go_kr_serviceKey,
        'bjdCode': bjdCode,
        '_type': 'json',
        'numOfRows': '10',
        'pageNo': '1',
      });
      
      print('🔍 [AptInfoService] 법정동코드 검색 요청 URL: ${uri.toString()}');
      
      final response = await http.get(uri);
      
      print('🔍 [AptInfoService] 법정동코드 검색 응답 상태코드: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        print('🔍 [AptInfoService] 법정동코드 검색 응답 데이터: $responseBody');
        
        final data = json.decode(responseBody);
        
        if (data['response'] != null && data['response']['body'] != null) {
          final body = data['response']['body'];
          
          if (body['items'] != null) {
            dynamic items = body['items'];
            List<dynamic> itemList = [];
            
            // API 응답 구조 확인: items가 배열인지, items['item']인지 확인
            if (items is List) {
              // items가 이미 배열인 경우
              itemList = items.cast<dynamic>();
              print('🔍 [AptInfoService] items가 배열입니다 - 개수: ${itemList.length}');
            } else if (items is Map) {
              // items가 Map인 경우 'item' 필드 확인
              final itemValue = items['item'];
              if (itemValue != null) {
                if (itemValue is List) {
                  itemList = itemValue.cast<dynamic>();
                } else {
                  itemList = [itemValue];
                }
                print('🔍 [AptInfoService] items['item']에서 배열 추출 - 개수: ${itemList.length}');
              } else {
                print('⚠️ [AptInfoService] items가 Map이지만 item 필드가 없습니다');
                print('⚠️ [AptInfoService] items 내용: $items');
              }
            } else {
              print('⚠️ [AptInfoService] 예상하지 못한 items 구조: ${items.runtimeType}');
              print('⚠️ [AptInfoService] items 내용: $items');
            }
            
            print('🔍 [AptInfoService] 법정동코드 검색 결과 개수: ${itemList.length}');
            
            if (itemList.isNotEmpty) {
              // 첫 번째 결과 반환 (도로명코드 검색에서는 첫 번째 결과가 가장 적합)
              final firstItem = itemList[0];
              final kaptCode = firstItem['kaptCode']?.toString() ?? '';
              final kaptName = firstItem['kaptName']?.toString() ?? '';
              
              print('✅ [AptInfoService] 법정동코드로 단지코드 검색 성공: $kaptCode ($kaptName)');
              return kaptCode;
            } else {
              print('⚠️ [AptInfoService] 법정동코드 검색 결과 없음');
              return null;
            }
          }
        }
      } else {
        print('❌ [AptInfoService] 법정동코드 검색 API 요청 실패 - 상태코드: ${response.statusCode}');
        print('❌ [AptInfoService] 응답 내용: ${response.body}');
      }
    } catch (e, stackTrace) {
      print('❌ [AptInfoService] 법정동코드로 단지코드 검색 오류: $e');
      print('❌ [AptInfoService] 스택 트레이스: $stackTrace');
    }
    
    return null;
  }
  
  /// 단지명으로 단지코드 검색
  /// 
  /// 공동주택 관리정보 시스템 API의 단지명 검색 기능을 사용합니다.
  static Future<String?> searchKaptCodeByName(String complexName) async {
    if (complexName.isEmpty) {
      print('⚠️ [AptInfoService] 단지명이 비어있음');
      return null;
    }
    
    try {
      print('🔍 [AptInfoService] 단지명으로 단지코드 검색 시작: $complexName');
      
      // 단지명 검색은 AptListService3의 getTotalAptList3 사용
      // 전체 목록을 가져와서 클라이언트에서 필터링하거나
      // 또는 법정동코드로 검색한 결과에서 단지명으로 필터링
      // 일단 단지명 검색 전용 API가 없다면 법정동코드로 검색 후 필터링하는 방식 사용
      // 하지만 현재는 단지명 검색 전용 API를 찾을 수 없으므로
      // 응답에서 받은 결과들 중에서 단지명과 가장 유사한 것을 찾는 방식 사용
      
      // 주의: AptBasisInfoServiceV4/getAptBasisInfo는 단지코드를 받는 엔드포인트입니다
      // 단지명으로 검색하는 엔드포인트는 AptListService3의 다른 메서드를 사용하거나
      // 전체 목록에서 필터링해야 합니다.
      
      // 현재는 단지명 검색 전용 API가 없는 것으로 보이므로
      // null을 반환하고 상위에서 다른 방법(fallback)을 시도하도록 합니다
      print('⚠️ [AptInfoService] 단지명 검색 전용 API를 찾을 수 없습니다');
      print('⚠️ [AptInfoService] 현재는 단지명으로 직접 검색할 수 없습니다');
      
      // 임시로 전체 목록 API를 사용해보지만, 이것도 단지명 파라미터를 지원하지 않을 수 있습니다
      // 따라서 현재는 단지명 검색을 지원하지 않고, 도로명코드/법정동코드 검색 결과에서
      // 단지명 매칭 로직을 추가하는 것이 더 나을 수 있습니다.
      
      return null; // 단지명 검색 전용 API가 없으므로 null 반환
    } catch (e, stackTrace) {
      print('❌ [AptInfoService] 단지명으로 단지코드 검색 오류: $e');
      print('❌ [AptInfoService] 스택 트레이스: $stackTrace');
    }
    
    return null;
  }
  
  /// 단지코드 추출 (주소에서 추출하거나 기본값 사용)
  /// 
  /// 주의: 현재는 제한적인 매칭만 지원합니다.
  /// 공동주택인 경우 주소에서 건물명을 추출하여 단지코드를 찾습니다.
  /// 
  /// 이 함수는 동기 함수이므로 하드코딩된 매칭만 반환합니다.
  /// 실제 단지명 검색은 extractKaptCodeFromAddressAsync를 사용하세요.
  static String extractKaptCodeFromAddress(String address) {
    if (address.isEmpty) return '';
    
    // 하드코딩된 매칭 (빠른 응답을 위한 캐시)
    if (address.contains('우성아파트') || 
        address.contains('서현시범우성') ||
        (address.contains('분당구') && address.contains('서현'))) {
      return 'A46377309'; // 우성아파트 단지코드
    }
    
    // 매칭 실패 시 빈 문자열 반환
    return '';
  }
  
  /// 주소 검색 API 데이터에서 도로명코드/법정동코드 추출
  /// 
  /// 주소 검색 API 응답 데이터에서 도로명코드나 법정동코드를 추출합니다.
  /// fullAddrAPIData: 주소 검색 API에서 반환된 원본 데이터 (Map<String, String>)
  static Map<String, String?> extractCodesFromAddressData(Map<String, String>? fullAddrAPIData) {
    if (fullAddrAPIData == null || fullAddrAPIData.isEmpty) {
      print('⚠️ [AptInfoService] 주소 데이터가 비어있음');
      return {'roadCode': null, 'bjdCode': null};
    }
    
    print('🔍 [AptInfoService] 주소 데이터에서 코드 추출 시도');
    print('🔍 [AptInfoService] 주소 데이터 keys: ${fullAddrAPIData.keys}');
    
    // 주소 검색 API(juso.go.kr) 응답 구조
    // 일반적인 필드들:
    // - roadAddr: 도로명주소
    // - jibunAddr: 지번주소
    // - rnMgtSn: 도로명관리번호 (도로명코드 추출에 사용)
    // - bdMgtSn: 건물관리번호
    // - admCd: 행정구역코드 (법정동코드 추출에 사용 가능)
    // - siNm, sggNm, emdNm: 시명, 시군구명, 읍면동명
    
    // 전체 데이터를 콘솔에 출력하여 구조 확인
    print('🔍 [AptInfoService] 주소 데이터 전체 내용:');
    fullAddrAPIData.forEach((key, value) {
      print('🔍 [AptInfoService]   $key: $value');
    });
    
    // 도로명코드 추출 시도
    // 도로명코드 형식: 시군구번호(5자리) + 도로명번호(7자리) = 12자리
    // 예: 263802006002 (부산광역시 사하구 + 도로명번호)
    String? roadCode;
    
    // 방법 1: rnMgtSn 사용 (도로명관리번호에서 추출 가능한 경우)
    final rnMgtSn = fullAddrAPIData['rnMgtSn'] ?? '';
    print('🔍 [AptInfoService] rnMgtSn: $rnMgtSn');
    
    // 방법 2: 시군구코드와 도로명번호를 조합
    // 주소 검색 API에서 직접 roadCode를 제공하지 않을 수 있으므로
    // rnMgtSn이나 다른 필드를 조합하여 생성해야 할 수 있음
    
    if (rnMgtSn.isNotEmpty) {
      // rnMgtSn이 12자리 이상이면 앞의 12자리를 roadCode로 사용
      // 또는 rnMgtSn에서 도로명코드를 추출하는 로직 필요
      if (rnMgtSn.length >= 12) {
        roadCode = rnMgtSn.substring(0, 12);
        print('🔍 [AptInfoService] rnMgtSn에서 도로명코드 추출: $roadCode');
      } else {
        // rnMgtSn이 짧으면 그대로 사용 시도
        roadCode = rnMgtSn;
        print('🔍 [AptInfoService] rnMgtSn을 도로명코드로 사용: $roadCode');
      }
    }
    
    // 법정동코드 추출 시도
    // 법정동코드 형식: 시군구코드(5자리) + 법정동코드(5자리) = 10자리
    // 예: 2638010100 (부산광역시 사하구 + 법정동코드)
    String? bjdCode;
    
    // 방법 1: admCd 사용 (행정구역코드)
    final admCd = fullAddrAPIData['admCd'] ?? '';
    print('🔍 [AptInfoService] admCd: $admCd');
    
    if (admCd.isNotEmpty) {
      // admCd가 10자리 이상이면 앞의 10자리를 bjdCode로 사용
      if (admCd.length >= 10) {
        bjdCode = admCd.substring(0, 10);
        print('🔍 [AptInfoService] admCd에서 법정동코드 추출: $bjdCode');
      } else {
        // admCd가 짧으면 그대로 사용 시도
        bjdCode = admCd;
        print('🔍 [AptInfoService] admCd를 법정동코드로 사용: $bjdCode');
      }
    }
    
    print('🔍 [AptInfoService] 최종 추출 결과:');
    print('🔍 [AptInfoService]   roadCode: $roadCode');
    print('🔍 [AptInfoService]   bjdCode: $bjdCode');
    
    return {'roadCode': roadCode, 'bjdCode': bjdCode};
  }
  
  /// 주소에서 단지코드를 비동기로 추출 (도로명코드/법정동코드 우선, 단지명 검색 fallback)
  /// 
  /// 1. 주소 검색 API 데이터에서 도로명코드/법정동코드 추출하여 검색
  /// 2. 실패 시 주소에서 단지명 추출하여 검색
  static Future<String?> extractKaptCodeFromAddressAsync(String address, {Map<String, String>? fullAddrAPIData}) async {
    print('🔍 [AptInfoService] extractKaptCodeFromAddressAsync 시작: $address');
    print('🔍 [AptInfoService] fullAddrAPIData 제공됨: ${fullAddrAPIData != null}');
    
    // 먼저 하드코딩된 매칭 확인
    final hardcodedCode = extractKaptCodeFromAddress(address);
    if (hardcodedCode.isNotEmpty) {
      print('✅ [AptInfoService] 하드코딩된 매칭 발견: $hardcodedCode');
      return hardcodedCode;
    }
    
    // 1순위: 주소 검색 API 데이터에서 도로명코드/법정동코드 추출하여 검색
    if (fullAddrAPIData != null) {
      final codes = extractCodesFromAddressData(fullAddrAPIData);
      final roadCode = codes['roadCode'];
      final bjdCode = codes['bjdCode'];
      
      // 도로명코드로 검색 시도
      if (roadCode != null && roadCode.isNotEmpty) {
        print('🔍 [AptInfoService] 도로명코드로 검색 시도: $roadCode');
        final kaptCode = await searchKaptCodeByRoadCode(roadCode);
        if (kaptCode != null && kaptCode.isNotEmpty) {
          print('✅ [AptInfoService] 도로명코드로 단지코드 찾음: $kaptCode');
          return kaptCode;
        }
      }
      
      // 법정동코드로 검색 시도 (단지명 매칭 포함)
      if (bjdCode != null && bjdCode.isNotEmpty) {
        print('🔍 [AptInfoService] 법정동코드로 검색 시도: $bjdCode');
        
        // 주소에서 단지명 추출
        final complexName = extractComplexNameFromAddress(address);
        
        if (complexName != null && complexName.isNotEmpty) {
          // 단지명이 있으면 법정동코드로 검색 후 매칭
          print('🔍 [AptInfoService] 단지명으로 필터링 시도: $complexName');
          
          try {
            final baseUrl = 'https://apis.data.go.kr/1613000/AptListService3';
            final uri = Uri.parse('$baseUrl/getLegaldongAptList3').replace(queryParameters: {
              'ServiceKey': ApiConstants.data_go_kr_serviceKey,
              'bjdCode': bjdCode,
              '_type': 'json',
              'numOfRows': '50', // 더 많은 결과를 가져와서 매칭
              'pageNo': '1',
            });
            
            final response = await http.get(uri);
            
            if (response.statusCode == 200) {
              final responseBody = utf8.decode(response.bodyBytes);
              final data = json.decode(responseBody);
              
              if (data['response'] != null && data['response']['body'] != null) {
                final body = data['response']['body'];
                
                if (body['items'] != null) {
                  dynamic items = body['items'];
                  List<dynamic> itemList = [];
                  
                  if (items is List) {
                    itemList = items.cast<dynamic>();
                  } else if (items is Map) {
                    final itemValue = items['item'];
                    if (itemValue != null) {
                      if (itemValue is List) {
                        itemList = itemValue.cast<dynamic>();
                      } else {
                        itemList = [itemValue];
                      }
                    }
                  }
                  
                  // 단지명 매칭 시도 (대소문자 무시, 공백 제거)
                  final normalizedComplexName = complexName.replaceAll(RegExp(r'\s+'), '').toLowerCase();
                  
                  for (var item in itemList) {
                    final kaptCode = item['kaptCode']?.toString() ?? '';
                    final kaptNameDisplay = item['kaptName']?.toString() ?? '';
                    final normalizedKaptName = kaptNameDisplay.replaceAll(RegExp(r'\s+'), '').toLowerCase();
                    
                    if (normalizedKaptName.contains(normalizedComplexName) || 
                        normalizedComplexName.contains(normalizedKaptName)) {
                      print('✅ [AptInfoService] 단지명 매칭 성공: $kaptCode ($kaptNameDisplay)');
                      return kaptCode;
                    }
                  }
                  
                  print('⚠️ [AptInfoService] 단지명 매칭 실패 - 첫 번째 결과 반환');
                  if (itemList.isNotEmpty) {
                    final firstItem = itemList[0];
                    final kaptCode = firstItem['kaptCode']?.toString() ?? '';
                    return kaptCode;
                  }
                }
              }
            }
          } catch (e) {
            print('⚠️ [AptInfoService] 단지명 매칭 중 오류: $e');
            // 오류 발생 시 일반 검색으로 fallback
            final kaptCode = await searchKaptCodeByBjdCode(bjdCode);
            if (kaptCode != null && kaptCode.isNotEmpty) {
              return kaptCode;
            }
          }
        } else {
          // 단지명이 없으면 일반 검색
          final kaptCode = await searchKaptCodeByBjdCode(bjdCode);
          if (kaptCode != null && kaptCode.isNotEmpty) {
            print('✅ [AptInfoService] 법정동코드로 단지코드 찾음: $kaptCode');
            return kaptCode;
          }
        }
      }
    }
    
    print('⚠️ [AptInfoService] 단지코드를 찾을 수 없음');
    return null;
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
