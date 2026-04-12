import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/constants/typography.dart';
import 'package:property/widgets/common_design_system.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AirbnbColors.surface,
      appBar: CommonDesignSystem.standardAppBar(title: '개인정보 처리방침'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          color: AirbnbColors.background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child:   Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MyHome 개인정보 처리방침',
                  style: AppTypography.withColor(AppTypography.h3, AirbnbColors.textPrimary),
                ),
                SizedBox(height: 8),
                Text(
                  '시행일: 2025년 2월 3일',
                  style: AppTypography.withColor(AppTypography.caption, AirbnbColors.textSecondary),
                ),
                SizedBox(height: 24),

                _SectionTitle('1. 개인정보의 수집 및 이용 목적'),
                _SectionContent(
                  'MyHome(이하 "서비스")은 다음의 목적을 위하여 개인정보를 수집합니다.\n\n'
                  '• 회원 가입 및 관리: 회원제 서비스 이용에 따른 본인확인, 개인식별, 가입의사 확인\n'
                  '• 서비스 제공: 부동산 매물 등록, 중개 서비스 연결, 견적 요청 및 비교\n'
                  '• 알림 서비스: 매물 상태 변경, 견적 응답, 방문 일정 등 알림 발송\n'
                  '• 고객 지원: 문의 응대, 불만 처리, 공지사항 전달',
                ),

                _SectionTitle('2. 수집하는 개인정보 항목'),
                _SectionContent(
                  '필수 항목:\n'
                  '• 일반 회원: 이메일, 이름, 전화번호\n'
                  '• 공인중개사: 이메일, 대표자명, 사업자상호, 전화번호, 중개업 등록번호\n\n'
                  '선택 항목:\n'
                  '• 프로필 사진, 주소\n\n'
                  '자동 수집 항목:\n'
                  '• 기기 정보(OS 버전, 기기 모델), 앱 사용 기록, 접속 로그',
                ),

                _SectionTitle('3. 개인정보의 보유 및 이용 기간'),
                _SectionContent(
                  '• 회원 탈퇴 시까지 보유 (탈퇴 후 즉시 파기)\n'
                  '• 단, 관계 법령에 의해 보존이 필요한 경우 해당 기간 동안 보존\n'
                  '  - 계약 또는 청약철회에 관한 기록: 5년\n'
                  '  - 소비자 불만 또는 분쟁처리에 관한 기록: 3년\n'
                  '  - 접속에 관한 기록: 3개월',
                ),

                _SectionTitle('4. 개인정보의 제3자 제공'),
                _SectionContent(
                  '서비스는 원칙적으로 이용자의 개인정보를 제3자에게 제공하지 않습니다.\n\n'
                  '다만, 다음의 경우에는 예외로 합니다:\n'
                  '• 이용자가 사전에 동의한 경우\n'
                  '• 견적 요청 시 선택한 공인중개사에게 연락처 정보 제공\n'
                  '• 법령에 의해 요구되는 경우',
                ),

                _SectionTitle('5. 개인정보 처리 위탁'),
                _SectionContent(
                  '서비스는 원활한 서비스 제공을 위해 다음과 같이 개인정보 처리를 위탁합니다:\n\n'
                  '• Firebase (Google): 회원 인증, 데이터 저장, 푸시 알림\n'
                  '• 카카오: 소셜 로그인 서비스',
                ),

                _SectionTitle('6. 이용자의 권리'),
                _SectionContent(
                  '이용자는 언제든지 다음의 권리를 행사할 수 있습니다:\n\n'
                  '• 개인정보 열람 요구\n'
                  '• 개인정보 정정·삭제 요구\n'
                  '• 개인정보 처리정지 요구\n'
                  '• 회원 탈퇴\n\n'
                  '권리 행사는 앱 내 [마이페이지 > 설정] 또는 고객센터를 통해 가능합니다.',
                ),

                _SectionTitle('7. 개인정보의 안전성 확보 조치'),
                _SectionContent(
                  '서비스는 개인정보의 안전성 확보를 위해 다음과 같은 조치를 취하고 있습니다:\n\n'
                  '• 개인정보의 암호화\n'
                  '• 해킹 등에 대비한 보안시스템 구축\n'
                  '• 개인정보 접근 권한 제한\n'
                  '• 개인정보 취급 직원의 최소화 및 교육',
                ),

                _SectionTitle('8. 개인정보 보호책임자'),
                _SectionContent(
                  '성명: MyHome 고객지원팀\n'
                  '이메일: support@myhome.app\n\n'
                  '개인정보 관련 문의사항은 위 연락처로 문의해 주시기 바랍니다.',
                ),

                _SectionTitle('9. 개인정보 처리방침 변경'),
                _SectionContent(
                  '이 개인정보 처리방침은 법령, 정책 또는 보안기술의 변경에 따라 내용이 변경될 수 있습니다.\n\n'
                  '변경 시 앱 내 공지사항 또는 푸시 알림을 통해 안내드립니다.',
                ),

                SizedBox(height: 24),
                Divider(),
                SizedBox(height: 16),
                Text(
                  '본 개인정보 처리방침은 2025년 2월 3일부터 적용됩니다.',
                  style: AppTypography.withColor(AppTypography.caption, AirbnbColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        text,
        style:  AppTypography.body.copyWith(color: AirbnbColors.textPrimary, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _SectionContent extends StatelessWidget {
  final String text;
  const _SectionContent(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style:  AppTypography.bodySmall.copyWith(color: AirbnbColors.textPrimary, height: 1.6),
    );
  }
}
