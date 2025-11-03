# 모바일 출시를 위한 상세 액션 플랜

> **목표:** 출시 준비도 51% → 85% 이상  
> **예상 소요 시간:** 4-6주  
> **작성일:** 2024-11-01

---

## 📊 현재 상태

| 항목 | 현재 점수 | 목표 점수 | 차이 |
|------|----------|----------|------|
| 보안 | 40% 🔴 | 90%+ | +50% |
| 테스트 | 20% 🔴 | 80%+ | +60% |
| 성능 | 70% ⚠️ | 85%+ | +15% |
| **전체** | **51%** | **85%+** | **+34%** |

---

# 1. 보안 강화 (40% → 90%)

## 🔴 Critical - 즉시 조치 필요

### 1.1 관리자 페이지 인증 추가

#### 현재 문제
```dart
// lib/main.dart Line 108
if (settings.name == '/admin-panel-myhome-2024') {
  return MaterialPageRoute(
    builder: (context) => const AdminDashboard(
      userId: 'admin',
      userName: '관리자',
    ),
  );
}
```
**위험:** URL만 알면 누구나 접근 가능

#### 해결 방법 1: 관리자 로그인 페이지 추가

**Step 1: 관리자 로그인 페이지 생성**
```dart
// lib/screens/admin/admin_login_page.dart (신규 파일)
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:property/api_request/firebase_service.dart';
import 'admin_dashboard.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Firebase 로그인
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // 관리자 권한 확인
      final user = await FirebaseService().getUser(credential.user!.uid);
      if (user?['role'] != 'admin') {
        throw Exception('관리자 권한이 없습니다');
      }

      // 관리자 대시보드로 이동
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AdminDashboard(
              userId: credential.user!.uid,
              userName: user?['name'] ?? '관리자',
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _getErrorMessage(e.code);
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
        return '이메일 또는 비밀번호가 올바르지 않습니다';
      case 'invalid-email':
        return '올바른 이메일 형식이 아닙니다';
      default:
        return '로그인에 실패했습니다';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('관리자 로그인')),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.admin_panel_settings, size: 80, color: Colors.blue),
              const SizedBox(height: 32),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: '관리자 이메일',
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: '비밀번호',
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('로그인'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

**Step 2: main.dart 수정**
```dart
// lib/main.dart
import 'screens/admin/admin_login_page.dart';

// Line 108 수정
if (settings.name == '/admin-panel-myhome-2024') {
  return MaterialPageRoute(
    builder: (context) => const AdminLoginPage(), // 로그인 페이지로 변경
  );
}
```

**Step 3: Firebase에 관리자 role 추가**
```javascript
// Firestore users 컬렉션
{
  "uid": "admin_user_id",
  "email": "admin@example.com",
  "name": "관리자",
  "role": "admin"  // 추가
}
```

**작업 시간:** 2-3시간

---

### 1.2 API 키 환경 변수화

#### 현재 문제
```dart
// lib/constants/app_constants.dart
class ApiConstants {
  static const String data_go_kr_serviceKey = "실제_API_키_노출"; // 🔴 위험
  static const String vworldApiKey = "실제_API_키_노출";
}
```
**위험:** 
- Git 히스토리에 영구 저장
- 디컴파일 시 키 탈취 가능
- 악용 가능

#### 해결 방법: Flutter dotenv 사용

**Step 1: 패키지 추가**
```yaml
# pubspec.yaml
dependencies:
  flutter_dotenv: ^5.1.0
