import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';

// 색상 상수 - MyHome 브랜드 디자인 (코랄/테라코타)
@Deprecated('Use AirbnbColors instead')
class AppColors {
  // 메인 컬러 (코랄/테라코타 - 따뜻한 집의 느낌)
  static const Color kPrimary = Color(0xFFE07A5F);      // 메인 코랄
  static const Color kSecondary = Color(0xFFC9654D);    // 진한 코랄 (다크)
  static const Color kAccent = Color(0xFFD4715A);       // 코랄 호버

  // 배경 및 텍스트
  static const Color kBackground = Color(0xFFFDF8F6);   // 따뜻한 크림 배경
  static const Color kSurface = Color(0xFFFFFFFF);      // 흰색
  static const Color kTextPrimary = Color(0xFF1F2937);  // 더 진한 텍스트 (가시성 개선)
  static const Color kTextSecondary = Color(0xFF4B5563);// 진한 보통 텍스트
  static const Color kTextLight = Color(0xFF6B7280);    // 진한 밝은 텍스트

  // 그라데이션 (브랜드 기본: 코랄 → 진한 코랄)
  static const Color kGradientStart = Color(0xFFE07A5F); // coral
  static const Color kGradientEnd = Color(0xFFC9654D);   // coral-dark
  
  // 상태 컬러
  static const Color kSuccess = Color(0xFF10b981);      // 성공 (녹색)
  static const Color kWarning = Color(0xFFf59e0b);      // 경고 (주황)
  static const Color kError = Color(0xFFef4444);        // 에러 (빨강)
  static const Color kInfo = Color(0xFF3b82f6);         // 정보 (파랑)
  
  // 하위 호환성을 위한 별칭 (기존 코드 지원)
  static const Color kBrown = kPrimary;
  static const Color kLightBrown = kBackground;
  static const Color kDarkBrown = kAccent;

  // MLS 시스템 호환성을 위한 별칭
  static const Color primary = kPrimary;
  static const Color textSecondary = kTextSecondary;
  static const Color success = kSuccess;
  static const Color warning = kWarning;
  static const Color error = kError;
  static const Color accent = kAccent;
}

/// 공통 그라데이션 스타일
class AppGradients {
  /// 브랜드 기본 대각선 그라데이션 (홈 히어로 1단계와 톤 맞춤)
  static const LinearGradient primaryDiagonal = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.kGradientStart, AppColors.kGradientEnd],
  );
}

/// 에어비엔비 스타일 색상 시스템 (코랄/테라코타 + 다양한 조화 색상)
class AirbnbColors {
  // ========== 주력 색상 (코랄/테라코타 계열) ==========
  static const Color primary = Color(0xFFE07A5F);      // 메인 코랄 (주력색)
  static const Color primaryHover = Color(0xFFD4715A); // 호버 코랄
  static const Color primaryLight = Color(0xFFF4A593); // 연한 코랄
  static const Color primaryDark = Color(0xFFC9654D);  // 진한 코랄
  
  // ========== 중성 색상 (따뜻한 뉴트럴) ==========
  static const Color background = Color(0xFFFFFFFF);     // 흰색 (카드/서피스)
  static const Color surface = Color(0xFFFAF8F5);        // 따뜻한 크림 배경
  static const Color surfaceDark = Color(0xFF1A1512);    // 다크 서피스 (히어로 카드)
  static const Color border = Color(0xFFE8E5E1);         // 따뜻한 회색 테두리
  static const Color borderLight = Color(0xFFF0EDE8);    // 연한 따뜻한 테두리
  static const Color pillSecondary = Color(0xFFEBE5DC);  // 필 버튼 배경

  // ========== 텍스트 (따뜻한 톤) ==========
  static const Color textPrimary = Color(0xFF2D2A26);    // 따뜻한 거의 검정
  static const Color textSecondary = Color(0xFF6B6560);  // 따뜻한 중간 회색 (WCAG AA 4.8:1)
  static const Color textLight = Color(0xFF837B73);      // 따뜻한 연한 회색 (WCAG AA 4.0:1)
  static const Color textWhite = Color(0xFFFFFFFF);
  
