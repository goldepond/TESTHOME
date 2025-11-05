import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/models/property.dart';
import 'package:property/widgets/loading_overlay.dart';
import 'admin_property_info_page.dart';

class AdminPropertyManagement extends StatefulWidget {
  final String userId;
  final String userName;

  const AdminPropertyManagement({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<AdminPropertyManagement> createState() => _AdminPropertyManagementState();
}

class _AdminPropertyManagementState extends State<AdminPropertyManagement> {
  final FirebaseService _firebaseService = FirebaseService();
  List<Property> _properties = [];
  bool _isLoading = true;
  String _selectedStatus = '전체';
  String _searchQuery = '';

  final List<String> _statusOptions = [
    '전체',
    '작성 완료',
    '보류',
    '예약',
  ];

  @override
  void initState() {
    super.initState();
    _loadProperties();
  }

  Future<void> _loadProperties() async {
    setState(() {
      _isLoading = true;
    });

    try {
      
      // 먼저 현재 사용자의 broker 정보를 가져와서 license_number 확인
      final userData = await _firebaseService.getUser(widget.userId);
      if (userData == null || userData['brokerInfo'] == null) {
        setState(() {
          _properties = [];
          _isLoading = false;
        });
        return;
      }
      
      final brokerLicenseNumber = userData['brokerInfo']['broker_license_number'];
      
      if (brokerLicenseNumber == null || brokerLicenseNumber.toString().isEmpty) {
        setState(() {
          _properties = [];
          _isLoading = false;
        });
        return;
      }
      
      final properties = await _firebaseService.getPropertiesByBroker(brokerLicenseNumber);
      
      // 디버깅: 각 매물의 broker_id 확인
      for (var _ in properties) {
      }
      
      setState(() {
        _properties = properties;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('매물을 불러오는데 실패했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Property> get _filteredProperties {
    List<Property> filtered = _properties;

    // 상태별 필터링
    if (_selectedStatus != '전체') {
      filtered = filtered.where((property) => property.contractStatus == _selectedStatus).toList();
    }

    // 검색어 필터링
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((property) {
        return property.address.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               (property.buildingName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      }).toList();
    }

    return filtered;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case '작성 완료':
        return Colors.green;
      case '보류':
        return Colors.orange;
      case '예약':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case '작성 완료':
        return Icons.check_circle_outline;
      case '보류':
        return Icons.pending_actions_outlined;
      case '예약':
        return Icons.event_available_outlined;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      message: '매물 정보를 불러오는 중...',
      child: Scaffold(
        body: Column(
          children: [
            // 검색 및 필터 섹션
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[50],
              child: Column(
                children: [
                  // 검색바
                  TextField(
                  decoration: InputDecoration(
                    hintText: '주소 또는 건물명으로 검색...',
                    prefixIcon: const Icon(Icons.search),
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
                      borderSide: const BorderSide(color: AppColors.kBrown, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
                
                const SizedBox(height: 12),
                
                // 상태 필터
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _statusOptions.map((status) {
                      final isSelected = _selectedStatus == status;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(status),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedStatus = status;
                            });
                          },
                          selectedColor: AppColors.kBrown.withValues(alpha:0.2),
                          checkmarkColor: AppColors.kBrown,
                          labelStyle: TextStyle(
                            color: isSelected ? AppColors.kBrown : Colors.grey[600],
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          
          // 매물 목록
          Expanded(
            child: _filteredProperties.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                        onRefresh: _loadProperties,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredProperties.length,
                          itemBuilder: (context, index) {
                            final property = _filteredProperties[index];
                            return _buildPropertyCard(property);
                          },
                        ),
                      ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.home_work_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _selectedStatus == '전체' && _searchQuery.isEmpty
                ? '등록된 매물이 없습니다'
                : '검색 결과가 없습니다',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedStatus == '전체' && _searchQuery.isEmpty
                ? '새로운 매물을 등록해보세요'
                : '다른 검색어나 필터를 시도해보세요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyCard(Property property) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더 (상태 및 건물명)
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(property.contractStatus).withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getStatusIcon(property.contractStatus),
                        size: 16,
                        color: _getStatusColor(property.contractStatus),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        property.contractStatus,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(property.contractStatus),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (property.buildingName != null && property.buildingName!.isNotEmpty)
                  Text(
                    property.buildingName!,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.kDarkBrown,
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // 주소
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    property.address,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // 기본 정보
            Row(
              children: [
                if (property.buildingType != null && property.buildingType!.isNotEmpty) ...[
                  _buildInfoChip(property.buildingType!),
                  const SizedBox(width: 8),
                ],
                if (property.area != null) ...[
                  _buildInfoChip('${property.area}㎡'),
                  const SizedBox(width: 8),
                ],
                if (property.floor != null) ...[
                  _buildInfoChip('${property.floor}층'),
                ],
              ],
            ),
            
            const SizedBox(height: 16),
            
            // 관리 액션 버튼들
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    '전체 정보 보기',
                    Icons.info_outline,
                    Colors.blue,
                    () => _viewAllInfo(property),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton(
                    '상세 정보 추가',
                    Icons.edit_outlined,
                    Colors.orange,
                    () => _addDetails(property),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton(
                    '매물 등록',
                    Icons.check_circle_outline,
                    Colors.green,
                    () => _registerProperty(property),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[700],
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha:0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha:0.3)),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // 1. 전체 정보 보기
  void _viewAllInfo(Property property) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AdminPropertyInfoPage(
          property: property,
        ),
      ),
    );
  }

  // 2. 상세 정보 추가 입력
  void _addDetails(Property property) {
    // TODO: 상세 정보 추가 입력 페이지로 이동
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('상세 정보 추가 입력 기능은 준비 중입니다.'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  // 3. 매물 등록 (보류 → 등록상태 변경)
  void _registerProperty(Property property) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('매물 등록'),
          content: Text('이 매물을 정식 등록하시겠습니까?\n\n상태가 "보류"에서 "등록"으로 변경되어 "내집사기" 목록에 표시됩니다.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _updatePropertyStatus(property, '등록');
              },
              child: const Text('등록'),
            ),
          ],
        );
      },
    );
  }

  // 매물 상태 업데이트
  Future<void> _updatePropertyStatus(Property property, String newStatus) async {
    try {
      // Property 객체의 contractStatus 업데이트
      final updatedProperty = property.copyWith(
        contractStatus: newStatus,
        updatedAt: DateTime.now(),
      );

      // Firebase에 업데이트
      if (property.firestoreId != null) {
        await _firebaseService.updateProperty(property.firestoreId!, updatedProperty);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('매물이 "$newStatus" 상태로 변경되었습니다.'),
              backgroundColor: Colors.green,
            ),
          );
          
          // 목록 새로고침
          _loadProperties();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('매물 상태 변경에 실패했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
