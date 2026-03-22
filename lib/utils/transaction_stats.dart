import '../api_request/real_transaction_service.dart';

/// 실거래가 통계 분석 유틸리티
class TransactionStats {
  final List<RealTransaction> transactions;
  final String transactionType;

  TransactionStats({
    required this.transactions,
    required this.transactionType,
  });

  /// 데이터 유효성
  bool get hasData => transactions.isNotEmpty;
  int get count => transactions.length;

  /// 가격 목록 (매매: dealAmount, 전세/월세: deposit)
  List<int> get prices => transactions.map((t) => t.dealAmount).toList();

  /// 평균가
  int get average {
    if (!hasData) return 0;
    return prices.reduce((a, b) => a + b) ~/ prices.length;
  }

  /// 최고가
  int get maxPrice {
    if (!hasData) return 0;
    return prices.reduce((a, b) => a > b ? a : b);
  }

  /// 최저가
  int get minPrice {
    if (!hasData) return 0;
    return prices.reduce((a, b) => a < b ? a : b);
  }

  /// 중간값 (Median)
  int get median {
    if (!hasData) return 0;
    final sorted = List<int>.from(prices)..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) {
      return sorted[mid];
    }
    return (sorted[mid - 1] + sorted[mid]) ~/ 2;
  }

  /// 입력 가격이 평균 대비 몇 % 인지 계산
  /// 음수면 저렴, 양수면 비쌈
  double compareToAverage(int price) {
    if (average == 0) return 0;
    return ((price - average) / average) * 100;
  }

  /// 입력 가격에 대한 평가 문구
  String getPriceEvaluation(int price) {
    final diff = compareToAverage(price);
    final absPercentage = diff.abs().toStringAsFixed(0);

    if (diff <= -10) {
      return '평균보다 $absPercentage% 저렴해요';
    } else if (diff <= -5) {
      return '평균보다 $absPercentage% 저렴한 편이에요';
    } else if (diff < 5) {
      return '평균 수준이에요';
    } else if (diff < 10) {
      return '평균보다 $absPercentage% 높은 편이에요';
    } else {
      return '평균보다 $absPercentage% 높아요';
    }
  }

  /// 가격대별 거래 속도 가이드
  PriceSpeedGuide getPriceSpeedGuide() {
    final avg = average;
    return PriceSpeedGuide(
      fastThreshold: (avg * 0.95).toInt(), // 평균 -5% 이하
      normalMin: (avg * 0.95).toInt(),
      normalMax: (avg * 1.05).toInt(),
      slowThreshold: (avg * 1.05).toInt(), // 평균 +5% 이상
    );
  }

  /// 월별 평균가 계산 (트렌드 분석용)
  Map<String, MonthlyStats> getMonthlyStats() {
    final Map<String, List<RealTransaction>> byMonth = {};

    for (final t in transactions) {
      final key = '${t.dealYear}-${t.dealMonth.toString().padLeft(2, '0')}';
      byMonth.putIfAbsent(key, () => []).add(t);
    }

    final result = <String, MonthlyStats>{};
    byMonth.forEach((key, list) {
      final amounts = list.map((t) => t.dealAmount).toList();
      final avg = amounts.reduce((a, b) => a + b) ~/ amounts.length;
      result[key] = MonthlyStats(
        yearMonth: key,
        count: list.length,
        average: avg,
        min: amounts.reduce((a, b) => a < b ? a : b),
        max: amounts.reduce((a, b) => a > b ? a : b),
      );
    });

    return result;
  }

  /// 가격 트렌드 계산 (최근 vs 이전)
  /// 최근 3개월 vs 그 이전 3개월 비교
  PriceTrend? calculateTrend() {
    if (transactions.length < 3) return null;

    final now = DateTime.now();
    final threeMonthsAgo = DateTime(now.year, now.month - 3);

    final recent = transactions.where((t) => t.dealDate.isAfter(threeMonthsAgo)).toList();
    final older = transactions.where((t) => t.dealDate.isBefore(threeMonthsAgo)).toList();

    if (recent.isEmpty || older.isEmpty) {
      // 데이터가 한쪽에만 있으면 첫/마지막 비교
      if (transactions.length >= 2) {
        final sorted = List<RealTransaction>.from(transactions)
          ..sort((a, b) => a.dealDate.compareTo(b.dealDate));
        final oldAvg = sorted.take(sorted.length ~/ 2).map((t) => t.dealAmount).reduce((a, b) => a + b) ~/ (sorted.length ~/ 2);
        final newAvg = sorted.skip(sorted.length ~/ 2).map((t) => t.dealAmount).reduce((a, b) => a + b) ~/ (sorted.length - sorted.length ~/ 2);
        final changePercent = ((newAvg - oldAvg) / oldAvg) * 100;
        return PriceTrend(
          changePercent: changePercent,
          direction: changePercent > 1 ? TrendDirection.up : (changePercent < -1 ? TrendDirection.down : TrendDirection.stable),
          recentAverage: newAvg,
          previousAverage: oldAvg,
        );
      }
      return null;
    }

    final recentAvg = recent.map((t) => t.dealAmount).reduce((a, b) => a + b) ~/ recent.length;
    final olderAvg = older.map((t) => t.dealAmount).reduce((a, b) => a + b) ~/ older.length;
    final changePercent = ((recentAvg - olderAvg) / olderAvg) * 100;

    return PriceTrend(
      changePercent: changePercent,
      direction: changePercent > 1 ? TrendDirection.up : (changePercent < -1 ? TrendDirection.down : TrendDirection.stable),
      recentAverage: recentAvg,
      previousAverage: olderAvg,
    );
  }

  /// 평형별 그룹화
  Map<String, List<RealTransaction>> groupByArea() {
    final Map<String, List<RealTransaction>> result = {};

    for (final t in transactions) {
      // 10㎡ 단위로 그룹화 (예: 80~89㎡)
      final groupKey = _getAreaGroupKey(t.area);
      result.putIfAbsent(groupKey, () => []).add(t);
    }

    return result;
  }

  /// 사용 가능한 평형 목록 (필터용)
  List<AreaFilter> get availableAreaFilters {
    final grouped = groupByArea();
    final result = grouped.entries.map((e) {
      final amounts = e.value.map((t) => t.dealAmount).toList();
      final avg = amounts.reduce((a, b) => a + b) ~/ amounts.length;
      return AreaFilter(
        label: e.key,
        count: e.value.length,
        minArea: e.value.map((t) => t.area).reduce((a, b) => a < b ? a : b),
        maxArea: e.value.map((t) => t.area).reduce((a, b) => a > b ? a : b),
        averagePrice: avg,
      );
    }).toList();

    result.sort((a, b) => a.minArea.compareTo(b.minArea));
    return result;
  }

  /// 층별 그룹화
  Map<String, List<RealTransaction>> groupByFloor() {
    final Map<String, List<RealTransaction>> result = {};

    for (final t in transactions) {
      if (t.floor <= 0) continue; // 단독/다가구 제외
      final groupKey = _getFloorGroupKey(t.floor);
      result.putIfAbsent(groupKey, () => []).add(t);
    }

    return result;
  }

  /// 사용 가능한 층 필터 목록
  List<FloorFilter> get availableFloorFilters {
    final grouped = groupByFloor();
    final result = grouped.entries.map((e) {
      final amounts = e.value.map((t) => t.dealAmount).toList();
      final avg = amounts.reduce((a, b) => a + b) ~/ amounts.length;
      return FloorFilter(
        label: e.key,
        count: e.value.length,
        averagePrice: avg,
      );
    }).toList();

    // 정렬: 저층 → 중층 → 고층
    final order = ['저층 (1~5층)', '중층 (6~10층)', '고층 (11~15층)', '초고층 (16층+)'];
    result.sort((a, b) => order.indexOf(a.label).compareTo(order.indexOf(b.label)));
    return result;
  }

  /// 평형 그룹 키 생성
  String _getAreaGroupKey(double area) {
    if (area < 40) return '40㎡ 미만';
    if (area < 60) return '40~59㎡';
    if (area < 85) return '60~84㎡';
    if (area < 115) return '85~114㎡';
    if (area < 135) return '115~134㎡';
    return '135㎡ 이상';
  }

  /// 층 그룹 키 생성
  String _getFloorGroupKey(int floor) {
    if (floor <= 5) return '저층 (1~5층)';
    if (floor <= 10) return '중층 (6~10층)';
    if (floor <= 15) return '고층 (11~15층)';
    return '초고층 (16층+)';
  }

  /// 필터 적용된 새 TransactionStats 반환
  TransactionStats filtered({
    double? minArea,
    double? maxArea,
    int? minFloor,
    int? maxFloor,
  }) {
    final filtered = transactions.where((t) {
      if (minArea != null && t.area < minArea) return false;
      if (maxArea != null && t.area > maxArea) return false;
      if (minFloor != null && t.floor < minFloor) return false;
      if (maxFloor != null && t.floor > maxFloor) return false;
      return true;
    }).toList();

    return TransactionStats(
      transactions: filtered,
      transactionType: transactionType,
    );
  }
}

