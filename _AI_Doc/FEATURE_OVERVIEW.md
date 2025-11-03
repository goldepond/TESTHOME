# MyHome - 전체 기능 개요

> **프로젝트명:** MyHome (마이홈) - 쉽고 빠른 부동산 상담  
> **플랫폼:** Flutter (Web, Android, iOS)  
> **최종 업데이트:** 2024-11-01

---

## 🎯 서비스 핵심 가치

```
부동산 소유자가 주소만 입력하면
→ 등기부등본, 아파트 정보, 근처 공인중개사를 한번에 확인
→ 비대면으로 견적 요청
→ 계약서 작성까지 원스톱 서비스
```

---

## 📱 주요 화면 구성

### 1. 메인 페이지 (MainPage)
```
┌─────────────────────────────┐
│  MyHome 로고                │
│  [내집팔기] [내집관리] [내정보] │
└─────────────────────────────┘
```

**하단 네비게이션:**
- 🏠 내집팔기 (HomePage)
- 📋 내집관리 (HouseManagementPage)  
- 👤 내정보 (PersonalInfoPage)

---

## 🔥 핵심 기능 (8개 카테고리)

### 1️⃣ 사용자 인증 시스템

#### Firebase Authentication 기반
```
회원가입 → 이메일/비밀번호
로그인 → 자동 로그인 (세션 유지)
비밀번호 찾기 → 이메일 재설정
로그아웃
```

**주요 기능:**
- ✅ Firebase Auth 통합
- ✅ 자동 로그인 (AuthGate 캐싱)
- ✅ 로그인 상태 실시간 동기화
- ✅ 비밀번호 재설정 이메일
- ✅ 에러 메시지 한글화

**관련 파일:**
- `lib/screens/login_page.dart`
- `lib/screens/signup_page.dart`
- `lib/screens/forgot_password_page.dart`
- `lib/main.dart` (AuthGate)

---

### 2️⃣ 주소 검색 및 부동산 정보 조회

#### A. 주소 검색 (Juso API)
```
사용자 입력 → 디바운싱 (0.5초) → API 호출 → 결과 표시
```

**기능:**
- ✅ 도로명 주소 검색
- ✅ 디바운싱 (과도한 API 호출 방지)
- ✅ 페이지네이션 (10개/페이지)
- ✅ 자동 선택 (첫 번째 결과)
- ✅ 상세 주소 입력 (동/호수)

**관련 파일:**
- `lib/api_request/address_service.dart`
- `lib/utils/address_parser.dart`

#### B. 등기부등본 조회 (CODEF API)
```
주소 선택 → 등기부등본 API 호출 → 파싱 → 표시
```

**조회 정보:**
- 📄 등기사항전부증명서 헤더 (발급일, 발급기관, 발급번호)
- 👤 소유자 정보 (이름, 지분)
- 🏠 토지/건물 정보 (지목, 면적, 구조, 층별 면적)
- ⚖️ 권리사항 (저당권, 가압류 등)

**추가 기능:**
- ✅ 소유자 일치/불일치 검증
- ✅ 등기부등본 데이터 Firebase 저장
- ✅ 테스트 모드 지원

**현재 상태:** 🔴 비활성화 (점검 중)
- 재활성화: `isRegisterFeatureEnabled = true`

**관련 파일:**
- `lib/api_request/register_service.dart`
- `lib/utils/current_state_parser.dart`
- `lib/utils/owner_parser.dart`

#### C. VWorld 좌표 조회 (VWorld API)
```
주소 → 좌표 변환 → 공인중개사 찾기에 활용
```

**기능:**
- ✅ 주소 → 위경도 좌표
- ✅ 백그라운드 호출
- ✅ 공인중개사 거리 계산용

**관련 파일:**
- `lib/api_request/vworld_service.dart`

#### D. 아파트 단지 정보 조회 (data.go.kr API)
```
주소 선택 → 단지코드 자동 추출 → API 호출 → 상세 정보 표시
```

