import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'constants/app_constants.dart';
import 'screens/main_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'api_request/firebase_service.dart';
import 'screens/inquiry/broker_inquiry_response_page.dart';
import 'widgets/retry_view.dart';
// 관리자 페이지는 조건부로 로드 (외부 분리 가능)
// 관리자 페이지를 외부로 분리할 때는 아래 import를 제거하고
// admin_page_loader_actual.dart 파일을 삭제하면 됩니다.
import 'utils/admin_page_loader_actual.dart' show AdminPageLoaderActual;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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
        }
        
        // 공인중개사용 답변 페이지 (/inquiry/:id) - 안전한 경로 파싱
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
      // home은 사용하지 않음: initialRoute + onGenerateRoute로 일원화
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


