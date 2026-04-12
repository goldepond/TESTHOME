# MyHome UI/UX 종합 개선 계획

> 작성일: 2026-04-12
> 근거 문서: UI-SPEC.md (디자인 스펙), UI-REVIEW.md (6축 감사), UI Checker 결과
> 현재 종합 점수: **34/60** (목표: 50/60)

---

## 1. 감사 결과 종합 요약

### 1.1 정량 현황

| 지표 | 현재 수치 | 목표 | 비고 |
|------|----------|------|------|
| 6축 종합 점수 | 34/60 | 50/60 | 접근성(3)이 최저 |
| 색상 시스템 수 | 3개 공존 | 1개 (AirbnbColors) | AppleColors 497건, AppColors 0건(screens), 하드코딩 2,055건 |
| AppTypography 사용률 | 40% (224 vs 337 인라인) | 85%+ | 비표준 fontSize(11,13,15,22) 다수 |
| AppSpacing 사용률 | 17% (105 vs 524 인라인) | 60%+ | 대부분 하드코딩 EdgeInsets |
| CommonDesignSystem 활용 | 3% (13건/4파일) | 30%+ | 41개 화면 중 4개만 |
| 반응형 적용 | 42% (17/40 화면) | 90%+ | admin 전체 + auth 관련 미적용 |
| Semantics 사용 | 11건/3파일 | 전체 인터랙티브 요소 | WCAG AA 전면 미달 |
| borderRadius 변형 | 10종+ | 5종 (8/12/16/24/100) | 표준 미정의 |

### 1.2 6축 점수 분석

| 축 | 점수 | 핵심 문제 |
|---|------|----------|
| **접근성** | **3/10** | Semantics 11건, 색상 대비 WCAG AA 미달, 터치 타겟 40px |
| **일관성** | **5/10** | 3개 색상 체계, 인라인 스타일이 토큰의 1.5~5배 |
| **반응성** | 6/10 | 23개 화면 미적용, 브레이크포인트 불일치(800 vs 600) |
| **시각 계층** | 6/10 | 비표준 fontSize, AppBar/카드 스타일 직접 구성 |
| **인터랙션** | 7/10 | 양호. SnackBar 스타일 불일치, 중복 제출 방지 일부 누락 |
| **브랜드** | 7/10 | 코랄 통일 양호. Colors.white 등 Flutter 기본 직접 사용 빈번 |

### 1.3 UI Checker FLAG 3건

1. **카피라이팅**: CTA 라벨 일관성 검증 필요 (빈 상태 메시지 역할별 차이)
2. **시각 계층**: 인라인 fontSize 337건으로 정의된 타이포 스케일 무력화
3. **타이포그래피**: body 16px vs 17px 이중 정의, 비표준 사이즈 산재

---

## 2. 실행 로드맵

### 우선순위 근거

1. **접근성(Phase 1)을 최우선으로 하는 이유**: 법적 리스크(장애인차별금지법, 앱스토어 접근성 정책), 사용자 기반 확대 불가, 점수 3/10으로 가장 낮음
2. **토큰 통합(Phase 2)이 그 다음인 이유**: 이후 모든 개선 작업의 기반. 토큰이 통일되지 않으면 Phase 3-4에서 다시 불일치 발생
3. **반응형/컴포넌트(Phase 3)**: 토큰 통합 후 일괄 적용이 효율적
4. **고도화(Phase 4)**: 기반이 갖춰진 후 진행해야 효과 극대화

---

## Phase 1: 접근성 P0 이슈 해결 (긴급, 1-2주)

> 목표: 접근성 점수 3/10 -> 6/10
> WCAG AA 기본 충족, 터치 타겟 44px 보장, Semantics 핵심 화면 적용

### 1-1. 색상 대비 WCAG AA 충족 [쉬움]

**파일**: `lib/constants/app_constants.dart`

| 변경 | 현재 값 | 변경 값 | 대비 (on white) |
|------|---------|---------|:----:|
| `AirbnbColors.textSecondary` | `#8B7F74` (3.4:1) | `#6B6560` (4.8:1) | AA 통과 |
| `AirbnbColors.textLight` | `#A69E96` (2.5:1) | `#837B73` (4.0:1) | 대형 텍스트 통과 |

