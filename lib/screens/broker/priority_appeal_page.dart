import 'package:flutter/material.dart';

import '../../api_request/priority_appeal_service.dart';
import '../../api_request/priority_grant_service.dart';
import '../../constants/app_constants.dart';
import '../../constants/grant_messages.dart';
import '../../constants/responsive_constants.dart';
import '../../constants/spacing.dart';
import '../../constants/typography.dart';
import '../../models/priority_appeal.dart';
import '../../models/priority_grant.dart';
import '../../utils/formatters.dart';
import '../../utils/snackbar_utils.dart';

/// 이의 제기 actor 역할.
///
/// Problem 004 — 본 페이지는 broker / seller 양 actor 가 사용한다.
/// * [broker]: 본인이 받은 grant 에 대한 결정 이의 (기존 흐름).
/// * [seller]: 본인 매물 grant 결정에 대한 이의 (Problem 004 신규 진입점).
/// 백엔드는 actor 무관 — `priority_appeals.filerUid` 만 사용. 분기 영역은 UI 카피와
/// grant 목록 source 뿐이다.
enum AppealActorRole { broker, seller }

/// 이의 제기 페이지 (P1-21.1 / Problem 004 일반화).
///
/// `_AppealCenterSheet` 모달을 대체하는 전용 페이지. 카테고리 라디오 +
/// 대상 매물 선택 + 사유 입력으로 80세 노인도 따라 할 수 있는 단순 흐름을
/// 유지한다 — 점수·% 표시 0건, 한 화면 의사결정 ≤2.
///
/// 카테고리:
/// * `grantDecision`(기본): 본인 차례 결정에 대한 이의 → grantId 필수.
/// * `listingModeDispute`: 매물 모드 분쟁 → propertyId 필수, grantId 부재 허용.
/// * `other`: 기타 → grantId 또는 propertyId 중 하나 이상 필요.
///
/// Actor 분기 (Problem 004 §2.2):
/// * [role] == [AppealActorRole.broker] (기본): grant source = `watchByBroker(actorUid)`.
/// * [role] == [AppealActorRole.seller]: grant source = `watchBySeller(actorUid)` — 본인
///   매물에서 발급된 active grant 목록.
/// 두 경우 모두 history 탭은 `watchMyAppeals()` (filerUid 기준) 동일.
///
/// [preselectedGrantId] 가 주어지면 해당 grant 가 드롭다운에 사전 선택된 채 페이지가
/// 열린다 (audit timeline 행에서 진입할 때 사용).
class PriorityAppealPage extends StatefulWidget {
  const PriorityAppealPage({
    required this.actorUid,
    this.role = AppealActorRole.broker,
    this.preselectedGrantId,
    super.key,
  });

  final String actorUid;
  final AppealActorRole role;
  final String? preselectedGrantId;

  @override
  State<PriorityAppealPage> createState() => _PriorityAppealPageState();
}

