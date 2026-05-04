import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:property/models/broker_eligibility.dart';
import 'package:property/models/priority_grant.dart';
import 'package:property/utils/cloud_functions_guard.dart';
import 'package:property/utils/logger.dart';

/// `createBuyerMatchGrant` callable 결과의 타입 안전 래퍼.
///
/// Backend가 돌려주는 형식:
///   { grantId, expiresAt: millis, score, switched, previousGrantId? }
class BuyerMatchGrantResult {
  final String grantId;
  final DateTime expiresAt;
  final double score;
  final bool switched;
  final String? previousGrantId;

  const BuyerMatchGrantResult({
    required this.grantId,
    required this.expiresAt,
    required this.score,
    required this.switched,
    this.previousGrantId,
  });

  factory BuyerMatchGrantResult.fromMap(Map<String, dynamic> map) {
    final dynamic rawExpires = map['expiresAt'];
    final DateTime expires = rawExpires is int
        ? DateTime.fromMillisecondsSinceEpoch(rawExpires)
        : (rawExpires is double
            ? DateTime.fromMillisecondsSinceEpoch(rawExpires.toInt())
            : DateTime.now());
    final dynamic rawScore = map['score'];
    final double score = rawScore is num ? rawScore.toDouble() : 0.0;
    return BuyerMatchGrantResult(
      grantId: map['grantId'] as String? ?? '',
      expiresAt: expires,
      score: score,
      switched: map['switched'] == true,
      previousGrantId: map['previousGrantId'] as String?,
    );
  }
}

/// 우선권 부여 원장 클라이언트 서비스
///
/// **읽기 전용 클라이언트** — 우선권 생성/만료/취소는 Cloud Functions만 수행한다.
/// 클라이언트는 watch 스트림으로 구독하고, callable로 Functions를 호출한다.
class PriorityGrantService {
  // 싱글톤 패턴
  static final PriorityGrantService _instance =
      PriorityGrantService._internal();
  factory PriorityGrantService() => _instance;
  PriorityGrantService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Cloud Functions 리전 — functions/index.js의 onCall 설정과 일치해야 한다.
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  static const String _grantsCollection = 'priority_grants';
  static const String _eligibilityCollection = 'broker_eligibility';
  static const String _appealsCollection = 'priority_appeals';

  // ----------------- 스트림 -----------------

  /// 특정 매물의 우선권 목록 (최신순).
  ///
  /// firestore.rules priority_grants read 는 sellerUid 또는 brokerUid 가
  /// auth.uid 와 일치해야 한다. 단순 propertyId 필터만으로는 Firestore 가
  /// 안전성을 정적으로 증명할 수 없어 권한 외 사용자에게 PERMISSION_DENIED 가
  /// 떨어진다 — 이 경우 빈 리스트로 graceful degrade 한다.
  Stream<List<PriorityGrant>> watchByProperty(String propertyId) {
    return _firestore
        .collection(_grantsCollection)
        .where('propertyId', isEqualTo: propertyId)
        .orderBy('grantedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PriorityGrant.fromFirestore(doc))
              .toList(),
        )
        .handleError((Object error, StackTrace stack) {
          // 권한 거부는 일반/매수자 사용자에서 의도된 결과 — 로그 noise 회피
          if (_isPermissionDenied(error)) return;
          Logger.warning(
            'watchByProperty stream error',
            metadata: {
              'propertyId': propertyId,
              'error': error.toString(),
            },
          );
        });
  }

  /// 특정 중개사의 활성 우선권 목록 (최신순).
  ///
  /// firestore.rules 가 brokerUid == auth.uid 로 read 권한을 결정하므로
  /// 쿼리도 brokerUid 필드를 사용해야 PERMISSION_DENIED 를 회피한다.
  Stream<List<PriorityGrant>> watchByBroker(String brokerUid) {
    return _firestore
        .collection(_grantsCollection)
        .where('brokerUid', isEqualTo: brokerUid)
        .where('status', isEqualTo: 'active')
        .orderBy('grantedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PriorityGrant.fromFirestore(doc))
              .toList(),
        )
        .handleError((Object error, StackTrace stack) {
          if (_isPermissionDenied(error)) return;
          Logger.warning(
            'watchByBroker stream error',
            metadata: {
              'brokerUid': brokerUid,
              'error': error.toString(),
            },
          );
        });
  }

