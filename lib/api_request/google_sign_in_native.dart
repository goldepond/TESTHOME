// 네이티브(모바일/데스크톱) Google Sign-In 서비스
// 모바일: 실제 google_sign_in 사용
// 데스크톱: 런타임에 지원 불가 반환
import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:property/utils/logger.dart';

/// Google Sign-In 처리 클래스 - 네이티브 플랫폼용
class GoogleSignInService {
  // serverClientId: google-services.json의 client_type: 3 (Web) OAuth 클라이언트 ID
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '1018586798653-nr1i1kl3eejtjmpebfiol2bkfd83ulmj.apps.googleusercontent.com',
    scopes: ['email', 'profile'],
  );

  /// Google Sign-In 수행
  /// 성공 시 Firebase UserCredential 반환, 실패/취소 시 null 반환
  static Future<UserCredential?> signIn() async {
    // 데스크톱에서는 지원하지 않음
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      Logger.warning('Google 로그인은 데스크톱에서 지원되지 않습니다.');
      return null;
    }

    try {
      Logger.info('[GoogleSignIn] 로그인 시작');

      // 계정 선택 UI 표시 (silent 로그인 생략 - 로그아웃 후 재로그인 시 충돌 방지)
      Logger.info('[GoogleSignIn] 계정 선택 UI 표시');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      Logger.info('[GoogleSignIn] googleUser: ${googleUser?.email ?? "null"}');

      if (googleUser == null) {
        Logger.info('[GoogleSignIn] 사용자가 로그인 취소');
        return null;
      }

      // Google 인증 정보 가져오기
      Logger.info('[GoogleSignIn] 인증 정보 가져오는 중...');
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      Logger.info('[GoogleSignIn] accessToken: ${googleAuth.accessToken != null ? "있음" : "없음"}');
      Logger.info('[GoogleSignIn] idToken: ${googleAuth.idToken != null ? "있음" : "없음"}');

      if (googleAuth.idToken == null) {
        Logger.error('[GoogleSignIn] idToken이 null - 재시도 필요');
        await _googleSignIn.signOut();
        throw Exception('Google 인증 토큰을 가져오지 못했습니다. 다시 시도해 주세요.');
      }

      // Firebase credential 생성
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Firebase에 로그인
      Logger.info('[GoogleSignIn] Firebase 로그인 시도...');
      final result = await FirebaseAuth.instance.signInWithCredential(credential);
      Logger.info('[GoogleSignIn] Firebase 로그인 성공: ${result.user?.uid}');
      return result;
    } catch (e, stackTrace) {
      Logger.error('[GoogleSignIn] 오류 발생: $e');
      Logger.error('[GoogleSignIn] 스택: $stackTrace');
      rethrow;
    }
  }

  /// Google 계정 정보 가져오기
  static Future<GoogleSignInAccount?> getCurrentUser() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return null;
    }
    return _googleSignIn.currentUser;
  }

  /// Google 로그아웃
  static Future<void> signOut() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return;
    }
    await _googleSignIn.signOut();
    Logger.info('Google 로그아웃 완료');
  }

  /// 다른 계정으로 로그인 (기존 세션 클리어 후 계정 선택 UI 강제 표시)
  static Future<UserCredential?> signInWithNewAccount() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      Logger.warning('Google 로그인은 데스크톱에서 지원되지 않습니다.');
      return null;
    }

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
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return false;
    }
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return false;

      await _googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return false;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await currentUser.reauthenticateWithCredential(credential);
      return true;
    } catch (e) {
      Logger.error('[GoogleSignIn] 재인증 오류: $e');
      return false;
    }
  }

  /// 플랫폼 지원 여부
  static bool get isSupported {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return false;
    }
    return true; // Android, iOS
  }
}
