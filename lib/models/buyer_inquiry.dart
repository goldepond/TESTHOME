/// 구매자 문의 모델
///
/// 구매자가 매물에 관심을 표시하고 중개사와 연결되는 흐름을 추적
/// 문의 접수 → 중개사 배정 → 연락 → 방문 → 완료/종료
///
/// Task 03 (M1.2 매수자-중개사 매물별 매칭) 신설 필드:
///   - selectedBrokerId: 매수자가 임장(방문)을 위해 선택한 중개사 brokerId
///   - activeBuyerMatchGrantId: 매수자의 활성 buyer_match priority_grant 참조
///   - brokerSelectedAt: 중개사 선택 시각 (24h 쿨다운 기준점)
///
/// 위 3개 필드는 *클라이언트 직접 수정 금지*. `createBuyerMatchGrant` callable만 갱신.
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

  // === Task 03 — M1.2 매수자-중개사 매물별 매칭 ===
  final String? selectedBrokerId;
  final String? activeBuyerMatchGrantId;
  final DateTime? brokerSelectedAt;

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
    this.selectedBrokerId,
    this.activeBuyerMatchGrantId,
    this.brokerSelectedAt,
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
      'selectedBrokerId': selectedBrokerId,
      'activeBuyerMatchGrantId': activeBuyerMatchGrantId,
      'brokerSelectedAt': brokerSelectedAt?.toIso8601String(),
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
      createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
      assignedAt: _parseDate(map['assignedAt']),
      contactedAt: _parseDate(map['contactedAt']),
      selectedBrokerId: map['selectedBrokerId'] as String?,
      activeBuyerMatchGrantId: map['activeBuyerMatchGrantId'] as String?,
      brokerSelectedAt: _parseDate(map['brokerSelectedAt']),
    );
  }

  /// Firestore Timestamp / DateTime / ISO String 3종 모두 수용.
  /// Functions가 Timestamp로 쓴 데이터를 클라가 읽을 수 있도록 방어 처리.
  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) {
      try {
        return DateTime.parse(raw);
      } catch (_) {
        return null;
      }
    }
    // Firestore Timestamp(toDate 메서드 보유)
    try {
      // ignore: avoid_dynamic_calls
      final dynamic toDate = (raw as dynamic).toDate;
      if (toDate is Function) {
        // ignore: avoid_dynamic_calls
        final result = toDate.call();
        if (result is DateTime) return result;
      }
    } catch (_) {
      // fallthrough
    }
    return null;
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
    String? selectedBrokerId,
    String? activeBuyerMatchGrantId,
    DateTime? brokerSelectedAt,
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
      selectedBrokerId: selectedBrokerId ?? this.selectedBrokerId,
      activeBuyerMatchGrantId:
          activeBuyerMatchGrantId ?? this.activeBuyerMatchGrantId,
      brokerSelectedAt: brokerSelectedAt ?? this.brokerSelectedAt,
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
