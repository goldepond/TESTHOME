import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/mls_property.dart';
import '../models/buyer_inquiry.dart';
import '../models/notification_model.dart';
import '../utils/logger.dart';
import '../utils/formatters.dart';
import 'firebase_service.dart';
import 'broker_stats_service.dart';

/// MLS(Multiple Listing Service)형 매물 관리 서비스
///
/// 매도인 중심의 매물 통합 관리 시스템:
/// - 매물 등록/수정/삭제
/// - 지역 기반 중개사 자동 배포
/// - 실시간 상태 동기화
/// - 방문 예약 관리
/// - 협의 이력 관리
class MLSPropertyService {
  // 싱글톤 패턴
  static final MLSPropertyService _instance = MLSPropertyService._internal();
  factory MLSPropertyService() => _instance;
  MLSPropertyService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _collectionName = 'mlsProperties';

  // 스트림 캐싱용 변수 (재구독 방지)
  final Map<String, Stream<List<MLSProperty>>> _broadcastStreams = {};

  // 지역 목록 캐시
  List<String>? _cachedRegions;
  DateTime? _regionsCacheTime;

  /// 매물 생성
  Future<String> createProperty(MLSProperty property) async {
    try {
      final docRef = _firestore.collection(_collectionName).doc(property.id);
      await docRef.set(property.toMap());
      Logger.info('MLS Property created: ${property.id}');
      return property.id;
    } catch (e) {
      Logger.error('Failed to create MLS property', error: e);
      rethrow;
    }
  }

  /// 매물 생성 (사용자 기본 시간 블록 자동 적용)
  ///
  /// 사용자가 설정한 기본 주간 시간 블록을 자동으로 적용합니다.
  Future<String> createPropertyWithDefaults(
    MLSProperty property,
    String userId,
  ) async {
    try {
      // 사용자의 기본 시간 블록 조회
      final defaultBlocks = await FirebaseService().getDefaultWeeklyTimeBlocks(userId);

      // 기본 시간 블록이 있으면 적용
      MLSProperty propertyWithDefaults = property;
      if (defaultBlocks.isNotEmpty) {
        propertyWithDefaults = property.copyWith(
          weeklyTimeBlocks: defaultBlocks,
        );
        Logger.info('기본 주간 시간 블록 적용: ${defaultBlocks.keys.length}일');
      }

      // 매물 생성
      final docRef = _firestore.collection(_collectionName).doc(propertyWithDefaults.id);
      await docRef.set(propertyWithDefaults.toMap());
      Logger.info('MLS Property created with defaults: ${propertyWithDefaults.id}');

      return propertyWithDefaults.id;
    } catch (e) {
      Logger.error('Failed to create MLS property with defaults', error: e);
      rethrow;
    }
  }

  /// 관리자 대리 매물 등록
  ///
  /// 관리자가 특정 사용자를 대신하여 매물을 등록합니다.
  /// [property] - 등록할 매물 정보 (userId, userName은 대상 사용자 정보로 설정되어 있어야 함)
  /// [adminId] - 등록을 처리한 관리자 ID
  Future<String> createPropertyOnBehalf({
    required MLSProperty property,
    required String adminId,
  }) async {
    try {
      final propertyMap = property.toMap();
      propertyMap['registeredByAdmin'] = adminId;
      propertyMap['isProxyRegistration'] = true;

      final docRef = _firestore.collection(_collectionName).doc(property.id);
      await docRef.set(propertyMap);

      Logger.info('MLS Property created on behalf: ${property.id} by admin: $adminId');
      return property.id;
    } catch (e) {
      Logger.error('Failed to create MLS property on behalf', error: e);
      rethrow;
    }
  }

  /// 외부 매물을 앱 가입한 사용자에게 연결
  ///
  /// 외부 매물(당근마켓 등)의 집주인이 나중에 앱에 가입했을 때
  /// 해당 매물의 소유권을 이전합니다.
  Future<void> linkExternalPropertyToUser({
    required String propertyId,
    required String userId,
    required String userName,
  }) async {
    try {
      await _firestore.collection(_collectionName).doc(propertyId).update({
        'linkedUserId': userId,
        'userId': userId,
        'userName': userName,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      Logger.info('External property $propertyId linked to user: $userId');
    } catch (e) {
      Logger.error('Failed to link external property to user', error: e);
      rethrow;
    }
  }

  /// 전화번호로 외부 매물 조회
  Future<List<MLSProperty>> findExternalPropertiesByPhone(String phone) async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .where('isExternalListing', isEqualTo: true)
          .where('externalSellerPhone', isEqualTo: phone)
          .get();

      return snapshot.docs
          .map((doc) => MLSProperty.fromMap(doc.data()))
          .toList();
    } catch (e) {
      Logger.error('Failed to find external properties by phone', error: e);
      return [];
    }
  }

