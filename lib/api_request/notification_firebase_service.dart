import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:property/models/notification_model.dart';
import 'package:property/utils/logger.dart';

/// 알림(Notification) 전용 Firebase 서비스
///
/// [FirebaseService]의 알림 관련 메서드를 위임받아 처리합니다.
/// 직접 사용하려면 `NotificationFirebaseService()` 싱글톤을 사용하세요.
/// 기존 코드와의 호환성을 위해 [FirebaseService]도 동일한 시그니처를 유지합니다.
class NotificationFirebaseService {
  static final NotificationFirebaseService _instance =
      NotificationFirebaseService._internal();
  factory NotificationFirebaseService() => _instance;
  NotificationFirebaseService._internal();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  static const String _collection = 'notifications';

  /// 단일 알림 전송
  Future<bool> sendNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
    String? relatedId,
  }) async {
    try {
      await _firestore.collection(_collection).add({
        'userId': userId,
        'title': title,
        'message': message,
        'type': type,
        'relatedId': relatedId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      Logger.error('[Notification] 알림 전송 실패', error: e);
      return false;
    }
  }

  /// 사용자 알림 목록 조회 (실시간 스트림)
  Stream<List<NotificationModel>> getUserNotifications(String userId) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NotificationModel.fromMap(doc.id, doc.data()))
            .toList());
  }

  /// 알림 읽음 처리
  Future<bool> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(notificationId)
          .set({'isRead': true}, SetOptions(merge: true));
      return true;
    } catch (e) {
      Logger.error('[Notification] 알림 읽음 처리 실패', error: e);
      return false;
    }
  }

  /// 모든 알림 읽음 처리
  Future<bool> markAllNotificationsAsRead(String userId) async {
    try {
      final batch = _firestore.batch();
      final snapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
      return true;
    } catch (e) {
      Logger.error('[Notification] 전체 알림 읽음 처리 실패', error: e);
      return false;
    }
  }

  /// 읽지 않은 알림 개수 조회 (실시간 스트림)
  Stream<int> getUnreadNotificationCount(String userId) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// 대량 알림 전송
  ///
  /// Firestore 배치는 500건 제한이 있으므로 499건씩 분할 커밋한다.
  /// 반환값: 성공/실패 건수.
  Future<({int succeeded, int failed})> sendBulkNotifications({
    required List<String> userIds,
    required String title,
    required String message,
    required String type,
    String? relatedId,
    Map<String, dynamic>? additionalData,
  }) async {
    const batchLimit = 499;
    int succeeded = 0;
    int failed = 0;

    for (int i = 0; i < userIds.length; i += batchLimit) {
      final chunk = userIds.sublist(
        i,
        (i + batchLimit > userIds.length) ? userIds.length : i + batchLimit,
      );
      final batch = _firestore.batch();
      for (final userId in chunk) {
        final docRef = _firestore.collection(_collection).doc();
        final notificationData = <String, dynamic>{
          'userId': userId,
          'title': title,
          'message': message,
          'type': type,
          'relatedId': relatedId,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        };
        if (additionalData != null) {
          notificationData['additionalData'] = additionalData;
        }
        batch.set(docRef, notificationData);
      }
      try {
        await batch.commit();
        succeeded += chunk.length;
      } catch (e) {
        Logger.error(
          '[Notification] 벌크 알림 배치 커밋 실패 (${chunk.length}건)',
          error: e,
        );
        failed += chunk.length;
      }
    }

    if (failed > 0) {
      Logger.warning(
        '[Notification] 벌크 알림 결과: 성공 $succeeded건, 실패 $failed건',
      );
    }

    return (succeeded: succeeded, failed: failed);
  }
}
