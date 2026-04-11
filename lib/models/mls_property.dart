import 'package:property/constants/property_constants.dart';

/// MLS(Multiple Listing Service)형 매물 마스터 카드 모델
///
/// 매도인이 한 번 등록하면 지역 내 다수 중개사에게 자동 배포되고,
/// 방문/네고/계약 상태가 실시간으로 동기화되는 매물 관리 시스템
class MLSProperty {
  // 고유 식별자
  final String id; // 고유 매물 ID (REGION-YYYYMMDD-SEQ)
  final String propertyId; // Property 테이블 연결용
  final String userId; // 매도인 ID
  final String userName; // 매도인 이름

  // 매물 기본 정보
  final String address; // 전체 주소
  final String roadAddress; // 도로명 주소
  final String jibunAddress; // 지번 주소
  final String buildingName; // 건물명
  final String? propertyType; // 매물 유형 (아파트, 빌라, 오피스텔, 단독주택, 기타)
  final double? latitude; // 위도
  final double? longitude; // 경도

  // 면적/평형
  final double? area; // 전용면적 (m²)
  final double? supplyArea; // 공급면적 (m²)
  final double? pyeong; // 평형 (자동 계산)

  // 상세 정보
  final int? floor; // 층수
  final int? totalFloors; // 총 층수
  final int? rooms; // 방 개수
  final int? bathrooms; // 화장실 개수
  final String? direction; // 향 (동향, 서향, 남향, 북향 등)
  final String? structure; // 구조 (베이형태: 2베이, 3베이, 4베이 등)

  // 거래 유형
  final String transactionType; // 매매, 전세, 월세

  // 가격 정보
  final double desiredPrice; // 희망가 (매매가/전세금/월세)
  final double? deposit; // 보증금 (월세인 경우)
  final bool negotiable; // 협상 가능 여부
  final double? minimumPrice; // 최소 희망가 (옵션)

  // 이사 정보
  final DateTime? moveInDate; // 이사 가능일
  final String moveInFlexibility; // immediate(즉시), flexible(협의), specific(특정일)

  // 수리 상태
  final String repairStatus; // excellent(올수리), partial(부분수리), needed(수리필요)
  final String? recentRepairDetails; // 최근 수리 내역

  // 옵션
  final List<String> options; // 에어컨, 붙박이장, 확장 등

  // 셀링 포인트
  final List<String> sellingPoints; // 채광, 조용함, 학군, 역세권 등

  // 추가 메모
  final String? notes; // 자유 입력 메모/추가 설명

  // 사진/미디어
  final List<String> imageUrls; // 사진 URL 리스트
  final String? thumbnailUrl; // 대표 사진
  final String? videoUrl; // 영상 (옵션)

  // 매도인 연락처
  final String? sellerPhone; // 매도인 전화번호

  // 안심번호
  final String? virtualPhoneNumber; // 050 안심번호
  final bool virtualPhoneActive; // 안심번호 활성 상태

  // 배포 정보
  final String region; // 배포 지역 (동/읍/면)
  final String district; // 시군구
  final List<String> targetBrokerIds; // 배포 대상 중개사 ID 리스트
  final DateTime? broadcastedAt; // 배포 시각

  // 중개사 수락 현황
  final Map<String, BrokerResponse> brokerResponses; // brokerId → 응답 정보

  // 상태 관리 (단일 상태 머신)
  final PropertyStatus status; // 매물 상태
  final String? currentBrokerId; // 현재 진행 중인 중개사 ID
  final DateTime? statusChangedAt; // 상태 변경 시각
  final List<StatusHistory> statusHistory; // 상태 변경 이력

  // 방문 요청/예약
  final List<VisitRequest> visitRequests; // 방문 요청 리스트 (신규)
  final List<VisitSchedule> visitSchedules; // 방문 일정 리스트 (레거시 호환)
  final Map<String, List<TimeSlot>> availableSlots; // 날짜별 가용 시간대
  final Map<int, List<String>> weeklyTimeBlocks; // 요일별 시간 블록 (1=월~7=일, 값: morning/afternoon/evening)

  // 네고 이력
  final List<NegotiationLog> negotiations; // 협의 이력

  // 거래 정보
  final DateTime? depositTakenAt; // 가계약 시각
  final DateTime? soldAt; // 거래 완료 시각
  final String? finalBrokerId; // 최종 거래 중개사 ID
  final double? finalPrice; // 최종 거래가

  // 검증 정보
  final VerificationStatus? verificationStatus; // 검증 상태
  final DateTime? verificationRequestedAt; // 검증 요청 시각
  final DateTime? verifiedAt; // 검증 완료 시각
  final String? verifiedBy; // 검증자 ID ('auto' 또는 admin ID)
  final String? rejectionReason; // 거절 사유
  final String? duplicatePropertyId; // 중복 감지된 매물 ID