  // ========== 상태 색상 (에러/경고/성공/정보) ==========
  static const Color success = Color(0xFF10b981);      // 성공 (녹색)
  static const Color successLight = Color(0xFF34d399);
  static const Color warning = Color(0xFFf59e0b);      // 경고 (주황)
  static const Color error = Color(0xFFef4444);        // 에러 (빨강)
  static const Color info = Color(0xFF3b82f6);         // 정보 (파랑)
  
  // ========== 다양한 용도별 색상 (에어비엔비 스타일) ==========
  // 청록색 계열 (정보, 진행중, 활성화)
  static const Color teal = Color(0xFF00A699);        // 에어비엔비 청록색
  static const Color tealLight = Color(0xFF00D9C4);
  static const Color tealDark = Color(0xFF008B7A);
  
  // 파란색 계열 (링크, 정보, 신뢰)
  static const Color blue = Color(0xFF3b82f6);         // 정보 (파랑)
  static const Color blueLight = Color(0xFF60a5fa);
  static const Color blueDark = Color(0xFF2563eb);
  
  // 주황색 계열 (대기, 진행중, 알림)
  static const Color orange = Color(0xFFf59e0b);       // 경고 (주황)
  static const Color orangeLight = Color(0xFFfbbf24);
  static const Color orangeDark = Color(0xFFd97706);
  
  // 녹색 계열 (완료, 성공, 활성)
  static const Color green = Color(0xFF10b981);        // 성공 (녹색)
  static const Color greenLight = Color(0xFF34d399);
  static const Color greenDark = Color(0xFF059669);
  
  // 빨간색 계열 (에러, 취소, 위험)
  static const Color red = Color(0xFFef4444);          // 에러 (빨강)
  static const Color redLight = Color(0xFFf87171);
  static const Color redDark = Color(0xFFdc2626);
  
  // 보라색 계열 (특별, 프리미엄, 강조)
  static const Color purple = Color(0xFF8b5cf6);       // 메인 보라색과 동일
  static const Color purpleLight = Color(0xFFa78bfa);
  static const Color purpleDark = Color(0xFF7c3aed);
  
  // 분홍색 계열 (강조, 특별 이벤트)
  static const Color pink = Color(0xFFec4899);
  static const Color pinkLight = Color(0xFFf472b6);
  static const Color pinkDark = Color(0xFFdb2777);
  
  // ========== 카테고리별 색상 (에어비엔비처럼 다양한 용도) ==========
  // 거래 유형별
  static const Color categorySale = primary;           // 매매 (보라색)
  static const Color categoryRent = teal;             // 전세/월세 (청록색)
  static const Color categoryManagement = blue;        // 관리 (파란색)
  
  // 상태별
  static const Color statusPending = orange;           // 대기중 (주황)
  static const Color statusProgress = blue;             // 진행중 (파랑)
  static const Color statusCompleted = green;           // 완료 (녹색)
  static const Color statusCancelled = red;             // 취소 (빨강)
  
  // 우선순위별
  static const Color priorityHigh = red;               // 높음 (빨강)
  static const Color priorityMedium = orange;           // 중간 (주황)
  static const Color priorityLow = blue;                // 낮음 (파랑)
  
  // ========== 그림자 (에어비엔비 스타일 - 부드럽고 깊이감 있는 그림자) ==========
  static BoxShadow get cardShadow => BoxShadow(
    color: textPrimary.withValues(alpha: 0.06),
    blurRadius: 20,
    offset: const Offset(0, 2),
  );
  
  static BoxShadow get cardShadowHover => BoxShadow(
    color: textPrimary.withValues(alpha: 0.12),
    blurRadius: 24,
    offset: const Offset(0, 4),
  );
  
  // 더 부드러운 그림자 (히어로 섹션 등 큰 카드용)
  static BoxShadow get cardShadowLarge => BoxShadow(
    color: textPrimary.withValues(alpha: 0.08),
    blurRadius: 32,
    offset: const Offset(0, 4),
  );
  
