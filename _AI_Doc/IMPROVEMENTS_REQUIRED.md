# 필요한 개선 사항

> **작성일:** 2024-11-01  
> **우선순위:** 🔴 Critical

---

## 1. MainPage vs HomePage 구조 정리

### 현재 상황

```
_AuthGate
  └─ MainPage (탭 네비게이션 컨테이너)
      └─ IndexedStack
          └─ _pages[0]: HomePage (내집팔기 탭 내용)
          └─ _pages[1]: HouseMarketPage (내집사기)
          └─ _pages[2]: HouseManagementPage (내집관리)
          └─ _pages[3]: PersonalInfoPage (내 정보)
```

**문제점:**
- MainPage와 HomePage가 혼동될 수 있음
- 비로그인 상태에서도 MainPage로 들어가는데, 실제로는 HomePage만 사용 가능한 기능임

**개선 방안:**
- MainPage는 순수하게 탭 네비게이션 컨테이너 역할만
- HomePage는 "내집팔기" 기능의 실제 페이지
- 구조는 유지하되 문서화 및 네이밍 개선

---

## 2. 공인중개사 회원가입/로그인 시스템 ⭐⭐⭐

### 현재 문제점

1. **초기 영업 단계:**
   - 전국 공인중개사 이메일을 알 수 없음
   - 공인중개사가 서비스를 모름
   - → 관리자가 수동으로 이메일 발송 필요

2. **1회성 링크 방식의 한계:**
   - 링크만 클릭하고 끝
   - 플랫폼에 편입되지 않음
   - 재방문 시 링크 다시 필요

### 필요 기능

#### A. 공인중개사 회원가입

**요구사항:**
```
1. 회원가입 페이지
   - 이메일
   - 비밀번호
   - 사업자등록번호 (brokerRegistrationNumber) ⭐ 핵심
   - 대표자명 (ownerName) ⭐ 핵심
   - 사무소명 (businessName)
   - 전화번호

2. API 검증
   - 입력한 brokerRegistrationNumber로
   - VWorld API 또는 서울시 API에서 조회
   - 등록번호 + 대표자명 일치 확인
   - ✅ 일치: 회원가입 승인
   - ❌ 불일치: 회원가입 거부 (오류 메시지)
```

**검증 로직:**
```dart
Future<bool> validateBrokerRegistration({
  required String registrationNumber,
  required String ownerName,
}) async {
  // 1. VWorld API로 중개사 정보 조회
  final broker = await BrokerService.getBrokerByRegistrationNumber(
    registrationNumber,
  );
  
  // 2. 검증
  if (broker == null) {
    return false; // 등록번호가 없음
  }
  
  if (broker.ownerName != ownerName) {
    return false; // 대표자명 불일치
  }
  
  return true; // ✅ 검증 통과
}
```

#### B. 공인중개사 로그인

**요구사항:**
```
1. 로그인 페이지 (판매자와 분리)
   - 이메일/등록번호
   - 비밀번호

2. 사용자 타입 구분
   - 판매자 (기존)
   - 공인중개사 (신규)
```

#### C. 공인중개사 대시보드

**요구사항:**
```
1. 본인에게 온 견적 목록
   - Firebase 필터: brokerRegistrationNumber == 본인 등록번호
   - 상태별 필터 (대기중/답변완료)
   - 정렬: 최신순

2. 견적 상세 보기
   - 매물 정보
   - 요청자 정보
   - 요청 내용

3. 견적 답변
   - 기존 링크 방식도 유지 (비회원 접근용)
   - 회원은 대시보드에서 직접 답변 가능

4. 알림 시스템
   - 새 견적 요청 시 앱 내 알림
   - Firebase Cloud Messaging (FCM) 푸시 알림
```

#### D. Firebase 데이터 구조 변경

**기존:**
```javascript
// users 컬렉션
{
  userId: "user123",
  email: "seller@example.com",
  userName: "홍길동",
  userType: "seller", // 없음 (추정)
}
```

**변경:**
```javascript
// users 컬렉션
{
  userId: "user123",
  email: "seller@example.com",
  userName: "홍길동",
  userType: "seller", // "seller" 또는 "broker" ⭐
}

// brokers 컬렉션 (신규)
{
  brokerId: "broker456",
  email: "broker@example.com",
  brokerRegistrationNumber: "123-45-67890", // ⭐ 검증됨
  ownerName: "김중개", // ⭐ 검증됨
  businessName: "○○부동산",
  phoneNumber: "02-1234-5678",
  verified: true, // API 검증 완료
  createdAt: Timestamp,
}
```

#### E. quoteRequests 컬렉션 변경

