import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../services/firebase_service.dart';
import 'propertySale/house_market_page.dart';
import 'home_page.dart';
import 'userInfo/personal_info_page.dart';
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
      HomePage(userName: widget.userName), // 내집팔기
      HouseMarketPage(userName: widget.userName), // 내집사기
      HouseManagementPage(
        userId: widget.userId,
        userName: widget.userName,
      ), // 내집관리
      PersonalInfoPage(
        userId: widget.userId,
        userName: widget.userName,
      ), // 내 정보
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
      appBar: _buildTopNavigationBar(),
      body: IndexedStack(index: _currentIndex, children: _pages,),
    );
  }

  PreferredSizeWidget _buildTopNavigationBar() {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 2,
      toolbarHeight: 70,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      surfaceTintColor: Colors.transparent,
      title: Row(
        children: [
          // 로고
          Row(
            children: const [
              Text(
                '🏠',
                style: TextStyle(fontSize: 28),
              ),
              SizedBox(width: 10),
              Text(
                'HouseMVP',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.kPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(width: 60),
          
          // 네비게이션 메뉴
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(child: _buildNavButton('내집팔기', 0, Icons.add_home_rounded)),
                const SizedBox(width: 4),
                Flexible(child: _buildNavButton('내집사기', 1, Icons.list_alt_rounded)),
                const SizedBox(width: 4),
                Flexible(child: _buildNavButton('내집관리', 2, Icons.home_work_rounded)),
                const SizedBox(width: 4),
                Flexible(child: _buildNavButton('내 정보', 3, Icons.person_rounded)),
              ],
            ),
          ),
          
          // 사용자 정보
          Container(
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
              boxShadow: [
                BoxShadow(
                  color: AppColors.kPrimary.withValues(alpha: 0.1),
                  offset: const Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.person,
                  color: AppColors.kPrimary,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.userName,
                  style: TextStyle(
                    color: AppColors.kPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton(String label, int index, IconData icon) {
    final isSelected = _currentIndex == index;
    
    return InkWell(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected 
            ? LinearGradient(
                colors: const [AppColors.kPrimary, AppColors.kSecondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
          color: isSelected ? null : Colors.transparent,
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
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey[700],
              size: 18,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 14,
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}