import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:property/models/priority_appeal.dart';
import 'package:property/utils/logger.dart';

/// 우선권 이의 제기 클라이언트 서비스 (Task 06).
///
/// **클라가 직접 `priority_appeals` 컬렉션에 create**한다.
/// Rules가 `filerUid == request.auth.uid` + `status == 'open'` 만 허용.
/// Backend 트리거 `onPriorityAppealCreated`가 자동 replay 후
/// [PriorityAppeal.replayedDecision] 필드를 비동기로 채운다.
///
/// 본 서비스는 *읽기 + create*만 담당한다 — 상태 갱신·해결은 관리자 callable 전용.
class PriorityAppealService {
  // 싱글톤 패턴 (다른 priority 서비스들과 동일 컨벤션)
  static final PriorityAppealService _instance =
      PriorityAppealService._internal();
  factory PriorityAppealService() => _instance;
  PriorityAppealService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _collection = 'priority_appeals';

  /// 이의 제기 신청. 클라가 직접 `priority_appeals` 컬렉션에 create.
  ///
  /// 자동 트리거가 `replayedDecision` 필드를 비동기로 채운다.
  /// `reason` 1~1000자 검증 — 위반 시 [ArgumentError].
  /// 비로그인 상태 호출 시 [StateError].
  ///
  /// P1-12 / P1-21.1 — 카테고리 분기:
  /// * `grantDecision`(기본) / `other`: `grantId` 필수.
  /// * `listingModeDispute`: `propertyId` 필수, `grantId` 부재 허용.
  Future<String> fileAppeal({
    required String grantId,
    required String reason,
    AppealCategory appealCategory = AppealCategory.grantDecision,
    String? propertyId,
  }) async {
    final String trimmed = reason.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('이유를 1자 이상 적어주세요');
    }
    if (trimmed.length > PriorityAppeal.maxReasonLength) {
      throw ArgumentError(
        '이유는 최대 ${PriorityAppeal.maxReasonLength}자까지 적을 수 있어요',
      );
    }

    final bool isModeDispute =
        appealCategory == AppealCategory.listingModeDispute;
    final String? trimmedPropertyId = propertyId?.trim();

    if (isModeDispute) {
      if (trimmedPropertyId == null || trimmedPropertyId.isEmpty) {
        throw ArgumentError('어느 매물에 대한 분쟁인지 골라주세요');
      }
    } else if (grantId.isEmpty) {
      throw ArgumentError('어느 매물 차례에 대해 신청할지 골라주세요');
    }

    final String? currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null || currentUid.isEmpty) {
      throw StateError('로그인 후에 신청할 수 있어요');
    }

    try {
      final DocumentReference<Map<String, dynamic>> docRef =
          _firestore.collection(_collection).doc();

      final Map<String, dynamic> payload = <String, dynamic>{
        'appealId': docRef.id,
        'filerUid': currentUid,
        'grantId': isModeDispute ? '' : grantId,
        'appealCategory': appealCategory.wireName,
        'reason': trimmed,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      };
      if (trimmedPropertyId != null && trimmedPropertyId.isNotEmpty) {
        payload['propertyId'] = trimmedPropertyId;
      }

      await docRef.set(payload);

      Logger.info(
        'priority appeal filed',
        metadata: <String, dynamic>{
          'appealId': docRef.id,
          'grantId': grantId,
          'appealCategory': appealCategory.wireName,
          'propertyId': trimmedPropertyId,
        },
      );
      return docRef.id;
    } catch (e, stack) {
      Logger.error(
        'fileAppeal failed',
        error: e,
        stackTrace: stack,
        context: 'PriorityAppealService',
        metadata: <String, dynamic>{
          'grantId': grantId,
          'appealCategory': appealCategory.wireName,
          'propertyId': trimmedPropertyId,
        },
      );
      rethrow;
    }
  }

  /// 본인 이의 제기 목록 (createdAt DESC) 스트림.
  ///
  /// 비로그인 시 빈 스트림. 인덱스: `(filerUid ASC, createdAt DESC)`.
  Stream<List<PriorityAppeal>> watchMyAppeals() {
    final String? currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null || currentUid.isEmpty) {
      return Stream<List<PriorityAppeal>>.value(const <PriorityAppeal>[]);
    }
    return _firestore
        .collection(_collection)
        .where('filerUid', isEqualTo: currentUid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snapshot) => snapshot.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                    PriorityAppeal.fromFirestore(doc),
              )
              .toList(),
        )
        .handleError((Object error, StackTrace stack) {
          Logger.error(
            'watchMyAppeals stream error',
            error: error,
            stackTrace: stack,
            context: 'PriorityAppealService',
            metadata: <String, dynamic>{'filerUid': currentUid},
          );
        });
  }

  /// 단일 이의 제기 watch — `replayedDecision` 채워질 때까지 갱신 수신.
  Stream<PriorityAppeal?> watchAppeal(String appealId) {
    if (appealId.isEmpty) {
      return Stream<PriorityAppeal?>.value(null);
    }
    return _firestore
        .collection(_collection)
        .doc(appealId)
        .snapshots()
        .map(
          (DocumentSnapshot<Map<String, dynamic>> snap) =>
              snap.exists ? PriorityAppeal.fromFirestore(snap) : null,
        )
        .handleError((Object error, StackTrace stack) {
          Logger.error(
            'watchAppeal stream error',
            error: error,
            stackTrace: stack,
            context: 'PriorityAppealService',
            metadata: <String, dynamic>{'appealId': appealId},
          );
        });
  }
}
