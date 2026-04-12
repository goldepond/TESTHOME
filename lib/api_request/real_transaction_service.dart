import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:property/constants/app_constants.dart';
import 'package:property/constants/property_constants.dart';
import 'package:property/utils/api_helper.dart';
import 'package:property/utils/logger.dart';

/// 주택 유형
enum HousingType {
  apartment, // 아파트
  rowHouse, // 연립다세대
  singleHouse, // 단독/다가구
}

/// 면적 카테고리 (비슷한 면적끼리 비교해야 의미있는 시세 참고 가능)
enum AreaCategory {
  /// 초소형: 40㎡ 미만 (~12평) - 원룸, 1인가구
  compact(0, 40, '초소형', '~40㎡'),

  /// 소형: 40~59㎡ (12~18평) - 신혼, 2인가구
  small(40, 60, '소형', '40~59㎡'),

  /// 중형: 60~85㎡ (18~26평) - 3~4인 표준가구
  medium(60, 85, '중형', '60~84㎡'),

  /// 대형: 85㎡ 이상 (26평~) - 대가족
  large(85, double.infinity, '대형', '85㎡~');

  final double minArea;
  final double maxArea;
  final String label;
  final String description;

  const AreaCategory(this.minArea, this.maxArea, this.label, this.description);

  /// 면적으로 카테고리 판별
  static AreaCategory fromArea(double area) {
    if (area < 40) return AreaCategory.compact;
    if (area < 60) return AreaCategory.small;
    if (area < 85) return AreaCategory.medium;
    return AreaCategory.large;
  }

  /// 해당 카테고리에 포함되는지 확인
  bool contains(double area) => area >= minArea && area < maxArea;
}

/// 검색 범위 (유연성 옵션)
enum SearchScope {
  /// 같은 도로 (도로명 매칭)
  sameRoad('같은 도로', '같은 도로명의 모든 거래'),

  /// 같은 동 전체 (법정동 내 모든 거래)
  sameDong('같은 동 전체', '같은 법정동 내 모든 거래'),

  /// 같은 구 전체 (LAWD_CD 5자리 - 시군구 단위)
  sameDistrict('같은 구 전체', '시군구 내 모든 거래');

  final String label;
  final String description;

  const SearchScope(this.label, this.description);
}

/// 층수 카테고리
enum FloorCategory {
  /// 저층: 1~5층
  low(1, 5, '저층', '1~5층'),

  /// 중층: 6~15층
  mid(6, 15, '중층', '6~15층'),

  /// 고층: 16층 이상
  high(16, 999, '고층', '16층~');

  final int minFloor;
  final int maxFloor;
  final String label;
  final String description;

  const FloorCategory(this.minFloor, this.maxFloor, this.label, this.description);

  /// 층수로 카테고리 판별
  static FloorCategory fromFloor(int floor) {
    if (floor <= 5) return FloorCategory.low;
    if (floor <= 15) return FloorCategory.mid;
    return FloorCategory.high;
  }

  /// 해당 카테고리에 포함되는지 확인
  bool contains(int floor) => floor >= minFloor && floor <= maxFloor;
}

/// 건축년도 카테고리
enum BuildYearCategory {
  /// 신축: 5년 이내
  brandNew(0, 5, '신축', '5년 이내'),

  /// 준신축: 5~10년
  newer(5, 10, '준신축', '5~10년'),

  /// 10~20년
  middle(10, 20, '10~20년', '10~20년'),

  /// 20년 이상
  old(20, 100, '20년+', '20년 이상');

  final int minAge;
  final int maxAge;
  final String label;
  final String description;

  const BuildYearCategory(this.minAge, this.maxAge, this.label, this.description);

  /// 건축년도로 카테고리 판별
  static BuildYearCategory? fromBuildYear(String? buildYear) {
    if (buildYear == null) return null;
    final year = int.tryParse(buildYear);
    if (year == null) return null;
    final age = DateTime.now().year - year;
    if (age < 5) return BuildYearCategory.brandNew;
    if (age < 10) return BuildYearCategory.newer;
    if (age < 20) return BuildYearCategory.middle;
    return BuildYearCategory.old;
  }

  /// 해당 카테고리에 포함되는지 확인
  bool containsYear(String? buildYear) {
    if (buildYear == null) return false;
    final year = int.tryParse(buildYear);
    if (year == null) return false;
    final age = DateTime.now().year - year;
    return age >= minAge && age < maxAge;
  }
}

/// 거래유형 (매매 전용)
enum DealingType {
  /// 중개거래
  broker('중개거래'),

  /// 직거래
  direct('직거래');

  final String label;

  const DealingType(this.label);

  /// API 값으로 판별
  static DealingType? fromValue(String? value) {
    if (value == null) return null;
    final normalized = value.trim();
    if (normalized.contains('직거래')) return DealingType.direct;
    if (normalized.contains('중개')) return DealingType.broker;
    return null;
  }

  /// 해당 타입과 일치하는지
  bool matches(String? value) {
    if (value == null) return false;
    final normalized = value.trim();
    switch (this) {
      case DealingType.broker:
        return normalized.contains('중개');
      case DealingType.direct:
        return normalized.contains('직거래');
    }
  }
}

/// 계약구분 (전월세 전용)
enum ContractTypeFilter {
  /// 신규 계약
  newContract('신규'),

  /// 갱신 계약
  renewal('갱신');

  final String label;

  const ContractTypeFilter(this.label);

  /// 해당 타입과 일치하는지
  bool matches(String? value) {
    if (value == null) return false;
    return value.contains(label);
  }
}

/// 거래 당사자 구분 (개인/법인)
enum PartyType {
  /// 개인
  individual('개인'),

  /// 법인
  corporation('법인');

  final String label;

  const PartyType(this.label);

  /// 해당 타입과 일치하는지
  bool matches(String? value) {
    if (value == null) return false;
    return value.contains(label);
  }
}

/// 가격대 필터
enum PriceRange {
  /// 1억 미만
  under1(0, 10000, '1억 미만', '~1억'),

  /// 1~3억
  range1to3(10000, 30000, '1~3억', '1~3억'),

  /// 3~5억
  range3to5(30000, 50000, '3~5억', '3~5억'),

  /// 5~10억
  range5to10(50000, 100000, '5~10억', '5~10억'),

