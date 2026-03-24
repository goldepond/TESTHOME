import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../constants/apple_design_system.dart';
import '../../api_request/mls_property_service.dart';
import '../../utils/formatters.dart';
import '../../constants/property_constants.dart';
import '../_shared/address_search_mixin.dart';
import '../../api_request/storage_service.dart';
import '../../api_request/vworld_service.dart';
import '../../api_request/broker_service.dart';
import '../../api_request/firebase_service.dart';
import '../../models/mls_property.dart';
import '../../utils/logger.dart';
import '../../widgets/road_address_list.dart';
import '../../widgets/price_input_widget.dart';
import '../../widgets/real_transaction_reference.dart';
import '../../widgets/address_map_widget_stub.dart'
    if (dart.library.html) '../../widgets/address_map_widget.dart';
import '../../widgets/address_map_widget_mobile.dart';

/// MLS 빠른 매물 등록 - 헤이딜러 스타일 단계별 플로우
///
/// Step 0: 주소 입력 → 선택하면 자동으로 다음 단계
/// Step 1: 가격 입력 → 입력하면 자동으로 다음 단계
/// Step 2: 사진 업로드 → 업로드하면 등록 버튼 표시
class MLSQuickRegistrationPage extends StatefulWidget {
  /// 등록 완료 후 호출되는 콜백 (탭 전환 등에 사용)
  final VoidCallback? onRegistrationComplete;

  const MLSQuickRegistrationPage({
    super.key,
    this.onRegistrationComplete,
  });

  @override
  State<MLSQuickRegistrationPage> createState() => _MLSQuickRegistrationPageState();
}

