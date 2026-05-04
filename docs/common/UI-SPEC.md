# MyHome UI 디자인 스펙

> 2026-04-12 기준 코드베이스 분석 기반
>
> 이 문서는 MyHome 앱의 전체 UI 디자인 계약(design contract)이다.
> 현재 구현된 디자인 시스템의 정리, 역할별 화면 패턴, 문제점, 개선 방향을 포함한다.

---

## 1. 디자인 시스템 현황

### 1.1 색상 체계

세 개의 색상 클래스가 공존한다. **`AirbnbColors`가 주력이다.**

| 클래스 | 파일 | 용도 | 상태 |
|--------|------|------|------|
| `AirbnbColors` | `app_constants.dart` | 주력. 상태/카테고리 시맨틱 색상, 그림자 프리셋 | 활성 |
| `AppleColors` | `apple_design_system.dart` | Apple HIG 표준 색상 | 활성 (보조) |
| `AppColors` | `app_constants.dart` | 레거시 호환 | 폐기 예정 |

#### 브랜드 색상 (코랄/테라코타)

| 토큰 | 값 | 용도 |
|------|------|------|
| `AirbnbColors.primary` | `#E07A5F` | 주요 CTA, 브랜드 액센트 |
| `AirbnbColors.primaryHover` | `#D4715A` | 호버/프레스 상태 |
| `AirbnbColors.primaryLight` | `#F4A593` | 배경 틴트, 뱃지 배경 |
| `AirbnbColors.primaryDark` | `#C9654D` | 그라데이션 끝점 |

#### 60/30/10 색상 분배

| 비율 | 역할 | 토큰 | 값 |
|:----:|------|------|------|
| 60% | 배경/서피스 | `AirbnbColors.surface` | `#FAF8F5` (따뜻한 크림) |
| 30% | 카드/컨테이너 | `AirbnbColors.background` | `#FFFFFF` (흰색) |
| 10% | 액센트 | `AirbnbColors.primary` | `#E07A5F` (코랄) |

**액센트 색상 사용처 (10% 이내로 제한):**
- 주요 CTA 버튼 배경
- 선택/활성 탭 인디케이터
- 진행률 바, 체크마크
- 가격 강조 텍스트
- EmptyState 아이콘 배경 틴트

#### 텍스트 색상

| 토큰 | 값 | 용도 |
|------|------|------|
| `AirbnbColors.textPrimary` | `#2D2A26` | 제목, 본문 주요 텍스트 |
| `AirbnbColors.textSecondary` | `#8B7F74` | 보조 설명, 라벨 |
| `AirbnbColors.textLight` | `#A69E96` | 플레이스홀더, 비활성 텍스트 |
| `AirbnbColors.textWhite` | `#FFFFFF` | primary 배경 위 텍스트 |

#### 상태 색상

| 상태 | 토큰 | 값 | 용도 |
|------|------|------|------|
| 성공 | `AirbnbColors.success` | `#10B981` | 완료, 활성, 승인 |
| 경고 | `AirbnbColors.warning` | `#F59E0B` | 대기중, 주의 |
| 에러 | `AirbnbColors.error` | `#EF4444` | 실패, 취소, 삭제 |
| 정보 | `AirbnbColors.info` | `#3B82F6` | 진행중, 링크 |

#### 테두리/구분선

| 토큰 | 값 | 용도 |
|------|------|------|
| `AirbnbColors.border` | `#E8E5E1` | 카드 테두리, 입력 필드 |
| `AirbnbColors.borderLight` | `#F0EDE8` | 연한 구분선 |

#### 문제점: 색상 체계 이중화

`AirbnbColors`와 `AppleColors`가 동일한 역할의 색상을 각각 정의한다.
예를 들어 `AppleColors.systemBlue`가 `#E07A5F`(코랄)로 재정의되어 있어
의미와 이름이 일치하지 않는다.

**권장:** 신규 코드에서는 `AirbnbColors`만 사용한다. `AppleColors`는
`apple_design_system.dart`의 위젯(`AppleButton`, `AppleCard`)에서만 내부적으로 사용한다.
`AppColors`는 점진적으로 `AirbnbColors`로 마이그레이션한다.

