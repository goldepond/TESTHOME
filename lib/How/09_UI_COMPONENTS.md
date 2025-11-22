# 09. UI 컴포넌트 및 화면 플로우

> 작성일: 2025-01-XX  
> 파일: `lib/HOW/09_UI_COMPONENTS.md`

---

## 📋 개요

MyHome 서비스의 주요 화면과 UI 컴포넌트의 플로우를 설명합니다.

---

## 🏠 주요 화면

### 1. MainPage (메인 네비게이션)

**파일:** `lib/screens/main_page.dart`

**구조:**

```40:53:lib/screens/main_page.dart
void _initializePages() {
  _pages = [
    HomePage(userId: widget.userId, userName: widget.userName), // 내집팔기
    HouseMarketPage(userName: widget.userName), // 내집사기
    HouseManagementPage(
      userId: widget.userId,
      userName: widget.userName,
    ), // 내집관리
    PersonalInfoPage(
      userId: widget.userId,
      userName: widget.userName,
    ), // 내 정보
  ];
}
```

**하단 네비게이션:**
- 내집팔기 (HomePage)
- 내집사기 (HouseMarketPage)
- 내집관리 (HouseManagementPage)
- 내정보 (PersonalInfoPage)

---

### 2. HomePage (내집팔기)

**파일:** `lib/screens/home_page.dart`

**주요 기능:**

1. **주소 검색**
   - Juso API 연동
   - 디바운싱 (0.5초)
   - 페이지네이션

2. **부동산 정보 조회**
   - VWorld API (좌표 변환)
   - AptInfoService (아파트 정보)
   - (선택적) RegisterService (등기부등본)

3. **공인중개사 찾기**
   - "공인중개사 찾기" 버튼 클릭
   - BrokerListPage로 이동

---

### 3. BrokerListPage (공인중개사 찾기)

**파일:** `lib/screens/broker_list_page.dart`

**주요 기능:**

1. **공인중개사 목록 표시**
   - 거리순 정렬
   - 페이지네이션 (10개씩)

2. **필터링**
   - 검색어 필터
   - 전화번호 필터
   - 영업상태 필터

3. **견적 요청**
   - 개별 요청
   - 다중 요청 (MVP 핵심)

---

### 4. QuoteHistoryPage (견적 이력)

**파일:** `lib/screens/quote_history_page.dart`

**주요 기능:**

1. **견적 목록 표시**
   - 실시간 업데이트 (StreamBuilder)
   - 주소별 그룹화

2. **필터링**
   - 상태별 필터 (전체/대기중/답변완료)

3. **견적 비교**
   - 여러 견적 선택 후 비교 페이지로 이동

---

### 5. QuoteComparisonPage (견적 비교)

**파일:** `lib/screens/quote_comparison_page.dart`

**주요 기능:**

1. **가격 비교**
   - 최저가/평균가/최고가 자동 계산
   - 가격 파싱 및 정규화

2. **중개사별 상세 정보**
   - 권장 매도가
   - 최저수락가
   - 예상 거래기간
   - 수수료 제안율

---

## 🔄 화면 전환 플로우

### 판매자 플로우

```
MainPage (내집팔기)
    ↓
HomePage
    ↓
주소 검색 및 정보 조회
    ↓
BrokerListPage
    ↓
견적 요청 (개별 또는 다중)
    ↓
QuoteHistoryPage
    ↓
QuoteComparisonPage (선택적)
```

### 중개사 플로우

```
링크 클릭 (/inquiry/{linkId})
    ↓
BrokerInquiryResponsePage
    ↓
문의 정보 확인
    ↓
답변 작성 및 제출
    ↓
Firestore 업데이트
    ↓
판매자에게 실시간 전달
```

---

## 🎨 UI 컴포넌트

### 1. 공통 디자인 시스템

**파일:** `lib/widgets/common_design_system.dart`

**주요 컴포넌트:**
- 버튼 스타일
- 카드 스타일
- 색상 팔레트

### 2. LoadingOverlay

**파일:** `lib/widgets/loading_overlay.dart`

로딩 상태를 표시하는 오버레이 컴포넌트

### 3. HomeLogoButton

**파일:** `lib/widgets/home_logo_button.dart`

홈으로 이동하는 로고 버튼

---

## 📱 반응형 디자인

### 웹 최적화

```270:274:lib/screens/broker_list_page.dart
// 웹 최적화: 최대 너비 제한
final screenWidth = MediaQuery.of(context).size.width;
final isWeb = screenWidth > 800;
final maxWidth = isWeb ? 900.0 : screenWidth;
```

주요 화면은 웹 환경에서 최대 너비를 제한하여 가독성을 높입니다.

---

## 📝 마무리

이 문서는 MyHome 서비스의 전체 로직을 코드와 함께 상세하게 설명합니다. 각 기능의 구현 세부사항과 데이터 흐름을 이해할 수 있도록 작성되었습니다.

---

## 📚 문서 목록

1. **[00_PROJECT_OVERVIEW.md](00_PROJECT_OVERVIEW.md)** - 프로젝트 개요 및 아키텍처
2. **[01_AUTHENTICATION_SYSTEM.md](01_AUTHENTICATION_SYSTEM.md)** - 인증 시스템
3. **[02_ADDRESS_SEARCH.md](02_ADDRESS_SEARCH.md)** - 주소 검색 및 부동산 정보 조회
4. **[03_BROKER_SEARCH.md](03_BROKER_SEARCH.md)** - 공인중개사 찾기
5. **[04_QUOTE_REQUEST.md](04_QUOTE_REQUEST.md)** - 견적 요청 시스템
6. **[05_QUOTE_MANAGEMENT.md](05_QUOTE_MANAGEMENT.md)** - 견적 관리 및 답변 시스템
7. **[06_ADMIN_SYSTEM.md](06_ADMIN_SYSTEM.md)** - 관리자 시스템
8. **[07_DATA_MODELS.md](07_DATA_MODELS.md)** - 데이터 모델 상세 설명
9. **[08_API_SERVICES.md](08_API_SERVICES.md)** - API 서비스 통합 문서
10. **[09_UI_COMPONENTS.md](09_UI_COMPONENTS.md)** - UI 컴포넌트 및 화면 플로우

---

**작성 완료일:** 2025-11-06  
**버전:** 1.0

