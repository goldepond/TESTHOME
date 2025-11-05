import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/models/quote_request.dart';
import 'package:property/widgets/home_logo_button.dart';
import 'package:property/screens/quote_comparison_page.dart';
import 'package:property/api_request/vworld_service.dart';
import 'package:property/screens/broker_list_page.dart';
import 'package:intl/intl.dart';

/// 견적문의 내역 페이지
class QuoteHistoryPage extends StatefulWidget {
  final String userName;
  final String? userId; // userId 추가

  const QuoteHistoryPage({
    required this.userName,
    this.userId, // userId 추가
    super.key,
  });

  @override
  State<QuoteHistoryPage> createState() => _QuoteHistoryPageState();
}

class _QuoteHistoryPageState extends State<QuoteHistoryPage> {
  final FirebaseService _firebaseService = FirebaseService();
  List<QuoteRequest> quotes = [];
  List<QuoteRequest> filteredQuotes = [];
  bool isLoading = true;
  String? error;
  
  // 필터 상태
  String selectedStatus = 'all'; // all, pending, completed
  
  // 그룹화된 견적 데이터 (주소별)
  Map<String, List<QuoteRequest>> _groupedQuotes = {};
  
  @override
  void initState() {
    super.initState();
    _loadQuotes();
  }
  
  /// 견적문의 목록 로드
  Future<void> _loadQuotes() async {
    if (!mounted) return;
    
    setState(() {
      isLoading = true;
      error = null;
    });
    
    try {
      
      // userId가 있으면 userId 사용, 없으면 userName 사용
      final queryId = widget.userId ?? widget.userName;
      
      // Stream으로 실시간 데이터 수신
      _firebaseService.getQuoteRequestsByUser(queryId).listen((loadedQuotes) {
        if (mounted) {
          setState(() {
            quotes = loadedQuotes;
            isLoading = false;
          });
          _applyFilter();
        }
      });
    } catch (e) {
      print('❌ [견적문의내역] 로드 오류: $e');
      if (!mounted) return;
      
      setState(() {
        error = '견적문의 내역을 불러오는 중 오류가 발생했습니다.';
        isLoading = false;
      });
    }
  }
  
  /// 필터 적용
  void _applyFilter() {
    setState(() {
      if (selectedStatus == 'all') {
        filteredQuotes = quotes;
      } else {
        filteredQuotes = quotes.where((q) => q.status == selectedStatus).toList();
      }
      
      // 주소별로 그룹화
      _groupedQuotes = {};
      for (final quote in filteredQuotes) {
        final address = quote.propertyAddress ?? '주소없음';
        if (!_groupedQuotes.containsKey(address)) {
          _groupedQuotes[address] = [];
        }
        _groupedQuotes[address]!.add(quote);
      }
      
      // 각 그룹 내에서 날짜순 정렬 (최신순)
      _groupedQuotes.forEach((key, value) {
        value.sort((a, b) => b.requestDate.compareTo(a.requestDate));
      });
    });
  }
  
