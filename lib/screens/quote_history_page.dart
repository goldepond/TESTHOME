import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/models/quote_request.dart';
import 'package:property/widgets/home_logo_button.dart';
import 'package:property/screens/quote_comparison_page.dart';
import 'package:property/api_request/vworld_service.dart';
import 'package:property/screens/broker_list_page.dart';
import 'package:property/widgets/retry_view.dart';
import 'package:intl/intl.dart';
import 'package:property/utils/analytics_service.dart';
import 'package:property/utils/analytics_events.dart';
import 'package:property/screens/login_page.dart';
import 'package:property/screens/broker/broker_detail_page.dart';
import 'package:property/api_request/broker_service.dart';
import 'package:property/models/broker_review.dart';

/// 내집관리 (견적 현황) 페이지
class HouseManagementPage extends StatefulWidget {
  final String userName;
  final String? userId; // userId 추가

  const HouseManagementPage({
    required this.userName,
    this.userId, // userId 추가
    super.key,
  });

  @override
  State<HouseManagementPage> createState() => _HouseManagementPageState();
}

class _HouseManagementPageState extends State<HouseManagementPage> {
  final FirebaseService _firebaseService = FirebaseService();
  List<QuoteRequest> quotes = [];
  List<QuoteRequest> filteredQuotes = [];
  bool isLoading = true;
  String? error;
  
  // 필터 상태
  String selectedStatus = 'all'; // all, pending, completed
  
  // 그룹화된 견적 데이터 (주소별)
  Map<String, List<QuoteRequest>> _groupedQuotes = {};

  static const Map<String, List<String>> _statusGroups = {
    'waiting': ['pending'],
    'progress': ['contacted', 'answered'],
    'completed': ['completed'],
    'cancelled': ['cancelled'],
  };