class _PriorityAppealPageState extends State<PriorityAppealPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final PriorityAppealService _appeals = PriorityAppealService();
  final PriorityGrantService _grants = PriorityGrantService();
  final TextEditingController _reasonController = TextEditingController();

  AppealCategory _category = AppealCategory.grantDecision;
  PriorityGrant? _selectedGrant;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String reason = _reasonController.text.trim();
    final PriorityGrant? grant = _selectedGrant;

    if (reason.isEmpty) {
      AppSnackBar.error(context, '이유를 1자 이상 적어주세요');
      return;
    }
    if (reason.length > PriorityAppeal.maxReasonLength) {
      AppSnackBar.error(
        context,
        GrantMessages.appealReasonTooLong(PriorityAppeal.maxReasonLength),
      );
      return;
    }

    final bool isModeDispute =
        _category == AppealCategory.listingModeDispute;

    if (grant == null) {
      AppSnackBar.error(
        context,
        isModeDispute ? '어느 매물에 대한 분쟁인지 골라주세요' : GrantMessages.appealSelectGrantPrompt,
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await _appeals.fileAppeal(
        grantId: isModeDispute ? '' : grant.id,
        reason: reason,
        appealCategory: _category,
        propertyId: grant.propertyId,
      );
      if (!mounted) return;
      AppSnackBar.success(context, GrantMessages.appealSubmitted);
      _reasonController.clear();
      setState(() {
        _selectedGrant = null;
        _category = AppealCategory.grantDecision;
      });
      _tabs.animateTo(1);
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.error(context, '신청을 보내지 못했어요. 잠시 후 다시 시도해 주세요.');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AirbnbColors.surface,
      appBar: AppBar(
        backgroundColor: AirbnbColors.background,
        foregroundColor: AirbnbColors.textPrimary,
        elevation: 0,
        title: Text(
          GrantMessages.appealMenuTitle,
          style: AppTypography.h4.copyWith(fontWeight: FontWeight.w700),
        ),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AirbnbColors.primary,
          unselectedLabelColor: AirbnbColors.textSecondary,
          indicatorColor: AirbnbColors.primary,
          tabs: const <Widget>[
            Tab(text: '신청하기'),
            Tab(text: '내 내역'),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: ResponsiveHelper.getMaxWidth(context),
          ),
          child: TabBarView(
            controller: _tabs,
            children: <Widget>[
              _buildFileTab(),
              _buildHistoryTab(),
            ],
          ),
        ),
      ),
    );
  }

  /// Actor 역할별 grant source 분기.
  /// * broker: 본인 명의 grant.
  /// * seller: 본인 매물에서 발급된 grant (다른 중개사 명의).
  Stream<List<PriorityGrant>> _grantsStream() {
    switch (widget.role) {
      case AppealActorRole.broker:
        return _grants.watchByBroker(widget.actorUid);
      case AppealActorRole.seller:
        return _grants.watchBySeller(widget.actorUid);
    }
  }

  /// Actor 역할별 빈 상태 카피.
  String get _emptyStateCopy {
    switch (widget.role) {
      case AppealActorRole.broker:
        return GrantMessages.appealNoEligibleGrants;
      case AppealActorRole.seller:
        return GrantMessages.appealNoEligibleGrantsForSeller;
    }
  }

  /// Actor 역할별 드롭다운 라벨.
  String get _targetLabel {
    switch (widget.role) {
      case AppealActorRole.broker:
        return GrantMessages.appealTargetLabel;
      case AppealActorRole.seller:
        return GrantMessages.sellerAppealTargetLabel;
    }
  }

  /// preselectedGrantId 가 주어졌을 때 해당 grant 가 stream 결과에 등장하면
  /// _selectedGrant 에 자동 할당. 사용자가 다른 grant 를 선택한 뒤에는 덮어쓰지 않는다
  /// (onChanged 가 _selectedGrant 를 갱신하므로 1회만 적용).
  void _applyPreselection(List<PriorityGrant> grants) {
    final String? preselectedId = widget.preselectedGrantId;
    if (preselectedId == null || preselectedId.isEmpty) return;
    if (_selectedGrant != null) return;
    for (final PriorityGrant g in grants) {
      if (g.id == preselectedId) {
        // setState 는 build 내부 호출 금지 — 다음 frame 에 적용.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _selectedGrant = g);
        });
        return;
      }
    }
  }

  Widget _buildFileTab() {
    return StreamBuilder<List<PriorityGrant>>(
      stream: _grantsStream(),
      builder: (context, snapshot) {
        final List<PriorityGrant> grants =
            snapshot.data ?? const <PriorityGrant>[];
        _applyPreselection(grants);

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            Text(
              GrantMessages.appealCategorySectionTitle,
              style: AppTypography.body.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildCategoryOption(
              category: AppealCategory.grantDecision,
              label: GrantMessages.appealCategoryGrantDecision,
            ),
            _buildCategoryOption(
              category: AppealCategory.listingModeDispute,
              label: GrantMessages.appealCategoryListingModeDispute,
            ),
            _buildCategoryOption(
              category: AppealCategory.other,
              label: GrantMessages.appealCategoryOther,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              GrantMessages.appealFormTitle,
              style: AppTypography.body.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (grants.isEmpty)
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AirbnbColors.background,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AirbnbColors.border),
                ),
                child: Text(
                  _emptyStateCopy,
                  style: AppTypography.bodySmall.copyWith(
                    color: AirbnbColors.textSecondary,
                  ),
                ),
              )
            else
              DropdownButtonFormField<PriorityGrant>(
                initialValue: _selectedGrant,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: _targetLabel,
                  filled: true,
                  fillColor: AirbnbColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                items: grants
                    .map(
                      (PriorityGrant g) => DropdownMenuItem<PriorityGrant>(
                        value: g,
                        child: Text(
                          '${GrantMessages.describeStage(g.stage.name)} · '
                          '${_truncatePropertyId(g.propertyId)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (PriorityGrant? value) {
                  setState(() => _selectedGrant = value);
                },
              ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _reasonController,
              minLines: 4,
              maxLines: 8,
              maxLength: PriorityAppeal.maxReasonLength,
              decoration: InputDecoration(
                labelText: '이유',
                hintText: GrantMessages.appealReasonHint,
                filled: true,
                fillColor: AirbnbColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AirbnbColors.primary,
                  foregroundColor: AirbnbColors.background,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(GrantMessages.appealSubmit),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryOption({
    required AppealCategory category,
    required String label,
  }) {
    return RadioListTile<AppealCategory>(
      value: category,
      // ignore: deprecated_member_use
      groupValue: _category,
      // ignore: deprecated_member_use
      onChanged: (AppealCategory? value) {
        if (value == null) return;
        setState(() => _category = value);
      },
      contentPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      activeColor: AirbnbColors.primary,
      title: Text(
        label,
        style: AppTypography.body.copyWith(color: AirbnbColors.textPrimary),
      ),
    );
  }

  Widget _buildHistoryTab() {
    return StreamBuilder<List<PriorityAppeal>>(
      stream: _appeals.watchMyAppeals(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        final List<PriorityAppeal> items =
            snapshot.data ?? const <PriorityAppeal>[];
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                GrantMessages.appealEmptyState,
                style: AppTypography.body.copyWith(
                  color: AirbnbColors.textSecondary,
                ),
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, i) => _buildAppealRow(items[i]),
        );
      },
    );
  }

  Widget _buildAppealRow(PriorityAppeal a) {
    final Color statusColor;
    switch (a.status) {
      case AppealStatus.open:
      case AppealStatus.reviewing:
        statusColor = AirbnbColors.warning;
        break;
      case AppealStatus.resolved:
        statusColor = AirbnbColors.green;
        break;
      case AppealStatus.rejected:
        statusColor = AirbnbColors.textSecondary;
        break;
    }
    final String reasonExcerpt = a.reason.length > 80
        ? '${a.reason.substring(0, 80)}...'
        : a.reason;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AirbnbColors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AirbnbColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  GrantMessages.appealStatusLabel(a.status.name),
                  style: AppTypography.caption.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  GrantMessages.appealCategoryLabel(a.appealCategory.wireName),
                  style: AppTypography.caption.copyWith(
                    color: AirbnbColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                DateTimeFormatter.timeAgo(a.createdAt),
                style: AppTypography.caption.copyWith(
                  color: AirbnbColors.textLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            reasonExcerpt,
            style: AppTypography.bodySmall.copyWith(
              color: AirbnbColors.textPrimary,
            ),
          ),
          if (a.resolution != null && a.resolution!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              '결과: ${a.resolution!}',
              style: AppTypography.caption.copyWith(
                color: AirbnbColors.textSecondary,
              ),
            ),
          ] else if (a.isOpen) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              GrantMessages.appealReviewedNote,
              style: AppTypography.caption.copyWith(
                color: AirbnbColors.textLight,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _truncatePropertyId(String id) {
    return id.length <= 8 ? id : id.substring(0, 8);
  }
}
