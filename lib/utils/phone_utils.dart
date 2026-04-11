/// 전화번호 검증, 정규화, 포맷팅 유틸리티
class PhoneUtils {
  PhoneUtils._();

  /// 전화번호 유효성 검사
  ///
  /// 유효하면 null, 아니면 에러 메시지 반환.
  /// 한국 휴대전화 번호(01X-XXXX-XXXX, 10~11자리)만 허용.
  static String? validate(String? value) {
    if (value == null || value.isEmpty) {
      return '전화번호를 입력해주세요';
    }
    final digits = normalize(value);
    if (digits.length < 10 || digits.length > 11) {
      return '올바른 전화번호를 입력해주세요';
    }
    if (!digits.startsWith('01')) {
      return '휴대폰 번호를 입력해주세요';
    }
    return null;
  }

  /// 숫자만 추출 (정규화)
  ///
  /// "010-1234-5678" → "01012345678"
  static String normalize(String phone) {
    return phone.replaceAll(RegExp(r'[^0-9]'), '');
  }

  /// 표시용 포맷 (010-XXXX-XXXX)
  ///
  /// 11자리: "010-1234-5678", 10자리: "010-123-4567"
  static String format(String phone) {
    final digits = normalize(phone);
    if (digits.length == 11) {
      return '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7)}';
    }
    if (digits.length == 10) {
      return '${digits.substring(0, 3)}-${digits.substring(3, 6)}-${digits.substring(6)}';
    }
    return phone;
  }
}
