/// 판매자 히스토리 모델
///
/// 판매자의 거래 이력을 자산화하여 다음 매도 시 활용합니다.
/// - 이전 거래에서 성과 좋은 중개사 추천
/// - 거래 패턴 분석
/// - 가격 조정 이력 참고
class SellerHistory {
  final String sellerId;
  final String sellerName;

  // 거래 이력
  final List<DealRecord> dealRecords; // 거래 기록 목록

  // 중개사 성과 기록
  final Map<String, BrokerPerformance> brokerPerformances; // brokerId -> 성과

  // 집계 통계
  final int totalProperties; // 총 등록 매물 수
  final int completedDeals; // 완료된 거래 수
  final double totalDealAmount; // 총 거래 금액
  final int avgDealDurationDays; // 평균 거래 기간 (일)

  // 메타데이터
  final DateTime createdAt;
  final DateTime updatedAt;

  SellerHistory({
    required this.sellerId,
    required this.sellerName,
    required this.createdAt,
    required this.updatedAt,
    this.dealRecords = const [],
    this.brokerPerformances = const {},
    this.totalProperties = 0,
    this.completedDeals = 0,
    this.totalDealAmount = 0,
    this.avgDealDurationDays = 0,
  });

  /// 성과 좋은 중개사 추천 (상위 N명)
  List<BrokerPerformance> getTopBrokers({int limit = 3}) {
    final brokers = brokerPerformances.values.toList()
      ..sort((a, b) => b.performanceScore.compareTo(a.performanceScore));
    return brokers.take(limit).toList();
  }

  /// 특정 지역에서 성과 좋은 중개사
  List<BrokerPerformance> getTopBrokersInRegion(String region, {int limit = 3}) {
    final brokers = brokerPerformances.values
        .where((b) => b.regions.contains(region))
        .toList()
      ..sort((a, b) => b.performanceScore.compareTo(a.performanceScore));
    return brokers.take(limit).toList();
  }

