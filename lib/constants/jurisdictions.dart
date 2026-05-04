/// 시·군·구 법정동코드(5자리) ↔ 표시명 매핑 단일 진실원.
///
/// 출처: 행정안전부 법정동코드 (시·군·구 단위 = 앞 5자리).
/// 본 catalog 는 [docs/task/2026-05-04_003-broker-jurisdictions-self-service.md]
/// §2.1.7 결정에 따라 *5자리 법정동코드* 를 단일 표준으로 채택한 *런타임 데이터*다.
///
/// **현재 범위 (v1.4.1 기준)**:
///   - 서울특별시 25개 자치구
///   - 6대 광역시 자치구·군 (부산·대구·인천·광주·대전·울산)
///   - 경기도 31개 시·군
///   - 세종특별자치시
///   - 즉, 약 90여 개 항목.
///
/// **확장 계획**: v1.5 운영 phase 에서 운영 데이터(`tools/data/lawd_codes.json`)
/// 와 동기 후 250+ 전체 시·군·구로 확장 예정. 본 phase 는 MVP 사용자 흐름이
/// 막히지 않도록 *수도권 + 광역시* 중심으로 우선 하드코딩한다.
///
/// **사용처**:
///   - `JurisdictionPicker` UI 표시
///   - `broker_settings_page.dart` 칩 표시명 변환
///   - 추후 매물 등록 시 lawdCd 일관성 검증
///
/// **금지**: 사용자 화면에 5자리 코드 자체 노출 금지.
///         반드시 [JurisdictionCatalog.toDisplayName] 으로 표시명 변환 후 노출.
library;

/// 시·도 한 단위.
class JurisdictionSido {
  const JurisdictionSido({required this.name, required this.sigungu});

  /// 시·도 이름 (예: '서울특별시').
  final String name;

  /// 해당 시·도에 속한 시·군·구 목록.
  final List<JurisdictionSigungu> sigungu;
}

/// 시·군·구 한 단위.
class JurisdictionSigungu {
  const JurisdictionSigungu({required this.code, required this.name});

  /// 5자리 법정동코드 (예: '11680').
  final String code;

  /// 시·군·구 이름 (예: '강남구').
  final String name;
}

/// 시·군·구 catalog 단일 진실원.
class JurisdictionCatalog {
  JurisdictionCatalog._();