```

**Step 2: .env 파일 생성**
```bash
# .env (프로젝트 루트)
DATA_GO_KR_SERVICE_KEY=실제_API_키_여기
VWORLD_API_KEY=실제_API_키_여기
CODEF_CLIENT_ID=실제_클라이언트_ID
CODEF_CLIENT_SECRET=실제_시크릿
```

**Step 3: .gitignore 추가**
```bash
# .gitignore
.env
.env.*
!.env.example
```

**Step 4: .env.example 생성 (팀 공유용)**
```bash
# .env.example
DATA_GO_KR_SERVICE_KEY=your_key_here
VWORLD_API_KEY=your_key_here
CODEF_CLIENT_ID=your_client_id
CODEF_CLIENT_SECRET=your_client_secret
```

**Step 5: main.dart에서 로드**
```dart
// lib/main.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // .env 파일 로드
  await dotenv.load(fileName: ".env");
  
  // Firebase 초기화
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  
  runApp(const MyApp());
}
```

**Step 6: app_constants.dart 수정**
```dart
// lib/constants/app_constants.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  static String get dataGoKrServiceKey => 
    dotenv.env['DATA_GO_KR_SERVICE_KEY'] ?? '';
  
  static String get vworldApiKey => 
    dotenv.env['VWORLD_API_KEY'] ?? '';
    
  static String get codefClientId => 
    dotenv.env['CODEF_CLIENT_ID'] ?? '';
    
  static String get codefClientSecret => 
    dotenv.env['CODEF_CLIENT_SECRET'] ?? '';
}
```

**Step 7: pubspec.yaml에 asset 추가**
```yaml
# pubspec.yaml
flutter:
  assets:
    - .env
```

**Step 8: Git 히스토리에서 API 키 제거**
```bash
# Git 히스토리에서 민감 정보 제거 (주의!)
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch lib/constants/app_constants.dart" \
  --prune-empty --tag-name-filter cat -- --all

