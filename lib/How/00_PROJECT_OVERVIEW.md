# 00. 프로젝트 개요 및 아키텍처

> 작성일: 2025-01-XX  
> 파일: `lib/HOW/00_PROJECT_OVERVIEW.md`

---

## 📋 프로젝트 소개

### 프로젝트명
**MyHome (마이홈)** - 쉽고 빠른 부동산 상담 플랫폼

### 핵심 가치 제안
```
부동산 소유자가 주소만 입력하면
→ 등기부등본, 아파트 정보, 근처 공인중개사를 한번에 확인
→ 비대면으로 견적 요청
→ 여러 중개사 동시 비교
→ 계약서 작성까지 원스톱 서비스
```

---

## 🏗️ 아키텍처 개요

### 전체 구조

```
┌─────────────────────────────────────────┐
│           Flutter App (Web)             │
├─────────────────────────────────────────┤
│                                         │
│  ┌──────────────┐    ┌──────────────┐   │
│  │   UI Layer   │    │ Service Layer│   │
│  │   (Screens)  │◄───┤  (API Calls) │   │
│  └──────────────┘    └──────────────┘   │
│         │                     │         │
│         └───────────┬─────────┘         │
│                     │                   │
│              ┌──────▼──────┐            │
│              │   Models    │            │
│              │ (Data Layer)│            │
│              └──────┬──────┘            │
│                     │                   │
└─────────────────────┼───────────────────┘
                      │
         ┌────────────┼────────────┐
         │            │            │
    ┌────▼─────┐ ┌────▼────┐ ┌────▼────┐
    │ Firebase │ │ External│ │ External│
    │          │ │   APIs  │ │   APIs  │
    │ Auth +   │ │ (Juso,  │ │ (CODEF, │
    │ Firestore│ │ VWorld) │ │ Data.go)│
    └──────────┘ └─────────┘ └─────────┘
```

---

## 📁 프로젝트 구조

### 파일 구조

```
lib/
├── main.dart                           # 앱 진입점, 라우팅 설정
│
├── screens/                            # 화면 컴포넌트
│   ├── home_page.dart                 # 내집팔기 (주소 검색, 부동산 조회)
│   ├── broker_list_page.dart          # 공인중개사 찾기 및 견적 요청
│   ├── quote_history_page.dart        # 견적 이력 확인
│   ├── quote_comparison_page.dart     # 견적 비교
│   ├── main_page.dart                 # 메인 네비게이션
│   ├── login_page.dart                # 로그인
│   ├── signup_page.dart               # 회원가입
│   ├── admin/                         # 관리자 페이지
│   │   ├── admin_dashboard.dart
│   │   ├── admin_quote_requests_page.dart
│   │   ├── admin_broker_management.dart
│   │   └── admin_property_management.dart
│   ├── broker/                        # 중개사 페이지
│   │   ├── broker_signup_page.dart
│   │   ├── broker_login_page.dart
│   │   └── broker_dashboard_page.dart
│   └── inquiry/                       # 문의 답변 페이지
│       └── broker_inquiry_response_page.dart
│
├── api_request/                        # API 서비스 레이어
│   ├── firebase_service.dart          # Firebase 통합 서비스
│   ├── address_service.dart           # 주소 검색 (Juso API)
│   ├── vworld_service.dart            # 좌표 변환, 토지 정보
│   ├── broker_service.dart            # 공인중개사 검색
│   ├── register_service.dart          # 등기부등본 조회 (CODEF API)
│   ├── apt_info_service.dart          # 아파트 정보 조회
│   └── seoul_broker_service.dart     # 서울시 공인중개사 API (검증 포함)
│
├── models/                             # 데이터 모델
│   ├── quote_request.dart             # 견적문의 모델
│   ├── property.dart                  # 부동산 모델
│
├── utils/                              # 유틸리티
│   ├── address_parser.dart            # 주소 파싱
│   ├── owner_parser.dart              # 소유자 정보 추출
│   ├── current_state_parser.dart     # 등기부등본 파싱
│   └── admin_page_loader_actual.dart  # 관리자 페이지 로더
│
├── widgets/                            # 재사용 가능한 위젯
│   ├── common_design_system.dart
│   ├── loading_overlay.dart
│   └── home_logo_button.dart
│
└── constants/                           # 상수
    └── app_constants.dart             # API 키, 색상 등
```

---

## 🔄 데이터 흐름

### 1. 사용자 인증 흐름

```
사용자 입력 (이메일/비밀번호)
    ↓
Firebase Authentication
    ↓
Firestore에서 사용자 정보 조회
    ↓
AuthGate에서 세션 관리
    ↓
MainPage로 이동
```

