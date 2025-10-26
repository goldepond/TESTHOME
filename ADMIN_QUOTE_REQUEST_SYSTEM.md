# 🎯 Admin 견적문의 시스템 구현 완료

## 📋 개요

`D:\houseMvpProject`의 로직을 기반으로 Flutter 프로젝트에 **Admin 견적문의 시스템**을 구현했습니다.

---

## ✨ 주요 기능

### 1️⃣ **사용자 측 (공인중개사 찾기 페이지)**

- ✅ **견적문의 버튼**: 공인중개사에게 문의 메시지 전송
- ✅ **Firestore 저장**: 문의 내용이 자동으로 `quoteRequests` 컬렉션에 저장
- ✅ **사용자 정보 포함**: userId, userName, userEmail 자동 포함
- ✅ **중개사 정보 포함**: 중개사명, 등록번호, 주소 등

### 2️⃣ **관리자 측 (Admin 대시보드)**

- ✅ **견적문의 관리 탭**: 새로운 탭 추가 (대시보드 → **견적문의** → 관리 설정 → 매물관리)
- ✅ **실시간 데이터**: StreamBuilder로 실시간 견적문의 모니터링
- ✅ **통계 대시보드**: 총 문의, 대기중, 완료, 오늘 문의 수 표시
- ✅ **상태 관리**: pending → contacted → completed / cancelled
- ✅ **이메일 첨부 기능**: 관리자가 공인중개사 이메일을 나중에 첨부 가능

---

## 📁 생성/수정된 파일

### 새로 생성된 파일

1. **`lib/models/quote_request.dart`**
   - 견적문의 데이터 모델
   - Firestore 직렬화/역직렬화
   - 상태 텍스트 및 색상 정의

2. **`lib/screens/admin/admin_quote_requests_page.dart`**
   - 관리자용 견적문의 관리 페이지
   - 실시간 견적문의 목록 표시
   - 이메일 첨부, 상태 변경 기능

### 수정된 파일

3. **`lib/services/firebase_service.dart`**
   - `saveQuoteRequest()`: 견적문의 저장
   - `getAllQuoteRequests()`: 모든 견적문의 조회 (Stream)
   - `getQuoteRequestsByUser()`: 사용자별 견적문의 조회 (Stream)
   - `updateQuoteRequestStatus()`: 상태 업데이트
   - `attachEmailToBroker()`: 이메일 첨부
   - `deleteQuoteRequest()`: 견적문의 삭제

4. **`lib/screens/broker_list_page.dart`**
   - `_requestQuote()` 메서드 수정: Firestore에 견적문의 저장
   - 사용자 정보, 중개사 정보 포함하여 저장
   - 저장 성공/실패 메시지 표시

5. **`lib/screens/admin/admin_dashboard.dart`**
   - 견적문의 탭 추가
   - BottomNavigationBar 4개 탭으로 확장
   - 빠른 액션 카드에 견적문의 추가

---

## 🔄 작동 흐름

```
사용자
  ↓
[공인중개사 찾기 페이지]
  ↓
[견적문의 버튼 클릭]
  ↓
[문의 내용 입력]
  ↓
[Firestore에 저장]
  ↓
Admin 대시보드 (실시간 업데이트)
  ↓
[관리자가 이메일 첨부]
  ↓
[상태 변경: 대기중 → 연락완료 → 완료]
```

---

## 📊 Firestore 데이터 구조

### Collection: `quoteRequests`

```json
{
  "userId": "guest",
  "userName": "게스트",
  "userEmail": "guest@example.com",
  "brokerName": "중앙공인중개사사무소",
  "brokerRegistrationNumber": "가-3604-3-7442",
  "brokerRoadAddress": "경기도 성남시 분당구 중앙공원로31번길 42",
  "brokerJibunAddress": "경기도 성남시분당구 서현동 89",
  "brokerEmail": null,  // Admin이 나중에 첨부
  "message": "견적 문의드립니다. 연락 부탁드립니다.",
  "status": "pending",
  "requestDate": "2025-10-24T15:30:00Z",
  "emailAttachedAt": null,
  "emailAttachedBy": null,
  "updatedAt": null
}
```

---

## 🎨 UI 구성

### Admin 견적문의 관리 페이지

#### 통계 카드 (4개)
- 📊 총 견적문의
- ⏳ 대기중 문의
- ✅ 완료된 문의
- 📅 오늘 문의

#### 견적문의 카드
- **헤더**: 중개사명, 문의일시, 상태 배지
- **사용자 정보**: 이름, 이메일
- **중개사 정보**: 주소, 등록번호, 이메일 (첨부된 경우)
- **문의 내용**: 사용자가 입력한 메시지
- **액션 버튼**:
  - 📧 이메일 첨부 (이메일이 없는 경우)
  - 📞 연락완료 (pending 상태)
  - ✅ 완료처리 (contacted 상태)
  - ❌ 취소

---

## 🔐 상태 관리

### 견적문의 상태 (status)

| 상태 | 텍스트 | 색상 | 설명 |
|------|--------|------|------|
| `pending` | 대기중 | 🟠 주황색 | 새로운 문의 |
| `contacted` | 연락완료 | 🔵 파란색 | 관리자가 연락함 |
| `completed` | 완료 | 🟢 초록색 | 처리 완료 |
| `cancelled` | 취소됨 | 🔴 빨간색 | 취소된 문의 |

---

## 🚀 테스트 방법

### 1. 사용자 테스트
1. 앱 실행
2. 주소 검색 후 등기부등본 조회
3. "공인중개사 찾기" 버튼 클릭
4. 공인중개사 카드에서 "견적문의" 버튼 클릭
5. 문의 내용 입력 후 "전송"
6. "견적 문의가 전송되었습니다!" 메시지 확인

### 2. 관리자 테스트
1. 관리자로 로그인
2. Admin 대시보드 진입
3. "견적문의" 탭 선택
4. 통계 확인 (총 문의, 대기중 등)
5. 견적문의 카드에서:
   - "📧 이메일 첨부" 클릭 → 중개사 이메일 입력
   - "📞 연락완료" 클릭 → 상태 변경
   - "✅ 완료처리" 클릭 → 최종 완료

---

## 📝 참고사항

### TODO: 실제 사용자 정보 연동

현재 `broker_list_page.dart`에서는 하드코딩된 사용자 정보를 사용합니다:

```dart
String get _currentUserId => 'guest';
String get _currentUserName => '게스트';
String get _currentUserEmail => 'guest@example.com';
```

**실제 프로덕션에서는**:
- 로그인 시스템에서 현재 사용자 정보를 가져와야 함
- `FirebaseAuth.instance.currentUser` 또는 앱 전역 상태에서 가져오기

---

## 🔗 참고 파일 (D:\houseMvpProject)

- `admin.html` / `admin.js`: Admin 대시보드 로직
- `broker.html` / `broker.js`: 공인중개사 찾기 및 견적문의 로직

---

## ✅ 구현 완료 체크리스트

- [x] QuoteRequest 모델 생성
- [x] FirebaseService에 견적문의 메서드 추가
- [x] BrokerListPage에 견적문의 Firestore 저장 기능 추가
- [x] Admin 견적문의 관리 페이지 생성
- [x] Admin 대시보드에 견적문의 탭 추가
- [x] 이메일 첨부 기능 구현
- [x] 상태 관리 기능 구현
- [x] 실시간 업데이트 (StreamBuilder)

---

**🎉 모든 기능이 정상적으로 구현되었습니다!**