# 또는 BFG Repo-Cleaner 사용 (권장)
# https://rtyley.github.io/bfg-repo-cleaner/
```

**작업 시간:** 1-2시간

---

### 1.3 Firestore Security Rules 강화

#### 현재 문제
```javascript
// firestore.rules (추정)
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null; // 너무 관대함
    }
  }
}
```
**위험:** 로그인한 사용자가 모든 데이터에 접근 가능

#### 해결 방법: 세밀한 권한 설정

```javascript
// firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // ============================================
    // 헬퍼 함수
    // ============================================
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function isOwner(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }
    
    function isAdmin() {
      return isAuthenticated() && 
             get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    
    // ============================================
    // Users 컬렉션
    // ============================================
    match /users/{userId} {
      // 본인 또는 관리자만 읽기
      allow read: if isOwner(userId) || isAdmin();
      
      // 본인만 생성 (회원가입 시)
      allow create: if isOwner(userId);
      
      // 본인만 수정 (단, role은 수정 불가)
      allow update: if isOwner(userId) && 
                       request.resource.data.role == resource.data.role;
      
      // 본인만 삭제
      allow delete: if isOwner(userId);
    }
    
    // ============================================
    // Properties 컬렉션 (부동산 정보)
    // ============================================
    match /properties/{propertyId} {
      // 소유자 또는 관리자만 읽기
      allow read: if isOwner(resource.data.registeredBy) || isAdmin();
      
      // 로그인 사용자만 생성
      allow create: if isAuthenticated() && 
                       request.resource.data.registeredBy == request.auth.uid;
      
      // 소유자만 수정
      allow update: if isOwner(resource.data.registeredBy) &&
                       request.resource.data.registeredBy == resource.data.registeredBy;
      
      // 소유자 또는 관리자만 삭제
      allow delete: if isOwner(resource.data.registeredBy) || isAdmin();
    }
    
    // ============================================
    // QuoteRequests 컬렉션 (견적 요청)
    // ============================================
    match /quoteRequests/{requestId} {
      // 요청자 또는 관리자만 읽기
      allow read: if isOwner(resource.data.userId) || isAdmin();
      
      // 로그인 사용자만 생성
      allow create: if isAuthenticated() && 
                       request.resource.data.userId == request.auth.uid;
      
      // 요청자는 수정 불가, 공인중개사는 답변만 추가 가능 (linkId로 접근)
      allow update: if isOwner(resource.data.userId) || 
                       (request.resource.data.diff(resource.data).affectedKeys()
                        .hasOnly(['brokerResponse', 'estimatedPrice', 'availableTime', 
                                  'status', 'respondedAt']));
      
      // 요청자 또는 관리자만 삭제
      allow delete: if isOwner(resource.data.userId) || isAdmin();
    }
    
    // ============================================
    // FrequentLocations 컬렉션 (자주 가는 위치)
    // ============================================
    match /frequentLocations/{locationId} {
      // 본인 또는 관리자만 읽기
      allow read: if isOwner(resource.data.userId) || isAdmin();
      
      // 로그인 사용자만 생성
      allow create: if isAuthenticated() && 
                       request.resource.data.userId == request.auth.uid;
      
      // 본인만 수정
      allow update: if isOwner(resource.data.userId);
      
      // 본인 또는 관리자만 삭제
      allow delete: if isOwner(resource.data.userId) || isAdmin();
    }
    
    // ============================================
    // 기타 컬렉션 차단
    // ============================================
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

**테스트 방법:**
```bash
# Firebase CLI 설치
npm install -g firebase-tools

# 로그인
firebase login

# 프로젝트 초기화 (기존에 했다면 스킵)
firebase init firestore

# Rules 테스트
firebase emulators:start --only firestore

# Rules 배포
firebase deploy --only firestore:rules
```

**작업 시간:** 2-3시간

---

### 1.4 HTTPS 통신 강제

#### Android 설정
```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<application
    android:usesCleartextTraffic="false"  <!-- HTTP 차단 -->
    ...>
```

#### iOS 설정
```xml
<!-- ios/Runner/Info.plist -->
<!-- NSAppTransportSecurity 키가 있으면 제거 -->
<!-- 기본적으로 HTTPS만 허용됨 -->
```

**작업 시간:** 10분

---

### 1.5 민감 정보 로깅 제거

#### 현재 문제
```dart
// lib/screens/home_page.dart 등 여러 파일
print('🔍 [DEBUG] registerResult: $registerResult'); // 🔴 민감 정보 출력
print('📍 [원본 주소] $address');
print('🔍 [DEBUG] aptInfoResult: $aptInfoResult');
```

#### 해결 방법: 프로덕션에서 로그 비활성화

**Step 1: 로거 클래스 생성**
```dart
// lib/utils/logger.dart (신규 파일)
import 'package:flutter/foundation.dart';

class AppLogger {
  static const bool _enableLogging = kDebugMode; // 디버그 모드에서만 활성화
  
  static void debug(String message) {
    if (_enableLogging) {
      print('🔍 [DEBUG] $message');
    }
  }
  
  static void info(String message) {
    if (_enableLogging) {
      print('ℹ️ [INFO] $message');
    }
  }
  
  static void warning(String message) {
    if (_enableLogging) {
      print('⚠️ [WARNING] $message');
    }
  }
  
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    // 에러는 항상 로그 (Crashlytics 등으로 전송)
    print('❌ [ERROR] $message');
    if (error != null) print('Error: $error');
    if (stackTrace != null) print('StackTrace: $stackTrace');
  }
}
```

**Step 2: 기존 print 문 교체**
```dart
// Before
print('🔍 [DEBUG] registerResult: $registerResult');

// After
AppLogger.debug('registerResult: ${registerResult != null ? "loaded" : "null"}');
// 민감 정보 대신 상태만 로그
```

**작업 시간:** 3-4시간 (전체 코드 수정)

---

## 보안 체크리스트

- [ ] 관리자 로그인 페이지 추가
- [ ] 관리자 role 기반 권한 검증
- [ ] API 키 .env로 이전
- [ ] .gitignore에 .env 추가
- [ ] Git 히스토리에서 API 키 제거
- [ ] Firestore Security Rules 배포
- [ ] HTTPS 통신 강제
- [ ] 프로덕션 로그 비활성화
- [ ] 민감 정보 로깅 제거

**총 작업 시간:** 1-1.5주

---

# 2. 테스트 강화 (20% → 80%)

## 🔴 Critical - 핵심 기능 테스트

### 2.1 자동화 테스트 (Unit + Widget)

#### 패키지 설치
```yaml
# pubspec.yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  mockito: ^5.4.0
  build_runner: ^2.4.0
```

#### Unit Test 예시

**test/api/address_service_test.dart**
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:property/api_request/address_service.dart';

void main() {
  group('AddressService Tests', () {
    test('주소 검색 API 정상 호출', () async {
      final result = await AddressService.instance.searchRoadAddress(
        '성남시 분당구',
        page: 1,
      );
      
      expect(result.addresses, isNotEmpty);
      expect(result.totalCount, greaterThan(0));
    });
    
    test('빈 검색어는 에러 반환', () async {
      final result = await AddressService.instance.searchRoadAddress(
        '',
        page: 1,
      );
      
      expect(result.errorMessage, isNotNull);
    });
  });
}
```

**test/utils/address_parser_test.dart**
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:property/utils/address_parser.dart';

void main() {
  group('AddressParser Tests', () {
    test('도로명 주소 파싱', () {
      final parsed = AddressParser.parseAddress1st(
        '경기도 성남시 분당구 중앙공원로 54'
      );
      
      expect(parsed['sido'], '경기도');
      expect(parsed['sigungu'], '성남시 분당구');
      expect(parsed['roadName'], '중앙공원로');
      expect(parsed['buildingNumber'], '54');
    });
    
    test('상세 주소 파싱 (동호수)', () {
      final parsed = AddressParser.parseDetailAddress('211동 1506호');
      
      expect(parsed['dong'], '211');
      expect(parsed['ho'], '1506');
    });
  });
}
```

**작업 시간:** 
- 핵심 함수 10개: 3-4시간
- 전체 커버리지 50%: 1주

---

#### Widget Test 예시

**test/widgets/login_test.dart**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:property/screens/login_page.dart';

void main() {
  testWidgets('로그인 페이지 렌더링', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoginPage()),
    );
    
    expect(find.text('로그인'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2)); // 이메일, 비밀번호
    expect(find.byType(ElevatedButton), findsOneWidget);
  });
  
  testWidgets('빈 입력으로 로그인 시도 시 에러', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoginPage()),
    );
    
    // 로그인 버튼 클릭
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    
    // 에러 메시지 확인
    expect(find.text('이메일을 입력해주세요'), findsOneWidget);
  });
}
```

**작업 시간:** 2-3일

---

### 2.2 Integration Test (E2E)

**integration_test/app_test.dart**
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:property/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  
  group('E2E 테스트', () {
    testWidgets('회원가입 → 주소 검색 → 공인중개사 찾기', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      
      // 1. 회원가입
      await tester.tap(find.text('회원가입'));
      await tester.pumpAndSettle();
      
      await tester.enterText(find.byKey(const Key('name')), '테스트사용자');
      await tester.enterText(find.byKey(const Key('email')), 'test@example.com');
      await tester.enterText(find.byKey(const Key('password')), 'Test123!');
      await tester.tap(find.text('가입하기'));
      await tester.pumpAndSettle(const Duration(seconds: 3));
      
      // 2. 주소 검색
      await tester.enterText(find.byType(TextField).first, '성남시 분당구');
      await tester.pumpAndSettle(const Duration(seconds: 2));
      
      // 3. 주소 선택
      await tester.tap(find.byType(ListTile).first);
      await tester.pumpAndSettle();
      
      // 4. 조회하기
      await tester.tap(find.text('조회하기'));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      
      // 5. 공인중개사 찾기
      await tester.tap(find.text('공인중개사 찾기'));
      await tester.pumpAndSettle(const Duration(seconds: 3));
      
      // 검증
      expect(find.byType(GridView), findsOneWidget);
    });
  });
}
```

