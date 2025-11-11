import 'package:flutter/material.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/models/quote_request.dart';
import 'package:property/api_request/apt_info_service.dart';
import 'package:property/api_request/vworld_service.dart';
import 'package:property/api_request/address_service.dart';
import 'package:flutter/services.dart';

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
  final TextEditingController _recommendedPriceController = TextEditingController();
  final TextEditingController _commissionRateController = TextEditingController();
  final TextEditingController _expectedDurationController = TextEditingController();
  final TextEditingController _promotionMethodController = TextEditingController();
  final TextEditingController _recentCasesController = TextEditingController();
  
  Map<String, dynamic>? _inquiryData;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _hasExistingAnswer = false; // 기존 답변 존재 여부 (수정 가능하도록 변경)
  
  // API 정보
  Map<String, dynamic>? _vworldCoordinates;
  Map<String, dynamic>? _aptInfo;
  Map<String, String>? _fullAddrAPIData;
  bool _isLoadingApiInfo = false;
  String? _apiError;

  @override
  void initState() {
    super.initState();
    _loadInquiry();
  }
  
  /// 주소 검색 API 정보 로드
  Future<void> _loadApiInfo(String? address) async {
    if (address == null || address.isEmpty) {
      return;
    }
    
    setState(() {
      _isLoadingApiInfo = true;
      _apiError = null;
    });
    
    try {
      final addressService = AddressService();
      
      // 1. 주소 상세 정보 조회 (AddressService)
      try {
        final addrResult = await addressService.searchRoadAddress(address, page: 1);
        if (addrResult.fullData.isNotEmpty) {
          _fullAddrAPIData = addrResult.fullData.first;
        }
      } catch (e) {
        // 주소 상세 정보 조회 실패는 무시
      }
      
      // 2. VWorld 좌표 정보 조회
      try {
        final landResult = await VWorldService.getLandInfoFromAddress(address);
        if (landResult != null && landResult['coordinates'] != null) {
          _vworldCoordinates = landResult['coordinates'];
        }
      } catch (e) {
        // VWorld 좌표 조회 실패는 무시
      }
      
      // 3. 아파트 정보 조회 (단지코드 추출 시도)
      try {
        final kaptCode = await AptInfoService.extractKaptCodeFromAddressAsync(
          address,
          fullAddrAPIData: _fullAddrAPIData,
        );
        if (kaptCode != null && kaptCode.isNotEmpty) {
          final aptInfoResult = await AptInfoService.getAptBasisInfo(kaptCode);
          if (aptInfoResult != null && aptInfoResult.isNotEmpty) {
            _aptInfo = aptInfoResult;
          }
        }
      } catch (e) {
        // 아파트 정보 조회 실패는 무시
      }
      
      if (mounted) {
        setState(() {
          _isLoadingApiInfo = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingApiInfo = false;
          _apiError = 'API 정보를 불러오는 중 오류가 발생했습니다.';
        });
      }
    }
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
        // 이미 답변이 있으면 표시하고 수정 가능하도록
        if (data['brokerAnswer'] != null && data['brokerAnswer'].toString().isNotEmpty) {
          _hasExistingAnswer = true;
          _answerController.text = data['brokerAnswer'];
        }
        // 구조화 필드 프리필
        _recommendedPriceController.text = data['recommendedPrice']?.toString() ?? '';
        _commissionRateController.text = data['commissionRate']?.toString() ?? '';
        _expectedDurationController.text = data['expectedDuration']?.toString() ?? '';
        _promotionMethodController.text = data['promotionMethod']?.toString() ?? '';
        _recentCasesController.text = data['recentCases']?.toString() ?? '';
      });
      
      // 주소가 있으면 API 정보 로드
      final propertyAddress = data['propertyAddress'];
      if (propertyAddress != null && propertyAddress.toString().isNotEmpty) {
        _loadApiInfo(propertyAddress.toString());
      }
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
    final hasAnyField = _answerController.text.trim().isNotEmpty ||
        _recommendedPriceController.text.trim().isNotEmpty ||
        _commissionRateController.text.trim().isNotEmpty ||
        _expectedDurationController.text.trim().isNotEmpty ||
        _promotionMethodController.text.trim().isNotEmpty ||
        _recentCasesController.text.trim().isNotEmpty;
    if (!hasAnyField) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('최소 한 개 이상의 답변 항목을 입력해주세요.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final success = await _firebaseService.updateQuoteRequestDetailedAnswer(
        requestId: _inquiryData!['id'],
        recommendedPrice: _recommendedPriceController.text.trim(),
        commissionRate: _commissionRateController.text.trim(),
        expectedDuration: _expectedDurationController.text.trim(),
        promotionMethod: _promotionMethodController.text.trim(),
        recentCases: _recentCasesController.text.trim(),
        brokerAnswer: _answerController.text.trim(),
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        
        if (success) {
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(_hasExistingAnswer ? '✅ 답변 수정 완료' : '✅ 답변 전송 완료'),
              content: Text(
                _hasExistingAnswer 
                  ? '답변이 성공적으로 수정되었습니다.\n'
                    '문의자에게 수정된 답변이 즉시 전달됩니다.'
                  : '답변이 성공적으로 전송되었습니다.\n'
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
          
          // 기존 답변 상태로 변경 및 데이터 다시 로드
          setState(() => _hasExistingAnswer = true);
          await _loadInquiry();
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
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('문의 정보를 불러오는 중...'),
              ],
            ),
          ),
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
                children: const [
                  Icon(Icons.info_outline, color: AppColors.kPrimary, size: 24),
                  SizedBox(width: 12),
                  Expanded(
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
            
            // 매물 정보 참조 (API 정보) - 문의 정보 바로 아래에 배치하여 먼저 확인 가능하도록
            // 매물 주소가 있으면 항상 표시 (로딩 중이거나 데이터가 없어도 섹션은 표시)
            Builder(
              builder: (context) {
                final address = quoteRequest.propertyAddress;
                if (address != null && address.toString().trim().isNotEmpty) {
                  return Column(
                    children: [
                      _buildReferenceInfoSection(address.toString()),
                      const SizedBox(height: 24),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            
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
            
            // 특이사항 (입력된 경우에만 표시) - 답변 작성 바로 위에 배치하여 참고하기 쉽게
            if (quoteRequest.hasTenant != null || 
                quoteRequest.desiredPrice != null || 
                quoteRequest.targetPeriod != null || 
                (quoteRequest.specialNotes != null && quoteRequest.specialNotes!.isNotEmpty))
              ...[
                const SizedBox(height: 24),
                _buildSection(
                  title: '📝 특이사항 (답변 작성시 참고하세요)',
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.3), width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (quoteRequest.hasTenant != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 100,
                                    child: Text(
                                      '세입자 여부',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      quoteRequest.hasTenant! ? '있음' : '없음',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF2C3E50),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (quoteRequest.desiredPrice != null && quoteRequest.desiredPrice!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 100,
                                    child: Text(
                                      '희망가',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      quoteRequest.desiredPrice!,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF2C3E50),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (quoteRequest.targetPeriod != null && quoteRequest.targetPeriod!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 100,
                                    child: Text(
                                      '목표기간',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      quoteRequest.targetPeriod!,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF2C3E50),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (quoteRequest.specialNotes != null && quoteRequest.specialNotes!.isNotEmpty) ...[
                            if (quoteRequest.hasTenant != null || 
                                quoteRequest.desiredPrice != null || 
                                quoteRequest.targetPeriod != null)
                              const Divider(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 100,
                                  child: Text(
                                    '특이사항',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    quoteRequest.specialNotes!,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF2C3E50),
                                      height: 1.6,
                                    ),
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
              ],
            
            const SizedBox(height: 24),
            
            // 답변 작성 (수정 가능)
            _buildSection(
              title: _hasExistingAnswer ? '✏️ 답변 수정 (재전송 가능)' : '✏️ 답변 작성',
              children: [
                // 구조화 입력 필드
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      _buildLabeledField(
                        '예상 매도가',
                        _recommendedPriceController,
                        hint: '예: 10.8',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        suffix: '억',
                      ),
                      const SizedBox(height: 12),
                      _buildLabeledField(
                        '수수료율',
                        _commissionRateController,
                        hint: '예: 0.6',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        suffix: '%',
                      ),
                      const SizedBox(height: 12),
                      _buildLabeledField('예상 기간', _expectedDurationController, hint: '예: 2~3개월'),
                      const SizedBox(height: 12),
                      _buildLabeledField('판매 전략 요약', _promotionMethodController, hint: '예: 빠른 오픈, 네이버/당근/현수막 병행'),
                      const SizedBox(height: 12),
                      _buildLabeledField('유사 거래 사례', _recentCasesController, hint: '예: 인근 A아파트 84㎡, 10.7억(23.12)'),
                    ],
                  ),
                ),
                if (quoteRequest.hasTenant != null || 
                    quoteRequest.desiredPrice != null || 
                    quoteRequest.targetPeriod != null || 
                    (quoteRequest.specialNotes != null && quoteRequest.specialNotes!.isNotEmpty))
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.kPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.kPrimary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.info_outline, color: AppColors.kPrimary, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '위 특이사항을 참고하여 답변을 작성해주세요.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.kPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_hasExistingAnswer)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.edit, color: Colors.blue, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '기존 답변을 수정한 후 다시 전송할 수 있습니다.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                TextField(
                  controller: _answerController,
                  maxLines: 8,
                  enabled: true, // 항상 수정 가능
                  decoration: InputDecoration(
                    hintText: '답변을 입력해주세요...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // 전송/재전송 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitAnswer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _hasExistingAnswer ? Colors.blue : AppColors.kPrimary,
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
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_hasExistingAnswer ? Icons.refresh : Icons.send, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            _hasExistingAnswer ? '수정 후 재전송' : '전송하기',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
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
  
  Widget _buildLabeledField(String label, TextEditingController controller, {String? hint, TextInputType? keyboardType, String? suffix}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.kTextPrimary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: keyboardType == const TextInputType.numberWithOptions(decimal: true)
              ? <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9\.\%]')),
                ]
              : null,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            suffixText: suffix,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }
  
  /// 참조 정보 섹션 (매물정보 API 데이터)
  Widget _buildReferenceInfoSection(String address) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3), width: 2),
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
              Icon(Icons.info_outline, color: Colors.blue[700], size: 24),
              const SizedBox(width: 12),
              const Text(
                '매물 정보 참조',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '주소 검색 시 API로 불러온 정보입니다. 답변 작성 시 참고하세요.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 20),
          
          if (_isLoadingApiInfo)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_apiError != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.orange[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _apiError!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange[900],
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            // 주소 상세 정보 (Juso API)
            if (_fullAddrAPIData != null && _fullAddrAPIData!.isNotEmpty) ...[
              _buildInfoSection(
                '주소 상세 정보',
                Icons.location_on,
                [
                  if (_fullAddrAPIData!['roadAddr'] != null && _fullAddrAPIData!['roadAddr']!.isNotEmpty)
                    _buildInfoRow('도로명주소', _fullAddrAPIData!['roadAddr']!),
                  if (_fullAddrAPIData!['jibunAddr'] != null && _fullAddrAPIData!['jibunAddr']!.isNotEmpty)
                    _buildInfoRow('지번주소', _fullAddrAPIData!['jibunAddr']!),
                  if (_fullAddrAPIData!['bdNm'] != null && _fullAddrAPIData!['bdNm']!.isNotEmpty)
                    _buildInfoRow('건물명', _fullAddrAPIData!['bdNm']!),
                  if (_fullAddrAPIData!['siNm'] != null && _fullAddrAPIData!['siNm']!.isNotEmpty)
                    _buildInfoRow('시도', _fullAddrAPIData!['siNm']!),
                  if (_fullAddrAPIData!['sggNm'] != null && _fullAddrAPIData!['sggNm']!.isNotEmpty)
                    _buildInfoRow('시군구', _fullAddrAPIData!['sggNm']!),
                  if (_fullAddrAPIData!['emdNm'] != null && _fullAddrAPIData!['emdNm']!.isNotEmpty)
                    _buildInfoRow('읍면동', _fullAddrAPIData!['emdNm']!),
                  if (_fullAddrAPIData!['rn'] != null && _fullAddrAPIData!['rn']!.isNotEmpty)
                    _buildInfoRow('도로명', _fullAddrAPIData!['rn']!),
                  if (_fullAddrAPIData!['buldMgtNo'] != null && _fullAddrAPIData!['buldMgtNo']!.isNotEmpty)
                    _buildInfoRow('건물관리번호', _fullAddrAPIData!['buldMgtNo']!),
                  if (_fullAddrAPIData!['roadAddrNo'] != null && _fullAddrAPIData!['roadAddrNo']!.isNotEmpty)
                    _buildInfoRow('건물번호', _fullAddrAPIData!['roadAddrNo']!),
                ],
              ),
              const SizedBox(height: 16),
            ],
            
            // VWorld 좌표 정보
            if (_vworldCoordinates != null && _vworldCoordinates!.isNotEmpty) ...[
              _buildInfoSection(
                '좌표 정보',
                Icons.my_location,
                [
                  if (_vworldCoordinates!['x'] != null)
                    _buildInfoRow('경도', _vworldCoordinates!['x'].toString()),
                  if (_vworldCoordinates!['y'] != null)
                    _buildInfoRow('위도', _vworldCoordinates!['y'].toString()),
                  if (_vworldCoordinates!['level'] != null)
                    _buildInfoRow('정확도 레벨', _vworldCoordinates!['level'].toString()),
                ],
              ),
              const SizedBox(height: 16),
            ],
            
            // 아파트 단지 정보
            if (_aptInfo != null && _aptInfo!.isNotEmpty) ...[
              _buildInfoSection(
                '아파트 단지 정보',
                Icons.apartment,
                [
                  if (_aptInfo!['kaptCode'] != null && _aptInfo!['kaptCode'].toString().isNotEmpty)
                    _buildInfoRow('단지코드', _aptInfo!['kaptCode'].toString()),
                  if (_aptInfo!['kaptName'] != null && _aptInfo!['kaptName'].toString().isNotEmpty)
                    _buildInfoRow('단지명', _aptInfo!['kaptName'].toString()),
                  if (_aptInfo!['codeStr'] != null && _aptInfo!['codeStr'].toString().isNotEmpty)
                    _buildInfoRow('건물구조', _aptInfo!['codeStr'].toString()),
                  if (_aptInfo!['kaptdPcnt'] != null && _aptInfo!['kaptdPcnt'].toString().isNotEmpty)
                    _buildInfoRow('주차대수(지상)', '${_aptInfo!['kaptdPcnt']}대'),
                  if (_aptInfo!['kaptdPcntu'] != null && _aptInfo!['kaptdPcntu'].toString().isNotEmpty)
                    _buildInfoRow('주차대수(지하)', '${_aptInfo!['kaptdPcntu']}대'),
                  if (_aptInfo!['kaptdEcnt'] != null && _aptInfo!['kaptdEcnt'].toString().isNotEmpty)
                    _buildInfoRow('승강기대수', '${_aptInfo!['kaptdEcnt']}대'),
                  if (_aptInfo!['kaptMgrCnt'] != null && _aptInfo!['kaptMgrCnt'].toString().isNotEmpty)
                    _buildInfoRow('관리사무소 수', '${_aptInfo!['kaptMgrCnt']}개'),
                  if (_aptInfo!['kaptCcompany'] != null && _aptInfo!['kaptCcompany'].toString().isNotEmpty)
                    _buildInfoRow('관리업체', _aptInfo!['kaptCcompany'].toString()),
                  if (_aptInfo!['codeMgr'] != null && _aptInfo!['codeMgr'].toString().isNotEmpty)
                    _buildInfoRow('관리방식', _aptInfo!['codeMgr'].toString()),
                  if (_aptInfo!['kaptdCccnt'] != null && _aptInfo!['kaptdCccnt'].toString().isNotEmpty)
                    _buildInfoRow('CCTV대수', '${_aptInfo!['kaptdCccnt']}대'),
                  if (_aptInfo!['codeSec'] != null && _aptInfo!['codeSec'].toString().isNotEmpty)
                    _buildInfoRow('경비관리방식', _aptInfo!['codeSec'].toString()),
                  if (_aptInfo!['kaptdScnt'] != null && _aptInfo!['kaptdScnt'].toString().isNotEmpty)
                    _buildInfoRow('경비인력 수', '${_aptInfo!['kaptdScnt']}명'),
                  if (_aptInfo!['kaptdSecCom'] != null && _aptInfo!['kaptdSecCom'].toString().isNotEmpty)
                    _buildInfoRow('경비업체', _aptInfo!['kaptdSecCom'].toString()),
                  if (_aptInfo!['codeClean'] != null && _aptInfo!['codeClean'].toString().isNotEmpty)
                    _buildInfoRow('청소관리방식', _aptInfo!['codeClean'].toString()),
                  if (_aptInfo!['kaptdClcnt'] != null && _aptInfo!['kaptdClcnt'].toString().isNotEmpty)
                    _buildInfoRow('청소인력 수', '${_aptInfo!['kaptdClcnt']}명'),
                  if (_aptInfo!['codeGarbage'] != null && _aptInfo!['codeGarbage'].toString().isNotEmpty)
                    _buildInfoRow('음식물처리방법', _aptInfo!['codeGarbage'].toString()),
                  if (_aptInfo!['codeDisinf'] != null && _aptInfo!['codeDisinf'].toString().isNotEmpty)
                    _buildInfoRow('소독관리방식', _aptInfo!['codeDisinf'].toString()),
                  if (_aptInfo!['kaptdDcnt'] != null && _aptInfo!['kaptdDcnt'].toString().isNotEmpty)
                    _buildInfoRow('소독인력 수', '${_aptInfo!['kaptdDcnt']}명'),
                  if (_aptInfo!['codeEcon'] != null && _aptInfo!['codeEcon'].toString().isNotEmpty)
                    _buildInfoRow('세대전기계약방식', _aptInfo!['codeEcon'].toString()),
                  if (_aptInfo!['kaptdEcapa'] != null && _aptInfo!['kaptdEcapa'].toString().isNotEmpty)
                    _buildInfoRow('수전용량', _aptInfo!['kaptdEcapa'].toString()),
                  if (_aptInfo!['codeFalarm'] != null && _aptInfo!['codeFalarm'].toString().isNotEmpty)
                    _buildInfoRow('화재수신반방식', _aptInfo!['codeFalarm'].toString()),
                  if (_aptInfo!['codeWsupply'] != null && _aptInfo!['codeWsupply'].toString().isNotEmpty)
                    _buildInfoRow('급수방식', _aptInfo!['codeWsupply'].toString()),
                  if (_aptInfo!['codeElev'] != null && _aptInfo!['codeElev'].toString().isNotEmpty)
                    _buildInfoRow('승강기관리형태', _aptInfo!['codeElev'].toString()),
                  if (_aptInfo!['codeNet'] != null && _aptInfo!['codeNet'].toString().isNotEmpty)
                    _buildInfoRow('주차관제/홈네트워크', _aptInfo!['codeNet'].toString()),
                  if (_aptInfo!['welfareFacility'] != null && _aptInfo!['welfareFacility'].toString().isNotEmpty)
                    _buildInfoRow('부대/복리시설', _aptInfo!['welfareFacility'].toString()),
                  if (_aptInfo!['convenientFacility'] != null && _aptInfo!['convenientFacility'].toString().isNotEmpty)
                    _buildInfoRow('편의시설', _aptInfo!['convenientFacility'].toString()),
                  if (_aptInfo!['kaptdWtimebus'] != null && _aptInfo!['kaptdWtimebus'].toString().isNotEmpty)
                    _buildInfoRow('버스정류장 거리', _aptInfo!['kaptdWtimebus'].toString()),
                  if (_aptInfo!['subwayLine'] != null && _aptInfo!['subwayLine'].toString().isNotEmpty)
                    _buildInfoRow('지하철 노선', _aptInfo!['subwayLine'].toString()),
                  if (_aptInfo!['subwayStation'] != null && _aptInfo!['subwayStation'].toString().isNotEmpty)
                    _buildInfoRow('지하철역', _aptInfo!['subwayStation'].toString()),
                  if (_aptInfo!['kaptdWtimesub'] != null && _aptInfo!['kaptdWtimesub'].toString().isNotEmpty)
                    _buildInfoRow('지하철역 거리', _aptInfo!['kaptdWtimesub'].toString()),
                ],
              ),
            ],
            
            // 정보가 하나도 없는 경우 (로딩이 완료된 후에만 표시)
            if (!_isLoadingApiInfo &&
                (_fullAddrAPIData == null || _fullAddrAPIData!.isEmpty) &&
                (_vworldCoordinates == null || _vworldCoordinates!.isEmpty) &&
                (_aptInfo == null || _aptInfo!.isEmpty))
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'API 정보를 불러올 수 없습니다.\n주소 정보를 확인해주세요.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
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
  
  Widget _buildInfoSection(String title, IconData icon, List<Widget> children) {
    if (children.isEmpty) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[900],
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
}

