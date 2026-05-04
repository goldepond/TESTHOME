import 'package:flutter/material.dart';
import 'package:property/api_request/mls_property_service.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/constants/grant_messages.dart';
import 'package:property/constants/typography.dart';
import 'package:property/utils/snackbar_utils.dart';
import 'package:property/widgets/common_design_system.dart';

/// Task 07 — 매도자 자율 단독 지정 섹션.
///
/// 매물 등록 화면에서 사용. 라디오 버튼(open/exclusive) + exclusive 선택 시
/// 면허 검증된 중개사 검색 모달 + 자발 동의 체크박스를 제공한다.
///
/// 법무 라인 (§33①9호 회피):
///   * UI 흐름이 *매도자 자발 선택* 임을 명백히 한다.
///   * 추천 표현 금지 — 가나다 순 중립 정렬, "추천" 어휘 사용 안 함.
///   * 자율 동의 체크박스 미표시 시 exclusive 진입 차단.
class ListingModeSection extends StatefulWidget {
  const ListingModeSection({
    required this.listingMode,
    required this.exclusiveBrokerIds,
    required this.exclusiveBrokerLabels,
    required this.consentSelfAttested,
    required this.onChanged,
    super.key,
    this.allowExclusive = true,
    this.lockReason,
  });

  /// 'open' | 'exclusive'
  final String listingMode;
  final List<String> exclusiveBrokerIds;

  /// brokerId → 표시 라벨 캐시 (등록 폼에서 표시 용).
  final Map<String, String> exclusiveBrokerLabels;
  final bool consentSelfAttested;

  /// (newMode, newIds, newLabels, newConsent) 콜백.
  final void Function(
    String newMode,
    List<String> newIds,
    Map<String, String> newLabels,
    bool newConsent,
  ) onChanged;

  /// 편집 화면에서 활성 grant 가 있을 때 exclusive 진입을 잠그는 옵션.
  final bool allowExclusive;
  final String? lockReason;

  @override
  State<ListingModeSection> createState() => _ListingModeSectionState();
}

