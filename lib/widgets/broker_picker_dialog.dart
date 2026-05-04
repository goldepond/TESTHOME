import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:property/api_request/priority_grant_service.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/constants/grant_messages.dart';
import 'package:property/constants/spacing.dart';
import 'package:property/constants/typography.dart';
import 'package:property/models/broker_eligibility.dart';
import 'package:property/models/mls_property.dart';
import 'package:property/models/priority_grant.dart';
import 'package:property/utils/logger.dart';

/// Task 03 — M1.2 매수자측 임장 신청 시 담당 중개사 선택 다이얼로그.
///
/// 80세 노인 테스트:
/// - 한 화면 의사결정은 1개 ("어느 중개사를 통해 임장하시겠습니까?")
/// - 점수·가중치 노출 절대 금지
/// - 옵션 카드 위주, 한 줄 카피
///
/// 표시 순서 (명세 03-m1-buyer-broker.md §2 #2):
/// - A. 매물의 활성 seller_match grant 보유자 (M1.1 추천)
/// - B. 자격 통과 중개사 직접 검색 (해당 시군구)
/// - C. 평소 거래 중개사 (즐겨찾기) — 데이터 없으면 비표시
class BrokerPickerDialog extends StatefulWidget {
  /// 매수자가 임장하려는 매물.
  final MLSProperty property;

  /// 즐겨찾기 brokerId 목록 (없거나 비면 옵션 C 미표시).
  final List<String> favoriteBrokerIds;

  /// 동일 inquiry에 다른 활성 grant가 이미 있는 경우 — 교체 흐름.
  /// null이면 신규 발급.
  final PriorityGrant? currentActiveGrant;

  const BrokerPickerDialog({
    required this.property,
    super.key,
    this.favoriteBrokerIds = const <String>[],
    this.currentActiveGrant,
  });

  /// 다이얼로그를 띄우고, 매수자가 선택한 brokerId(또는 취소 시 null) 반환.
  ///
  /// **외부 호출자가 callable을 호출**하도록 한다 (다이얼로그는 brokerId만 반환).
  /// 이렇게 분리한 이유: 발급 실패 시(SwitchRequired/SwitchCooldown 등) 에러 처리
  /// 흐름이 다이얼로그 안에서 복잡해지는 것을 막기 위해.
  static Future<String?> show({
    required BuildContext context,
    required MLSProperty property,
    List<String> favoriteBrokerIds = const <String>[],
    PriorityGrant? currentActiveGrant,
  }) {
    return showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => BrokerPickerDialog(
        property: property,
        favoriteBrokerIds: favoriteBrokerIds,
        currentActiveGrant: currentActiveGrant,
      ),
    );
  }

  @override
  State<BrokerPickerDialog> createState() => _BrokerPickerDialogState();
}

class _BrokerPickerDialogState extends State<BrokerPickerDialog> {
  final PriorityGrantService _grantService = PriorityGrantService();

  PriorityGrant? _recommendedGrant; // M1.1 보유자 추천
  List<BrokerEligibility> _eligibleBrokers = const <BrokerEligibility>[];
  List<_BrokerOption> _favoriteBrokers = const <_BrokerOption>[];
  String _searchQuery = '';
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final FirebaseFirestore db = FirebaseFirestore.instance;
      // MLSProperty.region은 non-nullable이지만 빈 문자열일 수 있다.
      final String jurisdiction = widget.property.region;

      // A. 매물의 active seller_match grant (M1.1 추천)
      final QuerySnapshot<Map<String, dynamic>> recSnap = await db
          .collection('priority_grants')
          .where('propertyId', isEqualTo: widget.property.id)
          .where('type', isEqualTo: 'seller_match')
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();
      final PriorityGrant? rec = recSnap.docs.isEmpty
          ? null
          : PriorityGrant.fromFirestore(recSnap.docs.first);

      // B. 자격 통과 중개사 (해당 시군구)
      List<BrokerEligibility> eligible = const <BrokerEligibility>[];
      if (jurisdiction.isNotEmpty) {
        eligible = await _grantService.listEligibleBrokers(
          jurisdiction: jurisdiction,
        );
      }

      // C. 즐겨찾기 brokers (있으면 brokers 컬렉션에서 이름 조회)
      final List<_BrokerOption> favs = <_BrokerOption>[];
      for (final String fid in widget.favoriteBrokerIds) {
        if (fid.isEmpty) continue;
        try {
          final DocumentSnapshot<Map<String, dynamic>> doc =
              await db.collection('brokers').doc(fid).get();
          if (!doc.exists) continue;
          final Map<String, dynamic>? d = doc.data();
          if (d == null) continue;
          favs.add(
            _BrokerOption(
              brokerId: fid,
              displayName: (d['ownerName'] as String?) ??
                  (d['name'] as String?) ??
                  '○○○ 중개사',
              companyName: d['companyName'] as String?,
            ),
          );
        } catch (_) {
          // skip silently
        }
      }

