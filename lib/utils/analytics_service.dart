import 'package:firebase_analytics/firebase_analytics.dart';
import 'analytics_events.dart';

/// Firebase Analytics 기반 분석 서비스.
/// 기존 Firestore 직접 저장 방식에서 Firebase Analytics로 전환.
/// - Firestore 쓰기 할당량 절약
/// - 자동 화면 추적, 사용자 속성, 이벤트 분석 제공
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// 사용자 ID 설정 (로그인 시 호출)
  Future<void> setUserId(String? userId) async {
    await _analytics.setUserId(id: userId);
  }

  /// 사용자 속성 설정 (역할 등)
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {
    await _analytics.setUserProperty(name: name, value: value);
  }

  /// 커스텀 이벤트 로깅
  Future<void> logEvent(
    String name, {
    Map<String, dynamic>? params,
    String? userId,
    String? userName,
    FunnelStage? stage,
  }) async {
    try {
      final sanitizedParams = _sanitizeParams(params ?? const {});

      // Firebase Analytics에 이벤트 전송
      await _analytics.logEvent(
        name: _sanitizeEventName(name),
        parameters: {
          ...sanitizedParams,
          if (userName != null) 'user_name': userName,
          if (stage != null) 'funnel_stage': stage.key,
        },
      );
    } catch (_) {
      // 분석 실패는 앱 동작에 영향 없음
    }
  }

  /// 화면 조회 로깅
  Future<void> logScreenView(String screenName, {String? screenClass}) async {
    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass,
      );
    } catch (_) {
      // 실패 무시
    }
  }

  /// Firebase Analytics 이벤트 이름 규칙에 맞게 변환
  /// - 영문 소문자, 숫자, 밑줄만 허용
  /// - 최대 40자
  String _sanitizeEventName(String name) {
    final sanitized = name
        .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')
        .toLowerCase();
    return sanitized.length > 40 ? sanitized.substring(0, 40) : sanitized;
  }

  /// 파라미터 값을 Firebase Analytics 호환 타입으로 변환
  Map<String, Object> _sanitizeParams(Map<String, dynamic> source) {
    final Map<String, Object> result = {};
    source.forEach((key, value) {
      if (value == null) return;
      // Firebase Analytics는 String, int, double만 지원
      if (value is String) {
        // 문자열 파라미터는 최대 100자
        result[key] = value.length > 100 ? value.substring(0, 100) : value;
      } else if (value is int || value is double) {
        result[key] = value;
      } else if (value is bool) {
        result[key] = value ? 1 : 0;
      } else if (value is DateTime) {
        result[key] = value.toIso8601String();
      } else {
        result[key] = value.toString();
      }
    });
    return result;
  }
}
