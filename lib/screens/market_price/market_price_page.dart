import 'package:flutter/material.dart';
import '../_shared/address_search_mixin.dart';
import '../../api_request/real_transaction_service.dart';
import '../../constants/app_constants.dart';
import '../../constants/typography.dart';
import '../../constants/spacing.dart';
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
      backgroundColor: AirbnbColors.background,
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isMobile ? 20.0 : AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 20.0),
                        _buildAddressSearch(),
                        const SizedBox(height: AppSpacing.md),
                        _buildTransactionTypeSelector(),
                        const SizedBox(height: 12.0),
                        _buildPeriodSelector(),
                        const SizedBox(height: 12.0),
                        _buildApiFiltersToggle(),
                        if (_selectedFullData != null) ...[
                          const SizedBox(height: AppSpacing.lg),
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
        style: AppTypography.display.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: AirbnbColors.textPrimary,
          height: 1.2,
        ),
        children: const [
          TextSpan(text: '실거래가 '),
          TextSpan(
            text: '시세 조회',
            style: TextStyle(color: AirbnbColors.primary),
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
              right: type != '월세' ? AppSpacing.sm : 0,
            ),
            child: GestureDetector(
              onTap: () => _onTransactionTypeChanged(type),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AirbnbColors.primary
                      : AirbnbColors.background,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: isSelected
                      ? null
                      : Border.all(color: AirbnbColors.border),
                ),
                child: Center(
                  child: Text(
                    type,
                    style: AppTypography.bodySmall.copyWith(
                      color: isSelected ? AirbnbColors.background : AirbnbColors.textPrimary,
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
              right: months != 24 ? AppSpacing.sm : 0,
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
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AirbnbColors.primary.withValues(alpha: 0.1)
                      : AirbnbColors.background,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: isSelected
                        ? AirbnbColors.primary
                        : AirbnbColors.border,
                  ),
                ),
                child: Center(
                  child: Text(
                    '$months개월',
                    style: AppTypography.bodySmall.copyWith(
                      color: isSelected ? AirbnbColors.primary : AirbnbColors.textPrimary,
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
              horizontal: AppSpacing.md,
              vertical: 12.0,
            ),
            decoration: BoxDecoration(
              color: AirbnbColors.background,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AirbnbColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.tune_rounded, size: 16, color: AirbnbColors.textSecondary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '상세 필터',
                  style: AppTypography.bodySmall.copyWith(
                    color: AirbnbColors.textSecondary,
                  ),
                ),
                if (_hasActiveApiFilters()) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AirbnbColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
                const Spacer(),
                Icon(
                  _showApiFilters ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: AirbnbColors.textLight,
                ),
              ],
            ),
          ),
        ),
        if (_showApiFilters) ...[
          const SizedBox(height: AppSpacing.md),
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
        const SizedBox(height: 12.0),

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
        const SizedBox(height: 12.0),

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
        const SizedBox(height: 12.0),

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
          const SizedBox(height: 12.0),
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
          style: AppTypography.bodySmall.copyWith(
            color: AirbnbColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12.0),
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
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 12.0,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? AirbnbColors.primary
                : AirbnbColors.background,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: isSelected
                ? null
                : Border.all(color: AirbnbColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(
                  color: isSelected ? AirbnbColors.background : AirbnbColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  height: 1.3,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.8)
                        : AirbnbColors.textLight,
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
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AirbnbColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: AirbnbColors.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on, color: AirbnbColors.primary, size: 20),
            const SizedBox(width: 12.0),
            Expanded(
              child: Text(
                _selectedAddress,
                style: AppTypography.body.copyWith(
                  color: AirbnbColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              onPressed: _resetSearch,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                '변경',
                style: AppTypography.caption.copyWith(
                  color: AirbnbColors.primary,
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
            hintStyle: AppTypography.body.copyWith(
              color: AirbnbColors.textLight,
            ),
            filled: true,
            fillColor: AirbnbColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(AppSpacing.md),
            prefixIcon: const Icon(Icons.search, color: AirbnbColors.primary),
            suffixIcon: _addressController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: AirbnbColors.textLight),
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
          style: AppTypography.body.copyWith(color: AirbnbColors.textPrimary),
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
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
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
            padding: const EdgeInsets.only(top: 12.0),
            child: Text(
              addressErrorMessage!,
              style: AppTypography.caption.copyWith(
                color: AirbnbColors.orange,
              ),
            ),
          ),
        if (addressList.isNotEmpty) ...[
          const SizedBox(height: 12.0),
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
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: AppSpacing.md),
              Text('실거래가 조회 중...'),
            ],
          ),
        ),
      );
    }

    if (_transactionError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.info_outline, size: 48, color: AirbnbColors.textLight),
              const SizedBox(height: AppSpacing.md),
              Text(
                _transactionError!,
                style: AppTypography.body.copyWith(
                  color: AirbnbColors.textSecondary,
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
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: AirbnbColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12.0),
                Text(
                  '추가 데이터 로딩 중...',
                  style: AppTypography.caption.copyWith(
                    color: AirbnbColors.primary,
                  ),
                ),
              ],
            ),
          ),

        // 1. 가격 요약 + 트렌드
        _buildPriceSummary(stats),
        const SizedBox(height: AppSpacing.md),

        // 2. 가격대별 거래 속도 가이드
        _buildPriceSpeedGuide(stats),
        const SizedBox(height: AppSpacing.md),

        // 3. 내 호가 비교
        _buildMyPriceCompare(stats),
        const SizedBox(height: AppSpacing.md),

        // 4. 예상 수수료
        _buildBrokerFee(stats),
        const SizedBox(height: 20.0),

        // 5. 필터
        _buildFilters(),
        const SizedBox(height: 20.0),

        // 6. 월별 평균가 추이 그래프
        if (_transactions.isNotEmpty) ...[
          PriceTrendChart(
            transactions: _transactions,
            transactionType: _transactionType,
            months: _selectedMonths,
          ),
          const SizedBox(height: 20.0),
        ],

        // 7. 거래 목록
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '거래 내역',
              style: AppTypography.h4.copyWith(
                color: AirbnbColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${transactions.length}건',
              style: AppTypography.bodySmall.copyWith(
                color: AirbnbColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12.0),
        ...transactions.take(20).map(_buildTransactionCard),

        if (transactions.length > 20)
          Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Text(
              '외 ${transactions.length - 20}건 더 있음',
              style: AppTypography.caption.copyWith(
                color: AirbnbColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),

        const SizedBox(height: AppSpacing.md),
        Text(
          '* 국토교통부 실거래가 공개시스템 기준 (최근 12개월)',
          style: AppTypography.caption.copyWith(
            color: AirbnbColors.textLight,
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
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: AirbnbColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          // 트렌드 배지
          if (trend != null)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: _getTrendColor(trend.direction).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                trend.trendText,
                style: AppTypography.caption.copyWith(
                  color: _getTrendColor(trend.direction),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (trend != null) const SizedBox(height: 12.0),

          Text(
            '평균 $priceLabel',
            style: AppTypography.bodySmall.copyWith(
              color: AirbnbColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            RealTransaction.formatKoreanPrice(stats.average),
            style: AppTypography.display.copyWith(
              color: AirbnbColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem('최저', RealTransaction.formatKoreanPrice(stats.minPrice)),
              ),
              Container(width: 1, height: 32, color: AirbnbColors.border),
              Expanded(
                child: _buildSummaryItem('최고', RealTransaction.formatKoreanPrice(stats.maxPrice)),
              ),
              Container(width: 1, height: 32, color: AirbnbColors.border),
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
        return AirbnbColors.red;
      case TrendDirection.down:
        return AirbnbColors.primary;
      case TrendDirection.stable:
        return AirbnbColors.textSecondary;
    }
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AirbnbColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTypography.bodySmall.copyWith(
            color: AirbnbColors.textPrimary,
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
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AirbnbColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AirbnbColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline, size: 18, color: AirbnbColors.orange),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '가격대별 거래 예상',
                style: AppTypography.bodySmall.copyWith(
                  color: AirbnbColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          _buildSpeedGuideRow(
            '${RealTransaction.formatKoreanPrice(guide.fastThreshold)} 이하',
            '빠른 거래 예상',
            AirbnbColors.green,
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildSpeedGuideRow(
            '${RealTransaction.formatKoreanPrice(guide.normalMin)} ~ ${RealTransaction.formatKoreanPrice(guide.normalMax)}',
            '평균 속도',
            AirbnbColors.orange,
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildSpeedGuideRow(
            '${RealTransaction.formatKoreanPrice(guide.slowThreshold)} 이상',
            '협상 여지 필요',
            AirbnbColors.red,
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
        const SizedBox(width: 12.0),
        Expanded(
          child: Text(
            price,
            style: AppTypography.caption.copyWith(
              color: AirbnbColors.textSecondary,
            ),
          ),
        ),
        Text(
          label,
          style: AppTypography.caption.copyWith(
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
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AirbnbColors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '내 희망 가격 비교',
            style: AppTypography.bodySmall.copyWith(
              color: AirbnbColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12.0),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _myPriceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: '만원 단위 입력',
                    hintStyle: AppTypography.body.copyWith(
                      color: AirbnbColors.textLight,
                    ),
                    filled: true,
                    fillColor: AirbnbColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 12.0,
                    ),
                    suffixText: '만원',
                    suffixStyle: AppTypography.body.copyWith(
                      color: AirbnbColors.textSecondary,
                    ),
                  ),
                  style: AppTypography.body.copyWith(color: AirbnbColors.textPrimary),
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
            const SizedBox(height: 12.0),
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: _getCompareColor(stats.compareToAverage(_myPrice!)).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                children: [
                  Icon(
                    _getCompareIcon(stats.compareToAverage(_myPrice!)),
                    size: 20,
                    color: _getCompareColor(stats.compareToAverage(_myPrice!)),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Text(
                      stats.getPriceEvaluation(_myPrice!),
                      style: AppTypography.bodySmall.copyWith(
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
    if (diff <= -5) return AirbnbColors.green;
    if (diff < 5) return AirbnbColors.orange;
    return AirbnbColors.red;
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
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AirbnbColors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AirbnbColors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long, size: 20, color: AirbnbColors.green),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '예상 중개 수수료',
                  style: AppTypography.caption.copyWith(
                    color: AirbnbColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  fee.formatted,
                  style: AppTypography.h4.copyWith(
                    color: AirbnbColors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '요율 ${fee.ratePercent}',
            style: AppTypography.caption.copyWith(
              color: AirbnbColors.textSecondary,
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
              const Icon(Icons.filter_list, size: 18, color: AirbnbColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '필터',
                style: AppTypography.bodySmall.copyWith(
                  color: AirbnbColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (_selectedAreaFilter != null || _selectedFloorFilter != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AirbnbColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${(_selectedAreaFilter != null ? 1 : 0) + (_selectedFloorFilter != null ? 1 : 0)}',
                    style: AppTypography.caption.copyWith(
                      color: AirbnbColors.background,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const Spacer(),
              Icon(
                _showFilters ? Icons.expand_less : Icons.expand_more,
                color: AirbnbColors.primary,
                size: 20,
              ),
            ],
          ),
        ),
        if (_showFilters) ...[
          const SizedBox(height: 12.0),
          // 평형 필터
          if (areaFilters.length > 1) ...[
            Text(
              '평형',
              style: AppTypography.caption.copyWith(
                color: AirbnbColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
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
            const SizedBox(height: 12.0),
          ],
          // 층 필터
          if (floorFilters.length > 1) ...[
            Text(
              '층',
              style: AppTypography.caption.copyWith(
                color: AirbnbColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
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
          horizontal: 12.0,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AirbnbColors.primary : AirbnbColors.background,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: isSelected ? null : Border.all(color: AirbnbColors.border),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: isSelected ? AirbnbColors.background : AirbnbColors.textPrimary,
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
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AirbnbColors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
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
                    style: AppTypography.bodySmall.copyWith(
                      color: AirbnbColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (t.aptName.isNotEmpty) const SizedBox(height: 4),
                Text(
                  '${t.area.toStringAsFixed(0)}㎡ (${t.areaPyeong.toStringAsFixed(0)}평)  ·  ${t.floor > 0 ? "${t.floor}층  ·  " : ""}${t.dealYear}.${t.dealMonth.toString().padLeft(2, '0')}.${t.dealDay.toString().padLeft(2, '0')}',
                  style: AppTypography.caption.copyWith(
                    color: AirbnbColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12.0),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                priceText,
                style: AppTypography.h4.copyWith(
                  color: AirbnbColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (diffText.isNotEmpty)
                Text(
                  diffText,
                  style: AppTypography.caption.copyWith(
                    color: diff < 0 ? AirbnbColors.green : AirbnbColors.red,
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
        20.0,
        AppSpacing.md,
        20.0,
        MediaQuery.of(context).padding.bottom + AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AirbnbColors.background,
        border: Border(
          top: BorderSide(color: AirbnbColors.border, width: 0.5),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AirbnbColors.primary,
            foregroundColor: AirbnbColors.background,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            elevation: 0,
          ),
          child: Text(
            '이 가격에 매물 등록하기',
            style: AppTypography.h4.copyWith(
              color: AirbnbColors.background,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
