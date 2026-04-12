import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/constants/typography.dart';
import 'package:property/constants/spacing.dart';
import 'package:property/widgets/common_design_system.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/utils/validation_utils.dart';
import 'package:property/utils/snackbar_utils.dart';

/// 비밀번호 찾기 페이지
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    if (_emailController.text.isEmpty) {
      AppSnackBar.warning(context, '이메일을 입력해주세요.');
      return;
    }

    // 이메일 형식 검증
    if (!ValidationUtils.isValidEmail(_emailController.text)) {
      AppSnackBar.warning(context, '올바른 이메일 형식을 입력해주세요.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Firebase Authentication이 자동으로 이메일 발송!
      final success = await _firebaseService.sendPasswordResetEmail(_emailController.text);
      
      if (success && mounted) {
        setState(() {
          _emailSent = true;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoading = false;
        });
        AppSnackBar.error(context, '해당 이메일로 가입된 계정이 없습니다.');
      }
    } on Exception catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        AppSnackBar.error(context, '이메일 발송에 실패했습니다. 잠시 후 다시 시도해 주세요.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && FocusScope.of(context).hasFocus) {
          FocusScope.of(context).unfocus();
          await Future.delayed(const Duration(milliseconds: 100));
        }
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
        resizeToAvoidBottomInset: true,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
        decoration: const BoxDecoration(
          color: AirbnbColors.background,
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // 뒤로가기 버튼
              Positioned(
                top: 16,
                left: 16,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: AirbnbColors.background, size: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              // 메인 콘텐츠
                LayoutBuilder(
                  builder: (context, constraints) {
                    final viewInsets = MediaQuery.of(context).viewInsets;
                    final actualHeight = constraints.maxHeight - viewInsets.bottom;
                    
                    return Center(
                child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: actualHeight - 48,
                          ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 로고 영역
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.lg + AppSpacing.xs),
                        decoration: CommonDesignSystem.cardDecoration(
                          borderRadius: 20,
                        ),
                        child: Column(
                          children: [
                            Icon(
                              _emailSent ? Icons.check_circle : Icons.lock_reset,
                              size: 48,
                              color: _emailSent ? AirbnbColors.success : AirbnbColors.primary,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              _emailSent ? '이메일 발송 완료' : '비밀번호 찾기',
                              style: AppTypography.withColor(
                                AppTypography.display.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1.5,
                                  height: 1.1,
                                ),
                                AirbnbColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Text(
                              _emailSent
                                ? '비밀번호 재설정 링크를 발송했습니다'
                                : '가입한 이메일을 입력하세요',
                              style: AppTypography.withColor(
                                AppTypography.bodyLarge.copyWith(
                                  fontWeight: FontWeight.w400,
                                  height: 1.6,
                                ),
                                AirbnbColors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                      
                      if (!_emailSent) ...[
                        // 이메일 입력 폼
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AirbnbColors.background,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AirbnbColors.textPrimary.withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // 안내 메시지
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AirbnbColors.primary.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AirbnbColors.primary.withValues(alpha: 0.2)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline, color: AirbnbColors.primary.withValues(alpha: 0.7), size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        '가입 시 입력한 이메일로 비밀번호 재설정 링크를 발송합니다.',
                                        style: AppTypography.withColor(
                                          AppTypography.caption.copyWith(height: 1.4),
                                          AirbnbColors.primary.withValues(alpha: 0.9),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              
                              // 이메일 입력
                              TextField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: '이메일',
                                  hintText: 'example@email.com',
                                  prefixIcon: Icon(Icons.email, color: AirbnbColors.primary),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(12)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(12)),
                                    borderSide: BorderSide(color: AirbnbColors.primary, width: 2),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              
                              // 발송 버튼
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _sendResetEmail,
                                  style: CommonDesignSystem.primaryButtonStyle(),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(AirbnbColors.background),
                                          ),
                                        )
                                      : const Text('재설정 링크 발송'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        // 발송 완료 메시지
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AirbnbColors.background,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AirbnbColors.textPrimary.withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.mark_email_read,
                                size: 80,
                                color: AirbnbColors.success.withValues(alpha: 0.4),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                _emailController.text,
                                style:  AppTypography.body.copyWith(color: AirbnbColors.primary, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                '위 이메일로 비밀번호 재설정 링크를 발송했습니다.\n이메일을 확인해주세요.',
                                style: AppTypography.withColor(
                                  AppTypography.bodySmall.copyWith(height: 1.5),
                                  AirbnbColors.textSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AirbnbColors.primary,
                                    side: const BorderSide(color: AirbnbColors.primary),
                                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md - AppSpacing.xs),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child:   Text(
                                    '로그인 페이지로 돌아가기',
                                    style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                      ),
                    );
                  },
              ),
            ],
            ),
          ),
          ),
        ),
        ),
      ),
      ),
    );
  }
}
