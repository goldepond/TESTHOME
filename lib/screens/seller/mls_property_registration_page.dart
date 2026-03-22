import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/mls_property.dart';
import '../../api_request/mls_property_service.dart';
import '../../api_request/storage_service.dart';
import '../../widgets/common_design_system.dart';
import '../../widgets/address_search/address_input_tab.dart';
import '../../constants/app_constants.dart';
import '../../utils/logger.dart';

/// P1. 매물 정보 입력 시트 (디지털 마스터 카드)
///
/// 매물 핵심 정보를 입력하여 표준 매물 카드(마스터 카드)를 생성합니다.
/// 중개사 배포 전, 매도인이 미리보기로 품질을 확인할 수 있습니다.
class MLSPropertyRegistrationPage extends StatefulWidget {
  const MLSPropertyRegistrationPage({super.key});

  @override
  State<MLSPropertyRegistrationPage> createState() => _MLSPropertyRegistrationPageState();
}

class _MLSPropertyRegistrationPageState extends State<MLSPropertyRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _mlsService = MLSPropertyService();
  final _storageService = StorageService();

  // 폼 필드
  final _priceController = TextEditingController();
  final _minPriceController = TextEditingController();
  final _repairDetailsController = TextEditingController();

  // 주소 정보
  String _roadAddress = '';
  String _jibunAddress = '';
  String _buildingName = '';
  double? _latitude;
  double? _longitude;
  String _region = '';
  String _district = '';

  // 면적 정보
  double? _area;
  double? _supplyArea;

  // 선택 필드
  bool _negotiable = true;
  DateTime? _moveInDate;
  String _moveInFlexibility = 'flexible';
  String _repairStatus = 'partial';
  final List<String> _selectedOptions = [];
  final List<String> _selectedSellingPoints = [];

  // 이미지
  final List<String> _imageUrls = [];
  String? _thumbnailUrl;
  bool _isUploadingImages = false;

  // 로딩 상태
  bool _isLoading = false;
  bool _showPreview = false;

  // 옵션 목록
  final List<String> _optionsList = [
    '에어컨',
    '냉장고',
    '세탁기',
    '전자레인지',
    '가스레인지',
    '붙박이장',
    '신발장',
    '싱크대',
    '욕조',
    '샤워부스',
    '비데',
    '인터넷',
    'TV',
    '침대',
    '책상',
    '소파',
  ];

  // 셀링 포인트 목록
  final List<String> _sellingPointsList = [
    '채광 우수',
    '조용한 환경',
    '역세권',
    '학군 우수',
    '공원 인접',
    '대형마트 인접',
    '병원 인접',
    '주차 편리',
    '최근 리모델링',
    '풀옵션',
    '저층',
    '고층',
    '남향',
    '남동향',
  ];

  @override
  void dispose() {
    _priceController.dispose();
    _minPriceController.dispose();
    _repairDetailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('매물 등록'),
        backgroundColor: AppColors.primary,
        actions: [
          if (_showPreview)
            TextButton(
              onPressed: () => setState(() => _showPreview = false),
              child: const Text('편집', style: TextStyle(color: Colors.white)),
            )
          else
            TextButton(
              onPressed: _previewProperty,
              child: const Text('미리보기', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: _showPreview ? _buildPreview() : _buildForm(),
      bottomNavigationBar: !_showPreview ? _buildBottomBar() : null,
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle('기본 정보'),
          _buildAddressSection(),
          const SizedBox(height: 24),

          _buildSectionTitle('가격 정보'),
          _buildPriceSection(),
          const SizedBox(height: 24),

          _buildSectionTitle('이사 정보'),
          _buildMoveInSection(),
          const SizedBox(height: 24),

          _buildSectionTitle('수리 상태'),
          _buildRepairSection(),
          const SizedBox(height: 24),

          _buildSectionTitle('옵션'),
          _buildOptionsSection(),
          const SizedBox(height: 24),

          _buildSectionTitle('셀링 포인트'),
          _buildSellingPointsSection(),
          const SizedBox(height: 24),

          _buildSectionTitle('사진 등록'),
          _buildImageSection(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildAddressSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: CommonDesignSystem.cardDecoration(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_roadAddress.isEmpty)
                ElevatedButton.icon(
                  onPressed: _selectAddress,
                  icon: const Icon(Icons.search),
                  label: const Text('주소 검색'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _roadAddress,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _jibunAddress,
                      style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                    if (_buildingName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        _buildingName,
                        style: const TextStyle(fontSize: 14, color: AppColors.primary),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _selectAddress,
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('주소 변경'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPriceSection() {
    return Container(
      decoration: CommonDesignSystem.cardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextFormField(
            controller: _priceController,
            decoration: const InputDecoration(
              labelText: '희망 매도가',
              suffixText: '만원',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '희망 매도가를 입력해주세요';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Checkbox(
                value: _negotiable,
                onChanged: (value) => setState(() => _negotiable = value ?? true),
                activeColor: AppColors.primary,
              ),
              const Text('협상 가능'),
            ],
          ),
          if (_negotiable) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _minPriceController,
              decoration: const InputDecoration(
                labelText: '최소 희망가 (선택)',
                suffixText: '만원',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMoveInSection() {
    return Container(
      decoration: CommonDesignSystem.cardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            initialValue: _moveInFlexibility,
            decoration: const InputDecoration(
              labelText: '이사 가능 시기',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'immediate', child: Text('즉시 가능')),
              DropdownMenuItem(value: 'flexible', child: Text('협의 가능')),
              DropdownMenuItem(value: 'specific', child: Text('특정일')),
            ],
            onChanged: (value) => setState(() => _moveInFlexibility = value!),
          ),
          if (_moveInFlexibility == 'specific') ...[
            const SizedBox(height: 16),
            ListTile(
              title: Text(_moveInDate == null
                ? '이사 가능일 선택'
                : '${_moveInDate!.year}-${_moveInDate!.month.toString().padLeft(2, '0')}-${_moveInDate!.day.toString().padLeft(2, '0')}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: _selectMoveInDate,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRepairSection() {
    return Container(
      decoration: CommonDesignSystem.cardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            initialValue: _repairStatus,
            decoration: const InputDecoration(
              labelText: '수리 상태',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'excellent', child: Text('올수리')),
              DropdownMenuItem(value: 'partial', child: Text('부분수리')),
              DropdownMenuItem(value: 'needed', child: Text('수리필요')),
            ],
            onChanged: (value) => setState(() => _repairStatus = value!),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _repairDetailsController,
            decoration: const InputDecoration(
              labelText: '최근 수리 내역 (선택)',
              border: OutlineInputBorder(),
              hintText: '예: 2023년 화장실 리모델링',
            ),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsSection() {
    return Container(
      decoration: CommonDesignSystem.cardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _optionsList.map((option) {
          final isSelected = _selectedOptions.contains(option);
          return FilterChip(
            label: Text(option),
            selected: isSelected,
            onSelected: (selected) {
              setState(() {
                if (selected) {
                  _selectedOptions.add(option);
                } else {
                  _selectedOptions.remove(option);
                }
              });
            },
            selectedColor: AppColors.primary.withValues(alpha: 0.2),
            checkmarkColor: AppColors.primary,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSellingPointsSection() {
    return Container(
      decoration: CommonDesignSystem.cardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _sellingPointsList.map((point) {
          final isSelected = _selectedSellingPoints.contains(point);
          return FilterChip(
            label: Text(point),
            selected: isSelected,
            onSelected: (selected) {
              setState(() {
                if (selected) {
                  _selectedSellingPoints.add(point);
                } else {
                  _selectedSellingPoints.remove(point);
                }
              });
            },
            selectedColor: AppColors.accent.withValues(alpha: 0.2),
            checkmarkColor: AppColors.accent,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildImageSection() {
    return Container(
      decoration: CommonDesignSystem.cardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ElevatedButton.icon(
            onPressed: _isUploadingImages ? null : _pickImages,
            icon: const Icon(Icons.add_photo_alternate),
            label: Text(_isUploadingImages ? '업로드 중...' : '사진 추가'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          if (_imageUrls.isNotEmpty) ...[
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _imageUrls.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: NetworkImage(_imageUrls[index]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _removeImage(index),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                    if (_thumbnailUrl == _imageUrls[index])
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '대표',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreview() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          decoration: CommonDesignSystem.cardDecoration(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '매물 미리보기',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Divider(height: 24),
              if (_thumbnailUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(_thumbnailUrl!, height: 200, fit: BoxFit.cover),
                ),
              const SizedBox(height: 16),
              _buildPreviewRow('주소', _roadAddress),
              _buildPreviewRow('건물명', _buildingName),
              _buildPreviewRow('희망가', '${_priceController.text} 만원'),
              if (_negotiable)
                _buildPreviewRow('협상', '가능'),
              _buildPreviewRow('이사 가능', _getMoveInText()),
              _buildPreviewRow('수리 상태', _getRepairStatusText()),
              if (_selectedOptions.isNotEmpty)
                _buildPreviewRow('옵션', _selectedOptions.join(', ')),
              if (_selectedSellingPoints.isNotEmpty)
                _buildPreviewRow('셀링 포인트', _selectedSellingPoints.join(', ')),
              if (_repairDetailsController.text.isNotEmpty)
                _buildPreviewRow('수리 내역', _repairDetailsController.text),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: _isLoading ? null : _submitProperty,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text('매물 등록하기', style: TextStyle(fontSize: 18)),
        ),
      ),
    );
  }

  void _selectAddress() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddressInputTab()),
    );

    if (result != null) {
      setState(() {
        _roadAddress = result['roadAddress'] ?? '';
        _jibunAddress = result['jibunAddress'] ?? '';
        _buildingName = result['buildingName'] ?? '';
        _latitude = result['latitude'];
        _longitude = result['longitude'];
        _region = result['region'] ?? '';
        _district = result['district'] ?? '';
        _area = result['area'];
        _supplyArea = result['supplyArea'];
      });
    }
  }

  void _selectMoveInDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _moveInDate = date);
    }
  }

  void _pickImages() async {
    setState(() => _isUploadingImages = true);
    try {
      final image = await _storageService.pickImage();
      if (image != null) {
        final urls = await _storageService.uploadImages(
          files: [image],
          basePath: 'mls_properties',
        );
        setState(() {
          _imageUrls.addAll(urls);
          if (_thumbnailUrl == null && urls.isNotEmpty) {
            _thumbnailUrl = urls.first;
          }
        });
      }
    } catch (e) {
      Logger.error('Failed to upload images', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미지 업로드에 실패했습니다')),
        );
      }
    } finally {
      setState(() => _isUploadingImages = false);
    }
  }

  void _removeImage(int index) {
    setState(() {
      final removedUrl = _imageUrls.removeAt(index);
      if (_thumbnailUrl == removedUrl && _imageUrls.isNotEmpty) {
        _thumbnailUrl = _imageUrls.first;
      }
    });
  }

  void _previewProperty() {
    if (_formKey.currentState!.validate() && _roadAddress.isNotEmpty) {
      setState(() => _showPreview = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('필수 정보를 입력해주세요')),
      );
    }
  }

  Future<void> _submitProperty() async {
    if (!_formKey.currentState!.validate() || _roadAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('필수 정보를 입력해주세요')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      final sequence = await _mlsService.getNextSequence(_region);
      final propertyId = MLSProperty.generateId(_region, sequence);
      final now = DateTime.now();

      final property = MLSProperty(
        id: propertyId,
        propertyId: '', // 연결할 Property ID (옵션)
        userId: user.uid,
        userName: user.displayName ?? '',
        address: _roadAddress,
        roadAddress: _roadAddress,
        jibunAddress: _jibunAddress,
        buildingName: _buildingName,
        latitude: _latitude,
        longitude: _longitude,
        area: _area,
        supplyArea: _supplyArea,
        pyeong: _area != null ? _area! / 3.3058 : null,
        desiredPrice: double.tryParse(_priceController.text) ?? 0,
        negotiable: _negotiable,
        minimumPrice: _minPriceController.text.isNotEmpty ? double.tryParse(_minPriceController.text) : null,
        moveInDate: _moveInDate,
        moveInFlexibility: _moveInFlexibility,
        repairStatus: _repairStatus,
        recentRepairDetails: _repairDetailsController.text.isNotEmpty ? _repairDetailsController.text : null,
        options: _selectedOptions,
        sellingPoints: _selectedSellingPoints,
        imageUrls: _imageUrls,
        thumbnailUrl: _thumbnailUrl,
        region: _region,
        district: _district,
        createdAt: now,
        updatedAt: now,
      );

      await _mlsService.createProperty(property);

      if (!mounted) return;
      Navigator.pop(context, propertyId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('매물이 등록되었습니다')),
      );
    } catch (e) {
      Logger.error('Failed to submit property', error: e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('매물 등록에 실패했습니다: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getMoveInText() {
    switch (_moveInFlexibility) {
      case 'immediate':
        return '즉시 가능';
      case 'flexible':
        return '협의 가능';
      case 'specific':
        return _moveInDate != null
          ? '${_moveInDate!.year}-${_moveInDate!.month.toString().padLeft(2, '0')}-${_moveInDate!.day.toString().padLeft(2, '0')}'
          : '특정일';
      default:
        return '협의 가능';
    }
  }

  String _getRepairStatusText() {
    switch (_repairStatus) {
      case 'excellent':
        return '올수리';
      case 'partial':
        return '부분수리';
      case 'needed':
        return '수리필요';
      default:
        return '부분수리';
    }
  }
}
