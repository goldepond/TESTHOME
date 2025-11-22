import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/models/quote_request.dart';
import 'package:property/constants/status_constants.dart';
import 'package:property/widgets/home_logo_button.dart';
import 'package:intl/intl.dart';
import '../main_page.dart';
import 'broker_quote_detail_page.dart';
import '../login_page.dart';
import 'broker_settings_page.dart';
import '../notification/notification_page.dart';

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
  String _selectedStatus = 'all'; // all, pending, completed, selected
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
      return _quotes.where((q) => QuoteLifecycleStatus.fromQuote(q) == QuoteLifecycleStatus.requested).toList();
    } else if (_selectedStatus == 'completed') {
      return _quotes.where((q) => QuoteLifecycleStatus.fromQuote(q) == QuoteLifecycleStatus.comparing).toList();
    } else if (_selectedStatus == 'selected') {
      return _quotes.where((q) => QuoteLifecycleStatus.fromQuote(q) == QuoteLifecycleStatus.selected).toList();
    } else {
      return _quotes;
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
        title: const HomeLogoButton(
          fontSize: 18,
          color: AppColors.kPrimary,
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.kPrimary,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: AppColors.kPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: '알림',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NotificationPage(userId: widget.brokerData['uid'] ?? widget.brokerId),
                ),
              );
            },
          ),
          TextButton.icon(
            onPressed: () {
              // 일반 메인 페이지로 이동 (동일 계정)
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => MainPage(
                      userId: user.uid,
                      userName: widget.brokerName,
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.home_outlined, size: 18, color: AppColors.kPrimary),
            label: const Text(
              '일반 화면',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.kPrimary,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '로그아웃',
            onPressed: _logout,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFFE0E0E0), width: 0.5),
                bottom: BorderSide(color: Color(0xFFE0E0E0), width: 0.5),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.kPrimary,
              indicatorWeight: 3,
              labelColor: AppColors.kPrimary,
              unselectedLabelColor: Color(0xFF9E9E9E),
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
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 견적문의 탭
          Column(
            children: [
              // 헤더 (일반 화면 히어로 배너와 동일 그라데이션 사용)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                decoration: const BoxDecoration(
                  gradient: AppGradients.primaryDiagonal,
                ),
                child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.business,
                                color: Colors.white,
                                size: 28,
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
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.brokerName,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _buildStatCard(
                              '전체',
                              _quotes.length.toString(),
                              AppColors.kPrimary,
                              'all',
                            ),
                            const SizedBox(width: 12),
                            _buildStatCard(
                              '대기/수집중',
                              _quotes
                                  .where((q) =>
                                      QuoteLifecycleStatus.fromQuote(q) ==
                                      QuoteLifecycleStatus.requested)
                                  .length
                                  .toString(),
                              Colors.orange,
                              'pending',
                            ),
                            const SizedBox(width: 12),
                            _buildStatCard(
                              '비교중',
                              _quotes
                                  .where((q) =>
                                      QuoteLifecycleStatus.fromQuote(q) ==
                                      QuoteLifecycleStatus.comparing)
                                  .length
                                  .toString(),
                              Colors.blueAccent,
                              'completed',
                            ),
                            const SizedBox(width: 12),
                            _buildStatCard(
                              '선택됨',
                              _quotes
                                  .where((q) =>
                                      QuoteLifecycleStatus.fromQuote(q) ==
                                      QuoteLifecycleStatus.selected)
                                  .length
                                  .toString(),
                              Colors.greenAccent,
                              'selected',
                            ),
                          ],
                        ),
                      ],
                    ),
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

  Widget _buildStatCard(String label, String value, Color color, String statusValue) {
    final isSelected = _selectedStatus == statusValue;
    
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedStatus = statusValue;
          });
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            // 히어로 배경 위에 떠 있는 흰색 카드 느낌으로 통일
            // 선택된 경우 배경색을 약간 강조
            color: isSelected 
                ? Colors.white 
                : Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              // 선택된 경우 테두리를 해당 상태 색상으로 강조
              color: isSelected 
                  ? color 
                  : Colors.white.withValues(alpha: 0.6),
              width: isSelected ? 2.5 : 1,
            ),
            boxShadow: isSelected 
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ] 
                : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? color : const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
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
                  if (!hasAnswer && quote.status != 'cancelled') ...[
                    OutlinedButton.icon(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('이번 건 진행 안함'),
                            content: const Text(
                              '이 견적 문의는 이번에는 진행하지 않으시겠습니까?\n'
                              '판매자 화면에서는 \'취소됨\' 상태로 표시됩니다.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('취소'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('진행 안함'),
                              ),
                            ],
                          ),
                        );

                        if (confirmed == true) {
                          final success = await _firebaseService
                              .updateQuoteRequestStatus(quote.id, 'cancelled');
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                success
                                    ? '이번 건은 진행하지 않도록 표시했어요.'
                                    : '처리 중 오류가 발생했습니다. 다시 시도해주세요.',
                              ),
                              backgroundColor:
                                  success ? AppColors.kInfo : Colors.red,
                            ),
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      icon: const Icon(Icons.block, size: 16),
                      label: const Text(
                        '진행 안함',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  ElevatedButton.icon(
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
                    label: Text(
                      hasAnswer ? '답변 수정' : '답변하기',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.kPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 2,
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

