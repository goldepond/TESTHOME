import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/api_request/address_service.dart';
import 'package:property/screens/main_page.dart';

class PersonalInfoPage extends StatefulWidget {
  final String userId;
  final String userName;

  const PersonalInfoPage({
    required this.userId,
    required this.userName,
    super.key,
  });

  @override
  State<PersonalInfoPage> createState() => _PersonalInfoPageState();
}

class _PersonalInfoPageState extends State<PersonalInfoPage> {
  final FirebaseService _firebaseService = FirebaseService();
  
  // 자주 가는 위치 관련 변수들
  final TextEditingController _frequentLocationController = TextEditingController();
  bool _isEditingLocation = false;
  bool _isSavingLocation = false;
  
  // 주소 검색 관련 변수들
  final AddressService _addressService = AddressService.instance;
  List<String> _searchResults = [];
  bool _isSearching = false;
  String _searchKeyword = '';

  @override
  void initState() {
    super.initState();
    _loadUserFrequentLocation();
  }

  @override
  void dispose() {
    _frequentLocationController.dispose();
    super.dispose();
  }


  Future<void> _loadUserFrequentLocation() async {
    try {
      final userData = await _firebaseService.getUser(widget.userId);
      if (userData != null) {
        // firstZone 필드를 우선으로 하고, 없으면 frequentLocation 필드 사용
        final location = userData['firstZone'] ?? userData['frequentLocation'];
        if (location != null) {
          _frequentLocationController.text = location;
        }
      }
    } catch (e) {
      print('자주 가는 위치 로드 오류: $e');
    }
  }

  Future<void> _saveFrequentLocation() async {
    if (_frequentLocationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('자주 가는 위치를 입력해주세요.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSavingLocation = true;
    });

    try {
      final success = await _firebaseService.updateUserFrequentLocation(
        widget.userId,
        _frequentLocationController.text.trim(),
      );

      if (mounted) {
        setState(() {
          _isSavingLocation = false;
          _isEditingLocation = false;
        });

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('자주 가는 위치가 저장되었습니다.'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('저장에 실패했습니다.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSavingLocation = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('저장 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _cancelEditingLocation() {
    setState(() {
      _isEditingLocation = false;
      _searchResults = [];
      _searchKeyword = '';
    });
    _loadUserFrequentLocation(); // 원래 값으로 되돌리기
  }

  // 주소 검색 기능
  Future<void> _searchAddress(String keyword) async {
    if (keyword.trim().length < 2) {
      setState(() {
        _searchResults = [];
        _searchKeyword = keyword;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchKeyword = keyword;
    });

    try {
      final result = await _addressService.searchRoadAddress(keyword);
      
      if (mounted) {
        setState(() {
          _isSearching = false;
          _searchResults = result.addresses;
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
            content: Text('주소 검색 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 주소 선택
  void _selectAddress(String address) {
    setState(() {
      _frequentLocationController.text = address;
      _searchResults = [];
      _searchKeyword = '';
    });
  }

  // 로그아웃 기능
  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Firebase 로그아웃
      await _firebaseService.signOut();
      
      // 로그인 페이지로 이동하고 모든 이전 페이지 스택 제거
      if (context.mounted) {
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kBackground, // 단색 배경
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              // 사용자 정보 카드
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '내 정보',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.kBrown,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow('아이디', widget.userId),
                      _buildInfoRow('이름', widget.userName),
                      _buildInfoRow('역할', '일반 사용자'),
                      const SizedBox(height: 16),
                      
                      // 자주 가는 위치 섹션
                      _buildFrequentLocationSection(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 로그아웃 섹션
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '계정 관리',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.kBrown,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () => _logout(context),
                          icon: const Icon(Icons.logout, color: Colors.white),
                          label: const Text(
                            '로그아웃',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.kDarkBrown,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFrequentLocationSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.kBrown.withValues(alpha:0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.kBrown.withValues(alpha:0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_on,
                color: AppColors.kBrown,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                '자주 가는 위치 (회사/학교)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.kBrown,
                ),
              ),
              const Spacer(),
              if (!_isEditingLocation)
                IconButton(
                  onPressed: () {
                    setState(() {
                      _isEditingLocation = true;
                    });
                  },
                  icon: const Icon(Icons.edit, size: 18),
                  color: AppColors.kBrown,
                ),
            ],
          ),
          const SizedBox(height: 12),
          
          if (_isEditingLocation) ...[
            // 편집 모드 - 주소 검색 기능 포함
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _frequentLocationController,
                  decoration: InputDecoration(
                    hintText: '주소를 검색하세요 (예: 강남구 테헤란로)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    suffixIcon: _isSearching
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : const Icon(Icons.search),
                  ),
                  maxLines: 1,
                  onChanged: (value) {
                    _searchAddress(value);
                  },
                ),
                
                // 검색 결과 목록
                if (_searchResults.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.withValues(alpha:0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha:0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final address = _searchResults[index];
                        return ListTile(
                          dense: true,
                          title: Text(
                            address,
                            style: const TextStyle(fontSize: 14),
                          ),
                          onTap: () => _selectAddress(address),
                          leading: const Icon(
                            Icons.location_on,
                            size: 16,
                            color: AppColors.kBrown,
                          ),
                        );
                      },
                    ),
                  ),
                ],
                
                // 검색 결과가 없을 때 안내 메시지
                if (_searchKeyword.isNotEmpty && _searchResults.isEmpty && !_isSearching) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '검색 결과가 없습니다. 다른 키워드로 검색해보세요.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSavingLocation ? null : _saveFrequentLocation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.kBrown,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isSavingLocation
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('저장'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSavingLocation ? null : _cancelEditingLocation,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.kBrown,
                      side: const BorderSide(color: AppColors.kBrown),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('취소'),
                  ),
                ),
              ],
            ),
          ] else ...[
            // 보기 모드
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withValues(alpha:0.3)),
              ),
              child: Text(
                _frequentLocationController.text.isEmpty
                    ? '자주 가는 위치를 설정해주세요'
                    : _frequentLocationController.text,
                style: TextStyle(
                  fontSize: 14,
                  color: _frequentLocationController.text.isEmpty
                      ? Colors.grey[600]
                      : Colors.black87,
                  fontStyle: _frequentLocationController.text.isEmpty
                      ? FontStyle.italic
                      : FontStyle.normal,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
} 