  // 미세한 그림자 (작은 요소용)
  static BoxShadow get cardShadowSubtle => BoxShadow(
    color: textPrimary.withValues(alpha: 0.04),
    blurRadius: 8,
    offset: const Offset(0, 1),
  );
  
  // ========== 헬퍼 메서드 ==========
  /// 상태에 따른 색상 반환 (에어비엔비 스타일)
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case '대기':
      case '요청됨':
        return statusPending;
      case 'progress':
      case '진행중':
      case '수집중':
      case '검토중':
        return statusProgress;
      case 'completed':
      case '완료':
      case '선택됨':
        return statusCompleted;
      case 'cancelled':
      case '취소':
      case '취소됨':
        return statusCancelled;
      default:
        return primary;
    }
  }
  
  /// 거래 유형에 따른 색상 반환
  static Color getTransactionTypeColor(String? type) {
    switch (type) {
      case '매매':
        return categorySale;
      case '전세':
      case '월세':
        return categoryRent;
      default:
        return primary;
    }
  }
}

// CODEF API 관련 상수
class CodefApiKeys {
  static String get clientId => _getEnv('CODEF_CLIENT_ID');
  static String get clientSecret => _getEnv('CODEF_CLIENT_SECRET');
  static String get publicKey => _getEnv('CODEF_PUBLIC_KEY');
}

class VWorldApiConstants {
  static String get apiKey => _getEnv('VWORLD_API_KEY');
  static String get geocoderApiKey => _getEnv('VWORLD_GEOCODER_API_KEY');

  static const String vworldProxyUrl = 'https://map.vworld.kr/proxy.do?url='; //https://github.com/V-world/Utilization-Model/blob/master/utilization-model/%EA%B5%90%ED%86%B5%EC%95%88%EC%A0%84%EC%A7%80%EB%8F%84/index.html#L529
  static const String brokerQueryBaseUrl = 'https://api.vworld.kr/ned/wfs/getEstateBrkpgWFS';
  static const String geocoderBaseUrl = 'https://api.vworld.kr/req/address'; // 하루 40000 제한
  static const String landBaseUrl = 'https://api.vworld.kr/ned/wfs/getLandCharacteristicsWFS';

  static const String brokerQueryTypeName = 'dt_d170';
  static const String landQueryTypeName = 'dt_d194';

  static const String domainCORSParam = 'https://goldepond.github.io/'; // Production 릴리즈시 호스팅하는 사이트 DNS 로 변경 필요함
  static const String srsName = 'EPSG:4326';
  static const int brokerMaxFeatures = 30;
}

// API 관련 상수
class ApiConstants {
  // Firebase Functions 프록시 (CORS 우회용)
  static const String proxyRequstAddr = 'https://asia-northeast3-houseproject-18f44.cloudfunctions.net/proxy';

  // 주소 관련
  static String get jusoApiKey => _getEnv('JUSO_API_KEY');
  static String get registerApiKey => _getEnv('REGISTER_API_KEY');
  static const String baseJusoUrl = 'https://business.juso.go.kr/addrlink/addrLinkApi.do';
  static const String coordIncludedJusoUrl = 'https://business.juso.go.kr/addrlink/addrCoordApi.do';
  static const int requestTimeoutSeconds = 5;
  static const int pageSize = 10;

  // Data.go.kr
  static String get dataGoKrServiceKey => _getEnv('DATA_GO_KR_SERVICE_KEY');

  // AptBasisInfoServiceV4 - 공동주택 상세 정보조회 API
  // 실제 메서드명: /getAphusDtlInfoV4
  static const String aptInfoAPIBaseUrl = 'https://apis.data.go.kr/1613000/AptBasisInfoServiceV4/getAphusDtlInfoV4';
  static const String buildingInfoAPIBaseUrl = 'https://apis.data.go.kr/1613000/ArchPmsServiceV2';