**조회 방법:**
1. 도로명코드 기반 검색 (우선)
2. 법정동코드 기반 검색 (대체)
3. 단지명 매칭 (fallback)

**표시 정보:**
- 📌 **기본 정보:** 단지명, 단지코드, 건물구조
- 📌 **관리 정보:** 관리방식, 관리업체, 관리사무소 수
- 📌 **경비 관리:** 경비방식, 경비인력, 경비업체
- 📌 **청소 관리:** 청소방식, 청소인력, 음식물처리
- 📌 **소독 관리:** 소독방식, 소독인력
- 📌 **건물/시설:** 수전용량, 전기계약, 화재수신반, 급수방식
- 📌 **승강기/주차:** 승강기 대수, 주차대수 (지상/지하)
- 📌 **통신/보안:** CCTV 대수, 주차관제/홈네트워크
- 📌 **편의시설:** 복리시설, 편의시설
- 📌 **교통정보:** 버스정류장, 지하철역, 거리
- 📌 **교육시설:** 주변 교육시설
- 📌 **전기차:** 충전기 대수 (지상/지하)

**관련 파일:**
- `lib/api_request/apt_info_service.dart`

---

### 3️⃣ 공인중개사 찾기 시스템 🔥

#### A. 공인중개사 검색
```
주소 조회 → VWorld 좌표 획득 → 공인중개사 찾기
```

**데이터 소스:**
- 🌐 VWorld API (기본 정보)
- 🏢 서울시 공개 API (상세 정보)

**표시 정보:**
- 📍 사무소명
- 👤 대표자명
- 📞 전화번호
- 🏪 영업상태 (영업중/휴업/폐업)
- 🎫 등록번호
- 👥 고용인원
- 📍 도로명주소, 지번주소
- 📏 거리 (현재 위치 기준)
- ⚠️ 행정처분 이력 (있는 경우만)

**주요 기능:**
- ✅ 거리순 정렬 (기본)
- ✅ 페이지네이션 (10개/페이지)
- ✅ 필터링 (관리비 등)
- ✅ 반응형 그리드 레이아웃
  - 모바일: 1열
  - 태블릿: 2열
  - 데스크톱: 3열

**관련 파일:**
- `lib/screens/broker_list_page.dart` (2,237줄)
- `lib/api_request/broker_service.dart`
- `lib/api_request/seoul_broker_service.dart`

#### B. 자주 가는 위치 기반 추천
```
사용자 조회 이력 → 자주 찾는 위치 분석 → 해당 지역 공인중개사 추천
```

**탭 구성:**
- 📍 부동산 인근 (기본)
- ⭐ 자주 가는 위치 (로그인 사용자)

**관련 파일:**
- `lib/api_request/firebase_service.dart`

#### C. 공인중개사 액션
```
공인중개사 카드에서 3가지 액션 가능
```

**버튼:**
1. 🗺️ **길찾기** - 네이버/카카오 지도 연동
2. 📞 **전화문의** - 전화 걸기
3. 💬 **비대면문의** - 견적 요청 (로그인 필요)

---

### 4️⃣ 견적 요청/응답 시스템 💼

#### A. 견적 요청 (사용자)
```
공인중개사 선택 → 비대면문의 → 정보 입력 → 견적 요청
```

**입력 정보:**
- 📝 기본 메시지
- 💰 희망 시세
- 📅 목표 기간
- 📌 특별 요구사항

**요청 후:**
- ✅ Firebase에 저장 (`quoteRequests` 컬렉션)
- ✅ 고유 링크 생성 (`linkId`)
- ✅ 상태: `pending` (대기중)

**관련 파일:**
- `lib/screens/broker_list_page.dart`
- `lib/models/quote_request.dart`

#### B. 견적 답변 (공인중개사)
```
이메일/문자로 링크 수신 → 비로그인 접속 → 답변 작성
```

**접속 URL:**
```
https://yoursite.com/inquiry/{linkId}
```

