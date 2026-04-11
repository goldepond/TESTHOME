import 'package:flutter/material.dart';
import '../models/mls_property.dart';
import '../api_request/mls_property_service.dart';
import '../utils/formatters.dart';
import '../utils/phone_utils.dart';
import '../constants/apple_design_system.dart';
import 'broker_profile_sheet.dart';
import 'report_dialog.dart';

/// 방문 요청 관리 바텀시트 (판매자용)
/// 매물 리스트에서 바로 승인/거절 가능 - 3클릭 룰 개선
class VisitRequestQuickSheet extends StatefulWidget {
  final MLSProperty property;
  final VoidCallback? onUpdated;

  const VisitRequestQuickSheet({
    required this.property, super.key,
    this.onUpdated,
  });

  /// 바텀시트로 표시
  static Future<void> show(
    BuildContext context, {
    required MLSProperty property,
    VoidCallback? onUpdated,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => VisitRequestQuickSheet(
        property: property,
        onUpdated: onUpdated,
      ),
    );
  }

  @override
  State<VisitRequestQuickSheet> createState() => _VisitRequestQuickSheetState();
}

class _VisitRequestQuickSheetState extends State<VisitRequestQuickSheet> {
  final _mlsService = MLSPropertyService();
  bool _isLoading = false;
  final Set<String> _expandedMessages = {};

