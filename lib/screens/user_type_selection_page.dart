import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/constants/typography.dart';
import 'package:property/constants/spacing.dart';
import 'package:property/widgets/home_logo_button.dart';
import 'signup_page.dart';
import 'broker/broker_signup_page.dart';

/// 사용자 타입 선택 페이지 (회원가입 시작 시)
class UserTypeSelectionPage extends StatelessWidget {
  const UserTypeSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AirbnbColors.surface,
      appBar: AppBar(
        backgroundColor: AirbnbColors.background,
        foregroundColor: AirbnbColors.primary,
        elevation: 0.5,
        title: HomeLogoButton(
          fontSize: AppTypography.h4.fontSize!,
          color: AirbnbColors.primary,
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              
              // 제목
                Center(
                child: Text(
                  '회원가입',
                  style: AppTypography.withColor(AppTypography.display, AirbnbColors.textPrimary),
                ),
              ),
              const SizedBox(height: 12),
                Center(
                child: Text(
                  '가입하실 계정 유형을 선택해주세요',
                  style: AppTypography.withColor(AppTypography.body, AirbnbColors.textSecondary),
                ),
              ),
              
              const SizedBox(height: 60),
              
              // 일반 사용자 카드
              _UserTypeCard(
                title: '일반 사용자',
                description: '부동산 매물을 등록하고\n관리하는 일반 사용자',
                icon: Icons.person_outline,
                color: AirbnbColors.primary,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SignupPage(),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: AppSpacing.lg),
              
              // 공인중개사 카드
              _UserTypeCard(
                title: '공인중개사',
                description: '부동산 중개 업무를 수행하는\n공인중개사',
                icon: Icons.business_outlined,
                color: AirbnbColors.primary,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BrokerSignupPage(),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 40),
              
              // 로그인으로 이동
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    '이미 계정이 있으신가요? 로그인',
                    style: AppTypography.withColor(
                      AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w500),
                      AirbnbColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
        ),
      ),
    );
  }
}

/// 사용자 타입 선택 카드 위젯
class _UserTypeCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _UserTypeCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AirbnbColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            // 아이콘
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: color,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            
            // 텍스트
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.withColor(
                      AppTypography.h3.copyWith(fontWeight: FontWeight.bold),
                      color,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    description,
                    style: AppTypography.withColor(
                      AppTypography.bodySmall.copyWith(height: 1.5),
                      AirbnbColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            
            // 화살표
            Icon(
              Icons.arrow_forward_ios,
              color: color,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

