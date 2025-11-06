import 'dart:convert';
import 'package:http/http.dart' as http;

/// 공인중개사 등록번호 검증 결과
class BrokerValidationResult {
  final bool isValid;
  final String? errorMessage;
  final SeoulBrokerInfo? brokerInfo;

  BrokerValidationResult({
    required this.isValid,
    this.errorMessage,
    this.brokerInfo,
  });

  factory BrokerValidationResult.success(SeoulBrokerInfo info) {
    return BrokerValidationResult(
      isValid: true,
      brokerInfo: info,
    );
  }

  factory BrokerValidationResult.failure(String message) {
    return BrokerValidationResult(
      isValid: false,
      errorMessage: message,
    );
  }
}

/// 서울시 부동산 중개업소 정보 API 서비스
class SeoulBrokerService {
  static const String _apiKey = '516b44654c676f6c313036564f4c4d66';
  static const String _baseUrl = 'http://openapi.seoul.go.kr:8088';
  
  /// 공인중개사 등록번호 및 대표자명 검증
  /// 
  /// [registrationNumber] 중개업 등록번호 (예: "11230-2022-00144")
  /// [ownerName] 대표자명 (중개업자명)
  /// 
  /// 반환: BrokerValidationResult
  /// - isValid: true면 검증 성공
  /// - brokerInfo: 검증된 중개사 정보
  /// - errorMessage: 검증 실패 시 오류 메시지
  static Future<BrokerValidationResult> validateBroker({
    required String registrationNumber,
    required String ownerName,
  }) async {
    try {
      // 입력값 검증
      if (registrationNumber.isEmpty || registrationNumber.trim().isEmpty) {
        return BrokerValidationResult.failure('등록번호를 입력해주세요.');
      }

      if (ownerName.isEmpty || ownerName.trim().isEmpty) {
        return BrokerValidationResult.failure('대표자명을 입력해주세요.');
      }

      // 등록번호 정규화
      final normalizedRegNo = _normalizeRegistrationNumber(registrationNumber);
      final normalizedOwnerName = ownerName.trim();

      // 서울시 API로 조회
      final seoulBroker = await getBrokerDetailByRegistrationNumber(normalizedRegNo);

      if (seoulBroker != null) {
        // 대표자명 비교 (부분 일치 허용 - 공백, 특수문자 무시)
        final seoulOwnerName = seoulBroker.ownerName.trim();
        if (_compareNames(normalizedOwnerName, seoulOwnerName)) {
          return BrokerValidationResult.success(seoulBroker);
        } else {
          return BrokerValidationResult.failure(
            '등록번호와 대표자명이 일치하지 않습니다.\n'
            '등록된 대표자명: $seoulOwnerName',
          );
        }
      }

      return BrokerValidationResult.failure(
        '입력하신 등록번호로 등록된 공인중개사를 찾을 수 없습니다.\n'
        '등록번호와 대표자명을 다시 확인해주세요.\n\n'
        '※ 현재는 서울시 소재 공인중개사만 검증 가능합니다.',
      );
    } catch (e) {
      return BrokerValidationResult.failure(
        '검증 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.',
      );
    }
  }

  /// 등록번호 정규화
  /// 예: "11230-2022-00144" → "11230-2022-00144"
  ///     "11230 2022 00144" → "11230-2022-00144"
  static String _normalizeRegistrationNumber(String regNo) {
    // 공백 제거
    var normalized = regNo.trim().replaceAll(RegExp(r'\s+'), '');
    
    // 하이픈이 없으면 형식에 맞게 추가
    // 형식: "XXXXX-YYYY-ZZZZZ"
    if (!normalized.contains('-')) {
      // 숫자만 추출
      final digits = normalized.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length >= 10) {
        // 5-4-5 형식으로 변환
        normalized = '${digits.substring(0, 5)}-${digits.substring(5, 9)}-${digits.substring(9)}';
      }
    }
    
