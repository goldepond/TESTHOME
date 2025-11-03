# 지금 당장 시작할 수 있는 작업 (보안 제외)

> **작업 가능:** 코드 작업, 자동화 테스트, 성능 최적화  
> **작업 불가:** 실제 기기 필요한 테스트

---

## 🚀 즉시 시작 가능한 작업 (우선순위순)

# 1️⃣ 성능 최적화 (즉시 가능)

## ⭐ 우선순위 1: const 위젯 자동 적용 (10분)

**가장 쉽고 빠른 성능 개선!**

```bash
# 1. 미리보기 (변경될 내용 확인)
dart fix --dry-run

# 2. 자동 적용
dart fix --apply
```

**효과:**
- 불필요한 위젯 재빌드 방지
- 메모리 사용량 감소
- 성능 즉시 개선

⏱️ **소요 시간:** 10분  
💡 **난이도:** ⭐☆☆☆☆ (매우 쉬움)

---

## ⭐ 우선순위 2: API 캐싱 구현 (2-3시간)

### Step 1: CacheService 클래스 생성

```dart
// lib/services/cache_service.dart (신규 파일)
import 'dart:async';

class CacheService {
  static final Map<String, dynamic> _cache = {};
  static final Map<String, DateTime> _cacheTime = {};
  
  /// 캐시 또는 새로 가져오기
  static Future<T?> getOrFetch<T>(
    String key,
    Future<T> Function() fetcher, {
    Duration cacheDuration = const Duration(minutes: 5),
  }) async {
    // 캐시 확인
    if (_cache.containsKey(key)) {
      final cacheAge = DateTime.now().difference(_cacheTime[key]!);
      if (cacheAge < cacheDuration) {
        print('✅ [Cache] Hit: $key (age: ${cacheAge.inSeconds}s)');
        return _cache[key] as T;
      } else {
        print('⚠️ [Cache] Expired: $key (age: ${cacheAge.inSeconds}s)');
      }
    }
    
    // 캐시 미스 - 새로 가져오기
    print('🔄 [Cache] Miss: $key - Fetching...');
    final data = await fetcher();
    _cache[key] = data;
    _cacheTime[key] = DateTime.now();
    return data;
  }
  
  /// 특정 키 캐시 삭제
  static void clear(String key) {
    _cache.remove(key);
    _cacheTime.remove(key);
    print('🗑️ [Cache] Cleared: $key');
  }
  
  /// 전체 캐시 삭제
  static void clearAll() {
    _cache.clear();
    _cacheTime.clear();
    print('🗑️ [Cache] Cleared all');
  }
  
  /// 캐시 통계
  static Map<String, dynamic> getStats() {
    return {
      'cacheSize': _cache.length,
      'keys': _cache.keys.toList(),
    };
  }
}
```

### Step 2: 아파트 정보 캐싱 적용

```dart
// lib/screens/home_page.dart
// Line 667 부근 수정

// Before
final aptInfoResult = await AptInfoService.getAptBasisInfo(extractedKaptCode);

// After
import 'package:property/services/cache_service.dart';

final aptInfoResult = await CacheService.getOrFetch(
  'apt_info_$extractedKaptCode',
  () => AptInfoService.getAptBasisInfo(extractedKaptCode),
  cacheDuration: const Duration(hours: 1), // 아파트 정보는 1시간 캐싱
);
```

### Step 3: 공인중개사 목록 캐싱

```dart
// lib/screens/broker_list_page.dart
// _loadBrokers() 메서드 수정

// Before
final vworldBrokers = await BrokerService.getNearbyBrokers(...);
final seoulBrokers = await SeoulBrokerService.searchBrokers(...);

// After
import 'package:property/services/cache_service.dart';

final cacheKey = 'brokers_${latitude}_${longitude}';
final vworldBrokers = await CacheService.getOrFetch(
  cacheKey,
  () => BrokerService.getNearbyBrokers(...),
  cacheDuration: const Duration(minutes: 30), // 30분 캐싱
);
```

### Step 4: 주소 검색 캐싱 (선택적)