  /// 10~20억
  range10to20(100000, 200000, '10~20억', '10~20억'),

  /// 20억 이상
  over20(200000, 9999999, '20억+', '20억 이상');

  final int minPrice; // 만원
  final int maxPrice; // 만원
  final String label;
  final String description;

  const PriceRange(this.minPrice, this.maxPrice, this.label, this.description);

  /// 가격으로 카테고리 판별
  static PriceRange fromPrice(int priceManwon) {
    if (priceManwon < 10000) return PriceRange.under1;
    if (priceManwon < 30000) return PriceRange.range1to3;
    if (priceManwon < 50000) return PriceRange.range3to5;
    if (priceManwon < 100000) return PriceRange.range5to10;
    if (priceManwon < 200000) return PriceRange.range10to20;
    return PriceRange.over20;
  }

  /// 해당 가격대에 포함되는지 확인
  bool contains(int priceManwon) => priceManwon >= minPrice && priceManwon < maxPrice;
}

/// 실거래가 데이터 모델
class RealTransaction {
  final String buildingName; // 건물명 (아파트명/연립다세대명/없음)
  final double area; // 전용면적 또는 연면적 (㎡)
  final int dealAmount; // 거래금액 또는 보증금 (만원)
  final int dealYear;
  final int dealMonth;
  final int dealDay;
  final int floor;
  final String? buildYear;
  final String? dealingGbn; // 거래유형 (중개/직거래) - 매매만
  final int? deposit; // 보증금 (만원) - 전세/월세
  final int? monthlyRent; // 월세 (만원)
  final String transactionType; // 매매/전세/월세
  final HousingType housingType; // 주택 유형
  final String? umdNm; // 법정동명
  final String? roadNm; // 도로명
  final String? jibun; // 지번
  // 전월세 전용 필드
  final String? contractType; // 계약구분 (신규/갱신)
  final String? contractTerm; // 계약기간
  final bool useRenewalRight; // 갱신요구권 사용 여부
  final int? preDeposit; // 종전 보증금 (갱신 시)
  final int? preMonthlyRent; // 종전 월세 (갱신 시)
  // 매매 전용 필드
  final String? slerGbn; // 매도자 구분 (개인/법인)
  final String? buyerGbn; // 매수자 구분 (개인/법인)
  // 단독/다가구 전용
  final String? houseType; // 주택유형 (단독/다가구)
  final double? landArea; // 대지면적 (㎡)

  const RealTransaction({
    required this.buildingName,
    required this.area,
    required this.dealAmount,
    required this.dealYear,
    required this.dealMonth,
    required this.dealDay,
    required this.floor,
    required this.transactionType,
    required this.housingType,
    this.buildYear,
    this.dealingGbn,
    this.deposit,
    this.monthlyRent,
    this.umdNm,
    this.roadNm,
    this.jibun,
    this.contractType,
    this.contractTerm,
    this.useRenewalRight = false,
    this.preDeposit,
    this.preMonthlyRent,
    this.slerGbn,
    this.buyerGbn,
    this.houseType,
    this.landArea,
  });

  DateTime get dealDate => DateTime(dealYear, dealMonth, dealDay);

  /// JSON 직렬화 (로컬 캐싱용)
  Map<String, dynamic> toJson() => {
    'buildingName': buildingName,
    'area': area,
    'dealAmount': dealAmount,
    'dealYear': dealYear,
    'dealMonth': dealMonth,
    'dealDay': dealDay,
    'floor': floor,
    'buildYear': buildYear,
    'dealingGbn': dealingGbn,
    'deposit': deposit,
    'monthlyRent': monthlyRent,
    'transactionType': transactionType,
    'housingType': housingType.index,
    'umdNm': umdNm,
    'roadNm': roadNm,
    'jibun': jibun,
    'contractType': contractType,
    'contractTerm': contractTerm,
    'useRenewalRight': useRenewalRight,
    'preDeposit': preDeposit,
    'preMonthlyRent': preMonthlyRent,
    'slerGbn': slerGbn,
    'buyerGbn': buyerGbn,
    'houseType': houseType,
    'landArea': landArea,
  };

  /// JSON 역직렬화 (로컬 캐싱용)
  factory RealTransaction.fromCacheJson(Map<String, dynamic> json) {
    return RealTransaction(
      buildingName: json['buildingName'] ?? '',
      area: (json['area'] as num?)?.toDouble() ?? 0,
      dealAmount: json['dealAmount'] ?? 0,
      dealYear: json['dealYear'] ?? 0,
      dealMonth: json['dealMonth'] ?? 0,
      dealDay: json['dealDay'] ?? 0,
      floor: json['floor'] ?? 0,
      buildYear: json['buildYear'],
      dealingGbn: json['dealingGbn'],
      deposit: json['deposit'],
      monthlyRent: json['monthlyRent'],
      transactionType: json['transactionType'] ?? '매매',
      housingType: HousingType.values[json['housingType'] ?? 0],
      umdNm: json['umdNm'],
      roadNm: json['roadNm'],
      jibun: json['jibun'],
      contractType: json['contractType'],
      contractTerm: json['contractTerm'],
      useRenewalRight: json['useRenewalRight'] ?? false,
      preDeposit: json['preDeposit'],
      preMonthlyRent: json['preMonthlyRent'],
      slerGbn: json['slerGbn'],
      buyerGbn: json['buyerGbn'],
      houseType: json['houseType'],
      landArea: (json['landArea'] as num?)?.toDouble(),
    );
  }

  /// 면적을 평으로 변환 (1평 ≈ 3.3058㎡)
  double get areaPyeong => area / AppNumericConstants.pyeongConversion;

  /// 가격 포맷팅 (만원 → 한글)
  String get formattedPrice => formatKoreanPrice(dealAmount);

  /// 보증금 포맷팅
  String? get formattedDeposit =>
      deposit != null ? formatKoreanPrice(deposit!) : null;

  /// 월세 포맷팅
  String? get formattedMonthlyRent =>
      monthlyRent != null ? formatKoreanPrice(monthlyRent!) : null;

  /// 갱신 시 보증금 인상률 (%)
  double? get depositIncreaseRate {
    if (contractType != '갱신' || preDeposit == null || preDeposit == 0) {
      return null;
    }
    return ((deposit ?? dealAmount) - preDeposit!) / preDeposit! * 100;
  }

