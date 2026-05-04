// Copy Deck ↔ grant_messages.dart 동기 검증 스크립트.
//
// 사용:
//   dart run tools/audit_copy_deck.dart
//   exit 0 → 모든 검증 통과
//   exit 1 → 위반 사항 출력 후 실패
//
// 검증 4종:
//   1. copy-deck §2 영역별 표 ↔ grant_messages.dart const/static String 양방향 일치
//   2. copy-deck §3 사유 코드 26종 표 ↔ reasonCopy Map 1:1
//   3. copy-deck §4 audit eventType 17종 표 ↔ auditEventLabel Map 1:1
//   4. copy-deck §5 "우선권" 단어 정책 — auditEventLabel + participationHolderBadge 외
//      식별자에서 "우선권" 단어 사용 0건
//
// 화이트리스트:
//   - 내부 폴백 const (예: fallbackDisplayName 등)
//   - 액션·동의·시스템 문구 등 영역 표에 등록되지 않은 보조 const
//     (CopyDeck §0 사용 규칙: *사용자 노출 카피*만 §2 표에 등록.
//      raw 문자열 가드 const는 본 검증 면제)
//
// CI 통합:
//   .github/workflows/copy-doctrine.yml에 별도 step으로:
//     - run: dart run tools/audit_copy_deck.dart
library;

import 'dart:io';

const String _copyDeckPath = 'docs/common/copy-deck.md';
const String _grantMessagesPath = 'lib/constants/grant_messages.dart';

/// §2 표에 등록되지 않아도 검증 면제할 const 식별자.
/// 사유: 시스템 동작 문구, 보조 동의 가드, 폴백 안내 등 카피 정책 영역 외.
const Set<String> _identifierWhitelist = <String>{
  // 시스템 공통 동작
  'actionConfirm',
  'actionCancel',
  // 매도자 측 보조 안내 (§2.1 표 외부지만 정책 라인)
  'sellerSidesMayDifferNotice',
  // Task 03 보조 라벨 (매수자 측 다이얼로그 옵션)
  'actionUseRecommendedBroker',
  'actionSearchBroker',
  'actionUseFavoriteBroker',
  // Task 04 — 단계 정지 누적 카피 (§2.6 표는 핵심 항목만 등록)
  'tierPausedByGrantInline',
  'myPropertyTierHistoryTitle',
  // Task 05 audit timeline 진입 카피
  'auditTimelineTitle',
  'auditEmptyState',
  // Task 07 모드 검색·전환 보조 카피 (§2.4 핵심 외)
  'listingModeOpenDescription',
  'listingModeExclusiveDescription',
  'exclusiveSearchTitle',
  'exclusiveSearchHint',
  'exclusiveSearchEmpty',
  'exclusiveSelectedCountSuffix',
  'exclusiveLimitWarning',
  'exclusiveAtLeastOneRequired',
  'exclusiveSelfAttestationRequired',
  'listingModeCurrentOpen',
  'listingModeCurrentExclusive',
  'listingModeToOpenConfirm',
  'listingModeToExclusiveConfirm',
  'listingModeChangeCooldownNotice',
  'exclusiveBrokersChanged',
  // Task 08 보조 안내 (§2.2 표 핵심 외)
  'brokerBuyerLeadsHint',
  'genericRetryNotice',
  // P2-4 — scoringInputs 분석 결과 보조 카피 (copy-deck §3.1 별도 표).
  // §3 사유 코드 26종에는 추가하지 않고 §3.1 별도 표로 운용. §3 정규식이
  // 소문자 snake_case 만 잡으므로 본 식별자(camelCase)는 §3 1:1 검증에 무관.
  // §2 역방향 검증에서만 화이트리스트 처리해 통과시킨다.
  'scoringFailJurisdiction',
  'scoringFailLicense',
  'scoringFailCap',
  'scoringFailActivity',
  'scoringFailDistance',
  'scoringFailTime',
  'scoringFailGeneric',
};

/// "우선권" 단어 사용이 명시 허용된 식별자 (copy-deck §5).
const Set<String> _woosunGwonAllowedIdentifiers = <String>{
  // §5: 매도자 보유자 강조 — 1건 한정 허용
  'participationHolderBadge',
  // §5: 단계 정지 인라인 (매도자 시야)
  'tierPausedByGrantInline',
  // §5: 매도자 audit timeline 진입
  'auditTimelineTitle',
};

