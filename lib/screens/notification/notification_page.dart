import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/models/notification_model.dart';
import 'package:intl/intl.dart';

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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('모든 알림을 읽음 처리했습니다'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('모두 읽음'),
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
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
                    style: const TextStyle(
                      fontSize: 16,
                      color: AirbnbColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
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
    );
  }

  Widget _buildNotificationItem(NotificationModel notification) {
    final dateFormat = DateFormat('MM.dd HH:mm');

    return InkWell(
        onTap: () {
          if (!notification.isRead) {
            _firebaseService.markNotificationAsRead(notification.id);
          }
          // 알림 타입에 따른 네비게이션 처리
          // 예: if (notification.type == 'quote_answered') ...
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
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.bold,
                              color: AirbnbColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          dateFormat.format(notification.createdAt),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AirbnbColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AirbnbColors.textSecondary,
                        height: 1.4,
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

  IconData _getIconData(String type) {
    switch (type) {
      case 'quote_answered':
        return Icons.mark_email_unread_outlined;
      case 'broker_selected':
        return Icons.check_circle_outline;
      case 'property_registered':
        return Icons.home_work_outlined;
      // MLS 거래 관련 알림
      case 'property_deposit_taken':
        return Icons.handshake_outlined;
      case 'property_sold':
        return Icons.check_circle;
      case 'property_expired':
        return Icons.timer_off_outlined;
      case 'visit_schedule_approved':
        return Icons.calendar_today;
      case 'visit_schedule_rejected':
        return Icons.event_busy;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _getIconColor(String type) {
    switch (type) {
      case 'quote_answered':
        return AirbnbColors.primary;
      case 'broker_selected':
        return AirbnbColors.success;
      case 'property_registered':
        return AirbnbColors.warning;
      // MLS 거래 관련 알림
      case 'property_deposit_taken':
        return Colors.orange;
      case 'property_sold':
        return AirbnbColors.success;
      case 'property_expired':
        return Colors.grey;
      case 'visit_schedule_approved':
        return AirbnbColors.primary;
      case 'visit_schedule_rejected':
        return Colors.red;
      default:
        return AirbnbColors.textSecondary;
    }
  }

  Color _getIconBackgroundColor(String type) {
    switch (type) {
      case 'quote_answered':
        return AirbnbColors.primary.withValues(alpha: 0.1);
      case 'broker_selected':
        return AirbnbColors.success.withValues(alpha: 0.1);
      case 'property_registered':
        return AirbnbColors.warning.withValues(alpha: 0.1);
      // MLS 거래 관련 알림
      case 'property_deposit_taken':
        return Colors.orange.withValues(alpha: 0.1);
      case 'property_sold':
        return AirbnbColors.success.withValues(alpha: 0.1);
      case 'property_expired':
        return Colors.grey.withValues(alpha: 0.1);
      case 'visit_schedule_approved':
        return AirbnbColors.primary.withValues(alpha: 0.1);
      case 'visit_schedule_rejected':
        return Colors.red.withValues(alpha: 0.1);
      default:
        return AirbnbColors.textSecondary.withValues(alpha: 0.1);
    }
  }
}
