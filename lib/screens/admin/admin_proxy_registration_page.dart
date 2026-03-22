import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../constants/app_constants.dart';
import '../../constants/property_constants.dart';
import '../_shared/address_search_mixin.dart';
import '../../api_request/mls_property_service.dart';
import '../../api_request/storage_service.dart';
import '../../api_request/vworld_service.dart';
import '../../api_request/firebase_service.dart';
import '../../api_request/broker_service.dart';
import '../../models/mls_property.dart';
import '../../utils/logger.dart';
import '../../widgets/admin_user_selector.dart';
import '../../widgets/road_address_list.dart';
import '../../widgets/price_input_widget.dart';

/// 관리자 대리 매물 등록/수정 페이지
///
/// 관리자가 특정 사용자를 대신하여 매물을 등록하거나 수정할 수 있습니다.
class AdminProxyRegistrationPage extends StatefulWidget {
  /// 수정 모드일 때 기존 매물 전달
  final MLSProperty? existingProperty;

  /// 미리 선택된 대상 사용자
  final Map<String, dynamic>? targetUser;

  const AdminProxyRegistrationPage({
    this.existingProperty,
    this.targetUser,
    super.key,
  });

  @override
  State<AdminProxyRegistrationPage> createState() =>
      _AdminProxyRegistrationPageState();
}

class _AdminProxyRegistrationPageState extends State<AdminProxyRegistrationPage> with AddressSearchMixin {
  final _formKey = GlobalKey<FormState>();
  final _mlsService = MLSPropertyService();
  final _storageService = StorageService();
  final _imagePicker = ImagePicker();

  // 대상 사용자
  Map<String, dynamic>? _selectedUser;

  // 외부 매물 모드
  bool _isExternalMode = false;
  final _externalNameController = TextEditingController();
  final _externalPhoneController = TextEditingController();
  final _externalUrlController = TextEditingController();
  String _externalSource = '당근마켓';

  static const List<String> _externalSources = [
    '당근마켓', '피터팬', '맘카페', '네이버카페', '기타',
  ];

  // 현재 단계 (0: 사용자 선택, 1: 주소, 2: 가격, 3: 사진)
  int _currentStep = 0;
  bool get _isEditMode => widget.existingProperty != null;

  // 거래 유형
  String _transactionType = '매매';

  // 주소 관련
  final _addressController = TextEditingController();
  final _detailAddressController = TextEditingController();
  String _selectedAddress = '';
  bool _isMainAddressSelected = false;
  double? _latitude;
  double? _longitude;
  Map<String, String>? _selectedFullData;

  // 가격 관련
  final _priceController = TextEditingController();
  final _priceUkController = TextEditingController();
  final _priceManController = TextEditingController();
  final _depositController = TextEditingController();
  final _depositUkController = TextEditingController();
  final _depositManController = TextEditingController();

  // 이미지 관련
  final List<XFile> _selectedImages = [];
  static const int _maxImages = 5;
  bool _isSubmitting = false;

  // 상세 정보 (선택)
  int? _floor;
  int? _rooms;
  int? _bathrooms;
  String? _direction;
  final Set<String> _selectedOptions = {};
  final _notesController = TextEditingController();

  static const List<String> _availableOptions = PropertyConstants.availableOptions;

  static const List<String> _directions = PropertyConstants.directions;

  @override
  void initState() {
    super.initState();

    // 수정 모드면 기존 데이터 로드
    if (_isEditMode) {
      _loadExistingData();
    }

    // 대상 사용자가 전달되었으면 설정
    if (widget.targetUser != null) {
      _selectedUser = widget.targetUser;
      _currentStep = 1;
    }
  }

