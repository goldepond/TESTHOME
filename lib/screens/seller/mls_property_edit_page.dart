import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/mls_property.dart';
import '../../api_request/mls_property_service.dart';
import '../../api_request/storage_service.dart';
import '../../constants/apple_design_system.dart';
import '../../utils/logger.dart';

/// 매물 정보 수정 페이지
class MLSPropertyEditPage extends StatefulWidget {
  final MLSProperty property;

  const MLSPropertyEditPage({required this.property, super.key});

  @override
  State<MLSPropertyEditPage> createState() => _MLSPropertyEditPageState();
}

class _MLSPropertyEditPageState extends State<MLSPropertyEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _mlsService = MLSPropertyService();
  final _storageService = StorageService();

  late TextEditingController _priceController;
  late TextEditingController _buildingNameController;

  bool _isSubmitting = false;
  bool _negotiable = true;

  // 이미지 관리 (다중 이미지 지원)
  List<_ImageItem> _images = [];
  static const int _maxImages = 10;

  // 방문 가능 시간 설정
  Map<String, List<TimeSlot>> _availableSlots = {};

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(
      text: widget.property.desiredPrice.toInt().toString(),
    );
    _buildingNameController = TextEditingController(
      text: widget.property.buildingName,
    );
    _negotiable = widget.property.negotiable;

    // 기존 이미지 로드
    _loadExistingImages();

    // 방문 가능 시간 로드
    _availableSlots = Map.from(widget.property.availableSlots);
  }

  void _loadExistingImages() {
    final existingUrls = widget.property.imageUrls;
    if (existingUrls.isNotEmpty) {
      _images = existingUrls.map((url) => _ImageItem(existingUrl: url)).toList();
    } else if (widget.property.thumbnailUrl != null) {
      _images = [_ImageItem(existingUrl: widget.property.thumbnailUrl!)];
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    _buildingNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = AppleResponsive.isMobile(context);

    return Scaffold(
      backgroundColor: AppleColors.systemGroupedBackground,
      appBar: AppBar(
        backgroundColor: AppleColors.systemBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppleColors.label),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '매물 정보 수정',
          style: AppleTypography.headline.copyWith(color: AppleColors.label),
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _saveChanges,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    '저장',
                    style: AppleTypography.body.copyWith(
                      color: AppleColors.systemBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? AppleSpacing.md : AppleSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 주소 정보 (읽기 전용)
              _buildSectionTitle('주소'),
              _buildReadOnlyCard(
                icon: Icons.location_on_outlined,
                title: widget.property.roadAddress,
                subtitle: widget.property.jibunAddress,
              ),

              const SizedBox(height: AppleSpacing.xl),

              // 이미지 섹션 (다중 이미지)
              _buildSectionTitle('사진 (${_images.length}/$_maxImages)'),
              _buildImageGallerySection(),

              const SizedBox(height: AppleSpacing.xl),

              // 가격 섹션
              _buildSectionTitle('희망 가격'),
              _buildPriceSection(),

              const SizedBox(height: AppleSpacing.xl),

              // 건물명 섹션
              _buildSectionTitle('건물명 (선택)'),
              _buildBuildingNameSection(),

              const SizedBox(height: AppleSpacing.xl),

              // 방문 가능 시간 섹션
              _buildSectionTitle('방문 가능 시간'),
              _buildVisitAvailabilitySection(),

              const SizedBox(height: AppleSpacing.xl),

              // 매물 ID 정보
              _buildSectionTitle('매물 정보'),
              _buildReadOnlyCard(
                icon: Icons.tag,
                title: '매물 ID',
                subtitle: widget.property.id,
              ),

              const SizedBox(height: AppleSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppleSpacing.sm),
      child: Text(
        title,
        style: AppleTypography.headline.copyWith(
          color: AppleColors.label,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildReadOnlyCard({
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
    return AppleCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppleColors.systemBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppleRadius.sm),
            ),
            child: Icon(icon, color: AppleColors.systemBlue, size: 22),
          ),
          const SizedBox(width: AppleSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppleTypography.body.copyWith(color: AppleColors.label),
                ),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppleTypography.caption1.copyWith(
                      color: AppleColors.secondaryLabel,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGallerySection() {
    return AppleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 안내 텍스트
          Text(
            '첫 번째 사진이 대표 사진으로 사용됩니다',
            style: AppleTypography.caption1.copyWith(
              color: AppleColors.secondaryLabel,
            ),
          ),
          const SizedBox(height: AppleSpacing.md),

          // 이미지 그리드
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _images.length + (_images.length < _maxImages ? 1 : 0),
            itemBuilder: (context, index) {
              // 마지막은 추가 버튼
              if (index == _images.length) {
                return _buildAddImageButton();
              }
              return _buildImageTile(index);
            },
          ),

          // 이미지가 있으면 순서 변경 안내
          if (_images.length > 1) ...[
            const SizedBox(height: AppleSpacing.sm),
            Text(
              '길게 눌러 순서 변경 · 탭하여 수정/삭제',
              style: AppleTypography.caption2.copyWith(
                color: AppleColors.tertiaryLabel,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImageTile(int index) {
    final item = _images[index];
    final isFirst = index == 0;

    return GestureDetector(
      onTap: () => _showImageOptions(index),
      onLongPress: () => _showReorderSheet(),
      child: Stack(
        children: [
          // 이미지
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppleRadius.sm),
              border: isFirst
                  ? Border.all(color: AppleColors.systemBlue, width: 2)
                  : Border.all(color: AppleColors.separator),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppleRadius.sm - 1),
              child: item.newFile != null
                  ? Image.file(
                      File(item.newFile!.path),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (_, a, b) => _buildImageError(),
                    )
                  : Image.network(
                      item.existingUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (_, a, b) => _buildImageError(),
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
                  color: AppleColors.systemBlue,
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
                width: 24,
                height: 24,
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
      ),
    );
  }

  Widget _buildAddImageButton() {
    return GestureDetector(
      onTap: _addImages,
      child: Container(
        decoration: BoxDecoration(
          color: AppleColors.tertiarySystemFill,
          borderRadius: BorderRadius.circular(AppleRadius.sm),
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
              color: AppleColors.secondaryLabel,
            ),
            const SizedBox(height: 4),
            Text(
              '추가',
              style: AppleTypography.caption2.copyWith(
                color: AppleColors.secondaryLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageError() {
    return Container(
      color: AppleColors.tertiarySystemFill,
      child: const Center(
        child: Icon(
          Icons.broken_image,
          color: AppleColors.tertiaryLabel,
        ),
      ),
    );
  }

  /// 이미지 추가
  Future<void> _addImages() async {
    if (_images.length >= _maxImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('최대 $_maxImages장까지 등록 가능합니다'),
          backgroundColor: AppleColors.systemOrange,
        ),
      );
      return;
    }

    final images = await _storageService.pickMultipleImages(
      maxImages: _maxImages - _images.length,
    );

    if (images != null && images.isNotEmpty) {
      setState(() {
        _images.addAll(images.map((f) => _ImageItem(newFile: f)));
      });
    }
  }

  /// 이미지 삭제
  void _removeImage(int index) {
    // 마지막 이미지는 삭제 불가 (최소 1장 필요)
    if (_images.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('최소 1장의 사진이 필요합니다'),
          backgroundColor: AppleColors.systemOrange,
        ),
      );
      return;
    }

    setState(() {
      _images.removeAt(index);
    });
  }

  /// 이미지 옵션 (교체/삭제/대표 설정)
  void _showImageOptions(int index) {
    final isFirst = index == 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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
              const SizedBox(height: AppleSpacing.md),

              // 사진 교체
              ListTile(
                leading: const Icon(Icons.swap_horiz, color: AppleColors.systemBlue),
                title: const Text('사진 교체'),
                onTap: () {
                  Navigator.pop(context);
                  _replaceImage(index);
                },
              ),

              // 대표 사진으로 설정
              if (!isFirst)
                ListTile(
                  leading: const Icon(Icons.star, color: AppleColors.systemOrange),
                  title: const Text('대표 사진으로 설정'),
                  onTap: () {
                    Navigator.pop(context);
                    _setAsThumbnail(index);
                  },
                ),

              // 삭제
              if (_images.length > 1)
                ListTile(
                  leading: const Icon(Icons.delete, color: AppleColors.systemRed),
                  title: const Text(
                    '삭제',
                    style: TextStyle(color: AppleColors.systemRed),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _removeImage(index);
                  },
                ),

              const SizedBox(height: AppleSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  /// 이미지 교체
  Future<void> _replaceImage(int index) async {
    final image = await _storageService.pickImage();
    if (image != null) {
      setState(() {
        _images[index] = _ImageItem(newFile: image);
      });
    }
  }

  /// 대표 사진으로 설정 (맨 앞으로 이동)
  void _setAsThumbnail(int index) {
    if (index == 0) return;

    setState(() {
      final item = _images.removeAt(index);
      _images.insert(0, item);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('대표 사진으로 설정되었습니다'),
        backgroundColor: AppleColors.systemGreen,
      ),
    );
  }

  /// 순서 변경 시트
  void _showReorderSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppleColors.systemBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppleRadius.lg)),
          ),
          child: Column(
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
                padding: const EdgeInsets.all(AppleSpacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '사진 순서 변경',
                      style: AppleTypography.headline.copyWith(fontWeight: FontWeight.w600),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('완료'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ReorderableListView.builder(
                  scrollController: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: AppleSpacing.md),
                  itemCount: _images.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex--;
                      final item = _images.removeAt(oldIndex);
                      _images.insert(newIndex, item);
                    });
                  },
                  itemBuilder: (context, index) {
                    final item = _images[index];
                    return ListTile(
                      key: ValueKey('image_$index'),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 60,
                          height: 60,
                          child: item.newFile != null
                              ? Image.file(File(item.newFile!.path), fit: BoxFit.cover)
                              : Image.network(item.existingUrl!, fit: BoxFit.cover),
                        ),
                      ),
                      title: Text(index == 0 ? '대표 사진' : '사진 ${index + 1}'),
                      trailing: const Icon(Icons.drag_handle),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceSection() {
    return AppleCard(
      child: Column(
        children: [
          TextFormField(
            controller: _priceController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: AppleTypography.title2.copyWith(
              fontWeight: FontWeight.w700,
              color: AppleColors.label,
            ),
            decoration: InputDecoration(
              hintText: '희망 가격 입력',
              hintStyle: AppleTypography.title2.copyWith(
                color: AppleColors.tertiaryLabel,
              ),
              suffixText: '만원',
              suffixStyle: AppleTypography.body.copyWith(
                color: AppleColors.secondaryLabel,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '가격을 입력해주세요';
              }
              final price = double.tryParse(value);
              if (price == null || price <= 0) {
                return '올바른 가격을 입력해주세요';
              }
              return null;
            },
          ),
          const Divider(height: AppleSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '가격 협의 가능',
                style: AppleTypography.body.copyWith(color: AppleColors.label),
              ),
              Switch.adaptive(
                value: _negotiable,
                onChanged: (value) => setState(() => _negotiable = value),
                activeTrackColor: AppleColors.systemBlue,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBuildingNameSection() {
    return AppleCard(
      child: TextFormField(
        controller: _buildingNameController,
        style: AppleTypography.body.copyWith(color: AppleColors.label),
        decoration: InputDecoration(
          hintText: '아파트/빌라/오피스텔 이름',
          hintStyle: AppleTypography.body.copyWith(
            color: AppleColors.tertiaryLabel,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

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

    return AppleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '매주 반복되는 방문 가능 시간대를 설정하세요.',
            style: AppleTypography.caption1.copyWith(
              color: AppleColors.secondaryLabel,
            ),
          ),
          const SizedBox(height: AppleSpacing.md),

          // 요일 선택
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: weekdays.map((day) {
              final dayKey = day['key'] as String;
              final dayName = day['name'] as String;
              final isWeekend = day['isWeekend'] as bool;
              final hasSlots = _availableSlots[dayKey]?.isNotEmpty ?? false;

              return GestureDetector(
                onTap: () => _showWeekdayTimeSlotPicker(dayKey, dayName),
                child: Container(
                  width: 44,
                  height: 56,
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
                        style: AppleTypography.headline.copyWith(
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
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(top: 4),
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
            const SizedBox(height: AppleSpacing.md),
            const Divider(height: 1),
            const SizedBox(height: AppleSpacing.sm),
            _buildAvailabilitySummary(),
          ],
        ],
      ),
    );
  }

  Widget _buildAvailabilitySummary() {
    const weekdayNames = ['', '월', '화', '수', '목', '금', '토', '일'];
    final summaryParts = <String>[];

    for (int i = 1; i <= 7; i++) {
      final slots = _availableSlots['$i'];
      if (slots != null && slots.isNotEmpty) {
        summaryParts.add('${weekdayNames[i]} ${slots.length}개');
      }
    }

    return Text(
      summaryParts.join(' · '),
      style: AppleTypography.subheadline.copyWith(
        color: AppleColors.systemBlue,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  /// 요일별 시간대 선택 다이얼로그
  Future<void> _showWeekdayTimeSlotPicker(String dayKey, String dayName) async {
    final existingSlots = List<TimeSlot>.from(_availableSlots[dayKey] ?? []);

    // 기본 시간대 옵션
    final timeOptions = [
      {'start': '09:00', 'end': '11:00', 'label': '오전 (9-11시)'},
      {'start': '11:00', 'end': '13:00', 'label': '점심 (11-13시)'},
      {'start': '14:00', 'end': '16:00', 'label': '오후 (14-16시)'},
      {'start': '16:00', 'end': '18:00', 'label': '저녁 (16-18시)'},
      {'start': '19:00', 'end': '21:00', 'label': '야간 (19-21시)'},
    ];

    // 기존 선택된 시간대 확인
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
                // 핸들바
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

                      // 시간대 옵션들
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

                      // 전체 선택/해제 버튼
                      const SizedBox(height: AppleSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setSheetState(() {
                                  selectedTimes.clear();
                                });
                              },
                              child: const Text('전체 해제'),
                            ),
                          ),
                          const SizedBox(width: AppleSpacing.sm),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setSheetState(() {
                                  for (final option in timeOptions) {
                                    selectedTimes.add('${option['start']}-${option['end']}');
                                  }
                                });
                              },
                              child: const Text('전체 선택'),
                            ),
                          ),
                        ],
                      ),

                      // 완료 버튼 (하단 큰 버튼)
                      const SizedBox(height: AppleSpacing.lg),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            // 선택 완료
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

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('최소 1장의 사진이 필요합니다'),
          backgroundColor: AppleColors.systemOrange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // 모든 이미지 URL 목록 생성
      final List<String> finalImageUrls = [];

      for (int i = 0; i < _images.length; i++) {
        final item = _images[i];

        if (item.newFile != null) {
          // 새 이미지 업로드
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final path = 'mls_properties/${widget.property.userId}/image_${timestamp}_$i.jpg';
          final uploadedUrl = await _storageService.uploadImage(
            file: item.newFile!,
            path: path,
          );

          if (uploadedUrl == null) {
            throw Exception('이미지 업로드에 실패했습니다 (${i + 1}번째)');
          }
          finalImageUrls.add(uploadedUrl);
        } else if (item.existingUrl != null) {
          // 기존 이미지 유지
          finalImageUrls.add(item.existingUrl!);
        }
      }

      // 업데이트할 데이터 준비
      final updateData = <String, dynamic>{
        'desiredPrice': double.parse(_priceController.text),
        'negotiable': _negotiable,
        'buildingName': _buildingNameController.text.trim(),
        'updatedAt': DateTime.now().toIso8601String(),
        'imageUrls': finalImageUrls,
        'thumbnailUrl': finalImageUrls.isNotEmpty ? finalImageUrls.first : null,
        'availableSlots': _availableSlots.map(
          (date, slots) => MapEntry(date, slots.map((s) => s.toMap()).toList()),
        ),
      };

      await _mlsService.updateProperty(widget.property.id, updateData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('매물 정보가 수정되었습니다'),
            backgroundColor: AppleColors.systemGreen,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      Logger.error('Failed to update property', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('수정에 실패했습니다. 잠시 후 다시 시도해 주세요.'),
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

/// 이미지 아이템 (기존 URL 또는 새 파일)
class _ImageItem {
  final String? existingUrl;
  final XFile? newFile;

  _ImageItem({this.existingUrl, this.newFile})
      : assert(existingUrl != null || newFile != null, '이미지가 필요합니다');
}