class _MLSQuickRegistrationPageState extends State<MLSQuickRegistrationPage>
    with SingleTickerProviderStateMixin, AddressSearchMixin {
  final _formKey = GlobalKey<FormState>();
  final _mlsService = MLSPropertyService();
  final _storageService = StorageService();
  final _imagePicker = ImagePicker();

  // 현재 단계 (0: 주소, 1: 가격, 2: 사진)
  int _currentStep = 0;

  // 거래 유형 (매매, 전세, 월세)
  String _transactionType = '매매';

  // Phase 1 필수 필드
  final _addressController = TextEditingController();
  final _detailAddressController = TextEditingController();
  final _detailAddressFocusNode = FocusNode();
  final _priceController = TextEditingController(); // 내부 저장용 (만원 단위)
  final _priceUkController = TextEditingController(); // 억 단위 입력
  final _priceManController = TextEditingController(); // 만원 단위 입력
  final _depositController = TextEditingController(); // 월세 보증금
  final _depositUkController = TextEditingController(); // 보증금 억 단위
  final _depositManController = TextEditingController(); // 보증금 만원 단위
  final _priceFocusNode = FocusNode();
  final List<XFile> _selectedImages = []; // 선택된 이미지 파일들 (최대 5장)
  static const int _maxImages = 5;
  bool _isSubmitting = false;

  // 상세 정보 (선택적)
  bool _showDetailFields = false; // 상세 정보 섹션 표시 여부
  int? _floor; // 층수
  int? _rooms; // 방 개수
  int? _bathrooms; // 화장실 개수
  String? _direction; // 향
  final Set<String> _selectedOptions = {}; // 선택된 옵션들
  final _notesController = TextEditingController(); // 자유 입력 메모

  // 옵션 목록
  static const List<String> _availableOptions = PropertyConstants.availableOptions;

  // 향 목록
  static const List<String> _directions = PropertyConstants.directions;


  // 방문 가능 시간 (요일별)
  final Map<String, List<TimeSlot>> _availableSlots = {};

  // 주소 검색 관련 상태는 AddressSearchMixin에서 관리:
  // isAddressSearching, addressSearchResults, addressList, addressErrorMessage
  bool _isMainAddressSelected = false; // 기본 주소 선택 완료 여부
  bool _hasCheckedMarketPrice = false; // 시세 확인 완료 여부

  // 지도 좌표
  double? _latitude;
  double? _longitude;
  bool _isLoadingCoordinates = false;
  Map<String, String>? _selectedFullData; // 선택된 주소의 전체 데이터

  @override
  void initState() {
    super.initState();
    _priceController.addListener(_onPriceChanged);
  }

  @override
  void dispose() {
    _addressController.dispose();
    _detailAddressController.dispose();
    _detailAddressFocusNode.dispose();
    _priceController.removeListener(_onPriceChanged);
    _priceController.dispose();
    _priceUkController.dispose();
    _priceManController.dispose();
    _depositController.dispose();
    _depositUkController.dispose();
    _depositManController.dispose();
    _priceFocusNode.dispose();
    _notesController.dispose();
    cancelAddressSearch();
    super.dispose();
  }

  void _onPriceChanged() {
    // 가격 입력 시 자동으로 다음 단계로
    if (_priceController.text.isNotEmpty && _currentStep == 1) {
      final price = double.tryParse(_priceController.text);
      if (price != null && price > 0) {
        // 가격이 유효하면 다음 단계로 이동 준비
        setState(() {});
      }
    }
  }

  /// 억/만원 입력값을 합산하여 _priceController에 동기화
  void _syncPriceFromSplit() {
    final uk = int.tryParse(_priceUkController.text) ?? 0;
    final man = int.tryParse(_priceManController.text) ?? 0;
    final total = uk * 10000 + man;
    _priceController.text = total > 0 ? total.toString() : '';
    setState(() {});
  }

  /// 억/만원 입력값을 합산하여 _depositController에 동기화
  void _syncDepositFromSplit() {
    final uk = int.tryParse(_depositUkController.text) ?? 0;
    final man = int.tryParse(_depositManController.text) ?? 0;
    final total = uk * 10000 + man;
    _depositController.text = total > 0 ? total.toString() : '';
    setState(() {});
  }

  /// 프리셋 선택 시 억/만원 분리 컨트롤러에 값 설정
  void _setPricePreset(int manwon) {
    final uk = manwon ~/ 10000;
    final man = manwon % 10000;
    _priceUkController.text = uk > 0 ? uk.toString() : '';
    _priceManController.text = man > 0 ? man.toString() : '';
    _priceController.text = manwon.toString();
    setState(() {});
  }

  /// 보증금 프리셋 선택 시 억/만원 분리 컨트롤러에 값 설정
  void _setDepositPreset(int manwon) {
    final uk = manwon ~/ 10000;
    final man = manwon % 10000;
    _depositUkController.text = uk > 0 ? uk.toString() : '';
    _depositManController.text = man > 0 ? man.toString() : '';
    _depositController.text = manwon.toString();
    setState(() {});
  }

  void _goToNextStep() {
    if (_currentStep < 2) {
      setState(() {
        _currentStep++;
      });
      // 가격 입력 단계면 포커스
      if (_currentStep == 1) {
        Future.delayed(const Duration(milliseconds: 300), () {
          _priceFocusNode.requestFocus();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = AppleResponsive.isMobile(context);
    final maxWidth = isMobile ? double.infinity : 720.0;

    return Scaffold(
      backgroundColor: AppleColors.systemBackground,
      // MainPage에서 AppBar를 제공하므로 여기서는 제거
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // 스크롤 가능한 컨텐츠
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(isMobile ? AppleSpacing.lg : AppleSpacing.xl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 헤이딜러 스타일 헤더
                          _buildHeroHeader(),
                          const SizedBox(height: AppleSpacing.xxl),

                          // 단계별 컨텐츠
                          _buildStepContent(),
                        ],
                      ),
                    ),
                  ),

                  // 하단 버튼 영역
                  _buildBottomArea(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroHeader() {
    // 거래 유형에 따른 문구
    String typeLabel;
    String priceLabel;
    switch (_transactionType) {
      case '전세':
        typeLabel = '전세';
        priceLabel = '전세금';
        break;
      case '월세':
        typeLabel = '월세';
        priceLabel = '월세';
        break;
      default:
        typeLabel = '매물';
        priceLabel = '매매가';
    }

    // 단계에 따라 헤더 문구 변경
    String title;
    String subtitle;
    String description;

    switch (_currentStep) {
      case 0:
        title = '$typeLabel 등록 한 번이면';
        subtitle = '모든 중개사가 봐요';
        description = '먼저 매물 주소를 알려주세요';
        break;
      case 1:
        title = _transactionType == '월세' ? '월세는' : '희망 $priceLabel은';
        subtitle = '얼마인가요?';
        description = _transactionType == '월세' ? '보증금과 월세를 입력해주세요' : '희망 가격을 입력해주세요';
        break;
      case 2:
        title = '마지막으로';
        subtitle = '사진 한 장!';
        description = '매물 사진을 올려주시면 끝이에요';
        break;
      default:
        title = '$typeLabel 등록 한 번이면';
        subtitle = '모든 중개사가 봐요';
        description = '';
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Column(
        key: ValueKey(_currentStep),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppleTypography.largeTitle.copyWith(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppleColors.label,
              height: 1.2,
            ),
          ),
          const SizedBox(height: AppleSpacing.xxs),
          Text(
            subtitle,
            style: AppleTypography.largeTitle.copyWith(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppleColors.systemBlue,
              height: 1.2,
            ),
          ),
          const SizedBox(height: AppleSpacing.md),
          Text(
            description,
            style: AppleTypography.body.copyWith(
              color: AppleColors.secondaryLabel,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  /// 거래 유형 선택 (매매, 전세, 월세)
  Widget _buildTransactionTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '거래 유형',
          style: AppleTypography.subheadline.copyWith(
            color: AppleColors.secondaryLabel,
          ),
        ),
        const SizedBox(height: AppleSpacing.sm),
        Row(
          children: ['매매', '전세', '월세'].map((type) {
            final isSelected = _transactionType == type;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: type != '월세' ? AppleSpacing.xs : 0,
                ),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _transactionType = type;
                      // 거래 유형 변경 시 가격 및 시세 확인 상태 초기화
                      _priceController.clear();
                      _priceUkController.clear();
                      _priceManController.clear();
                      _depositController.clear();
                      _depositUkController.clear();
                      _depositManController.clear();
                      _hasCheckedMarketPrice = false;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: AppleSpacing.md),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppleColors.systemBlue
                          : AppleColors.secondarySystemGroupedBackground,
                      borderRadius: BorderRadius.circular(AppleRadius.md),
                      border: isSelected
                          ? null
                          : Border.all(color: AppleColors.separator),
                    ),
                    child: Center(
                      child: Text(
                        type,
                        style: AppleTypography.headline.copyWith(
                          color: isSelected ? Colors.white : AppleColors.label,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
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

  Widget _buildStepContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 거래 유형 선택 (항상 상단에 표시)
        _buildTransactionTypeSelector(),
        const SizedBox(height: AppleSpacing.xl),

        // Step 0: 주소 입력 (항상 표시, 완료 시 요약으로)
        _buildAddressStep(),

        // Step 1: 가격 입력 (주소 입력 후 표시)
        if (_currentStep >= 1) ...[
          const SizedBox(height: AppleSpacing.xl),
          _buildPriceStep(),
        ],

        // Step 2: 사진 업로드 (가격 입력 후 표시)
        if (_currentStep >= 2) ...[
          const SizedBox(height: AppleSpacing.xl),
          _buildPhotoStep(),
        ],

        // 상세 정보 (선택적) - 사진 업로드 후 표시
        if (_currentStep >= 2 && _selectedImages.isNotEmpty) ...[
          const SizedBox(height: AppleSpacing.xl),
          _buildDetailInfoSection(),

          // 방문 가능 시간 (선택적)
          const SizedBox(height: AppleSpacing.xl),
          _buildVisitAvailabilitySection(),
        ],
      ],
    );
  }

  /// 전체 주소 반환 (기본 주소 + 세부 주소)
  String get _fullAddress {
    final detail = _detailAddressController.text.trim();
    if (detail.isEmpty) {
      return _addressController.text;
    }
    return '${_addressController.text} $detail';
  }

  Widget _buildAddressStep() {
    final isCompleted = _currentStep > 0;

    if (isCompleted) {
      // 완료된 단계 - 요약 표시
      return _buildCompletedStep(
        icon: Icons.location_on,
        label: '매물 주소',
        value: _fullAddress,
        onEdit: () {
          setState(() {
            _currentStep = 0;
            _isMainAddressSelected = false;
            addressSearchResults = [];
            addressList = [];
          });
        },
      );
    }

    // 활성 단계 - 입력 폼
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStepLabel('매물 주소', stepNumber: 1),
        const SizedBox(height: AppleSpacing.sm),

        // 기본 주소가 선택되었으면 선택된 주소 표시
        if (_isMainAddressSelected) ...[
          _buildSelectedMainAddress(),
          const SizedBox(height: AppleSpacing.md),
          // 세부 주소 입력
          _buildDetailAddressField(),
          const SizedBox(height: AppleSpacing.md),
          // 다음 버튼
          _buildNextButton(
            onPressed: _goToNextStep,
            label: '다음',
          ),
        ] else ...[
          // 주소 검색 필드
          TextFormField(
            controller: _addressController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: '도로명, 건물명, 지번 등을 입력하세요',
              hintStyle: AppleTypography.body.copyWith(
                color: AppleColors.tertiaryLabel,
              ),
              filled: true,
              fillColor: AppleColors.secondarySystemGroupedBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppleRadius.md),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(AppleSpacing.md),
              prefixIcon: const Icon(
                Icons.search,
                color: AppleColors.systemBlue,
              ),
              suffixIcon: _addressController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: AppleColors.tertiaryLabel),
                      onPressed: () {
                        _addressController.clear();
                        setState(() {
                          addressSearchResults = [];
                          addressList = [];
                        });
                      },
                    )
                  : null,
            ),
            style: AppleTypography.body.copyWith(color: AppleColors.label),
            onChanged: (value) {
              setState(() {});
              if (value.trim().isNotEmpty) {
                searchAddress(value.trim());
              } else {
                setState(() {
                  addressSearchResults = [];
                  addressList = [];
                });
              }
            },
            onFieldSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                searchAddress(value.trim());
              }
            },
          ),
          // 검색 결과
          if (addressList.isNotEmpty || isAddressSearching || addressErrorMessage != null) ...[
            const SizedBox(height: AppleSpacing.sm),
            _buildAddressSearchResults(),
          ],
        ],
      ],
    );
  }

  /// 선택된 기본 주소 표시 (지도 포함)
  Widget _buildSelectedMainAddress() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 주소 카드
        Container(
          padding: const EdgeInsets.all(AppleSpacing.md),
          decoration: BoxDecoration(
            color: AppleColors.systemBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppleRadius.md),
            border: Border.all(
              color: AppleColors.systemBlue.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.location_on,
                color: AppleColors.systemBlue,
                size: 20,
              ),
              const SizedBox(width: AppleSpacing.sm),
              Expanded(
                child: Text(
                  _addressController.text,
                  style: AppleTypography.body.copyWith(
                    color: AppleColors.label,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isMainAddressSelected = false;
                    _detailAddressController.clear();
                    _latitude = null;
                    _longitude = null;
                    _selectedFullData = null;
                  });
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: AppleSpacing.sm),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  '변경',
                  style: AppleTypography.footnote.copyWith(
                    color: AppleColors.systemBlue,
                  ),
                ),
              ),
            ],
          ),
        ),
        // 지도 표시
        const SizedBox(height: AppleSpacing.md),
        _buildAddressMap(),
      ],
    );
  }

  /// 지도 위젯 (선택된 주소 표시)
  Widget _buildAddressMap() {
    // 좌표 로딩 중
    if (_isLoadingCoordinates) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: AppleColors.secondarySystemGroupedBackground,
          borderRadius: BorderRadius.circular(AppleRadius.md),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: AppleSpacing.sm),
              Text('지도를 불러오는 중...'),
            ],
          ),
        ),
      );
    }

    // 좌표가 없으면 로딩 실패 메시지
    if (_latitude == null || _longitude == null) {
      return Container(
        height: 100,
        decoration: BoxDecoration(
          color: AppleColors.secondarySystemGroupedBackground,
          borderRadius: BorderRadius.circular(AppleRadius.md),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.map_outlined,
                color: AppleColors.tertiaryLabel,
                size: 32,
              ),
              const SizedBox(height: AppleSpacing.xs),
              Text(
                '지도를 불러올 수 없습니다',
                style: AppleTypography.footnote.copyWith(
                  color: AppleColors.tertiaryLabel,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 지도 표시 (웹/모바일 분기)
    if (kIsWeb) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppleRadius.md),
        child: AddressMapWidget(
          latitude: _latitude,
          longitude: _longitude,
          height: 180,
        ),
      );
    } else {
      return AddressMapWidgetMobile(
        latitude: _latitude,
        longitude: _longitude,
        height: 180,
      );
    }
  }

  /// 주소에서 좌표 가져오기
  Future<void> _fetchCoordinates(String address, Map<String, String> fullData) async {
    setState(() {
      _isLoadingCoordinates = true;
    });

    try {
      final result = await VWorldService.getCoordinatesFromAddress(
        address,
        fullAddrData: fullData,
      );

      if (result != null && mounted) {
        final rawLongitude = double.tryParse(result['x']?.toString() ?? '');
        final rawLatitude = double.tryParse(result['y']?.toString() ?? '');

        setState(() {
          _longitude = rawLongitude;
          _latitude = rawLatitude;
          _isLoadingCoordinates = false;
        });
      } else {
        setState(() {
          _isLoadingCoordinates = false;
        });
      }
    } catch (e) {
      Logger.error('좌표 변환 실패', error: e);
      if (mounted) {
        setState(() {
          _isLoadingCoordinates = false;
        });
      }
    }
  }

  /// 세부 주소 입력 필드
  Widget _buildDetailAddressField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '세부 주소 (선택)',
          style: AppleTypography.footnote.copyWith(
            color: AppleColors.secondaryLabel,
          ),
        ),
        const SizedBox(height: AppleSpacing.xs),
        TextFormField(
          controller: _detailAddressController,
          focusNode: _detailAddressFocusNode,
          decoration: InputDecoration(
            hintText: '동/호수, 건물명 등 (예: 101동 202호)',
            hintStyle: AppleTypography.body.copyWith(
              color: AppleColors.tertiaryLabel,
            ),
            filled: true,
            fillColor: AppleColors.secondarySystemGroupedBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppleRadius.md),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(AppleSpacing.md),
            prefixIcon: const Icon(
              Icons.apartment,
              color: AppleColors.secondaryLabel,
            ),
          ),
          style: AppleTypography.body.copyWith(color: AppleColors.label),
          onFieldSubmitted: (_) => _goToNextStep(),
        ),
      ],
    );
  }

  Widget _buildPriceStep() {
    final isCompleted = _currentStep > 1;
    final isActive = _currentStep == 1;

    // 거래 유형에 따른 라벨
    String priceLabel;
    String completedValue;
    switch (_transactionType) {
      case '전세':
        priceLabel = '전세금';
        completedValue = _formatPriceDisplay(_priceController.text);
        break;
      case '월세':
        priceLabel = '보증금/월세';
        final deposit = _formatPriceDisplay(_depositController.text);
        final monthly = _formatPriceDisplay(_priceController.text);
        completedValue = deposit.isNotEmpty && monthly.isNotEmpty
            ? '$deposit / 월 $monthly'
            : monthly;
        break;
      default:
        priceLabel = '매매가';
        completedValue = _formatPriceDisplay(_priceController.text);
    }

    if (isCompleted) {
      return _buildCompletedStep(
        icon: Icons.attach_money,
        label: '희망 $priceLabel',
        value: completedValue,
        onEdit: () {
          setState(() {
            _currentStep = 1;
          });
          Future.delayed(const Duration(milliseconds: 100), () {
            _priceFocusNode.requestFocus();
          });
        },
      );
    }

    return AnimatedOpacity(
      opacity: isActive ? 1.0 : 0.5,
      duration: const Duration(milliseconds: 300),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ═══════════════════════════════════════════════════════
          // 섹션 1: 시세 참고 (실거래 기반)
          // ═══════════════════════════════════════════════════════
          if (_selectedFullData != null) ...[
            _buildStepLabel('시세 참고', stepNumber: 2),
            const SizedBox(height: AppleSpacing.xs),
            Text(
              '실거래가 기반으로 예상 시세를 확인하세요',
              style: AppleTypography.caption1.copyWith(
                color: AppleColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: AppleSpacing.sm),
            RealTransactionReference(
              addressData: _selectedFullData,
              transactionType: _transactionType,
              embedded: true,
              onDataLoaded: () {
                setState(() {
                  _hasCheckedMarketPrice = true;
                });
              },
              onPriceSelected: (price) {
                _setPricePreset(price);
              },
            ),
            const SizedBox(height: AppleSpacing.xl),
          ],

          // ═══════════════════════════════════════════════════════
          // 섹션 2: 희망 매매가 입력
          // ═══════════════════════════════════════════════════════
          if (_selectedFullData == null || _hasCheckedMarketPrice) ...[
            _buildStepLabel('희망 $priceLabel', stepNumber: _selectedFullData != null ? 3 : 2),
            const SizedBox(height: AppleSpacing.xs),
            Text(
              '만원 단위로 입력해주세요 (예: 5억 = 50000)',
              style: AppleTypography.caption1.copyWith(
                color: AppleColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: AppleSpacing.sm),
            // 월세인 경우 보증금 먼저 입력
            if (_transactionType == '월세') ...[
              Text(
                '보증금',
                style: AppleTypography.subheadline.copyWith(
                  color: AppleColors.secondaryLabel,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppleSpacing.xs),
              // 보증금 프리셋
              Wrap(
                spacing: AppleSpacing.xs,
                runSpacing: AppleSpacing.xs,
                children: [
                  _buildDepositPresetNew('500만', 500),
                  _buildDepositPresetNew('1000만', 1000),
                  _buildDepositPresetNew('2000만', 2000),
                  _buildDepositPresetNew('5000만', 5000),
                  _buildDepositPresetNew('1억', 10000),
                ],
              ),
              const SizedBox(height: AppleSpacing.sm),
              // 보증금 억/만원 분리 입력
              PriceInputWidget(
                ukController: _depositUkController,
                manController: _depositManController,
                onChanged: _syncDepositFromSplit,
              ),
              const SizedBox(height: AppleSpacing.lg),
              Text(
                '월세',
                style: AppleTypography.subheadline.copyWith(
                  color: AppleColors.secondaryLabel,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppleSpacing.xs),
              // 월세 프리셋
              Wrap(
                spacing: AppleSpacing.xs,
                runSpacing: AppleSpacing.xs,
                children: [
                  _buildPricePreset('30만', 30),
                  _buildPricePreset('50만', 50),
                  _buildPricePreset('70만', 70),
                  _buildPricePreset('100만', 100),
                  _buildPricePreset('150만', 150),
                ],
              ),
              const SizedBox(height: AppleSpacing.sm),
            ] else ...[
              // 매매/전세 프리셋 (더 촘촘하게)
              Wrap(
                spacing: AppleSpacing.xs,
                runSpacing: AppleSpacing.xs,
                children: _transactionType == '전세'
                    ? [
                        _buildPricePresetNew('5천', 5000),
                        _buildPricePresetNew('1억', 10000),
                        _buildPricePresetNew('2억', 20000),
                        _buildPricePresetNew('3억', 30000),
                        _buildPricePresetNew('5억', 50000),
                      ]
                    : [
                        _buildPricePresetNew('1억', 10000),
                        _buildPricePresetNew('2억', 20000),
                        _buildPricePresetNew('3억', 30000),
                        _buildPricePresetNew('5억', 50000),
                        _buildPricePresetNew('7억', 70000),
                        _buildPricePresetNew('10억', 100000),
                      ],
              ),
              const SizedBox(height: AppleSpacing.md),

              // 억/만원 분리 입력
              PriceInputWidget(
                ukController: _priceUkController,
                manController: _priceManController,
                onChanged: _syncPriceFromSplit,
                focusNode: _priceFocusNode,
                onSubmitted: _validateAndGoToPhoto,
              ),
            ],
          ],

          // 실시간 가격 변환 표시
          if (_priceController.text.isNotEmpty) ...[
            const SizedBox(height: AppleSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppleSpacing.md),
              decoration: BoxDecoration(
                color: AppleColors.systemBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppleRadius.md),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 18,
                    color: AppleColors.systemBlue,
                  ),
                  const SizedBox(width: AppleSpacing.sm),
                  Expanded(
                    child: Text(
                      _transactionType == '월세'
                          ? '보증금 ${_formatPriceDisplay(_depositController.text)} / 월세 ${_formatPriceDisplay(_priceController.text)}'
                          : _formatPriceDisplay(_priceController.text),
                      style: AppleTypography.headline.copyWith(
                        color: AppleColors.systemBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppleSpacing.md),
          // 가격 입력 시 다음 버튼
          if (_priceController.text.isNotEmpty)
            _buildNextButton(
              onPressed: _validateAndGoToPhoto,
              label: '다음',
            ),
          // 하단 여백
          const SizedBox(height: AppleSpacing.xxl),
        ],
      ),
    );
  }

  Widget _buildPricePreset(String label, int value) {
    final isSelected = _priceController.text == value.toString();
    return GestureDetector(
      onTap: () {
        setState(() {
          _priceController.text = value.toString();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppleSpacing.md,
          vertical: AppleSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppleColors.systemBlue
              : AppleColors.secondarySystemGroupedBackground,
          borderRadius: BorderRadius.circular(AppleRadius.sm),
          border: Border.all(
            color: isSelected ? AppleColors.systemBlue : AppleColors.separator,
          ),
        ),
        child: Text(
          label,
          style: AppleTypography.subheadline.copyWith(
            color: isSelected ? Colors.white : AppleColors.label,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// 새 프리셋 버튼 (억/만원 분리 입력 연동)
  Widget _buildPricePresetNew(String label, int value) {
    final isSelected = _priceController.text == value.toString();
    return GestureDetector(
      onTap: () => _setPricePreset(value),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppleSpacing.md,
          vertical: AppleSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppleColors.systemBlue
              : AppleColors.secondarySystemGroupedBackground,
          borderRadius: BorderRadius.circular(AppleRadius.sm),
          border: Border.all(
            color: isSelected ? AppleColors.systemBlue : AppleColors.separator,
          ),
        ),
        child: Text(
          label,
          style: AppleTypography.subheadline.copyWith(
            color: isSelected ? Colors.white : AppleColors.label,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// 새 보증금 프리셋 버튼 (억/만원 분리 입력 연동)
  Widget _buildDepositPresetNew(String label, int value) {
    final isSelected = _depositController.text == value.toString();
    return GestureDetector(
      onTap: () => _setDepositPreset(value),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppleSpacing.md,
          vertical: AppleSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppleColors.systemBlue
              : AppleColors.secondarySystemGroupedBackground,
          borderRadius: BorderRadius.circular(AppleRadius.sm),
          border: Border.all(
            color: isSelected ? AppleColors.systemBlue : AppleColors.separator,
          ),
        ),
        child: Text(
          label,
          style: AppleTypography.subheadline.copyWith(
            color: isSelected ? Colors.white : AppleColors.label,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  String _formatPriceDisplay(String priceText) => PriceFormatter.formatFromText(priceText);

  void _validateAndGoToPhoto() {
    final price = double.tryParse(_priceController.text);
    if (price != null && price > 0) {
      _goToNextStep();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '올바른 가격을 입력해주세요',
            style: AppleTypography.body.copyWith(color: Colors.white),
          ),
          backgroundColor: AppleColors.systemOrange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppleRadius.md),
          ),
        ),
      );
    }
  }

  Widget _buildPhotoStep() {
    return AnimatedOpacity(
      opacity: _currentStep >= 2 ? 1.0 : 0.5,
      duration: const Duration(milliseconds: 300),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _buildStepLabel('사진 업로드', stepNumber: 3)),
              Text(
                '${_selectedImages.length}/$_maxImages장',
                style: AppleTypography.subheadline.copyWith(
                  color: _selectedImages.isNotEmpty
                      ? AppleColors.systemGreen
                      : AppleColors.secondaryLabel,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppleSpacing.xs),
          Text(
            '첫 번째 사진이 대표 사진으로 표시됩니다',
            style: AppleTypography.caption1.copyWith(
              color: AppleColors.secondaryLabel,
            ),
          ),
          const SizedBox(height: AppleSpacing.sm),
          // 이미지 그리드
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: AppleSpacing.sm,
              mainAxisSpacing: AppleSpacing.sm,
            ),
            itemCount: _selectedImages.length < _maxImages
                ? _selectedImages.length + 1
                : _selectedImages.length,
            itemBuilder: (context, index) {
              // 마지막 슬롯: 추가 버튼
              if (index == _selectedImages.length && _selectedImages.length < _maxImages) {
                return _buildAddPhotoButton();
              }
              // 기존 이미지
              return _buildImageTile(index);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAddPhotoButton() {
    return GestureDetector(
      onTap: _pickImages,
      child: Container(
        decoration: BoxDecoration(
          color: AppleColors.secondarySystemGroupedBackground,
          borderRadius: BorderRadius.circular(AppleRadius.md),
          border: Border.all(
            color: AppleColors.separator,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.add_photo_alternate_outlined,
              size: 32,
              color: AppleColors.systemBlue,
            ),
            const SizedBox(height: AppleSpacing.xs),
            Text(
              '사진 추가',
              style: AppleTypography.caption1.copyWith(
                color: AppleColors.systemBlue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageTile(int index) {
    final image = _selectedImages[index];
    final isFirst = index == 0;

    return Stack(
      children: [
        // 이미지
        ClipRRect(
          borderRadius: BorderRadius.circular(AppleRadius.md),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isFirst ? AppleColors.systemGreen : Colors.transparent,
                width: isFirst ? 2 : 0,
              ),
              borderRadius: BorderRadius.circular(AppleRadius.md),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(isFirst ? AppleRadius.md - 2 : AppleRadius.md),
              child: kIsWeb
                  ? FutureBuilder<Uint8List>(
                      future: image.readAsBytes(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          return Image.memory(
                            snapshot.data!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          );
                        }
                        return const Center(child: CircularProgressIndicator());
                      },
                    )
                  : Image.file(
                      File(image.path),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
            ),
          ),
        ),
        // 대표 사진 배지
        if (isFirst)
          Positioned(
            top: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppleColors.systemGreen,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '대표',
                style: AppleTypography.caption2.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        // 삭제 버튼
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => _removeImage(index),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  /// 상세 정보 입력 섹션 (선택적)
  Widget _buildDetailInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 상세 정보 토글 버튼
        GestureDetector(
          onTap: () => setState(() => _showDetailFields = !_showDetailFields),
          child: Container(
            padding: const EdgeInsets.all(AppleSpacing.md),
            decoration: BoxDecoration(
              color: AppleColors.secondarySystemGroupedBackground,
              borderRadius: BorderRadius.circular(AppleRadius.md),
            ),
            child: Row(
              children: [
                Icon(
                  _showDetailFields ? Icons.remove_circle_outline : Icons.add_circle_outline,
                  color: AppleColors.systemBlue,
                  size: 20,
                ),
                const SizedBox(width: AppleSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '상세 정보 추가 (선택)',
                        style: AppleTypography.headline.copyWith(
                          color: AppleColors.systemBlue,
                        ),
                      ),
                      Text(
                        '층수, 방/화장실, 향, 옵션 등',
                        style: AppleTypography.caption1.copyWith(
                          color: AppleColors.secondaryLabel,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _showDetailFields ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: AppleColors.secondaryLabel,
                ),
              ],
            ),
          ),
        ),

        // 상세 정보 필드들 (토글 시 표시)
        if (_showDetailFields) ...[
          const SizedBox(height: AppleSpacing.md),
          _buildDetailFields(),
        ],
      ],
    );
  }

  /// 방문 가능 시간 설정 섹션
  Widget _buildVisitAvailabilitySection() {
    // 요일 목록 (월~일)
    const weekdays = [
      {'key': '1', 'name': '월', 'isWeekend': false},
      {'key': '2', 'name': '화', 'isWeekend': false},
      {'key': '3', 'name': '수', 'isWeekend': false},
      {'key': '4', 'name': '목', 'isWeekend': false},
      {'key': '5', 'name': '금', 'isWeekend': false},
      {'key': '6', 'name': '토', 'isWeekend': true},
      {'key': '7', 'name': '일', 'isWeekend': true},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '방문 가능 시간 (선택)',
          style: AppleTypography.headline.copyWith(
            color: AppleColors.label,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppleSpacing.xs),
        Text(
          '매주 반복되는 방문 가능 시간대를 설정하세요.',
          style: AppleTypography.caption1.copyWith(
            color: AppleColors.secondaryLabel,
          ),
        ),
        const SizedBox(height: AppleSpacing.md),

        Container(
          padding: const EdgeInsets.all(AppleSpacing.md),
          decoration: BoxDecoration(
            color: AppleColors.secondarySystemGroupedBackground,
            borderRadius: BorderRadius.circular(AppleRadius.md),
          ),
          child: Column(
            children: [
              // 요일 선택
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: weekdays.map((day) {
                  final dayKey = day['key'] as String;
                  final dayName = day['name'] as String;
                  final isWeekend = day['isWeekend'] as bool;
                  final hasSlots = _availableSlots[dayKey]?.isNotEmpty ?? false;

                  return GestureDetector(
                    onTap: () => _showWeekdaySlotPicker(dayKey, dayName),
                    child: Container(
                      width: 40,
                      height: 52,
                      decoration: BoxDecoration(
                        color: hasSlots
                            ? AppleColors.systemBlue.withValues(alpha: 0.1)
                            : AppleColors.tertiarySystemFill,
                        borderRadius: BorderRadius.circular(AppleRadius.sm),
                        border: hasSlots
                            ? Border.all(color: AppleColors.systemBlue, width: 1.5)
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            dayName,
                            style: AppleTypography.subheadline.copyWith(
                              color: hasSlots
                                  ? AppleColors.systemBlue
                                  : isWeekend
                                      ? AppleColors.systemRed
                                      : AppleColors.label,
                              fontWeight: hasSlots ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                          if (hasSlots)
                            Container(
                              width: 5,
                              height: 5,
                              margin: const EdgeInsets.only(top: 3),
                              decoration: const BoxDecoration(
                                color: AppleColors.systemBlue,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              // 선택된 시간대 요약
              if (_availableSlots.isNotEmpty) ...[
                const SizedBox(height: AppleSpacing.sm),
                Text(
                  _getAvailabilitySummary(),
                  style: AppleTypography.caption1.copyWith(
                    color: AppleColors.systemBlue,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _getAvailabilitySummary() {
    const weekdayNames = ['', '월', '화', '수', '목', '금', '토', '일'];
    final parts = <String>[];
    for (int i = 1; i <= 7; i++) {
      final slots = _availableSlots['$i'];
      if (slots != null && slots.isNotEmpty) {
        parts.add('${weekdayNames[i]} ${slots.length}개');
      }
    }
    return parts.join(' · ');
  }

  Future<void> _showWeekdaySlotPicker(String dayKey, String dayName) async {
    final existingSlots = List<TimeSlot>.from(_availableSlots[dayKey] ?? []);

    final timeOptions = [
      {'start': '09:00', 'end': '11:00', 'label': '오전 (9-11시)'},
      {'start': '11:00', 'end': '13:00', 'label': '점심 (11-13시)'},
      {'start': '14:00', 'end': '16:00', 'label': '오후 (14-16시)'},
      {'start': '16:00', 'end': '18:00', 'label': '저녁 (16-18시)'},
      {'start': '19:00', 'end': '21:00', 'label': '야간 (19-21시)'},
    ];

    final Set<String> selectedTimes = {};
    for (final slot in existingSlots) {
      selectedTimes.add('${slot.startTime}-${slot.endTime}');
    }

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: AppleColors.systemBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppleRadius.lg)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: AppleSpacing.sm),
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppleColors.separator,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppleSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 헤더
                      Text(
                        '매주 $dayName요일 방문 가능 시간',
                        style: AppleTypography.title3.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: AppleSpacing.lg),

                      ...timeOptions.map((option) {
                        final key = '${option['start']}-${option['end']}';
                        final isSelected = selectedTimes.contains(key);

                        return GestureDetector(
                          onTap: () {
                            setSheetState(() {
                              if (isSelected) {
                                selectedTimes.remove(key);
                              } else {
                                selectedTimes.add(key);
                              }
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: AppleSpacing.sm),
                            padding: const EdgeInsets.all(AppleSpacing.md),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppleColors.systemBlue.withValues(alpha: 0.1)
                                  : AppleColors.tertiarySystemFill,
                              borderRadius: BorderRadius.circular(AppleRadius.sm),
                              border: isSelected
                                  ? Border.all(color: AppleColors.systemBlue, width: 1.5)
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                                  color: isSelected
                                      ? AppleColors.systemBlue
                                      : AppleColors.tertiaryLabel,
                                  size: 22,
                                ),
                                const SizedBox(width: AppleSpacing.sm),
                                Text(
                                  option['label']!,
                                  style: AppleTypography.body.copyWith(
                                    color: isSelected
                                        ? AppleColors.systemBlue
                                        : AppleColors.label,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),

                      // 완료 버튼 (하단 큰 버튼)
                      const SizedBox(height: AppleSpacing.lg),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            final newSlots = <TimeSlot>[];
                            for (final option in timeOptions) {
                              final key = '${option['start']}-${option['end']}';
                              if (selectedTimes.contains(key)) {
                                newSlots.add(TimeSlot(
                                  startTime: option['start']!,
                                  endTime: option['end']!,
                                ));
                              }
                            }

                            setState(() {
                              if (newSlots.isEmpty) {
                                _availableSlots.remove(dayKey);
                              } else {
                                _availableSlots[dayKey] = newSlots;
                              }
                            });
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppleColors.systemBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: AppleSpacing.md),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppleRadius.sm),
                            ),
                          ),
                          child: Text(
                            '완료',
                            style: AppleTypography.body.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailFields() {
    return Container(
      padding: const EdgeInsets.all(AppleSpacing.md),
      decoration: BoxDecoration(
        color: AppleColors.secondarySystemGroupedBackground,
        borderRadius: BorderRadius.circular(AppleRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 층수/방/화장실 입력
          Row(
            children: [
              Expanded(
                child: _buildNumberField(
                  label: '층수',
                  value: _floor,
                  onChanged: (val) => setState(() => _floor = val),
                  suffix: '층',
                ),
              ),
              const SizedBox(width: AppleSpacing.sm),
              Expanded(
                child: _buildNumberField(
                  label: '방',
                  value: _rooms,
                  onChanged: (val) => setState(() => _rooms = val),
                  suffix: '개',
                ),
              ),
              const SizedBox(width: AppleSpacing.sm),
              Expanded(
                child: _buildNumberField(
                  label: '화장실',
                  value: _bathrooms,
                  onChanged: (val) => setState(() => _bathrooms = val),
                  suffix: '개',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppleSpacing.md),

          // 향 선택
          _buildSelectionField(
            label: '향',
            options: _directions,
            selectedValue: _direction,
            onSelected: (val) => setState(() => _direction = val),
          ),
          const SizedBox(height: AppleSpacing.md),

          // 옵션 선택 (다중 선택)
          _buildOptionsField(),
          const SizedBox(height: AppleSpacing.md),

          // 자유 입력 메모
          _buildNotesField(),
        ],
      ),
    );
  }

  Widget _buildNumberField({
    required String label,
    required int? value,
    required ValueChanged<int?> onChanged,
    required String suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppleTypography.subheadline.copyWith(
            color: AppleColors.secondaryLabel,
          ),
        ),
        const SizedBox(height: AppleSpacing.xs),
        Row(
          children: [
            // 감소 버튼
            GestureDetector(
              onTap: () {
                if (value != null && value > 1) {
                  onChanged(value - 1);
                }
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppleColors.tertiarySystemFill,
                  borderRadius: BorderRadius.circular(AppleRadius.sm),
                ),
                child: const Icon(Icons.remove, size: 18, color: AppleColors.secondaryLabel),
              ),
            ),
            const SizedBox(width: AppleSpacing.sm),
            // 값 표시
            Expanded(
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  color: AppleColors.systemBackground,
                  borderRadius: BorderRadius.circular(AppleRadius.sm),
                  border: Border.all(color: AppleColors.separator),
                ),
                child: Center(
                  child: Text(
                    value != null ? '$value$suffix' : '-',
                    style: AppleTypography.body.copyWith(
                      color: AppleColors.label,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppleSpacing.sm),
            // 증가 버튼
            GestureDetector(
              onTap: () {
                onChanged((value ?? 0) + 1);
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppleColors.systemBlue,
                  borderRadius: BorderRadius.circular(AppleRadius.sm),
                ),
                child: const Icon(Icons.add, size: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSelectionField({
    required String label,
    required List<String> options,
    required String? selectedValue,
    required ValueChanged<String?> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppleTypography.subheadline.copyWith(
            color: AppleColors.secondaryLabel,
          ),
        ),
        const SizedBox(height: AppleSpacing.xs),
        Wrap(
          spacing: AppleSpacing.xs,
          runSpacing: AppleSpacing.xs,
          children: options.map((option) {
            final isSelected = selectedValue == option;
            return GestureDetector(
              onTap: () => onSelected(isSelected ? null : option),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppleSpacing.sm,
                  vertical: AppleSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppleColors.systemBlue
                      : AppleColors.systemBackground,
                  borderRadius: BorderRadius.circular(AppleRadius.sm),
                  border: Border.all(
                    color: isSelected ? AppleColors.systemBlue : AppleColors.separator,
                  ),
                ),
                child: Text(
                  option,
                  style: AppleTypography.subheadline.copyWith(
                    color: isSelected ? Colors.white : AppleColors.label,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildOptionsField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '옵션',
          style: AppleTypography.subheadline.copyWith(
            color: AppleColors.secondaryLabel,
          ),
        ),
        const SizedBox(height: AppleSpacing.xs),
        Wrap(
          spacing: AppleSpacing.xs,
          runSpacing: AppleSpacing.xs,
          children: _availableOptions.map((option) {
            final isSelected = _selectedOptions.contains(option);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedOptions.remove(option);
                  } else {
                    _selectedOptions.add(option);
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppleSpacing.sm,
                  vertical: AppleSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppleColors.systemGreen.withValues(alpha: 0.1)
                      : AppleColors.systemBackground,
                  borderRadius: BorderRadius.circular(AppleRadius.sm),
                  border: Border.all(
                    color: isSelected ? AppleColors.systemGreen : AppleColors.separator,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected) ...[
                      const Icon(Icons.check, size: 14, color: AppleColors.systemGreen),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      option,
                      style: AppleTypography.subheadline.copyWith(
                        color: isSelected ? AppleColors.systemGreen : AppleColors.label,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildNotesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '추가 설명',
          style: AppleTypography.subheadline.copyWith(
            color: AppleColors.secondaryLabel,
          ),
        ),
        const SizedBox(height: AppleSpacing.xs),
        TextFormField(
          controller: _notesController,
          maxLines: 3,
          maxLength: 200,
          decoration: InputDecoration(
            hintText: '매물에 대한 추가 정보를 자유롭게 입력하세요\n(예: 리모델링 완료, 조용한 동네, 학군 좋음 등)',
            hintStyle: AppleTypography.body.copyWith(
              color: AppleColors.tertiaryLabel,
              height: 1.4,
            ),
            filled: true,
            fillColor: AppleColors.systemBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppleRadius.sm),
              borderSide: const BorderSide(color: AppleColors.separator),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppleRadius.sm),
              borderSide: const BorderSide(color: AppleColors.separator),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppleRadius.sm),
              borderSide: const BorderSide(color: AppleColors.systemBlue, width: 1.5),
            ),
            contentPadding: const EdgeInsets.all(AppleSpacing.md),
            counterStyle: AppleTypography.caption2.copyWith(
              color: AppleColors.tertiaryLabel,
            ),
          ),
          style: AppleTypography.body.copyWith(color: AppleColors.label),
        ),
      ],
    );
  }

  Widget _buildStepLabel(String label, {required int stepNumber}) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: AppleColors.systemBlue,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$stepNumber',
              style: AppleTypography.caption1.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppleSpacing.sm),
        Text(
          label,
          style: AppleTypography.headline.copyWith(
            color: AppleColors.label,
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedStep({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onEdit,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppleSpacing.md),
      decoration: BoxDecoration(
        color: AppleColors.systemGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppleRadius.md),
        border: Border.all(
          color: AppleColors.systemGreen.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle,
            color: AppleColors.systemGreen,
            size: 20,
          ),
          const SizedBox(width: AppleSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppleTypography.caption1.copyWith(
                    color: AppleColors.secondaryLabel,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppleTypography.body.copyWith(
                    color: AppleColors.label,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onEdit,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: AppleSpacing.sm),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              '수정',
              style: AppleTypography.footnote.copyWith(
                color: AppleColors.systemBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextButton({
    required VoidCallback onPressed,
    required String label,
  }) {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppleColors.systemBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppleRadius.md),
          ),
        ),
        child: Text(
          label,
          style: AppleTypography.body.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomArea() {
    // 모든 단계 완료 시 등록 버튼 표시
    final isComplete = _currentStep >= 2 && _selectedImages.isNotEmpty;

    if (!isComplete) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppleSpacing.lg),
      decoration: BoxDecoration(
        color: AppleColors.systemBackground,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 안내 문구
            Container(
              padding: const EdgeInsets.all(AppleSpacing.md),
              decoration: BoxDecoration(
                color: AppleColors.tertiarySystemFill,
                borderRadius: BorderRadius.circular(AppleRadius.md),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppleColors.secondaryLabel,
                    size: 18,
                  ),
                  const SizedBox(width: AppleSpacing.sm),
                  Expanded(
                    child: Text(
                      '상세 정보는 나중에 추가할 수 있어요',
                      style: AppleTypography.footnote.copyWith(
                        color: AppleColors.secondaryLabel,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppleSpacing.md),
            // 등록 버튼
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitQuickRegistration,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppleColors.systemBlue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppleColors.secondarySystemFill,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppleRadius.md),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        '등록 완료',
                        style: AppleTypography.headline.copyWith(
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _pickImages() async {
    try {
      final remainingSlots = _maxImages - _selectedImages.length;
      if (remainingSlots <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '최대 $_maxImages장까지만 업로드할 수 있습니다.',
              style: AppleTypography.body.copyWith(color: Colors.white),
            ),
            backgroundColor: AppleColors.systemOrange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final List<XFile> images = await _imagePicker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        setState(() {
          // 최대 개수 제한
          final imagesToAdd = images.take(remainingSlots).toList();
          _selectedImages.addAll(imagesToAdd);

          if (images.length > remainingSlots) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${images.length - remainingSlots}장은 추가되지 않았습니다. (최대 $_maxImages장)',
                  style: AppleTypography.body.copyWith(color: Colors.white),
                ),
                backgroundColor: AppleColors.systemOrange,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        });
      }
    } catch (e) {
      Logger.error('Failed to pick images', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '사진을 선택할 수 없습니다.',
              style: AppleTypography.body.copyWith(color: Colors.white),
            ),
            backgroundColor: AppleColors.systemRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppleRadius.md),
            ),
          ),
        );
      }
    }
  }

  Widget _buildAddressSearchResults() {
    // 로딩 중
    if (isAddressSearching) {
      return Container(
        padding: const EdgeInsets.all(AppleSpacing.lg),
        decoration: BoxDecoration(
          color: AppleColors.secondarySystemGroupedBackground,
          borderRadius: BorderRadius.circular(AppleRadius.md),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    // 에러 메시지
    if (addressErrorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(AppleSpacing.md),
        decoration: BoxDecoration(
          color: AppleColors.secondarySystemGroupedBackground,
          borderRadius: BorderRadius.circular(AppleRadius.md),
        ),
        child: Text(
          addressErrorMessage!,
          style: AppleTypography.footnote.copyWith(
            color: AppleColors.systemRed,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    // 검색 결과 - 스크롤 없이 전체 표시
    if (addressList.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: AppleColors.systemBackground,
        borderRadius: BorderRadius.circular(AppleRadius.md),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppleRadius.md),
        child: RoadAddressList(
          fullAddrAPIDatas: addressSearchResults,
          addresses: addressList,
          selectedAddress: '',
          onSelect: (fullData, displayAddr) {
            final roadAddr = (fullData['roadAddr'] ?? '').trim();
            final jibunAddr = (fullData['jibunAddr'] ?? '').trim();
            final cleanAddress = roadAddr.isNotEmpty ? roadAddr : jibunAddr;

            setState(() {
              _addressController.text = cleanAddress;
              addressSearchResults = [];
              addressList = [];
              _isMainAddressSelected = true;
              _selectedFullData = fullData;
              _latitude = null;
              _longitude = null;
              // 주소 변경 시 시세 확인 상태 및 가격 초기화
              _hasCheckedMarketPrice = false;
              _priceController.clear();
              _priceUkController.clear();
              _priceManController.clear();
              _depositController.clear();
              _depositUkController.clear();
              _depositManController.clear();
            });

            // 좌표 가져오기 (지도 표시용)
            _fetchCoordinates(cleanAddress, fullData);

            // 세부 주소 입력 필드로 포커스
            Future.delayed(const Duration(milliseconds: 100), () {
              _detailAddressFocusNode.requestFocus();
            });
          },
        ),
      ),
    );
  }

  /// 폼 초기화 - 등록 완료 후 처음 상태로
  void _resetForm() {
    setState(() {
      _currentStep = 0;
      _transactionType = '매매';
      _addressController.clear();
      _detailAddressController.clear();
      _priceController.clear();
      _priceUkController.clear();
      _priceManController.clear();
      _depositController.clear();
      _depositUkController.clear();
      _depositManController.clear();
      _selectedImages.clear();
      _isMainAddressSelected = false;
      _selectedFullData = null;
      _latitude = null;
      _longitude = null;
      addressSearchResults = [];
      addressList = [];
      addressErrorMessage = null;
      _hasCheckedMarketPrice = false;
      // 상세 정보 초기화
      _showDetailFields = false;
      _floor = null;
      _rooms = null;
      _bathrooms = null;
      _direction = null;
      _selectedOptions.clear();
      _notesController.clear();
      _availableSlots.clear();
    });
  }

  Future<void> _submitQuickRegistration() async {
    if (_addressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('주소를 입력해주세요'),
          backgroundColor: AppleColors.systemOrange,
        ),
      );
      return;
    }

    final price = double.tryParse(_priceController.text);
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('올바른 가격을 입력해주세요'),
          backgroundColor: AppleColors.systemOrange,
        ),
      );
      return;
    }

    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('사진을 1장 이상 선택해주세요'),
          backgroundColor: AppleColors.systemOrange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('로그인이 필요합니다');
      }

      // 1. 다중 이미지 업로드
      final List<String> uploadedImageUrls = [];
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      for (int i = 0; i < _selectedImages.length; i++) {
        final image = _selectedImages[i];
        final path = 'mls_properties/${user.uid}/image_${timestamp}_$i.jpg';
        final url = await _storageService.uploadImage(
          file: image,
          path: path,
        );
        if (url != null) {
          uploadedImageUrls.add(url);
        }
      }

      if (uploadedImageUrls.isEmpty) {
        throw Exception('이미지 업로드에 실패했습니다');
      }

      // 첫 번째 이미지를 대표 사진으로 사용
      final thumbnailUrl = uploadedImageUrls.first;

      // 2. 지역 추출 (주소에서)
      String region = 'SEOUL'; // 기본값
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

      // 3. 매물 ID 생성
      final sequence = await _mlsService.getNextSequence(region);
      final propertyId = MLSProperty.generateId(region, sequence);
      final now = DateTime.now();

      // 4. MLSProperty 객체 생성 (상세 정보 포함)
      final property = MLSProperty(
        id: propertyId,
        propertyId: '',
        userId: user.uid,
        userName: user.displayName ?? user.email ?? '',
        address: _fullAddress,
        roadAddress: _addressController.text,
        jibunAddress: _selectedFullData?['jibunAddr'] ?? '',
        buildingName: _selectedFullData?['bdNm'] ?? '',
        latitude: _latitude,
        longitude: _longitude,
        // 상세 정보
        floor: _floor,
        rooms: _rooms,
        bathrooms: _bathrooms,
        direction: _direction,
        options: _selectedOptions.toList(),
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        // 거래 유형 및 가격
        transactionType: _transactionType,
        desiredPrice: price,
        deposit: _transactionType == '월세' ? double.tryParse(_depositController.text) : null,
        imageUrls: uploadedImageUrls,
        thumbnailUrl: thumbnailUrl,
        region: region,
        district: _selectedFullData?['siNm'] ?? '',
        status: PropertyStatus.active, // 등록 완료 시 active 상태
        availableSlots: _availableSlots,
        createdAt: now,
        updatedAt: now,
      );

      // 5. Firestore에 저장
      await _mlsService.createProperty(property);

      // 6. 자동 배포 - 주변 중개사 검색 후 플랫폼 가입 중개사만 배포
      int broadcastCount = 0;
      try {
        if (_latitude != null && _longitude != null) {
          final brokerResult = await BrokerService.searchNearbyBrokers(
            latitude: _latitude!,
            longitude: _longitude!,
            radiusMeters: 3000, // 3km 반경
          );

          if (brokerResult.brokers.isNotEmpty) {
            // 외부 API 등록번호 목록
            final externalRegNumbers = brokerResult.brokers.map((b) => b.registrationNumber).toList();

            // 플랫폼에 실제 가입된 중개사만 필터링
            final firebaseService = FirebaseService();
            final registeredBrokers = await firebaseService.getBrokersByRegistrationNumbers(externalRegNumbers);

            if (registeredBrokers.isNotEmpty) {
              // 플랫폼 중개사의 UID를 사용 (Firestore document ID)
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
        // 자동 배포 실패는 무시
      }

      if (mounted) {
        // 성공 다이얼로그 표시
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppleRadius.lg),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle,
                  color: AppleColors.systemGreen,
                  size: 64,
                ),
                const SizedBox(height: AppleSpacing.md),
                Text(
                  '매물 등록 완료!',
                  style: AppleTypography.title2.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppleSpacing.sm),
                Text(
                  broadcastCount > 0
                      ? '매물이 등록되고 $broadcastCount개 중개사에게\n자동 배포되었습니다.'
                      : '매물이 등록되었습니다.\n주변 중개사가 없어 배포 대기 중입니다.',
                  style: AppleTypography.body.copyWith(
                    color: AppleColors.secondaryLabel,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: Text(
                  '확인',
                  style: AppleTypography.body.copyWith(
                    color: AppleColors.systemBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );

        // 폼 초기화
        _resetForm();

        // 등록 완료 콜백 호출 (내 매물 탭으로 이동)
        widget.onRegistrationComplete?.call();
      }
    } catch (e) {
      Logger.error('Failed to register property', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '매물 등록에 실패했습니다: ${e.toString()}',
              style: AppleTypography.body.copyWith(color: Colors.white),
            ),
            backgroundColor: AppleColors.systemRed,
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