  // 외부 매물 정보 (당근마켓/피터팬 등에서 가져온 매물)
  final bool isExternalListing; // 외부 매물 여부
  final String? externalSellerName; // 외부 집주인 이름
  final String? externalSellerPhone; // 외부 집주인 전화번호
  final String? externalSource; // 출처 (당근마켓, 피터팬, 맘카페 등)
  final String? externalListingUrl; // 원본 게시글 URL
  final String? linkedUserId; // 앱 가입 시 연결할 userId

  // 통계
  final int viewCount; // 상세 페이지 조회수

  // 메타데이터
  final DateTime createdAt; // 생성 시각
  final DateTime updatedAt; // 수정 시각
  final bool isActive; // 활성 상태
  final bool isDeleted; // 삭제 여부

  MLSProperty({
    required this.id,
    required this.propertyId,
    required this.userId,
    required this.userName,
    required this.address,
    required this.roadAddress,
    required this.jibunAddress,
    required this.buildingName,
    required this.desiredPrice, required this.region, required this.district, required this.createdAt, required this.updatedAt, this.propertyType,
    this.latitude,
    this.longitude,
    this.area,
    this.supplyArea,
    this.pyeong,
    this.floor,
    this.totalFloors,
    this.rooms,
    this.bathrooms,
    this.direction,
    this.structure,
    this.transactionType = '매매',
    this.deposit,
    this.negotiable = true,
    this.minimumPrice,
    this.moveInDate,
    this.moveInFlexibility = 'flexible',
    this.repairStatus = 'partial',
    this.recentRepairDetails,
    this.options = const [],
    this.sellingPoints = const [],
    this.notes,
    this.imageUrls = const [],
    this.thumbnailUrl,
    this.videoUrl,
    this.sellerPhone,
    this.virtualPhoneNumber,
    this.virtualPhoneActive = false,
    this.targetBrokerIds = const [],
    this.broadcastedAt,
    this.brokerResponses = const {},
    this.status = PropertyStatus.draft,
    this.currentBrokerId,
    this.statusChangedAt,
    this.statusHistory = const [],
    this.visitRequests = const [],
    this.visitSchedules = const [],
    this.availableSlots = const {},
    this.weeklyTimeBlocks = const {},
    this.negotiations = const [],
    this.depositTakenAt,
    this.soldAt,
    this.finalBrokerId,
    this.finalPrice,
    this.verificationStatus,
    this.verificationRequestedAt,
    this.verifiedAt,
    this.verifiedBy,
    this.rejectionReason,
    this.duplicatePropertyId,
    this.isExternalListing = false,
    this.externalSellerName,
    this.externalSellerPhone,
    this.externalSource,
    this.externalListingUrl,
    this.linkedUserId,
    this.viewCount = 0,
    this.isActive = true,
    this.isDeleted = false,
  });

  /// 평형 계산 (m² → 평)
  double calculatePyeong() {
    if (area == null) return 0;
    return area! / AppNumericConstants.pyeongConversion;
  }

