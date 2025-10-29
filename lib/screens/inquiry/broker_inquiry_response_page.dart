import 'package:flutter/material.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/models/quote_request.dart';

/// 공인중개사용 문의 답변 페이지
class BrokerInquiryResponsePage extends StatefulWidget {
  final String linkId;

  const BrokerInquiryResponsePage({
    required this.linkId,
    super.key,
  });

  @override
  State<BrokerInquiryResponsePage> createState() => _BrokerInquiryResponsePageState();
}

class _BrokerInquiryResponsePageState extends State<BrokerInquiryResponsePage> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _answerController = TextEditingController();
  
  Map<String, dynamic>? _inquiryData;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _alreadyAnswered = false;

  @override
  void initState() {
    super.initState();
    _loadInquiry();
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _loadInquiry() async {
    setState(() => _isLoading = true);

    try {
      final data = await _firebaseService.getQuoteRequestByLinkId(widget.linkId);
      
      if (data == null) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      setState(() {
        _inquiryData = data;
        _isLoading = false;
        // 이미 답변이 있으면 표시
        if (data['brokerAnswer'] != null && data['brokerAnswer'].toString().isNotEmpty) {
          _alreadyAnswered = true;
          _answerController.text = data['brokerAnswer'];
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('문의 정보를 불러오는데 실패했습니다: $e')),
        );
      }
    }
  }

  Future<void> _submitAnswer() async {
    if (_answerController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('답변을 입력해주세요.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final success = await _firebaseService.updateQuoteRequestAnswer(
        _inquiryData!['id'],
        _answerController.text.trim(),
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        
        if (success) {
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('✅ 답변 전송 완료'),
              content: const Text(
                '답변이 성공적으로 전송되었습니다.\n'
                '문의자에게 답변이 즉시 전달됩니다.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('확인'),
                ),
              ],
            ),
          );
          
          // 이미 답변 상태로 변경
          setState(() => _alreadyAnswered = true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('답변 전송에 실패했습니다. 다시 시도해주세요.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류가 발생했습니다: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_inquiryData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('문의 정보'),
          backgroundColor: AppColors.kPrimary,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text('문의를 찾을 수 없습니다.'),
              SizedBox(height: 8),
              Text(
                '링크가 만료되었거나 잘못된 접근입니다.',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final quoteRequest = QuoteRequest.fromMap(_inquiryData!['id'], _inquiryData!);

    return Scaffold(
      appBar: AppBar(
        title: const Text('문의 답변'),
        backgroundColor: AppColors.kPrimary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 안내 메시지
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.kPrimary.withValues(alpha: 0.1), AppColors.kSecondary.withValues(alpha: 0.1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.kPrimary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.kPrimary, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '문의 내용을 확인하고 답변을 작성해주세요.\n답변은 즉시 문의자에게 전달됩니다.',
                      style: TextStyle(fontSize: 13, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 문의 정보
            _buildSection(
              title: '📌 문의 정보',
              children: [
                _buildInfoRow('문의자', quoteRequest.userName),
                _buildInfoRow('이메일', quoteRequest.userEmail),
                if (quoteRequest.propertyAddress != null)
                  _buildInfoRow('매물 주소', quoteRequest.propertyAddress!),
                if (quoteRequest.propertyArea != null)
                  _buildInfoRow('전용면적', '${quoteRequest.propertyArea}㎡'),
                if (quoteRequest.propertyType != null)
                  _buildInfoRow('매물 유형', quoteRequest.propertyType!),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // 문의 내용
            _buildSection(
              title: '💬 문의 내용',
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.kBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    quoteRequest.message,
                    style: const TextStyle(fontSize: 14, height: 1.6),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // 답변 작성
            _buildSection(
              title: _alreadyAnswered ? '✅ 답변 내용' : '✏️ 답변 작성',
              children: [
                TextField(
                  controller: _answerController,
                  maxLines: 8,
                  enabled: !_alreadyAnswered,
                  decoration: InputDecoration(
                    hintText: '답변을 입력해주세요...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: _alreadyAnswered ? Colors.grey.withValues(alpha: 0.1) : Colors.white,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // 전송 버튼
            if (!_alreadyAnswered)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitAnswer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.kPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          '전송하기',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            
            if (_alreadyAnswered)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.kSuccess.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.kSuccess),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: AppColors.kSuccess),
                    SizedBox(width: 8),
                    Text(
                      '이미 답변이 전송되었습니다.',
                      style: TextStyle(
                        color: AppColors.kSuccess,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.kPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF2C3E50),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

