import 'package:flutter/material.dart';
import '../_shared/address_search_mixin.dart';
import '../../api_request/real_transaction_service.dart';
import '../../constants/apple_design_system.dart';
import '../../services/search_analytics_service.dart';
import '../../utils/logger.dart';
import '../../utils/transaction_stats.dart';
import '../../widgets/road_address_list.dart';
import '../../widgets/price_trend_chart.dart';

/// 시세 조회 페이지 (로그인 불필요 - SEO용 공개 페이지 겸 탭)
class MarketPricePage extends StatefulWidget {
  const MarketPricePage({super.key});

  @override
  State<MarketPricePage> createState() => _MarketPricePageState();
}

class _MarketPricePageState extends State<MarketPricePage> with AddressSearchMixin {
  // 주소 검색
  final _addressController = TextEditingController();
  Map<String, String>? _selectedFullData;
  String _selectedAddress = '';

  // 실거래가 데이터
  List<RealTransaction> _transactions = [];
  bool _isLoadingTransactions = false;
  bool _isLoadingMore = false; // 추가 데이터 로딩 중
  String? _transactionError;
  String _transactionType = '매매';

  // API 필터 (조회 전 적용)
  AreaCategory? _selectedAreaCategory;
  SearchScope _selectedSearchScope = SearchScope.sameRoad;
  FloorCategory? _selectedFloorCategory;
  BuildYearCategory? _selectedBuildYearCategory;
  ContractTypeFilter? _selectedContractType;

  // 통계 및 후처리 필터 (조회 후 적용)
  TransactionStats? _stats;
  String? _selectedAreaFilter;
  String? _selectedFloorFilter;
  bool _showFilters = false;

  // API 필터 섹션 접기/펼치기
  bool _showApiFilters = false;

  // 기간 선택 (6개월, 12개월, 24개월)
  int _selectedMonths = 12;

  // 내 호가 입력 (평균 대비 비교용)
  final _myPriceController = TextEditingController();
  int? _myPrice;

  @override
  void dispose() {
    _addressController.dispose();
    _myPriceController.dispose();
    cancelAddressSearch();
    super.dispose();
  }

  void _onAddressSelected(Map<String, String> fullData, String address) {
    setState(() {
      _selectedFullData = fullData;
      _selectedAddress = address;
      _addressController.text = address;
      addressSearchResults = [];
      addressList = [];
      _selectedAreaFilter = null;
      _selectedFloorFilter = null;
    });
    _fetchTransactions();
  }

  Future<void> _fetchTransactions() async {
    final admCd = _selectedFullData?['admCd'];
    final lawdCd = RealTransactionService.extractLawdCd(admCd);

    if (lawdCd == null) {
      setState(() {
        _transactionError = '주소 정보가 부족하여 실거래가를 조회할 수 없습니다.';
      });
      return;
    }

    setState(() {
      _isLoadingTransactions = true;
      _isLoadingMore = false;
      _transactionError = null;
      _transactions = [];
      _stats = null;
    });

    try {
      final aptName = _selectedFullData?['bdNm']?.trim();
      bool isFirstBatch = true;

      await RealTransactionService.getRecentTransactionsProgressive(
        lawdCd: lawdCd,
        aptName: aptName,
        roadNm: _selectedFullData?['rn'],
        umdNm: _selectedFullData?['emdNm'],
        transactionType: _transactionType,
        months: _selectedMonths,
        areaCategory: _selectedAreaCategory,
        searchScope: _selectedSearchScope,
        floorCategory: _selectedFloorCategory,
        buildYearCategory: _selectedBuildYearCategory,
        dealingType: _transactionType == '매매' ? DealingType.broker : null,
        contractTypeFilter: _transactionType != '매매' ? _selectedContractType : null,
        onData: (partialResults, isPartial) {
          if (!mounted) return;

          if (isFirstBatch && partialResults.isNotEmpty) {
            isFirstBatch = false;
            setState(() {
              _transactions = partialResults;
              _stats = TransactionStats(
                transactions: partialResults,
                transactionType: _transactionType,
              );
              _isLoadingTransactions = false;
              _isLoadingMore = isPartial;
            });
          } else if (!isPartial) {
            setState(() {
              _transactions = partialResults;
              _stats = TransactionStats(
                transactions: partialResults,
                transactionType: _transactionType,
              );
              _isLoadingMore = false;
              if (partialResults.isEmpty) {
                _transactionError = '해당 지역의 최근 실거래 데이터가 없습니다.';
              }
            });
          } else {
            setState(() {
              _transactions = partialResults;
              _stats = TransactionStats(
                transactions: partialResults,
                transactionType: _transactionType,
              );
            });
          }
        },
      );

      SearchAnalyticsService.logMarketPriceSearch(
        lawdCd: lawdCd,
        buildingName: aptName,
        transactionType: _transactionType,
        address: _selectedAddress,
      );

    } catch (e) {
      Logger.error('[MarketPrice] 실거래가 조회 실패', error: e);
      if (!mounted) return;
      setState(() {
        _isLoadingTransactions = false;
        _isLoadingMore = false;
        _transactionError = '실거래가 조회 중 오류가 발생했습니다.';
      });
    }
  }

