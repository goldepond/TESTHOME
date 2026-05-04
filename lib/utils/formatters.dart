/// 가격 및 날짜/시간 포맷팅 유틸리티
///
/// 프로젝트 전반에서 중복으로 구현되던 _formatPrice, _formatTimeAgo 등을
/// 단일 구현으로 통합합니다.
library;

class PriceFormatter {
  /// 만원 단위의 숫자를 읽기 쉬운 한국식 표현으로 변환합니다.
  ///
  /// - null → '가격 미정'
  /// - 10000만원 이상 → '$uk억 $remainder만원' 또는 '$uk억'
  /// - 미만 → '$priceInMan만원'
  static String format(double? price) {
    if (price == null) return '가격 미정';
    final priceInMan = price.round();
    if (priceInMan >= 10000) {
      final uk = priceInMan ~/ 10000;
      final remainder = priceInMan % 10000;
      if (remainder > 0) return '$uk억 $remainder만원';
      return '$uk억';
    }
    return '$priceInMan만원';
  }

  /// 문자열로 전달된 만원 단위 숫자를 한국식 표현으로 변환합니다.
  ///
  /// 파싱 실패 또는 0 이하이면 빈 문자열을 반환합니다.
  static String formatFromText(String priceText) {
    final number = int.tryParse(priceText);
    if (number == null || number <= 0) return '';
    if (number >= 10000) {
      final uk = number ~/ 10000;
      final remainder = number % 10000;
      if (remainder > 0) return '$uk억 $remainder만원';
      return '$uk억';
    }
    return '$number만원';
  }
}

class DateTimeFormatter {
  /// 과거 시점으로부터 경과한 시간을 상대적 표현으로 반환합니다.
  ///
  /// - 1분 미만 → '방금'
  /// - 1시간 미만 → '$n분 전'
  /// - 24시간 미만 → '$n시간 전'
  /// - 7일 미만 → '$n일 전'
  /// - 이상 → '월/일' 형식
  static String timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${dateTime.month}/${dateTime.day}';
  }

  /// 절대 시각을 한국어 자연어로 반환합니다.
  ///
  /// 예: '4월 12일 오후 2시' / '12월 1일 오전 9시 30분'
  /// - 분이 0이면 분 부분 생략
  /// - 12시간제 + 오전/오후
  /// - 80세 노인 화법 (copy-deck §1.1) — 콜론·24시간제 노출 0
  static String koreanAbsolute(DateTime dateTime) {
    final int hour24 = dateTime.hour;
    final String period = hour24 < 12 ? '오전' : '오후';
    int hour12 = hour24 % 12;
    if (hour12 == 0) hour12 = 12;
    final String minutePart =
        dateTime.minute == 0 ? '' : ' ${dateTime.minute}분';
    return '${dateTime.month}월 ${dateTime.day}일 $period $hour12시$minutePart';
  }
}