```dart
// lib/api_request/address_service.dart
// searchRoadAddress() 메서드 수정

// 같은 검색어 재검색 시 캐시 사용
final cacheKey = 'address_${keyword}_$page';
final result = await CacheService.getOrFetch(
  cacheKey,
  () => _performSearch(keyword, page),
  cacheDuration: const Duration(minutes: 5),
);
```

⏱️ **소요 시간:** 2-3시간  
💡 **난이도:** ⭐⭐☆☆☆ (쉬움)  
🎯 **효과:** 네트워크 호출 50% 감소, 빠른 응답

---

## ⭐ 우선순위 3: 불필요한 디버그 로그 제거 (1시간)

### 삭제 대상 print 문 찾기

```bash
# 모든 print 문 찾기
grep -rn "print(" lib/ | wc -l
# 예상: 200개 이상
```

### 빠른 제거 방법 (정규식 사용)

```dart
// 1. 등기부등본 관련 과도한 로그
// lib/screens/home_page.dart

// 삭제할 라인들 (예시):
// Line 170: print('[DEBUG] registerResult: ...')
// Line 654-664: print('═══════...') 등 장식 로그
// Line 618-740: 모든 🔍 [DEBUG] 로그

// 간단하게: 주석 처리
/*
print('🔍 [DEBUG] ...');
print('📍 [원본 주소] ...');
*/

// 또는 조건부 로그로 변경
if (kDebugMode) {
  print('🔍 [DEBUG] ...');
}
```

### 일괄 주석 처리 스크립트 (선택)

```dart
// lib/utils/debug_helper.dart (신규)
import 'package:flutter/foundation.dart';

void debugLog(String message) {
  if (kDebugMode) {
    print(message);
  }
}

// 기존 print를 debugLog로 변경
// print('...') → debugLog('...')
```

⏱️ **소요 시간:** 1시간  
💡 **난이도:** ⭐☆☆☆☆ (매우 쉬움)  
🎯 **효과:** 프로덕션 성능 개선, 로그 정리

---

## ⭐ 우선순위 4: 빌드 최적화 (30분)

### Android APK 크기 감소

```bash
# 1. ABI별 분리 빌드 (크기 50% 감소)
flutter build apk --release --split-per-abi

# 결과 확인
ls -lh build/app/outputs/flutter-apk/
# app-armeabi-v7a-release.apk (약 15MB)
# app-arm64-v8a-release.apk (약 18MB)
# app-x86_64-release.apk (약 20MB)
```

### Proguard 활성화

```gradle
// android/app/build.gradle
android {
    buildTypes {
        release {
            minifyEnabled true        // 코드 축소
            shrinkResources true      // 리소스 축소
            
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 
                          'proguard-rules.pro'
        }
    }
}
```

```proguard
# android/app/proguard-rules.pro (없으면 생성)
# Flutter 기본 규칙
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Firebase
-keep class com.google.firebase.** { *; }
```

⏱️ **소요 시간:** 30분  
💡 **난이도:** ⭐⭐☆☆☆ (쉬움)  
🎯 **효과:** APK 크기 30-50% 감소

---

# 2️⃣ 테스트 (즉시 가능)

## ⭐ 우선순위 5: Unit Test 작성 (3-4시간)

### 패키지 설치
```bash
flutter pub add --dev mockito build_runner
```

### Test 1: AddressParser (15분)

```dart
// test/utils/address_parser_test.dart (신규)
import 'package:flutter_test/flutter_test.dart';
import 'package:property/utils/address_parser.dart';

void main() {
  group('AddressParser Tests', () {
    test('도로명 주소 파싱 - 정상', () {
      final result = AddressParser.parseAddress1st(
        '경기도 성남시 분당구 중앙공원로 54'
      );
      
      expect(result['sido'], '경기도');
      expect(result['sigungu'], '성남시 분당구');
      expect(result['roadName'], '중앙공원로');
      expect(result['buildingNumber'], '54');
    });
    
    test('상세 주소 파싱 - 동호수', () {
      final result = AddressParser.parseDetailAddress('211동 1506호');
      
      expect(result['dong'], '211');
      expect(result['ho'], '1506');
    });
    
    test('상세 주소 파싱 - 빈 입력', () {
      final result = AddressParser.parseDetailAddress('');
      
      expect(result['dong'], isEmpty);
      expect(result['ho'], isEmpty);
    });
  });
}
```

