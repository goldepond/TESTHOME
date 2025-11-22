import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'constants/app_constants.dart';
import 'screens/main_page.dart';
import 'screens/broker/broker_dashboard_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'api_request/firebase_service.dart';
import 'screens/inquiry/broker_inquiry_response_page.dart';
import 'widgets/retry_view.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await dotenv.load(fileName: ".env");
  
  // Firebase 초기화
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (_) {
    // Firebase 초기화 실패는 무시 (이미 초기화된 경우 등)
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyHome - 쉽고 빠른 부동산 상담', 
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppColors.kPrimary,
        scaffoldBackgroundColor: AppColors.kBackground,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.kPrimary,
          primary: AppColors.kPrimary,
          secondary: AppColors.kSecondary,
          surface: AppColors.kSurface,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.kPrimary,
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.kPrimary,
            foregroundColor: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.kPrimary,
            side: BorderSide(color: AppColors.kPrimary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.kPrimary,
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: AppColors.kPrimary,
          foregroundColor: Colors.white,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.kPrimary, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
        ),
        useMaterial3: true,
        fontFamily: 'NotoSansKR',
      ),
      // URL 기반 라우팅
      initialRoute: '/',
      onGenerateRoute: (settings) {
        
        // 공인중개사용 답변 페이지 (/inquiry/:id)
        final uri = Uri.parse(settings.name ?? '/');
        if (uri.pathSegments.length == 2 && uri.pathSegments.first == 'inquiry') {
          final linkId = uri.pathSegments[1];
          return MaterialPageRoute(
            builder: (context) => BrokerInquiryResponsePage(linkId: linkId),
          );
        }
        
        // 기본 홈 페이지: Auth 게이트 사용
        return MaterialPageRoute(
          builder: (context) => const _AuthGate(),
        );
      },
    );
  }
}

/// Firebase Auth 상태를 구독하여 새로고침 시에도 로그인 유지
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  Map<String, dynamic>? _cachedUserData;
  bool _isInitializingAnonymous = false;
  
  @override
  void initState() {
    super.initState();
    _initializeAnonymousUser();
  }
  
  Future<void> _initializeAnonymousUser() async {
    // 이미 로그인된 사용자가 있으면 익명 로그인은 시도하지 않는다.
    if (FirebaseAuth.instance.currentUser != null) {
      return;
    }
    setState(() {
      _isInitializingAnonymous = true;
    });
    try {
      await FirebaseService().signInAnonymously();
    } finally {
      if (mounted) {
        setState(() {
          _isInitializingAnonymous = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        
        if ((snapshot.connectionState == ConnectionState.waiting || _isInitializingAnonymous) && user == null) {
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
          // 브로커 계정인 경우 공인중개사 대시보드로 진입
          if (_cachedUserData!['userType'] == 'broker' &&
              _cachedUserData!['brokerData'] != null) {
            final brokerId =
                _cachedUserData!['brokerId'] ?? _cachedUserData!['uid'];
            final brokerName = _cachedUserData!['name'] ?? '공인중개사';
            return BrokerDashboardPage(
              brokerId: brokerId,
              brokerName: brokerName,
              brokerData: _cachedUserData!['brokerData'],
            );
          }

          // 일반 사용자 기본 페이지
          return MainPage(
            key: ValueKey('main_${_cachedUserData!['uid']}'),
            userId: _cachedUserData!['uid'],
            userName: _cachedUserData!['name'],
          );
        }

        // Firestore / brokers 컬렉션에서 사용자 유형 및 표시 이름 로드
        return FutureBuilder<Map<String, dynamic>?>(
          key: ValueKey(user.uid),
          future: () async {
            final service = FirebaseService();

            // 1) 공인중개사 컬렉션 먼저 확인
            final brokerData = await service.getBroker(user.uid);
            if (brokerData != null) {
              final brokerName = (brokerData['ownerName'] as String?) ??
                  (brokerData['businessName'] as String?) ??
                  '공인중개사';
              final brokerId =
                  (brokerData['brokerId'] as String?) ?? user.uid;

              return <String, dynamic>{
                'uid': user.uid,
                'name': brokerName,
                'userType': 'broker',
                'brokerId': brokerId,
                'brokerData': brokerData,
              };
            }

            // 2) 일반 사용자 컬렉션 조회
            final data = await service.getUser(user.uid);
            final userName = data != null
                ? (data['name'] as String? ??
                    data['id'] as String? ??
                    user.email?.split('@').first ??
                    '사용자')
                : (user.email?.split('@').first ?? '사용자');

            return <String, dynamic>{
              'uid': user.uid,
              'name': userName,
              'userType': 'user',
              'userData': data,
            };
          }(),
          builder: (context, userSnap) {
            if (userSnap.hasError) {
              return Scaffold(
                body: RetryView(
                  message: '사용자 정보를 불러오지 못했습니다.\n네트워크 상태를 확인한 뒤 다시 시도해주세요.',
                  onRetry: () {
                    // 단순 재빌드로 Future 재호출
                    (context as Element).markNeedsBuild();
                  },
                ),
              );
            }
            if (userSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final profile = userSnap.data!;

            // 캐시 업데이트 (브로커 / 일반 사용자 공통)
            _cachedUserData = profile;

            // 브로커 계정이면 공인중개사 대시보드로 이동
            if (profile['userType'] == 'broker' &&
                profile['brokerData'] != null) {
              final brokerId = profile['brokerId'] ?? profile['uid'];
              final brokerName = profile['name'] ?? '공인중개사';
              return BrokerDashboardPage(
                brokerId: brokerId,
                brokerName: brokerName,
                brokerData: profile['brokerData'],
              );
            }

            // 기본: 일반 사용자 메인 페이지
            return MainPage(
              key: ValueKey('main_${user.uid}'),
              userId: profile['uid'] as String,
              userName: profile['name'] as String,
            );
          },
        );
      },
    );
  }
}
