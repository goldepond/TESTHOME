import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/constants/typography.dart';
import 'package:property/constants/spacing.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/models/quote_request.dart';
import 'package:property/constants/status_constants.dart';
import 'package:property/utils/validation_utils.dart';
import 'package:url_launcher/url_launcher.dart';

/// 관리자 - 견적문의 관리 페이지
class AdminQuoteRequestsPage extends StatefulWidget {
  final String userId;
  final String userName;

  const AdminQuoteRequestsPage({
    required this.userId, required this.userName, super.key,
  });

  @override
  State<AdminQuoteRequestsPage> createState() => _AdminQuoteRequestsPageState();
}

class _AdminQuoteRequestsPageState extends State<AdminQuoteRequestsPage> {
  final FirebaseService _firebaseService = FirebaseService();
  
  // 필터/정렬 상태
  String _statusFilter = 'all'; // all, pending, contacted, answered, completed, cancelled
  String _periodFilter = 'all'; // today, 7d, 30d, all (기본값: 전체)
  String _sortOption = 'newest'; // newest, oldest
  final TextEditingController _regionController = TextEditingController(); // 지역/주소 키워드

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
      backgroundColor: AirbnbColors.surface,
        resizeToAvoidBottomInset: true,
      body: StreamBuilder<List<QuoteRequest>>(
        stream: _firebaseService.getAllQuoteRequests(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AirbnbColors.primary),
                  ),
                  SizedBox(height: AppSpacing.md),
                  Text(
                    '견적문의를 불러오는 중...',
                    style: TextStyle(
                      color: AirbnbColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: AirbnbColors.error),
                  const SizedBox(height: AppSpacing.md),
                  Text('오류: ${snapshot.error}'),
                ],
              ),
            );
          }

          final quoteRequests = snapshot.data ?? [];
          
          // 필터링
          final filtered = _applyFilters(quoteRequests);
          // 정렬
          final sorted = _applySorting(filtered);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 통계 카드
                _buildStatsCards(quoteRequests),
                
                const SizedBox(height: 24),
                
                // 필터바
                _buildFilterBar(),
                
                // 견적문의 목록
                Text(
                  '💬 견적문의 관리 (${sorted.length}/${quoteRequests.length}개)',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AirbnbColors.primaryHover,
                  ),
                ),
                const SizedBox(height: 16),

                if (sorted.isEmpty)
                  _buildEmptyState()
                else
                  ...sorted.map((request) => _buildQuoteRequestCard(request)),
              ],
            ),
          );
        },
        ),
      ),
    );
  }
  
  List<QuoteRequest> _applyFilters(List<QuoteRequest> list) {
    DateTime? since;
    final now = DateTime.now();
    switch (_periodFilter) {
      case 'today':
        since = DateTime(now.year, now.month, now.day);
        break;
      case '7d':
        since = now.subtract(const Duration(days: 7));
        break;
      case '30d':
        since = now.subtract(const Duration(days: 30));
        break;
      case 'all':
      default:
        since = null;
    }
    
    return list.where((r) {
      // 상태 필터
      final statusOk = _statusFilter == 'all' ? true : r.status == _statusFilter;
      // 기간 필터
      final periodOk = since == null ? true : r.requestDate.isAfter(since);
      // 지역/주소 키워드
      final region = _regionController.text.trim();
      final regionOk = region.isEmpty
          ? true
          : ((r.propertyAddress ?? '').toLowerCase().contains(region.toLowerCase()) ||
             (r.brokerRoadAddress ?? '').toLowerCase().contains(region.toLowerCase()));
      return statusOk && periodOk && regionOk;
    }).toList();
  }
  
  List<QuoteRequest> _applySorting(List<QuoteRequest> list) {
    final result = [...list];
    result.sort((a, b) {
      if (_sortOption == 'oldest') {
        return a.requestDate.compareTo(b.requestDate);
      }
      // newest default
      return b.requestDate.compareTo(a.requestDate);
    });
    return result;
  }
  
  Widget _buildFilterBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AirbnbColors.background,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AirbnbColors.textPrimary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Wrap(
        runSpacing: 8,
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // 상태 탭
          DropdownButton<String>(
            value: _statusFilter,
            items: const [
              DropdownMenuItem(value: 'all', child: Text('상태: 전체')),
              DropdownMenuItem(value: 'pending', child: Text('대기중')),
              DropdownMenuItem(value: 'contacted', child: Text('연락완료')),
              DropdownMenuItem(value: 'answered', child: Text('답변완료')),
              DropdownMenuItem(value: 'completed', child: Text('완료')),
              DropdownMenuItem(value: 'cancelled', child: Text('취소됨')),
            ],
            onChanged: (v) => setState(() => _statusFilter = v ?? 'all'),
          ),
          // 기간 필터
          DropdownButton<String>(
            value: _periodFilter,
            items: const [
              DropdownMenuItem(value: 'today', child: Text('기간: 오늘')),
              DropdownMenuItem(value: '7d', child: Text('7일')),
              DropdownMenuItem(value: '30d', child: Text('30일')),
              DropdownMenuItem(value: 'all', child: Text('전체')),
            ],
            onChanged: (v) => setState(() => _periodFilter = v ?? '7d'),
          ),
          // 정렬
          DropdownButton<String>(
            value: _sortOption,
            items: const [
              DropdownMenuItem(value: 'newest', child: Text('정렬: 최신순')),
              DropdownMenuItem(value: 'oldest', child: Text('정렬: 오래된순')),
            ],
            onChanged: (v) => setState(() => _sortOption = v ?? 'newest'),
          ),
          // 지역/주소 키워드
          SizedBox(
            width: 220,
            child: TextField(
              controller: _regionController,
              decoration: InputDecoration(
                hintText: '지역/주소 검색',
                prefixIcon: const Icon(Icons.location_on_outlined),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
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
        Expanded(child: _buildStatCard('총 견적문의', totalCount, Icons.email, AirbnbColors.primary)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('대기중', pendingCount, Icons.pending_actions, AirbnbColors.warning)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('완료', completedCount, Icons.check_circle, AirbnbColors.success)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('오늘 문의', todayCount, Icons.today, AirbnbColors.primary)),
      ],
    );
  }

  /// 통계 카드 항목
  Widget _buildStatCard(String label, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AirbnbColors.background,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AirbnbColors.textSecondary.withValues(alpha: 0.1),
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
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: const TextStyle(
              color: AirbnbColors.textSecondary,
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
        color: AirbnbColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: AirbnbColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              '견적문의가 없습니다',
              style: AppTypography.withColor(
                AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                AirbnbColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '아직 견적문의가 접수되지 않았습니다.',
              style: TextStyle(
                color: AirbnbColors.textSecondary,
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
        color: AirbnbColors.background,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AirbnbColors.textSecondary.withValues(alpha: 0.1),
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
                decoration: const BoxDecoration(
                  color: AirbnbColors.background,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AirbnbColors.background.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.business,
                    color: AirbnbColors.background,
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
                        style: AppTypography.withColor(
                          AppTypography.body.copyWith(fontWeight: FontWeight.bold),
                          AirbnbColors.background,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '문의일시: ${_formatDateTime(request.requestDate)}',
                        style: const TextStyle(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(request),
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
                    valueColor: AirbnbColors.success,
                    suffix: ' ✓ 첨부됨',
                  ),
                  const SizedBox(height: 8),
                ],
                
                // 매물 정보 (있는 경우)
                if (request.propertyAddress != null && request.propertyAddress!.isNotEmpty) ...[
                  const Divider(height: 24),
                  _buildInfoRow(Icons.home, '매물 주소', request.propertyAddress!),
                  const SizedBox(height: 8),
                ],
                if (request.propertyArea != null && request.propertyArea!.isNotEmpty) ...[
                  _buildInfoRow(Icons.square_foot, '전용면적', '${request.propertyArea}㎡'),
                  const SizedBox(height: 8),
                ],
                if (request.propertyType != null && request.propertyType!.isNotEmpty) ...[
                  _buildInfoRow(Icons.category, '매물 유형', request.propertyType!),
                  const SizedBox(height: 8),
                ],
                
                const Divider(height: 24),
                
                // 문의 내용
                const Text(
                  '💬 문의내용',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AirbnbColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AirbnbColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AirbnbColors.textSecondary.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    request.message,
                    style: const TextStyle(
                      color: AirbnbColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ),
                
                // 특이사항 (입력된 경우에만 표시)
                if (request.hasTenant != null || 
                    request.desiredPrice != null || 
                    request.targetPeriod != null || 
                    (request.specialNotes != null && request.specialNotes!.isNotEmpty)) ...[
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    '📝 특이사항',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AirbnbColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AirbnbColors.warning.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AirbnbColors.warning.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (request.hasTenant != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                const Text(
                                  '세입자 여부: ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AirbnbColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  request.hasTenant! ? '있음' : '없음',
                                  style: const TextStyle(
                                    color: AirbnbColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (request.desiredPrice != null && request.desiredPrice!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '희망가: ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AirbnbColors.textPrimary,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    request.desiredPrice!,
                                    style: const TextStyle(
                                      color: AirbnbColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (request.targetPeriod != null && request.targetPeriod!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '목표기간: ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AirbnbColors.textPrimary,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    request.targetPeriod!,
                                    style: const TextStyle(
                                      color: AirbnbColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (request.specialNotes != null && request.specialNotes!.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                            child: Text(
                              '특이사항:',
                              style: AppTypography.withColor(
                                AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                                AirbnbColors.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            request.specialNotes!,
                            style: const TextStyle(
                              color: AirbnbColors.textPrimary,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                
                // 공인중개사 답변 (있는 경우)
                if (request.brokerAnswer != null && request.brokerAnswer!.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Divider(height: 24),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AirbnbColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AirbnbColors.primary.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AirbnbColors.primary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.reply, size: 16, color: AirbnbColors.primary),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '✅ 공인중개사 답변',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AirbnbColors.primary,
                              ),
                            ),
                            if (request.answerDate != null) ...[
                              const Spacer(),
                              Text(
                                _formatDateTime(request.answerDate!),
                                style: AppTypography.withColor(
                                  AppTypography.caption,
                                  AirbnbColors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AirbnbColors.background.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AirbnbColors.primary.withValues(alpha: 0.2)),
                          ),
                          child: Text(
                            request.brokerAnswer!,
                            style: const TextStyle(
                              color: AirbnbColors.textPrimary,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
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
                          backgroundColor: AirbnbColors.textPrimary, // 에어비엔비 스타일: 검은색 배경
                          foregroundColor: AirbnbColors.background,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.attach_email, size: 18),
                        label: const Text('이메일 첨부', style: AppTypography.bodySmall),
                      ),

                    // 링크 복사 버튼 (항상 표시)
                    OutlinedButton.icon(
                      onPressed: () => _copyInquiryLink(request),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AirbnbColors.primary,
                        side: const BorderSide(color: AirbnbColors.primary),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.link, size: 18),
                      label: const Text('링크 복사', style: TextStyle(fontSize: 13)),
                    ),
                    
                    // 이메일 보내기 버튼 (이메일이 첨부된 경우)
                    if (request.brokerEmail != null && request.brokerEmail!.isNotEmpty)
                      ElevatedButton.icon(
                        onPressed: () => _sendInquiryEmail(request),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AirbnbColors.textPrimary, // 에어비엔비 스타일: 검은색 배경
                          foregroundColor: AirbnbColors.background,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.email, size: 18),
                        label: const Text('이메일 보내기', style: AppTypography.bodySmall),
                      ),
                    
                    // 상태 변경 버튼
                    if (request.status == 'pending')
                      ElevatedButton.icon(
                        onPressed: () => _updateStatus(request.id, 'contacted'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AirbnbColors.textPrimary, // 에어비엔비 스타일: 검은색 배경
                          foregroundColor: AirbnbColors.background,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.phone, size: 18),
                        label: const Text('연락완료', style: AppTypography.bodySmall),
                      ),
                    
                    if (request.status == 'contacted')
                      ElevatedButton.icon(
                        onPressed: () => _updateStatus(request.id, 'completed'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AirbnbColors.success,
                          foregroundColor: AirbnbColors.background,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: const Text('완료처리', style: AppTypography.bodySmall),
                      ),
                    
                    if (request.status != 'cancelled' && request.status != 'completed')
                      OutlinedButton.icon(
                        onPressed: () => _updateStatus(request.id, 'cancelled'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AirbnbColors.error,
                          side: const BorderSide(color: AirbnbColors.error),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.cancel, size: 18),
                        label: const Text('취소', style: TextStyle(fontSize: 13)),
                      ),

                    // 삭제 버튼 (항상 표시)
                    OutlinedButton.icon(
                      onPressed: () => _showDeleteConfirmDialog(request),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AirbnbColors.error,
                        side: const BorderSide(color: AirbnbColors.error),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('삭제', style: TextStyle(fontSize: 13)),
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

  /// 상태 배지 (라이프사이클 기준)
  Widget _buildStatusBadge(QuoteRequest request) {
    final lifecycle = QuoteLifecycleStatus.fromQuote(request);
    final color = QuoteLifecycleStatus.color(lifecycle);
    final label = QuoteLifecycleStatus.label(lifecycle);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + AppSpacing.xs, vertical: AppSpacing.xs + AppSpacing.xs / 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color,
          width: 1.5,
        ),
      ),
      child: Text(
        label,
        style: AppTypography.withColor(
          AppTypography.caption.copyWith(fontWeight: FontWeight.w600),
          color,
        ),
      ),
    );
  }

  /// 정보 행
  Widget _buildInfoRow(IconData icon, String label, String value, {Color? valueColor, String? suffix}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AirbnbColors.textSecondary),
        const SizedBox(width: 8),
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AirbnbColors.textSecondary,
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
                    color: valueColor ?? AirbnbColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (suffix != null)
                Text(
                  suffix,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AirbnbColors.textSecondary,
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
            const Text(
              '공인중개사의 이메일 주소를 입력하세요:',
              style: TextStyle(fontSize: 14, color: AirbnbColors.textSecondary),
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
              if (!ValidationUtils.isValidEmail(email)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('올바른 이메일 형식을 입력해주세요')),
                );
                return;
              }
              
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AirbnbColors.textPrimary, // 에어비엔비 스타일: 검은색 배경
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
              backgroundColor: AirbnbColors.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ 이메일 첨부에 실패했습니다. 다시 시도해주세요.'),
              backgroundColor: AirbnbColors.error,
            ),
          );
        }
      }
    }
  }

  /// 이메일 보내기 (mailto 링크)
  Future<void> _sendInquiryEmail(QuoteRequest request) async {
    // 고유 링크 ID 생성 (이미 있으면 재사용)
    final String linkId = request.inquiryLinkId ?? _generateLinkId();
    
    // 링크 ID가 없으면 Firestore에 저장
    if (request.inquiryLinkId == null || request.inquiryLinkId!.isEmpty) {
      await _firebaseService.updateQuoteRequestLinkId(request.id, linkId);
    }
    
    // 배포된 URL (실제 배포 후 변경 필요)
    const baseUrl = 'https://goldepond.github.io/TESTHOME';
    final inquiryUrl = '$baseUrl/#/inquiry/$linkId';
    
    // 이메일 제목
    final subject = Uri.encodeComponent('부동산 문의 안내 - ${request.propertyAddress ?? request.brokerName}');
    
    // 특이사항 텍스트 생성
    String specialNotesText = '';
    if (request.hasTenant != null || 
        request.desiredPrice != null || 
        request.targetPeriod != null || 
        (request.specialNotes != null && request.specialNotes!.isNotEmpty)) {
      specialNotesText = '\n┌─────────────────────────────────\n📝 특이사항\n├─────────────────────────────────';
      if (request.hasTenant != null) {
        specialNotesText += '\n• 세입자 여부: ${request.hasTenant! ? '있음' : '없음'}';
      }
      if (request.desiredPrice != null && request.desiredPrice!.isNotEmpty) {
        specialNotesText += '\n• 희망가: ${request.desiredPrice!}';
      }
      if (request.targetPeriod != null && request.targetPeriod!.isNotEmpty) {
        specialNotesText += '\n• 목표기간: ${request.targetPeriod!}';
      }
      if (request.specialNotes != null && request.specialNotes!.isNotEmpty) {
        specialNotesText += '\n• 특이사항: ${request.specialNotes!}';
      }
    }
    
    // 이메일 본문
    final body = Uri.encodeComponent('''
안녕하세요, ${request.brokerName}님.

MyHome 플랫폼에서 부동산 문의가 접수되었습니다.

┌─────────────────────────────────
📌 문의 정보
├─────────────────────────────────
• 문의자: ${request.userName}
• 매물 주소: ${request.propertyAddress ?? '미지정'}
• 전용면적: ${request.propertyArea ?? '-'}㎡
• 문의 유형: ${request.propertyType ?? '-'}

┌─────────────────────────────────
💬 문의 내용
├─────────────────────────────────
${request.message}$specialNotesText

┌─────────────────────────────────
📝 답변하기
├─────────────────────────────────
아래 링크를 클릭하시면 답변을 작성하실 수 있어요:
$inquiryUrl

※ 이 링크는 7일간 유효합니다.
※ 답변은 즉시 고객님께 전달됩니다.
    ''');
    
    // mailto URL 생성
    final mailtoUrl = 'mailto:${request.brokerEmail}?subject=$subject&body=$body';
    
    // 이메일 클라이언트 열기
    final uri = Uri.parse(mailtoUrl);
    final success = await launchUrl(uri);
    
    if (mounted && !success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ 이메일 앱을 열 수 없습니다. 이메일 주소를 확인해주세요.'),
          backgroundColor: AirbnbColors.error,
        ),
      );
    }
  }

  /// 문의 링크 복사 (관리자 수동 공유용)
  Future<void> _copyInquiryLink(QuoteRequest request) async {
    try {
      // 링크 ID 생성 또는 재사용
      final String linkId = request.inquiryLinkId ?? _generateLinkId();
      if (request.inquiryLinkId == null || request.inquiryLinkId!.isEmpty) {
        await _firebaseService.updateQuoteRequestLinkId(request.id, linkId);
      }

      const baseUrl = 'https://goldepond.github.io/TESTHOME';
      final inquiryUrl = '$baseUrl/#/inquiry/$linkId';

      await Clipboard.setData(ClipboardData(text: inquiryUrl));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 링크가 클립보드에 복사되었습니다.'),
            backgroundColor: AirbnbColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('링크 복사에 실패했습니다. 잠시 후 다시 시도해 주세요.'),
            backgroundColor: AirbnbColors.error,
          ),
        );
      }
    }
  }
  
  /// 고유 링크 ID 생성
  String _generateLinkId() {
    final random = DateTime.now().millisecondsSinceEpoch;
    final hash = random.hashCode.toString().substring(1, 9);
    return 'inq_$hash';
  }

  /// 상태 업데이트
  Future<void> _updateStatus(String requestId, String newStatus) async {
    final success = await _firebaseService.updateQuoteRequestStatus(requestId, newStatus);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 상태가 업데이트되었습니다!'),
            backgroundColor: AirbnbColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ 상태 업데이트에 실패했습니다. 다시 시도해주세요.'),
            backgroundColor: AirbnbColors.error,
          ),
        );
      }
    }
  }

  /// 견적문의 삭제 확인 다이얼로그 (사유 입력 포함)
  Future<void> _showDeleteConfirmDialog(QuoteRequest request) async {
    final reasonController = TextEditingController();
    String selectedReason = '잘못된 정보';

    final result = await showDialog<String?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('견적문의 삭제'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('정말로 이 견적문의를 삭제하시겠습니까?'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AirbnbColors.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('문의자: ${request.userName}', style: const TextStyle(fontSize: 13)),
                      Text('중개사: ${request.brokerName}', style: const TextStyle(fontSize: 13)),
                      Text('문의일: ${_formatDateTime(request.requestDate)}', style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '삭제 사유 선택',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                // 사유 선택 드롭다운
                DropdownButtonFormField<String>(
                  initialValue: selectedReason,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: '잘못된 정보', child: Text('잘못된 정보')),
                    DropdownMenuItem(value: '중복 문의', child: Text('중복 문의')),
                    DropdownMenuItem(value: '스팸/테스트', child: Text('스팸/테스트')),
                    DropdownMenuItem(value: '사용자 요청', child: Text('사용자 요청')),
                    DropdownMenuItem(value: '기타', child: Text('기타 (직접 입력)')),
                  ],
                  onChanged: (value) {
                    setDialogState(() => selectedReason = value ?? '잘못된 정보');
                  },
                ),
                // 기타 선택 시 직접 입력
                if (selectedReason == '기타') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonController,
                    decoration: InputDecoration(
                      hintText: '삭제 사유를 입력하세요',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    maxLines: 2,
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AirbnbColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AirbnbColors.warning.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: AirbnbColors.warning, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '삭제 시 문의자에게 알림이 전송됩니다.',
                          style: TextStyle(fontSize: 13, color: AirbnbColors.warning),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                final reason = selectedReason == '기타'
                    ? (reasonController.text.trim().isEmpty ? '기타' : reasonController.text.trim())
                    : selectedReason;
                Navigator.pop(context, reason);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AirbnbColors.error,
                foregroundColor: AirbnbColors.background,
              ),
              child: const Text('삭제'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      await _deleteQuoteRequest(request, result);
    }
  }

  /// 견적문의 삭제 (알림 전송 포함)
  Future<void> _deleteQuoteRequest(QuoteRequest request, String reason) async {
    // 삭제 전에 문의자 정보 저장
    final userId = request.userId;
    final brokerName = request.brokerName;

    final success = await _firebaseService.deleteQuoteRequest(request.id);

    if (!mounted) return;

    if (success) {
      // 문의자에게 알림 전송
      if (userId.isNotEmpty) {
        await _firebaseService.sendNotification(
          userId: userId,
          title: '견적문의 삭제 알림',
          message: '"$brokerName" 중개사에게 보낸 견적문의가 관리자에 의해 삭제되었습니다.\n\n사유: $reason',
          type: 'quote_request_deleted',
          relatedId: request.id,
        );
      }
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${request.userName}님의 견적문의가 삭제되고 알림이 전송되었습니다.'),
          backgroundColor: AirbnbColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('견적문의 삭제에 실패했습니다. 다시 시도해주세요.'),
          backgroundColor: AirbnbColors.error,
        ),
      );
    }
  }
}