  /// 고유 ID 생성 (REGION-YYYYMMDD-SEQ)
  static String generateId(String region, int sequence) {
    final now = DateTime.now();
    final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final seqStr = sequence.toString().padLeft(6, '0');
    return '${region.toUpperCase()}-$dateStr-$seqStr';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'propertyId': propertyId,
      'userId': userId,
      'userName': userName,
      'address': address,
      'roadAddress': roadAddress,
      'jibunAddress': jibunAddress,
      'buildingName': buildingName,
      'propertyType': propertyType,
      'latitude': latitude,
      'longitude': longitude,
      'area': area,
      'supplyArea': supplyArea,
      'pyeong': pyeong,
      'floor': floor,
      'totalFloors': totalFloors,
      'rooms': rooms,
      'bathrooms': bathrooms,
      'direction': direction,
      'structure': structure,
      'transactionType': transactionType,
      'desiredPrice': desiredPrice,
      'deposit': deposit,
      'negotiable': negotiable,
      'minimumPrice': minimumPrice,
      'moveInDate': moveInDate?.toIso8601String(),
      'moveInFlexibility': moveInFlexibility,
      'repairStatus': repairStatus,
      'recentRepairDetails': recentRepairDetails,
      'options': options,
      'sellingPoints': sellingPoints,
      'notes': notes,
      'imageUrls': imageUrls,
      'thumbnailUrl': thumbnailUrl,
      'videoUrl': videoUrl,
      'sellerPhone': sellerPhone,
      'virtualPhoneNumber': virtualPhoneNumber,
      'virtualPhoneActive': virtualPhoneActive,
      'region': region,
      'district': district,
      'targetBrokerIds': targetBrokerIds,
      'broadcastedAt': broadcastedAt?.toIso8601String(),
      'brokerResponses': brokerResponses.map((k, v) => MapEntry(k, v.toMap())),
      'status': status.toString().split('.').last,
      'currentBrokerId': currentBrokerId,
      'statusChangedAt': statusChangedAt?.toIso8601String(),
      'statusHistory': statusHistory.map((e) => e.toMap()).toList(),
      'visitRequests': visitRequests.map((e) => e.toMap()).toList(),
      'visitSchedules': visitSchedules.map((e) => e.toMap()).toList(),
      'availableSlots': availableSlots.map(
        (date, slots) => MapEntry(date, slots.map((s) => s.toMap()).toList()),
      ),
      'weeklyTimeBlocks': weeklyTimeBlocks.map(
        (weekday, blocks) => MapEntry(weekday.toString(), blocks),
      ),
      'negotiations': negotiations.map((e) => e.toMap()).toList(),
      'depositTakenAt': depositTakenAt?.toIso8601String(),
      'soldAt': soldAt?.toIso8601String(),
      'finalBrokerId': finalBrokerId,
      'finalPrice': finalPrice,
      'verificationStatus': verificationStatus?.toString().split('.').last,
      'verificationRequestedAt': verificationRequestedAt?.toIso8601String(),
      'verifiedAt': verifiedAt?.toIso8601String(),
      'verifiedBy': verifiedBy,
      'rejectionReason': rejectionReason,
      'duplicatePropertyId': duplicatePropertyId,
      'isExternalListing': isExternalListing,
      'externalSellerName': externalSellerName,
      'externalSellerPhone': externalSellerPhone,
      'externalSource': externalSource,
      'externalListingUrl': externalListingUrl,
      'linkedUserId': linkedUserId,
      'viewCount': viewCount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isActive': isActive,
      'isDeleted': isDeleted,
    };
  }

  factory MLSProperty.fromMap(Map<String, dynamic> map) {
    return MLSProperty(
      id: map['id'] ?? '',
      propertyId: map['propertyId'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      address: map['address'] ?? '',
      roadAddress: map['roadAddress'] ?? '',
      jibunAddress: map['jibunAddress'] ?? '',
      buildingName: map['buildingName'] ?? '',
      propertyType: map['propertyType'],
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      area: map['area']?.toDouble(),
      supplyArea: map['supplyArea']?.toDouble(),
      pyeong: map['pyeong']?.toDouble(),
      floor: map['floor']?.toInt(),
      totalFloors: map['totalFloors']?.toInt(),
      rooms: map['rooms']?.toInt(),
      bathrooms: map['bathrooms']?.toInt(),
      direction: map['direction'],
      structure: map['structure'],
      transactionType: map['transactionType'] ?? '매매',
      desiredPrice: map['desiredPrice']?.toDouble() ?? 0,
      deposit: map['deposit']?.toDouble(),
      negotiable: map['negotiable'] ?? true,
      minimumPrice: map['minimumPrice']?.toDouble(),
      moveInDate: map['moveInDate'] != null ? DateTime.parse(map['moveInDate']) : null,
      moveInFlexibility: map['moveInFlexibility'] ?? 'flexible',
      repairStatus: map['repairStatus'] ?? 'partial',
      recentRepairDetails: map['recentRepairDetails'],
      options: List<String>.from(map['options'] ?? []),
      sellingPoints: List<String>.from(map['sellingPoints'] ?? []),
      notes: map['notes'],
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
      thumbnailUrl: map['thumbnailUrl'],
      videoUrl: map['videoUrl'],
      sellerPhone: map['sellerPhone'],
      virtualPhoneNumber: map['virtualPhoneNumber'],
      virtualPhoneActive: map['virtualPhoneActive'] ?? false,
      region: map['region'] ?? '',
      district: map['district'] ?? '',
      targetBrokerIds: List<String>.from(map['targetBrokerIds'] ?? []),
      broadcastedAt: map['broadcastedAt'] != null ? DateTime.parse(map['broadcastedAt']) : null,
      brokerResponses: (map['brokerResponses'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, BrokerResponse.fromMap(v)),
      ) ?? {},
      status: PropertyStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => PropertyStatus.draft,
      ),
      currentBrokerId: map['currentBrokerId'],
      statusChangedAt: map['statusChangedAt'] != null ? DateTime.parse(map['statusChangedAt']) : null,
      statusHistory: (map['statusHistory'] as List?)?.map((e) => StatusHistory.fromMap(e)).toList() ?? [],
      visitRequests: (map['visitRequests'] as List?)?.map((e) => VisitRequest.fromMap(e)).toList() ?? [],
      visitSchedules: (map['visitSchedules'] as List?)?.map((e) => VisitSchedule.fromMap(e)).toList() ?? [],
      availableSlots: (map['availableSlots'] as Map<String, dynamic>?)?.map(
        (date, slots) => MapEntry(
          date,
          (slots as List).map((s) => TimeSlot.fromMap(s)).toList(),
        ),
      ) ?? {},
      weeklyTimeBlocks: (map['weeklyTimeBlocks'] as Map<String, dynamic>?)?.map(
        (weekday, blocks) => MapEntry(
          int.parse(weekday),
          List<String>.from(blocks ?? []),
        ),
      ) ?? {},
      negotiations: (map['negotiations'] as List?)?.map((e) => NegotiationLog.fromMap(e)).toList() ?? [],
      depositTakenAt: map['depositTakenAt'] != null ? DateTime.parse(map['depositTakenAt']) : null,
      soldAt: map['soldAt'] != null ? DateTime.parse(map['soldAt']) : null,
      finalBrokerId: map['finalBrokerId'],
      finalPrice: map['finalPrice']?.toDouble(),
      verificationStatus: map['verificationStatus'] != null
        ? VerificationStatus.values.firstWhere(
            (e) => e.toString().split('.').last == map['verificationStatus'],
            orElse: () => VerificationStatus.pending,
          )
        : null,
      verificationRequestedAt: map['verificationRequestedAt'] != null
        ? DateTime.parse(map['verificationRequestedAt'])
        : null,
      verifiedAt: map['verifiedAt'] != null ? DateTime.parse(map['verifiedAt']) : null,
      verifiedBy: map['verifiedBy'],
      rejectionReason: map['rejectionReason'],
      duplicatePropertyId: map['duplicatePropertyId'],
      isExternalListing: map['isExternalListing'] ?? false,
      externalSellerName: map['externalSellerName'],
      externalSellerPhone: map['externalSellerPhone'],
      externalSource: map['externalSource'],
      externalListingUrl: map['externalListingUrl'],
      linkedUserId: map['linkedUserId'],
      viewCount: (map['viewCount'] as num?)?.toInt() ?? 0,
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : DateTime.now(),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : DateTime.now(),
      isActive: map['isActive'] ?? true,
      isDeleted: map['isDeleted'] ?? false,
    );
  }

  MLSProperty copyWith({
    String? id,
    String? propertyId,
    String? userId,
    String? userName,
    String? address,
    String? roadAddress,
    String? jibunAddress,
    String? buildingName,
    String? propertyType,
    double? latitude,
    double? longitude,
    double? area,
    double? supplyArea,
    double? pyeong,
    int? floor,
    int? totalFloors,
    int? rooms,
    int? bathrooms,
    String? direction,
    String? structure,
    String? transactionType,
    double? desiredPrice,
    double? deposit,
    bool? negotiable,
    double? minimumPrice,
    DateTime? moveInDate,
    String? moveInFlexibility,
    String? repairStatus,
    String? recentRepairDetails,
    List<String>? options,
    List<String>? sellingPoints,
    String? notes,
    List<String>? imageUrls,
    String? thumbnailUrl,
    String? videoUrl,
    String? sellerPhone,
    String? virtualPhoneNumber,
    bool? virtualPhoneActive,
    String? region,
    String? district,
    List<String>? targetBrokerIds,
    DateTime? broadcastedAt,
    Map<String, BrokerResponse>? brokerResponses,
    PropertyStatus? status,
    String? currentBrokerId,
    DateTime? statusChangedAt,
    List<StatusHistory>? statusHistory,
    List<VisitRequest>? visitRequests,
    List<VisitSchedule>? visitSchedules,
    Map<String, List<TimeSlot>>? availableSlots,
    Map<int, List<String>>? weeklyTimeBlocks,
    List<NegotiationLog>? negotiations,
    DateTime? depositTakenAt,
    DateTime? soldAt,
    String? finalBrokerId,
    double? finalPrice,
    VerificationStatus? verificationStatus,
    DateTime? verificationRequestedAt,
    DateTime? verifiedAt,
    String? verifiedBy,
    String? rejectionReason,
    String? duplicatePropertyId,
    bool? isExternalListing,
    String? externalSellerName,
    String? externalSellerPhone,
    String? externalSource,
    String? externalListingUrl,
    String? linkedUserId,
    int? viewCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    bool? isDeleted,
  }) {
    return MLSProperty(
      id: id ?? this.id,
      propertyId: propertyId ?? this.propertyId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      address: address ?? this.address,
      roadAddress: roadAddress ?? this.roadAddress,
      jibunAddress: jibunAddress ?? this.jibunAddress,
      buildingName: buildingName ?? this.buildingName,
      propertyType: propertyType ?? this.propertyType,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      area: area ?? this.area,
      supplyArea: supplyArea ?? this.supplyArea,
      pyeong: pyeong ?? this.pyeong,
      floor: floor ?? this.floor,
      totalFloors: totalFloors ?? this.totalFloors,
      rooms: rooms ?? this.rooms,
      bathrooms: bathrooms ?? this.bathrooms,
      direction: direction ?? this.direction,
      structure: structure ?? this.structure,
      transactionType: transactionType ?? this.transactionType,
      desiredPrice: desiredPrice ?? this.desiredPrice,
      deposit: deposit ?? this.deposit,
      negotiable: negotiable ?? this.negotiable,
      minimumPrice: minimumPrice ?? this.minimumPrice,
      moveInDate: moveInDate ?? this.moveInDate,
      moveInFlexibility: moveInFlexibility ?? this.moveInFlexibility,
      repairStatus: repairStatus ?? this.repairStatus,
      recentRepairDetails: recentRepairDetails ?? this.recentRepairDetails,
      options: options ?? this.options,
      sellingPoints: sellingPoints ?? this.sellingPoints,
      notes: notes ?? this.notes,
      imageUrls: imageUrls ?? this.imageUrls,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      sellerPhone: sellerPhone ?? this.sellerPhone,
      virtualPhoneNumber: virtualPhoneNumber ?? this.virtualPhoneNumber,
      virtualPhoneActive: virtualPhoneActive ?? this.virtualPhoneActive,
      region: region ?? this.region,
      district: district ?? this.district,
      targetBrokerIds: targetBrokerIds ?? this.targetBrokerIds,
      broadcastedAt: broadcastedAt ?? this.broadcastedAt,
      brokerResponses: brokerResponses ?? this.brokerResponses,
      status: status ?? this.status,
      currentBrokerId: currentBrokerId ?? this.currentBrokerId,
      statusChangedAt: statusChangedAt ?? this.statusChangedAt,
      statusHistory: statusHistory ?? this.statusHistory,
      visitRequests: visitRequests ?? this.visitRequests,
      visitSchedules: visitSchedules ?? this.visitSchedules,
      availableSlots: availableSlots ?? this.availableSlots,
      weeklyTimeBlocks: weeklyTimeBlocks ?? this.weeklyTimeBlocks,
      negotiations: negotiations ?? this.negotiations,
      depositTakenAt: depositTakenAt ?? this.depositTakenAt,
      soldAt: soldAt ?? this.soldAt,
      finalBrokerId: finalBrokerId ?? this.finalBrokerId,
      finalPrice: finalPrice ?? this.finalPrice,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      verificationRequestedAt: verificationRequestedAt ?? this.verificationRequestedAt,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      duplicatePropertyId: duplicatePropertyId ?? this.duplicatePropertyId,
      isExternalListing: isExternalListing ?? this.isExternalListing,
      externalSellerName: externalSellerName ?? this.externalSellerName,
      externalSellerPhone: externalSellerPhone ?? this.externalSellerPhone,
      externalSource: externalSource ?? this.externalSource,
      externalListingUrl: externalListingUrl ?? this.externalListingUrl,
      linkedUserId: linkedUserId ?? this.linkedUserId,
      viewCount: viewCount ?? this.viewCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}

/// 매물 상태 (단일 상태 머신)
enum PropertyStatus {
  draft, // 임시저장
  pending, // 검증 대기 (NEW - 등록 후 검증 전)
  rejected, // 검증 거절 (NEW - 중복/허위 매물)
  active, // 활성 (검증 완료, 중개사 배포)
  inquiry, // 문의 중 (방문 일정 잡힘)
  underOffer, // 협의 중 (네고 진행)
  depositTaken, // 가계약 완료
  sold, // 거래 완료
  cancelled, // 취소
}

/// 매물 검증 상태
enum VerificationStatus {
  pending, // 검증 대기
  addressDuplicate, // 주소 중복 감지
  autoApproved, // 자동 승인 (중복 없음)
  adminApproved, // 관리자 승인
  rejected, // 거절됨
}

/// 중개사 응답 정보 (매물 배포 수신 현황)
///
/// 중개사가 매물을 받고 열람했는지 추적.
/// 실제 방문 요청은 VisitRequest 모델에서 관리.
class BrokerResponse {
  final String brokerId;
  final String brokerName;
  final String? brokerCompany; // 중개사무소명
  final String? brokerPhone; // 연락처 (승인 후 공개)
  final BrokerStage stage; // received, viewed, requested, approved, completed
  final DateTime receivedAt; // 배포 수신 시각
  final DateTime? viewedAt; // 열람 시각

  BrokerResponse({
    required this.brokerId,
    required this.brokerName,
    required this.receivedAt, this.brokerCompany,
    this.brokerPhone,
    this.stage = BrokerStage.received,
    this.viewedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'brokerId': brokerId,
      'brokerName': brokerName,
      'brokerCompany': brokerCompany,
      'brokerPhone': brokerPhone,
      'stage': stage.toString().split('.').last,
      'receivedAt': receivedAt.toIso8601String(),
      'viewedAt': viewedAt?.toIso8601String(),
    };
  }

  factory BrokerResponse.fromMap(Map<String, dynamic> map) {
    // 레거시 데이터 호환: respondedAt → receivedAt
    final receivedAt = map['receivedAt'] ?? map['respondedAt'];

    // 레거시 stage 매핑
    String stageStr = map['stage'] ?? 'received';
    if (stageStr == 'waiting') stageStr = 'received';
    if (stageStr == 'inquiry') stageStr = 'viewed';
    if (stageStr == 'visiting') stageStr = 'requested';
    if (stageStr == 'negotiating') stageStr = 'approved';
    if (stageStr == 'depositOffer') stageStr = 'completed';

    return BrokerResponse(
      brokerId: map['brokerId'] ?? '',
      brokerName: map['brokerName'] ?? '',
      brokerCompany: map['brokerCompany'],
      brokerPhone: map['brokerPhone'],
      stage: BrokerStage.values.firstWhere(
        (e) => e.toString().split('.').last == stageStr,
        orElse: () => BrokerStage.received,
      ),
      receivedAt: receivedAt != null ? DateTime.parse(receivedAt) : DateTime.now(),
      viewedAt: map['viewedAt'] != null ? DateTime.parse(map['viewedAt']) : null,
    );
  }

  BrokerResponse copyWith({
    String? brokerId,
    String? brokerName,
    String? brokerCompany,
    String? brokerPhone,
    BrokerStage? stage,
    DateTime? receivedAt,
    DateTime? viewedAt,
  }) {
    return BrokerResponse(
      brokerId: brokerId ?? this.brokerId,
      brokerName: brokerName ?? this.brokerName,
      brokerCompany: brokerCompany ?? this.brokerCompany,
      brokerPhone: brokerPhone ?? this.brokerPhone,
      stage: stage ?? this.stage,
      receivedAt: receivedAt ?? this.receivedAt,
      viewedAt: viewedAt ?? this.viewedAt,
    );
  }

  /// 열람 여부
  bool get hasViewed => viewedAt != null || stage != BrokerStage.received;

  /// 방문 요청 여부
  bool get hasRequested => stage == BrokerStage.requested ||
                           stage == BrokerStage.approved ||
                           stage == BrokerStage.completed;

  /// 연락처 공개 여부 (승인된 경우)
  bool get isContactVisible => stage == BrokerStage.approved || stage == BrokerStage.completed;
}

/// 방문 요청 모델 (핵심 상호작용)
///
/// 중개사가 매수/임차 희망자를 데리고 방문하고 싶을 때 요청.
/// 필수 정보: 희망가, 방문 희망 일시
/// 판매자/임대인이 승인하면 연락처 상호 교환 → 앱 역할 종료
class VisitRequest {
  final String id; // 요청 고유 ID
  final String propertyId; // 매물 ID
  final String brokerId;
  final String brokerName;
  final String? brokerCompany;
  final String? brokerPhone; // 승인 후 공개

  // 희망가 (필수)
  final double proposedPrice; // 희망가 (매매가/전세금/월세)

  // 방문 일시 (필수)
  final DateTime requestedDateTime; // 희망 방문 일시

  // 추가 정보 (선택)
  final String? message; // 중개사 메모/요청사항

  // 상태 관리
  final VisitRequestStatus status;
  final DateTime createdAt;
  final DateTime? respondedAt; // 판매자 응답 시각

  // 판매자 응답
  final String? sellerResponse; // 승인/거절 메시지
  final DateTime? alternativeDateTime; // 다른 시간 제안 (status가 reschedule일 때)

  // 연락처 교환 정보 (승인 후)
  final String? sellerPhone; // 판매자 연락처 (승인 시 공개)
  final DateTime? contactExchangedAt; // 연락처 교환 시각

  // 방문 완료 추적 (노쇼 측정용)
  final DateTime? visitCompletedAt; // 실제 방문 완료 시각
  final bool noShow; // 노쇼 여부 (승인 후 미방문)
  final String? visitFeedback; // 방문 후 피드백

  VisitRequest({
    required this.id,
    required this.propertyId,
    required this.brokerId,
    required this.brokerName,
    required this.proposedPrice, required this.requestedDateTime, required this.createdAt, this.brokerCompany,
    this.brokerPhone,
    this.message,
    this.status = VisitRequestStatus.pending,
    this.respondedAt,
    this.sellerResponse,
    this.alternativeDateTime,
    this.sellerPhone,
    this.contactExchangedAt,
    this.visitCompletedAt,
    this.noShow = false,
    this.visitFeedback,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'propertyId': propertyId,
      'brokerId': brokerId,
      'brokerName': brokerName,
      'brokerCompany': brokerCompany,
      'brokerPhone': brokerPhone,
      'proposedPrice': proposedPrice,
      'requestedDateTime': requestedDateTime.toIso8601String(),
      'message': message,
      'status': status.toString().split('.').last,
      'createdAt': createdAt.toIso8601String(),
      'respondedAt': respondedAt?.toIso8601String(),
      'sellerResponse': sellerResponse,
      'alternativeDateTime': alternativeDateTime?.toIso8601String(),
      'sellerPhone': sellerPhone,
      'contactExchangedAt': contactExchangedAt?.toIso8601String(),
      'visitCompletedAt': visitCompletedAt?.toIso8601String(),
      'noShow': noShow,
      'visitFeedback': visitFeedback,
    };
  }

  factory VisitRequest.fromMap(Map<String, dynamic> map) {
    return VisitRequest(
      id: map['id'] ?? '',
      propertyId: map['propertyId'] ?? '',
      brokerId: map['brokerId'] ?? '',
      brokerName: map['brokerName'] ?? '',
      brokerCompany: map['brokerCompany'],
      brokerPhone: map['brokerPhone'],
      proposedPrice: map['proposedPrice']?.toDouble() ?? 0,
      requestedDateTime: map['requestedDateTime'] != null
          ? DateTime.parse(map['requestedDateTime'])
          : DateTime.now(),
      message: map['message'],
      status: VisitRequestStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => VisitRequestStatus.pending,
      ),
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : DateTime.now(),
      respondedAt: map['respondedAt'] != null ? DateTime.parse(map['respondedAt']) : null,
      sellerResponse: map['sellerResponse'],
      alternativeDateTime: map['alternativeDateTime'] != null
          ? DateTime.parse(map['alternativeDateTime'])
          : null,
      sellerPhone: map['sellerPhone'],
      contactExchangedAt: map['contactExchangedAt'] != null
          ? DateTime.parse(map['contactExchangedAt'])
          : null,
      visitCompletedAt: map['visitCompletedAt'] != null
          ? DateTime.parse(map['visitCompletedAt'])
          : null,
      noShow: map['noShow'] ?? false,
      visitFeedback: map['visitFeedback'],
    );
  }

  VisitRequest copyWith({
    String? id,
    String? propertyId,
    String? brokerId,
    String? brokerName,
    String? brokerCompany,
    String? brokerPhone,
    double? proposedPrice,
    DateTime? requestedDateTime,
    String? message,
    VisitRequestStatus? status,
    DateTime? createdAt,
    DateTime? respondedAt,
    String? sellerResponse,
    DateTime? alternativeDateTime,
    String? sellerPhone,
    DateTime? contactExchangedAt,
    DateTime? visitCompletedAt,
    bool? noShow,
    String? visitFeedback,
  }) {
    return VisitRequest(
      id: id ?? this.id,
      propertyId: propertyId ?? this.propertyId,
      brokerId: brokerId ?? this.brokerId,
      brokerName: brokerName ?? this.brokerName,
      brokerCompany: brokerCompany ?? this.brokerCompany,
      brokerPhone: brokerPhone ?? this.brokerPhone,
      proposedPrice: proposedPrice ?? this.proposedPrice,
      requestedDateTime: requestedDateTime ?? this.requestedDateTime,
      message: message ?? this.message,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
      sellerResponse: sellerResponse ?? this.sellerResponse,
      alternativeDateTime: alternativeDateTime ?? this.alternativeDateTime,
      sellerPhone: sellerPhone ?? this.sellerPhone,
      contactExchangedAt: contactExchangedAt ?? this.contactExchangedAt,
      visitCompletedAt: visitCompletedAt ?? this.visitCompletedAt,
      noShow: noShow ?? this.noShow,
      visitFeedback: visitFeedback ?? this.visitFeedback,
    );
  }

  /// 응답 대기 여부
  bool get isPending => status == VisitRequestStatus.pending;

  /// 승인 여부
  bool get isApproved => status == VisitRequestStatus.approved;

  /// 연락처 교환 완료 여부
  bool get isContactExchanged => contactExchangedAt != null;
}