---

### 1.2 타이포그래피

**폰트:** Noto Sans KR (Google Fonts)
**가중치:** 400(regular), 600(semibold), 700(bold)

#### AppTypography 스케일 (주력)

| 토큰 | 크기 | 가중치 | 행간 | 자간 | 용도 |
|------|:----:|:------:|:----:|:----:|------|
| `display` | 32px | 700 | 1.2 | -0.5 | 랜딩 히어로 제목 |
| `h1` | 28px | 700 | 1.3 | -0.3 | 페이지 제목 |
| `h2` | 24px | 700 | 1.3 | -0.2 | 섹션 제목 |
| `h3` | 20px | 700 | 1.4 | 0 | AppBar 제목, 카드 제목 |
| `h4` | 18px | 600 | 1.4 | 0 | 서브 섹션 제목 |
| `bodyLarge` | 18px | 400 | 1.5 | 0 | 강조 본문 |
| `body` | 16px | 400 | 1.5 | 0 | 기본 본문 |
| `bodySmall` | 14px | 400 | 1.5 | 0 | 보조 본문, 리스트 아이템 |
| `caption` | 12px | 400 | 1.4 | 0 | 메타 정보, 타임스탬프 |
| `button` | 16px | 600 | 1.2 | 0 | 버튼 라벨 |
| `buttonSmall` | 14px | 600 | 1.2 | 0 | 소형 버튼 라벨 |

**색상 적용 패턴:**
```dart
AppTypography.withColor(AppTypography.body, AirbnbColors.textPrimary)
```

#### AppleTypography 스케일 (보조)

Apple HIG 준수가 필요한 위젯에서만 사용한다. 주요 차이점:

| 토큰 | 크기 | 가중치 | 비고 |
|------|:----:|:------:|------|
| `largeTitle` | 34px | 700 | iOS 네비게이션 대형 타이틀 |
| `headline` | 17px | 600 | iOS 리스트 헤드라인 |
| `body` | 17px | 400 | iOS 표준 본문 (16px 아닌 17px) |
| `footnote` | 13px | 400 | iOS 각주 |

#### 문제점: 이중 타이포 시스템

`AppTypography`와 `AppleTypography`가 비슷하지만 미묘하게 다른 스케일을 정의한다.
`body`가 16px(App) vs 17px(Apple)로 다르다.

**권장:** `AppTypography`를 표준으로 사용한다. `AppleTypography`는
`AppleButton`, `AppleCard` 위젯 내부에서만 사용한다.

---

### 1.3 간격 체계

**기본 단위:** 8px 그리드

#### AppSpacing (주력)

| 토큰 | 값 | 용도 |
|------|:----:|------|
| `xs` | 4px | 인라인 아이콘-텍스트 간격, 뱃지 내부 |
| `sm` | 8px | 칩 내부, 리스트 아이템 간격 |
| `md` | 16px | 카드 패딩, 입력 필드 패딩, 화면 기본 마진 |
| `lg` | 24px | 섹션 간격, 버튼 수평 패딩 |
| `xl` | 32px | 대형 섹션 간격 |
| `xxl` | 48px | 페이지 최상단/최하단 여백 |
| `xxxl` | 64px | 히어로 섹션 간격 |

#### 시맨틱 간격 토큰

| 토큰 | 값 | 용도 |
|------|:----:|------|
| `screenPadding` | 16px | 화면 좌우 기본 패딩 |
| `cardPadding` | 16px | 카드 내부 패딩 |
| `cardPaddingLarge` | 24px | 대형 카드 내부 패딩 |
| `sectionSpacing` | 24px | 섹션 간 수직 간격 |
| `buttonPadding` | 16px | 버튼 내부 패딩 |
| `inputPadding` | 16px | 입력 필드 내부 패딩 |

#### AppleSpacing (보조)

Apple 위젯 전용. 12px, 20px 등 8px 그리드에서 벗어나는 값이 있다.

| 토큰 | 값 |
|------|:----:|
| `sm` | 12px |
| `lg` | 20px |
| `section` | 40px |

