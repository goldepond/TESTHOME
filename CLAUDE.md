# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## 프로젝트 개요

**MyHome** - Flutter 기반 부동산 MLS(Multiple Listing Service) 플랫폼.
매도인이 매물을 한 번 등록하면 지역 내 중개사에게 자동 배포되는 구조.

- **앱 타입**: 멀티 유저 부동산 마켓플레이스 (판매자 / 중개사 / 공개 사용자 / 관리자)
- **플랫폼**: iOS, Android, Web (주력), Windows/macOS/Linux
- **패키지명**: `property` (pubspec.yaml)
- **버전**: 1.2.1+24 / Flutter ^3.35.4 / Dart ^3.9.2
- **미구현**: 실시간 채팅(삭제됨), 결제 시스템, 네이버/Apple 로그인

---

## 빌드 및 실행 명령

```bash
# 의존성 설치
flutter pub get

# 정적 분석 (lint)
dart analyze

# 앱 실행 (개발)
flutter run

# Web 빌드 (환경 변수 주입 필요)
flutter build web --release \
  --dart-define=JUSO_API_KEY=xxx \
  --dart-define=DATA_GO_KR_SERVICE_KEY=yyy

# 프로덕션 빌드 (멀티 플랫폼, scripts/build_production.sh)
# base-href="/TESTHOME/", HTML 렌더러, Android는 key.properties 필요
bash scripts/build_production.sh

# Android / iOS
flutter build apk --release
flutter build ios --release

# 관리자 대시보드 Web 빌드 (별도 바이너리)
flutter build web --release \
  --target=lib/main_admin.dart \
  --output=build/web_admin
```

**테스트**: 현재 자동화된 테스트 없음. 수동 테스트로 검증.

### Firebase Functions (Node 20 필요)

```bash
cd functions
npm install
npm run serve    # 로컬 에뮬레이터
npm run deploy   # 배포
```

### Firebase 배포

```bash
# Web 앱 배포
firebase deploy --only hosting:main

# 관리자 대시보드 배포
firebase deploy --only hosting:admin

# Firestore 규칙 배포
firebase deploy --only firestore:rules

# Functions 배포
firebase deploy --only functions
```

### CI/CD

`.github/workflows/`에 4개 워크플로우:
- `build.yml`: 멀티 플랫폼 빌드 (Linux, Web, Android, Windows, macOS, iOS)
- `deploy.yml`: GitHub Pages 배포 (`/MyHome/` 경로, SPA 404.html 포함)
- `firebase-hosting-*.yml`: PR & merge 시 Firebase Hosting 프리뷰/배포

### 환경 변수

`.env` 파일이 필요하다. 웹 빌드는 `.env` 대신 `--dart-define` 플래그를 사용한다.

필수 키: `JUSO_API_KEY`, `VWORLD_API_KEY`, `VWORLD_GEOCODER_API_KEY`, `DATA_GO_KR_SERVICE_KEY`, `KAKAO_NATIVE_APP_KEY`, `KAKAO_JAVASCRIPT_APP_KEY`

프로덕션 빌드 추가 키: `NAVER_MAP_CLIENT_ID`, `REGISTER_API_KEY`, `SEOUL_OPEN_API_KEY`, `CODEF_CLIENT_ID`, `CODEF_CLIENT_SECRET`, `CODEF_PUBLIC_KEY`

---

## 아키텍처

### 진입점

| 파일 | 역할 |
|------|------|
| `lib/main.dart` | 주 앱 진입점. `_AuthGate`에서 Firebase Auth 스트림으로 역할 분기 |
| `lib/main_admin.dart` | 관리자 대시보드 전용 별도 바이너리 |

**라우팅**: `_AuthGate`가 사용자 역할(일반/broker)에 따라 `MainPage` 또는 `MLSBrokerDashboardPage`로 분기. 소셜 로그인 후 이름/전화번호가 없으면 `ProfileCompletionPage`를 거침. 공개 URL은 비로그인 접근 허용:
- `/market-price` — 실거래가 조회
- `/listings` — 공개 매물 목록
- `/property/:id` — 매물 상세
- `/inquiry/:id` — 중개사용 답변 페이지

