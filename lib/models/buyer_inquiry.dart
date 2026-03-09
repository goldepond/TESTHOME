/// 구매자 문의 모델
///
/// 구매자가 매물에 관심을 표시하고 중개사와 연결되는 흐름을 추적
/// 문의 접수 → 중개사 배정 → 연락 → 방문 → 완료/종료
class BuyerInquiry {
  final String id;
  final String propertyId;
  final String buyerUserId;
  final String buyerName;
  final String? buyerPhone;
  final String? buyerMessage; // 구매자 메모 (선택)
  final BuyerInquiryStatus status;
  final String? assignedBrokerId;
  final String? assignedBrokerName;
  final DateTime createdAt;
  final DateTime? assignedAt;
  final DateTime? contactedAt; // 중개사가 구매자에게 연락한 시각

  BuyerInquiry({
    required this.id,
    required this.propertyId,
    required this.buyerUserId,
    required this.buyerName,
    required this.status,
    required this.createdAt,
    this.buyerPhone,
    this.buyerMessage,
    this.assignedBrokerId,
    this.assignedBrokerName,
    this.assignedAt,
    this.contactedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'propertyId': propertyId,
      'buyerUserId': buyerUserId,
      'buyerName': buyerName,
      'buyerPhone': buyerPhone,
      'buyerMessage': buyerMessage,
      'status': status.toString().split('.').last,
      'assignedBrokerId': assignedBrokerId,
      'assignedBrokerName': assignedBrokerName,
      'createdAt': createdAt.toIso8601String(),
      'assignedAt': assignedAt?.toIso8601String(),
      'contactedAt': contactedAt?.toIso8601String(),
    };
  }

  factory BuyerInquiry.fromMap(Map<String, dynamic> map) {
    return BuyerInquiry(
      id: map['id'] as String? ?? '',
      propertyId: map['propertyId'] as String? ?? '',
      buyerUserId: map['buyerUserId'] as String? ?? '',
      buyerName: map['buyerName'] as String? ?? '구매 희망자',
      buyerPhone: map['buyerPhone'] as String?,
      buyerMessage: map['buyerMessage'] as String?,
      status: BuyerInquiryStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => BuyerInquiryStatus.pending,
      ),
      assignedBrokerId: map['assignedBrokerId'] as String?,
      assignedBrokerName: map['assignedBrokerName'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
      assignedAt: map['assignedAt'] != null
          ? DateTime.parse(map['assignedAt'] as String)
          : null,
      contactedAt: map['contactedAt'] != null
          ? DateTime.parse(map['contactedAt'] as String)
          : null,
    );
  }

  BuyerInquiry copyWith({
    String? id,
    String? propertyId,
    String? buyerUserId,
    String? buyerName,
    String? buyerPhone,
    String? buyerMessage,
    BuyerInquiryStatus? status,
    String? assignedBrokerId,
    String? assignedBrokerName,
    DateTime? createdAt,
    DateTime? assignedAt,
    DateTime? contactedAt,
  }) {
    return BuyerInquiry(
      id: id ?? this.id,
      propertyId: propertyId ?? this.propertyId,
      buyerUserId: buyerUserId ?? this.buyerUserId,
      buyerName: buyerName ?? this.buyerName,
      buyerPhone: buyerPhone ?? this.buyerPhone,
      buyerMessage: buyerMessage ?? this.buyerMessage,
      status: status ?? this.status,
      assignedBrokerId: assignedBrokerId ?? this.assignedBrokerId,
      assignedBrokerName: assignedBrokerName ?? this.assignedBrokerName,
      createdAt: createdAt ?? this.createdAt,
      assignedAt: assignedAt ?? this.assignedAt,
      contactedAt: contactedAt ?? this.contactedAt,
    );
  }
}

/// 구매자 문의 상태
enum BuyerInquiryStatus {
  pending,         // 관심 등록됨, 중개사 미배정
  brokerAssigned,  // 중개사 배정 완료
  contacted,       // 중개사가 구매자에게 연락함
  visiting,        // 방문 예정/진행 중
  completed,       // 거래 완료 또는 종료
  cancelled,       // 취소
}

extension BuyerInquiryStatusExtension on BuyerInquiryStatus {
  String get label {
    switch (this) {
      case BuyerInquiryStatus.pending:
        return '중개사 매칭 중';
      case BuyerInquiryStatus.brokerAssigned:
        return '중개사 배정 완료';
      case BuyerInquiryStatus.contacted:
        return '연락 완료';
      case BuyerInquiryStatus.visiting:
        return '방문 진행 중';
      case BuyerInquiryStatus.completed:
        return '완료';
      case BuyerInquiryStatus.cancelled:
        return '취소됨';
    }
  }
}
