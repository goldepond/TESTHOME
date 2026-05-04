/// 중개사 성과 통계 모델
///
/// 중개사의 행동 데이터 기반 성과 지표를 집계합니다.
/// 별점/리뷰 없이 오직 행동 데이터만 사용하여 조작 불가능한 지표를 제공합니다.
class BrokerStats {
  final String brokerId;
  final String brokerName;
  final String? brokerCompany;
  final String? brokerRegistrationNumber;

  // 방문 요청 통계
  final int totalRequests; // 총 방문 요청 수
  final int approvedRequests; // 승인된 요청 수
  final int rejectedRequests; // 거절된 요청 수
  final int cancelledRequests; // 취소된 요청 수

  // 방문 완료 통계 (노쇼 측정)
  final int completedVisits; // 실제 방문 완료 수
  final int noShowCount; // 노쇼 횟수

  // 거래 통계
  final int completedDeals; // 거래 완료 건수
  final double totalDealAmount; // 총 거래 금액

  // 제안가 통계
  final double totalProposedAmount; // 총 제안 금액
  final double totalFinalAmount; // 총 최종 거래 금액 (제안가 편차 계산용)
  final int priceComparisonCount; // 제안가-최종가 비교 가능 건수

  // 응답 속도 통계
  final int totalResponseTimeSeconds; // 총 응답 시간 (초)
  final int responseCount; // 응답 횟수

  // 지역별 통계
  final Map<String, int> dealsByRegion; // 지역별 거래 건수

  // 전문 분야 (레거시 호환)
  final List<String> specialties;
  final String? primaryRegion;

  // 메타데이터
  final DateTime createdAt;
  final DateTime updatedAt;

  // ========== 라운드 2D P2-6 — Reputation Pool 기본 골격 (admin 노출 only) ==========
  //
  // 정책 출처: docs/goal/multi_agent_competition_solutions_cross_industry.md §4.2
  //   (Reputation Pool — 후행 메커니즘, 차별화 X, 베이스라인)
  //
  // **중요 정책 (사용자 노출 0)**:
  //   * 본 4종 카운터는 *admin 화면에만* 노출. 사용자/매도자/broker 본인 노출 0.
  //   * copy-deck §1.4 "백분율(%) UI 노출 절대 금지. 점수·가중치 절대 금지" 준수.
  //   * 상대평가 산식 / 정렬 알고리즘 / 카테고리화 ("이 동네 활동 많은 분")는
  //     P2-7 후행 phase 분리. 본 phase 는 *데이터 누적*만.
  //
  // **카운터 적재 경로** (functions/index.js):
  //   * fulfilledGrantsCount — onPriorityGrantFulfilled 트리거가 priority_grants
  //     status active→fulfilled 전이 시 +1. lastFulfilledAt = serverTimestamp.
  //   * declaredCount / visitScheduledCount / offerMadeCount —
  //     onBrokerParticipationStageAdvanced 트리거가 broker_participations
  //     stage rank 증가 시 해당 stage 카운터 +1.
  //
  // **카카오 회피**:
  //   고정 우대 패턴 X. 카운터는 *전체 broker 분포* 기반 후행 카테고리화에만
  //   사용 (후행 phase 책임).

  /// Fulfilled (거래 성사) 우선권 누적 카운트.
  /// 후행 phase 에서 *분포 백분위 기반 카테고리화* 입력으로만 사용.
  final int fulfilledGrantsCount;

  /// 마지막 fulfillment 시각.
  /// 후행 phase 에서 *최근 활동 카테고리* 입력으로 사용 가능.
  final DateTime? lastFulfilledAt;

  /// 참여 등록 (declared) 단계 진입 누적 카운트 (broker_participations stage).
  final int declaredCount;

  /// 임장 예정 (visit_scheduled) 단계 진입 누적 카운트.
  final int visitScheduledCount;

  /// 의향서 제출 (offer_made) 단계 진입 누적 카운트.
  final int offerMadeCount;

  BrokerStats({
    required this.brokerId,
    required this.brokerName,
    required this.createdAt,
    required this.updatedAt,
    this.brokerCompany,
    this.brokerRegistrationNumber,
    this.totalRequests = 0,
    this.approvedRequests = 0,
    this.rejectedRequests = 0,
    this.cancelledRequests = 0,
    this.completedVisits = 0,
    this.noShowCount = 0,
    this.completedDeals = 0,
    this.totalDealAmount = 0,
    this.totalProposedAmount = 0,
    this.totalFinalAmount = 0,
    this.priceComparisonCount = 0,
    this.totalResponseTimeSeconds = 0,
    this.responseCount = 0,
    this.dealsByRegion = const {},
    this.specialties = const [],
    this.primaryRegion,
    // P2-6 신규 4종 — 기본값 0/null. 기존 doc 누락 시 fromMap 에서 0/null 폴백.
    this.fulfilledGrantsCount = 0,
    this.lastFulfilledAt,
    this.declaredCount = 0,
    this.visitScheduledCount = 0,
    this.offerMadeCount = 0,
  });