```dart
// lib/constants/app_constants.dart:71-72 변경
// 변경 전
static const Color textSecondary = Color(0xFF8B7F74);
static const Color textLight = Color(0xFFA69E96);
// 변경 후
static const Color textSecondary = Color(0xFF6B6560);  // WCAG AA 4.8:1
static const Color textLight = Color(0xFF837B73);      // WCAG AA 4.0:1 (대형 텍스트)
```

### 1-2. 터치 타겟 최소 44px 보장 [쉬움]

| 파일 | 현재 | 변경 |
|------|------|------|
| `lib/screens/main_page.dart:414` | `height: 40, width: 40` | `height: 44, width: 44` |
| `lib/screens/seller/mls_property_detail_page.dart:1660` | `height: 40` | `height: 44` |

추가로 프로젝트 전체에서 `height: 40` 또는 `width: 40`인 인터랙티브 요소를 검색하여 44px로 조정:

```bash
# 검색 명령
grep -rn "height: 40\|width: 40" lib/screens/ lib/widgets/
```

### 1-3. 핵심 화면 Semantics 추가 [보통]

**대상**: 사용 빈도 높은 8개 화면 우선 적용

| 파일 | 작업 | 예상 변경량 |
|------|------|-----------|
| `lib/screens/main_page.dart` | BottomNavigationBar 아이템에 semanticLabel, 헤더 IconButton에 Tooltip+Semantics | ~15건 |
| `lib/screens/seller/mls_seller_dashboard_page.dart` | 매물 카드 Semantics.label, 필터 칩 semanticLabel | ~20건 |
| `lib/screens/broker/mls_broker_dashboard_page.dart` | 탭 Semantics, 매물 카드 label, 액션 버튼 tooltip | ~25건 |
| `lib/screens/auth/auth_landing_page.dart` | 소셜 로그인 버튼 semanticLabel, 로고 이미지 semanticLabel | ~5건 |
| `lib/screens/login_page.dart` | 폼 필드 label, 로그인 버튼 semanticLabel | ~5건 |
| `lib/screens/public/public_listings_page.dart` | 매물 그리드 아이템 Semantics, 필터 label | ~15건 |
| `lib/screens/seller/mls_property_detail_page.dart` | 이미지 갤러리 semanticLabel, 액션 버튼 tooltip | ~20건 |
| `lib/screens/market_price/market_price_page.dart` | 검색 입력 label, 차트 Semantics | ~10건 |

**패턴**: `AccessibleWidget` 래퍼 활용 또는 직접 Semantics 위젯 추가

```dart
// IconButton에 Tooltip + Semantics 추가 패턴
Semantics(
  button: true,
  label: '알림',
  child: Tooltip(
    message: '알림',
    child: IconButton(
      icon: const Icon(Icons.notifications_outlined),
      onPressed: () { ... },
    ),
  ),
)
```

### 1-4. 이미지 접근성 [쉬움]

**파일**: `lib/widgets/optimized_image.dart`, 각 화면의 Image/Icon 위젯

- 모든 `Image.network`, `Image.asset`에 `semanticLabel` 파라미터 추가
- 장식용 이미지는 `Semantics(excludeSemantics: true)` 래핑

**Phase 1 완료 후 예상 점수 변화:**

| 축 | 변경 전 | 변경 후 |
|---|:------:|:------:|
| 접근성 | 3/10 | 6/10 |
| **종합** | **34/60** | **37/60** |

---

## Phase 2: 색상/타이포/간격 토큰 통합 (단기, 2-4주)

> 목표: 일관성 점수 5/10 -> 7/10, 시각 계층 6/10 -> 8/10
> AirbnbColors 단일 체계, AppTypography 사용률 85%, AppSpacing 사용률 60%

### 2-1. AppleColors/AppleTypography -> AirbnbColors/AppTypography 마이그레이션 [보통]

9개 파일에서 총 497건의 AppleColors/AppleTypography 참조를 AirbnbColors/AppTypography로 변환.

**매핑 테이블:**