/// 방문 요청 상태
enum VisitRequestStatus {
  pending,     // 대기 중 (판매자 응답 필요)
  approved,    // 승인됨 (연락처 교환 완료)
  rejected,    // 거절됨
  reschedule,  // 다른 시간 제안
  cancelled,   // 취소됨 (중개사가 취소)
  expired,     // 만료됨 (응답 없이 시간 지남)
}

/// 중개사 상태 (매물 배포 기준)
///
/// 핵심 흐름: 배포 → 열람 → 방문요청 → 승인(연락처 교환) → 앱 역할 종료
enum BrokerStage {
  received,   // 배포 받음 (알림만)
  viewed,     // 매물 열람함
  requested,  // 방문 요청함 (구체적 조건 제시)
  approved,   // 방문 승인됨 (연락처 교환 완료)
  completed,  // 거래 완료 (선택적 피드백)
}

// ResponseStatus enum 제거됨 - BrokerStage로 통합

/// 상태 변경 이력
class StatusHistory {
  final PropertyStatus from;
  final PropertyStatus to;
  final DateTime changedAt;
  final String? changedBy; // userId or brokerId
  final String? reason;

  StatusHistory({
    required this.from,
    required this.to,
    required this.changedAt,
    this.changedBy,
    this.reason,
  });