**코드 위치:**
```138:205:lib/main.dart
/// Firebase Auth 상태를 구독하여 새로고침 시에도 로그인 유지
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  Map<String, dynamic>? _cachedUserData;
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        
        if (snapshot.connectionState == ConnectionState.waiting && user == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        if (user == null) {
          _cachedUserData = null;
          return const MainPage(userId: '', userName: '');
        }
        
        // 캐시된 데이터가 있고 같은 사용자면 즉시 반환
        if (_cachedUserData != null && _cachedUserData!['uid'] == user.uid) {
          return MainPage(
            key: ValueKey('main_${_cachedUserData!['uid']}'),
            userId: _cachedUserData!['uid'],
            userName: _cachedUserData!['name'],
          );
        }
        
        // Firestore에서 사용자 표시 이름 로드
        return FutureBuilder<Map<String, dynamic>?>(
          key: ValueKey(user.uid),
          future: FirebaseService().getUser(user.uid),
          builder: (context, userSnap) {
            if (userSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            
            final data = userSnap.data;
            final userName = data != null
                ? (data['name'] as String? ?? data['id'] as String? ?? user.email?.split('@').first ?? '사용자')
                : (user.email?.split('@').first ?? '사용자');
            
            // 캐시 업데이트
            _cachedUserData = {'uid': user.uid, 'name': userName};
            
            return MainPage(
              key: ValueKey('main_${user.uid}'),
              userId: user.uid,
              userName: userName,
            );
          },
        );
      },
    );
  }
}
```

---

### 2. 주소 검색 및 부동산 정보 조회 흐름

```
사용자 입력 (주소)
    ↓
디바운싱 (0.5초)
    ↓
Juso API 호출 (AddressService)
    ↓
결과 표시 및 선택
    ↓
VWorld API 호출 (좌표 변환)
    ↓
AptInfoService 호출 (아파트 정보)
    ↓
(선택적) RegisterService 호출 (등기부등본)
    ↓
BrokerListPage로 이동
```

**코드 위치:**
```474:550:lib/screens/home_page.dart
// 도로명 주소 검색 함수 (AddressService 사용)
Future<void> searchRoadAddress(String keyword, {int page = 1, bool skipDebounce = false}) async {
  // 디바운싱 (페이지네이션은 제외)
  if (!skipDebounce && page == 1) {
    // 중복 요청 방지
    if (_lastSearchKeyword == keyword.trim() && isSearchingRoadAddr) {
      return;
    }
    
    // 이전 타이머 취소
    _addressSearchDebounceTimer?.cancel();
    
    // 디바운싱 적용
    _lastSearchKeyword = keyword.trim();
    _addressSearchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performAddressSearch(keyword, page: page);
    });
    return;
  }
  
  // 페이지네이션이나 즉시 검색이 필요한 경우 바로 실행
  await _performAddressSearch(keyword, page: page);
}

// 실제 주소 검색 수행
Future<void> _performAddressSearch(String keyword, {int page = 1}) async {
  setState(() {
    isSearchingRoadAddr = true;
  });
  
  try {
    final result = await AddressService.instance.searchRoadAddress(keyword, page: page);
    
    if (mounted) {
      setState(() {
        if (page == 1) {
          fullAddrAPIDataList = result.fullData;
          roadAddressList = result.addresses;
        } else {
          // 페이지네이션: 기존 목록에 추가
          fullAddrAPIDataList.addAll(result.fullData);
          roadAddressList.addAll(result.addresses);
        }
        totalCount = result.totalCount;
        currentPage = page;
      });
      
      // 첫 번째 결과 자동 선택
      if (result.addresses.isNotEmpty && page == 1) {
        final firstAddr = result.addresses.first;
        final firstData = result.fullData.first;
        setState(() {
          selectedRoadAddress = firstAddr;
          selectedFullAddrAPIData = firstData;
          selectedFullAddress = firstAddr;
        });
        
        // 자동으로 VWorld 데이터 로드
        _loadVWorldData(firstAddr);
        
        // 단지 정보도 자동으로 로드
        _loadAptInfoFromAddress(firstAddr, fullAddrAPIData: firstData);
      }
    }
  } finally {
    setState(() {
      isSearchingRoadAddr = false;
    });
  }
}
```

---

### 3. 공인중개사 찾기 및 견적 요청 흐름

```
BrokerListPage 진입 (좌표 전달)
    ↓
BrokerService.searchNearbyBrokers() 호출
    ↓
VWorld API + 서울시 API 병합
    ↓
필터링 및 정렬
    ↓
사용자 선택 (개별 또는 다중)
    ↓
견적 요청 작성 (QuoteRequest)
    ↓
Firebase에 저장 (FirebaseService.saveQuoteRequest)
    ↓
고유 링크 ID 생성
    ↓
관리자에게 알림 (수동 처리)
```

