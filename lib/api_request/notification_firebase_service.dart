import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:property/models/notification_model.dart';

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
    } catch (_) {
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
          .update({'isRead': true});
      return true;
    } catch (_) {
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
    } catch (_) {
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
  Future<void> sendBulkNotifications({
    required List<String> userIds,
    required String title,
    required String message,
    required String type,
    String? relatedId,
    Map<String, dynamic>? additionalData,
  }) async {
    final batch = _firestore.batch();
    for (final userId in userIds) {
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
    await batch.commit();
  }
}
