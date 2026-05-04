import 'package:flutter/material.dart';

import 'package:property/constants/app_constants.dart';
import 'package:property/constants/jurisdictions.dart';
import 'package:property/constants/spacing.dart';
import 'package:property/constants/typography.dart';

/// 시·군·구 다중 선택기.
///
/// 80세 노인 테스트 통과 설계:
///   - 한 화면 두 단계: ① 시·도 1개 ② 시·군·구 N개 (의사결정 ≤ 2)
///   - 5자리 코드 자체 노출 0 (표시명만)
///   - 한자어 ("관할", "행정구역", "법정동") 노출 0
///   - 점수·가중치·% 노출 0
///   - 되돌리기 가능 (취소 버튼 + 칩 X)
///
/// 사용 예:
/// ```dart
/// final picked = await showJurisdictionPicker(
///   context,
///   initialCodes: ['11680'],
///   minCount: 1,
///   maxCount: 5,
/// );
/// if (picked != null) {
///   // picked 는 List<String> — 5자리 코드 목록
/// }
/// ```
class JurisdictionPicker extends StatefulWidget {
  const JurisdictionPicker({
    required this.initialCodes,
    required this.onConfirm,
    this.minCount = 1,
    this.maxCount = 5,
    super.key,
  });

  /// 현재 선택된 5자리 코드 목록.
  final List<String> initialCodes;

  /// 최소 선택 개수 (기본 1).
  final int minCount;

  /// 최대 선택 개수 (기본 5).
  final int maxCount;

  /// 저장 버튼 클릭 시 콜백. 호출자는 다이얼로그를 닫지 않으며,
  /// 본 위젯이 자동으로 [Navigator.pop] 한다.
  final ValueChanged<List<String>> onConfirm;

  @override
  State<JurisdictionPicker> createState() => _JurisdictionPickerState();
}

class _JurisdictionPickerState extends State<JurisdictionPicker> {
  late JurisdictionSido _selectedSido;
  late Set<String> _selectedCodes;
  String? _warning;

  @override
  void initState() {
    super.initState();
    _selectedCodes = <String>{...widget.initialCodes};
    // 초기 시·도: 선택된 코드 중 첫 번째가 속한 시·도 → 없으면 catalog 첫 항목.
    _selectedSido = _findSidoForCode(widget.initialCodes.isNotEmpty
            ? widget.initialCodes.first
            : null) ??
        JurisdictionCatalog.tree.first;
  }

  JurisdictionSido? _findSidoForCode(String? code) {
    if (code == null) return null;
    for (final sido in JurisdictionCatalog.tree) {
      for (final sg in sido.sigungu) {
        if (sg.code == code) return sido;
      }
    }
    return null;
  }

  void _toggle(String code) {
    setState(() {
      if (_selectedCodes.contains(code)) {
        _selectedCodes.remove(code);
        _warning = null;
      } else {
        if (_selectedCodes.length >= widget.maxCount) {
          _warning = '지역은 최대 ${widget.maxCount}개까지 고를 수 있어요';
          return;
        }
        _selectedCodes.add(code);
        _warning = null;
      }
    });
  }

  void _removeChip(String code) {
    setState(() {
      _selectedCodes.remove(code);
      _warning = null;
    });
  }

  void _onSavePressed() {
    if (_selectedCodes.length < widget.minCount) {
      setState(() {
        _warning = '지역을 ${widget.minCount}개 이상 골라주세요';
      });
      return;
    }
    final codes = _selectedCodes.toList()..sort();
    widget.onConfirm(codes);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // 다이얼로그 — 화면 높이의 80% 이내.
    final maxHeight = media.size.height * 0.8;

    return Dialog(
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: AirbnbColors.background,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: 520, maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _buildHeader(),
            const Divider(height: 1, color: AirbnbColors.border),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _buildStepLabel(1, '시·도 선택'),
                    const SizedBox(height: AppSpacing.sm),
                    _buildSidoDropdown(),
                    const SizedBox(height: AppSpacing.lg),
                    _buildStepLabel(
                      2,
                      '시·군·구 선택 (고른 곳: ${_selectedCodes.length}개)',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _buildSigunguGrid(),
                    if (_selectedCodes.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.lg),
                      _buildSelectedChipsLabel(),
                      const SizedBox(height: AppSpacing.sm),
                      _buildSelectedChips(),
                    ],
                    if (_warning != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      _buildWarning(_warning!),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: AirbnbColors.border),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '영업할 동네 고르기',
            style: AppTypography.withColor(
                AppTypography.h3, AirbnbColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '최대 ${widget.maxCount}개까지 고를 수 있어요',
            style: AppTypography.withColor(
                AppTypography.bodySmall, AirbnbColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildStepLabel(int step, String text) {
    return Row(
      children: <Widget>[
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AirbnbColors.primary,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$step',
            style: AppTypography.caption.copyWith(
              color: AirbnbColors.background,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: AppTypography.withColor(
                AppTypography.h4, AirbnbColors.textPrimary),
          ),
        ),
      ],
    );
  }

  Widget _buildSidoDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AirbnbColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AirbnbColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<JurisdictionSido>(
          value: _selectedSido,
          isExpanded: true,
          icon: const Icon(Icons.expand_more,
              color: AirbnbColors.textSecondary),
          items: <DropdownMenuItem<JurisdictionSido>>[
            for (final sido in JurisdictionCatalog.tree)
              DropdownMenuItem<JurisdictionSido>(
                value: sido,
                child: Text(
                  sido.name,
                  style: AppTypography.body,
                ),
              ),
          ],
          onChanged: (sido) {
            if (sido == null) return;
            setState(() {
              _selectedSido = sido;
            });
          },
        ),
      ),
    );
  }

