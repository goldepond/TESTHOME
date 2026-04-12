import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/api_request/mls_property_service.dart';
import 'package:property/models/notification_model.dart';
import 'package:property/screens/seller/mls_property_detail_page.dart';
import 'package:intl/intl.dart';
import 'package:property/constants/typography.dart';
import 'package:property/utils/snackbar_utils.dart';

class NotificationPage extends StatefulWidget {
  final String userId;

  const NotificationPage({
    required this.userId,
    super.key,
  });

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _showReadNotifications = false; // 읽은 알림 표시 여부
  bool _isNavigating = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AirbnbColors.surface,
      appBar: AppBar(
        title: const Text(
          '알림 센터',
          style: TextStyle(
            color: AirbnbColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AirbnbColors.background,
        elevation: 0.5,
        foregroundColor: AirbnbColors.textPrimary,
        actions: [
          IconButton(
            icon: Icon(
              _showReadNotifications ? Icons.visibility : Icons.visibility_off,
              size: 20,
            ),
            tooltip: _showReadNotifications ? '읽은 알림 숨기기' : '읽은 알림 보기',
            onPressed: () {
              setState(() {
                _showReadNotifications = !_showReadNotifications;
              });
            },
          ),
          TextButton(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('모두 읽음'),
                  content: const Text('읽지 않은 모든 알림을 읽음 처리하시겠습니까?\n\n읽은 알림은 자동으로 숨겨집니다.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('취소'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('확인'),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                await _firebaseService.markAllNotificationsAsRead(widget.userId);
                if (!context.mounted) return;
                setState(() {
                  _showReadNotifications = false; // 자동으로 읽은 알림 숨기기
                });
                AppSnackBar.info(context, '모든 알림을 읽음 처리했습니다');
              }
            },
            child: const Text('모두 읽음'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: StreamBuilder<List<NotificationModel>>(
        stream: _firebaseService.getUserNotifications(widget.userId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('오류가 발생했습니다: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allNotifications = snapshot.data ?? [];

          // 읽은 알림 필터링
          final notifications = _showReadNotifications
              ? allNotifications
              : allNotifications.where((n) => !n.isRead).toList();

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _showReadNotifications
                        ? Icons.notifications_off_outlined
                        : Icons.mark_email_read_outlined,
                    size: 64,
                    color: AirbnbColors.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _showReadNotifications
                        ? '알림이 없습니다'
                        : '읽지 않은 알림이 없습니다',
                    style:  AppTypography.body.copyWith(color: AirbnbColors.textSecondary, fontWeight: FontWeight.w500),
                  ),
                  if (!_showReadNotifications && allNotifications.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _showReadNotifications = true;
                        });
                      },
                      icon: const Icon(Icons.visibility, size: 18),
                      label: const Text('읽은 알림 보기'),
                    ),
                  ],
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              return _buildNotificationItem(notifications[index]);
            },
          );
        },
      ),
        ),
      ),
    );
  }

  Widget _buildNotificationItem(NotificationModel notification) {
    final dateFormat = DateFormat('MM.dd HH:mm');

    return InkWell(
        onTap: () {
          if (!notification.isRead) {
            _firebaseService.markNotificationAsRead(notification.id);
          }
          _navigateByNotificationType(notification);
        },
        child: Container(
          color: notification.isRead ? AirbnbColors.background : AirbnbColors.primary.withValues(alpha: 0.05),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _getIconBackgroundColor(notification.type),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getIconData(notification.type),
                  color: _getIconColor(notification.type),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: AppTypography.withColor(AppTypography.body, AirbnbColors.textPrimary),
                          ),
                        ),
                        Text(
                          dateFormat.format(notification.createdAt),
                          style:  AppTypography.withColor(AppTypography.caption, AirbnbColors.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style:  AppTypography.bodySmall.copyWith(color: AirbnbColors.textSecondary, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
    );
  }

  /// 알림 타입별 아이콘/색상 스타일 (3개 switch-case를 단일 Map으로 통합)
  static final Map<String, ({IconData icon, Color color, Color bgColor})> _notificationStyles = {
    'quote_answered': (icon: Icons.mark_email_unread_outlined, color: AirbnbColors.primary, bgColor: AirbnbColors.primary.withValues(alpha: 0.1)),
    'broker_selected': (icon: Icons.check_circle_outline, color: AirbnbColors.success, bgColor: AirbnbColors.success.withValues(alpha: 0.1)),
    'property_registered': (icon: Icons.home_work_outlined, color: AirbnbColors.warning, bgColor: AirbnbColors.warning.withValues(alpha: 0.1)),
    // MLS 거래 관련 알림
    'property_deposit_taken': (icon: Icons.handshake_outlined, color: AirbnbColors.orange, bgColor: AirbnbColors.orange.withValues(alpha: 0.1)),
    'property_sold': (icon: Icons.check_circle, color: AirbnbColors.success, bgColor: AirbnbColors.success.withValues(alpha: 0.1)),
    'property_expired': (icon: Icons.timer_off_outlined, color: AirbnbColors.textSecondary, bgColor: AirbnbColors.textSecondary.withValues(alpha: 0.1)),
    'visit_schedule_approved': (icon: Icons.calendar_today, color: AirbnbColors.primary, bgColor: AirbnbColors.primary.withValues(alpha: 0.1)),
    'visit_schedule_rejected': (icon: Icons.event_busy, color: AirbnbColors.red, bgColor: AirbnbColors.red.withValues(alpha: 0.1)),
    // 매물 승인/삭제/거절
    'property_approved': (icon: Icons.verified_outlined, color: AirbnbColors.success, bgColor: AirbnbColors.success.withValues(alpha: 0.1)),
    'property_rejected': (icon: Icons.cancel_outlined, color: AirbnbColors.red, bgColor: AirbnbColors.red.withValues(alpha: 0.1)),
    'property_deleted': (icon: Icons.delete_outline, color: AirbnbColors.textSecondary, bgColor: AirbnbColors.textSecondary.withValues(alpha: 0.1)),
    // 구매자 문의
    'buyer_inquiry': (icon: Icons.person_add_outlined, color: AirbnbColors.green, bgColor: AirbnbColors.green.withValues(alpha: 0.1)),
    'buyer_inquiry_cancelled': (icon: Icons.person_remove_outlined, color: AirbnbColors.orange, bgColor: AirbnbColors.orange.withValues(alpha: 0.1)),
    // 중개 제안
    'broker_offer': (icon: Icons.handshake_rounded, color: AirbnbColors.primary, bgColor: AirbnbColors.primary.withValues(alpha: 0.1)),
    // 중개사 인증
    'broker_verified': (icon: Icons.verified_user, color: AirbnbColors.success, bgColor: AirbnbColors.success.withValues(alpha: 0.1)),
    'broker_unverified': (icon: Icons.gpp_bad_outlined, color: AirbnbColors.red, bgColor: AirbnbColors.red.withValues(alpha: 0.1)),
    // 방문 관련
    'visit_request': (icon: Icons.door_front_door_outlined, color: AirbnbColors.primary, bgColor: AirbnbColors.primary.withValues(alpha: 0.1)),
    'visit_approved': (icon: Icons.check_circle_outline, color: AirbnbColors.success, bgColor: AirbnbColors.success.withValues(alpha: 0.1)),
    'visit_rejected': (icon: Icons.cancel_outlined, color: AirbnbColors.red, bgColor: AirbnbColors.red.withValues(alpha: 0.1)),
    'visit_confirmed': (icon: Icons.event_available, color: AirbnbColors.success, bgColor: AirbnbColors.success.withValues(alpha: 0.1)),
    'visit_cancelled': (icon: Icons.event_busy, color: AirbnbColors.orange, bgColor: AirbnbColors.orange.withValues(alpha: 0.1)),
    'visit_reschedule_needed': (icon: Icons.schedule, color: AirbnbColors.orange, bgColor: AirbnbColors.orange.withValues(alpha: 0.1)),
    'visit_reschedule': (icon: Icons.update, color: AirbnbColors.orange, bgColor: AirbnbColors.orange.withValues(alpha: 0.1)),
    // 협상 관련
    'counter_offer': (icon: Icons.price_change_outlined, color: AirbnbColors.orange, bgColor: AirbnbColors.orange.withValues(alpha: 0.1)),
    'negotiation_started': (icon: Icons.handshake_outlined, color: AirbnbColors.primary, bgColor: AirbnbColors.primary.withValues(alpha: 0.1)),
    // 상태 변경 알림
    'status_changed_inquiry': (icon: Icons.info_outline, color: AirbnbColors.info, bgColor: AirbnbColors.info.withValues(alpha: 0.1)),
    'status_changed_under_offer': (icon: Icons.trending_up, color: AirbnbColors.purple, bgColor: AirbnbColors.purple.withValues(alpha: 0.1)),
    // 매물 취소
    'property_cancelled': (icon: Icons.block, color: AirbnbColors.textSecondary, bgColor: AirbnbColors.textSecondary.withValues(alpha: 0.1)),
  };

  static const _defaultStyle = (icon: Icons.notifications_outlined, color: AirbnbColors.textSecondary);

  IconData _getIconData(String type) => _notificationStyles[type]?.icon ?? _defaultStyle.icon;
  Color _getIconColor(String type) => _notificationStyles[type]?.color ?? _defaultStyle.color;
  Color _getIconBackgroundColor(String type) => _notificationStyles[type]?.bgColor ?? AirbnbColors.textSecondary.withValues(alpha: 0.1);

  /// 알림 타입에 따라 관련 화면으로 이동
  Future<void> _navigateByNotificationType(NotificationModel notification) async {
    if (_isNavigating) return;

    final relatedId = notification.relatedId;
    if (relatedId == null || relatedId.isEmpty) {
      if (mounted) {
        AppSnackBar.info(context, '상세 정보를 찾을 수 없습니다');
      }
      return;
    }

    // 매물 상세로 이동하는 알림 타입들
    const propertyTypes = {
      NotificationType.propertyRegistered,
      NotificationType.propertyDepositTaken,
      NotificationType.propertySold,
      NotificationType.propertyExpired,
      NotificationType.propertyApproved,
      NotificationType.propertyRejected,
      NotificationType.propertyDeleted,
      NotificationType.propertyCancelled,
      NotificationType.quoteReceived,
      NotificationType.quoteAnswered,
      NotificationType.brokerSelected,
      NotificationType.competitorAdvanced,
      NotificationType.visitScheduleApproved,
      NotificationType.visitScheduleRejected,
      NotificationType.visitRequest,
      NotificationType.visitApproved,
      NotificationType.visitRejected,
      NotificationType.visitConfirmed,
      NotificationType.visitCancelled,
      NotificationType.visitReschedule,
      NotificationType.visitRescheduleNeeded,
      NotificationType.counterOffer,
      NotificationType.negotiationStarted,
      NotificationType.buyerInquiry,
      NotificationType.buyerInquiryCancelled,
      NotificationType.brokerOffer,
      NotificationType.statusChangedToInquiry,
      NotificationType.statusChangedToUnderOffer,
    };

    if (propertyTypes.contains(notification.type)) {
      await _navigateToPropertyDetail(relatedId);
    }
  }

  Future<void> _navigateToPropertyDetail(String propertyId) async {
    if (!mounted || _isNavigating) return;
    _isNavigating = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final property = await MLSPropertyService().getProperty(propertyId);
      if (!mounted) return;
      Navigator.of(context).pop();
      if (property == null) {
        AppSnackBar.info(context, '해당 매물을 찾을 수 없습니다');
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MLSPropertyDetailPage(property: property),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      AppSnackBar.error(context, '매물 정보를 불러오는데 실패했습니다');
    } finally {
      _isNavigating = false;
    }
  }

}
