import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/mls_property.dart';
import '../utils/logger.dart';
import 'firebase_service.dart';
import 'broker_stats_service.dart';

/// 방문 요청 서비스 (Sub-collection 기반)
///
/// 기존 MLSProperty.visitRequests 리스트 방식에서
/// Sub-collection 방식으로 마이그레이션하기 위한 서비스입니다.
///
/// 구조:
/// mlsProperties/{propertyId}/visitRequests/{requestId}
class VisitRequestService {
  // 싱글톤 패턴
  static final VisitRequestService _instance = VisitRequestService._internal();
  factory VisitRequestService() => _instance;
  VisitRequestService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _propertiesCollection = 'mlsProperties';
  static const String _visitRequestsSubCollection = 'visitRequests';

  // ========== Sub-collection 기반 CRUD ==========

  /// 방문 요청 생성 (Sub-collection)
  Future<VisitRequest> createVisitRequest({
    required String propertyId,
    required String brokerId,
    required String brokerName,
    required double proposedPrice,
    required DateTime requestedDateTime,
    String? brokerCompany,
    String? brokerPhone,
    String? brokerUid,
    String? message,
  }) async {
    try {
      final now = DateTime.now();
      final requestId = 'vr_${now.millisecondsSinceEpoch}_$brokerId';

      final visitRequest = VisitRequest(
        id: requestId,
        propertyId: propertyId,
        brokerId: brokerId,
        brokerName: brokerName,
        brokerCompany: brokerCompany,
        brokerPhone: brokerPhone,
        proposedPrice: proposedPrice,
        requestedDateTime: requestedDateTime,
        message: message,
        createdAt: now,
      );

      // Sub-collection에 저장
      await _firestore
          .collection(_propertiesCollection)
          .doc(propertyId)
          .collection(_visitRequestsSubCollection)
          .doc(requestId)
          .set(visitRequest.toMap());

      // 요청 수 카운터 업데이트 (매물 문서에) — set(merge:true)로 문서 미존재 시에도 안전
      await _firestore.collection(_propertiesCollection).doc(propertyId).set({
        'visitRequestCount': FieldValue.increment(1),
        'updatedAt': now.toIso8601String(),
      }, SetOptions(merge: true));

      // 중개사 통계 업데이트
      await BrokerStatsService().onVisitRequestCreated(
        brokerId: brokerId,
        brokerName: brokerName,
        brokerCompany: brokerCompany,
      );

      Logger.info('Visit request created (sub-collection): $requestId');
      return visitRequest;
    } catch (e) {
      Logger.error('Failed to create visit request (sub-collection)', error: e);
      rethrow;
    }
  }

  /// 방문 요청 조회 (단건)
  Future<VisitRequest?> getVisitRequest(String propertyId, String requestId) async {
    try {
      final doc = await _firestore
          .collection(_propertiesCollection)
          .doc(propertyId)
          .collection(_visitRequestsSubCollection)
          .doc(requestId)
          .get();

      if (!doc.exists) return null;
      return VisitRequest.fromMap(doc.data()!);
    } catch (e) {
      Logger.error('Failed to get visit request', error: e);
      return null;
    }
  }

