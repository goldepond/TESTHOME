
class SpecialClause {
  final String id;
  final String title;
  final String description;
  final String category;
  final String defaultText;
  final String reason;
  final String objectiveBasis; // 객관적 근거
  final bool isDefaultOn; // 기본 ON 상태인지
  final List<String> recommendationConditions; // 추천 조건
  final List<String> alternatives; // 대체안
  final Map<String, String> variables; // 수정 가능한 변수들

  SpecialClause({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.defaultText,
    required this.reason,
    required this.objectiveBasis,
    this.isDefaultOn = false,
    this.recommendationConditions = const [],
    this.alternatives = const [],
    this.variables = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'defaultText': defaultText,
      'reason': reason,
      'objectiveBasis': objectiveBasis,
      'isDefaultOn': isDefaultOn,
      'recommendationConditions': recommendationConditions,
      'alternatives': alternatives,
      'variables': variables,
    };
  }

  factory SpecialClause.fromMap(Map<String, dynamic> map) {
    return SpecialClause(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? '',
      defaultText: map['defaultText'] ?? '',
      reason: map['reason'] ?? '',
      objectiveBasis: map['objectiveBasis'] ?? '',
      isDefaultOn: map['isDefaultOn'] ?? false,
      recommendationConditions: List<String>.from(map['recommendationConditions'] ?? []),
      alternatives: List<String>.from(map['alternatives'] ?? []),
      variables: Map<String, String>.from(map['variables'] ?? {}),
    );
  }

  SpecialClause copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? defaultText,
    String? reason,
    String? objectiveBasis,
    bool? isDefaultOn,
    List<String>? recommendationConditions,
    List<String>? alternatives,
    Map<String, String>? variables,
  }) {
    return SpecialClause(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      defaultText: defaultText ?? this.defaultText,
      reason: reason ?? this.reason,
      objectiveBasis: objectiveBasis ?? this.objectiveBasis,
      isDefaultOn: isDefaultOn ?? this.isDefaultOn,
      recommendationConditions: recommendationConditions ?? this.recommendationConditions,
      alternatives: alternatives ?? this.alternatives,
      variables: variables ?? this.variables,
    );
  }
}