| AppleColors | AirbnbColors 대체 |
|-------------|------------------|
| `AppleColors.systemBlue` | `AirbnbColors.primary` |
| `AppleColors.systemRed` | `AirbnbColors.red` |
| `AppleColors.systemOrange` | `AirbnbColors.orange` |
| `AppleColors.systemGreen` | `AirbnbColors.green` |
| `AppleColors.systemGray` | `AirbnbColors.textSecondary` |
| `AppleColors.systemGray2` | `AirbnbColors.textLight` |
| `AppleColors.systemGray3` | `AirbnbColors.border` |
| `AppleColors.systemGray5` | `AirbnbColors.borderLight` |
| `AppleColors.systemGray6` | `AirbnbColors.surface` |
| `AppleColors.label` | `AirbnbColors.textPrimary` |
| `AppleColors.secondaryLabel` | `AirbnbColors.textSecondary` |
| `AppleTypography.body` | `AppTypography.body` |
| `AppleTypography.headline` | `AppTypography.h4` |
| `AppleTypography.footnote` | `AppTypography.caption` |
| `AppleTypography.largeTitle` | `AppTypography.display` |

**파일별 작업량 (내림차순):**

| 파일 | AppleColors 건수 | 난이도 |
|------|:---------------:|:------:|
| `lib/screens/market_price/market_price_page.dart` | 135건 | 어려움 |
| `lib/screens/seller/mls_property_detail_page.dart` | 153건 | 어려움 |
| `lib/screens/seller/mls_quick_registration_page.dart` | 96건 | 보통 |
| `lib/screens/seller/mls_seller_dashboard_page.dart` | 34건 | 보통 |
| `lib/screens/seller/mls_property_edit_page.dart` | 32건 | 보통 |
| `lib/screens/auth/profile_completion_page.dart` | 26건 | 쉬움 |
| `lib/screens/auth/auth_landing_page.dart` | 8건 | 쉬움 |
| `lib/screens/seller/mls_property_registration_page.dart` | 7건 | 쉬움 |
| `lib/screens/main_page.dart` | 6건 | 쉬움 |

### 2-2. 인라인 fontSize -> AppTypography 토큰 교체 [보통]

337건의 인라인 `TextStyle(fontSize: ...)` -> `AppTypography.*` 토큰으로 교체.

**변환 규칙:**

| 인라인 fontSize | AppTypography 토큰 | 비고 |
|:--------------:|-------------------|------|
| 32 | `AppTypography.display` | |
| 28 | `AppTypography.h1` | |
| 24 | `AppTypography.h2` | |
| 20 | `AppTypography.h3` | |
| 18 | `AppTypography.h4` 또는 `bodyLarge` | bold면 h4, normal이면 bodyLarge |
| 16 | `AppTypography.body` | |
| 14 | `AppTypography.bodySmall` | |
| 12 | `AppTypography.caption` | |

**비표준 사이즈 처리:**

| 비표준 fontSize | 처리 방법 |
|:--------------:|----------|
| 11 | `AppTypography.caption` (12px)로 변경. 시각적 차이 최소 |
| 13 | `AppTypography.bodySmall` (14px) 또는 신규 `captionLarge` 토큰 추가 |
| 15 | `AppTypography.body` (16px) 또는 `AppTypography.bodySmall` (14px) |
| 22 | `AppTypography.h2` (24px)로 변경. 차이가 크면 `h2Small` 토큰 추가 |

**typography.dart에 추가 권장 토큰:**

```dart
// lib/constants/typography.dart 에 추가
static const TextStyle captionLarge = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.normal,
  height: 1.4,
  fontFamily: 'NotoSansKR',
);
```

**주요 대상 파일 (인라인 fontSize 다빈도 순):**

| 파일 | 예상 인라인 건수 | 난이도 |
|------|:--------------:|:------:|
| `lib/screens/seller/mls_quick_registration_page.dart` | ~40건 | 보통 |
| `lib/screens/seller/mls_property_detail_page.dart` | ~35건 | 보통 |
| `lib/screens/market_price/market_price_page.dart` | ~30건 | 보통 |
| `lib/screens/seller/mls_seller_dashboard_page.dart` | ~25건 | 보통 |
| `lib/screens/broker/mls_broker_dashboard_page.dart` | ~20건 | 보통 |
| 나머지 31개 화면 | ~187건 | 쉬움~보통 |

### 2-3. 인라인 EdgeInsets -> AppSpacing 토큰 교체 [보통]

524건의 하드코딩 EdgeInsets 중 반복 패턴 우선 교체.

**변환 규칙:**

