import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/app_constants.dart';
import '../../models/admin_match.dart';
import '../../models/mls_property.dart';
import '../../utils/logger.dart';
import '../../utils/formatters.dart';

/// 관리자 매칭 관리 페이지
///
/// 외부 매물의 집주인과 중개사를 수동으로 연결하고
/// 매칭 진행 상태를 추적합니다.
class AdminMatchingPage extends StatefulWidget {
  final String userId;
  final String userName;

  const AdminMatchingPage({
    required this.userId,
    required this.userName,
    super.key,
  });

  @override
  State<AdminMatchingPage> createState() => _AdminMatchingPageState();
}

class _AdminMatchingPageState extends State<AdminMatchingPage> {
  final _firestore = FirebaseFirestore.instance;
  static const String _matchCollection = 'adminMatches';
  static const String _propertyCollection = 'mlsProperties';

  AdminMatchStatus? _statusFilter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AirbnbColors.surface,
      body: Column(
        children: [
          _buildHeader(),
          _buildStatusFilterBar(),
          Expanded(child: _buildMatchList()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateMatchDialog,
        backgroundColor: AirbnbColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('매칭 생성'),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: AirbnbColors.background,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '매칭 관리',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AirbnbColors.textPrimary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '매물과 중개사를 수동으로 연결하고 진행 상태를 추적합니다',
            style: TextStyle(
              fontSize: 14,
              color: AirbnbColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterBar() {
    final filters = <MapEntry<AdminMatchStatus?, String>>[
      const MapEntry(null, '전체'),
      const MapEntry(AdminMatchStatus.pending, '대기'),
      const MapEntry(AdminMatchStatus.contacted, '연락중'),
      const MapEntry(AdminMatchStatus.connected, '연결완료'),
      const MapEntry(AdminMatchStatus.visiting, '방문중'),
      const MapEntry(AdminMatchStatus.completed, '성사'),
      const MapEntry(AdminMatchStatus.failed, '불발'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AirbnbColors.background,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((entry) {
            final isSelected = _statusFilter == entry.key;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(entry.value),
                selected: isSelected,
                onSelected: (_) => setState(() => _statusFilter = entry.key),
                selectedColor: AirbnbColors.primary.withValues(alpha: 0.2),
                checkmarkColor: AirbnbColors.primary,
                labelStyle: TextStyle(
                  color: isSelected ? AirbnbColors.primary : AirbnbColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMatchList() {
    Query query = _firestore
        .collection(_matchCollection)
        .orderBy('createdAt', descending: true);

    if (_statusFilter != null) {
      query = query.where('status',
          isEqualTo: _statusFilter.toString().split('.').last);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.handshake_outlined,
                    size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                const Text(
                  '매칭 내역이 없습니다',
                  style: TextStyle(
                    fontSize: 16,
                    color: AirbnbColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '+ 버튼을 눌러 새 매칭을 생성하세요',
                  style: TextStyle(
                    fontSize: 14,
                    color: AirbnbColors.textLight,
                  ),
                ),
              ],
            ),
          );
        }

        final matches = snapshot.data!.docs
            .map((doc) =>
                AdminMatch.fromMap(doc.data() as Map<String, dynamic>))
            .toList();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: matches.length,
          itemBuilder: (context, index) => _buildMatchCard(matches[index]),
        );
      },
    );
  }

  Widget _buildMatchCard(AdminMatch match) {
    final statusInfo = _getStatusInfo(match.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AirbnbColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AirbnbColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단: 매물 주소 + 상태 배지
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        match.propertyAddress ?? match.propertyId,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AirbnbColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${match.brokerCompany ?? ''} ${match.brokerName}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AirbnbColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusInfo.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusInfo.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusInfo.color,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 구분선
          const Divider(height: 1),

          // 하단: 액션 버튼들
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                if (match.status == AdminMatchStatus.pending)
                  _buildActionButton(
                    '연락함',
                    Icons.phone_callback,
                    () => _updateStatus(match, AdminMatchStatus.contacted),
                  ),
                if (match.status == AdminMatchStatus.contacted)
                  _buildActionButton(
                    '연결완료',
                    Icons.connect_without_contact,
                    () => _showShareContactDialog(match),
                  ),
                if (match.status == AdminMatchStatus.connected)
                  _buildActionButton(
                    '방문중',
                    Icons.home_work,
                    () => _updateStatus(match, AdminMatchStatus.visiting),
                  ),
                if (match.status == AdminMatchStatus.visiting) ...[
                  _buildActionButton(
                    '거래성사',
                    Icons.celebration,
                    () => _updateStatus(match, AdminMatchStatus.completed),
                  ),
                  _buildActionButton(
                    '불발',
                    Icons.close,
                    () => _updateStatus(match, AdminMatchStatus.failed),
                  ),
                ],
                const Spacer(),
                _buildActionButton(
                  '메모',
                  Icons.edit_note,
                  () => _showNotesDialog(match),
                ),
              ],
            ),
          ),

          // 메모 표시
          if (match.notes != null && match.notes!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AirbnbColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  match.notes!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AirbnbColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      String label, IconData icon, VoidCallback onPressed) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      style: TextButton.styleFrom(
        foregroundColor: AirbnbColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  ({String label, Color color}) _getStatusInfo(AdminMatchStatus status) {
    switch (status) {
      case AdminMatchStatus.pending:
        return (label: '대기', color: AirbnbColors.textSecondary);
      case AdminMatchStatus.contacted:
        return (label: '연락중', color: Colors.orange);
      case AdminMatchStatus.connected:
        return (label: '연결완료', color: Colors.blue);
      case AdminMatchStatus.visiting:
        return (label: '방문중', color: AirbnbColors.primary);
      case AdminMatchStatus.completed:
        return (label: '거래성사', color: AirbnbColors.success);
      case AdminMatchStatus.failed:
        return (label: '불발', color: AirbnbColors.error);
    }
  }

  // === 다이얼로그 ===

  Future<void> _showCreateMatchDialog() async {
    final propertyController = TextEditingController();
    final brokerNameController = TextEditingController();
    final brokerPhoneController = TextEditingController();
    final brokerCompanyController = TextEditingController();
    final notesController = TextEditingController();

    MLSProperty? selectedProperty;
    List<MLSProperty> searchResults = [];

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('매칭 생성',
              style: TextStyle(fontWeight: FontWeight.w600)),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 매물 검색
                  const Text('매물 선택',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  if (selectedProperty != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AirbnbColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AirbnbColors.success),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: AirbnbColors.success, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              selectedProperty!.address,
                              style: const TextStyle(fontSize: 13),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => setDialogState(() {
                              selectedProperty = null;
                              propertyController.clear();
                            }),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    TextField(
                      controller: propertyController,
                      decoration: InputDecoration(
                        hintText: '매물 주소로 검색',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        isDense: true,
                      ),
                      onChanged: (query) async {
                        if (query.length < 2) {
                          setDialogState(() => searchResults = []);
                          return;
                        }
                        final snapshot = await _firestore
                            .collection(_propertyCollection)
                            .where('status', isEqualTo: 'active')
                            .get();
                        final results = snapshot.docs
                            .map((doc) => MLSProperty.fromMap(doc.data()))
                            .where((p) => p.address
                                .toLowerCase()
                                .contains(query.toLowerCase()))
                            .take(5)
                            .toList();
                        setDialogState(() => searchResults = results);
                      },
                    ),
                    if (searchResults.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        constraints: const BoxConstraints(maxHeight: 150),
                        decoration: BoxDecoration(
                          border: Border.all(color: AirbnbColors.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: searchResults.length,
                          itemBuilder: (context, i) {
                            final property = searchResults[i];
                            return ListTile(
                              dense: true,
                              title: Text(property.address,
                                  style: const TextStyle(fontSize: 13)),
                              subtitle: Text(
                                '${property.transactionType} ${_formatPrice(property.desiredPrice)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              onTap: () => setDialogState(() {
                                selectedProperty = property;
                                searchResults = [];
                                propertyController.text = property.address;
                              }),
                            );
                          },
                        ),
                      ),
                  ],

                  const SizedBox(height: 20),
                  const Text('중개사 정보',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: brokerCompanyController,
                    decoration: InputDecoration(
                      labelText: '중개사무소명',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: brokerNameController,
                    decoration: InputDecoration(
                      labelText: '중개사 이름 (필수)',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: brokerPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: '중개사 전화번호',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: '메모 (선택)',
                      hintText: '매수자 조건, 통화 내용 등',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedProperty == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('매물을 선택해주세요')),
                  );
                  return;
                }
                if (brokerNameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('중개사 이름을 입력해주세요')),
                  );
                  return;
                }

                await _createMatch(
                  property: selectedProperty!,
                  brokerName: brokerNameController.text.trim(),
                  brokerPhone: brokerPhoneController.text.trim().isNotEmpty
                      ? brokerPhoneController.text.trim()
                      : null,
                  brokerCompany:
                      brokerCompanyController.text.trim().isNotEmpty
                          ? brokerCompanyController.text.trim()
                          : null,
                  notes: notesController.text.trim().isNotEmpty
                      ? notesController.text.trim()
                      : null,
                );

                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AirbnbColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('생성'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showShareContactDialog(AdminMatch match) async {
    // 매물에서 집주인 전화번호 가져오기
    String? sellerPhone = match.sellerPhone;
    if (sellerPhone == null || sellerPhone.isEmpty) {
      try {
        final propertyDoc = await _firestore
            .collection(_propertyCollection)
            .doc(match.propertyId)
            .get();
        if (propertyDoc.exists) {
          final data = propertyDoc.data()!;
          sellerPhone = data['externalSellerPhone'] as String?;
        }
      } catch (e) {
        Logger.error('Failed to fetch seller phone', error: e);
      }
    }

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('연락처 공유 확인'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('중개사 ${match.brokerName}에게'),
            if (sellerPhone != null && sellerPhone.isNotEmpty)
              Text('집주인 전화번호 ($sellerPhone)를')
            else
              const Text('집주인 연락처를'),
            const Text('공유했습니까?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('아니요'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AirbnbColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('네, 공유했습니다'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _firestore.collection(_matchCollection).doc(match.id).update({
        'status': AdminMatchStatus.connected.toString().split('.').last,
        'contactShared': true,
        'contactSharedAt': DateTime.now().toIso8601String(),
        'sellerPhone': sellerPhone,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> _showNotesDialog(AdminMatch match) async {
    final notesController = TextEditingController(text: match.notes ?? '');
    final buyerInfoController =
        TextEditingController(text: match.buyerInfo ?? '');

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('메모 수정',
            style: TextStyle(fontWeight: FontWeight.w600)),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.6,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: '관리자 메모',
                  hintText: '통화 내용, 진행 상황 등',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: buyerInfoController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: '매수자 정보',
                  hintText: '매수자 조건, 예산, 희망 입주일 등',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _firestore
                  .collection(_matchCollection)
                  .doc(match.id)
                  .update({
                'notes': notesController.text.trim().isNotEmpty
                    ? notesController.text.trim()
                    : null,
                'buyerInfo': buyerInfoController.text.trim().isNotEmpty
                    ? buyerInfoController.text.trim()
                    : null,
                'updatedAt': DateTime.now().toIso8601String(),
              });
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AirbnbColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  // === 데이터 조작 ===

  Future<void> _createMatch({
    required MLSProperty property,
    required String brokerName,
    String? brokerPhone,
    String? brokerCompany,
    String? notes,
  }) async {
    try {
      final adminUser = FirebaseAuth.instance.currentUser;
      if (adminUser == null) return;

      final now = DateTime.now();
      final matchId = 'match_${now.millisecondsSinceEpoch}';

      // 외부 매물이면 집주인 전화번호 가져오기
      String? sellerPhone;
      if (property.isExternalListing) {
        sellerPhone = property.externalSellerPhone;
      }

      final match = AdminMatch(
        id: matchId,
        propertyId: property.id,
        propertyAddress: property.address,
        brokerName: brokerName,
        brokerPhone: brokerPhone,
        brokerCompany: brokerCompany,
        adminId: adminUser.uid,
        sellerPhone: sellerPhone,
        notes: notes,
        createdAt: now,
        updatedAt: now,
      );

      await _firestore
          .collection(_matchCollection)
          .doc(matchId)
          .set(match.toMap());

      Logger.info('Admin match created: $matchId for property: ${property.id}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('매칭이 생성되었습니다'),
            backgroundColor: AirbnbColors.success,
          ),
        );
      }
    } catch (e) {
      Logger.error('Failed to create admin match', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('매칭 생성에 실패했습니다. 잠시 후 다시 시도해 주세요.'),
            backgroundColor: AirbnbColors.error,
          ),
        );
      }
    }
  }

  Future<void> _updateStatus(
      AdminMatch match, AdminMatchStatus newStatus) async {
    try {
      await _firestore.collection(_matchCollection).doc(match.id).update({
        'status': newStatus.toString().split('.').last,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      Logger.error('Failed to update match status', error: e);
    }
  }

  String _formatPrice(double price) => PriceFormatter.format(price);
}
