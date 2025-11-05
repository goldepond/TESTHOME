import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/models/quote_request.dart';
import 'package:property/widgets/loading_overlay.dart';
import 'package:intl/intl.dart';

class HouseManagementPage extends StatefulWidget {
  final String userId;
  final String userName;

  const HouseManagementPage({
    required this.userId,
    required this.userName,
    super.key,
  });

  @override
  State<HouseManagementPage> createState() => _HouseManagementPageState();
}

class _HouseManagementPageState extends State<HouseManagementPage> with SingleTickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  List<QuoteRequest> _myQuotes = [];
  bool _isLoading = true;
  
  // 탭 컨트롤러
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    _loadMyQuotes();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadMyQuotes() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }
      
      // Stream으로 실시간 데이터 수신
      _firebaseService.getQuoteRequestsByUser(widget.userId).listen((quotes) {
        if (mounted) {
          setState(() {
            _myQuotes = quotes;
            _isLoading = false; // ✅ 최초/갱신 수신 시 로딩 해제
          });
        }
      });
    } catch (e) {
      print('❌ [내집관리] 내 요청 목록 로드 오류: $e');
      if (mounted) {
        setState(() {
          _myQuotes = [];
          _isLoading = false; // ✅ 오류 시에도 로딩 해제
        });
      }
    }
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
          '이 요청을 삭제하시겠습니까?\n삭제된 내역은 복구할 수 없습니다.',
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
            content: Text('요청이 삭제되었습니다.'),
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
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      message: '내 집 정보를 불러오는 중...',
      child: Scaffold(
        backgroundColor: AppColors.kBackground,
        body: SafeArea(
          child: Column(
            children: [
              // 상단 헤더 영역 (다른 페이지와 통일)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: const [
                      AppColors.kPrimary,
                      AppColors.kSecondary,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.kPrimary.withValues(alpha: 0.3),
                      offset: const Offset(0, 4),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.home_work_rounded,
                      size: 40,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '내집관리',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '견적 요청 내역을 확인하세요',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              // TabBar
              Container(
                color: AppColors.kPrimary,
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.white,
                  indicatorWeight: 3,
                  labelColor: Colors.white,
                  labelStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  unselectedLabelColor: Colors.white.withOpacity(0.7),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.normal,
                  ),
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.request_quote),
                      text: '내 요청',
                    ),
                  ],
                ),
              ),
              // 메인 콘텐츠
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildMyRequestsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// 내 요청 탭
  Widget _buildMyRequestsTab() {
    if (_myQuotes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.inbox,
                size: 64,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '보낸 요청이 없습니다',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '공인중개사에게 제안 요청을 보내보세요!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _myQuotes.length,
      itemBuilder: (context, index) {
        final quote = _myQuotes[index];
        return _buildQuoteCard(quote);
      },
    );
  }
  
  /// 견적문의 카드
  Widget _buildQuoteCard(QuoteRequest quote) {
    final dateFormat = DateFormat('yyyy.MM.dd HH:mm');
    final isPending = quote.status == 'pending';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPending 
              ? Colors.orange.withOpacity(0.3) 
              : Colors.green.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: isPending 
                ? Colors.orange.withOpacity(0.15) 
                : Colors.green.withOpacity(0.15),
            blurRadius: 24,
            offset: const Offset(0, 6),
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
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
              gradient: LinearGradient(
                colors: isPending 
                    ? [
                        Colors.orange.withOpacity(0.2),
                        Colors.orange.withOpacity(0.15),
                      ]
                    : [
                        Colors.green.withOpacity(0.2),
                        Colors.green.withOpacity(0.15),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
              border: Border(
                bottom: BorderSide(
                  color: isPending 
                      ? Colors.orange.withOpacity(0.3) 
                      : Colors.green.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isPending ? Colors.orange : Colors.green,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: (isPending ? Colors.orange : Colors.green).withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    isPending ? Icons.schedule : Icons.check_circle,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quote.brokerName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.grey[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            dateFormat.format(quote.requestDate),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isPending ? Colors.orange : Colors.green,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: (isPending ? Colors.orange : Colors.green).withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    isPending ? '답변대기' : '답변완료',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
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
                // 매물 정보
                if (quote.propertyAddress != null) ...[
                  _buildQuoteInfoRow(Icons.location_on, '매물 주소', quote.propertyAddress!),
                  const SizedBox(height: 12),
                ],
                if (quote.propertyType != null) ...[
                  _buildQuoteInfoRow(Icons.home, '매물 유형', quote.propertyType!),
                  const SizedBox(height: 12),
                ],
                if (quote.propertyArea != null) ...[
                  _buildQuoteInfoRow(Icons.square_foot, '전용면적', '${quote.propertyArea} ㎡'),
                  const SizedBox(height: 12),
                ],
                
                // 내가 입력한 정보
                if (quote.desiredPrice != null && quote.desiredPrice!.isNotEmpty) ...[
                  const Divider(height: 32, thickness: 1.5, color: Color(0xFFE0E0E0)),
                  _buildQuoteInfoRow(Icons.attach_money, '희망가', quote.desiredPrice!),
                  const SizedBox(height: 12),
                ],
                if (quote.targetPeriod != null && quote.targetPeriod!.isNotEmpty) ...[
                  _buildQuoteInfoRow(Icons.schedule, '목표기간', quote.targetPeriod!),
                  const SizedBox(height: 12),
                ],
                if (quote.hasTenant != null) ...[
                  _buildQuoteInfoRow(
                    Icons.people, 
                    '세입자', 
                    quote.hasTenant! ? '있음' : '없음',
                  ),
                  const SizedBox(height: 12),
                ],
                
                // 중개 제안 (중개업자가 작성한 경우)
                if (quote.recommendedPrice != null || quote.minimumPrice != null) ...[
                  const Divider(height: 32, thickness: 1.5, color: Color(0xFFE0E0E0)),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.green.withOpacity(0.1),
                          Colors.green.withOpacity(0.08),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.green.withOpacity(0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.campaign, size: 18, color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '중개 제안',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (quote.recommendedPrice != null && quote.recommendedPrice!.isNotEmpty)
                          _buildQuoteInfoRow(Icons.monetization_on, '권장 매도가', quote.recommendedPrice!),
                        if (quote.minimumPrice != null && quote.minimumPrice!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _buildQuoteInfoRow(Icons.price_check, '최저수락가', quote.minimumPrice!),
                        ],
                        if (quote.commissionRate != null && quote.commissionRate!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _buildQuoteInfoRow(Icons.percent, '수수료율', quote.commissionRate!),
                        ],
                      ],
                    ),
                  ),
                ],
                
                // 공인중개사 답변 (있는 경우)
                if (quote.hasAnswer || quote.status == 'answered' || quote.status == 'completed') ...[
                  const Divider(height: 32, thickness: 1.5, color: Color(0xFFE0E0E0)),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF9C27B0).withValues(alpha: 0.15),
                          const Color(0xFF7B1FA2).withValues(alpha: 0.12),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF9C27B0).withValues(alpha: 0.4),
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF9C27B0).withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF9C27B0),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.check_circle, size: 18, color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '공인중개사 답변',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF9C27B0),
                                letterSpacing: -0.3,
                              ),
                            ),
                            if (quote.answerDate != null) ...[
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: 12,
                                      color: Colors.grey[700],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      dateFormat.format(quote.answerDate!),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey[300]!, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: quote.brokerAnswer != null && quote.brokerAnswer!.isNotEmpty
                              ? Text(
                                  quote.brokerAnswer!,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Color(0xFF1A1A1A),
                                    height: 1.7,
                                    letterSpacing: -0.2,
                                  ),
                                )
                              : Column(
                                  children: [
                                    Icon(Icons.hourglass_empty, size: 36, color: Colors.grey[400]),
                                    const SizedBox(height: 10),
                                    Text(
                                      '답변 내용을 불러오는 중입니다...',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                        fontStyle: FontStyle.italic,
                                        fontWeight: FontWeight.w500,
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
                
                // 액션 버튼
                const Divider(height: 28, thickness: 1.5, color: Color(0xFFE0E0E0)),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _deleteQuote(quote.id),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red, width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.delete, size: 20),
                    label: const Text(
                      '요청 삭제',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
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
  
  /// 견적문의 정보 행
  Widget _buildQuoteInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.kPrimary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: AppColors.kPrimary,
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              fontWeight: FontWeight.bold,
              letterSpacing: -0.2,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF1A1A1A),
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ],
    );
  }
}

