/// 간격 시스템
/// 8px 그리드 시스템을 기반으로 한 일관된 간격 정의
class AppSpacing {
  // 기본 간격 (8px 그리드 시스템)
  static const double xs = 4.0;   // 0.5 * 8
  static const double sm = 8.0;   // 1 * 8
  static const double md = 16.0;  // 2 * 8
  static const double lg = 24.0;  // 3 * 8
  static const double xl = 32.0;  // 4 * 8
  static const double xxl = 48.0; // 6 * 8
  static const double xxxl = 64.0; // 8 * 8
  
  // 카드 간격
  static const double cardSpacing = md;
  static const double sectionSpacing = lg;
  
  // 패딩
  static const double screenPadding = md;
  static const double cardPadding = md;
  static const double cardPaddingLarge = lg;
  
  // 마진
  static const double screenMargin = md;
  static const double sectionMargin = lg;
  
  // 버튼
  static const double buttonPadding = md;
  static const double buttonPaddingSmall = sm;
  static const double buttonPaddingLarge = lg;
  
  // 입력 필드
  static const double inputPadding = md;
  static const double inputSpacing = md;
}

/// 둥근 모서리(border radius) 시스템
/// 일관된 둥근 모서리 값 정의
class AppRadius {
  static const double sm = 8.0;    // 칩, 작은 요소
  static const double md = 12.0;   // 입력 필드, 소형 카드, 버튼
  static const double lg = 16.0;   // 일반 카드
  static const double xl = 24.0;   // 대형 카드, 바텀시트
  static const double pill = 100.0; // 필 버튼
}







