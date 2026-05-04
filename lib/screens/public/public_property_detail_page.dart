import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../constants/app_constants.dart';
import '../../constants/grant_messages.dart';
import '../../constants/responsive_constants.dart';
import '../../models/mls_property.dart';
import '../../models/broker_offer.dart';
import '../../models/priority_grant.dart';
import '../../api_request/mls_property_service.dart';
import '../../api_request/firebase_service.dart';
import '../../api_request/priority_grant_service.dart';
import '../../utils/cloud_functions_guard.dart';
import '../../utils/formatters.dart';
import '../../models/buyer_inquiry.dart';
import '../../utils/logger.dart';
import '../../utils/phone_utils.dart';
import '../../widgets/broker_picker_dialog.dart';
import '../../widgets/home_logo_button.dart';
import '../auth/auth_landing_page.dart';
import 'package:property/constants/typography.dart';
import 'package:property/utils/snackbar_utils.dart';

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
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: ResponsiveHelper.getMaxWidth(context)),
          child: FutureBuilder<DocumentSnapshot>(
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

              final Map<String, dynamic> raw =
                  snapshot.data!.data() as Map<String, dynamic>;
              final property = MLSProperty.fromMap(raw);

              // Task 05 — 비로그인 공개: 집계 수치만 노출 (개별 displayName 금지).
              // P1-6 — Map 직독 폐기. MLSProperty 모델 비정규화 필드 사용.
              return _PropertyDetailView(
                property: property,
                participantCount: property.participantCount ?? 0,
                firstParticipantDeclaredAt: property.firstParticipantDeclaredAt,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildNotFound(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, size: 64, color: AirbnbColors.borderLight),
          const SizedBox(height: 16),
            Text(
            '매물을 찾을 수 없습니다',
            style: AppTypography.withColor(AppTypography.h4, AirbnbColors.textPrimary),
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
              foregroundColor: AirbnbColors.background,
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

  /// Task 05 — `mlsProperties.participantCount` 비정규화 필드.
  /// 비로그인 공개 read 가능. 개별 displayName 노출 금지 — 집계만.
  final int participantCount;

  /// Task 05 — `mlsProperties.firstParticipantDeclaredAt` 비정규화 필드.
  /// "첫 참여 D-N" 표시용.
  final DateTime? firstParticipantDeclaredAt;

  const _PropertyDetailView({
    required this.property,
    this.participantCount = 0,
    this.firstParticipantDeclaredAt,
  });

  @override
  State<_PropertyDetailView> createState() => _PropertyDetailViewState();
}

class _PropertyDetailViewState extends State<_PropertyDetailView> {
  final _mlsService = MLSPropertyService();
  final _firebaseService = FirebaseService();
  final _grantService = PriorityGrantService();
  bool _alreadyInquired = false;
  bool _isCheckingInquiry = false;
  BuyerInquiry? _existingInquiry;
  PriorityGrant? _buyerMatchGrant; // Task 03: 매수자가 선택한 buyer_match grant
  bool _isPickingBroker = false;
  bool _isBookmarked = false;
  bool _isTogglingBookmark = false;
  bool _isBroker = false;

  MLSProperty get property => widget.property;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _mlsService.incrementViewCount(property.id);
      await Future.wait([
        _checkExistingInquiry(),
        _checkBookmark(),
        _checkBrokerRole(),
      ]);
    });
  }

  Future<void> _checkBrokerRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final brokerDoc = await FirebaseFirestore.instance
        .collection('brokers')
        .doc(user.uid)
        .get();
    if (mounted) setState(() => _isBroker = brokerDoc.exists);
  }

  Future<void> _checkExistingInquiry() async {
    if (FirebaseAuth.instance.currentUser == null) return;
    setState(() => _isCheckingInquiry = true);
    final inquiry = await _mlsService.getMyActiveInquiry(property.id);
    PriorityGrant? grant;
    if (inquiry != null) {
      grant = await _grantService.getActiveBuyerMatchGrant(inquiry.id);
    }
    if (mounted) {
      setState(() {
        _existingInquiry = inquiry;
        _alreadyInquired = inquiry != null;
        _buyerMatchGrant = grant;
        _isCheckingInquiry = false;
      });
    }
  }

  /// Task 03 — 임장 신청: 중개사 선택 다이얼로그 → createBuyerMatchGrant 호출.
  ///
  /// 이미 활성 grant가 있으면 *교체 흐름*: 1차 거절(BUYER_SWITCH_REQUIRED)이면
  /// 매수자 명시적 동의 다이얼로그 표시 후 confirmSwitch=true로 재호출.
  Future<void> _handleVisitRequest(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      AppSnackBar.warning(context, '임장 신청은 로그인이 필요합니다');
      return;
    }
    final inquiry = _existingInquiry;
    if (inquiry == null) {
      AppSnackBar.warning(context, '먼저 매물 문의를 보내주세요');
      return;
    }
    if (_isPickingBroker) return;

    final String? pickedBrokerId = await BrokerPickerDialog.show(
      context: context,
      property: property,
      currentActiveGrant: _buyerMatchGrant,
    );
    if (pickedBrokerId == null) return;
    if (!context.mounted) return;

    await _issueBuyerMatchGrant(
      context: context,
      brokerId: pickedBrokerId,
      inquiryId: inquiry.id,
      confirmSwitch: false,
    );
  }

  Future<void> _issueBuyerMatchGrant({
    required BuildContext context,
    required String brokerId,
    required String inquiryId,
    required bool confirmSwitch,
  }) async {
    setState(() => _isPickingBroker = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final BuyerMatchGrantResult result =
          await _grantService.requestBuyerMatchGrantViaFunction(
        propertyId: property.id,
        brokerId: brokerId,
        buyerInquiryId: inquiryId,
        confirmSwitch: confirmSwitch,
      );
      // 성공 — 갱신된 grant 다시 로드
      final PriorityGrant? grant =
          await _grantService.getActiveBuyerMatchGrant(inquiryId);
      if (!mounted) return;
      setState(() {
        _buyerMatchGrant = grant;
        _isPickingBroker = false;
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text(result.switched
              ? GrantMessages.buyerMatchSwitched
              : GrantMessages.buyerMatchSuccess),
          backgroundColor: AirbnbColors.green,
        ),
      );
    } on CloudFunctionsUserFacingException catch (e) {
      // problem 002 가드 — NOT_FOUND 등은 한국어 카피로 변환된 상태로 도착.
      Logger.warning(
        'buyer match grant guarded',
        metadata: <String, dynamic>{
          'inquiryId': inquiryId,
          'functionName': e.functionName,
          'firebaseCode': e.firebaseCode,
        },
      );
      if (!mounted) return;
      setState(() => _isPickingBroker = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.userMessage),
          backgroundColor: AirbnbColors.error,
        ),
      );
      return;
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() => _isPickingBroker = false);
      final String? code = GrantMessages.extractReasonCode(e.message);
      // 첫 시도가 SWITCH_REQUIRED → 매수자 명시적 동의 다이얼로그 후 재호출
      if (code == 'buyer_switch_required' && !confirmSwitch) {
        if (!context.mounted) return;
        final bool confirmed = await _confirmSwitchBroker(context);
        if (!mounted || !confirmed) return;
        if (!context.mounted) return;
        await _issueBuyerMatchGrant(
          context: context,
          brokerId: brokerId,
          inquiryId: inquiryId,
          confirmSwitch: true,
        );
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(GrantMessages.describeReason(code)),
          backgroundColor: AirbnbColors.error,
        ),
      );
    } catch (e, stack) {
      Logger.error(
        '[PublicPropertyDetail] buyer_match grant 발급 실패',
        error: e,
        stackTrace: stack,
        context: 'PublicPropertyDetail',
        metadata: <String, dynamic>{
          'inquiryId': inquiryId,
          'brokerId': brokerId,
        },
      );
      if (!mounted) return;
      setState(() => _isPickingBroker = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('잠시 후 다시 시도해 주세요'),
          backgroundColor: AirbnbColors.error,
        ),
      );
    }
  }

  /// Task 03 — 임장 신청 / 담당 중개사 상태 박스.
  ///
  /// - grant 없음 → "임장 신청하기" 버튼
  /// - grant 있음 → 담당 중개사 표시 + "다른 중개사로 바꾸기" 버튼
  Widget _buildBuyerMatchSection(BuildContext context) {
    final PriorityGrant? grant = _buyerMatchGrant;
    if (_isPickingBroker) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (grant == null) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _handleVisitRequest(context),
          icon: const Icon(Icons.tour_outlined, size: 18),
          label: const Text(GrantMessages.actionVisitProperty),
          style: ElevatedButton.styleFrom(
            backgroundColor: AirbnbColors.primary,
            foregroundColor: AirbnbColors.background,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
        ),
      );
    }
    final int days = grant.expiresAt.difference(DateTime.now()).inDays;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AirbnbColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AirbnbColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.person_pin_circle_outlined,
                  color: AirbnbColors.primary, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '담당 중개사: ${grant.brokerId}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AirbnbColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${GrantMessages.describeStage(grant.stage.name)} · ${GrantMessages.describeDaysLeft(days)}',
            style: AppTypography.withColor(
              AppTypography.caption,
              AirbnbColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _handleVisitRequest(context),
              icon: const Icon(Icons.swap_horiz, size: 16),
              label: const Text(GrantMessages.actionSwitchBroker),
              style: TextButton.styleFrom(
                foregroundColor: AirbnbColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmSwitchBroker(BuildContext context) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text(GrantMessages.buyerSwitchConfirmTitle),
        content: const Text(GrantMessages.buyerSwitchConfirmBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(GrantMessages.actionCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AirbnbColors.primary,
              foregroundColor: AirbnbColors.background,
            ),
            child: const Text(GrantMessages.actionSwitchBroker),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _checkBookmark() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final bookmarks = await _firebaseService.getBookmarks(user.uid);
    if (mounted) setState(() => _isBookmarked = bookmarks.contains(property.id));
  }

  Future<void> _toggleBookmark() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      AppSnackBar.warning(context, '찜하려면 로그인이 필요합니다');
      return;
    }
    if (_isTogglingBookmark) return;
    setState(() => _isTogglingBookmark = true);
    final newState = await _firebaseService.toggleBookmark(user.uid, property.id);
    if (mounted) {
      setState(() {
        _isBookmarked = newState;
        _isTogglingBookmark = false;
      });
      AppSnackBar.info(context, newState ? '찜 목록에 추가되었습니다' : '찜 목록에서 제거되었습니다');
    }
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
                    _buildParticipationCountSection(),
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
                    // Task 07 — 매도자가 단독 지정한 매물 안내.
                    // 매수자에게는 "평소처럼 가능"으로 중립 안내 (M1.2 영향 없음).
                    // 일반 중개사에게는 "참여 등록 불가" 명시 — 자율 선택임을 강조.
                    if (property.listingMode == 'exclusive') ...[
                      const SizedBox(height: 24),
                      _buildExclusiveListingNotice(context),
                    ],
                    const SizedBox(height: 32),
                    _buildBuyerCtaSection(context),
                    if (_isBroker) ...[
                      const SizedBox(height: 16),
                      _buildOfferCtaSection(context),
                    ],
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
          const Spacer(),
          IconButton(
            icon: _isTogglingBookmark
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(
                    _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    color: _isBookmarked ? AirbnbColors.primary : AirbnbColors.textSecondary,
                  ),
            tooltip: _isBookmarked ? '찜 해제' : '찜하기',
            onPressed: _toggleBookmark,
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
        child: CachedNetworkImage(
          imageUrl: property.imageUrls.first,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(color: AirbnbColors.surface),
          errorWidget: (context, url, error) => Container(
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
              left: index == 0 ? 0 : 8,
              right: index == property.imageUrls.length - 1 ? 0 : 8,
            ),
            child: CachedNetworkImage(
              imageUrl: property.imageUrls[index],
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: AirbnbColors.surface),
              errorWidget: (context, url, error) => Container(
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
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            property.transactionType,
            style:  AppTypography.captionLarge.copyWith(color: AirbnbColors.primary, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 8),

        // 가격
        Text(
          _formatPrice(property.desiredPrice),
          style:  AppTypography.h1.copyWith(color: AirbnbColors.textPrimary, fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),

        // 월세인 경우 보증금
        if (property.transactionType == '월세' && property.deposit != null)
          Text(
            '보증금 ${_formatPrice(property.deposit!)}',
            style:  AppTypography.withColor(AppTypography.body, AirbnbColors.textSecondary),
          ),

        if (property.negotiable)
            Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              '가격 협의 가능',
              style: AppTypography.captionLarge.copyWith(color: AirbnbColors.success, fontWeight: FontWeight.w500),
            ),
          ),
      ],
    );
  }

  /// Task 05 — 비로그인 공개: 집계 수치만 한 줄.
  ///
  /// "${count}명의 중개사가 참여 중, 첫 참여 N일 전" 형식.
  /// 명세 §2.3 / §4 — 개별 displayName 절대 노출 금지.
  Widget _buildParticipationCountSection() {
    final int count = widget.participantCount;
    if (count <= 0) return const SizedBox.shrink();

    final DateTime? firstAt = widget.firstParticipantDeclaredAt;
    String body = '$count${GrantMessages.participationPublicCountSuffix}';
    if (firstAt != null) {
      final int days = DateTime.now().difference(firstAt).inDays;
      body = '$body, ${GrantMessages.participationFirstDaysAgo(days)}';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.people_outline,
            size: 16,
            color: AirbnbColors.textSecondary,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              body,
              style: AppTypography.captionLarge.copyWith(
                color: AirbnbColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
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
                  style:  AppTypography.withColor(AppTypography.body, AirbnbColors.textPrimary),
                ),
              ),
            ],
          ),
          if (property.buildingName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 24),
              child: Text(
                property.buildingName,
                style:  AppTypography.withColor(AppTypography.bodySmall, AirbnbColors.textSecondary),
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
                    style:  AppTypography.withColor(AppTypography.bodySmall, AirbnbColors.textSecondary),
                  ),
                ),
                Expanded(
                  child: Text(
                    entry.value,
                    style:  AppTypography.bodySmall.copyWith(color: AirbnbColors.textPrimary, fontWeight: FontWeight.w500),
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
              style:  AppTypography.withColor(AppTypography.captionLarge, AirbnbColors.textPrimary),
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
        style:  AppTypography.bodySmall.copyWith(color: AirbnbColors.textPrimary, height: 1.6),
      ),
    );
  }

  /// Task 07 — 매도자 자율 단독 지정 매물 안내.
  ///
  /// listingMode === 'exclusive' 인 경우 노출. 사용자 역할에 따라 카피 분기:
  ///   * 일반 중개사(지정 외): 참여 등록 불가 명시.
  ///   * 지정 중개사: 본인이 단독 지정 받았음을 알림.
  ///   * 매수자/비로그인: 매수 문의는 평소처럼 가능 (M1.2 영향 없음).
  ///
  /// 모든 카피는 "매도자가 직접 지정"을 명백히 — §33①9호 회피.
  Widget _buildExclusiveListingNotice(BuildContext context) {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    final bool isAssignedBroker =
        _isBroker && uid != null && property.exclusiveBrokerIds.contains(uid);

    final String message;
    final IconData icon;
    final Color tone;
    if (isAssignedBroker) {
      message = GrantMessages.listingExclusiveAssignedBadge;
      icon = Icons.verified;
      tone = AirbnbColors.green;
    } else if (_isBroker) {
      message = GrantMessages.listingExclusiveSellerSelectedNotice;
      icon = Icons.lock_outline;
      tone = AirbnbColors.orange;
    } else {
      // 매수자 / 비로그인 — 영향 없음 안내.
      message = GrantMessages.listingExclusiveBuyerNeutralNotice;
      icon = Icons.info_outline;
      tone = AirbnbColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tone.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: tone, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: AppTypography.body.copyWith(
                color: AirbnbColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 구매자 문의 CTA 섹션
  Widget _buildBuyerCtaSection(BuildContext context) {
    final isLoggedIn = FirebaseAuth.instance.currentUser != null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AirbnbColors.green.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AirbnbColors.green.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          const Icon(Icons.favorite_border, size: 32, color: AirbnbColors.green),
          const SizedBox(height: 10),
            Text(
            '이 매물에 관심이 있으신가요?',
            style: AppTypography.body.copyWith(color: AirbnbColors.textPrimary, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            isLoggedIn
                ? '문의하시면 담당 중개사가 연락드립니다'
                : '로그인하고 문의하면 담당 중개사가 연락드립니다',
            textAlign: TextAlign.center,
            style:  AppTypography.withColor(AppTypography.captionLarge, AirbnbColors.textSecondary),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: !isLoggedIn
                ? ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AuthLandingPage()),
                      );
                    },
                    icon: const Icon(Icons.login, size: 18),
                    label:   Text(
                      '로그인하고 문의하기',
                      style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AirbnbColors.green,
                      foregroundColor: AirbnbColors.background,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      elevation: 0,
                    ),
                  )
                : _isCheckingInquiry
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _alreadyInquired
                    ? Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: AirbnbColors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle, color: AirbnbColors.green, size: 18),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    _existingInquiry?.status.label ?? '문의 접수 완료 — 중개사 배정 중',
                                    style:  AppTypography.bodySmall.copyWith(color: AirbnbColors.green, fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_existingInquiry?.buyerMessage != null &&
                              _existingInquiry!.buyerMessage!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                '메모: ${_existingInquiry!.buyerMessage}',
                                style:  AppTypography.withColor(AppTypography.captionLarge, AirbnbColors.textSecondary),
                              ),
                            ),
                          // Task 03 — 임장 신청 / 담당 중개사 표시
                          const SizedBox(height: 12),
                          _buildBuyerMatchSection(context),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _showEditInquiryDialog(context),
                                  icon: const Icon(Icons.edit_outlined, size: 16),
                                  label: const Text('메모 수정'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AirbnbColors.textSecondary,
                                    side: const BorderSide(color: AirbnbColors.border),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 11),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _showCancelInquiryDialog(context),
                                  icon: const Icon(Icons.close, size: 16),
                                  label: const Text('문의 취소'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AirbnbColors.error,
                                    side: const BorderSide(color: AirbnbColors.error),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 11),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : ElevatedButton.icon(
                        onPressed: () => _showBuyerInquiryDialog(context),
                        icon: const Icon(Icons.message_outlined, size: 18),
                        label:   Text(
                          '이 매물 문의하기',
                          style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AirbnbColors.green,
                          foregroundColor: AirbnbColors.background,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          elevation: 0,
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  /// 문의 메모 수정 다이얼로그
  void _showEditInquiryDialog(BuildContext context) {
    final inquiry = _existingInquiry;
    if (inquiry == null) return;

    final messageController = TextEditingController(text: inquiry.buyerMessage ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.edit_outlined, color: AirbnbColors.green, size: 22),
                SizedBox(width: 8),
                Text('메모 수정', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            content: TextField(
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
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('취소'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        setDialogState(() => isSaving = true);
                        final messenger = ScaffoldMessenger.of(ctx);
                        try {
                          await _mlsService.updateBuyerInquiryMessage(
                            inquiry.id,
                            messageController.text.trim(),
                          );
                          if (dialogContext.mounted) Navigator.pop(dialogContext);
                          if (mounted) {
                            await _checkExistingInquiry();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('메모가 수정되었습니다.'),
                                backgroundColor: AirbnbColors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          Logger.error('[PublicPropertyDetail] 메모 수정 실패', error: e);
                          if (dialogContext.mounted) {
                            setDialogState(() => isSaving = false);
                          }
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('수정에 실패했습니다. 잠시 후 다시 시도해 주세요.'),
                              backgroundColor: AirbnbColors.error,
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AirbnbColors.green,
                  foregroundColor: AirbnbColors.background,
                ),
                child: isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AirbnbColors.background))
                    : const Text('저장'),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 문의 취소 확인 다이얼로그
  void _showCancelInquiryDialog(BuildContext context) {
    final inquiry = _existingInquiry;
    if (inquiry == null) return;

    showDialog(
      context: context,
      builder: (dialogContext) {
        bool isCancelling = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('문의를 취소하시겠습니까?'),
            content: const Text(
              '취소하면 중개사 배정이 중단됩니다.\n다시 문의하실 수 있습니다.',
              style: TextStyle(color: AirbnbColors.textSecondary, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('아니요'),
              ),
              ElevatedButton(
                onPressed: isCancelling
                    ? null
                    : () async {
                        setDialogState(() => isCancelling = true);
                        final messenger = ScaffoldMessenger.of(ctx);
                        try {
                          await _mlsService.cancelBuyerInquiry(inquiry.id);
                          if (dialogContext.mounted) Navigator.pop(dialogContext);
                          if (mounted) {
                            setState(() {
                              _alreadyInquired = false;
                              _existingInquiry = null;
                            });
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('문의가 취소되었습니다.'),
                              ),
                            );
                          }
                        } catch (e) {
                          Logger.error('[PublicPropertyDetail] 문의 취소 실패', error: e);
                          if (dialogContext.mounted) {
                            setDialogState(() => isCancelling = false);
                          }
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('취소에 실패했습니다. 잠시 후 다시 시도해 주세요.'),
                              backgroundColor: AirbnbColors.error,
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AirbnbColors.error,
                  foregroundColor: AirbnbColors.background,
                ),
                child: isCancelling
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AirbnbColors.background))
                    : const Text('취소하기'),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 구매자 문의 다이얼로그
  void _showBuyerInquiryDialog(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      AppSnackBar.warning(context, '문의하려면 로그인이 필요합니다');
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
              Icon(Icons.message_outlined, color: AirbnbColors.green, size: 22),
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
                            style:  AppTypography.captionLarge,
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
                    Text(
                    '* 담당 중개사가 연락드립니다',
                    style: AppTypography.withColor(AppTypography.caption, AirbnbColors.textSecondary),
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
                              backgroundColor: AirbnbColors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        Logger.error('[PublicPropertyDetail] 문의 제출 실패', error: e);
                        if (dialogContext.mounted) {
                          setDialogState(() => isSubmitting = false);
                        }
                        messenger.showSnackBar(
                          const SnackBar(content: Text('일시적인 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.'), backgroundColor: AirbnbColors.error),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AirbnbColors.green,
                foregroundColor: AirbnbColors.background,
              ),
              child: isSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AirbnbColors.background))
                  : const Text('문의 보내기'),
            ),
          ],
        ),
      ),
    );
  }

  /// 중개 제안 CTA 섹션
  Widget _buildOfferCtaSection(BuildContext context) {
    // Task 07 — exclusive 매물에서 비지정 중개사는 제안 버튼을 비활성화하고
    // 매도자 자율 선택 결과임을 안내한다 (§33①9호 회피).
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    final bool isExclusive = property.listingMode == 'exclusive';
    final bool isAssigned =
        uid != null && property.exclusiveBrokerIds.contains(uid);
    final bool blocked = isExclusive && !isAssigned;

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
            Text(
            '이 매물을 중개하고 싶으신가요?',
            style: AppTypography.withColor(AppTypography.h4, AirbnbColors.textPrimary),
          ),
          const SizedBox(height: 8),
            Text(
            blocked
                ? GrantMessages.listingExclusiveSellerSelectedNotice
                : '중개 제안을 보내시면, 매물 소유자가\n중개사를 비교하고 선택합니다',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(color: AirbnbColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: blocked ? null : () => _showOfferDialog(context),
              icon: const Icon(Icons.send_rounded, size: 20),
              label:   Text(
                blocked ? '참여 등록 불가' : '중개 제안하기',
                style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AirbnbColors.primary,
                foregroundColor: AirbnbColors.background,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 0,
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
      } catch (e) {
        Logger.warning('[PublicPropertyDetail] 브로커 정보 조회 실패 - 수동 입력으로 진행', metadata: {'error': e.toString()});
      }
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogInnerContext, setDialogState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
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
              width: double.maxFinite,
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
                        child:   Row(
                          children: [
                            Icon(Icons.verified_user, size: 16, color: AirbnbColors.success),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '로그인된 중개사 정보가 자동으로 입력되었습니다',
                                style: AppTypography.withColor(AppTypography.caption, AirbnbColors.success),
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
                            style:  AppTypography.withColor(AppTypography.captionLarge, AirbnbColors.textPrimary),
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
                    maxLength: 13,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d\-]')),
                    ],
                    decoration: InputDecoration(
                      labelText: '전화번호 *',
                      hintText: '010-1234-5678',
                      prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                      counterText: '',
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
                      labelText: '어필 한마디 *',
                      hintText: '예: 이 단지 10년 전문입니다. 현재 매수 희망자가 2명 있습니다.',
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
                        AppSnackBar.info(dialogContext, '이름을 입력해주세요');
                        return;
                      }
                      if (phoneController.text.trim().isEmpty) {
                        AppSnackBar.info(dialogContext, '전화번호를 입력해주세요');
                        return;
                      }
                      if (pitchController.text.trim().isEmpty) {
                        AppSnackBar.info(dialogContext, '어필 한마디를 입력해주세요');
                        return;
                      }

                      setDialogState(() => isSubmitting = true);

                      try {
                        // 중복 제안 체크 (전화번호 정규화 비교)
                        final normalizedPhone = PhoneUtils.normalize(phoneController.text.trim());
                        final allOffers = await FirebaseFirestore.instance
                            .collection('brokerOffers')
                            .where('propertyId', isEqualTo: property.id)
                            .get();

                        final isDuplicate = allOffers.docs.any((d) {
                          final savedPhone = PhoneUtils.normalize(
                            ((d.data())['brokerPhone'] ?? '').toString(),
                          );
                          return savedPhone == normalizedPhone;
                        });

                        if (isDuplicate) {
                          setDialogState(() => isSubmitting = false);
                          if (dialogContext.mounted) {
                            AppSnackBar.warning(dialogContext, '이미 이 매물에 제안을 보내셨습니다');
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

                        // 매도인에게 새 중개 제안 알림
                        await FirebaseService().sendNotification(
                          userId: property.userId,
                          type: 'broker_offer',
                          title: '새 중개 제안',
                          message: '${nameController.text.trim()} 중개사가 매물에 중개 제안을 보냈습니다.',
                          relatedId: property.id,
                        );

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
                                    style: AppTypography.h4,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    '매도인이 중개사를 검토 후 직접 연락드립니다.\n보통 1~2일 내 연락이 옵니다.',
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
                          AppSnackBar.error(context, '제출에 실패했습니다. 잠시 후 다시 시도해 주세요.');
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AirbnbColors.primary,
                foregroundColor: AirbnbColors.background,
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AirbnbColors.background),
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
          style:  AppTypography.withColor(AppTypography.h4, AirbnbColors.textPrimary),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  String _formatPrice(double price) => PriceFormatter.format(price);
}
