import 'package:cloud_firestore/cloud_firestore.dart';

/// 우선권 부여 원장 (priority_grants 컬렉션)
///
/// M1.1(seller_match) / M1.2(buyer_match)에서 발급되는 우선권 인스턴스.
/// *불변 + append-only* — 만료/취소도 새 이벤트로 기록한다.
///
/// 클라이언트는 *생성/수정/삭제 불가* — Cloud Functions(`issuePriorityGrant` 등)만 생성한다.
class PriorityGrant {
  // 식별자
  final String id; // 'pg_{ts}_{brokerId}' 형식
  final String propertyId; // mlsProperties/{id}
  final String brokerId; // 우선권 보유 중개사 ID
  final String brokerUid; // Firebase Auth uid (Rules 검증용)
  final String? sellerUid; // 매도자 uid (Rules priority_grants 매도자 권한 검사용)

  // 분류
  final PriorityGrantType type; // seller_match vs buyer_match
  final String? buyerInquiryId; // type=buyer_match일 때만 존재
  final PriorityGrantStage stage; // participation / visit / offer

  // 시간 정보
  final DateTime grantedAt;
  final DateTime expiresAt; // grantedAt + 14~30일

  // 상태
  final PriorityGrantStatus status;
  final String? statusReason; // 만료/취소 사유 코드

  // 활동성 평가 (80% 룰)
  final double activityScore; // 0.0 ~ 1.0
  final DateTime? lastActivityAt;

  // Dynamic Matching 입력 변수 스냅샷 (자유형)
  final Map<String, dynamic> scoringInputs;

  // 종결 시각
  final DateTime? revokedAt;
  final DateTime? fulfilledAt;

  // P1-20: fulfillment 메타데이터 (P1-4 fulfillGrant callable 또는 onContractCreated 트리거가 set)
  final String? fulfillmentSource; // 'manual' | 'trigger'
  final String? contractId; // 트리거 경유 시 contracts/{id} 참조

  const PriorityGrant({
    required this.id,
    required this.propertyId,
    required this.brokerId,
    required this.brokerUid,
    required this.type,
    required this.stage,
    required this.grantedAt,
    required this.expiresAt,
    required this.status,
    this.sellerUid,
    this.buyerInquiryId,
    this.statusReason,
    this.activityScore = 0.0,
    this.lastActivityAt,
    this.scoringInputs = const {},
    this.revokedAt,
    this.fulfilledAt,
    this.fulfillmentSource,
    this.contractId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'propertyId': propertyId,
      'brokerId': brokerId,
      'brokerUid': brokerUid,
      'sellerUid': sellerUid,
      'type': _typeToString(type),
      'buyerInquiryId': buyerInquiryId,
      'stage': _stageToString(stage),
      'grantedAt': grantedAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'status': _statusToString(status),
      'statusReason': statusReason,
      'activityScore': activityScore,
      'lastActivityAt': lastActivityAt?.toIso8601String(),
      'scoringInputs': scoringInputs,
      'revokedAt': revokedAt?.toIso8601String(),
      'fulfilledAt': fulfilledAt?.toIso8601String(),
      'fulfillmentSource': fulfillmentSource,
      'contractId': contractId,
    };
  }

  factory PriorityGrant.fromMap(Map<String, dynamic> map) {
    return PriorityGrant(
      id: map['id'] ?? '',
      propertyId: map['propertyId'] ?? '',
      brokerId: map['brokerId'] ?? '',
      brokerUid: map['brokerUid'] ?? '',
      sellerUid: map['sellerUid'] as String?,
      type: _typeFromString(map['type']),
      buyerInquiryId: map['buyerInquiryId'],
      stage: _stageFromString(map['stage']),
      grantedAt: _parseDate(map['grantedAt']) ?? DateTime.now(),
      expiresAt: _parseDate(map['expiresAt']) ?? DateTime.now(),
      status: _statusFromString(map['status']),
      statusReason: map['statusReason'],
      activityScore: (map['activityScore'] as num?)?.toDouble() ?? 0.0,
      lastActivityAt: _parseDate(map['lastActivityAt']),
      scoringInputs: Map<String, dynamic>.from(map['scoringInputs'] ?? const {}),
      revokedAt: _parseDate(map['revokedAt']),
      fulfilledAt: _parseDate(map['fulfilledAt']),
      fulfillmentSource: map['fulfillmentSource'] as String?,
      contractId: map['contractId'] as String?,
    );
  }

