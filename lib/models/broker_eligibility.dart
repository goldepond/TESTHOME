import 'package:cloud_firestore/cloud_firestore.dart';

/// 중개사 자격 캐시 (broker_eligibility 컬렉션)
///
/// 면허 + 지역 관할을 *우선권 부여 시점에 동결*시키기 위한 캐시.
/// 클라이언트 읽기 가능 (목록/필터링), 쓰기는 *관리자 + 검증 함수만*.
class BrokerEligibility {
  final String brokerId;
  final String brokerUid;

  // 면허 정보
  final String licenseNumber;
  final DateTime? licenseVerifiedAt;
  final LicenseStatus licenseStatus;

  // 영업 가능 지역 (시군구 코드 배열)
  final List<String> jurisdictions;

  // 사무소 좌표 + 영업 반경
  final BrokerGeofence geofence;

  // 보완 C: 동시 우선권 카운터
  final int activeGrantsCount;
  final int activeGrantsCap; // 기본 5

  final DateTime updatedAt;

  const BrokerEligibility({
    required this.brokerId,
    required this.brokerUid,
    required this.licenseNumber,
    required this.licenseStatus,
    required this.geofence,
    required this.updatedAt,
    this.licenseVerifiedAt,
    this.jurisdictions = const [],
    this.activeGrantsCount = 0,
    this.activeGrantsCap = 5,
  });

  Map<String, dynamic> toMap() {
    return {
      'brokerId': brokerId,
      'brokerUid': brokerUid,
      'licenseNumber': licenseNumber,
      'licenseVerifiedAt': licenseVerifiedAt?.toIso8601String(),
      'licenseStatus': licenseStatus.name,
      'jurisdictions': jurisdictions,
      'geofence': geofence.toMap(),
      'activeGrantsCount': activeGrantsCount,
      'activeGrantsCap': activeGrantsCap,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory BrokerEligibility.fromMap(Map<String, dynamic> map) {
    return BrokerEligibility(
      brokerId: map['brokerId'] ?? '',
      brokerUid: map['brokerUid'] ?? '',
      licenseNumber: map['licenseNumber'] ?? '',
      licenseVerifiedAt: _parseDate(map['licenseVerifiedAt']),
      licenseStatus: LicenseStatus.values.firstWhere(
        (e) => e.name == map['licenseStatus'],
        orElse: () => LicenseStatus.pending,
      ),
      jurisdictions: List<String>.from(map['jurisdictions'] ?? const []),
      geofence: BrokerGeofence.fromMap(
        Map<String, dynamic>.from(map['geofence'] ?? const {}),
      ),
      activeGrantsCount: (map['activeGrantsCount'] as num?)?.toInt() ?? 0,
      activeGrantsCap: (map['activeGrantsCap'] as num?)?.toInt() ?? 5,
      updatedAt: _parseDate(map['updatedAt']) ?? DateTime.now(),
    );
  }

  factory BrokerEligibility.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    // brokerId가 본문에 없으면 doc.id를 사용 (컬렉션이 brokerId 키로 저장된다고 가정)
    return BrokerEligibility.fromMap({
      ...data,
      if (data['brokerId'] == null) 'brokerId': doc.id,
    });
  }

  BrokerEligibility copyWith({
    String? brokerId,
    String? brokerUid,
    String? licenseNumber,
    DateTime? licenseVerifiedAt,
    LicenseStatus? licenseStatus,
    List<String>? jurisdictions,
    BrokerGeofence? geofence,
    int? activeGrantsCount,
    int? activeGrantsCap,
    DateTime? updatedAt,
  }) {
    return BrokerEligibility(
      brokerId: brokerId ?? this.brokerId,
      brokerUid: brokerUid ?? this.brokerUid,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      licenseVerifiedAt: licenseVerifiedAt ?? this.licenseVerifiedAt,
      licenseStatus: licenseStatus ?? this.licenseStatus,
      jurisdictions: jurisdictions ?? this.jurisdictions,
      geofence: geofence ?? this.geofence,
      activeGrantsCount: activeGrantsCount ?? this.activeGrantsCount,
      activeGrantsCap: activeGrantsCap ?? this.activeGrantsCap,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 활성 우선권 한도 도달 여부
  bool get isCapReached => activeGrantsCount >= activeGrantsCap;

  /// 면허 검증 완료 + 한도 미도달
  bool get isEligible =>
      licenseStatus == LicenseStatus.verified && !isCapReached;
}

/// 중개사무소 지오펜스 (좌표 + 영업 반경)
class BrokerGeofence {
  final double lat;
  final double lng;
  final double radiusKm; // 기본 5km
  final String? geohash; // Task 04 — 1km 반경 prefix 쿼리용

  const BrokerGeofence({
    required this.lat,
    required this.lng,
    this.radiusKm = 5.0,
    this.geohash,
  });

  Map<String, dynamic> toMap() {
    return {
      'lat': lat,
      'lng': lng,
      'radiusKm': radiusKm,
      if (geohash != null) 'geohash': geohash,
    };
  }

  factory BrokerGeofence.fromMap(Map<String, dynamic> map) {
    return BrokerGeofence(
      lat: (map['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (map['lng'] as num?)?.toDouble() ?? 0.0,
      radiusKm: (map['radiusKm'] as num?)?.toDouble() ?? 5.0,
      geohash: map['geohash'] as String?,
    );
  }

  BrokerGeofence copyWith({
    double? lat,
    double? lng,
    double? radiusKm,
    String? geohash,
  }) {
    return BrokerGeofence(
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      radiusKm: radiusKm ?? this.radiusKm,
      geohash: geohash ?? this.geohash,
    );
  }
}

/// 면허 상태
enum LicenseStatus {
  verified, // 검증 완료
  pending, // 검증 대기
  invalid, // 면허 무효
  expired, // 면허 만료
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
