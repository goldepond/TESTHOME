/// 등기부등본 데이터에서 소유자 이름을 추출하는 함수
/// 다양한 패턴(소유자: 홍길동, 소유자+홍길동 등) 지원
import 'current_state_parser.dart';

/// 등기 목록에서 소유자 이름을 추출하는 공통 함수
void _extractOwnerNamesFromList(
  List<Map<String, dynamic>> registrationList,
  List<String> ownerNames,
) {
  for (var item in registrationList) {
    if (item['resType'] == '갑구') {
      final contentsList = safeMapList(item['resContentsList']);
      if (contentsList.isNotEmpty) {
        for (var content in contentsList) {
          final detailList = safeMapList(content['resDetailList']);
          if (detailList.isNotEmpty) {
            for (var detail in detailList) {
              final resContents = detail['resContents']?.toString() ?? '';
              if (resContents.contains('소유자')) {
                if (resContents.startsWith('소유자+')) {
                  final parts = resContents.split('+');
                  if (parts.length > 1) {
                    final ownerName = parts[1].trim();
                    if (ownerName.isNotEmpty && !ownerNames.contains(ownerName)) {
                      ownerNames.add(ownerName);
                    }
                  }
                } else if (resContents.startsWith('소유자:')) {
                  final ownerName = resContents.substring(4).trim();
                  if (ownerName.isNotEmpty && !ownerNames.contains(ownerName)) {
                    ownerNames.add(ownerName);
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}

List<String> extractOwnerNames(Map<String, dynamic> entry) {
  final List<String> ownerNames = [];

  // resRegistrationHisList에서 추출
  final registrationHisList = safeMapList(entry['resRegistrationHisList']);
  _extractOwnerNamesFromList(registrationHisList, ownerNames);

  // resRegistrationSumList에서도 추출
  final registrationSumList = safeMapList(entry['resRegistrationSumList']);
  _extractOwnerNamesFromList(registrationSumList, ownerNames);

  return ownerNames;
} 