  /// 시·도 → 시·군·구 트리.
  ///
  /// JurisdictionPicker 가 ① 시·도 드롭다운, ② 시·군·구 체크박스 리스트로 사용.
  static const List<JurisdictionSido> tree = <JurisdictionSido>[
    // ─────────────────────────────────────────────────────────
    // 서울특별시 (25개 자치구)
    // ─────────────────────────────────────────────────────────
    JurisdictionSido(
      name: '서울특별시',
      sigungu: <JurisdictionSigungu>[
        JurisdictionSigungu(code: '11110', name: '종로구'),
        JurisdictionSigungu(code: '11140', name: '중구'),
        JurisdictionSigungu(code: '11170', name: '용산구'),
        JurisdictionSigungu(code: '11200', name: '성동구'),
        JurisdictionSigungu(code: '11215', name: '광진구'),
        JurisdictionSigungu(code: '11230', name: '동대문구'),
        JurisdictionSigungu(code: '11260', name: '중랑구'),
        JurisdictionSigungu(code: '11290', name: '성북구'),
        JurisdictionSigungu(code: '11305', name: '강북구'),
        JurisdictionSigungu(code: '11320', name: '도봉구'),
        JurisdictionSigungu(code: '11350', name: '노원구'),
        JurisdictionSigungu(code: '11380', name: '은평구'),
        JurisdictionSigungu(code: '11410', name: '서대문구'),
        JurisdictionSigungu(code: '11440', name: '마포구'),
        JurisdictionSigungu(code: '11470', name: '양천구'),
        JurisdictionSigungu(code: '11500', name: '강서구'),
        JurisdictionSigungu(code: '11530', name: '구로구'),
        JurisdictionSigungu(code: '11545', name: '금천구'),
        JurisdictionSigungu(code: '11560', name: '영등포구'),
        JurisdictionSigungu(code: '11590', name: '동작구'),
        JurisdictionSigungu(code: '11620', name: '관악구'),
        JurisdictionSigungu(code: '11650', name: '서초구'),
        JurisdictionSigungu(code: '11680', name: '강남구'),
        JurisdictionSigungu(code: '11710', name: '송파구'),
        JurisdictionSigungu(code: '11740', name: '강동구'),
      ],
    ),

    // ─────────────────────────────────────────────────────────
    // 부산광역시 (16개 시·군·구)
    // ─────────────────────────────────────────────────────────
    JurisdictionSido(
      name: '부산광역시',
      sigungu: <JurisdictionSigungu>[
        JurisdictionSigungu(code: '26110', name: '중구'),
        JurisdictionSigungu(code: '26140', name: '서구'),
        JurisdictionSigungu(code: '26170', name: '동구'),
        JurisdictionSigungu(code: '26200', name: '영도구'),
        JurisdictionSigungu(code: '26230', name: '부산진구'),
        JurisdictionSigungu(code: '26260', name: '동래구'),
        JurisdictionSigungu(code: '26290', name: '남구'),
        JurisdictionSigungu(code: '26320', name: '북구'),
        JurisdictionSigungu(code: '26350', name: '해운대구'),
        JurisdictionSigungu(code: '26380', name: '사하구'),
        JurisdictionSigungu(code: '26410', name: '금정구'),
        JurisdictionSigungu(code: '26440', name: '강서구'),
        JurisdictionSigungu(code: '26470', name: '연제구'),
        JurisdictionSigungu(code: '26500', name: '수영구'),
        JurisdictionSigungu(code: '26530', name: '사상구'),
        JurisdictionSigungu(code: '26710', name: '기장군'),
      ],
    ),

    // ─────────────────────────────────────────────────────────
    // 대구광역시 (8개 시·군·구)
    // ─────────────────────────────────────────────────────────
    JurisdictionSido(
      name: '대구광역시',
      sigungu: <JurisdictionSigungu>[
        JurisdictionSigungu(code: '27110', name: '중구'),
        JurisdictionSigungu(code: '27140', name: '동구'),
        JurisdictionSigungu(code: '27170', name: '서구'),
        JurisdictionSigungu(code: '27200', name: '남구'),
        JurisdictionSigungu(code: '27230', name: '북구'),
        JurisdictionSigungu(code: '27260', name: '수성구'),
        JurisdictionSigungu(code: '27290', name: '달서구'),
        JurisdictionSigungu(code: '27710', name: '달성군'),
      ],
    ),

    // ─────────────────────────────────────────────────────────
    // 인천광역시 (10개 시·군·구)
    // ─────────────────────────────────────────────────────────
    JurisdictionSido(
      name: '인천광역시',
      sigungu: <JurisdictionSigungu>[
        JurisdictionSigungu(code: '28110', name: '중구'),
        JurisdictionSigungu(code: '28140', name: '동구'),
        JurisdictionSigungu(code: '28177', name: '미추홀구'),
        JurisdictionSigungu(code: '28185', name: '연수구'),
        JurisdictionSigungu(code: '28200', name: '남동구'),
        JurisdictionSigungu(code: '28237', name: '부평구'),
        JurisdictionSigungu(code: '28245', name: '계양구'),
        JurisdictionSigungu(code: '28260', name: '서구'),
        JurisdictionSigungu(code: '28710', name: '강화군'),
        JurisdictionSigungu(code: '28720', name: '옹진군'),
      ],
    ),

    // ─────────────────────────────────────────────────────────
    // 광주광역시 (5개 자치구)
    // ─────────────────────────────────────────────────────────
    JurisdictionSido(
      name: '광주광역시',
      sigungu: <JurisdictionSigungu>[
        JurisdictionSigungu(code: '29110', name: '동구'),
        JurisdictionSigungu(code: '29140', name: '서구'),
        JurisdictionSigungu(code: '29155', name: '남구'),
        JurisdictionSigungu(code: '29170', name: '북구'),
        JurisdictionSigungu(code: '29200', name: '광산구'),
      ],
    ),

    // ─────────────────────────────────────────────────────────
    // 대전광역시 (5개 자치구)
    // ─────────────────────────────────────────────────────────
    JurisdictionSido(
      name: '대전광역시',
      sigungu: <JurisdictionSigungu>[
        JurisdictionSigungu(code: '30110', name: '동구'),
        JurisdictionSigungu(code: '30140', name: '중구'),
        JurisdictionSigungu(code: '30170', name: '서구'),
        JurisdictionSigungu(code: '30200', name: '유성구'),
        JurisdictionSigungu(code: '30230', name: '대덕구'),
      ],
    ),

    // ─────────────────────────────────────────────────────────
    // 울산광역시 (5개 시·군·구)
    // ─────────────────────────────────────────────────────────
    JurisdictionSido(
      name: '울산광역시',
      sigungu: <JurisdictionSigungu>[
        JurisdictionSigungu(code: '31110', name: '중구'),
        JurisdictionSigungu(code: '31140', name: '남구'),
        JurisdictionSigungu(code: '31170', name: '동구'),
        JurisdictionSigungu(code: '31200', name: '북구'),
        JurisdictionSigungu(code: '31710', name: '울주군'),
      ],
    ),

    // ─────────────────────────────────────────────────────────
    // 세종특별자치시 (단일 단위)
    // ─────────────────────────────────────────────────────────
    JurisdictionSido(
      name: '세종특별자치시',
      sigungu: <JurisdictionSigungu>[
        JurisdictionSigungu(code: '36110', name: '세종특별자치시'),
      ],
    ),

    // ─────────────────────────────────────────────────────────
    // 경기도 (31개 시·군 — 부 단위 통합 표기)
    // ─────────────────────────────────────────────────────────
    JurisdictionSido(
      name: '경기도',
      sigungu: <JurisdictionSigungu>[
        JurisdictionSigungu(code: '41110', name: '수원시'),
        JurisdictionSigungu(code: '41130', name: '성남시'),
        JurisdictionSigungu(code: '41150', name: '의정부시'),
        JurisdictionSigungu(code: '41170', name: '안양시'),
        JurisdictionSigungu(code: '41190', name: '부천시'),
        JurisdictionSigungu(code: '41210', name: '광명시'),
        JurisdictionSigungu(code: '41220', name: '평택시'),
        JurisdictionSigungu(code: '41250', name: '동두천시'),
        JurisdictionSigungu(code: '41270', name: '안산시'),
        JurisdictionSigungu(code: '41280', name: '고양시'),
        JurisdictionSigungu(code: '41290', name: '과천시'),
        JurisdictionSigungu(code: '41310', name: '구리시'),
        JurisdictionSigungu(code: '41360', name: '남양주시'),
        JurisdictionSigungu(code: '41370', name: '오산시'),
        JurisdictionSigungu(code: '41390', name: '시흥시'),
        JurisdictionSigungu(code: '41410', name: '군포시'),
        JurisdictionSigungu(code: '41430', name: '의왕시'),
        JurisdictionSigungu(code: '41450', name: '하남시'),
        JurisdictionSigungu(code: '41460', name: '용인시'),
        JurisdictionSigungu(code: '41480', name: '파주시'),
        JurisdictionSigungu(code: '41500', name: '이천시'),
        JurisdictionSigungu(code: '41550', name: '안성시'),
        JurisdictionSigungu(code: '41570', name: '김포시'),
        JurisdictionSigungu(code: '41590', name: '화성시'),
        JurisdictionSigungu(code: '41610', name: '광주시'),
        JurisdictionSigungu(code: '41630', name: '양주시'),
        JurisdictionSigungu(code: '41650', name: '포천시'),
        JurisdictionSigungu(code: '41670', name: '여주시'),
        JurisdictionSigungu(code: '41800', name: '연천군'),
        JurisdictionSigungu(code: '41820', name: '가평군'),
        JurisdictionSigungu(code: '41830', name: '양평군'),
      ],
    ),
  ];

