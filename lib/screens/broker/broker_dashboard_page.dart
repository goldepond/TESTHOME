import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/models/quote_request.dart';
import 'package:property/widgets/home_logo_button.dart';
import 'package:intl/intl.dart';
import 'broker_quote_detail_page.dart';
import '../login_page.dart';
import 'broker_settings_page.dart';

/// 공인중개사 대시보드 페이지
class BrokerDashboardPage extends StatefulWidget {
  final String brokerId;
  final String brokerName;
  final Map<String, dynamic> brokerData;

  const BrokerDashboardPage({
    required this.brokerId,
    required this.brokerName,
    required this.brokerData,
    super.key,
  });

  @override
  State<BrokerDashboardPage> createState() => _BrokerDashboardPageState();
}

class _BrokerDashboardPageState extends State<BrokerDashboardPage> with SingleTickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  List<QuoteRequest> _quotes = [];
  bool _isLoading = true;
  String? _error;
  String _selectedStatus = 'all'; // all, pending, completed
  late TabController _tabController;

  String? _brokerRegistrationNumber;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _brokerRegistrationNumber = widget.brokerData['brokerRegistrationNumber'] as String?;
    _loadQuotes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadQuotes() {
    if (_brokerRegistrationNumber == null || _brokerRegistrationNumber!.isEmpty) {
      setState(() {
        _error = '등록번호 정보가 없습니다.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null; // 오류 초기화
    });

    // Stream으로 실시간 데이터 수신
    _firebaseService.getBrokerQuoteRequests(_brokerRegistrationNumber!).listen(
      (quotes) {
        if (mounted) {
          setState(() {
            _quotes = quotes;
            _isLoading = false;
            _error = null; // 정상적으로 데이터를 받았으므로 오류 없음
          });
        }
      },
      onError: (error) {
        // 실제 오류가 발생한 경우에만 오류 메시지 표시
        if (mounted) {
          setState(() {
            _error = '견적 목록을 불러오는 중 오류가 발생했습니다.\n잠시 후 다시 시도해주세요.';
            _isLoading = false;
          });
        }
      },
      cancelOnError: false, // 오류 발생 시에도 스트림 계속 유지
    );
  }

  List<QuoteRequest> get _filteredQuotes {
    if (_selectedStatus == 'all') {
      return _quotes;
    } else if (_selectedStatus == 'pending') {
      return _quotes.where((q) => q.status == 'pending' && !q.hasAnswer).toList();
    } else {
      return _quotes.where((q) => q.hasAnswer).toList();
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _firebaseService.signOut();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kBackground,
      appBar: AppBar(
        title: const HomeLogoButton(fontSize: 18),
        backgroundColor: AppColors.kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '로그아웃',
            onPressed: _logout,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(
              icon: Icon(Icons.chat_bubble_outline),
              text: '견적문의',
            ),
            Tab(
              icon: Icon(Icons.settings),
              text: '내 정보',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 견적문의 탭
          Column(
            children: [
              // 헤더
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  gradient: AppGradients.primaryDiagonal,
                ),
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.business,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '공인중개사 대시보드',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.brokerName,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          _buildStatCard(
                            '전체',
                            _quotes.length.toString(),
                            Colors.white,
                          ),
                          const SizedBox(width: 12),
                          _buildStatCard(
                            '대기중',
                            _quotes.where((q) => q.status == 'pending' && !q.hasAnswer).length.toString(),
                            Colors.orange,
                          ),
                          const SizedBox(width: 12),
                          _buildStatCard(
                            '답변완료',
                            _quotes.where((q) => q.hasAnswer).length.toString(),
                            Colors.green,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // 필터 버튼
              if (!_isLoading && _quotes.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildFilterChip('전체', 'all', _quotes.length),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildFilterChip('대기중', 'pending',
                            _quotes.where((q) => q.status == 'pending' && !q.hasAnswer).length),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildFilterChip('답변완료', 'completed',
                            _quotes.where((q) => q.hasAnswer).length),
                      ),
                    ],
                  ),
                ),

              // 견적 목록
              Expanded(
                child: _buildQuoteList(),
              ),
            ],
          ),
          // 내 정보 탭
          BrokerSettingsPage(
            brokerId: widget.brokerId,
            brokerName: widget.brokerName,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String status, int count) {
    final isSelected = _selectedStatus == status;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedStatus = status;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.kPrimary : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.kPrimary : Colors.grey.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.grey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.grey[700],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuoteList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.kPrimary),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadQuotes,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (_filteredQuotes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 24),
            Text(
              _selectedStatus == 'all'
                  ? '받은 견적 요청이 없습니다'
                  : '조건에 맞는 견적이 없습니다',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '판매자로부터 견적 요청이 들어오면\n여기에 표시됩니다',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredQuotes.length,
      itemBuilder: (context, index) {
        return _buildQuoteCard(_filteredQuotes[index]);
      },
    );
  }

  Widget _buildQuoteCard(QuoteRequest quote) {
    final dateFormat = DateFormat('yyyy.MM.dd HH:mm');
    final hasAnswer = quote.hasAnswer;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: hasAnswer
            ? Border.all(color: Colors.green.withValues(alpha: 0.3), width: 2)
            : Border.all(color: Colors.orange.withValues(alpha: 0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BrokerQuoteDetailPage(
                quote: quote,
                brokerData: widget.brokerData,
              ),
            ),
          ).then((_) => _loadQuotes()); // 답변 후 목록 새로고침
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: hasAnswer
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      hasAnswer ? Icons.check_circle : Icons.schedule,
                      color: hasAnswer ? Colors.green : Colors.orange,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          quote.userName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateFormat.format(quote.requestDate),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: hasAnswer ? Colors.green : Colors.orange,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      hasAnswer ? '답변완료' : '대기중',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 매물 정보
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            quote.propertyAddress ?? '-',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (quote.propertyArea != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.square_foot, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text(
                            '${quote.propertyArea}㎡',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (quote.desiredPrice != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.attach_money, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text(
                            '희망가: ${quote.desiredPrice}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 액션
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BrokerQuoteDetailPage(
                            quote: quote,
                            brokerData: widget.brokerData,
                          ),
                        ),
                      ).then((_) => _loadQuotes());
                    },
                    icon: Icon(
                      hasAnswer ? Icons.edit : Icons.reply,
                      size: 18,
                    ),
                    label: Text(hasAnswer ? '답변 수정' : '답변하기'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.kPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


