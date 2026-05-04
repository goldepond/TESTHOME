import 'package:flutter/material.dart';
import 'package:property/api_request/priority_grant_service.dart';
import 'package:property/constants/grant_messages.dart';
import 'package:property/models/priority_grant.dart';
import 'package:property/widgets/priority_grant_badge.dart';
import 'package:property/widgets/release_tier_badge.dart';
import 'package:property/widgets/revoke_own_grant_confirm_dialog.dart';
import '../../../constants/app_constants.dart';
import '../../../constants/spacing.dart';
import '../../../constants/typography.dart';
import '../../../models/mls_property.dart';
import '../../../utils/formatters.dart';
import '../../../utils/commission_calculator.dart';
import '../../../utils/snackbar_utils.dart';

/// 브로커 대시보드 탐색 탭의 매물 카드
///
/// [property]: 표시할 매물
/// [brokerId]: 현재 중개사 ID (참여 여부 판단에 사용)
/// [isVerifiedBroker]: 인증된 중개사 여부 (제안 버튼 활성화)
/// [onTap]: 카드 탭 시 (상세 보기)
/// [onPropose]: '조건 제안' 버튼 탭 시
/// [onProposalModify]: '제안 수정' 버튼 탭 시
/// [currentBrokerUid]: 현재 로그인한 중개사의 Firebase Auth uid.
///   null이면 우선권 뱃지·받기 버튼이 모두 숨겨진다(기존 호출자 호환성).
/// [onTakeProperty]: '이 매물 받기' 버튼 탭 시. null이면 버튼이 숨겨진다.
class BrokerPropertyCard extends StatelessWidget {
  const BrokerPropertyCard({
    required this.property,
    required this.brokerId,
    required this.isVerifiedBroker,
    required this.onTap,
    required this.onPropose,
    required this.onProposalModify,
    super.key,
    this.currentBrokerUid,
    this.onTakeProperty,
  });

  final MLSProperty property;
  final String brokerId;
  final bool isVerifiedBroker;
  final VoidCallback onTap;
  final VoidCallback onPropose;
  final VoidCallback onProposalModify;
  final String? currentBrokerUid;
  final Future<void> Function()? onTakeProperty;

