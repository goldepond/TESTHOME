import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/apple_design_system.dart';
import '../../api_request/firebase_service.dart';
import '../../widgets/home_logo_button.dart';
import '../../utils/logger.dart';
import '../login_page.dart';
import '../user_type_selection_page.dart';

/// 로그인/회원가입 랜딩페이지 (헤이딜러 스타일)
/// 앱/웹 진입 시 로그인을 강제하는 페이지
class AuthLandingPage extends StatefulWidget {
  const AuthLandingPage({super.key});

  @override
  State<AuthLandingPage> createState() => _AuthLandingPageState();
}

class _AuthLandingPageState extends State<AuthLandingPage> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = false;
  String? _lastLoginMethod; // 'kakao', 'google', 'email' 중 하나

  static const String _lastLoginKey = 'last_login_method';

  @override
  void initState() {
    super.initState();
    _loadLastLoginMethod();
  }

  @override
  void dispose() {
    super.dispose();
  }


  Future<void> _loadLastLoginMethod() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final method = prefs.getString(_lastLoginKey);
      if (mounted && method != null) {
        setState(() => _lastLoginMethod = method);
      }
    } catch (e) {
      Logger.warning('마지막 로그인 방식 로드 실패: $e');
    }
  }

  Future<void> _saveLastLoginMethod(String method) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastLoginKey, method);
    } catch (e) {
      Logger.warning('마지막 로그인 방식 저장 실패: $e');
    }
  }

  // 카카오 로그인
  Future<void> _signInWithKakao() async {
    setState(() => _isLoading = true);
    try {
      final result = await _firebaseService.signInWithKakao();
      if (result != null && mounted) {
        await _saveLastLoginMethod('kakao');
        // StreamBuilder가 자동으로 AuthGate를 통해 네비게이션함
        // 100ms 대기 후 아직 이 화면에 있으면 직접 네비게이션 (fallback)
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
        return;
      } else if (mounted) {
        _showError('카카오 로그인에 실패했습니다.');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      Logger.error('카카오 로그인 오류', error: e);
      if (mounted) {
        _showError('카카오 로그인 중 오류가 발생했습니다.');
        setState(() => _isLoading = false);
      }
    }
  }

  // Google 로그인
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final result = await _firebaseService.signInWithGoogle();
      if (result != null && mounted) {
        await _saveLastLoginMethod('google');
        // StreamBuilder가 자동으로 AuthGate를 통해 네비게이션함
        // 100ms 대기 후 아직 이 화면에 있으면 직접 네비게이션 (fallback)
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
        return;
      } else if (mounted) {
        _showError('Google 로그인에 실패했습니다.');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      Logger.error('Google 로그인 오류', error: e);
      if (mounted) {
        _showError('Google 로그인 중 오류가 발생했습니다.');
        setState(() => _isLoading = false);
      }
    }
  }

  // 이메일로 시작하기 (회원가입 페이지로 이동)
  void _startWithEmail() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const UserTypeSelectionPage(),
      ),
    );
  }

  // 기존 계정으로 로그인
  void _goToLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LoginPage(
          returnResult: false, // AuthGate가 자동으로 라우팅하도록 함
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppleColors.systemRed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppleColors.systemBackground,
      body: SafeArea(
        child: Stack(
          children: [
            _buildContent(),
            if (_isLoading) _buildLoadingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppleSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: AppleSpacing.section),
              _buildSocialButtons(),
              const SizedBox(height: AppleSpacing.lg),
              _buildBottomLinks(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // 로고
        const LogoImage(height: 60),
        const SizedBox(height: AppleSpacing.xl),
        // 메인 카피
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: AppleTypography.largeTitle.copyWith(
              height: 1.3,
              fontWeight: FontWeight.w700,
            ),
            children: const [
              TextSpan(
                text: '한 번',
                style: TextStyle(
                  color: AppleColors.systemBlue,
                  fontWeight: FontWeight.w800,
                ),
              ),
              TextSpan(text: ' 등록하면\n'),
              TextSpan(
                text: '모든 중개사',
                style: TextStyle(
                  color: AppleColors.systemBlue,
                  fontWeight: FontWeight.w800,
                ),
              ),
              TextSpan(text: '가 봐요'),
            ],
          ),
        ),
        const SizedBox(height: AppleSpacing.lg),

        // 서브 카피
        Text(
          '주소 · 가격 · 사진만 입력하면\n지역 중개사들에게 자동으로 전달됩니다',
          textAlign: TextAlign.center,
          style: AppleTypography.body.copyWith(
            color: AppleColors.secondaryLabel,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButtons() {
    return Column(
      children: [
        // 카카오 로그인 버튼
        _SocialLoginButton(
          text: '카카오로 시작하기',
          backgroundColor: const Color(0xFFFEE500),
          textColor: const Color(0xFF191919),
          iconPath: 'kakao',
          onPressed: _isLoading ? null : () { _signInWithKakao(); },
          isLastUsed: _lastLoginMethod == 'kakao',
        ),
        const SizedBox(height: AppleSpacing.sm),

        // Google 로그인 버튼
        _SocialLoginButton(
          text: 'Google로 시작하기',
          backgroundColor: Colors.white,
          textColor: AppleColors.label,
          iconPath: 'google',
          onPressed: _isLoading ? null : _signInWithGoogle,
          hasBorder: true,
          isLastUsed: _lastLoginMethod == 'google',
        ),
      ],
    );
  }

  /// 비로그인 매물 탐색 경로 — 구매자 이탈률 감소 목적
  void _browseListingsWithoutLogin() {
    Navigator.pushNamed(context, '/listings');
  }

  Widget _buildBottomLinks() {
    return Column(
      children: [
        // 비로그인 매물 둘러보기
        TextButton(
          onPressed: _browseListingsWithoutLogin,
          child: Text(
            '먼저 매물 둘러보기',
            style: AppleTypography.body.copyWith(
              color: const Color(0xFFE07A5F),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        // 이메일 가입 · 로그인
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: _startWithEmail,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                '이메일로 가입',
                style: AppleTypography.subheadline.copyWith(
                  color: AppleColors.tertiaryLabel,
                ),
              ),
            ),
            Text(
              '·',
              style: AppleTypography.subheadline.copyWith(
                color: AppleColors.tertiaryLabel,
              ),
            ),
            TextButton(
              onPressed: _goToLogin,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                '로그인',
                style: AppleTypography.subheadline.copyWith(
                  color: AppleColors.tertiaryLabel,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.3),
      child: const Center(
        child: CircularProgressIndicator(
          color: AppleColors.systemBlue,
        ),
      ),
    );
  }
}

/// 소셜 로그인 버튼 위젯
class _SocialLoginButton extends StatelessWidget {
  final String text;
  final Color backgroundColor;
  final Color textColor;
  final String? iconPath;
  final VoidCallback? onPressed;
  final bool hasBorder;
  final bool isLastUsed;

  const _SocialLoginButton({
    required this.text,
    required this.backgroundColor,
    required this.textColor,
    this.onPressed, this.iconPath,
    this.hasBorder = false,
    this.isLastUsed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(AppleRadius.md),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(AppleRadius.md),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppleSpacing.lg,
                vertical: AppleSpacing.md,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppleRadius.md),
                border: hasBorder
                    ? Border.all(color: AppleColors.separator)
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildIcon(),
                  const SizedBox(width: AppleSpacing.sm),
                  Text(
                    text,
                    style: AppleTypography.body.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // 이전 로그인 방식 힌트
        if (isLastUsed)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '↩ 지난번에 사용한 방법',
              style: AppleTypography.caption1.copyWith(
                color: AppleColors.systemBlue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildIcon() {
    // 소셜 로그인 아이콘 (텍스트 기반 대체)
    if (iconPath == 'kakao') {
      return Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: Color(0xFF191919),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Text(
            'K',
            style: TextStyle(
              color: Color(0xFFFEE500),
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.0,
            ),
            textHeightBehavior: TextHeightBehavior(
              applyHeightToFirstAscent: false,
              applyHeightToLastDescent: false,
            ),
          ),
        ),
      );
    }

    if (iconPath == 'google') {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppleColors.separator, width: 0.5),
        ),
        child: const Center(
          child: Text(
            'G',
            style: TextStyle(
              color: Color(0xFF4285F4),
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.0,
            ),
            textHeightBehavior: TextHeightBehavior(
              applyHeightToFirstAscent: false,
              applyHeightToLastDescent: false,
            ),
          ),
        ),
      );
    }

    return const SizedBox(width: 24, height: 24);
  }
}