/// 가격대별 거래 속도 가이드
class PriceSpeedGuide {
  final int fastThreshold; // 이 가격 이하면 빠른 거래
  final int normalMin;
  final int normalMax;
  final int slowThreshold; // 이 가격 이상이면 느린 거래

  const PriceSpeedGuide({
    required this.fastThreshold,
    required this.normalMin,
    required this.normalMax,
    required this.slowThreshold,
  });

  String getSpeedLabel(int price) {
    if (price <= fastThreshold) return '빠른 거래 예상';
    if (price <= normalMax) return '평균 속도';
    return '협상 여지 필요';
  }
}

/// 월별 통계
class MonthlyStats {
  final String yearMonth;
  final int count;
  final int average;
  final int min;
  final int max;

  const MonthlyStats({
    required this.yearMonth,
    required this.count,
    required this.average,
    required this.min,
    required this.max,
  });
}

/// 가격 트렌드
class PriceTrend {
  final double changePercent;
  final TrendDirection direction;
  final int recentAverage;
  final int previousAverage;

  const PriceTrend({
    required this.changePercent,
    required this.direction,
    required this.recentAverage,
    required this.previousAverage,
  });

  String get trendText {
    final absPercent = changePercent.abs().toStringAsFixed(1);
    switch (direction) {
      case TrendDirection.up:
        return '↑ $absPercent% 상승';
      case TrendDirection.down:
        return '↓ $absPercent% 하락';
      case TrendDirection.stable:
        return '→ 보합';
    }
  }
}