| 인라인 값 | AppSpacing 대체 |
|----------|----------------|
| `EdgeInsets.all(4)` | `EdgeInsets.all(AppSpacing.xs)` |
| `EdgeInsets.all(8)` | `EdgeInsets.all(AppSpacing.sm)` |
| `EdgeInsets.all(16)` | `EdgeInsets.all(AppSpacing.md)` |
| `EdgeInsets.all(24)` | `EdgeInsets.all(AppSpacing.lg)` |
| `EdgeInsets.all(32)` | `EdgeInsets.all(AppSpacing.xl)` |
| `EdgeInsets.symmetric(horizontal: 16)` | `EdgeInsets.symmetric(horizontal: AppSpacing.md)` |
| `EdgeInsets.symmetric(horizontal: 24)` | `EdgeInsets.symmetric(horizontal: AppSpacing.lg)` |
| `SizedBox(height: 8)` | `SizedBox(height: AppSpacing.sm)` |
| `SizedBox(height: 16)` | `SizedBox(height: AppSpacing.md)` |
| `SizedBox(height: 24)` | `SizedBox(height: AppSpacing.lg)` |

**작업 순서**: 고빈도 패턴부터 정규식 일괄 치환 -> 수동 검증

### 2-4. borderRadius 표준화 [쉬움]

**spacing.dart에 borderRadius 상수 추가:**

```dart
// lib/constants/spacing.dart 에 추가
class AppRadius {
  static const double sm = 8.0;    // 칩, 작은 요소
  static const double md = 12.0;   // 입력 필드, 소형 카드, 버튼
  static const double lg = 16.0;   // 일반 카드
  static const double xl = 24.0;   // 대형 카드, 바텀시트
  static const double pill = 100.0; // 필 버튼
}
```

**변환 규칙:**

| 현재 값 | 표준 값 | 비고 |
|:------:|:------:|------|
| 4, 6 | `AppRadius.sm` (8) | 올림 |
| 8 | `AppRadius.sm` (8) | 유지 |
| 10 | `AppRadius.md` (12) | 올림 |
| 12 | `AppRadius.md` (12) | 유지 |
| 16 | `AppRadius.lg` (16) | 유지 |
| 20 | `AppRadius.xl` (24) | 올림 |
| 24, 26 | `AppRadius.xl` (24) | 통일 |
| 100 | `AppRadius.pill` (100) | 유지 |

### 2-5. 하드코딩 Colors.* 정리 (고빈도) [쉬움]

가장 빈번한 Flutter 기본 색상 직접 사용을 AirbnbColors 토큰으로 교체:

| 하드코딩 | AirbnbColors 대체 | 비고 |
|---------|------------------|------|
| `Colors.white` | `AirbnbColors.background` | 카드/서피스 배경 |
| `Colors.black` | `AirbnbColors.textPrimary` | 텍스트 용도일 때 |
| `Colors.grey[200]` | `AirbnbColors.borderLight` | 테두리 용도 |
| `Colors.grey[300]` | `AirbnbColors.border` | 테두리 용도 |
| `Colors.grey[600]` | `AirbnbColors.textSecondary` | 텍스트 용도 |
| `Colors.red` | `AirbnbColors.red` | 에러/삭제 |
| `Colors.green` | `AirbnbColors.green` | 성공 |
| `Colors.transparent` | 유지 | 의미적으로 투명 |

**Phase 2 완료 후 예상 점수 변화:**

| 축 | 변경 전 | 변경 후 |
|---|:------:|:------:|
| 일관성 | 5/10 | 7/10 |
| 시각 계층 | 6/10 | 8/10 |
| 브랜드 정체성 | 7/10 | 8/10 |
| **종합** | **37/60** | **43/60** |

---

## Phase 3: 반응형 확대 및 컴포넌트 표준화 (중기, 1-2개월)

> 목표: 반응성 점수 6/10 -> 8/10, 인터랙션 7/10 -> 8/10
> 전체 화면 반응형 적용, CommonDesignSystem 활용 확대

### 3-1. 미적용 화면에 반응형 레이아웃 추가 [보통]

23개 미적용 화면에 `Center` + `ConstrainedBox` + `ResponsiveHelper.getMaxWidth()` 래핑 추가.

**admin 화면 (9개):**

