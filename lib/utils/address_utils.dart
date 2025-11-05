import 'package:property/constants/app_constants.dart';

class AddressUtils {
  // ========== 주소 파싱 관련 메서드 ==========
  
  /// 1차 주소 파싱: 시/도, 시군구, 도로명, 건물번호
  static Map<String, String> parseAddress1st(String address) {
    for (final entry in RegionConstants.sidoSigunguMap.entries) {
      final sido = entry.key;
      if (address.startsWith(sido)) {
        // 시/도 이후 문자열
        String remain = address.substring(sido.length).trim();
        // 시군구 목록 중 가장 긴(2단계 포함) sigungu를 먼저 찾음
        final sortedSigungu = List<String>.from(entry.value)
          ..sort((a, b) => b.length.compareTo(a.length));
        String? foundSigungu;
        for (final sigungu in sortedSigungu) {
          if (remain.startsWith(sigungu)) {
            foundSigungu = sigungu;
            break;
          }
        }
        if (foundSigungu != null) {
          String roadRemain = remain.substring(foundSigungu.length).trim();
          // 도로명과 건물번호 분리
          // 예: '중앙공원로 54 (서현동, 시범단지우성아파트)'
          final reg = RegExp(r'^(.*?)(\d+)(?=\s|\(|$)');
          final match = reg.firstMatch(roadRemain);
          String roadName = '';
          String buildingNumber = '';
          if (match != null) {
            roadName = match.group(1)?.trim() ?? '';
            buildingNumber = match.group(2) ?? '';
          } else {
            roadName = roadRemain;
          }
          return {
            'sido': sido,
            'sigungu': foundSigungu,
            'roadName': roadName,
            'buildingNumber': buildingNumber,
          };
        } else {
          // 시군구가 없는 시/도(세종특별자치시 등)
          return {
            'sido': sido,
            'sigungu': '',
            'roadName': remain,
            'buildingNumber': '',
          };
        }
      }
    }
    // 매칭 실패 시 fallback
    return {
      'sido': '',
      'sigungu': '',
      'roadName': address,
      'buildingNumber': '',
    };
  }

  /// 2차 상세주소 파싱: 동/호
  static Map<String, String> parseDetailAddress(String detail) {
    String dong = '';
    String ho = '';
    
    // 빈 문자열 체크
    if (detail.trim().isEmpty) {
      return {'dong': '', 'ho': ''};
    }
    
    // "제211동 제15,16층 제1506호" 형식 파싱
    final reg = RegExp(r'제(\d+동)\s*제(\d+,\d+층)?\s*제(\d+호)?');
    final match = reg.firstMatch(detail.trim());
    
    if (match != null) {
      dong = '제${match.group(1)} ${match.group(2) ?? ''}'.trim();
      ho = '제${match.group(3) ?? ''}'.trim();
    } else {
      // 기존 형식도 지원
      final simpleReg = RegExp(r'(\d+동)?\s*(\d+호)?');
      final simpleMatch = simpleReg.firstMatch(detail.trim());
      if (simpleMatch != null) {
        dong = simpleMatch.group(1) ?? '';
        ho = simpleMatch.group(2) ?? '';
      }
    }
    
    return {
      'dong': dong,
      'ho': ho,
    };
  }
  
  // ========== 주소 유틸리티 관련 메서드 ==========
  
  /// 주소에서 시단위를 추출하는 함수
  static String? extractCityFromAddress(String address) {
    if (address.isEmpty) return null;
    
    // 특별시/광역시 패턴
    final specialCities = [
      '서울특별시', '부산광역시', '대구광역시', '인천광역시',
      '광주광역시', '대전광역시', '울산광역시', '세종특별자치시'
    ];
    
    for (String city in specialCities) {
      if (address.contains(city)) {
        return city;
      }
    }
    
    // 도 단위 패턴 (경기도, 강원도 등)
    final provinces = [
      '경기도', '강원도', '경상남도', '경상북도',
      '전라남도', '전라북도', '제주특별자치도', '충청남도', '충청북도'
    ];
    
    for (String province in provinces) {
      if (address.contains(province)) {
        return province;
      }
    }
    
    // 시 단위 패턴 (경기도 고양시, 강원도 춘천시 등)
    final cityPatterns = [
      // 경기도
      '고양시', '과천시', '광명시', '광주시', '구리시', '군포시', '김포시', '남양주시',
      '동두천시', '부천시', '성남시', '수원시', '시흥시', '안산시', '안성시', '안양시',
      '양주시', '여주시', '오산시', '용인시', '의왕시', '의정부시', '이천시', '파주시',
      '평택시', '포천시', '하남시', '화성시',
      
      // 강원도
      '강릉시', '동해시', '삼척시', '속초시', '원주시', '춘천시', '태백시',
      
      // 경상남도
      '거제시', '김해시', '밀양시', '사천시', '양산시', '진주시', '창원시', '통영시',
      
      // 경상북도
      '경산시', '경주시', '구미시', '김천시', '문경시', '상주시', '안동시', '영주시',
      '영천시', '포항시',
      
      // 전라남도
      '광양시', '나주시', '목포시', '순천시', '여수시',
      
      // 전라북도
      '군산시', '김제시', '남원시', '익산시', '전주시', '정읍시',
      
      // 제주특별자치도
      '서귀포시', '제주시',
      
      // 충청남도
      '계룡시', '공주시', '논산시', '당진시', '보령시', '서산시', '아산시', '천안시',
      
      // 충청북도
      '제천시', '청주시', '충주시',
    ];
    
    for (String city in cityPatterns) {
      if (address.contains(city)) {
        return city;
      }
    }
    
    // 매칭되는 시단위가 없으면 null 반환
    return null;
  }
  
  // 지역명을 정규화하는 함수 (필터링 시 사용)
  static String normalizeRegionName(String regionName) {
    // 특별시/광역시는 그대로 반환
    if (regionName.endsWith('특별시') || regionName.endsWith('광역시') || regionName.endsWith('특별자치시')) {
      return regionName;
    }
    
    // 도 단위는 그대로 반환
    if (regionName.endsWith('도')) {
      return regionName;
    }
    
    // 시 단위는 그대로 반환
    if (regionName.endsWith('시')) {
      return regionName;
    }
    
    return regionName;
  }
  
  // 두 지역명이 매칭되는지 확인하는 함수
  static bool isRegionMatch(String? propertyCity, String selectedRegion) {
    if (propertyCity == null || propertyCity.isEmpty) return false;
    
    // 정확히 일치하는 경우
    if (propertyCity == selectedRegion) return true;
    
    // 특별시/광역시의 경우
    if (selectedRegion.endsWith('특별시') || selectedRegion.endsWith('광역시') || selectedRegion.endsWith('특별자치시')) {
      return propertyCity == selectedRegion;
    }
    
    // 시 단위의 경우 (정확히 일치하는 시만)
    if (selectedRegion.endsWith('시')) {
      return propertyCity == selectedRegion;
    }
    
    return false;
  }
}
