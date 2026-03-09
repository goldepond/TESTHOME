import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:property/firebase_options.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/screens/admin/admin_dashboard.dart';
import 'package:property/utils/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables (.env 파일이 있으면 로드, 없으면 무시, 웹에서는 건너뜀)
  if (!kIsWeb) {
    try {
      await dotenv.load();
    } catch (e) {
      Logger.warning(
        '.env 파일을 로드할 수 없습니다',
        metadata: {'error': e.toString()},
      );
    }
  }

  // Firebase 초기화
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      Logger.info('Firebase 초기화 성공 (관리자 앱)');
    }
  } catch (e, stackTrace) {
    Logger.error(
      'Firebase 초기화 실패 (관리자 앱)',
      error: e,
      stackTrace: stackTrace,
      context: 'firebase_initialization_admin',
    );
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
        primaryColor: AirbnbColors.primary,
        scaffoldBackgroundColor: AirbnbColors.surface,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AirbnbColors.primary,
          primary: AirbnbColors.primary,
          secondary: AirbnbColors.success,
          surface: AirbnbColors.surface,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AirbnbColors.background,
          foregroundColor: AirbnbColors.textPrimary,
          elevation: 0,
          shadowColor: Colors.black.withValues(alpha: 0.08),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AirbnbColors.textPrimary,
            foregroundColor: AirbnbColors.textWhite,
            elevation: 2,
            shadowColor: AirbnbColors.textPrimary.withValues(alpha: 0.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
        useMaterial3: true,
        fontFamily: 'NotoSansKR',
      ),
      home: const AdminLoginPage(),
    );
  }
}

/// 관리자 이메일/비밀번호 로그인 페이지
class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
  }

  /// 기존 세션이 있으면 관리자 클레임 확인 후 대시보드 이동
  Future<void> _checkExistingSession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() => _isLoading = true);
      try {
        final idTokenResult = await user.getIdTokenResult(true);
        if (idTokenResult.claims?['admin'] == true) {
          if (mounted) _navigateToDashboard(user);
          return;
        }
      } catch (_) {}
      setState(() => _isLoading = false);
    }
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = '이메일과 비밀번호를 입력해주세요.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        setState(() {
          _isLoading = false;
          _error = '로그인에 실패했습니다.';
        });
        return;
      }

      // Custom Claims에서 admin 권한 확인
      final idTokenResult = await user.getIdTokenResult(true);
      if (idTokenResult.claims?['admin'] != true) {
        await FirebaseAuth.instance.signOut();
        setState(() {
          _isLoading = false;
          _error = '관리자 권한이 없는 계정입니다.';
        });
        return;
      }

      if (mounted) _navigateToDashboard(user);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
        _error = switch (e.code) {
          'user-not-found' => '등록되지 않은 이메일입니다.',
          'wrong-password' => '비밀번호가 올바르지 않습니다.',
          'invalid-email' => '유효하지 않은 이메일 형식입니다.',
          'too-many-requests' => '너무 많은 시도가 있었습니다. 잠시 후 다시 시도해주세요.',
          _ => '로그인 실패: ${e.message}',
        };
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = '로그인 중 오류가 발생했습니다.';
      });
    }
  }

  void _navigateToDashboard(User user) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => AdminDashboard(
          userId: user.uid,
          userName: user.email ?? '관리자',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('관리자 인증 확인 중...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.admin_panel_settings, size: 64, color: AirbnbColors.primary),
                const SizedBox(height: 16),
                const Text(
                  'MyHome 관리자',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: '이메일',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: '비밀번호',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outlined),
                  ),
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _login(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: AirbnbColors.error, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _login,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text('로그인', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