| 파일 | 작업 | 난이도 |
|------|------|:------:|
| `lib/screens/admin/admin_dashboard.dart` | body를 Center+ConstrainedBox로 래핑 | 보통 |
| `lib/screens/admin/admin_broker_management.dart` | 동일 패턴 적용 | 보통 |
| `lib/screens/admin/admin_broker_stats_page.dart` | 동일 패턴 적용 | 보통 |
| `lib/screens/admin/admin_property_management.dart` | 이미 1건 ConstrainedBox 있으나 전체 적용 필요 | 보통 |
| `lib/screens/admin/admin_property_verification_page.dart` | 동일 패턴 적용 | 보통 |
| `lib/screens/admin/admin_matching_page.dart` | 동일 패턴 적용 | 보통 |
| `lib/screens/admin/admin_quote_requests_page.dart` | 동일 패턴 적용 | 보통 |
| `lib/screens/admin/admin_user_logs_page.dart` | 동일 패턴 적용 | 보통 |
| `lib/screens/admin/admin_proxy_registration_page.dart` | 동일 패턴 적용 | 보통 |

**auth/개인 화면 (7개):**

| 파일 | 작업 | 난이도 |
|------|------|:------:|
| `lib/screens/auth/auth_landing_page.dart` | Center+ConstrainedBox 래핑 (maxWidth: 480) | 쉬움 |
| `lib/screens/login_page.dart` | 동일 (maxWidth: 480) | 쉬움 |
| `lib/screens/signup_page.dart` | 동일 (maxWidth: 480) | 쉬움 |
| `lib/screens/forgot_password_page.dart` | 동일 (maxWidth: 480) | 쉬움 |
| `lib/screens/change_password_page.dart` | 동일 (maxWidth: 480) | 쉬움 |
| `lib/screens/notification/notification_page.dart` | Center+ConstrainedBox 래핑 | 쉬움 |
| `lib/screens/buyer/my_inquiries_page.dart` | Center+ConstrainedBox 래핑 | 쉬움 |

**기타 미적용 화면 (7개):**

| 파일 | 작업 | 난이도 |
|------|------|:------:|
| `lib/screens/buyer/my_favorites_page.dart` | Center+ConstrainedBox 래핑 | 쉬움 |
| `lib/screens/userInfo/personal_info_page.dart` | 동일 (maxWidth: 480) | 쉬움 |
| `lib/screens/common/submit_success_page.dart` | 동일 (maxWidth: 480) | 쉬움 |
| `lib/screens/user_type_selection_page.dart` | 동일 (maxWidth: 480) | 쉬움 |
| `lib/screens/inquiry/broker_inquiry_response_page.dart` | Center+ConstrainedBox 래핑 | 보통 |
| `lib/screens/seller/negotiation_section.dart` | 부모 화면에서 제약 상속 확인 | 쉬움 |
| `lib/screens/public/public_property_detail_page.dart` | Center+ConstrainedBox 래핑 | 보통 |

**적용 패턴 (auth 화면 예시):**

```dart
// 변경 전
@override
Widget build(BuildContext context) {
  return Scaffold(
    body: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [...]),
      ),
    ),
  );
}

// 변경 후
@override
Widget build(BuildContext context) {
  return Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Column(children: [...]),
          ),
        ),
      ),
    ),
  );
}
```

### 3-2. 브레이크포인트 통일 [쉬움]

`ResponsiveHelper.isWeb()` (800px 기준) 사용처를 `ResponsiveHelper.isTablet()` (600px) 또는 적절한 브레이크포인트로 통일.

**파일**: `lib/constants/responsive_constants.dart` 내 `isWeb` 메서드 수정 또는 호출부 변경

### 3-3. CommonDesignSystem 활용 확대 [보통]

**standardAppBar() 적용 확대:**

현재 4파일 -> 전체 Scaffold 화면 적용.

| 적용 대상 | 예상 파일 수 | 작업 |
|----------|:----------:|------|
| `AppBar()` 직접 구성 화면 | ~30개 | `CommonDesignSystem.standardAppBar(title: ...)` 로 교체 |

**cardDecoration() 적용 확대:**

```dart
// 변경 전 (각 화면에서 직접 정의)
Container(
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: Colors.grey[200]!),
    boxShadow: [...],
  ),
)

// 변경 후
Container(
  decoration: CommonDesignSystem.cardDecoration(),
)
```

**inputDecoration() 적용 확대:**

폼 입력 필드의 `InputDecoration` 직접 정의를 `CommonDesignSystem.inputDecoration()` 으로 교체.

