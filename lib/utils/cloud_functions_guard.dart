import 'package:cloud_functions/cloud_functions.dart';
import 'package:property/utils/logger.dart';

/// Cloud Functions callable 호출의 표준 에러 매퍼.
///
/// problem 002 (2026-05-04 functions 대량 미배포) 재발 방지 가드.
///
/// 동작 원칙:
/// - `not-found` / `unavailable` / `unauthenticated` 3종은 사용자 친화 카피로 변환
///   하여 [CloudFunctionsUserFacingException] 으로 다시 throw 한다. 영문 에러 코드를
///   사용자에게 노출하지 않는다 (80세 노인 화법 — copy-deck.md §1.6 §1.4 준수).
/// - 그 외 도메인 에러(`failed-precondition`, `permission-denied`,
///   `invalid-argument`, `cap_exceeded` 같은 backend reason 코드 등) 는 *그대로*
///   re-throw 한다. 호출처의 기존 분기/[GrantMessages.describeReason] 흐름을 보존한다.
///
/// 사용 패턴 (서비스 레이어):
/// ```dart
/// try {
///   final callable = _functions.httpsCallable('issuePriorityGrant');
///   ...
/// } catch (e, stack) {
///   CloudFunctionsGuard.throwAsUserFacing(
///     e, stack, functionName: 'issuePriorityGrant',
///   );
/// }
/// ```
///
/// UI 레이어는 [CloudFunctionsUserFacingException] 을 잡아 `e.userMessage` 를
/// SnackBar 등으로 그대로 노출하면 된다. 일반 [FirebaseFunctionsException] 분기와
/// 공존 가능 — 도메인 에러 처리는 평소대로 작성한다.
class CloudFunctionsGuard {
  CloudFunctionsGuard._();

  /// 사용자에게 그대로 노출 가능한 한국어 카피.
  /// copy-deck.md §1.4 / §1.6 — 한 줄 / 행동 지시 / 외래어 0 / 사유 코드 0.
  ///
  /// `String`을 반환하는 호출처(예: `FirebaseService.deleteUserAccount`)에서도
  /// 동일한 카피를 사용하기 위해 외부 노출한다 — 변형 금지.
  static const String msgNotFound = '잠시 점검 중입니다. 1~2분 뒤 다시 눌러 주세요.';
  static const String msgUnavailable = '지금은 연결이 어렵습니다. 잠시 뒤 다시 시도해 주세요.';
  static const String msgUnauthenticated = '다시 로그인이 필요합니다.';

  /// callable 호출 catch 블록의 표준 통과로(passthrough). 항상 throw 로 종료한다.
  ///
  /// [functionName] 은 로그/모니터링 식별용 — 실제 callable 이름과 일치시킨다.
  static Never throwAsUserFacing(
    Object error,
    StackTrace stack, {
    required String functionName,
  }) {
    if (error is FirebaseFunctionsException) {
      final String code = error.code;

      if (code == 'not-found') {
        Logger.error(
          '[Functions NOT_FOUND] $functionName 미배포 의심',
          error: error,
          stackTrace: stack,
          context: 'CloudFunctionsGuard',
          metadata: <String, dynamic>{
            'functionName': functionName,
            'severity': 'CRITICAL',
            'firebaseCode': code,
            'firebaseMessage': error.message,
          },
        );
        throw CloudFunctionsUserFacingException(
          userMessage: msgNotFound,
          functionName: functionName,
          firebaseCode: code,
          cause: error,
          stack: stack,
        );
      }

      if (code == 'unavailable' || code == 'deadline-exceeded') {
        Logger.warning(
          '[Functions UNAVAILABLE] $functionName 응답 없음',
          metadata: <String, dynamic>{
            'functionName': functionName,
            'firebaseCode': code,
            'firebaseMessage': error.message,
          },
        );
        throw CloudFunctionsUserFacingException(
          userMessage: msgUnavailable,
          functionName: functionName,
          firebaseCode: code,
          cause: error,
          stack: stack,
        );
      }

      if (code == 'unauthenticated') {
        Logger.warning(
          '[Functions UNAUTHENTICATED] $functionName 인증 만료',
          metadata: <String, dynamic>{
            'functionName': functionName,
            'firebaseCode': code,
          },
        );
        throw CloudFunctionsUserFacingException(
          userMessage: msgUnauthenticated,
          functionName: functionName,
          firebaseCode: code,
          cause: error,
          stack: stack,
        );
      }
    }

    // 도메인 에러 / 그 외 — 그대로 통과 (호출처의 분기 보존).
    throw error;
  }
}

/// 가드가 사용자에게 그대로 노출 가능한 형태로 변환한 예외.
///
/// UI 레이어는 다음과 같이 처리한다:
/// ```dart
/// } on CloudFunctionsUserFacingException catch (e) {
///   ScaffoldMessenger.of(context).showSnackBar(
///     SnackBar(content: Text(e.userMessage)),
///   );
/// }
/// ```
class CloudFunctionsUserFacingException implements Exception {
  CloudFunctionsUserFacingException({
    required this.userMessage,
    required this.functionName,
    required this.firebaseCode,
    required this.cause,
    required this.stack,
  });

  /// 사용자에게 그대로 노출 가능한 한국어 카피 (80세 노인 통과).
  final String userMessage;

  /// 원인이 된 callable 이름 — 로그/디버그용.
  final String functionName;

  /// 원본 Firebase 에러 코드 (`not-found` / `unavailable` / `unauthenticated`).
  /// 사용자 노출 절대 금지 — 디버그/Sentry 메타데이터 전용.
  final String firebaseCode;

  /// 원본 예외 — 추가 디버그 필요 시 참조.
  final Object cause;

  /// 원본 스택 트레이스.
  final StackTrace stack;

  @override
  String toString() => userMessage;
}
