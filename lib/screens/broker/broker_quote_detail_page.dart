import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/models/quote_request.dart';
import 'package:property/widgets/home_logo_button.dart';
import 'package:property/api_request/apt_info_service.dart';
import 'package:property/api_request/vworld_service.dart';
import 'package:property/api_request/address_service.dart';
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
  
  // API 정보
  Map<String, dynamic>? _vworldCoordinates;
  Map<String, dynamic>? _aptInfo;
  Map<String, String>? _fullAddrAPIData;
  bool _isLoadingApiInfo = false;
  String? _apiError;

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
    
    // 주소가 있으면 API 정보 로드
    if (widget.quote.propertyAddress != null && widget.quote.propertyAddress!.isNotEmpty) {
      _loadApiInfo();
    }
  }
  
  /// 주소 검색 API 정보 로드
  Future<void> _loadApiInfo() async {
    if (widget.quote.propertyAddress == null || widget.quote.propertyAddress!.isEmpty) {
      return;
    }
    
    setState(() {
      _isLoadingApiInfo = true;
      _apiError = null;
    });
    
    try {
      final address = widget.quote.propertyAddress!;
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
          if (aptInfoResult != null) {
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
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 매물정보 카드 (중개업자 빠른 상담을 위해 명확하게 표시)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withValues(alpha: 0.1),
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
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.home,
                            color: Colors.orange,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            '매물 정보',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // 매물 유형
                    if (widget.quote.propertyType != null && widget.quote.propertyType!.isNotEmpty)
                      _buildPropertyInfoRow(
                        icon: Icons.category,
                        label: '매물 유형',
                        value: widget.quote.propertyType!,
                      ),
                    // 매물 주소 (전체 주소)
                    if (widget.quote.propertyAddress != null && widget.quote.propertyAddress!.isNotEmpty) ...[
                      _buildPropertyInfoRow(
                        icon: Icons.location_on,
                        label: '매물 주소',
                        value: widget.quote.propertyAddress!,
                        isImportant: true,
                      ),
                      // 주소에서 동/호 파싱해서 표시
                      Builder(
                        builder: (context) {
                          // 주소에서 동/호 정보 추출 시도
                          final address = widget.quote.propertyAddress!;
                          
                          // 주소를 공백으로 분리하여 마지막 부분에서 동/호 찾기
                          // 예: "서울특별시 동대문구 답십리로 130 (답십리동, 래미안위브) 제211동 제1506호"
                          final dongHoMatch = RegExp(r'제?\s*(\d+동)\s*제?\s*(\d+호)?', caseSensitive: false).firstMatch(address);
                          String? dong, ho;
                          
                          if (dongHoMatch != null) {
                            dong = dongHoMatch.group(1);
                            ho = dongHoMatch.group(2);
                          } else {
                            // 다른 형식 시도: "211동 1506호"
                            final simpleMatch = RegExp(r'(\d+동)\s*(\d+호)?', caseSensitive: false).firstMatch(address);
                            if (simpleMatch != null) {
                              dong = simpleMatch.group(1);
                              ho = simpleMatch.group(2);
                            }
                          }
                          
                          if (dong != null && dong.isNotEmpty) {
                            return Column(
                              children: [
                                _buildPropertyInfoRow(
                                  icon: Icons.apartment,
                                  label: '동',
                                  value: dong,
                                  isImportant: true,
                                ),
                                if (ho != null && ho.isNotEmpty)
                                  _buildPropertyInfoRow(
                                    icon: Icons.home,
                                    label: '호수',
                                    value: ho,
                                    isImportant: true,
                                  ),
                              ],
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                    // 전용면적
                    if (widget.quote.propertyArea != null && widget.quote.propertyArea!.isNotEmpty)
                      _buildPropertyInfoRow(
                        icon: Icons.square_foot,
                        label: '전용면적',
                        value: '${widget.quote.propertyArea}㎡',
                      ),
                    // 희망가
                    if (widget.quote.desiredPrice != null && widget.quote.desiredPrice!.isNotEmpty)
                      _buildPropertyInfoRow(
                        icon: Icons.attach_money,
                        label: '희망가',
                        value: widget.quote.desiredPrice!,
                        isImportant: true,
                      ),
                    // 목표기간
                    if (widget.quote.targetPeriod != null && widget.quote.targetPeriod!.isNotEmpty)
                      _buildPropertyInfoRow(
                        icon: Icons.calendar_today,
                        label: '목표기간',
                        value: widget.quote.targetPeriod!,
                      ),
                    // 세입자 여부
                    if (widget.quote.hasTenant != null)
                      _buildPropertyInfoRow(
                        icon: Icons.people,
                        label: '세입자 여부',
                        value: widget.quote.hasTenant! ? '있음' : '없음',
                      ),
                    // 특이사항
                    if (widget.quote.specialNotes != null && widget.quote.specialNotes!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.note, size: 18, color: Colors.orange[700]),
                                const SizedBox(width: 8),
                                const Text(
                                  '특이사항',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2C3E50),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.quote.specialNotes!,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[800],
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 참조 정보 섹션 (매물정보 바로 아래에 표시)
              if (widget.quote.propertyAddress != null && widget.quote.propertyAddress!.isNotEmpty)
                _buildReferenceInfoSection(),

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
  
  /// 참조 정보 섹션
  Widget _buildReferenceInfoSection() {
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
            
            // 정보가 하나도 없는 경우
            if ((_fullAddrAPIData == null || _fullAddrAPIData!.isEmpty) &&
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
  
  Widget _buildInfoRow(String label, String value) {
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
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF1A1A1A),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// 매물정보 행 위젯
  Widget _buildPropertyInfoRow({
    required IconData icon,
    required String label,
    required String value,
    bool isImportant = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isImportant 
                  ? Colors.orange.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: isImportant ? Colors.orange[700] : Colors.grey[700],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    color: isImportant ? Colors.orange[900] : const Color(0xFF2C3E50),
                    fontWeight: isImportant ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}



