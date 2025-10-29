import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// 견적문의 모델 (매도자 입찰카드)
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
  
  // ========== 1️⃣ 기본정보 (자동 입력) ==========
  final String? propertyType;        // 매물 유형 (아파트/오피스텔/원룸)
  final String? propertyAddress;     // 위치
  final String? propertyArea;        // 전용면적 (㎡)
  
  // ========== 2️⃣ 중개 제안 (중개업자 입력) ==========
  final String? recommendedPrice;    // 권장 매도가
  final String? minimumPrice;        // 최저수락가
  final String? expectedDuration;    // 예상 거래기간
  final String? promotionMethod;     // 홍보 방법
  final String? commissionRate;      // 수수료 제안율
  final String? recentCases;         // 최근 유사 거래 사례
  
  // ========== 3️⃣ 특이사항 (판매자 입력) ==========
  final bool? hasTenant;             // 세입자 여부
  final String? desiredPrice;        // 희망가
  final String? targetPeriod;        // 목표기간
  final String? specialNotes;        // 특이사항
  
  // ========== 4️⃣ 중개업자 답변 ==========
  final String? brokerAnswer;        // 공인중개사 답변
  final DateTime? answerDate;        // 답변 일시
  final String? inquiryLinkId;       // 고유 링크 ID (이메일용)

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
    // 1️⃣ 기본정보
    this.propertyType,
    this.propertyAddress,
    this.propertyArea,
    // 2️⃣ 중개 제안
    this.recommendedPrice,
    this.minimumPrice,
    this.expectedDuration,
    this.promotionMethod,
    this.commissionRate,
    this.recentCases,
    // 3️⃣ 특이사항
    this.hasTenant,
    this.desiredPrice,
    this.targetPeriod,
    this.specialNotes,
    // 4️⃣ 중개업자 답변
    this.brokerAnswer,
    this.answerDate,
    this.inquiryLinkId,
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
      // 1️⃣ 기본정보
      'propertyType': propertyType,
      'propertyAddress': propertyAddress,
      'propertyArea': propertyArea,
      // 2️⃣ 중개 제안
      'recommendedPrice': recommendedPrice,
      'minimumPrice': minimumPrice,
      'expectedDuration': expectedDuration,
      'promotionMethod': promotionMethod,
      'commissionRate': commissionRate,
      'recentCases': recentCases,
      // 3️⃣ 특이사항
      'hasTenant': hasTenant,
      'desiredPrice': desiredPrice,
      'targetPeriod': targetPeriod,
      'specialNotes': specialNotes,
      // 4️⃣ 중개업자 답변
      'brokerAnswer': brokerAnswer,
      'answerDate': answerDate != null ? Timestamp.fromDate(answerDate!) : null,
      'inquiryLinkId': inquiryLinkId,
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
      // 1️⃣ 기본정보
      propertyType: map['propertyType'],
      propertyAddress: map['propertyAddress'],
      propertyArea: map['propertyArea'],
      // 2️⃣ 중개 제안
      recommendedPrice: map['recommendedPrice'],
      minimumPrice: map['minimumPrice'],
      expectedDuration: map['expectedDuration'],
      promotionMethod: map['promotionMethod'],
      commissionRate: map['commissionRate'],
      recentCases: map['recentCases'],
      // 3️⃣ 특이사항
      hasTenant: map['hasTenant'],
      desiredPrice: map['desiredPrice'],
      targetPeriod: map['targetPeriod'],
      specialNotes: map['specialNotes'],
      // 4️⃣ 중개업자 답변
      brokerAnswer: map['brokerAnswer'],
      answerDate: (map['answerDate'] as Timestamp?)?.toDate(),
      inquiryLinkId: map['inquiryLinkId'],
    );
  }

  /// 상태 텍스트 반환
  String get statusText {
    switch (status) {
      case 'pending':
        return '대기중';
      case 'contacted':
        return '연락완료';
      case 'answered':
        return '답변완료';
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
      case 'answered':
        return const Color(0xFF9C27B0); // 보라색
      case 'completed':
        return const Color(0xFF66BB6A); // 초록색
      case 'cancelled':
        return const Color(0xFFEF5350); // 빨간색
      default:
        return const Color(0xFF9E9E9E); // 회색
    }
  }
  
  /// 답변이 있는지 확인
  bool get hasAnswer => brokerAnswer != null && brokerAnswer!.isNotEmpty;
}

