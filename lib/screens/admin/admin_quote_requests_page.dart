import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../constants/app_constants.dart';
import '../../services/firebase_service.dart';
import '../../models/quote_request.dart';

/// 관리자 - 견적문의 관리 페이지
class AdminQuoteRequestsPage extends StatefulWidget {
  final String userId;
  final String userName;

  const AdminQuoteRequestsPage({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<AdminQuoteRequestsPage> createState() => _AdminQuoteRequestsPageState();
}

class _AdminQuoteRequestsPageState extends State<AdminQuoteRequestsPage> {
  final FirebaseService _firebaseService = FirebaseService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kBackground,
      body: StreamBuilder<List<QuoteRequest>>(
        stream: _firebaseService.getAllQuoteRequests(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('오류: ${snapshot.error}'),
                ],
              ),
            );
          }

          final quoteRequests = snapshot.data ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 통계 카드
                _buildStatsCards(quoteRequests),
                
                const SizedBox(height: 24),
                
                // 견적문의 목록
                const Text(
                  '💬 견적문의 관리',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.kDarkBrown,
                  ),
                ),
                const SizedBox(height: 16),
                
                if (quoteRequests.isEmpty)
                  _buildEmptyState()
                else
                  ...quoteRequests.map((request) => _buildQuoteRequestCard(request)),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 통계 카드
  Widget _buildStatsCards(List<QuoteRequest> requests) {
    final totalCount = requests.length;
    final pendingCount = requests.where((r) => r.status == 'pending').length;
    final completedCount = requests.where((r) => r.status == 'completed').length;
    
    // 오늘 문의 수
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayCount = requests.where((r) => 
      r.requestDate.isAfter(todayStart)
    ).length;

    return Row(
      children: [
        Expanded(child: _buildStatCard('총 견적문의', totalCount, Icons.email, Colors.blue)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('대기중', pendingCount, Icons.pending_actions, Colors.orange)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('완료', completedCount, Icons.check_circle, Colors.green)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('오늘 문의', todayCount, Icons.today, AppColors.kPrimary)),
      ],
    );
  }

  /// 통계 카드 항목
  Widget _buildStatCard(String label, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// 빈 상태 표시
  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              '견적문의가 없습니다',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '아직 견적문의가 접수되지 않았습니다.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 견적문의 카드
  Widget _buildQuoteRequestCard(QuoteRequest request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.kPrimary, AppColors.kSecondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.business,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.brokerName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '문의일시: ${_formatDateTime(request.requestDate)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(request.status),
              ],
            ),
          ),

          // 내용
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 사용자 정보
                _buildInfoRow(Icons.person, '사용자', request.userName),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.email, '이메일', request.userEmail),
                const SizedBox(height: 8),
                
                // 중개사 정보
                if (request.brokerRoadAddress != null && request.brokerRoadAddress!.isNotEmpty) ...[
                  _buildInfoRow(Icons.location_on, '중개사 주소', request.brokerRoadAddress!),
                  const SizedBox(height: 8),
                ],
                if (request.brokerRegistrationNumber != null && request.brokerRegistrationNumber!.isNotEmpty) ...[
                  _buildInfoRow(Icons.badge, '등록번호', request.brokerRegistrationNumber!),
                  const SizedBox(height: 8),
                ],
                
                // 중개사 이메일 (admin이 첨부한 경우)
                if (request.brokerEmail != null && request.brokerEmail!.isNotEmpty) ...[
                  _buildInfoRow(
                    Icons.email_outlined,
                    '중개사 이메일',
                    request.brokerEmail!,
                    valueColor: AppColors.kSuccess,
                    suffix: ' ✓ 첨부됨',
                  ),
                  const SizedBox(height: 8),
                ],
                
                const Divider(height: 24),
                
                // 문의 내용
                const Text(
                  '💬 문의내용',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.kBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    request.message,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF2C3E50),
                      height: 1.5,
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // 액션 버튼들
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // 이메일 첨부 버튼
                    if (request.brokerEmail == null || request.brokerEmail!.isEmpty)
                      ElevatedButton.icon(
                        onPressed: () => _attachEmail(request),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.attach_email, size: 18),
                        label: const Text('이메일 첨부', style: TextStyle(fontSize: 13)),
                      ),
                    
                    // 상태 변경 버튼
                    if (request.status == 'pending')
                      ElevatedButton.icon(
                        onPressed: () => _updateStatus(request.id, 'contacted'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.phone, size: 18),
                        label: const Text('연락완료', style: TextStyle(fontSize: 13)),
                      ),
                    
                    if (request.status == 'contacted')
                      ElevatedButton.icon(
                        onPressed: () => _updateStatus(request.id, 'completed'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.kSuccess,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: const Text('완료처리', style: TextStyle(fontSize: 13)),
                      ),
                    
                    if (request.status != 'cancelled' && request.status != 'completed')
                      OutlinedButton.icon(
                        onPressed: () => _updateStatus(request.id, 'cancelled'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.cancel, size: 18),
                        label: const Text('취소', style: TextStyle(fontSize: 13)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 상태 배지
  Widget _buildStatusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: QuoteRequest.getStatusColor(status).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: QuoteRequest.getStatusColor(status),
          width: 1.5,
        ),
      ),
      child: Text(
        QuoteRequest(
          id: '',
          userId: '',
          userName: '',
          userEmail: '',
          brokerName: '',
          message: '',
          status: status,
          requestDate: DateTime.now(),
        ).statusText,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: QuoteRequest.getStatusColor(status),
        ),
      ),
    );
  }

  /// 정보 행
  Widget _buildInfoRow(IconData icon, String label, String value, {Color? valueColor, String? suffix}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    color: valueColor ?? const Color(0xFF2C3E50),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (suffix != null)
                Text(
                  suffix,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// 날짜 시간 포맷팅
  String _formatDateTime(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
  }

  /// 이메일 첨부
  Future<void> _attachEmail(QuoteRequest request) async {
    final TextEditingController emailController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${request.brokerName} 이메일 첨부'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '공인중개사의 이메일 주소를 입력하세요:',
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'broker@example.com',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              final email = emailController.text.trim();
              if (email.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('이메일을 입력해주세요')),
                );
                return;
              }
              
              // 이메일 형식 검증
              final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
              if (!emailRegex.hasMatch(email)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('올바른 이메일 형식을 입력해주세요')),
                );
                return;
              }
              
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.kPrimary,
            ),
            child: const Text('첨부'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final email = emailController.text.trim();
      final success = await _firebaseService.attachEmailToBroker(request.id, email);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${request.brokerName}의 이메일이 첨부되었습니다!'),
              backgroundColor: AppColors.kSuccess,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ 이메일 첨부에 실패했습니다. 다시 시도해주세요.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// 상태 업데이트
  Future<void> _updateStatus(String requestId, String newStatus) async {
    final success = await _firebaseService.updateQuoteRequestStatus(requestId, newStatus);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 상태가 업데이트되었습니다!'),
            backgroundColor: AppColors.kSuccess,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ 상태 업데이트에 실패했습니다. 다시 시도해주세요.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