  /// 주택유형 한글명
  String get housingTypeName {
    switch (housingType) {
      case HousingType.apartment:
        return '아파트';
      case HousingType.rowHouse:
        return '연립다세대';
      case HousingType.singleHouse:
        return houseType ?? '단독/다가구';
    }
  }

  /// 이전 API와 호환을 위한 getter
  String get aptName => buildingName;

  static String formatKoreanPrice(int manwon) {
    if (manwon >= 10000) {
      final uk = manwon ~/ 10000;
      final remainder = manwon % 10000;
      if (remainder > 0) {
        return '$uk억 $remainder만원';
      }
      return '$uk억원';
    }
    return '$manwon만원';
  }

  /// 아파트 매매 JSON 파싱
  factory RealTransaction.fromAptTradeJson(Map<String, dynamic> json) {
    return RealTransaction(
      buildingName: (json['aptNm'] ?? '').toString().trim(),
      area: double.tryParse(json['excluUseAr']?.toString() ?? '0') ?? 0,
      dealAmount: _parseDealAmount(json['dealAmount']),
      dealYear: int.tryParse(json['dealYear']?.toString() ?? '0') ?? 0,
      dealMonth: int.tryParse(json['dealMonth']?.toString() ?? '0') ?? 0,
      dealDay: int.tryParse(json['dealDay']?.toString() ?? '0') ?? 0,
      floor: int.tryParse(json['floor']?.toString() ?? '0') ?? 0,
      buildYear: json['buildYear']?.toString(),
      dealingGbn: json['dealingGbn']?.toString().trim(),
      transactionType: '매매',
      housingType: HousingType.apartment,
      umdNm: json['umdNm']?.toString().trim(),
      roadNm: json['roadNm']?.toString().trim(),
      jibun: json['jibun']?.toString().trim(),
      slerGbn: json['slerGbn']?.toString().trim(),
      buyerGbn: json['buyerGbn']?.toString().trim(),
    );
  }

  /// 아파트 전월세 JSON 파싱
  factory RealTransaction.fromAptRentJson(Map<String, dynamic> json) {
    final monthlyRentValue = _parseDealAmount(json['monthlyRent']);
    final depositValue = _parseDealAmount(json['deposit']);
    return RealTransaction(
      buildingName: (json['aptNm'] ?? '').toString().trim(),
      area: double.tryParse(json['excluUseAr']?.toString() ?? '0') ?? 0,
      dealAmount: depositValue,
      dealYear: int.tryParse(json['dealYear']?.toString() ?? '0') ?? 0,
      dealMonth: int.tryParse(json['dealMonth']?.toString() ?? '0') ?? 0,
      dealDay: int.tryParse(json['dealDay']?.toString() ?? '0') ?? 0,
      floor: int.tryParse(json['floor']?.toString() ?? '0') ?? 0,
      buildYear: json['buildYear']?.toString(),
      deposit: depositValue,
      monthlyRent: monthlyRentValue > 0 ? monthlyRentValue : null,
      transactionType: monthlyRentValue > 0 ? '월세' : '전세',
      housingType: HousingType.apartment,
      umdNm: json['umdNm']?.toString().trim(),
      roadNm: json['roadNm']?.toString().trim(),
      jibun: json['jibun']?.toString().trim(),
      contractType: json['contractType']?.toString().trim(),
      contractTerm: json['contractTerm']?.toString().trim(),
      useRenewalRight: json['useRRRight']?.toString().trim() == '사용',
      preDeposit: _parseDealAmount(json['preDeposit']),
      preMonthlyRent: _parseDealAmount(json['preMonthlyRent']),
    );
  }

  /// 연립다세대 매매 JSON 파싱
  factory RealTransaction.fromRhTradeJson(Map<String, dynamic> json) {
    return RealTransaction(
      buildingName: (json['mhouseNm'] ?? '').toString().trim(),
      area: double.tryParse(json['excluUseAr']?.toString() ?? '0') ?? 0,
      dealAmount: _parseDealAmount(json['dealAmount']),
      dealYear: int.tryParse(json['dealYear']?.toString() ?? '0') ?? 0,
      dealMonth: int.tryParse(json['dealMonth']?.toString() ?? '0') ?? 0,
      dealDay: int.tryParse(json['dealDay']?.toString() ?? '0') ?? 0,
      floor: int.tryParse(json['floor']?.toString() ?? '0') ?? 0,
      buildYear: json['buildYear']?.toString(),
      dealingGbn: json['dealingGbn']?.toString().trim(),
      transactionType: '매매',
      housingType: HousingType.rowHouse,
      umdNm: json['umdNm']?.toString().trim(),
      roadNm: json['roadNm']?.toString().trim(),
      jibun: json['jibun']?.toString().trim(),
      slerGbn: json['slerGbn']?.toString().trim(),
      buyerGbn: json['buyerGbn']?.toString().trim(),
      landArea: double.tryParse(json['landAr']?.toString() ?? '0'),
    );
  }

  /// 연립다세대 전월세 JSON 파싱
  factory RealTransaction.fromRhRentJson(Map<String, dynamic> json) {
    final monthlyRentValue = _parseDealAmount(json['monthlyRent']);
    final depositValue = _parseDealAmount(json['deposit']);
    return RealTransaction(
      buildingName: (json['mhouseNm'] ?? '').toString().trim(),
      area: double.tryParse(json['excluUseAr']?.toString() ?? '0') ?? 0,
      dealAmount: depositValue,
      dealYear: int.tryParse(json['dealYear']?.toString() ?? '0') ?? 0,
      dealMonth: int.tryParse(json['dealMonth']?.toString() ?? '0') ?? 0,
      dealDay: int.tryParse(json['dealDay']?.toString() ?? '0') ?? 0,
      floor: int.tryParse(json['floor']?.toString() ?? '0') ?? 0,
      buildYear: json['buildYear']?.toString(),
      deposit: depositValue,
      monthlyRent: monthlyRentValue > 0 ? monthlyRentValue : null,
      transactionType: monthlyRentValue > 0 ? '월세' : '전세',
      housingType: HousingType.rowHouse,
      umdNm: json['umdNm']?.toString().trim(),
      roadNm: json['roadNm']?.toString().trim(),
      jibun: json['jibun']?.toString().trim(),
      contractType: json['contractType']?.toString().trim(),
      contractTerm: json['contractTerm']?.toString().trim(),
      useRenewalRight: json['useRRRight']?.toString().trim() == '사용',
      preDeposit: _parseDealAmount(json['preDeposit']),
      preMonthlyRent: _parseDealAmount(json['preMonthlyRent']),
    );
  }

