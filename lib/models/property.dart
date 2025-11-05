class Property {
  final int? id;  // SQLite database ID (AUTO INCREMENT)
  final String? firestoreId;  // Firestore document ID
  final String address;
  final String? addressCity; // 주소에서 추출한 시단위
  final String transactionType; // 매매, 전세, 월세
  final int price;
  final String description;
  final String registerData; // JSON 문자열로 저장된 등기부등본 데이터
  final String registerSummary; // 핵심 정보만 담은 JSON
  final String contractStatus;
  final String mainContractor; // 대표 계약자
  final String contractor; // 계약자(한글/영문 이름)
  final String? registeredBy; // 매물 등록자 ID
  final String? registeredByName; // 매물 등록자 이름
  final Map<String, dynamic>? registeredByInfo; // 등록자 상세 정보
  
  // 사용자 정보 (등기부등본과 완전히 분리)
  final String? userMainContractor; // 사용자가 설정한 대표 계약자
  final String? userContractor; // 사용자가 설정한 계약자
  final String? userContactInfo; // 사용자 연락처
  final String? userNotes; // 사용자 메모
  final Map<String, dynamic>? brokerInfo; // 중개업자 정보
  final String? brokerId; // 중개업자 ID
  
  final DateTime createdAt;
  
  // 추가 부동산 정보 필드들
  final String? buildingName; // 건물명
  final String? buildingType; // 건물 유형 (아파트, 빌라, 단독주택 등)
  final int? totalFloors; // 전체 층수
  final int? floor; // 해당 층
  final double? area; // 면적 (제곱미터)
  final String? structure; // 구조 (철근콘크리트, 목조 등)
  final String? landPurpose; // 토지 지목
  final double? landArea; // 토지 면적
  final String? ownerName; // 소유자명
  final String? ownerInfo; // 소유자 상세정보
  final List<String>? liens; // 권리사항 (저당권 등)
  final String? publishDate; // 등기부등본 발급일
  final String? officeName; // 발급기관
  final String? publishNo; // 발급번호
  final String? uniqueNo; // 고유번호
  final String? issueNo; // 발행번호
  final String? realtyDesc; // 부동산 표시
  final String? receiptDate; // 접수일
  final String? cause; // 원인
  final String? purpose; // 목적
  final List<Map<String, dynamic>>? floorAreas; // 층별 면적 정보
  final String? estimatedValue; // 감정가
  final String? marketValue; // 시세
  final String? aiConfidence; // AI 신뢰도
  final String? recentTransaction; // 최근 거래가
  final String? priceHistory; // 가격 변동 이력 (JSON)
  final String? nearbyPrices; // 주변 시세 (JSON)
  final String? propertyImages; // 부동산 이미지 URL들 (JSON)
  final String? notes; // 메모
  final String? status; // 상태 (판매중, 계약완료, 임대중 등)
  final DateTime? updatedAt; // 수정일시
  
  // 등기부등본 상세 정보 필드들
  final String? docTitle; // 문서 제목
  final String? competentRegistryOffice; // 관할 등기소
  final String? transactionId; // 거래 ID
  final String? resultCode; // 결과 코드
  final String? resultMessage; // 결과 메시지
  
  // 소유권 정보 (갑구)
  final List<Map<String, dynamic>>? ownershipHistory; // 소유권 이전 내역
  final List<Map<String, dynamic>>? currentOwners; // 현재 소유자 목록
  final String? ownershipRatio; // 소유지분
  
  // 권리사항 정보 (을구)
  final List<Map<String, dynamic>>? lienHistory; // 권리사항 이력
  final List<Map<String, dynamic>>? currentLiens; // 현재 권리사항
  final String? totalLienAmount; // 총 권리금액
  
  // 건물 상세 정보
  final String? buildingNumber; // 건물번호
  final String? exclusiveArea; // 전용면적
  final String? commonArea; // 공용면적
  final String? parkingArea; // 주차면적
  final String? buildingYear; // 건축년도
  final String? buildingPermit; // 건축허가
  
  // 토지 상세 정보
  final String? landNumber; // 토지번호
  final String? landRatio; // 토지지분
  final String? landUse; // 토지용도
  final String? landCategory; // 토지분류
  
  // 등기부등본 원본 데이터 (구조화된)
  final Map<String, dynamic>? registerHeader; // 등기부등본 헤더
  final Map<String, dynamic>? registerOwnership; // 소유권 정보
  final Map<String, dynamic>? registerLiens; // 권리사항 정보
  final Map<String, dynamic>? registerBuilding; // 건물 정보
  final Map<String, dynamic>? registerLand; // 토지 정보
  final Map<String, dynamic>? registerSummaryData; // 요약 정보
  
  // 상세정보 입력 폼 데이터
  final Map<String, dynamic>? detailFormData; // 상세정보 입력 폼 데이터
  final String? detailFormJson; // 상세정보 입력 폼 JSON
  final Map<String, bool>? selectedClauses; // 선택된 특약사항들

  // API 리턴값 - 필요시 사용해야 함 (현재로써는 주소 위도 경도 API 호출위해 사용)
  Map<String,String> fullAddrAPIData;

  Property({
    this.id,
    this.firestoreId,
    required this.address,
    this.addressCity,
    required this.transactionType,
    required this.price,
    this.description = '',
    this.registerData = '{}',
    this.registerSummary = '',
    this.contractStatus = '대기',
    this.mainContractor = '',
    this.contractor = '',
    this.registeredBy,
    this.registeredByName,
    this.registeredByInfo,
    DateTime? createdAt,
    this.buildingName,
    this.buildingType,
    this.totalFloors,
    this.floor,
    this.area,
    this.structure,
    this.landPurpose,
    this.landArea,
    this.ownerName,
    this.ownerInfo,
    this.liens,
    this.publishDate,
    this.officeName,
    this.publishNo,
    this.uniqueNo,
    this.issueNo,
    this.realtyDesc,
    this.receiptDate,
    this.cause,
    this.purpose,
    this.floorAreas,
    this.estimatedValue,
    this.marketValue,
    this.aiConfidence,
    this.recentTransaction,
    this.priceHistory,
    this.nearbyPrices,
    this.propertyImages,
    this.notes,
    this.status,
    DateTime? updatedAt,
    this.docTitle,
    this.competentRegistryOffice,
    this.transactionId,
    this.resultCode,
    this.resultMessage,
    this.ownershipHistory,
    this.currentOwners,
    this.ownershipRatio,
    this.lienHistory,
    this.currentLiens,
    this.totalLienAmount,
    this.buildingNumber,
    this.exclusiveArea,
    this.commonArea,
    this.parkingArea,
    this.buildingYear,
    this.buildingPermit,
    this.landNumber,
    this.landRatio,
    this.landUse,
    this.landCategory,
    this.registerHeader,
    this.registerOwnership,
    this.registerLiens,
    this.registerBuilding,
    this.registerLand,
    this.registerSummaryData,
    this.detailFormData,
    this.detailFormJson,
    this.selectedClauses,
    this.userMainContractor,
    this.userContractor,
    this.userContactInfo,
    this.userNotes,
    this.brokerInfo,
    this.brokerId,
    this.fullAddrAPIData = const {}, //FIXME
  })  : createdAt = createdAt ?? DateTime.now(), // bit confusing but works
        updatedAt = updatedAt ?? DateTime.now();


  Map<String, dynamic> toMap() {
    final map = {
      'address': address,
      'addressCity': addressCity,
      'firestoreId': firestoreId,
      'transactionType': transactionType,
      'price': price,
      'description': description,
      'registerData': registerData,
      'registerSummary': registerSummary,
      'contractStatus': contractStatus,
      'mainContractor': mainContractor,
      'contractor': contractor,
      'registeredBy': registeredBy,
      'registeredByName': registeredByName,
      'registeredByInfo': registeredByInfo,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
    
    // 추가 필드들 (null이 아닌 경우만 추가)
    if (buildingName != null) map['buildingName'] = buildingName;
    if (buildingType != null) map['buildingType'] = buildingType;
    if (totalFloors != null) map['totalFloors'] = totalFloors;
    if (floor != null) map['floor'] = floor;
    if (area != null) map['area'] = area;
    if (structure != null) map['structure'] = structure;
    if (landPurpose != null) map['landPurpose'] = landPurpose;
    if (landArea != null) map['landArea'] = landArea;
    if (ownerName != null) map['ownerName'] = ownerName;
    if (ownerInfo != null) map['ownerInfo'] = ownerInfo;
    if (liens != null) map['liens'] = liens;
    if (publishDate != null) map['publishDate'] = publishDate;
    if (officeName != null) map['officeName'] = officeName;
    if (publishNo != null) map['publishNo'] = publishNo;
    if (uniqueNo != null) map['uniqueNo'] = uniqueNo;
    if (issueNo != null) map['issueNo'] = issueNo;
    if (realtyDesc != null) map['realtyDesc'] = realtyDesc;
    if (receiptDate != null) map['receiptDate'] = receiptDate;
    if (cause != null) map['cause'] = cause;
    if (purpose != null) map['purpose'] = purpose;
    if (floorAreas != null) map['floorAreas'] = floorAreas;
    if (estimatedValue != null) map['estimatedValue'] = estimatedValue;
    if (marketValue != null) map['marketValue'] = marketValue;
    if (aiConfidence != null) map['aiConfidence'] = aiConfidence;
    if (recentTransaction != null) map['recentTransaction'] = recentTransaction;
    if (priceHistory != null) map['priceHistory'] = priceHistory;
    if (nearbyPrices != null) map['nearbyPrices'] = nearbyPrices;
    if (propertyImages != null) map['propertyImages'] = propertyImages;
    if (notes != null) map['notes'] = notes;
    if (status != null) map['status'] = status;
    
    // 등기부등본 상세 정보 필드들
    if (docTitle != null) map['docTitle'] = docTitle;
    if (competentRegistryOffice != null) map['competentRegistryOffice'] = competentRegistryOffice;
    if (transactionId != null) map['transactionId'] = transactionId;
    if (resultCode != null) map['resultCode'] = resultCode;
    if (resultMessage != null) map['resultMessage'] = resultMessage;
    if (ownershipHistory != null) map['ownershipHistory'] = ownershipHistory;
    if (currentOwners != null) map['currentOwners'] = currentOwners;
    if (ownershipRatio != null) map['ownershipRatio'] = ownershipRatio;
    if (lienHistory != null) map['lienHistory'] = lienHistory;
    if (currentLiens != null) map['currentLiens'] = currentLiens;
    if (totalLienAmount != null) map['totalLienAmount'] = totalLienAmount;
    if (buildingNumber != null) map['buildingNumber'] = buildingNumber;
    if (exclusiveArea != null) map['exclusiveArea'] = exclusiveArea;
    if (commonArea != null) map['commonArea'] = commonArea;
    if (parkingArea != null) map['parkingArea'] = parkingArea;
    if (buildingYear != null) map['buildingYear'] = buildingYear;
    if (buildingPermit != null) map['buildingPermit'] = buildingPermit;
    if (landNumber != null) map['landNumber'] = landNumber;
    if (landRatio != null) map['landRatio'] = landRatio;
    if (landUse != null) map['landUse'] = landUse;
    if (landCategory != null) map['landCategory'] = landCategory;
    if (registerHeader != null) map['registerHeader'] = registerHeader;
    if (registerOwnership != null) map['registerOwnership'] = registerOwnership;
    if (registerLiens != null) map['registerLiens'] = registerLiens;
    if (registerBuilding != null) map['registerBuilding'] = registerBuilding;
    if (registerLand != null) map['registerLand'] = registerLand;
    if (registerSummaryData != null) map['registerSummaryData'] = registerSummaryData;
    
    // 상세정보 입력 폼 데이터
    if (detailFormData != null) map['detailFormData'] = detailFormData;
    if (detailFormJson != null) map['detailFormJson'] = detailFormJson;
    if (selectedClauses != null) map['selectedClauses'] = selectedClauses;
    
    // 사용자 정보 필드들
    if (userMainContractor != null) map['userMainContractor'] = userMainContractor;
    if (userContractor != null) map['userContractor'] = userContractor;
    if (userContactInfo != null) map['userContactInfo'] = userContactInfo;
    if (userNotes != null) map['userNotes'] = userNotes;
    if (brokerInfo != null) map['brokerInfo'] = brokerInfo;
    if (brokerId != null) map['brokerId'] = brokerId;
    
    // id가 있을 때만 map에 추가 (INSERT 시에는 AUTO INCREMENT를 위해 제외)
    if (id != null) {
      map['id'] = id as Object;
    }
    
    return map;
  }

  static Property fromMap(Map<String, dynamic> map) {
    return Property(
      id: map['id'] is int ? map['id'] as int : int.tryParse(map['id']?.toString() ?? ''),
      firestoreId: map['firestoreId']?.toString(),
      address: map['address']?.toString() ?? '',
      addressCity: map['addressCity']?.toString(),
      transactionType: map['transactionType']?.toString() ?? '',
      price: map['price'] is int ? map['price'] as int : int.tryParse(map['price']?.toString() ?? '0') ?? 0,
      description: map['description']?.toString() ?? '',
      registerData: map['registerData']?.toString() ?? '{}',
      registerSummary: map['registerSummary']?.toString() ?? '',
      contractStatus: map['contractStatus']?.toString() ?? '대기',
      mainContractor: map['mainContractor']?.toString() ?? '',
      contractor: map['contractor']?.toString() ?? '',
      registeredBy: map['registeredBy']?.toString(),
      registeredByName: map['registeredByName']?.toString(),
      registeredByInfo: map['registeredByInfo'] != null ? Map<String, dynamic>.from(map['registeredByInfo']) : null,
      createdAt: map['createdAt'] != null
        ? (map['createdAt'] is DateTime 
            ? map['createdAt'] as DateTime
            : DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now())
        : DateTime.now(),
      buildingName: map['buildingName']?.toString(),
      buildingType: map['buildingType']?.toString(),
      totalFloors: map['totalFloors'] is int ? map['totalFloors'] as int : int.tryParse(map['totalFloors']?.toString() ?? ''),
      floor: map['floor'] is int ? map['floor'] as int : int.tryParse(map['floor']?.toString() ?? ''),
      area: map['area'] is double ? map['area'] as double : double.tryParse(map['area']?.toString() ?? ''),
      structure: map['structure']?.toString(),
      landPurpose: map['landPurpose']?.toString(),
      landArea: map['landArea'] is double ? map['landArea'] as double : double.tryParse(map['landArea']?.toString() ?? ''),
      ownerName: map['ownerName']?.toString(),
      ownerInfo: map['ownerInfo']?.toString(),
      liens: map['liens'] != null ? List<String>.from(map['liens']) : null,
      publishDate: map['publishDate']?.toString(),
      officeName: map['officeName']?.toString(),
      publishNo: map['publishNo']?.toString(),
      uniqueNo: map['uniqueNo']?.toString(),
      issueNo: map['issueNo']?.toString(),
      realtyDesc: map['realtyDesc']?.toString(),
      receiptDate: map['receiptDate']?.toString(),
      cause: map['cause']?.toString(),
      purpose: map['purpose']?.toString(),
      // floorAreas 변환 및 로그
      floorAreas: (() {
        final raw = map['floorAreas'];
        if (raw is List) {
          final filtered = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
          return filtered;
        }
        return null;
      })(),
      estimatedValue: map['estimatedValue']?.toString(),
      marketValue: map['marketValue']?.toString(),
      aiConfidence: map['aiConfidence']?.toString(),
      recentTransaction: map['recentTransaction']?.toString(),
      priceHistory: map['priceHistory']?.toString(),
      nearbyPrices: map['nearbyPrices']?.toString(),
      propertyImages: map['propertyImages']?.toString(),
      notes: map['notes']?.toString(),
      status: map['status']?.toString(),
      updatedAt: map['updatedAt'] != null 
          ? (map['updatedAt'] is DateTime 
              ? map['updatedAt'] as DateTime
              : DateTime.tryParse(map['updatedAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
      docTitle: map['docTitle']?.toString(),
      competentRegistryOffice: map['competentRegistryOffice']?.toString(),
      transactionId: map['transactionId']?.toString(),
      resultCode: map['resultCode']?.toString(),
      resultMessage: map['resultMessage']?.toString(),
      // ownershipHistory 변환 및 로그
      ownershipHistory: (() {
        final raw = map['ownershipHistory'];
        if (raw is List) {
          final filtered = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
          return filtered;
        }
        return null;
      })(),
      // currentOwners 변환 및 로그
      currentOwners: (() {
        final raw = map['currentOwners'];
        if (raw is List) {
          final filtered = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
          return filtered;
        }
        return null;
      })(),
      ownershipRatio: map['ownershipRatio']?.toString(),
      // lienHistory 변환 및 로그
      lienHistory: (() {
        final raw = map['lienHistory'];
        if (raw is List) {
          final filtered = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
          return filtered;
        }
        return null;
      })(),
      // currentLiens 변환 및 로그
      currentLiens: (() {
        final raw = map['currentLiens'];
        if (raw is List) {
          final filtered = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
          return filtered;
        }
        return null;
      })(),
      totalLienAmount: map['totalLienAmount']?.toString(),
      buildingNumber: map['buildingNumber']?.toString(),
      exclusiveArea: map['exclusiveArea']?.toString(),
      commonArea: map['commonArea']?.toString(),
      parkingArea: map['parkingArea']?.toString(),
      buildingYear: map['buildingYear']?.toString(),
      buildingPermit: map['buildingPermit']?.toString(),
      landNumber: map['landNumber']?.toString(),
      landRatio: map['landRatio']?.toString(),
      landUse: map['landUse']?.toString(),
      landCategory: map['landCategory']?.toString(),
      registerHeader: map['registerHeader'] != null ? Map<String, dynamic>.from(map['registerHeader']) : null,
      registerOwnership: map['registerOwnership'] != null ? Map<String, dynamic>.from(map['registerOwnership']) : null,
      registerLiens: map['registerLiens'] != null ? Map<String, dynamic>.from(map['registerLiens']) : null,
      registerBuilding: map['registerBuilding'] != null ? Map<String, dynamic>.from(map['registerBuilding']) : null,
      registerLand: map['registerLand'] != null ? Map<String, dynamic>.from(map['registerLand']) : null,
      registerSummaryData: map['registerSummaryData'] != null ? Map<String, dynamic>.from(map['registerSummaryData']) : null,
      detailFormData: map['detailFormData'] != null ? Map<String, dynamic>.from(map['detailFormData']) : null,
      detailFormJson: map['detailFormJson']?.toString(),
      selectedClauses: map['selectedClauses'] != null ? Map<String, bool>.from(map['selectedClauses']) : null,
      userMainContractor: map['userMainContractor']?.toString(),
      userContractor: map['userContractor']?.toString(),
      userContactInfo: map['userContactInfo']?.toString(),
      userNotes: map['userNotes']?.toString(),
      brokerInfo: map['brokerInfo'] != null ? Map<String, dynamic>.from(map['brokerInfo']) : null,
      brokerId: map['brokerId']?.toString(),
    );
  }

  Property copyWith({
    int? id,
    String? firestoreId,
    String? address,
    String? addressCity,
    String? transactionType,
    int? price,
    String? description,
    String? registerData,
    String? registerSummary,
    String? contractStatus,
    String? mainContractor,
    String? contractor,
    String? registeredBy,
    String? registeredByName,
    Map<String, dynamic>? registeredByInfo,
    DateTime? createdAt,
    String? buildingName,
    String? buildingType,
    int? totalFloors,
    int? floor,
    double? area,
    String? structure,
    String? landPurpose,
    double? landArea,
    String? ownerName,
    String? ownerInfo,
    List<String>? liens,
    String? publishDate,
    String? officeName,
    String? publishNo,
    String? uniqueNo,
    String? issueNo,
    String? realtyDesc,
    String? receiptDate,
    String? cause,
    String? purpose,
    List<Map<String, dynamic>>? floorAreas,
    String? estimatedValue,
    String? marketValue,
    String? aiConfidence,
    String? recentTransaction,
    String? priceHistory,
    String? nearbyPrices,
    String? propertyImages,
    String? notes,
    String? status,
    DateTime? updatedAt,
    String? docTitle,
    String? competentRegistryOffice,
    String? transactionId,
    String? resultCode,
    String? resultMessage,
    List<Map<String, dynamic>>? ownershipHistory,
    List<Map<String, dynamic>>? currentOwners,
    String? ownershipRatio,
    List<Map<String, dynamic>>? lienHistory,
    List<Map<String, dynamic>>? currentLiens,
    String? totalLienAmount,
    String? buildingNumber,
    String? exclusiveArea,
    String? commonArea,
    String? parkingArea,
    String? buildingYear,
    String? buildingPermit,
    String? landNumber,
    String? landRatio,
    String? landUse,
    String? landCategory,
    Map<String, dynamic>? registerHeader,
    Map<String, dynamic>? registerOwnership,
    Map<String, dynamic>? registerLiens,
    Map<String, dynamic>? registerBuilding,
    Map<String, dynamic>? registerLand,
    Map<String, dynamic>? registerSummaryData,
    Map<String, dynamic>? detailFormData,
    String? detailFormJson,
    Map<String, bool>? selectedClauses,
    String? userMainContractor,
    String? userContractor,
    String? userContactInfo,
    String? userNotes,
    Map<String, dynamic>? brokerInfo,
  }) {
    return Property(
      id: id ?? this.id,
      firestoreId: firestoreId ?? this.firestoreId,
      address: address ?? this.address,
      addressCity: addressCity ?? this.addressCity,
      transactionType: transactionType ?? this.transactionType,
      price: price ?? this.price,
      description: description ?? this.description,
      registerData: registerData ?? this.registerData,
      registerSummary: registerSummary ?? this.registerSummary,
      contractStatus: contractStatus ?? this.contractStatus,
      mainContractor: mainContractor ?? this.mainContractor,
      contractor: contractor ?? this.contractor,
      registeredBy: registeredBy ?? this.registeredBy,
      registeredByName: registeredByName ?? this.registeredByName,
      registeredByInfo: registeredByInfo ?? this.registeredByInfo,
      createdAt: createdAt ?? this.createdAt,
      buildingName: buildingName ?? this.buildingName,
      buildingType: buildingType ?? this.buildingType,
      totalFloors: totalFloors ?? this.totalFloors,
      floor: floor ?? this.floor,
      area: area ?? this.area,
      structure: structure ?? this.structure,
      landPurpose: landPurpose ?? this.landPurpose,
      landArea: landArea ?? this.landArea,
      ownerName: ownerName ?? this.ownerName,
      ownerInfo: ownerInfo ?? this.ownerInfo,
      liens: liens ?? this.liens,
      publishDate: publishDate ?? this.publishDate,
      officeName: officeName ?? this.officeName,
      publishNo: publishNo ?? this.publishNo,
      uniqueNo: uniqueNo ?? this.uniqueNo,
      issueNo: issueNo ?? this.issueNo,
      realtyDesc: realtyDesc ?? this.realtyDesc,
      receiptDate: receiptDate ?? this.receiptDate,
      cause: cause ?? this.cause,
      purpose: purpose ?? this.purpose,
      floorAreas: floorAreas ?? this.floorAreas,
      estimatedValue: estimatedValue ?? this.estimatedValue,
      marketValue: marketValue ?? this.marketValue,
      aiConfidence: aiConfidence ?? this.aiConfidence,
      recentTransaction: recentTransaction ?? this.recentTransaction,
      priceHistory: priceHistory ?? this.priceHistory,
      nearbyPrices: nearbyPrices ?? this.nearbyPrices,
      propertyImages: propertyImages ?? this.propertyImages,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
      docTitle: docTitle ?? this.docTitle,
      competentRegistryOffice: competentRegistryOffice ?? this.competentRegistryOffice,
      transactionId: transactionId ?? this.transactionId,
      resultCode: resultCode ?? this.resultCode,
      resultMessage: resultMessage ?? this.resultMessage,
      ownershipHistory: ownershipHistory ?? this.ownershipHistory,
      currentOwners: currentOwners ?? this.currentOwners,
      ownershipRatio: ownershipRatio ?? this.ownershipRatio,
      lienHistory: lienHistory ?? this.lienHistory,
      currentLiens: currentLiens ?? this.currentLiens,
      totalLienAmount: totalLienAmount ?? this.totalLienAmount,
      buildingNumber: buildingNumber ?? this.buildingNumber,
      exclusiveArea: exclusiveArea ?? this.exclusiveArea,
      commonArea: commonArea ?? this.commonArea,
      parkingArea: parkingArea ?? this.parkingArea,
      buildingYear: buildingYear ?? this.buildingYear,
      buildingPermit: buildingPermit ?? this.buildingPermit,
      landNumber: landNumber ?? this.landNumber,
      landRatio: landRatio ?? this.landRatio,
      landUse: landUse ?? this.landUse,
      landCategory: landCategory ?? this.landCategory,
      registerHeader: registerHeader ?? this.registerHeader,
      registerOwnership: registerOwnership ?? this.registerOwnership,
      registerLiens: registerLiens ?? this.registerLiens,
      registerBuilding: registerBuilding ?? this.registerBuilding,
      registerLand: registerLand ?? this.registerLand,
      registerSummaryData: registerSummaryData ?? this.registerSummaryData,
      detailFormData: detailFormData ?? this.detailFormData,
      detailFormJson: detailFormJson ?? this.detailFormJson,
      selectedClauses: selectedClauses ?? this.selectedClauses,
      userMainContractor: userMainContractor ?? this.userMainContractor,
      userContractor: userContractor ?? this.userContractor,
      userContactInfo: userContactInfo ?? this.userContactInfo,
      userNotes: userNotes ?? this.userNotes,
      brokerInfo: brokerInfo ?? this.brokerInfo,
      brokerId: brokerId ?? brokerId,
    );
  }
} 