**권장:** 새 코드에서는 `AppSpacing`만 사용한다. 8px 그리드(4의 배수)를 준수한다.

---

### 1.4 반응형 레이아웃

#### 브레이크포인트

| 구간 | 너비 | 열 수 | 최대 콘텐츠 너비 | 좌우 패딩 |
|------|:----:|:----:|:----:|:----:|
| 모바일 | < 600px | 1 | 100% | 12px |
| 태블릿 | 600 ~ 899px | 2 | 900px | 16px |
| 데스크톱 | 900 ~ 1199px | 2 | 1400px | 32px |
| 대형 데스크톱 | >= 1200px | 3 | 1600px | 48px |

#### 레이아웃 패턴

모든 웹 화면은 다음 패턴을 따른다:
```dart
Center(
  child: ConstrainedBox(
    constraints: BoxConstraints(
      maxWidth: ResponsiveHelper.getMaxWidth(context),
    ),
    child: content,
  ),
)
```

#### 문제점: 반응형 헬퍼 이중화

`ResponsiveHelper`와 `AppleResponsive`가 비슷한 기능을 각각 제공한다.
`AppleResponsive.getMaxContentWidth()`는 최대 1200px인데
`ResponsiveHelper.getMaxWidth()`는 최대 1600px으로 불일치한다.

**권장:** `ResponsiveHelper`를 표준으로 사용한다.

---

### 1.5 그림자 체계

#### AirbnbColors 그림자

| 토큰 | blur | offset | alpha | 용도 |
|------|:----:|:------:|:-----:|------|
| `cardShadowSubtle` | 8px | (0, 1) | 0.04 | 작은 요소 |
| `cardShadow` | 20px | (0, 2) | 0.06 | 일반 카드 |
| `cardShadowHover` | 24px | (0, 4) | 0.12 | 호버 상태 카드 |
| `cardShadowLarge` | 32px | (0, 4) | 0.08 | 히어로 카드 |

#### AppleShadows (보조)

| 토큰 | blur | offset | alpha | 용도 |
|------|:----:|:------:|:-----:|------|
| `subtle` | 8px | (0, 2) | 0.04 | 떠있는 느낌 |
| `card` | 16px | (0, 4) | 0.08 | 카드 |
| `strong` | 24px | (0, 8) | 0.12 | 모달, 팝업 |

---

### 1.6 모서리 반경

#### 사용 기준

| 요소 | 반경 | 근거 |
|------|:----:|------|
| 주요 카드 | 16px | `CommonDesignSystem.cardDecoration()` |
| 소형 카드 | 12px | `CommonDesignSystem.smallCardDecoration()` |
| 버튼 | 12px | `CommonDesignSystem.primaryButtonStyle()` |
| 필(pill) 버튼 | 100px | `pill: true` 옵션 |
| 입력 필드 | 12px | `CommonDesignSystem.inputDecoration()` |
| EmptyState 아이콘 | 원형 | `BoxShape.circle` |

---

### 1.7 버튼 체계

#### 버튼 유형

| 유형 | 클래스 메서드 | 배경 | 전경 | 높이 | 용도 |
|------|-------------|------|------|:----:|------|
| Primary | `primaryButtonStyle()` | `#E07A5F` 코랄 | 흰색 | 52px | 주요 CTA |
| Dark | `darkButtonStyle()` | `#2D2A26` 다크 | 흰색 | 52px | 강조 CTA |
| Secondary | `secondaryButtonStyle()` | `#EBE5DC` 필 | 다크 | 52px | 보조 액션 |
| Outlined | `outlinedButtonStyle()` | 투명 | 다크 | 52px | 3순위 액션 |
| Disabled | `disabledButtonStyle()` | 흰색 | `#A69E96` | 52px | 비활성 |

**버튼 텍스트:** 16px, weight 700, Noto Sans KR, letter-spacing -0.3
**수평 패딩:** 24px (AppSpacing.lg)
**수직 패딩:** 16px (AppSpacing.md)

---

## 2. 공통 UI 컴포넌트 인벤토리

### 2.1 구현 완료 컴포넌트

