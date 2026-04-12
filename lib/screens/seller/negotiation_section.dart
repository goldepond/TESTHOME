import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';
import '../../constants/typography.dart';
import '../../models/mls_property.dart';
import '../../utils/formatters.dart';
import '../../constants/spacing.dart';

/// 협상 현황 타임라인 섹션
///
/// 매물 상세 페이지에서 underOffer 이상 상태일 때 표시.
/// NegotiationLog 목록을 타임라인으로 보여주고, 역제안 기능 제공.
class NegotiationSection extends StatelessWidget {
  final MLSProperty property;
  final VoidCallback? onCounterOffer;

  const NegotiationSection({
    required this.property,
    this.onCounterOffer,
    super.key,
  });

  bool _isCounterOffer(NegotiationLog log) => log.id.startsWith('counter_');

  @override
  Widget build(BuildContext context) {
    final negotiations = property.negotiations;
    if (negotiations.isEmpty) return const SizedBox.shrink();

    final latestPrice = negotiations
        .where((n) => n.proposedPrice != null)
        .lastOrNull
        ?.proposedPrice;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AirbnbColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AirbnbColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              const Icon(Icons.handshake_outlined,
                  size: 20, color: AirbnbColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text('협상 현황',
                  style: AppTypography.body
                      .copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('${negotiations.length}건',
                  style: AppTypography.bodySmall
                      .copyWith(color: AirbnbColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          // 가격 비교
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AirbnbColors.pillSecondary,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('희망가',
                          style: AppTypography.caption
                              .copyWith(color: AirbnbColors.textLight)),
                      const SizedBox(height: 2),
                      Text(PriceFormatter.format(property.desiredPrice),
                          style: AppTypography.body
                              .copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward,
                    size: 16, color: AirbnbColors.textLight),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('최신 제안가',
                          style: AppTypography.caption
                              .copyWith(color: AirbnbColors.textLight)),
                      const SizedBox(height: 2),
                      Text(
                        latestPrice != null
                            ? PriceFormatter.format(latestPrice)
                            : '-',
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AirbnbColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // 타임라인
          ...negotiations.reversed.map((log) => _buildTimelineItem(log)),
          // 역제안 버튼
          if (onCounterOffer != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onCounterOffer,
                icon: const Icon(Icons.reply, size: 18),
                label: const Text('역제안하기'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AirbnbColors.primary,
                  side: const BorderSide(color: AirbnbColors.primary),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimelineItem(NegotiationLog log) {
    final isCounter = _isCounterOffer(log);
    final iconColor = isCounter ? AirbnbColors.primary : AirbnbColors.info;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 타임라인 도트
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCounter ? Icons.reply : Icons.gavel,
              size: 14,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 10),
          // 내용
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isCounter ? '매도인 역제안' : log.brokerName,
                      style: AppTypography.bodySmall
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Text(
                      _formatDate(log.createdAt),
                      style: AppTypography.caption
                          .copyWith(color: AirbnbColors.textLight),
                    ),
                  ],
                ),
                if (log.proposedPrice != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '제안가: ${PriceFormatter.format(log.proposedPrice)}',
                    style: AppTypography.bodySmall
                        .copyWith(color: AirbnbColors.textPrimary),
                  ),
                ],
                if (log.proposedMoveInDate != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '입주일: ${log.proposedMoveInDate!.year}.${log.proposedMoveInDate!.month}.${log.proposedMoveInDate!.day}',
                    style: AppTypography.caption
                        .copyWith(color: AirbnbColors.textSecondary),
                  ),
                ],
                if (log.conditions != null &&
                    log.conditions!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '조건: ${log.conditions}',
                    style: AppTypography.caption
                        .copyWith(color: AirbnbColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (log.buyerFeedback != null &&
                    log.buyerFeedback!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AirbnbColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      '매수자 반응: ${log.buyerFeedback}',
                      style: AppTypography.caption.copyWith(
                          color: AirbnbColors.warning,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