  void _loadExistingData() {
    final property = widget.existingProperty!;

    _transactionType = property.transactionType;
    _addressController.text = property.roadAddress;
    _isMainAddressSelected = true;
    _latitude = property.latitude;
    _longitude = property.longitude;

    // 가격 설정
    final price = property.desiredPrice.toInt();
    _priceUkController.text = (price ~/ 10000) > 0 ? (price ~/ 10000).toString() : '';
    _priceManController.text = (price % 10000) > 0 ? (price % 10000).toString() : '';
    _priceController.text = price.toString();

    if (property.deposit != null) {
      final deposit = property.deposit!.toInt();
      _depositUkController.text = (deposit ~/ 10000) > 0 ? (deposit ~/ 10000).toString() : '';
      _depositManController.text = (deposit % 10000) > 0 ? (deposit % 10000).toString() : '';
      _depositController.text = deposit.toString();
    }

    // 상세 정보
    _floor = property.floor;
    _rooms = property.rooms;
    _bathrooms = property.bathrooms;
    _direction = property.direction;
    _selectedOptions.addAll(property.options);
    _notesController.text = property.notes ?? '';

    // 수정 모드에서는 사용자 선택 단계 스킵
    _selectedUser = {
      'uid': property.userId,
      'name': property.userName,
    };
    _currentStep = 1;
  }

  @override
  void dispose() {
    _addressController.dispose();
    _detailAddressController.dispose();
    _priceController.dispose();
    _priceUkController.dispose();
    _priceManController.dispose();
    _depositController.dispose();
    _depositUkController.dispose();
    _depositManController.dispose();
    _notesController.dispose();
    _externalNameController.dispose();
    _externalPhoneController.dispose();
    _externalUrlController.dispose();
    cancelAddressSearch();
    super.dispose();
  }

  void _syncPriceFromSplit() {
    final uk = int.tryParse(_priceUkController.text) ?? 0;
    final man = int.tryParse(_priceManController.text) ?? 0;
    final total = uk * 10000 + man;
    _priceController.text = total > 0 ? total.toString() : '';
    setState(() {});
  }

