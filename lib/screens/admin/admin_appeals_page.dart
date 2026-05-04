import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:property/api_request/admin_priority_service.dart';
import 'package:property/utils/cloud_functions_guard.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/constants/responsive_constants.dart';
import 'package:property/constants/spacing.dart';
import 'package:property/constants/typography.dart';
import 'package:property/models/priority_appeal.dart';

/// 관리자 - 이의 제기 큐 (Task 06).
///
/// 좌측: status 필터 칩 + 큐 리스트.
/// 우측: 선택된 appeal 상세 (사유 / replayedDecision / 처리 액션).
class AdminAppealsPage extends StatefulWidget {
  final String userId;
  final String userName;

  const AdminAppealsPage({
    required this.userId,
    required this.userName,
    super.key,
  });

  @override
  State<AdminAppealsPage> createState() => _AdminAppealsPageState();
}

class _AdminAppealsPageState extends State<AdminAppealsPage> {
  final AdminPriorityService _service = AdminPriorityService();
  final DateFormat _dateFmt = DateFormat('yyyy-MM-dd HH:mm');
  final JsonEncoder _jsonEncoder = const JsonEncoder.withIndent('  ');

  AppealStatus? _statusFilter;
  String? _selectedAppealId;
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AirbnbColors.surface,
      body: Center(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxWidth: ResponsiveHelper.getMaxWidth(context)),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: AppSpacing.md),
                _buildFilterChips(),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 360,
                        child: _buildAppealsList(),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: _buildAppealDetail()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(Icons.gavel_outlined, color: AirbnbColors.primary, size: 28),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '이의 제기 큐',
          style: AppTypography.h2.copyWith(color: AirbnbColors.textPrimary),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(
          '관리자: ${widget.userName}',
          style: AppTypography.caption
              .copyWith(color: AirbnbColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    const entries = <_StatusFilterEntry>[
      _StatusFilterEntry(null, '전체'),
      _StatusFilterEntry(AppealStatus.open, '접수'),
      _StatusFilterEntry(AppealStatus.reviewing, '검토중'),
      _StatusFilterEntry(AppealStatus.resolved, '인용'),
      _StatusFilterEntry(AppealStatus.rejected, '기각'),
    ];

    return Wrap(
      spacing: AppSpacing.sm,
      children: entries.map((entry) {
        final selected = _statusFilter == entry.status;
        return ChoiceChip(
          label: Text(entry.label),
          selected: selected,
          onSelected: (_) {
            setState(() {
              _statusFilter = entry.status;
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildAppealsList() {
    return Container(
      decoration: BoxDecoration(
        color: AirbnbColors.background,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: AirbnbColors.textPrimary.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: StreamBuilder<List<PriorityAppeal>>(
        stream: _service.watchAllAppeals(statusFilter: _statusFilter),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                '큐를 불러오지 못했습니다: ${snapshot.error}',
                style: AppTypography.bodySmall
                    .copyWith(color: AirbnbColors.error),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final appeals = snapshot.data!;
          if (appeals.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                '표시할 이의 제기가 없습니다.',
                style: AppTypography.bodySmall
                    .copyWith(color: AirbnbColors.textSecondary),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            itemCount: appeals.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final appeal = appeals[index];
              final selected = appeal.appealId == _selectedAppealId;
              return _buildAppealRow(appeal, selected);
            },
          );
        },
      ),
    );
  }

  Widget _buildAppealRow(PriorityAppeal appeal, bool selected) {
    return InkWell(
      onTap: () {
        setState(() => _selectedAppealId = appeal.appealId);
      },
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        color: selected
            ? AirbnbColors.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _statusBadge(appeal.status),
                const Spacer(),
                Text(
                  _dateFmt.format(appeal.createdAt),
                  style: AppTypography.caption
                      .copyWith(color: AirbnbColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'grantId: ${appeal.grantId}',
              style: AppTypography.caption
                  .copyWith(color: AirbnbColors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              appeal.reason,
              style: AppTypography.bodySmall
                  .copyWith(color: AirbnbColors.textPrimary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(AppealStatus status) {
    final (color, label) = switch (status) {
      AppealStatus.open => (Colors.blue, '접수'),
      AppealStatus.reviewing => (Colors.orange, '검토중'),
      AppealStatus.resolved => (Colors.green, '인용'),
      AppealStatus.rejected => (Colors.grey, '기각'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: AppTypography.caption
            .copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildAppealDetail() {
    if (_selectedAppealId == null) {
      return Container(
        decoration: BoxDecoration(
          color: AirbnbColors.background,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        alignment: Alignment.center,
        child: Text(
          '좌측에서 이의 제기를 선택하세요.',
          style: AppTypography.body
              .copyWith(color: AirbnbColors.textSecondary),
        ),
      );
    }

    return StreamBuilder<PriorityAppeal?>(
      stream: _service.watchAppeal(_selectedAppealId!),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _detailContainer(
            child: Text(
              '상세를 불러오지 못했습니다: ${snapshot.error}',
              style:
                  AppTypography.bodySmall.copyWith(color: AirbnbColors.error),
            ),
          );
        }
        if (!snapshot.hasData) {
          return _detailContainer(
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        final appeal = snapshot.data;
        if (appeal == null) {
          return _detailContainer(
            child: Text(
              '문서가 존재하지 않습니다.',
              style: AppTypography.bodySmall
                  .copyWith(color: AirbnbColors.textSecondary),
            ),
          );
        }
        return _detailContainer(child: _buildDetailBody(appeal));
      },
    );
  }

  Widget _detailContainer({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: AirbnbColors.background,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: AirbnbColors.textPrimary.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: child,
    );
  }

  Widget _buildDetailBody(PriorityAppeal appeal) {
    final replay = appeal.replayedDecision;
    final match = replay?['match'];
    final divergence = replay?['divergenceReason'];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _statusBadge(appeal.status),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: SelectableText(
                  'appealId: ${appeal.appealId}',
                  style: AppTypography.caption
                      .copyWith(color: AirbnbColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SelectableText(
            'grantId: ${appeal.grantId}',
            style: AppTypography.body
                .copyWith(color: AirbnbColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          SelectableText(
            'filerUid: ${appeal.filerUid}',
            style: AppTypography.bodySmall
                .copyWith(color: AirbnbColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          SelectableText(
            'createdAt: ${_dateFmt.format(appeal.createdAt)}'
            '${appeal.resolvedAt != null ? '  /  resolvedAt: ${_dateFmt.format(appeal.resolvedAt!)}' : ''}',
            style: AppTypography.caption
                .copyWith(color: AirbnbColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '이의 사유',
            style: AppTypography.h4.copyWith(color: AirbnbColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AirbnbColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: AirbnbColors.textLight.withValues(alpha: 0.4),
              ),
            ),
            child: SelectableText(
              appeal.reason,
              style: AppTypography.body
                  .copyWith(color: AirbnbColors.textPrimary),
            ),
          ),
          if (appeal.resolution != null && appeal.resolution!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              '처리 사유',
              style: AppTypography.h4.copyWith(color: AirbnbColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.xs),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AirbnbColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AirbnbColors.textLight.withValues(alpha: 0.4),
                ),
              ),
              child: SelectableText(
                appeal.resolution!,
                style: AppTypography.body
                    .copyWith(color: AirbnbColors.textPrimary),
              ),
            ),
          ],
          if (match == false) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                border: Border.all(color: Colors.red),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.red, size: 24),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '재현 결과 불일치 (match=false)',
                          style: AppTypography.body.copyWith(
                              color: Colors.red,
                              fontWeight: FontWeight.w600),
                        ),
                        if (divergence != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: SelectableText(
                              'divergenceReason: $divergence',
                              style: AppTypography.bodySmall
                                  .copyWith(color: Colors.red),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Text(
                'replayedDecision',
                style: AppTypography.h4
                    .copyWith(color: AirbnbColors.textPrimary),
              ),
              const SizedBox(width: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: _isProcessing
                    ? null
                    : () => _runReplay(appeal.grantId),
                icon: const Icon(Icons.replay, size: 18),
                label: const Text('재현 다시 실행'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AirbnbColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: AirbnbColors.textLight.withValues(alpha: 0.4),
              ),
            ),
            child: SelectableText(
              replay == null
                  ? '(아직 재현되지 않았습니다. 위 버튼을 눌러 재현하세요.)'
                  : _safeJsonEncode(replay),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.5,
                color: AirbnbColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (appeal.isOpen) _buildActionButtons(appeal),
        ],
      ),
    );
  }

  Widget _buildActionButtons(PriorityAppeal appeal) {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: _isProcessing
              ? null
              : () => _resolveAppealDialog(appeal, decision: 'resolved'),
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('인용'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        ElevatedButton.icon(
          onPressed: _isProcessing
              ? null
              : () => _resolveAppealDialog(appeal, decision: 'rejected'),
          icon: const Icon(Icons.cancel_outlined),
          label: const Text('기각'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AirbnbColors.error,
            foregroundColor: Colors.white,
          ),
        ),
        if (_isProcessing) ...[
          const SizedBox(width: AppSpacing.md),
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ],
      ],
    );
  }

  Future<void> _runReplay(String grantId) async {
    setState(() => _isProcessing = true);
    try {
      final result = await _service.replayDecision(grantId: grantId);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('재현 결과'),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: SelectableText(
                _safeJsonEncode(result),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('닫기'),
            ),
          ],
        ),
      );
    } on CloudFunctionsUserFacingException catch (e) {
      // problem 002 가드 — 미배포/연결불가 등은 한국어 카피로 노출.
      if (!mounted) return;
      _showError(e.userMessage);
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      _showError('재현 실패 (${e.code}): ${e.message ?? '오류'}');
    } catch (e) {
      if (!mounted) return;
      _showError('재현 실패: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _resolveAppealDialog(
    PriorityAppeal appeal, {
    required String decision,
  }) async {
    final controller = TextEditingController();
    final isResolve = decision == 'resolved';
    final title = isResolve ? '이의 제기 인용' : '이의 제기 기각';

    final resolution = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '처리 사유를 1~1000자로 입력하세요.',
                  style: AppTypography.bodySmall
                      .copyWith(color: AirbnbColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: controller,
                  maxLines: 6,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: '예: 가중치 변경에 따른 점수 차이 확인 후 ~',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isEmpty) return;
                Navigator.of(ctx).pop(text);
              },
              child: Text(isResolve ? '인용' : '기각'),
            ),
          ],
        );
      },
    );

    if (resolution == null || resolution.isEmpty) return;

    setState(() => _isProcessing = true);
    try {
      await _service.resolveAppeal(
        appealId: appeal.appealId,
        decision: decision,
        resolution: resolution,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('처리 완료 (${isResolve ? "인용" : "기각"})')),
      );
    } on CloudFunctionsUserFacingException catch (e) {
      // problem 002 가드 — 미배포/연결불가 등은 한국어 카피로 노출.
      if (!mounted) return;
      _showError(e.userMessage);
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      _showError('처리 실패 (${e.code}): ${_localizeFunctionsError(e)}');
    } catch (e) {
      if (!mounted) return;
      _showError('처리 실패: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AirbnbColors.error,
      ),
    );
  }

  String _localizeFunctionsError(FirebaseFunctionsException e) {
    return switch (e.code) {
      'permission-denied' => '권한이 없습니다.',
      'not-found' => '대상 문서를 찾을 수 없습니다.',
      'invalid-argument' => '입력값이 올바르지 않습니다.',
      'failed-precondition' => '처리할 수 없는 상태입니다.',
      'unauthenticated' => '인증이 만료되었습니다. 다시 로그인하세요.',
      _ => e.message ?? '알 수 없는 오류',
    };
  }

  String _safeJsonEncode(Object? value) {
    try {
      return _jsonEncoder.convert(value);
    } catch (_) {
      return value.toString();
    }
  }
}

class _StatusFilterEntry {
  final AppealStatus? status;
  final String label;
  const _StatusFilterEntry(this.status, this.label);
}
