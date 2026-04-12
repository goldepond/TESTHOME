import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';
import '../../constants/typography.dart';
import '../../models/buyer_inquiry.dart';
import '../../models/mls_property.dart';
import '../../api_request/mls_property_service.dart';
import '../../utils/formatters.dart';
import '../public/public_property_detail_page.dart';
import '../../constants/spacing.dart';
import 'package:property/utils/snackbar_utils.dart';

/// 구매자 문의 현황 페이지
///
/// 구매자가 자신의 문의 상태를 추적하는 화면.
/// 진입: PublicListingsPage 상단 배너
class MyInquiriesPage extends StatefulWidget {
  const MyInquiriesPage({super.key});

  @override
  State<MyInquiriesPage> createState() => _MyInquiriesPageState();
}

class _MyInquiriesPageState extends State<MyInquiriesPage> {
  final _mlsService = MLSPropertyService();
  int _selectedFilterIndex = 0;

  List<BuyerInquiry> _filterInquiries(List<BuyerInquiry> inquiries) {
    if (_selectedFilterIndex == 0) return inquiries;
    if (_selectedFilterIndex == 1) {
      return inquiries
          .where((i) =>
              i.status == BuyerInquiryStatus.pending ||
              i.status == BuyerInquiryStatus.brokerAssigned ||
              i.status == BuyerInquiryStatus.contacted ||
              i.status == BuyerInquiryStatus.visiting)
          .toList();
    }
    return inquiries
        .where((i) =>
            i.status == BuyerInquiryStatus.completed ||
            i.status == BuyerInquiryStatus.cancelled)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AirbnbColors.surface,
      appBar: AppBar(
        title: const Text('내 문의 현황'),
        backgroundColor: AirbnbColors.surface,
        foregroundColor: AirbnbColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: StreamBuilder<List<BuyerInquiry>>(
        stream: _mlsService.getMyBuyerInquiries(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                '데이터를 불러오지 못했습니다.',
                style: AppTypography.body
                    .copyWith(color: AirbnbColors.textSecondary),
              ),
            );
          }

          final inquiries = snapshot.data ?? [];

          if (inquiries.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.inbox_outlined,
                      size: 56, color: AirbnbColors.textLight),
                  const SizedBox(height: AppSpacing.md),
                  Text('아직 문의한 매물이 없습니다',
                      style: AppTypography.body
                          .copyWith(color: AirbnbColors.textSecondary)),
                  const SizedBox(height: AppSpacing.sm),
                  Text('매물 상세에서 "문의하기"를 눌러보세요',
                      style: AppTypography.bodySmall
                          .copyWith(color: AirbnbColors.textLight)),
                ],
              ),
            );
          }

          final filtered = _filterInquiries(inquiries);
          final activeCount = inquiries
              .where((i) =>
                  i.status != BuyerInquiryStatus.completed &&
                  i.status != BuyerInquiryStatus.cancelled)
              .length;
          final doneCount = inquiries.length - activeCount;

          return Column(
            children: [
              // 상태 필터 칩
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    _buildFilterChip(0, '전체', inquiries.length),
                    const SizedBox(width: AppSpacing.sm),
                    _buildFilterChip(1, '진행 중', activeCount),
                    const SizedBox(width: AppSpacing.sm),
                    _buildFilterChip(2, '완료', doneCount),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) =>
                      _buildInquiryCard(filtered[index]),
                ),
              ),
            ],
          );
        },
      ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(int index, String label, int count) {
    final isSelected = _selectedFilterIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilterIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AirbnbColors.primary
              : AirbnbColors.pillSecondary,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Text(
          '$label $count',
          style: AppTypography.bodySmall.copyWith(
            color: isSelected ? AirbnbColors.background : AirbnbColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildInquiryCard(BuyerInquiry inquiry) {
    final statusColor = switch (inquiry.status) {
      BuyerInquiryStatus.pending => AirbnbColors.warning,
      BuyerInquiryStatus.brokerAssigned => AirbnbColors.primary,
      BuyerInquiryStatus.contacted => AirbnbColors.success,
      BuyerInquiryStatus.visiting => AirbnbColors.info,
      BuyerInquiryStatus.completed => AirbnbColors.textSecondary,
      BuyerInquiryStatus.cancelled => AirbnbColors.error,
    };

    return FutureBuilder<MLSProperty?>(
      future: _mlsService.getProperty(inquiry.propertyId),
      builder: (context, propSnap) {
        final property = propSnap.data;

        return GestureDetector(
          onTap: property != null
              ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          PublicPropertyDetailPage(propertyId: property.id),
                    ),
                  )
              : null,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AirbnbColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AirbnbColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 매물 정보 + 상태 배지
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        property?.roadAddress ?? '매물 정보 로딩 중...',
                        style: AppTypography.body
                            .copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        inquiry.status.label,
                        style: AppTypography.caption.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                // 가격
                if (property != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${property.transactionType} ${PriceFormatter.format(property.desiredPrice)}',
                    style: AppTypography.bodySmall
                        .copyWith(color: AirbnbColors.textSecondary),
                  ),
                ],
                // 배정된 중개사
                if (inquiry.assignedBrokerName != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      const Icon(Icons.person_outline,
                          size: 14, color: AirbnbColors.textLight),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '담당 중개사: ${inquiry.assignedBrokerName}',
                        style: AppTypography.bodySmall
                            .copyWith(color: AirbnbColors.textPrimary),
                      ),
                    ],
                  ),
                ],
                // 내 메모
                if (inquiry.buyerMessage != null &&
                    inquiry.buyerMessage!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '메모: ${inquiry.buyerMessage}',
                    style: AppTypography.bodySmall
                        .copyWith(color: AirbnbColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                // 날짜 + 액션
                Row(
                  children: [
                    Text(
                      '문의일: ${inquiry.createdAt.month}/${inquiry.createdAt.day}',
                      style: AppTypography.caption
                          .copyWith(color: AirbnbColors.textLight),
                    ),
                    const Spacer(),
                    if (inquiry.status == BuyerInquiryStatus.pending ||
                        inquiry.status == BuyerInquiryStatus.brokerAssigned)
                      TextButton(
                        onPressed: () => _showCancelDialog(inquiry),
                        style: TextButton.styleFrom(
                          foregroundColor: AirbnbColors.error,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('문의 취소',
                            style: AppTypography.captionLarge),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCancelDialog(BuyerInquiry inquiry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text('문의 취소',
            style: TextStyle(fontWeight: FontWeight.w600)),
        content: const Text('이 매물에 대한 문의를 취소하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('아니요'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _mlsService.cancelBuyerInquiry(inquiry.id);
              if (mounted) {
                AppSnackBar.info(context, '문의가 취소되었습니다');
              }
            },
            style: TextButton.styleFrom(foregroundColor: AirbnbColors.error),
            child: const Text('취소하기'),
          ),
        ],
      ),
    );
  }
}
