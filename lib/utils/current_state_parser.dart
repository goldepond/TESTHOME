import 'dart:convert';

class Header {
  final String publishNo, publishDate, docTitle, realtyDesc,
      officeName, issueNo, uniqueNo;
  Header({
    required this.publishNo,
    required this.publishDate,
    required this.docTitle,
    required this.realtyDesc,
    required this.officeName,
    required this.issueNo,
    required this.uniqueNo,
  });
}

class Ownership {
  final String purpose, receipt, cause, ownerRaw;
  Ownership(String? purpose, String? receipt, String? cause, String? ownerRaw)
      : purpose = purpose ?? '',
        receipt = receipt ?? '',
        cause = cause ?? '',
        ownerRaw = ownerRaw ?? '';
}

class LandArea {
  final String landPurpose;
  final String landSize;
  LandArea(String? landPurpose, String? landSize)
      : landPurpose = landPurpose ?? '',
        landSize = landSize ?? '';
}

class FloorInfo {
  final String floorLabel;
  final String area;
  FloorInfo(String? floorLabel, String? area)
      : floorLabel = floorLabel ?? '',
        area = area ?? '';
}

class BuildingArea {
  final String structure;
  final List<FloorInfo> floors;
  String get areaTotal {
    if (floors.isEmpty) return '0.00㎡';
    return '${floors
        .map((f) => double.tryParse(f.area.replaceAll('㎡', '')) ?? 0)
        .reduce((a, b) => a + b)
        .toStringAsFixed(2)}㎡';
  }
  BuildingArea(String? structure, List<FloorInfo>? floors)
      : structure = structure ?? '',
        floors = floors ?? <FloorInfo>[];
}

class Lien {
  final String purpose, receipt, mainText;
  Lien(String? purpose, String? receipt, String? mainText)
      : purpose = purpose ?? '',
        receipt = receipt ?? '',
        mainText = mainText ?? '';
}

class CurrentState {
  final Header header;
  final Ownership ownership;
  final LandArea land;
  final BuildingArea building;
  final List<Lien> liens;
  CurrentState({
    required this.header,
    required this.ownership,
    required this.land,
    required this.building,
    required this.liens,
  });
}

String clean(String s) {
  s = s.replaceAll(RegExp(r'&[^&]*&'), '');
  s = s.replaceAll('+', ' ');
  return s.trim();
}

String filterOwnerRaw(String raw) {
  return raw
    .split('\n')
    .where((line) =>
      line.trim().isNotEmpty &&
      !line.contains('부동산등기법') &&
      !line.contains('전산이기') &&
      !line.contains('발행일')
    )
    .join('\n');
}

String filterMainText(String raw) {
  return raw
    .split('\n')
    .where((line) =>
      line.trim().isNotEmpty &&
      !line.contains('부동산등기법') &&
      !line.contains('전산이기') &&
      !line.contains('발행일')
    )
    .join('\n');
}

String findDetailByPrefix(List details, String prefix) {
  final item = details.cast<Map>().firstWhere(
    (d) => d['resContents']?.toString().startsWith(prefix) ?? false,
    orElse: () => <String, dynamic>{},
  );
  if (item.isEmpty) return '';
  return item['resContents'].toString().replaceFirst(prefix, '').trim();
}

String findDetailContains(List details, String keyword) {
  final item = details.cast<Map>().firstWhere(
    (d) => d['resContents']?.toString().contains(keyword) ?? false,
    orElse: () => <String, dynamic>{},
  );
  if (item.isEmpty) return '';
  return item['resContents'].toString();
}

String formatDate(String date) {
  if (date.contains('.')) {
    return date.replaceAll('.', '-');
  }
  final m = RegExp(r'^(\d{4})(\d{2})(\d{2})$').firstMatch(date);
  if (m != null) {
    return '${m[1]}-${m[2]}-${m[3]}';
  }
  return date;
}

String cleanRealtyDesc(String s) {
  s = s.replaceAll(RegExp(r'^\[.*?\]\s*'), '');
  s = s.replaceAllMapped(RegExp(r'제(\d+)동'), (m) => '제${m.group(1)}동');
  s = s.replaceAllMapped(RegExp(r'제(\d+,\d+층)'), (m) => '제${m.group(1)}');
  s = s.replaceAllMapped(RegExp(r'제(\d+)층'), (m) => '제${m.group(1)}층');
  s = s.replaceAllMapped(RegExp(r'제(\d+)호'), (m) => '제${m.group(1)}호');
  s = clean(s);
  return s.trim();
}

