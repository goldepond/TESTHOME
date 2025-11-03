# 모바일 출시 필요 작업 요약

> **현재 출시 준비도: 51%**  
> **목표: 85% 이상**

---

## 📊 점수별 필요 작업

# 1️⃣ 보안 40% → 90% 🔴

## 필수 작업 (5개)

### ✅ 1. 관리자 페이지 인증 추가
**현재:** URL만 알면 누구나 접근 가능  
**필요:**
```dart
// 1. 관리자 로그인 페이지 생성
lib/screens/admin/admin_login_page.dart (신규)

// 2. main.dart 수정
if (settings.name == '/admin-panel-myhome-2024') {
  return MaterialPageRoute(
    builder: (context) => const AdminLoginPage(), // 인증 필수
  );
}

// 3. Firebase에 role 필드 추가
users/{userId}:
  - role: "admin" | "user"
```
⏱️ **소요 시간:** 2-3시간

---

### ✅ 2. API 키 환경 변수화
**현재:** 소스코드에 하드코딩  
**필요:**
```bash
# 1. 패키지 설치
flutter pub add flutter_dotenv

# 2. .env 파일 생성
.env:
  DATA_GO_KR_SERVICE_KEY=실제키
  VWORLD_API_KEY=실제키
  
# 3. .gitignore 추가
.env
.env.*

# 4. app_constants.dart 수정
static String get dataGoKrServiceKey => dotenv.env['DATA_GO_KR_SERVICE_KEY']!;
```
⏱️ **소요 시간:** 1-2시간

---

### ✅ 3. Firestore Security Rules 강화
**현재:** 로그인하면 모든 데이터 접근 가능  
**필요:**
```javascript
// firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // 사용자: 본인만
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
    }
    
    // 부동산: 등록자만
    match /properties/{propertyId} {
      allow read, write: if request.auth.uid == resource.data.registeredBy;
    }
    
    // 견적: 요청자만 읽기, 공인중개사는 답변 추가만
    match /quoteRequests/{requestId} {
      allow read: if request.auth.uid == resource.data.userId;
      allow update: if request.resource.data.diff(resource.data)
                       .affectedKeys().hasOnly(['brokerResponse', 'status']);
    }
  }
}
```

**배포:**
```bash
firebase deploy --only firestore:rules
```
⏱️ **소요 시간:** 2-3시간

---

### ✅ 4. HTTPS 통신 강제
**필요:**
```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<application
    android:usesCleartextTraffic="false">  <!-- HTTP 차단 -->
```
⏱️ **소요 시간:** 10분

---

### ✅ 5. 민감 정보 로깅 제거
**현재:** print()로 민감 정보 출력  
**필요:**
```dart
// 1. 로거 클래스 생성
lib/utils/logger.dart:
  - AppLogger.debug() (디버그 모드만)
  - AppLogger.error() (항상)

// 2. 기존 print 교체
// Before
print('registerResult: $registerResult'); // 민감 정보

// After
AppLogger.debug('registerResult loaded'); // 상태만
```
⏱️ **소요 시간:** 3-4시간

---

## 보안 총 작업 시간: 1-1.5주

---

# 2️⃣ 테스트 20% → 80% 🔴

## 필수 작업 (4개)

### ✅ 1. Unit Test (핵심 로직 테스트)

**필요한 테스트 (최소 10개):**

```dart
// test/api/address_service_test.dart
test('주소 검색 정상 동작', () async {
  final result = await AddressService.instance.searchRoadAddress('성남시');
  expect(result.addresses, isNotEmpty);
});

// test/utils/address_parser_test.dart
test('주소 파싱 정확성', () {
  final parsed = AddressParser.parseAddress1st('경기도 성남시...');
  expect(parsed['sido'], '경기도');
});

// test/utils/owner_parser_test.dart
test('소유자 이름 추출', () {
  final owners = extractOwnerNames(mockData);
  expect(owners, contains('홍길동'));
});

// test/models/property_test.dart
test('Property 모델 직렬화', () {
  final property = Property(...);
  final map = property.toMap();
  expect(map['address'], isNotEmpty);
});

// test/models/quote_request_test.dart
test('QuoteRequest 모델 생성', () {
  final quote = QuoteRequest(...);
  expect(quote.linkId, isNotEmpty);
});
```

**실행:**
```bash
flutter test
```
⏱️ **소요 시간:** 3-4시간

---

### ✅ 2. Widget Test (UI 컴포넌트 테스트)

