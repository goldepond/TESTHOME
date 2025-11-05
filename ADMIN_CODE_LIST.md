# 관리자 페이지 관련 코드 목록

> 작성일: 2025-01-XX  
> 관리자 페이지 관련 파일 및 역할

---

## 📁 주요 파일 구조

```
lib/
├── screens/
│   └── admin/
│       ├── admin_dashboard.dart              # 메인 대시보드 (탭 네비게이션)
│       ├── admin_quote_requests_page.dart    # 견적문의 관리 페이지 ⭐ 핵심
│       ├── admin_broker_management.dart      # 공인중개사 관리 페이지
│       ├── admin_property_management.dart     # 매물 관리 페이지
│       └── admin_property_info_page.dart     # 매물 상세 정보 페이지
│
├── main.dart                                 # 라우팅 설정 (관리자 URL 접근)
├── api_request/
│   └── firebase_service.dart                # 관리자용 Firebase 서비스 메서드
└── models/
    └── quote_request.dart                    # 견적문의 모델
```

---

## 📄 파일별 상세 설명

### 1️⃣ `lib/main.dart` - 라우팅 설정

**역할:** 관리자 페이지 URL 접근 처리

**관련 코드:**
```dart
// Line 106-112
if (settings.name == '/admin-panel-myhome-2024') {
  return MaterialPageRoute(
    builder: (context) => const AdminDashboard(
      userId: 'admin',
      userName: '관리자',
    ),
  );
}
```

**접근 URL:**
- 로컬: `http://localhost:58810/#/admin-panel-myhome-2024`
- 배포: `https://배포도메인/#/admin-panel-myhome-2024`

**⚠️ 보안 주의:** 현재 인증 없이 URL만으로 접근 가능 (보안 담당자에게 넘김)

---

### 2️⃣ `lib/screens/admin/admin_dashboard.dart` - 메인 대시보드

**역할:** 관리자 대시보드의 메인 컨테이너 (탭 네비게이션)

**주요 기능:**
- 대시보드 홈 화면 (`_buildDashboardHome()`)
- 4개 탭 관리:
  1. 대시보드 (홈)
  2. 견적문의 관리 (`AdminQuoteRequestsPage`)
  3. 공인중개사 관리 (`AdminBrokerManagement`)
  4. 매물관리 (`AdminPropertyManagement`)

**파일 크기:** 약 459줄

**주요 메서드:**
- `_buildTopNavigationBar()` - 상단 네비게이션 바
- `_buildMobileHeader()` - 모바일 헤더
- `_buildDesktopHeader()` - 데스크톱 헤더
- `_buildDashboardHome()` - 홈 화면
- `_buildManagementCards()` - 관리 기능 카드들

---

### 3️⃣ `lib/screens/admin/admin_quote_requests_page.dart` ⭐ 핵심 파일

**역할:** 견적문의 관리 (일상 운영에서 가장 많이 사용)

**주요 기능:**
- ✅ 견적문의 실시간 모니터링 (`StreamBuilder`)
- ✅ 통계 대시보드 (총 문의, 대기중, 완료, 오늘 문의 수)
- ✅ 견적문의 목록 표시
- ✅ **중개사 이메일 전송** (`_sendInquiryEmail()`) - 수동 작업 핵심
- ✅ **링크 복사** (`_copyInquiryLink()`) - 수동 작업 핵심
- ✅ 중개사 이메일 첨부 기능 (`attachEmailToBroker()`)
- ✅ 상태 변경 기능

**파일 크기:** 약 993줄

**핵심 메서드:**
- `_sendInquiryEmail()` (Line 846) - 이메일 전송
- `_copyInquiryLink()` (Line 930) - 링크 복사
- `_buildStatsCards()` - 통계 카드
- `_buildQuoteRequestCard()` - 견적문의 카드
- `_buildEmptyState()` - 빈 상태 표시

**사용하는 Firebase 서비스:**
- `getAllQuoteRequests()` - 모든 견적문의 조회
- `updateQuoteRequestLinkId()` - 링크 ID 업데이트
- `attachEmailToBroker()` - 중개사 이메일 첨부

---

### 4️⃣ `lib/screens/admin/admin_broker_management.dart` - 공인중개사 관리

**역할:** 전체 공인중개사 목록 관리

**주요 기능:**
- ✅ 모든 공인중개사 목록 조회
- ✅ 검색 기능 (중개사명, 등록번호)
- ✅ 공인중개사 정보 확인
- ✅ 공인중개사 수정/삭제 (선택적)

**파일 크기:** 약 372줄

**주요 메서드:**
- `_loadBrokers()` - 중개사 목록 로드
- `_filteredBrokers` - 검색 필터링
- `_buildBrokerCard()` - 중개사 카드 표시

**사용하는 Firebase 서비스:**
- `getAllBrokers()` - 모든 중개사 조회

---

### 5️⃣ `lib/screens/admin/admin_property_management.dart` - 매물 관리

**역할:** 전체 매물 목록 관리

**주요 기능:**
- ✅ 모든 매물 목록 조회
- ✅ 상태별 필터링 (전체/작성 완료/보류/예약)
- ✅ 검색 기능 (주소)
- ✅ 매물 상세 정보 확인

**파일 크기:** 약 546줄

**주요 메서드:**
- `_loadProperties()` - 매물 목록 로드
- `_filteredProperties` - 필터링
- `_buildPropertyCard()` - 매물 카드 표시