  void _syncDepositFromSplit() {
    final uk = int.tryParse(_depositUkController.text) ?? 0;
    final man = int.tryParse(_depositManController.text) ?? 0;
    final total = uk * 10000 + man;
    _depositController.text = total > 0 ? total.toString() : '';
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AirbnbColors.surface,
      appBar: AppBar(
        backgroundColor: AirbnbColors.background,
        foregroundColor: AirbnbColors.textPrimary,
        elevation: 0,
        title: Text(
          _isEditMode ? '매물 수정 (관리자)' : '대리 매물 등록',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_currentStep > 0 && !_isEditMode)
            TextButton(
              onPressed: () {
                setState(() {
                  _currentStep = 0;
                  _selectedUser = null;
                });
              },
              child: const Text('사용자 변경'),
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // 진행 상태 표시
              _buildProgressIndicator(),

              // 선택된 사용자 정보 표시
              if (_selectedUser != null && _currentStep > 0)
                _buildSelectedUserInfo(),

              // 단계별 컨텐츠
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _buildCurrentStep(),
                ),
              ),

              // 하단 버튼
              _buildBottomButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final steps = _isEditMode
        ? ['주소', '가격', '사진']
        : ['사용자', '주소', '가격', '사진'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      color: AirbnbColors.background,
      child: Row(
        children: List.generate(steps.length, (index) {
          final isCompleted = index < _currentStep;
          final isActive = index == _currentStep;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isCompleted || isActive
                              ? AirbnbColors.primary
                              : AirbnbColors.border,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: isCompleted
                              ? const Icon(Icons.check, color: Colors.white, size: 16)
                              : Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: isActive ? Colors.white : AirbnbColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        steps[index],
                        style: TextStyle(
                          fontSize: 11,
                          color: isActive ? AirbnbColors.primary : AirbnbColors.textSecondary,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                if (index < steps.length - 1)
                  Container(
                    width: 20,
                    height: 2,
                    color: isCompleted ? AirbnbColors.primary : AirbnbColors.border,
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSelectedUserInfo() {
    final isExternal = _selectedUser?['isExternal'] == true;
    final name = _selectedUser?['name'] ?? '이름 없음';
    final subtitle = isExternal
        ? '$_externalSource · ${_selectedUser?['phone'] ?? ''}'
        : (_selectedUser?['email'] ?? '');
    final badgeColor = isExternal ? Colors.orange : AirbnbColors.primary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Icon(
                isExternal ? Icons.open_in_new : Icons.person,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isExternal ? '외부 매물: $name' : '대상 사용자: $name',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AirbnbColors.textPrimary,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AirbnbColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Icon(
            isExternal ? Icons.open_in_new : Icons.person,
            color: badgeColor,
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    final effectiveStep = _isEditMode ? _currentStep + 1 : _currentStep;

    switch (effectiveStep) {
      case 0:
        return _buildUserSelectionStep();
      case 1:
        return _buildAddressStep();
      case 2:
        return _buildPriceStep();
      case 3:
        return _buildPhotoStep();
      default:
        return _buildUserSelectionStep();
    }
  }

  // Step 0: 사용자 선택 (앱 사용자 / 외부 매물 선택)
  Widget _buildUserSelectionStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '매물을 등록할 대상을 선택하세요',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AirbnbColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '앱 사용자 또는 외부 매물(당근마켓 등)을 선택합니다',
          style: TextStyle(
            fontSize: 16,
            color: AirbnbColors.textSecondary,
          ),
        ),
        const SizedBox(height: 20),

        // 모드 선택 토글
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() {
                  _isExternalMode = false;
                  _selectedUser = null;
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: !_isExternalMode ? AirbnbColors.primary : AirbnbColors.background,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                    border: Border.all(
                      color: !_isExternalMode ? AirbnbColors.primary : AirbnbColors.border,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '앱 사용자',
                      style: TextStyle(
                        color: !_isExternalMode ? Colors.white : AirbnbColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() {
                  _isExternalMode = true;
                  _selectedUser = null;
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _isExternalMode ? AirbnbColors.primary : AirbnbColors.background,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    border: Border.all(
                      color: _isExternalMode ? AirbnbColors.primary : AirbnbColors.border,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '외부 매물',
                      style: TextStyle(
                        color: _isExternalMode ? Colors.white : AirbnbColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // 모드별 콘텐츠
        if (_isExternalMode)
          _buildExternalSellerForm()
        else
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: AdminUserSelector(
              selectedUserId: (_selectedUser?['uid'] ?? _selectedUser?['id'])?.toString(),
              onUserSelected: (user) {
                setState(() {
                  _selectedUser = user;
                });
              },
            ),
          ),
      ],
    );
  }

  // 외부 매물 집주인 정보 입력 폼
  Widget _buildExternalSellerForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '당근마켓, 피터팬 등 외부 플랫폼에서 발견한 매물을 등록합니다. 집주인이 앱에 가입하지 않아도 됩니다.',
                  style: TextStyle(fontSize: 13, color: AirbnbColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 집주인 이름
        TextField(
          controller: _externalNameController,
          decoration: InputDecoration(
            labelText: '집주인 이름 (필수)',
            hintText: '홍길동',
            prefixIcon: const Icon(Icons.person_outline),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: AirbnbColors.background,
          ),
        ),
        const SizedBox(height: 16),

        // 집주인 전화번호
        TextField(
          controller: _externalPhoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: '집주인 전화번호 (필수)',
            hintText: '010-1234-5678',
            prefixIcon: const Icon(Icons.phone_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: AirbnbColors.background,
          ),
        ),
        const SizedBox(height: 16),

        // 출처 선택
        DropdownButtonFormField<String>(
          initialValue: _externalSource,
          decoration: InputDecoration(
            labelText: '매물 출처',
            prefixIcon: const Icon(Icons.source_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: AirbnbColors.background,
          ),
          items: _externalSources
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (v) => setState(() => _externalSource = v ?? '당근마켓'),
        ),
        const SizedBox(height: 16),

        // 원본 URL (선택)
        TextField(
          controller: _externalUrlController,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            labelText: '원본 게시글 URL (선택)',
            hintText: 'https://...',
            prefixIcon: const Icon(Icons.link),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: AirbnbColors.background,
          ),
        ),
      ],
    );
  }

  // Step 1: 주소 입력
  Widget _buildAddressStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '매물 주소를 입력하세요',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AirbnbColors.textPrimary,
          ),
        ),
        const SizedBox(height: 24),

        // 거래 유형 선택
        _buildTransactionTypeSelector(),
        const SizedBox(height: 24),

        // 주소 검색
        TextField(
          controller: _addressController,
          decoration: InputDecoration(
            hintText: '도로명 주소 검색 (예: 강남대로 123)',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _addressController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _addressController.clear();
                      setState(() {
                        addressSearchResults = [];
                        addressList = [];
                        _isMainAddressSelected = false;
                      });
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: AirbnbColors.background,
          ),
          onChanged: searchAddress,
          enabled: !_isMainAddressSelected,
        ),

        // 검색 결과 또는 선택된 주소
        if (isAddressSearching)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (!_isMainAddressSelected && addressList.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            constraints: const BoxConstraints(maxHeight: 300),
            decoration: BoxDecoration(
              color: AirbnbColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AirbnbColors.border),
            ),
            child: RoadAddressList(
              fullAddrAPIDatas: addressSearchResults,
              addresses: addressList,
              selectedAddress: _selectedAddress,
              onSelect: _onAddressSelected,
            ),
          )
        else if (_isMainAddressSelected) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AirbnbColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AirbnbColors.success),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: AirbnbColors.success),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _addressController.text,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () {
                    setState(() {
                      _isMainAddressSelected = false;
                      addressSearchResults = [];
                      addressList = [];
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 상세 주소
          TextField(
            controller: _detailAddressController,
            decoration: InputDecoration(
              hintText: '상세 주소 (동/호수)',
              prefixIcon: const Icon(Icons.apartment),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: AirbnbColors.background,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTransactionTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '거래 유형',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AirbnbColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: ['매매', '전세', '월세'].map((type) {
            final isSelected = _transactionType == type;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: type != '월세' ? 8 : 0),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _transactionType = type;
                      _priceController.clear();
                      _priceUkController.clear();
                      _priceManController.clear();
                      _depositController.clear();
                      _depositUkController.clear();
                      _depositManController.clear();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected ? AirbnbColors.primary : AirbnbColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AirbnbColors.primary : AirbnbColors.border,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        type,
                        style: TextStyle(
                          color: isSelected ? Colors.white : AirbnbColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _onAddressSelected(Map<String, String> addressData, String address) {
    setState(() {
      _addressController.text = address;
      _selectedFullData = addressData;
      _selectedAddress = address;
      _isMainAddressSelected = true;
      addressSearchResults = [];
      addressList = [];
    });

    // 좌표 변환
    _fetchCoordinates(address, addressData);
  }

  Future<void> _fetchCoordinates(String address, Map<String, String> fullData) async {
    try {
      final result = await VWorldService.getCoordinatesFromAddress(
        address,
        fullAddrData: fullData,
      );

      if (result != null && mounted) {
        setState(() {
          _longitude = double.tryParse(result['x']?.toString() ?? '');
          _latitude = double.tryParse(result['y']?.toString() ?? '');
        });
      }
    } catch (e) {
      Logger.error('좌표 변환 실패', error: e);
    }
  }

  // Step 2: 가격 입력
  Widget _buildPriceStep() {
    final priceLabel = _transactionType == '전세'
        ? '전세금'
        : _transactionType == '월세'
            ? '월세'
            : '매매가';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '희망 $priceLabel을 입력하세요',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AirbnbColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '만원 단위로 입력해주세요',
          style: TextStyle(color: AirbnbColors.textSecondary),
        ),
        const SizedBox(height: 24),

        // 월세인 경우 보증금 먼저
        if (_transactionType == '월세') ...[
          const Text(
            '보증금',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          PriceInputWidget(
            ukController: _depositUkController,
            manController: _depositManController,
            onChanged: _syncDepositFromSplit,
          ),
          const SizedBox(height: 24),
          const Text(
            '월세',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
        ],

        // 가격 입력
        PriceInputWidget(
          ukController: _priceUkController,
          manController: _priceManController,
          onChanged: _syncPriceFromSplit,
        ),

        const SizedBox(height: 32),

        // 상세 정보 (선택)
        _buildDetailInfoSection(),
      ],
    );
  }


  Widget _buildDetailInfoSection() {
    return ExpansionTile(
      title: const Text(
        '상세 정보 (선택)',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      initiallyExpanded: _floor != null || _rooms != null,
      children: [
        const SizedBox(height: 16),

        // 층수, 방, 화장실
        Row(
          children: [
            Expanded(
              child: _buildNumberField('층수', _floor, (v) => setState(() => _floor = v)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildNumberField('방', _rooms, (v) => setState(() => _rooms = v)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildNumberField('화장실', _bathrooms, (v) => setState(() => _bathrooms = v)),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 향
        DropdownButtonFormField<String>(
          initialValue: _direction,
          decoration: InputDecoration(
            labelText: '향',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: AirbnbColors.background,
          ),
          items: _directions.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
          onChanged: (v) => setState(() => _direction = v),
        ),
        const SizedBox(height: 16),

        // 옵션
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availableOptions.map((option) {
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
              selectedColor: AirbnbColors.primary.withValues(alpha: 0.2),
              checkmarkColor: AirbnbColors.primary,
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // 메모
        TextField(
          controller: _notesController,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: '메모 (선택)',
            hintText: '추가 정보를 입력하세요',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: AirbnbColors.background,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildNumberField(String label, int? value, Function(int?) onChanged) {
    return TextField(
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: AirbnbColors.background,
      ),
      controller: TextEditingController(text: value?.toString() ?? ''),
      onChanged: (v) => onChanged(int.tryParse(v)),
    );
  }

  // Step 3: 사진 업로드
  Widget _buildPhotoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '매물 사진을 업로드하세요',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AirbnbColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '최대 $_maxImages장까지 업로드 가능합니다',
          style: TextStyle(color: AirbnbColors.textSecondary),
        ),
        const SizedBox(height: 24),

        // 이미지 그리드
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: _selectedImages.length + 1,
          itemBuilder: (context, index) {
            if (index == _selectedImages.length) {
              // 추가 버튼
              if (_selectedImages.length >= _maxImages) return const SizedBox();
              return GestureDetector(
                onTap: _pickImage,
                child: Container(
                  decoration: BoxDecoration(
                    color: AirbnbColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AirbnbColors.border),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate, size: 32, color: AirbnbColors.textSecondary),
                      SizedBox(height: 4),
                      Text('사진 추가', style: TextStyle(fontSize: 12, color: AirbnbColors.textSecondary)),
                    ],
                  ),
                ),
              );
            }

            // 선택된 이미지
            return Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: kIsWeb
                      ? Image.network(
                          _selectedImages[index].path,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        )
                      : Image.file(
                          File(_selectedImages[index].path),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedImages.removeAt(index)),
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
                if (index == 0)
                  Positioned(
                    bottom: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AirbnbColors.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '대표',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _pickImage() async {
    try {
      final images = await _imagePicker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        final remaining = _maxImages - _selectedImages.length;
        final toAdd = images.take(remaining).toList();

        setState(() {
          _selectedImages.addAll(toAdd);
        });
      }
    } catch (e) {
      Logger.error('이미지 선택 실패', error: e);
    }
  }

  Widget _buildBottomButtons() {
    final effectiveStep = _isEditMode ? _currentStep + 1 : _currentStep;
    const maxStep = 3;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AirbnbColors.background,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -2),
            blurRadius: 8,
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // 이전 버튼
            if (effectiveStep > (_isEditMode ? 1 : 0))
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _currentStep--),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('이전'),
                ),
              ),
            if (effectiveStep > (_isEditMode ? 1 : 0)) const SizedBox(width: 12),

            // 다음/등록 버튼
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _onNextPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AirbnbColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        effectiveStep == maxStep
                            ? (_isEditMode ? '수정 완료' : '등록하기')
                            : '다음',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onNextPressed() {
    final effectiveStep = _isEditMode ? _currentStep + 1 : _currentStep;

    switch (effectiveStep) {
      case 0: // 사용자 선택
        if (_isExternalMode) {
          if (_externalNameController.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('집주인 이름을 입력해주세요')),
            );
            return;
          }
          if (_externalPhoneController.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('집주인 전화번호를 입력해주세요')),
            );
            return;
          }
          _selectedUser = {
            'name': _externalNameController.text.trim(),
            'phone': _externalPhoneController.text.trim(),
            'isExternal': true,
          };
        } else {
          if (_selectedUser == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('사용자를 선택해주세요')),
            );
            return;
          }
        }
        setState(() => _currentStep++);
        break;

      case 1: // 주소
        if (!_isMainAddressSelected) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('주소를 검색하고 선택해주세요')),
          );
          return;
        }
        setState(() => _currentStep++);
        break;

      case 2: // 가격
        if (_priceController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('가격을 입력해주세요')),
          );
          return;
        }
        if (_transactionType == '월세' && _depositController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('보증금을 입력해주세요')),
          );
          return;
        }
        setState(() => _currentStep++);
        break;

      case 3: // 사진 → 등록
        if (_selectedImages.isEmpty && !_isEditMode) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('최소 1장의 사진이 필요합니다')),
          );
          return;
        }
        _submitProperty();
        break;
    }
  }

  Future<void> _submitProperty() async {
    if (_selectedUser == null) return;

    setState(() => _isSubmitting = true);

    try {
      final adminUser = FirebaseAuth.instance.currentUser;
      if (adminUser == null) throw Exception('관리자 인증 정보가 없습니다');

      final bool isExternal = _selectedUser!['isExternal'] == true;
      final String targetUserId = isExternal
          ? 'external_${DateTime.now().millisecondsSinceEpoch}'
          : (_selectedUser!['uid'] ?? _selectedUser!['id'] ?? '').toString();
      final String targetUserName = (_selectedUser!['name'] ?? '').toString();

      // 1. 이미지 업로드
      List<String> uploadedImageUrls = [];

      if (_isEditMode && _selectedImages.isEmpty) {
        // 수정 모드에서 새 이미지가 없으면 기존 이미지 유지
        uploadedImageUrls = widget.existingProperty!.imageUrls;
      } else {
        for (int i = 0; i < _selectedImages.length; i++) {
          final image = _selectedImages[i];
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final path = 'mls_properties/$targetUserId/image_${timestamp}_$i.jpg';

          final url = await _storageService.uploadImage(
            file: image,
            path: path,
          );
          if (url != null) {
            uploadedImageUrls.add(url);
          }
        }
      }

      if (uploadedImageUrls.isEmpty) {
        throw Exception('이미지가 필요합니다');
      }

      final thumbnailUrl = uploadedImageUrls.first;
      final price = double.parse(_priceController.text);
      final fullAddress = _detailAddressController.text.isNotEmpty
          ? '${_addressController.text} ${_detailAddressController.text}'
          : _addressController.text;

      // 2. 지역 추출
      String region = 'SEOUL';
      final address = _addressController.text;
      if (address.contains('서울')) {
        region = 'SEOUL';
      } else if (address.contains('경기')) {
        region = 'GYEONGGI';
      } else if (address.contains('인천')) {
        region = 'INCHEON';
      } else if (address.contains('부산')) {
        region = 'BUSAN';
      } else if (address.contains('대구')) {
        region = 'DAEGU';
      } else if (address.contains('대전')) {
        region = 'DAEJEON';
      } else if (address.contains('광주')) {
        region = 'GWANGJU';
      } else if (address.contains('울산')) {
        region = 'ULSAN';
      }

      final now = DateTime.now();

      if (_isEditMode) {
        // 수정 모드
        final updates = <String, dynamic>{
          'transactionType': _transactionType,
          'desiredPrice': price,
          'deposit': _transactionType == '월세' ? double.tryParse(_depositController.text) : null,
          'imageUrls': uploadedImageUrls,
          'thumbnailUrl': thumbnailUrl,
          'floor': _floor,
          'rooms': _rooms,
          'bathrooms': _bathrooms,
          'direction': _direction,
          'options': _selectedOptions.toList(),
          'notes': _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
          'updatedAt': now.toIso8601String(),
          'lastModifiedByAdmin': adminUser.uid,
        };

        await _mlsService.updateProperty(widget.existingProperty!.id, updates);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('매물 정보가 수정되었습니다'),
              backgroundColor: AirbnbColors.success,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        // 신규 등록
        final sequence = await _mlsService.getNextSequence(region);
        final propertyId = MLSProperty.generateId(region, sequence);

        final property = MLSProperty(
          id: propertyId,
          propertyId: '',
          userId: targetUserId,
          userName: targetUserName,
          address: fullAddress,
          roadAddress: _addressController.text,
          jibunAddress: _selectedFullData?['jibunAddr'] ?? '',
          buildingName: _selectedFullData?['bdNm'] ?? '',
          latitude: _latitude,
          longitude: _longitude,
          floor: _floor,
          rooms: _rooms,
          bathrooms: _bathrooms,
          direction: _direction,
          options: _selectedOptions.toList(),
          notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
          transactionType: _transactionType,
          desiredPrice: price,
          deposit: _transactionType == '월세' ? double.tryParse(_depositController.text) : null,
          imageUrls: uploadedImageUrls,
          thumbnailUrl: thumbnailUrl,
          region: region,
          district: _selectedFullData?['siNm'] ?? '',
          status: PropertyStatus.active,
          verificationStatus: isExternal ? VerificationStatus.adminApproved : null,
          verifiedAt: isExternal ? now : null,
          verifiedBy: isExternal ? adminUser.uid : null,
          isExternalListing: isExternal,
          externalSellerName: isExternal ? _externalNameController.text.trim() : null,
          externalSellerPhone: isExternal ? _externalPhoneController.text.trim() : null,
          externalSource: isExternal ? _externalSource : null,
          externalListingUrl: isExternal && _externalUrlController.text.trim().isNotEmpty
              ? _externalUrlController.text.trim()
              : null,
          createdAt: now,
          updatedAt: now,
        );

        // 대리 등록으로 저장
        await _mlsService.createPropertyOnBehalf(
          property: property,
          adminId: adminUser.uid,
        );

        // 자동 배포
        int broadcastCount = 0;
        try {
          if (_latitude != null && _longitude != null) {
            final brokerResult = await BrokerService.searchNearbyBrokers(
              latitude: _latitude!,
              longitude: _longitude!,
              radiusMeters: 3000,
            );

            if (brokerResult.brokers.isNotEmpty) {
              final externalRegNumbers = brokerResult.brokers.map((b) => b.registrationNumber).toList();
              final firebaseService = FirebaseService();
              final registeredBrokers = await firebaseService.getBrokersByRegistrationNumbers(externalRegNumbers);

              if (registeredBrokers.isNotEmpty) {
                final platformBrokerIds = registeredBrokers.values
                    .map((b) => b['uid'] as String?)
                    .where((uid) => uid != null && uid.isNotEmpty)
                    .cast<String>()
                    .toList();

                if (platformBrokerIds.isNotEmpty) {
                  await _mlsService.broadcastProperty(
                    propertyId: propertyId,
                    brokerIds: platformBrokerIds,
                  );
                  broadcastCount = platformBrokerIds.length;
                }
              }
            }
          }
        } catch (e) {
          // 자동 배포 실패 무시
        }

        // 대상 사용자에게 알림 전송 (외부 매물은 스킵)
        if (!isExternal) {
          try {
            await FirebaseService().sendNotification(
              userId: targetUserId,
              title: '매물 등록 완료',
              message: '관리자가 고객님의 매물 "$fullAddress"을 등록했습니다.',
              type: 'property_registered_by_admin',
              relatedId: propertyId,
            );
          } catch (e) {
            // 알림 실패 무시
          }
        }

        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: AirbnbColors.success, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    isExternal ? '외부 매물 등록 완료!' : '대리 등록 완료!',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isExternal
                        ? '$targetUserName님의 외부 매물이 등록되었습니다.\n'
                          '${broadcastCount > 0 ? '$broadcastCount개 중개사에게 배포되었습니다.' : ''}'
                        : '$targetUserName님의 매물이 등록되었습니다.\n'
                          '${broadcastCount > 0 ? '$broadcastCount개 중개사에게 배포되었습니다.' : ''}',
                    style: const TextStyle(color: AirbnbColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('확인'),
                ),
              ],
            ),
          );
          if (mounted) Navigator.pop(context, true);
        }
      }
    } catch (e) {
      Logger.error('매물 등록/수정 실패', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('일시적인 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.'),
            backgroundColor: AirbnbColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
