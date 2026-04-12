import 'dart:async';
import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/api_request/fcm_service.dart';
import 'package:property/screens/auth/auth_landing_page.dart';
import 'package:property/screens/policy/privacy_policy_page.dart';
import 'package:property/screens/policy/terms_of_service_page.dart';
import 'package:property/widgets/customer_service_dialog.dart';
import 'package:property/screens/notification/notification_page.dart';
import 'package:property/constants/typography.dart';
import 'package:property/utils/snackbar_utils.dart';

/// 전체 페이지 (설정/마이페이지) - 반응형 디자인
class PersonalInfoPage extends StatefulWidget {
  final String userId;
  final String userName;

  const PersonalInfoPage({
    required this.userId,
    required this.userName,
    super.key,
  });

  @override
  State<PersonalInfoPage> createState() => _PersonalInfoPageState();
}

class _PersonalInfoPageState extends State<PersonalInfoPage> {
  final FirebaseService _firebaseService = FirebaseService();

  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isBroker = false;
  bool _isDeletingAccount = false;
  int _unreadNotificationCount = 0;
  StreamSubscription<int>? _notificationSubscription;

  // 반응형 브레이크포인트
  static const double _mobileBreakpoint = 600;
  static const double _tabletBreakpoint = 900;
  static const double _maxContentWidth = 700;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _subscribeToNotifications();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToNotifications() {
    if (widget.userId.isEmpty) return;
    _notificationSubscription = _firebaseService
        .getUnreadNotificationCount(widget.userId)
        .listen((count) {
      if (mounted) {
        setState(() => _unreadNotificationCount = count);
      }
    });
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    try {
      final userData = await _firebaseService.getUser(widget.userId);

      bool isBroker = false;
      Map<String, dynamic>? mergedData = userData;

      if (userData != null) {
        final role = userData['role']?.toString().toLowerCase() ?? '';
        if (role == 'broker') {
          isBroker = true;
        } else {
          final brokerData = await _firebaseService.getBroker(widget.userId);
          isBroker = brokerData != null;
          if (brokerData != null) {
            // 공인중개사 데이터 병합
            mergedData = {...userData, ...brokerData};
          }
        }
      } else {
        // users 컬렉션에 없으면 brokers 컬렉션에서 조회
        final brokerData = await _firebaseService.getBroker(widget.userId);
        if (brokerData != null) {
          isBroker = true;
          mergedData = brokerData;
        }
      }

      if (mounted) {
        setState(() {
          _userData = mergedData;
          _isBroker = isBroker;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AirbnbColors.surface,
      appBar: _buildAppBar(context),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > _mobileBreakpoint;
                final isVeryWide = constraints.maxWidth > _tabletBreakpoint;

                return SingleChildScrollView(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isVeryWide ? _maxContentWidth : double.infinity,
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isWide ? 24 : 0,
                          vertical: isWide ? 16 : 0,
                        ),
                        child: Column(
                          children: [
                            // 프로필 헤더
                            _buildProfileHeader(isWide),
                            SizedBox(height: isWide ? 16 : 8),
                            // 개인정보 섹션
                            _buildSectionCard(
                              isWide: isWide,
                              child: _buildPersonalInfoSection(isWide),
                            ),
                            SizedBox(height: isWide ? 16 : 8),
                            // 설정 섹션
                            _buildSectionCard(
                              isWide: isWide,
                              child: _buildSettingsSection(isWide),
                            ),
                            SizedBox(height: isWide ? 16 : 8),
                            // 기타 섹션
                            _buildSectionCard(
                              isWide: isWide,
                              child: _buildOtherSection(isWide),
                            ),
                            SizedBox(height: isWide ? 48 : 32),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AirbnbColors.background,
      elevation: 0,
      centerTitle: true,
      title:   Text(
        '전체',
        style: AppTypography.withColor(AppTypography.h4, AirbnbColors.textPrimary),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, size: 20),
        color: AirbnbColors.textPrimary,
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  /// 섹션 카드 래퍼 (웹에서 카드 스타일 적용)
  Widget _buildSectionCard({required bool isWide, required Widget child}) {
    if (!isWide) {
      return child;
    }

    return Container(
      decoration: BoxDecoration(
        color: AirbnbColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AirbnbColors.border.withValues(alpha: 0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  /// 프로필 헤더
  Widget _buildProfileHeader(bool isWide) {
    final userName = _userData?['name'] ?? widget.userName;
    final userEmail = _userData?['email'] ?? '';

    final Widget content = Container(
      color: AirbnbColors.background,
      padding: EdgeInsets.all(isWide ? 24 : 20),
      child: Row(
        children: [
          // 프로필 이미지
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AirbnbColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.person,
              size: 28,
              color: AirbnbColors.primary,
            ),
          ),
          const SizedBox(width: 16),
          // 사용자 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        userName,
                        style:  AppTypography.withColor(AppTypography.h4, AirbnbColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_isBroker) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AirbnbColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child:   Text(
                          '공인중개사',
                          style: AppTypography.caption.copyWith(color: AirbnbColors.primary, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ],
                ),
                if (userEmail.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    userEmail,
                    style:  AppTypography.withColor(AppTypography.bodySmall, AirbnbColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          // 편집 버튼
          IconButton(
            onPressed: () => _showEditNameDialog(),
            icon: const Icon(Icons.edit_outlined, size: 20),
            color: AirbnbColors.textLight,
          ),
        ],
      ),
    );

    if (isWide) {
      return Container(
        decoration: BoxDecoration(
          color: AirbnbColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AirbnbColors.border.withValues(alpha: 0.3)),
        ),
        clipBehavior: Clip.antiAlias,
        child: content,
      );
    }

    return content;
  }

  /// 개인정보 섹션
  Widget _buildPersonalInfoSection(bool isWide) {
    final phone = _userData?['phone']?.toString() ??
        _userData?['phoneNumber']?.toString() ??
        '';
    final brokerRegistrationNumber =
        _userData?['brokerRegistrationNumber']?.toString() ??
            _userData?['registrationNumber']?.toString() ??
            '';

    return Container(
      color: AirbnbColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('개인정보'),
          _buildListTile(
            icon: Icons.person_outline,
            title: '이름',
            value: _userData?['name'] ??
                _userData?['ownerName'] ??
                widget.userName,
            onTap: () => _showEditNameDialog(),
          ),
          _buildDivider(),
          _buildListTile(
            icon: Icons.phone_outlined,
            title: '전화번호',
            value: phone.isNotEmpty ? phone : '-',
            onTap: () => _showEditPhoneDialog(),
          ),
          // 공인중개사인 경우 등록번호 표시
          if (_isBroker) ...[
            _buildDivider(),
            _buildListTile(
              icon: Icons.badge_outlined,
              title: '중개업 등록번호',
              value: brokerRegistrationNumber.isNotEmpty
                  ? brokerRegistrationNumber
                  : '-',
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }


  /// 설정 섹션
  Widget _buildSettingsSection(bool isWide) {
    return Container(
      color: AirbnbColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('설정'),
          Stack(
            children: [
              _buildListTile(
                icon: Icons.notifications_outlined,
                title: '알림',
                showArrow: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NotificationPage(userId: widget.userId),
                    ),
                  );
                },
              ),
              // 알림 배지
              if (_unreadNotificationCount > 0)
                Positioned(
                  left: 38,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: AirbnbColors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _unreadNotificationCount > 99 ? '99+' : '$_unreadNotificationCount',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AirbnbColors.background,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// 기타 섹션
  Widget _buildOtherSection(bool isWide) {
    return Container(
      color: AirbnbColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('기타'),
          _buildListTile(
            icon: Icons.headset_mic_outlined,
            title: '고객센터',
            showArrow: true,
            onTap: () => showCustomerServiceDialog(context),
          ),
          _buildDivider(),
          _buildListTile(
            icon: Icons.article_outlined,
            title: '이용약관',
            showArrow: true,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TermsOfServicePage()),
              );
            },
          ),
          _buildDivider(),
          _buildListTile(
            icon: Icons.shield_outlined,
            title: '개인정보 처리방침',
            showArrow: true,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
              );
            },
          ),
          _buildDivider(),
          _buildListTile(
            icon: Icons.info_outline,
            title: '앱 버전',
            value: '1.1.0+13',
          ),
          _buildDivider(),
          _buildListTile(
            icon: Icons.logout_rounded,
            title: '로그아웃',
            titleColor: AirbnbColors.red,
            onTap: () => _logout(),
          ),
          _buildDivider(),
          _buildListTile(
            icon: Icons.person_remove_outlined,
            title: '회원탈퇴',
            titleColor: AirbnbColors.red,
            onTap: () => _deleteAccount(),
          ),
          // 하단 여유 공간
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        title,
        style:  AppTypography.captionLarge.copyWith(color: AirbnbColors.textSecondary, fontWeight: FontWeight.w600),
      ),
    );
  }

  /// 리스트 타일 빌더
  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? value,
    Color? titleColor,
    bool showArrow = false,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: titleColor ?? AirbnbColors.textSecondary,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.withColor(AppTypography.body, titleColor ?? AirbnbColors.textPrimary),
                ),
              ),
              if (value != null)
                Flexible(
                  child: Text(
                    value,
                    style:  AppTypography.withColor(AppTypography.body, AirbnbColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (showArrow || onTap != null)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: AirbnbColors.textLight,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.only(left: 56),
      child: Divider(height: 1, color: AirbnbColors.border),
    );
  }

  // ============================================================
  // 다이얼로그 및 액션 메서드들
  // ============================================================

  Future<void> _showEditNameDialog() async {
    final controller = TextEditingController(
      text: _userData?['name'] ?? widget.userName,
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('이름 수정'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: '이름',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('저장'),
          ),
        ],
      ),
    );

    if (result == true && controller.text.trim().isNotEmpty) {
      final success = await _firebaseService.updateUserName(
        widget.userId,
        controller.text.trim(),
      );
      if (success && mounted) {
        AppSnackBar.success(context, '이름이 수정되었습니다.');
        _loadUserData();
      }
    }
    controller.dispose();
  }

  Future<void> _showEditPhoneDialog() async {
    final controller = TextEditingController(text: _userData?['phone'] ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('전화번호 수정'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: '전화번호',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            hintText: '010-1234-5678',
          ),
          keyboardType: TextInputType.phone,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('저장'),
          ),
        ],
      ),
    );

    if (result == true && controller.text.trim().isNotEmpty) {
      final success = await _firebaseService.updateUserPhone(
        widget.userId,
        controller.text.trim(),
      );
      if (success && mounted) {
        AppSnackBar.success(context, '전화번호가 수정되었습니다.');
        _loadUserData();
      }
    }
    controller.dispose();
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('로그아웃'),
        content: const Text('로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AirbnbColors.red),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // 알림 구독 먼저 취소 (로그아웃 후 PERMISSION_DENIED 방지)
      _notificationSubscription?.cancel();
      _notificationSubscription = null;
      // FCM 토큰 삭제 (로그아웃 후 푸시 알림 수신 방지)
      await FCMService().removeToken(widget.userId);
      await _firebaseService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthLandingPage()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('회원탈퇴'),
        content: const Text(
          '정말 탈퇴하시겠습니까?\n\n모든 데이터가 삭제되며 복구할 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AirbnbColors.red),
            child: const Text('탈퇴하기'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (_isDeletingAccount) return;
      setState(() => _isDeletingAccount = true);

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      _notificationSubscription?.cancel();
      _notificationSubscription = null;
      final error = await _firebaseService.deleteUserAccount(widget.userId);

      if (mounted) Navigator.of(context).pop(); // 로딩 닫기

      if (error == null && mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthLandingPage()),
          (route) => false,
        );
      } else if (mounted) {
        setState(() => _isDeletingAccount = false);
        AppSnackBar.error(context, error ?? '회원탈퇴 실패');
      }
    }
  }
}
