import 'package:flutter/material.dart';
import 'dart:async';
import '../services/address_service.dart';
import '../constants/app_constants.dart';
import 'login_page.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isSearching = false;
  bool _showResults = false;
  Timer? _debounce;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    if (query.trim().isEmpty) {
      setState(() {
        _showResults = false;
        _searchResults = [];
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
      _showResults = true;
    });

    try {
      final addressService = AddressService.instance;
      final result = await addressService.searchRoadAddress(query);
      
      if (mounted) {
        if (result.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.errorMessage!),
              backgroundColor: Colors.orange,
            ),
          );
        }
        
        // AddressSearchResult를 Map 형태로 변환
        final List<Map<String, String>> resultList = result.addresses.map((addr) {
          return {
            'roadAddr': addr,
            'jibunAddr': '', // 간단한 검색이므로 지번 주소는 비워둠
            'zipNo': '',
          };
        }).toList();
        
        setState(() {
          _searchResults = resultList;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _searchResults = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('검색 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showLoginModal() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const LoginPage(),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Scaffold(
      body: Stack(
        children: [
          // 그라데이션 배경
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.kGradientStart, // Sky Blue
                  AppColors.kGradientEnd,   // Purple
                ],
              ),
            ),
          ),
          
          // 헤더
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildHeader(),
          ),
          
          // 메인 컨텐츠
          Center(
            child: SingleChildScrollView(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: screenHeight * 0.15),
                      
                      // 메인 타이틀
                      const Text(
                        '어떤 집을 찾고 계세요?',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              offset: Offset(0, 2),
                              blurRadius: 4,
                              color: Colors.black26,
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // 서브 타이틀
                      const Text(
                        '원하는 지역의 집을 쉽고 빠르게 찾아보세요',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.white,
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 50),
                      
                      // 검색 박스
                      _buildSearchBox(),
                      
                      // 검색 결과
                      if (_showResults) _buildSearchResults(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 로고
          const Row(
            children: [
              Text(
                '🏠',
                style: TextStyle(fontSize: 28),
              ),
              SizedBox(width: 8),
              Text(
                'HouseMVP',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.kSecondary,
                ),
              ),
            ],
          ),
          
          // 로그인 버튼
          Row(
            children: [
              OutlinedButton(
                onPressed: _showLoginModal,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.kSecondary,
                  side: const BorderSide(color: AppColors.kSecondary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text(
                  '로그인',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 15),
              ElevatedButton(
                onPressed: _showLoginModal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.kSecondary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 0,
                ),
                child: const Text(
                  '회원가입',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBox() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 800),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                hintText: '원하시는 지역명, 지하철역, 단지명을 입력해주세요',
                hintStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 25, vertical: 20),
              ),
              style: const TextStyle(fontSize: 18),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: AppColors.kPrimary,
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(15),
                bottomRight: Radius.circular(15),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _performSearch(_searchController.text),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(15),
                  bottomRight: Radius.circular(15),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 20),
                  child: const Text(
                    '검색',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 800),
      margin: const EdgeInsets.only(top: 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '검색 결과 (${_searchResults.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                if (_isSearching)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          
          // 결과 목록
          if (_searchResults.isEmpty && !_isSearching)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Text(
                '검색 결과가 없습니다.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            Container(
              constraints: const BoxConstraints(maxHeight: 400),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final result = _searchResults[index];
                  return _buildResultItem(result);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResultItem(dynamic result) {
    final roadAddr = result['roadAddr'] ?? '';
    final jibunAddr = result['jibunAddr'] ?? '';
    final zipNo = result['zipNo'] ?? '';
    
    return InkWell(
      onTap: () {
        // 로그인이 필요하다는 메시지
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('로그인이 필요합니다'),
            content: const Text('상세 정보를 확인하려면 로그인해주세요.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showLoginModal();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.kPrimary,
                ),
                child: const Text('로그인'),
              ),
            ],
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey[200]!),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              roadAddr,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              jibunAddr,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            if (zipNo.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  '우편번호: $zipNo',
                  style: const TextStyle(
                    color: AppColors.kPrimary,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