  @override
  Widget build(BuildContext context) {
    final isMyCompeting = property.brokerResponses.containsKey(brokerId) &&
        property.brokerResponses[brokerId]!.hasViewed;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AirbnbColors.background,
        borderRadius: BorderRadius.circular(12),
        border: isMyCompeting
            ? Border.all(color: AirbnbColors.green, width: 1.5)
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
                // 우선권 뱃지 (currentBrokerUid가 있을 때만 표시)
                if (currentBrokerUid != null) ...[
                  _buildPriorityBadge(),
                  const SizedBox(height: AppSpacing.sm),
                ],
                // Task 07 — 단독 지정 배지 + 비참여 안내.
                if (property.listingMode == 'exclusive') ...[
                  _buildExclusiveBadge(),
                  const SizedBox(height: AppSpacing.sm),
                ],
                // 상단: 상태 + 검증 + 지역 (+ Problem 004 갭 2 — 본인 grant 보유 시 ⋮ 메뉴)
                Row(
                  children: [
                    _buildStatusBadge(property.status),
                    if (property.verificationStatus == VerificationStatus.adminApproved) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AirbnbColors.teal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified, size: 12, color: AirbnbColors.teal),
                            const SizedBox(width: 2),
                            Text(
                              '검증됨',
                              style: AppTypography.caption.copyWith(
                                color: AirbnbColors.teal,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (isMyCompeting) ...[
                      const SizedBox(width: 6),
                      _buildBadge('참여중', AirbnbColors.green),
                    ],
                    // 단계(tier) 뱃지 — exclusive면 '단독 매물', 그 외 tier 라벨.
                    if (property.listingMode == 'exclusive' ||
                        (property.releaseTier != null &&
                            property.releaseTier!.isNotEmpty)) ...[
                      const SizedBox(width: 6),
                      ReleaseTierBadge(
                        tier: property.releaseTier,
                        listingMode: property.listingMode,
                      ),
                    ],
                    const Spacer(),
                    Text(
                      property.region,
                      style: AppTypography.caption.copyWith(color: AirbnbColors.textLight),
                    ),
                    // Problem 004 갭 2 — 본인 명의 active grant 보유 시에만 ⋮ 메뉴 노출.
                    // 본인 grant 부재 / 만료 grant / currentBrokerUid null 일 때 메뉴 자체 비노출
                    // → 80세 테스트 §1.4 (의사결정 ≤2개) 자동 통과.
                    if (currentBrokerUid != null)
                      _buildOverflowMenu(),
                  ],
                ),
                const SizedBox(height: 12),

                // 주소
                Text(
                  property.address,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AirbnbColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // 가격
                Text(
                  PriceFormatter.format(property.desiredPrice),
                  style: AppTypography.h3.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AirbnbColors.primary,
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
                        const Icon(Icons.percent, size: 12, color: AirbnbColors.textLight),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '법정 최고 $maxRate% (${CommissionCalculator.formatCommission(maxCommission)})',
                            style: AppTypography.caption.copyWith(
                              color: AirbnbColors.textLight,
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
                    const Icon(Icons.person_outline, size: 14, color: AirbnbColors.textLight),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        property.userName.isNotEmpty ? property.userName : '매도인',
                        style: AppTypography.caption.copyWith(color: AirbnbColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.access_time, size: 14, color: AirbnbColors.textLight),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        DateTimeFormatter.timeAgo(property.createdAt),
                        style: AppTypography.caption.copyWith(color: AirbnbColors.textLight),
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
                // '이 매물 받기' 버튼 (콜백이 주어졌을 때만)
                if (currentBrokerUid != null && onTakeProperty != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _buildTakeButton(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Task 07 — 단독 지정 배지.
  ///
  /// 매도자가 자율적으로 단독 지정한 매물임을 표시. 본인이 지정 받았으면
  /// 녹색 "단독 지정 받은 매물" 강조, 그 외엔 주황색 "단독 지정" 비참여 안내.
  Widget _buildExclusiveBadge() {
    final bool isAssigned = currentBrokerUid != null &&
        property.exclusiveBrokerIds.contains(currentBrokerUid);
    final Color tone =
        isAssigned ? AirbnbColors.green : AirbnbColors.orange;
    final String label = isAssigned
        ? GrantMessages.listingExclusiveAssignedBadge
        : GrantMessages.listingExclusiveBadge;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tone.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            isAssigned ? Icons.verified : Icons.lock_outline,
            size: 14,
            color: tone,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: tone,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// 우선권 뱃지: 활성 grant 스트림을 구독하여 상태 뱃지로 변환.
  Widget _buildPriorityBadge() {
    return StreamBuilder<List<PriorityGrant>>(
      stream: PriorityGrantService().watchByProperty(property.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final grants = snapshot.data ?? const <PriorityGrant>[];
        return Align(
          alignment: Alignment.centerLeft,
          child: PriorityGrantBadge.fromGrants(
            activeGrants: grants,
            currentBrokerUid: currentBrokerUid ?? '',
            currentUserEligible: currentBrokerUid != null,
          ),
        );
      },
    );
  }

  /// Problem 004 갭 2 — 카드 ⋮ 메뉴.
  ///
  /// 본인 명의 *active* grant 1건 보유 시에만 "이 매물 놓기" 액션 노출.
  /// stream 결과가 비어있거나 본인 grant 가 없으면 SizedBox.shrink() 로 자리 차지 X
  /// (의사결정 ≤2 유지 — 80세 테스트 §1.4).
  ///
  /// 진입 시 [RevokeOwnGrantConfirmDialog.show] 의 2단계 확인을 거쳐
  /// `revokeOwnGrantViaFunction` 호출. 성공/실패 SnackBar 노출.
  Widget _buildOverflowMenu() {
    return StreamBuilder<List<PriorityGrant>>(
      stream: PriorityGrantService().watchByProperty(property.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final List<PriorityGrant> grants =
            snapshot.data ?? const <PriorityGrant>[];
        // 본인 명의 active grant 1건 추출.
        PriorityGrant? myActiveGrant;
        for (final PriorityGrant g in grants) {
          if (g.brokerUid == currentBrokerUid &&
              g.status == PriorityGrantStatus.active) {
            myActiveGrant = g;
            break;
          }
        }
        if (myActiveGrant == null) {
          return const SizedBox.shrink();
        }
        final PriorityGrant grant = myActiveGrant;
        return Padding(
          padding: const EdgeInsets.only(left: 4),
          child: SizedBox(
            width: 28,
            height: 28,
            child: PopupMenuButton<String>(
              tooltip: GrantMessages.actionReleaseHold,
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.more_vert,
                size: 18,
                color: AirbnbColors.textSecondary,
              ),
              itemBuilder: (BuildContext _) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'release',
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.outbox_outlined,
                        size: 16,
                        color: AirbnbColors.textPrimary,
                      ),
                      SizedBox(width: 8),
                      Text(GrantMessages.actionReleaseHold),
                    ],
                  ),
                ),
              ],
              onSelected: (String value) async {
                if (value != 'release') return;
                await _handleRevokeMyGrant(context, grant);
              },
            ),
          ),
        );
      },
    );
  }

  /// 자진 만료 핸들러 — 2단계 확인 통과 후 callable 호출.
  /// 성공: 24h 쿨다운 안내 SnackBar.
  /// 실패: 사유 코드 → `describeReason()` (raw 노출 차단).
  Future<void> _handleRevokeMyGrant(
    BuildContext context,
    PriorityGrant grant,
  ) async {
    final bool confirmed = await RevokeOwnGrantConfirmDialog.show(
      context: context,
      grant: grant,
    );
    if (!confirmed) return;
    if (!context.mounted) return;
    try {
      await PriorityGrantService().revokeOwnGrantViaFunction(grant.id);
      if (!context.mounted) return;
      AppSnackBar.success(
        context,
        GrantMessages.revokeSuccessWithCooldown,
      );
    } catch (e) {
      if (!context.mounted) return;
      final String? code = GrantMessages.extractReasonCode(e.toString());
      AppSnackBar.error(context, GrantMessages.describeReason(code));
    }
  }

  /// '이 매물 받기' 액션 버튼.
  ///
  /// Task 07 — listingMode === 'exclusive' 이고 본인이 지정 외 중개사면 비활성화.
  /// 매도자 자율 선택 결과 임을 분명히 한다 (§33①9호 회피).
  Widget _buildTakeButton() {
    final bool isExclusive = property.listingMode == 'exclusive';
    final bool isAssigned = currentBrokerUid != null &&
        property.exclusiveBrokerIds.contains(currentBrokerUid);
    final bool blocked = isExclusive && !isAssigned;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: blocked
            ? null
            : () async {
                final cb = onTakeProperty;
                if (cb != null) {
                  await cb();
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: AirbnbColors.primary,
          foregroundColor: AirbnbColors.background,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          blocked ? '단독 지정 매물' : GrantMessages.actionTakeProperty,
          style: AppTypography.bodySmall.copyWith(
            color: AirbnbColors.background,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(PropertyStatus status) {
    final (label, color) = switch (status) {
      PropertyStatus.active => ('신규', AirbnbColors.green),
      PropertyStatus.inquiry => ('문의중', AirbnbColors.primary),
      PropertyStatus.underOffer => ('협상중', AirbnbColors.orange),
      PropertyStatus.depositTaken => ('가계약', AirbnbColors.purple),
      PropertyStatus.sold => ('완료', AirbnbColors.textSecondary),
      _ => ('', AirbnbColors.textSecondary),
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
        style: AppTypography.caption.copyWith(
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
          color: AirbnbColors.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: AirbnbColors.background,
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
        style: AppTypography.bodySmall.copyWith(
          color: AirbnbColors.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