| 컴포넌트 | 파일 | 설명 |
|----------|------|------|
| `EmptyState` | `widgets/empty_state.dart` | 빈 상태 표시 (아이콘 + 제목 + 메시지 + CTA 버튼) |
| `RetryView` | `widgets/retry_view.dart` | 에러 재시도 (아이콘 + 메시지 + 다시 시도 버튼) |
| `LoadingOverlay` | `widgets/loading_overlay.dart` | 로딩 오버레이 + 다이얼로그 |
| `AppleButton` | `apple_design_system.dart` | Apple 스타일 버튼 (primary/secondary) |
| `AppleCard` | `apple_design_system.dart` | Apple 스타일 카드 (테두리 + 그림자) |
| `CommonDesignSystem` | `common_design_system.dart` | 카드/AppBar/버튼/입력 필드 스타일 팩토리 |
| `AccessibleWidget` | `common_design_system.dart` | 접근성 래퍼 (Semantics + Tooltip) |
| `HeroBanner` | `widgets/hero_banner.dart` | 히어로 배너 |
| `VisitRequestQuickSheet` | `widgets/visit_request_quick_sheet.dart` | 방문 요청 승인 바텀시트 |
| `PriceInputWidget` | `widgets/price_input_widget.dart` | 가격 입력 위젯 |
| `OptimizedImage` | `widgets/optimized_image.dart` | 최적화 이미지 |
| `OfflineBanner` | `widgets/offline_banner.dart` | 오프라인 상태 배너 |

### 2.2 AppBar 패턴

두 가지 AppBar 패턴이 정의되어 있다:

**일반 AppBar** (`CommonDesignSystem.standardAppBar`)
- 배경: `AirbnbColors.surface` (95% 불투명도, 반투명 효과)
- 높이: 64px
- 제목: `AppTypography.h3`, 좌측 정렬
- 하단 테두리: `AirbnbColors.border`, 0.5px
- 엘리베이션: 0 (그림자 없음)

**탭 AppBar** (`CommonDesignSystem.tabAppBar`)
- 일반 AppBar와 동일 + TabBar 하단 추가

### 2.3 카드 패턴

| 유형 | 배경 | 테두리 | 반경 | 그림자 |
|------|------|--------|:----:|--------|
| 기본 카드 | `#FFFFFF` | `#E8E5E1` 1px | 16px | blur 12, alpha 0.04 |
| 소형 카드 | `#FFFFFF` | `#E8E5E1` 1px | 12px | blur 6, alpha 0.03 |
| 다크 히어로 | `#1A1512` 그라데이션 | 없음 | 16px | 없음 |

### 2.4 입력 필드 패턴

- 배경: `AirbnbColors.surface` (`#FAF8F5`)
- 테두리: `AirbnbColors.border` (`#E8E5E1`), 반경 12px
- 포커스 테두리: `AirbnbColors.primary` (`#E07A5F`), 2px
- 내부 패딩: 16px 수평/수직

### 2.5 다이얼로그 패턴

`AccessibleWidget.showConfirmDialog()`:
- 일반 확인: 기본 ElevatedButton
- 위험한 액션: `AirbnbColors.warning` 배경 ElevatedButton
- 취소: TextButton

---

## 3. 역할별 화면 구조

### 3.1 매도자 (Seller)

**진입점:** `MainPage` (4개 탭)

| 탭 | 화면 | 주요 UI 패턴 |
|:--:|------|-------------|
| 0 | 매물 등록 (3단계) | 스텝 인디케이터 + 폼 |
| 1 | 내 매물 대시보드 | 상태 필터 칩 + 매물 카드 리스트 + 빠른 방문 승인 |
| 2 | 시세 조회 | 검색 + 실거래가 차트 + 내 매물 비교 |
| 3 | 탐색 | 공개 매물 그리드 |

**핵심 흐름:** 등록 -> 대기 -> 방문 요청 수신 -> 승인/거절 -> 연락처 교환

### 3.2 중개사 (Broker)

**진입점:** `MLSBrokerDashboardPage` (5개 탭)

