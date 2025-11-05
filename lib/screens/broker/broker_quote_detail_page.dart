import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/models/quote_request.dart';
import 'package:property/widgets/home_logo_button.dart';
import 'package:intl/intl.dart';

/// 공인중개사 견적 상세/답변 페이지
class BrokerQuoteDetailPage extends StatefulWidget {
  final QuoteRequest quote;
  final Map<String, dynamic> brokerData;

  const BrokerQuoteDetailPage({
    required this.quote,
    required this.brokerData,
    super.key,
  });

  @override
  State<BrokerQuoteDetailPage> createState() => _BrokerQuoteDetailPageState();
}

class _BrokerQuoteDetailPageState extends State<BrokerQuoteDetailPage> {
  final _formKey = GlobalKey<FormState>();
  final _recommendedPriceController = TextEditingController();
  final _minimumPriceController = TextEditingController();
  final _expectedDurationController = TextEditingController();
  final _promotionMethodController = TextEditingController();
  final _commissionRateController = TextEditingController();
  final _recentCasesController = TextEditingController();
  final _brokerAnswerController = TextEditingController();

  bool _isSubmitting = false;
  final FirebaseService _firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();
    // 기존 답변 있으면 자동 채우기
    if (widget.quote.recommendedPrice != null) {
      _recommendedPriceController.text = widget.quote.recommendedPrice!;
    }
    if (widget.quote.minimumPrice != null) {
      _minimumPriceController.text = widget.quote.minimumPrice!;
    }
    if (widget.quote.expectedDuration != null) {
      _expectedDurationController.text = widget.quote.expectedDuration!;
    }
    if (widget.quote.promotionMethod != null) {
      _promotionMethodController.text = widget.quote.promotionMethod!;
    }
    if (widget.quote.commissionRate != null) {
      _commissionRateController.text = widget.quote.commissionRate!;
    }
    if (widget.quote.recentCases != null) {
      _recentCasesController.text = widget.quote.recentCases!;
    }
    if (widget.quote.brokerAnswer != null) {
      _brokerAnswerController.text = widget.quote.brokerAnswer!;
    }
  }

  @override
  void dispose() {
    _recommendedPriceController.dispose();
    _minimumPriceController.dispose();
    _expectedDurationController.dispose();
    _promotionMethodController.dispose();
    _commissionRateController.dispose();
    _recentCasesController.dispose();
    _brokerAnswerController.dispose();
    super.dispose();
  }

  Future<void> _submitAnswer() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 최소 하나는 입력해야 함
    final hasAnyInput = _recommendedPriceController.text.trim().isNotEmpty ||
        _minimumPriceController.text.trim().isNotEmpty ||
        _expectedDurationController.text.trim().isNotEmpty ||
        _brokerAnswerController.text.trim().isNotEmpty;

    if (!hasAnyInput) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('최소 하나 이상의 항목을 입력해주세요.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final success = await _firebaseService.updateQuoteRequestDetailedAnswer(
        requestId: widget.quote.id,
        recommendedPrice: _recommendedPriceController.text.trim().isNotEmpty
            ? _recommendedPriceController.text.trim()
            : null,
        minimumPrice: _minimumPriceController.text.trim().isNotEmpty
            ? _minimumPriceController.text.trim()
            : null,
        expectedDuration: _expectedDurationController.text.trim().isNotEmpty
            ? _expectedDurationController.text.trim()
            : null,
        promotionMethod: _promotionMethodController.text.trim().isNotEmpty
            ? _promotionMethodController.text.trim()
            : null,
        commissionRate: _commissionRateController.text.trim().isNotEmpty
            ? _commissionRateController.text.trim()
            : null,
        recentCases: _recentCasesController.text.trim().isNotEmpty
            ? _recentCasesController.text.trim()
            : null,
        brokerAnswer: _brokerAnswerController.text.trim().isNotEmpty
            ? _brokerAnswerController.text.trim()
            : null,
      );

      setState(() {
        _isSubmitting = false;
      });

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 답변이 성공적으로 전송되었습니다!'),
            backgroundColor: AppColors.kSuccess,
          ),
        );
        Navigator.pop(context, true); // 성공 반환
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('답변 전송에 실패했습니다. 다시 시도해주세요.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy.MM.dd HH:mm');

    return Scaffold(
      backgroundColor: AppColors.kBackground,
      appBar: AppBar(
        title: const HomeLogoButton(fontSize: 18),
        backgroundColor: AppColors.kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 요청 정보 카드
              Container(
                padding: const EdgeInsets.all(20),
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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.kPrimary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.person,
                            color: AppColors.kPrimary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '요청자 정보',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2C3E50),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.quote.userName,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          dateFormat.format(widget.quote.requestDate),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 8),
                              Text(
                                widget.quote.propertyAddress ?? '-',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2C3E50),
                                ),
                              ),
                            ],
                          ),
                          if (widget.quote.propertyArea != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.square_foot, size: 16, color: Colors.grey[600]),
                                const SizedBox(width: 8),
                                Text(
                                  '${widget.quote.propertyArea}㎡',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (widget.quote.desiredPrice != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.attach_money, size: 16, color: Colors.grey[600]),
                                const SizedBox(width: 8),
                                Text(
                                  '희망가: ${widget.quote.desiredPrice}',
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
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 답변 입력 섹션
              Container(
                padding: const EdgeInsets.all(20),
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
                    Row(
                      children: [
                        Icon(Icons.reply, color: AppColors.kPrimary, size: 24),
                        const SizedBox(width: 12),
                        const Text(
                          '중개 제안 작성',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '판매자에게 제안할 내용을 입력해주세요',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildTextField(
                      label: '권장 매도가',
                      controller: _recommendedPriceController,
                      hint: '예: 11억 5천만원',
                      icon: Icons.attach_money,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: '최저수락가',
                      controller: _minimumPriceController,
                      hint: '예: 11억',
                      icon: Icons.money_off,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: '예상 거래기간',
                      controller: _expectedDurationController,
                      hint: '예: 2~3개월',
                      icon: Icons.calendar_today,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: '홍보 방법',
                      controller: _promotionMethodController,
                      hint: '예: 온라인+오프라인 동시',
                      icon: Icons.campaign,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: '수수료 제안율',
                      controller: _commissionRateController,
                      hint: '예: 0.5%',
                      icon: Icons.percent,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: '최근 유사 거래 사례',
                      controller: _recentCasesController,
                      hint: '예: 근처 아파트 84㎡ 11.2억 거래...',
                      icon: Icons.history,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: '추가 메시지',
                      controller: _brokerAnswerController,
                      hint: '판매자에게 전달할 추가 메시지를 입력하세요',
                      icon: Icons.note,
                      maxLines: 4,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // 제출 버튼
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitAnswer,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.send, size: 24),
                  label: Text(
                    _isSubmitting ? '전송 중...' : '답변 전송하기',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.kPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey.withValues(alpha: 0.05),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: maxLines > 1 ? 16 : 14,
            ),
          ),
          maxLines: maxLines,
        ),
      ],
    );
  }
}