### Test 2: OwnerParser (15분)

```dart
// test/utils/owner_parser_test.dart (신규)
import 'package:flutter_test/flutter_test.dart';
import 'package:property/utils/owner_parser.dart';

void main() {
  group('OwnerParser Tests', () {
    test('소유자 이름 추출', () {
      final mockData = {
        'resRegistrationHisList': [
          {
            'resContentsList': [
              {
                'resRightType': '소유권',
                'resDetailList': [
                  {'resOwner': '홍길동'},
                  {'resOwner': '김철수'},
                ]
              }
            ]
          }
        ]
      };
      
      final owners = extractOwnerNames(mockData);
      
      expect(owners, hasLength(2));
      expect(owners, contains('홍길동'));
      expect(owners, contains('김철수'));
    });
    
    test('소유자 정보 없음', () {
      final mockData = {'resRegistrationHisList': []};
      final owners = extractOwnerNames(mockData);
      
      expect(owners, isEmpty);
    });
  });
}
```

### Test 3: Property Model (15분)

```dart
// test/models/property_test.dart (신규)
import 'package:flutter_test/flutter_test.dart';
import 'package:property/models/property.dart';

void main() {
  group('Property Model Tests', () {
    test('Property 생성 및 직렬화', () {
      final property = Property(
        fullAddrAPIData: {'roadAddr': '테스트주소'},
        address: '서울특별시 강남구 테헤란로 123',
        transactionType: '매매',
        price: 500000000,
        description: '테스트 설명',
        registerData: '{}',
        registerSummary: '{}',
        registeredBy: 'test_user',
        registeredByName: '테스트사용자',
      );
      
      final map = property.toMap();
      
      expect(map['address'], '서울특별시 강남구 테헤란로 123');
      expect(map['transactionType'], '매매');
      expect(map['price'], 500000000);
    });
    
    test('Property fromMap', () {
      final map = {
        'fullAddrAPIData': {'roadAddr': '테스트주소'},
        'address': '테스트 주소',
        'transactionType': '전세',
        'price': 300000000,
        'description': '',
        'registerData': '{}',
        'registerSummary': '{}',
        'registeredBy': 'user123',
        'registeredByName': '홍길동',
      };
      
      final property = Property.fromMap(map);
      
      expect(property.address, '테스트 주소');
      expect(property.transactionType, '전세');
    });
  });
}
```

### Test 4: QuoteRequest Model (15분)

```dart
// test/models/quote_request_test.dart (신규)
import 'package:flutter_test/flutter_test.dart';
import 'package:property/models/quote_request.dart';

void main() {
  group('QuoteRequest Model Tests', () {
    test('QuoteRequest 생성 시 linkId 자동 생성', () {
      final quote = QuoteRequest(
        userId: 'user123',
        userName: '홍길동',
        propertyAddress: '테스트 주소',
        brokerName: '테스트 중개사',
        brokerPhone: '02-123-4567',
        message: '견적 요청합니다',
      );
      
      expect(quote.linkId, isNotEmpty);
      expect(quote.linkId.length, greaterThan(10));
      expect(quote.status, 'pending');
    });
    
    test('QuoteRequest toMap/fromMap', () {
      final quote = QuoteRequest(
        userId: 'user123',
        userName: '홍길동',
        propertyAddress: '테스트 주소',
        brokerName: '테스트 중개사',
        brokerPhone: '02-123-4567',
        message: '견적 요청',
      );
      
      final map = quote.toMap();
      final restored = QuoteRequest.fromMap(map);
      
      expect(restored.userId, quote.userId);
      expect(restored.linkId, quote.linkId);
    });
  });
}
```

### 실행 및 확인

```bash
# 모든 테스트 실행
flutter test

# 특정 테스트만 실행
flutter test test/utils/address_parser_test.dart

# 커버리지 확인
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
# coverage/html/index.html 브라우저에서 열기
```

⏱️ **소요 시간:** 3-4시간  
💡 **난이도:** ⭐⭐☆☆☆ (쉬움)  
🎯 **효과:** 코드 안정성 확보, 회귀 테스트 가능