    return normalized;
  }

  /// 이름 비교 (부분 일치 허용)
  /// 공백, 특수문자, 한글 자음/모음 변형 무시
  static bool _compareNames(String name1, String name2) {
    // 정규화: 공백, 특수문자 제거, 소문자 변환
    final n1 = name1
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[^\w가-힣]'), '')
        .toLowerCase();
    final n2 = name2
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[^\w가-힣]'), '')
        .toLowerCase();

    // 완전 일치
    if (n1 == n2) return true;

    // 부분 일치 (한쪽이 다른 쪽을 포함)
    if (n1.contains(n2) || n2.contains(n1)) return true;

    // 한글 자음/모음 변형 무시 (기본적인 레벨)
    final n1Normalized = _normalizeKoreanName(n1);
    final n2Normalized = _normalizeKoreanName(n2);

    return n1Normalized == n2Normalized;
  }

  /// 한글 이름 정규화 (기본)
  static String _normalizeKoreanName(String name) {
    // 공백 제거, 특수문자 제거만 수행
    return name.replaceAll(RegExp(r'\s+'), '').replaceAll(RegExp(r'[^\w가-힣]'), '');
  }
  
  /// 서울시 중개업소 상세 정보 조회
  /// 
  /// [registrationNumber] 중개업 등록번호 (예: "11230-2022-00144")
  static Future<SeoulBrokerInfo?> getBrokerDetailByRegistrationNumber(
    String registrationNumber,
  ) async {
    if (registrationNumber.isEmpty || registrationNumber == '-') {
      return null;
    }

    try {
      // 전체 데이터를 가져와서 등록번호로 필터링
      // 참고: 실제로는 대량 데이터이므로 캐싱 전략 필요
      final uri = Uri.parse('$_baseUrl/$_apiKey/json/landBizInfo/1/1000/');
      
      
      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('API 타임아웃'),
      );
      
      if (response.statusCode == 200) {
        final jsonText = utf8.decode(response.bodyBytes);
        final data = json.decode(jsonText);
        
        // 응답 검증
        final result = data['landBizInfo']?['RESULT'];
        if (result != null && result['CODE'] != 'INFO-000') {
          return null;
        }
        
        final List<dynamic> rows = data['landBizInfo']?['row'] ?? [];
        
        // 등록번호로 매칭
        for (final row in rows) {
          final regNo = row['REST_BRKR_INFO']?.toString() ?? '';
          if (regNo == registrationNumber) {
            return SeoulBrokerInfo.fromJson(row);
          }
        }
        
        return null;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }
  
  /// 주소 기반 중개업소 정보 조회 (등록번호가 일치하지 않으므로)
  /// 
  /// [brokerAddresses] 중개업소 주소 목록 (도로명주소, 지번주소)
  static Future<Map<String, SeoulBrokerInfo>> getBrokersDetailByAddress(
    List<BrokerAddressInfo> brokerAddresses,
  ) async {
    final result = <String, SeoulBrokerInfo>{};
    
    if (brokerAddresses.isEmpty) {
      return result;
    }

    try {
      
      List<dynamic> allRows = [];
      int currentPage = 1;
      const int pageSize = 1000;
      
      // 최대 5번까지 페이징 (5000개) - 성능 최적화
      // 대부분의 중개사는 앞쪽 페이지에 있으므로 5페이지면 충분
      // (필요시 더 늘릴 수 있음, 하지만 속도 저하)
      for (int i = 0; i < 5; i++) {
        final startIndex = (currentPage - 1) * pageSize + 1;
        final endIndex = currentPage * pageSize;
        
        if (currentPage <= 3 || currentPage % 5 == 0) {
        }
        
        final uri = Uri.parse('$_baseUrl/$_apiKey/json/landBizInfo/$startIndex/$endIndex/');
        
        final response = await http.get(uri).timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw Exception('API 타임아웃'),
        );
        
        if (response.statusCode != 200) {
          break;
        }
        
        final jsonText = utf8.decode(response.bodyBytes);
        final data = json.decode(jsonText);
        
        // 응답 검증
        final apiResult = data['landBizInfo']?['RESULT'];
        if (apiResult != null && apiResult['CODE'] != 'INFO-000') {
          break;
        }
        
        final List<dynamic> rows = data['landBizInfo']?['row'] ?? [];
        
        if (currentPage <= 3 || currentPage % 5 == 0) {
        }
        
        if (rows.isEmpty) break;
        
        allRows.addAll(rows);
        
        // 주소 기반 매칭 시도
        int tempMatchCount = 0;
        for (final row in rows) {
          final seoulAddr = row['ADDR']?.toString() ?? '';
          final seoulBusinessName = row['BZMN_CONM']?.toString() ?? '';
          
          // 각 VWorld 중개업소와 비교
          for (final brokerAddr in brokerAddresses) {
            // 이미 매칭된 경우 스킵
            if (result.containsKey(brokerAddr.key)) continue;
            
            // 주소 매칭 (도로명주소 또는 지번주소)
            bool addressMatch = _isSimilarAddress(seoulAddr, brokerAddr.roadAddress) ||
                                _isSimilarAddress(seoulAddr, brokerAddr.jibunAddress);
            
            // 상호명도 비슷한지 확인 (선택적)
            bool nameMatch = _isSimilarName(seoulBusinessName, brokerAddr.name);
            
            if (addressMatch || (nameMatch && seoulAddr.contains('광진구'))) {
              final info = SeoulBrokerInfo.fromJson(row);
              result[brokerAddr.key] = info;
              tempMatchCount++;
              
              // 매칭 발견 시 간단히 로그 (첫 3개만)
              if (tempMatchCount <= 3) {
              }
              break; // 매칭되면 다음 row로
            }
          }
        }
        
        if (tempMatchCount > 0 || currentPage <= 3) {
        }
        
        // 조기 종료 조건
        // 1. 모든 중개업소를 찾았거나
        // 2. 마지막 페이지거나
        // 3. 절반 이상 매칭되고 3페이지 이상 조회했으면
        final halfMatched = result.length >= (brokerAddresses.length / 2);
        if (result.length >= brokerAddresses.length || 
            rows.length < pageSize ||
            (halfMatched && currentPage >= 3)) {
          if (halfMatched && currentPage >= 3) {
          }
          break;
        }
        
        currentPage++;
      }
    } catch (_) {
      // 서울시 API 호출 실패 시 빈 리스트 반환
    }
    
    return result;
  }
  
  /// 주소 유사도 비교 (간단한 부분 문자열 매칭)
  static bool _isSimilarAddress(String addr1, String addr2) {
    if (addr1.isEmpty || addr2.isEmpty) return false;
    
    // 공백, 특수문자 제거 후 비교
    final clean1 = addr1.replaceAll(RegExp(r'[\s\-,()]'), '').toLowerCase();
    final clean2 = addr2.replaceAll(RegExp(r'[\s\-,()]'), '').toLowerCase();
    
    // 도로명주소의 핵심 부분 추출 (구 + 도로명 + 번호)
    // 예: "서울특별시 광진구 자양로23길 86" → "광진구자양로23길86"
    String extractCore(String addr) {
      final match = RegExp(r'([가-힣]+구)\s*([가-힣0-9]+[로길])\s*(\d+)').firstMatch(addr);
      if (match != null) {
        return '${match.group(1)}${match.group(2)}${match.group(3)}'.replaceAll(' ', '');
      }
      return addr;
    }
    
    final core1 = extractCore(clean1);
    final core2 = extractCore(clean2);
    
    // 핵심 부분이 일치하면 매칭
    if (core1 == core2) return true;
    
    // 또는 한쪽이 다른 쪽을 포함하면 매칭
    return clean1.contains(clean2) || clean2.contains(clean1);
  }
  
  /// 상호명 유사도 비교
  static bool _isSimilarName(String name1, String name2) {
    if (name1.isEmpty || name2.isEmpty) return false;
    
    // 공백 제거 후 비교
    final clean1 = name1.replaceAll(' ', '').toLowerCase();
    final clean2 = name2.replaceAll(' ', '').toLowerCase();
    
    // 한쪽이 다른 쪽을 포함하면 매칭
    return clean1.contains(clean2) || clean2.contains(clean1);
  }
}

