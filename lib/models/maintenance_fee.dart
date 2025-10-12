import 'package:flutter/material.dart';

class MaintenanceFee {
  final double amount; // 관리비 금액
  final double area; // 면적 (㎡)
  final List<String> includedItems; // 포함 항목
  final List<String> excludedItems; // 제외 항목
  final String region; // 지역
  final DateTime? lastUpdated; // 최종 업데이트 날짜
  final List<MonthlyFee> monthlyHistory; // 월별 내역

  MaintenanceFee({
    required this.amount,
    required this.area,
    required this.includedItems,
    required this.excludedItems,
    required this.region,
    this.lastUpdated,
    this.monthlyHistory = const [],
  });

  // 면적당 환산 관리비
  double get amountPerArea => area > 0 ? amount / area : 0;

  // 포함 항목 개수
  int get includedCount => includedItems.length;

  // 제외 항목 개수
  int get excludedCount => excludedItems.length;

  // 관리비 수준 판정 (높음/보통/낮음)
  MaintenanceFeeLevel get level {
    if (amountPerArea >= 1500) return MaintenanceFeeLevel.high;
    if (amountPerArea >= 800) return MaintenanceFeeLevel.normal;
    return MaintenanceFeeLevel.low;
  }

  // 경고 여부 (포함 항목이 적은데 금액이 높은 경우)
  bool get hasWarning {
    return includedCount <= 2 && amountPerArea >= 1200;
  }

  // 경고 메시지
  String get warningMessage {
    if (!hasWarning) return '';
    
    final missingItems = ['엘리베이터', '경비', '청소', '수도', '전기', '가스']
        .where((item) => !includedItems.contains(item))
        .take(3)
        .join('/');
    
    return '$missingItems 없음 + 관리비 ${amount.toStringAsFixed(0)}만원 → 높은 편 경고';
  }

  // 지역 평균 대비 차이 (시뮬레이션)
  double get regionDifference {
    // 실제로는 지역 평균 데이터를 가져와야 함
    final regionAverage = _getRegionAverage(region);
    return amountPerArea - regionAverage;
  }

  // 지역 평균 대비 퍼센트
  double get regionDifferencePercent {
    final regionAverage = _getRegionAverage(region);
    if (regionAverage == 0) return 0;
    return ((amountPerArea - regionAverage) / regionAverage) * 100;
  }

  // 지역 평균 (시뮬레이션)
  double _getRegionAverage(String region) {
    switch (region) {
      case '강남구':
        return 1200;
      case '서초구':
        return 1100;
      case '마포구':
        return 900;
      case '용산구':
        return 1000;
      default:
        return 1000;
    }
  }

  // 표시용 문구
  String get displayText {
    final includedText = includedItems.isNotEmpty 
        ? includedItems.join('/') 
        : '포함 항목 없음';
    final excludedText = excludedItems.isNotEmpty 
        ? excludedItems.join('/') 
        : '';
    
    String text = '관리비 ${amount.toStringAsFixed(0)}원';
    if (includedText != '포함 항목 없음') {
      text += ' · $includedText 포함';
    }
    if (excludedText.isNotEmpty) {
      text += ' · $excludedText 제외';
    }
    
    return text;
  }

  // 지역 평균 대비 문구
  String get regionComparisonText {
    final diff = regionDifferencePercent;
    if (diff.abs() < 5) return '지역 평균과 비슷';
    
    final direction = diff > 0 ? '+' : '';
    final level = diff > 20 ? '높음' : diff > 10 ? '높은 편' : '보통';
    
    return '지역 평균 대비 $direction${diff.toStringAsFixed(0)}% ($level)';
  }

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'area': area,
      'includedItems': includedItems,
      'excludedItems': excludedItems,
      'region': region,
      'lastUpdated': lastUpdated?.toIso8601String(),
      'monthlyHistory': monthlyHistory.map((e) => e.toMap()).toList(),
    };
  }

  factory MaintenanceFee.fromMap(Map<String, dynamic> map) {
    return MaintenanceFee(
      amount: (map['amount'] ?? 0).toDouble(),
      area: (map['area'] ?? 0).toDouble(),
      includedItems: List<String>.from(map['includedItems'] ?? []),
      excludedItems: List<String>.from(map['excludedItems'] ?? []),
      region: map['region'] ?? '',
      lastUpdated: map['lastUpdated'] != null 
          ? DateTime.parse(map['lastUpdated']) 
          : null,
      monthlyHistory: (map['monthlyHistory'] as List<dynamic>?)
          ?.map((e) => MonthlyFee.fromMap(e))
          .toList() ?? [],
    );
  }

  MaintenanceFee copyWith({
    double? amount,
    double? area,
    List<String>? includedItems,
    List<String>? excludedItems,
    String? region,
    DateTime? lastUpdated,
    List<MonthlyFee>? monthlyHistory,
  }) {
    return MaintenanceFee(
      amount: amount ?? this.amount,
      area: area ?? this.area,
      includedItems: includedItems ?? this.includedItems,
      excludedItems: excludedItems ?? this.excludedItems,
      region: region ?? this.region,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      monthlyHistory: monthlyHistory ?? this.monthlyHistory,
    );
  }
}

// 관리비 수준
enum MaintenanceFeeLevel {
  low,    // 낮음
  normal, // 보통
  high,   // 높음
}

extension MaintenanceFeeLevelExtension on MaintenanceFeeLevel {
  String get displayName {
    switch (this) {
      case MaintenanceFeeLevel.low:
        return '낮음';
      case MaintenanceFeeLevel.normal:
        return '보통';
      case MaintenanceFeeLevel.high:
        return '높음';
    }
  }

  Color get color {
    switch (this) {
      case MaintenanceFeeLevel.low:
        return Colors.green;
      case MaintenanceFeeLevel.normal:
        return Colors.orange;
      case MaintenanceFeeLevel.high:
        return Colors.red;
    }
  }

  IconData get icon {
    switch (this) {
      case MaintenanceFeeLevel.low:
        return Icons.trending_down;
      case MaintenanceFeeLevel.normal:
        return Icons.trending_flat;
      case MaintenanceFeeLevel.high:
        return Icons.trending_up;
    }
  }
}

// 월별 관리비 내역
class MonthlyFee {
  final DateTime date;
  final double amount;
  final String? note;

  MonthlyFee({
    required this.date,
    required this.amount,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'amount': amount,
      'note': note,
    };
  }

  factory MonthlyFee.fromMap(Map<String, dynamic> map) {
    return MonthlyFee(
      date: DateTime.parse(map['date']),
      amount: (map['amount'] ?? 0).toDouble(),
      note: map['note'],
    );
  }
}

// 관리비 필터 옵션
class MaintenanceFeeFilter {
  final double? maxAmount;
  final List<String>? requiredItems;
  final MaintenanceFeeLevel? maxLevel;

  MaintenanceFeeFilter({
    this.maxAmount,
    this.requiredItems,
    this.maxLevel,
  });

  bool matches(MaintenanceFee fee) {
    if (maxAmount != null && fee.amount > maxAmount!) {
      return false;
    }
    
    if (requiredItems != null) {
      for (final item in requiredItems!) {
        if (!fee.includedItems.contains(item)) {
          return false;
        }
      }
    }
    
    if (maxLevel != null && fee.level.index > maxLevel!.index) {
      return false;
    }
    
    return true;
  }
}