  // 네이버 지도 API
  static String get naverMapClientId => _getEnv('NAVER_MAP_CLIENT_ID');
  
  // 서울시 Open API
  static String get seoulOpenApiKey => _getEnv('SEOUL_OPEN_API_KEY');
  static const String seoulGlobalBrokerBaseUrl = 'https://openapi.seoul.go.kr:8088';

  // 카카오 SDK
  static String get kakaoNativeAppKey => _getEnv('KAKAO_NATIVE_APP_KEY');
  static String get kakaoJavaScriptAppKey => _getEnv('KAKAO_JAVASCRIPT_APP_KEY');
}

// dotenv 안전 접근 헬퍼 함수
String _getEnv(String key) {
  // 웹에서는 환경 변수 또는 기본값 사용
  if (kIsWeb) {
    // 웹 빌드 시 --dart-define으로 주입된 환경 변수 사용
    const webApiKeys = {
      'JUSO_API_KEY': String.fromEnvironment('JUSO_API_KEY'),
      'VWORLD_API_KEY': String.fromEnvironment('VWORLD_API_KEY'),
      'VWORLD_GEOCODER_API_KEY': String.fromEnvironment('VWORLD_GEOCODER_API_KEY'),
      'DATA_GO_KR_SERVICE_KEY': String.fromEnvironment('DATA_GO_KR_SERVICE_KEY'),
      'NAVER_MAP_CLIENT_ID': String.fromEnvironment('NAVER_MAP_CLIENT_ID'),
      'CODEF_CLIENT_ID': String.fromEnvironment('CODEF_CLIENT_ID'),
      'CODEF_CLIENT_SECRET': String.fromEnvironment('CODEF_CLIENT_SECRET'),
      'CODEF_PUBLIC_KEY': String.fromEnvironment('CODEF_PUBLIC_KEY'),
      'REGISTER_API_KEY': String.fromEnvironment('REGISTER_API_KEY'),
      'SEOUL_OPEN_API_KEY': String.fromEnvironment('SEOUL_OPEN_API_KEY'),
      'KAKAO_NATIVE_APP_KEY': String.fromEnvironment('KAKAO_NATIVE_APP_KEY'),
      'KAKAO_JAVASCRIPT_APP_KEY': String.fromEnvironment('KAKAO_JAVASCRIPT_APP_KEY'),
    };
    
    final value = webApiKeys[key] ?? '';
    // 웹 빌드 시 --dart-define으로 키를 주입해야 합니다.
    // 예: flutter build web --dart-define=JUSO_API_KEY=xxx --dart-define=DATA_GO_KR_SERVICE_KEY=yyy
    // 하드코딩된 fallback 키는 보안상 제거되었습니다.
    return value;
  }
  
  try {
    // dotenv가 초기화되었는지 확인
    return dotenv.env[key] ?? '';
  } catch (e) {
    // NotInitializedError 등 예외 발생 시 빈 문자열 반환
    return '';
  }
}