---

## ⭐ 우선순위 6: Widget Test 작성 (2-3시간)

### Test 1: ErrorMessage 위젯 (15분)

```dart
// test/widgets/error_message_test.dart (신규)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:property/screens/home_page.dart';

void main() {
  testWidgets('ErrorMessage 위젯 렌더링', (WidgetTester tester) async {
    bool retryClicked = false;
    
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ErrorMessage(
            message: '테스트 에러 메시지',
            onRetry: () {
              retryClicked = true;
            },
          ),
        ),
      ),
    );
    
    // 에러 메시지 표시 확인
    expect(find.text('등기부등본 조회 실패'), findsOneWidget);
    expect(find.text('테스트 에러 메시지'), findsOneWidget);
    
    // 다시 시도 버튼 확인
    expect(find.text('다시 시도'), findsOneWidget);
    
    // 버튼 클릭
    await tester.tap(find.text('다시 시도'));
    await tester.pump();
    
    expect(retryClicked, true);
  });
}
```

### Test 2: DetailAddressInput 위젯 (15분)

```dart
// test/widgets/detail_address_input_test.dart (신규)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:property/screens/home_page.dart';

void main() {
  testWidgets('상세주소 입력 위젯', (WidgetTester tester) async {
    final controller = TextEditingController();
    String? changedValue;
    
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DetailAddressInput(
            controller: controller,
            onChanged: (val) {
              changedValue = val;
            },
          ),
        ),
      ),
    );
    
    // 힌트 텍스트 확인
    expect(find.text('예: 211동 1506호'), findsOneWidget);
    
    // 입력
    await tester.enterText(find.byType(TextField), '211동 1506호');
    await tester.pump();
    
    expect(changedValue, '211동 1506호');
  });
}
```

### Test 3: RoadAddressList 위젯 (20분)

```dart
// test/widgets/road_address_list_test.dart (신규)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:property/screens/home_page.dart';

void main() {
  testWidgets('주소 목록 위젯 렌더링', (WidgetTester tester) async {
    final addresses = [
      '서울특별시 강남구 테헤란로 123',
      '경기도 성남시 분당구 중앙공원로 54',
    ];
    final fullData = [
      {'roadAddr': addresses[0]},
      {'roadAddr': addresses[1]},
    ];
    
    String? selectedAddr;
    
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoadAddressList(
            fullAddrAPIDatas: fullData,
            addresses: addresses,
            selectedAddress: '',
            onSelect: (data, addr) {
              selectedAddr = addr;
            },
          ),
        ),
      ),
    );
    
    // 검색 결과 텍스트 확인
    expect(find.text('검색 결과 2건'), findsOneWidget);
    
    // 주소 표시 확인
    expect(find.text(addresses[0]), findsOneWidget);
    expect(find.text(addresses[1]), findsOneWidget);
    
    // 첫 번째 주소 선택
    await tester.tap(find.text(addresses[0]));
    await tester.pump();
    
    expect(selectedAddr, addresses[0]);
  });
}
```

⏱️ **소요 시간:** 2-3시간  
💡 **난이도:** ⭐⭐☆☆☆ (쉬움)

---

## ⭐ 우선순위 7: home_page.dart 리팩토링 시작 (2-3일)

**단계적 접근 (조금씩):**

### Phase 1: 위젯 분리 (1일)

**Step 1: AddressSearchSection 분리**
```dart
// lib/screens/home_page/widgets/address_search_section.dart (신규)
import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';

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
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(
          color: AppColors.kPrimary.withValues(alpha: 0.3), 
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.kPrimary.withValues(alpha: 0.2),
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
              onSubmitted: (val) {
                if (val.trim().isNotEmpty) {
                  onSearch();
                }
              },
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: '경기도 성남시 분당구 중앙공원로 54',
                hintStyle: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[400],
                ),
              ),
              style: const TextStyle(
                fontSize: 18,
                color: AppColors.kTextPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.kPrimary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.search, color: Colors.white),
              onPressed: onSearch,
            ),
          ),
        ],
      ),
    );
  }
}
```