### 상태 관리

**별도 상태관리 라이브러리 없음.** `StatefulWidget` + `StreamBuilder` + Firestore 직접 구독 패턴 사용.

```dart
// 전형적인 패턴
StreamBuilder<User?>(
  stream: FirebaseAuth.instance.userChanges(),
  builder: (context, snapshot) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: FirebaseService().getUser(user.uid),
      builder: (context, userSnap) { ... },
    );
  },
)
```

### 레이어 구조

```
lib/
├── api_request/    # Firebase & 외부 API 서비스 클래스
├── constants/      # 색상, 타이포그래피, 반응형 상수
├── models/         # Firestore 데이터 모델
├── screens/        # 풀스크린 페이지
│   ├── auth/       # 인증 랜딩, 프로필 완성
│   ├── broker/     # 중개사 대시보드, 설정
│   ├── seller/     # MLS 매물 등록/관리
│   ├── admin/      # 관리자 기능
│   ├── public/     # 비로그인 공개 페이지
│   └── market_price/ # 실거래가 조회 (SEO 공개)
├── services/       # 분석·추적 서비스 (search_analytics_service 등)
├── utils/          # 유틸리티 (로거, 에러 핸들러, 계산기 등)
└── widgets/        # 재사용 UI 컴포넌트
```

### 핵심 서비스

| 파일 | 역할 |
|------|------|
| `firebase_service.dart` | Firestore CRUD 기본 연산 |
| `mls_property_service.dart` | MLS 매물 CRUD, 방문 요청, 검증 |
| `real_transaction_service.dart` | 실거래가 API (3단계 캐싱) |
| `broker_stats_service.dart` | 중개사 상대평가 엔진 |
| `visit_request_service.dart` | 방문 요청 Sub-collection 관리 |

### 외부 API 호출 구조

외부 API(주소 검색, 실거래가 등)는 CORS 제약으로 Cloud Functions `proxy`를 경유한다.

```
Flutter Web → Cloud Functions proxy → 외부 API (juso, vworld, data.go.kr 등)
```

`proxy` 함수 (`functions/index.js`):
- 허용 도메인: `business.juso.go.kr`, `api.vworld.kr`, `apis.data.go.kr`, `openapi.seoul.go.kr`, `map.vworld.kr`
- 캐싱: `apis.data.go.kr` 실거래 API → Firestore 기반 6시간 TTL 서버 캐시
- 캐시 키에서 ServiceKey 제외 (보안)

### Firestore 컬렉션 구조

| 컬렉션 | 접근 권한 | 비고 |
|--------|----------|------|
| `users` | 인증 사용자 읽기, 본인만 쓰기 | role을 admin으로 자가 변경 금지 |
| `brokers` | 인증 사용자 읽기, 본인+관리자 수정 | 중개사 등록 정보 |
| `mlsProperties` | **비로그인 읽기 허용**, 본인+관리자+targetBrokerIds 수정 | 공개 매물 |
| `mlsProperties/{id}/broker_participations` | 인증 사용자 읽기, 본인 중개사만 쓰기 | 서브컬렉션 |
| `brokerOffers` | 본인 제안자/매물 소유자/관리자 읽기 | `brokers` 컬렉션에 문서가 있는 사용자만 생성 가능 |
| `buyerInquiries` | 문의자/배정 중개사/관리자 읽기 | `assignedBrokerId` 필드로 중개사 배정 |
| `brokerStats` | 인증 사용자 읽기/쓰기 | Cloud Functions 업데이트 권장 |
| `notifications` | userId가 uid 또는 email일 수 있음 | FCM 트리거용 |
| `chatMessages` / `chat_messages` | 채팅방 참가자만 | 레거시(`chat_messages`)와 신규(`chatMessages`) 이중 지원 |
| `apiCache` | **클라이언트 접근 불가** | Cloud Functions 전용 서버 캐시 |
| `analytics_market_price` | 관리자만 읽기, 인증 사용자 생성 | 수정/삭제 금지 |
| `analytics_region_counts` | 인증 사용자 읽기/쓰기 | 인기 지역 집계용, 삭제 금지 |
| `contracts` | 관련 당사자(seller/buyer/broker)만 | **삭제 금지** |