### 3-4. SnackBar 스타일 표준화 [보통]

**lib/utils/에 공통 SnackBar 유틸 추가:**

```dart
// lib/utils/snackbar_utils.dart (신규 파일)
class AppSnackBar {
  static void success(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: AppTypography.withColor(AppTypography.bodySmall, AirbnbColors.textWhite)),
      backgroundColor: AirbnbColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
      duration: const Duration(seconds: 3),
    ));
  }

  static void error(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: AppTypography.withColor(AppTypography.bodySmall, AirbnbColors.textWhite)),
      backgroundColor: AirbnbColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
      duration: const Duration(seconds: 4),
    ));
  }

  static void warning(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: AppTypography.withColor(AppTypography.bodySmall, AirbnbColors.textWhite)),
      backgroundColor: AirbnbColors.warning,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
      duration: const Duration(seconds: 4),
    ));
  }
}
```

27개 파일에서 314건의 SnackBar를 점진적으로 `AppSnackBar.*()` 호출로 교체.

### 3-5. 에러 핸들링 표준화 [보통]

UI-SPEC 7.3절 권장 표준 적용:

| 에러 유형 | UI 패턴 | 적용 대상 |
|----------|---------|----------|
| 네트워크/로딩 실패 | `RetryView` (전체 화면 대체) | StreamBuilder/FutureBuilder error 분기 |
| 폼 제출 실패 | `AppSnackBar.error()` | 모든 폼 제출 catch 블록 |
| 위험한 액션 확인 | `AccessibleWidget.showConfirmDialog()` | 삭제/거절/탈퇴 |
| 인라인 검증 | TextFormField `validator` | 모든 필수 입력 필드 |

**Phase 3 완료 후 예상 점수 변화:**

| 축 | 변경 전 | 변경 후 |
|---|:------:|:------:|
| 반응성 | 6/10 | 8/10 |
| 인터랙션 | 7/10 | 8/10 |
| 일관성 | 7/10 | 8/10 |
| **종합** | **43/60** | **48/60** |

---

## Phase 4: 디자인 시스템 고도화 (장기, 2-3개월)

> 목표: 전체 50/60 이상
> apple_design_system.dart 내부화, 다크 모드 준비, 애니메이션 체계

### 4-1. AppleColors/AppleTypography 내부화 [보통]

Phase 2에서 화면 코드의 직접 참조를 제거한 후, `apple_design_system.dart` 내부의 `AppleButton`, `AppleCard` 등 위젯이 내부적으로만 AppleColors를 사용하도록 캡슐화.

- `AppleColors`, `AppleTypography`를 `_AppleColors`, `_AppleTypography`로 변경 (private)
- 또는 `AppleButton`/`AppleCard` 위젯 자체를 AirbnbColors 기반으로 재작성

### 4-2. AppColors 완전 제거 [쉬움]

`lib/constants/app_constants.dart`에서 `AppColors` 클래스를 deprecated 마킹 후, 남은 참조(widgets/ 등)를 모두 `AirbnbColors`로 교체하고 클래스 삭제.

### 4-3. 다크 모드 지원 준비 [어려움]

```dart
// lib/constants/app_constants.dart 에 추가
class AirbnbColorsDark {
  static const Color primary = Color(0xFFF4A593);      // 연한 코랄 (다크 배경 위)
  static const Color background = Color(0xFF1A1512);    // 다크 배경
  static const Color surface = Color(0xFF2D2A26);       // 다크 서피스
  static const Color textPrimary = Color(0xFFFAF8F5);   // 밝은 텍스트
  static const Color textSecondary = Color(0xFFA69E96);  // 중간 텍스트
  static const Color border = Color(0xFF3D3832);        // 다크 테두리
  // ... 전체 토큰 미러링
}
```

- `ThemeData.light()` / `ThemeData.dark()` 기반 테마 전환 구조 구축
- `AirbnbColors` 정적 참조를 `Theme.of(context).extension<AppColorScheme>()` 패턴으로 점진적 전환

### 4-4. 애니메이션/트랜지션 체계 [보통]

UI-SPEC 9.2절 권장사항 적용:

