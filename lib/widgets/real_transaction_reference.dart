import 'package:flutter/material.dart';
import '../api_request/real_transaction_service.dart';
import '../constants/app_constants.dart';
import '../constants/typography.dart';
import '../constants/spacing.dart';
import 'price_trend_chart.dart';

/// 등록 플로우에서 최근 실거래가를 참고로 보여주는 위젯
class RealTransactionReference extends StatefulWidget {
  final Map<String, String>? addressData;
  final String transactionType; // 매매/전세/월세
  final ValueChanged<int>? onPriceSelected;
  final double? referenceArea; // 참고할 면적 (자동 카테고리 선택용)
  final VoidCallback? onDataLoaded; // 데이터 로드 완료 콜백
  final bool initiallyExpanded; // 초기 펼침 상태
  final bool embedded; // 임베디드 모드 (컨테이너 없이 내용만 표시)

  const RealTransactionReference({
    required this.addressData,
    required this.transactionType,
    super.key,
    this.onPriceSelected,
    this.referenceArea,
    this.onDataLoaded,
    this.initiallyExpanded = true,
    this.embedded = false, // 기본값: 컨테이너 포함
  });

  @override
  State<RealTransactionReference> createState() =>
      _RealTransactionReferenceState();
}

class _RealTransactionReferenceState extends State<RealTransactionReference> {
  bool _isExpanded = false;
  bool _isLoading = false;
  bool _isLoadingMore = false; // 백그라운드 로딩 상태
  List<RealTransaction> _transactions = [];
  String? _errorMessage;

  // 고정값
  final int _selectedMonths = 12; // 12개월 고정
  final SearchScope _selectedSearchScope = SearchScope.sameRoad; // 같은 도로 고정

  // 필터 옵션
  AreaCategory? _selectedAreaCategory;
  FloorCategory? _selectedFloorCategory;
  BuildYearCategory? _selectedBuildYearCategory;
  ContractTypeFilter? _selectedContractType;

  // 순차적 필터용 선택 완료 플래그
  bool _areaSelected = false;
  bool _floorSelected = false;
  bool _buildYearSelected = false;

  // 이전 요청 파라미터 캐시 (변경 시 재조회)
  String? _lastFilterHash;