**입력 정보:**
- 💵 예상 금액
- 🕐 상담 가능 시간
- 💬 추가 메시지

**답변 후:**
- ✅ 상태: `pending` → `responded`
- ✅ 사용자가 견적 이력에서 확인 가능

**관련 파일:**
- `lib/screens/inquiry/broker_inquiry_response_page.dart`

#### C. 견적 요청 이력 (사용자)
```
견적 이력 아이콘 → 요청 목록 → 답변 확인
```

**표시 정보:**
- 📋 요청 일시
- 🏢 공인중개사 정보
- 📍 부동산 주소
- 💬 요청 메시지
- ✅ 답변 내용 (있는 경우)
- 🏷️ 상태 (대기중/답변완료)

**관련 파일:**
- `lib/screens/quote_history_page.dart`

---

### 5️⃣ 계약서 작성 시스템 📄

#### 5단계 프로세스
```
등기부등본 조회 → 계약서 작성 시작 → 5단계 입력 → Firebase 저장
```

**단계별 화면:**

**1단계: 기본 정보**
- 부동산 주소 (자동 입력)
- 거래 유형 (매매/전세/월세)
- 거래 금액
- 계약 당사자 정보

**2단계: 계약 조건**
- 계약일
- 잔금일
- 특약사항

**3단계: 보증금 관리**
- 계약금
- 중도금
- 잔금 (자동 계산)

**4단계: 거래 방법**
- 직거래
  - 매도인/매수인 정보
- 공인중개사
  - 중개사 정보
  - 중개 수수료

**5단계: 최종 확인 및 등록**
- 입력 정보 요약
- 계약서 등록 (Firebase 저장)

**관련 파일:**
- `lib/screens/contract/contract_step_controller.dart`
- `lib/screens/contract/contract_step1_basic_info.dart`
- `lib/screens/contract/contract_step2_contract_conditions.dart`
- `lib/screens/contract/contract_step3_deposit_management.dart`
- `lib/screens/contract/contract_step4_transaction_method.dart`
- `lib/screens/contract/contract_step4_direct_details.dart`
- `lib/screens/contract/contract_step5_registration.dart`

---

### 6️⃣ 내 부동산 관리 🏠

#### A. 부동산 목록
```
Firebase 조회 → 사용자가 등록한 부동산 목록 표시
```

**카드 정보:**
- 📍 주소
- 💰 거래 유형 및 가격
- 📅 등록일
- 📊 상태

**관련 파일:**
- `lib/screens/propertyMgmt/house_management_page.dart`

#### B. 부동산 상세 정보
```
부동산 선택 → 상세 페이지
```

**표시 정보:**
- 등기부등본 정보
- 계약서 정보
- 아파트 단지 정보 (해당 시)
- 견적 요청 이력

**액션:**
- ✏️ 수정
- 🗑️ 삭제

**관련 파일:**
- `lib/screens/admin/admin_property_info_page.dart`

---

### 7️⃣ 개인정보 관리 👤

#### 개인정보 페이지
```
내정보 탭 → 사용자 정보 및 설정
```

**표시 정보:**
- 👤 사용자 이름
- 📧 이메일
- 📅 가입일

**기능:**
- 🔑 비밀번호 변경
- 🚪 로그아웃
- 🗑️ 회원 탈퇴

**자주 가는 위치:**
- 📍 조회 이력 기반 자동 표시
- 🔄 페이지 로드 시 자동 조회

**관련 파일:**
- `lib/screens/userInfo/personal_info_page.dart`

---

### 8️⃣ 관리자 기능 👨‍💼

#### 관리자 대시보드
```
URL 접속: /admin-panel-myhome-2024
```

**⚠️ 주의:** 현재 인증 없이 URL만으로 접근 가능 (보안 강화 필요)

**주요 기능:**

**A. 부동산 관리**
- 모든 사용자의 부동산 조회
- 필터링 (사용자별, 거래 유형별)
- 검색 (주소)
- 수정/삭제 권한