  static const List<Map<String, String>> _statusFilterDefinitions = [
    {'value': 'all', 'label': '전체'},
    {'value': 'waiting', 'label': '미응답'},
    {'value': 'progress', 'label': '진행중'},
    {'value': 'completed', 'label': '완료'},
    {'value': 'cancelled', 'label': '취소됨'},
  ];
  
  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logEvent(
      AnalyticsEventNames.quoteHistoryOpened,
      userId: widget.userId,
      userName: widget.userName,
      stage: FunnelStage.quoteResponse,
    );
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
          _applyFilter(source: 'auto_sync');
        }
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        error = '내집관리 데이터를 불러오는 중 오류가 발생했습니다.';
        isLoading = false;
      });
    }
  }
  
  /// 필터 적용
  void _applyFilter({String source = 'auto'}) {
    final List<QuoteRequest> nextFiltered;
    if (selectedStatus == 'all') {
      nextFiltered = List<QuoteRequest>.from(quotes);
    } else {
      final group = _statusGroups[selectedStatus];
      if (group != null) {
        nextFiltered = quotes.where((q) => group.contains(q.status)).toList();
      } else {
        nextFiltered = quotes.where((q) => q.status == selectedStatus).toList();
      }
    }

    final Map<String, List<QuoteRequest>> grouped = {};
    for (final quote in nextFiltered) {
      final address = quote.propertyAddress ?? '주소없음';
      grouped.putIfAbsent(address, () => []).add(quote);
    }
    grouped.forEach((key, value) {
      value.sort((a, b) => b.requestDate.compareTo(a.requestDate));
    });

    setState(() {
      filteredQuotes = nextFiltered;
      _groupedQuotes = grouped;
    });

    final appliedStatuses = selectedStatus == 'all'
        ? null
        : (_statusGroups[selectedStatus] ?? [selectedStatus]);

    AnalyticsService.instance.logEvent(
      AnalyticsEventNames.quoteHistoryFilterApplied,
      params: {
        'status': selectedStatus,
        'source': source,
        'totalQuotes': quotes.length,
        'filteredQuotes': nextFiltered.length,
        'appliedStatuses': appliedStatuses,
      },
      userId: widget.userId,
      userName: widget.userName,
      stage: FunnelStage.quoteResponse,
    );
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

  /// 견적 카드에서 공인중개사 상세 페이지로 이동
  void _openBrokerDetailFromQuote(QuoteRequest quote) {
    if (quote.brokerRegistrationNumber == null ||
        quote.brokerRegistrationNumber!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('중개사 등록번호 정보가 없어 상세 페이지를 열 수 없습니다.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final broker = Broker(
      name: quote.brokerName,
      roadAddress: quote.brokerRoadAddress ?? '',
      jibunAddress: quote.brokerJibunAddress ?? '',
      registrationNumber: quote.brokerRegistrationNumber!,
      etcAddress: '',
      employeeCount: '-',
      registrationDate: '',
      latitude: null,
      longitude: null,
      distance: null,
      systemRegNo: null,
      ownerName: null,
      businessName: null,
      phoneNumber: null,
      businessStatus: null,
      seoulAddress: null,
      district: null,
      legalDong: null,
      sggCode: null,
      stdgCode: null,
      lotnoSe: null,
      mno: null,
      sno: null,
      roadCode: null,
      bldg: null,
      bmno: null,
      bsno: null,
      penaltyStartDate: null,
      penaltyEndDate: null,
      inqCount: null,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BrokerDetailPage(
          broker: broker,
          currentUserId: widget.userId,
          currentUserName: widget.userName,
          quoteRequestId: quote.id,
          quoteStatus: quote.status,
        ),
      ),
    );
  }

  /// 후기 작성 / 수정 바텀시트
  // ignore: unused_element
  Future<void> _openReviewSheet(QuoteRequest quote) async {
    if (widget.userId == null || widget.userId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('로그인 후 후기를 작성할 수 있습니다.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (quote.status != 'completed') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('상담이 완료된 견적에만 후기를 남길 수 있습니다.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (quote.brokerRegistrationNumber == null ||
        quote.brokerRegistrationNumber!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('중개사 정보가 없어 후기를 작성할 수 없습니다.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final existingReview = await _firebaseService.getUserReviewForQuote(
      userId: widget.userId!,
      brokerRegistrationNumber: quote.brokerRegistrationNumber!,
      quoteRequestId: quote.id,
    );

    bool recommend = existingReview?.recommend ?? true;
    final commentController =
        TextEditingController(text: existingReview?.comment ?? '');

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final bottom = MediaQuery.of(context).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${quote.brokerName} 후기',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('추천 여부', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('추천'),
                        selected: recommend == true,
                        onSelected: (_) {
                          setState(() {
                            recommend = true;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('비추천'),
                        selected: recommend == false,
                        onSelected: (_) {
                          setState(() {
                            recommend = false;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: commentController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: '상담을 받으면서 좋았던 점, 아쉬웠던 점을 자유롭게 작성해주세요.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final trimmed =
                            commentController.text.trim().isEmpty
                                ? null
                                : commentController.text.trim();

                        final now = DateTime.now();
                        final review = BrokerReview(
                          id: existingReview?.id ?? '',
                          brokerRegistrationNumber:
                              quote.brokerRegistrationNumber!,
                          userId: widget.userId!,
                          userName: widget.userName,
                          quoteRequestId: quote.id,
                          rating: recommend ? 5 : 1,
                          recommend: recommend,
                          comment: trimmed,
                          createdAt: existingReview?.createdAt ?? now,
                          updatedAt: now,
                        );

                        final savedId =
                            await _firebaseService.saveBrokerReview(review);

                        if (!mounted) return;

                        Navigator.pop(context);

                        if (savedId != null) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text('후기가 저장되었습니다.'),
                              backgroundColor: AppColors.kSuccess,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text('후기 저장에 실패했습니다.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.kPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        existingReview == null ? '후기 저장' : '후기 수정하기',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _navigateToLoginAndRefresh() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
    if (!mounted) return;
    if (result != null) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
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
      }
    }
  }
  
  /// 견적문의 전체 상세 정보 표시
  void _showFullQuoteDetails(QuoteRequest quote) {
    final dateFormat = DateFormat('yyyy.MM.dd HH:mm');
    AnalyticsService.instance.logEvent(
      AnalyticsEventNames.quoteDetailViewed,
      params: {
        'quoteId': quote.id,
        'status': quote.status,
        'brokerName': quote.brokerName,
        'hasAnswer': quote.hasAnswer,
      },
      userId: widget.userId,
      userName: widget.userName,
      stage: FunnelStage.quoteResponse,
    );
    
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
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _openBrokerDetailFromQuote(quote);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                      child: const Text(
                        '중개사 소개 / 후기 보기',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
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
    final structuredQuotes = quotes.where(_hasStructuredData).toList();
    
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
            title: const HomeLogoButton(fontSize: 18),
            centerTitle: false,
            actions: [
              // 견적 비교 버튼 (MVP 핵심)
              IconButton(
                icon: const Icon(Icons.compare_arrows, color: Colors.white),
                tooltip: '견적 비교',
                onPressed: () {
                  // 답변 완료된 견적만 필터
              AnalyticsService.instance.logEvent(
                AnalyticsEventNames.quoteComparisonShortcutTapped,
                params: {
                  'totalQuotes': quotes.length,
                },
                userId: widget.userId,
                userName: widget.userName,
                stage: FunnelStage.selection,
              );
                  final respondedQuotes = quotes.where((q) {
                    return (q.recommendedPrice != null && q.recommendedPrice!.isNotEmpty) ||
                           (q.minimumPrice != null && q.minimumPrice!.isNotEmpty);
                  }).toList();
                  
                  if (respondedQuotes.isEmpty) {
                AnalyticsService.instance.logEvent(
                  AnalyticsEventNames.quoteComparisonShortcutEmpty,
                  params: {
                    'totalQuotes': quotes.length,
                  },
                  userId: widget.userId,
                  userName: widget.userName,
                  stage: FunnelStage.selection,
                );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('비교할 견적이 없습니다. 공인중개사로부터 답변을 받으면 비교할 수 있습니다.'),
                        backgroundColor: Colors.orange,
                        duration: Duration(seconds: 3),
                      ),
                    );
                    return;
                  }
                  
              AnalyticsService.instance.logEvent(
                AnalyticsEventNames.quoteComparisonOpened,
                params: {
                  'totalQuotes': quotes.length,
                  'respondedQuotes': respondedQuotes.length,
                },
                userId: widget.userId,
                userName: widget.userName,
                stage: FunnelStage.selection,
              );

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
                              '내집관리',
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
                          '내집관리 현황을 확인하세요',
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
                          children: _statusFilterDefinitions.map((definition) {
                            final value = definition['value']!;
                            final label = definition['label']!;
                            final count = value == 'all'
                                ? quotes.length
                                : quotes.where((q) {
                                    final group = _statusGroups[value];
                                    if (group == null) {
                                      return q.status == value;
                                    }
                                    return group.contains(q.status);
                                  }).length;
                            return _buildFilterChip(label, value, count);
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                if (!isLoading && quotes.isNotEmpty) ...[
                  _buildStatusOverviewCard(),
                  const SizedBox(height: 16),
                ],
                if (!isLoading && (widget.userId == null || widget.userId!.isEmpty)) ...[
                      _buildGuestBanner(),
                      const SizedBox(height: 16),
                    ],
                    if (!isLoading && structuredQuotes.isNotEmpty) ...[
                      _buildComparisonTable(structuredQuotes),
                      const SizedBox(height: 24),
                    ],
                    
                    // 로딩 / 에러 / 결과 표시
                    if (isLoading)
                      _buildSkeletonList()
                    else if (error != null)
                      RetryView(
                        message: error!,
                        onRetry: _loadQuotes,
                      )
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
  
  bool _hasStructuredData(QuoteRequest quote) {
    return (quote.recommendedPrice?.isNotEmpty ?? false) ||
        (quote.minimumPrice?.isNotEmpty ?? false) ||
        (quote.commissionRate?.isNotEmpty ?? false) ||
        (quote.expectedDuration?.isNotEmpty ?? false) ||
        (quote.promotionMethod?.isNotEmpty ?? false) ||
        (quote.recentCases?.isNotEmpty ?? false);
  }

  Widget _buildSkeletonList() {
    return Column(
      children: List.generate(3, (index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 18,
                  width: 140,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 14,
                  width: 220,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildGuestBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Colors.blue, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '로그인하시면 상담 현황이 자동으로 저장되고, 알림도 받을 수 있어요.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '지금은 게스트 모드입니다. 손쉽게 로그인하고 알림/비교 기능을 끝까지 활용해보세요.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.kTextSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      AnalyticsService.instance.logEvent(
                        AnalyticsEventNames.guestLoginCtaTapped,
                        params: {'source': 'quote_history_banner'},
                        userId: widget.userId,
                        userName: widget.userName,
                        stage: FunnelStage.selection,
                      );
                      await _navigateToLoginAndRefresh();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.kPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.login, size: 18),
                    label: const Text(
                      '로그인하고 이어서 보기',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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

  Widget _buildStatusOverviewCard() {
    final total = quotes.length;
    final waitingStatuses = _statusGroups['waiting'] ?? const [];
    final progressStatuses = _statusGroups['progress'] ?? const [];
    final completedStatuses = _statusGroups['completed'] ?? const [];

    final waiting = quotes.where((q) => waitingStatuses.contains(q.status)).length;
    final inProgress = quotes.where((q) => progressStatuses.contains(q.status)).length;
    final completed = quotes.where((q) => completedStatuses.contains(q.status)).length;
    final responded = quotes.where(_hasStructuredData).length;

    return Container(
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '진행 현황 요약',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.kTextPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _StatusMetricTile(label: '총 요청', count: total, color: Colors.indigo),
                _StatusMetricTile(label: '답변 대기', count: waiting, color: Colors.orange),
                _StatusMetricTile(label: '진행 중', count: inProgress, color: Colors.blue),
                _StatusMetricTile(label: '완료', count: completed, color: Colors.green),
                _StatusMetricTile(label: '비교 가능', count: responded, color: Colors.purple),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonTable(List<QuoteRequest> data) {
    final displayed = data.length > 6 ? data.sublist(0, 6) : data;
    return Card(
      elevation: 3,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📊 주요 제안 비교',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.kTextPrimary,
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStateProperty.resolveWith(
                  (states) => const Color(0xFFF3E8FF),
                ),
                headingTextStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.kTextPrimary,
                ),
                columnSpacing: 32,
                horizontalMargin: 12,
                columns: const [
                  DataColumn(label: Text('중개사')),
                  DataColumn(label: Text('권장가')),
                  DataColumn(label: Text('수수료')),
                ],
                rows: displayed.map((quote) {
                  String format(String? value) =>
                      value == null || value.isEmpty ? '-' : value;
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          quote.brokerName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          format(quote.recommendedPrice),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      DataCell(
                        Text(
                          format(quote.commissionRate),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.kPrimary,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
            if (data.length > displayed.length)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  '※ 최신 제안 6건만 표시됩니다. 전체 내용은 각 카드에서 확인하세요.',
                  style: TextStyle(fontSize: 11, color: AppColors.kTextSecondary),
                ),
              ),
          ],
        ),
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
    // 상태별 대표 색상 정의
    Color statusColor;
    switch (value) {
      case 'waiting':
        statusColor = Colors.orange;
        break;
      case 'progress':
        statusColor = Colors.blue;
        break;
      case 'completed':
        statusColor = Colors.green;
        break;
      case 'cancelled':
        statusColor = Colors.redAccent;
        break;
      default:
        statusColor = AppColors.kPrimary;
    }
    return Tooltip(
      message: '$label ($count건)',
      child: FilterChip(
        labelPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? statusColor.withValues(alpha: 0.25)
                    : Colors.grey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? statusColor : Colors.grey[700],
                ),
              ),
            ),
          ],
        ),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            selectedStatus = value;
            _applyFilter(source: 'user');
          });
        },
        selectedColor: statusColor.withValues(alpha: 0.15),
        checkmarkColor: statusColor,
        backgroundColor: Colors.grey[100],
        labelStyle: TextStyle(
          color: isSelected ? statusColor : Colors.grey[700],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        materialTapTargetSize: MaterialTapTargetSize.padded,
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
                
                const SizedBox(height: 16),
                // 1줄째: 중개사 상세 / 견적 상세 (둘 다 큰 버튼)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openBrokerDetailFromQuote(quote),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.kPrimary,
                          side: const BorderSide(color: AppColors.kPrimary, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.person_search, size: 18),
                        label: const Text(
                          '중개사 소개 / 후기 보기',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showFullQuoteDetails(quote),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.kPrimary,
                          side: const BorderSide(color: AppColors.kPrimary, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.visibility_outlined, size: 18),
                        label: const Text(
                          '상세 보기',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // 2줄째: 비교 화면 / 중개사 재연락
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final hasResponded = _hasStructuredData(quote);
                      if (hasResponded) {
                        final respondedQuotes = quotes.where(_hasStructuredData).toList();
                        AnalyticsService.instance.logEvent(
                          AnalyticsEventNames.quoteComparisonOpened,
                          params: {
                            'source': 'card_cta',
                            'brokerName': quote.brokerName,
                            'respondedQuotes': respondedQuotes.length,
                          },
                          userId: widget.userId,
                          userName: widget.userName,
                          stage: FunnelStage.selection,
                        );
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => QuoteComparisonPage(
                              quotes: respondedQuotes,
                              userName: widget.userName,
                              userId: widget.userId,
                            ),
                          ),
                        );
                      } else {
                        _recontactBroker(quote);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _hasStructuredData(quote) ? AppColors.kSecondary : AppColors.kPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: Icon(
                      _hasStructuredData(quote) ? Icons.compare_outlined : Icons.phone_forwarded,
                      size: 18,
                    ),
                    label: Text(
                      _hasStructuredData(quote) ? '비교 화면으로 이동' : '중개사 재연락',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _deleteQuote(quote.id),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red[700],
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text(
                      '내역 삭제',
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
    final hasResponded = _hasStructuredData(quote);
    final respondedQuotes = quotes.where(_hasStructuredData).toList();
    
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
                // 중개사 소개 / 후기 보기 링크
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _openBrokerDetailFromQuote(quote),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: AppColors.kPrimary,
                    ),
                    icon: const Icon(Icons.person_search, size: 16),
                    label: const Text(
                      '중개사 소개 / 후기 보기',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

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
                
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showFullQuoteDetails(quote),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.kPrimary,
                          side: const BorderSide(color: AppColors.kPrimary, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.visibility_outlined, size: 18),
                        label: const Text('상세 보기', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: hasResponded && respondedQuotes.isNotEmpty
                            ? () {
                                AnalyticsService.instance.logEvent(
                                  AnalyticsEventNames.quoteComparisonOpened,
                                  params: {
                                    'source': 'card_cta',
                                    'brokerName': quote.brokerName,
                                    'respondedQuotes': respondedQuotes.length,
                                  },
                                  userId: widget.userId,
                                  userName: widget.userName,
                                  stage: FunnelStage.selection,
                                );
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => QuoteComparisonPage(
                                      quotes: respondedQuotes,
                                      userName: widget.userName,
                                      userId: widget.userId,
                                    ),
                                  ),
                                );
                              }
                            : () => _recontactBroker(quote),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: hasResponded ? AppColors.kSecondary : AppColors.kPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: Icon(
                          hasResponded ? Icons.compare_outlined : Icons.phone_forwarded,
                          size: 18,
                        ),
                        label: Text(
                          hasResponded ? '비교 화면으로 이동' : '중개사 재연락',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // 카드에서는 후기 작성 버튼 제거 (상세 페이지에서 통합 처리)
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _deleteQuote(quote.id),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red[700],
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('내역 삭제', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ],
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
              '관리 중인 견적이 없습니다',
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

class _StatusMetricTile extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatusMetricTile({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.9),
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$count건',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