| 요소 | 구현 | 파일 |
|------|------|------|
| 카드 호버 그림자 | `AnimatedContainer` + `cardShadow` -> `cardShadowHover` | 매물 카드 위젯 |
| 필터 칩 활성화 | `AnimatedContainer` 배경색 전환 150ms | 필터 칩 위젯 |
| 리스트 아이템 추가 | `AnimatedList` 또는 `SlideTransition` | 매물 리스트 |

### 4-5. 남은 Semantics 전면 적용 [보통]

Phase 1에서 핵심 8개 화면에 적용한 패턴을 나머지 32개 화면으로 확대.

### 4-6. 나머지 하드코딩 Colors.* 정리 [보통]

Phase 2에서 고빈도 패턴을 처리한 후, 남은 하드코딩 색상 전수 조사 및 교체.

**Phase 4 완료 후 예상 점수 변화:**

| 축 | 변경 전 | 변경 후 |
|---|:------:|:------:|
| 접근성 | 6/10 | 8/10 |
| 일관성 | 8/10 | 9/10 |
| 브랜드 정체성 | 8/10 | 9/10 |
| **종합** | **48/60** | **52/60** |

---

## 3. 전체 작업 목록 요약

| Phase | 작업 | 파일 수 | 난이도 | 예상 소요 |
|:-----:|------|:------:|:------:|:--------:|
| 1-1 | 색상 대비 WCAG AA | 1 | 쉬움 | 0.5일 |
| 1-2 | 터치 타겟 44px | 2~5 | 쉬움 | 0.5일 |
| 1-3 | 핵심 화면 Semantics | 8 | 보통 | 3일 |
| 1-4 | 이미지 접근성 | 10~15 | 쉬움 | 1일 |
| 2-1 | AppleColors 마이그레이션 | 9 | 보통 | 5일 |
| 2-2 | 인라인 fontSize 토큰화 | 36 | 보통 | 5일 |
| 2-3 | 인라인 EdgeInsets 토큰화 | 40 | 보통 | 5일 |
| 2-4 | borderRadius 표준화 | 30+ | 쉬움 | 2일 |
| 2-5 | Colors.* 고빈도 정리 | 40 | 쉬움 | 3일 |
| 3-1 | 반응형 23개 화면 적용 | 23 | 보통 | 5일 |
| 3-2 | 브레이크포인트 통일 | 1~3 | 쉬움 | 0.5일 |
| 3-3 | CommonDesignSystem 확대 | 30 | 보통 | 5일 |
| 3-4 | SnackBar 표준화 | 27+1(신규) | 보통 | 3일 |
| 3-5 | 에러 핸들링 표준화 | 33 | 보통 | 3일 |
| 4-1 | Apple 시스템 내부화 | 1~3 | 보통 | 2일 |
| 4-2 | AppColors 제거 | 1~5 | 쉬움 | 1일 |
| 4-3 | 다크 모드 준비 | 전체 | 어려움 | 15일 |
| 4-4 | 애니메이션 체계 | 5~10 | 보통 | 5일 |
| 4-5 | Semantics 전면 확대 | 32 | 보통 | 5일 |
| 4-6 | 하드코딩 색상 전수 정리 | 40 | 보통 | 5일 |

---

## 4. 예상 점수 변화 추이

```
Phase 0 (현재):  34/60 ████████████████░░░░░░░░░░░░░░
Phase 1 완료:    37/60 ██████████████████░░░░░░░░░░░░
Phase 2 완료:    43/60 █████████████████████░░░░░░░░░
Phase 3 완료:    48/60 ████████████████████████░░░░░░
Phase 4 완료:    52/60 ██████████████████████████░░░░
```

| 축 | 현재 | P1 후 | P2 후 | P3 후 | P4 후 |
|---|:----:|:-----:|:-----:|:-----:|:-----:|
| 접근성 | 3 | 6 | 6 | 6 | 8 |
| 일관성 | 5 | 5 | 7 | 8 | 9 |
| 반응성 | 6 | 6 | 6 | 8 | 8 |
| 시각 계층 | 6 | 6 | 8 | 8 | 9 |
| 인터랙션 | 7 | 7 | 7 | 8 | 9 |
| 브랜드 | 7 | 7 | 8 | 8 | 9 |
| **합계** | **34** | **37** | **42** | **46** | **52** |

---

## 5. 디자인 원칙 5가지

향후 모든 코드 작성 시 다음 규칙을 준수한다.