  Map<String, dynamic> toMap() {
    return {
      'sellerId': sellerId,
      'sellerName': sellerName,
      'dealRecords': dealRecords.map((e) => e.toMap()).toList(),
      'brokerPerformances':
          brokerPerformances.map((k, v) => MapEntry(k, v.toMap())),
      'totalProperties': totalProperties,
      'completedDeals': completedDeals,
      'totalDealAmount': totalDealAmount,
      'avgDealDurationDays': avgDealDurationDays,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory SellerHistory.fromMap(Map<String, dynamic> map) {
    return SellerHistory(
      sellerId: map['sellerId'] ?? '',
      sellerName: map['sellerName'] ?? '',
      dealRecords: (map['dealRecords'] as List?)
              ?.map((e) => DealRecord.fromMap(e))
              .toList() ??
          [],
      brokerPerformances:
          (map['brokerPerformances'] as Map<String, dynamic>?)?.map(
                (k, v) => MapEntry(k, BrokerPerformance.fromMap(v)),
              ) ??
              {},
      totalProperties: map['totalProperties']?.toInt() ?? 0,
      completedDeals: map['completedDeals']?.toInt() ?? 0,
      totalDealAmount: map['totalDealAmount']?.toDouble() ?? 0,
      avgDealDurationDays: map['avgDealDurationDays']?.toInt() ?? 0,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : DateTime.now(),
    );
  }

  SellerHistory copyWith({
    String? sellerId,
    String? sellerName,
    List<DealRecord>? dealRecords,
    Map<String, BrokerPerformance>? brokerPerformances,
    int? totalProperties,
    int? completedDeals,
    double? totalDealAmount,
    int? avgDealDurationDays,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SellerHistory(
      sellerId: sellerId ?? this.sellerId,
      sellerName: sellerName ?? this.sellerName,
      dealRecords: dealRecords ?? this.dealRecords,
      brokerPerformances: brokerPerformances ?? this.brokerPerformances,
      totalProperties: totalProperties ?? this.totalProperties,
      completedDeals: completedDeals ?? this.completedDeals,
      totalDealAmount: totalDealAmount ?? this.totalDealAmount,
      avgDealDurationDays: avgDealDurationDays ?? this.avgDealDurationDays,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 빈 히스토리 생성
  factory SellerHistory.empty(String sellerId, String sellerName) {
    final now = DateTime.now();
    return SellerHistory(
      sellerId: sellerId,
      sellerName: sellerName,
      createdAt: now,
      updatedAt: now,
    );
  }
}

/// 개별 거래 기록
class DealRecord {
  final String propertyId;
  final String address;
  final String region;

  // 가격 정보
  final double initialPrice; // 최초 희망가
  final double finalPrice; // 최종 거래가
  final List<PriceAdjustment> priceAdjustments; // 가격 조정 이력

  // 거래 정보
  final String finalBrokerId;
  final String finalBrokerName;
  final String transactionType; // 매매, 전세, 월세

  // 기간 정보
  final DateTime registeredAt; // 등록일
  final DateTime soldAt; // 거래 완료일
  final int durationDays; // 거래 기간

  // 방문 통계
  final int totalVisitRequests; // 총 방문 요청
  final int approvedVisits; // 승인된 방문

  DealRecord({
    required this.propertyId,
    required this.address,
    required this.region,
    required this.initialPrice,
    required this.finalPrice,
    required this.finalBrokerId,
    required this.finalBrokerName,
    required this.transactionType,
    required this.registeredAt,
    required this.soldAt,
    required this.durationDays,
    this.priceAdjustments = const [],
    this.totalVisitRequests = 0,
    this.approvedVisits = 0,
  });

  /// 가격 조정률 (최초 대비 최종)
  double get priceAdjustmentRate {
    if (initialPrice == 0) return 1.0;
    return finalPrice / initialPrice;
  }

  Map<String, dynamic> toMap() {
    return {
      'propertyId': propertyId,
      'address': address,
      'region': region,
      'initialPrice': initialPrice,
      'finalPrice': finalPrice,
      'priceAdjustments': priceAdjustments.map((e) => e.toMap()).toList(),
      'finalBrokerId': finalBrokerId,
      'finalBrokerName': finalBrokerName,
      'transactionType': transactionType,
      'registeredAt': registeredAt.toIso8601String(),
      'soldAt': soldAt.toIso8601String(),
      'durationDays': durationDays,
      'totalVisitRequests': totalVisitRequests,
      'approvedVisits': approvedVisits,
    };
  }

  factory DealRecord.fromMap(Map<String, dynamic> map) {
    return DealRecord(
      propertyId: map['propertyId'] ?? '',
      address: map['address'] ?? '',
      region: map['region'] ?? '',
      initialPrice: map['initialPrice']?.toDouble() ?? 0,
      finalPrice: map['finalPrice']?.toDouble() ?? 0,
      priceAdjustments: (map['priceAdjustments'] as List?)
              ?.map((e) => PriceAdjustment.fromMap(e))
              .toList() ??
          [],
      finalBrokerId: map['finalBrokerId'] ?? '',
      finalBrokerName: map['finalBrokerName'] ?? '',
      transactionType: map['transactionType'] ?? '매매',
      registeredAt: map['registeredAt'] != null
          ? DateTime.parse(map['registeredAt'])
          : DateTime.now(),
      soldAt: map['soldAt'] != null
          ? DateTime.parse(map['soldAt'])
          : DateTime.now(),
      durationDays: map['durationDays']?.toInt() ?? 0,
      totalVisitRequests: map['totalVisitRequests']?.toInt() ?? 0,
      approvedVisits: map['approvedVisits']?.toInt() ?? 0,
    );
  }
}

/// 가격 조정 이력
class PriceAdjustment {
  final double previousPrice;
  final double newPrice;
  final DateTime adjustedAt;
  final String? reason;

  PriceAdjustment({
    required this.previousPrice,
    required this.newPrice,
    required this.adjustedAt,
    this.reason,
  });

  /// 조정률
  double get adjustmentRate {
    if (previousPrice == 0) return 1.0;
    return newPrice / previousPrice;
  }

  Map<String, dynamic> toMap() {
    return {
      'previousPrice': previousPrice,
      'newPrice': newPrice,
      'adjustedAt': adjustedAt.toIso8601String(),
      'reason': reason,
    };
  }

  factory PriceAdjustment.fromMap(Map<String, dynamic> map) {
    return PriceAdjustment(
      previousPrice: map['previousPrice']?.toDouble() ?? 0,
      newPrice: map['newPrice']?.toDouble() ?? 0,
      adjustedAt: map['adjustedAt'] != null
          ? DateTime.parse(map['adjustedAt'])
          : DateTime.now(),
      reason: map['reason'],
    );
  }
}

/// 특정 판매자에 대한 중개사 성과
class BrokerPerformance {
  final String brokerId;
  final String brokerName;
  final String? brokerCompany;

  // 거래 통계
  final int totalDeals; // 이 판매자와의 총 거래 수
  final double totalAmount; // 총 거래 금액
  final int avgDurationDays; // 평균 거래 기간

  // 성과 지표
  final double avgPriceAchievementRate; // 평균 가격 달성률 (최종가/희망가)
  final int visitSuccessCount; // 방문 성사 횟수
  final int noShowCount; // 노쇼 횟수

  // 활동 지역
  final List<String> regions; // 거래한 지역 목록

  // 마지막 거래
  final DateTime? lastDealAt;

  BrokerPerformance({
    required this.brokerId,
    required this.brokerName,
    this.brokerCompany,
    this.totalDeals = 0,
    this.totalAmount = 0,
    this.avgDurationDays = 0,
    this.avgPriceAchievementRate = 1.0,
    this.visitSuccessCount = 0,
    this.noShowCount = 0,
    this.regions = const [],
    this.lastDealAt,
  });

  /// 성과 점수 (내부 계산용)
  /// 거래 수 30% + 가격달성률 40% + (1-노쇼율) 30%
  double get performanceScore {
    final dealScore = (totalDeals / 10).clamp(0.0, 1.0) * 0.3;
    final priceScore = avgPriceAchievementRate.clamp(0.0, 1.0) * 0.4;
    final noShowScore = (visitSuccessCount > 0
            ? (1 - noShowCount / visitSuccessCount)
            : 1.0) *
        0.3;
    return dealScore + priceScore + noShowScore;
  }

  Map<String, dynamic> toMap() {
    return {
      'brokerId': brokerId,
      'brokerName': brokerName,
      'brokerCompany': brokerCompany,
      'totalDeals': totalDeals,
      'totalAmount': totalAmount,
      'avgDurationDays': avgDurationDays,
      'avgPriceAchievementRate': avgPriceAchievementRate,
      'visitSuccessCount': visitSuccessCount,
      'noShowCount': noShowCount,
      'regions': regions,
      'lastDealAt': lastDealAt?.toIso8601String(),
    };
  }

  factory BrokerPerformance.fromMap(Map<String, dynamic> map) {
    return BrokerPerformance(
      brokerId: map['brokerId'] ?? '',
      brokerName: map['brokerName'] ?? '',
      brokerCompany: map['brokerCompany'],
      totalDeals: map['totalDeals']?.toInt() ?? 0,
      totalAmount: map['totalAmount']?.toDouble() ?? 0,
      avgDurationDays: map['avgDurationDays']?.toInt() ?? 0,
      avgPriceAchievementRate: map['avgPriceAchievementRate']?.toDouble() ?? 1.0,
      visitSuccessCount: map['visitSuccessCount']?.toInt() ?? 0,
      noShowCount: map['noShowCount']?.toInt() ?? 0,
      regions: List<String>.from(map['regions'] ?? []),
      lastDealAt: map['lastDealAt'] != null
          ? DateTime.parse(map['lastDealAt'])
          : null,
    );
  }

  BrokerPerformance copyWith({
    String? brokerId,
    String? brokerName,
    String? brokerCompany,
    int? totalDeals,
    double? totalAmount,
    int? avgDurationDays,
    double? avgPriceAchievementRate,
    int? visitSuccessCount,
    int? noShowCount,
    List<String>? regions,
    DateTime? lastDealAt,
  }) {
    return BrokerPerformance(
      brokerId: brokerId ?? this.brokerId,
      brokerName: brokerName ?? this.brokerName,
      brokerCompany: brokerCompany ?? this.brokerCompany,
      totalDeals: totalDeals ?? this.totalDeals,
      totalAmount: totalAmount ?? this.totalAmount,
      avgDurationDays: avgDurationDays ?? this.avgDurationDays,
      avgPriceAchievementRate:
          avgPriceAchievementRate ?? this.avgPriceAchievementRate,
      visitSuccessCount: visitSuccessCount ?? this.visitSuccessCount,
      noShowCount: noShowCount ?? this.noShowCount,
      regions: regions ?? this.regions,
      lastDealAt: lastDealAt ?? this.lastDealAt,
    );
  }
}