  void _onTransactionTypeChanged(String type) {
    if (type == _transactionType) return;
    setState(() {
      _transactionType = type;
      _selectedAreaFilter = null;
      _selectedFloorFilter = null;
      _myPrice = null;
      _myPriceController.clear();
    });
    if (_selectedFullData != null) {
      _fetchTransactions();
    }
  }

  void _resetSearch() {
    setState(() {
      _selectedFullData = null;
      _selectedAddress = '';
      _addressController.clear();
      _transactions = [];
      _transactionError = null;
      addressSearchResults = [];
      addressList = [];
      _stats = null;
      _selectedAreaCategory = null;
      _selectedSearchScope = SearchScope.sameRoad;
      _selectedFloorCategory = null;
      _selectedBuildYearCategory = null;
      _selectedContractType = null;
      _selectedAreaFilter = null;
      _selectedFloorFilter = null;
      _myPrice = null;
      _myPriceController.clear();
    });
  }

  void _onAreaCategoryChanged(AreaCategory? category) {
    setState(() {
      _selectedAreaCategory = category;
    });
    if (_selectedFullData != null) {
      _fetchTransactions();
    }
  }

  void _onSearchScopeChanged(SearchScope scope) {
    setState(() {
      _selectedSearchScope = scope;
    });
    if (_selectedFullData != null) {
      _fetchTransactions();
    }
  }

  void _onFloorCategoryChanged(FloorCategory? category) {
    setState(() {
      _selectedFloorCategory = category;
    });
    if (_selectedFullData != null) {
      _fetchTransactions();
    }
  }

  void _onBuildYearCategoryChanged(BuildYearCategory? category) {
    setState(() {
      _selectedBuildYearCategory = category;
    });
    if (_selectedFullData != null) {
      _fetchTransactions();
    }
  }

  void _onContractTypeChanged(ContractTypeFilter? type) {
    setState(() {
      _selectedContractType = type;
    });
    if (_selectedFullData != null) {
      _fetchTransactions();
    }
  }

  List<RealTransaction> get _filteredTransactions {
    if (_stats == null) return _transactions;

    var filtered = _transactions;

    if (_selectedAreaFilter != null) {
      final grouped = _stats!.groupByArea();
      filtered = grouped[_selectedAreaFilter] ?? [];
    }

    if (_selectedFloorFilter != null) {
      final grouped = TransactionStats(
        transactions: filtered,
        transactionType: _transactionType,
      ).groupByFloor();
      filtered = grouped[_selectedFloorFilter] ?? [];
    }

    return filtered;
  }

