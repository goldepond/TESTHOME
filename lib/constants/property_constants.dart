/// 매물 도메인 상수 모음
///
/// 여러 화면에서 중복 정의되던 매물 유형, 옵션, 방향, 가격 구간,
/// 지역 코드 매핑을 단일 위치에서 관리합니다.
library;

import 'dart:ui' show Color;

/// 앱 전역에서 사용되는 매직 넘버 상수
class AppNumericConstants {
  // ── 가격 관련 ──
  /// 가격 필터 최대 범위 (만원 단위, 50억)
  static const double maxPriceRange = 500000;

  /// 매물 목록 1회 로드 한도
  static const int propertiesLoadLimit = 30;

  // ── 이미지 관련 ──
  /// 빠른 등록 시 최대 이미지 수
  static const int maxImagesQuick = 5;

  /// 상세 등록 시 최대 이미지 수
  static const int maxImagesDetail = 10;

  // ── 면적 변환 ──
  /// m² → 평 변환 계수 (1평 ≈ 3.3058㎡)
  static const double pyeongConversion = 3.3058;

  // ── 캐시 TTL ──
  /// 실거래가 캐시 유효 시간
  static const Duration realTransactionCacheTTL = Duration(hours: 6);

  // ── 소셜 로그인 색상 ──
  static const Color kakaoYellow = Color(0xFFFEE500);
  static const Color kakaoBlack = Color(0xFF191919);
  static const Color googleWhite = Color(0xFFFFFFFF);
}

class PropertyConstants {
  /// 매물 유형 목록
  static const List<String> propertyTypes = [
    '아파트',
    '빌라/다세대',
    '오피스텔',
    '단독/다가구',
    '상가',
    '토지',
    '기타',
  ];

  /// 매물 옵션 목록
  static const List<String> availableOptions = [
    '에어컨',
    '붙박이장',
    '확장형',
    '주차',
    '엘리베이터',
    '베란다',
    '반려동물',
    '풀옵션',
    '세탁기',
    '냉장고',
    '인덕션',
    '식기세척기',
    '건조기',
    '신발장',
    'CCTV',
    '무인택배함',
  ];

  /// 향(방향) 목록
  static const List<String> directions = [
    '동향',
    '서향',
    '남향',
    '북향',
    '남동향',
    '남서향',
    '북동향',
    '북서향',
  ];

  /// 가격 필터 프리셋 (만원 단위)
  static const List<Map<String, dynamic>> pricePresets = [
    {'label': '전체', 'min': 0.0, 'max': 500000.0},
    {'label': '1억 이하', 'min': 0.0, 'max': 10000.0},
    {'label': '1~3억', 'min': 10000.0, 'max': 30000.0},
    {'label': '3~5억', 'min': 30000.0, 'max': 50000.0},
    {'label': '5~10억', 'min': 50000.0, 'max': 100000.0},
    {'label': '10억 이상', 'min': 100000.0, 'max': 500000.0},
  ];

  /// 거래 유형 목록 (공개 필터용)
  static const List<String> transactionTypes = ['전체', '매매', '전세', '월세'];

  /// 공개 매물 목록 UI 필터용 주요 지역 (표시 목적)
  static const Map<String, String> filterRegions = {
    'SEOUL': '서울',
    'GYEONGGI': '경기',
    'INCHEON': '인천',
    'BUSAN': '부산',
    'DAEGU': '대구',
    'DAEJEON': '대전',
    'GWANGJU': '광주',
    'ULSAN': '울산',
  };
}

/// 지역 코드 → 한글 표시명 변환 유틸리티
class RegionDisplayNames {
  /// 지역 코드와 한글 표시명의 전체 매핑 (17개 광역시도)
  static const Map<String, String> nameMap = {
    'SEOUL': '서울',
    'GYEONGGI': '경기',
    'INCHEON': '인천',
    'BUSAN': '부산',
    'DAEGU': '대구',
    'DAEJEON': '대전',
    'GWANGJU': '광주',
    'ULSAN': '울산',
    'SEJONG': '세종',
    'GANGWON': '강원',
    'CHUNGBUK': '충북',
    'CHUNGNAM': '충남',
    'JEONBUK': '전북',
    'JEONNAM': '전남',
    'GYEONGBUK': '경북',
    'GYEONGNAM': '경남',
    'JEJU': '제주',
  };

  /// 지역 코드를 한글 표시명으로 변환합니다. 알 수 없는 코드는 원본을 반환합니다.
  static String of(String regionCode) =>
      nameMap[regionCode.toUpperCase()] ?? regionCode;
}