**필요한 테스트 (최소 5개):**

```dart
// test/widgets/login_page_test.dart
testWidgets('로그인 버튼 존재', (tester) async {
  await tester.pumpWidget(MaterialApp(home: LoginPage()));
  expect(find.text('로그인'), findsOneWidget);
});

// test/widgets/signup_page_test.dart
testWidgets('회원가입 필수 입력 검증', (tester) async {
  // 빈 입력으로 제출 시 에러 메시지
});

// test/widgets/broker_card_test.dart
testWidgets('공인중개사 카드 렌더링', (tester) async {
  // 카드 정보 표시 확인
});

// test/widgets/address_search_test.dart
testWidgets('주소 검색 입력', (tester) async {
  // 검색창 입력 및 버튼 클릭
});

// test/widgets/quote_dialog_test.dart
testWidgets('견적 요청 다이얼로그', (tester) async {
  // 다이얼로그 표시 및 입력
});
```

⏱️ **소요 시간:** 2-3시간

---

### ✅ 3. Integration Test (E2E 테스트)

**필요한 시나리오 (최소 3개):**

```dart
// integration_test/app_test.dart

// 시나리오 1: 회원가입 → 주소 검색 → 공인중개사
testWidgets('E2E: 신규 사용자 전체 플로우', (tester) async {
  // 1. 회원가입
  // 2. 주소 검색
  // 3. 조회하기
  // 4. 공인중개사 찾기
  // 5. 견적 요청
});

// 시나리오 2: 로그인 → 내집관리
testWidgets('E2E: 부동산 관리 플로우', (tester) async {
  // 1. 로그인
  // 2. 내집관리 탭
  // 3. 부동산 상세
});

// 시나리오 3: 공인중개사 답변
testWidgets('E2E: 견적 답변 플로우', (tester) async {
  // 1. 링크 접속
  // 2. 답변 작성
  // 3. 제출
});
```

**실행:**
```bash
flutter test integration_test/app_test.dart
```
⏱️ **소요 시간:** 1-2일

---

### ✅ 4. 실제 기기 테스트

#### Android (3개 기기)
**테스트 매트릭스:**
| 기기 | 화면 | Android 버전 | 테스트 항목 |
|------|------|--------------|------------|
| Galaxy A32 | 5.5" | 11 | 전체 기능 |
| Galaxy S21 | 6.2" | 13 | 전체 기능 |
| Galaxy Tab | 10.1" | 12 | 반응형 레이아웃 |

**체크리스트:**
- [ ] 앱 설치 및 실행
- [ ] 회원가입/로그인
- [ ] 주소 검색 (한글 입력)
- [ ] 공인중개사 찾기
- [ ] 전화 걸기 (실제 전화 연결)
- [ ] 지도 앱 연동
- [ ] 견적 요청
- [ ] 사진 촬영/업로드 (향후 기능)
- [ ] 백버튼 동작
- [ ] 권한 요청 (위치, 전화)
- [ ] 네트워크 오프라인 처리
- [ ] 앱 전환 후 복귀 시 상태 유지

⏱️ **소요 시간:** 1일

#### iOS (2개 기기)
**테스트 매트릭스:**
| 기기 | 화면 | iOS 버전 | 테스트 항목 |
|------|------|----------|------------|
| iPhone SE | 4.7" | 15 | 전체 기능 |
| iPhone 14 | 6.1" | 17 | 전체 기능 |

**체크리스트:**
- [ ] TestFlight 배포 및 설치
- [ ] 전체 기능 테스트 (Android와 동일)
- [ ] Safe Area 처리 (노치 대응)
- [ ] iOS 네이티브 제스처
- [ ] App Store 스크린샷 캡처

⏱️ **소요 시간:** 1일

---

## 테스트 총 작업 시간: 1.5-2주

---

# 3️⃣ 성능 70% → 85% ⚠️

## 중요 작업 (6개)

### ✅ 1. home_page.dart 리팩토링

**현재:** 2,550줄 (너무 큼)  
**목표:** 300줄 이하

**분리 계획:**
```
home_page.dart (2,550줄)
↓
lib/screens/home_page/
├── home_page.dart (300줄) ← 메인
├── widgets/
│   ├── address_search_section.dart (200줄)
│   ├── selected_address_card.dart (100줄)
│   ├── detail_address_input.dart (80줄)
│   ├── apt_info_section.dart (300줄)
│   ├── register_result_card.dart (400줄)
│   └── broker_search_button.dart (50줄)
└── services/
    ├── home_search_service.dart (300줄)
    └── home_state_manager.dart (200줄)
```