  Map<String, dynamic> toMap() {
    return {
      'from': from.toString().split('.').last,
      'to': to.toString().split('.').last,
      'changedAt': changedAt.toIso8601String(),
      'changedBy': changedBy,
      'reason': reason,
    };
  }

  factory StatusHistory.fromMap(Map<String, dynamic> map) {
    return StatusHistory(
      from: PropertyStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['from'],
        orElse: () => PropertyStatus.draft,
      ),
      to: PropertyStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['to'],
        orElse: () => PropertyStatus.active,
      ),
      changedAt: map['changedAt'] != null ? DateTime.parse(map['changedAt']) : DateTime.now(),
      changedBy: map['changedBy'],
      reason: map['reason'],
    );
  }
}

/// 방문 일정
class VisitSchedule {
  final String id;
  final String brokerId;
  final String brokerName;
  final DateTime scheduledAt;
  final VisitStatus status; // requested, approved, rejected, completed, cancelled
  final String? note; // 중개사 메모
  final String? feedback; // 방문 후 피드백
  final DateTime? feedbackSubmittedAt;

  VisitSchedule({
    required this.id,
    required this.brokerId,
    required this.brokerName,
    required this.scheduledAt,
    this.status = VisitStatus.requested,
    this.note,
    this.feedback,
    this.feedbackSubmittedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'brokerId': brokerId,
      'brokerName': brokerName,
      'scheduledAt': scheduledAt.toIso8601String(),
      'status': status.toString().split('.').last,
      'note': note,
      'feedback': feedback,
      'feedbackSubmittedAt': feedbackSubmittedAt?.toIso8601String(),
    };
  }

