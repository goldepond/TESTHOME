import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'analytics_events.dart';

/// 간단한 퍼널/행동 로그 저장용 서비스.
///
/// Firebase Analytics 같은 외부 의존성 대신 Firestore 컬렉션(`analyticsEvents`)
/// 에 이벤트를 적재해 MVP 단계에서 사용자 흐름을 추적할 수 있게 한다.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> logEvent(
    String name, {
    Map<String, dynamic>? params,
    String? userId,
    String? userName,
    FunnelStage? stage,
  }) async {
    try {
      final sanitizedParams = _sanitizeParams(params ?? const {});
      final platform = defaultTargetPlatform.toString().split('.').last.toLowerCase();

      await _firestore.collection('analyticsEvents').add({
        'name': name,
        'params': sanitizedParams,
        'userId': userId,
        'userName': userName,
        'platform': platform,
        'environment': kReleaseMode ? 'release' : 'debug',
        if (stage != null) 'funnelStage': stage.key,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // MVP 단계에서는 실패를 무시하고 앱 흐름에 영향을 주지 않는다.
    }
  }

  Map<String, dynamic> _sanitizeParams(Map<String, dynamic> source) {
    final Map<String, dynamic> result = {};
    source.forEach((key, value) {
      if (value == null) {
        return;
      }
      if (value is DateTime) {
        result[key] = value.toIso8601String();
      } else if (value is num || value is String || value is bool) {
        result[key] = value;
      } else if (value is Map<String, dynamic>) {
        result[key] = _sanitizeParams(value);
      } else if (value is Iterable) {
        result[key] = value
            .map((item) => item is DateTime ? item.toIso8601String() : item.toString())
            .toList();
      } else {
        result[key] = value.toString();
      }
    });
    return result;
  }
}