  /// 매물 수정
  Future<void> updateProperty(String id, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = DateTime.now().toIso8601String();
      await _firestore.collection(_collectionName).doc(id).update(updates);
      Logger.info('MLS Property updated: $id');
    } catch (e) {
      Logger.error('Failed to update MLS property', error: e);
      rethrow;
    }
  }

  /// 매물 조회 (단건)
  Future<MLSProperty?> getProperty(String id) async {
    try {
      final doc = await _firestore.collection(_collectionName).doc(id).get();
      if (!doc.exists) return null;
      return MLSProperty.fromMap(doc.data()!);
    } catch (e) {
      Logger.error('Failed to get MLS property', error: e);
      return null;
    }
  }

  /// 매도인별 매물 목록 조회 (실시간 스트림)
  Stream<List<MLSProperty>> getPropertiesByUser(String userId) {
    return _firestore
      .collection(_collectionName)
      .where('userId', isEqualTo: userId)
      .where('isDeleted', isEqualTo: false)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
        .map((doc) => MLSProperty.fromMap(doc.data()))
        .toList());
  }

  /// 전체 활성 매물 조회 (마켓플레이스용)
  Stream<List<MLSProperty>> getAllActiveProperties({int limit = 50}) {
    return _firestore
      .collection(_collectionName)
      .where('isActive', isEqualTo: true)
      .where('isDeleted', isEqualTo: false)
      .where('status', whereIn: [
        PropertyStatus.active.toString().split('.').last,
        PropertyStatus.inquiry.toString().split('.').last,
        PropertyStatus.underOffer.toString().split('.').last,
      ])
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((snapshot) => snapshot.docs
        .map((doc) => MLSProperty.fromMap(doc.data()))
        .toList());
  }

  /// 관리자용 전체 매물 조회 (모든 상태 포함 - pending, rejected 등)
  Stream<List<MLSProperty>> getAllPropertiesForAdmin({int limit = 500}) {
    return _firestore
      .collection(_collectionName)
      .where('isDeleted', isEqualTo: false)
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((snapshot) => snapshot.docs
        .map((doc) => MLSProperty.fromMap(doc.data()))
        .toList());
  }

  /// 전체 활성 매물 빠른 조회 (마켓플레이스 초기 로딩용)
  Future<List<MLSProperty>> getAllActivePropertiesFast({int limit = 100}) async {
    try {
      final snapshot = await _firestore
        .collection(_collectionName)
        .where('isActive', isEqualTo: true)
        .where('isDeleted', isEqualTo: false)
        .where('status', whereIn: [
          PropertyStatus.active.toString().split('.').last,
          PropertyStatus.inquiry.toString().split('.').last,
          PropertyStatus.underOffer.toString().split('.').last,
        ])
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

      return snapshot.docs
        .map((doc) => MLSProperty.fromMap(doc.data()))
        .toList();
    } catch (e) {
      Logger.error('Failed to get active properties fast', error: e);
      return [];
    }
  }

  /// 중개사가 영업할 매물 목록 조회 (모든 활성 매물)
  /// whereIn 대신 클라이언트 필터링 사용하여 인덱스 제약 회피
  /// 스트림 캐싱으로 재구독 방지
  Stream<List<MLSProperty>> getAllBrowsableProperties({String? region, int limit = 50}) {
    final cacheKey = 'browsable_${region ?? 'all'}_$limit';

    // 이미 캐싱된 스트림이 있으면 재사용
    if (_broadcastStreams.containsKey(cacheKey)) {
      return _broadcastStreams[cacheKey]!;
    }

    Query<Map<String, dynamic>> query = _firestore
      .collection(_collectionName)
      .where('isActive', isEqualTo: true)
      .where('isDeleted', isEqualTo: false)
      .orderBy('createdAt', descending: true)
      .limit(limit);

    if (region != null && region.isNotEmpty) {
      query = query.where('region', isEqualTo: region);
    }

    final stream = query.snapshots().map((snapshot) {
      return snapshot.docs
        .map((doc) => MLSProperty.fromMap(doc.data()))
        .where((p) =>
          p.status == PropertyStatus.active ||
          p.status == PropertyStatus.inquiry ||
          p.status == PropertyStatus.underOffer)
        .toList();
    }).asBroadcastStream();

    _broadcastStreams[cacheKey] = stream;
    return stream;
  }

  /// 캐시된 스트림 초기화 (지역 변경 시 호출)
  void clearBrowsableCache() {
    _broadcastStreams.removeWhere((key, _) => key.startsWith('browsable_'));
  }

  /// 전체 매물의 지역 목록 조회 (필터용) - 5분 캐싱
  Future<List<String>> getAvailableRegions({bool forceRefresh = false}) async {
    // 캐시가 유효하면 바로 반환 (5분)
    if (!forceRefresh &&
        _cachedRegions != null &&
        _regionsCacheTime != null &&
        DateTime.now().difference(_regionsCacheTime!).inMinutes < 5) {
      return _cachedRegions!;
    }

    try {
      // 필요한 필드만 가져오기 (region만)
      final snapshot = await _firestore
        .collection(_collectionName)
        .where('isActive', isEqualTo: true)
        .where('isDeleted', isEqualTo: false)
        .limit(200) // 최대 200개만 조회
        .get();

      final regions = snapshot.docs
        .map((doc) => doc.data()['region'] as String?)
        .where((r) => r != null && r.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();

      regions.sort();

      // 캐시 저장
      _cachedRegions = regions;
      _regionsCacheTime = DateTime.now();

      return regions;
    } catch (e) {
      Logger.error('Failed to get available regions', error: e);
      return _cachedRegions ?? [];
    }
  }

  /// 지역별 활성 매물 조회
  Stream<List<MLSProperty>> getActivePropertiesByRegion(String region) {
    return _firestore
      .collection(_collectionName)
      .where('region', isEqualTo: region)
      .where('isActive', isEqualTo: true)
      .where('isDeleted', isEqualTo: false)
      .where('status', whereIn: [
        PropertyStatus.active.toString().split('.').last,
        PropertyStatus.inquiry.toString().split('.').last,
        PropertyStatus.underOffer.toString().split('.').last,
      ])
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
        .map((doc) => MLSProperty.fromMap(doc.data()))
        .toList());
  }

  /// 중개사에게 배포된 모든 매물 조회 (참여 대시보드용) - Future 버전
  /// 수락 여부와 관계없이 targetBrokerIds에 포함된 모든 매물 반환
  Future<List<MLSProperty>> getPropertiesBroadcastedToBroker(String brokerId) async {
    try {
      final snapshot = await _firestore
        .collection(_collectionName)
        .where('targetBrokerIds', arrayContains: brokerId)
        .where('isDeleted', isEqualTo: false)
        .where('isActive', isEqualTo: true)
        .orderBy('broadcastedAt', descending: true)
        .get();

      return snapshot.docs
        .map((doc) => MLSProperty.fromMap(doc.data()))
        .toList();
    } catch (e) {
      Logger.error('Failed to get broadcasted properties', error: e);
      return [];
    }
  }

  /// 중개사에게 배포된 활성 매물 조회 (실시간 스트림 버전)
  /// 활성 상태(active, inquiry, underOffer)인 매물만 반환
  /// 스트림 캐싱으로 재구독 방지
  Stream<List<MLSProperty>> getPropertiesBroadcastedToBrokerStream(String brokerId) {
    final cacheKey = 'broadcasted_$brokerId';

    if (_broadcastStreams.containsKey(cacheKey)) {
      return _broadcastStreams[cacheKey]!;
    }

    final stream = _firestore
      .collection(_collectionName)
      .where('targetBrokerIds', arrayContains: brokerId)
      .where('isDeleted', isEqualTo: false)
      .where('isActive', isEqualTo: true)
      .orderBy('broadcastedAt', descending: true)
      .snapshots()
      .map((snapshot) {
        // 클라이언트 측에서 활성 상태만 필터링 (arrayContains와 whereIn 동시 사용 불가)
        return snapshot.docs
          .map((doc) => MLSProperty.fromMap(doc.data()))
          .where((property) =>
            property.status == PropertyStatus.active ||
            property.status == PropertyStatus.inquiry ||
            property.status == PropertyStatus.underOffer)
          .toList();
      }).asBroadcastStream();

    _broadcastStreams[cacheKey] = stream;
    return stream;
  }

  /// 중개사가 가계약 또는 거래완료한 매물 조회 (성과 탭용)
  /// 스트림 캐싱으로 재구독 방지
  Stream<List<MLSProperty>> getCompletedPropertiesByBroker(String brokerId) {
    final cacheKey = 'completed_$brokerId';

    if (_broadcastStreams.containsKey(cacheKey)) {
      return _broadcastStreams[cacheKey]!;
    }

    final stream = _firestore
      .collection(_collectionName)
      .where('finalBrokerId', isEqualTo: brokerId)
      .where('isDeleted', isEqualTo: false)
      .orderBy('depositTakenAt', descending: true)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs
          .map((doc) => MLSProperty.fromMap(doc.data()))
          .where((property) =>
            property.status == PropertyStatus.depositTaken ||
            property.status == PropertyStatus.sold)
          .toList();
      }).asBroadcastStream();

    _broadcastStreams[cacheKey] = stream;
    return stream;
  }

  // ========================================
  // 빠른 초기 로딩용 Future 메서드 (대시보드 최적화)
  // ========================================

  /// 전체 활성 매물 빠른 조회 (초기 로딩용)
  Future<List<MLSProperty>> getAllBrowsablePropertiesFast({String? region, int limit = 30}) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
        .collection(_collectionName)
        .where('isActive', isEqualTo: true)
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(limit);

      if (region != null && region.isNotEmpty) {
        query = query.where('region', isEqualTo: region);
      }

      final snapshot = await query.get();
      return snapshot.docs
        .map((doc) => MLSProperty.fromMap(doc.data()))
        .where((p) =>
          p.status == PropertyStatus.active ||
          p.status == PropertyStatus.inquiry ||
          p.status == PropertyStatus.underOffer)
        .toList();
    } catch (e) {
      Logger.error('Failed to get browsable properties fast', error: e);
      return [];
    }
  }

  /// 중개사에게 배포된 매물 빠른 조회 (초기 로딩용)
  /// 활성 상태(active, inquiry, underOffer)인 매물만 반환
  Future<List<MLSProperty>> getPropertiesBroadcastedToBrokerFast(String brokerId) async {
    try {
      final snapshot = await _firestore
        .collection(_collectionName)
        .where('targetBrokerIds', arrayContains: brokerId)
        .where('isDeleted', isEqualTo: false)
        .where('isActive', isEqualTo: true)
        .orderBy('broadcastedAt', descending: true)
        .limit(50)
        .get();

      // 클라이언트 측에서 활성 상태만 필터링 (arrayContains와 whereIn 동시 사용 불가)
      return snapshot.docs
        .map((doc) => MLSProperty.fromMap(doc.data()))
        .where((property) =>
          property.status == PropertyStatus.active ||
          property.status == PropertyStatus.inquiry ||
          property.status == PropertyStatus.underOffer)
        .toList();
    } catch (e) {
      Logger.error('Failed to get broadcasted properties fast', error: e);
      return [];
    }
  }

  /// 중개사 성과 매물 빠른 조회 (초기 로딩용)
  Future<List<MLSProperty>> getCompletedPropertiesByBrokerFast(String brokerId) async {
    try {
      final snapshot = await _firestore
        .collection(_collectionName)
        .where('finalBrokerId', isEqualTo: brokerId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('depositTakenAt', descending: true)
        .limit(50)
        .get();

      return snapshot.docs
        .map((doc) => MLSProperty.fromMap(doc.data()))
        .where((property) =>
          property.status == PropertyStatus.depositTaken ||
          property.status == PropertyStatus.sold)
        .toList();
    } catch (e) {
      Logger.error('Failed to get completed properties fast', error: e);
      return [];
    }
  }

  /// 중개사 관련 캐시 초기화 (로그아웃 시 호출)
  void clearBrokerCache(String brokerId) {
    _broadcastStreams.removeWhere((key, _) =>
        key == 'broadcasted_$brokerId' || key == 'completed_$brokerId');
  }

  /// 전체 캐시 초기화 (로그아웃 시 호출)
  void clearAllCache() {
    _broadcastStreams.clear();
  }

  /// 매물 배포 (지역 내 중개사에게 푸시)
  Future<void> broadcastProperty({
    required String propertyId,
    required List<String> brokerIds,
  }) async {
    try {
      final now = DateTime.now();
      final brokerResponses = <String, BrokerResponse>{};

      for (final brokerId in brokerIds) {
        brokerResponses[brokerId] = BrokerResponse(
          brokerId: brokerId,
          brokerName: '', // 실제로는 중개사 정보 조회 필요
          receivedAt: now,
        );
      }

      await updateProperty(propertyId, {
        'targetBrokerIds': brokerIds,
        'brokerResponses': brokerResponses.map((k, v) => MapEntry(k, v.toMap())),
        'broadcastedAt': now.toIso8601String(),
        'status': PropertyStatus.active.toString().split('.').last,
      });

      Logger.info('Property broadcasted to ${brokerIds.length} brokers: $propertyId');
    } catch (e) {
      Logger.error('Failed to broadcast property', error: e);
      rethrow;
    }
  }

  /// 중개사 응답 업데이트 (상태 및 진행 단계 업데이트)
  Future<void> updateBrokerResponse({
    required String propertyId,
    required String brokerId,
    String? brokerName,
    String? brokerCompany,
    String? brokerPhone,
    BrokerStage? stage,
    bool? viewed,
  }) async {
    try {
      final property = await getProperty(propertyId);
      if (property == null) {
        throw Exception('Property not found: $propertyId');
      }

      final responses = Map<String, BrokerResponse>.from(property.brokerResponses);
      final existing = responses[brokerId];

      responses[brokerId] = BrokerResponse(
        brokerId: brokerId,
        brokerName: brokerName ?? existing?.brokerName ?? '',
        brokerCompany: brokerCompany ?? existing?.brokerCompany,
        brokerPhone: brokerPhone ?? existing?.brokerPhone,
        stage: stage ?? existing?.stage ?? BrokerStage.received,
        receivedAt: existing?.receivedAt ?? DateTime.now(),
        viewedAt: viewed == true ? DateTime.now() : existing?.viewedAt,
      );

      // targetBrokerIds에 Firebase UID 추가 (Firestore 규칙 통과용)
      final targetBrokerIds = List<String>.from(property.targetBrokerIds);
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid != null && !targetBrokerIds.contains(currentUid)) {
        targetBrokerIds.add(currentUid);
      }
      if (!targetBrokerIds.contains(brokerId)) {
        targetBrokerIds.add(brokerId);
      }

      await updateProperty(propertyId, {
        'brokerResponses': responses.map((k, v) => MapEntry(k, v.toMap())),
        'targetBrokerIds': targetBrokerIds,
      });

      Logger.info('Broker response updated: $brokerId -> stage: $stage');
    } catch (e) {
      Logger.error('Failed to update broker response', error: e);
      rethrow;
    }
  }

  /// 매물 상태 변경 (상태 머신)
  Future<void> updateStatus({
    required String propertyId,
    required PropertyStatus newStatus,
    String? changedBy,
    String? reason,
    String? currentBrokerId,
  }) async {
    try {
      final property = await getProperty(propertyId);
      if (property == null) {
        throw Exception('Property not found: $propertyId');
      }

      final history = List<StatusHistory>.from(property.statusHistory);
      history.add(StatusHistory(
        from: property.status,
        to: newStatus,
        changedAt: DateTime.now(),
        changedBy: changedBy,
        reason: reason,
      ));

      final updates = <String, dynamic>{
        'status': newStatus.toString().split('.').last,
        'statusChangedAt': DateTime.now().toIso8601String(),
        'statusHistory': history.map((e) => e.toMap()).toList(),
      };

      if (currentBrokerId != null) {
        updates['currentBrokerId'] = currentBrokerId;
      }

      // 가계약/거래완료 시 추가 처리
      if (newStatus == PropertyStatus.depositTaken) {
        updates['depositTakenAt'] = DateTime.now().toIso8601String();
        updates['virtualPhoneActive'] = false; // 안심번호 비활성화

        // 중개사 통계 업데이트 (가계약)
        if (currentBrokerId != null) {
          await FirebaseService().updateBrokerStatsOnDeal(
            brokerId: currentBrokerId,
            isDepositTaken: true,
          );
        }
      } else if (newStatus == PropertyStatus.sold) {
        updates['soldAt'] = DateTime.now().toIso8601String();
        updates['isActive'] = false;
        updates['virtualPhoneActive'] = false;

        // 중개사 통계 업데이트 (거래 완료)
        final finalBrokerId = currentBrokerId ?? property.finalBrokerId;
        if (finalBrokerId != null) {
          await FirebaseService().updateBrokerStatsOnDeal(
            brokerId: finalBrokerId,
            isDepositTaken: false,
          );
        }
      }

      await updateProperty(propertyId, updates);
      Logger.info('Property status updated: $propertyId -> $newStatus');

      // 가계약/거래완료 시 모든 중개사에게 알림 전송
      if (newStatus == PropertyStatus.depositTaken || newStatus == PropertyStatus.sold) {
        await _notifyAllBrokers(propertyId, newStatus);
      }
    } catch (e) {
      Logger.error('Failed to update property status', error: e);
      rethrow;
    }
  }

  /// 방문 예약 생성
  Future<void> createVisitSchedule({
    required String propertyId,
    required VisitSchedule schedule,
  }) async {
    try {
      final property = await getProperty(propertyId);
      if (property == null) {
        throw Exception('Property not found: $propertyId');
      }

      // 동일 시간대 중복 확인
      final hasConflict = property.visitSchedules.any((s) =>
        s.scheduledAt == schedule.scheduledAt &&
        (s.status == VisitStatus.approved || s.status == VisitStatus.requested));

      if (hasConflict) {
        throw Exception('Time slot already booked');
      }

      final schedules = List<VisitSchedule>.from(property.visitSchedules);
      schedules.add(schedule);

      await updateProperty(propertyId, {
        'visitSchedules': schedules.map((e) => e.toMap()).toList(),
      });

      Logger.info('Visit schedule created: ${schedule.id}');
    } catch (e) {
      Logger.error('Failed to create visit schedule', error: e);
      rethrow;
    }
  }

  /// 방문 예약 상태 업데이트
  Future<void> updateVisitSchedule({
    required String propertyId,
    required String scheduleId,
    required VisitStatus status,
    String? feedback,
  }) async {
    try {
      final property = await getProperty(propertyId);
      if (property == null) {
        throw Exception('Property not found: $propertyId');
      }

      final schedules = List<VisitSchedule>.from(property.visitSchedules);
      final index = schedules.indexWhere((s) => s.id == scheduleId);
      if (index == -1) {
        throw Exception('Schedule not found: $scheduleId');
      }

      final updatedSchedule = VisitSchedule(
        id: schedules[index].id,
        brokerId: schedules[index].brokerId,
        brokerName: schedules[index].brokerName,
        scheduledAt: schedules[index].scheduledAt,
        status: status,
        note: schedules[index].note,
        feedback: feedback ?? schedules[index].feedback,
        feedbackSubmittedAt: feedback != null ? DateTime.now() : schedules[index].feedbackSubmittedAt,
      );

      schedules[index] = updatedSchedule;

      await updateProperty(propertyId, {
        'visitSchedules': schedules.map((e) => e.toMap()).toList(),
      });

      // 방문 승인 시 매물 상태를 inquiry로 변경
      if (status == VisitStatus.approved && property.status == PropertyStatus.active) {
        await updateStatus(
          propertyId: propertyId,
          newStatus: PropertyStatus.inquiry,
          changedBy: property.userId,
          reason: 'Visit approved',
          currentBrokerId: updatedSchedule.brokerId,
        );
      }

      Logger.info('Visit schedule updated: $scheduleId -> $status');
    } catch (e) {
      Logger.error('Failed to update visit schedule', error: e);
      rethrow;
    }
  }

  /// 협의 로그 추가
  Future<void> addNegotiationLog({
    required String propertyId,
    required NegotiationLog log,
  }) async {
    try {
      final property = await getProperty(propertyId);
      if (property == null) {
        throw Exception('Property not found: $propertyId');
      }

      final negotiations = List<NegotiationLog>.from(property.negotiations);
      negotiations.add(log);

      await updateProperty(propertyId, {
        'negotiations': negotiations.map((e) => e.toMap()).toList(),
      });

      // 첫 협의 로그 시 상태를 underOffer로 변경
      if (negotiations.length == 1 && property.status == PropertyStatus.inquiry) {
        await updateStatus(
          propertyId: propertyId,
          newStatus: PropertyStatus.underOffer,
          changedBy: log.brokerId,
          reason: 'Negotiation started',
          currentBrokerId: log.brokerId,
        );
      }

      Logger.info('Negotiation log added: ${log.id}');
    } catch (e) {
      Logger.error('Failed to add negotiation log', error: e);
      rethrow;
    }
  }

  /// 판매자 역제안 추가
  Future<void> addSellerCounterOffer({
    required String propertyId,
    required String brokerId,
    required String brokerName,
    required double counterPrice,
    String? conditions,
    String? message,
  }) async {
    try {
      final property = await getProperty(propertyId);
      if (property == null) {
        throw Exception('Property not found: $propertyId');
      }

      // 협상 로그 추가
      final log = NegotiationLog(
        id: 'counter_${DateTime.now().millisecondsSinceEpoch}',
        brokerId: brokerId,
        brokerName: brokerName,
        proposedPrice: counterPrice,
        conditions: conditions,
        buyerFeedback: message, // 판매자 메시지로 사용
        createdAt: DateTime.now(),
      );

      final negotiations = List<NegotiationLog>.from(property.negotiations);
      negotiations.add(log);

      // 중개사 응답 업데이트 (승인 상태로 - 역제안은 연락 교환 후 진행)
      final brokerResponses = Map<String, BrokerResponse>.from(property.brokerResponses);
      if (brokerResponses.containsKey(brokerId)) {
        brokerResponses[brokerId] = brokerResponses[brokerId]!.copyWith(
          stage: BrokerStage.approved,
        );
      }

      await updateProperty(propertyId, {
        'negotiations': negotiations.map((e) => e.toMap()).toList(),
        'brokerResponses': brokerResponses.map((k, v) => MapEntry(k, v.toMap())),
        'status': PropertyStatus.underOffer.toString().split('.').last,
      });

      // 중개사에게 알림 전송
      final firebaseService = FirebaseService();
      await firebaseService.sendNotification(
        userId: brokerId,
        type: 'counter_offer',
        title: '판매자 역제안',
        message: '${property.userName}님이 ${_formatPrice(counterPrice)}에 역제안했습니다.',
        relatedId: propertyId,
      );

      Logger.info('Seller counter-offer added: $propertyId -> $brokerId');
    } catch (e) {
      Logger.error('Failed to add seller counter-offer', error: e);
      rethrow;
    }
  }

  String _formatPrice(double price) => PriceFormatter.format(price);

  /// 두 시간이 같은 시간대인지 확인 (1시간 이내면 충돌로 간주)
  bool _isSameTimeSlot(DateTime time1, DateTime time2) {
    final diff = time1.difference(time2).abs();
    return diff.inMinutes < 60; // 1시간 이내면 같은 시간대로 간주
  }

  /// 거래 완료 처리
  Future<void> completeTransaction({
    required String propertyId,
    required String finalBrokerId,
    required double finalPrice,
  }) async {
    try {
      await updateProperty(propertyId, {
        'finalBrokerId': finalBrokerId,
        'finalPrice': finalPrice,
      });

      await updateStatus(
        propertyId: propertyId,
        newStatus: PropertyStatus.sold,
        changedBy: finalBrokerId,
        reason: 'Transaction completed',
      );

      Logger.info('Transaction completed: $propertyId');

      // 중개사 통계 업데이트 (거래 완료)
      // 제안가와 최종가 비교를 위해 매물 정보 조회
      final updatedProperty = await getProperty(propertyId);
      if (updatedProperty != null) {
        // 해당 중개사의 제안가 찾기
        final visitRequest = updatedProperty.visitRequests
            .where((r) => r.brokerId == finalBrokerId)
            .lastOrNull;
        final proposedPrice = visitRequest?.proposedPrice ?? finalPrice;

        // 지역 정보 추출 (시/도 단위)
        final region = updatedProperty.address.split(' ').firstOrNull ?? '';

        await BrokerStatsService().onDealCompleted(
          brokerId: finalBrokerId,
          dealAmount: finalPrice,
          proposedPrice: proposedPrice,
          finalPrice: finalPrice,
          region: region,
        );

        // 판매자 히스토리 업데이트
        await BrokerStatsService().onSellerDealCompleted(
          sellerId: updatedProperty.userId,
          propertyId: propertyId,
          brokerId: finalBrokerId,
          brokerName: visitRequest?.brokerName ?? '',
          finalPrice: finalPrice,
          proposedPrice: proposedPrice,
          region: region,
          brokerCompany: visitRequest?.brokerCompany,
          address: updatedProperty.address,
          transactionType: updatedProperty.transactionType,
        );
      }
    } catch (e) {
      Logger.error('Failed to complete transaction', error: e);
      rethrow;
    }
  }

  /// 매물 삭제 (소프트 삭제)
  Future<void> deleteProperty(String propertyId) async {
    try {
      await updateProperty(propertyId, {
        'isDeleted': true,
        'isActive': false,
      });
      Logger.info('Property deleted: $propertyId');
    } catch (e) {
      Logger.error('Failed to delete property', error: e);
      rethrow;
    }
  }

  /// 고유 ID 생성 시 시퀀스 조회
  Future<int> getNextSequence(String region) async {
    try {
      final today = DateTime.now();
      final dateStr = '${today.year}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}';
      final prefix = '${region.toUpperCase()}-$dateStr-';

      final snapshot = await _firestore
        .collection(_collectionName)
        .where('id', isGreaterThanOrEqualTo: prefix)
        .where('id', isLessThan: '${prefix}999999')
        .orderBy('id', descending: true)
        .limit(1)
        .get();

      if (snapshot.docs.isEmpty) {
        return 1;
      }

      final lastId = snapshot.docs.first.id;
      final seqStr = lastId.split('-').last;
      return int.parse(seqStr) + 1;
    } catch (e) {
      Logger.error('Failed to get next sequence', error: e);
      return 1;
    }
  }

  /// 모든 수락 중개사에게 알림 전송 (성사 중개사 제외)
  ///
  /// 가계약/거래완료 시 해당 매물에 참여했던 다른 모든 중개사에게
  /// 거래 성사 알림을 전송하여 중복 영업을 방지합니다.
  Future<void> _notifyAllBrokers(String propertyId, PropertyStatus status) async {
    try {
      final property = await getProperty(propertyId);
      if (property == null) return;

      // 성사 중개사 ID (알림 제외 대상)
      final winnerId = property.finalBrokerId;

      // 참여했던 모든 중개사 중 성사 중개사 제외
      final brokerIdsToNotify = property.brokerResponses.entries
        .where((e) =>
          e.value.hasViewed &&
          e.key != winnerId)  // 성사 중개사 제외
        .map((e) => e.key)
        .toList();

      if (brokerIdsToNotify.isEmpty) {
        Logger.info('No brokers to notify for property: $propertyId');
        return;
      }

      // 알림 내용 결정
      String title;
      String message;
      String type;

      if (status == PropertyStatus.depositTaken) {
        title = '매물 가계약 성사 알림';
        message = '${property.roadAddress} 매물이 다른 중개사와 가계약되었습니다.\n해당 매물 영업을 중단해주세요.';
        type = NotificationType.propertyDepositTaken;
      } else if (status == PropertyStatus.sold) {
        title = '매물 거래 완료 알림';
        message = '${property.roadAddress} 매물의 거래가 완료되었습니다.\n수고하셨습니다!';
        type = NotificationType.propertySold;
      } else {
        // 다른 상태는 알림 불필요
        return;
      }

      // 대량 알림 전송
      await FirebaseService().sendBulkNotifications(
        userIds: brokerIdsToNotify,
        title: title,
        message: message,
        type: type,
        relatedId: propertyId,
        additionalData: {
          'propertyAddress': property.roadAddress,
          'winnerBrokerId': winnerId,
        },
      );

      Logger.info('Notifications sent to ${brokerIdsToNotify.length} brokers for property: $propertyId');
    } catch (e) {
      Logger.error('Failed to notify brokers', error: e);
      // 알림 실패해도 거래 처리는 계속 진행
    }
  }

  /// 가용 시간대 설정
  Future<void> setAvailableSlots({
    required String propertyId,
    required Map<String, List<TimeSlot>> slots,
  }) async {
    try {
      final slotsMap = slots.map(
        (date, timeSlots) => MapEntry(date, timeSlots.map((s) => s.toMap()).toList()),
      );

      await updateProperty(propertyId, {
        'availableSlots': slotsMap,
      });

      Logger.info('Available slots updated for property: $propertyId');
    } catch (e) {
      Logger.error('Failed to set available slots', error: e);
      rethrow;
    }
  }

  /// 주간 시간 블록 설정 (요일별 오전/오후/저녁)
  Future<void> setWeeklyTimeBlocks({
    required String propertyId,
    required Map<int, List<String>> weeklyBlocks,
  }) async {
    try {
      // Firestore는 int 키를 지원하지 않으므로 문자열로 변환
      final blocksMap = weeklyBlocks.map(
        (weekday, blocks) => MapEntry(weekday.toString(), blocks),
      );

      await updateProperty(propertyId, {
        'weeklyTimeBlocks': blocksMap,
      });

      Logger.info('Weekly time blocks updated for property: $propertyId');
    } catch (e) {
      Logger.error('Failed to set weekly time blocks', error: e);
      rethrow;
    }
  }

  // ========================================
  // 매물 검증 시스템 (Phase 2)
  // ========================================

  /// 중복 주소 체크
  /// 동일한 도로명주소로 이미 활성 상태인 매물이 있는지 확인
  Future<MLSProperty?> checkDuplicateAddress(String roadAddress) async {
    try {
      final snapshot = await _firestore
        .collection(_collectionName)
        .where('roadAddress', isEqualTo: roadAddress)
        .where('isDeleted', isEqualTo: false)
        .get();

      // 활성 상태인 매물만 중복으로 판단
      // (pending, active, inquiry, underOffer, depositTaken)
      final activeStatuses = [
        PropertyStatus.pending,
        PropertyStatus.active,
        PropertyStatus.inquiry,
        PropertyStatus.underOffer,
        PropertyStatus.depositTaken,
      ].map((s) => s.toString().split('.').last).toSet();

      for (final doc in snapshot.docs) {
        final property = MLSProperty.fromMap(doc.data());
        final statusStr = property.status.toString().split('.').last;
        if (activeStatuses.contains(statusStr)) {
          return property;
        }
      }

      return null;
    } catch (e) {
      Logger.error('Failed to check duplicate address', error: e);
      return null;
    }
  }

  /// 매물 검증 요청 (등록 시 자동 호출)
  /// 중복 없으면 자동 승인 → active로 전환
  /// 중복 있으면 pending 유지 + 관리자 검토 필요
  Future<VerificationStatus> submitForVerification(String propertyId) async {
    try {
      final property = await getProperty(propertyId);
      if (property == null) {
        throw Exception('Property not found: $propertyId');
      }

      // 중복 주소 체크
      final duplicate = await checkDuplicateAddress(property.roadAddress);

      final now = DateTime.now();
      VerificationStatus verificationStatus;
      PropertyStatus newStatus;

      if (duplicate != null && duplicate.id != propertyId) {
        // 중복 감지 → pending 유지, 관리자 검토 필요
        verificationStatus = VerificationStatus.addressDuplicate;
        newStatus = PropertyStatus.pending;

        await updateProperty(propertyId, {
          'status': newStatus.toString().split('.').last,
          'verificationStatus': verificationStatus.toString().split('.').last,
          'verificationRequestedAt': now.toIso8601String(),
          'duplicatePropertyId': duplicate.id,
          'updatedAt': now.toIso8601String(),
        });

        Logger.warning('Duplicate address detected for property: $propertyId');
      } else {
        // 중복 없음 → 자동 승인
        verificationStatus = VerificationStatus.autoApproved;
        newStatus = PropertyStatus.active;

        await updateProperty(propertyId, {
          'status': newStatus.toString().split('.').last,
          'verificationStatus': verificationStatus.toString().split('.').last,
          'verificationRequestedAt': now.toIso8601String(),
          'verifiedAt': now.toIso8601String(),
          'verifiedBy': 'auto',
          'isActive': true,
          'updatedAt': now.toIso8601String(),
        });

        // 향후 기능: 자동 승인 시 지역 중개사에게 자동 배포
        // 현재는 수동 배포 방식 사용

        Logger.info('Property auto-approved: $propertyId');
      }

      return verificationStatus;
    } catch (e) {
      Logger.error('Failed to submit for verification', error: e);
      rethrow;
    }
  }

  /// 매물 검증 승인 (관리자용)
  Future<void> approveProperty({
    required String propertyId,
    required String adminId,
  }) async {
    try {
      final now = DateTime.now();

      await updateProperty(propertyId, {
        'status': PropertyStatus.active.toString().split('.').last,
        'verificationStatus': VerificationStatus.adminApproved.toString().split('.').last,
        'verifiedAt': now.toIso8601String(),
        'verifiedBy': adminId,
        'isActive': true,
        'updatedAt': now.toIso8601String(),
      });

      // 향후 기능: 관리자 승인 시 지역 중개사에게 자동 배포
      // 현재는 수동 배포 방식 사용

      Logger.info('Property approved by admin: $propertyId');
    } catch (e) {
      Logger.error('Failed to approve property', error: e);
      rethrow;
    }
  }

  /// 매물 검증 거절 (관리자용)
  Future<void> rejectProperty({
    required String propertyId,
    required String adminId,
    required String reason,
  }) async {
    try {
      final now = DateTime.now();
      final property = await getProperty(propertyId);

      await updateProperty(propertyId, {
        'status': PropertyStatus.rejected.toString().split('.').last,
        'verificationStatus': VerificationStatus.rejected.toString().split('.').last,
        'verifiedAt': now.toIso8601String(),
        'verifiedBy': adminId,
        'rejectionReason': reason,
        'isActive': false,
        'updatedAt': now.toIso8601String(),
      });

      // 매도인에게 거절 알림 전송
      if (property != null) {
        await FirebaseService().sendNotification(
          userId: property.userId,
          title: '매물 등록 거절',
          message: '등록하신 매물이 검증 과정에서 거절되었습니다.\n사유: $reason',
          type: 'property_rejected',
          relatedId: propertyId,
        );
      }

      Logger.info('Property rejected by admin: $propertyId, reason: $reason');
    } catch (e) {
      Logger.error('Failed to reject property', error: e);
      rethrow;
    }
  }

  /// 검증 대기 매물 목록 조회 (관리자용)
  Stream<List<MLSProperty>> getPendingProperties() {
    return _firestore
      .collection(_collectionName)
      .where('status', isEqualTo: PropertyStatus.pending.toString().split('.').last)
      .where('isDeleted', isEqualTo: false)
      .orderBy('createdAt', descending: false) // 오래된 순
      .snapshots()
      .map((snapshot) =>
        snapshot.docs.map((doc) => MLSProperty.fromMap(doc.data())).toList());
  }

  /// 검증 대기 매물 목록 조회 (관리자용) - Future 버전
  Future<List<MLSProperty>> getPendingPropertiesList() async {
    try {
      final snapshot = await _firestore
        .collection(_collectionName)
        .where('status', isEqualTo: PropertyStatus.pending.toString().split('.').last)
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: false)
        .get();

      return snapshot.docs.map((doc) => MLSProperty.fromMap(doc.data())).toList();
    } catch (e) {
      Logger.error('Failed to get pending properties list', error: e);
      rethrow;
    }
  }

  /// 검증 대기 매물 수 조회 (관리자용)
  Future<int> getPendingPropertyCount() async {
    try {
      final snapshot = await _firestore
        .collection(_collectionName)
        .where('status', isEqualTo: PropertyStatus.pending.toString().split('.').last)
        .where('isDeleted', isEqualTo: false)
        .count()
        .get();

      return snapshot.count ?? 0;
    } catch (e) {
      Logger.error('Failed to get pending property count', error: e);
      return 0;
    }
  }

  // ========================================
  // 방문 요청 관리 (VisitRequest CRUD)
  // ========================================

  /// 방문 요청 생성 (중개사가 요청)
  ///
  /// 중개사가 매수/임차 희망자 정보와 희망 방문 일시를 제출합니다.
  /// 생성 시 BrokerResponse의 stage도 'requested'로 업데이트됩니다.
  /// Firestore 트랜잭션으로 동시성 문제를 방지합니다.
  Future<VisitRequest> createVisitRequest({
    required String propertyId,
    required String brokerId,
    required String brokerName,
    required double proposedPrice,
    required DateTime requestedDateTime,
    String? brokerCompany,
    String? brokerPhone,
    String? brokerUid, // Firebase UID (Firestore 규칙용)
    String? message,
  }) async {
    try {
      final docRef = _firestore.collection(_collectionName).doc(propertyId);
      String? sellerUserId;

      final visitRequest = await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          throw Exception('Property not found: $propertyId');
        }

        final property = MLSProperty.fromMap(snapshot.data()!);
        sellerUserId = property.userId;

        // 중복 요청 방지: 같은 중개사의 pending 요청이 있는지 확인
        final existingPending = property.visitRequests.where(
          (r) => r.brokerId == brokerId && r.status == VisitRequestStatus.pending,
        ).toList();

        if (existingPending.isNotEmpty) {
          throw Exception('이미 대기 중인 방문 요청이 있습니다');
        }

        final now = DateTime.now();
        final requestId = 'vr_${now.millisecondsSinceEpoch}_$brokerId';

        final vr = VisitRequest(
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

        // 방문 요청 리스트 업데이트
        final visitRequests = List<VisitRequest>.from(property.visitRequests);
        visitRequests.add(vr);

        // 중개사 응답 상태도 업데이트 (requested 단계로)
        final brokerResponses = Map<String, BrokerResponse>.from(property.brokerResponses);
        final existingResponse = brokerResponses[brokerId];

        brokerResponses[brokerId] = BrokerResponse(
          brokerId: brokerId,
          brokerName: brokerName,
          brokerCompany: brokerCompany ?? existingResponse?.brokerCompany,
          brokerPhone: brokerPhone ?? existingResponse?.brokerPhone,
          stage: BrokerStage.requested,
          receivedAt: existingResponse?.receivedAt ?? now,
          viewedAt: existingResponse?.viewedAt ?? now,
        );

        // targetBrokerIds에 중개사 추가 (내 참여 탭에 표시되도록)
        final targetBrokerIds = List<String>.from(property.targetBrokerIds);
        if (!targetBrokerIds.contains(brokerId)) {
          targetBrokerIds.add(brokerId);
        }
        // Firebase UID도 추가 (Firestore 보안 규칙에서 request.auth.uid로 확인)
        final effectiveUid = brokerUid ?? FirebaseAuth.instance.currentUser?.uid;
        if (effectiveUid != null && !targetBrokerIds.contains(effectiveUid)) {
          targetBrokerIds.add(effectiveUid);
        }

        transaction.update(docRef, {
          'visitRequests': visitRequests.map((e) => e.toMap()).toList(),
          'brokerResponses': brokerResponses.map((k, v) => MapEntry(k, v.toMap())),
          'targetBrokerIds': targetBrokerIds,
          'broadcastedAt': property.broadcastedAt?.toIso8601String() ?? now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        });

        return vr;
      });

      // 트랜잭션 외부: 부작용 (알림, 통계)
      if (sellerUserId != null) {
        await FirebaseService().sendNotification(
          userId: sellerUserId!,
          type: 'visit_request',
          title: '새 방문 요청',
          message: '$brokerName 중개사가 ${_formatPrice(proposedPrice)}에 방문을 요청했습니다.',
          relatedId: propertyId,
        );
      }

      Logger.info('Visit request created: ${visitRequest.id} for property: $propertyId');

      await BrokerStatsService().onVisitRequestCreated(
        brokerId: brokerId,
        brokerName: brokerName,
        brokerCompany: brokerCompany,
      );

      return visitRequest;
    } catch (e) {
      Logger.error('Failed to create visit request', error: e);
      rethrow;
    }
  }

  /// 방문 요청 승인 (판매자가 승인 → 연락처 교환)
  ///
  /// 승인 시 양측의 연락처가 공개됩니다.
  /// BrokerResponse의 stage는 'approved'로 업데이트됩니다.
  /// Firestore 트랜잭션으로 동시성 문제를 방지합니다.
  Future<void> approveVisitRequest({
    required String propertyId,
    required String requestId,
    required String sellerPhone,
    String? sellerMessage,
  }) async {
    try {
      final docRef = _firestore.collection(_collectionName).doc(propertyId);
      String? approvedBrokerId;
      String? propertyUserName;
      DateTime? requestCreatedAt;
      final conflictingBrokerIds = <String>[];

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          throw Exception('Property not found: $propertyId');
        }

        final property = MLSProperty.fromMap(snapshot.data()!);
        propertyUserName = property.userName;

        final visitRequests = List<VisitRequest>.from(property.visitRequests);
        final index = visitRequests.indexWhere((r) => r.id == requestId);
        if (index == -1) {
          throw Exception('Visit request not found: $requestId');
        }

        final request = visitRequests[index];
        approvedBrokerId = request.brokerId;
        requestCreatedAt = request.createdAt;
        final now = DateTime.now();

        // 요청 상태 업데이트
        final updatedRequest = request.copyWith(
          status: VisitRequestStatus.approved,
          respondedAt: now,
          sellerResponse: sellerMessage,
          sellerPhone: sellerPhone, // 판매자 연락처 공개
          contactExchangedAt: now,
        );
        visitRequests[index] = updatedRequest;

        // 중개사 응답 상태 업데이트 (approved 단계 + 연락처 공개)
        final brokerResponses = Map<String, BrokerResponse>.from(property.brokerResponses);
        final existingResponse = brokerResponses[request.brokerId];

        brokerResponses[request.brokerId] = BrokerResponse(
          brokerId: request.brokerId,
          brokerName: request.brokerName,
          brokerCompany: request.brokerCompany ?? existingResponse?.brokerCompany,
          brokerPhone: request.brokerPhone ?? existingResponse?.brokerPhone,
          stage: BrokerStage.approved,
          receivedAt: existingResponse?.receivedAt ?? now,
          viewedAt: existingResponse?.viewedAt ?? now,
        );

        // 같은 시간대 다른 요청 자동 reschedule 처리 (동시성 제어)
        final approvedTime = request.requestedDateTime;

        for (int i = 0; i < visitRequests.length; i++) {
          final visitRequest = visitRequests[i];
          if (visitRequest.id != requestId &&
              visitRequest.status == VisitRequestStatus.pending &&
              _isSameTimeSlot(visitRequest.requestedDateTime, approvedTime)) {
            // 충돌하는 요청을 reschedule 상태로 변경
            visitRequests[i] = visitRequest.copyWith(
              status: VisitRequestStatus.reschedule,
              respondedAt: now,
              sellerResponse: '다른 중개사의 같은 시간 요청이 승인되었습니다. 다른 시간을 선택해 주세요.',
            );
            conflictingBrokerIds.add(visitRequest.brokerId);

            // BrokerResponse stage를 viewed로 변경
            if (brokerResponses.containsKey(visitRequest.brokerId) &&
                brokerResponses[visitRequest.brokerId]!.stage == BrokerStage.requested) {
              brokerResponses[visitRequest.brokerId] = brokerResponses[visitRequest.brokerId]!.copyWith(
                stage: BrokerStage.viewed,
              );
            }
          }
        }

        // 매물 상태도 inquiry로 변경 (첫 승인인 경우)
        final newStatus = property.status == PropertyStatus.active
            ? PropertyStatus.inquiry
            : property.status;

        transaction.update(docRef, {
          'visitRequests': visitRequests.map((e) => e.toMap()).toList(),
          'brokerResponses': brokerResponses.map((k, v) => MapEntry(k, v.toMap())),
          'status': newStatus.toString().split('.').last,
          'updatedAt': DateTime.now().toIso8601String(),
        });
      });

      // 트랜잭션 외부: 부작용 (알림, 통계)
      if (approvedBrokerId != null) {
        await FirebaseService().sendNotification(
          userId: approvedBrokerId!,
          type: 'visit_approved',
          title: '방문 요청 승인',
          message: '${propertyUserName ?? '판매자'}님이 방문 요청을 승인했습니다. 연락처: $sellerPhone',
          relatedId: propertyId,
        );
      }

      for (final brokerId in conflictingBrokerIds) {
        await FirebaseService().sendNotification(
          userId: brokerId,
          type: 'visit_reschedule_needed',
          title: '시간 변경 필요',
          message: '요청하신 시간에 다른 방문이 확정되었습니다. 다른 시간을 선택해 주세요.',
          relatedId: propertyId,
        );
      }

      Logger.info('Visit request approved: $requestId, contact exchanged');

      if (approvedBrokerId != null && requestCreatedAt != null) {
        final responseTimeSeconds = DateTime.now().difference(requestCreatedAt!).inSeconds;
        await BrokerStatsService().onVisitRequestResponded(
          brokerId: approvedBrokerId!,
          approved: true,
          responseTimeSeconds: responseTimeSeconds,
        );
      }
    } catch (e) {
      Logger.error('Failed to approve visit request', error: e);
      rethrow;
    }
  }

  /// 방문 요청 거절 (판매자가 거절)
  /// Firestore 트랜잭션으로 동시성 문제를 방지합니다.
  Future<void> rejectVisitRequest({
    required String propertyId,
    required String requestId,
    String? reason,
  }) async {
    try {
      final docRef = _firestore.collection(_collectionName).doc(propertyId);
      String? rejectedBrokerId;
      String? propertyUserName;
      DateTime? requestCreatedAt;

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          throw Exception('Property not found: $propertyId');
        }

        final property = MLSProperty.fromMap(snapshot.data()!);
        propertyUserName = property.userName;

        final visitRequests = List<VisitRequest>.from(property.visitRequests);
        final index = visitRequests.indexWhere((r) => r.id == requestId);
        if (index == -1) {
          throw Exception('Visit request not found: $requestId');
        }

        final request = visitRequests[index];
        rejectedBrokerId = request.brokerId;
        requestCreatedAt = request.createdAt;
        final now = DateTime.now();

        // 요청 상태 업데이트
        final updatedRequest = request.copyWith(
          status: VisitRequestStatus.rejected,
          respondedAt: now,
          sellerResponse: reason,
        );
        visitRequests[index] = updatedRequest;

        // BrokerResponse stage는 viewed로 유지 (거절해도 다시 요청 가능)
        // 단, hasRequested가 false가 되도록 stage는 viewed로 변경
        final brokerResponses = Map<String, BrokerResponse>.from(property.brokerResponses);
        final existingResponse = brokerResponses[request.brokerId];

        if (existingResponse != null && existingResponse.stage == BrokerStage.requested) {
          brokerResponses[request.brokerId] = existingResponse.copyWith(
            stage: BrokerStage.viewed,
          );
        }

        transaction.update(docRef, {
          'visitRequests': visitRequests.map((e) => e.toMap()).toList(),
          'brokerResponses': brokerResponses.map((k, v) => MapEntry(k, v.toMap())),
          'updatedAt': now.toIso8601String(),
        });
      });

      // 트랜잭션 외부: 부작용 (알림, 통계)
      if (rejectedBrokerId != null) {
        await FirebaseService().sendNotification(
          userId: rejectedBrokerId!,
          type: 'visit_rejected',
          title: '방문 요청 거절',
          message: reason != null
              ? '${propertyUserName ?? '판매자'}님이 방문 요청을 거절했습니다: $reason'
              : '${propertyUserName ?? '판매자'}님이 방문 요청을 거절했습니다.',
          relatedId: propertyId,
        );
      }

      Logger.info('Visit request rejected: $requestId');

      if (rejectedBrokerId != null && requestCreatedAt != null) {
        final responseTimeSeconds = DateTime.now().difference(requestCreatedAt!).inSeconds;
        await BrokerStatsService().onVisitRequestResponded(
          brokerId: rejectedBrokerId!,
          approved: false,
          responseTimeSeconds: responseTimeSeconds,
        );
      }
    } catch (e) {
      Logger.error('Failed to reject visit request', error: e);
      rethrow;
    }
  }

  /// 다른 시간 제안 (판매자가 대안 제시)
  Future<void> suggestAlternativeTime({
    required String propertyId,
    required String requestId,
    required DateTime alternativeDateTime,
    String? message,
  }) async {
    try {
      final property = await getProperty(propertyId);
      if (property == null) {
        throw Exception('Property not found: $propertyId');
      }

      final visitRequests = List<VisitRequest>.from(property.visitRequests);
      final index = visitRequests.indexWhere((r) => r.id == requestId);
      if (index == -1) {
        throw Exception('Visit request not found: $requestId');
      }

      final request = visitRequests[index];
      final now = DateTime.now();

      // 요청 상태 업데이트 (reschedule)
      final updatedRequest = request.copyWith(
        status: VisitRequestStatus.reschedule,
        respondedAt: now,
        sellerResponse: message,
        alternativeDateTime: alternativeDateTime,
      );
      visitRequests[index] = updatedRequest;

      await updateProperty(propertyId, {
        'visitRequests': visitRequests.map((e) => e.toMap()).toList(),
      });

      // 중개사에게 알림 전송
      final dateStr = '${alternativeDateTime.month}/${alternativeDateTime.day} '
          '${alternativeDateTime.hour}:${alternativeDateTime.minute.toString().padLeft(2, '0')}';
      await FirebaseService().sendNotification(
        userId: request.brokerId,
        type: 'visit_reschedule',
        title: '다른 시간 제안',
        message: '${property.userName}님이 $dateStr 시간을 제안했습니다.',
        relatedId: propertyId,
      );

      Logger.info('Alternative time suggested for visit request: $requestId');
    } catch (e) {
      Logger.error('Failed to suggest alternative time', error: e);
      rethrow;
    }
  }

  /// 방문 요청 취소 (중개사가 취소)
  Future<void> cancelVisitRequest({
    required String propertyId,
    required String requestId,
    String? reason,
  }) async {
    try {
      final property = await getProperty(propertyId);
      if (property == null) {
        throw Exception('Property not found: $propertyId');
      }

      final visitRequests = List<VisitRequest>.from(property.visitRequests);
      final index = visitRequests.indexWhere((r) => r.id == requestId);
      if (index == -1) {
        throw Exception('Visit request not found: $requestId');
      }

      final request = visitRequests[index];

      // pending 상태인 경우만 취소 가능
      if (request.status != VisitRequestStatus.pending &&
          request.status != VisitRequestStatus.reschedule) {
        throw Exception('이미 처리된 요청은 취소할 수 없습니다');
      }

      // 요청 상태 업데이트
      final updatedRequest = request.copyWith(
        status: VisitRequestStatus.cancelled,
      );
      visitRequests[index] = updatedRequest;

      // BrokerResponse stage를 viewed로 변경
      final brokerResponses = Map<String, BrokerResponse>.from(property.brokerResponses);
      final existingResponse = brokerResponses[request.brokerId];

      if (existingResponse != null && existingResponse.stage == BrokerStage.requested) {
        brokerResponses[request.brokerId] = existingResponse.copyWith(
          stage: BrokerStage.viewed,
        );
      }

      await updateProperty(propertyId, {
        'visitRequests': visitRequests.map((e) => e.toMap()).toList(),
        'brokerResponses': brokerResponses.map((k, v) => MapEntry(k, v.toMap())),
      });

      // 판매자에게 알림 전송
      await FirebaseService().sendNotification(
        userId: property.userId,
        type: 'visit_cancelled',
        title: '방문 요청 취소',
        message: '${request.brokerName} 중개사가 방문 요청을 취소했습니다.',
        relatedId: propertyId,
      );

      Logger.info('Visit request cancelled: $requestId');

      // 중개사 통계 업데이트 (취소됨)
      await BrokerStatsService().onVisitRequestCancelled(
        brokerId: request.brokerId,
      );
    } catch (e) {
      Logger.error('Failed to cancel visit request', error: e);
      rethrow;
    }
  }

  /// 다른 시간 제안 수락 (중개사가 판매자의 제안 시간 수락)
  Future<void> acceptAlternativeTime({
    required String propertyId,
    required String requestId,
  }) async {
    try {
      final property = await getProperty(propertyId);
      if (property == null) {
        throw Exception('Property not found: $propertyId');
      }

      final visitRequests = List<VisitRequest>.from(property.visitRequests);
      final index = visitRequests.indexWhere((r) => r.id == requestId);
      if (index == -1) {
        throw Exception('Visit request not found: $requestId');
      }

      final request = visitRequests[index];

      if (request.status != VisitRequestStatus.reschedule) {
        throw Exception('시간 조율 상태가 아닙니다');
      }

      if (request.alternativeDateTime == null) {
        throw Exception('제안된 시간이 없습니다');
      }

      // 요청 시간을 제안 시간으로 변경하고 다시 pending으로
      final updatedRequest = request.copyWith(
        requestedDateTime: request.alternativeDateTime,
        status: VisitRequestStatus.pending,
      );
      visitRequests[index] = updatedRequest;

      // BrokerResponse stage를 requested로 유지
      final brokerResponses = Map<String, BrokerResponse>.from(property.brokerResponses);
      final existingResponse = brokerResponses[request.brokerId];

      if (existingResponse != null) {
        brokerResponses[request.brokerId] = existingResponse.copyWith(
          stage: BrokerStage.requested,
        );
      }

      await updateProperty(propertyId, {
        'visitRequests': visitRequests.map((e) => e.toMap()).toList(),
        'brokerResponses': brokerResponses.map((k, v) => MapEntry(k, v.toMap())),
      });

      // 판매자에게 알림 전송
      final dateStr = '${updatedRequest.requestedDateTime.month}/${updatedRequest.requestedDateTime.day}';
      await FirebaseService().sendNotification(
        userId: property.userId,
        type: 'time_accepted',
        title: '시간 제안 수락',
        message: '${request.brokerName} 중개사가 $dateStr 방문 시간에 동의했습니다.',
        relatedId: propertyId,
      );

      Logger.info('Alternative time accepted for visit request: $requestId');
    } catch (e) {
      Logger.error('Failed to accept alternative time', error: e);
      rethrow;
    }
  }

  // ========================================
  // 방문 완료/노쇼 처리 (통계 수집용)
  // ========================================

  /// 방문 완료 처리 (판매자가 확인)
  ///
  /// 승인된 방문 요청에 대해 실제 방문이 완료되었음을 기록합니다.
  Future<void> markVisitCompleted({
    required String propertyId,
    required String requestId,
    String? feedback,
  }) async {
    try {
      final property = await getProperty(propertyId);
      if (property == null) {
        throw Exception('Property not found: $propertyId');
      }

      final visitRequests = List<VisitRequest>.from(property.visitRequests);
      final index = visitRequests.indexWhere((r) => r.id == requestId);
      if (index == -1) {
        throw Exception('Visit request not found: $requestId');
      }

      final request = visitRequests[index];

      if (request.status != VisitRequestStatus.approved) {
        throw Exception('승인된 요청만 방문 완료 처리할 수 있습니다');
      }

      final now = DateTime.now();

      // 요청 상태 업데이트
      final updatedRequest = request.copyWith(
        visitCompletedAt: now,
        noShow: false,
        visitFeedback: feedback,
      );
      visitRequests[index] = updatedRequest;

      await updateProperty(propertyId, {
        'visitRequests': visitRequests.map((e) => e.toMap()).toList(),
      });

      // 중개사 통계 업데이트 (방문 완료)
      await BrokerStatsService().onVisitCompleted(
        brokerId: request.brokerId,
      );

      Logger.info('Visit completed: $requestId');
    } catch (e) {
      Logger.error('Failed to mark visit completed', error: e);
      rethrow;
    }
  }

  /// 노쇼 처리 (판매자가 확인)
  ///
  /// 승인된 방문 요청에 대해 중개사가 나타나지 않았음을 기록합니다.
  Future<void> markVisitNoShow({
    required String propertyId,
    required String requestId,
    String? feedback,
  }) async {
    try {
      final property = await getProperty(propertyId);
      if (property == null) {
        throw Exception('Property not found: $propertyId');
      }

      final visitRequests = List<VisitRequest>.from(property.visitRequests);
      final index = visitRequests.indexWhere((r) => r.id == requestId);
      if (index == -1) {
        throw Exception('Visit request not found: $requestId');
      }

      final request = visitRequests[index];

      if (request.status != VisitRequestStatus.approved) {
        throw Exception('승인된 요청만 노쇼 처리할 수 있습니다');
      }

      final now = DateTime.now();

      // 요청 상태 업데이트
      final updatedRequest = request.copyWith(
        visitCompletedAt: now,
        noShow: true,
        visitFeedback: feedback,
      );
      visitRequests[index] = updatedRequest;

      await updateProperty(propertyId, {
        'visitRequests': visitRequests.map((e) => e.toMap()).toList(),
      });

      // 중개사 통계 업데이트 (노쇼)
      await BrokerStatsService().onNoShow(
        brokerId: request.brokerId,
      );

      // 판매자에게 알림 전송 (노쇼 기록됨)
      await FirebaseService().sendNotification(
        userId: request.brokerId,
        type: 'no_show_recorded',
        title: '노쇼 기록',
        message: '${property.userName}님이 방문 미이행을 기록했습니다.',
        relatedId: propertyId,
      );

      Logger.info('Visit marked as no-show: $requestId');
    } catch (e) {
      Logger.error('Failed to mark visit as no-show', error: e);
      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // 구매자 문의 (BuyerInquiry)
  // ─────────────────────────────────────────────

  static const String _buyerInquiriesCollection = 'buyerInquiries';

  /// 구매자 문의 생성
  ///
  /// 동일 매물에 이미 문의한 경우 중복 생성하지 않고 기존 문의를 반환
  Future<BuyerInquiry> createBuyerInquiry({
    required String propertyId,
    required String buyerMessage,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('로그인이 필요합니다.');

    // 중복 문의 확인
    final existing = await _firestore
        .collection(_buyerInquiriesCollection)
        .where('propertyId', isEqualTo: propertyId)
        .where('buyerUserId', isEqualTo: user.uid)
        .where('status', whereNotIn: ['cancelled', 'completed'])
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      return BuyerInquiry.fromMap(existing.docs.first.data());
    }

    // 사용자 정보 조회
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userName = userDoc.data()?['name'] as String? ?? '구매 희망자';
    final userPhone = userDoc.data()?['phone'] as String?;

    final docRef = _firestore.collection(_buyerInquiriesCollection).doc();
    final now = DateTime.now();
    final inquiry = BuyerInquiry(
      id: docRef.id,
      propertyId: propertyId,
      buyerUserId: user.uid,
      buyerName: userName,
      status: BuyerInquiryStatus.pending,
      createdAt: now,
      buyerPhone: userPhone,
      buyerMessage: buyerMessage.isEmpty ? null : buyerMessage,
    );

    await docRef.set(inquiry.toMap());

    // 매물의 승인된 중개사에게 알림
    await _notifyBrokersOnNewInquiry(propertyId, docRef.id, userName);

    Logger.info('BuyerInquiry created: ${docRef.id}');
    return inquiry;
  }

  /// 신규 구매자 문의 시 해당 매물의 중개사에게 알림
  Future<void> _notifyBrokersOnNewInquiry(
    String propertyId,
    String inquiryId,
    String buyerName,
  ) async {
    try {
      final property = await getProperty(propertyId);
      if (property == null) return;

      // 승인된 중개사 우선, 없으면 방문 요청 중개사에게 알림
      final brokersToNotify = property.brokerResponses.values
          .where((br) =>
              br.stage == BrokerStage.approved ||
              br.stage == BrokerStage.requested)
          .toList();

      for (final broker in brokersToNotify) {
        await FirebaseService().sendNotification(
          userId: broker.brokerId,
          type: 'buyer_inquiry',
          title: '새 구매 관심자',
          message: '$buyerName님이 매물에 관심을 표시했습니다.',
          relatedId: propertyId,
        );
      }
    } catch (e) {
      Logger.error('Failed to notify brokers on new inquiry', error: e);
    }
  }

  /// 내 구매 문의 목록 조회 (구매자용)
  Stream<List<BuyerInquiry>> getMyBuyerInquiries() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection(_buyerInquiriesCollection)
        .where('buyerUserId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => BuyerInquiry.fromMap(d.data())).toList());
  }

  /// 내가 배정된 구매자 리드 목록 (중개사용)
  Stream<List<BuyerInquiry>> getMyBuyerLeads(String brokerId) {
    return _firestore
        .collection(_buyerInquiriesCollection)
        .where('assignedBrokerId', isEqualTo: brokerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => BuyerInquiry.fromMap(d.data())).toList());
  }

  /// 특정 매물의 구매자 문의 목록 (중개사/관리자용)
  Stream<List<BuyerInquiry>> getBuyerInquiriesForProperty(String propertyId) {
    return _firestore
        .collection(_buyerInquiriesCollection)
        .where('propertyId', isEqualTo: propertyId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => BuyerInquiry.fromMap(d.data())).toList());
  }

  /// 특정 매물에 이미 문의했는지 확인
  Future<bool> hasExistingInquiry(String propertyId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final snap = await _firestore
        .collection(_buyerInquiriesCollection)
        .where('propertyId', isEqualTo: propertyId)
        .where('buyerUserId', isEqualTo: user.uid)
        .where('status', whereNotIn: ['cancelled', 'completed'])
        .limit(1)
        .get();

    return snap.docs.isNotEmpty;
  }

  /// 문의 취소
  Future<void> cancelBuyerInquiry(String inquiryId) async {
    await _firestore
        .collection(_buyerInquiriesCollection)
        .doc(inquiryId)
        .update({'status': 'cancelled'});
  }
}
