/// 입력값 검증 유틸리티 클래스
class ValidationUtils {
  /// 이메일 형식 검증 (일반적인 이메일 형식)
  /// 
  /// [email] 검증할 이메일 주소
  /// Returns true if valid email format
  static bool isValidEmail(String email) {
    if (email.isEmpty) return false;
    // 일반적인 이메일 형식 검증 (user@domain.com)
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  /// 간단한 이메일 형식 검증 (최소한의 형식만 확인)
  /// 
  /// [email] 검증할 이메일 주소
  /// Returns true if valid email format
  static bool isValidEmailSimple(String email) {
    if (email.isEmpty) return false;
    // 간단한 이메일 형식 검증 (@와 . 포함)
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return emailRegex.hasMatch(email);
  }

  /// 비밀번호 길이 검증
  /// 
  /// [password] 검증할 비밀번호
  /// [minLength] 최소 길이 (기본값: 6)
  /// Returns true if password meets minimum length requirement
  static bool isValidPasswordLength(String password, {int minLength = 6}) {
    return password.length >= minLength;
  }

  /// 비밀번호 일치 확인
  /// 
  /// [password] 첫 번째 비밀번호
  /// [confirmPassword] 확인 비밀번호
  /// Returns true if passwords match
  static bool doPasswordsMatch(String password, String confirmPassword) {
    return password == confirmPassword;
  }

  /// 비밀번호 강도 계산
  /// 
  /// [password] 검증할 비밀번호
  /// Returns password strength (0-4)
  /// - 0: 매우 약함
  /// - 1: 약함
  /// - 2: 보통
  /// - 3: 강함
  /// - 4: 매우 강함
  static int getPasswordStrength(String password) {
    if (password.isEmpty) return 0;
    int strength = 0;
    if (password.length >= 8) strength++;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength++;
    if (RegExp(r'[0-9]').hasMatch(password)) strength++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) strength++;
    return strength;
  }

  /// 비밀번호 강도 색상 반환
  static String getPasswordStrengthText(int strength) {
    if (strength <= 1) return '약함';
    if (strength == 2) return '보통';
    if (strength == 3) return '강함';
    return '매우 강함';
  }
}