**코드 위치:**
```156:189:lib/screens/broker_list_page.dart
/// 공인중개사 검색
Future<void> _searchBrokers() async {
  if (!mounted) return;

  setState(() {
    isLoading = true;
    error = null;
  });

  try {
    final searchResults = await BrokerService.searchNearbyBrokers(
      latitude: widget.latitude,
      longitude: widget.longitude,
      radiusMeters: 1000, // 1km 반경
    );

    if (!mounted) return; // 위젯이 dispose된 경우 setState 호출 방지

    setState(() {
      propertyBrokers = searchResults;
      _sortBySystemRegNo(propertyBrokers);
      brokers = List<Broker>.from(propertyBrokers);
      filteredBrokers = List<Broker>.from(brokers); // 초기에는 정렬 반영된 전체
      isLoading = false;
      _resetPagination();
    });
  } catch (e) {
    if (!mounted) return; // 위젯이 dispose된 경우 setState 호출 방지

    setState(() {
      error = '공인중개사 정보를 불러오는 중 오류가 발생했습니다.';
      isLoading = false;
    });
  }
}
```

---

### 4. 견적 답변 시스템 흐름

```
관리자가 이메일 전송 또는 링크 공유
    ↓
중개사가 링크 클릭 (/inquiry/{linkId})
    ↓
BrokerInquiryResponsePage 로드
    ↓
FirebaseService.getQuoteRequestByLinkId() 호출
    ↓
문의 정보 표시
    ↓
중개사가 답변 작성
    ↓
FirebaseService.updateQuoteRequestAnswer() 호출
    ↓
Firestore 업데이트
    ↓
판매자가 실시간으로 확인 가능 (StreamBuilder)
```

**코드 위치:**
```40:70:lib/screens/inquiry/broker_inquiry_response_page.dart
Future<void> _loadInquiry() async {
  setState(() => _isLoading = true);

  try {
    final data = await _firebaseService.getQuoteRequestByLinkId(widget.linkId);
    
    if (data == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    setState(() {
      _inquiryData = data;
      _isLoading = false;
      // 이미 답변이 있으면 표시하고 수정 가능하도록
      if (data['brokerAnswer'] != null && data['brokerAnswer'].toString().isNotEmpty) {
        _hasExistingAnswer = true;
        _answerController.text = data['brokerAnswer'];
      }
    });
  } catch (e) {
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('문의 정보를 불러오는데 실패했습니다: $e')),
      );
    }
  }
}
```

---

## 🔌 API 통합 구조

### 외부 API 목록

1. **Juso API** (행정안전부)
   - 용도: 도로명 주소 검색
   - 파일: `lib/api_request/address_service.dart`
   - 제한: 일일 10,000건

2. **VWorld API** (국토교통부)
   - 용도: 좌표 변환, 토지 정보, 공인중개사 검색
   - 파일: `lib/api_request/vworld_service.dart`
   - 제한: 일일 40,000건

3. **CODEF API**
   - 용도: 등기부등본 조회
   - 파일: `lib/api_request/register_service.dart`
   - 현재: 비활성화 (`isRegisterFeatureEnabled = false`)

4. **Data.go.kr API**
   - 용도: 아파트 단지 정보 조회
   - 파일: `lib/api_request/apt_info_service.dart`

5. **서울시 공개 API**
   - 용도: 공인중개사 상세 정보 (21개 필드), 등록번호 및 대표자명 검증
   - 파일: `lib/api_request/seoul_broker_service.dart`
   - 검증 기능: `validateBroker()` 메서드로 회원가입 시 검증

### Firebase 서비스 구조

**FirebaseService** (`lib/api_request/firebase_service.dart`)
- 모든 Firebase 작업을 중앙화
- Firestore 컬렉션:
  - `users` - 사용자 정보
  - `brokers` - 공인중개사 정보
  - `properties` - 부동산 정보
  - `quoteRequests` - 견적문의

---

## 🎯 핵심 비즈니스 로직

### 1. 견적 요청 시스템 (MVP 핵심)

**개별 요청:**
```1997:2011:lib/screens/broker_list_page.dart
void _requestQuote(Broker broker) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => _QuoteRequestFormPage(
        broker: broker,
        userName: widget.userName,
        userId: widget.userId ?? '',
        propertyAddress: widget.address, // 조회한 주소 전달
        propertyArea: widget.propertyArea, // 토지 면적 전달
      ),
      fullscreenDialog: true,
    ),
  );
}
```

**다중 요청 (MVP 핵심 기능):**
```2014:2044:lib/screens/broker_list_page.dart
/// 여러 공인중개사에게 일괄 견적 요청 (MVP 핵심 기능)
Future<void> _requestQuoteToMultiple() async {
  if (_selectedBrokerIds.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('견적을 요청할 공인중개사를 선택해주세요.'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }
  
  // 선택한 중개사 목록 가져오기
  final selectedBrokers = filteredBrokers.where((broker) {
    return _selectedBrokerIds.contains(broker.systemRegNo);
  }).toList();
  
  // 일괄 견적 요청 다이얼로그 표시
  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _MultipleQuoteRequestDialog(
      brokerCount: selectedBrokers.length,
      address: widget.address,
      propertyArea: widget.propertyArea,
    ),
  );
  
  if (result == null) return; // 취소됨
  
  // 선택한 모든 중개사에게 동일한 정보로 견적 요청
  int successCount = 0;
```

