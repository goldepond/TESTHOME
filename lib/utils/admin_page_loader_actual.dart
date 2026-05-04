import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/admin/admin_dashboard.dart';
import '../screens/admin/admin_appeals_page.dart';
import '../screens/admin/admin_metrics_page.dart';
import '../screens/admin/admin_audit_log_page.dart';
import '../constants/app_constants.dart';

/// 관리자 페이지 로더
///
/// 이 파일을 삭제하면 관리자 페이지 기능이 자동으로 비활성화됩니다.
/// main.dart의 onGenerateRoute에서 조건부로 로드됩니다.
class AdminPageLoaderActual {
  /// 관리자 페이지 라우트 생성
  ///
  /// [routeName]이 `/admin-panel-myhome-2024`인 경우 관리자 페이지 라우트를 반환합니다.
  /// 그 외의 경우 null을 반환합니다.
  static Route? createAdminRoute(String? routeName) {
    if (routeName == null) {
      return null;
    }

    // 관리자 페이지 경로 확인
    final uri = Uri.parse(routeName);
    if (uri.path == '/admin-panel-myhome-2024' ||
        uri.pathSegments.contains('admin-panel-myhome-2024')) {
      return MaterialPageRoute(
        builder: (context) => const _AdminAuthGate(),
      );
    }

    // === Task 06: 알고리즘 투명성 직접 라우트 ===
    // 모두 동일한 _AdminAuthGate를 거쳐 인증 후 해당 페이지로 이동.
    if (uri.path == '/admin/appeals') {
      return MaterialPageRoute(
        builder: (context) => const _AdminAuthGate(target: _AdminTarget.appeals),
      );
    }
    if (uri.path == '/admin/metrics') {
      return MaterialPageRoute(
        builder: (context) => const _AdminAuthGate(target: _AdminTarget.metrics),
      );
    }
    if (uri.path == '/admin/audit') {
      return MaterialPageRoute(
        builder: (context) => const _AdminAuthGate(target: _AdminTarget.audit),
      );
    }

    return null;
  }
}

/// 인증 후 어떤 화면을 직접 표시할지.
enum _AdminTarget {
  dashboard,
  appeals,
  metrics,
  audit,
}

/// 관리자 로그인 확인 및 대시보드 연결
/// 이메일/비밀번호 로그인 + Firebase Custom Claims로 관리자 인증
class _AdminAuthGate extends StatefulWidget {
  final _AdminTarget target;
  const _AdminAuthGate({this.target = _AdminTarget.dashboard});

  @override
  State<_AdminAuthGate> createState() => _AdminAuthGateState();
}

class _AdminAuthGateState extends State<_AdminAuthGate> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = true;
  bool _isAdmin = false;
  String? _error;
  User? _adminUser;

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
  }

  /// 기존 세션에서 관리자 권한 확인
  Future<void> _checkExistingSession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.isAnonymous) {
      try {
        final idTokenResult = await user.getIdTokenResult(true);
        if (idTokenResult.claims?['admin'] == true) {
          setState(() {
            _isAdmin = true;
            _adminUser = user;
            _isLoading = false;
          });
          return;
        }
      } catch (_) {}
    }
    setState(() => _isLoading = false);
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
      // 기존 일반 사용자 세션이 있으면 로그아웃
      if (FirebaseAuth.instance.currentUser != null) {
        await FirebaseAuth.instance.signOut();
      }

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

      setState(() {
        _isAdmin = true;
        _adminUser = user;
        _isLoading = false;
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
        _error = switch (e.code) {
          'user-not-found' => '등록되지 않은 이메일입니다.',
          'wrong-password' => '비밀번호가 올바르지 않습니다.',
          'invalid-email' => '유효하지 않은 이메일 형식입니다.',
          'too-many-requests' => '잠시 후 다시 시도해주세요.',
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
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 관리자 인증 완료 → 타겟 화면 (기본: 대시보드)
    if (_isAdmin && _adminUser != null) {
      final uid = _adminUser!.uid;
      final name = _adminUser!.email ?? '관리자';
      switch (widget.target) {
        case _AdminTarget.appeals:
          return AdminAppealsPage(userId: uid, userName: name);
        case _AdminTarget.metrics:
          return AdminMetricsPage(userId: uid, userName: name);
        case _AdminTarget.audit:
          return AdminAuditLogPage(userId: uid, userName: name);
        case _AdminTarget.dashboard:
          return AdminDashboard(userId: uid, userName: name);
      }
    }

    // 로그인 폼
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
                    child: Text('관리자 로그인', style: TextStyle(fontSize: 16)),
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