**실행 방법:**
```bash
flutter test integration_test/app_test.dart
```

**작업 시간:** 1-2일

---

### 2.3 수동 테스트 (QA)

**QA 시나리오 실행 (51개)**
- 파일: `_AI_Doc/QA_SCENARIOS.md`

**체크리스트 (우선순위 높은 20개)**

#### 인증 (5개)
- [ ] TC-AUTH-001: 정상 회원가입
- [ ] TC-AUTH-004: 정상 로그인
- [ ] TC-AUTH-005: 잘못된 로그인
- [ ] TC-AUTH-006: 자동 로그인
- [ ] TC-AUTH-008: 로그아웃

#### 주소 및 조회 (5개)
- [ ] TC-ADDR-001: 도로명 주소 검색
- [ ] TC-ADDR-004: 상세주소 입력
- [ ] TC-APT-001: 단지 정보 자동 조회
- [ ] TC-VWORLD-001: 좌표 정보 자동 조회

#### 공인중개사 (5개)
- [ ] TC-BROKER-001: 공인중개사 조회
- [ ] TC-BROKER-005: 전화 걸기
- [ ] TC-BROKER-006: 견적 요청 (로그인)
- [ ] TC-BROKER-009: 견적 답변 페이지 접속
- [ ] TC-BROKER-010: 견적 답변 제출