**Step 2: home_page.dart에서 사용**
```dart
// lib/screens/home_page.dart
import 'home_page/widgets/address_search_section.dart';

// Line 930-987 부분을 교체
AddressSearchSection(
  controller: _controller,
  queryAddress: queryAddress,
  onSearch: () {
    if (queryAddress.trim().isNotEmpty) {
      searchRoadAddress(queryAddress.trim(), page: 1);
    }
  },
  onChanged: (val) => setState(() => queryAddress = val),
),
```

**분리할 위젯 순서:**
1. ✅ AddressSearchSection (검색창)
2. ✅ SelectedAddressCard (선택된 주소)
3. ✅ DetailAddressInput (상세주소) - 이미 별도 클래스
4. ✅ AptInfoSection (아파트 정보)
5. ✅ RegisterResultCard (등기부등본)

⏱️ **소요 시간:** 1일 (위젯 5개 분리)  
💡 **난이도:** ⭐⭐⭐☆☆ (중간)  
🎯 **효과:** 코드 가독성 대폭 향상, 재사용 가능

---

### Phase 2: 디버그 로그 정리 (2시간)

```dart
// 과도한 디버그 로그 제거
// lib/screens/home_page.dart

// 삭제할 섹션들:
// Line 654-664: ═══════ 장식 로그
// Line 618-740: 🔍 [DEBUG] 로그들
// Line 428-453: 🔍 [DEBUG] 로그들

// 핵심 에러 로그만 유지
print('❌ 저장 중 오류 발생: $e'); // 유지
print('✅ 부동산 데이터 저장 성공'); // 유지
```

⏱️ **소요 시간:** 2시간  
💡 **난이도:** ⭐☆☆☆☆ (쉬움)

---

## ⭐ 우선순위 8: 사용하지 않는 코드 제거 (1시간)

### 찾기 및 제거

```bash
# 1. 사용하지 않는 메서드 찾기
flutter analyze | grep "unused_element"

# 결과:
# - _getSampleProperties (house_management_page.dart)
# - _buildPropertyListTab
# - _buildRentalStatCard
# - _buildTenantList
# - _buildContractList
# - _buildRepairHistoryList
# - _showAddTenantDialog
# - _showRepairRequestDialog
```

```dart
// lib/screens/propertyMgmt/house_management_page.dart
// Line 138, 225, 473, 506, 595, 671, 771, 947

// 삭제 또는 주석 처리
/*
List<Map<String, dynamic>> _getSampleProperties() {
  // ... 향후 사용 예정
}
*/
```

⏱️ **소요 시간:** 1시간  
💡 **난이도:** ⭐☆☆☆☆ (매우 쉬움)  
🎯 **효과:** 코드 정리, 파일 크기 감소

---

## ⭐ 우선순위 9: deprecated 경고 수정 (1시간)

### withOpacity → withValues 변경

```bash
# 찾기
grep -rn "withOpacity" lib/screens/

# 자동 변경
```

```dart
// Before
color: Colors.blue.withOpacity(0.3)

// After
color: Colors.blue.withValues(alpha: 0.3)
```

**일괄 변경 (VSCode):**
1. Ctrl+H (찾기 및 바꾸기)
2. 찾기: `withOpacity\(([0-9.]+)\)`
3. 바꾸기: `withValues(alpha: $1)`
4. 정규식 모드 활성화
5. 모두 바꾸기

⏱️ **소요 시간:** 30분-1시간  
💡 **난이도:** ⭐☆☆☆☆ (쉬움)

---

# 📋 즉시 시작 가능한 작업 정리

## 쉬운 것부터 (1-2시간 안에 완료)

### 1️⃣ const 위젯 자동 적용 ⭐⭐⭐⭐⭐
```bash
dart fix --apply
```
⏱️ 10분 | 💡 매우 쉬움 | 🎯 즉시 성능 개선

### 2️⃣ 빌드 최적화 ⭐⭐⭐⭐⭐
```bash
flutter build apk --release --split-per-abi
```
⏱️ 30분 | 💡 쉬움 | 🎯 APK 크기 50% 감소