**B. 견적 요청 관리**
- 모든 견적 요청 조회
- 상태별 필터 (대기중/답변완료)
- 공인중개사 답변 링크 복사
- 특별 요구사항 표시

**C. 공인중개사 설정**
- 공인중개사 목록 관리
- 수동 추가/수정/삭제

**관련 파일:**
- `lib/screens/admin/admin_dashboard.dart`
- `lib/screens/admin/admin_property_management.dart`
- `lib/screens/admin/admin_quote_requests_page.dart`
- `lib/screens/admin/admin_broker_settings.dart`

---

## 🗄️ 데이터 모델

### Firebase Firestore 컬렉션

#### 1. `users` - 사용자 정보
```dart
{
  id: String,           // 사용자 ID (UID)
  name: String,         // 이름
  email: String,        // 이메일
  createdAt: Timestamp, // 가입일
}
```

#### 2. `properties` - 부동산 정보
```dart
{
  id: String,                    // 문서 ID
  address: String,               // 주소
  fullAddrAPIData: Map,          // 주소 API 원본 데이터
  transactionType: String,       // 거래 유형 (매매/전세/월세)
  price: int,                    // 가격
  
  // 등기부등본 정보
  registerData: String,          // 원본 JSON
  registerSummary: String,       // 요약 JSON
  ownerName: String?,            // 소유자명
  liens: List?,                  // 권리사항
  
  // 건물 정보
  buildingName: String?,         // 건물명
  buildingType: String?,         // 건물 유형
  floor: int?,                   // 층수
  area: double?,                 // 면적
  structure: String?,            // 구조
  
  // 토지 정보
  landPurpose: String?,          // 토지 지목
  landArea: double?,             // 토지 면적
  
  // 등록자 정보
  registeredBy: String,          // 등록자 ID
  registeredByName: String,      // 등록자 이름
  registeredAt: Timestamp,       // 등록일
  
  // 기타
  status: String,                // 상태
  notes: String?,                // 메모
}
```

#### 3. `quoteRequests` - 견적 요청
```dart
{
  id: String,                    // 문서 ID
  linkId: String,                // 고유 링크 ID (UUID)
  
  // 요청자 정보
  userId: String,                // 사용자 ID
  userName: String,              // 사용자 이름
  userPhone: String?,            // 전화번호
  
  // 부동산 정보
  propertyAddress: String,       // 부동산 주소
  propertyArea: String?,         // 면적
  
  // 공인중개사 정보
  brokerId: String?,             // 공인중개사 ID
  brokerName: String,            // 사무소명
  brokerPhone: String,           // 전화번호
  
  // 요청 내용
  message: String,               // 기본 메시지
  expectedPrice: String?,        // 희망 시세
  targetPeriod: String?,         // 목표 기간
  specialNotes: String?,         // 특별 요구사항
  
  // 답변 내용
  brokerResponse: String?,       // 답변 메시지
  estimatedPrice: String?,       // 예상 금액
  availableTime: String?,        // 상담 가능 시간
  
  // 상태 관리
  status: String,                // pending/responded
  createdAt: Timestamp,          // 요청일
  respondedAt: Timestamp?,       // 답변일
}
```

#### 4. `frequentLocations` - 자주 가는 위치
```dart
{
  userId: String,                // 사용자 ID
  address: String,               // 주소
  latitude: double,              // 위도
  longitude: double,             // 경도
  visitCount: int,               // 방문 횟수
  lastVisitAt: Timestamp,        // 마지막 방문일
}
```

---

## 🔌 외부 API 통합

### 1. 주소 검색
- **API:** 행정안전부 주소 API (Juso API)
- **용도:** 도로명 주소 검색
- **파일:** `lib/api_request/address_service.dart`

### 2. 등기부등본 조회
- **API:** CODEF API
- **용도:** 부동산 등기부등본 조회
- **파일:** `lib/api_request/register_service.dart`
- **상태:** 🔴 비활성화