  Widget _buildSigunguGrid() {
    final list = _selectedSido.sigungu;
    return LayoutBuilder(
      builder: (context, constraints) {
        // 좁은 폭(360 미만) 1열, 그 외 2열.
        final columns = constraints.maxWidth < 360 ? 1 : 2;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (final sg in list)
              SizedBox(
                width: (constraints.maxWidth -
                        AppSpacing.sm * (columns - 1)) /
                    columns,
                child: _buildSigunguTile(sg),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSigunguTile(JurisdictionSigungu sg) {
    final isChecked = _selectedCodes.contains(sg.code);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _toggle(sg.code),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isChecked
              ? AirbnbColors.primary.withValues(alpha: 0.08)
              : AirbnbColors.background,
          border: Border.all(
            color: isChecked
                ? AirbnbColors.primary
                : AirbnbColors.border,
            width: isChecked ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              isChecked
                  ? Icons.check_box
                  : Icons.check_box_outline_blank,
              size: 20,
              color: isChecked
                  ? AirbnbColors.primary
                  : AirbnbColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                sg.name,
                style: AppTypography.body.copyWith(
                  color: AirbnbColors.textPrimary,
                  fontWeight:
                      isChecked ? FontWeight.w600 : FontWeight.w400,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedChipsLabel() {
    return Text(
      '지금 고른 동네',
      style: AppTypography.withColor(
          AppTypography.captionLarge, AirbnbColors.textSecondary),
    );
  }

  Widget _buildSelectedChips() {
    final codes = _selectedCodes.toList()..sort();
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        for (final code in codes)
          _buildChip(code,
              JurisdictionCatalog.toDisplayName(code) ?? '알 수 없는 지역'),
      ],
    );
  }

  Widget _buildChip(String code, String displayName) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: AirbnbColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AirbnbColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            displayName,
            style: AppTypography.captionLarge.copyWith(
              color: AirbnbColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: () => _removeChip(code),
            borderRadius: BorderRadius.circular(12),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close,
                  size: 14, color: AirbnbColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarning(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AirbnbColors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: AirbnbColors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.info_outline,
              size: 18, color: AirbnbColors.orange),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: AppTypography.captionLarge.copyWith(
                color: AirbnbColors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Row(
        children: <Widget>[
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: AirbnbColors.border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                '취소',
                style: AppTypography.body.copyWith(
                  color: AirbnbColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: ElevatedButton(
              onPressed: _onSavePressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AirbnbColors.primary,
                foregroundColor: AirbnbColors.background,
                padding:
                    const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                '저장',
                style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// JurisdictionPicker 다이얼로그를 표시하고 사용자 선택 결과를 반환한다.
///
/// 반환값:
///   - 사용자가 [저장] 누른 경우: 선택된 5자리 코드 목록 (정렬됨)
///   - [취소] 또는 닫은 경우: null
Future<List<String>?> showJurisdictionPicker(
  BuildContext context, {
  required List<String> initialCodes,
  int minCount = 1,
  int maxCount = 5,
}) async {
  List<String>? result;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => JurisdictionPicker(
      initialCodes: initialCodes,
      minCount: minCount,
      maxCount: maxCount,
      onConfirm: (codes) {
        result = codes;
      },
    ),
  );
  return result;
}
