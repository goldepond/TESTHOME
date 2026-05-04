import 'package:cloud_firestore/cloud_firestore.dart';

/// 플랫폼 점유율 모니터링 지표 (platform_metrics 컬렉션)
///
/// docId 형식: `YYYYMMDD` — 일자별 1건.
/// 관리자만 읽기 가능, 쓰기는 Functions만.
class PlatformMetric {
  final String date; // 'YYYY-MM-DD' 또는 'YYYYMMDD'
  final int totalActiveListings;
  final int totalActiveBrokers;
  final double estimatedRegionMarketShare; // 0.0~1.0
  final AlertLevel alertLevel; // 0.3 도달 시 yellow

  /// 시도(region)별 활성 매물 수. Cloud Function `computeDailyMetricsScheduled` 적재.
  /// 키 예: '서울특별시', '경기도'.
  final Map<String, int> regionCounts;

  /// 시군구(district)별 활성 매물 수. 동일 함수 적재.
  /// 키 예: '강남구', '성남시 분당구'.
  final Map<String, int> districtCounts;

  final DateTime createdAt;

  const PlatformMetric({
    required this.date,
    required this.totalActiveListings,
    required this.totalActiveBrokers,
    required this.estimatedRegionMarketShare,
    required this.alertLevel,
    required this.createdAt,
    this.regionCounts = const {},
    this.districtCounts = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'totalActiveListings': totalActiveListings,
      'totalActiveBrokers': totalActiveBrokers,
      'estimatedRegionMarketShare': estimatedRegionMarketShare,
      'alertLevel': alertLevel.name,
      'regionCounts': regionCounts,
      'districtCounts': districtCounts,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory PlatformMetric.fromMap(Map<String, dynamic> map) {
    return PlatformMetric(
      date: map['date'] ?? '',
      totalActiveListings: (map['totalActiveListings'] as num?)?.toInt() ?? 0,
      totalActiveBrokers: (map['totalActiveBrokers'] as num?)?.toInt() ?? 0,
      estimatedRegionMarketShare:
          (map['estimatedRegionMarketShare'] as num?)?.toDouble() ?? 0.0,
      alertLevel: AlertLevel.values.firstWhere(
        (e) => e.name == map['alertLevel'],
        orElse: () => AlertLevel.green,
      ),
      regionCounts: _parseIntMap(map['regionCounts']),
      districtCounts: _parseIntMap(map['districtCounts']),
      createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
    );
  }

  factory PlatformMetric.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    // docId가 yyyymmdd라면 date 본문이 비어있을 때 보강
    return PlatformMetric.fromMap({
      ...data,
      if (data['date'] == null || (data['date'] as String).isEmpty)
        'date': doc.id,
    });
  }

  PlatformMetric copyWith({
    String? date,
    int? totalActiveListings,
    int? totalActiveBrokers,
    double? estimatedRegionMarketShare,
    AlertLevel? alertLevel,
    Map<String, int>? regionCounts,
    Map<String, int>? districtCounts,
    DateTime? createdAt,
  }) {
    return PlatformMetric(
      date: date ?? this.date,
      totalActiveListings: totalActiveListings ?? this.totalActiveListings,
      totalActiveBrokers: totalActiveBrokers ?? this.totalActiveBrokers,
      estimatedRegionMarketShare:
          estimatedRegionMarketShare ?? this.estimatedRegionMarketShare,
      alertLevel: alertLevel ?? this.alertLevel,
      regionCounts: regionCounts ?? this.regionCounts,
      districtCounts: districtCounts ?? this.districtCounts,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// 경고 임계 도달 여부 (yellow 이상)
  bool get isAlerting => alertLevel != AlertLevel.green;

  /// 시군구별 추정 점유율 — 해당 시군구 매물 수를 전국 활성 중개사*5 휴리스틱 분모로 나눈다.
  ///
  /// Cloud Function `computeDailyMetricsScheduled` 와 동일한 휴리스틱 적용:
  /// `share ≈ districtListings / max(totalActiveBrokers * 5, 1)`.
  /// 한국감정원 거래량 미연동 상태이므로 임시 추정값 (Task 06 §5.1 #6 인계).
  double districtShare(String district) {
    final listings = districtCounts[district] ?? 0;
    final denom = (totalActiveBrokers * 5).clamp(1, 1 << 30);
    return listings / denom;
  }
}

/// 점유율 알림 단계
enum AlertLevel {
  green, // 정상
  yellow, // 경고 (점유율 0.3 도달)
  red, // 위험 (대량 집중)
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

/// Firestore `Map<String, dynamic>` 형태의 카운트 맵을 `Map<String, int>`로 정규화.
/// 값이 num이 아니거나 키가 String이 아닌 항목은 무시.
Map<String, int> _parseIntMap(dynamic value) {
  if (value is! Map) return const {};
  final result = <String, int>{};
  value.forEach((dynamic k, dynamic v) {
    if (k is String && v is num) {
      result[k] = v.toInt();
    }
  });
  return result;
}
