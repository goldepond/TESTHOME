# MyHome UI 코드 감사 보고서

**감사일:** 2026-04-12
**감사 기준:** 코드 기반 분석 (디자인 시스템 정의 vs 실제 사용 비교)
**스크린샷:** 미캡처 (개발 서버 미실행, 코드 전용 감사)
**감사 범위:** lib/screens/ (41개 파일), lib/widgets/ (47개 파일), lib/constants/ (디자인 토큰)

---

## 6축 종합 점수

| 축 | 점수 | 핵심 발견 |
|---|------|----------|
| 1. 일관성 (Consistency) | 5/10 | 3개 색상 시스템 혼용, 인라인 스타일이 디자인 토큰보다 3배 많음 |
| 2. 접근성 (Accessibility) | 3/10 | Semantics 사용 거의 없음 (11건), Tooltip 4건, 아이콘 버튼 라벨 부족 |
| 3. 반응성 (Responsiveness) | 6/10 | ResponsiveHelper 활용 존재하나 17개 화면만 적용, 23개 화면 미적용 |
| 4. 시각적 계층 (Visual Hierarchy) | 6/10 | AppTypography 정의 우수, 그러나 화면별 인라인 fontSize 337건으로 계층 불일치 |
| 5. 인터랙션 (Interaction) | 7/10 | 로딩/에러/빈 상태 위젯 존재, 대부분 화면에서 처리됨 |
| 6. 브랜드 정체성 (Brand Identity) | 7/10 | 코랄(#E07A5F) 일관 사용, AirbnbColors 주력 전환 진행 중 |

**종합: 34/60**

---

## 축 1: 일관성 (Consistency) - 5/10

### 색상 시스템 3중 혼용

프로젝트에 3개의 색상 클래스가 공존하며, 동일 화면에서도 혼용됩니다.

| 색상 클래스 | screens/ 사용량 | widgets/ 사용량 | 상태 |
|------------|----------------|----------------|------|
| `AirbnbColors` | 1,564건 (39파일) | 315건 (28파일) | 주력 (권장) |
| `AppleColors`/`AppleTypography` | 497건 (9파일) | - | 혼용 중 |
| `AppColors` | 0건 | 0건 | screens에서 제거됨 |
| `Colors.` / `Color(0x...)` 직접 | 2,055건 (40파일) | - | 하드코딩 |

**문제 파일 (AppleColors + AirbnbColors 동시 사용):**
- `main_page.dart`: AirbnbColors(8건) + AppleColors/AppleTypography(6건) - 배지에 AppleColors.systemRed, 스낵바에 AppleTypography 사용
- `mls_seller_dashboard_page.dart`: AirbnbColors(42건) + AppleColors(34건)
- `mls_quick_registration_page.dart`: AirbnbColors(136건) + AppleColors(96건)
- `market_price_page.dart`: AirbnbColors(8건) + AppleColors(135건) - AppleColors가 주력
- `mls_property_detail_page.dart`: AirbnbColors(128건) + AppleColors(153건)

### 타이포그래피 이중화

- `AppTypography` 사용: **224건** (24파일)
- 인라인 `TextStyle(fontSize: ...)`: **337건** (36파일)

인라인 스타일이 디자인 토큰 사용량의 1.5배입니다. AppTypography에 정의된 스케일(12/14/16/18/20/24/28/32)과 다른 사이즈도 다수 발견됩니다:
- `fontSize: 13` - 11, 15, 22 등 비표준 사이즈 다수
- `fontSize: 11` (my_favorites_page.dart:336)
- `fontSize: 15` (broker_inquiry_response_page.dart:183)
- `fontSize: 22` (forgot_password_page.dart:125, submit_success_page.dart:131)

### 간격 이중화

- `AppSpacing` 사용: **105건** (16파일)
- 인라인 `EdgeInsets` (AppSpacing 미사용): **524건** (40파일)

AppSpacing 사용률이 약 17%에 불과합니다. 대부분의 화면에서 하드코딩된 간격값을 사용합니다.

### CommonDesignSystem 저활용

`CommonDesignSystem` 사용: **13건** (4파일) - 41개 화면 중 4개만 활용

표준 카드 데코레이션, 입력 필드, 버튼 스타일이 정의되어 있으나 대부분 화면에서 직접 스타일링합니다.

### borderRadius 불일치

발견된 borderRadius 값: 4, 6, 8, 10, 12, 16, 20, 24, 26, 100
- CommonDesignSystem 표준: 16 (대형 카드), 12 (소형 카드/입력)
- 실제: 10종 이상의 서로 다른 값 사용

---

## 축 2: 접근성 (Accessibility) - 3/10

### Semantics/접근성 라벨 부재

| 접근성 요소 | 사용 건수 | 위치 |
|-----------|---------|------|
| `Semantics()` | 9건 | common_design_system.dart(9) - AccessibleWidget 내부만 |
| `semanticLabel` | 1건 | login_page.dart |
| `Tooltip()` | 4건 | common_design_system.dart(1), main_page.dart(1) 등 |

`AccessibleWidget` 유틸리티가 정의되어 있으나 (`common_design_system.dart`), **실제 화면에서 거의 사용되지 않습니다.**

### 아이콘 버튼 접근성

`main_page.dart`의 `_buildHeaderActionButton`에서 Tooltip은 제공하나 Semantics는 없습니다. 대부분의 `IconButton` 사용처에서 tooltip 또는 semanticLabel이 누락되어 있습니다.

### 터치 타겟 크기

- `main_page.dart:414` 헤더 액션 버튼: `height: 40, width: 40` - Apple HIG 최소 기준(44pt)에 미달
- 대부분의 주요 버튼은 `minimumSize: Size(0, 52)` (CommonDesignSystem)로 적절
- 일부 버튼은 `height: 40` 사용 (mls_property_detail_page.dart:1660)

### 색상 대비

- `AirbnbColors.textSecondary` (#8B7F74) on white (#FFFFFF): 약 3.4:1 - **WCAG AA 실패** (4.5:1 필요)
- `AirbnbColors.textLight` (#A69E96) on white: 약 2.5:1 - **WCAG AA 실패**
- `AirbnbColors.textPrimary` (#2D2A26) on white: 약 14:1 - 통과
- `AppColors.kTextSecondary` (#4B5563) on white: 약 7:1 - 통과

---

## 축 3: 반응성 (Responsiveness) - 6/10

### ResponsiveHelper 적용 현황

`ResponsiveHelper` 또는 `ConstrainedBox`/`getMaxWidth` 사용: **25건** (17파일)

**적용된 주요 화면:**
- main_page.dart, broker_settings_page.dart, broker_signup_page.dart
- mls_broker_dashboard_page.dart, mls_property_registration_page.dart
- mls_quick_registration_page.dart, public_listings_page.dart 등

**미적용 화면 (23개):**
- admin 전체 (admin_dashboard, admin_broker_management 등 8개)
- auth_landing_page.dart, login_page.dart, signup_page.dart
- forgot_password_page.dart, change_password_page.dart
- notification_page.dart, my_inquiries_page.dart 등

### 브레이크포인트 체계

`ResponsiveBreakpoints`가 잘 정의되어 있으나 (600/900/1200), 일부 화면에서 하드코딩된 브레이크포인트를 사용합니다:
- `ResponsiveHelper.isWeb(context)` - 800px 기준으로 `ResponsiveBreakpoints`와 불일치

---

## 축 4: 시각적 계층 (Visual Hierarchy) - 6/10

### 타이포그래피 계층 정의 (양호)

AppTypography 스케일:
| 토큰 | 크기 | 무게 | 용도 |
|------|------|------|------|
| display | 32px | bold | 대제목 |
| h1 | 28px | bold | 제목 |
| h2 | 24px | bold | 소제목 |
| h3 | 20px | bold | 섹션 제목 |
| h4 | 18px | w600 | 카드 제목 |
| bodyLarge | 18px | normal | 큰 본문 |
| body | 16px | normal | 본문 |
| bodySmall | 14px | normal | 작은 본문 |
| caption | 12px | normal | 캡션 |
| button | 16px | w600 | 버튼 |

**문제점:** 인라인에서 비표준 크기(11, 13, 15, 22) 사용으로 계층 흐려짐

### fontSize 분포 (인라인 337건 분석)

고빈도 사용:
- `fontSize: 14` - 가장 많음 (bodySmall 대체 가능)
- `fontSize: 16` - 두 번째 (body 대체 가능)
- `fontSize: 12` - 세 번째 (caption 대체 가능)
- `fontSize: 13` - 네 번째 (**비표준, AppTypography에 없음**)
- `fontSize: 18` - 다섯 번째 (h4/bodyLarge 대체 가능)

### 헤더/AppBar 일관성

`CommonDesignSystem.standardAppBar()` 정의 존재하나 사용은 4파일뿐. 대부분 직접 AppBar 구성.

---

## 축 5: 인터랙션 (Interaction) - 7/10

### 로딩 상태 처리 (양호)

- `isLoading`/`_isLoading`/`CircularProgressIndicator`: **203건** (31파일)
- `LoadingOverlay` 공통 위젯 존재 및 사용
- 대부분 화면에서 로딩 인디케이터 표시

### 에러 상태 처리 (양호)

- `catch`/에러/오류/실패 처리: **223건** (33파일)
- `RetryView` 공통 위젯 존재
- SnackBar를 통한 에러 피드백: **314건** (27파일)

### 빈 상태 처리 (양호)

- 빈 상태 관련 텍스트: **104건** (48파일)
- `EmptyState` 공통 위젯 존재
- 대부분 리스트 화면에서 빈 상태 처리

### 대화형 피드백

- `showDialog`/`showModalBottomSheet`/`showSnackBar`: **213건** (27파일)
- 파괴적 액션에 대한 확인 다이얼로그: `AccessibleWidget.showConfirmDialog` 존재

### 부족한 점

- 일부 SnackBar 스타일 불일치: AppleColors.systemRed, AppleColors.systemOrange 등 혼용
- 폼 제출 시 중복 클릭 방지가 일부 화면에서 누락될 가능성

---

## 축 6: 브랜드 정체성 (Brand Identity) - 7/10

### 브랜드 컬러 일관성 (양호)

- 코랄 #E07A5F가 `AirbnbColors.primary`, `AppColors.kPrimary`, `AppleColors.systemBlue` 모두에서 통일
- 주요 CTA 버튼, 로딩 인디케이터, 포커스 보더에 일관 적용
- 그라데이션 `AppGradients.primaryDiagonal` 정의됨

### 따뜻한 뉴트럴 톤 (양호)

- 배경: 따뜻한 크림 (#FAF8F5 surface, #FFFFFF background)
- 텍스트: 따뜻한 다크 (#2D2A26 primary, #8B7F74 secondary)
- 보더: 따뜻한 회색 (#E8E5E1)

### 부족한 점

- `Colors.white`, `Colors.transparent`, `Colors.black` 등 Flutter 기본 색상 직접 사용이 많음
- 일부 화면에서 AppleColors 시스템(쿨톤 회색 #F2F2F7)과 AirbnbColors(웜톤 크림 #FAF8F5) 혼용으로 톤앤매너 불일치 가능성
- 다크 모드 미지원

---

## 우선순위별 개선 권장사항

### [P0] 긴급 - 접근성

1. **Semantics 추가 필수**
   - 모든 `IconButton`에 `tooltip` 또는 `semanticLabel` 추가
   - `AccessibleWidget.iconButton()` 사용 확대 또는 린트 규칙 추가
   - 영향 화면: 전체 (특히 main_page.dart, broker_dashboard 등 헤더 영역)

2. **색상 대비 개선**
   - `AirbnbColors.textSecondary` (#8B7F74 -> #6B6560 정도로 진하게) - WCAG AA 4.5:1 충족
   - `AirbnbColors.textLight` (#A69E96 -> #837B73 정도로 진하게)
   - 파일: `lib/constants/app_constants.dart:71-72`

3. **터치 타겟 최소 44pt 보장**
   - `main_page.dart:414` 헤더 버튼 `height/width: 40` -> `44`
   - `mls_property_detail_page.dart:1660` `height: 40` -> `44`

### [P1] 높음 - 일관성

4. **AppleColors/AppleTypography 제거 통합**
   - 9개 파일에서 AppleColors -> AirbnbColors 마이그레이션
   - 주요 대상: market_price_page.dart(135건), mls_property_detail_page.dart(153건)
   - `AppleColors.systemRed` -> `AirbnbColors.red`
   - `AppleColors.systemOrange` -> `AirbnbColors.orange`
   - `AppleTypography.body` -> `AppTypography.body`

5. **인라인 TextStyle을 AppTypography로 통합**
   - 337건의 인라인 fontSize를 AppTypography 토큰으로 교체
   - 비표준 크기 정리: `fontSize: 13` -> `AppTypography.bodySmall(14)` 또는 `AppTypography.caption(12)`
   - `fontSize: 22` -> `AppTypography.h2(24)` 또는 새 토큰 추가
   - `fontSize: 15` -> `AppTypography.bodySmall(14)` 또는 `AppTypography.body(16)`

6. **인라인 EdgeInsets를 AppSpacing으로 통합**
   - 524건 중 반복 패턴 먼저 교체 (예: `EdgeInsets.all(16)` -> `EdgeInsets.all(AppSpacing.md)`)
   - `EdgeInsets.symmetric(horizontal: 24, vertical: 14)` 같은 패턴은 AppSpacing 조합으로

7. **borderRadius 표준화**
   - 표준 스케일 정의: `sm: 8`, `md: 12`, `lg: 16`, `xl: 24`, `pill: 100`
   - AppSpacing에 `borderRadiusSm/Md/Lg` 상수 추가
   - 10종+ 값을 5종으로 통합

### [P2] 중간 - 반응성/구조

8. **미적용 화면에 반응형 레이아웃 추가**
   - admin 화면 8개: `Center` + `ConstrainedBox` + `ResponsiveHelper.getMaxWidth()` 래핑
   - auth 관련 화면 (login, signup, forgot_password 등)
   - `ResponsiveHelper.isWeb()` (800px) -> `ResponsiveHelper.isTablet()` (600px) 이상으로 통일

9. **CommonDesignSystem 활용 확대**
   - `standardAppBar()` 사용 4파일 -> 전체 화면 적용
   - `cardDecoration()` 사용 확대
   - `inputDecoration()` 사용 확대

10. **SnackBar 스타일 표준화**
    - 공통 SnackBar 유틸 메서드 생성 (성공/경고/에러 3종)
    - AppleColors 사용 중인 SnackBar를 AirbnbColors로 통일

### [P3] 낮음 - 장기 개선

11. **다크 모드 지원 준비**
    - AirbnbColors에 다크 모드 변형 추가
    - ThemeData 기반으로 전환 가능한 구조로 리팩토링

12. **AppTypography 비표준 크기 토큰 추가 검토**
    - `fontSize: 13`이 빈번하면 `bodyXSmall` 토큰 추가 고려
    - `fontSize: 22`이 필요하면 `h2Small` 또는 `subtitle` 토큰 추가 고려

---

## 감사 대상 파일 목록

### 디자인 시스템 (상세 분석)
- `lib/constants/app_constants.dart` - AppColors, AirbnbColors, API 상수
- `lib/constants/typography.dart` - AppTypography
- `lib/constants/spacing.dart` - AppSpacing
- `lib/constants/responsive_constants.dart` - ResponsiveHelper
- `lib/constants/apple_design_system.dart` - AppleColors, AppleTypography
- `lib/widgets/common_design_system.dart` - CommonDesignSystem, AccessibleWidget

### 공통 위젯 (상세 분석)
- `lib/widgets/empty_state.dart`
- `lib/widgets/retry_view.dart`
- `lib/widgets/loading_overlay.dart`

### 화면 (코드 패턴 분석)
- `lib/screens/main_page.dart` - 메인 네비게이션
- `lib/screens/auth/auth_landing_page.dart` - 인증 랜딩
- `lib/screens/seller/mls_seller_dashboard_page.dart` - 매도인 대시보드
- `lib/screens/broker/mls_broker_dashboard_page.dart` - 중개사 대시보드
- `lib/screens/public/public_listings_page.dart` - 공개 매물 목록
- 외 36개 화면 파일 (grep 기반 패턴 분석)

---

## 정량 요약

| 지표 | 수치 | 판정 |
|------|------|------|
| 색상 시스템 수 | 3개 공존 | 1개로 통합 필요 |
| AirbnbColors 사용률 (screens) | 1,564건 / 39파일 | 주력 (양호) |
| AppleColors 잔존 | 497건 / 9파일 | 제거 필요 |
| 하드코딩 색상 | 2,055건 / 40파일 | 점진적 교체 |
| AppTypography 사용률 | 224건 vs 인라인 337건 | 40% (저조) |
| AppSpacing 사용률 | 105건 vs 인라인 524건 | 17% (매우 저조) |
| CommonDesignSystem 활용 | 13건 / 4파일 | 3% (거의 미사용) |
| 반응형 적용 화면 | 17 / 40 화면 | 42% |
| Semantics 사용 | 11건 / 3파일 | 심각하게 부족 |
| 로딩 상태 처리 | 203건 / 31파일 | 양호 |
| 에러 처리 | 223건 / 33파일 | 양호 |
| 빈 상태 처리 | 104건 / 48파일 | 양호 |
