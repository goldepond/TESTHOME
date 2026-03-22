// 모바일/웹용 Google Sign-In 서비스
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import '../utils/logger.dart';

/// Google Sign-In 처리 클래스
class GoogleSignInService {
  // serverClientId: google-services.json의 client_type: 3 (Web) OAuth 클라이언트 ID
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '1018586798653-nr1i1kl3eejtjmpebfiol2bkfd83ulmj.apps.googleusercontent.com',
    scopes: ['email', 'profile'],
  );

  /// Google Sign-In 수행
  /// 성공 시 Firebase UserCredential 반환, 실패/취소 시 null 반환
  static Future<UserCredential?> signIn() async {
    try {
      GoogleSignInAccount? googleUser;

      // 웹에서는 signInSilently가 FedCM 이슈로 항상 타임아웃되므로 건너뜀
      if (!kIsWeb) {
        // 모바일: 먼저 이미 로그인된 계정이 있는지 확인 (silent sign-in)
        try {
          googleUser = await _googleSignIn.signInSilently()
              .timeout(const Duration(seconds: 3));
        } catch (e) {
          googleUser = null;
        }
      }

      // silent 로그인 실패시 계정 선택 UI 표시
      if (googleUser == null) {
        try {
          googleUser = await _googleSignIn.signIn()
              .timeout(const Duration(seconds: 60)); // 사용자 선택 대기 (최대 60초)
        } catch (e) {
          return null;
        }
      }

      if (googleUser == null) {
        return null;
      }

      // Google 인증 정보 가져오기 (타임아웃 10초)
      final GoogleSignInAuthentication googleAuth;
      try {
        googleAuth = await googleUser.authentication
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        return null;
      }

      // Firebase credential 생성
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Firebase에 로그인 (타임아웃 15초)
      try {
        final result = await FirebaseAuth.instance.signInWithCredential(credential)
            .timeout(const Duration(seconds: 15));
        return result;
      } catch (e) {
        return null;
      }
    } catch (e, stackTrace) {
      Logger.error('Google 로그인 오류', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Google 계정 정보 가져오기
  static Future<GoogleSignInAccount?> getCurrentUser() async {
    return _googleSignIn.currentUser;
  }

  /// Google 로그아웃
  static Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  /// 다른 계정으로 로그인 (기존 세션 클리어 후 계정 선택 UI 강제 표시)
  static Future<UserCredential?> signInWithNewAccount() async {
    try {
      Logger.info('[GoogleSignIn] 다른 계정으로 로그인 시작');

      // 기존 세션 클리어
      await _googleSignIn.signOut();
      Logger.info('[GoogleSignIn] 기존 세션 클리어 완료');

      // 계정 선택 UI 강제 표시
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      Logger.info('[GoogleSignIn] 선택된 계정: ${googleUser?.email ?? "null"}');

      if (googleUser == null) {
        Logger.info('[GoogleSignIn] 사용자가 계정 선택 취소');
        return null;
      }

      // Google 인증 정보 가져오기
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Firebase credential 생성
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Firebase에 로그인
      final result = await FirebaseAuth.instance.signInWithCredential(credential);
      Logger.info('[GoogleSignIn] 다른 계정 로그인 성공: ${result.user?.uid}');
      return result;
    } catch (e, stackTrace) {
      Logger.error('[GoogleSignIn] 다른 계정 로그인 오류: $e');
      Logger.error('[GoogleSignIn] 스택: $stackTrace');
      rethrow;
    }
  }

  /// 계정 삭제 전 재인증 (requires-recent-login 오류 해결용)
  /// 성공 시 true, 실패/취소 시 false 반환
  static Future<bool> reauthenticate() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return false;

      await _googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn()
          .timeout(const Duration(seconds: 60));
      if (googleUser == null) return false;

      final GoogleSignInAuthentication googleAuth;
      try {
        googleAuth = await googleUser.authentication
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        return false;
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await currentUser.reauthenticateWithCredential(credential);
      return true;
    } catch (e) {
      Logger.error('Google 재인증 오류', error: e);
      return false;
    }
  }

  /// 플랫폼 지원 여부
  static bool get isSupported => true;
}
