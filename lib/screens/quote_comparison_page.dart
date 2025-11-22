import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/models/quote_request.dart';
import 'package:property/widgets/home_logo_button.dart';
import 'package:intl/intl.dart';
import 'package:property/utils/analytics_service.dart';
import 'package:property/utils/analytics_events.dart';
import 'package:property/api_request/firebase_service.dart';

/// 견적 비교 페이지 (MVP 핵심 기능)
class QuoteComparisonPage extends StatefulWidget {
  final List<QuoteRequest> quotes;
  final String? userName; // 로그인 사용자 이름
  final String? userId; // 로그인 사용자 ID

  const QuoteComparisonPage({
    required this.quotes,
    this.userName,
    this.userId,
    super.key,
  });

  @override
  State<QuoteComparisonPage> createState() => _QuoteComparisonPageState();
}

class _QuoteComparisonPageState extends State<QuoteComparisonPage> {
  final FirebaseService _firebaseService = FirebaseService();

  /// 이 화면에서 사용자가 선택 완료한 견적 ID
  String? _selectedQuoteId;
  bool _isAssigning = false;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logEvent(
      AnalyticsEventNames.quoteComparisonPageOpened,
      params: {'quoteCount': widget.quotes.length},
      userId: widget.userId,
      userName: widget.userName,
      stage: FunnelStage.selection,
    );
  }

  /// 판매자가 특정 공인중개사를 최종 선택할 때 호출
  Future<void> _onSelectBroker(QuoteRequest quote) async {
    // 이미 이 화면에서 선택 완료된 견적이면 다시 처리하지 않음
    if (_selectedQuoteId == quote.id) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('이미 이 공인중개사와 진행 중입니다.'),
            backgroundColor: AppColors.kInfo,
          ),
        );
      }
      return;
    }

    // 로그인 여부 확인 (userId 필요)
    if (widget.userId == null || widget.userId!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('로그인 후에 공인중개사를 선택할 수 있습니다.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('공인중개사 선택'),
        content: Text(
          '"${quote.brokerName}" 공인중개사와 계속 진행하시겠습니까?\n\n'
          '확인 버튼을 누르면:\n'
          '• 이 공인중개사에게만 판매자님의 연락처가 전달되고\n'
          '• 이 중개사와의 본격적인 상담이 시작됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.kPrimary,
              foregroundColor: Colors.white,
            ),
            child: const Text('확인'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // 로딩 다이얼로그
    setState(() {
      _isAssigning = true;
    });
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final success = await _firebaseService.assignQuoteToBroker(
        requestId: quote.id,
        userId: widget.userId!,
      );

      if (!mounted) return;

      Navigator.pop(context); // 로딩 닫기

      if (success) {
        setState(() {
          _selectedQuoteId = quote.id;
          _isAssigning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '"${quote.brokerName}" 공인중개사에게 매물 판매 의뢰가 전달되었습니다.\n'
              '곧 중개사에게서 연락이 올 거예요.',
            ),
            backgroundColor: AppColors.kSuccess,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        setState(() {
          _isAssigning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('공인중개사 선택 처리 중 오류가 발생했습니다. 다시 시도해주세요.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // 로딩 닫기
      setState(() {
        _isAssigning = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 가격 문자열에서 숫자 추출
  int? _extractPrice(String? priceStr) {
    if (priceStr == null || priceStr.isEmpty) return null;
    
    // "2억 5천만원", "250000000", "2.5억" 등 다양한 형식 처리
    final cleanStr = priceStr.replaceAll(RegExp(r'[^0-9억천만원\.]'), '');
    
    // "억" 처리
    if (cleanStr.contains('억')) {
      final parts = cleanStr.split('억');
      double? eok = double.tryParse(parts[0].replaceAll(RegExp(r'[^0-9\.]'), ''));
      if (eok == null) return null;
      
      int total = (eok * 100000000).toInt();
      
      // "천만", "만" 처리
      if (parts.length > 1) {
        final remainder = parts[1].replaceAll(RegExp(r'[^0-9]'), '');
        if (remainder.isNotEmpty) {
          final remainderInt = int.tryParse(remainder);
          if (remainderInt != null) {
            // "천만" 또는 "만" 구분
            if (parts[1].contains('천만')) {
              total += remainderInt * 10000000;
            } else if (parts[1].contains('만')) {
              total += remainderInt * 10000;
            } else {
              // 숫자만 있으면 만원 단위로 가정
              total += remainderInt * 10000;
            }
          }
        }
      }
      
      return total;
    }
    
    // 숫자만 있는 경우
    final digits = cleanStr.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits);
  }

  /// 가격 포맷팅
  String _formatPrice(int price) {
    if (price >= 100000000) {
      final eok = price / 100000000;
      if (eok == eok.roundToDouble()) {
        return '${eok.toInt()}억원';
      }
      return '${eok.toStringAsFixed(1)}억원';
    } else if (price >= 10000) {
      final man = price / 10000;
      return '${man.toInt()}만원';
    }
    return '$price원';
  }

  @override
  Widget build(BuildContext context) {
    // 답변 완료된 견적만 필터 (recommendedPrice 또는 minimumPrice가 있는 것)
    final respondedQuotes = widget.quotes.where((q) {
      return (q.recommendedPrice != null && q.recommendedPrice!.isNotEmpty) ||
             (q.minimumPrice != null && q.minimumPrice!.isNotEmpty);
    }).toList();

    if (respondedQuotes.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.kBackground,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.kPrimary,
          elevation: 0.5,
          title: const HomeLogoButton(
            fontSize: 18,
            color: AppColors.kPrimary,
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.compare_arrows,
                size: 80,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 24),
              Text(
                '비교할 견적이 없습니다',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '공인중개사로부터 답변을 받으면\n여기서 견적을 비교할 수 있습니다',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 가격 추출 및 정렬
    final quotePrices = respondedQuotes.map((q) {
      // recommendedPrice 우선, 없으면 minimumPrice
      final priceStr = q.recommendedPrice ?? q.minimumPrice;
      final price = _extractPrice(priceStr);
      return {
        'quote': q,
        'price': price,
        'priceStr': priceStr,
      };
    }).where((item) => item['price'] != null).toList();

    if (quotePrices.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.kBackground,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.kPrimary,
          elevation: 0.5,
          title: const HomeLogoButton(
            fontSize: 18,
            color: AppColors.kPrimary,
          ),
        ),
        body: const Center(
          child: Text('가격 정보가 없는 견적만 있습니다.'),
        ),
      );
    }

    // 가격 정렬
    quotePrices.sort((a, b) {
      final aPrice = a['price'] as int?;
      final bPrice = b['price'] as int?;
      if (aPrice == null && bPrice == null) return 0;
      if (aPrice == null) return 1;
      if (bPrice == null) return -1;
      return aPrice.compareTo(bPrice);
    });

    final prices = quotePrices.map((item) => item['price'] as int).toList();
    final minPrice = prices.first;
    final maxPrice = prices.last;
    final avgPrice = (prices.reduce((a, b) => a + b) / prices.length).round();

    final dateFormat = DateFormat('yyyy.MM.dd');

    return Scaffold(
      backgroundColor: AppColors.kBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.kPrimary,
        elevation: 0.5,
        title: const HomeLogoButton(
          fontSize: 18,
          color: AppColors.kPrimary,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: '견적 비교',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('견적 비교 가이드'),
                  content: const Text(
                    '공인중개사로부터 받은 견적을 한눈에 비교할 수 있습니다.\n\n'
                    '• 최저가: 가장 낮은 견적\n'
                    '• 평균가: 모든 견적의 평균\n'
                    '• 최고가: 가장 높은 견적\n\n'
                    '최저가 견적은 초록색으로 강조되어 표시됩니다.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('확인'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 요약 카드
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppGradients.primaryDiagonal,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.kPrimary.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSummaryItem('최저가', _formatPrice(minPrice), Colors.green[100]!),
                      _buildSummaryItem('평균가', _formatPrice(avgPrice), Colors.white),
                      _buildSummaryItem('최고가', _formatPrice(maxPrice), Colors.red[100]!),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.info_outline, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '${quotePrices.length}개 견적 비교 중',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            const SizedBox(height: 24),

            // 견적 목록
            Text(
              '견적 상세',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),

            const SizedBox(height: 16),

            ...quotePrices.map((item) {
              final quote = item['quote'] as QuoteRequest;
              final isAlreadySelected = quote.isSelectedByUser == true;
              final isSelectedHere = _selectedQuoteId == quote.id;
              final price = item['price'] as int;
              final priceStr = item['priceStr'] as String?;
              final isLowest = price == minPrice;
              final isHighest = price == maxPrice;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: isLowest
                      ? Border.all(color: Colors.green, width: 3)
                      : Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: isLowest
                          ? Colors.green.withValues(alpha: 0.2)
                          : Colors.black.withValues(alpha: 0.06),
                      blurRadius: isLowest ? 12 : 8,
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
                        color: isLowest
                            ? Colors.green.withValues(alpha: 0.1)
                            : isHighest
                                ? Colors.red.withValues(alpha: 0.1)
                                : Colors.grey.withValues(alpha: 0.05),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
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
                                if (quote.answerDate != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '답변일: ${dateFormat.format(quote.answerDate!)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (isLowest)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                '최저가',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          if (isHighest && !isLowest)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                '최고가',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // 가격 정보 + 세부 정보 + 선택 버튼
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isLowest
                                  ? Colors.green.withValues(alpha: 0.05)
                                  : const Color(0xFFF8F9FA),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isLowest
                                    ? Colors.green.withValues(alpha: 0.3)
                                    : Colors.grey.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  '예상 금액',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2C3E50),
                                  ),
                                ),
                                Text(
                                  priceStr ?? _formatPrice(price),
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: isLowest
                                        ? Colors.green[700]
                                        : const Color(0xFF2C3E50),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          if (quote.expectedDuration != null &&
                              quote.expectedDuration!.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _buildInfoRow('예상 거래기간', quote.expectedDuration!),
                          ],

                          if (quote.commissionRate != null &&
                              quote.commissionRate!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _buildInfoRow('수수료율', quote.commissionRate!),
                          ],

                          if (quote.brokerAnswer != null &&
                              quote.brokerAnswer!.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '추가 메시지',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    quote.brokerAnswer!,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF2C3E50),
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: (_isAssigning || isAlreadySelected || isSelectedHere)
                                  ? null
                                  : () => _onSelectBroker(quote),
                              icon: Icon(
                                isAlreadySelected || isSelectedHere
                                    ? Icons.check_circle
                                    : Icons.handshake,
                              ),
                              label: Text(
                                isAlreadySelected || isSelectedHere
                                    ? '이 공인중개사와 진행 중입니다'
                                    : '이 공인중개사와 계속 진행할래요',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isAlreadySelected || isSelectedHere
                                    ? Colors.grey[300]
                                    : AppColors.kPrimary,
                                foregroundColor: isAlreadySelected || isSelectedHere
                                    ? Colors.grey[800]
                                    : Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
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
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: bgColor == Colors.white ? Colors.white : const Color(0xFF2C3E50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF2C3E50),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