  // ========== 계산된 지표 (판매자에게 표시) ==========

  /// 방문 성사율: 승인 방문 ÷ 요청
  /// "말만 많은지 실제 고객인지" 판단
  double get visitSuccessRate {
    if (totalRequests == 0) return 0;
    return approvedRequests / totalRequests;
  }

  /// 노쇼 비율: 노쇼 ÷ 승인
  /// "시간 낭비 리스크" 판단
  double get noShowRate {
    if (approvedRequests == 0) return 0;
    return noShowCount / approvedRequests;
  }

  /// 평균 제안가 편차: 제안가 ÷ 최종가
  /// "저가 압박형 중개사 여부" 판단
  /// 1.0에 가까울수록 정직한 제안, 낮을수록 저가 압박
  double get avgPriceDeviation {
    if (priceComparisonCount == 0 || totalFinalAmount == 0) return 1.0;
    return totalProposedAmount / totalFinalAmount;
  }

  /// 평균 응답 속도 (초)
  /// "급한 상황에서 쓸 수 있는지" 판단
  int get avgResponseTimeSeconds {
    if (responseCount == 0) return 0;
    return totalResponseTimeSeconds ~/ responseCount;
  }

  /// 평균 응답 속도 (시간 단위 문자열)
  String get avgResponseTimeFormatted {
    final seconds = avgResponseTimeSeconds;
    if (seconds < 60) return '$seconds초';
    if (seconds < 3600) return '${seconds ~/ 60}분';
    if (seconds < 86400) return '${seconds ~/ 3600}시간';
    return '${seconds ~/ 86400}일';
  }

  /// 거래 완료율: 거래 완료 ÷ 승인
  double get dealCompletionRate {
    if (approvedRequests == 0) return 0;
    return completedDeals / approvedRequests;
  }

  /// 신뢰도 점수 (내부 계산용, UI에서 정렬 기준으로 사용)
  /// 방문성사율 40% + (1-노쇼율) 30% + 제안가정직도 20% + 응답속도 10%
  double get reliabilityScore {
    final visitScore = visitSuccessRate * 0.4;
    final noShowScore = (1 - noShowRate) * 0.3;
    final priceScore = (avgPriceDeviation > 0.9 ? 1.0 : avgPriceDeviation) * 0.2;
    final responseScore = (avgResponseTimeSeconds < 3600
            ? 1.0
            : avgResponseTimeSeconds < 86400
                ? 0.7
                : 0.3) *
        0.1;
    return visitScore + noShowScore + priceScore + responseScore;
  }

  // 레거시 호환 getter
  int get totalDeals => completedDeals;
  double get responseRate => responseCount > 0 ? 100.0 : 0.0;
  int get avgResponseTimeMinutes => avgResponseTimeSeconds ~/ 60;

  Map<String, dynamic> toMap() {
    return {
      'brokerId': brokerId,
      'brokerName': brokerName,
      'brokerCompany': brokerCompany,
      'brokerRegistrationNumber': brokerRegistrationNumber,
      'totalRequests': totalRequests,
      'approvedRequests': approvedRequests,
      'rejectedRequests': rejectedRequests,
      'cancelledRequests': cancelledRequests,
      'completedVisits': completedVisits,
      'noShowCount': noShowCount,
      'completedDeals': completedDeals,
      'totalDealAmount': totalDealAmount,
      'totalProposedAmount': totalProposedAmount,
      'totalFinalAmount': totalFinalAmount,
      'priceComparisonCount': priceComparisonCount,
      'totalResponseTimeSeconds': totalResponseTimeSeconds,
      'responseCount': responseCount,
      'dealsByRegion': dealsByRegion,
      'specialties': specialties,
      'primaryRegion': primaryRegion,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      // P2-6 신규 카운터 — admin 노출 only.
      'fulfilledGrantsCount': fulfilledGrantsCount,
      'lastFulfilledAt': lastFulfilledAt?.toIso8601String(),
      'declaredCount': declaredCount,
      'visitScheduledCount': visitScheduledCount,
      'offerMadeCount': offerMadeCount,
    };
  }