  /// 단독/다가구 매매 JSON 파싱
  factory RealTransaction.fromShTradeJson(Map<String, dynamic> json) {
    return RealTransaction(
      buildingName: '', // 단독/다가구는 건물명 없음
      area: double.tryParse(json['totalFloorAr']?.toString() ?? '0') ?? 0,
      dealAmount: _parseDealAmount(json['dealAmount']),
      dealYear: int.tryParse(json['dealYear']?.toString() ?? '0') ?? 0,
      dealMonth: int.tryParse(json['dealMonth']?.toString() ?? '0') ?? 0,
      dealDay: int.tryParse(json['dealDay']?.toString() ?? '0') ?? 0,
      floor: 0, // 단독/다가구는 층 정보 없음
      buildYear: json['buildYear']?.toString(),
      dealingGbn: json['dealingGbn']?.toString().trim(),
      transactionType: '매매',
      housingType: HousingType.singleHouse,
      umdNm: json['umdNm']?.toString().trim(),
      roadNm: json['roadNm']?.toString().trim(),
      jibun: json['jibun']?.toString().trim(),
      slerGbn: json['slerGbn']?.toString().trim(),
      buyerGbn: json['buyerGbn']?.toString().trim(),
      houseType: json['houseType']?.toString().trim(),
      landArea: double.tryParse(json['plottageAr']?.toString() ?? '0'),
    );
  }

  /// 단독/다가구 전월세 JSON 파싱
  factory RealTransaction.fromShRentJson(Map<String, dynamic> json) {
    final monthlyRentValue = _parseDealAmount(json['monthlyRent']);
    final depositValue = _parseDealAmount(json['deposit']);
    return RealTransaction(
      buildingName: '', // 단독/다가구는 건물명 없음
      area: double.tryParse(json['totalFloorAr']?.toString() ?? '0') ?? 0,
      dealAmount: depositValue,
      dealYear: int.tryParse(json['dealYear']?.toString() ?? '0') ?? 0,
      dealMonth: int.tryParse(json['dealMonth']?.toString() ?? '0') ?? 0,
      dealDay: int.tryParse(json['dealDay']?.toString() ?? '0') ?? 0,
      floor: 0, // 단독/다가구는 층 정보 없음
      buildYear: json['buildYear']?.toString(),
      deposit: depositValue,
      monthlyRent: monthlyRentValue > 0 ? monthlyRentValue : null,
      transactionType: monthlyRentValue > 0 ? '월세' : '전세',
      housingType: HousingType.singleHouse,
      umdNm: json['umdNm']?.toString().trim(),
      roadNm: json['roadNm']?.toString().trim(),
      contractType: json['contractType']?.toString().trim(),
      contractTerm: json['contractTerm']?.toString().trim(),
      useRenewalRight: json['useRRRight']?.toString().trim() == '사용',
      preDeposit: _parseDealAmount(json['preDeposit']),
      preMonthlyRent: _parseDealAmount(json['preMonthlyRent']),
    );
  }

  /// 이전 API 호환을 위한 팩토리 메서드
  factory RealTransaction.fromTradeJson(Map<String, dynamic> json) =>
      RealTransaction.fromAptTradeJson(json);

  factory RealTransaction.fromRentJson(Map<String, dynamic> json) =>
      RealTransaction.fromAptRentJson(json);

  /// "94,500" 또는 94500 → int 94500
  static int _parseDealAmount(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    final str = value.toString().replaceAll(',', '').trim();
    return int.tryParse(str) ?? 0;
  }

  /// 해제된 거래인지 확인
  static bool _isCancelled(Map<String, dynamic> json) {
    final cdealType = json['cdealType']?.toString().trim();
    return cdealType == 'O' || cdealType == 'o';
  }
}

/// 캐시 엔트리
class _CacheEntry {
  final List<RealTransaction> data;
  final DateTime timestamp;

  const _CacheEntry({required this.data, required this.timestamp});

  bool isExpired(Duration ttl) => DateTime.now().difference(timestamp) > ttl;

  /// JSON 직렬화 (로컬 저장소용)
  Map<String, dynamic> toJson() => {
    'data': data.map((t) => t.toJson()).toList(),
    'timestamp': timestamp.millisecondsSinceEpoch,
  };

  /// JSON 역직렬화 (로컬 저장소용)
  factory _CacheEntry.fromJson(Map<String, dynamic> json) {
    return _CacheEntry(
      data: (json['data'] as List)
          .map((e) => RealTransaction.fromCacheJson(e as Map<String, dynamic>))
          .toList(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
    );
  }
}

/// 국토부 실거래가 API 서비스
class RealTransactionService {
  // 실거래가는 하루에 한 번 갱신되므로 6시간 캐시
  static const Duration _cacheTTL = AppNumericConstants.realTransactionCacheTTL;
  static const int _cacheLimit = 100; // 확장 (이전: 50)
  static final Map<String, _CacheEntry> _cache = {};

  // 로컬 저장소 캐시 키 프리픽스
  static const String _localCachePrefix = 'rt_cache_';

  /// 로컬 저장소에서 캐시 로드
  static Future<_CacheEntry?> _loadFromLocalStorage(String cacheKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('$_localCachePrefix$cacheKey');
      if (jsonStr == null) return null;

      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final entry = _CacheEntry.fromJson(json);

      // 만료된 캐시는 무시
      if (entry.isExpired(_cacheTTL)) {
        await prefs.remove('$_localCachePrefix$cacheKey');
        return null;
      }

      return entry;
    } catch (e) {
      Logger.warning('[로컬캐시] 로드 실패: $e');
      return null;
    }
  }