class _ListingModeSectionState extends State<ListingModeSection> {
  @override
  Widget build(BuildContext context) {
    final bool isExclusive = widget.listingMode == 'exclusive';

    return Container(
      decoration: CommonDesignSystem.cardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            GrantMessages.listingModeSectionTitle,
            style: AppTypography.withColor(
              AppTypography.h4,
              AirbnbColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildRadioTile(
            value: 'open',
            label: GrantMessages.listingModeOpenLabel,
            description: GrantMessages.listingModeOpenDescription,
            selected: !isExclusive,
            enabled: true,
          ),
          const SizedBox(height: 8),
          _buildRadioTile(
            value: 'exclusive',
            label: GrantMessages.listingModeExclusiveLabel,
            description: GrantMessages.listingModeExclusiveDescription,
            selected: isExclusive,
            enabled: widget.allowExclusive,
          ),
          if (!widget.allowExclusive && widget.lockReason != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              widget.lockReason!,
              style: AppTypography.withColor(
                AppTypography.caption,
                AirbnbColors.textSecondary,
              ),
            ),
          ],
          if (isExclusive) ...<Widget>[
            const SizedBox(height: 16),
            _buildSelectedBrokers(),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _openSearchSheet,
              icon: const Icon(Icons.search),
              label: Text(
                widget.exclusiveBrokerIds.isEmpty
                    ? GrantMessages.exclusiveSearchTitle
                    : '지정 중개사 다시 고르기',
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                side: const BorderSide(color: AirbnbColors.primary),
                foregroundColor: AirbnbColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            _buildConsentCheckbox(),
          ],
        ],
      ),
    );
  }

  Widget _buildRadioTile({
    required String value,
    required String label,
    required String description,
    required bool selected,
    required bool enabled,
  }) {
    return InkWell(
      onTap: enabled
          ? () {
              if (value == widget.listingMode) return;
              if (value == 'open') {
                // exclusive → open: 지정 정보 초기화.
                widget.onChanged('open', <String>[], <String, String>{}, false);
              } else {
                // open → exclusive: 동의·지정은 모달/체크박스에서 채움.
                widget.onChanged(
                  'exclusive',
                  widget.exclusiveBrokerIds,
                  widget.exclusiveBrokerLabels,
                  widget.consentSelfAttested,
                );
              }
            }
          : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? AirbnbColors.primary.withValues(alpha: 0.06)
              : AirbnbColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AirbnbColors.primary : AirbnbColors.border,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 8),
              child: Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: enabled
                    ? (selected ? AirbnbColors.primary : AirbnbColors.textSecondary)
                    : AirbnbColors.border,
                size: 22,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: enabled
                          ? AirbnbColors.textPrimary
                          : AirbnbColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: AppTypography.withColor(
                      AppTypography.bodySmall,
                      AirbnbColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedBrokers() {
    if (widget.exclusiveBrokerIds.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          GrantMessages.exclusiveAtLeastOneRequired,
          style: AppTypography.withColor(
            AppTypography.bodySmall,
            AirbnbColors.error,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '${widget.exclusiveBrokerIds.length}${GrantMessages.exclusiveSelectedCountSuffix}',
          style: AppTypography.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            color: AirbnbColors.primary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.exclusiveBrokerIds.map((String id) {
            final String label = widget.exclusiveBrokerLabels[id] ?? id;
            return Chip(
              label: Text(label),
              backgroundColor: AirbnbColors.primary.withValues(alpha: 0.08),
              side: const BorderSide(color: AirbnbColors.primary),
              labelStyle: AppTypography.bodySmall.copyWith(
                color: AirbnbColors.primary,
              ),
              deleteIcon: const Icon(Icons.close, size: 16),
              onDeleted: () {
                final List<String> newIds = List<String>.from(widget.exclusiveBrokerIds)
                  ..remove(id);
                final Map<String, String> newLabels =
                    Map<String, String>.from(widget.exclusiveBrokerLabels)..remove(id);
                widget.onChanged(
                  'exclusive',
                  newIds,
                  newLabels,
                  widget.consentSelfAttested,
                );
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildConsentCheckbox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AirbnbColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.consentSelfAttested
              ? AirbnbColors.primary
              : AirbnbColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Checkbox(
            value: widget.consentSelfAttested,
            onChanged: (bool? v) {
              widget.onChanged(
                'exclusive',
                widget.exclusiveBrokerIds,
                widget.exclusiveBrokerLabels,
                v ?? false,
              );
            },
            activeColor: AirbnbColors.primary,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                GrantMessages.exclusiveSelfAttestationLabel,
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSearchSheet() async {
    final List<String>? picked = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AirbnbColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) => _ExclusiveBrokerSearchSheet(
        initialIds: widget.exclusiveBrokerIds,
        initialLabels: widget.exclusiveBrokerLabels,
        onLabelsChanged: (Map<String, String> labels) {
          // 모달 종료 시 라벨도 같이 끌어오므로 별도 처리.
          // pop 시 ids 만 반환하므로 라벨 캐시는 별도 setState 트리거.
        },
      ),
    );
    if (picked == null) return;
    if (picked.length > 3) {
      if (mounted) {
        AppSnackBar.info(context, GrantMessages.exclusiveLimitWarning);
      }
      return;
    }
    // 모달이 라벨을 별도 보유하지 않으므로, 호출처에서 brokerId 만 받고
    // 라벨은 listVerifiedBrokersForExclusive 결과를 다시 매핑하지 않는 한
    // 기존 캐시 + brokerId 폴백으로 표시한다.
    final Map<String, String> newLabels = <String, String>{};
    for (final String id in picked) {
      newLabels[id] = widget.exclusiveBrokerLabels[id] ?? id;
    }
    widget.onChanged(
      'exclusive',
      picked,
      newLabels,
      widget.consentSelfAttested,
    );
  }
}

/// Task 07 — exclusive 모드 검색 모달.
///
/// 면허 검증된 중개사만 노출, 가나다 순 중립 정렬.
/// "추천" 어휘 사용 금지 — 매도자 자율 선택을 위한 중립 표현.
class _ExclusiveBrokerSearchSheet extends StatefulWidget {
  const _ExclusiveBrokerSearchSheet({
    required this.initialIds,
    required this.initialLabels,
    required this.onLabelsChanged,
  });

  final List<String> initialIds;
  final Map<String, String> initialLabels;
  final void Function(Map<String, String>) onLabelsChanged;

  @override
  State<_ExclusiveBrokerSearchSheet> createState() =>
      _ExclusiveBrokerSearchSheetState();
}

class _ExclusiveBrokerSearchSheetState
    extends State<_ExclusiveBrokerSearchSheet> {
  final MLSPropertyService _service = MLSPropertyService();
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selected = <String>{};
  final Map<String, String> _labels = <String, String>{};

  Future<List<Map<String, dynamic>>>? _future;

  @override
  void initState() {
    super.initState();
    _selected.addAll(widget.initialIds);
    _labels.addAll(widget.initialLabels);
    _future = _service.listVerifiedBrokersForExclusive();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _runSearch() {
    setState(() {
      _future = _service.listVerifiedBrokersForExclusive(
        query: _searchController.text.trim(),
      );
    });
  }

  void _toggle(Map<String, dynamic> broker) {
    final String id = broker['brokerId'] as String;
    final String label =
        (broker['displayName'] as String).isNotEmpty
            ? broker['displayName'] as String
            : id;
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
        _labels.remove(id);
      } else {
        if (_selected.length >= 3) {
          AppSnackBar.info(context, GrantMessages.exclusiveLimitWarning);
          return;
        }
        _selected.add(id);
        _labels[id] = label;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final double height = MediaQuery.of(context).size.height * 0.85;
    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AirbnbColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              GrantMessages.exclusiveSearchTitle,
              style: AppTypography.h4,
            ),
            const SizedBox(height: 4),
            Text(
              GrantMessages.exclusiveOnlyVerifiedNotice,
              style: AppTypography.withColor(
                AppTypography.caption,
                AirbnbColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: GrantMessages.exclusiveSearchHint,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _runSearch,
                ),
              ),
              onSubmitted: (_) => _runSearch(),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  '${_selected.length}${GrantMessages.exclusiveSelectedCountSuffix}',
                  style: AppTypography.body.copyWith(
                    color: AirbnbColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                ElevatedButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () {
                          widget.onLabelsChanged(_labels);
                          Navigator.pop(context, _selected.toList());
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AirbnbColors.primary,
                  ),
                  child: const Text(GrantMessages.actionConfirm),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _future,
                builder: (BuildContext ctx,
                    AsyncSnapshot<List<Map<String, dynamic>>> snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(
                      child: Text(
                        '검색 중 오류가 발생했습니다: ${snap.error}',
                        style: AppTypography.bodySmall,
                      ),
                    );
                  }
                  final List<Map<String, dynamic>> list = snap.data ?? <Map<String, dynamic>>[];
                  if (list.isEmpty) {
                    return const Center(
                      child: Text(
                        GrantMessages.exclusiveSearchEmpty,
                        style: AppTypography.body,
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (BuildContext _, int _) =>
                        const Divider(height: 1),
                    itemBuilder: (BuildContext ictx, int idx) {
                      final Map<String, dynamic> b = list[idx];
                      final String id = b['brokerId'] as String;
                      final bool selected = _selected.contains(id);
                      return CheckboxListTile(
                        value: selected,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(
                          (b['displayName'] as String).isNotEmpty
                              ? b['displayName'] as String
                              : id,
                          style: AppTypography.body.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          [
                            (b['officeName'] as String?) ?? '',
                            (b['officeAddress'] as String?) ?? '',
                          ]
                              .where((String s) => s.isNotEmpty)
                              .join(' · '),
                          style: AppTypography.caption,
                        ),
                        onChanged: (_) => _toggle(b),
                        activeColor: AirbnbColors.primary,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