  /// 견적문의 삭제
  /// 공인중개사 재연락 (전화 또는 다시 견적 요청)
  Future<void> _recontactBroker(QuoteRequest quote) async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.phone, color: AppColors.kPrimary, size: 28),
            const SizedBox(width: 12),
            const Text('재연락 방법', style: TextStyle(fontSize: 20)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '이 공인중개사와 재연락하는 방법을 선택하세요:',
              style: TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.phone, color: Colors.green),
              title: const Text('전화 걸기', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('직접 통화하여 문의'),
              onTap: () => Navigator.pop(context, 'phone'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            ListTile(
              leading: const Icon(Icons.refresh, color: AppColors.kPrimary),
              title: const Text('다시 견적 요청', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('같은 주소로 새로 견적 요청'),
              onTap: () => Navigator.pop(context, 'resend'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
        ],
      ),
    );

    if (action == 'phone') {
      // 전화 걸기 (등록번호로 중개사 정보 조회 필요 - 간단히 처리)
      final phoneNumber = quote.brokerRegistrationNumber; // 실제로는 전화번호를 저장해야 함
      if (phoneNumber == null || phoneNumber.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('전화번호 정보가 없습니다.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // 실제로는 QuoteRequest에 brokerPhoneNumber 필드가 있어야 함
      // 현재는 brokerRegistrationNumber만 있으므로, BrokerService로 조회 필요
      // 일단 간단히 안내만 표시
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('전화번호 정보는 공인중개사 목록에서 확인할 수 있습니다.'),
          backgroundColor: AppColors.kInfo,
          duration: Duration(seconds: 3),
        ),
      );
    } else if (action == 'resend') {
      // 다시 견적 요청
      if (quote.propertyAddress == null || quote.propertyAddress!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('주소 정보가 없어 견적을 다시 요청할 수 없습니다.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // 로딩 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      try {
        // 주소에서 좌표 조회
        final coord = await VWorldService.getCoordinatesFromAddress(
          quote.propertyAddress!,
        );

        if (coord == null) {
          if (context.mounted) {
            Navigator.pop(context); // 로딩 닫기
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('주소 정보를 찾을 수 없습니다.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        final lat = double.tryParse('${coord['y']}');
        final lon = double.tryParse('${coord['x']}');

        if (lat == null || lon == null) {
          if (context.mounted) {
            Navigator.pop(context); // 로딩 닫기
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('좌표 정보를 가져올 수 없습니다.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        if (context.mounted) {
          Navigator.pop(context); // 로딩 닫기

          // BrokerListPage로 이동 (기존 주소 사용)
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BrokerListPage(
                address: quote.propertyAddress!,
                latitude: lat,
                longitude: lon,
                userName: widget.userName,
                userId: quote.userId.isNotEmpty ? quote.userId : null,
                propertyArea: quote.propertyArea,
              ),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.pop(context); // 로딩 닫기
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('오류가 발생했습니다: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteQuote(String quoteId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('삭제 확인', style: TextStyle(fontSize: 20)),
          ],
        ),
        content: const Text(
          '이 견적문의를 삭제하시겠습니까?\n삭제된 내역은 복구할 수 없습니다.',
          style: TextStyle(fontSize: 15, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소', style: TextStyle(fontSize: 15)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('삭제', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      final success = await _firebaseService.deleteQuoteRequest(quoteId);
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('견적문의가 삭제되었습니다.'),
            backgroundColor: AppColors.kSuccess,
          ),
        );
      } else if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('삭제에 실패했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
        print('❌ [견적문의내역] 삭제 실패: $quoteId');
      }
    }
  }
  
  /// 견적문의 전체 상세 정보 표시
  void _showFullQuoteDetails(QuoteRequest quote) {
    final dateFormat = DateFormat('yyyy.MM.dd HH:mm');
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          child: Column(
            children: [
              // 헤더
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.kPrimary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.description, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            quote.brokerName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          if (quote.answerDate != null)
                            Text(
                              '답변일: ${dateFormat.format(quote.answerDate!)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              
              // 내용
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 매물 정보
                      if (quote.propertyAddress != null || quote.propertyArea != null || quote.propertyType != null) ...[
                        _buildDetailSection(
                          '매물 정보',
                          Icons.home,
                          Colors.blue,
                          [
                            if (quote.propertyAddress != null)
                              _buildDetailRow('위치', quote.propertyAddress!),
                            if (quote.propertyType != null)
                              _buildDetailRow('유형', quote.propertyType!),
                            if (quote.propertyArea != null)
                              _buildDetailRow('면적', '${quote.propertyArea} ㎡'),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                      
                      // 중개 제안
                      if (quote.recommendedPrice != null || quote.minimumPrice != null ||
                          quote.expectedDuration != null || quote.promotionMethod != null ||
                          quote.commissionRate != null || quote.recentCases != null) ...[
                        _buildDetailSection(
                          '중개 제안',
                          Icons.campaign,
                          Colors.green,
                          [
                            if (quote.recommendedPrice != null)
                              _buildDetailRow('권장 매도가', quote.recommendedPrice!),
                            if (quote.minimumPrice != null)
                              _buildDetailRow('최저수락가', quote.minimumPrice!),
                            if (quote.expectedDuration != null)
                              _buildDetailRow('예상 거래기간', quote.expectedDuration!),
                            if (quote.commissionRate != null)
                              _buildDetailRow('수수료 제안율', quote.commissionRate!),
                            if (quote.promotionMethod != null)
                              _buildDetailRow('홍보 방법', quote.promotionMethod!),
                            if (quote.recentCases != null)
                              _buildDetailRow('최근 유사 거래 사례', quote.recentCases!),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                      
                      // 공인중개사 답변
                      if (quote.brokerAnswer != null && quote.brokerAnswer!.isNotEmpty) ...[
                        _buildDetailSection(
                          '공인중개사 답변',
                          Icons.reply,
                          const Color(0xFF9C27B0),
                          [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Text(
                                quote.brokerAnswer!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.7,
                                  color: Color(0xFF2C3E50),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              
              // 하단 버튼
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _recontactBroker(quote);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.kPrimary,
                          side: BorderSide(color: AppColors.kPrimary, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.phone, size: 18),
                        label: const Text('재연락', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _deleteQuote(quote.id);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.delete, size: 18),
                        label: const Text('삭제', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// 상세 정보 섹션 위젯
  Widget _buildDetailSection(String title, IconData icon, Color color, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
  
  /// 상세 정보 행 위젯
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF2C3E50),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = screenWidth > 800;
    final maxWidth = isWeb ? 1200.0 : screenWidth;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          // 헤더
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            backgroundColor: Colors.white,
            foregroundColor: AppColors.kPrimary,
            elevation: 0,
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            leadingWidth: 56,
            title: const HomeLogoButton(fontSize: 18),
            centerTitle: false,
            actions: [
              // 견적 비교 버튼 (MVP 핵심)
              IconButton(
                icon: const Icon(Icons.compare_arrows, color: Colors.white),
                tooltip: '견적 비교',
                onPressed: () {
                  // 답변 완료된 견적만 필터
                  final respondedQuotes = quotes.where((q) {
                    return (q.recommendedPrice != null && q.recommendedPrice!.isNotEmpty) ||
                           (q.minimumPrice != null && q.minimumPrice!.isNotEmpty);
                  }).toList();
                  
                  if (respondedQuotes.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('비교할 견적이 없습니다. 공인중개사로부터 답변을 받으면 비교할 수 있습니다.'),
                        backgroundColor: Colors.orange,
                        duration: Duration(seconds: 3),
                      ),
                    );
                    return;
                  }
                  
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => QuoteComparisonPage(
                        quotes: quotes,
                        userName: widget.userName,
                        userId: quotes.isNotEmpty && quotes.first.userId.isNotEmpty
                            ? quotes.first.userId
                            : null,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  color: AppColors.kSecondary, // 남색 단색
                ),
                child: Center(
                  child: Container(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 40),
                        const Row(
                          children: [
                            Icon(Icons.history, color: Colors.white, size: 40),
                            SizedBox(width: 16),
                            Text(
                              '견적문의 내역',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '내가 보낸 견적문의 내역을 확인하세요',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // 컨텐츠
          SliverToBoxAdapter(
            child: Center(
              child: Container(
                constraints: BoxConstraints(maxWidth: maxWidth),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 필터 버튼들
                    if (!isLoading && quotes.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
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
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildFilterChip('전체', 'all', quotes.length),
                            _buildFilterChip('답변대기', 'pending', 
                              quotes.where((q) => q.status == 'pending').length),
                            _buildFilterChip('답변완료', 'completed', 
                              quotes.where((q) => q.status == 'completed').length),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    
                    // 로딩 / 에러 / 결과 표시
                    if (isLoading)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(60),
                          child: const CircularProgressIndicator(strokeWidth: 3),
                        ),
                      )
                    else if (error != null)
                      _buildErrorCard()
                    else if (quotes.isEmpty)
                      _buildEmptyCard()
                    else if (filteredQuotes.isEmpty)
                      _buildNoFilterResultsCard()
                    else
                      _buildQuoteList(),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// 정보 행 위젯
  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF2C3E50),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
  
  /// 필터 칩 위젯
  Widget _buildFilterChip(String label, String value, int count) {
    final isSelected = selectedStatus == value;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isSelected 
                  ? AppColors.kPrimary.withValues(alpha: 0.3) 
                  : Colors.grey.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? AppColors.kPrimary : Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          selectedStatus = value;
          _applyFilter();
        });
      },
      selectedColor: AppColors.kPrimary.withValues(alpha: 0.2),
      checkmarkColor: AppColors.kPrimary,
      backgroundColor: Colors.grey[100],
      labelStyle: TextStyle(
        color: isSelected ? AppColors.kPrimary : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
  
  /// 견적문의 목록 (주소별 그룹화)
  Widget _buildQuoteList() {
    if (_groupedQuotes.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _groupedQuotes.length,
      itemBuilder: (context, index) {
        final address = _groupedQuotes.keys.elementAt(index);
        final quotesForAddress = _groupedQuotes[address]!;
        
        // 같은 주소에 대한 답변이 여러 개인 경우 그룹으로 표시
        if (quotesForAddress.length > 1) {
          return _buildGroupedQuotesCard(address, quotesForAddress);
        } else {
          // 답변이 하나만 있는 경우 기존 방식대로 표시
          return _buildQuoteCard(quotesForAddress.first);
        }
      },
    );
  }
  
  /// 같은 주소에 대한 여러 답변을 그룹화하여 표시하는 카드
  Widget _buildGroupedQuotesCard(String address, List<QuoteRequest> quotes) {
    final answeredCount = quotes.where((q) => q.hasAnswer).length;
    final pendingCount = quotes.length - answeredCount;
    
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 그룹 헤더
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: answeredCount > 0
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.orange.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: answeredCount > 0 ? Colors.green : Colors.orange,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        answeredCount > 0 ? Icons.compare_arrows : Icons.schedule,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.home, size: 16, color: Colors.grey[700]),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  address,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2C3E50),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '답변완료: $answeredCount',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '답변대기: $pendingCount',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // 각 답변 카드들
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: quotes.asMap().entries.map((entry) {
                final index = entry.key;
                final quote = entry.value;
                final isLast = index == quotes.length - 1;
                
                return Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                  child: _buildComparisonQuoteCard(quote, index + 1),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
  
  /// 비교용 축약된 견적 카드 (그룹 내에서 사용)
  Widget _buildComparisonQuoteCard(QuoteRequest quote, int index) {
    final dateFormat = DateFormat('yyyy.MM.dd HH:mm');
    final hasAnswer = quote.hasAnswer;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasAnswer 
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.orange.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 중개사 정보 헤더
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: hasAnswer 
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.orange.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: hasAnswer ? Colors.green : Colors.orange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '$index',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quote.brokerName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      if (quote.brokerRoadAddress != null && quote.brokerRoadAddress!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          quote.brokerRoadAddress!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: hasAnswer ? Colors.green : Colors.orange,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasAnswer ? Icons.check_circle : Icons.schedule,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        hasAnswer ? '답변완료' : '답변대기',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // 핵심 정보 비교 섹션
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 권장가 / 최저가 비교
                if (quote.recommendedPrice != null || quote.minimumPrice != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _buildComparisonInfoCard(
                          '권장 매도가',
                          quote.recommendedPrice ?? '-',
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildComparisonInfoCard(
                          '최저수락가',
                          quote.minimumPrice ?? '-',
                          Colors.purple,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                
                // 거래기간 / 수수료 비교
                if (quote.expectedDuration != null || quote.commissionRate != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _buildComparisonInfoCard(
                          '예상 거래기간',
                          quote.expectedDuration ?? '-',
                          Colors.teal,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildComparisonInfoCard(
                          '수수료',
                          quote.commissionRate ?? '-',
                          Colors.indigo,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                
                // 공인중개사 답변 (전체 텍스트 표시)
                if (quote.brokerAnswer != null && quote.brokerAnswer!.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF9C27B0).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.reply,
                              size: 16,
                              color: Color(0xFF9C27B0),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              '공인중개사 답변',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF9C27B0),
                              ),
                            ),
                            if (quote.answerDate != null) ...[
                              const Spacer(),
                              Text(
                                dateFormat.format(quote.answerDate!),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          quote.brokerAnswer!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF2C3E50),
                            height: 1.5,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => _showFullQuoteDetails(quote),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(
                              Icons.open_in_full,
                              size: 14,
                              color: Color(0xFF9C27B0),
                            ),
                            label: const Text(
                              '전체보기',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF9C27B0),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.hourglass_empty, size: 16, color: Colors.orange[700]),
                        const SizedBox(width: 8),
                        Text(
                          '답변 대기 중입니다',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[700],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                // 전체보기 버튼 (중개 제안이 있으면 항상 표시)
                if (quote.recommendedPrice != null || quote.minimumPrice != null ||
                    quote.expectedDuration != null || quote.promotionMethod != null ||
                    quote.commissionRate != null || quote.recentCases != null ||
                    quote.brokerAnswer != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showFullQuoteDetails(quote),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.kPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 2,
                      ),
                      icon: const Icon(Icons.description, size: 18),
                      label: const Text(
                        '전체 제안 내용 보기',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // 액션 버튼
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _recontactBroker(quote),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.kPrimary,
                      side: BorderSide(color: AppColors.kPrimary, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.phone, size: 16),
                    label: const Text(
                      '재연락',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _deleteQuote(quote.id),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.delete, size: 16),
                    label: const Text(
                      '삭제',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  /// 비교용 정보 카드 위젯
  Widget _buildComparisonInfoCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  /// 견적문의 카드
  Widget _buildQuoteCard(QuoteRequest quote) {
    final dateFormat = DateFormat('yyyy.MM.dd HH:mm');
    final isPending = quote.status == 'pending';
    
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isPending 
                  ? Colors.orange.withValues(alpha: 0.1) 
                  : Colors.green.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isPending ? Colors.orange : Colors.green,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isPending ? Icons.schedule : Icons.check_circle,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quote.brokerName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateFormat.format(quote.requestDate),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isPending ? Colors.orange : Colors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isPending ? '답변대기' : '답변완료',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 내용
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 중개사 주소
                if (quote.brokerRoadAddress != null && quote.brokerRoadAddress!.isNotEmpty) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.business, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          quote.brokerRoadAddress!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                
                // ========== 기본정보 ==========
                if (quote.propertyType != null || quote.propertyAddress != null || quote.propertyArea != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.home, size: 16, color: Colors.blue[700]),
                            const SizedBox(width: 8),
                            Text(
                              '매물 정보',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (quote.propertyType != null) ...[
                          _buildInfoRow('유형', quote.propertyType!),
                          const SizedBox(height: 8),
                        ],
                        if (quote.propertyAddress != null) ...[
                          _buildInfoRow('위치', quote.propertyAddress!),
                          const SizedBox(height: 8),
                        ],
                        if (quote.propertyArea != null)
                          _buildInfoRow('면적', '${quote.propertyArea} ㎡'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // ========== 특이사항 ==========
                if (quote.hasTenant != null || quote.desiredPrice != null || 
                    quote.targetPeriod != null || quote.specialNotes != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.edit_note, size: 16, color: Colors.orange[700]),
                            const SizedBox(width: 8),
                            Text(
                              '특이사항',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (quote.hasTenant != null) ...[
                          _buildInfoRow('세입자', quote.hasTenant! ? '있음' : '없음'),
                          const SizedBox(height: 8),
                        ],
                        if (quote.desiredPrice != null && quote.desiredPrice!.isNotEmpty) ...[
                          _buildInfoRow('희망가', quote.desiredPrice!),
                          const SizedBox(height: 8),
                        ],
                        if (quote.targetPeriod != null && quote.targetPeriod!.isNotEmpty) ...[
                          _buildInfoRow('목표기간', quote.targetPeriod!),
                          const SizedBox(height: 8),
                        ],
                        if (quote.specialNotes != null && quote.specialNotes!.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '추가사항',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                quote.specialNotes!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF2C3E50),
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // ========== 중개 제안 (중개업자가 입력한 경우) ==========
                if (quote.recommendedPrice != null || quote.minimumPrice != null ||
                    quote.expectedDuration != null || quote.promotionMethod != null ||
                    quote.commissionRate != null || quote.recentCases != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.campaign, size: 16, color: Colors.green[700]),
                            const SizedBox(width: 8),
                            Text(
                              '중개 제안',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (quote.recommendedPrice != null && quote.recommendedPrice!.isNotEmpty) ...[
                          _buildInfoRow('권장 매도가', quote.recommendedPrice!),
                          const SizedBox(height: 8),
                        ],
                        if (quote.minimumPrice != null && quote.minimumPrice!.isNotEmpty) ...[
                          _buildInfoRow('최저수락가', quote.minimumPrice!),
                          const SizedBox(height: 8),
                        ],
                        if (quote.expectedDuration != null && quote.expectedDuration!.isNotEmpty) ...[
                          _buildInfoRow('예상 거래기간', quote.expectedDuration!),
                          const SizedBox(height: 8),
                        ],
                        if (quote.promotionMethod != null && quote.promotionMethod!.isNotEmpty) ...[
                          _buildInfoRow('홍보 방법', quote.promotionMethod!),
                          const SizedBox(height: 8),
                        ],
                        if (quote.commissionRate != null && quote.commissionRate!.isNotEmpty) ...[
                          _buildInfoRow('수수료 제안율', quote.commissionRate!),
                          const SizedBox(height: 8),
                        ],
                        if (quote.recentCases != null && quote.recentCases!.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '최근 유사 거래 사례',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                quote.recentCases!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF2C3E50),
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // ========== 공인중개사 답변 ==========
                // 답변이 있거나 상태가 answered/completed인 경우 표시 (답변 데이터가 없어도 상태 확인)
                if (quote.hasAnswer || quote.status == 'answered' || quote.status == 'completed') ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF9C27B0).withValues(alpha: 0.1),
                          const Color(0xFF7B1FA2).withValues(alpha: 0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF9C27B0).withValues(alpha: 0.3), width: 2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF9C27B0).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.reply, size: 16, color: Color(0xFF9C27B0)),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '✅ 공인중개사 답변',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF9C27B0),
                              ),
                            ),
                            if (quote.answerDate != null) ...[
                              const Spacer(),
                              Text(
                                DateFormat('yyyy.MM.dd HH:mm').format(quote.answerDate!),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF9C27B0).withValues(alpha: 0.2)),
                          ),
                          child: quote.brokerAnswer != null && quote.brokerAnswer!.isNotEmpty
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      quote.brokerAnswer!,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF2C3E50),
                                        height: 1.6,
                                      ),
                                      maxLines: 5,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton.icon(
                                        onPressed: () => _showFullQuoteDetails(quote),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        icon: const Icon(
                                          Icons.open_in_full,
                                          size: 14,
                                          color: Color(0xFF9C27B0),
                                        ),
                                        label: const Text(
                                          '전체보기',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF9C27B0),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  children: [
                                    Icon(Icons.hourglass_empty, size: 32, color: Colors.grey[400]),
                                    const SizedBox(height: 8),
                                    Text(
                                      '답변 내용을 불러오는 중입니다...',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                        fontStyle: FontStyle.italic,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                // 전체보기 버튼 (중개 제안이 있으면 항상 표시)
                if (quote.recommendedPrice != null || quote.minimumPrice != null ||
                    quote.expectedDuration != null || quote.promotionMethod != null ||
                    quote.commissionRate != null || quote.recentCases != null ||
                    quote.brokerAnswer != null || quote.hasAnswer) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showFullQuoteDetails(quote),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.kPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      icon: const Icon(Icons.description, size: 20),
                      label: const Text(
                        '전체 제안 내용 보기',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
                
                const SizedBox(height: 16),
                
                // 액션 버튼
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _recontactBroker(quote),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.kPrimary,
                              side: BorderSide(color: AppColors.kPrimary, width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.phone, size: 18),
                            label: const Text('재연락', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _deleteQuote(quote.id),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red, width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.delete, size: 18),
                            label: const Text('삭제', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  /// 에러 카드
  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline, color: Colors.red, size: 48),
            ),
            const SizedBox(height: 20),
            const Text(
              '오류 발생',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              error ?? '',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadQuotes,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.kPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text('다시 시도', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
  
  /// 내역 없음 카드
  Widget _buildEmptyCard() {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.inbox, size: 64, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            const Text(
              '견적문의 내역이 없습니다',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '공인중개사에게 문의를 보내보세요!',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  /// 필터 결과 없음 카드
  Widget _buildNoFilterResultsCard() {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.filter_alt_off, size: 64, color: Colors.orange),
            ),
            const SizedBox(height: 24),
            const Text(
              '해당하는 문의 내역이 없습니다',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '다른 필터를 선택해보세요.',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