**작업 순서:**
1. 위젯부터 분리 (쉬움)
2. 로직 분리 (중간)
3. 상태 관리 개선 (어려움, 선택적)

⏱️ **소요 시간:** 2-3일

---

### ✅ 2. const 위젯 사용 확대

**현재:** const 사용률 낮음  
**목표:** 고정 위젯 90% 이상 const

**자동 적용:**
```bash
# Dart fix 실행
dart fix --dry-run  # 미리보기
dart fix --apply    # 적용
```

**수동 확인:**
```dart
// Before
Text('고정 텍스트')
Icon(Icons.home)
SizedBox(height: 16)

// After
const Text('고정 텍스트')
const Icon(Icons.home)
const SizedBox(height: 16)
```

⏱️ **소요 시간:** 1-2시간

---

### ✅ 3. API 응답 캐싱

**필요한 캐싱:**
```dart
// 아파트 정보 (1시간 캐싱)
final aptInfo = await CacheService.getOrFetch(
  'apt_$kaptCode',
  () => AptInfoService.getAptBasisInfo(kaptCode),
  cacheDuration: Duration(hours: 1),
);

// 공인중개사 목록 (30분 캐싱)
final brokers = await CacheService.getOrFetch(
  'brokers_${lat}_$lon',
  () => BrokerService.getNearbyBrokers(lat, lon),
  cacheDuration: Duration(minutes: 30),
);

// 주소 검색 (5분 캐싱)
final addresses = await CacheService.getOrFetch(
  'address_$keyword',
  () => AddressService.instance.searchRoadAddress(keyword),
  cacheDuration: Duration(minutes: 5),
);
```

**구현:**
```dart
// lib/services/cache_service.dart (신규)
class CacheService {
  static final _cache = <String, dynamic>{};
  static final _cacheTime = <String, DateTime>{};
  
  static Future<T?> getOrFetch<T>(
    String key,
    Future<T> Function() fetcher,
    {Duration cacheDuration = const Duration(minutes: 5)}
  ) async {
    if (_cache.containsKey(key)) {
      final age = DateTime.now().difference(_cacheTime[key]!);
      if (age < cacheDuration) {
        return _cache[key] as T;
      }
    }
    
    final data = await fetcher();
    _cache[key] = data;
    _cacheTime[key] = DateTime.now();
    return data;
  }
}
```

⏱️ **소요 시간:** 2-3시간

---

### ✅ 4. 메모리 최적화

**필요 작업:**
```dart
// 1. ListView → ListView.builder 변환
// Before
Column(
  children: list.map((item) => Widget(item)).toList(),
)

// After
ListView.builder(
  itemCount: list.length,
  itemBuilder: (context, index) => Widget(list[index]),
)

// 2. dispose 확인
@override
void dispose() {
  _controller.dispose();       ✅
  _debounceTimer?.cancel();    ✅
  super.dispose();
}

// 3. 큰 데이터 메모리 해제
setState(() {
  registerResult = null; // 더 이상 필요 없으면 null
});
```

⏱️ **소요 시간:** 2-3시간

---

### ✅ 5. 빌드 크기 최적화

**Android:**
```bash
# 1. ABI별 분리 (크기 50% 감소)
flutter build apk --release --split-per-abi

# 2. Proguard 활성화
# android/app/build.gradle
buildTypes {
  release {
    minifyEnabled true
    shrinkResources true
  }
}
```

**결과:**
- Before: 30MB
- After: 15-20MB

⏱️ **소요 시간:** 1시간

---

### ✅ 6. 성능 측정 및 모니터링

**측정 항목:**
```dart
// 1. 로딩 시간
Stopwatch stopwatch = Stopwatch()..start();
await fetchData();
print('Loading time: ${stopwatch.elapsedMilliseconds}ms');

// 목표:
- 주소 검색: < 1초
- 아파트 정보: < 2초
- 공인중개사: < 3초
```

**메모리 측정:**
```bash
# Android
adb shell dumpsys meminfo com.yourcompany.myhome | grep TOTAL

# 목표:
- 초기: < 100MB
- 정상: < 150MB
- 최대: < 200MB
```

**도구:**
- Flutter DevTools
- Android Studio Profiler
- Xcode Instruments

⏱️ **소요 시간:** 1일

---

## 성능 총 작업 시간: 1주

