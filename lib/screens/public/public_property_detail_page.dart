import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/app_constants.dart';
import '../../models/mls_property.dart';
import '../../models/broker_offer.dart';
import '../../api_request/mls_property_service.dart';
import '../../widgets/home_logo_button.dart';

/// 공개 매물 상세 페이지
///
/// 로그인 없이 접근 가능한 개별 매물 상세 보기.
/// URL: /property/{propertyId}
/// 연락처 정보는 비공개 처리됩니다.
/// 중개사는 "중개 제안하기"로 경쟁 제안을 제출할 수 있습니다.
class PublicPropertyDetailPage extends StatelessWidget {
  final String propertyId;

  const PublicPropertyDetailPage({
    required this.propertyId,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AirbnbColors.surface,
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('mlsProperties')
            .doc(propertyId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return _buildNotFound(context);
          }

          final property = MLSProperty.fromMap(
              snapshot.data!.data() as Map<String, dynamic>);

          return _PropertyDetailView(property: property);
        },
      ),
    );
  }

  Widget _buildNotFound(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            '매물을 찾을 수 없습니다',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AirbnbColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '삭제되었거나 존재하지 않는 매물입니다',
            style: TextStyle(color: AirbnbColors.textSecondary),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pushReplacementNamed(context, '/listings'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AirbnbColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('매물 목록으로'),
          ),
        ],
      ),
    );
  }
}

class _PropertyDetailView extends StatefulWidget {
  final MLSProperty property;

  const _PropertyDetailView({required this.property});

  @override
  State<_PropertyDetailView> createState() => _PropertyDetailViewState();
}

class _PropertyDetailViewState extends State<_PropertyDetailView> {
  final _mlsService = MLSPropertyService();
  bool _alreadyInquired = false;
  bool _isCheckingInquiry = false;

  MLSProperty get property => widget.property;

  @override
  void initState() {
    super.initState();
    _checkExistingInquiry();
  }