### 3. 좌표 변환
- **API:** VWorld API
- **용도:** 주소 → 좌표 변환
- **파일:** `lib/api_request/vworld_service.dart`

### 4. 아파트 단지 정보
- **API:** data.go.kr 공동주택 API
- **용도:** 단지 정보 조회
- **파일:** `lib/api_request/apt_info_service.dart`

### 5. 공인중개사 정보
- **API 1:** VWorld API (기본)
- **API 2:** 서울시 공개 API (상세)
- **용도:** 공인중개사 정보 조회
- **파일:** 
  - `lib/api_request/broker_service.dart`
  - `lib/api_request/seoul_broker_service.dart`

---

## 🎨 디자인 시스템

### 컬러 팔레트
```dart
class AppColors {
  static const kPrimary = Color(0xFF3498DB);      // 파란색 (메인)
  static const kSecondary = Color(0xFF2C3E50);    // 남색 (서브)
  static const kBackground = Color(0xFFF5F5F5);   // 회색 배경
  static const kSurface = Colors.white;           // 흰색
  static const kError = Color(0xFFE74C3C);        // 빨간색
}
```

### 디자인 원칙
- ✅ 단색 사용 (그라데이션 제거)
- ✅ 명확한 계층 구조
- ✅ 충분한 여백
- ✅ 일관된 아이콘 사용
- ✅ 반응형 레이아웃

### 폰트
- **기본 폰트:** Noto Sans KR
- **가중치:** 100 ~ 900

---

## 🚀 배포 및 CI/CD

### GitHub Pages 자동 배포
```
Git Push (main) 
    → GitHub Actions 
    → Flutter Web Build 
    → GitHub Pages 배포
```

**워크플로우 파일:**
- `.github/workflows/flutter-gh-pages.yml`

**배포 URL:**
- `https://goldepond.github.io/TESTHOME/`

---

## 📊 프로젝트 통계

### 코드 규모
| 항목 | 수치 |
|------|------|
| 총 파일 수 | 100개+ |
| 총 코드 라인 | 30,000줄+ |
| 주요 화면 | 25개 |
| API 통합 | 5개 |
| Firebase 컬렉션 | 4개 |

### 주요 파일 크기
| 파일 | 라인 수 |
|------|---------|
| `broker_list_page.dart` | 2,237줄 |
| `home_page.dart` | 2,550줄 |
| `house_management_page.dart` | 1,200줄+ |
| `quote_history_page.dart` | 959줄 |
| `apt_info_service.dart` | 1,000줄+ |

---

## 🔄 사용자 플로우

### 핵심 시나리오

#### 시나리오 1: 신규 사용자 등록 → 부동산 조회
```
1. 회원가입 (이메일/비밀번호)
2. 자동 로그인
3. 주소 검색 ("성남시 분당구 중앙공원로 54")
4. "조회하기" 클릭
5. 아파트 단지 정보 자동 표시
6. "공인중개사 찾기" 클릭
7. 인근 공인중개사 목록 확인
8. "비대면문의" → 견적 요청
9. "견적 이력"에서 답변 확인
```

#### 시나리오 2: 공인중개사 답변
```
1. 이메일/문자로 링크 수신
2. 링크 클릭 (/inquiry/{linkId})
3. 견적 정보 확인
4. 답변 작성 (예상 금액, 상담 시간)
5. "답변 제출"
6. 사용자에게 자동 전달
```

#### 시나리오 3: 관리자 견적 관리
```
1. /admin-panel-myhome-2024 접속
2. "견적 요청 관리" 클릭
3. 모든 견적 조회
4. 상태별 필터 (대기중/답변완료)
5. 답변 링크 복사
6. 공인중개사에게 전달
```

---

## ⚙️ 기술 스택

### Frontend
- **Framework:** Flutter 3.x
- **언어:** Dart
- **상태 관리:** setState (기본)
- **UI 라이브러리:** Material Design 3