#### 부동산 관리 (3개)
- [ ] TC-PROPERTY-001: 목록 조회
- [ ] TC-PROPERTY-003: 수정
- [ ] TC-PROPERTY-004: 삭제

#### 관리자 (2개)
- [ ] TC-ADMIN-001: 관리자 대시보드 접속
- [ ] TC-ADMIN-004: 견적 요청 조회

**작업 시간:** 2-3일

---

### 2.4 플랫폼별 실제 기기 테스트

#### Android 테스트 기기
```
최소 3개 기기 테스트 (다양한 화면 크기)
- 소형: Galaxy A 시리즈 (5.5인치)
- 중형: Galaxy S 시리즈 (6.1인치)
- 대형: Galaxy Note/Tab (6.8인치+)
```

**테스트 항목:**
- [ ] 앱 설치 정상
- [ ] 권한 요청 (위치, 전화) 정상
- [ ] 모든 화면 정상 렌더링
- [ ] 터치/제스처 정상
- [ ] 전화 걸기 기능
- [ ] 지도 앱 연동
- [ ] 백버튼 동작
- [ ] 앱 전환/복귀 시 상태 유지
- [ ] 네트워크 끊김 시 에러 처리

#### iOS 테스트 기기
```
최소 2개 기기 테스트
- iPhone SE (소형)
- iPhone 14/15 (표준)
```

**테스트 항목:**
- [ ] 앱 설치 정상
- [ ] 권한 요청 정상
- [ ] Safe Area 처리
- [ ] Face ID/Touch ID (해당 시)
- [ ] iOS 네이티브 제스처 (swipe back)
- [ ] 전화/지도 연동

**작업 시간:** 2-3일

---

### 2.5 성능 테스트

#### 로딩 시간 측정
```dart
// 각 주요 화면의 로딩 시간 측정
- 주소 검색: < 1초
- 아파트 정보: < 2초
- 공인중개사 목록: < 3초
- 견적 이력: < 1초
```

#### 메모리 사용량 측정
```bash
# Android
adb shell dumpsys meminfo com.yourcompany.myhome

# iOS
Xcode → Debug Navigator → Memory
```

**기준:**
- 초기 실행: < 100MB
- 정상 사용: < 150MB
- 최대: < 200MB

**작업 시간:** 1일

---

## 테스트 체크리스트

### 자동화 테스트
- [ ] Unit Test 10개 이상
- [ ] Widget Test 5개 이상
- [ ] Integration Test 3개 이상
- [ ] 테스트 커버리지 50% 이상

### 수동 테스트
- [ ] QA 시나리오 20개 실행
- [ ] Android 실제 기기 3종
- [ ] iOS 실제 기기 2종
- [ ] 다양한 네트워크 환경

### 성능 테스트
- [ ] 로딩 시간 측정
- [ ] 메모리 사용량 측정
- [ ] 배터리 소모 테스트

**총 작업 시간:** 1.5-2주

---

# 3. 성능 최적화 (70% → 85%)

## ⚠️ Important - 성능 개선

### 3.1 home_page.dart 리팩토링

#### 현재 문제
```
파일 크기: 2,550줄
문제점:
- 하나의 파일에 모든 로직
- 거대한 build 메서드
- 불필요한 재빌드
- 메모리 부담
```

#### 해결 방법: 파일 분리

**구조 개선:**
```
lib/screens/home_page/
├── home_page.dart (메인, 300줄)
├── widgets/
│   ├── address_search_section.dart (주소 검색, 200줄)
│   ├── selected_address_card.dart (선택된 주소, 100줄)
│   ├── apt_info_card.dart (아파트 정보, 300줄)
│   ├── register_result_card.dart (등기부등본, 400줄)
│   └── broker_search_button.dart (공인중개사 버튼, 50줄)
├── services/
│   ├── address_search_service.dart (주소 검색 로직, 150줄)
│   ├── register_service_handler.dart (등기부등본 로직, 300줄)
│   └── apt_info_handler.dart (아파트 정보 로직, 200줄)
└── models/
    └── home_page_state.dart (상태 관리, 100줄)
```