      if (!mounted) return;
      setState(() {
        _recommendedGrant = rec;
        _eligibleBrokers = eligible;
        _favoriteBrokers = favs;
        _isLoading = false;
      });
    } catch (e, stack) {
      Logger.error(
        'BrokerPickerDialog data load failed',
        error: e,
        stackTrace: stack,
        context: 'BrokerPickerDialog',
        metadata: <String, dynamic>{'propertyId': widget.property.id},
      );
      if (!mounted) return;
      setState(() {
        _error = '잠시 후 다시 시도해 주세요';
        _isLoading = false;
      });
    }
  }

  void _confirm(String brokerId) {
    Navigator.of(context).pop(brokerId);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AirbnbColors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(AppSpacing.md),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                widget.currentActiveGrant != null
                    ? GrantMessages.buyerSwitchConfirmTitle
                    : GrantMessages.buyerPickerTitle,
                style: AppTypography.withColor(
                  AppTypography.h3,
                  AirbnbColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                widget.currentActiveGrant != null
                    ? GrantMessages.buyerSwitchConfirmBody
                    : GrantMessages.buyerPickerHelp,
                style: AppTypography.withColor(
                  AppTypography.bodySmall,
                  AirbnbColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text(
                    _error!,
                    style: AppTypography.withColor(
                      AppTypography.body,
                      AirbnbColors.error,
                    ),
                  ),
                )
              else
                Flexible(child: SingleChildScrollView(child: _buildOptions())),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(GrantMessages.actionCancel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (_recommendedGrant != null)
          _buildSection(
            title: '매물 추천 중개사',
            child: _buildOptionTile(
              brokerId: _recommendedGrant!.brokerId,
              title: '○○○ 중개사 (이 매물 우선 중개사)',
              subtitle: GrantMessages.actionUseRecommendedBroker,
            ),
          ),
        if (_favoriteBrokers.isNotEmpty)
          _buildSection(
            title: '평소 거래 중개사',
            child: Column(
              children: _favoriteBrokers
                  .map((_BrokerOption b) => _buildOptionTile(
                        brokerId: b.brokerId,
                        title: b.displayName,
                        subtitle: b.companyName,
                      ))
                  .toList(),
            ),
          ),
        _buildSection(
          title: '내 지역에서 활동 중인 중개사',
          child: Column(
            children: <Widget>[
              TextField(
                decoration: const InputDecoration(
                  hintText: '이름이나 사무소로 찾기',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (String v) =>
                    setState(() => _searchQuery = v.trim()),
              ),
              const SizedBox(height: AppSpacing.sm),
              ..._filteredEligible().map(
                (BrokerEligibility b) => _buildOptionTile(
                  brokerId: b.brokerId,
                  title: '○○○ 중개사',
                  subtitle: '면허 ${b.licenseNumber}',
                ),
              ),
              if (_filteredEligible().isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Text(
                    '이 지역에서 활동 중인 중개사가 아직 없어요',
                    style: AppTypography.withColor(
                      AppTypography.bodySmall,
                      AirbnbColors.textLight,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  List<BrokerEligibility> _filteredEligible() {
    if (_searchQuery.isEmpty) return _eligibleBrokers;
    final String q = _searchQuery.toLowerCase();
    return _eligibleBrokers
        .where(
          (BrokerEligibility b) =>
              b.brokerId.toLowerCase().contains(q) ||
              b.licenseNumber.toLowerCase().contains(q),
        )
        .toList();
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: AppTypography.withColor(
              AppTypography.caption,
              AirbnbColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          child,
        ],
      ),
    );
  }

  Widget _buildOptionTile({
    required String brokerId,
    required String title,
    String? subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      decoration: BoxDecoration(
        border: Border.all(color: AirbnbColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        title: Text(
          title,
          style: AppTypography.withColor(
            AppTypography.body,
            AirbnbColors.textPrimary,
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle,
                style: AppTypography.withColor(
                  AppTypography.caption,
                  AirbnbColors.textSecondary,
                ),
              ),
        trailing: const Icon(Icons.chevron_right, color: AirbnbColors.textLight),
        onTap: () => _confirm(brokerId),
      ),
    );
  }
}

class _BrokerOption {
  final String brokerId;
  final String displayName;
  final String? companyName;

  const _BrokerOption({
    required this.brokerId,
    required this.displayName,
    this.companyName,
  });
}
