import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:property/api_request/admin_priority_service.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/constants/responsive_constants.dart';
import 'package:property/constants/spacing.dart';
import 'package:property/constants/typography.dart';

/// 관리자 - 분쟁 조회용 audit log 타임라인 (Task 06).
///
/// `priority_audit_logs` 컬렉션을 propertyId로 collectionGroup query.
/// eventType 다중 선택 칩 + participation_* 전용 보기 토글.
class AdminAuditLogPage extends StatefulWidget {
  final String userId;
  final String userName;

  const AdminAuditLogPage({
    required this.userId,
    required this.userName,
    super.key,
  });

  @override
  State<AdminAuditLogPage> createState() => _AdminAuditLogPageState();
}

class _AdminAuditLogPageState extends State<AdminAuditLogPage> {
  final AdminPriorityService _service = AdminPriorityService();
  final TextEditingController _searchController = TextEditingController();
  final DateFormat _dateFmt = DateFormat('yyyy-MM-dd HH:mm:ss');
  final JsonEncoder _jsonEncoder = const JsonEncoder.withIndent('  ');

  bool _isLoading = false;
  String? _error;
  String? _queriedPropertyId;
  List<Map<String, dynamic>> _logs = const [];

  /// 사용자가 토글한 eventType 필터 (비어 있으면 전체).
  final Set<String> _selectedEventTypes = <String>{};

  /// participation_* 전용 보기 토글.
  bool _participationOnly = false;

