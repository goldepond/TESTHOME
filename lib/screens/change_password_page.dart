import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/constants/typography.dart';
import 'package:property/constants/spacing.dart';
import 'package:property/widgets/common_design_system.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/utils/snackbar_utils.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final TextEditingController _currentController = TextEditingController();
  final TextEditingController _newController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    // 전화번호 형식 정리 (하이픈 제거)
    final currentPhone = _currentController.text.replaceAll('-', '').replaceAll(' ', '').trim();
    final newPhone = _newController.text.replaceAll('-', '').replaceAll(' ', '').trim();
    final confirmPhone = _confirmController.text.replaceAll('-', '').replaceAll(' ', '').trim();
    
    if (currentPhone.isEmpty || newPhone.isEmpty || confirmPhone.isEmpty) {
      AppSnackBar.warning(context, '현재/새 전화번호를 모두 입력해주세요.');
      return;
    }

    // 전화번호 형식 검증
    if (!RegExp(r'^01[0-9]{8,9}$').hasMatch(currentPhone)) {
      AppSnackBar.error(context, '현재 전화번호 형식이 올바르지 않습니다.');
      return;
    }

    if (!RegExp(r'^01[0-9]{8,9}$').hasMatch(newPhone)) {
      AppSnackBar.error(context, '새 전화번호 형식이 올바르지 않습니다. (01012345678 형식)');
      return;
    }

    if (newPhone != confirmPhone) {
      AppSnackBar.error(context, '새 전화번호와 확인이 일치하지 않습니다.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final errorMessage = await _firebaseService.changePassword(
      currentPhone,
      newPhone,
    );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });

    if (errorMessage == null) {
      AppSnackBar.success(context, '전화번호가 변경되었습니다.');
      Navigator.of(context).pop(true);
    } else {
      AppSnackBar.error(context, errorMessage.replaceAll('비밀번호', '전화번호'));
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
      appBar: AppBar(
        backgroundColor: AirbnbColors.background,
        foregroundColor: AirbnbColors.primary,
        elevation: 2,
        title: Text(
          '전화번호 변경',
          style: AppTypography.h3.copyWith(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final viewInsets = MediaQuery.of(context).viewInsets;
              final actualHeight = constraints.maxHeight - viewInsets.bottom;
              
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: actualHeight - 48,
                  ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg + AppSpacing.xs),
              decoration: CommonDesignSystem.cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Text(
                    '현재 전화번호',
                    style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _currentController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: '현재 전화번호를 입력하세요 (예: 01012345678)',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: AirbnbColors.textSecondary.withValues(alpha: 0.05),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                    Text(
                    '새 전화번호',
                    style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _newController,
                    keyboardType: TextInputType.phone,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: '새 전화번호를 입력하세요 (예: 01012345678)',
                      prefixIcon: const Icon(Icons.phone),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: AirbnbColors.textSecondary.withValues(alpha: 0.05),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                    Text(
                    '새 전화번호 확인',
                    style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _confirmController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: '새 전화번호를 다시 입력하세요',
                      prefixIcon: const Icon(Icons.phone),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: AirbnbColors.textSecondary.withValues(alpha: 0.05),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg + AppSpacing.xs),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _changePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AirbnbColors.textPrimary, // 에어비엔비 스타일: 검은색 배경
                        foregroundColor: AirbnbColors.background,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(AirbnbColors.background),
                              ),
                            )
                          : const Text(
                              '전화번호 변경',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
                  ),
                ),
              );
            },
          ),
        ),
          ),
        ),
        ),
      ),
    );
  }

}