  /// 5자리 코드 → 시·도 + 시·군·구 합친 표시명.
  ///
  /// 예: '11680' → '서울특별시 강남구'
  /// 코드가 catalog 에 없으면 null 반환. 호출자가 폴백 처리.
  static String? toDisplayName(String code) {
    final lookup = _codeLookup;
    return lookup[code];
  }

  /// 시·군·구 단순 이름만 (시·도 prefix 제외).
  ///
  /// 예: '11680' → '강남구'
  /// 칩(Chip) 표시 등 좁은 공간용. 동명 시·군·구가 여러 시·도에 있으면
  /// 모호할 수 있으므로 본문에는 [toDisplayName] 사용 권장.
  static String? toShortName(String code) {
    for (final sido in tree) {
      for (final sg in sido.sigungu) {
        if (sg.code == code) return sg.name;
      }
    }
    return null;
  }

  /// 5자리 코드 1개가 catalog 에 존재하는지.
  static bool isKnownCode(String code) => _codeLookup.containsKey(code);

  /// 5자리 코드 형식 검증 (정규식).
  ///
  /// catalog 존재 여부와 무관히 *형식*만 확인. Firestore Rules·서비스 메서드
  /// 양쪽이 동일한 정규식을 사용해야 한다.
  static bool isValidCodeFormat(String code) =>
      RegExp(r'^\d{5}$').hasMatch(code);

  // ─────────────────────────────────────────────────────────
  // 내부: 코드 → 표시명 사전 (런타임 1회 lazy 빌드)
  // ─────────────────────────────────────────────────────────
  static Map<String, String>? _codeLookupCache;

  static Map<String, String> get _codeLookup {
    final cache = _codeLookupCache;
    if (cache != null) return cache;
    final m = <String, String>{};
    for (final sido in tree) {
      for (final sg in sido.sigungu) {
        m[sg.code] = '${sido.name} ${sg.name}';
      }
    }
    _codeLookupCache = m;
    return m;
  }
}
