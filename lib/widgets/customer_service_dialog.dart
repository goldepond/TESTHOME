import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/constants/typography.dart';

/// 고객센터 다이얼로그 표시
void showCustomerServiceDialog(BuildContext context) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    isScrollControlled: true,
    builder: (context) => const CustomerServiceDialog(),
  );
}

class CustomerServiceDialog extends StatelessWidget {
  const CustomerServiceDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AirbnbColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.support_agent,
                  color: AirbnbColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
                Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '고객센터 / 문의하기',
                      style: AppTypography.withColor(AppTypography.h3, AirbnbColors.textPrimary),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '원하시는 채널을 선택해주세요',
                      style: AppTypography.withColor(AppTypography.bodySmall, AirbnbColors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AirbnbColors.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // 채널 옵션들
          _buildServiceOption(
            context,
            icon: Icons.chat_bubble_outline,
            iconColor: const Color(0xFFFEE500),
            title: '카카오톡 오픈채팅',
            subtitle: '실시간 문의 및 피드백',
            onTap: () => _launchKakaoOpenChat(context),
          ),
          const SizedBox(height: 12),
          _buildServiceOption(
            context,
            icon: Icons.facebook,
            iconColor: const Color(0xFF1877F2),
            title: '페이스북',
            subtitle: '소식 및 업데이트',
            onTap: () => _launchFacebook(context),
          ),
          const SizedBox(height: 12),
          _buildServiceOption(
            context,
            icon: Icons.forum_outlined,
            iconColor: AirbnbColors.textPrimary,
            title: '스레드',
            subtitle: '피드백 및 소통',
            onTap: () => _launchThreads(context),
          ),
          const SizedBox(height: 12),
          _buildServiceOption(
            context,
            icon: Icons.email_outlined,
            iconColor: AirbnbColors.primary,
            title: '이메일 문의',
            subtitle: CustomerServiceUrls.supportEmail,
            onTap: () => _launchEmail(context),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceOption(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: AirbnbColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style:  AppTypography.body.copyWith(color: AirbnbColors.textPrimary, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style:  AppTypography.withColor(AppTypography.captionLarge, AirbnbColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AirbnbColors.textSecondary),
          ],
        ),
      ),
    );
  }

  /// 카카오톡 오픈채팅방 열기
  static Future<void> _launchKakaoOpenChat(BuildContext context) async {
    const url = CustomerServiceUrls.kakaoOpenChatUrl;
    final uri = Uri.parse(url);
    
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('카카오톡을 열 수 없습니다. URL을 확인해주세요.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// 페이스북 열기
  static Future<void> _launchFacebook(BuildContext context) async {
    const url = CustomerServiceUrls.facebookUrl;
    final uri = Uri.parse(url);
    
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// 스레드 열기
  static Future<void> _launchThreads(BuildContext context) async {
    const url = CustomerServiceUrls.threadsUrl;
    final uri = Uri.parse(url);
    
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// 이메일 클라이언트 열기
  static Future<void> _launchEmail(BuildContext context) async {
    const email = CustomerServiceUrls.supportEmail;
    final subject = Uri.encodeComponent('[MyHome 문의]');
    final body = Uri.encodeComponent(
      '문의 내용을 작성해주세요.\n\n'
      '--------------------------------\n'
      '앱 버전: 1.0.0\n'
      '문의 유형: [버그 신고 / 기능 제안 / 불만 접수 / 기타]\n'
      '--------------------------------\n\n',
    );
    
    final uri = Uri.parse('mailto:$email?subject=$subject&body=$body');
    
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('이메일 앱을 열 수 없습니다.\n직접 $email 로 문의해주세요.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}

