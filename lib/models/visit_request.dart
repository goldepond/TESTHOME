import 'package:flutter/material.dart';

class VisitRequest {
  final String? id;
  final String propertyId;
  final String propertyAddress;
  final String buyerId;
  final String buyerName;
  final String sellerId;
  final String sellerName;
  final DateTime requestTimestamp;
  final DateTime visitTimestamp;
  final String status; // 'pending', 'confirmed', 'rejected', 'completed'
  final String? lastMessage;
  final String? notes;
  final DateTime? confirmedAt;
  final String? confirmedBy;

  VisitRequest({
    this.id,
    required this.propertyId,
    required this.propertyAddress,
    required this.buyerId,
    required this.buyerName,
    required this.sellerId,
    required this.sellerName,
    DateTime? requestTimestamp,
    required this.visitTimestamp,
    this.status = 'pending',
    this.lastMessage,
    this.notes,
    this.confirmedAt,
    this.confirmedBy,
  }) : requestTimestamp = requestTimestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'propertyId': propertyId,
      'propertyAddress': propertyAddress,
      'buyerId': buyerId,
      'buyerName': buyerName,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'requestTimestamp': requestTimestamp.toIso8601String(),
      'visitTimestamp': visitTimestamp.toIso8601String(),
      'status': status,
      'lastMessage': lastMessage?.isNotEmpty == true ? lastMessage : null,
      'notes': notes?.isNotEmpty == true ? notes : null,
      'confirmedAt': confirmedAt?.toIso8601String(),
      'confirmedBy': confirmedBy,
    };
  }

  static VisitRequest fromMap(Map<String, dynamic> map) {
    return VisitRequest(
      id: map['id']?.toString(),
      propertyId: map['propertyId']?.toString() ?? '',
      propertyAddress: map['propertyAddress']?.toString() ?? '',
      buyerId: map['buyerId']?.toString() ?? '',
      buyerName: map['buyerName']?.toString() ?? '',
      sellerId: map['sellerId']?.toString() ?? '',
      sellerName: map['sellerName']?.toString() ?? '',
      requestTimestamp: map['requestTimestamp'] != null 
          ? DateTime.tryParse(map['requestTimestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      visitTimestamp: map['visitTimestamp'] != null 
          ? DateTime.tryParse(map['visitTimestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      status: map['status']?.toString() ?? 'pending',
      lastMessage: map['lastMessage']?.toString(),
      notes: map['notes']?.toString(),
      confirmedAt: map['confirmedAt'] != null 
          ? DateTime.tryParse(map['confirmedAt'].toString())
          : null,
      confirmedBy: map['confirmedBy']?.toString(),
    );
  }

  VisitRequest copyWith({
    String? id,
    String? propertyId,
    String? propertyAddress,
    String? buyerId,
    String? buyerName,
    String? sellerId,
    String? sellerName,
    DateTime? requestTimestamp,
    DateTime? visitTimestamp,
    String? status,
    String? lastMessage,
    String? notes,
    DateTime? confirmedAt,
    String? confirmedBy,
  }) {
    return VisitRequest(
      id: id ?? this.id,
      propertyId: propertyId ?? this.propertyId,
      propertyAddress: propertyAddress ?? this.propertyAddress,
      buyerId: buyerId ?? this.buyerId,
      buyerName: buyerName ?? this.buyerName,
      sellerId: sellerId ?? this.sellerId,
      sellerName: sellerName ?? this.sellerName,
      requestTimestamp: requestTimestamp ?? this.requestTimestamp,
      visitTimestamp: visitTimestamp ?? this.visitTimestamp,
      status: status ?? this.status,
      lastMessage: lastMessage ?? this.lastMessage,
      notes: notes ?? this.notes,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      confirmedBy: confirmedBy ?? this.confirmedBy,
    );
  }

  // 상태별 색상 반환
  Color getStatusColor() {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  // 상태별 텍스트 반환
  String getStatusText() {
    switch (status) {
      case 'pending':
        return '대기중';
      case 'confirmed':
        return '확정됨';
      case 'rejected':
        return '거절됨';
      case 'completed':
        return '완료됨';
      default:
        return '알 수 없음';
    }
  }

  // 방문 시간 포맷팅
  String getFormattedVisitTime() {
    return '${visitTimestamp.year}년 ${visitTimestamp.month}월 ${visitTimestamp.day}일 '
           '${visitTimestamp.hour.toString().padLeft(2, '0')}:${visitTimestamp.minute.toString().padLeft(2, '0')}';
  }

  // 요청 시간 포맷팅
  String getFormattedRequestTime() {
    final now = DateTime.now();
    final difference = now.difference(requestTimestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}일 전';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}시간 전';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}분 전';
    } else {
      return '방금 전';
    }
  }
} 