| 탭 | 화면 | 주요 UI 패턴 |
|:--:|------|-------------|
| 0 | 매물 탐색 | 지역/가격/유형 필터 + 리스트/지도 토글 + 매물 카드 |
| 1 | 관심 매물 | 제안 완료 매물 리스트 (상태별 필터) |
| 2 | 경쟁 현황 | 참여 중개사 수 표시 |
| 3 | 성과 | 거래 실적 + 프로필 |
| 4 | 구매 리드 | 문의 리스트 + 상태 전환 |

**핵심 흐름:** 매물 발견 -> 제안 -> 승인 대기 -> 방문 -> 거래

### 3.3 구매자/공개 사용자 (Buyer/Public)

**진입점 (비로그인):** `AuthLandingPage` -> `PublicListingsPage`
**진입점 (로그인):** `MainPage` 탭 3 (탐색)

| 화면 | 주요 UI 패턴 |
|------|-------------|
| 공개 매물 목록 | 필터 칩 + 반응형 그리드 |
| 매물 상세 | 이미지 갤러리 + 정보 카드 + 문의 버튼 |
| 내 문의 | 문의 카드 리스트 + 상태 표시 |

**핵심 흐름:** 탐색 -> 상세 보기 -> 문의 -> 중개사 배정 대기

### 3.4 관리자 (Admin)

**진입점:** `AdminDashboard` (별도 바이너리, 8개 탭)

| 탭 | 화면 | 주요 UI 패턴 |
|:--:|------|-------------|
| 0 | 홈 | 환영 메시지 + 기능 카드 |
| 1 | 견적문의 | 문의 리스트 관리 |
| 2 | 중개사 관리 | 인증 처리 리스트 |
| 3 | 중개사 성과 | 통계 대시보드 |
| 4 | 매물 관리 | 매물 리스트 관리 |
| 5 | 매물 검증 | 등기 확인 + 승인 |
| 6 | 활동 로그 | 로그 리스트 |
| 7 | 매칭 관리 | 구매자-중개사 매칭 |

---

## 4. 카피라이팅 계약

### 4.1 주요 CTA 라벨

| 화면 | CTA | 현재 라벨 |
|------|-----|----------|
| 매물 등록 | 제출 | "매물 등록하기" |
| 매물 탐색 | 문의 | "문의하기" |
| 중개사 제안 | 제안 | "중개 제안하기" |
| 방문 요청 | 승인 | "승인" |
| 방문 요청 | 거절 | "거절" |

### 4.2 빈 상태 메시지

`EmptyState` 위젯이 표준 패턴을 제공한다. 역할별 빈 상태:

| 화면 | 아이콘 | 제목 | 메시지 | CTA |
|------|--------|------|--------|-----|
| 매도자 대시보드 (매물 없음) | `Icons.home_outlined` | "등록된 매물이 없습니다" | "매물을 등록하면 지역 중개사에게 자동으로 배포됩니다" | "매물 등록하기" |
| 중개사 탐색 (결과 없음) | `Icons.search_off` | "조건에 맞는 매물이 없습니다" | "필터를 조정하거나 다른 지역을 확인해보세요" | "필터 초기화" |
| 구매자 문의 (문의 없음) | `Icons.chat_bubble_outline` | "아직 문의가 없습니다" | "관심 있는 매물에 문의하면 중개사가 배정됩니다" | "매물 둘러보기" |
| 중개사 성과 (실적 없음) | `Icons.trending_up` | "아직 거래 실적이 없습니다" | "매물에 제안하고 거래를 성사시켜보세요" | "매물 탐색하기" |
| 지도 뷰 (매물 없음) | - | - | "이 지역에 매물이 없습니다" | - |

### 4.3 에러 상태 메시지

`RetryView` 위젯이 표준 패턴을 제공한다.

| 상황 | 메시지 | CTA |
|------|--------|-----|
| 네트워크 에러 | "데이터를 불러올 수 없습니다. 네트워크 연결을 확인해주세요." | "다시 시도" |
| 매물 로딩 실패 | "매물을 불러올 수 없습니다." | "다시 시도" |
| 삭제된 매물 참조 | "삭제된 매물입니다." | 없음 |
| 문의 저장 실패 | "문의를 보내지 못했습니다. 다시 시도해주세요." | "다시 시도" |

