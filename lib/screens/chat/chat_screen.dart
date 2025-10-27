import 'package:flutter/material.dart';
import 'package:property/models/property.dart';
import 'package:property/models/chat_message.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/constants/app_constants.dart';

class ChatScreen extends StatefulWidget {
  final Property property;
  final String currentUserId;
  final String currentUserName;

  const ChatScreen({
    super.key,
    required this.property,
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseService _firebaseService = FirebaseService();
  Stream<List<ChatMessage>>? _chatStream;

  @override
  void initState() {
    super.initState();
    _chatStream = _firebaseService.getChatMessagesForProperty(widget.property.firestoreId ?? '');
    
    // 채팅 화면에 들어오면 모든 메시지를 읽음 처리
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markAllMessagesAsRead();
    });
  }

  Future<void> _markAllMessagesAsRead() async {
    try {
      final messages = await _firebaseService.getChatMessagesForProperty(widget.property.firestoreId ?? '').first;
      for (final message in messages) {
        if (message.receiverId == widget.currentUserId && !message.isRead && message.id != null) {
          await _firebaseService.markMessageAsRead(message.id!);
        }
      }
    } catch (e) {
      print('메시지 읽음 처리 중 오류: $e');
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    // 매물 등록자 정보 가져오기 (사용자 정보 필드 사용)
    final receiverId = widget.property.userMainContractor ?? widget.property.registeredBy ?? '';
    final receiverName = widget.property.userMainContractor ?? widget.property.registeredByName ?? '';

    // 디버그: 수신자 정보 확인
    print('🔍 [ChatScreen] 메시지 전송:');
    print('   - senderId: ${widget.currentUserId}');
    print('   - senderName: ${widget.currentUserName}');
    print('   - receiverId: $receiverId');
    print('   - receiverName: $receiverName');
    print('   - propertyId: ${widget.property.firestoreId}');
    print('   - message: $message');

    final chatMessage = ChatMessage(
      senderId: widget.currentUserId,
      senderName: widget.currentUserName,
      receiverId: receiverId,
      receiverName: receiverName,
      propertyId: widget.property.firestoreId ?? '',
      propertyAddress: widget.property.address,
      message: message,
    );

    final success = await _firebaseService.sendChatMessage(chatMessage);
    
    if (success != null) {
      _messageController.clear();
      _scrollToBottom();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('메시지 전송에 실패했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.property.address,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              '등록자: ${widget.property.userMainContractor ?? widget.property.registeredByName ?? '알 수 없음'}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        backgroundColor: AppColors.kBrown,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 채팅 메시지 영역
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
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
                              _chatStream = _firebaseService.getChatMessagesForProperty(widget.property.firestoreId ?? '');
                            });
                          },
                          child: const Text('다시 시도'),
                        ),
                      ],
                    ),
                  );
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          '아직 메시지가 없습니다.',
                          style: TextStyle(color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '첫 번째 메시지를 보내보세요!',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMyMessage = message.senderId == widget.currentUserId;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: isMyMessage 
                            ? MainAxisAlignment.end 
                            : MainAxisAlignment.start,
                        children: [
                          if (!isMyMessage) ...[
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: AppColors.kBrown.withValues(alpha:0.2),
                              child: Text(
                                message.senderName.isNotEmpty 
                                    ? message.senderName[0] 
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.kBrown,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isMyMessage 
                                    ? AppColors.kBrown 
                                    : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Column(
                                crossAxisAlignment: isMyMessage 
                                    ? CrossAxisAlignment.end 
                                    : CrossAxisAlignment.start,
                                children: [
                                  if (!isMyMessage)
                                    Text(
                                      message.senderName,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    message.message,
                                    style: TextStyle(
                                      color: isMyMessage ? Colors.white : Colors.black87,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatTime(message.timestamp),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isMyMessage 
                                          ? Colors.white.withValues(alpha:0.7) 
                                          : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (isMyMessage) ...[
                            const SizedBox(width: 8),
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: AppColors.kBrown,
                              child: Text(
                                message.senderName.isNotEmpty 
                                    ? message.senderName[0] 
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // 메시지 입력 영역
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha:0.2),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: '메시지를 입력하세요...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(24)),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(
                    color: AppColors.kBrown,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.send, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 