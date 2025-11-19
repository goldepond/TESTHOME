import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:property/api_request/broker_service.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/models/broker_review.dart';
import 'package:url_launcher/url_launcher.dart';

/// 공인중개사 상세 소개 / 후기 페이지
///
/// - 공인중개사 찾기 페이지 카드에서 진입
/// - 내집관리(견적 이력) 카드에서 진입
/// - 매물 정보는 표시하지 않고, 중개사 정보와 후기만 표시
class BrokerDetailPage extends StatelessWidget {
  final Broker broker;
  final String? currentUserId;
  final String? currentUserName;
  final String? quoteRequestId;  // 내집관리에서 들어온 경우, 어떤 견적인지
  final String? quoteStatus;     // 견적 상태 (completed 에서만 후기 허용)

  const BrokerDetailPage({
    super.key,
    required this.broker,
    this.currentUserId,
    this.currentUserName,
    this.quoteRequestId,
    this.quoteStatus,
  });

  @override
  Widget build(BuildContext context) {
    final firebaseService = FirebaseService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('공인중개사 정보'),
        backgroundColor: AppColors.kPrimary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<BrokerReview>>(
        stream: firebaseService.getBrokerReviews(broker.registrationNumber),
        builder: (context, snapshot) {
          final reviews = snapshot.data ?? <BrokerReview>[];

          final recommendCount = reviews.where((r) => r.recommend).length;
          final notRecommendCount = reviews.where((r) => !r.recommend).length;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderCard(
                  reviewCount: reviews.length,
                  recommendCount: recommendCount,
                  notRecommendCount: notRecommendCount,
                ),
                const SizedBox(height: 16),
                _buildInfoCard(),
                const SizedBox(height: 16),
                _buildActionsRow(context),
                const SizedBox(height: 16),
                if (_canWriteReview)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _openReviewSheet(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.kPrimary,
                        side: const BorderSide(color: AppColors.kPrimary, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.rate_review_outlined, size: 18),
                      label: const Text(
                        '이 중개사에 후기 남기기 / 수정하기',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                _buildReviewSection(reviews),
              ],
            ),
          );
        },
      ),
    );
  }

  bool get _canWriteReview {
    return currentUserId != null &&
        currentUserId!.isNotEmpty &&
        quoteRequestId != null &&
        quoteRequestId!.isNotEmpty &&
        quoteStatus == 'completed';
  }

  /// 상단 요약 카드 (이름 / 대표자 / 등록번호 / 추천·비추천)
  Widget _buildHeaderCard({
    required int reviewCount,
    required int recommendCount,
    required int notRecommendCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.kSecondary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            broker.name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          if (broker.ownerName != null && broker.ownerName!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '대표: ${broker.ownerName}',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.badge, color: Colors.white.withValues(alpha: 0.9), size: 16),
              const SizedBox(width: 6),
              Text(
                '등록번호: ${broker.registrationNumber}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (reviewCount > 0) ...[
            Text(
              '추천 $recommendCount · 비추천 $notRecommendCount',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else ...[
            Text(
              '아직 등록된 후기가 없습니다',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 공인중개사 기본 정보 카드 (주소 / 전화 / 영업상태 / 행정처분)
  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow(Icons.location_on, '도로명주소', broker.roadAddress),
          const SizedBox(height: 8),
          _infoRow(Icons.pin_drop, '지번주소', broker.jibunAddress),
          if (broker.phoneNumber != null && broker.phoneNumber!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _infoRow(Icons.phone, '전화번호', broker.phoneNumber!),
          ],
          if (broker.businessStatus != null && broker.businessStatus!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _infoRow(Icons.store, '영업상태', broker.businessStatus!),
          ],
          if ((broker.penaltyStartDate != null && broker.penaltyStartDate!.isNotEmpty) ||
              (broker.penaltyEndDate != null && broker.penaltyEndDate!.isNotEmpty)) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Colors.orange[700], size: 18),
                      const SizedBox(width: 6),
                      Text(
                        '행정처분 이력',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.orange[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (broker.penaltyStartDate != null &&
                      broker.penaltyStartDate!.isNotEmpty)
                    _smallInfoRow('처분 시작일', broker.penaltyStartDate!),
                  if (broker.penaltyEndDate != null &&
                      broker.penaltyEndDate!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _smallInfoRow('처분 종료일', broker.penaltyEndDate!),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.kPrimary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF2C3E50),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _smallInfoRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF2C3E50),
            ),
          ),
        ),
      ],
    );
  }

  /// 길찾기 / 전화하기 액션 버튼
  Widget _buildActionsRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _openMap(broker.roadAddress),
            icon: const Icon(Icons.map, size: 18),
            label: const Text('길찾기'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: broker.phoneNumber == null || broker.phoneNumber!.isEmpty
                ? null
                : () => _callBroker(broker.phoneNumber!),
            icon: const Icon(Icons.phone, size: 18),
            label: const Text('전화하기'),
          ),
        ),
      ],
    );
  }

  /// 후기 리스트
  Widget _buildReviewSection(List<BrokerReview> reviews) {
    if (reviews.isEmpty) {
      return const Text(
        '아직 등록된 후기가 없습니다.\n내집관리 > 견적 이력에서 상담이 끝난 중개사에게 후기를 남겨보세요.',
        style: TextStyle(fontSize: 13, color: Colors.grey),
      );
    }

    final dateFormat = DateFormat('yyyy.MM.dd');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '후기',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...reviews.map((r) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      r.recommend ? Icons.thumb_up_alt_outlined : Icons.thumb_down_alt_outlined,
                      size: 16,
                      color: r.recommend ? Colors.green[700] : Colors.red[700],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      r.recommend ? '추천' : '비추천',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: r.recommend ? Colors.green[700] : Colors.red[700],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      dateFormat.format(r.createdAt),
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
                if (r.comment != null && r.comment!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    r.comment!,
                    style: const TextStyle(fontSize: 13, height: 1.3),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  r.userName,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Future<void> _openMap(String address) async {
    final encoded = Uri.encodeComponent(address);
    final uri = Uri.parse('https://map.naver.com/v5/search/$encoded');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _callBroker(String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  /// 후기 작성 / 수정 바텀시트 (내집관리에서 들어온 경우에만 사용)
  Future<void> _openReviewSheet(BuildContext context) async {
    if (currentUserId == null || currentUserId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('로그인 후 후기를 작성할 수 있습니다.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (quoteRequestId == null || quoteRequestId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이 견적에 대한 정보가 없어 후기를 작성할 수 없습니다.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (quoteStatus != 'completed') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('상담이 완료된 견적에만 후기를 남길 수 있습니다.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final firebaseService = FirebaseService();
    final existingReview = await firebaseService.getUserReviewForQuote(
      userId: currentUserId!,
      brokerRegistrationNumber: broker.registrationNumber,
      quoteRequestId: quoteRequestId!,
    );

    bool recommend = existingReview?.recommend ?? true;
    final commentController =
        TextEditingController(text: existingReview?.comment ?? '');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
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
                    '${broker.name} 후기',
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
                        final trimmed = commentController.text.trim().isEmpty
                            ? null
                            : commentController.text.trim();

                        final now = DateTime.now();
                        final review = BrokerReview(
                          id: existingReview?.id ?? '',
                          brokerRegistrationNumber: broker.registrationNumber,
                          userId: currentUserId!,
                          userName: currentUserName ?? '알 수 없음',
                          quoteRequestId: quoteRequestId!,
                          rating: recommend ? 5 : 1,
                          recommend: recommend,
                          comment: trimmed,
                          createdAt: existingReview?.createdAt ?? now,
                          updatedAt: now,
                        );

                        final savedId =
                            await firebaseService.saveBrokerReview(review);

                        if (!context.mounted) return;

                        Navigator.pop(context);

                        if (savedId != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('후기가 저장되었습니다.'),
                              backgroundColor: AppColors.kSuccess,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
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
}