// 시/도-시군구 매핑 데이터
class RegionConstants {
  static const Map<String, List<String>> sidoSigunguMap = {
    "서울특별시": ["강남구", "강동구", "강북구", "강서구", "관악구", "광진구", "구로구", "금천구", "노원구", "도봉구",
              "동대문구", "동작구", "마포구", "서대문구", "서초구", "성동구", "성북구", "송파구", "양천구", "영등포구",
              "용산구", "은평구", "종로구", "중구", "중랑구"],
    "부산광역시": ["강서구", "금정구", "기장군", "남구", "동구", "동래구", "법인구", "부산진구", "북구", "사상구",
              "사하구", "서구", "수영구", "연제구", "영도구", "중구", "해운대구"],
    "대구광역시": ["남구", "달서구", "달성군", "동구", "북구", "서구", "수성구", "중구"],
    "인천광역시": ["강화군", "계양구", "남구", "남동구", "동구", "미추홀구", "부평구", "서구", "연수구", "옹진군", "중구"],
    "광주광역시": ["광산구", "남구", "동구", "북구", "서구"],
    "대전광역시": ["대덕구", "동구", "서구", "유성구", "중구"],
    "울산광역시": ["남구", "동구", "북구", "울주군", "중구"],
    "세종특별자치시": [],
    "경기도": ["가평군", "고양시 덕양구", "고양시 일산동구", "고양시 일산서구", "과천시", "광명시", "광주시", "구리시", "군포시", "김포시",
           "남양주시", "동두천시", "부천시", "부천시 소사구", "부천시 오정구", "부천시 원미구", "성남시", "성남시 분당구",
           "성남시 수정구", "성남시 중원구", "수원시", "수원시 권선구", "수원시 영통구", "수원시 장안구", "수원시 팔달구",
           "시흥시", "안산시", "안산시 단원구", "안산시 상록구", "안성시", "안양시", "안양시 동안구", "안양시 만안구",
           "양주시", "양평군", "여주군", "여주시", "연천군", "오산시", "용인시", "용인시 기흥구", "용인시 수지구", "용인시 처인구",
           "의왕시", "의정부시", "이천시", "파주시", "평택시", "포천시", "하남시", "화성시"],
    "강원도": ["강릉시", "고성군", "동해시", "삼척시", "속초시", "양구군", "양양군", "영월군", "원주시", "인제군",
           "정선군", "철원군", "춘천시", "태백시", "평창군", "홍천군", "화천군", "횡성군"],
    "충청북도": ["괴산군", "단양군", "보은군", "영동군", "옥천군", "음성군", "제천시", "증평군", "진천군",
            "청원군", "청주시 상당구", "청주시 서원구", "청주시 청원구", "청주시 흥덕구", "충주시"],
    "충청남도": ["계룡시", "공주시", "금산군", "논산시", "당진군", "당진시", "보령시", "부여군", "서산시", "서천군",
            "아산시", "연기군", "예산군", "천안시", "천안시 동남구", "천안시 서북구", "청양군", "태안군", "홍성군"],
    "전라북도": ["고창군", "군산시", "김제시", "남원시", "무주군", "부안군", "순창군", "완주군", "익산시", "임실군",
            "장수군", "전주시", "전주시 덕진구", "전주시 완산구", "정읍시", "진안군"],
    "전라남도": ["강진군", "고흥군", "곡성군", "광양시", "구례군", "나주시", "담양군", "목포시", "무안군", "보성군",
            "순천시", "신안군", "여수시", "영광군", "영암군", "완도군", "장성군", "장흥군", "진도군",
            "함평군", "해남군", "화순군"],
    "경상북도": ["경산시", "경주시", "고령군", "구미시", "군위군", "김천시", "문경시", "봉화군", "상주시", "성주군",
            "안동시", "영덕군", "영양군", "영주시", "영천시", "예천군", "울릉군", "울진군", "의성군",
            "청도군", "청송군", "칠곡군", "포항시", "포항시 남구", "포항시 북구"],
    "경상남도": ["거제시", "거창군", "고성군", "김해시", "남해군", "밀양시", "사천시", "산청군", "양산시", "의령군",
            "진주시", "창녕군", "창원시", "창원시 마산합포구", "창원시 마산회원구", "창원시 성산구",
            "창원시 의창구", "창원시 진해구", "통영시", "하동군", "함안군", "함양군", "합천군"],
    "제주특별자치도": ["서귀포시", "제주시"]
  };
}

// 고객센터 / 문의하기 관련 URL 상수
class CustomerServiceUrls {
  static const String kakaoOpenChatUrl = 'https://open.kakao.com/o/g6pBaX5h';
  static const String facebookUrl = 'https://www.facebook.com/61585231130222/posts/pfbid0MHmKymArwSneHZdbZu76dx2grVupcE3xu5QCPCz7pRcnVYWXb7eTEJBh2L1QTepol/';
  static const String threadsUrl = 'https://www.threads.com/@goldepond';
  static const String supportEmail = 'goldepond@gmail.com';
} 