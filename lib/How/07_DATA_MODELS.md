# 07. 데이터 모델 상세 설명

> 작성일: 2025-01-XX  
> 파일: `lib/HOW/07_DATA_MODELS.md`

---

## 📋 개요

MyHome 서비스의 주요 데이터 모델을 설명합니다.

---

## 📊 주요 모델

### 1. QuoteRequest (견적문의)

**파일:** `lib/models/quote_request.dart`

**Firestore 구조:**

```dart
{
  userId: String,                    // 판매자 ID
  userName: String,                   // 판매자 이름
  userEmail: String,                  // 판매자 이메일
  brokerName: String,                 // 중개사명
  brokerRegistrationNumber: String?, // 등록번호
  brokerEmail: String?,               // 중개사 이메일 (관리자가 추가)
  message: String,                    // 문의 내용
  status: String,                     // 'pending' | 'answered' | 'completed'
  propertyAddress: String?,          // 매물 주소
  propertyArea: String?,              // 전용면적
  recommendedPrice: String?,          // 권장 매도가
  brokerAnswer: String?,              // 중개사 답변
  inquiryLinkId: String?,             // 고유 링크 ID
  requestDate: Timestamp,            // 요청일
  answerDate: Timestamp?,            // 답변일
}
```

---

### 2. Property (부동산)

**파일:** `lib/models/property.dart`

**주요 필드:**

```dart
{
  address: String,                    // 주소
  transactionType: String,            // 매매/전세/월세
  price: int,                         // 가격
  registerData: String,               // 등기부등본 원본 JSON
  registerSummary: String,            // 등기부등본 요약 JSON
  buildingName: String?,             // 건물명
  buildingType: String?,             // 건물 유형
  area: double?,                      // 면적
  ownerName: String?,                // 소유자명
  liens: List<String>?,              // 권리사항
  // ... 기타 필드
}
```

---

### 3. Broker (공인중개사)

**파일:** `lib/api_request/broker_service.dart`

**주요 필드:**

```dart
{
  name: String,                      // 상호명
  roadAddress: String,              // 도로명주소
  jibunAddress: String,             // 지번주소
  registrationNumber: String,        // 등록번호
  phoneNumber: String?,             // 전화번호
  businessStatus: String?,           // 영업상태
  latitude: double?,                // 위도
  longitude: double?,               // 경도
  distance: double?,                // 거리 (미터)
  // 서울시 API 추가 필드 (21개)
}
```

---

## 🔄 Firestore 컬렉션 구조

### 1. `users` 컬렉션

```dart
{
  uid: String,              // Firebase Auth UID (문서 ID)
  id: String,               // 사용자 ID
  name: String,             // 이름
  email: String,            // 이메일
  phone: String?,           // 휴대폰 번호
  role: String,             // 'user' | 'admin'
  createdAt: Timestamp,     // 가입일
  updatedAt: Timestamp,     // 수정일
}
```

### 2. `quoteRequests` 컬렉션

견적문의 문서들 (위 QuoteRequest 모델 참조)

### 3. `brokers` 컬렉션

공인중개사 정보 문서들

### 4. `properties` 컬렉션

부동산 정보 문서들 (위 Property 모델 참조)

---

## 📝 다음 문서

다음 문서로 계속 읽어보세요:

👉 **[08_API_SERVICES.md](08_API_SERVICES.md)** - API 서비스 통합 문서