### 4.4 위험한 액션

| 액션 | 확인 제목 | 확인 메시지 | 확인 버튼 | 스타일 |
|------|----------|-----------|----------|--------|
| 매물 삭제 | "매물 삭제" | "이 매물을 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다." | "삭제" | `isDangerous: true` (warning 배경) |
| 방문 거절 | "방문 요청 거절" | "이 방문 요청을 거절하시겠습니까?" | "거절" | `isDangerous: true` |
| 계정 탈퇴 | "계정 탈퇴" | "모든 데이터가 삭제됩니다. 정말 탈퇴하시겠습니까?" | "탈퇴" | `isDangerous: true` |

---

## 5. 매물 상태별 색상 매핑

### 5.1 MLS 매물 상태

| 상태 | 한글 라벨 | 색상 토큰 | 값 |
|------|----------|----------|------|
| `draft` | 임시저장 | `AirbnbColors.textLight` | `#A69E96` |
| `pending` | 검토중 | `AirbnbColors.statusPending` (=warning) | `#F59E0B` |
| `active` | 배포중 | `AirbnbColors.statusCompleted` (=green) | `#10B981` |
| `inquiry` | 문의중 | `AirbnbColors.statusProgress` (=blue) | `#3B82F6` |
| `underOffer` | 협상중 | `AirbnbColors.purple` | `#8B5CF6` |
| `depositTaken` | 계약금 수령 | `AirbnbColors.teal` | `#00A699` |
| `sold` | 거래완료 | `AirbnbColors.textSecondary` | `#8B7F74` |
| `rejected` | 반려됨 | `AirbnbColors.statusCancelled` (=red) | `#EF4444` |
| `cancelled` | 취소됨 | `AirbnbColors.statusCancelled` (=red) | `#EF4444` |

### 5.2 거래 유형별 색상

| 유형 | 색상 토큰 | 값 |
|------|----------|------|
| 매매 | `AirbnbColors.categorySale` (=primary) | `#E07A5F` |
| 전세/월세 | `AirbnbColors.categoryRent` (=teal) | `#00A699` |

---

## 6. 아이콘 체계

**아이콘 라이브러리:** Flutter Material Icons (`Icons.*`)

커스텀 아이콘 패키지 없음. 전체 프로젝트에서 Material Icons만 사용한다.

### 주요 아이콘 매핑

| 용도 | 아이콘 | 크기 |
|------|--------|:----:|
| 매물 등록 | `Icons.add_home` | 24px |
| 탐색 | `Icons.search` | 24px |
| 문의 | `Icons.chat_bubble_outline` | 24px |
| 시세 | `Icons.trending_up` | 24px |
| 설정 | `Icons.settings` | 24px |
| 에러 | `Icons.error_outline` | 40px |
| 빈 상태 | (역할에 따라 상이) | 64px |

---

## 7. 문제점 종합 및 개선 방향

### 7.1 디자인 시스템 구조 문제

| ID | 문제 | 영향 | 개선 방향 |
|:--:|------|------|----------|
| DS-001 | 3개 색상 클래스 공존 (`AirbnbColors`, `AppleColors`, `AppColors`) | 동일 역할의 색상이 다른 값을 가짐. 신규 개발자 혼란 | `AirbnbColors`로 통일. `AppColors` 점진적 마이그레이션 |
| DS-002 | 2개 타이포 시스템 공존 (`AppTypography`, `AppleTypography`) | body 크기 불일치 (16 vs 17px) | `AppTypography`를 표준으로. `AppleTypography`는 Apple 위젯 내부에서만 |
| DS-003 | 2개 간격 시스템 공존 (`AppSpacing`, `AppleSpacing`) | `AppleSpacing.sm`=12, `AppSpacing.sm`=8. 8px 그리드 위반 | `AppSpacing`을 표준으로. 8px 배수만 사용 |
| DS-004 | 2개 반응형 헬퍼 공존 (`ResponsiveHelper`, `AppleResponsive`) | 최대 콘텐츠 너비 불일치 (1600 vs 1200px) | `ResponsiveHelper`를 표준으로 |
| DS-005 | 인라인 스타일이 곳곳에 존재 | `EmptyState`의 `TextStyle(fontSize: 20)`이 `AppTypography.h3`를 사용하지 않음 | 공통 위젯 내에서도 `AppTypography` 토큰 참조 |

