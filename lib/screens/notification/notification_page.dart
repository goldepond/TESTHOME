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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kBackground,
      appBar: AppBar(
        title: const Text(
          '알림 센터',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: Colors.black87,
        actions: [
          TextButton(
            onPressed: () async {
              await _firebaseService.markAllNotificationsAsRead(widget.userId);
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

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    '새로운 알림이 없습니다',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
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
    
    return Dismissible(
      key: Key(notification.id),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        // 실제 삭제 기능은 FirebaseService에 추가 필요 (여기서는 UI만 처리하거나 생략)
        // 이번 구현에서는 읽음 처리만 하므로 스와이프 삭제는 비활성화하거나 추가 구현
      },
      confirmDismiss: (direction) async {
        // 읽음 처리만 하고 삭제는 안 함 (또는 삭제 기능 추가)
        // 여기서는 스와이프로 읽음 처리한다고 가정하거나 막아둠
        return false; 
      },
      child: InkWell(
        onTap: () {
          if (!notification.isRead) {
            _firebaseService.markNotificationAsRead(notification.id);
          }
          // 알림 타입에 따른 네비게이션 처리
          // 예: if (notification.type == 'quote_answered') ...
        },
        child: Container(
          color: notification.isRead ? Colors.white : Colors.blue.withValues(alpha: 0.05),
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
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Text(
                          dateFormat.format(notification.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _getIconColor(String type) {
    switch (type) {
      case 'quote_answered':
        return Colors.blue;
      case 'broker_selected':
        return Colors.green;
      case 'property_registered':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Color _getIconBackgroundColor(String type) {
    switch (type) {
      case 'quote_answered':
        return Colors.blue.withValues(alpha: 0.1);
      case 'broker_selected':
        return Colors.green.withValues(alpha: 0.1);
      case 'property_registered':
        return Colors.orange.withValues(alpha: 0.1);
      default:
        return Colors.grey.withValues(alpha: 0.1);
    }
  }
}

