import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';
import '../../services/firebase_service.dart';
import '../../models/property.dart';
import 'admin_broker_settings.dart';
import 'admin_property_management.dart';
import 'admin_quote_requests_page.dart';

class AdminDashboard extends StatefulWidget {
  final String userId;
  final String userName;

  const AdminDashboard({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;
  final FirebaseService _firebaseService = FirebaseService();
  List<Property> _properties = [];
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadPropertiesForStats();
  }

  Future<void> _loadPropertiesForStats() async {
    try {
      // 현재 사용자의 broker 정보를 가져와서 license_number 확인
      final userData = await _firebaseService.getUser(widget.userId);
      if (userData != null && userData['brokerInfo'] != null) {
        final brokerLicenseNumber = userData['brokerInfo']['broker_license_number'];
        if (brokerLicenseNumber != null && brokerLicenseNumber.toString().isNotEmpty) {
          final properties = await _firebaseService.getPropertiesByBroker(brokerLicenseNumber);
          setState(() {
            _properties = properties;
            _isLoadingStats = false;
          });
        }
      }
    } catch (e) {
      print('❌ [Admin Dashboard] 통계 데이터 로드 실패: $e');
      setState(() {
        _isLoadingStats = false;
      });
    }
  }

  // 대시보드 새로고침 메서드 (외부에서 호출 가능)
  void refreshStats() {
    _loadPropertiesForStats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildDashboardHome(),
          AdminQuoteRequestsPage(
            userId: widget.userId,
            userName: widget.userName,
          ),
          AdminBrokerSettings(
            userId: widget.userId,
            userName: widget.userName,
          ),
          AdminPropertyManagement(
            userId: widget.userId,
            userName: widget.userName,
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          
          // 대시보드로 돌아올 때 통계 새로고침
          if (index == 0) {
            _loadPropertiesForStats();
          }
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.kBrown,
        unselectedItemColor: Colors.grey[600],
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: '대시보드',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: '견적문의',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_rounded),
            label: '관리 설정',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home_work_rounded),
            label: '매물관리',
          ),
        ],
      ),
      appBar: _buildAppBar(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final List<String> titles = [
      '관리자 대시보드',
      '견적문의 관리',
      '관리 설정',
      '매물관리',
    ];

    return AppBar(
      title: Text(
        titles[_currentIndex],
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      backgroundColor: AppColors.kBrown,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.white),
          onPressed: () {
            _showLogoutDialog();
          },
        ),
      ],
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
                colors: const [AppColors.kBrown, AppColors.kDarkBrown],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.kBrown.withValues(alpha:0.3),
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
                  '부동산 관리 시스템에 오신 것을 환영합니다',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // 빠른 액션 카드들
          const Text(
            '빠른 액션',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.kDarkBrown,
            ),
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  icon: Icons.chat_bubble_outline,
                  title: '견적문의',
                  subtitle: '고객 견적문의 관리',
                  color: AppColors.kPrimary,
                  onTap: () {
                    setState(() {
                      _currentIndex = 1;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildQuickActionCard(
                  icon: Icons.settings_rounded,
                  title: '관리 설정',
                  subtitle: '중개업자 정보 관리',
                  color: Colors.blue,
                  onTap: () {
                    setState(() {
                      _currentIndex = 2;
                    });
                  },
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  icon: Icons.home_work_rounded,
                  title: '매물관리',
                  subtitle: '등록된 매물 조회',
                  color: Colors.green,
                  onTap: () {
                    setState(() {
                      _currentIndex = 3;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(child: SizedBox()), // 빈 공간
            ],
          ),
          
          const SizedBox(height: 24),
          
          // 통계 정보
          const Text(
            '시스템 통계',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.kDarkBrown,
            ),
          ),
          const SizedBox(height: 16),
          
          _buildStatsCard(),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha:0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 32,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.kDarkBrown,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    // 통계 계산
    final totalProperties = _properties.length;
    final pendingProperties = _properties.where((p) => p.contractStatus == '보류').length;
    final reservedProperties = _properties.where((p) => p.contractStatus == '예약').length;
    final registeredProperties = _properties.where((p) => p.contractStatus == '등록').length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha:0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                icon: Icons.home_work_rounded,
                label: '총 매물',
                value: _isLoadingStats ? '...' : totalProperties.toString(),
                color: Colors.blue,
              ),
              _buildStatItem(
                icon: Icons.pending_actions_rounded,
                label: '보류 매물',
                value: _isLoadingStats ? '...' : pendingProperties.toString(),
                color: Colors.orange,
              ),
              _buildStatItem(
                icon: Icons.event_available_rounded,
                label: '예약 매물',
                value: _isLoadingStats ? '...' : reservedProperties.toString(),
                color: Colors.purple,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                icon: Icons.check_circle_outline,
                label: '등록 매물',
                value: _isLoadingStats ? '...' : registeredProperties.toString(),
                color: Colors.green,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha:0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('로그아웃'),
          content: const Text('정말 로그아웃하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacementNamed('/login');
              },
              child: const Text('로그아웃'),
            ),
          ],
        );
      },
    );
  }
}