enum TrendDirection { up, down, stable }

/// 평형 필터
class AreaFilter {
  final String label;
  final int count;
  final double minArea;
  final double maxArea;
  final int averagePrice;

  const AreaFilter({
    required this.label,
    required this.count,
    required this.minArea,
    required this.maxArea,
    required this.averagePrice,
  });
}

/// 층 필터
class FloorFilter {
  final String label;
  final int count;
  final int averagePrice;

  const FloorFilter({
    required this.label,
    required this.count,
    required this.averagePrice,
  });
}

/// 중개 수수료 계산기
class BrokerFeeCalculator {
  /// 매매 중개 수수료 계산 (2024년 기준)
  static BrokerFee calculateSaleFee(int dealAmount) {
    // dealAmount는 만원 단위
    final amountInWon = dealAmount * 10000;

    double rate;
    int maxFee;

    if (amountInWon < 50000000) {
      // 5천만원 미만: 0.6%, 최대 25만원
      rate = 0.006;
      maxFee = 250000;
    } else if (amountInWon < 200000000) {
      // 5천만원 ~ 2억원 미만: 0.5%, 최대 80만원
      rate = 0.005;
      maxFee = 800000;
    } else if (amountInWon < 900000000) {
      // 2억원 ~ 9억원 미만: 0.4%
      rate = 0.004;
      maxFee = 0; // 상한 없음
    } else if (amountInWon < 1200000000) {
      // 9억원 ~ 12억원 미만: 0.5%
      rate = 0.005;
      maxFee = 0;
    } else if (amountInWon < 1500000000) {
      // 12억원 ~ 15억원 미만: 0.6%
      rate = 0.006;
      maxFee = 0;
    } else {
      // 15억원 이상: 0.7%
      rate = 0.007;
      maxFee = 0;
    }

    var fee = (amountInWon * rate).round();
    if (maxFee > 0 && fee > maxFee) {
      fee = maxFee;
    }

    return BrokerFee(
      amount: fee,
      rate: rate,
      description: '매매 중개 수수료',
    );
  }

