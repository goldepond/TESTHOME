import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/constants/responsive_constants.dart';
import 'package:property/widgets/home_logo_button.dart';
import 'admin_quote_requests_page.dart';
import 'admin_broker_management.dart';
import 'admin_broker_stats_page.dart';
import 'admin_user_logs_page.dart';
import 'admin_property_management.dart';
import 'admin_property_verification_page.dart';
import 'admin_matching_page.dart';
import '../main_page.dart';
import 'package:property/constants/typography.dart';

class AdminDashboard extends StatefulWidget {
  final String userId;
  final String userName;

  const AdminDashboard({
    required this.userId,
    required this.userName,
    super.key,
  });

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AirbnbColors.surface,
      appBar: _buildTopNavigationBar(),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: ResponsiveHelper.getMaxWidth(context)),
          child: IndexedStack(
        index: _currentIndex,
        children: [
          _buildDashboardHome(),
          AdminQuoteRequestsPage(
            userId: widget.userId,
            userName: widget.userName,
          ),
          AdminBrokerManagement(
            userId: widget.userId,
            userName: widget.userName,
          ),
          AdminBrokerStatsPage(
            userId: widget.userId,
            userName: widget.userName,
          ),
          AdminPropertyManagement(
            userId: widget.userId,
            userName: widget.userName,
          ),
          AdminPropertyVerificationPage(
            userId: widget.userId,
            userName: widget.userName,
          ),
          AdminUserLogsPage(
            userId: widget.userId,
            userName: widget.userName,
          ),
          AdminMatchingPage(
            userId: widget.userId,
            userName: widget.userName,
          ),
        ],
      ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildTopNavigationBar() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return AppBar(
      backgroundColor: AirbnbColors.background,
      foregroundColor: AirbnbColors.textPrimary,
      elevation: 2,
      toolbarHeight: 70,
      shadowColor: AirbnbColors.textPrimary.withValues(alpha: 0.1),
      surfaceTintColor: Colors.transparent,
      title: isMobile
          ? _buildMobileHeader()
          : _buildDesktopHeader(),
    );
  }

  Widget _buildMobileHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(child: _buildNavButton('대시보드', 0, Icons.dashboard_rounded, isMobile: true)),
        const SizedBox(width: 4),
        Expanded(child: _buildNavButton('견적', 1, Icons.chat_bubble_outline, isMobile: true)),
        const SizedBox(width: 4),
        Expanded(child: _buildNavButton('중개사', 2, Icons.business_rounded, isMobile: true)),
        const SizedBox(width: 4),
        Expanded(child: _buildNavButton('통계', 3, Icons.bar_chart_rounded, isMobile: true)),
        const SizedBox(width: 4),
        Expanded(child: _buildNavButton('부동산', 4, Icons.home, isMobile: true)),
        const SizedBox(width: 4),
        Expanded(child: _buildNavButton('검증', 5, Icons.verified_rounded, isMobile: true)),
        const SizedBox(width: 4),
        Expanded(child: _buildNavButton('로그', 6, Icons.analytics_outlined, isMobile: true)),
        const SizedBox(width: 4),
        Expanded(child: _buildNavButton('매칭', 7, Icons.handshake_rounded, isMobile: true)),
      ],
    );
  }

  Widget _buildDesktopHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrowDesktop = constraints.maxWidth < 900;
        
        return Row(
          children: [
            // 로고 + 관리자 배지
            Row(
              children: [
                LogoWithText(
                  logoHeight: 60,
                  textColor: AirbnbColors.primary,
                  onTap: _goToHome,
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AirbnbColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AirbnbColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child:   Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.admin_panel_settings,
                        color: AirbnbColors.primary,
                        size: 14,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '관리자',
                        style: AppTypography.caption.copyWith(color: AirbnbColors.primary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(width: isNarrowDesktop ? 16 : 40),
        
        // 네비게이션 메뉴
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 중간 화면 크기 대응
              final isNarrow = constraints.maxWidth < 500;
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(child: _buildNavButton('대시보드', 0, Icons.dashboard_rounded)),
                  SizedBox(width: isNarrow ? 2 : 4),
                  Flexible(child: _buildNavButton('견적문의', 1, Icons.chat_bubble_outline)),
                  SizedBox(width: isNarrow ? 2 : 4),
                  Flexible(child: _buildNavButton('중개사', 2, Icons.business_rounded)),
                  SizedBox(width: isNarrow ? 2 : 4),
                  Flexible(child: _buildNavButton('통계', 3, Icons.bar_chart_rounded)),
                  SizedBox(width: isNarrow ? 2 : 4),
                  Flexible(child: _buildNavButton('부동산', 4, Icons.home)),
                  SizedBox(width: isNarrow ? 2 : 4),
                  Flexible(child: _buildNavButton('검증', 5, Icons.verified_rounded)),
                  SizedBox(width: isNarrow ? 2 : 4),
                  Flexible(child: _buildNavButton('활동로그', 6, Icons.analytics_outlined)),
                  SizedBox(width: isNarrow ? 2 : 4),
                  Flexible(child: _buildNavButton('매칭', 7, Icons.handshake_rounded)),
                ],
              );
            },
          ),
        ),
        
            // 홈으로 가기 버튼
            _buildHomeButton(),
          ],
        );
      },
    );
  }

  Widget _buildHomeButton() {
    return Semantics(
      button: true,
      label: '홈으로 이동',
      child: InkWell(
      onTap: _goToHome,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AirbnbColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AirbnbColors.primary.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        child:   Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.home,
              color: AirbnbColors.primary,
              size: 20,
            ),
            SizedBox(width: 6),
            Text(
              '홈으로',
              style: AppTypography.body.copyWith(color: AirbnbColors.primary, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildNavButton(String label, int index, IconData icon, {bool isMobile = false}) {
    final isSelected = _currentIndex == index;
    const Color unselectedColor = AirbnbColors.textSecondary;

    return Semantics(
      button: true,
      label: '$label 탭${isSelected ? ", 선택됨" : ""}',
      child: InkWell(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 4 : 16,
          vertical: isMobile ? 6 : 12,
        ),
        decoration: BoxDecoration(
              color: isSelected ? AirbnbColors.primary.withValues(alpha: 0.1) : null,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AirbnbColors.primary.withValues(alpha: 0.3),
                    offset: const Offset(0, 2),
                    blurRadius: 6,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? AirbnbColors.background : unselectedColor,
              size: isMobile ? 22 : 20,
            ),
            SizedBox(width: isMobile ? 4 : 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? AirbnbColors.background : unselectedColor,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: isMobile ? 13 : 15,
                  shadows: isSelected
                      ? [
                          Shadow(
                            color: AirbnbColors.textPrimary.withValues(alpha: 0.2),
                            offset: const Offset(0, 1),
                            blurRadius: 2,
                          ),
                        ]
                      : null,
                ),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildDashboardHome() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 환영 메시지 (메인페이지 스타일)
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              vertical: MediaQuery.of(context).size.width < 768 ? 48.0 : 64.0,
              horizontal: MediaQuery.of(context).size.width < 768 ? 24.0 : 48.0,
            ),
            decoration: BoxDecoration(
              // Stripe 스타일: 밝은 배경에 미묘한 그라데이션
              color: AirbnbColors.background,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '관리자 대시보드',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.width < 768 ? 40 : 64,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.5,
                    height: 1.1,
                    color: AirbnbColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '안녕하세요, ${widget.userName}님',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.width < 768 ? 18 : 22,
                    fontWeight: FontWeight.w400,
                    height: 1.6,
                    color: AirbnbColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'MyHome 관리자 페이지에 오신 것을 환영합니다',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.width < 768 ? 16 : 18,
                    fontWeight: FontWeight.w400,
                    height: 1.6,
                    color: AirbnbColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // 관리 기능 카드들
          _buildManagementCards(),
        ],
      ),
    );
  }

  Widget _buildManagementCards() {
    return Column(
      children: [
        _buildCard(
          icon: Icons.chat_bubble_outline,
          title: '견적문의 관리',
          description: '사용자들의 견적 문의를 확인하고 관리합니다',
          onTap: () => setState(() => _currentIndex = 1),
        ),
        const SizedBox(height: 16),
        _buildCard(
          icon: Icons.business_rounded,
          title: '공인중개사 관리',
          description: '등록된 공인중개사 목록을 확인하고 관리합니다',
          onTap: () => setState(() => _currentIndex = 2),
        ),
        const SizedBox(height: 16),
        _buildCard(
          icon: Icons.bar_chart_rounded,
          title: '중개사 성과 통계',
          description: '행동 데이터 기반 중개사 성과 지표를 모니터링합니다',
          onTap: () => setState(() => _currentIndex = 3),
        ),
        const SizedBox(height: 16),
        _buildCard(
          icon: Icons.home,
          title: '부동산 관리',
          description: '등록된 부동산 목록을 확인하고 관리합니다',
          onTap: () => setState(() => _currentIndex = 4),
        ),
        const SizedBox(height: 16),
        _buildCard(
          icon: Icons.verified_rounded,
          title: '매물 검증',
          description: '신규 등록 매물의 등기를 확인하고 검증 승인합니다',
          onTap: () => setState(() => _currentIndex = 5),
        ),
        const SizedBox(height: 16),
        _buildCard(
          icon: Icons.analytics_outlined,
          title: '사용자 행동 로그',
          description: '사용자들의 앱 내 활동 내역을 실시간으로 모니터링합니다',
          onTap: () => setState(() => _currentIndex = 6),
        ),
        const SizedBox(height: 16),
        _buildCard(
          icon: Icons.handshake_rounded,
          title: '매칭 관리',
          description: '매물과 중개사를 수동으로 연결하고 진행 상태를 추적합니다',
          onTap: () => setState(() => _currentIndex = 7),
        ),
      ],
    );
  }

  Widget _buildCard({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: '$title - $description',
      child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AirbnbColors.background,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AirbnbColors.textPrimary.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AirbnbColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: AirbnbColors.primary,
                size: 24,
              ),
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
                    description,
                    style:  AppTypography.withColor(AppTypography.bodySmall, AirbnbColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: AirbnbColors.textLight,
              size: 16,
            ),
          ],
        ),
      ),
    ),
    );
  }

  void _goToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const MainPage(
          userId: '',
          userName: '',
        ),
      ),
      (route) => false,
    );
  }
}