### 3️⃣ 사용하지 않는 코드 제거 ⭐⭐⭐⭐
```dart
// house_management_page.dart에서 8개 메서드 제거
```
⏱️ 1시간 | 💡 매우 쉬움 | 🎯 코드 정리

### 4️⃣ deprecated 경고 수정 ⭐⭐⭐⭐
```dart
withOpacity → withValues (일괄 변경)
```
⏱️ 30분-1시간 | 💡 쉬움 | 🎯 경고 제거

### 5️⃣ 디버그 로그 제거 ⭐⭐⭐
```dart
// home_page.dart에서 100개 이상 print 제거
```
⏱️ 1시간 | 💡 쉬움 | 🎯 프로덕션 준비

**소계:** 3-4시간에 5개 작업 완료 가능

---

## 중간 난이도 (반나절-1일)

### 6️⃣ API 캐싱 구현 ⭐⭐⭐
```dart
// CacheService 클래스 + 적용
```
⏱️ 2-3시간 | 💡 쉬움 | 🎯 네트워크 호출 50% 감소

### 7️⃣ Unit Test 10개 ⭐⭐⭐
```dart
// address_parser, owner_parser, models
```
⏱️ 3-4시간 | 💡 쉬움 | 🎯 코드 안정성

### 8️⃣ Widget Test 5개 ⭐⭐⭐
```dart
// ErrorMessage, DetailAddressInput 등
```
⏱️ 2-3시간 | 💡 쉬움 | 🎯 UI 안정성

**소계:** 1일에 3개 작업 완료 가능

---

## 시간이 좀 걸리는 것 (2-3일)

### 9️⃣ home_page.dart 위젯 분리 ⭐⭐⭐⭐
```
2,550줄 → 5개 파일로 분리
```
⏱️ 1-2일 | 💡 중간 | 🎯 대폭 개선

### 🔟 Integration Test 3개 ⭐⭐⭐⭐
```dart
// E2E 시나리오
```
⏱️ 1-2일 | 💡 중간 | 🎯 전체 플로우 검증

**소계:** 2-3일

---

# 🎯 추천 작업 순서

## 오늘 (3-4시간)
```
1. const 위젯 자동 적용 (10분) ✅
2. 빌드 최적화 (30분) ✅
3. deprecated 수정 (1시간) ✅
4. 디버그 로그 제거 (1시간) ✅
5. 사용 안하는 코드 제거 (1시간) ✅
```
→ **즉시 성능 10-15% 향상!**

## 내일 (1일)
```
6. API 캐싱 구현 (3시간) ✅
7. Unit Test 10개 (4시간) ✅
```
→ **성능 + 안정성 확보**

## 모레 (1일)
```
8. Widget Test 5개 (3시간) ✅
9. home_page 위젯 분리 시작 (5시간) ✅
```
→ **코드 품질 대폭 향상**

## 3-4일차 (2일)
```
10. home_page 위젯 분리 완료 ✅
11. Integration Test 3개 ✅
```
→ **리팩토링 완료**

---

# 📊 예상 효과

## 오늘만 작업해도
```
성능: 70% → 80% (+10%)
전체: 51% → 58% (+7%)
```

## 4일 작업 후
```
성능: 70% → 85% (+15%)
테스트: 20% → 70% (+50%)
전체: 51% → 73% (+22%)
```

---

# ✅ 바로 시작 가능한 작업 체크리스트

## 쉬운 작업 (오늘 완료 가능)
- [ ] const 위젯 자동 적용 (10분)
- [ ] 빌드 최적화 (30분)
- [ ] deprecated 수정 (1시간)
- [ ] 디버그 로그 제거 (1시간)
- [ ] 사용 안하는 코드 제거 (1시간)

## 중간 작업 (1-2일)
- [ ] API 캐싱 구현 (3시간)
- [ ] Unit Test 10개 (4시간)
- [ ] Widget Test 5개 (3시간)

## 큰 작업 (2-3일)
- [ ] home_page.dart 리팩토링 (2일)
- [ ] Integration Test (1일)

---

**어떤 작업부터 시작하시겠습니까?** 🚀

제안: **오늘의 5개 쉬운 작업부터 시작**하면 3-4시간 만에 10% 성능 향상 가능합니다!
