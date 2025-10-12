import '../constants/app_constants.dart';

class AddressParser {
  // 1차 주소 파싱: 시/도, 시군구, 도로명, 건물번호
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

  // 2차 상세주소 파싱: 동/호
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
} 