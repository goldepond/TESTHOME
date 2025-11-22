/// 가격/면적 등 파싱 유틸리티
class QuoteUtils {
  /// 가격 문자열에서 숫자 추출 (예: "12억 5천" -> 1250000000)
  static int? extractPrice(String? priceStr) {
    if (priceStr == null || priceStr.isEmpty) return null;
    
    // "2억 5천만원", "250000000", "2.5억" 등 다양한 형식 처리
    final cleanStr = priceStr.replaceAll(RegExp(r'[^0-9억천만원\.]'), '');
    
    // "억" 처리
    if (cleanStr.contains('억')) {
      final parts = cleanStr.split('억');
      double? eok = double.tryParse(parts[0].replaceAll(RegExp(r'[^0-9\.]'), ''));
      if (eok == null) return null;
      
      int total = (eok * 100000000).toInt();
      
      // "천만", "만" 처리
      if (parts.length > 1) {
        final remainder = parts[1].replaceAll(RegExp(r'[^0-9]'), '');
        if (remainder.isNotEmpty) {
          final remainderInt = int.tryParse(remainder);
          if (remainderInt != null) {
            // "천만" 또는 "만" 구분
            if (parts[1].contains('천만')) {
              total += remainderInt * 10000000;
            } else if (parts[1].contains('만')) {
              total += remainderInt * 10000;
            } else {
              // 숫자만 있으면 만원 단위로 가정
              total += remainderInt * 10000;
            }
          }
        }
      }
      
      return total;
    }
    
    // 숫자만 있는 경우
    final digits = cleanStr.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits);
  }

  /// 면적 문자열에서 숫자만 추출 (예: "84㎡" -> 84.0)
  static double? extractArea(String? areaStr) {
    if (areaStr == null || areaStr.isEmpty) return null;
    return double.tryParse(areaStr.replaceAll(RegExp(r'[^0-9\.]'), ''));
  }
}