/// auditEventLabel Map 안의 값은 매도자 사실 통지용 — "우선권" 허용.

class _Violation {
  _Violation(this.category, this.detail);
  final String category;
  final String detail;

  @override
  String toString() => '  - [$category] $detail';
}

class _CopyDeckSection2Entry {
  _CopyDeckSection2Entry(this.identifier, this.copy, this.subsection);
  final String identifier;
  final String copy;
  final String subsection;
}

class _GrantConst {
  _GrantConst(this.identifier, this.value);
  final String identifier;
  final String value;
}

Future<int> main(List<String> args) async {
  final List<_Violation> violations = <_Violation>[];

  final File copyDeckFile = File(_copyDeckPath);
  final File grantFile = File(_grantMessagesPath);
  if (!copyDeckFile.existsSync()) {
    stderr.writeln('FATAL: $_copyDeckPath 를 찾을 수 없습니다.');
    return 2;
  }
  if (!grantFile.existsSync()) {
    stderr.writeln('FATAL: $_grantMessagesPath 를 찾을 수 없습니다.');
    return 2;
  }

  final String copyDeckSrc = copyDeckFile.readAsStringSync();
  final String grantSrc = grantFile.readAsStringSync();

  // 1. copy-deck §2 영역별 표 파싱
  final List<_CopyDeckSection2Entry> section2Entries =
      _parseCopyDeckSection2(copyDeckSrc);

  // 2. copy-deck §3 사유 코드 표
  final Map<String, String> deckReasons = _parseCopyDeckSection3(copyDeckSrc);

  // 3. copy-deck §4 audit eventType 표
  final Map<String, String> deckAudit = _parseCopyDeckSection4(copyDeckSrc);

  // 4. grant_messages.dart const String 파싱
  final List<_GrantConst> grantConsts = _parseGrantConsts(grantSrc);
  final Set<String> grantConstIds =
      grantConsts.map((_GrantConst c) => c.identifier).toSet();

  // 5. grant_messages.dart reasonCopy / auditEventLabel Map 파싱
  final Map<String, String> grantReasons =
      _parseMapLiteral(grantSrc, 'reasonCopy');
  final Map<String, String> grantAudit =
      _parseAuditEventLabelMap(grantSrc);

  // === 검증 1: §2 표 ↔ grant const String 양방향 ===

  // 정방향: deck §2에 있는 식별자가 grant const에 존재
  for (final _CopyDeckSection2Entry entry in section2Entries) {
    if (!grantConstIds.contains(entry.identifier)) {
      violations.add(_Violation(
        '§2 → grant',
        '${entry.subsection}: copy-deck에 등록된 `${entry.identifier}` 가 '
            'grant_messages.dart에 없습니다.',
      ));
      continue;
    }
    // 카피 일치 확인 (escape 등을 정규화 후 비교)
    final _GrantConst gc = grantConsts
        .firstWhere((_GrantConst c) => c.identifier == entry.identifier);
    final String deckCopy = _normalize(entry.copy);
    final String codeCopy = _normalize(gc.value);
    if (deckCopy != codeCopy) {
      violations.add(_Violation(
        '§2 카피 불일치',
        '`${entry.identifier}` deck="${entry.copy}" code="${gc.value}"',
      ));
    }
  }

  // 역방향: grant const 중 deck §2에 등록되지 않은 사용자 노출 카피 발견
  final Set<String> deckIds =
      section2Entries.map((_CopyDeckSection2Entry e) => e.identifier).toSet();
  for (final _GrantConst gc in grantConsts) {
    if (deckIds.contains(gc.identifier)) continue;
    if (_identifierWhitelist.contains(gc.identifier)) continue;
    violations.add(_Violation(
      'grant → §2',
      '`${gc.identifier}` ("${gc.value}") 가 grant_messages.dart에 있지만 '
          'copy-deck §2 표에 미등록입니다. (화이트리스트 추가 또는 §2 표 갱신)',
    ));
  }

  // === 검증 2: §3 사유 코드 ↔ reasonCopy Map 1:1 ===

  // 정방향
  for (final MapEntry<String, String> e in deckReasons.entries) {
    if (!grantReasons.containsKey(e.key)) {
      violations.add(_Violation(
        '§3 → reasonCopy',
        '`${e.key}` 가 reasonCopy Map에 없습니다.',
      ));
      continue;
    }
    final String deckCopy = _normalize(e.value);
    final String codeCopy = _normalize(grantReasons[e.key]!);
    if (deckCopy != codeCopy) {
      violations.add(_Violation(
        '§3 카피 불일치',
        '`${e.key}` deck="${e.value}" code="${grantReasons[e.key]}"',
      ));
    }
  }
  // 역방향
  for (final MapEntry<String, String> e in grantReasons.entries) {
    if (!deckReasons.containsKey(e.key)) {
      violations.add(_Violation(
        'reasonCopy → §3',
        '`${e.key}` 가 copy-deck §3 표에 미등록입니다.',
      ));
    }
  }

  // === 검증 3: §4 audit eventType ↔ auditEventLabel Map 1:1 ===

  // 정방향
  for (final MapEntry<String, String> e in deckAudit.entries) {
    if (!grantAudit.containsKey(e.key)) {
      violations.add(_Violation(
        '§4 → auditEventLabel',
        '`${e.key}` 가 auditEventLabel Map에 없습니다.',
      ));
      continue;
    }
    final String deckCopy = _normalize(e.value);
    final String codeCopy = _normalize(grantAudit[e.key]!);
    if (deckCopy != codeCopy) {
      violations.add(_Violation(
        '§4 카피 불일치',
        '`${e.key}` deck="${e.value}" code="${grantAudit[e.key]}"',
      ));
    }
  }
  // 역방향
  for (final MapEntry<String, String> e in grantAudit.entries) {
    if (!deckAudit.containsKey(e.key)) {
      violations.add(_Violation(
        'auditEventLabel → §4',
        '`${e.key}` 가 copy-deck §4 표에 미등록입니다.',
      ));
    }
  }

  // === 검증 4: "우선권" 단어 정책 ===
  // const String 식별자의 *값*에 "우선권" 등장 시 — _woosunGwonAllowedIdentifiers
  // 또는 auditEventLabel Map의 value(=Map 내부 라인)만 허용.
  for (final _GrantConst gc in grantConsts) {
    if (!gc.value.contains('우선권')) continue;
    if (_woosunGwonAllowedIdentifiers.contains(gc.identifier)) continue;
    violations.add(_Violation(
      '§5 "우선권" 위반',
      '`${gc.identifier}` 값 "${gc.value}" 에 "우선권" 사용. '
          '허용 식별자: ${_woosunGwonAllowedIdentifiers.join(", ")}',
    ));
  }
  // (Map auditEventLabel 의 value들은 §5에서 명시 허용 — 검증 면제)

  // === 보고 ===
  if (violations.isEmpty) {
    stdout.writeln('OK: copy-deck.md ↔ grant_messages.dart 동기 검증 모두 통과.');
    stdout.writeln('  - §2 영역별 표 항목: ${section2Entries.length}개');
    stdout.writeln('  - §3 사유 코드: ${deckReasons.length}개');
    stdout.writeln('  - §4 audit eventType: ${deckAudit.length}개');
    stdout.writeln('  - §5 "우선권" 단어 정책: 위반 0건');
    return 0;
  }

  stderr.writeln('FAIL: copy-deck.md ↔ grant_messages.dart 동기 위반 '
      '${violations.length}건');
  for (final _Violation v in violations) {
    stderr.writeln(v.toString());
  }
  return 1;
}

