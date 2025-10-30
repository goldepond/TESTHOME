import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'constants/app_constants.dart';
import 'screens/main_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'api_request/firebase_service.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/inquiry/broker_inquiry_response_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase 초기화
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } else {
      print('Firebase already initialized, using existing app');
    }
  } catch (e) {
    print('Firebase initialization error (handled): $e');
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
        // 관리자 페이지 직접 접근 (로그인 불필요)
        // 보안을 위한 복잡한 URL 사용
        if (settings.name == '/admin-panel-myhome-2024') {
          return MaterialPageRoute(
            builder: (context) => const AdminDashboard(
              userId: 'admin',
              userName: '관리자',
            ),
          );
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
      home: const _AuthGate(),
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
  Map<String, String>? _cachedUser;

  @override
  void initState() {
    super.initState();
    // 초기 로그인 상태 체크
    FirebaseAuth.instance.currentUser?.then((user) {
      if (user != null && !mounted) return;
      _checkAndCacheUser();
    });
  }

  Future<void> _checkAndCacheUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !_cachedUser.containsKey(user.uid)) {
      final data = await FirebaseService().getUser(user.uid);
      if (data != null && mounted) {
        setState(() {
          _cachedUser = {
            'uid': user.uid,
            'name': data['name'] ?? data['id'] ?? user.email?.split('@').first ?? '사용자',
          };
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
        if (snapshot.connectionState == ConnectionState.waiting && user == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (user == null) {
          _cachedUser = null;
          return const MainPage(userId: '', userName: '');
        }
        // Firestore에서 사용자 표시 이름 로드
        return FutureBuilder<Map<String, dynamic>?>(
          key: ValueKey(user.uid), // uid 변경 시 재빌드
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
            return MainPage(userId: user.uid, userName: userName);
          },
        );
      },
    );
  }
}


