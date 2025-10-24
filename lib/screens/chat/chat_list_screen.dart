import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';
import '../../models/chat_message.dart';
import '../../models/property.dart';
import '../../services/firebase_service.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;

  const ChatListScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  Stream<List<ChatMessage>>? _chatStream;

  @override
  void initState() {
    super.initState();
    _chatStream = _firebaseService.getAllUserMessages(widget.currentUserId);
    
    // 디버그: 채팅 스트림 설정 확인
    print('🔍 [ChatListScreen] 초기화:');
    print('   - currentUserId: ${widget.currentUserId}');
    print('   - currentUserName: ${widget.currentUserName}');
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${difference.inDays}일 전';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}시간 전';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}분 전';
    } else {
      return '방금 전';
    }
  }

  String _getChatTitle(ChatMessage message) {
    if (message.senderId == widget.currentUserId) {
      return message.receiverName;
    } else {
      return message.senderName;
    }
  }

  String _getLastMessage(List<ChatMessage> messages) {
    if (messages.isEmpty) return '';
    return messages.last.message;
  }

  Map<String, List<ChatMessage>> _groupMessagesByProperty(List<ChatMessage> messages) {
    final Map<String, List<ChatMessage>> grouped = {};
    
    for (final message in messages) {
      final key = message.propertyId;
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(message);
    }
    
    // 각 그룹 내에서 시간순 정렬
    for (final key in grouped.keys) {
      grouped[key]!.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    }
    
    return grouped;
  }

  int _getUnreadCount(List<ChatMessage> messages) {
    return messages.where((msg) => 
      msg.receiverId == widget.currentUserId && !msg.isRead
    ).length;
  }

  // 채팅 삭제 확인 다이얼로그
  void _showDeleteDialog(String propertyId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('채팅 삭제'),
          content: const Text('이 채팅 대화를 삭제하시겠습니까?\n삭제된 채팅은 복구할 수 없습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteChatConversation(propertyId);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );
  }

  // 채팅 대화 삭제 실행
  Future<void> _deleteChatConversation(String propertyId) async {
    try {
      final success = await _firebaseService.deleteChatConversation(propertyId);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('채팅 대화가 삭제되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('채팅 삭제에 실패했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<ChatMessage>>(
        stream: _chatStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('오류가 발생했습니다: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _chatStream = _firebaseService.getAllUserMessages(widget.currentUserId);
                      });
                    },
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            );
          }

          final messages = snapshot.data ?? [];
          final groupedMessages = _groupMessagesByProperty(messages);

          // 디버그: 메시지 로딩 확인
          print('🔍 [ChatListScreen] 메시지 로딩:');
          print('   - 전체 메시지 수: ${messages.length}');
          print('   - 그룹화된 채팅 수: ${groupedMessages.length}');
          for (final message in messages.take(3)) {
            print('   - 메시지: ${message.senderId} -> ${message.receiverId} (${message.message})');
          }

          if (groupedMessages.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    '아직 채팅이 없습니다.',
                    style: TextStyle(color: Colors.grey, fontSize: 18),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '매물을 보고 등록자에게 문의해보세요!',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groupedMessages.length,
            itemBuilder: (context, index) {
              final propertyId = groupedMessages.keys.elementAt(index);
              final propertyMessages = groupedMessages[propertyId]!;
              final lastMessage = propertyMessages.last;
              final chatTitle = _getChatTitle(lastMessage);
              final isMyMessage = lastMessage.senderId == widget.currentUserId;
              final unreadCount = _getUnreadCount(propertyMessages);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.kBrown.withValues(alpha:0.2),
                    child: Text(
                      chatTitle.isNotEmpty ? chatTitle[0] : '?',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.kBrown,
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          chatTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        lastMessage.propertyAddress,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _getLastMessage(propertyMessages),
                        style: TextStyle(
                          fontSize: 14,
                          color: isMyMessage ? Colors.grey : Colors.black87,
                          fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(lastMessage.timestamp),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _showDeleteDialog(propertyId),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha:0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    // 임시 Property 객체 생성 (채팅 화면에서 필요)
                    final tempProperty = Property(
                      address: lastMessage.propertyAddress,
                      transactionType: '매매',
                      price: 0,
                      mainContractor: isMyMessage ? lastMessage.receiverName : lastMessage.senderName,
                      firestoreId: lastMessage.propertyId,
                    );

                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          property: tempProperty,
                          currentUserId: widget.currentUserId,
                          currentUserName: widget.currentUserName,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
} 