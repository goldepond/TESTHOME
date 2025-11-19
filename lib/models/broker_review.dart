import 'package:cloud_firestore/cloud_firestore.dart';

/// 공인중개사 후기 / 추천 정보 모델
class BrokerReview {
  final String id;
  final String brokerRegistrationNumber; // 공인중개사 등록번호
  final String userId;                   // 작성자 uid
  final String userName;                 // 작성자 이름
  final String quoteRequestId;           // 어떤 견적에 대한 후기인지
  final int rating;                      // 1~5점
  final bool recommend;                  // 추천(true) / 비추천(false)
  final String? comment;                 // 텍스트 후기
  final DateTime createdAt;
  final DateTime? updatedAt;

  BrokerReview({
    required this.id,
    required this.brokerRegistrationNumber,
    required this.userId,
    required this.userName,
    required this.quoteRequestId,
    required this.rating,
    required this.recommend,
    this.comment,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'brokerRegistrationNumber': brokerRegistrationNumber,
      'userId': userId,
      'userName': userName,
      'quoteRequestId': quoteRequestId,
      'rating': rating,
      'recommend': recommend,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory BrokerReview.fromMap(String id, Map<String, dynamic> map) {
    return BrokerReview(
      id: id,
      brokerRegistrationNumber: (map['brokerRegistrationNumber'] ?? '') as String,
      userId: (map['userId'] ?? '') as String,
      userName: (map['userName'] ?? '') as String,
      quoteRequestId: (map['quoteRequestId'] ?? '') as String,
      rating: (map['rating'] ?? 0) as int,
      recommend: (map['recommend'] ?? false) as bool,
      comment: map['comment'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}


