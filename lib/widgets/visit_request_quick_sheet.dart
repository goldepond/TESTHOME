import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../models/mls_property.dart';
import '../api_request/mls_property_service.dart';
import '../utils/formatters.dart';
import '../utils/phone_utils.dart';
import '../constants/typography.dart';
import '../constants/spacing.dart';
import 'broker_profile_sheet.dart';
import 'report_dialog.dart';
import 'package:property/utils/snackbar_utils.dart';

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
        color: AirbnbColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
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
                color: AirbnbColors.border,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),

          // 헤더
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '방문 요청 관리',
                        style: AppTypography.h2.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.property.roadAddress,
                        style: AppTypography.caption.copyWith(
                          color: AirbnbColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AirbnbColors.textSecondary),
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
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: _pendingRequests.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12.0),
                    itemBuilder: (context, index) {
                      return _buildRequestCard(_pendingRequests[index]);
                    },
                  ),
          ),

          // 하단 여백
          SizedBox(height: MediaQuery.of(context).padding.bottom + AppSpacing.md),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_outlined, size: 48, color: AirbnbColors.textLight),
          const SizedBox(height: AppSpacing.md),
          Text(
            '대기 중인 방문 요청이 없습니다',
            style: AppTypography.h4.copyWith(color: AirbnbColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(VisitRequest request) {
    final isReschedule = request.status == VisitRequestStatus.reschedule;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isReschedule
            ? AirbnbColors.primary.withValues(alpha: 0.05)
            : AirbnbColors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: isReschedule
            ? Border.all(color: AirbnbColors.primary.withValues(alpha: 0.3))
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
                        color: AirbnbColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person, color: AirbnbColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12.0),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              request.brokerName,
                              style: AppTypography.h4.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.info_outline, size: 14, color: AirbnbColors.primary),
                          ],
                        ),
                        if (request.brokerCompany != null)
                          Text(
                            request.brokerCompany!,
                            style: AppTypography.caption.copyWith(
                              color: AirbnbColors.textSecondary,
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
                    style: AppTypography.h3.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AirbnbColors.green,
                    ),
                  ),
                  Text(
                    '희망가',
                    style: AppTypography.caption.copyWith(
                      color: AirbnbColors.textLight,
                    ),
                  ),
                ],
              ),
              // 더보기 메뉴 (신고)
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert,
                  color: AirbnbColors.textSecondary,
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
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
                        Icon(Icons.flag_rounded, color: AirbnbColors.red, size: 18),
                        SizedBox(width: 8),
                        Text('중개사 신고', style: TextStyle(color: AirbnbColors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12.0),

          // 방문 희망일시
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AirbnbColors.surface,
              borderRadius: BorderRadius.circular(4.0),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today, size: 14, color: AirbnbColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  _formatDateTime(request.requestedDateTime),
                  style: AppTypography.caption.copyWith(
                    color: AirbnbColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (isReschedule) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AirbnbColors.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '시간 조율',
                      style: AppTypography.caption.copyWith(
                        color: AirbnbColors.background,
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
            const SizedBox(height: AppSpacing.sm),
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
                    style: AppTypography.caption.copyWith(
                      color: AirbnbColors.textSecondary,
                    ),
                    maxLines: _expandedMessages.contains(request.id) ? null : 2,
                    overflow: _expandedMessages.contains(request.id) ? null : TextOverflow.ellipsis,
                  ),
                  if (request.message!.length > 60)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        _expandedMessages.contains(request.id) ? '접기' : '더보기',
                        style: AppTypography.caption.copyWith(
                          color: AirbnbColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.md),

          // 액션 버튼
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading ? null : () => _rejectRequest(request),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AirbnbColors.red,
                    side: BorderSide(color: AirbnbColors.red.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('거절'),
                ),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () => _approveRequest(request),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AirbnbColors.green,
                    foregroundColor: AirbnbColors.background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AirbnbColors.background,
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
              style: AppTypography.body.copyWith(
                color: AirbnbColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: '010-0000-0000',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
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
              backgroundColor: AirbnbColors.green,
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
        AppSnackBar.success(context, '${request.brokerName}님의 방문 요청을 승인했습니다');
        widget.onUpdated?.call();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppSnackBar.error(context, '승인 실패: $e');
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
        AppSnackBar.warning(context, '${request.brokerName}님의 방문 요청을 거절했습니다');
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
        AppSnackBar.error(context, '거절 실패: $e');
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