### 7.2 역할별 UX 문제 (우선순위순)

#### 매도자 (Seller)

| 우선순위 | ID | 문제 | 난이도 |
|:--------:|:--:|------|:------:|
| 1 | S-007 | 관심자 수/조회수 미표시 -- 리텐션 핵심 지표 없음 | 중 |
| 2 | S-002 | 전화번호 포맷 검증 없음 -- 잘못된 번호 저장 가능 | 하 |
| 3 | S-003 | 이미지 업로드 진행률 미표시 -- 변수 선언만 되어 있음 | 하 |
| 4 | S-008 | 매물 로딩 실패 시 UI 피드백 없음 | 하 |
| 5 | S-010 | 방문 승인 후 다음 단계 안내 없음 | 하 |
| 6 | S-001 | 가격 입력 실시간 검증 없음 | 하 |

#### 중개사 (Broker)

| 우선순위 | ID | 문제 | 난이도 |
|:--------:|:--:|------|:------:|
| 1 | BR-007 | 리드 N+1 쿼리 문제 -- 성능/비용 | 중 |
| 2 | BR-006 | 삭제 매물 리드 유령 카드 | 하 |
| 3 | BR-009 | 제안 전화번호 정규화 누락 -- 중복 제안 가능 | 하 |
| 4 | BR-010 | 제안 제출 로딩 상태 없음 -- 중복 제출 가능 | 하 |
| 5 | BR-003 | 지역 필터 시/도 단위만 지원 | 중 |
| 6 | BR-004 | 활성 필터 표시 없음 | 하 |

#### 구매자 (Buyer)

| 우선순위 | ID | 문제 | 난이도 |
|:--------:|:--:|------|:------:|
| 1 | B-002 | 삭제 매물 문의 카드 무한 로딩 | 하 |
| 2 | B-001 | 문의 저장 확인 없음 (낙관적 업데이트 롤백 누락) | 하 |
| 3 | B-003 | 배정 중개사 연락처 미표시 | 하 |
| 4 | B-005 | 찜/관심 기능 없음 | 중 |
| 5 | B-008 | 매물 공유 기능 없음 | 하 |
| 6 | B-007 | 빈 검색 결과 CTA 없음 | 하 |

#### 관리자 (Admin)

| 우선순위 | ID | 문제 | 난이도 |
|:--------:|:--:|------|:------:|
| 1 | A-001 | 홈 탭에 KPI 없음 -- 8개 탭 돌아다녀야 파악 | 하 |
| 2 | A-002 | 탭 미처리 건수 배지 없음 | 하 |
| 3 | A-006 | 매물 검증 다이얼로그 주소 빈 줄 | 하 |
| 4 | A-008 | 500~900px 구간 레이아웃 깨짐 | 중 |

#### 구조적 문제

| 우선순위 | ID | 문제 | 난이도 |
|:--------:|:--:|------|:------:|
| 1 | STR-007 | 전화번호 저장 포맷 비일관 | 하 |
| 2 | STR-002 | 필수 FCM 알림 4종 누락 | 중 |
| 3 | STR-006 | 구매자 문의 자동 배정 실패 미처리 | 중 |
| 4 | STR-011 | 에러 핸들링 패턴 비일관 (SnackBar vs Dialog vs 무반응) | 중 |
| 5 | STR-012 | 반응형 레이아웃 적용 불균일 | 중 |

### 7.3 에러 핸들링 표준화 권장

현재 에러 표시가 SnackBar / AlertDialog / 무반응 세 가지로 제각각이다.

**권장 표준:**

| 에러 유형 | UI 패턴 | 지속 시간 |
|----------|---------|----------|
| 네트워크/로딩 실패 | `RetryView` (전체 화면 대체) | 영구 (재시도까지) |
| 폼 제출 실패 | `SnackBar` (하단) | 4초 |
| 위험한 액션 확인 | `AlertDialog` | 사용자 응답까지 |
| 인라인 검증 오류 | 입력 필드 아래 빨간 텍스트 | 영구 (수정까지) |