  /// 로컬 저장소에 캐시 저장
  static Future<void> _saveToLocalStorage(String cacheKey, _CacheEntry entry) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(entry.toJson());
      await prefs.setString('$_localCachePrefix$cacheKey', jsonStr);
    } catch (e) {
      Logger.warning('[로컬캐시] 저장 실패: $e');
    }
  }

  /// 오래된 로컬 캐시 정리 (앱 시작 시 호출 권장)
  static Future<void> cleanupLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_localCachePrefix));

      for (final key in keys) {
        try {
          final jsonStr = prefs.getString(key);
          if (jsonStr != null) {
            final json = jsonDecode(jsonStr) as Map<String, dynamic>;
            final timestamp = DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int);
            if (DateTime.now().difference(timestamp) > _cacheTTL) {
              await prefs.remove(key);
            }
          }
        } catch (_) {
          await prefs.remove(key);
        }
      }

    } catch (e) {
      Logger.warning('[로컬캐시] 정리 실패: $e');
    }
  }

  // API 엔드포인트
  static const _aptTradeUrl =
      'https://apis.data.go.kr/1613000/RTMSDataSvcAptTradeDev/getRTMSDataSvcAptTradeDev';
  static const _aptRentUrl =
      'https://apis.data.go.kr/1613000/RTMSDataSvcAptRent/getRTMSDataSvcAptRent';
  static const _rhTradeUrl =
      'https://apis.data.go.kr/1613000/RTMSDataSvcRHTrade/getRTMSDataSvcRHTrade';
  static const _rhRentUrl =
      'https://apis.data.go.kr/1613000/RTMSDataSvcRHRent/getRTMSDataSvcRHRent';
  static const _shTradeUrl =
      'https://apis.data.go.kr/1613000/RTMSDataSvcSHTrade/getRTMSDataSvcSHTrade';
  static const _shRentUrl =
      'https://apis.data.go.kr/1613000/RTMSDataSvcSHRent/getRTMSDataSvcSHRent';

  /// 아파트 매매 실거래가 조회
  static Future<List<RealTransaction>> getAptTrades({
    required String lawdCd,
    required String dealYmd,
  }) async {
    return _fetchTransactions(
      cacheKey: 'apt_trade_${lawdCd}_$dealYmd',
      baseUrl: _aptTradeUrl,
      lawdCd: lawdCd,
      dealYmd: dealYmd,
      parser: RealTransaction.fromAptTradeJson,
      logLabel: '아파트 매매',
    );
  }

  /// 아파트 전세/월세 실거래가 조회
  static Future<List<RealTransaction>> getAptRents({
    required String lawdCd,
    required String dealYmd,
  }) async {
    return _fetchTransactions(
      cacheKey: 'apt_rent_${lawdCd}_$dealYmd',
      baseUrl: _aptRentUrl,
      lawdCd: lawdCd,
      dealYmd: dealYmd,
      parser: RealTransaction.fromAptRentJson,
      logLabel: '아파트 전월세',
      filterCancelled: false, // 전월세 API에는 cdealType 없음
    );
  }

  /// 연립다세대 매매 실거래가 조회
  static Future<List<RealTransaction>> getRhTrades({
    required String lawdCd,
    required String dealYmd,
  }) async {
    return _fetchTransactions(
      cacheKey: 'rh_trade_${lawdCd}_$dealYmd',
      baseUrl: _rhTradeUrl,
      lawdCd: lawdCd,
      dealYmd: dealYmd,
      parser: RealTransaction.fromRhTradeJson,
      logLabel: '연립다세대 매매',
    );
  }

  /// 연립다세대 전세/월세 실거래가 조회
  static Future<List<RealTransaction>> getRhRents({
    required String lawdCd,
    required String dealYmd,
  }) async {
    return _fetchTransactions(
      cacheKey: 'rh_rent_${lawdCd}_$dealYmd',
      baseUrl: _rhRentUrl,
      lawdCd: lawdCd,
      dealYmd: dealYmd,
      parser: RealTransaction.fromRhRentJson,
      logLabel: '연립다세대 전월세',
      filterCancelled: false,
    );
  }

  /// 단독/다가구 매매 실거래가 조회
  static Future<List<RealTransaction>> getShTrades({
    required String lawdCd,
    required String dealYmd,
  }) async {
    return _fetchTransactions(
      cacheKey: 'sh_trade_${lawdCd}_$dealYmd',
      baseUrl: _shTradeUrl,
      lawdCd: lawdCd,
      dealYmd: dealYmd,
      parser: RealTransaction.fromShTradeJson,
      logLabel: '단독/다가구 매매',
    );
  }

  /// 단독/다가구 전세/월세 실거래가 조회
  static Future<List<RealTransaction>> getShRents({
    required String lawdCd,
    required String dealYmd,
  }) async {
    return _fetchTransactions(
      cacheKey: 'sh_rent_${lawdCd}_$dealYmd',
      baseUrl: _shRentUrl,
      lawdCd: lawdCd,
      dealYmd: dealYmd,
      parser: RealTransaction.fromShRentJson,
      logLabel: '단독/다가구 전월세',
      filterCancelled: false,
    );
  }

  /// 한 페이지당 최대 조회 건수
  static const int _numOfRows = 1000;

  /// 공통 API 호출 로직 (페이지네이션 지원)
  static Future<List<RealTransaction>> _fetchTransactions({
    required String cacheKey,
    required String baseUrl,
    required String lawdCd,
    required String dealYmd,
    required RealTransaction Function(Map<String, dynamic>) parser,
    required String logLabel,
    bool filterCancelled = true,
  }) async {
    // 1. 메모리 캐시 확인
    final cached = _cache[cacheKey];
    if (cached != null && !cached.isExpired(_cacheTTL)) {
      return cached.data;
    }

    // 2. 로컬 저장소 캐시 확인
    final localCached = await _loadFromLocalStorage(cacheKey);
    if (localCached != null) {
      _cache[cacheKey] = localCached;
      _enforceCacheLimit();
      return localCached.data;
    }

    final serviceKey = ApiConstants.dataGoKrServiceKey;
    if (serviceKey.isEmpty) {
      Logger.warning('[$logLabel] DATA_GO_KR_SERVICE_KEY가 설정되지 않았습니다');
      return [];
    }

    try {
      final List<RealTransaction> allTransactions = [];
      int pageNo = 1;
      int totalCount = 0;
      int fetchedCount = 0;

      do {
        final queryParams = {
          'ServiceKey': serviceKey,
          'LAWD_CD': lawdCd,
          'DEAL_YMD': dealYmd,
          '_type': 'json',
          'numOfRows': '$_numOfRows',
          'pageNo': '$pageNo',
        };
        final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);
        final requestUri = ApiHelper.getRequestUri(uri);

        final response = await http.get(requestUri).timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                throw TimeoutException('$logLabel 실거래가 조회 시간 초과');
              },
            );

        if (response.statusCode != 200) {
          Logger.warning('[$logLabel] API 응답 오류: ${response.statusCode}');
          break;
        }

        final responseBody = utf8.decode(response.bodyBytes);
        final data = json.decode(responseBody);

        final resultCode = data['response']?['header']?['resultCode']?.toString();
        final resultMsg = data['response']?['header']?['resultMsg'];
        final isSuccess = resultCode == '00' || resultCode == '000';
        if (!isSuccess) {
          Logger.warning('[$logLabel] API 오류: $resultCode - $resultMsg');
          break;
        }

        final items = data['response']?['body']?['items'];
        totalCount = data['response']?['body']?['totalCount'] ?? 0;

        if (items == null || items == '') break;

        final itemList = _extractItemList(items);
        fetchedCount += itemList.length;

        final pageTransactions = itemList
            .where((item) {
              if (!filterCancelled) return true;
              return !RealTransaction._isCancelled(item as Map<String, dynamic>);
            })
            .map((item) => parser(item as Map<String, dynamic>))
            .where((t) => t.dealAmount > 0)
            .toList();

        allTransactions.addAll(pageTransactions);

        if (fetchedCount >= totalCount || itemList.length < _numOfRows) {
          break;
        }
        pageNo++;
      } while (pageNo <= 10);

      // 캐시 저장
      final cacheEntry = _CacheEntry(data: allTransactions, timestamp: DateTime.now());
      _cache[cacheKey] = cacheEntry;
      _enforceCacheLimit();
      _saveToLocalStorage(cacheKey, cacheEntry);

      return allTransactions;
    } catch (e) {
      Logger.error('[$logLabel] 실거래가 조회 실패', error: e);
      return [];
    }
  }

  /// 최근 N개월 실거래가 조회 (편의 메서드)
  ///
  /// [lawdCd] 법정동코드 앞 5자리
  /// [aptName] 특정 건물명 필터 (null이면 전체)
  /// [transactionType] 매매/전세/월세
  /// [housingType] 주택 유형 (기본: 아파트)
  /// [months] 최근 몇 개월 (기본 3)
  /// [areaCategory] 면적 카테고리 필터 (null이면 전체)
  /// [searchScope] 검색 범위 (기본: 같은 동 전체)
  /// [floorCategory] 층수 카테고리 필터 (null이면 전체)
  /// [buildYearCategory] 건축년도 카테고리 필터 (null이면 전체)
  /// [dealingType] 거래유형 필터 - 매매만 (null이면 전체)
  /// [contractTypeFilter] 계약구분 필터 - 전월세만 (null이면 전체)
  /// [sellerType] 매도자 구분 필터 - 매매만 (null이면 전체)
  /// [buyerType] 매수자 구분 필터 - 매매만 (null이면 전체)
  /// [priceRange] 가격대 필터 (null이면 전체)
  /// [useRenewalRightFilter] 갱신요구권 사용 필터 - 전월세만 (null이면 전체)
  static Future<List<RealTransaction>> getRecentTransactions({
    required String lawdCd,
    String? aptName,
    String? roadNm, // 같은 도로 필터용
    String? umdNm, // 같은 동 필터용
    String transactionType = '매매',
    HousingType housingType = HousingType.apartment,
    int months = 3,
    AreaCategory? areaCategory,
    SearchScope searchScope = SearchScope.sameDong,
    FloorCategory? floorCategory,
    BuildYearCategory? buildYearCategory,
    DealingType? dealingType,
    ContractTypeFilter? contractTypeFilter,
    PartyType? sellerType,
    PartyType? buyerType,
    PriceRange? priceRange,
    bool? useRenewalRightFilter,
  }) async {
    final now = DateTime.now();

    // 월별 API 호출을 병렬로 실행
    final List<Future<List<RealTransaction>>> futures = [];

    for (int i = 0; i < months; i++) {
      final targetDate = DateTime(now.year, now.month - i);
      final dealYmd =
          '${targetDate.year}${targetDate.month.toString().padLeft(2, '0')}';

      if (transactionType == '매매') {
        futures.add(_getTradesByHousingType(
          housingType: housingType,
          lawdCd: lawdCd,
          dealYmd: dealYmd,
        ));
      } else {
        futures.add(_getRentsByHousingType(
          housingType: housingType,
          lawdCd: lawdCd,
          dealYmd: dealYmd,
        ));
      }
    }

    final results = await Future.wait(futures);

    // 결과 합치기
    final List<RealTransaction> allTransactions = [];
    for (int i = 0; i < results.length; i++) {
      var monthData = results[i];

      // 전세/월세 필터링
      if (transactionType != '매매') {
        if (transactionType == '월세') {
          monthData = monthData.where((t) => t.transactionType == '월세').toList();
        } else if (transactionType == '전세') {
          monthData = monthData.where((t) => t.transactionType == '전세').toList();
        }
      }

      allTransactions.addAll(monthData);
    }

    List<RealTransaction> filtered = allTransactions;

    // 1. 검색 범위에 따른 필터
    if (searchScope == SearchScope.sameRoad && roadNm != null && roadNm.isNotEmpty) {
      filtered = allTransactions.where((t) =>
        t.umdNm == umdNm && t.roadNm == roadNm
      ).toList();
    } else if (searchScope == SearchScope.sameDong && umdNm != null && umdNm.isNotEmpty) {
      filtered = allTransactions.where((t) => t.umdNm == umdNm).toList();
    }

    // 2. 면적 카테고리 필터
    if (areaCategory != null) {
      filtered = filtered.where((t) => areaCategory.contains(t.area)).toList();
    }

    // 3. 층수 카테고리 필터
    if (floorCategory != null) {
      filtered = filtered.where((t) => floorCategory.contains(t.floor)).toList();
    }

    // 4. 건축년도 카테고리 필터
    if (buildYearCategory != null) {
      filtered = filtered.where((t) => buildYearCategory.containsYear(t.buildYear)).toList();
    }

    // 5. 거래유형 필터 (매매만)
    if (dealingType != null && transactionType == '매매') {
      filtered = filtered.where((t) => dealingType.matches(t.dealingGbn)).toList();
    }

    // 6. 계약구분 필터 (전월세만)
    if (contractTypeFilter != null && transactionType != '매매') {
      filtered = filtered.where((t) => contractTypeFilter.matches(t.contractType)).toList();
    }

    // 7. 매도자 구분 필터 (매매만)
    if (sellerType != null && transactionType == '매매') {
      filtered = filtered.where((t) => sellerType.matches(t.slerGbn)).toList();
    }

    // 8. 매수자 구분 필터 (매매만)
    if (buyerType != null && transactionType == '매매') {
      filtered = filtered.where((t) => buyerType.matches(t.buyerGbn)).toList();
    }

    // 9. 가격대 필터
    if (priceRange != null) {
      filtered = filtered.where((t) => priceRange.contains(t.dealAmount)).toList();
    }

    // 10. 갱신요구권 사용 필터 (전월세만)
    if (useRenewalRightFilter != null && transactionType != '매매') {
      filtered = filtered.where((t) => t.useRenewalRight == useRenewalRightFilter).toList();
    }

    // 정렬
    if (areaCategory != null) {
      filtered.sort((a, b) {
        final areaCompare = a.area.compareTo(b.area);
        if (areaCompare != 0) return areaCompare;
        return b.dealDate.compareTo(a.dealDate);
      });
    } else {
      filtered.sort((a, b) => b.dealDate.compareTo(a.dealDate));
    }

    return filtered;
  }

  /// 주택유형별 매매 API 호출
  static Future<List<RealTransaction>> _getTradesByHousingType({
    required HousingType housingType,
    required String lawdCd,
    required String dealYmd,
  }) async {
    switch (housingType) {
      case HousingType.apartment:
        return getAptTrades(lawdCd: lawdCd, dealYmd: dealYmd);
      case HousingType.rowHouse:
        return getRhTrades(lawdCd: lawdCd, dealYmd: dealYmd);
      case HousingType.singleHouse:
        return getShTrades(lawdCd: lawdCd, dealYmd: dealYmd);
    }
  }

  /// 주택유형별 전월세 API 호출
  static Future<List<RealTransaction>> _getRentsByHousingType({
    required HousingType housingType,
    required String lawdCd,
    required String dealYmd,
  }) async {
    switch (housingType) {
      case HousingType.apartment:
        return getAptRents(lawdCd: lawdCd, dealYmd: dealYmd);
      case HousingType.rowHouse:
        return getRhRents(lawdCd: lawdCd, dealYmd: dealYmd);
      case HousingType.singleHouse:
        return getShRents(lawdCd: lawdCd, dealYmd: dealYmd);
    }
  }

  /// 모든 주택유형 통합 조회
  static Future<List<RealTransaction>> getAllHousingTypesTransactions({
    required String lawdCd,
    String? buildingName,
    String transactionType = '매매',
    int months = 3,
  }) async {
    final results = await Future.wait([
      getRecentTransactions(
        lawdCd: lawdCd,
        aptName: buildingName,
        transactionType: transactionType,
        months: months,
      ),
      getRecentTransactions(
        lawdCd: lawdCd,
        aptName: buildingName,
        transactionType: transactionType,
        housingType: HousingType.rowHouse,
        months: months,
      ),
      getRecentTransactions(
        lawdCd: lawdCd,
        aptName: buildingName,
        transactionType: transactionType,
        housingType: HousingType.singleHouse,
        months: months,
      ),
    ]);

    final allTransactions = <RealTransaction>[];
    for (final list in results) {
      allTransactions.addAll(list);
    }

    // 날짜 역순 정렬
    allTransactions.sort((a, b) => b.dealDate.compareTo(a.dealDate));

    return allTransactions;
  }

  /// admCd에서 LAWD_CD 추출 (앞 5자리)
  static String? extractLawdCd(String? admCd) {
    if (admCd == null || admCd.length < 5) return null;
    return admCd.substring(0, 5);
  }

  /// items에서 리스트 추출 (AptInfoService 패턴 동일)
  static List<dynamic> _extractItemList(dynamic items) {
    if (items is List) return items;
    if (items is Map) {
      final itemValue = items['item'];
      if (itemValue != null) {
        if (itemValue is List) return itemValue;
        return [itemValue];
      }
    }
    return [];
  }

  /// 캐시 크기 제한
  static void _enforceCacheLimit() {
    if (_cache.length <= _cacheLimit) return;
    final sortedEntries = _cache.entries.toList()
      ..sort((a, b) => a.value.timestamp.compareTo(b.value.timestamp));
    final removeCount = _cache.length - _cacheLimit;
    for (int i = 0; i < removeCount; i++) {
      _cache.remove(sortedEntries[i].key);
    }
  }

  /// 캐시 초기화 (테스트용)
  static void clearCache() {
    _cache.clear();
  }

  /// 동시 요청 수 제한 (Rate Limit 대응)
  static const int _maxConcurrentRequests = 4;

  /// 단계적 로딩: 최근 N개월 실거래가 조회 (최적화 버전)
  ///
  /// 12개월 전체를 병렬로 요청하되:
  /// - 동시 요청 수 제한 (Rate Limit 대응)
  /// - 3개월 결과가 먼저 완료되면 UI 업데이트
  /// - 전체 완료 후 최종 업데이트
  static Future<void> getRecentTransactionsProgressive({
    required String lawdCd,
    required void Function(List<RealTransaction> transactions, bool isPartial) onData,
    String? aptName,
    String? roadNm,
    String? umdNm,
    String transactionType = '매매',
    HousingType housingType = HousingType.apartment,
    int months = 12,
    AreaCategory? areaCategory,
    SearchScope searchScope = SearchScope.sameDong,
    FloorCategory? floorCategory,
    BuildYearCategory? buildYearCategory,
    DealingType? dealingType,
    ContractTypeFilter? contractTypeFilter,
    PartyType? sellerType,
    PartyType? buyerType,
    PriceRange? priceRange,
    bool? useRenewalRightFilter,
  }) async {
    final now = DateTime.now();
    const firstBatchMonths = 3;

    // 필터링 함수
    List<RealTransaction> applyFilters(List<RealTransaction> allTransactions) {
      List<RealTransaction> filtered = allTransactions;

      // 전세/월세 필터링
      if (transactionType != '매매') {
        if (transactionType == '월세') {
          filtered = filtered.where((t) => t.transactionType == '월세').toList();
        } else if (transactionType == '전세') {
          filtered = filtered.where((t) => t.transactionType == '전세').toList();
        }
      }

      // 검색 범위 필터
      if (searchScope == SearchScope.sameRoad && roadNm != null && roadNm.isNotEmpty) {
        filtered = filtered.where((t) => t.umdNm == umdNm && t.roadNm == roadNm).toList();
      } else if (searchScope == SearchScope.sameDong && umdNm != null && umdNm.isNotEmpty) {
        filtered = filtered.where((t) => t.umdNm == umdNm).toList();
      }

      // 면적 카테고리 필터
      if (areaCategory != null) {
        filtered = filtered.where((t) => areaCategory.contains(t.area)).toList();
      }

      // 층수 카테고리 필터
      if (floorCategory != null) {
        filtered = filtered.where((t) => floorCategory.contains(t.floor)).toList();
      }

      // 건축년도 카테고리 필터
      if (buildYearCategory != null) {
        filtered = filtered.where((t) => buildYearCategory.containsYear(t.buildYear)).toList();
      }

      // 거래유형 필터 (매매만)
      if (dealingType != null && transactionType == '매매') {
        filtered = filtered.where((t) => dealingType.matches(t.dealingGbn)).toList();
      }

      // 계약구분 필터 (전월세만)
      if (contractTypeFilter != null && transactionType != '매매') {
        filtered = filtered.where((t) => contractTypeFilter.matches(t.contractType)).toList();
      }

      // 매도자 구분 필터 (매매만)
      if (sellerType != null && transactionType == '매매') {
        filtered = filtered.where((t) => sellerType.matches(t.slerGbn)).toList();
      }

      // 매수자 구분 필터 (매매만)
      if (buyerType != null && transactionType == '매매') {
        filtered = filtered.where((t) => buyerType.matches(t.buyerGbn)).toList();
      }

      // 가격대 필터
      if (priceRange != null) {
        filtered = filtered.where((t) => priceRange.contains(t.dealAmount)).toList();
      }

      // 갱신요구권 사용 필터 (전월세 갱신만)
      if (useRenewalRightFilter != null && transactionType != '매매') {
        filtered = filtered.where((t) => t.useRenewalRight == useRenewalRightFilter).toList();
      }

      // 정렬
      if (areaCategory != null) {
        filtered.sort((a, b) {
          final areaCompare = a.area.compareTo(b.area);
          if (areaCompare != 0) return areaCompare;
          return b.dealDate.compareTo(a.dealDate);
        });
      } else {
        filtered.sort((a, b) => b.dealDate.compareTo(a.dealDate));
      }

      return filtered;
    }

    // 월별 dealYmd 목록 생성
    final List<String> dealYmds = [];
    for (int i = 0; i < months; i++) {
      final targetDate = DateTime(now.year, now.month - i);
      dealYmds.add('${targetDate.year}${targetDate.month.toString().padLeft(2, '0')}');
    }

    // 전체 결과 저장
    final Map<int, List<RealTransaction>> resultsByMonth = {};

    // API 호출 함수 생성
    Future<List<RealTransaction>> fetchMonth(int monthIndex) async {
      final dealYmd = dealYmds[monthIndex];
      if (transactionType == '매매') {
        return _getTradesByHousingType(
          housingType: housingType,
          lawdCd: lawdCd,
          dealYmd: dealYmd,
        );
      } else {
        return _getRentsByHousingType(
          housingType: housingType,
          lawdCd: lawdCd,
          dealYmd: dealYmd,
        );
      }
    }

    // 첫 3개월을 먼저 병렬로 요청
    final firstBatchFutures = <Future<List<RealTransaction>>>[];
    for (int i = 0; i < firstBatchMonths && i < months; i++) {
      firstBatchFutures.add(fetchMonth(i).then((result) {
        resultsByMonth[i] = result;
        return result;
      }));
    }

    // 나머지 월은 동시 요청 수 제한하면서 병렬로 요청
    final remainingFutures = <Future<void>>[];
    final semaphore = _Semaphore(_maxConcurrentRequests);

    for (int i = firstBatchMonths; i < months; i++) {
      final monthIndex = i;
      remainingFutures.add(
        semaphore.acquire().then((_) async {
          try {
            resultsByMonth[monthIndex] = await fetchMonth(monthIndex);
          } finally {
            semaphore.release();
          }
        }),
      );
    }

    // 첫 3개월 완료 대기 → UI 업데이트
    await Future.wait(firstBatchFutures);

    final firstBatchTransactions = <RealTransaction>[];
    for (int i = 0; i < firstBatchMonths && i < months; i++) {
      firstBatchTransactions.addAll(resultsByMonth[i] ?? []);
    }

    onData(applyFilters(firstBatchTransactions), true);

    // 나머지 월 완료 대기 → 전체 업데이트
    if (remainingFutures.isNotEmpty) {
      await Future.wait(remainingFutures);

      final allTransactions = <RealTransaction>[];
      for (int i = 0; i < months; i++) {
        allTransactions.addAll(resultsByMonth[i] ?? []);
      }

      onData(applyFilters(allTransactions), false);
    }
  }
}

/// 세마포어 구현 (동시 요청 수 제한)
class _Semaphore {
  final int maxCount;
  int _currentCount = 0;
  final List<Completer<void>> _waiters = [];

  _Semaphore(this.maxCount);

  Future<void> acquire() async {
    if (_currentCount < maxCount) {
      _currentCount++;
      return;
    }
    final completer = Completer<void>();
    _waiters.add(completer);
    await completer.future;
    _currentCount++;
  }

  void release() {
    _currentCount--;
    if (_waiters.isNotEmpty && _currentCount < maxCount) {
      final completer = _waiters.removeAt(0);
      completer.complete();
    }
  }
}
