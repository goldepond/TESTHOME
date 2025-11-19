import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'admin_quote_requests_page.dart';
import 'admin_broker_management.dart';
import '../main_page.dart';

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
      backgroundColor: AppColors.kBackground,
      appBar: _buildTopNavigationBar(),
      body: IndexedStack(
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
        ],
      ),
    );
  }

  PreferredSizeWidget _buildTopNavigationBar() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 2,
      toolbarHeight: 70,
      shadowColor: Colors.black.withValues(alpha: 0.1),
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
        Expanded(child: _buildNavButton('견적문의', 1, Icons.chat_bubble_outline, isMobile: true)),
        const SizedBox(width: 4),
        Expanded(child: _buildNavButton('공인중개사', 2, Icons.business_rounded, isMobile: true)),
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
                InkWell(
                  onTap: _goToHome,
                  child: const Text(
                    'MyHome',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.kPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.kPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.kPrimary.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.admin_panel_settings,
                        color: AppColors.kPrimary,
                        size: 14,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '관리자',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.kPrimary,
                        ),
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
                  Flexible(child: _buildNavButton('공인중개사', 2, Icons.business_rounded)),
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
    return InkWell(
      onTap: _goToHome,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.kPrimary.withValues(alpha: 0.1),
              AppColors.kSecondary.withValues(alpha: 0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.kPrimary.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(
              Icons.home,
              color: AppColors.kPrimary,
              size: 20,
            ),
            SizedBox(width: 6),
            Text(
              '홈으로',
              style: TextStyle(
                color: AppColors.kPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButton(String label, int index, IconData icon, {bool isMobile = false}) {
    final isSelected = _currentIndex == index;
    final Color unselectedColor = Colors.grey.shade600;

    return InkWell(
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
              gradient: isSelected ? AppGradients.primaryDiagonal : null,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.kPrimary.withValues(alpha: 0.3),
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
              color: isSelected ? Colors.white : unselectedColor,
              size: isMobile ? 22 : 20,
            ),
            SizedBox(width: isMobile ? 4 : 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : unselectedColor,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: isMobile ? 13 : 15,
                  shadows: isSelected
                      ? [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.2),
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
    );
  }

  Widget _buildDashboardHome() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 환영 메시지
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.kPrimary, AppColors.kPrimary.withValues(alpha: 0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.kPrimary.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '관리자 대시보드',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '안녕하세요, ${widget.userName}님',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'MyHome 관리자 페이지에 오신 것을 환영합니다',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
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
      ],
    );
  }

  Widget _buildCard({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
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
                color: AppColors.kPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: AppColors.kPrimary,
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
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey[400],
              size: 16,
            ),
          ],
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