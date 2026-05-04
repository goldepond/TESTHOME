import 'package:cloud_firestore/cloud_firestore.dart';

/// 우선권 감사 로그 (priority_audit_logs 컬렉션, append-only)
///
/// 모든 우선권 발급/만료/취소/이행 이벤트를 1:1로 기록한다.
/// `allow update: if false; allow delete: if false` — Functions에서만 생성한다.
class PriorityAuditLog {
  final String eventId;
  final AuditEventType eventType;

  // 액터/대상
  final String? actorUid; // 사용자 액션이면 uid, 시스템 액션이면 null
  final String? propertyId;
  final String? brokerId;
  final String? grantId;

  // 결정 입력/출력 스냅샷 (자유형)
  final Map<String, dynamic> inputs;
  final Map<String, dynamic> outputs;

  // 룰북 버전 — 산정 알고리즘 변경 시 추적용
  final String rulebookVersion; // e.g. 'v1.3.0'

  final DateTime createdAt;

  const PriorityAuditLog({
    required this.eventId,
    required this.eventType,
    required this.rulebookVersion,
    required this.createdAt,
    this.actorUid,
    this.propertyId,
    this.brokerId,
    this.grantId,
    this.inputs = const {},
    this.outputs = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'eventType': _eventTypeToString(eventType),
      'actorUid': actorUid,
      'propertyId': propertyId,
      'brokerId': brokerId,
      'grantId': grantId,
      'inputs': inputs,
      'outputs': outputs,
      'rulebookVersion': rulebookVersion,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory PriorityAuditLog.fromMap(Map<String, dynamic> map) {
    return PriorityAuditLog(
      eventId: map['eventId'] ?? '',
      eventType: _eventTypeFromString(map['eventType']),
      actorUid: map['actorUid'],
      propertyId: map['propertyId'],
      brokerId: map['brokerId'],
      grantId: map['grantId'],
      inputs: Map<String, dynamic>.from(map['inputs'] ?? const {}),
      outputs: Map<String, dynamic>.from(map['outputs'] ?? const {}),
      rulebookVersion: map['rulebookVersion'] ?? '',
      createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
    );
  }

  factory PriorityAuditLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PriorityAuditLog.fromMap({...data, 'eventId': doc.id});
  }

  PriorityAuditLog copyWith({
    String? eventId,
    AuditEventType? eventType,
    String? actorUid,
    String? propertyId,
    String? brokerId,
    String? grantId,
    Map<String, dynamic>? inputs,
    Map<String, dynamic>? outputs,
    String? rulebookVersion,
    DateTime? createdAt,
  }) {
    return PriorityAuditLog(
      eventId: eventId ?? this.eventId,
      eventType: eventType ?? this.eventType,
      actorUid: actorUid ?? this.actorUid,
      propertyId: propertyId ?? this.propertyId,
      brokerId: brokerId ?? this.brokerId,
      grantId: grantId ?? this.grantId,
      inputs: inputs ?? this.inputs,
      outputs: outputs ?? this.outputs,
      rulebookVersion: rulebookVersion ?? this.rulebookVersion,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// 감사 이벤트 종류 (8개)
enum AuditEventType {
  grantIssued,
  grantExpired,
  grantRevoked,
  grantFulfilled,
  eligibilityCheck,
  capBlocked,
  tieredReleaseStep,
  // 명세상 7개지만 향후 확장 여지를 위해 자유형 'other' 슬롯을 둔다.
  other,
}

String _eventTypeToString(AuditEventType type) {
  switch (type) {
    case AuditEventType.grantIssued:
      return 'grant_issued';
    case AuditEventType.grantExpired:
      return 'grant_expired';
    case AuditEventType.grantRevoked:
      return 'grant_revoked';
    case AuditEventType.grantFulfilled:
      return 'grant_fulfilled';
    case AuditEventType.eligibilityCheck:
      return 'eligibility_check';
    case AuditEventType.capBlocked:
      return 'cap_blocked';
    case AuditEventType.tieredReleaseStep:
      return 'tiered_release_step';
    case AuditEventType.other:
      return 'other';
  }
}

AuditEventType _eventTypeFromString(dynamic value) {
  switch (value) {
    case 'grant_issued':
      return AuditEventType.grantIssued;
    case 'grant_expired':
      return AuditEventType.grantExpired;
    case 'grant_revoked':
      return AuditEventType.grantRevoked;
    case 'grant_fulfilled':
      return AuditEventType.grantFulfilled;
    case 'eligibility_check':
      return AuditEventType.eligibilityCheck;
    case 'cap_blocked':
      return AuditEventType.capBlocked;
    case 'tiered_release_step':
      return AuditEventType.tieredReleaseStep;
    default:
      return AuditEventType.other;
  }
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