  factory BrokerStats.fromMap(Map<String, dynamic> map) {
    return BrokerStats(
      brokerId: map['brokerId'] ?? '',
      brokerName: map['brokerName'] ?? '',
      brokerCompany: map['brokerCompany'],
      brokerRegistrationNumber: map['brokerRegistrationNumber'],
      totalRequests: map['totalRequests']?.toInt() ?? 0,
      approvedRequests: map['approvedRequests']?.toInt() ?? 0,
      rejectedRequests: map['rejectedRequests']?.toInt() ?? 0,
      cancelledRequests: map['cancelledRequests']?.toInt() ?? 0,
      completedVisits: map['completedVisits']?.toInt() ?? 0,
      noShowCount: map['noShowCount']?.toInt() ?? 0,
      completedDeals: map['completedDeals']?.toInt() ?? map['totalDeals']?.toInt() ?? 0,
      totalDealAmount: map['totalDealAmount']?.toDouble() ?? 0,
      totalProposedAmount: map['totalProposedAmount']?.toDouble() ?? 0,
      totalFinalAmount: map['totalFinalAmount']?.toDouble() ?? 0,
      priceComparisonCount: map['priceComparisonCount']?.toInt() ?? 0,
      totalResponseTimeSeconds: map['totalResponseTimeSeconds']?.toInt() ?? 0,
      responseCount: map['responseCount']?.toInt() ?? 0,
      dealsByRegion: Map<String, int>.from(map['dealsByRegion'] ?? {}),
      specialties: List<String>.from(map['specialties'] ?? []),
      primaryRegion: map['primaryRegion'],
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : DateTime.now(),
      // P2-6 신규 카운터 — 기존 doc 누락 시 0/null 폴백.
      // Firestore Timestamp 또는 ISO String 둘 다 수용 (functions 트리거는
      // Timestamp 직접 set, fromMap toIso8601String 직렬화 둘 다 호환).
      fulfilledGrantsCount: map['fulfilledGrantsCount']?.toInt() ?? 0,
      lastFulfilledAt: _parseDateTime(map['lastFulfilledAt']),
      declaredCount: map['declaredCount']?.toInt() ?? 0,
      visitScheduledCount: map['visitScheduledCount']?.toInt() ?? 0,
      offerMadeCount: map['offerMadeCount']?.toInt() ?? 0,
    );
  }

  /// P2-6 — Firestore Timestamp / ISO String / null 모두 수용하는 헬퍼.
  /// Cloud Functions 트리거가 직접 Timestamp 로 set 하므로 두 형태 모두 지원.
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    // Firestore Timestamp 객체 — toDate() 메서드 보유. cloud_firestore 의
    // Timestamp 타입을 직접 import 하지 않고 duck-typing 으로 처리 (모델은
    // pure dart 유지 — broker_stats_service 가 Timestamp 변환 책임).
    try {
      final dynamic ts = value;
      if (ts.runtimeType.toString().contains('Timestamp')) {
        return ts.toDate() as DateTime;
      }
    } catch (_) {
      // ignore
    }
    return null;
  }

  BrokerStats copyWith({
    String? brokerId,
    String? brokerName,
    String? brokerCompany,
    String? brokerRegistrationNumber,
    int? totalRequests,
    int? approvedRequests,
    int? rejectedRequests,
    int? cancelledRequests,
    int? completedVisits,
    int? noShowCount,
    int? completedDeals,
    double? totalDealAmount,
    double? totalProposedAmount,
    double? totalFinalAmount,
    int? priceComparisonCount,
    int? totalResponseTimeSeconds,
    int? responseCount,
    Map<String, int>? dealsByRegion,
    List<String>? specialties,
    String? primaryRegion,
    DateTime? createdAt,
    DateTime? updatedAt,
    // P2-6 신규 카운터.
    int? fulfilledGrantsCount,
    DateTime? lastFulfilledAt,
    int? declaredCount,
    int? visitScheduledCount,
    int? offerMadeCount,
  }) {
    return BrokerStats(
      brokerId: brokerId ?? this.brokerId,
      brokerName: brokerName ?? this.brokerName,
      brokerCompany: brokerCompany ?? this.brokerCompany,
      brokerRegistrationNumber:
          brokerRegistrationNumber ?? this.brokerRegistrationNumber,
      totalRequests: totalRequests ?? this.totalRequests,
      approvedRequests: approvedRequests ?? this.approvedRequests,
      rejectedRequests: rejectedRequests ?? this.rejectedRequests,
      cancelledRequests: cancelledRequests ?? this.cancelledRequests,
      completedVisits: completedVisits ?? this.completedVisits,
      noShowCount: noShowCount ?? this.noShowCount,
      completedDeals: completedDeals ?? this.completedDeals,
      totalDealAmount: totalDealAmount ?? this.totalDealAmount,
      totalProposedAmount: totalProposedAmount ?? this.totalProposedAmount,
      totalFinalAmount: totalFinalAmount ?? this.totalFinalAmount,
      priceComparisonCount: priceComparisonCount ?? this.priceComparisonCount,
      totalResponseTimeSeconds:
          totalResponseTimeSeconds ?? this.totalResponseTimeSeconds,
      responseCount: responseCount ?? this.responseCount,
      dealsByRegion: dealsByRegion ?? this.dealsByRegion,
      specialties: specialties ?? this.specialties,
      primaryRegion: primaryRegion ?? this.primaryRegion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      fulfilledGrantsCount: fulfilledGrantsCount ?? this.fulfilledGrantsCount,
      lastFulfilledAt: lastFulfilledAt ?? this.lastFulfilledAt,
      declaredCount: declaredCount ?? this.declaredCount,
      visitScheduledCount: visitScheduledCount ?? this.visitScheduledCount,
      offerMadeCount: offerMadeCount ?? this.offerMadeCount,
    );
  }

  /// 빈 통계 생성
  factory BrokerStats.empty(String brokerId, String brokerName,
      {String? brokerCompany, String? brokerRegistrationNumber}) {
    final now = DateTime.now();
    return BrokerStats(
      brokerId: brokerId,
      brokerName: brokerName,
      brokerCompany: brokerCompany,
      brokerRegistrationNumber: brokerRegistrationNumber,
      createdAt: now,
      updatedAt: now,
    );
  }
}