---

# 📅 전체 일정 요약

## Week 1: 보안 강화 (40% → 90%)
```
Day 1-2: 관리자 인증 (3시간)
Day 3:   API 키 환경 변수화 (2시간)
Day 4:   Firestore Rules (3시간)
Day 5:   HTTPS + 로깅 제거 (4시간)
```

## Week 2: 테스트 - 자동화 (20% → 60%)
```
Day 1-2: Unit Test 10개
Day 3:   Widget Test 5개
Day 4:   Integration Test 3개
Day 5:   테스트 실행 및 버그 수정
```

## Week 3: 테스트 - 수동 (60% → 80%)
```
Day 1-2: Android 실제 기기 테스트
Day 3:   iOS 실제 기기 테스트
Day 4-5: QA 시나리오 20개 실행
```

## Week 4: 성능 최적화 (70% → 85%)
```
Day 1-3: home_page.dart 리팩토링
Day 4:   API 캐싱 + const 위젯
Day 5:   빌드 최적화 + 성능 측정
```

---

# ✅ 체크리스트 (전체)

## 보안 (5개)
- [ ] 관리자 로그인 페이지 생성
- [ ] API 키 .env로 이전
- [ ] Firestore Security Rules 배포
- [ ] HTTPS 강제 설정
- [ ] 민감 정보 로깅 제거

## 테스트 (4개)
- [ ] Unit Test 10개 작성
- [ ] Widget Test 5개 작성
- [ ] Integration Test 3개 작성
- [ ] Android/iOS 실제 기기 테스트

## 성능 (6개)
- [ ] home_page.dart 리팩토링
- [ ] const 위젯 90% 적용
- [ ] API 캐싱 구현
- [ ] 메모리 최적화
- [ ] 빌드 크기 최적화
- [ ] 성능 측정 완료

**총 15개 작업**

---

# 💰 필요 리소스

## 인력
- **개발자 1명** (풀타임, 4주)
- **QA 테스터 0.5명** (파트타임, Week 3)

## 장비
- **Android 기기 3대** (소/중/대형)
- **iOS 기기 2대** (SE, 14/15)
- **Mac 컴퓨터 1대** (iOS 빌드 및 테스트)

## 계정/라이선스
- **Apple Developer:** $99/년
- **Google Play Developer:** $25 (일회성)

## 시간
- **총 4주** (주당 40시간 기준)
  - Week 1: 보안
  - Week 2: 자동화 테스트
  - Week 3: 수동 테스트
  - Week 4: 성능 최적화

---

# 📈 예상 결과

## 점수 향상
| 항목 | Before | After | 개선 |
|------|--------|-------|------|
| 보안 | 40% | 90% | +50% ⬆️ |
| 테스트 | 20% | 80% | +60% ⬆️ |
| 성능 | 70% | 85% | +15% ⬆️ |
| **전체** | **51%** | **85%** | **+34%** ⬆️ |

## 출시 가능 여부
```
Before: ❌ 출시 불가 (51%)
After:  ✅ 출시 가능 (85%)
```

---

# 🚀 빠른 출시 옵션 (2주)

**긴급하게 출시해야 한다면:**

## 최소 필수 항목만 (60% 달성)
```
Week 1:
✅ 관리자 인증 (필수)
✅ API 키 환경 변수화 (필수)
✅ Firestore Rules (필수)

Week 2:
✅ Android 실제 기기 테스트 (필수)
✅ 핵심 기능 QA 10개 (필수)
✅ 빌드 최적화 (필수)

생략 가능:
⏸️ home_page.dart 리팩토링 (나중에)
⏸️ 자동화 테스트 (나중에)
⏸️ iOS 테스트 (Android만 먼저)
```

**위험:**
- 품질 보장 어려움
- 버그 발견 늦어짐
- 나중에 리팩토링 비용 증가

---

# 📝 결론

## 권장 플랜: 4주 완성 플랜

```
✅ 보안 강화: 1주
✅ 테스트: 2주
✅ 성능: 1주
───────────────
총 4주 → 85% 달성 → 출시 가능
```

## 최소 플랜: 2주 긴급 플랜

```
✅ 필수 보안만: 1주
✅ 필수 테스트만: 1주
───────────────
총 2주 → 60% 달성 → 위험하지만 출시 가능
```

---

**상세 작업 내용:** [RELEASE_ACTION_PLAN.md](./RELEASE_ACTION_PLAN.md)  
**작성일:** 2024-11-01