**추가 필드:**
```javascript
{
  // ... 기존 필드 ...
  brokerId: "broker456", // 공인중개사 회원 ID (선택)
  brokerRegistrationNumber: "123-45-67890", // 기존 필드 유지
  notificationSent: true, // 알림 발송 여부
  notificationRead: false, // 알림 읽음 여부
}
```

---

## 3. 판매자: 재선택 및 재연락 기능 ⭐⭐

### 현재 문제점

1. **견적 비교 후:**
   - 모든 견적이 마음에 안 들면?
   - → 다시 공인중개사 찾기 화면으로 돌아가야 함

2. **재연락 필요:**
   - 마음에 드는 중개사와 다시 연락하고 싶을 때
   - → 방법이 없음

### 필요 기능

#### A. 견적 비교 페이지에서 재선택

**UI 추가:**
```
┌─────────────────────────────────────────┐
│  견적 비교 화면                         │
│                                         │
│  [요약 카드]                            │
│                                         │
│  [견적 목록]                            │
│                                         │
│  ┌─────────────────────────────────┐  │
│  │ [다시 공인중개사 찾기]            │  │
│  │ 새로운 견적을 받고 싶으시다면...   │  │
│  └─────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

**기능:**
- 버튼 클릭 시 → BrokerListPage로 이동
- 이전에 조회했던 주소 자동 전달
- 같은 중개사 목록 재표시 (이미 요청한 것은 표시)

#### B. 견적 이력에서 재연락

**UI 추가:**
```
┌─────────────────────────────────────────┐
│  견적 이력 카드                         │
│                                         │
│  [답변완료] △△부동산                    │
│  예상 금액: 2억 3천만원                 │
│                                         │
│  ┌──────────┐  ┌──────────┐           │
│  │ [재연락] │  │ [비교]  │           │
│  └──────────┘  └──────────┘           │
└─────────────────────────────────────────┘
```

**재연락 옵션:**
1. **전화 걸기**
   - 원클릭 전화 연결

2. **다시 견적 요청**
   - 같은 중개사에게 다시 요청
   - 새로운 견적 요청 생성 (이전 것과 별개)

3. **공인중개사 정보 보기**
   - BrokerListPage로 이동
   - 해당 중개사로 스크롤/하이라이트

---

## 구현 우선순위

### 🔴 Critical (즉시 구현 필요)

1. **공인중개사 회원가입/로그인** (3-5일)
   - 회원가입 페이지 + API 검증
   - 로그인 페이지 (타입 구분)
   - Firebase 구조 변경

2. **공인중개사 대시보드** (3-5일)
   - 본인 견적 목록
   - 견적 상세/답변
   - 알림 시스템

### 🟡 High (1주일 내)

3. **재선택 기능** (1일)
   - 견적 비교 페이지에서 버튼 추가

4. **재연락 기능** (1일)
   - 견적 이력에 버튼 추가
   - 전화, 재요청, 정보 보기

### 🟢 Medium (2주일 내)

5. **MainPage/HomePage 구조 정리**
   - 문서화
   - 네이밍 개선 (필요 시)

---

## 상세 구현 계획

### Phase 1: 공인중개사 회원가입 (2일)

**파일 생성:**
- `lib/screens/broker/broker_signup_page.dart`
- `lib/screens/broker/broker_login_page.dart`
- `lib/api_request/broker_validation_service.dart`

**Firebase 변경:**
- `users` 컬렉션에 `userType` 필드 추가
- `brokers` 컬렉션 생성

**검증 로직:**
```dart
// lib/api_request/broker_validation_service.dart
class BrokerValidationService {
  /// 공인중개사 등록번호 검증
  static Future<BrokerValidationResult> validateBroker({
    required String registrationNumber,
    required String ownerName,
  }) async {
    // 1. VWorld API로 조회
    // 2. 서울시 API로 조회
    // 3. 등록번호 + 대표자명 일치 확인
    // 4. 결과 반환
  }
}
```

### Phase 2: 공인중개사 로그인 (1일)

**수정 파일:**
- `lib/screens/login_page.dart`
  - 사용자 타입 선택 (판매자/공인중개사)
  - 또는 별도 페이지

**Firebase 쿼리:**
- 판매자: `users` 컬렉션, `userType == "seller"`
- 공인중개사: `brokers` 컬렉션

### Phase 3: 공인중개사 대시보드 (3일)

**파일 생성:**
- `lib/screens/broker/broker_dashboard_page.dart`
- `lib/screens/broker/broker_quote_list_page.dart`
- `lib/screens/broker/broker_quote_detail_page.dart`

**Firebase 쿼리:**
```dart
// 본인에게 온 견적만 조회
final quotes = await FirebaseFirestore.instance
  .collection('quoteRequests')
  .where('brokerRegistrationNumber', isEqualTo: currentBroker.registrationNumber)
  .orderBy('requestDate', descending: true)
  .get();
