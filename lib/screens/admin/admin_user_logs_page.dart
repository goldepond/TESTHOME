import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/action_log.dart';
import '../../api_request/log_service.dart';
import '../../constants/app_constants.dart';
import '../../constants/responsive_constants.dart';
import 'package:property/constants/typography.dart';

/// 화면 이름 한글 매핑
const Map<String, String> _screenNameMap = {
  'MainPage': '메인 홈',
  'MainPageTab': '메인 홈',
  'HomePage': '홈페이지',
  'MLSQuickRegistrationPage': 'MLS 매물 등록',
  'MLSSellerDashboardPage': 'MLS 판매자 대시보드',
  'MLSPropertyDetailPage': 'MLS 매물 상세',
  'MLSBrokerDashboardPage': 'MLS 중개사 대시보드',
  'NotificationPage': '알림',
  'UserInfoPage': '내 정보',
  'LoginPage': '로그인',
  'SignUpPage': '회원가입',
  'SettingsPage': '설정',
};

/// 액션 타입 한글 매핑
const Map<String, String> _actionTypeMap = {
  'view_screen': '화면 조회',
  'click': '클릭',
  'submit': '제출',
  'search': '검색',
  'login': '로그인',
  'logout': '로그아웃',
};

class AdminUserLogsPage extends StatefulWidget {
  final String userId;
  final String userName;

  const AdminUserLogsPage({
    required this.userId,
    required this.userName,
    super.key,
  });

  @override
  State<AdminUserLogsPage> createState() => _AdminUserLogsPageState();
}

class _AdminUserLogsPageState extends State<AdminUserLogsPage> {
  final LogService _logService = LogService();

  /// 로그를 사용자별로 그룹화
  Map<String, List<ActionLog>> _groupLogsByUser(List<ActionLog> logs) {
    final Map<String, List<ActionLog>> grouped = {};
    for (final log in logs) {
      if (!grouped.containsKey(log.userId)) {
        grouped[log.userId] = [];
      }
      grouped[log.userId]!.add(log);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AirbnbColors.surface,
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: ResponsiveHelper.getMaxWidth(context)),
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.all(20),
            color: AirbnbColors.background,
            child:   Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '사용자 활동 로그',
                  style: AppTypography.withColor(AppTypography.h2, AirbnbColors.primary),
                ),
                SizedBox(height: 8),
                Text(
                  '사용자별로 그룹화된 활동 내역입니다. 클릭하면 상세 로그를 볼 수 있습니다.',
                  style: AppTypography.withColor(AppTypography.bodySmall, AirbnbColors.textSecondary),
                ),
              ],
            ),
          ),

          // 로그 리스트 (사용자별 그룹화)
          Expanded(
            child: StreamBuilder<List<ActionLog>>(
              stream: _logService.getLogs(limit: 200),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('오류 발생: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final logs = snapshot.data ?? [];

                if (logs.isEmpty) {
                  return const Center(child: Text('기록된 로그가 없습니다.'));
                }

                // 사용자별로 그룹화
                final groupedLogs = _groupLogsByUser(logs);
                final userIds = groupedLogs.keys.toList();

                // 최근 활동 순으로 정렬
                userIds.sort((a, b) {
                  final aLatest = groupedLogs[a]!.first.timestamp;
                  final bLatest = groupedLogs[b]!.first.timestamp;
                  return bLatest.compareTo(aLatest);
                });

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: userIds.length,
                  itemBuilder: (context, index) {
                    final odbc = userIds[index];
                    final userLogs = groupedLogs[odbc]!;
                    return _buildUserCard(odbc, userLogs);
                  },
                );
              },
            ),
          ),
        ],
      ),
        ),
      ),
    );
  }

  /// 사용자별 카드 (접을 수 있는 형태)
  Widget _buildUserCard(String odbc, List<ActionLog> logs) {
    final latestLog = logs.first;
    final dateFormat = DateFormat('MM/dd HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: AirbnbColors.primary.withValues(alpha: 0.1),
          child: const Icon(Icons.person, color: AirbnbColors.primary),
        ),
        title: Text(
          _shortenUserId(odbc),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AirbnbColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${logs.length}개 활동',
                style:  AppTypography.caption.copyWith(color: AirbnbColors.success, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '최근: ${dateFormat.format(latestLog.timestamp)}',
              style:  AppTypography.withColor(AppTypography.caption, AirbnbColors.textSecondary),
            ),
          ],
        ),
        children: [
          const Divider(height: 1),
          ...logs.take(20).map((log) => _buildLogTile(log)),
          if (logs.length > 20)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '...외 ${logs.length - 20}개 더 있음',
                style:  AppTypography.withColor(AppTypography.caption, AirbnbColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLogTile(ActionLog log) {
    final dateFormat = DateFormat('MM/dd HH:mm:ss');

    // 한글로 변환
    final actionKorean = _actionTypeMap[log.actionType] ?? log.actionType;
    final screenKorean = _getScreenNameKorean(log.target);

    IconData icon;
    Color color;

    switch (log.actionType) {
      case 'view_screen':
        icon = Icons.visibility;
        color = AirbnbColors.primary;
        break;
      case 'click':
        icon = Icons.touch_app;
        color = AirbnbColors.warning;
        break;
      case 'submit':
        icon = Icons.send;
        color = AirbnbColors.success;
        break;
      case 'search':
        icon = Icons.search;
        color = AirbnbColors.info;
        break;
      default:
        icon = Icons.info_outline;
        color = AirbnbColors.textSecondary;
    }

    return ListTile(
      dense: true,
      leading: Icon(icon, color: color, size: 20),
      title: Text(
        '$actionKorean: $screenKorean',
        style:  AppTypography.bodySmall,
      ),
      trailing: Text(
        dateFormat.format(log.timestamp),
        style:  AppTypography.withColor(AppTypography.caption, AirbnbColors.textSecondary),
      ),
    );
  }

  /// 화면 이름을 한글로 변환
  String _getScreenNameKorean(String target) {
    // 매핑에 있으면 한글 반환
    if (_screenNameMap.containsKey(target)) {
      return _screenNameMap[target]!;
    }

    // minified 또는 dynamic 이름은 "기타 화면"으로 표시
    if (target.contains('minified') ||
        target.contains('dynamic') ||
        target.contains('<')) {
      return '기타 화면';
    }

    // Page 접미사 제거하고 띄어쓰기 추가
    String readable = target.replaceAll('Page', '').replaceAll('Screen', '');
    // CamelCase를 띄어쓰기로 변환
    readable = readable.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => '${match.group(1)} ${match.group(2)}',
    );

    return readable;
  }

  /// 사용자 ID를 짧게 표시 (처음 8자만)
  String _shortenUserId(String odbc) {
    if (odbc == 'anonymous') return '비로그인 사용자';
    if (odbc.length > 12) {
      return '사용자 ${odbc.substring(0, 8)}...';
    }
    return '사용자 $odbc';
  }
}