/// 판매자에게 표시할 중개사 지표 요약
class BrokerMetricsSummary {
  final String brokerId;
  final String brokerName;
  final String? brokerCompany;

  /// 방문 성사율 (0.0 ~ 1.0)
  final double visitSuccessRate;

  /// 노쇼 비율 (0.0 ~ 1.0)
  final double noShowRate;

  /// 평균 제안가 편차 (1.0에 가까울수록 좋음)
  final double avgPriceDeviation;

  /// 평균 응답 시간 (초)
  final int avgResponseTimeSeconds;

  /// 거래 완료 건수
  final int completedDeals;

  /// 총 요청 수 (신뢰도 판단용)
  final int totalRequests;

  BrokerMetricsSummary({
    required this.brokerId,
    required this.brokerName,
    required this.visitSuccessRate,
    required this.noShowRate,
    required this.avgPriceDeviation,
    required this.avgResponseTimeSeconds,
    required this.completedDeals,
    required this.totalRequests,
    this.brokerCompany,
  });

  factory BrokerMetricsSummary.fromStats(BrokerStats stats) {
    return BrokerMetricsSummary(
      brokerId: stats.brokerId,
      brokerName: stats.brokerName,
      brokerCompany: stats.brokerCompany,
      visitSuccessRate: stats.visitSuccessRate,
      noShowRate: stats.noShowRate,
      avgPriceDeviation: stats.avgPriceDeviation,
      avgResponseTimeSeconds: stats.avgResponseTimeSeconds,
      completedDeals: stats.completedDeals,
      totalRequests: stats.totalRequests,
    );
  }

  /// 평균 응답 시간 포맷
  String get avgResponseTimeFormatted {
    if (avgResponseTimeSeconds < 60) return '$avgResponseTimeSeconds초';
    if (avgResponseTimeSeconds < 3600) {
      return '${avgResponseTimeSeconds ~/ 60}분';
    }
    if (avgResponseTimeSeconds < 86400) {
      return '${avgResponseTimeSeconds ~/ 3600}시간';
    }
    return '${avgResponseTimeSeconds ~/ 86400}일';
  }

  /// 데이터 충분성 (최소 5건 이상 요청이 있어야 신뢰할 수 있음)
  bool get hasEnoughData => totalRequests >= 5;

  /// 방문 성사율 등급
  String get visitSuccessRateGrade {
    if (visitSuccessRate >= 0.8) return '매우 높음';
    if (visitSuccessRate >= 0.6) return '높음';
    if (visitSuccessRate >= 0.4) return '보통';
    return '낮음';
  }

  /// 노쇼 위험도
  String get noShowRisk {
    if (noShowRate <= 0.05) return '매우 낮음';
    if (noShowRate <= 0.1) return '낮음';
    if (noShowRate <= 0.2) return '보통';
    return '높음';
  }

  /// 제안가 정직도
  String get priceHonesty {
    if (avgPriceDeviation >= 0.95) return '매우 정직';
    if (avgPriceDeviation >= 0.9) return '정직';
    if (avgPriceDeviation >= 0.8) return '보통';
    return '저가 압박 경향';
  }

  /// 응답 속도 등급
  String get responseSpeedGrade {
    if (avgResponseTimeSeconds < 1800) return '매우 빠름'; // 30분 이내
    if (avgResponseTimeSeconds < 3600) return '빠름'; // 1시간 이내
    if (avgResponseTimeSeconds < 86400) return '보통'; // 24시간 이내
    return '느림';
  }
}
