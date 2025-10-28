import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/models/quote_request.dart';
import 'package:intl/intl.dart';

/// 견적문의 내역 페이지
class QuoteHistoryPage extends StatefulWidget {
  final String userName;

  const QuoteHistoryPage({
    required this.userName,
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
      // TODO: FirebaseService에 사용자별 견적문의 조회 메서드 추가 필요
      // 현재는 임시로 빈 리스트 반환
      final List<QuoteRequest> loadedQuotes = [];
      
      if (!mounted) return;
      
      setState(() {
        quotes = loadedQuotes;
        filteredQuotes = loadedQuotes;
        isLoading = false;
      });
      
      _applyFilter();
    } catch (e) {
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
    });
  }
  
  /// 견적문의 삭제
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
      // TODO: FirebaseService에 견적문의 삭제 메서드 추가 필요
      setState(() {
        quotes.removeWhere((q) => q.id == quoteId);
        _applyFilter();
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('견적문의가 삭제되었습니다.'),
            backgroundColor: AppColors.kSuccess,
          ),
        );
      }
    }
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
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: const [AppColors.kPrimary, AppColors.kSecondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
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
  
  /// 견적문의 목록
  Widget _buildQuoteList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredQuotes.length,
      itemBuilder: (context, index) {
        return _buildQuoteCard(filteredQuotes[index]);
      },
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
                // 주소
                if (quote.brokerRoadAddress != null && quote.brokerRoadAddress!.isNotEmpty) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          quote.brokerRoadAddress!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                
                // 문의 내용
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.message, size: 16, color: Colors.grey[700]),
                          const SizedBox(width: 8),
                          Text(
                            '문의 내용',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        quote.message,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF2C3E50),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // 액션 버튼
                Row(
                  children: [
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