**Step 1: 위젯 분리 예시**
```dart
// lib/screens/home_page/widgets/address_search_section.dart
import 'package:flutter/material.dart';

class AddressSearchSection extends StatelessWidget {
  final TextEditingController controller;
  final String queryAddress;
  final VoidCallback onSearch;
  final ValueChanged<String> onChanged;
  
  const AddressSearchSection({
    required this.controller,
    required this.queryAddress,
    required this.onSearch,
    required this.onChanged,
    super.key,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onSubmitted: (_) => onSearch(),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '경기도 성남시 분당구 중앙공원로 54',
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: onSearch,
          ),
        ],
      ),
    );
  }
}
```

**Step 2: home_page.dart 간소화**
```dart
// lib/screens/home_page/home_page.dart
class HomePage extends StatefulWidget {
  // ... (기존과 동일)
}

class _HomePageState extends State<HomePage> {
  // 상태 변수들...
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            AddressSearchSection(
              controller: _controller,
              queryAddress: queryAddress,
              onSearch: () => searchRoadAddress(queryAddress),
              onChanged: (val) => setState(() => queryAddress = val),
            ),
            if (selectedRoadAddress.isNotEmpty)
              SelectedAddressCard(address: selectedFullAddress),
            // ... 나머지 위젯들
          ],
        ),
      ),
    );
  }
}
```

**작업 시간:** 2-3일

---

### 3.2 불필요한 재빌드 방지

#### const 위젯 사용
```dart
// Before
Text('고정된 텍스트')

// After
const Text('고정된 텍스트')
```

#### 자동 변환
```bash
# const 자동 적용 (주의: 전체 테스트 필요)
dart fix --apply
```

**작업 시간:** 2-3시간

---

### 3.3 이미지 최적화

#### 현재 상태 확인
```dart
// 현재 이미지 사용 여부 확인
grep -r "Image\." lib/
```

#### 개선 방안 (이미지 사용 시)
```dart
// 1. 캐싱
Image.network(
  url,
  cacheWidth: 500,  // 너비 제한
  cacheHeight: 500, // 높이 제한
)

// 2. Lazy Loading
ListView.builder(
  itemBuilder: (context, index) {
    return Image.network(url);
  },
)

// 3. Placeholder
FadeInImage.assetNetwork(
  placeholder: 'assets/loading.gif',
  image: url,
)
```

**작업 시간:** 1시간 (이미지 있는 경우)

---

### 3.4 목록 최적화

#### ListView → ListView.builder 변환

**Before:**
```dart
Column(
  children: brokers.map((broker) => BrokerCard(broker)).toList(),
)
```

**After:**
```dart
ListView.builder(
  itemCount: brokers.length,
  itemBuilder: (context, index) {
    return BrokerCard(brokers[index]);
  },
)
```

**적용 대상:**
- 공인중개사 목록 ✅ (이미 적용됨)
- 부동산 목록 (확인 필요)
- 견적 이력 (확인 필요)

**작업 시간:** 1-2시간

---

### 3.5 API 호출 최적화

#### 캐싱 추가
```dart
// lib/services/cache_service.dart (신규)
class CacheService {
  static final Map<String, dynamic> _cache = {};
  static final Map<String, DateTime> _cacheTime = {};
  
  static Future<T?> getOrFetch<T>(
    String key,
    Future<T> Function() fetcher, {
    Duration cacheDuration = const Duration(minutes: 5),
  }) async {
    // 캐시 확인
    if (_cache.containsKey(key)) {
      final cacheAge = DateTime.now().difference(_cacheTime[key]!);
      if (cacheAge < cacheDuration) {
        return _cache[key] as T;
      }
    }
    
    // 새로 가져오기
    final data = await fetcher();
    _cache[key] = data;
    _cacheTime[key] = DateTime.now();
    return data;
  }
  
  static void clear(String key) {
    _cache.remove(key);
    _cacheTime.remove(key);
  }
  
  static void clearAll() {
    _cache.clear();
    _cacheTime.clear();
  }
}
```

