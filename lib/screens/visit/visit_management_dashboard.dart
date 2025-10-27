import 'package:flutter/material.dart';
import 'package:property/models/visit_request.dart';
import 'package:property/models/property.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/screens/chat/chat_screen.dart';

class VisitManagementDashboard extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;

  const VisitManagementDashboard({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  State<VisitManagementDashboard> createState() => _VisitManagementDashboardState();
}

class _VisitManagementDashboardState extends State<VisitManagementDashboard>
    with SingleTickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  late TabController _tabController;
  Stream<List<VisitRequest>>? _sellerRequestsStream;
  Stream<List<VisitRequest>>? _buyerRequestsStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _sellerRequestsStream = _firebaseService.getSellerVisitRequests(widget.currentUserId);
    _buyerRequestsStream = _firebaseService.getBuyerVisitRequests(widget.currentUserId);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleStatusUpdate(VisitRequest request, String newStatus) async {
    try {
      final success = await _firebaseService.updateVisitRequestStatus(
        request.id!,
        newStatus,
        confirmedBy: widget.currentUserName,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == 'confirmed' ? '방문 신청을 수락했습니다.' : '방문 신청을 거절했습니다.',
            ),
            backgroundColor: newStatus == 'confirmed' ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('상태 업데이트 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showVisitRequestDetail(VisitRequest request) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('방문 신청 상세'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('매물 주소', request.propertyAddress),
              _buildDetailRow('방문 시간', request.getFormattedVisitTime()),
              _buildDetailRow('신청 시간', request.getFormattedRequestTime()),
              _buildDetailRow('상태', request.getStatusText()),
              if (request.lastMessage != null)
                _buildDetailRow('메시지', request.lastMessage!),
              if (request.notes != null)
                _buildDetailRow('추가 메모', request.notes!),
              if (request.confirmedAt != null)
                _buildDetailRow('확정 시간', '${request.confirmedAt!.year}년 ${request.confirmedAt!.month}월 ${request.confirmedAt!.day}일'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  void _navigateToChat(VisitRequest request) {
    // 임시 Property 객체 생성 (채팅 화면에서 필요)
    final tempProperty = Property(
      address: request.propertyAddress,
      transactionType: '매매',
      price: 0,
      mainContractor: request.sellerName,
      firestoreId: request.propertyId,
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
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildVisitRequestCard(VisitRequest request, bool isSeller) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: request.getStatusColor().withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: request.getStatusColor()),
                  ),
                  child: Text(
                    request.getStatusText(),
                    style: TextStyle(
                      color: request.getStatusColor(),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  request.getFormattedRequestTime(),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 매물 정보
            Row(
              children: [
                Icon(Icons.home, color: AppColors.kBrown, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    request.propertyAddress,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // 방문 시간
            Row(
              children: [
                Icon(Icons.access_time, color: Colors.grey, size: 14),
                const SizedBox(width: 6),
                Text(
                  request.getFormattedVisitTime(),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // 상대방 정보
            Row(
              children: [
                Icon(Icons.person, color: Colors.grey, size: 14),
                const SizedBox(width: 6),
                Text(
                  isSeller ? '구매자: ${request.buyerName}' : '판매자: ${request.sellerName}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),

            // 메시지가 있는 경우
            if (request.lastMessage != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '방문 신청 메시지:',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      request.lastMessage!,
                      style: const TextStyle(fontSize: 12),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 10),

            // 액션 버튼들
            Row(
              children: [
                // 상세보기 버튼
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: OutlinedButton.icon(
                      onPressed: () => _showVisitRequestDetail(request),
                      icon: const Icon(Icons.info_outline, size: 14),
                      label: const Text(
                        '상세보기',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.kBrown,
                        side: BorderSide(color: AppColors.kBrown),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // 채팅 버튼
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: OutlinedButton.icon(
                      onPressed: () => _navigateToChat(request),
                      icon: const Icon(Icons.chat_bubble_outline, size: 14),
                      label: const Text(
                        '채팅',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        side: BorderSide(color: Colors.blue),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // 상태별 액션 버튼
                if (request.status == 'pending') ...[
                  if (isSeller) ...[
                    // 판매자: 수락/거절 버튼
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: ElevatedButton.icon(
                          onPressed: () => _handleStatusUpdate(request, 'confirmed'),
                          icon: const Icon(Icons.check, size: 14),
                          label: const Text(
                            '수락',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: ElevatedButton.icon(
                          onPressed: () => _handleStatusUpdate(request, 'rejected'),
                          icon: const Icon(Icons.close, size: 14),
                          label: const Text(
                            '거절',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    // 구매자: 취소 버튼
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: ElevatedButton.icon(
                          onPressed: () => _handleStatusUpdate(request, 'rejected'),
                          icon: const Icon(Icons.cancel, size: 14),
                          label: const Text(
                            '취소',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ] else if (request.status == 'confirmed') ...[
                  // 확정된 경우: 완료 버튼
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: ElevatedButton.icon(
                        onPressed: () => _handleStatusUpdate(request, 'completed'),
                        icon: const Icon(Icons.done_all, size: 14),
                        label: const Text(
                          '완료',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            color: AppColors.kBrown,
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: const [
                Tab(text: '받은 신청'),
                Tab(text: '보낸 신청'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 받은 신청 (판매자용)
                StreamBuilder<List<VisitRequest>>(
                  stream: _sellerRequestsStream,
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
                          ],
                        ),
                      );
                    }

                    final requests = snapshot.data ?? [];

                    if (requests.isEmpty) {
                      return _buildEmptyState(
                        '아직 받은 방문 신청이 없습니다.\n매물을 등록하면 방문 신청을 받을 수 있습니다.',
                        Icons.home_outlined,
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: requests.length,
                      itemBuilder: (context, index) {
                        return _buildVisitRequestCard(requests[index], true);
                      },
                    );
                  },
                ),

                // 보낸 신청 (구매자용)
                StreamBuilder<List<VisitRequest>>(
                  stream: _buyerRequestsStream,
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
                          ],
                        ),
                      );
                    }

                    final requests = snapshot.data ?? [];

                    if (requests.isEmpty) {
                      return _buildEmptyState(
                        '아직 보낸 방문 신청이 없습니다.\n관심 있는 매물에 방문 신청을 해보세요.',
                        Icons.send_outlined,
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: requests.length,
                      itemBuilder: (context, index) {
                        return _buildVisitRequestCard(requests[index], false);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 