# 08. API 서비스 통합 문서

> 작성일: 2025-01-XX  
> 파일: `lib/HOW/08_API_SERVICES.md`

---

## 📋 개요

MyHome 서비스에서 사용하는 모든 외부 API 서비스와 Firebase 서비스를 통합하여 설명합니다.

---

## 🔌 외부 API 서비스

### 1. Juso API (행정안전부)

**파일:** `lib/api_request/address_service.dart`

**용도:** 도로명 주소 검색

**제한:** 일일 10,000건

**주요 메서드:**
- `searchRoadAddress()` - 주소 검색

---

### 2. VWorld API (국토교통부)

**파일:** `lib/api_request/vworld_service.dart`

**용도:**
- 좌표 변환 (Geocoder API)
- 토지 정보 조회
- 공인중개사 검색 (WFS API)

**제한:** 일일 40,000건

**주요 메서드:**
- `getCoordinatesFromAddress()` - 주소 → 좌표 변환
- `getLandInfoFromAddress()` - 토지 정보 조회

---

### 3. CODEF API

**파일:** `lib/api_request/register_service.dart`

**용도:** 등기부등본 조회

**현재 상태:** 비활성화 (`isRegisterFeatureEnabled = false`)

**주요 메서드:**
- `getRealEstateRegister()` - 등기부등본 조회

---

### 4. Data.go.kr API

**파일:** `lib/api_request/apt_info_service.dart`

**용도:** 아파트 단지 정보 조회

**주요 메서드:**
- `getAptBasisInfo()` - 아파트 기본정보 조회
- `extractKaptCodeFromAddressAsync()` - 주소에서 단지코드 추출

---

### 5. 서울시 공개 API

**파일:** `lib/api_request/seoul_broker_service.dart`

**용도:** 
- 공인중개사 상세 정보 조회 (21개 필드)
- 공인중개사 등록번호 및 대표자명 검증

**주요 메서드:**
- `validateBroker()` - 등록번호 및 대표자명 검증 (회원가입용)
- `getBrokersDetailByAddress()` - 주소 기반 중개사 정보 조회
- `getBrokerDetailByRegistrationNumber()` - 등록번호 기반 조회

---

## 🔥 Firebase 서비스

**파일:** `lib/api_request/firebase_service.dart`

### 주요 메서드

#### 사용자 관련
- `authenticateUser()` - 로그인
- `registerUser()` - 회원가입
- `getUser()` - 사용자 조회
- `deleteUserAccount()` - 회원탈퇴

#### 견적문의 관련
- `saveQuoteRequest()` - 견적 요청 저장
- `getQuoteRequestsByUser()` - 사용자별 견적 조회 (Stream)
- `getAllQuoteRequests()` - 전체 견적 조회 (Stream)
- `getQuoteRequestByLinkId()` - 링크 ID로 조회
- `updateQuoteRequestAnswer()` - 답변 업데이트

#### 부동산 관련
- `addProperty()` - 부동산 추가
- `getProperties()` - 사용자별 부동산 조회 (Stream)
- `updateProperty()` - 부동산 업데이트
- `deleteProperty()` - 부동산 삭제

#### 공인중개사 관련
- `getBrokerByRegistrationNumber()` - 등록번호로 조회
- `addBroker()` - 중개사 추가
- `getAllBrokers()` - 전체 중개사 조회 (Stream)

---

## 🔄 API 통합 플로우

### 주소 검색 → 부동산 정보 조회 플로우

```
1. 사용자 입력 (주소)
   ↓
2. Juso API 호출 (AddressService)
   ↓
3. 결과 표시 및 선택
   ↓
4. 동시 호출:
   - VWorld API (좌표 변환)
   - AptInfoService (아파트 정보)
   ↓
5. 좌표 정보 저장
   ↓
6. 공인중개사 검색 준비 완료
```

### 공인중개사 검색 플로우

```
1. 좌표 정보 전달
   ↓
2. VWorld API 호출 (공인중개사 검색)
   ↓
3. 결과가 없으면 반경 확대 재시도 (최대 10km)
   ↓
4. 서울 지역인 경우:
   - 서울시 API 호출 (상세 정보)
   - 데이터 병합
   ↓
5. 거리순 정렬
   ↓
6. 결과 표시
```

---

## 📝 다음 문서

다음 문서로 계속 읽어보세요:

👉 **[09_UI_COMPONENTS.md](09_UI_COMPONENTS.md)** - UI 컴포넌트 및 화면 플로우

