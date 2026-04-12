import 'package:cloud_firestore/cloud_firestore.dart';

/// 알림 타입 상수
class NotificationType {
  static const String quoteReceived = 'quote_received';
  static const String quoteAnswered = 'quote_answered';
  static const String brokerSelected = 'broker_selected';
  static const String propertyRegistered = 'property_registered';
  static const String info = 'info';

  // MLS 거래 관련 알림
  static const String propertyDepositTaken = 'property_deposit_taken';
  static const String propertySold = 'property_sold';
  static const String propertyExpired = 'property_expired';
  static const String competitorAdvanced = 'competitor_advanced';
  static const String visitScheduleApproved = 'visit_schedule_approved';
  static const String visitScheduleRejected = 'visit_schedule_rejected';

  // 매물 검증 관련
  static const String propertyApproved = 'property_approved';
  static const String propertyRejected = 'property_rejected';
  static const String propertyDeleted = 'property_deleted';
  static const String propertyCancelled = 'property_cancelled';

  // 방문 요청 관련
  static const String visitRequest = 'visit_request';
  static const String visitApproved = 'visit_approved';
  static const String visitRejected = 'visit_rejected';
  static const String visitConfirmed = 'visit_confirmed';
  static const String visitCancelled = 'visit_cancelled';
  static const String visitReschedule = 'visit_reschedule';
  static const String visitRescheduleNeeded = 'visit_reschedule_needed';

  // 협상 관련
  static const String counterOffer = 'counter_offer';
  static const String negotiationStarted = 'negotiation_started';

  // 구매자 문의
  static const String buyerInquiry = 'buyer_inquiry';
  static const String buyerInquiryCancelled = 'buyer_inquiry_cancelled';

  // 중개 제안
  static const String brokerOffer = 'broker_offer';

  // 중개사 인증
  static const String brokerVerified = 'broker_verified';
  static const String brokerUnverified = 'broker_unverified';

  // 상태 변경 알림
  static const String statusChangedToInquiry = 'status_changed_inquiry';
  static const String statusChangedToUnderOffer = 'status_changed_under_offer';
}

class NotificationModel {
  final String id;
  final String userId; // 알림 받는 사람
  final String title;
  final String message;
  final String type; // 'quote_received', 'quote_selected', 'property_registered' 등
  final String? relatedId; // 관련된 ID (견적ID, 매물ID 등)
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt, this.relatedId,
    this.isRead = false,
  });

  factory NotificationModel.fromMap(String id, Map<String, dynamic> map) {
    return NotificationModel(
      id: id,
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      type: map['type'] ?? 'info',
      relatedId: map['relatedId'],
      isRead: map['isRead'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'message': message,
      'type': type,
      'relatedId': relatedId,
      'isRead': isRead,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