/// 외부 JSON에서 List<Map<String, dynamic>> 타입을 안전하게 변환하는 유틸 함수
List<Map<String, dynamic>> safeMapList(dynamic value) {
  if (value is List) {
    return value.where((e) => e is Map).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
  return [];
}

CurrentState parseCurrentState(String rawJson) {
  final root = jsonDecode(rawJson) as Map<String, dynamic>;
  final entries = safeMapList(root['data']['resRegisterEntriesList']);
  final entry = entries.isNotEmpty ? entries.first : <String, dynamic>{};

  // header
  final header = Header(
    publishNo   : entry['resPublishNo']?.toString() ?? '',
    publishDate : formatDate(entry['resPublishDate']?.toString() ?? ''),
    docTitle    : clean(entry['resDocTitle']?.toString() ?? ''),
    realtyDesc  : cleanRealtyDesc(entry['resRealty']?.toString() ?? ''),
    officeName  : clean(entry['commCompetentRegistryOffice']?.toString() ?? ''),
    issueNo     : entry['resIssueNo']?.toString() ?? '',
    uniqueNo    : entry['commUniqueNo']?.toString() ?? '',
  );

  // ownership (최종 소유자 정보는 sumList에서 추출)
  String purpose = '', receipt = '', cause = '', ownerRaw = '';
  final sumList = safeMapList(entry['resRegistrationSumList']);
  List<String> ownerLines = [];
  for (final item in sumList) {
    if ((item['resType'] ?? '').contains('소유지분현황')) {
      for (final owner in safeMapList(item['resContentsList'])) {
        if (owner['resType2'] == '2') {
          final d = safeMapList(owner['resDetailList']);
          final name = d.isNotEmpty ? d[0]['resContents'] : '';
          final ssn = d.length > 1 ? d[1]['resContents'] : '';
          final share = d.length > 2 ? d[2]['resContents'] : '';
          final addr = d.length > 3 ? d[3]['resContents'] : '';
          ownerLines.add('$share $name $ssn\n$addr');
        }
      }
    }
  }
  ownerRaw = ownerLines.join('\n');
  // purpose, receipt, cause는 기존 갑구 방식 유지(필요시 sumList에서 보완 가능)
  final gaGu = (entry['resRegistrationHisList'] as List?)?.firstWhere(
    (e) => e['resType'] == '갑구' && (e['resType1']?.toString() ?? '').contains('소유권'),
    orElse: () => <String, dynamic>{},
  );
  if (gaGu.isNotEmpty) {
    for (final block in (gaGu['resContentsList'] as List) ?? []) {
      for (final d in (block['resDetailList'] as List?) ?? []) {
        final text = d['resContents']?.toString() ?? '';
        if (text.contains('등기목적')) purpose = text.replaceAll('등기목적:', '').replaceAll('등기목적', '').trim();
        if (text.contains('접수')) receipt = text.replaceAll('접수:', '').replaceAll('접수', '').trim();
        if (text.contains('등기원인')) cause = text.replaceAll('등기원인:', '').replaceAll('등기원인', '').trim();
      }
    }
  }
  final ownership = Ownership(purpose, receipt, cause, ownerRaw);

  // areas.land
  String landPurpose = '', landArea = '';
  // 1. 표제부에서 기존 방식으로 시도
  final landSection = (entry['resRegistrationHisList'] as List?)?.firstWhere(
    (e) => e['resType'] == '표제부' && (e['resType1']?.toString() ?? '').contains('대지권'),
    orElse: () => null,
  );
  if (landSection != null) {
    for (final block in (landSection['resContentsList'] as List?) ?? []) {
      for (final d in (block['resDetailList'] as List?) ?? []) {
        final text = d['resContents']?.toString() ?? '';
        if (text.contains('지목')) landPurpose = text.replaceAll('지목', '').replaceAll(':', '').trim();
        if (text.contains('면적') || text.contains('㎡')) landArea = text.replaceAll(RegExp(r'[^\d.,㎡]'), '').trim();
      }
    }
  }
  // 2. 표제부가 없거나, 지목이 비어있으면 전체에서 지목 후보값 직접 탐색
  if (landPurpose.isEmpty) {
    final landCandidates = ['대', '전', '답', '임야', '잡종지', '도로', '공장용지', '학교용지', '주차장', '하천', '구거', '유지', '제방', '철도용지', '체육용지', '유원지', '공원', '묘지', '광천지', '염전', '수도용지', '공장용지', '창고용지', '종교용지', '사적지', '잡종지'];
    final hisList = entry['resRegistrationHisList'] as List? ?? [];
    for (final section in hisList) {
      for (final block in (section['resContentsList'] as List?) ?? []) {
        for (final d in (block['resDetailList'] as List?) ?? []) {
          final text = (d['resContents']?.toString() ?? '').trim();
          if (landCandidates.contains(text)) {
            landPurpose = text;
            break;
          }
        }
        if (landPurpose.isNotEmpty) break;
      }
      if (landPurpose.isNotEmpty) break;
    }
  }
  final land = LandArea(landPurpose, landArea);

  // areas.building
  String structure = '';
  List<FloorInfo> floors = [];
  final bldgSection = (entry['resRegistrationHisList'] as List?)?.firstWhere(
    (e) => e['resType'] == '표제부' && (e['resType1']?.toString() ?? '').contains('건물'),
    orElse: () => null,
  );
  // realtyDesc에서 해당 층 추출
  final realtyDesc = cleanRealtyDesc(entry['resRealty']?.toString() ?? '');
  final floorMatch = RegExp(r'(\d+(,\d+)*)층').firstMatch(realtyDesc);
  List<String> targetFloors = [];
  if (floorMatch != null) {
    targetFloors = floorMatch.group(1)!.split(',').map((f) => '$f층').toList();
  }
  if (bldgSection != null) {
    for (final block in (bldgSection['resContentsList'] as List?) ?? []) {
      String blockText = ((block['resDetailList'] as List?) ?? []).map((d) => d['resContents']?.toString() ?? '').join('\n');
      // 구조
      for (final d in (block['resDetailList'] as List?) ?? []) {
        final text = d['resContents']?.toString() ?? '';
        if ((text.contains('조') || text.contains('슬래브') || text.contains('지붕') || text.contains('아파트'))) {
          structure += '${clean(text)} ';
        }
      }
      // 층별 면적: 해당 층만 추출
      final floorMatches = RegExp(r'(\d+층)\s*([\d.]+㎡)').allMatches(blockText);
      for (final m in floorMatches) {
        if (targetFloors.contains(m.group(1))) {
          if (!floors.any((f) => f.floorLabel == m.group(1) && f.area == m.group(2))) {
            floors.add(FloorInfo(m.group(1), m.group(2)));
          }
        }
      }
    }
    structure = structure.trim();
  }
  final building = BuildingArea(structure, floors);

  // liens
  List<Lien> liens = [];
  final eulGu = (entry['resRegistrationHisList'] as List?)?.firstWhere(
    (e) => e['resType'] == '을구',
    orElse: () => null,
  );
  if (eulGu != null) {
    for (final block in (eulGu['resContentsList'] as List?) ?? []) {
      String purpose = '', receipt = '', mainText = '';
      for (final d in (block['resDetailList'] as List?) ?? []) {
        final text = d['resContents']?.toString() ?? '';
        if (text.contains('등기목적')) purpose = text.replaceAll('등기목적:', '').replaceAll('등기목적', '').trim();
        if (text.contains('접수')) receipt = text.replaceAll('접수:', '').replaceAll('접수', '').trim();
        if (text.contains('채권최고액') || text.contains('채무자') || text.contains('근저당권자')) mainText += '${clean(text)}\n';
      }
      mainText = filterMainText(mainText.trim());
      if (purpose.isNotEmpty || receipt.isNotEmpty || mainText.isNotEmpty) {
        liens.add(Lien(purpose, receipt, mainText));
      }
    }
  }

  return CurrentState(
    header   : header,
    ownership: ownership,
    land     : land,
    building : building,
    liens    : liens,
  );
} 