### 원칙 1: 토큰 우선 (Token First)

> 하드코딩 금지. 색상은 `AirbnbColors`, 타이포는 `AppTypography`, 간격은 `AppSpacing`, 모서리는 `AppRadius`만 사용한다.

```dart
// BAD
TextStyle(fontSize: 14, color: Colors.grey[600])
EdgeInsets.all(16)
BorderRadius.circular(12)

// GOOD
AppTypography.withColor(AppTypography.bodySmall, AirbnbColors.textSecondary)
EdgeInsets.all(AppSpacing.md)
BorderRadius.circular(AppRadius.md)
```

### 원칙 2: 접근성 내장 (Accessibility Built-in)

> 모든 인터랙티브 요소에 Semantics 또는 Tooltip을 포함한다. 아이콘 버튼에는 반드시 tooltip 파라미터를 전달한다. 이미지에는 semanticLabel을 포함한다.

```dart
// BAD
IconButton(icon: Icon(Icons.delete), onPressed: _delete)

// GOOD
IconButton(
  icon: const Icon(Icons.delete),
  tooltip: '삭제',
  onPressed: _delete,
)
```

### 원칙 3: 반응형 기본 (Responsive Default)

> 모든 Scaffold의 body는 `Center` + `ConstrainedBox` + `ResponsiveHelper.getMaxWidth()`로 래핑한다. auth 관련 폼 화면은 maxWidth 480px를 적용한다.

```dart
// 표준 패턴
Center(
  child: ConstrainedBox(
    constraints: BoxConstraints(
      maxWidth: ResponsiveHelper.getMaxWidth(context),
    ),
    child: actualContent,
  ),
)
```

### 원칙 4: 공통 컴포넌트 재사용 (Reuse Components)

> AppBar는 `CommonDesignSystem.standardAppBar()`, 카드는 `CommonDesignSystem.cardDecoration()`, 입력은 `CommonDesignSystem.inputDecoration()`, SnackBar는 `AppSnackBar.*()`, 확인 다이얼로그는 `AccessibleWidget.showConfirmDialog()`를 사용한다. 직접 스타일링 금지.

### 원칙 5: 8px 그리드 준수 (8px Grid)

> 모든 간격, 패딩, 마진은 4의 배수(4, 8, 16, 24, 32, 48, 64)만 사용한다. `AppSpacing` 상수를 사용하면 자동으로 준수된다. 12, 20, 36 등 비표준 값 금지.

---

## 6. 검증 방법

각 Phase 완료 후 다음 명령으로 진행 상황을 정량 확인:

```bash
# AppleColors 잔존 확인
grep -rn "AppleColors\|AppleTypography" lib/screens/ | wc -l

# 인라인 fontSize 잔존 확인
grep -rn "fontSize:" lib/screens/ | grep -v "AppTypography" | wc -l

# 인라인 EdgeInsets 잔존 확인 (AppSpacing 미사용)
grep -rn "EdgeInsets" lib/screens/ | grep -v "AppSpacing" | wc -l

# Semantics 사용량 확인
grep -rn "Semantics\|semanticLabel\|tooltip:" lib/screens/ lib/widgets/ | wc -l

# 반응형 적용 확인
grep -rn "ResponsiveHelper\|ConstrainedBox" lib/screens/ | wc -l

# borderRadius 비표준 값 확인
grep -rn "borderRadius\|BorderRadius" lib/screens/ | grep -v "AppRadius" | wc -l
```

---

## 7. 참고: 감사 문서 목록

| 문서 | 경로 | 역할 |
|------|------|------|
| UI-SPEC.md | `docs/UI-SPEC.md` | 디자인 시스템 전체 스펙 (10개 섹션) |
| UI-REVIEW.md | `docs/UI-REVIEW.md` | 6축 시각 감사 (정량 분석) |
| ux-analysis-seller.md | `docs/ux-analysis-seller.md` | 매도자 UX 분석 |
| ux-analysis-broker.md | `docs/ux-analysis-broker.md` | 중개사 UX 분석 |
| ux-analysis-buyer.md | `docs/ux-analysis-buyer.md` | 구매자 UX 분석 |
| ux-analysis-admin.md | `docs/ux-analysis-admin.md` | 관리자 UX 분석 |
| structural-issues.md | `docs/structural-issues.md` | 구조적 이슈 |
