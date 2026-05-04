/// Task 05 — M2 시간기록 공개 (Priority Disclosure) 모델.
///
/// `mlsProperties/{id}/broker_participations/{participationId}` 의 비식별 view.
/// Backend의 `getBrokerParticipationsForSeller` / `getMyParticipations` callable이
/// 필드 단위 마스킹을 강제하므로, 클라이언트는 본 모델로 그대로 직렬화한다.
///
/// **80세 노인 화법**: 다른 중개사 실명/사무소/전화번호는 우선권 부여 후만 공개.
/// 다른 중개사 식별 정보(brokerId/brokerUid)는 응답에 포함되지 않는다.
library;

/// 참여 단계.
///
/// - declared: 첫 참여 등록 (broker가 매물에 관심 표명한 시점)
/// - visitScheduled: 임장 예정 (방문 요청 승인 또는 일정 확정)
/// - offerMade: 의향서 제출 (broker_offer 작성)
enum ParticipationStage { declared, visitScheduled, offerMade }

class BrokerParticipation {
  /// 비식별 표시명 ("중개사 A", "중개사 B" ...). callable 응답 그대로.
  final String displayName;

  /// 현재 참여 단계.
  final ParticipationStage stage;

  /// 첫 참여 시간기록 (불변, 분쟁 시 객관 증거).
  final DateTime? declaredAt;

  /// 임장 예정 시각.
  final DateTime? visitScheduledAt;

  /// 의향서 제출 시각.
  final DateTime? offerMadeAt;

  /// 매도자 화면 공개 시각.
  final DateTime? publiclyVisibleAt;

  /// 우선권(priority_grant) 활성 보유 여부.
  /// true 일 때만 [brokerName] / [brokerPhone] / [officeName] 가 채워진다.
  final bool hasActiveGrant;

  /// 실명 (활성 grant 보유 시만).
  final String? brokerName;

  /// 전화번호 (활성 grant 보유 시만).
  final String? brokerPhone;

  /// 사무소명 (활성 grant 보유 시만).
  final String? officeName;

  /// `getMyParticipations` 응답에만 포함 — 본인 시점 매물 ID.
  final String? propertyId;

  /// `getMyParticipations` 응답에만 포함 — 연결된 grant ID.
  final String? relatedGrantId;

  const BrokerParticipation({
    required this.displayName,
    required this.stage,
    required this.hasActiveGrant,
    this.declaredAt,
    this.visitScheduledAt,
    this.offerMadeAt,
    this.publiclyVisibleAt,
    this.brokerName,
    this.brokerPhone,
    this.officeName,
    this.propertyId,
    this.relatedGrantId,
  });

  factory BrokerParticipation.fromMap(Map<String, dynamic> map) {
    return BrokerParticipation(
      displayName: map['displayName'] as String? ?? '',
      stage: stageFromString(map['participationStage'] as String?),
      declaredAt: _readMillis(map['declaredAt']),
      visitScheduledAt: _readMillis(map['visitScheduledAt']),
      offerMadeAt: _readMillis(map['offerMadeAt']),
      publiclyVisibleAt: _readMillis(map['publiclyVisibleAt']),
      hasActiveGrant: map['hasActiveGrant'] == true,
      brokerName: map['brokerName'] as String?,
      brokerPhone: map['brokerPhone'] as String?,
      officeName: map['officeName'] as String?,
      propertyId: map['propertyId'] as String?,
      relatedGrantId: map['relatedGrantId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'displayName': displayName,
      'participationStage': stageToString(stage),
      'declaredAt': declaredAt?.millisecondsSinceEpoch,
      'visitScheduledAt': visitScheduledAt?.millisecondsSinceEpoch,
      'offerMadeAt': offerMadeAt?.millisecondsSinceEpoch,
      'publiclyVisibleAt': publiclyVisibleAt?.millisecondsSinceEpoch,
      'hasActiveGrant': hasActiveGrant,
      if (brokerName != null) 'brokerName': brokerName,
      if (brokerPhone != null) 'brokerPhone': brokerPhone,
      if (officeName != null) 'officeName': officeName,
      if (propertyId != null) 'propertyId': propertyId,
      if (relatedGrantId != null) 'relatedGrantId': relatedGrantId,
    };
  }

  BrokerParticipation copyWith({
    String? displayName,
    ParticipationStage? stage,
    DateTime? declaredAt,
    DateTime? visitScheduledAt,
    DateTime? offerMadeAt,
    DateTime? publiclyVisibleAt,
    bool? hasActiveGrant,
    String? brokerName,
    String? brokerPhone,
    String? officeName,
    String? propertyId,
    String? relatedGrantId,
  }) {
    return BrokerParticipation(
      displayName: displayName ?? this.displayName,
      stage: stage ?? this.stage,
      declaredAt: declaredAt ?? this.declaredAt,
      visitScheduledAt: visitScheduledAt ?? this.visitScheduledAt,
      offerMadeAt: offerMadeAt ?? this.offerMadeAt,
      publiclyVisibleAt: publiclyVisibleAt ?? this.publiclyVisibleAt,
      hasActiveGrant: hasActiveGrant ?? this.hasActiveGrant,
      brokerName: brokerName ?? this.brokerName,
      brokerPhone: brokerPhone ?? this.brokerPhone,
      officeName: officeName ?? this.officeName,
      propertyId: propertyId ?? this.propertyId,
      relatedGrantId: relatedGrantId ?? this.relatedGrantId,
    );
  }

  /// 미지 stage 문자열은 `declared` 로 폴백.
  static ParticipationStage stageFromString(String? s) {
    switch (s) {
      case 'visit_scheduled':
        return ParticipationStage.visitScheduled;
      case 'offer_made':
        return ParticipationStage.offerMade;
      case 'declared':
      default:
        return ParticipationStage.declared;
    }
  }

  static String stageToString(ParticipationStage s) {
    switch (s) {
      case ParticipationStage.visitScheduled:
        return 'visit_scheduled';
      case ParticipationStage.offerMade:
        return 'offer_made';
      case ParticipationStage.declared:
        return 'declared';
    }
  }

  /// callable 응답의 number(millis) → DateTime 안전 변환.
  static DateTime? _readMillis(dynamic v) {
    if (v == null) return null;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is double) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
    if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
    return null;
  }
}