**사용 예시:**
```dart
// 아파트 정보 캐싱
final aptInfo = await CacheService.getOrFetch(
  'apt_$kaptCode',
  () => AptInfoService.getAptBasisInfo(kaptCode),
  cacheDuration: const Duration(hours: 1), // 1시간 캐싱
);
```

**작업 시간:** 2-3시간

---

### 3.6 빌드 최적화

#### Release 빌드 설정

**android/app/build.gradle**
```gradle
android {
    buildTypes {
        release {
            // 코드 축소 (Proguard)
            minifyEnabled true
            shrinkResources true
            
            // Proguard 규칙
            proguardFiles getDefaultProguardFile('proguard-android.txt'), 
                          'proguard-rules.pro'
            
            // 서명
            signingConfig signingConfigs.release
        }
    }
}
```

#### APK 크기 최적화
```bash
# ABI별 분리 빌드 (크기 50% 감소)
flutter build apk --release --split-per-abi

# 결과:
# app-armeabi-v7a-release.apk (ARM 32bit)
# app-arm64-v8a-release.apk (ARM 64bit)
# app-x86_64-release.apk (Intel 64bit)
```

**작업 시간:** 1시간

---

## 성능 체크리스트

### 코드 최적화
- [ ] home_page.dart 리팩토링 (2,550줄 → 300줄)
- [ ] const 위젯 사용 확대
- [ ] ListView.builder 사용
- [ ] 불필요한 재빌드 제거

### 네트워크 최적화
- [ ] API 응답 캐싱
- [ ] 이미지 lazy loading
- [ ] 동시 요청 수 제한

### 빌드 최적화
- [ ] Proguard 설정
- [ ] APK split-per-abi
- [ ] 불필요한 패키지 제거

### 성능 측정
- [ ] 로딩 시간 < 목표치
- [ ] 메모리 < 200MB
- [ ] 부드러운 스크롤 (60fps)

**총 작업 시간:** 1주

---

# 📊 전체 타임라인

## Week 1: 보안 강화
- Day 1-2: 관리자 인증 추가
- Day 3: API 키 환경 변수화
- Day 4: Firestore Rules 설정
- Day 5: 보안 점검 및 테스트

## Week 2: 테스트 - 자동화
- Day 1-2: Unit Test 작성
- Day 3: Widget Test 작성
- Day 4: Integration Test 작성
- Day 5: 테스트 실행 및 버그 수정

## Week 3: 테스트 - 수동
- Day 1-2: Android 실제 기기 테스트
- Day 3: iOS 실제 기기 테스트
- Day 4-5: QA 시나리오 실행 및 버그 수정

## Week 4: 성능 최적화
- Day 1-3: home_page.dart 리팩토링
- Day 4: API 캐싱 및 최적화
- Day 5: 빌드 최적화 및 성능 측정

## Week 5-6: 통합 테스트 및 버그 수정
- Week 5: 전체 통합 테스트
- Week 6: 최종 버그 수정 및 스토어 준비

---

# 🎯 예상 결과

| 항목 | 현재 | 목표 | 개선 |
|------|------|------|------|
| **보안** | 40% 🔴 | 90% ✅ | +50% |
| **테스트** | 20% 🔴 | 80% ✅ | +60% |
| **성능** | 70% ⚠️ | 85% ✅ | +15% |
| **전체** | **51%** | **85%** | **+34%** |

---

# 💰 리소스 필요사항

## 인력
- 개발자 1명 (풀타임)
- QA 테스터 0.5명 (파트타임, Week 3)

## 장비
- Android 테스트 기기 3대
- iOS 테스트 기기 2대
- Mac 컴퓨터 1대 (iOS 빌드)

## 계정
- Apple Developer ($99/년)
- Google Play Developer ($25 일회성)

## 시간
- 총 4-6주
- 주당 40시간 기준

---

**문서 버전:** 1.0.0  
**최종 업데이트:** 2024-11-01  
**작성자:** AI Assistant