  factory VisitSchedule.fromMap(Map<String, dynamic> map) {
    return VisitSchedule(
      id: map['id'] ?? '',
      brokerId: map['brokerId'] ?? '',
      brokerName: map['brokerName'] ?? '',
      scheduledAt: map['scheduledAt'] != null ? DateTime.parse(map['scheduledAt']) : DateTime.now(),
      status: VisitStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => VisitStatus.requested,
      ),
      note: map['note'],
      feedback: map['feedback'],
      feedbackSubmittedAt: map['feedbackSubmittedAt'] != null ? DateTime.parse(map['feedbackSubmittedAt']) : null,
    );
  }
}

enum VisitStatus {
  requested, // 요청됨
  approved, // 승인됨
  rejected, // 거절됨
  completed, // 완료됨
  cancelled, // 취소됨
}

/// 시간대 슬롯
class TimeSlot {
  final String startTime; // HH:mm
  final String endTime; // HH:mm
  final bool isAvailable;

  TimeSlot({
    required this.startTime,
    required this.endTime,
    this.isAvailable = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'startTime': startTime,
      'endTime': endTime,
      'isAvailable': isAvailable,
    };
  }

  factory TimeSlot.fromMap(Map<String, dynamic> map) {
    return TimeSlot(
      startTime: map['startTime'] ?? '',
      endTime: map['endTime'] ?? '',
      isAvailable: map['isAvailable'] ?? true,
    );
  }
}