### Backend
- **인증:** Firebase Authentication
- **데이터베이스:** Cloud Firestore
- **스토리지:** Firebase Storage (향후)
- **호스팅:** GitHub Pages

### 외부 API
- 행정안전부 주소 API
- CODEF API (등기부등본)
- VWorld API (좌표)
- data.go.kr API (아파트 정보)
- 서울시 공개 API (공인중개사)

### DevOps
- **버전 관리:** Git + GitHub
- **CI/CD:** GitHub Actions
- **배포:** GitHub Pages (자동)

---

## 📈 향후 개발 계획

### 우선순위 높음 🔴
1. **보안 강화**
   - 관리자 페이지 인증 추가
   - API 키 환경 변수화
   - Firebase Security Rules 강화

2. **등기부등본 재활성화**
   - 테스트 완료 후 활성화
   - 에러 처리 강화

3. **코드 리팩토링**
   - `home_page.dart` 분리 (2,550줄 → 여러 파일)
   - 상태 관리 개선 (Provider/Riverpod)

### 우선순위 중간 🟡
4. **기능 개선**
   - 채팅 기능 활성화
   - 푸시 알림 (견적 답변 시)
   - 파일 업로드 (계약서, 사진)

5. **테스트 자동화**
   - QA 시나리오 기반 테스트
   - E2E 테스트

### 우선순위 낮음 🟢
6. **부가 기능**
   - 리뷰/평점 시스템
   - 즐겨찾기 공인중개사
   - 시세 분석 차트

7. **성능 최적화**
   - 이미지 lazy loading
   - 메모리 사용량 최적화
   - 캐싱 전략

---

## 🐛 알려진 이슈

### 현재 상태
1. ⚠️ 관리자 페이지 인증 없음
2. ⚠️ `home_page.dart` 과도하게 큼 (2,550줄)
3. ⚠️ 등기부등본 기능 비활성화
4. ℹ️ 디버그 로그 과다 (프로덕션에서 제거 필요)

### 해결된 이슈
- ✅ AuthGate 중복 쿼리 (캐싱)
- ✅ 로그아웃 후 상태 오류
- ✅ 주소 검색 디바운싱
- ✅ 공인중개사 정보 과다 표시 (73% 제거)
- ✅ 타입 에러 수정

---

## 📚 관련 문서

### 사용자 가이드
- 준비 중

### 개발자 문서
- [QA 테스트 시나리오](./QA_SCENARIOS.md)
- [공인중개사 UI 개선](./BROKER_UI_IMPROVEMENT.md)
- [등기부등본 기능 토글](./REGISTER_FEATURE_TOGGLE.md)
- [변경사항 전체 정리](./CHANGELOG_FROM_2e48a29.md)
- [변경사항 요약](./CHANGELOG_SUMMARY.md)

### 관리자 가이드
- [관리자 접근 가이드](../ADMIN_ACCESS.md)

---

## 🎯 핵심 경쟁력

### 1. 원스톱 서비스
```
주소 입력만으로
→ 등기부등본 + 아파트 정보 + 공인중개사
→ 비대면 견적 요청
→ 계약서 작성
```

### 2. 자동화
- ✅ 아파트 단지 정보 자동 조회
- ✅ 좌표 자동 변환
- ✅ 소유자 일치 자동 검증

### 3. 사용자 친화적
- ✅ 간단한 UI/UX
- ✅ 불필요한 정보 제거
- ✅ 명확한 안내 메시지

### 4. 비대면 서비스
- ✅ 공인중개사 비로그인 답변
- ✅ 고유 링크 시스템
- ✅ 견적 이력 관리

---

## 📞 지원

### 문의
- **이메일:** (준비 중)
- **GitHub:** https://github.com/goldepond/TESTHOME

### 라이선스
- Private Project

---

**문서 버전:** 1.0.0  
**최종 업데이트:** 2024-11-01  
**작성자:** AI Assistant