  /// 특정 매도자가 소유한 매물의 활성 우선권 목록 (최신순).
  ///
  /// Problem 004 — 매도자 측 이의 제기 진입점에서 사용.
  /// firestore.rules priority_grants read 가 sellerUid == auth.uid 도 허용하므로
  /// sellerUid 필드 단일 조건으로 안전 조회. status == 'active' 필터로 만료/취소
  /// grant 는 제외 (이의 제기 대상은 살아있는 차례에 한정).
  /// 인덱스: (sellerUid ASC, status ASC, grantedAt DESC) — firestore.indexes.json 추가됨.
  Stream<List<PriorityGrant>> watchBySeller(String sellerUid) {
    return _firestore
        .collection(_grantsCollection)
        .where('sellerUid', isEqualTo: sellerUid)
        .where('status', isEqualTo: 'active')
        .orderBy('grantedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PriorityGrant.fromFirestore(doc))
              .toList(),
        )
        .handleError((Object error, StackTrace stack) {
          if (_isPermissionDenied(error)) return;
          Logger.warning(
            'watchBySeller stream error',
            metadata: {
              'sellerUid': sellerUid,
              'error': error.toString(),
            },
          );
        });
  }

  static bool _isPermissionDenied(Object error) {
    if (error is FirebaseException) {
      return error.code == 'permission-denied';
    }
    return error.toString().contains('permission-denied');
  }

  // ----------------- Functions 호출 -----------------

  /// Cloud Function `issuePriorityGrant`를 호출해 우선권 발급을 요청한다.
  ///
  /// 자격·5개 한도·중복 검증은 서버에서 수행한다 (Rules `allow create: if false`).
  /// [stage]는 'participation' / 'visit' / 'offer' 중 하나 (Backend 필수 인자).
  /// 반환은 함수가 돌려준 임의 데이터 맵 (예: { grantId, expiresAt, ... }).
  Future<Map<String, dynamic>> requestGrantViaFunction({
    required String propertyId,
    required String brokerId,
    required String type,
    required String stage,
    String? buyerInquiryId,
  }) async {
    // backend 의 issuePriorityGrant 는 brokerId 를 broker_eligibility doc id
    // 로 사용하며 doc id 는 *반드시 auth UID* 다. caller 가 email 또는 login id
    // 를 넘기더라도 자동으로 auth UID 로 보정한다.
    final String? authUid = FirebaseAuth.instance.currentUser?.uid;
    final String resolvedBrokerId =
        (authUid != null && authUid.isNotEmpty) ? authUid : brokerId;

    try {
      final callable = _functions.httpsCallable('issuePriorityGrant');
      final result = await callable.call<Map<dynamic, dynamic>>({
        'propertyId': propertyId,
        'brokerId': resolvedBrokerId,
        'type': type,
        'stage': stage,
        if (buyerInquiryId != null) 'buyerInquiryId': buyerInquiryId,
      });
      // FirebaseFunctions는 Map<dynamic, dynamic>으로 반환하므로 String 키로 변환한다.
      return Map<String, dynamic>.from(result.data);
    } catch (e, stack) {
      Logger.error(
        'issuePriorityGrant function call failed',
        error: e,
        stackTrace: stack,
        context: 'PriorityGrantService',
        metadata: {
          'propertyId': propertyId,
          'brokerId': resolvedBrokerId,
          'type': type,
          'stage': stage,
        },
      );
      // problem 002 재발 방지 가드 — NOT_FOUND/UNAVAILABLE/UNAUTHENTICATED 만
      // 사용자 친화 카피로 변환. 도메인 에러(cap_exceeded 등)는 그대로 통과.
      CloudFunctionsGuard.throwAsUserFacing(
        e,
        stack,
        functionName: 'issuePriorityGrant',
      );
    }
  }