  Future<void> _checkExistingInquiry() async {
    if (FirebaseAuth.instance.currentUser == null) return;
    setState(() => _isCheckingInquiry = true);
    final has = await _mlsService.hasExistingInquiry(property.id);
    if (mounted) setState(() { _alreadyInquired = has; _isCheckingInquiry = false; });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final contentWidth = isMobile ? screenWidth : 800.0;

    return SingleChildScrollView(
      child: Column(
        children: [
          // 상단 바
          _buildTopBar(context, isMobile),

          // 사진 갤러리
          _buildPhotoGallery(isMobile),

          // 컨텐츠
          Center(
            child: SizedBox(
              width: contentWidth,
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 16 : 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPriceSection(),
                    const SizedBox(height: 24),
                    _buildAddressSection(),
                    const SizedBox(height: 24),
                    _buildDetailsSection(),
                    if (property.options.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildOptionsSection(),
                    ],
                    if (property.notes != null &&
                        property.notes!.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildNotesSection(),
                    ],
                    const SizedBox(height: 32),
                    _buildBuyerCtaSection(context),
                    const SizedBox(height: 16),
                    _buildOfferCtaSection(context),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 40,
        vertical: 12,
      ),
      decoration: const BoxDecoration(
        color: AirbnbColors.background,
        border: Border(bottom: BorderSide(color: AirbnbColors.border)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                Navigator.pushReplacementNamed(context, '/listings');
              }
            },
          ),
          const SizedBox(width: 8),
          LogoWithText(
            logoHeight: 36,
            textColor: AirbnbColors.primary,
            onTap: () => Navigator.pushReplacementNamed(context, '/listings'),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoGallery(bool isMobile) {
    if (property.imageUrls.isEmpty) {
      return Container(
        height: isMobile ? 250 : 400,
        color: AirbnbColors.surface,
        child: const Center(
          child: Icon(Icons.home_outlined,
              size: 64, color: AirbnbColors.textLight),
        ),
      );
    }

    if (property.imageUrls.length == 1) {
      return SizedBox(
        height: isMobile ? 250 : 400,
        width: double.infinity,
        child: Image.network(
          property.imageUrls.first,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => Container(
            color: AirbnbColors.surface,
            child: const Center(
              child: Icon(Icons.broken_image, size: 48, color: AirbnbColors.textLight),
            ),
          ),
        ),
      );
    }

    // 여러 사진: 가로 스크롤
    return SizedBox(
      height: isMobile ? 250 : 400,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: property.imageUrls.length,
        itemBuilder: (context, index) {
          return Container(
            width: isMobile
                ? MediaQuery.of(context).size.width * 0.85
                : 500,
            margin: EdgeInsets.only(
              left: index == 0 ? 0 : 4,
              right: index == property.imageUrls.length - 1 ? 0 : 4,
            ),
            child: Image.network(
              property.imageUrls[index],
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => Container(
                color: AirbnbColors.surface,
                child: const Center(
                  child: Icon(Icons.broken_image, size: 48, color: AirbnbColors.textLight),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPriceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 거래유형 배지
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AirbnbColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            property.transactionType,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AirbnbColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // 가격
        Text(
          _formatPrice(property.desiredPrice),
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AirbnbColors.textPrimary,
          ),
        ),

        // 월세인 경우 보증금
        if (property.transactionType == '월세' && property.deposit != null)
          Text(
            '보증금 ${_formatPrice(property.deposit!)}',
            style: const TextStyle(
              fontSize: 16,
              color: AirbnbColors.textSecondary,
            ),
          ),

        if (property.negotiable)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              '가격 협의 가능',
              style: TextStyle(
                fontSize: 13,
                color: AirbnbColors.success,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAddressSection() {
    // 동/호수 제거
    final displayAddress = property.address
        .replaceAll(RegExp(r'\d+동\s*\d+호'), '')
        .replaceAll(RegExp(r'\d+호'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return _buildSection(
      title: '위치',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 18, color: AirbnbColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  displayAddress,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AirbnbColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (property.buildingName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 24),
              child: Text(
                property.buildingName,
                style: const TextStyle(
                  fontSize: 14,
                  color: AirbnbColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection() {
    final details = <MapEntry<String, String>>[];

    if (property.area != null) {
      details.add(MapEntry(
          '전용면적', '${property.area!.toStringAsFixed(1)}m² (${property.calculatePyeong().toStringAsFixed(1)}평)'));
    }
    if (property.floor != null) {
      final floorText = property.totalFloors != null
          ? '${property.floor}층 / ${property.totalFloors}층'
          : '${property.floor}층';
      details.add(MapEntry('층수', floorText));
    }
    if (property.rooms != null) {
      final roomText = property.bathrooms != null
          ? '${property.rooms}룸 / ${property.bathrooms}화장실'
          : '${property.rooms}룸';
      details.add(MapEntry('방/화장실', roomText));
    }
    if (property.direction != null) {
      details.add(MapEntry('향', property.direction!));
    }
    if (property.repairStatus != 'partial') {
      final repairLabel = property.repairStatus == 'excellent'
          ? '올수리'
          : property.repairStatus == 'needed'
              ? '수리필요'
              : '부분수리';
      details.add(MapEntry('수리상태', repairLabel));
    }
    final moveInLabel = property.moveInFlexibility == 'immediate'
        ? '즉시 입주 가능'
        : property.moveInFlexibility == 'specific' && property.moveInDate != null
            ? '${property.moveInDate!.month}/${property.moveInDate!.day} 이후'
            : '협의';
    details.add(MapEntry('입주', moveInLabel));

    if (details.isEmpty) return const SizedBox.shrink();

    return _buildSection(
      title: '상세 정보',
      child: Column(
        children: details.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    entry.key,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AirbnbColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    entry.value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AirbnbColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOptionsSection() {
    return _buildSection(
      title: '옵션',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: property.options.map((option) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AirbnbColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AirbnbColors.border),
            ),
            child: Text(
              option,
              style: const TextStyle(
                fontSize: 13,
                color: AirbnbColors.textPrimary,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNotesSection() {
    return _buildSection(
      title: '추가 설명',
      child: Text(
        property.notes!,
        style: const TextStyle(
          fontSize: 14,
          color: AirbnbColors.textPrimary,
          height: 1.6,
        ),
      ),
    );
  }

  /// 구매자 문의 CTA 섹션
  Widget _buildBuyerCtaSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          const Icon(Icons.search_rounded, size: 32, color: Colors.green),
          const SizedBox(height: 10),
          const Text(
            '이 매물에 관심이 있으신가요?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AirbnbColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '문의하시면 담당 중개사가 연락드립니다',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AirbnbColors.textSecondary),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: _isCheckingInquiry
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _alreadyInquired
                    ? Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle, color: Colors.green, size: 18),
                            SizedBox(width: 6),
                            Text(
                              '문의 접수 완료 — 중개사 배정 중',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: () => _showBuyerInquiryDialog(context),
                        icon: const Icon(Icons.message_outlined, size: 18),
                        label: const Text(
                          '이 매물 문의하기',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  /// 구매자 문의 다이얼로그
  void _showBuyerInquiryDialog(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('문의하려면 로그인이 필요합니다'),
          backgroundColor: AirbnbColors.warning,
        ),
      );
      return;
    }

    final messageController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.message_outlined, color: Colors.green, size: 22),
              SizedBox(width: 8),
              Text('매물 문의', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: MediaQuery.of(ctx).size.width * 0.85,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 매물 요약
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AirbnbColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AirbnbColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.home_outlined, size: 16, color: AirbnbColors.textSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${property.roadAddress} · ${_formatPrice(property.desiredPrice)}',
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 메모 (선택)
                  TextField(
                    controller: messageController,
                    maxLines: 3,
                    maxLength: 200,
                    decoration: InputDecoration(
                      labelText: '메모 (선택)',
                      hintText: '예: 주말 방문 희망합니다',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '* 담당 중개사가 연락드립니다',
                    style: TextStyle(fontSize: 12, color: AirbnbColors.textSecondary),
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
              onPressed: isSubmitting
                  ? null
                  : () async {
                      setDialogState(() => isSubmitting = true);
                      final messenger = ScaffoldMessenger.of(ctx);
                      try {
                        await _mlsService.createBuyerInquiry(
                          propertyId: property.id,
                          buyerMessage: messageController.text.trim(),
                        );
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        if (mounted) {
                          setState(() => _alreadyInquired = true);
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('문의가 접수되었습니다. 중개사가 곧 연락드립니다.'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        messenger.showSnackBar(
                          SnackBar(content: Text('오류: $e'), backgroundColor: AirbnbColors.error),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: isSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('문의 보내기'),
            ),
          ],
        ),
      ),
    );
  }

  /// 중개 제안 CTA 섹션
  Widget _buildOfferCtaSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AirbnbColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AirbnbColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          const Icon(Icons.handshake_outlined, size: 36, color: AirbnbColors.primary),
          const SizedBox(height: 12),
          const Text(
            '이 매물을 중개하고 싶으신가요?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AirbnbColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '중개 제안을 보내시면, 매물 소유자가\n중개사를 비교하고 선택합니다',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AirbnbColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),

          // 현재 제안 수 표시
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('brokerOffers')
                .where('propertyId', isEqualTo: property.id)
                .where('status', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, snapshot) {
              final count = snapshot.data?.docs.length ?? 0;
              if (count == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AirbnbColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '현재 $count명의 중개사가 제안했습니다',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AirbnbColors.primary,
                    ),
                  ),
                ),
              );
            },
          ),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showOfferDialog(context),
              icon: const Icon(Icons.send_rounded, size: 20),
              label: const Text(
                '중개 제안하기',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AirbnbColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 중개 제안 폼 다이얼로그
  void _showOfferDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final companyController = TextEditingController();
    final pitchController = TextEditingController();
    bool isSubmitting = false;

    // 로그인된 중개사인 경우 자동 입력
    String? loggedInBrokerId;
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        final brokerDoc = await FirebaseFirestore.instance
            .collection('brokers')
            .doc(currentUser.uid)
            .get();
        if (brokerDoc.exists) {
          final data = brokerDoc.data()!;
          loggedInBrokerId = currentUser.uid;
          nameController.text = data['name'] ?? '';
          phoneController.text = data['phone'] ?? '';
          companyController.text = data['companyName'] ?? '';
        }
      } catch (_) {
        // 브로커 정보 조회 실패 - 수동 입력으로 진행
      }
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.handshake_rounded, color: AirbnbColors.primary, size: 24),
              SizedBox(width: 8),
              Text('중개 제안', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.85,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 로그인 중개사 자동인식 배지
                  if (loggedInBrokerId != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AirbnbColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AirbnbColors.success.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.verified_user, size: 16, color: AirbnbColors.success),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '로그인된 중개사 정보가 자동으로 입력되었습니다',
                                style: TextStyle(fontSize: 12, color: AirbnbColors.success),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 매물 요약
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AirbnbColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AirbnbColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.home_outlined, size: 18, color: AirbnbColors.textSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${property.roadAddress} · ${_formatPrice(property.desiredPrice)}',
                            style: const TextStyle(fontSize: 13, color: AirbnbColors.textPrimary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 이름
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: '이름 *',
                      hintText: '홍길동',
                      prefixIcon: const Icon(Icons.person_outline, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 전화번호
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: '전화번호 *',
                      hintText: '010-1234-5678',
                      prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 사무소명
                  TextField(
                    controller: companyController,
                    decoration: InputDecoration(
                      labelText: '중개사무소명',
                      hintText: '성사동 에이스 부동산',
                      prefixIcon: const Icon(Icons.business_outlined, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 한마디
                  TextField(
                    controller: pitchController,
                    maxLines: 3,
                    maxLength: 200,
                    decoration: InputDecoration(
                      labelText: '한마디 *',
                      hintText: '이 단지 10년 전문입니다.\n현재 매수 희망자가 2명 있습니다.',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
              onPressed: isSubmitting
                  ? null
                  : () async {
                      // 검증
                      if (nameController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('이름을 입력해주세요')),
                        );
                        return;
                      }
                      if (phoneController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('전화번호를 입력해주세요')),
                        );
                        return;
                      }
                      if (pitchController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('한마디를 입력해주세요')),
                        );
                        return;
                      }

                      setDialogState(() => isSubmitting = true);

                      try {
                        // 중복 제안 체크 (전화번호 기준)
                        final phone = phoneController.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
                        final existing = await FirebaseFirestore.instance
                            .collection('brokerOffers')
                            .where('propertyId', isEqualTo: property.id)
                            .where('brokerPhone', isEqualTo: phoneController.text.trim())
                            .get();

                        // 번호에서 하이픈 제거한 버전으로도 체크
                        QuerySnapshot? existingNormalized;
                        if (existing.docs.isEmpty && phone != phoneController.text.trim()) {
                          existingNormalized = await FirebaseFirestore.instance
                              .collection('brokerOffers')
                              .where('propertyId', isEqualTo: property.id)
                              .get();
                        }

                        final isDuplicate = existing.docs.isNotEmpty ||
                            (existingNormalized?.docs.any((d) {
                              final savedPhone = ((d.data() as Map)['brokerPhone'] ?? '').toString().replaceAll(RegExp(r'[^0-9]'), '');
                              return savedPhone == phone;
                            }) ?? false);

                        if (isDuplicate) {
                          setDialogState(() => isSubmitting = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('이미 이 매물에 제안을 보내셨습니다'),
                                backgroundColor: AirbnbColors.warning,
                              ),
                            );
                          }
                          return;
                        }

                        final docRef = FirebaseFirestore.instance
                            .collection('brokerOffers')
                            .doc();

                        final offer = BrokerOffer(
                          id: docRef.id,
                          propertyId: property.id,
                          propertyAddress: property.roadAddress,
                          brokerName: nameController.text.trim(),
                          brokerPhone: phoneController.text.trim(),
                          brokerCompany: companyController.text.trim().isNotEmpty
                              ? companyController.text.trim()
                              : null,
                          brokerId: loggedInBrokerId,
                          pitch: pitchController.text.trim(),
                          createdAt: DateTime.now(),
                        );

                        await docRef.set(offer.toMap());

                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                        if (context.mounted) {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              content: const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle,
                                      color: AirbnbColors.success, size: 56),
                                  SizedBox(height: 16),
                                  Text(
                                    '제안이 접수되었습니다!',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    '매물 소유자가 검토 후 연락드릴 예정입니다.\n감사합니다.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AirbnbColors.textSecondary,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('확인'),
                                ),
                              ],
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('제출 실패: $e'),
                              backgroundColor: AirbnbColors.error,
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AirbnbColors.primary,
                foregroundColor: Colors.white,
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('제안 보내기'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AirbnbColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  String _formatPrice(double price) {
    if (price >= 10000) {
      final uk = (price / 10000).floor();
      final man = (price % 10000).toInt();
      if (man > 0) return '$uk억 $man만원';
      return '$uk억';
    }
    return '${price.toInt()}만원';
  }
}
