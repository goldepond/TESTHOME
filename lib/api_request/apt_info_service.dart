import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:property/constants/app_constants.dart';

class AptInfoService {
  /// 아파트 기본정보 조회
  static Future<Map<String, dynamic>?> getAptBasisInfo(String kaptCode) async {
    try {
      
      // ServiceKey URL 인코딩 문제 방지를 위해 queryParameters 사용
      // API 문서에 따르면 Encoding된 인증키를 사용해야 함
      // Uri.replace()가 자동으로 URL 인코딩해줌
      const baseUrl = ApiConstants.aptInfoAPIBaseUrl;
      final queryParams = {
        'ServiceKey': ApiConstants.data_go_kr_serviceKey, // Decoding된 키 (Uri가 자동 인코딩)
        'kaptCode': kaptCode,
      };
      final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);
      

      queryParams.forEach((key, value) {
        if (key == 'ServiceKey') {
        } else {
        }
      });

      final response = await http.get(uri);
      
      
      // UTF-8 디코딩으로 응답 본문 가져오기
      String responseBody;
      try {
        responseBody = utf8.decode(response.bodyBytes);
      } catch (e) {
        responseBody = response.body;
      }
      
      
      if (response.statusCode == 200) {
        try {
          final data = json.decode(responseBody);
          
          // 응답 구조 확인
          if (data['response'] != null) {
            final responseData = data['response'];
            
            // 에러 체크
            if (responseData['header'] != null) {
              final header = responseData['header'];
              final resultCode = header['resultCode']?.toString() ?? '';
              
              // 에러 코드가 있는 경우
              if (resultCode != '00' && resultCode != '0') {
                return null;
              }
            }
            
            if (responseData['body'] != null) {
              final body = responseData['body'];
              
              // 응답 구조 확인: body['item'] 또는 body['items']['item']
              dynamic item;
              if (body['item'] != null) {
                // 직접 item이 있는 경우 (getAphusDtlInfoV4)
                item = body['item'];
                return _parseAptInfo(item);
              } else if (body['items'] != null && body['items']['item'] != null) {
                // items 안에 item이 있는 경우 (다른 API)
                item = body['items']['item'];
                return _parseAptInfo(item);
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
      } else {
        
        // 500 에러인 경우 추가 정보
        if (response.statusCode == 500) {
        }
        
        // 응답 본문이 JSON 형식인지 확인
        try {
          final errorData = json.decode(responseBody);
          
          if (errorData['response'] != null && errorData['response']['header'] != null) {
            // 에러 처리 로직 필요 시 사용
          }
        } catch (_) {
          // 에러 발생 시 무시
        }
        
        return null;
      }
    } catch (e) {
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
    } catch (_) {
      // 파싱 오류 시 빈 Map 반환
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
    
    
    // 괄호 안의 내용 추출
    final bracketMatch = RegExp(r'\(([^)]+)\)').firstMatch(address);
    if (bracketMatch == null || bracketMatch.groupCount == 0) {
      return null;
    }
    
    final bracketContent = bracketMatch.group(1) ?? '';
    
    // 단지명 패턴 (더 많은 패턴 포함)
    final complexPattern = RegExp(r'(아파트|주택|단지|뷰|힐|파크|타운|빌|e편한세상|편한세상|래미안|자이|아이파크|힐스테이트|디자인|센트럴|센트리|팰리스|팔래스|프리미엄|프리미어|하이츠|하임|시티|타워|맨션|빌리지|뷰티풀|라인|스타|스마트|헤리움|신금호)', caseSensitive: false);
    
    // 동 이름 패턴 (제외할 패턴)
    final dongPattern = RegExp(r'^[가-힣]+동\d*가?$|^[가-힣]+동$', caseSensitive: false);
    
    // 쉼표로 구분된 경우
    if (bracketContent.contains(',')) {
      final parts = bracketContent.split(',').map((e) => e.trim()).toList();
      
      // 각 부분을 확인하여 단지명 찾기
      for (int i = parts.length - 1; i >= 0; i--) {
        final part = parts[i];
        
        // 동 이름 패턴이 아닌 경우에만 단지명으로 판단
        if (!dongPattern.hasMatch(part)) {
          // 단지명 패턴이 있는지 확인
          if (complexPattern.hasMatch(part)) {
            return part;
          } else {
            // 패턴이 없어도 길이가 3자 이상이고 숫자+동 형식이 아니면 단지명 가능성
            if (part.length >= 3 && !RegExp(r'^\d+동$').hasMatch(part)) {
              return part;
            }
          }
        }
      }
      
      // 모든 부분을 확인했지만 못 찾은 경우
    } else {
      // 쉼표가 없으면 전체를 확인
      
      // 동 이름이 아닌 경우
      if (!dongPattern.hasMatch(bracketContent)) {
        // 단지명 패턴 확인
        if (complexPattern.hasMatch(bracketContent)) {
          return bracketContent;
        } else {
          // 패턴이 없어도 길이가 3자 이상이면 단지명 가능성
          if (bracketContent.length >= 3) {
            return bracketContent;
          }
        }
      }
    }
    
    return null;
  }
  
  /// 단지명 매칭 헬퍼 메서드 (중복 코드 제거)
  static String? _matchComplexName(List<dynamic> itemList, String complexName) {
    final normalizedComplexName = complexName.replaceAll(RegExp(r'\s+'), '').toLowerCase();
    
    for (final item in itemList) {
      final kaptCode = item['kaptCode']?.toString() ?? '';
      final kaptNameDisplay = item['kaptName']?.toString() ?? '';
      final normalizedKaptName = kaptNameDisplay.replaceAll(RegExp(r'\s+'), '').toLowerCase();
      
      if (normalizedKaptName.contains(normalizedComplexName) || 
          normalizedComplexName.contains(normalizedKaptName)) {
        return kaptCode;
      }
    }
    
    return null;
  }
  
  /// API 응답에서 itemList 추출 헬퍼 메서드 (중복 코드 제거)
  static List<dynamic> _extractItemList(dynamic items) {
    if (items is List) {
      return items.cast<dynamic>();
    } else if (items is Map) {
      final itemValue = items['item'];
      if (itemValue != null) {
        if (itemValue is List) {
          return itemValue.cast<dynamic>();
        } else {
          return [itemValue];
        }
      }
    }
    return [];
  }
  
  /// 도로명코드로 단지코드 검색
  /// 
  /// 공동주택 단지 목록 제공 서비스의 도로명 아파트 목록 API 사용
  /// roadCode: 시군구번호+도로명번호
  static Future<String?> searchKaptCodeByRoadCode(String roadCode) async {
    if (roadCode.isEmpty) return null;
    
    try {
      const baseUrl = 'https://apis.data.go.kr/1613000/AptListService3';
      final queryParams = {
        'ServiceKey': ApiConstants.data_go_kr_serviceKey,
        'roadCode': roadCode,
        '_type': 'json',
        'numOfRows': '10',
        'pageNo': '1',
      };
      final uri = Uri.parse('$baseUrl/getRoadnameAptList3').replace(queryParameters: queryParams);
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        final data = json.decode(responseBody);
        
        if (data['response']?['body']?['items'] != null) {
          final itemList = _extractItemList(data['response']!['body']!['items']);
          if (itemList.isNotEmpty) {
            return itemList[0]['kaptCode']?.toString() ?? '';
          }
        }
      } else {
      }
    } catch (e) {
    }
    
    return null;
  }
  
  /// 법정동코드로 단지코드 검색
  /// 
  /// 공동주택 단지 목록 제공 서비스의 법정동 아파트 목록 API 사용
  /// bjdCode: 시군구코드+법정동코드
  static Future<String?> searchKaptCodeByBjdCode(String bjdCode) async {
    if (bjdCode.isEmpty) {
      return null;
    }
    
    try {
      
      const baseUrl = 'https://apis.data.go.kr/1613000/AptListService3';
      final queryParams = {
        'ServiceKey': ApiConstants.data_go_kr_serviceKey,
        'bjdCode': bjdCode,
        '_type': 'json',
        'numOfRows': '10',
        'pageNo': '1',
      };
      final uri = Uri.parse('$baseUrl/getLegaldongAptList3').replace(queryParameters: queryParams);
      
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        
        final data = json.decode(responseBody);
        
        if (data['response']?['body']?['items'] != null) {
          final itemList = _extractItemList(data['response']!['body']!['items']);
          if (itemList.isNotEmpty) {
            return itemList[0]['kaptCode']?.toString() ?? '';
          }
        }
      }
    } catch (_) {
      // 단지코드 검색 실패 시 null 반환
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
      return {'roadCode': null, 'bjdCode': null};
    }
    
    // 도로명코드 추출
    String? roadCode;
    final rnMgtSn = fullAddrAPIData['rnMgtSn'] ?? '';
    if (rnMgtSn.isNotEmpty) {
      roadCode = rnMgtSn.length >= 12 ? rnMgtSn.substring(0, 12) : rnMgtSn;
    }
    
    // 법정동코드 추출
    String? bjdCode;
    final admCd = fullAddrAPIData['admCd'] ?? '';
    if (admCd.isNotEmpty) {
      bjdCode = admCd.length >= 10 ? admCd.substring(0, 10) : admCd;
    }
    
    return {'roadCode': roadCode, 'bjdCode': bjdCode};
  }
  
  /// 주소에서 단지코드를 비동기로 추출 (도로명코드/법정동코드 우선, 단지명 검색 fallback)
  /// 
  /// 1. 주소 검색 API 데이터에서 도로명코드/법정동코드 추출하여 검색
  /// 2. 실패 시 주소에서 단지명 추출하여 검색
  static Future<String?> extractKaptCodeFromAddressAsync(String address, {Map<String, String>? fullAddrAPIData}) async {
    // 먼저 하드코딩된 매칭 확인
    final hardcodedCode = extractKaptCodeFromAddress(address);
    if (hardcodedCode.isNotEmpty) {
      return hardcodedCode;
    }
    
    // 1순위: 주소 검색 API 데이터에서 도로명코드/법정동코드 추출하여 검색
    if (fullAddrAPIData != null) {
      final codes = extractCodesFromAddressData(fullAddrAPIData);
      final roadCode = codes['roadCode'];
      final bjdCode = codes['bjdCode'];
      
      
      // 도로명코드로 검색 시도 (단지명 매칭 포함)
      if (roadCode != null && roadCode.isNotEmpty) {
        
        // 주소에서 단지명 추출하여 매칭
        // 방법 1: 주소 데이터에서 bdNm(건물명) 필드 확인 (가장 정확)
        String? complexName;
        if (fullAddrAPIData['bdNm'] != null && fullAddrAPIData['bdNm']!.isNotEmpty) {
          complexName = fullAddrAPIData['bdNm'];
        }
        
        // 방법 2: 주소 문자열에서 단지명 추출 (bdNm이 없거나 비어있는 경우)
        if (complexName == null || complexName.isEmpty) {
          complexName = extractComplexNameFromAddress(address);
        }
        
        if (complexName != null && complexName.isNotEmpty) {
          // 단지명이 있으면 도로명코드로 검색 후 매칭 시도
          try {
            const baseUrl = 'https://apis.data.go.kr/1613000/AptListService3';
            final queryParams = {
              'ServiceKey': ApiConstants.data_go_kr_serviceKey,
              'roadCode': roadCode,
              '_type': 'json',
              'numOfRows': '50',
              'pageNo': '1',
            };
            final uri = Uri.parse('$baseUrl/getRoadnameAptList3').replace(queryParameters: queryParams);
            
            final response = await http.get(uri);
            if (response.statusCode == 200) {
              final responseBody = utf8.decode(response.bodyBytes);
              final data = json.decode(responseBody);
              
              if (data['response']?['body']?['items'] != null) {
                final itemList = _extractItemList(data['response']!['body']!['items']);
                
                // 단지명 매칭 시도
                final matchedCode = _matchComplexName(itemList, complexName);
                if (matchedCode != null) return matchedCode;
                
                // 매칭 실패 시 첫 번째 결과 반환
                if (itemList.isNotEmpty) {
                  return itemList[0]['kaptCode']?.toString() ?? '';
                }
              }
            }
          } catch (e) {
            // 오류 발생 시 일반 검색으로 fallback
            final kaptCode = await searchKaptCodeByRoadCode(roadCode);
            if (kaptCode != null && kaptCode.isNotEmpty) {
              return kaptCode;
            }
          }
        } else {
          // 단지명이 없으면 일반 검색
          final kaptCode = await searchKaptCodeByRoadCode(roadCode);
          if (kaptCode != null && kaptCode.isNotEmpty) {
            return kaptCode;
          }
        }
      }
      
      // 법정동코드로 검색 시도 (단지명 매칭 포함)
      if (bjdCode != null && bjdCode.isNotEmpty) {
        // 주소에서 단지명 추출
        String? complexName = fullAddrAPIData['bdNm'];
        if (complexName == null || complexName.isEmpty) {
          complexName = extractComplexNameFromAddress(address);
        }
        
        if (complexName != null && complexName.isNotEmpty) {
          // 단지명이 있으면 법정동코드로 검색 후 매칭
          try {
            const baseUrl = 'https://apis.data.go.kr/1613000/AptListService3';
            final queryParams = {
              'ServiceKey': ApiConstants.data_go_kr_serviceKey,
              'bjdCode': bjdCode,
              '_type': 'json',
              'numOfRows': '50',
              'pageNo': '1',
            };
            final uri = Uri.parse('$baseUrl/getLegaldongAptList3').replace(queryParameters: queryParams);
            
            final response = await http.get(uri);
            if (response.statusCode == 200) {
              final responseBody = utf8.decode(response.bodyBytes);
              final data = json.decode(responseBody);
              
              if (data['response']?['body']?['items'] != null) {
                final itemList = _extractItemList(data['response']!['body']!['items']);
                
                // 단지명 매칭 시도
                final matchedCode = _matchComplexName(itemList, complexName);
                if (matchedCode != null) return matchedCode;
                
                // 매칭 실패 시 첫 번째 결과 반환
                if (itemList.isNotEmpty) {
                  return itemList[0]['kaptCode']?.toString() ?? '';
                }
              }
            }
          } catch (e) {
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
            return kaptCode;
          }
        }
      }
    }
    
    return null;
  }
}
