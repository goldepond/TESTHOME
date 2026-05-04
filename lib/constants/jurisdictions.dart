/// 시·군·구 법정동코드(5자리) ↔ 표시명 매핑 단일 진실원.
///
/// 출처: 행정안전부 법정동코드 (시·군·구 단위 = 앞 5자리).
/// 본 catalog 는 [docs/task/2026-05-04_003-broker-jurisdictions-self-service.md]
/// §2.1.7 결정에 따라 *5자리 법정동코드* 를 단일 표준으로 채택한 *런타임 데이터*다.
///
/// **현재 범위 (전국, 2026-05 기준)**:
///   - 서울특별시 25개 자치구
///   - 6대 광역시 자치구·군 (부산 16 / 대구 9 / 인천 10 / 광주 5 / 대전 5 / 울산 5)
///   - 세종특별자치시 1
///   - 경기도 31개 시·군
///   - 강원특별자치도 18 (2023-06-11 도→특별자치도, 51xxx)
///   - 충청북도 11 / 충청남도 15
///   - 전북특별자치도 14 (2024-01-18 도→특별자치도, 52xxx)
///   - 전라남도 22
///   - 경상북도 22 (2023-07 군위군 대구 편입 반영)
///   - 경상남도 18 (창원시는 통합 시 단위 1건)
///   - 제주특별자치도 2
///   - 합계 약 220개 시·군·구.
///
/// **데이터 출처**: 행정안전부 법정동코드 (시·군·구 단위 = 앞 5자리). 일반구
/// 분리 시·도(포항·창원)는 통합 시 단위로 1건만 등재 (UX 단순성 우선 — 일반구
/// 단위 매칭이 필요한 경우 별도 phase 에서 분기).
///
/// **갱신 정책**: 행정구역 통폐합·시 승격·도→특별자치도 변경 시 본 파일 수동
/// 갱신. `tools/data/lawd_codes.json` 운영 데이터와 분기마다 정합 검증 권장.
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
    // 대구광역시 (9개 시·군·구) — 2023-07-01 군위군 경북에서 편입
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
        JurisdictionSigungu(code: '27720', name: '군위군'),
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

    // ─────────────────────────────────────────────────────────
    // 강원특별자치도 (18개 시·군) — 2023-06-11 도→특별자치도 (51xxx)
    // ─────────────────────────────────────────────────────────
    JurisdictionSido(
      name: '강원특별자치도',
      sigungu: <JurisdictionSigungu>[
        JurisdictionSigungu(code: '51110', name: '춘천시'),
        JurisdictionSigungu(code: '51130', name: '원주시'),
        JurisdictionSigungu(code: '51150', name: '강릉시'),
        JurisdictionSigungu(code: '51170', name: '동해시'),
        JurisdictionSigungu(code: '51190', name: '태백시'),
        JurisdictionSigungu(code: '51210', name: '속초시'),
        JurisdictionSigungu(code: '51230', name: '삼척시'),
        JurisdictionSigungu(code: '51720', name: '홍천군'),
        JurisdictionSigungu(code: '51730', name: '횡성군'),
        JurisdictionSigungu(code: '51750', name: '영월군'),
        JurisdictionSigungu(code: '51760', name: '평창군'),
        JurisdictionSigungu(code: '51770', name: '정선군'),
        JurisdictionSigungu(code: '51780', name: '철원군'),
        JurisdictionSigungu(code: '51790', name: '화천군'),
        JurisdictionSigungu(code: '51800', name: '양구군'),
        JurisdictionSigungu(code: '51810', name: '인제군'),
        JurisdictionSigungu(code: '51820', name: '고성군'),
        JurisdictionSigungu(code: '51830', name: '양양군'),
      ],
    ),

    // ─────────────────────────────────────────────────────────
    // 충청북도 (11개 시·군)
    // ─────────────────────────────────────────────────────────
    JurisdictionSido(
      name: '충청북도',
      sigungu: <JurisdictionSigungu>[
        JurisdictionSigungu(code: '43110', name: '청주시'),
        JurisdictionSigungu(code: '43130', name: '충주시'),
        JurisdictionSigungu(code: '43150', name: '제천시'),
        JurisdictionSigungu(code: '43720', name: '보은군'),
        JurisdictionSigungu(code: '43730', name: '옥천군'),
        JurisdictionSigungu(code: '43740', name: '영동군'),
        JurisdictionSigungu(code: '43745', name: '증평군'),
        JurisdictionSigungu(code: '43750', name: '진천군'),
        JurisdictionSigungu(code: '43760', name: '괴산군'),
        JurisdictionSigungu(code: '43770', name: '음성군'),
        JurisdictionSigungu(code: '43800', name: '단양군'),
      ],
    ),

    // ─────────────────────────────────────────────────────────
    // 충청남도 (15개 시·군)
    // ─────────────────────────────────────────────────────────
    JurisdictionSido(
      name: '충청남도',
      sigungu: <JurisdictionSigungu>[
        JurisdictionSigungu(code: '44130', name: '천안시'),
        JurisdictionSigungu(code: '44150', name: '공주시'),
        JurisdictionSigungu(code: '44180', name: '보령시'),
        JurisdictionSigungu(code: '44200', name: '아산시'),
        JurisdictionSigungu(code: '44210', name: '서산시'),
        JurisdictionSigungu(code: '44230', name: '논산시'),
        JurisdictionSigungu(code: '44250', name: '계룡시'),
        JurisdictionSigungu(code: '44270', name: '당진시'),
        JurisdictionSigungu(code: '44710', name: '금산군'),
        JurisdictionSigungu(code: '44760', name: '부여군'),
        JurisdictionSigungu(code: '44770', name: '서천군'),
        JurisdictionSigungu(code: '44790', name: '청양군'),
        JurisdictionSigungu(code: '44800', name: '홍성군'),
        JurisdictionSigungu(code: '44810', name: '예산군'),
        JurisdictionSigungu(code: '44825', name: '태안군'),
      ],
    ),

    // ─────────────────────────────────────────────────────────
    // 전북특별자치도 (14개 시·군) — 2024-01-18 도→특별자치도 (52xxx)
    // ─────────────────────────────────────────────────────────
    JurisdictionSido(
      name: '전북특별자치도',
      sigungu: <JurisdictionSigungu>[
        JurisdictionSigungu(code: '52110', name: '전주시'),
        JurisdictionSigungu(code: '52130', name: '군산시'),
        JurisdictionSigungu(code: '52140', name: '익산시'),
        JurisdictionSigungu(code: '52180', name: '정읍시'),
        JurisdictionSigungu(code: '52190', name: '남원시'),
        JurisdictionSigungu(code: '52210', name: '김제시'),
        JurisdictionSigungu(code: '52710', name: '완주군'),
        JurisdictionSigungu(code: '52720', name: '진안군'),
        JurisdictionSigungu(code: '52730', name: '무주군'),
        JurisdictionSigungu(code: '52740', name: '장수군'),
        JurisdictionSigungu(code: '52750', name: '임실군'),
        JurisdictionSigungu(code: '52770', name: '순창군'),
        JurisdictionSigungu(code: '52790', name: '고창군'),
        JurisdictionSigungu(code: '52800', name: '부안군'),
      ],
    ),

    // ─────────────────────────────────────────────────────────
    // 전라남도 (22개 시·군)
    // ─────────────────────────────────────────────────────────
    JurisdictionSido(
      name: '전라남도',
      sigungu: <JurisdictionSigungu>[
        JurisdictionSigungu(code: '46110', name: '목포시'),
        JurisdictionSigungu(code: '46130', name: '여수시'),
        JurisdictionSigungu(code: '46150', name: '순천시'),
        JurisdictionSigungu(code: '46170', name: '나주시'),
        JurisdictionSigungu(code: '46230', name: '광양시'),
        JurisdictionSigungu(code: '46710', name: '담양군'),
        JurisdictionSigungu(code: '46720', name: '곡성군'),
        JurisdictionSigungu(code: '46730', name: '구례군'),
        JurisdictionSigungu(code: '46770', name: '고흥군'),
        JurisdictionSigungu(code: '46780', name: '보성군'),
        JurisdictionSigungu(code: '46790', name: '화순군'),
        JurisdictionSigungu(code: '46800', name: '장흥군'),
        JurisdictionSigungu(code: '46810', name: '강진군'),
        JurisdictionSigungu(code: '46820', name: '해남군'),
        JurisdictionSigungu(code: '46830', name: '영암군'),
        JurisdictionSigungu(code: '46840', name: '무안군'),
        JurisdictionSigungu(code: '46860', name: '함평군'),
        JurisdictionSigungu(code: '46870', name: '영광군'),
        JurisdictionSigungu(code: '46880', name: '장성군'),
        JurisdictionSigungu(code: '46890', name: '완도군'),
        JurisdictionSigungu(code: '46900', name: '진도군'),
        JurisdictionSigungu(code: '46910', name: '신안군'),
      ],
    ),

    // ─────────────────────────────────────────────────────────
    // 경상북도 (22개 시·군) — 군위군은 2023-07 대구로 편입되어 제외
    // ─────────────────────────────────────────────────────────
    JurisdictionSido(
      name: '경상북도',
      sigungu: <JurisdictionSigungu>[
        JurisdictionSigungu(code: '47110', name: '포항시'),
        JurisdictionSigungu(code: '47130', name: '경주시'),
        JurisdictionSigungu(code: '47150', name: '김천시'),
        JurisdictionSigungu(code: '47170', name: '안동시'),
        JurisdictionSigungu(code: '47190', name: '구미시'),
        JurisdictionSigungu(code: '47210', name: '영주시'),
        JurisdictionSigungu(code: '47230', name: '영천시'),
        JurisdictionSigungu(code: '47250', name: '상주시'),
        JurisdictionSigungu(code: '47280', name: '문경시'),
        JurisdictionSigungu(code: '47290', name: '경산시'),
        JurisdictionSigungu(code: '47730', name: '의성군'),
        JurisdictionSigungu(code: '47750', name: '청송군'),
        JurisdictionSigungu(code: '47760', name: '영양군'),
        JurisdictionSigungu(code: '47770', name: '영덕군'),
        JurisdictionSigungu(code: '47820', name: '청도군'),
        JurisdictionSigungu(code: '47830', name: '고령군'),
        JurisdictionSigungu(code: '47840', name: '성주군'),
        JurisdictionSigungu(code: '47850', name: '칠곡군'),
        JurisdictionSigungu(code: '47900', name: '예천군'),
        JurisdictionSigungu(code: '47920', name: '봉화군'),
        JurisdictionSigungu(code: '47930', name: '울진군'),
        JurisdictionSigungu(code: '47940', name: '울릉군'),
      ],
    ),

    // ─────────────────────────────────────────────────────────
    // 경상남도 (18개 시·군) — 창원시는 통합 시 단위 1건
    // ─────────────────────────────────────────────────────────
    JurisdictionSido(
      name: '경상남도',
      sigungu: <JurisdictionSigungu>[
        JurisdictionSigungu(code: '48120', name: '창원시'),
        JurisdictionSigungu(code: '48170', name: '진주시'),
        JurisdictionSigungu(code: '48220', name: '통영시'),
        JurisdictionSigungu(code: '48240', name: '사천시'),
        JurisdictionSigungu(code: '48250', name: '김해시'),
        JurisdictionSigungu(code: '48270', name: '밀양시'),
        JurisdictionSigungu(code: '48310', name: '거제시'),
        JurisdictionSigungu(code: '48330', name: '양산시'),
        JurisdictionSigungu(code: '48720', name: '의령군'),
        JurisdictionSigungu(code: '48730', name: '함안군'),
        JurisdictionSigungu(code: '48740', name: '창녕군'),
        JurisdictionSigungu(code: '48820', name: '고성군'),
        JurisdictionSigungu(code: '48840', name: '남해군'),
        JurisdictionSigungu(code: '48850', name: '하동군'),
        JurisdictionSigungu(code: '48860', name: '산청군'),
        JurisdictionSigungu(code: '48870', name: '함양군'),
        JurisdictionSigungu(code: '48880', name: '거창군'),
        JurisdictionSigungu(code: '48890', name: '합천군'),
      ],
    ),

    // ─────────────────────────────────────────────────────────
    // 제주특별자치도 (2개 시)
    // ─────────────────────────────────────────────────────────
    JurisdictionSido(
      name: '제주특별자치도',
      sigungu: <JurisdictionSigungu>[
        JurisdictionSigungu(code: '50110', name: '제주시'),
        JurisdictionSigungu(code: '50130', name: '서귀포시'),
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