/// 협의 로그
class NegotiationLog {
  final String id;
  final String brokerId;
  final String brokerName;
  final double? proposedPrice; // 제안 가격
  final DateTime? proposedMoveInDate; // 제안 이사일
  final String? conditions; // 조건 (잔금일, 옵션 등)
  final String? buyerFeedback; // 매수자 반응
  final DateTime createdAt;

  NegotiationLog({
    required this.id,
    required this.brokerId,
    required this.brokerName,
    required this.createdAt, this.proposedPrice,
    this.proposedMoveInDate,
    this.conditions,
    this.buyerFeedback,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'brokerId': brokerId,
      'brokerName': brokerName,
      'proposedPrice': proposedPrice,
      'proposedMoveInDate': proposedMoveInDate?.toIso8601String(),
      'conditions': conditions,
      'buyerFeedback': buyerFeedback,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory NegotiationLog.fromMap(Map<String, dynamic> map) {
    return NegotiationLog(
      id: map['id'] ?? '',
      brokerId: map['brokerId'] ?? '',
      brokerName: map['brokerName'] ?? '',
      proposedPrice: map['proposedPrice']?.toDouble(),
      proposedMoveInDate: map['proposedMoveInDate'] != null ? DateTime.parse(map['proposedMoveInDate']) : null,
      conditions: map['conditions'],
      buyerFeedback: map['buyerFeedback'],
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : DateTime.now(),
    );
  }
}
