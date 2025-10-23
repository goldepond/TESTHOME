import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../services/firebase_service.dart';
import 'propertySale/house_market_page.dart';
import 'home_page.dart';
import 'map/map_page.dart';
import 'userInfo/personal_info_page.dart';
import 'visit/visit_management_dashboard.dart';
import 'chat/chat_list_screen.dart';
import 'propertyMgmt/house_management_page.dart';

class MainPage extends StatefulWidget {
  final String userId;
  final String userName;

  const MainPage({
    required this.userId,
    required this.userName,
    super.key,
  });

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = true;
  int _currentIndex = 0; // 현재 선택된 탭 인덱스

  // 탭별 페이지들
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _initializePages();
  }

  void _initializePages() {
    _pages = [
      HomePage(userName: widget.userName), // 매물 등록 페이지 (첫 번째)
      HouseMarketPage(userName: widget.userName), // 매물 목록 페이지
      HouseManagementPage(
        userId: widget.userId,
        userName: widget.userName,
      ), // 내집관리 페이지
      ChatListScreen(
        currentUserId: widget.userId,
        currentUserName: widget.userName,
      ), // 채팅 페이지
      VisitManagementDashboard(
        currentUserId: widget.userId,
        currentUserName: widget.userName,
      ), // 방문 관리 페이지
      const MapPage(),
    ];
  }

  Future<void> _loadUserData() async {
    try {
      // 사용자 정보 로드
      await _firebaseService.getUser(widget.userId);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('사용자 데이터 로드 오류: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.kBackground,
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.kPrimary),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.kBackground,
      body: IndexedStack(index: _currentIndex, children: _pages,),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.08),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.kPrimary,
          unselectedItemColor: Colors.grey[600],
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.add_home_rounded),
              label: '내집팔기',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.list_alt_rounded),
              label: '내집사기',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.home_work_rounded),
              label: '내집관리',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_rounded),
              label: '채팅',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_rounded),
              label: '방문관리',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.map),
              label: '매물지도',
            ),
          ],
        ),
      ),
      appBar: _buildAppBar(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final List<String> titles = [
      '내집팔기',
      '내집사기',
      '내집관리',
      '채팅',
      '방문 관리',
      '매물 지도(test)'
    ];

    return AppBar(
      title: Row(
        children: [
          const Text(
            '🏠',
            style: TextStyle(fontSize: 24),
          ),
          const SizedBox(width: 8),
          Text(
            titles[_currentIndex],
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ],
      ),
      backgroundColor: AppColors.kPrimary,
      elevation: 2,
      actions: [
        // 사용자 이름 표시
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              widget.userName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ),
        // 개인정보 버튼
        IconButton(
          icon: const Icon(Icons.person_rounded, color: Colors.white),
          tooltip: '내 정보',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => PersonalInfoPage(
                  userId: widget.userId,
                  userName: widget.userName,
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}