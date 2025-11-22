import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'constants/app_constants.dart';
import 'screens/admin/admin_dashboard.dart';
import 'api_request/firebase_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
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

  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyHome 관리자',
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
        useMaterial3: true,
        fontFamily: 'NotoSansKR',
      ),
      // 관리자 앱은 루트('/')로 접속하면 바로 관리자 인증 게이트로 연결
      home: const AdminAuthGate(),
    );
  }
}

/// 관리자 로그인 확인 및 대시보드 연결
class AdminAuthGate extends StatefulWidget {
  const AdminAuthGate({super.key});

  @override
  State<AdminAuthGate> createState() => _AdminAuthGateState();
}

class _AdminAuthGateState extends State<AdminAuthGate> {
  bool _isInitializingAnonymous = false;

  @override
  void initState() {
    super.initState();
    _initializeAnonymousUser();
  }

  Future<void> _initializeAnonymousUser() async {
    // 이미 로그인된 사용자가 있으면 패스
    if (FirebaseAuth.instance.currentUser != null) {
      return;
    }
    
    setState(() {
      _isInitializingAnonymous = true;
    });
    
    try {
      // 임시: 관리자도 일단 익명 로그인 등을 사용한다고 가정
      // 실제 운영 시에는 이메일/비밀번호 로그인 폼으로 대체 권장
      await FirebaseService().signInAnonymously();
    } catch (e) {
      debugPrint('관리자 로그인 실패: $e');
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
        if (snapshot.connectionState == ConnectionState.waiting || _isInitializingAnonymous) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          // 로그인 성공 -> 관리자 대시보드
          return AdminDashboard(
            userId: snapshot.data!.uid,
            userName: snapshot.data!.email ?? '관리자',
          );
        }

        // 로그인 실패 또는 로그아웃 상태
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('관리자 접근 권한이 필요합니다.'),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _initializeAnonymousUser,
                  child: const Text('로그인 재시도'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

