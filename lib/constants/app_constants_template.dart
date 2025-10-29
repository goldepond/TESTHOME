import 'package:flutter/material.dart';

// 색상 상수 - HouseMVP 통합 디자인
class AppColors {
  // 메인 컬러 (보라+남색 조합 - 신뢰감 & 독창성)
  static const Color kPrimary = Color(0xFF8b5cf6);      // 메인 보라색
  static const Color kSecondary = Color(0xFF1e3a8a);    // 신뢰감 있는 남색 (navy blue)
  static const Color kAccent = Color(0xFF7c3aed);       // 진한 보라색
  
  // 배경 및 텍스트
  static const Color kBackground = Color(0xFFE8EAF0);   // 진한 회색 배경 (가시성 개선)
  static const Color kSurface = Color(0xFFFFFFFF);      // 흰색
  static const Color kTextPrimary = Color(0xFF1F2937);  // 더 진한 텍스트 (가시성 개선)
  static const Color kTextSecondary = Color(0xFF4B5563);// 진한 보통 텍스트
  static const Color kTextLight = Color(0xFF6B7280);    // 진한 밝은 텍스트
  
  // 그라데이션
  static const Color kGradientStart = Color(0xFF87CEEB); // Sky Blue
  static const Color kGradientEnd = Color(0xFF8b5cf6);   // Purple
  
  // 상태 컬러
  static const Color kSuccess = Color(0xFF10b981);      // 성공 (녹색)
  static const Color kWarning = Color(0xFFf59e0b);      // 경고 (주황)
  static const Color kError = Color(0xFFef4444);        // 에러 (빨강)
  static const Color kInfo = Color(0xFF3b82f6);         // 정보 (파랑)
  
  // 하위 호환성을 위한 별칭 (기존 코드 지원)
  static const Color kBrown = kPrimary;
  static const Color kLightBrown = kBackground;
  static const Color kDarkBrown = kAccent;
}

// VWorld API 상수 (공공 API - 도메인 제한 있음)
class VWorldApiConstants {
  // ⚠️ 보안: API 키를 여기에 직접 입력하세요
  static const String apiKey = 'YOUR_VWORLD_API_KEY_HERE';
  static const String geocoderApiKey = 'YOUR_GEOCODER_API_KEY_HERE';
  
  // API 엔드포인트
  static const String landBaseUrl = 'https://api.vworld.kr/req/data';
  static const String geocoderBaseUrl = 'https://api.vworld.kr/req/address';
  static const String brokerBaseUrl = 'https://api.vworld.kr/req/data';
  
  // 기타 설정
  static const String landQueryTypeName = 'lp_pa_cbnd_bubun';
  static const String brokerQueryTypeName = 'lt_c_adsido_info';
  static const String srsName = 'EPSG:4326';
  static const String domainCORSParam = 'http://localhost';
}

// 일반 API 상수
class ApiConstants {
  // ⚠️ 보안: API 키를 여기에 직접 입력하세요
  static const String jusoApiKey = 'YOUR_JUSO_API_KEY_HERE';
  static const String registerApiKey = 'YOUR_REGISTER_API_KEY_HERE';
  static const String data_go_kr_serviceKey = 'YOUR_DATA_GO_KR_KEY_HERE';
  
  // API 엔드포인트
  static const String roadAddressAPIBaseUrl = 'https://business.juso.go.kr/addrlink/addrLinkApi.do';
  static const String buildingInfoAPIBaseUrl = 'http://apis.data.go.kr/1613000/BldRgstService_v2';
  static const String aptInfoAPIBaseUrl = 'http://apis.data.go.kr/1613000/AptBasisInfoService1/getAphusBassInfo';
  
  static const int requestTimeoutSeconds = 10;
}

// Codef API (등기부등본)
class CodefApiKeys {
  // ⚠️ 보안: API 키를 여기에 직접 입력하세요
  static const String clientId = 'YOUR_CODEF_CLIENT_ID_HERE';
  static const String clientSecret = 'YOUR_CODEF_CLIENT_SECRET_HERE';
  static const String publicKey = 'YOUR_CODEF_PUBLIC_KEY_HERE';
}