/// 카피 비교용 정규화: 마침표·줄바꿈·공백 차이 흡수.
/// (deck 표는 줄임이 잦고, code 는 마침표가 붙는 경향)
String _normalize(String s) {
  final String unescaped = s
      .replaceAll(r'\n', '\n')
      .replaceAll('\\\'', "'")
      .replaceAll('\\"', '"');
  // 양 끝 마침표·물결 제거 후 공백 정리
  return unescaped
      .replaceAll(RegExp(r'[\s ]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'[.。]+$'), '');
}

/// copy-deck §2.1~§2.7 표를 모두 파싱.
/// 표 형식:
///   | `식별자` | 카피 | 사용처 |
List<_CopyDeckSection2Entry> _parseCopyDeckSection2(String src) {
  final List<_CopyDeckSection2Entry> entries = <_CopyDeckSection2Entry>[];
  final List<String> lines = src.split('\n');

  String? currentSubsection;
  bool inSection2 = false;
  for (int i = 0; i < lines.length; i++) {
    final String line = lines[i];

    // §2 진입
    if (line.startsWith('## 2.')) {
      inSection2 = true;
      continue;
    }
    if (line.startsWith('## 3.') ||
        line.startsWith('## 4.') ||
        line.startsWith('## 5.') ||
        line.startsWith('## 6.') ||
        line.startsWith('## 7.') ||
        line.startsWith('## 8.')) {
      inSection2 = false;
    }
    if (!inSection2) continue;

    // 서브섹션 추적
    final RegExpMatch? sub = RegExp(r'^### (2\.\d+) ').firstMatch(line);
    if (sub != null) {
      currentSubsection = sub.group(1)!;
      continue;
    }

    // 표 row — 백틱으로 둘러싸인 식별자
    final RegExpMatch? row = RegExp(
      r'^\|\s*`([A-Za-z][A-Za-z0-9_]*)`\s*\|\s*([^|]+?)\s*\|\s*([^|]*?)\s*\|',
    ).firstMatch(line);
    if (row == null) continue;
    final String identifier = row.group(1)!;
    final String copy = row.group(2)!.trim();
    // "★ Task 08 신설" 같은 헤더 row 제외
    if (copy.isEmpty || copy == '|') continue;
    entries.add(_CopyDeckSection2Entry(
      identifier,
      copy,
      currentSubsection ?? '§2.?',
    ));
  }
  return entries;
}

/// copy-deck §3 사유 코드 표 파싱.
/// 형식:
///   | `code` | 카피 | 정책 출처 |
/// 폴백 row(`(폴백)`)는 제외.
Map<String, String> _parseCopyDeckSection3(String src) {
  return _parseSimpleCodeTable(src, sectionMarker: '## 3.', stopMarker: '## 4.');
}

/// copy-deck §4 audit eventType 표 파싱.
Map<String, String> _parseCopyDeckSection4(String src) {
  return _parseSimpleCodeTable(src, sectionMarker: '## 4.', stopMarker: '## 5.');
}

Map<String, String> _parseSimpleCodeTable(
  String src, {
  required String sectionMarker,
  required String stopMarker,
}) {
  final Map<String, String> result = <String, String>{};
  final List<String> lines = src.split('\n');
  bool inSection = false;
  for (final String line in lines) {
    if (line.startsWith(sectionMarker)) {
      inSection = true;
      continue;
    }
    if (line.startsWith(stopMarker)) {
      inSection = false;
    }
    if (!inSection) continue;

    final RegExpMatch? row = RegExp(
      r'^\|\s*`([a-z_][a-z0-9_]*)`\s*\|\s*([^|]+?)\s*\|',
    ).firstMatch(line);
    if (row == null) continue;
    final String code = row.group(1)!;
    final String copy = row.group(2)!.trim();
    // 비고/주석 표시(※) 제거
    final String cleaned =
        copy.replaceAll(RegExp(r'\s*\(※[^)]*\)\s*'), '').trim();
    result[code] = cleaned;
  }
  return result;
}

/// grant_messages.dart 의 모든 `static const String <name> = '...'` 또는
/// `static const String <name> = '''...'''` 또는 멀티라인 string concat 파싱.
List<_GrantConst> _parseGrantConsts(String src) {
  final List<_GrantConst> result = <_GrantConst>[];

  // static const String <name> = ... ;  (값은 single/double quote, 멀티라인,
  // 줄바꿈을 string concatenation으로 표현 가능)
  // 단일 토큰 정규식으로 종결자 ; 까지 비탐욕 매칭.
  final RegExp re = RegExp(
    r"""static\s+const\s+String\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*((?:'[^']*'|"[^"]*"|\s|\+)+);""",
    multiLine: true,
  );

  for (final RegExpMatch m in re.allMatches(src)) {
    final String identifier = m.group(1)!;
    final String rawExpr = m.group(2)!;
    final String value = _evalStringExpression(rawExpr);
    result.add(_GrantConst(identifier, value));
  }
  return result;
}

/// 'foo' "bar" + 형식의 dart 문자열 표현식을 단일 문자열로 평가.
String _evalStringExpression(String expr) {
  final StringBuffer buf = StringBuffer();
  int i = 0;
  while (i < expr.length) {
    final String ch = expr[i];
    if (ch == "'" || ch == '"') {
      final String quote = ch;
      final int start = i + 1;
      int j = start;
      while (j < expr.length) {
        if (expr[j] == r'\\' && j + 1 < expr.length) {
          j += 2;
          continue;
        }
        if (expr[j] == quote) break;
        j++;
      }
      buf.write(expr.substring(start, j));
      i = j + 1;
      continue;
    }
    i++;
  }
  // \n escape 보존, 그 외는 raw
  return buf.toString();
}

/// reasonCopy 같은 `static const Map<String, String> name = <String, String>{ ... };`
/// 또는 `static const Map<String, String> name = { ... };` 파싱.
Map<String, String> _parseMapLiteral(String src, String mapName) {
  final RegExp openRe = RegExp(
    r'static\s+const\s+Map<String,\s*String>\s+' +
        RegExp.escape(mapName) +
        r'\s*=\s*(?:<String,\s*String>\s*)?\{',
  );
  final RegExpMatch? open = openRe.firstMatch(src);
  if (open == null) return <String, String>{};
  final int bodyStart = open.end;
  final int bodyEnd = _findMatchingBrace(src, bodyStart - 1);
  if (bodyEnd < 0) return <String, String>{};
  final String body = src.substring(bodyStart, bodyEnd);
  return _parseMapBody(body);
}

/// auditEventLabel은 메서드 *내부 지역 const Map* 이므로 별도 파서 사용.
Map<String, String> _parseAuditEventLabelMap(String src) {
  // const Map<String, String> map = <String, String>{ ... };
  final int methodIdx = src.indexOf('auditEventLabel');
  if (methodIdx < 0) return <String, String>{};
  final String tail = src.substring(methodIdx);
  final RegExp openRe = RegExp(
    r'const\s+Map<String,\s*String>\s+map\s*=\s*<String,\s*String>\s*\{',
  );
  final RegExpMatch? open = openRe.firstMatch(tail);
  if (open == null) return <String, String>{};
  final int bodyStartLocal = open.end;
  final int bodyEndLocal = _findMatchingBrace(tail, bodyStartLocal - 1);
  if (bodyEndLocal < 0) return <String, String>{};
  final String body = tail.substring(bodyStartLocal, bodyEndLocal);
  return _parseMapBody(body);
}

/// `'key': 'value',` 또는 `'key': "value",` 행을 파싱.
/// 주석(`// ...`) 행은 무시.
Map<String, String> _parseMapBody(String body) {
  final Map<String, String> result = <String, String>{};
  // 한 행 또는 여러 행. comment 제거 후 line-by-line.
  final List<String> lines = body.split('\n');
  for (final String rawLine in lines) {
    String line = rawLine;
    final int commentIdx = line.indexOf('//');
    if (commentIdx >= 0) line = line.substring(0, commentIdx);
    line = line.trim();
    if (line.isEmpty) continue;

    final RegExpMatch? m = RegExp(
      r"""^['"]([a-zA-Z_][a-zA-Z0-9_]*)['"]\s*:\s*['"](.*?)['"],?\s*$""",
    ).firstMatch(line);
    if (m == null) continue;
    final String key = m.group(1)!;
    final String value = m.group(2)!;
    result[key] = value;
  }
  return result;
}

/// `{` 위치(brace 위치)에서 매칭되는 `}` 위치 반환. 없으면 -1.
int _findMatchingBrace(String src, int openBracePos) {
  int depth = 0;
  for (int i = openBracePos; i < src.length; i++) {
    final String ch = src[i];
    if (ch == '{') depth++;
    if (ch == '}') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}
