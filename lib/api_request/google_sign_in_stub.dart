// Stub 파일 - 데스크톱 빌드용 (Windows/Linux/macOS)
// google_sign_in 패키지가 데스크톱을 지원하지 않아 stub으로 대체

import 'package:firebase_auth/firebase_auth.dart';

/// Google Sign-In Stub - 데스크톱에서는 지원되지 않음
class GoogleSignInService {
  /// Google Sign-In 수행 - 데스크톱에서는 항상 null 반환
  static Future<UserCredential?> signIn() async {
    return null;
  }

  /// Google 계정 정보 - 데스크톱에서는 항상 null
  static Future<dynamic> getCurrentUser() async {
    return null;
  }

  /// Google 로그아웃 - no-op
  static Future<void> signOut() async {}

  /// 다른 계정으로 로그인 - 데스크톱에서는 항상 null 반환
  static Future<UserCredential?> signInWithNewAccount() async {
    return null;
  }

  /// 재인증 - 데스크톱에서는 지원되지 않음
  static Future<bool> reauthenticate() async => false;

  /// 플랫폼 지원 여부 - 데스크톱은 미지원
  static bool get isSupported => false;
}