**사용하는 Firebase 서비스:**
- `getAllProperties()` - 모든 매물 조회

---

### 6️⃣ `lib/screens/admin/admin_property_info_page.dart` - 매물 상세 정보

**역할:** 매물의 전체 정보 표시

**주요 기능:**
- ✅ 매물 기본 정보 표시
- ✅ 계약 정보 표시
- ✅ 상세 정보 표시

**파일 크기:** 약 351줄

**주요 메서드:**
- `_buildInfoSection()` - 정보 섹션
- `_buildInfoRow()` - 정보 행

---

### 7️⃣ `lib/api_request/firebase_service.dart` - Firebase 서비스

**역할:** 관리자용 Firebase 데이터 접근 메서드

**관리자 관련 메서드:**

1. **`isAdmin(String userId)`** (Line 92)
   - 관리자 여부 확인
   - 현재는 사용 안 함 (URL 기반 접근)

2. **`getAllQuoteRequests()`** (Line 1164)
   - 모든 견적문의 조회 (Stream)
   - 사용: `admin_quote_requests_page.dart`

3. **`getAllBrokers()`** (Line 1512)
   - 모든 공인중개사 조회
   - 사용: `admin_broker_management.dart`

4. **`getAllProperties()`** (Line 341)
   - 모든 매물 조회 (Stream)
   - 사용: `admin_property_management.dart`

5. **`attachEmailToBroker()`** (Line 1260)
   - 중개사 이메일 첨부
   - 사용: `admin_quote_requests_page.dart`

6. **`updateQuoteRequestLinkId()`** (Line 1276)
   - 견적문의 링크 ID 업데이트
   - 사용: `admin_quote_requests_page.dart`

---

### 8️⃣ `lib/models/quote_request.dart` - 견적문의 모델

**역할:** 견적문의 데이터 구조 정의

**주요 필드:**
- `id`, `userId`, `userName`, `userEmail`
- `brokerName`, `brokerRegistrationNumber`, `brokerEmail`
- `status` (pending, contacted, completed, cancelled)
- `propertyAddress`, `propertyArea`, `propertyType`
- `recommendedPrice`, `minimumPrice`, `commissionRate`
- `inquiryLinkId` (중개사 답변 링크)

**사용 위치:**
- `admin_quote_requests_page.dart`
- `quote_history_page.dart`
- `broker_dashboard_page.dart`

---

## 🔧 수정이 필요한 주요 위치

### 1. 배포 URL 설정
**파일:** `lib/screens/admin/admin_quote_requests_page.dart`

**위치:**
- Line 856: `const baseUrl = 'https://goldepond.github.io/TESTHOME';`
- Line 938: `const baseUrl = 'https://goldepond.github.io/TESTHOME';`

**작업:** 실제 배포 URL로 변경

---

### 2. VWorld API CORS 도메인
**파일:** `lib/constants/app_constants.dart`

**위치:**
- Line 51: `domainCORSParam = 'http://localhost:8831'`

**작업:** 배포 도메인으로 변경 후 VWorld 개발자 포털에서도 등록

---

### 3. 관리자 페이지 접근 URL (보안)
**파일:** `lib/main.dart`

**위치:**
- Line 106: `if (settings.name == '/admin-panel-myhome-2024')`

**작업:** 보안 담당자에게 넘김 (인증 추가 필요)

---

## 📊 파일 크기 요약

| 파일 | 줄 수 | 역할 |
|------|-------|------|
| `admin_dashboard.dart` | 459줄 | 메인 대시보드 |
| `admin_quote_requests_page.dart` | 993줄 | 견적문의 관리 ⭐ |
| `admin_broker_management.dart` | 372줄 | 중개사 관리 |
| `admin_property_management.dart` | 546줄 | 매물 관리 |
| `admin_property_info_page.dart` | 351줄 | 매물 상세 |

**총합:** 약 2,721줄

---

## 🎯 일상 운영에서 사용하는 파일

### 가장 많이 사용하는 파일 ⭐

**`lib/screens/admin/admin_quote_requests_page.dart`**
- 매일 견적문의 확인
- 중개사 이메일 전송
- 링크 복사

**접근 방법:**
1. 관리자 대시보드 접속
2. "견적문의" 탭 클릭
3. 이 페이지가 표시됨

---

## 🔍 코드 검색 팁

### 관리자 관련 코드 찾기

```bash
# 모든 admin 관련 파일 찾기
grep -r "admin" lib/screens/admin/

# 관리자 페이지 라우팅 찾기
grep -r "admin-panel" lib/

# Firebase 관리자 메서드 찾기
grep -r "getAll" lib/api_request/firebase_service.dart
```

---

## 📝 주요 수정 포인트

### 출시 전 수정 필요

1. **배포 URL 설정** (`admin_quote_requests_page.dart:856`)
2. **VWorld CORS 도메인** (`app_constants.dart:51`)
3. **관리자 인증** (`main.dart:106`) - 보안 담당자에게 넘김

---

## ✅ 요약

**관리자 페이지 관련 파일:**
- 총 5개 Dart 파일 (`lib/screens/admin/`)
- 1개 라우팅 설정 (`lib/main.dart`)
- 여러 Firebase 서비스 메서드 (`lib/api_request/firebase_service.dart`)

**핵심 파일:**
- `admin_quote_requests_page.dart` (일상 운영에서 가장 많이 사용)

**수정 필요:**
- 배포 URL 2곳
- VWorld CORS 도메인 1곳

