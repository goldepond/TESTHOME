import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// 견적문의 모델
class QuoteRequest {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String brokerName;
  final String? brokerRegistrationNumber;
  final String? brokerRoadAddress;
  final String? brokerJibunAddress;
  final String? brokerEmail; // Admin이 나중에 추가하는 필드
  final String message;
  final String status; // pending, contacted, completed, cancelled
  final DateTime requestDate;
  final DateTime? emailAttachedAt;
  final String? emailAttachedBy;
  final DateTime? updatedAt;

  QuoteRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.brokerName,
    this.brokerRegistrationNumber,
    this.brokerRoadAddress,
    this.brokerJibunAddress,
    this.brokerEmail,
    required this.message,
    required this.status,
    required this.requestDate,
    this.emailAttachedAt,
    this.emailAttachedBy,
    this.updatedAt,
  });

  /// Firestore 문서로 변환
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'brokerName': brokerName,
      'brokerRegistrationNumber': brokerRegistrationNumber,
      'brokerRoadAddress': brokerRoadAddress,
      'brokerJibunAddress': brokerJibunAddress,
      'brokerEmail': brokerEmail,
      'message': message,
      'status': status,
      'requestDate': Timestamp.fromDate(requestDate),
      'emailAttachedAt': emailAttachedAt != null ? Timestamp.fromDate(emailAttachedAt!) : null,
      'emailAttachedBy': emailAttachedBy,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  /// Firestore 문서에서 생성
  factory QuoteRequest.fromMap(String id, Map<String, dynamic> map) {
    return QuoteRequest(
      id: id,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userEmail: map['userEmail'] ?? '',
      brokerName: map['brokerName'] ?? '',
      brokerRegistrationNumber: map['brokerRegistrationNumber'],
      brokerRoadAddress: map['brokerRoadAddress'],
      brokerJibunAddress: map['brokerJibunAddress'],
      brokerEmail: map['brokerEmail'],
      message: map['message'] ?? '',
      status: map['status'] ?? 'pending',
      requestDate: (map['requestDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      emailAttachedAt: (map['emailAttachedAt'] as Timestamp?)?.toDate(),
      emailAttachedBy: map['emailAttachedBy'],
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// 상태 텍스트 반환
  String get statusText {
    switch (status) {
      case 'pending':
        return '대기중';
      case 'contacted':
        return '연락완료';
      case 'completed':
        return '완료';
      case 'cancelled':
        return '취소됨';
      default:
        return status;
    }
  }

  /// 상태 색상 반환
  static Color getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFFFA726); // 주황색
      case 'contacted':
        return const Color(0xFF42A5F5); // 파란색
      case 'completed':
        return const Color(0xFF66BB6A); // 초록색
      case 'cancelled':
        return const Color(0xFFEF5350); // 빨간색
      default:
        return const Color(0xFF9E9E9E); // 회색
    }
  }
}