// 6대 기본 특약 정의
class SpecialClauseData {
  static List<SpecialClause> getDefaultClauses() {
    return [
      // 1. 권리변동 통지·배액배상 (가장 중요 - 기본 ON)
      SpecialClause(
        id: 'right_change_compensation',
        title: '권리변동 통지·배액배상',
        description: '잔금 전 근저당/소유권 변동 시 계약 해제 + 배액배상',
        category: '권리보호',
        defaultText: '계약금 지급일로부터 잔금 지급일까지 임대인의 소유권에 변동이 있거나 근저당권 등 권리변동이 있는 경우, 임차인은 계약을 해제할 수 있으며, 이 경우 임대인은 계약금의 배액을 배상하여야 한다.',
        reason: '근저당권이나 소유권 변동으로 인한 임차인 피해 방지',
        objectiveBasis: '국토교통부 표준임대차계약서 제7조에 포함된 합리적인 조항입니다.',
        isDefaultOn: true,
        recommendationConditions: [
          '다세대 주택',
          '후순위 근저당 존재',
          '신축 아파트',
        ],
        alternatives: [
          '계약금 환급 + 손해배상 범위 협의',
          '권리변동 시 사전 통지 의무',
        ],
        variables: {
          '계약금_지급일': '계약금 지급일',
          '잔금_지급일': '잔금 지급일',
        },
      ),

      // 2. 설비 수리 의무 (기본 ON)
      SpecialClause(
        id: 'repair_obligation',
        title: '설비 수리 의무',
        description: '자연마모·노후 하자 수리는 임대인 부담',
        category: '수리',
        defaultText: '임대주택의 자연마모, 노후화로 인한 하자는 임대인의 부담으로 수리하여야 하며, 임차인의 과실로 인한 하자는 임차인의 부담으로 수리하여야 한다.',
        reason: '자연마모와 임차인 과실을 명확히 구분하여 공정한 수리 책임 분담',
        objectiveBasis: '주택임대차보호법 제3조의2에 근거한 합리적인 조항입니다.',
        isDefaultOn: true,
        recommendationConditions: [
          '노후 건물',
          '오래된 설비',
          '하자 이력 있음',
        ],
        alternatives: [
          '수리비용 분담 비율 협의',
          '정기 점검 의무',
        ],
        variables: {},
      ),

      // 3. 보증금 반환 기한 (기본 ON)
      SpecialClause(
        id: 'deposit_return_deadline',
        title: '보증금 반환 기한',
        description: '퇴거일 즉시 반환, 지연 시 법정이자',
        category: '보증금',
        defaultText: '임차인이 임대주택을 인도할 때 임대인은 보증금을 즉시 반환하여야 하며, 지연 시에는 지연일수에 따라 법정이자를 지급하여야 한다.',
        reason: '보증금 반환 지연으로 인한 임차인 피해 방지',
        objectiveBasis: '주택임대차보호법 제3조에 명시된 임대인의 의무입니다.',
        isDefaultOn: true,
        recommendationConditions: [
          '높은 보증금',
          '이전 임차인 분쟁 이력',
        ],
        alternatives: [
          '반환 기한 7일로 연장',
          '부분 반환 허용',
        ],
        variables: {
          '반환_기한': '즉시',
          '이자_율': '법정이자',
        },
      ),

      // 4. 하자 2주 무상수리
      SpecialClause(
        id: 'defect_free_repair',
        title: '하자 2주 무상수리',
        description: '입주 후 2주 내 신고 하자 무상수리',
        category: '하자',
        defaultText: '임차인이 입주 후 2주 이내에 발견한 하자는 임대인의 부담으로 무상 수리하여야 한다.',
        reason: '입주 초기 발견된 하자의 신속한 수리 보장',
        objectiveBasis: '표준임대차계약서에서 권장하는 합리적인 기간입니다.',
        isDefaultOn: false,
        recommendationConditions: [
          '신축 건물',
          '리모델링 건물',
          '하자 이력 있음',
        ],
        alternatives: [
          '하자 수리 기한 1개월로 연장',
          '하자 범위 협의',
        ],
        variables: {
          '하자_신고_기한': '2주',
          '수리_방식': '무상',
        },
      ),

      // 5. 원상복구 범위 확정
      SpecialClause(
        id: 'restoration_scope',
        title: '원상복구 범위 확정',
        description: '자연마모·경년변화는 제외',
        category: '원상복구',
        defaultText: '임차인은 임대주택을 원상으로 복구하여야 하되, 자연마모, 경년변화로 인한 부분은 원상복구 대상에서 제외한다.',
        reason: '자연마모와 임차인 과실을 구분하여 공정한 원상복구 책임 분담',
        objectiveBasis: '대법원 판례에 근거한 합리적인 기준입니다.',
        isDefaultOn: false,
        recommendationConditions: [
          '장기 임대',
          '노후 건물',
          '고가 임대',
        ],
        alternatives: [
          '원상복구 비용 상한선 설정',
          '정기 점검으로 상태 기록',
        ],
        variables: {
          '제외_항목': '자연마모, 경년변화',
        },
      ),

      // 6. 확정일자·전입 협조
      SpecialClause(
        id: 'registration_cooperation',
        title: '확정일자·전입 협조',
        description: '임대인의 협조 의무',
        category: '권리보호',
        defaultText: '임대인은 임차인의 요청에 따라 확정일자 신청 및 전입신고에 필요한 서류를 제공하고 협조하여야 한다.',
        reason: '임차인의 권리보호를 위한 필수 절차 지원',
        objectiveBasis: '주택임대차보호법에서 임대인의 협조 의무로 규정하고 있습니다.',
        isDefaultOn: false,
        recommendationConditions: [
          '높은 보증금',
          '장기 임대',
          '상가 임대',
        ],
        alternatives: [
          '협조 범위 협의',
          '비용 분담 협의',
        ],
        variables: {
          '협조_범위': '필요한 서류 제공',
        },
      ),

      // 7. 관리비 명세·정산 기준 (추가 특약)
      SpecialClause(
        id: 'maintenance_fee_detail',
        title: '관리비 명세·정산 기준',
        description: '관리비 항목별 명세 및 정산 기준 명시',
        category: '관리비',
        defaultText: '관리비는 월 {관리비_금액}원으로 하며, 항목별 명세는 별첨과 같다. 연 1회 정산하여 차액을 정산한다.',
        reason: '관리비 투명성 확보 및 분쟁 방지',
        objectiveBasis: '공정거래위원회 표준약관에 포함된 합리적인 조항입니다.',
        isDefaultOn: false,
        recommendationConditions: [
          '관리비 10만원 이상',
          '개별계량 없음',
          '복합시설',
        ],
        alternatives: [
          '정산 주기 분기별로 변경',
          '항목별 상한선 설정',
        ],
        variables: {
          '관리비_금액': '관리비 금액',
          '정산_주기': '연 1회',
        },
      ),
    ];
  }

  // 추천 로직
  static List<SpecialClause> getRecommendedClauses({
    required double maintenanceFee,
    required bool hasIndividualMetering,
    required String buildingType,
    required bool hasJuniorMortgage,
    required int buildingAge,
    required double deposit,
    required int leaseTerm,
    required bool hasDefectHistory,
    required bool isNewBuilding,
  }) {
    final allClauses = getDefaultClauses();
    final recommended = <SpecialClause>[];

    for (final clause in allClauses) {
      bool shouldRecommend = false;

      switch (clause.id) {
        case 'right_change_compensation':
          shouldRecommend = buildingType == '다세대' || hasJuniorMortgage || isNewBuilding;
          break;
        case 'repair_obligation':
          shouldRecommend = buildingAge > 10 || hasDefectHistory;
          break;
        case 'deposit_return_deadline':
          shouldRecommend = deposit > 10000000; // 1000만원 이상
          break;
        case 'defect_free_repair':
          shouldRecommend = isNewBuilding || hasDefectHistory;
          break;
        case 'restoration_scope':
          shouldRecommend = leaseTerm > 12 || buildingAge > 15 || deposit > 20000000;
          break;
        case 'registration_cooperation':
          shouldRecommend = deposit > 10000000 || leaseTerm > 12;
          break;
        case 'maintenance_fee_detail':
          shouldRecommend = maintenanceFee >= 100000 || !hasIndividualMetering;
          break;
      }

      if (shouldRecommend) {
        recommended.add(clause);
      }
    }

    return recommended;
  }
}