---

## MLS 핵심 비즈니스 로직

### 매물 상태 전이

```
draft → pending → active → inquiry → underOffer → depositTaken → sold
                ↘ rejected          ↘ cancelled
```

- `pending`: 관리자 검증 대기
- `active`: 검증 완료, 중개사에게 배포 중
- `inquiry`: 첫 방문 요청 승인 → 연락처 교환 완료

### 방문 요청 (VisitRequest)

Firestore 경로: `mlsProperties/{propertyId}/visitRequests/{requestId}`

- 판매자가 설정한 **가용 시간대** 확인 후 중개사가 방문 요청
- 요청 승인 시 연락처 상호 교환 (승인 전까지 완전 비공개)
- 동일 중개사의 pending 요청이 있으면 중복 요청 불가
- 승인 시 ±30분 이내 충돌 요청 자동 reschedule

### 중개사 상대평가

별점/리뷰 없이 **행동 데이터** 기반 평가:
- 방문 성사율, 노쇼 비율, 제안가 편차, 응답 속도

---

## 디자인 시스템

**Apple HIG 기반, Airbnb 스타일.** `useMaterial3: false` (Material 2 사용).

### 색상 시스템 (3개 클래스)

| 클래스 | 파일 | 용도 |
|--------|------|------|
| `AirbnbColors` | `app_constants.dart` | **주력 사용.** 상태별/카테고리별 시맨틱 색상, 그림자 프리셋, `getStatusColor()` 등 유틸 메서드 포함 |
| `AppleColors` | `apple_design_system.dart` | Apple HIG 표준 색상. `systemBlue`가 코랄(#E07A5F)로 재정의됨 |
| `AppColors` | `app_constants.dart` | 레거시 호환용 (`kPrimary`, `kBrown` 등). 새 코드에서는 `AirbnbColors` 사용 |

```dart
// 브랜드 컬러 (코랄/테라코타)
AirbnbColors.primary  // #E07A5F
AirbnbColors.surface  // 배경
AirbnbColors.textPrimary  // 주요 텍스트
```

### 타이포그래피 & 간격

- **`AppTypography`** (`typography.dart`): `h1`~`h4`, `body`, `bodySmall`, `caption`, `button` 등. `AppTypography.withColor(style, color)`로 색상 적용.
- **`AppSpacing`** (`spacing.dart`): 8px 그리드 시스템. `xs(4)`, `sm(8)`, `md(16)`, `lg(24)`, `xl(32)`, `xxl(48)`.
- **`CommonDesignSystem`** (`widgets/common_design_system.dart`): 카드 데코레이션, AppBar 스타일 등 공통 위젯 헬퍼.

### 반응형 레이아웃

모든 웹 화면은 `Center` + `ConstrainedBox` + `ResponsiveHelper.getMaxWidth()` 패턴 사용.

```dart
// ResponsiveHelper 브레이크포인트 (responsive_constants.dart)
mobile: 600px / tablet: 900px / desktop: 1200px
getMaxWidth(): 900 → 1400 → 1600 (디바이스별)
getGridColumns(): 1 → 2 → 3 (디바이스별)
```

**폰트**: Noto Sans KR (400~900 weight)

---

## 코드 작성 규칙

### 필수 패턴

```dart
// 1. async 작업 후 mounted 체크 필수
if (mounted) setState(() { ... });

// 2. 무거운 초기화는 addPostFrameCallback 사용
WidgetsBinding.instance.addPostFrameCallback((_) async {
  await _loadData();
});

// 3. 가격 입력 필드
FilteringTextInputFormatter.digitsOnly

// 4. 탭 기반 UI는 지연 로딩 패턴 적용
```

### 명명 규칙

- 변수/함수명은 축약 없이 역할이 드러나게: `d` → `daysSinceCreation`
- boolean은 질문 형태: `isLoading`, `hasPermission`, `canSubmit`
- 중첩 3단계 이상 시 Early Return으로 가드 처리

### 플랫폼별 조건 임포트 (.stub 패턴)

Google Sign-in, Kakao SDK, 지도 위젯은 `.stub` 파일을 통해 플랫폼별로 조건 임포트됨.

```dart
// 예: lib/widgets/region_selection_map.dart
export 'region_selection_map_stub.dart'
    if (dart.library.html) 'region_selection_map_web.dart';

// 구현 파일 구조:
// region_selection_map.dart       → 조건 export
// region_selection_map_stub.dart  → 기본 (빈 구현)
// region_selection_map_web.dart   → 웹 전용 구현
// region_selection_map_mobile.dart → 모바일 전용 (있는 경우)
```

이 패턴이 적용된 위젯/서비스:
- `main.dart` → `main_stub.dart` / `main_web.dart` — 웹 첫 프레임 렌더링 완료 신호
- `google_sign_in_service.dart` (.stub / .native / .web)
- `kakao_sign_in_service.dart` (.stub / .native / .web)
- `region_selection_map.dart` (.stub / .web)
- `region_selection_section.dart` (.stub / .web) — 지역 선택 섹션
- `address_map_widget.dart` (.stub / .mobile)
- `broker_map_view.dart` (.stub / .web) — 중개사 대시보드 지도 뷰

---

## Firebase 구성

- **Firestore**: 규칙 `firestore.rules`, 인덱스 `firestore.indexes.json` (25개 복합 인덱스)
- **Hosting**: 두 타겟 — `main` (`build/web`), `admin` (`build/web_admin`)
- **Functions**: Node 20, `functions/index.js`
  - `setAdminClaim`: 관리자 Custom Claims 설정
  - `sendPushNotification`: `notifications/{id}` 생성 트리거 → FCM 전송
  - `sendBrokerPushNotification`: 중개사 전용 FCM
  - `proxy`: CORS 프록시 + 서버 캐싱 (외부 API 호출용)

### Firestore 인덱스 주의

`firestore.indexes.json`에 25개 복합 인덱스가 정의되어 있다. 새 쿼리에 복합 조건(where + orderBy 등)을 추가할 때 인덱스 추가가 필요할 수 있다. Firestore 콘솔 에러 메시지에 인덱스 생성 링크가 포함된다.

### 관리자 페이지 분리

`lib/utils/admin_page_loader_actual.dart`를 삭제하면 관리자 라우트가 비활성화됨 (배포 분리 목적).

---

## Lint 설정

`analysis_options.yaml` 기반 (`flutter_lints ^6.0.0`). 주요 활성 규칙:
- **const 강제**: `prefer_const_constructors`, `prefer_const_declarations`, `prefer_const_literals_to_create_immutables`
- **불변성**: `prefer_final_fields`, `prefer_final_locals`, `prefer_final_in_for_each`
- **성능**: `avoid_unnecessary_containers`, `avoid_redundant_argument_values`, `avoid_slow_async_io`
- **품질**: `always_declare_return_types`, `always_put_required_named_parameters_first`, `use_build_context_synchronously`, `use_key_in_widget_constructors`
- **허용**: `avoid_print: false` (디버깅용), `always_specify_types: false` (타입 추론 허용)
- 제외 파일: `*.g.dart`, `*.freezed.dart`

---

## 로깅

`Logger` (`lib/utils/logger.dart`) — 디버그 모드(`kDebugMode`)에서만 출력. `Logger.info()`, `Logger.warning()`, `Logger.error()` 사용. `context`와 `metadata` 파라미터 지원.

---

## 참고 자료

| 디렉토리 | 용도 |
|----------|------|
| `_reference/legal/` | 앱스토어 법적 문서 (개인정보처리방침, 이용약관) |
| `_reference/api/` | 외부 API 스펙 참고자료 |