  /// 우선권에 대한 이의 제기를 등록한다.
  ///
  /// `priority_appeals` 컬렉션에 클라이언트가 직접 create한다 (Rules가 본인 + status=open만 허용).
  /// 반환은 새로 생성된 doc id.
  Future<String> fileAppeal({
    required String grantId,
    required String reason,
  }) async {
    try {
      // 클라이언트에서 사유 길이 가드 — Rules도 별도 검증하지만 UX상 미리 차단한다.
      if (reason.length > 1000) {
        throw ArgumentError('reason은 최대 1000자까지 허용된다');
      }

      // Rules가 filerUid == request.auth.uid를 강제하므로 currentUser uid를 자동 주입.
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid == null || currentUid.isEmpty) {
        throw StateError('이의 제기는 로그인 상태에서만 가능합니다');
      }

      final docRef = _firestore.collection(_appealsCollection).doc();
      final now = DateTime.now();

      await docRef.set({
        'appealId': docRef.id,
        'filerUid': currentUid,
        'grantId': grantId,
        'reason': reason,
        'status': 'open',
        'createdAt': now.toIso8601String(),
      });

      Logger.info(
        'priority appeal filed',
        metadata: {'appealId': docRef.id, 'grantId': grantId},
      );
      return docRef.id;
    } catch (e, stack) {
      Logger.error(
        'fileAppeal failed',
        error: e,
        stackTrace: stack,
        context: 'PriorityGrantService',
        metadata: {'grantId': grantId},
      );
      rethrow;
    }
  }

  // ----------------- 자격 조회 -----------------

  /// 특정 시군구 관할에서 자격을 보유한 중개사 목록.
  ///
  /// `licenseStatus = 'verified'` AND `jurisdictions arrayContains jurisdiction`은
  /// Firestore 쿼리로 처리하지만, `activeGrantsCount < activeGrantsCap` 비교는
  /// Firestore가 두 필드 간 비교 연산을 지원하지 않으므로 **클라이언트 필터링**으로 처리한다.
  Future<List<BrokerEligibility>> listEligibleBrokers({
    required String jurisdiction,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_eligibilityCollection)
          .where('licenseStatus', isEqualTo: 'verified')
          .where('jurisdictions', arrayContains: jurisdiction)
          .get();

      final all = snapshot.docs
          .map((doc) => BrokerEligibility.fromFirestore(doc))
          .toList();

      // cap 비교는 Firestore에서 두 필드 간 연산이 불가능 → 클라이언트 fallback.
      return all.where((b) => b.activeGrantsCount < b.activeGrantsCap).toList();
    } catch (e, stack) {
      Logger.error(
        'listEligibleBrokers failed',
        error: e,
        stackTrace: stack,
        context: 'PriorityGrantService',
        metadata: {'jurisdiction': jurisdiction},
      );
      rethrow;
    }
  }

  /// Cloud Function `createBuyerMatchGrant`을 호출해 매수자측 buyer_match grant를 발급한다.
  ///
  /// **호출자는 매수자**(buyerInquiry.buyerUserId === caller uid)이어야 한다.
  /// [confirmSwitch]가 false인데 동일 inquiry에 다른 활성 grant가 있으면
  /// `BUYER_SWITCH_REQUIRED` 사유로 거절되어, 클라이언트가 매수자 동의를 받은 뒤
  /// `confirmSwitch=true`로 재호출한다 (24h 쿨다운이 추가 적용).
  ///
  /// 반환: { grantId, expiresAt, score, switched, previousGrantId? }
  Future<BuyerMatchGrantResult> requestBuyerMatchGrantViaFunction({
    required String propertyId,
    required String brokerId,
    required String buyerInquiryId,
    bool confirmSwitch = false,
  }) async {
    try {
      final callable = _functions.httpsCallable('createBuyerMatchGrant');
      final result = await callable.call<Map<dynamic, dynamic>>({
        'propertyId': propertyId,
        'brokerId': brokerId,
        'buyerInquiryId': buyerInquiryId,
        'confirmSwitch': confirmSwitch,
      });
      final Map<String, dynamic> data = Map<String, dynamic>.from(result.data);
      return BuyerMatchGrantResult.fromMap(data);
    } catch (e, stack) {
      Logger.error(
        'createBuyerMatchGrant function call failed',
        error: e,
        stackTrace: stack,
        context: 'PriorityGrantService',
        metadata: <String, dynamic>{
          'propertyId': propertyId,
          'brokerId': brokerId,
          'buyerInquiryId': buyerInquiryId,
          'confirmSwitch': confirmSwitch,
        },
      );
      CloudFunctionsGuard.throwAsUserFacing(
        e,
        stack,
        functionName: 'createBuyerMatchGrant',
      );
    }
  }

  /// 특정 inquiry에 대한 활성 buyer_match grant 1건을 가져온다 (없으면 null).
  Future<PriorityGrant?> getActiveBuyerMatchGrant(String buyerInquiryId) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection(_grantsCollection)
          .where('buyerInquiryId', isEqualTo: buyerInquiryId)
          .where('type', isEqualTo: 'buyer_match')
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      return PriorityGrant.fromFirestore(snapshot.docs.first);
    } catch (e, stack) {
      Logger.error(
        'getActiveBuyerMatchGrant failed',
        error: e,
        stackTrace: stack,
        context: 'PriorityGrantService',
        metadata: <String, dynamic>{'buyerInquiryId': buyerInquiryId},
      );
      return null;
    }
  }

  /// 특정 매수자(uid)의 활성 buyer_match grant 목록 (대시보드/마이페이지용).
  Stream<List<PriorityGrant>> watchActiveBuyerMatchByBroker(String brokerUid) {
    return _firestore
        .collection(_grantsCollection)
        .where('brokerUid', isEqualTo: brokerUid)
        .where('type', isEqualTo: 'buyer_match')
        .where('status', isEqualTo: 'active')
        .orderBy('grantedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PriorityGrant.fromFirestore(doc))
              .toList(),
        )
        .handleError((Object error, StackTrace stack) {
          Logger.error(
            'watchActiveBuyerMatchByBroker stream error',
            error: error,
            stackTrace: stack,
            context: 'PriorityGrantService',
            metadata: <String, dynamic>{'brokerUid': brokerUid},
          );
        });
  }

  /// P1-20: Cloud Function `fulfillGrant`을 호출해 거래 성사로 grant를 종결한다.
  ///
  /// 매도자 본인 또는 admin만 호출 가능 (P1-4 fulfillGrant callable 구현).
  /// 호출 시 grant.{status='fulfilled', fulfilledAt, fulfillmentSource='manual', contractId?} 갱신 +
  /// broker_eligibility.activeGrantsCount -= 1 + audit log 'grant_fulfilled' 1:1 기록.
  /// 반환: { grantId, fulfilledAt }
  Future<Map<String, dynamic>> fulfillGrantViaFunction({
    required String grantId,
    String? contractId,
  }) async {
    try {
      final callable = _functions.httpsCallable('fulfillGrant');
      final result = await callable.call<Map<dynamic, dynamic>>({
        'grantId': grantId,
        if (contractId != null) 'contractId': contractId,
      });
      return Map<String, dynamic>.from(result.data);
    } catch (e, stack) {
      Logger.error(
        'fulfillGrant function call failed',
        error: e,
        stackTrace: stack,
        context: 'PriorityGrantService',
        metadata: {'grantId': grantId},
      );
      CloudFunctionsGuard.throwAsUserFacing(
        e,
        stack,
        functionName: 'fulfillGrant',
      );
    }
  }

  /// Cloud Function `revokeOwnGrant`을 호출해 본인 명의 grant를 자진 만료한다.
  ///
  /// 24시간 쿨다운이 적용된다 (grant.revokeCooldownUntil).
  /// 반환은 함수가 돌려준 데이터 맵 (예: { grantId, revokedAt, revokeCooldownUntil }).
  Future<Map<String, dynamic>> revokeOwnGrantViaFunction(String grantId) async {
    try {
      final callable = _functions.httpsCallable('revokeOwnGrant');
      final result = await callable.call<Map<dynamic, dynamic>>({
        'grantId': grantId,
      });
      return Map<String, dynamic>.from(result.data);
    } catch (e, stack) {
      Logger.error(
        'revokeOwnGrant function call failed',
        error: e,
        stackTrace: stack,
        context: 'PriorityGrantService',
        metadata: {'grantId': grantId},
      );
      CloudFunctionsGuard.throwAsUserFacing(
        e,
        stack,
        functionName: 'revokeOwnGrant',
      );
    }
  }
}