---

## 8. 접근성 계약

### 8.1 현재 구현

`AccessibleWidget` 클래스가 다음을 제공한다:
- `Semantics` 래핑 (label, button, enabled)
- `Tooltip` 자동 추가
- 아이콘 버튼, 텍스트 버튼, Elevated 버튼 래퍼

### 8.2 권장 추가 사항

| 항목 | 현재 | 권장 |
|------|------|------|
| 색상 대비 | 미검증 | WCAG 2.1 AA 기준 (4.5:1 본문, 3:1 대형 텍스트) |
| 터치 타겟 | 52px 버튼 | 최소 44x44px (Apple HIG) -- 현재 충족 |
| 포커스 표시 | 기본 Flutter 포커스 링 | 커스텀 포커스 링 `AirbnbColors.primary` 2px |
| 화면 리더 | `AccessibleWidget` 부분 적용 | 모든 인터랙티브 요소에 적용 확대 |

### 8.3 색상 대비 검증

| 조합 | 비율 | AA 기준 |
|------|:----:|:-------:|
| `textPrimary` (#2D2A26) on `surface` (#FAF8F5) | ~12.5:1 | 통과 |
| `textSecondary` (#8B7F74) on `surface` (#FAF8F5) | ~3.2:1 | 대형 텍스트만 통과 |
| `textLight` (#A69E96) on `surface` (#FAF8F5) | ~2.3:1 | 미통과 -- 장식용으로만 사용 |
| `textWhite` (#FFFFFF) on `primary` (#E07A5F) | ~3.1:1 | 대형 텍스트만 통과 |

**주의:** `textSecondary`를 14px 이하 텍스트에 사용하면 WCAG AA 미통과.
보조 텍스트는 최소 16px 이상에서 사용하거나 색상을 더 진하게 조정해야 한다.

---

## 9. 애니메이션/트랜지션 계약

### 9.1 현재 사용 패턴

| 요소 | 트랜지션 | 지속 시간 |
|------|---------|----------|
| 페이지 전환 | Flutter 기본 (`MaterialPageRoute`) | ~300ms |
| 바텀시트 | Flutter 기본 (`showModalBottomSheet`) | ~250ms |
| 다이얼로그 | Flutter 기본 (`showDialog`) | ~150ms fade |
| 탭 전환 | 즉시 (애니메이션 없음) | 0ms |

### 9.2 권장 추가

| 요소 | 권장 트랜지션 | 지속 시간 |
|------|-------------|----------|
| 카드 호버 | 그림자 확대 (`cardShadow` -> `cardShadowHover`) | 200ms ease |
| 필터 칩 활성화 | 배경색 전환 | 150ms ease |
| 리스트 아이템 추가 | 슬라이드인 + 페이드인 | 300ms ease-out |

---

## 10. 디자인 시스템 통합 로드맵

### Phase 1: 토큰 통일 (단기, 난이도 하)

1. `AppColors` 사용처를 `AirbnbColors`로 교체
2. `EmptyState`, `RetryView` 등 공통 위젯의 인라인 스타일을 토큰으로 교체
3. 전화번호 정규화 공통 함수 생성

### Phase 2: 컴포넌트 표준화 (중기, 난이도 중)

1. 에러 핸들링 중앙화 (`AppErrorHandler`)
2. 빈 상태 CTA 패턴 표준화
3. 로딩/제출 중 버튼 비활성화 패턴 표준화

### Phase 3: UX 개선 (중기, 난이도 중)

1. 매도자: 관심자 수 뱃지, 업로드 진행률
2. 중개사: 동 단위 필터, 리드 배치 로드
3. 구매자: 찜 기능, 매물 공유
4. 관리자: KPI 대시보드, 탭 배지

### Phase 4: 반응형 통일 (장기, 난이도 중)

1. `AppleResponsive` 사용처를 `ResponsiveHelper`로 교체
2. 매도자/중개사 대시보드에 반응형 그리드 적용
3. 관리자 대시보드 500~900px 레이아웃 수정