  /// 전세 중개 수수료 계산
  static BrokerFee calculateJeonseFee(int depositAmount) {
    final amountInWon = depositAmount * 10000;

    double rate;
    int maxFee;

    if (amountInWon < 50000000) {
      rate = 0.005;
      maxFee = 200000;
    } else if (amountInWon < 100000000) {
      rate = 0.004;
      maxFee = 300000;
    } else if (amountInWon < 600000000) {
      rate = 0.003;
      maxFee = 0;
    } else if (amountInWon < 1200000000) {
      rate = 0.004;
      maxFee = 0;
    } else if (amountInWon < 1500000000) {
      rate = 0.005;
      maxFee = 0;
    } else {
      rate = 0.006;
      maxFee = 0;
    }

    var fee = (amountInWon * rate).round();
    if (maxFee > 0 && fee > maxFee) {
      fee = maxFee;
    }

    return BrokerFee(
      amount: fee,
      rate: rate,
      description: '전세 중개 수수료',
    );
  }

  /// 월세 중개 수수료 계산
  /// 환산보증금 = 보증금 + (월세 × 100)
  static BrokerFee calculateMonthlyRentFee(int deposit, int monthlyRent) {
    final convertedDeposit = deposit + (monthlyRent * 100);
    final amountInWon = convertedDeposit * 10000;

    double rate;
    int maxFee;

    if (amountInWon < 50000000) {
      rate = 0.005;
      maxFee = 200000;
    } else if (amountInWon < 100000000) {
      rate = 0.004;
      maxFee = 300000;
    } else if (amountInWon < 600000000) {
      rate = 0.003;
      maxFee = 0;
    } else if (amountInWon < 1200000000) {
      rate = 0.004;
      maxFee = 0;
    } else if (amountInWon < 1500000000) {
      rate = 0.005;
      maxFee = 0;
    } else {
      rate = 0.006;
      maxFee = 0;
    }

    var fee = (amountInWon * rate).round();
    if (maxFee > 0 && fee > maxFee) {
      fee = maxFee;
    }

    return BrokerFee(
      amount: fee,
      rate: rate,
      description: '월세 중개 수수료 (환산보증금 기준)',
      convertedDeposit: convertedDeposit,
    );
  }

  /// 수수료 포맷팅 (원 → 한글)
  static String formatFee(int fee) {
    if (fee >= 10000) {
      final man = fee ~/ 10000;
      final remainder = fee % 10000;
      if (remainder > 0) {
        return '약 $man만 $remainder원';
      }
      return '약 $man만원';
    }
    return '약 $fee원';
  }
}

/// 중개 수수료 결과
class BrokerFee {
  final int amount; // 원 단위
  final double rate;
  final String description;
  final int? convertedDeposit; // 월세의 경우 환산보증금

  const BrokerFee({
    required this.amount,
    required this.rate,
    required this.description,
    this.convertedDeposit,
  });

  String get formatted => BrokerFeeCalculator.formatFee(amount);
  String get ratePercent => '${(rate * 100).toStringAsFixed(1)}%';
}