  List<VisitRequest> get _pendingRequests => widget.property.visitRequests
      .where((r) =>
          r.status == VisitRequestStatus.pending ||
          r.status == VisitRequestStatus.reschedule)
      .toList()
    ..sort((a, b) => b.proposedPrice.compareTo(a.proposedPrice));

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: AppleColors.systemBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppleRadius.lg)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 핸들바
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: AppleColors.separator,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),

          // 헤더
          Padding(
            padding: const EdgeInsets.all(AppleSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '방문 요청 관리',
                        style: AppleTypography.title2.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.property.roadAddress,
                        style: AppleTypography.caption1.copyWith(
                          color: AppleColors.secondaryLabel,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppleColors.secondaryLabel),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // 콘텐츠
          Flexible(
            child: _pendingRequests.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(AppleSpacing.md),
                    itemCount: _pendingRequests.length,
                    separatorBuilder: (_, _) => const SizedBox(height: AppleSpacing.sm),
                    itemBuilder: (context, index) {
                      return _buildRequestCard(_pendingRequests[index]);
                    },
                  ),
          ),

          // 하단 여백
          SizedBox(height: MediaQuery.of(context).padding.bottom + AppleSpacing.md),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(AppleSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_outlined, size: 48, color: AppleColors.tertiaryLabel),
          const SizedBox(height: AppleSpacing.md),
          Text(
            '대기 중인 방문 요청이 없습니다',
            style: AppleTypography.headline.copyWith(color: AppleColors.secondaryLabel),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(VisitRequest request) {
    final isReschedule = request.status == VisitRequestStatus.reschedule;

    return Container(
      padding: const EdgeInsets.all(AppleSpacing.md),
      decoration: BoxDecoration(
        color: isReschedule
            ? AppleColors.systemBlue.withValues(alpha: 0.05)
            : AppleColors.secondarySystemGroupedBackground,
        borderRadius: BorderRadius.circular(AppleRadius.md),
        border: isReschedule
            ? Border.all(color: AppleColors.systemBlue.withValues(alpha: 0.3))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더: 중개사 정보 + 희망가
          Row(
            children: [
              // 중개사 프로필 (클릭 가능)
              GestureDetector(
                onTap: () => _showBrokerProfile(request),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppleColors.systemBlue.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person, color: AppleColors.systemBlue, size: 20),
                    ),
                    const SizedBox(width: AppleSpacing.sm),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              request.brokerName,
                              style: AppleTypography.headline.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.info_outline, size: 14, color: AppleColors.systemBlue),
                          ],
                        ),
                        if (request.brokerCompany != null)
                          Text(
                            request.brokerCompany!,
                            style: AppleTypography.caption1.copyWith(
                              color: AppleColors.secondaryLabel,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // 희망가
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatPrice(request.proposedPrice),
                    style: AppleTypography.title3.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppleColors.systemGreen,
                    ),
                  ),
                  Text(
                    '희망가',
                    style: AppleTypography.caption2.copyWith(
                      color: AppleColors.tertiaryLabel,
                    ),
                  ),
                ],
              ),
              // 더보기 메뉴 (신고)
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert,
                  color: AppleColors.secondaryLabel,
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppleRadius.md),
                ),
                onSelected: (value) {
                  if (value == 'report') {
                    _reportBroker(request);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'report',
                    child: Row(
                      children: [
                        Icon(Icons.flag_rounded, color: AppleColors.systemRed, size: 18),
                        SizedBox(width: 8),
                        Text('중개사 신고', style: TextStyle(color: AppleColors.systemRed)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: AppleSpacing.sm),

          // 방문 희망일시
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppleSpacing.sm,
              vertical: AppleSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppleColors.tertiarySystemFill,
              borderRadius: BorderRadius.circular(AppleRadius.xs),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today, size: 14, color: AppleColors.secondaryLabel),
                const SizedBox(width: 4),
                Text(
                  _formatDateTime(request.requestedDateTime),
                  style: AppleTypography.caption1.copyWith(
                    color: AppleColors.label,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (isReschedule) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppleColors.systemBlue,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '시간 조율',
                      style: AppleTypography.caption2.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 메모 (있는 경우)
          if (request.message != null && request.message!.isNotEmpty) ...[
            const SizedBox(height: AppleSpacing.xs),
            GestureDetector(
              onTap: () {
                setState(() {
                  if (_expandedMessages.contains(request.id)) {
                    _expandedMessages.remove(request.id);
                  } else {
                    _expandedMessages.add(request.id);
                  }
                });
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.message!,
                    style: AppleTypography.caption1.copyWith(
                      color: AppleColors.secondaryLabel,
                    ),
                    maxLines: _expandedMessages.contains(request.id) ? null : 2,
                    overflow: _expandedMessages.contains(request.id) ? null : TextOverflow.ellipsis,
                  ),
                  if (request.message!.length > 60)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        _expandedMessages.contains(request.id) ? '접기' : '더보기',
                        style: AppleTypography.caption2.copyWith(
                          color: AppleColors.systemBlue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppleSpacing.md),

          // 액션 버튼
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading ? null : () => _rejectRequest(request),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppleColors.systemRed,
                    side: BorderSide(color: AppleColors.systemRed.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppleRadius.sm),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('거절'),
                ),
              ),
              const SizedBox(width: AppleSpacing.sm),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () => _approveRequest(request),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppleColors.systemGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppleRadius.sm),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('승인 (연락처 교환)'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showBrokerProfile(VisitRequest request) {
    BrokerProfileSheet.show(
      context,
      brokerId: request.brokerId,
      brokerName: request.brokerName,
      brokerCompany: request.brokerCompany,
      brokerPhone: request.brokerPhone,
    );
  }

  Future<void> _approveRequest(VisitRequest request) async {
    // 전화번호 입력 다이얼로그 표시
    final phoneController = TextEditingController();
    final phone = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('연락처 교환'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${request.brokerName}님에게 공개할 연락처를 입력해주세요.',
              style: AppleTypography.body.copyWith(
                color: AppleColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: '010-0000-0000',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppleRadius.sm),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              final phone = phoneController.text;
              if (phone.isNotEmpty && PhoneUtils.validate(phone) == null) {
                Navigator.pop(context, PhoneUtils.normalize(phone));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppleColors.systemGreen,
            ),
            child: const Text('승인'),
          ),
        ],
      ),
    );

    if (phone == null || phone.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await _mlsService.approveVisitRequest(
        propertyId: widget.property.id,
        requestId: request.id,
        sellerPhone: phone,
      );
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${request.brokerName}님의 방문 요청을 승인했습니다'),
            backgroundColor: AppleColors.systemGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        widget.onUpdated?.call();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('승인 실패: $e'),
            backgroundColor: AppleColors.systemRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _rejectRequest(VisitRequest request) async {
    setState(() => _isLoading = true);
    try {
      await _mlsService.rejectVisitRequest(
        propertyId: widget.property.id,
        requestId: request.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${request.brokerName}님의 방문 요청을 거절했습니다'),
            backgroundColor: AppleColors.systemOrange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        widget.onUpdated?.call();
        // 다른 요청이 남아있으면 시트 유지, 없으면 닫기
        if (_pendingRequests.length <= 1) {
          Navigator.pop(context);
        } else {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('거절 실패: $e'),
            backgroundColor: AppleColors.systemRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// 중개사 신고
  Future<void> _reportBroker(VisitRequest request) async {
    await showReportDialog(
      context: context,
      reporterId: widget.property.userId,
      reporterName: widget.property.userName,
      brokerId: request.brokerId,
      brokerName: request.brokerName,
      propertyId: widget.property.id,
    );
  }

  String _formatPrice(double price) => PriceFormatter.format(price);

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final isToday = dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day;
    final isTomorrow = dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day + 1;

    String dateStr;
    if (isToday) {
      dateStr = '오늘';
    } else if (isTomorrow) {
      dateStr = '내일';
    } else {
      dateStr = '${dateTime.month}/${dateTime.day}';
    }

    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour < 12 ? '오전' : '오후';
    final displayHour = hour > 12 ? hour - 12 : hour;

    return '$dateStr $period $displayHour:$minute';
  }
}