```

### Phase 4: 알림 시스템 (2일)

**파일 생성:**
- `lib/services/notification_service.dart`
- `lib/services/fcm_service.dart`

**기능:**
- 새 견적 요청 시 푸시 알림
- 앱 내 알림 배지
- 읽음 처리

### Phase 5: 재선택/재연락 기능 (2일)

**수정 파일:**
- `lib/screens/quote_comparison_page.dart`
  - "다시 공인중개사 찾기" 버튼 추가

- `lib/screens/quote_history_page.dart`
  - 각 견적 카드에 "재연락" 버튼 추가
  - 액션 메뉴 (전화, 재요청, 정보보기)

---

## 데이터베이스 스키마 변경

### 기존 구조

```javascript
// users 컬렉션
{
  userId: "user123",
  email: "seller@example.com",
  userName: "홍길동",
}

// quoteRequests 컬렉션
{
  userId: "user123",
  userName: "홍길동",
  brokerName: "○○부동산",
  brokerRegistrationNumber: "123-45-67890",
  status: "pending",
  inquiryLinkId: "abc123",
}
```

### 변경 구조

```javascript
// users 컬렉션
{
  userId: "user123",
  email: "seller@example.com",
  userName: "홍길동",
  userType: "seller", // ⭐ 추가
}

// brokers 컬렉션 (신규)
{
  brokerId: "broker456",
  email: "broker@example.com",
  brokerRegistrationNumber: "123-45-67890",
  ownerName: "김중개",
  businessName: "○○부동산",
  phoneNumber: "02-1234-5678",
  verified: true, // API 검증 완료
  createdAt: Timestamp,
  userType: "broker", // ⭐
}

// quoteRequests 컬렉션
{
  userId: "user123",
  userName: "홍길동",
  brokerId: "broker456", // ⭐ 추가 (회원인 경우)
  brokerName: "○○부동산",
  brokerRegistrationNumber: "123-45-67890",
  status: "pending",
  inquiryLinkId: "abc123",
  notificationSent: true, // ⭐ 추가
  notificationRead: false, // ⭐ 추가
}
```

---

## 화면 플로우 변경

### 판매자 플로우 (변경 없음)

```
HomePage → BrokerListPage → 견적 요청
  ↓
견적 이력 → 견적 비교
  ↓
재선택/재연락 버튼 추가 ⭐
```

### 공인중개사 플로우 (신규)

```
공인중개사 회원가입
  ↓
API 검증 (등록번호 + 대표자명)
  ↓
로그인
  ↓
대시보드
  ├─ 본인 견적 목록
  ├─ 견적 상세
  └─ 견적 답변
  ↓
알림 받기 (새 견적 요청 시)
```

### 관리자 플로우 (변경 없음)

```
관리자 페이지
  ├─ 견적 요청 목록
  ├─ 공인중개사 이메일 추가 (초기 영업용)
  └─ 플랫폼 대시보드 (향후)
```

---

## 구현 체크리스트

### 공인중개사 시스템

- [ ] **회원가입 페이지**
  - [ ] UI 구현
  - [ ] 등록번호 + 대표자명 입력
  - [ ] API 검증 로직
  - [ ] Firebase 저장

- [ ] **로그인 페이지**
  - [ ] 사용자 타입 선택
  - [ ] 판매자/공인중개사 분기
  - [ ] Firebase 인증

- [ ] **대시보드**
  - [ ] 본인 견적 목록
  - [ ] 견적 상세 보기
  - [ ] 견적 답변 (회원용)
  - [ ] 상태 필터

- [ ] **알림 시스템**
  - [ ] FCM 설정
  - [ ] 푸시 알림 발송
  - [ ] 앱 내 알림 배지
  - [ ] 읽음 처리

### 재선택/재연락

- [ ] **견적 비교 페이지**
  - [ ] "다시 공인중개사 찾기" 버튼
  - [ ] BrokerListPage로 이동

- [ ] **견적 이력 페이지**
  - [ ] "재연락" 버튼
  - [ ] 액션 메뉴 (전화/재요청/정보보기)

---

## 예상 소요 시간

| 작업 | 시간 | 우선순위 |
|------|------|----------|
| 공인중개사 회원가입 | 2일 | 🔴 |
| 공인중개사 로그인 | 1일 | 🔴 |
| 공인중개사 대시보드 | 3일 | 🔴 |
| 알림 시스템 | 2일 | 🔴 |
| 재선택 기능 | 1일 | 🟡 |
| 재연락 기능 | 1일 | 🟡 |
| **총합** | **10일** | |

---

## 다음 단계

1. ✅ 이 문서 작성 완료
2. ⏳ 공인중개사 회원가입부터 시작
3. ⏳ 단계별 구현 진행

---

**문서 버전:** 1.0  
**작성일:** 2024-11-01


