import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../api_request/firebase_service.dart';
import 'package:property/constants/typography.dart';

/// 관리자가 사용자를 검색하고 선택할 수 있는 위젯
///
/// 사용 예:
/// ```dart
/// AdminUserSelector(
///   onUserSelected: (user) {
///     print('선택된 사용자: ${user['name']}');
///   },
/// )
/// ```
class AdminUserSelector extends StatefulWidget {
  /// 사용자 선택 시 호출되는 콜백
  final Function(Map<String, dynamic> selectedUser) onUserSelected;

  /// 현재 선택된 사용자 ID (하이라이트 표시용)
  final String? selectedUserId;

  const AdminUserSelector({
    required this.onUserSelected,
    this.selectedUserId,
    super.key,
  });

  @override
  State<AdminUserSelector> createState() => _AdminUserSelectorState();
}

class _AdminUserSelectorState extends State<AdminUserSelector> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _allUsers = [];
  String _searchQuery = '';
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final users = await _firebaseService.getAllUsers();
      if (mounted) {
        setState(() {
          _allUsers = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '사용자 목록을 불러오는데 실패했습니다: $e';
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_searchQuery.isEmpty) {
      return _allUsers;
    }

    final query = _searchQuery.toLowerCase();
    return _allUsers.where((user) {
      final name = (user['name'] ?? '').toString().toLowerCase();
      final email = (user['email'] ?? '').toString().toLowerCase();
      final phone = (user['phone'] ?? '').toString().toLowerCase();
      final uid = (user['uid'] ?? user['id'] ?? '').toString().toLowerCase();

      return name.contains(query) ||
          email.contains(query) ||
          phone.contains(query) ||
          uid.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 검색 필드
        _buildSearchField(),
        const SizedBox(height: 16),

        // 사용자 목록
        Expanded(
          child: _buildUserList(),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: '이름, 이메일, 전화번호로 검색',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                  });
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AirbnbColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AirbnbColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AirbnbColors.primary, width: 2),
        ),
        filled: true,
        fillColor: AirbnbColors.background,
      ),
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
    );
  }

  Widget _buildUserList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AirbnbColors.error.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style:  AppTypography.withColor(AppTypography.body, AirbnbColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadUsers,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (_filteredUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.person_search,
              size: 64,
              color: AirbnbColors.border,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty ? '등록된 사용자가 없습니다' : '검색 결과가 없습니다',
              style:  AppTypography.withColor(AppTypography.body, AirbnbColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _filteredUsers.length,
      itemBuilder: (context, index) {
        final user = _filteredUsers[index];
        return _buildUserCard(user);
      },
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final userId = (user['uid'] ?? user['id'] ?? '').toString();
    final isSelected = widget.selectedUserId == userId;
    final name = user['name'] ?? '이름 없음';
    final email = user['email'] ?? '';
    final phone = user['phone'] ?? '';
    final userType = user['userType'] ?? 'user';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: isSelected
            ? AirbnbColors.primary.withValues(alpha: 0.1)
            : AirbnbColors.background,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => widget.onUserSelected(user),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AirbnbColors.primary : AirbnbColors.border,
                width: isSelected ? 2 : 1,
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // 아바타
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AirbnbColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style:  AppTypography.withColor(AppTypography.h3, AirbnbColors.primary),
                    ),
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
                          Text(
                            name,
                            style:  AppTypography.body.copyWith(color: AirbnbColors.textPrimary, fontWeight: FontWeight.w600),
                          ),
                          if (userType == 'anonymous') ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AirbnbColors.warning.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child:   Text(
                                '익명',
                                style: AppTypography.caption.copyWith(color: AirbnbColors.warning, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (email.isNotEmpty)
                        Text(
                          email,
                          style:  AppTypography.withColor(AppTypography.bodySmall, AirbnbColors.textSecondary),
                        ),
                      if (phone.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            phone,
                            style:  AppTypography.withColor(AppTypography.captionLarge, AirbnbColors.textLight),
                          ),
                        ),
                    ],
                  ),
                ),

                // 선택 표시
                if (isSelected)
                  const Icon(
                    Icons.check_circle,
                    color: AirbnbColors.primary,
                    size: 24,
                  )
                else
                  const Icon(
                    Icons.chevron_right,
                    color: AirbnbColors.textLight,
                    size: 24,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 사용자 선택 다이얼로그를 표시합니다.
///
/// 선택된 사용자 정보를 반환하거나, 취소 시 null을 반환합니다.
Future<Map<String, dynamic>?> showUserSelectDialog(BuildContext context) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AirbnbColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // 드래그 핸들
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AirbnbColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // 헤더
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                    Expanded(
                    child: Text(
                      '사용자 선택',
                      style: AppTypography.withColor(AppTypography.h3, AirbnbColors.textPrimary),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // 사용자 선택 위젯
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: AdminUserSelector(
                  onUserSelected: (user) {
                    Navigator.pop(context, user);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