---

### 2. 실시간 데이터 동기화

**StreamBuilder 사용:**
```31:100:lib/screens/admin/admin_quote_requests_page.dart
body: StreamBuilder<List<QuoteRequest>>(
  stream: _firebaseService.getAllQuoteRequests(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.kBrown),
            ),
            SizedBox(height: 16),
            Text(
              '견적문의를 불러오는 중...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    if (snapshot.hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('오류: ${snapshot.error}'),
          ],
        ),
      );
    }

    final quoteRequests = snapshot.data ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 통계 카드
          _buildStatsCards(quoteRequests),
          
          const SizedBox(height: 24),
          
          // 견적문의 목록
          const Text(
            '💬 견적문의 관리',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.kDarkBrown,
            ),
          ),
          const SizedBox(height: 16),
          
          if (quoteRequests.isEmpty)
            _buildEmptyState()
          else
            ...quoteRequests.map((request) => _buildQuoteRequestCard(request)),
        ],
      ),
    );
  },
),
```

---

## 🔐 보안 아키텍처

### 현재 상태

1. **Firebase Authentication**
   - 사용자 인증 (이메일/비밀번호)
   - 자동 세션 관리
   - 비밀번호 재설정

2. **Firestore Security Rules**
   - 파일: `firestore.rules`
   - 사용자별 데이터 접근 제한
   - 인증 확인

3. **API 키 관리**
   - 현재: 하드코딩 (`lib/constants/app_constants.dart`)
   - 향후: 환경 변수 또는 Firebase Remote Config

4. **관리자 페이지 접근**
   - 현재: URL 기반 접근 (`/admin-panel-myhome-2024`)
   - 향후: 인증 추가 예정

---

## 📊 데이터베이스 구조

### Firestore 컬렉션

#### 1. `users` 컬렉션
```dart
{
  uid: String,              // Firebase Auth UID
  id: String,               // 사용자 ID
  name: String,             // 이름
  email: String,            // 이메일
  phone: String?,           // 휴대폰 번호
  role: String,             // 'user' | 'admin'
  createdAt: Timestamp,      // 가입일
  updatedAt: Timestamp,     // 수정일
}
```

#### 2. `quoteRequests` 컬렉션
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

#### 3. `brokers` 컬렉션
```dart
{
  registrationNumber: String,    // 등록번호
  ownerName: String,             // 대표자명
  businessName: String,          // 사무소명
  phoneNumber: String,          // 전화번호
  roadAddress: String,          // 도로명 주소
  jibunAddress: String,         // 지번 주소
  // ... 기타 필드
}
```

---

## 🚀 배포 구조

### 현재 배포 방식
- **플랫폼:** GitHub Pages
- **CI/CD:** GitHub Actions
- **빌드:** `flutter build web --release --base-href "/TESTHOME/"`

### 라우팅 구조
```104:132:lib/main.dart
// URL 기반 라우팅 추가
initialRoute: '/',
onGenerateRoute: (settings) {
  // 관리자 페이지 라우팅 (조건부 로드)
  // 관리자 페이지를 외부로 분리할 때는 AdminPageLoaderActual 파일을 삭제하면
  // 자동으로 관리자 기능이 비활성화됩니다.
  try {
    final adminRoute = AdminPageLoaderActual.createAdminRoute(settings.name);
    if (adminRoute != null) {
      return adminRoute;
    }
  } catch (e) {
    // 관리자 페이지 파일이 없는 경우 (외부로 분리된 경우)
    print('⚠️ [Main] 관리자 페이지를 찾을 수 없습니다. 외부로 분리되었을 수 있습니다.');
  }
  
  // 공인중개사용 답변 페이지 (/inquiry/:id)
  if (settings.name != null && settings.name!.startsWith('/inquiry/')) {
    final linkId = settings.name!.substring('/inquiry/'.length);
    return MaterialPageRoute(
      builder: (context) => BrokerInquiryResponsePage(linkId: linkId),
    );
  }
  
  // 기본 홈 페이지: Auth 게이트 사용
  return MaterialPageRoute(
    builder: (context) => const _AuthGate(),
  );
},
```

---

## 📝 다음 문서

다음 문서로 계속 읽어보세요:

👉 **[01_AUTHENTICATION_SYSTEM.md](01_AUTHENTICATION_SYSTEM.md)** - 인증 시스템 상세 설명