  /// 필터 상태를 해시로 변환 (캐시 키로 사용)
  String _computeFilterHash(String? lawdCd, String? aptName) {
    return [
      lawdCd,
      aptName,
      widget.transactionType,
      _selectedAreaCategory?.label,
      _selectedSearchScope.label,
      _selectedFloorCategory?.label,
      _selectedBuildYearCategory?.label,
      _selectedContractType?.label,
      _selectedMonths.toString(),
    ].join('|');
  }

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    // 참고 면적이 있으면 자동으로 해당 카테고리 선택
    if (widget.referenceArea != null) {
      _selectedAreaCategory = AreaCategory.fromArea(widget.referenceArea!);
    }
    // 초기에 펼쳐진 상태면 데이터 로드 (embedded 모드 제외 - 순차적 필터 사용)
    if (_isExpanded && !widget.embedded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchData();
      });
    }
  }

  @override
  void didUpdateWidget(RealTransactionReference oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 거래 유형이 변경되면 데이터 재조회
    if (oldWidget.transactionType != widget.transactionType &&
        _isExpanded &&
        _transactions.isNotEmpty) {
      _fetchData();
    }
    // 참고 면적이 변경되면 카테고리 업데이트
    if (oldWidget.referenceArea != widget.referenceArea &&
        widget.referenceArea != null) {
      setState(() {
        _selectedAreaCategory = AreaCategory.fromArea(widget.referenceArea!);
      });
      if (_isExpanded) _fetchData();
    }
  }

  Future<void> _fetchData() async {
    final admCd = widget.addressData?['admCd'];
    final lawdCd = RealTransactionService.extractLawdCd(admCd);
    if (lawdCd == null) {
      setState(() {
        _errorMessage = '주소 정보가 부족하여 실거래가를 조회할 수 없습니다.';
        _isLoading = false;
      });
      return;
    }

    final aptName = widget.addressData?['bdNm']?.trim();

    // 필터 해시로 동일 파라미터 재조회 방지
    final filterHash = _computeFilterHash(lawdCd, aptName);
    if (filterHash == _lastFilterHash && _transactions.isNotEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
      _isLoadingMore = false;
      _errorMessage = null;
    });

    try {
      // 단계적 로딩 사용: 3개월 먼저 → 나머지 9개월 백그라운드
      await RealTransactionService.getRecentTransactionsProgressive(
        lawdCd: lawdCd,
        aptName: aptName,
        roadNm: widget.addressData?['rn'],
        umdNm: widget.addressData?['emdNm'],
        transactionType: widget.transactionType,
        months: _selectedMonths,
        areaCategory: _selectedAreaCategory,
        searchScope: _selectedSearchScope,
        floorCategory: _selectedFloorCategory,
        buildYearCategory: _selectedBuildYearCategory,
        dealingType: widget.transactionType == '매매' ? DealingType.broker : null,
        contractTypeFilter: widget.transactionType != '매매' ? _selectedContractType : null,
        onData: (transactions, isPartial) {
          if (!mounted) return;
          setState(() {
            _transactions = transactions;
            _isLoading = false;
            _isLoadingMore = isPartial; // 부분 데이터면 추가 로딩 중
            _lastFilterHash = filterHash;
            if (transactions.isEmpty) {
              _errorMessage = _getEmptyMessage();
            } else {
              _errorMessage = null;
            }
          });

          // 모든 필터가 선택되고 전체 데이터 로드 완료 시 콜백 호출
          if (!isPartial && _areaSelected && _floorSelected && _buildYearSelected) {
            widget.onDataLoaded?.call();
          }
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _errorMessage = '실거래가 조회 중 오류가 발생했습니다.';
      });
    }
  }

  String _getEmptyMessage() {
    if (_selectedSearchScope == SearchScope.sameRoad) {
      return '해당 도로의 최근 실거래 기록이 없습니다.\n검색 범위를 넓혀보세요.';
    }
    if (_selectedAreaCategory != null) {
      return '해당 면적대(${_selectedAreaCategory!.description})의 실거래 기록이 없습니다.\n다른 면적대를 선택해보세요.';
    }
    return '해당 지역의 최근 실거래 기록이 없습니다.';
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    if (_isExpanded && _transactions.isEmpty && !_isLoading) {
      _fetchData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.addressData == null) return const SizedBox.shrink();

    // 임베디드 모드: 컨테이너 없이 내용만 표시
    if (widget.embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildEmbeddedContent(),
        ],
      );
    }

    // 기존 모드: 컨테이너 포함
    return Container(
      decoration: BoxDecoration(
        color: AirbnbColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AirbnbColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          // 헤더 (항상 표시)
          _buildHeader(),
          // 내용 (펼쳤을 때)
          if (_isExpanded) _buildContent(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return InkWell(
      onTap: _toggleExpand,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            const Icon(
              Icons.show_chart,
              size: 20,
              color: AirbnbColors.primary,
            ),
            const SizedBox(width: 12.0),
            Expanded(
              child: Text(
                _isExpanded ? '이 아파트 최근 실거래가' : '이 아파트 최근 실거래가 보기',
                style: AppTypography.bodySmall.copyWith(
                  color: AirbnbColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: AirbnbColors.primary,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  /// 임베디드 모드용 컨텐츠 (순차적 필터 방식)
  Widget _buildEmbeddedContent() {
    // 모든 필터 선택 완료 시: 필터 요약 + 결과 표시
    if (_buildYearSelected) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 선택된 필터 요약 + 다시 선택 버튼
          _buildFilterSummaryWithReset(),
          const SizedBox(height: AppSpacing.md),

          // 결과 표시
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20.0),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Text(
                _errorMessage!,
                style: AppTypography.captionLarge.copyWith(
                  color: AirbnbColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else ...[
            // 1. 가격 추이 그래프 (먼저)
            if (_transactions.length >= 3) ...[
              PriceTrendChart(
                transactions: _transactions,
                transactionType: widget.transactionType,
                months: _selectedMonths,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            // 2. 거래 목록 (최근 5건으로 축소)
            ..._transactions.take(5).map(_buildTransactionItem),
            // 3. 평균가 요약 (마지막 - 결론)
            const SizedBox(height: AppSpacing.md),
            _buildSummary(),
            // 출처
            const SizedBox(height: AppSpacing.sm),
            Text(
              '* 국토교통부 실거래가 공개시스템 기준',
              style: AppTypography.caption.copyWith(
                color: AirbnbColors.textLight,
              ),
            ),
          ],
        ],
      );
    }

    // 필터 선택 중: 순차적 필터 UI
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Step 0: 면적대 선택
        _buildSequentialStep(
          stepNumber: 0,
          label: '면적대',
          isCompleted: _areaSelected,
          selectedValue: _areaSelected ? _selectedAreaCategory!.label : null,
          child: _buildAreaSelector(),
        ),

        // Step 1: 층수 선택 (면적대 선택 후)
        if (_areaSelected)
          _buildSequentialStep(
            stepNumber: 1,
            label: '층수',
            isCompleted: _floorSelected,
            selectedValue: _floorSelected ? _selectedFloorCategory!.label : null,
            child: _buildFloorSelector(),
          ),

        // Step 2: 건축년도 선택 (층수 선택 후)
        if (_floorSelected)
          _buildSequentialStep(
            stepNumber: 2,
            label: '건축년도',
            isCompleted: _buildYearSelected,
            selectedValue: _buildYearSelected ? _selectedBuildYearCategory!.label : null,
            child: _buildBuildYearSelector(),
          ),
      ],
    );
  }

  /// 선택된 필터 요약 + 다시 선택 버튼
  Widget _buildFilterSummaryWithReset() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 12.0,
      ),
      decoration: BoxDecoration(
        color: AirbnbColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${_selectedAreaCategory!.label} · ${_selectedFloorCategory!.label} · ${_selectedBuildYearCategory!.label}',
              style: AppTypography.captionLarge.copyWith(
                color: AirbnbColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          GestureDetector(
            onTap: _resetFilters,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AirbnbColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4.0),
              ),
              child: Text(
                '다시 선택',
                style: AppTypography.caption.copyWith(
                  color: AirbnbColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 필터 초기화
  void _resetFilters() {
    setState(() {
      _areaSelected = false;
      _floorSelected = false;
      _buildYearSelected = false;
      _selectedAreaCategory = null;
      _selectedFloorCategory = null;
      _selectedBuildYearCategory = null;
      _transactions = [];
      _errorMessage = null;
      _lastFilterHash = null;
    });
  }

  /// 순차적 단계 위젯
  Widget _buildSequentialStep({
    required int stepNumber,
    required String label,
    required bool isCompleted,
    required String? selectedValue,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (stepNumber > 0) const SizedBox(height: AppSpacing.md),
        // 완료된 단계: 선택값 표시 + 수정 가능
        if (isCompleted)
          _buildCompletedStepHeader(label, selectedValue!)
        else ...[
          // 현재 단계: 라벨 + 선택 UI
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AirbnbColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12.0),
          child,
        ],
      ],
    );
  }

  /// 완료된 단계 헤더 (수정 가능)
  Widget _buildCompletedStepHeader(String label, String value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: AppTypography.captionLarge.copyWith(
            color: AirbnbColors.textLight,
          ),
        ),
        Text(
          value,
          style: AppTypography.captionLarge.copyWith(
            color: AirbnbColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// 면적대 선택기 (순차적 모드용)
  Widget _buildAreaSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: AreaCategory.values.map(
          (cat) => _buildSelectableChip(
            label: '${cat.label}\n${cat.description}',
            isSelected: _areaSelected && _selectedAreaCategory == cat,
            onTap: () {
              setState(() {
                _selectedAreaCategory = cat;
                _areaSelected = true;
              });
            },
          ),
        ).toList(),
      ),
    );
  }

  /// 층수 선택기 (순차적 모드용)
  Widget _buildFloorSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: FloorCategory.values.map(
          (cat) => _buildSelectableChip(
            label: cat.label,
            isSelected: _floorSelected && _selectedFloorCategory == cat,
            onTap: () {
              setState(() {
                _selectedFloorCategory = cat;
                _floorSelected = true;
              });
            },
          ),
        ).toList(),
      ),
    );
  }

  /// 건축년도 선택기 (순차적 모드용)
  Widget _buildBuildYearSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: BuildYearCategory.values.map(
          (cat) => _buildSelectableChip(
            label: cat.label,
            isSelected: _buildYearSelected && _selectedBuildYearCategory == cat,
            onTap: () {
              setState(() {
                _selectedBuildYearCategory = cat;
                _buildYearSelected = true;
                _isLoading = true; // 로딩 상태 먼저 설정
                _transactions = []; // 이전 데이터 초기화
                _errorMessage = null;
              });
              // 마지막 필터 선택 시 데이터 로드
              _fetchData();
            },
          ),
        ).toList(),
      ),
    );
  }

  /// 선택 가능한 칩 위젯
  Widget _buildSelectableChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AirbnbColors.primary
                : AirbnbColors.background,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: isSelected
                  ? AirbnbColors.primary
                  : AirbnbColors.border,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              color: isSelected ? Colors.white : AirbnbColors.textPrimary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              height: 1.3,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 12.0),
          // 필터 옵션
          _buildFilterOptions(),
          const SizedBox(height: 12.0),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20.0),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Text(
                _errorMessage!,
                style: AppTypography.captionLarge.copyWith(
                  color: AirbnbColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else ...[
            // 평균가 요약
            _buildSummary(),
            const SizedBox(height: AppSpacing.md),
            // 가격 추이 그래프
            if (_transactions.length >= 3)
              PriceTrendChart(
                transactions: _transactions,
                transactionType: widget.transactionType,
                months: _selectedMonths,
              ),
            if (_transactions.length >= 3)
              const SizedBox(height: AppSpacing.md),
            // 거래 목록 (최근 10건)
            ..._transactions.take(10).map(_buildTransactionItem),
            // 출처
            const SizedBox(height: AppSpacing.sm),
            Text(
              '* 국토교통부 실거래가 공개시스템 기준',
              style: AppTypography.caption.copyWith(
                color: AirbnbColors.textLight,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterOptions() {
    final isSale = widget.transactionType == '매매';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 면적 카테고리 선택
        _buildFilterRow('면적대', [
          ...AreaCategory.values.map(
            (cat) => _buildFilterChip(
              label: '${cat.label}\n${cat.description}',
              isSelected: _selectedAreaCategory == cat,
              onTap: () => _onFilterChanged(() => _selectedAreaCategory = cat),
            ),
          ),
        ]),
        const SizedBox(height: AppSpacing.sm),

        // 층수 선택
        _buildFilterRow('층수', [
          ...FloorCategory.values.map(
            (cat) => _buildFilterChip(
              label: cat.label,
              isSelected: _selectedFloorCategory == cat,
              onTap: () => _onFilterChanged(() => _selectedFloorCategory = cat),
            ),
          ),
        ]),
        const SizedBox(height: AppSpacing.sm),

        // 건축년도 선택
        _buildFilterRow('건축년도', [
          ...BuildYearCategory.values.map(
            (cat) => _buildFilterChip(
              label: cat.label,
              isSelected: _selectedBuildYearCategory == cat,
              onTap: () => _onFilterChanged(() => _selectedBuildYearCategory = cat),
            ),
          ),
        ]),
        const SizedBox(height: AppSpacing.sm),

        // 계약구분 (전월세만)
        if (!isSale) ...[
          _buildFilterRow('계약구분', [
            ...ContractTypeFilter.values.map(
              (type) => _buildFilterChip(
                label: type.label,
                isSelected: _selectedContractType == type,
                onTap: () => _onFilterChanged(() => _selectedContractType = type),
              ),
            ),
          ]),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }

  Widget _buildFilterRow(String label, List<Widget> chips) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AirbnbColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: chips),
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AirbnbColors.primary
                : AirbnbColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(
              color: isSelected ? Colors.white : AirbnbColors.textPrimary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  void _onFilterChanged(VoidCallback updateFilter) {
    setState(() {
      updateFilter();
    });
    _fetchData();
  }


  Widget _buildSummary() {
    if (_transactions.isEmpty) return const SizedBox.shrink();

    final amounts = _transactions.map((t) => t.dealAmount).toList();
    final avg = amounts.reduce((a, b) => a + b) ~/ amounts.length;
    final formattedAvg = RealTransaction.formatKoreanPrice(avg);

    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: AirbnbColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _isLoadingMore ? '최근 3개월 평균' : '최근 $_selectedMonths개월 평균',
                      style: AppTypography.caption.copyWith(
                        color: AirbnbColors.textSecondary,
                      ),
                    ),
                    if (_isLoadingMore) ...[
                      const SizedBox(width: 6),
                      const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: AirbnbColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '전체 로딩 중...',
                        style: AppTypography.caption.copyWith(
                          color: AirbnbColors.textLight,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  formattedAvg,
                  style: AppTypography.h4.copyWith(
                    color: AirbnbColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${_transactions.length}건',
            style: AppTypography.captionLarge.copyWith(
              color: AirbnbColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(RealTransaction t) {
    final priceLabel = widget.transactionType == '월세'
        ? '${t.formattedDeposit ?? "-"} / 월 ${t.formattedMonthlyRent ?? "-"}'
        : t.formattedPrice;

    return InkWell(
      onTap: widget.onPriceSelected != null
          ? () => widget.onPriceSelected!(t.dealAmount)
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            // 날짜
            SizedBox(
              width: 70,
              child: Text(
                '${t.dealYear}.${t.dealMonth.toString().padLeft(2, '0')}.${t.dealDay.toString().padLeft(2, '0')}',
                style: AppTypography.caption.copyWith(
                  color: AirbnbColors.textSecondary,
                ),
              ),
            ),
            // 면적
            SizedBox(
              width: 55,
              child: Text(
                '${t.area.toStringAsFixed(0)}㎡',
                style: AppTypography.caption.copyWith(
                  color: AirbnbColors.textSecondary,
                ),
              ),
            ),
            // 층
            SizedBox(
              width: 35,
              child: Text(
                '${t.floor}층',
                style: AppTypography.caption.copyWith(
                  color: AirbnbColors.textSecondary,
                ),
              ),
            ),
            // 가격
            Expanded(
              child: Text(
                priceLabel,
                textAlign: TextAlign.right,
                style: AppTypography.bodySmall.copyWith(
                  color: AirbnbColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (widget.onPriceSelected != null) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.arrow_forward_ios,
                size: 10,
                color: AirbnbColors.textLight,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