/// VWorld 중개업소 주소 정보 (매칭용)
class BrokerAddressInfo {
  final String key;              // 고유 식별자 (인덱스 등)
  final String name;             // 상호명
  final String roadAddress;      // 도로명주소
  final String jibunAddress;     // 지번주소
  
  BrokerAddressInfo({
    required this.key,
    required this.name,
    required this.roadAddress,
    required this.jibunAddress,
  });
}

/// 서울시 중개업소 상세 정보 모델 (전체 21개 필드)
class SeoulBrokerInfo {
  // 기본 정보
  final String systemRegNo;          // SYS_REG_NO - 시스템등록번호
  final String registrationNumber;   // REST_BRKR_INFO - 중개업등록번호
  final String ownerName;             // MDT_BSNS_NM - 중개업자명/대표자
  final String businessName;          // BZMN_CONM - 사업자상호
  final String phoneNumber;           // TELNO - 전화번호
  final String businessStatus;        // STTS_SE - 상태구분 (영업중/휴업)
  
  // 주소 정보
  final String address;               // ADDR - 주소
  final String district;              // CGG_CD - 자치구명
  final String legalDong;             // LGL_DONG_NM - 법정동명
  final String sggCode;               // SGG_CD - 시군구코드
  final String stdgCode;              // STDG_CD - 법정동코드
  final String lotnoSe;               // LOTNO_SE - 지번구분
  final String mno;                   // MNO - 본번
  final String sno;                   // SNO - 부번
  
