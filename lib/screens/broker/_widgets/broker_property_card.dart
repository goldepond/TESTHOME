import 'package:flutter/material.dart';
import '../../../constants/apple_design_system.dart';
import '../../../models/mls_property.dart';
import '../../../utils/formatters.dart';
import '../../../utils/commission_calculator.dart';

/// 브로커 대시보드 탐색 탭의 매물 카드
///
/// [property]: 표시할 매물
/// [brokerId]: 현재 중개사 ID (참여 여부 판단에 사용)
/// [isVerifiedBroker]: 인증된 중개사 여부 (제안 버튼 활성화)
/// [onTap]: 카드 탭 시 (상세 보기)
/// [onPropose]: '조건 제안' 버튼 탭 시
/// [onProposalModify]: '제안 수정' 버튼 탭 시
class BrokerPropertyCard extends StatelessWidget {
  const BrokerPropertyCard({
    required this.property,
    required this.brokerId,
    required this.isVerifiedBroker,
    required this.onTap,
    required this.onPropose,
    required this.onProposalModify,
    super.key,
  });

  final MLSProperty property;
  final String brokerId;
  final bool isVerifiedBroker;
  final VoidCallback onTap;
  final VoidCallback onPropose;
  final VoidCallback onProposalModify;

  @override
  Widget build(BuildContext context) {
    final isMyCompeting = property.brokerResponses.containsKey(brokerId) &&
        property.brokerResponses[brokerId]!.hasViewed;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppleColors.systemBackground,
        borderRadius: BorderRadius.circular(12),
        border: isMyCompeting
            ? Border.all(color: AppleColors.systemGreen, width: 1.5)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 상단: 상태 + 검증 + 지역
                Row(
                  children: [
                    _buildStatusBadge(property.status),
                    if (property.verificationStatus == VerificationStatus.adminApproved) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppleColors.systemTeal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified, size: 12, color: AppleColors.systemTeal),
                            const SizedBox(width: 2),
                            Text(
                              '검증됨',
                              style: AppleTypography.caption2.copyWith(
                                color: AppleColors.systemTeal,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (isMyCompeting) ...[
                      const SizedBox(width: 6),
                      _buildBadge('참여중', AppleColors.systemGreen),
                    ],
                    const Spacer(),
                    Text(
                      property.region,
                      style: AppleTypography.caption1.copyWith(color: AppleColors.tertiaryLabel),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 주소
                Text(
                  property.address,
                  style: AppleTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppleColors.label,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // 가격
                Text(
                  PriceFormatter.format(property.desiredPrice),
                  style: AppleTypography.title3.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppleColors.systemBlue,
                  ),
                ),
                const SizedBox(height: 6),

                // 법정 수수료 정보
                Builder(
                  builder: (context) {
                    final price = property.desiredPrice.toInt();
                    final maxRate = CommissionCalculator.getLegalMaxRate(
                      transactionPrice: price,
                      transactionType: CommissionCalculator.transactionSale,
                    );
                    final maxCommission = CommissionCalculator.calculateCommission(
                      transactionPrice: price,
                      commissionRate: maxRate,
                    );
                    return Row(
                      children: [
                        const Icon(Icons.percent, size: 12, color: AppleColors.tertiaryLabel),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '법정 최고 $maxRate% (${CommissionCalculator.formatCommission(maxCommission)})',
                            style: AppleTypography.caption2.copyWith(
                              color: AppleColors.tertiaryLabel,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),

                // 하단: 판매자 + 등록일 + 버튼
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 14, color: AppleColors.tertiaryLabel),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        property.userName.isNotEmpty ? property.userName : '매도인',
                        style: AppleTypography.caption1.copyWith(color: AppleColors.secondaryLabel),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.access_time, size: 14, color: AppleColors.tertiaryLabel),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        DateTimeFormatter.timeAgo(property.createdAt),
                        style: AppleTypography.caption1.copyWith(color: AppleColors.tertiaryLabel),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Spacer(),
                    if (!isMyCompeting)
                      _buildPrimaryButton('조건 제안', onPropose)
                    else
                      _buildSecondaryButton('제안 수정', onProposalModify),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(PropertyStatus status) {
    final (label, color) = switch (status) {
      PropertyStatus.active => ('신규', AppleColors.systemGreen),
      PropertyStatus.inquiry => ('문의중', AppleColors.systemBlue),
      PropertyStatus.underOffer => ('협상중', AppleColors.systemOrange),
      PropertyStatus.depositTaken => ('가계약', AppleColors.systemPurple),
      PropertyStatus.sold => ('완료', AppleColors.secondaryLabel),
      _ => ('', AppleColors.secondaryLabel),
    };
    if (label.isEmpty) return const SizedBox.shrink();
    return _buildBadge(label, color);
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: AppleTypography.caption2.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildPrimaryButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: AppleColors.systemBlue,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: AppleTypography.subheadline.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: AppleTypography.subheadline.copyWith(
          color: AppleColors.systemBlue,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
