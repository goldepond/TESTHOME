import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/api_request/firebase_service.dart';

/// 관리자 - 전체 공인중개사 관리 페이지
class AdminBrokerManagement extends StatefulWidget {
  final String userId;
  final String userName;

  const AdminBrokerManagement({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<AdminBrokerManagement> createState() => _AdminBrokerManagementState();
}

class _AdminBrokerManagementState extends State<AdminBrokerManagement> {
  final FirebaseService _firebaseService = FirebaseService();
  List<Map<String, dynamic>> _brokers = [];
  bool _isLoading = true;
  String? _error;
  String _searchKeyword = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBrokers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBrokers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      
      // brokers 컬렉션에서 모든 공인중개사 조회
      final snapshot = await _firebaseService.getAllBrokers();
      
      if (mounted) {
        setState(() {
          _brokers = snapshot;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '공인중개사 목록을 불러오는데 실패했습니다.';
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredBrokers {
    if (_searchKeyword.isEmpty) {
      return _brokers;
    }
    
    final keyword = _searchKeyword.toLowerCase();
    return _brokers.where((broker) {
      final name = (broker['businessName'] ?? broker['name'] ?? '').toString().toLowerCase();
      final registrationNumber = (broker['brokerRegistrationNumber'] ?? broker['registrationNumber'] ?? '').toString().toLowerCase();
      final ownerName = (broker['ownerName'] ?? '').toString().toLowerCase();
      
      return name.contains(keyword) || 
             registrationNumber.contains(keyword) ||
             ownerName.contains(keyword);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kBackground,
      body: Column(
        children: [
          // 검색 바
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '공인중개사명, 등록번호, 대표자명으로 검색',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchKeyword.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchKeyword = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.kPrimary, width: 2),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchKeyword = value;
                });
              },
            ),
          ),

          // 통계 카드
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    '전체',
                    _brokers.length.toString(),
                    AppColors.kPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    '검색 결과',
                    _filteredBrokers.length.toString(),
                    Colors.blue,
                  ),
                ),
              ],
            ),
          ),

          // 목록
          Expanded(
            child: _buildBrokerList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrokerList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadBrokers,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (_filteredBrokers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.business_outlined,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 24),
            Text(
              _searchKeyword.isEmpty
                  ? '등록된 공인중개사가 없습니다'
                  : '검색 결과가 없습니다',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredBrokers.length,
      itemBuilder: (context, index) {
        return _buildBrokerCard(_filteredBrokers[index]);
      },
    );
  }

  Widget _buildBrokerCard(Map<String, dynamic> broker) {
    final businessName = broker['businessName'] ?? broker['name'] ?? '정보 없음';
    final ownerName = broker['ownerName'] ?? '정보 없음';
    final registrationNumber = broker['brokerRegistrationNumber'] ?? broker['registrationNumber'] ?? '정보 없음';
    final phone = broker['phone'] ?? broker['phoneNumber'] ?? '정보 없음';
    final address = broker['roadAddress'] ?? broker['address'] ?? '정보 없음';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.kPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.business,
                    color: AppColors.kPrimary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        businessName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '대표자: $ownerName',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.badge, '등록번호', registrationNumber),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.phone, '전화번호', phone),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.location_on, '주소', address),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF2C3E50),
            ),
          ),
        ),
      ],
    );
  }
}