  TransactionStats get _filteredStats {
    return TransactionStats(
      transactions: _filteredTransactions,
      transactionType: _transactionType,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: AppleColors.systemBackground,
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isMobile ? AppleSpacing.lg : AppleSpacing.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: AppleSpacing.lg),
                        _buildAddressSearch(),
                        const SizedBox(height: AppleSpacing.md),
                        _buildTransactionTypeSelector(),
                        const SizedBox(height: AppleSpacing.sm),
                        _buildPeriodSelector(),
                        const SizedBox(height: AppleSpacing.sm),
                        _buildApiFiltersToggle(),
                        if (_selectedFullData != null) ...[
                          const SizedBox(height: AppleSpacing.xl),
                          _buildResults(),
                        ],
                      ],
                    ),
                  ),
                ),
                if (_selectedFullData != null) _buildCTA(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return RichText(
      text: TextSpan(
        style: AppleTypography.largeTitle.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: AppleColors.label,
          height: 1.2,
        ),
        children: const [
          TextSpan(text: '실거래가 '),
          TextSpan(
            text: '시세 조회',
            style: TextStyle(color: AppleColors.systemBlue),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTypeSelector() {
    return Row(
      children: ['매매', '전세', '월세'].map((type) {
        final isSelected = _transactionType == type;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: type != '월세' ? AppleSpacing.xs : 0,
            ),
            child: GestureDetector(
              onTap: () => _onTransactionTypeChanged(type),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: AppleSpacing.sm),
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
                    style: AppleTypography.subheadline.copyWith(
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
    );
  }

  Widget _buildPeriodSelector() {
    return Row(
      children: [6, 12, 24].map((months) {
        final isSelected = _selectedMonths == months;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: months != 24 ? AppleSpacing.xs : 0,
            ),
            child: GestureDetector(
              onTap: () {
                if (_selectedMonths != months) {
                  setState(() {
                    _selectedMonths = months;
                  });
                  if (_selectedFullData != null) {
                    _fetchTransactions();
                  }
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: AppleSpacing.sm),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppleColors.systemBlue.withValues(alpha: 0.1)
                      : AppleColors.secondarySystemGroupedBackground,
                  borderRadius: BorderRadius.circular(AppleRadius.md),
                  border: Border.all(
                    color: isSelected
                        ? AppleColors.systemBlue
                        : AppleColors.separator,
                  ),
                ),
                child: Center(
                  child: Text(
                    '$months개월',
                    style: AppleTypography.subheadline.copyWith(
                      color: isSelected ? AppleColors.systemBlue : AppleColors.label,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildApiFiltersToggle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => setState(() => _showApiFilters = !_showApiFilters),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppleSpacing.md,
              vertical: AppleSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppleColors.secondarySystemGroupedBackground,
              borderRadius: BorderRadius.circular(AppleRadius.md),
              border: Border.all(color: AppleColors.separator),
            ),
            child: Row(
              children: [
                const Icon(Icons.tune_rounded, size: 16, color: AppleColors.secondaryLabel),
                const SizedBox(width: AppleSpacing.xs),
                Text(
                  '상세 필터',
                  style: AppleTypography.subheadline.copyWith(
                    color: AppleColors.secondaryLabel,
                  ),
                ),
                if (_hasActiveApiFilters()) ...[
                  const SizedBox(width: AppleSpacing.xs),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppleColors.systemBlue,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
                const Spacer(),
                Icon(
                  _showApiFilters ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: AppleColors.tertiaryLabel,
                ),
              ],
            ),
          ),
        ),
        if (_showApiFilters) ...[
          const SizedBox(height: AppleSpacing.md),
          _buildApiFilters(),
        ],
      ],
    );
  }

  bool _hasActiveApiFilters() {
    return _selectedAreaCategory != null ||
        _selectedFloorCategory != null ||
        _selectedBuildYearCategory != null ||
        _selectedContractType != null ||
        _selectedSearchScope != SearchScope.sameRoad;
  }

  Widget _buildApiFilters() {
    final isSale = _transactionType == '매매';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 면적 카테고리 선택
        _buildFilterRow('면적대', [
          _buildApiFilterChip(
            label: '전체',
            isSelected: _selectedAreaCategory == null,
            onTap: () => _onAreaCategoryChanged(null),
          ),
          ...AreaCategory.values.map(
            (cat) => _buildApiFilterChip(
              label: '${cat.label}\n${cat.description}',
              isSelected: _selectedAreaCategory == cat,
              onTap: () => _onAreaCategoryChanged(cat),
            ),
          ),
        ]),
        const SizedBox(height: AppleSpacing.sm),

        // 층수 선택
        _buildFilterRow('층수', [
          _buildApiFilterChip(
            label: '전체',
            isSelected: _selectedFloorCategory == null,
            onTap: () => _onFloorCategoryChanged(null),
          ),
          ...FloorCategory.values.map(
            (cat) => _buildApiFilterChip(
              label: cat.label,
              subtitle: cat.description,
              isSelected: _selectedFloorCategory == cat,
              onTap: () => _onFloorCategoryChanged(cat),
            ),
          ),
        ]),
        const SizedBox(height: AppleSpacing.sm),

        // 건축년도 선택
        _buildFilterRow('건축년도', [
          _buildApiFilterChip(
            label: '전체',
            isSelected: _selectedBuildYearCategory == null,
            onTap: () => _onBuildYearCategoryChanged(null),
          ),
          ...BuildYearCategory.values.map(
            (cat) => _buildApiFilterChip(
              label: cat.label,
              subtitle: cat.description,
              isSelected: _selectedBuildYearCategory == cat,
              onTap: () => _onBuildYearCategoryChanged(cat),
            ),
          ),
        ]),
        const SizedBox(height: AppleSpacing.sm),

        // 계약구분 (전월세만)
        if (!isSale) ...[
          _buildFilterRow('계약구분', [
            _buildApiFilterChip(
              label: '전체',
              isSelected: _selectedContractType == null,
              onTap: () => _onContractTypeChanged(null),
            ),
            ...ContractTypeFilter.values.map(
              (type) => _buildApiFilterChip(
                label: type.label,
                isSelected: _selectedContractType == type,
                onTap: () => _onContractTypeChanged(type),
              ),
            ),
          ]),
          const SizedBox(height: AppleSpacing.sm),
        ],

        // 검색 범위 선택
        _buildFilterRow('검색 범위', [
          ...SearchScope.values.map(
            (scope) => _buildApiFilterChip(
              label: scope.label,
              subtitle: scope.description,
              isSelected: _selectedSearchScope == scope,
              onTap: () => _onSearchScopeChanged(scope),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _buildFilterRow(String label, List<Widget> chips) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppleTypography.subheadline.copyWith(
            color: AppleColors.secondaryLabel,
          ),
        ),
        const SizedBox(height: AppleSpacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: IntrinsicHeight(child: Row(children: chips)),
        ),
      ],
    );
  }

  Widget _buildApiFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    String? subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: AppleSpacing.xs),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppleSpacing.md,
            vertical: AppleSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? AppleColors.systemBlue
                : AppleColors.secondarySystemGroupedBackground,
            borderRadius: BorderRadius.circular(AppleRadius.md),
            border: isSelected
                ? null
                : Border.all(color: AppleColors.separator),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: AppleTypography.footnote.copyWith(
                  color: isSelected ? Colors.white : AppleColors.label,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  height: 1.3,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: AppleTypography.caption2.copyWith(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.8)
                        : AppleColors.tertiaryLabel,
                    height: 1.2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddressSearch() {
    if (_selectedFullData != null) {
      return Container(
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
            const Icon(Icons.location_on, color: AppleColors.systemBlue, size: 20),
            const SizedBox(width: AppleSpacing.sm),
            Expanded(
              child: Text(
                _selectedAddress,
                style: AppleTypography.body.copyWith(
                  color: AppleColors.label,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              onPressed: _resetSearch,
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
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _addressController,
          decoration: InputDecoration(
            hintText: '아파트명, 도로명, 지번 등을 입력하세요',
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
            prefixIcon: const Icon(Icons.search, color: AppleColors.systemBlue),
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
            searchAddress(value);
          },
          onFieldSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              searchAddress(value.trim());
            }
          },
        ),
        if (isAddressSearching)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppleSpacing.md),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        if (addressErrorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: AppleSpacing.sm),
            child: Text(
              addressErrorMessage!,
              style: AppleTypography.footnote.copyWith(
                color: AppleColors.systemOrange,
              ),
            ),
          ),
        if (addressList.isNotEmpty) ...[
          const SizedBox(height: AppleSpacing.sm),
          RoadAddressList(
            fullAddrAPIDatas: addressSearchResults,
            addresses: addressList,
            selectedAddress: _selectedAddress,
            onSelect: _onAddressSelected,
          ),
        ],
      ],
    );
  }

  Widget _buildResults() {
    if (_isLoadingTransactions) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppleSpacing.xxl),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: AppleSpacing.md),
              Text('실거래가 조회 중...'),
            ],
          ),
        ),
      );
    }

    if (_transactionError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppleSpacing.xl),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.info_outline, size: 48, color: AppleColors.tertiaryLabel),
              const SizedBox(height: AppleSpacing.md),
              Text(
                _transactionError!,
                style: AppleTypography.body.copyWith(
                  color: AppleColors.secondaryLabel,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final stats = _filteredStats;
    final transactions = _filteredTransactions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 추가 데이터 로딩 표시
        if (_isLoadingMore)
          Container(
            margin: const EdgeInsets.only(bottom: AppleSpacing.md),
            padding: const EdgeInsets.symmetric(vertical: AppleSpacing.sm, horizontal: AppleSpacing.md),
            decoration: BoxDecoration(
              color: AppleColors.systemBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppleRadius.sm),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: AppleSpacing.sm),
                Text(
                  '추가 데이터 로딩 중...',
                  style: AppleTypography.footnote.copyWith(
                    color: AppleColors.systemBlue,
                  ),
                ),
              ],
            ),
          ),

        // 1. 가격 요약 + 트렌드
        _buildPriceSummary(stats),
        const SizedBox(height: AppleSpacing.md),

        // 2. 가격대별 거래 속도 가이드
        _buildPriceSpeedGuide(stats),
        const SizedBox(height: AppleSpacing.md),

        // 3. 내 호가 비교
        _buildMyPriceCompare(stats),
        const SizedBox(height: AppleSpacing.md),

        // 4. 예상 수수료
        _buildBrokerFee(stats),
        const SizedBox(height: AppleSpacing.lg),

        // 5. 필터
        _buildFilters(),
        const SizedBox(height: AppleSpacing.lg),

        // 6. 월별 평균가 추이 그래프
        if (_transactions.isNotEmpty) ...[
          PriceTrendChart(
            transactions: _transactions,
            transactionType: _transactionType,
            months: _selectedMonths,
          ),
          const SizedBox(height: AppleSpacing.lg),
        ],

        // 7. 거래 목록
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '거래 내역',
              style: AppleTypography.headline.copyWith(
                color: AppleColors.label,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${transactions.length}건',
              style: AppleTypography.subheadline.copyWith(
                color: AppleColors.secondaryLabel,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppleSpacing.sm),
        ...transactions.take(20).map(_buildTransactionCard),

        if (transactions.length > 20)
          Padding(
            padding: const EdgeInsets.only(top: AppleSpacing.sm),
            child: Text(
              '외 ${transactions.length - 20}건 더 있음',
              style: AppleTypography.footnote.copyWith(
                color: AppleColors.secondaryLabel,
              ),
              textAlign: TextAlign.center,
            ),
          ),

        const SizedBox(height: AppleSpacing.md),
        Text(
          '* 국토교통부 실거래가 공개시스템 기준 (최근 12개월)',
          style: AppleTypography.caption2.copyWith(
            color: AppleColors.tertiaryLabel,
          ),
        ),
      ],
    );
  }

  Widget _buildPriceSummary(TransactionStats stats) {
    if (!stats.hasData) return const SizedBox.shrink();

    final trend = _stats?.calculateTrend();
    final priceLabel = _transactionType == '월세' ? '보증금' : '가격';

    return Container(
      padding: const EdgeInsets.all(AppleSpacing.lg),
      decoration: BoxDecoration(
        color: AppleColors.systemBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppleRadius.lg),
      ),
      child: Column(
        children: [
          // 트렌드 배지
          if (trend != null)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppleSpacing.sm,
                vertical: AppleSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: _getTrendColor(trend.direction).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppleRadius.sm),
              ),
              child: Text(
                trend.trendText,
                style: AppleTypography.caption1.copyWith(
                  color: _getTrendColor(trend.direction),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (trend != null) const SizedBox(height: AppleSpacing.sm),

          Text(
            '평균 $priceLabel',
            style: AppleTypography.subheadline.copyWith(
              color: AppleColors.secondaryLabel,
            ),
          ),
          const SizedBox(height: AppleSpacing.xs),
          Text(
            RealTransaction.formatKoreanPrice(stats.average),
            style: AppleTypography.largeTitle.copyWith(
              color: AppleColors.systemBlue,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppleSpacing.md),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem('최저', RealTransaction.formatKoreanPrice(stats.minPrice)),
              ),
              Container(width: 1, height: 32, color: AppleColors.separator),
              Expanded(
                child: _buildSummaryItem('최고', RealTransaction.formatKoreanPrice(stats.maxPrice)),
              ),
              Container(width: 1, height: 32, color: AppleColors.separator),
              Expanded(
                child: _buildSummaryItem('거래', '${stats.count}건'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getTrendColor(TrendDirection direction) {
    switch (direction) {
      case TrendDirection.up:
        return AppleColors.systemRed;
      case TrendDirection.down:
        return AppleColors.systemBlue;
      case TrendDirection.stable:
        return AppleColors.secondaryLabel;
    }
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
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
          style: AppleTypography.subheadline.copyWith(
            color: AppleColors.label,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildPriceSpeedGuide(TransactionStats stats) {
    if (!stats.hasData) return const SizedBox.shrink();

    final guide = stats.getPriceSpeedGuide();

    return Container(
      padding: const EdgeInsets.all(AppleSpacing.md),
      decoration: BoxDecoration(
        color: AppleColors.tertiarySystemGroupedBackground,
        borderRadius: BorderRadius.circular(AppleRadius.md),
        border: Border.all(color: AppleColors.separator),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline, size: 18, color: AppleColors.systemYellow),
              const SizedBox(width: AppleSpacing.xs),
              Text(
                '가격대별 거래 예상',
                style: AppleTypography.subheadline.copyWith(
                  color: AppleColors.label,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppleSpacing.sm),
          _buildSpeedGuideRow(
            '${RealTransaction.formatKoreanPrice(guide.fastThreshold)} 이하',
            '빠른 거래 예상',
            AppleColors.systemGreen,
          ),
          const SizedBox(height: AppleSpacing.xs),
          _buildSpeedGuideRow(
            '${RealTransaction.formatKoreanPrice(guide.normalMin)} ~ ${RealTransaction.formatKoreanPrice(guide.normalMax)}',
            '평균 속도',
            AppleColors.systemOrange,
          ),
          const SizedBox(height: AppleSpacing.xs),
          _buildSpeedGuideRow(
            '${RealTransaction.formatKoreanPrice(guide.slowThreshold)} 이상',
            '협상 여지 필요',
            AppleColors.systemRed,
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedGuideRow(String price, String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppleSpacing.sm),
        Expanded(
          child: Text(
            price,
            style: AppleTypography.footnote.copyWith(
              color: AppleColors.secondaryLabel,
            ),
          ),
        ),
        Text(
          label,
          style: AppleTypography.footnote.copyWith(
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildMyPriceCompare(TransactionStats stats) {
    if (!stats.hasData) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppleSpacing.md),
      decoration: BoxDecoration(
        color: AppleColors.secondarySystemGroupedBackground,
        borderRadius: BorderRadius.circular(AppleRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '내 희망 가격 비교',
            style: AppleTypography.subheadline.copyWith(
              color: AppleColors.label,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppleSpacing.sm),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _myPriceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: '만원 단위 입력',
                    hintStyle: AppleTypography.body.copyWith(
                      color: AppleColors.tertiaryLabel,
                    ),
                    filled: true,
                    fillColor: AppleColors.systemBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppleRadius.sm),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppleSpacing.md,
                      vertical: AppleSpacing.sm,
                    ),
                    suffixText: '만원',
                    suffixStyle: AppleTypography.body.copyWith(
                      color: AppleColors.secondaryLabel,
                    ),
                  ),
                  style: AppleTypography.body.copyWith(color: AppleColors.label),
                  onChanged: (value) {
                    setState(() {
                      _myPrice = int.tryParse(value.replaceAll(',', ''));
                    });
                  },
                ),
              ),
            ],
          ),
          if (_myPrice != null && _myPrice! > 0) ...[
            const SizedBox(height: AppleSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppleSpacing.sm),
              decoration: BoxDecoration(
                color: _getCompareColor(stats.compareToAverage(_myPrice!)).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppleRadius.sm),
              ),
              child: Row(
                children: [
                  Icon(
                    _getCompareIcon(stats.compareToAverage(_myPrice!)),
                    size: 20,
                    color: _getCompareColor(stats.compareToAverage(_myPrice!)),
                  ),
                  const SizedBox(width: AppleSpacing.sm),
                  Expanded(
                    child: Text(
                      stats.getPriceEvaluation(_myPrice!),
                      style: AppleTypography.subheadline.copyWith(
                        color: _getCompareColor(stats.compareToAverage(_myPrice!)),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getCompareColor(double diff) {
    if (diff <= -5) return AppleColors.systemGreen;
    if (diff < 5) return AppleColors.systemOrange;
    return AppleColors.systemRed;
  }

  IconData _getCompareIcon(double diff) {
    if (diff <= -5) return Icons.thumb_up_outlined;
    if (diff < 5) return Icons.remove;
    return Icons.trending_up;
  }

  Widget _buildBrokerFee(TransactionStats stats) {
    if (!stats.hasData) return const SizedBox.shrink();

    final BrokerFee fee;
    if (_transactionType == '매매') {
      fee = BrokerFeeCalculator.calculateSaleFee(stats.average);
    } else if (_transactionType == '전세') {
      fee = BrokerFeeCalculator.calculateJeonseFee(stats.average);
    } else {
      // 월세: 평균 월세 계산
      final monthlyRents = _filteredTransactions
          .where((t) => t.monthlyRent != null && t.monthlyRent! > 0)
          .map((t) => t.monthlyRent!)
          .toList();
      final avgMonthlyRent = monthlyRents.isNotEmpty
          ? monthlyRents.reduce((a, b) => a + b) ~/ monthlyRents.length
          : 50; // 기본값
      fee = BrokerFeeCalculator.calculateMonthlyRentFee(stats.average, avgMonthlyRent);
    }

    return Container(
      padding: const EdgeInsets.all(AppleSpacing.md),
      decoration: BoxDecoration(
        color: AppleColors.systemGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppleRadius.md),
        border: Border.all(color: AppleColors.systemGreen.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long, size: 20, color: AppleColors.systemGreen),
          const SizedBox(width: AppleSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '예상 중개 수수료',
                  style: AppleTypography.caption1.copyWith(
                    color: AppleColors.secondaryLabel,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  fee.formatted,
                  style: AppleTypography.headline.copyWith(
                    color: AppleColors.systemGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '요율 ${fee.ratePercent}',
            style: AppleTypography.caption1.copyWith(
              color: AppleColors.secondaryLabel,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    if (_stats == null || !_stats!.hasData) return const SizedBox.shrink();

    final areaFilters = _stats!.availableAreaFilters;
    final floorFilters = _stats!.availableFloorFilters;

    if (areaFilters.length <= 1 && floorFilters.length <= 1) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _showFilters = !_showFilters),
          child: Row(
            children: [
              const Icon(Icons.filter_list, size: 18, color: AppleColors.systemBlue),
              const SizedBox(width: AppleSpacing.xs),
              Text(
                '필터',
                style: AppleTypography.subheadline.copyWith(
                  color: AppleColors.systemBlue,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: AppleSpacing.xs),
              if (_selectedAreaFilter != null || _selectedFloorFilter != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppleColors.systemBlue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${(_selectedAreaFilter != null ? 1 : 0) + (_selectedFloorFilter != null ? 1 : 0)}',
                    style: AppleTypography.caption2.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const Spacer(),
              Icon(
                _showFilters ? Icons.expand_less : Icons.expand_more,
                color: AppleColors.systemBlue,
                size: 20,
              ),
            ],
          ),
        ),
        if (_showFilters) ...[
          const SizedBox(height: AppleSpacing.sm),
          // 평형 필터
          if (areaFilters.length > 1) ...[
            Text(
              '평형',
              style: AppleTypography.caption1.copyWith(
                color: AppleColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: AppleSpacing.xs),
            Wrap(
              spacing: AppleSpacing.xs,
              runSpacing: AppleSpacing.xs,
              children: [
                _buildFilterChip(
                  label: '전체',
                  isSelected: _selectedAreaFilter == null,
                  onTap: () => setState(() => _selectedAreaFilter = null),
                ),
                ...areaFilters.map((f) => _buildFilterChip(
                      label: '${f.label} (${f.count})',
                      isSelected: _selectedAreaFilter == f.label,
                      onTap: () => setState(() => _selectedAreaFilter = f.label),
                    )),
              ],
            ),
            const SizedBox(height: AppleSpacing.sm),
          ],
          // 층 필터
          if (floorFilters.length > 1) ...[
            Text(
              '층',
              style: AppleTypography.caption1.copyWith(
                color: AppleColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: AppleSpacing.xs),
            Wrap(
              spacing: AppleSpacing.xs,
              runSpacing: AppleSpacing.xs,
              children: [
                _buildFilterChip(
                  label: '전체',
                  isSelected: _selectedFloorFilter == null,
                  onTap: () => setState(() => _selectedFloorFilter = null),
                ),
                ...floorFilters.map((f) => _buildFilterChip(
                      label: '${f.label} (${f.count})',
                      isSelected: _selectedFloorFilter == f.label,
                      onTap: () => setState(() => _selectedFloorFilter = f.label),
                    )),
              ],
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppleSpacing.sm,
          vertical: AppleSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppleColors.systemBlue : AppleColors.secondarySystemGroupedBackground,
          borderRadius: BorderRadius.circular(AppleRadius.sm),
          border: isSelected ? null : Border.all(color: AppleColors.separator),
        ),
        child: Text(
          label,
          style: AppleTypography.caption1.copyWith(
            color: isSelected ? Colors.white : AppleColors.label,
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionCard(RealTransaction t) {
    String priceText;
    if (_transactionType == '월세') {
      priceText =
          '${t.formattedDeposit ?? "-"} / 월 ${t.formattedMonthlyRent ?? "-"}';
    } else {
      priceText = t.formattedPrice;
    }

    // 평균 대비 비교
    final diff = _filteredStats.hasData ? _filteredStats.compareToAverage(t.dealAmount) : 0.0;
    final diffText = diff.abs() >= 1
        ? (diff > 0 ? '+${diff.toStringAsFixed(0)}%' : '${diff.toStringAsFixed(0)}%')
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: AppleSpacing.sm),
      padding: const EdgeInsets.all(AppleSpacing.md),
      decoration: BoxDecoration(
        color: AppleColors.secondarySystemGroupedBackground,
        borderRadius: BorderRadius.circular(AppleRadius.md),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (t.aptName.isNotEmpty)
                  Text(
                    t.aptName,
                    style: AppleTypography.subheadline.copyWith(
                      color: AppleColors.label,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (t.aptName.isNotEmpty) const SizedBox(height: 4),
                Text(
                  '${t.area.toStringAsFixed(0)}㎡ (${t.areaPyeong.toStringAsFixed(0)}평)  ·  ${t.floor > 0 ? "${t.floor}층  ·  " : ""}${t.dealYear}.${t.dealMonth.toString().padLeft(2, '0')}.${t.dealDay.toString().padLeft(2, '0')}',
                  style: AppleTypography.caption1.copyWith(
                    color: AppleColors.secondaryLabel,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppleSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                priceText,
                style: AppleTypography.headline.copyWith(
                  color: AppleColors.systemBlue,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (diffText.isNotEmpty)
                Text(
                  diffText,
                  style: AppleTypography.caption2.copyWith(
                    color: diff < 0 ? AppleColors.systemGreen : AppleColors.systemRed,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCTA() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppleSpacing.lg,
        AppleSpacing.md,
        AppleSpacing.lg,
        MediaQuery.of(context).padding.bottom + AppleSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppleColors.systemBackground,
        border: Border(
          top: BorderSide(color: AppleColors.separator, width: 0.5),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppleColors.systemBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: AppleSpacing.md),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppleRadius.md),
            ),
            elevation: 0,
          ),
          child: Text(
            '이 가격에 매물 등록하기',
            style: AppleTypography.headline.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
