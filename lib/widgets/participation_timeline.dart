import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/constants/grant_messages.dart';
import 'package:property/constants/spacing.dart';
import 'package:property/constants/typography.dart';
import 'package:property/models/broker_participation.dart';

/// Task 05 — 매도자 대시보드용 중개사 활동 타임라인.
///
/// `mlsProperties/{id}/broker_participations/*` 의 비식별 view를
/// 시계열로 보여준다. 각 participant의 declared → visitScheduled → offerMade
/// 단계별 이벤트를 한 줄씩 표시한다.
///
/// **80세 노인 화법**:
/// - 다른 중개사 실명/사무소/전화번호는 우선권 부여 후만 노출
/// - "1등", "최우선", 점수, % 노출 *0건* — 강조는 색상만
/// - displayName + 단계 카피만
class ParticipationTimeline extends StatelessWidget {
  const ParticipationTimeline({
    required this.participants,
    super.key,
    this.showHolderHighlight = true,
  });

  /// callable `getBrokerParticipationsForSeller` 응답을 변환한 리스트.
  /// 정렬: `declaredAt ASC`.
  final List<BrokerParticipation> participants;

  /// `hasActiveGrant=true` participant를 색상으로 강조할지 여부. 기본 true.
  final bool showHolderHighlight;

  @override
  Widget build(BuildContext context) {
    if (participants.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Text(
          GrantMessages.participationEmptyState,
          style: AppTypography.caption.copyWith(
            color: AirbnbColors.textSecondary,
          ),
        ),
      );
    }

    // 각 participant의 단계별 이벤트를 평탄화 — 시계열 표시 보강.
    final List<_TimelineEvent> events = <_TimelineEvent>[];
    for (final BrokerParticipation p in participants) {
      if (p.declaredAt != null) {
        events.add(_TimelineEvent(
          participant: p,
          stage: ParticipationStage.declared,
          at: p.declaredAt!,
        ));
      }
      if (p.visitScheduledAt != null) {
        events.add(_TimelineEvent(
          participant: p,
          stage: ParticipationStage.visitScheduled,
          at: p.visitScheduledAt!,
        ));
      }
      if (p.offerMadeAt != null) {
        events.add(_TimelineEvent(
          participant: p,
          stage: ParticipationStage.offerMade,
          at: p.offerMadeAt!,
        ));
      }
    }
    // 시계열 정렬 — at 오름차순.
    events.sort((a, b) => a.at.compareTo(b.at));

    if (events.isEmpty) {
      // 모든 시간 필드 null인 비정상 케이스 — empty state 동일 처리.
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Text(
          GrantMessages.participationEmptyState,
          style: AppTypography.caption.copyWith(
            color: AirbnbColors.textSecondary,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int i = 0; i < events.length; i++)
          _buildEventRow(events[i], isLast: i == events.length - 1),
      ],
    );
  }

  Widget _buildEventRow(_TimelineEvent ev, {required bool isLast}) {
    final bool highlight = showHolderHighlight && ev.participant.hasActiveGrant;
    final Color accent =
        highlight ? AirbnbColors.primary : AirbnbColors.textLight;
    final Color cardBg = highlight
        ? AirbnbColors.primary.withValues(alpha: 0.06)
        : AirbnbColors.surface;
    final Color borderColor = highlight
        ? AirbnbColors.primary
        : AirbnbColors.border;
    final String stageLabel = GrantMessages.participationStageLabel(
      BrokerParticipation.stageToString(ev.stage),
    );
    final String timeLabel = DateFormat('MM-dd HH:mm').format(ev.at);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // 좌측 점/세로선
          SizedBox(
            width: 24,
            child: Column(
              children: <Widget>[
                const SizedBox(height: 14),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AirbnbColors.border,
                    ),
                  ),
              ],
            ),
          ),
          // 우측 카드
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(
                bottom: AppSpacing.sm,
                left: AppSpacing.xs,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: borderColor,
                    width: highlight ? 1.2 : 0.6,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // displayName · stage · time 한 줄
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 2,
                      children: <Widget>[
                        Text(
                          ev.participant.displayName,
                          style: AppTypography.body.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AirbnbColors.textPrimary,
                          ),
                        ),
                        Text(
                          '·',
                          style: AppTypography.caption.copyWith(
                            color: AirbnbColors.textLight,
                          ),
                        ),
                        Text(
                          stageLabel,
                          style: AppTypography.caption.copyWith(
                            color: AirbnbColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '·',
                          style: AppTypography.caption.copyWith(
                            color: AirbnbColors.textLight,
                          ),
                        ),
                        Text(
                          timeLabel,
                          style: AppTypography.caption.copyWith(
                            color: AirbnbColors.textLight,
                            fontFeatures: const <FontFeature>[
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (highlight) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        GrantMessages.participationHolderBadge,
                        style: AppTypography.caption.copyWith(
                          color: AirbnbColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    // 우선권 부여 후만 매도자에게 실명 공개 — 명세 §2.2 / §4
                    if (highlight && ev.participant.brokerName != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        _holderDetailLine(ev.participant),
                        style: AppTypography.caption.copyWith(
                          color: AirbnbColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 보유자 상세 라인: "홍길동 (행복 공인중개사)" 또는 "홍길동".
  /// 전화번호는 별도 위젯에서 노출 (본 위젯은 타임라인 라벨용).
  String _holderDetailLine(BrokerParticipation p) {
    final String name = p.brokerName ?? '';
    final String office = p.officeName ?? '';
    if (office.isEmpty) return name;
    return '$name ($office)';
  }
}

class _TimelineEvent {
  final BrokerParticipation participant;
  final ParticipationStage stage;
  final DateTime at;

  const _TimelineEvent({
    required this.participant,
    required this.stage,
    required this.at,
  });
}