  factory PriorityGrant.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PriorityGrant.fromMap({...data, 'id': doc.id});
  }

  PriorityGrant copyWith({
    String? id,
    String? propertyId,
    String? brokerId,
    String? brokerUid,
    String? sellerUid,
    PriorityGrantType? type,
    String? buyerInquiryId,
    PriorityGrantStage? stage,
    DateTime? grantedAt,
    DateTime? expiresAt,
    PriorityGrantStatus? status,
    String? statusReason,
    double? activityScore,
    DateTime? lastActivityAt,
    Map<String, dynamic>? scoringInputs,
    DateTime? revokedAt,
    DateTime? fulfilledAt,
    String? fulfillmentSource,
    String? contractId,
  }) {
    return PriorityGrant(
      id: id ?? this.id,
      propertyId: propertyId ?? this.propertyId,
      brokerId: brokerId ?? this.brokerId,
      brokerUid: brokerUid ?? this.brokerUid,
      sellerUid: sellerUid ?? this.sellerUid,
      type: type ?? this.type,
      buyerInquiryId: buyerInquiryId ?? this.buyerInquiryId,
      stage: stage ?? this.stage,
      grantedAt: grantedAt ?? this.grantedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      status: status ?? this.status,
      statusReason: statusReason ?? this.statusReason,
      activityScore: activityScore ?? this.activityScore,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      scoringInputs: scoringInputs ?? this.scoringInputs,
      revokedAt: revokedAt ?? this.revokedAt,
      fulfilledAt: fulfilledAt ?? this.fulfilledAt,
      fulfillmentSource: fulfillmentSource ?? this.fulfillmentSource,
      contractId: contractId ?? this.contractId,
    );
  }

  /// 만료 여부 (시간 기준)
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// 활동성 80% 룰 통과 여부
  bool get meetsActivityThreshold => activityScore >= 0.8;
}

/// 우선권 발급 사유 분류
enum PriorityGrantType {
  sellerMatch, // M1.1 — 매도자-중개사 매칭
  buyerMatch, // M1.2 — 매수자-중개사 매칭
}

/// 우선권 단계 (단계별 권리 등록)
enum PriorityGrantStage {
  participation,
  visit,
  offer,
}

/// 우선권 상태
enum PriorityGrantStatus {
  active,
  expired,
  revoked,
  fulfilled,
}

// ----------------- 직렬화 헬퍼 (Firestore 저장 키와 1:1 매핑) -----------------

String _typeToString(PriorityGrantType type) {
  switch (type) {
    case PriorityGrantType.sellerMatch:
      return 'seller_match';
    case PriorityGrantType.buyerMatch:
      return 'buyer_match';
  }
}

PriorityGrantType _typeFromString(dynamic value) {
  switch (value) {
    case 'seller_match':
      return PriorityGrantType.sellerMatch;
    case 'buyer_match':
      return PriorityGrantType.buyerMatch;
    default:
      return PriorityGrantType.sellerMatch;
  }
}

String _stageToString(PriorityGrantStage stage) {
  return stage.name; // participation / visit / offer
}

PriorityGrantStage _stageFromString(dynamic value) {
  return PriorityGrantStage.values.firstWhere(
    (e) => e.name == value,
    orElse: () => PriorityGrantStage.participation,
  );
}

String _statusToString(PriorityGrantStatus status) {
  return status.name; // active / expired / revoked / fulfilled
}

PriorityGrantStatus _statusFromString(dynamic value) {
  return PriorityGrantStatus.values.firstWhere(
    (e) => e.name == value,
    orElse: () => PriorityGrantStatus.active,
  );
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}
