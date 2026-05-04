import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:property/models/platform_metric.dart';
import 'package:property/models/priority_appeal.dart';
import 'package:property/utils/cloud_functions_guard.dart';
import 'package:property/utils/logger.dart';

/// 관리자 전용 우선권/이의제기 서비스 (Task 06).
///
/// 일반 사용자/중개사용 [PriorityGrantService]와 분리. callable 호출과
/// 관리자 전용 컬렉션 read-only watch를 담당한다. 모든 변경 액션은
/// `resolveAppeal`/`replayDecision` callable 경유 — 컬렉션 직접 update/delete 금지.
class AdminPriorityService {
  AdminPriorityService();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Cloud Functions 리전은 functions/index.js의 onCall 설정과 일치.
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  static const String _appealsCollection = 'priority_appeals';
  static const String _metricsCollection = 'platform_metrics';
  static const String _algorithmConfigCollection = 'algorithm_config';
  static const String _auditLogsCollection = 'priority_audit_logs';

  // ----------------- 이의 제기 watch -----------------

  /// 모든 이의 제기 (관리자 전용) — status 필터 가능, createdAt DESC 정렬.
  Stream<List<PriorityAppeal>> watchAllAppeals({AppealStatus? statusFilter}) {
    Query<Map<String, dynamic>> query = _firestore.collection(_appealsCollection);
    if (statusFilter != null) {
      query = query.where('status', isEqualTo: statusFilter.name);
    }
    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PriorityAppeal.fromFirestore(doc))
              .toList(),
        )
        .handleError((Object error, StackTrace stack) {
          Logger.error(
            'watchAllAppeals stream error',
            error: error,
            stackTrace: stack,
            context: 'AdminPriorityService',
            metadata: {'statusFilter': statusFilter?.name},
          );
        });
  }

  /// 단일 이의 제기 watch (replayedDecision 갱신 실시간 반영).
  Stream<PriorityAppeal?> watchAppeal(String appealId) {
    return _firestore
        .collection(_appealsCollection)
        .doc(appealId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          return PriorityAppeal.fromFirestore(doc);
        })
        .handleError((Object error, StackTrace stack) {
          Logger.error(
            'watchAppeal stream error',
            error: error,
            stackTrace: stack,
            context: 'AdminPriorityService',
            metadata: {'appealId': appealId},
          );
        });
  }

  // ----------------- callable 처리 -----------------

  /// `resolveAppeal` callable 호출.
  ///
  /// [decision]은 'resolved'(인용) 또는 'rejected'(기각).
  /// [resolution]은 1~1000자 처리 사유.
  ///
  /// 실패 시 [FirebaseFunctionsException]을 그대로 throw — 호출처에서
  /// `code`/`message` 기반 한국어 매핑한다.
  Future<void> resolveAppeal({
    required String appealId,
    required String decision,
    required String resolution,
  }) async {
    try {
      if (decision != 'resolved' && decision != 'rejected') {
        throw ArgumentError(
          "decision은 'resolved' 또는 'rejected'만 허용된다",
        );
      }
      if (resolution.isEmpty || resolution.length > 1000) {
        throw ArgumentError('resolution은 1~1000자 범위여야 한다');
      }

      final callable = _functions.httpsCallable('resolveAppeal');
      await callable.call<Map<dynamic, dynamic>>({
        'appealId': appealId,
        'decision': decision,
        'resolution': resolution,
      });

      Logger.info(
        'resolveAppeal succeeded',
        metadata: {'appealId': appealId, 'decision': decision},
      );
    } on FirebaseFunctionsException catch (e, stack) {
      Logger.error(
        'resolveAppeal callable failed',
        error: e,
        stackTrace: stack,
        context: 'AdminPriorityService',
        metadata: {
          'appealId': appealId,
          'decision': decision,
          'code': e.code,
          'message': e.message,
        },
      );
      // problem 002 가드 — NOT_FOUND/UNAVAILABLE/UNAUTHENTICATED 만 변환,
      // 도메인 에러(invalid-argument 등)는 그대로 통과.
      CloudFunctionsGuard.throwAsUserFacing(
        e,
        stack,
        functionName: 'resolveAppeal',
      );
    } catch (e, stack) {
      Logger.error(
        'resolveAppeal failed',
        error: e,
        stackTrace: stack,
        context: 'AdminPriorityService',
        metadata: {'appealId': appealId, 'decision': decision},
      );
      rethrow;
    }
  }

  /// `replayDecision` callable 호출 — 임의 grantId의 점수를 현재 가중치로 재현.
  ///
  /// 반환은 callable 응답 그대로 (grantId/propertyId/brokerId/type/stage/grantedAt/
  /// originalScore/originalWeightsVersion/recomputedScore/recomputedWeightsVersion/
  /// match/divergenceReason/weights/threshold/breakdown/rawInputs).
  Future<Map<String, dynamic>> replayDecision({required String grantId}) async {
    try {
      final callable = _functions.httpsCallable('replayDecision');
      final result = await callable.call<Map<dynamic, dynamic>>({
        'grantId': grantId,
      });
      return Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (e, stack) {
      Logger.error(
        'replayDecision callable failed',
        error: e,
        stackTrace: stack,
        context: 'AdminPriorityService',
        metadata: {
          'grantId': grantId,
          'code': e.code,
          'message': e.message,
        },
      );
      CloudFunctionsGuard.throwAsUserFacing(
        e,
        stack,
        functionName: 'replayDecision',
      );
    } catch (e, stack) {
      Logger.error(
        'replayDecision failed',
        error: e,
        stackTrace: stack,
        context: 'AdminPriorityService',
        metadata: {'grantId': grantId},
      );
      rethrow;
    }
  }

  // ----------------- 점유율 메트릭 -----------------

  /// 일자별 점유율 메트릭 (관리자 전용) — date DESC 정렬, 기본 limit 30.
  Stream<List<PlatformMetric>> watchPlatformMetrics({int limit = 30}) {
    return _firestore
        .collection(_metricsCollection)
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PlatformMetric.fromFirestore(doc))
              .toList(),
        )
        .handleError((Object error, StackTrace stack) {
          Logger.error(
            'watchPlatformMetrics stream error',
            error: error,
            stackTrace: stack,
            context: 'AdminPriorityService',
            metadata: {'limit': limit},
          );
        });
  }

  // ----------------- 알고리즘 설정 -----------------

  /// 활성 알고리즘 설정 (`algorithm_config/active`) read.
  ///
  /// 룰북 일치 검증/감사 화면에서 사용. 문서가 없거나 권한 부족 시 null.
  Future<Map<String, dynamic>?> getActiveAlgorithmConfig() async {
    try {
      final doc = await _firestore
          .collection(_algorithmConfigCollection)
          .doc('active')
          .get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      return Map<String, dynamic>.from(data);
    } catch (e, stack) {
      Logger.error(
        'getActiveAlgorithmConfig failed',
        error: e,
        stackTrace: stack,
        context: 'AdminPriorityService',
      );
      return null;
    }
  }

  // ----------------- audit log 조회 -----------------

  /// 매물별 audit log (`priority_audit_logs` collectionGroup query).
  ///
  /// 관리자는 모든 propertyId 조회 가능. createdAt DESC, 기본 limit 200.
  /// 인덱스 부재 시 Firestore 에러 메시지에 인덱스 생성 링크가 포함된다.
  Future<List<Map<String, dynamic>>> getPropertyAuditLogs(
    String propertyId, {
    int limit = 200,
  }) async {
    try {
      final snapshot = await _firestore
          .collectionGroup(_auditLogsCollection)
          .where('propertyId', isEqualTo: propertyId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['_docId'] = doc.id;
        return data;
      }).toList();
    } catch (e, stack) {
      Logger.error(
        'getPropertyAuditLogs failed',
        error: e,
        stackTrace: stack,
        context: 'AdminPriorityService',
        metadata: {'propertyId': propertyId, 'limit': limit},
      );
      rethrow;
    }
  }
}

