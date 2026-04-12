import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/constants/typography.dart';
import 'package:property/widgets/common_design_system.dart';

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AirbnbColors.surface,
      appBar: CommonDesignSystem.standardAppBar(title: '서비스 이용약관'),
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
                  'MyHome 서비스 이용약관',
                  style: AppTypography.withColor(AppTypography.h3, AirbnbColors.textPrimary),
                ),
                SizedBox(height: 8),
                Text(
                  '시행일: 2025년 2월 3일',
                  style: AppTypography.withColor(AppTypography.caption, AirbnbColors.textSecondary),
                ),
                SizedBox(height: 24),

                _SectionTitle('제1조 (목적)'),
                _SectionContent(
                  '이 약관은 MyHome(이하 "회사")이 제공하는 부동산 중개 플랫폼 서비스(이하 "서비스")의 이용 조건 및 절차, '
                  '회사와 이용자 간의 권리·의무 및 책임 사항 등을 규정함을 목적으로 합니다.',
                ),

                _SectionTitle('제2조 (용어의 정의)'),
                _SectionContent(
                  '1. "서비스"란 회사가 제공하는 부동산 매물 등록, 중개사 연결, 견적 비교 등의 모바일 애플리케이션 서비스를 말합니다.\n\n'
                  '2. "이용자"란 이 약관에 따라 서비스를 이용하는 회원 및 비회원을 말합니다.\n\n'
                  '3. "회원"이란 서비스에 가입하여 이용자 계정을 부여받은 자를 말합니다.\n\n'
                  '4. "일반 회원"이란 부동산 매물을 등록하거나 중개 서비스를 이용하는 회원을 말합니다.\n\n'
                  '5. "공인중개사 회원"이란 「공인중개사법」에 따른 중개업 등록을 완료하고 서비스에 중개사로 가입한 회원을 말합니다.',
                ),

                _SectionTitle('제3조 (약관의 효력 및 변경)'),
                _SectionContent(
                  '1. 이 약관은 서비스 화면에 게시하거나 기타의 방법으로 이용자에게 공지함으로써 효력이 발생합니다.\n\n'
                  '2. 회사는 필요한 경우 관련 법령을 위배하지 않는 범위에서 이 약관을 변경할 수 있습니다.\n\n'
                  '3. 약관이 변경되는 경우 회사는 변경 내용과 시행일을 정하여 시행일 7일 전에 공지합니다.',
                ),

                _SectionTitle('제4조 (서비스의 제공)'),
                _SectionContent(
                  '회사는 다음과 같은 서비스를 제공합니다:\n\n'
                  '• 부동산 매물 등록 및 관리\n'
                  '• 공인중개사 검색 및 연결\n'
                  '• 중개 견적 요청 및 비교\n'
                  '• 방문 일정 관리\n'
                  '• 실시간 채팅 서비스\n'
                  '• 푸시 알림 서비스\n'
                  '• 기타 회사가 정하는 서비스',
                ),

                _SectionTitle('제5조 (회원 가입)'),
                _SectionContent(
                  '1. 회원 가입은 이용자가 약관의 내용에 동의하고 회원가입 신청을 한 후 회사가 이를 승낙함으로써 체결됩니다.\n\n'
                  '2. 회사는 다음 각 호에 해당하는 신청에 대해서는 승낙을 거부할 수 있습니다:\n'
                  '   • 실명이 아니거나 타인의 명의를 사용한 경우\n'
                  '   • 허위 정보를 기재한 경우\n'
                  '   • 공인중개사 회원의 경우 중개업 등록 정보가 확인되지 않는 경우',
                ),

                _SectionTitle('제6조 (회원의 의무)'),
                _SectionContent(
                  '1. 회원은 서비스 이용 시 관계 법령, 이 약관의 규정, 이용안내 등을 준수하여야 합니다.\n\n'
                  '2. 회원은 다음 행위를 하여서는 안 됩니다:\n'
                  '   • 타인의 정보 도용\n'
                  '   • 허위 매물 등록\n'
                  '   • 서비스 운영 방해\n'
                  '   • 타인의 명예 훼손 또는 불이익을 주는 행위\n'
                  '   • 기타 불법적이거나 부당한 행위\n\n'
                  '3. 공인중개사 회원은 「공인중개사법」 등 관련 법령을 준수하여야 합니다.',
                ),

                _SectionTitle('제7조 (서비스 이용의 제한)'),
                _SectionContent(
                  '1. 회사는 회원이 이 약관의 의무를 위반하거나 서비스의 정상적인 운영을 방해한 경우 서비스 이용을 제한할 수 있습니다.\n\n'
                  '2. 회사는 다음의 경우 서비스 이용을 일시적으로 제한할 수 있습니다:\n'
                  '   • 시스템 점검, 보수, 교체\n'
                  '   • 천재지변, 국가비상사태 등 불가항력적 사유\n'
                  '   • 기타 회사가 필요하다고 인정하는 경우',
                ),

                _SectionTitle('제8조 (회원 탈퇴 및 자격 상실)'),
                _SectionContent(
                  '1. 회원은 언제든지 서비스 내 설정 메뉴를 통해 탈퇴를 요청할 수 있습니다.\n\n'
                  '2. 탈퇴 시 회원의 개인정보는 관련 법령에서 정한 기간 동안 보관 후 파기됩니다.\n\n'
                  '3. 진행 중인 거래가 있는 경우 해당 거래 완료 후 탈퇴가 가능합니다.',
                ),

                _SectionTitle('제9조 (책임의 제한)'),
                _SectionContent(
                  '1. 회사는 이용자 간 또는 이용자와 제3자 간에 서비스를 매개로 발생한 분쟁에 대해 개입할 의무가 없으며, '
                  '이로 인한 손해를 배상할 책임이 없습니다.\n\n'
                  '2. 회사는 천재지변 또는 이에 준하는 불가항력으로 인해 서비스를 제공할 수 없는 경우 책임이 면제됩니다.\n\n'
                  '3. 회사는 이용자의 귀책사유로 인한 서비스 이용 장애에 대해 책임을 지지 않습니다.',
                ),

                _SectionTitle('제10조 (분쟁 해결)'),
                _SectionContent(
                  '1. 회사와 이용자 간에 발생한 분쟁에 관한 소송은 대한민국 법을 적용합니다.\n\n'
                  '2. 서비스 이용 중 발생한 분쟁에 대해 소송이 제기될 경우 회사의 본사 소재지를 관할하는 법원을 전속 관할 법원으로 합니다.',
                ),

                _SectionTitle('제11조 (기타)'),
                _SectionContent(
                  '이 약관에 명시되지 않은 사항은 관계 법령 및 상관례에 따릅니다.',
                ),

                SizedBox(height: 24),
                Divider(),
                SizedBox(height: 16),
                Text(
                  '본 서비스 이용약관은 2025년 2월 3일부터 적용됩니다.',
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