  // 도로명 정보
  final String roadCode;              // ROAD_CD - 도로명코드
  final String bldg;                  // BLDG - 건물
  final String bmno;                  // BMNO - 건물 본번
  final String bsno;                  // BSNO - 건물 부번
  
  // 기타 정보
  final String penaltyStartDate;      // PBADMS_DSPS_STRT_DD - 행정처분 시작일
  final String penaltyEndDate;        // PBADMS_DSPS_END_DD - 행정처분 종료일
  final String inqCount;              // INQ_CNT - 조회 개수
  
  SeoulBrokerInfo({
    required this.systemRegNo,
    required this.registrationNumber,
    required this.ownerName,
    required this.businessName,
    required this.phoneNumber,
    required this.businessStatus,
    required this.address,
    required this.district,
    required this.legalDong,
    required this.sggCode,
    required this.stdgCode,
    required this.lotnoSe,
    required this.mno,
    required this.sno,
    required this.roadCode,
    required this.bldg,
    required this.bmno,
    required this.bsno,
    required this.penaltyStartDate,
    required this.penaltyEndDate,
    required this.inqCount,
  });
  
  factory SeoulBrokerInfo.fromJson(Map<String, dynamic> json) {
    return SeoulBrokerInfo(
      systemRegNo: json['SYS_REG_NO']?.toString() ?? '',
      registrationNumber: json['REST_BRKR_INFO']?.toString() ?? '',
      ownerName: json['MDT_BSNS_NM']?.toString() ?? '',
      businessName: json['BZMN_CONM']?.toString() ?? '',
      phoneNumber: json['TELNO']?.toString() ?? '',
      businessStatus: json['STTS_SE']?.toString() ?? '',
      address: json['ADDR']?.toString() ?? '',
      district: json['CGG_CD']?.toString() ?? '',
      legalDong: json['LGL_DONG_NM']?.toString() ?? '',
      sggCode: json['SGG_CD']?.toString() ?? '',
      stdgCode: json['STDG_CD']?.toString() ?? '',
      lotnoSe: json['LOTNO_SE']?.toString() ?? '',
      mno: json['MNO']?.toString() ?? '',
      sno: json['SNO']?.toString() ?? '',
      roadCode: json['ROAD_CD']?.toString() ?? '',
      bldg: json['BLDG']?.toString() ?? '',
      bmno: json['BMNO']?.toString() ?? '',
      bsno: json['BSNO']?.toString() ?? '',
      penaltyStartDate: json['PBADMS_DSPS_STRT_DD']?.toString() ?? '',
      penaltyEndDate: json['PBADMS_DSPS_END_DD']?.toString() ?? '',
      inqCount: json['INQ_CNT']?.toString() ?? '',
    );
  }
}