  /// 매물별 방문 요청 목록 (스트림)
  Stream<List<VisitRequest>> getVisitRequestsByProperty(String propertyId) {
    return _firestore
        .collection(_propertiesCollection)
        .doc(propertyId)
        .collection(_visitRequestsSubCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => VisitRequest.fromMap(doc.data()))
            .toList());
  }

  /// 중개사별 방문 요청 목록 (전체 매물에서)
  Future<List<VisitRequest>> getVisitRequestsByBroker(String brokerId) async {
    try {
      // Collection Group 쿼리 사용
      final snapshot = await _firestore
          .collectionGroup(_visitRequestsSubCollection)
          .where('brokerId', isEqualTo: brokerId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => VisitRequest.fromMap(doc.data()))
          .toList();
    } catch (e) {
      Logger.error('Failed to get visit requests by broker', error: e);
      return [];
    }
  }

  /// 대기 중인 방문 요청 목록 (매물별)
  Stream<List<VisitRequest>> getPendingVisitRequests(String propertyId) {
    return _firestore
        .collection(_propertiesCollection)
        .doc(propertyId)
        .collection(_visitRequestsSubCollection)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => VisitRequest.fromMap(doc.data()))
            .toList());
  }

  /// 방문 요청 상태 업데이트
  Future<void> updateVisitRequestStatus({
    required String propertyId,
    required String requestId,
    required VisitRequestStatus newStatus,
    String? sellerResponse,
    String? sellerPhone,
    DateTime? alternativeDateTime,
  }) async {
    try {
      final now = DateTime.now();
      final updates = <String, dynamic>{
        'status': newStatus.toString().split('.').last,
        'respondedAt': now.toIso8601String(),
      };

      if (sellerResponse != null) {
        updates['sellerResponse'] = sellerResponse;
      }
      if (sellerPhone != null) {
        updates['sellerPhone'] = sellerPhone;
        updates['contactExchangedAt'] = now.toIso8601String();
      }
      if (alternativeDateTime != null) {
        updates['alternativeDateTime'] = alternativeDateTime.toIso8601String();
      }

      await _firestore
          .collection(_propertiesCollection)
          .doc(propertyId)
          .collection(_visitRequestsSubCollection)
          .doc(requestId)
          .update(updates);

      Logger.info('Visit request status updated: $requestId -> $newStatus');
    } catch (e) {
      Logger.error('Failed to update visit request status', error: e);
      rethrow;
    }
  }

  /// 방문 요청 승인 (충돌 요청 자동 처리)
  Future<void> approveVisitRequest({
    required String propertyId,
    required String requestId,
    required String sellerPhone,
    String? sellerMessage,
  }) async {
    try {
      final request = await getVisitRequest(propertyId, requestId);
      if (request == null) {
        throw Exception('Visit request not found: $requestId');
      }

      final now = DateTime.now();

      // 1. 요청 승인
      await updateVisitRequestStatus(
        propertyId: propertyId,
        requestId: requestId,
        newStatus: VisitRequestStatus.approved,
        sellerResponse: sellerMessage,
        sellerPhone: sellerPhone,
      );

      // 2. 같은 시간대 다른 요청 자동 reschedule
      final conflictingRequests = await _getConflictingRequests(
        propertyId,
        requestId,
        request.requestedDateTime,
      );

      for (final conflicting in conflictingRequests) {
        await updateVisitRequestStatus(
          propertyId: propertyId,
          requestId: conflicting.id,
          newStatus: VisitRequestStatus.reschedule,
          sellerResponse: '다른 중개사의 같은 시간 요청이 승인되었습니다. 다른 시간을 선택해 주세요.',
        );

        // 충돌 알림 전송
        await FirebaseService().sendNotification(
          userId: conflicting.brokerId,
          type: 'visit_reschedule_needed',
          title: '시간 변경 필요',
          message: '요청하신 시간에 다른 방문이 확정되었습니다. 다른 시간을 선택해 주세요.',
          relatedId: propertyId,
        );
      }

      // 3. 승인 알림 전송
      await FirebaseService().sendNotification(
        userId: request.brokerId,
        type: 'visit_approved',
        title: '방문 요청 승인',
        message: '방문 요청이 승인되었습니다. 연락처: $sellerPhone',
        relatedId: propertyId,
      );

      // 4. 중개사 통계 업데이트
      final responseTimeSeconds = now.difference(request.createdAt).inSeconds;
      await BrokerStatsService().onVisitRequestResponded(
        brokerId: request.brokerId,
        approved: true,
        responseTimeSeconds: responseTimeSeconds,
      );

      Logger.info('Visit request approved (sub-collection): $requestId');
    } catch (e) {
      Logger.error('Failed to approve visit request (sub-collection)', error: e);
      rethrow;
    }
  }

  /// 방문 요청 거절
  Future<void> rejectVisitRequest({
    required String propertyId,
    required String requestId,
    String? rejectionReason,
    String? sellerMessage,
  }) async {
    try {
      final request = await getVisitRequest(propertyId, requestId);
      if (request == null) {
        throw Exception('Visit request not found: $requestId');
      }

      final now = DateTime.now();

      // 1. 상태를 rejected로 변경 + 거절 사유 저장
      final updates = <String, dynamic>{
        'status': 'rejected',
        'respondedAt': now.toIso8601String(),
        'sellerResponse': sellerMessage,
        'rejectionReason': rejectionReason,
      };

      await _firestore
          .collection(_propertiesCollection)
          .doc(propertyId)
          .collection(_visitRequestsSubCollection)
          .doc(requestId)
          .update(updates);

      // 2. 거절 알림 전송
      final reasonText = rejectionReason != null && rejectionReason.isNotEmpty
          ? ' 사유: $rejectionReason'
          : '';
      await FirebaseService().sendNotification(
        userId: request.brokerId,
        type: 'visit_rejected',
        title: '방문 요청 거절',
        message: '방문 요청이 거절되었습니다.$reasonText',
        relatedId: propertyId,
      );

      // 3. 중개사 통계 업데이트
      final responseTimeSeconds = now.difference(request.createdAt).inSeconds;
      await BrokerStatsService().onVisitRequestResponded(
        brokerId: request.brokerId,
        approved: false,
        responseTimeSeconds: responseTimeSeconds,
      );

      Logger.info('Visit request rejected: $requestId, reason: $rejectionReason');
    } catch (e) {
      Logger.error('Failed to reject visit request', error: e);
      rethrow;
    }
  }

  /// 같은 시간대의 충돌 요청 조회
  Future<List<VisitRequest>> _getConflictingRequests(
    String propertyId,
    String excludeRequestId,
    DateTime targetTime,
  ) async {
    try {
      // 1시간 범위 내의 요청 조회
      final startTime = targetTime.subtract(const Duration(minutes: 30));
      final endTime = targetTime.add(const Duration(minutes: 30));

      final snapshot = await _firestore
          .collection(_propertiesCollection)
          .doc(propertyId)
          .collection(_visitRequestsSubCollection)
          .where('status', isEqualTo: 'pending')
          .get();

      return snapshot.docs
          .map((doc) => VisitRequest.fromMap(doc.data()))
          .where((r) =>
              r.id != excludeRequestId &&
              r.requestedDateTime.isAfter(startTime) &&
              r.requestedDateTime.isBefore(endTime))
          .toList();
    } catch (e) {
      Logger.error('Failed to get conflicting requests', error: e);
      return [];
    }
  }

  /// 방문 완료 처리
  Future<void> markVisitCompleted({
    required String propertyId,
    required String requestId,
    String? feedback,
  }) async {
    try {
      final request = await getVisitRequest(propertyId, requestId);
      if (request == null) {
        throw Exception('Visit request not found: $requestId');
      }

      await _firestore
          .collection(_propertiesCollection)
          .doc(propertyId)
          .collection(_visitRequestsSubCollection)
          .doc(requestId)
          .update({
        'visitCompletedAt': DateTime.now().toIso8601String(),
        'noShow': false,
        'visitFeedback': feedback,
      });

      // 중개사 통계 업데이트
      await BrokerStatsService().onVisitCompleted(brokerId: request.brokerId);

      Logger.info('Visit marked as completed: $requestId');
    } catch (e) {
      Logger.error('Failed to mark visit completed', error: e);
      rethrow;
    }
  }

  /// 노쇼 처리
  Future<void> markVisitNoShow({
    required String propertyId,
    required String requestId,
    String? feedback,
  }) async {
    try {
      final request = await getVisitRequest(propertyId, requestId);
      if (request == null) {
        throw Exception('Visit request not found: $requestId');
      }

      await _firestore
          .collection(_propertiesCollection)
          .doc(propertyId)
          .collection(_visitRequestsSubCollection)
          .doc(requestId)
          .update({
        'visitCompletedAt': DateTime.now().toIso8601String(),
        'noShow': true,
        'visitFeedback': feedback,
      });

      // 중개사 통계 업데이트
      await BrokerStatsService().onNoShow(brokerId: request.brokerId);

      // 알림 전송
      await FirebaseService().sendNotification(
        userId: request.brokerId,
        type: 'no_show_recorded',
        title: '노쇼 기록',
        message: '방문 미이행이 기록되었습니다.',
        relatedId: propertyId,
      );

      Logger.info('Visit marked as no-show: $requestId');
    } catch (e) {
      Logger.error('Failed to mark visit as no-show', error: e);
      rethrow;
    }
  }

  // ========== 마이그레이션 유틸리티 ==========

  /// 기존 리스트 방식에서 Sub-collection으로 마이그레이션
  Future<void> migratePropertyVisitRequests(String propertyId) async {
    try {
      final propertyDoc = await _firestore
          .collection(_propertiesCollection)
          .doc(propertyId)
          .get();

      if (!propertyDoc.exists) {
        Logger.warning('Property not found for migration: $propertyId');
        return;
      }

      final data = propertyDoc.data()!;
      final visitRequestsList = data['visitRequests'] as List<dynamic>? ?? [];

      if (visitRequestsList.isEmpty) {
        Logger.info('No visit requests to migrate for: $propertyId');
        return;
      }

      // Batch로 마이그레이션
      final batch = _firestore.batch();

      for (final requestData in visitRequestsList) {
        final request = VisitRequest.fromMap(requestData as Map<String, dynamic>);
        final docRef = _firestore
            .collection(_propertiesCollection)
            .doc(propertyId)
            .collection(_visitRequestsSubCollection)
            .doc(request.id);

        batch.set(docRef, request.toMap());
      }

      // 원본 리스트 필드 제거 및 카운트 추가
      batch.update(
        _firestore.collection(_propertiesCollection).doc(propertyId),
        {
          'visitRequestCount': visitRequestsList.length,
          'visitRequestsMigrated': true,
          'migratedAt': DateTime.now().toIso8601String(),
        },
      );

      await batch.commit();
      Logger.info('Migrated ${visitRequestsList.length} visit requests for: $propertyId');
    } catch (e) {
      Logger.error('Failed to migrate visit requests', error: e);
      rethrow;
    }
  }

  /// 전체 매물 마이그레이션
  Future<int> migrateAllVisitRequests() async {
    try {
      final snapshot = await _firestore
          .collection(_propertiesCollection)
          .where('visitRequestsMigrated', isNotEqualTo: true)
          .get();

      int migratedCount = 0;
      for (final doc in snapshot.docs) {
        await migratePropertyVisitRequests(doc.id);
        migratedCount++;
      }

      Logger.info('Migration completed: $migratedCount properties');
      return migratedCount;
    } catch (e) {
      Logger.error('Failed to migrate all visit requests', error: e);
      return 0;
    }
  }
}
