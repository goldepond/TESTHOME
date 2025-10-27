import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/api_request/broker_service.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/models/quote_request.dart';

/// 공인중개사 찾기 페이지
class BrokerListPage extends StatefulWidget {
  final String address;
  final double latitude;
  final double longitude;
  final String userName; // 로그인 사용자 이름

  const BrokerListPage({
    required this.address,
    required this.latitude,
    required this.longitude,
    this.userName = '', // 기본값: 비로그인
    super.key,
  });

  @override
  State<BrokerListPage> createState() => _BrokerListPageState();
}

class _BrokerListPageState extends State<BrokerListPage> {
  List<Broker> brokers = [];
  bool isLoading = true;
  String? error;
  final FirebaseService _firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();
    _searchBrokers();
  }

  /// 공인중개사 검색
  Future<void> _searchBrokers() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final searchResults = await BrokerService.searchNearbyBrokers(
        latitude: widget.latitude,
        longitude: widget.longitude,
        radiusMeters: 1000, // 1km 반경
      );

      if (!mounted) return; // 위젯이 dispose된 경우 setState 호출 방지

      setState(() {
        brokers = searchResults;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return; // 위젯이 dispose된 경우 setState 호출 방지

      setState(() {
        error = '공인중개사 정보를 불러오는 중 오류가 발생했습니다.';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 웹 최적화: 최대 너비 제한
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = screenWidth > 800;
    final maxWidth = isWeb ? 1200.0 : screenWidth;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          // 웹 스타일 헤더
          SliverAppBar(
            expandedHeight: 200,
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
                            Icon(Icons.business, color: Colors.white, size: 40),
                            SizedBox(width: 16),
                            Text(
                              '주변 공인중개사 찾기',
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
                          '선택한 주소 주변의 공인중개사 정보를 확인하세요',
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
                    // 주소 요약 카드 - 웹 스타일
                    Container(
                      padding: const EdgeInsets.all(24),
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
                        border: Border.all(
                          color: Colors.grey.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: const [AppColors.kPrimary, AppColors.kSecondary],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Text(
                                  '검색 기준 주소',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2C3E50),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.kPrimary.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.kPrimary.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.address,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.kPrimary,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.my_location,
                                      size: 16,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '좌표: ${widget.latitude.toStringAsFixed(6)}, ${widget.longitude.toStringAsFixed(6)}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // 공인중개사 목록 헤더 - 웹 스타일
                    if (!isLoading && brokers.isNotEmpty) ...[
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: const [AppColors.kPrimary, AppColors.kSecondary],
                              ),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.business, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  '공인중개사 목록 (총 ${brokers.length}곳)',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Container(
                              height: 2,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.kPrimary.withValues(alpha: 0.3),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],

                    // 로딩 / 에러 / 결과 표시
                    if (isLoading)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(60),
                          child: const CircularProgressIndicator(
                            strokeWidth: 3,
                          ),
                        ),
                      )
                    else if (error != null)
                      _buildErrorCard(error!)
                    else if (brokers.isEmpty)
                        _buildNoResultsCard()
                      else
                      // 웹 그리드 레이아웃
                        _buildBrokerGrid(isWeb),

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

  /// 웹 최적화 그리드 레이아웃
  Widget _buildBrokerGrid(bool isWeb) {
    final crossAxisCount = isWeb ? 2 : 1;
    return LayoutBuilder(
      builder: (context, constraints) {
        const estimatedCardHeight = 450.0; // Measure or estimate actual content height
        final estimatedCardWidth = (constraints.maxWidth - 20) / crossAxisCount;
        final aspect = estimatedCardWidth / estimatedCardHeight;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: aspect,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
          ),
          itemCount: brokers.length,
          itemBuilder: (context, index) => _buildBrokerCard(brokers[index]),
        );
      },
    );
  }
  // FIXME
  // 1. 낮은 해상도에서 Column 이 너무 작아져서 카드가 깨지는 현상
  // 2. 높은 Width 에서 백색 Spacing 이 비대해지는 현상
  /// 공인중개사 카드
  Widget _buildBrokerCard(Broker broker) {
    return Container(
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
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: const [AppColors.kPrimary, AppColors.kSecondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.business,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    broker.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (broker.distance != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      broker.distanceText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 상세 정보 - 웹 스타일
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 주소 정보 그룹
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildBrokerInfo(Icons.location_on, '도로명주소', broker.fullAddress),
                      const SizedBox(height: 12),
                      _buildBrokerInfo(Icons.pin_drop, '지번주소', broker.jibunAddress),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 기타 정보
                _buildBrokerInfo(Icons.badge, '등록번호', broker.registrationNumber),
                if (broker.employeeCount.isNotEmpty && broker.employeeCount != '-' && broker.employeeCount != '0') ...[
                  const SizedBox(height: 12),
                  _buildBrokerInfo(Icons.people, '고용인원', '${broker.employeeCount}명'),
                ],
                if (broker.registrationDate.isNotEmpty && broker.registrationDate != '-') ...[
                  const SizedBox(height: 12),
                  _buildBrokerInfo(Icons.calendar_today, '데이터기준일', broker.registrationDate),
                ],
              ],
            ),
          ),

          // 액션 버튼들 - 웹 스타일
          Container(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Colors.grey.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _findRoute(broker.roadAddress),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.kPrimary,
                        side: const BorderSide(color: AppColors.kPrimary, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.map, size: 20),
                      label: const Text('길찾기', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // 로그인 체크
                        if (widget.userName.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('견적문의는 로그인 후 이용 가능합니다.'),
                              backgroundColor: Colors.orange,
                              duration: Duration(seconds: 2),
                            ),
                          );
                          return;
                        }
                        _requestQuote(broker.name);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.kPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                        shadowColor: AppColors.kPrimary.withValues(alpha: 0.3),
                      ),
                      icon: const Icon(Icons.chat_bubble, size: 20),
                      label: const Text('견적문의', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 공인중개사 정보 행 - 웹 스타일
  Widget _buildBrokerInfo(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.kPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: AppColors.kPrimary),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
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
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  /// 에러 카드 - 웹 스타일
  Widget _buildErrorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.1),
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
                color: Colors.orange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline, color: Colors.orange, size: 48),
            ),
            const SizedBox(height: 20),
            Text(
              '오류 발생',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[700],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// 결과 없음 카드 - 웹 스타일
  Widget _buildNoResultsCard() {
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
              child: const Icon(Icons.search_off, size: 64, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            const Text(
              '공인중개사를 찾을 수 없습니다',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '주변에 등록된 공인중개사가 없습니다.\n검색 반경을 넓혀보세요.',
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

  /// 길찾기
  void _findRoute(String address) {
    // 카카오맵 열기
    // 실제로는 url_launcher 패키지 필요
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('길찾기'),
        content: Text('카카오맵에서 $address로 길찾기를 시작합니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  /// 견적 문의
  void _requestQuote(String brokerName) {
    // 해당 중개사 정보 찾기
    final broker = brokers.firstWhere(
          (b) => b.name == brokerName,
      orElse: () => brokers.first,
    );

    showDialog(
      context: context,
      builder: (context) {
        String message = '';
        return AlertDialog(
          title: Text('$brokerName 견적문의'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '중개사: $brokerName',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              if (broker.roadAddress.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '주소: ${broker.roadAddress}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                autofocus: true,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: '문의 내용을 입력하세요',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => message = value,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (message.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('문의 내용을 입력해주세요')),
                  );
                  return;
                }

                Navigator.pop(context);

                // Firestore에 견적문의 저장
                final quoteRequest = QuoteRequest(
                  id: '', // Firestore가 자동 생성
                  userId: widget.userName,
                  userName: widget.userName,
                  userEmail: '${widget.userName}@example.com', // 임시 이메일
                  brokerName: brokerName,
                  brokerRegistrationNumber: broker.registrationNumber,
                  brokerRoadAddress: broker.roadAddress,
                  brokerJibunAddress: broker.jibunAddress,
                  message: message.trim(),
                  status: 'pending',
                  requestDate: DateTime.now(),
                );

                final requestId = await _firebaseService.saveQuoteRequest(quoteRequest);

                if (requestId != null) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$brokerName에 견적 문의가 전송되었습니다!\n빠른 시일 내에 연락드리겠습니다.'),
                        backgroundColor: AppColors.kSuccess,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                  print('✅ 견적문의 저장 성공: $brokerName - $message');
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('견적 문의 전송에 실패했습니다. 다시 시도해주세요.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                  print('❌ 견적문의 저장 실패: $brokerName - $message');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.kPrimary,
                foregroundColor: Colors.white,
              ),
              child: const Text('전송'),
            ),
          ],
        );
      },
    );
  }
}