/// audit log eventType → 한국어 라벨 매핑.
///
/// 관리자 화면 표기용 (운영자 화면이므로 영문 코드도 함께 노출 OK).
String auditEventLabel(String eventType) {
  switch (eventType) {
    case 'algorithm_config_bootstrapped':
      return '알고리즘 설정 부트스트랩';
    case 'grant_issued':
      return '우선권 발급';
    case 'grant_revoked':
      return '우선권 취소';
    case 'grant_expired':
      return '우선권 만료';
    case 'grant_denied_capacity':
      return '발급 거절 (용량 초과)';
    case 'grant_denied_duplicate':
      return '발급 거절 (중복)';
    case 'grant_denied_eligibility':
      return '발급 거절 (자격 미달)';
    case 'grant_denied_other':
      return '발급 거절 (기타)';
    case 'tiered_release_step':
      return '단계적 공개 진행';
    case 'participation_declared':
      return '참여 선언';
    case 'participation_stage_advanced':
      return '참여 단계 진행';
    case 'participation_stage_rejected':
      return '참여 단계 반려';
    case 'participation_query_seller':
      return '참여 조회 (매도자)';
    case 'participation_query_self':
      return '참여 조회 (본인)';
    case 'participation_count_recomputed':
      return '참여 카운트 재계산';
    case 'appeal_resolved':
      return '이의 제기 인용';
    case 'appeal_rejected':
      return '이의 제기 기각';
    case 'replay_decision':
      return '결정 재현';
    default:
      return eventType;
  }
}

/// `participation_*` eventType만 필터링하는 헬퍼.
bool isParticipationAuditEvent(String eventType) {
  return eventType.startsWith('participation_');
}