  /// 어떤 row를 펼쳐서 inputs/outputs JSON을 보여줄지 추적.
  final Set<int> _expanded = <int>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
                _buildSearchBar(),
                const SizedBox(height: AppSpacing.md),
                _buildFilters(),
                const SizedBox(height: AppSpacing.md),
                Expanded(child: _buildBody()),
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
        const Icon(Icons.fact_check_outlined,
            color: AirbnbColors.primary, size: 28),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '분쟁 조회 (audit log)',
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

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'propertyId',
              hintText: '매물 문서 id를 입력하세요',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _runQuery(),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _runQuery,
          icon: const Icon(Icons.search),
          label: const Text('조회'),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    final filteredLogs = _filterLogs(_logs);
    final allTypes = _logs
        .map((log) => (log['eventType'] as String?) ?? '')
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilterChip(
          label: const Text('참여 타임라인 전용'),
          selected: _participationOnly,
          onSelected: (value) {
            setState(() {
              _participationOnly = value;
              _expanded.clear();
            });
          },
        ),
        const SizedBox(width: AppSpacing.sm),
        for (final type in allTypes)
          FilterChip(
            label: Text(
              '${auditEventLabel(type)} ($type)',
              style: AppTypography.caption,
            ),
            selected: _selectedEventTypes.contains(type),
            onSelected: (value) {
              setState(() {
                if (value) {
                  _selectedEventTypes.add(type);
                } else {
                  _selectedEventTypes.remove(type);
                }
                _expanded.clear();
              });
            },
          ),
        const SizedBox(width: AppSpacing.sm),
        if (_logs.isNotEmpty)
          Text(
            '${filteredLogs.length} / ${_logs.length} 건',
            style: AppTypography.caption
                .copyWith(color: AirbnbColors.textSecondary),
          ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AirbnbColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AirbnbColors.error),
        ),
        child: Text(
          '조회 실패: $_error',
          style: AppTypography.body.copyWith(color: AirbnbColors.error),
        ),
      );
    }
    if (_queriedPropertyId == null) {
      return Center(
        child: Text(
          'propertyId를 입력하고 조회 버튼을 눌러 주세요.',
          style: AppTypography.body
              .copyWith(color: AirbnbColors.textSecondary),
        ),
      );
    }

    final filtered = _filterLogs(_logs);
    if (filtered.isEmpty) {
      return Center(
        child: Text(
          '조건에 맞는 audit log가 없습니다.',
          style: AppTypography.body
              .copyWith(color: AirbnbColors.textSecondary),
        ),
      );
    }

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
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        itemCount: filtered.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) => _buildLogRow(filtered[index], index),
      ),
    );
  }

  Widget _buildLogRow(Map<String, dynamic> log, int index) {
    final eventType = (log['eventType'] as String?) ?? '(unknown)';
    final actorUid = (log['actorUid'] as String?) ?? '';
    final brokerId = (log['brokerId'] as String?) ?? '';
    final grantId = (log['grantId'] as String?) ?? '';
    final createdAt = _toDateTime(log['createdAt']);
    final isExpanded = _expanded.contains(index);

    return InkWell(
      onTap: () {
        setState(() {
          if (isExpanded) {
            _expanded.remove(index);
          } else {
            _expanded.add(index);
          }
        });
      },
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _eventBadge(eventType),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        auditEventLabel(eventType),
                        style: AppTypography.body.copyWith(
                          color: AirbnbColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$eventType'
                        '${grantId.isNotEmpty ? "  /  grantId: $grantId" : ""}'
                        '${brokerId.isNotEmpty ? "  /  brokerId: ${_short(brokerId)}" : ""}'
                        '${actorUid.isNotEmpty ? "  /  actorUid: ${_short(actorUid)}" : ""}',
                        style: AppTypography.caption
                            .copyWith(color: AirbnbColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  createdAt == null ? '-' : _dateFmt.format(createdAt),
                  style: AppTypography.caption
                      .copyWith(color: AirbnbColors.textSecondary),
                ),
                Icon(
                  isExpanded
                      ? Icons.expand_less
                      : Icons.expand_more,
                  color: AirbnbColors.textLight,
                ),
              ],
            ),
            if (isExpanded) ...[
              const SizedBox(height: AppSpacing.sm),
              _buildJsonBlock('inputs', log['inputs']),
              const SizedBox(height: AppSpacing.xs),
              _buildJsonBlock('outputs', log['outputs']),
              const SizedBox(height: AppSpacing.xs),
              _buildJsonBlock('raw', _stripFields(log)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildJsonBlock(String label, Object? value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AirbnbColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: AirbnbColors.textLight.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AirbnbColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            value == null ? '(없음)' : _safeJsonEncode(value),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              height: 1.5,
              color: AirbnbColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _eventBadge(String eventType) {
    final color = _eventColor(eventType);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        eventType,
        style: AppTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _eventColor(String eventType) {
    if (eventType.startsWith('grant_denied')) return AirbnbColors.error;
    if (eventType == 'grant_revoked' || eventType == 'grant_expired') {
      return Colors.orange;
    }
    if (eventType == 'grant_issued') return Colors.green;
    if (eventType == 'appeal_resolved' || eventType == 'appeal_rejected') {
      return AirbnbColors.primary;
    }
    if (isParticipationAuditEvent(eventType)) return Colors.blueGrey;
    return AirbnbColors.textSecondary;
  }

  Future<void> _runQuery() async {
    final propertyId = _searchController.text.trim();
    if (propertyId.isEmpty) {
      setState(() {
        _error = 'propertyId를 입력해 주세요.';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
      _queriedPropertyId = propertyId;
      _logs = const [];
      _expanded.clear();
    });
    try {
      final logs = await _service.getPropertyAuditLogs(propertyId);
      if (!mounted) return;
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _filterLogs(List<Map<String, dynamic>> logs) {
    return logs.where((log) {
      final eventType = (log['eventType'] as String?) ?? '';
      if (_participationOnly && !isParticipationAuditEvent(eventType)) {
        return false;
      }
      if (_selectedEventTypes.isNotEmpty &&
          !_selectedEventTypes.contains(eventType)) {
        return false;
      }
      return true;
    }).toList();
  }

  Map<String, dynamic> _stripFields(Map<String, dynamic> log) {
    final clone = Map<String, dynamic>.from(log);
    clone.remove('inputs');
    clone.remove('outputs');
    return clone;
  }

  DateTime? _toDateTime(Object? raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    return null;
  }

  String _short(String id) {
    if (id.length <= 10) return id;
    return '${id.substring(0, 8)}…';
  }

  String _safeJsonEncode(Object? value) {
    try {
      return _jsonEncoder.convert(_makeJsonSafe(value));
    } catch (_) {
      return value.toString();
    }
  }

  /// Firestore Timestamp/DateTime 등은 JsonEncoder가 직접 처리하지 못하므로
  /// 직렬화 가능한 형태로 1회 변환한다.
  Object? _makeJsonSafe(Object? value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is DateTime) return value.toIso8601String();
    if (value is Map) {
      return value.map<String, Object?>(
        (key, val) => MapEntry(key.toString(), _makeJsonSafe(val)),
      );
    }
    if (value is Iterable) {
      return value.map(_makeJsonSafe).toList();
    }
    if (value is num || value is String || value is bool) return value;
    return value.toString();
  }
}
