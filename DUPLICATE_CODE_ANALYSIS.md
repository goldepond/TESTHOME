# 프로젝트 중복 코드 점검 결과

> 작성일: 2025-01-XX  
> 분석 대상: 전체 프로젝트 코드베이스

---

## 📋 중복 코드 발견 요약

| 항목 | 중복 정도 | 위치 | 우선순위 |
|------|----------|------|---------|
| owner_parser.dart 중복 블록 | 매우 높음 | 8-47줄 vs 49-87줄 | 🔴 높음 |
| 비밀번호 검증 로직 | 중간 | signup_page, broker_signup_page | 🟡 중간 |
| 이메일 형식 검증 | 중간 | signup_page, forgot_password_page, admin_quote_requests_page | 🟡 중간 |
| API 응답 처리 패턴 | 높음 | 모든 API 서비스 | 🟡 중간 |
| 에러 처리 패턴 | 높음 | 여러 화면 | 🟢 낮음 |

---

## 🔴 높은 우선순위: 즉시 개선 권장

### 1. owner_parser.dart - 완전 중복 코드 블록

**문제점:**
- `resRegistrationHisList`와 `resRegistrationSumList`에서 거의 동일한 코드가 **완전히 중복**됨
- 약 40줄의 코드가 2번 반복됨
- 하드코딩된 테스트 이름도 포함 (`['김태형', '윤명혜', '전균익']`)

**현재 구조:**
```dart
// 8-47줄: resRegistrationHisList에서 소유자 추출
for (var item in registrationHisList) {
  if (item['resType'] == '갑구') {
    // ... 동일한 로직 ...
  }
}

// 49-87줄: resRegistrationSumList에서 소유자 추출 (거의 동일)
for (var item in registrationSumList) {
  if (item['resType'] == '갑구') {
    // ... 동일한 로직 ...
  }
}
```

**개선 방안:**
```dart
// 공통 함수로 추출
List<String> _extractOwnerNamesFromList(List<Map<String, dynamic>> list) {
  final ownerNames = <String>[];
  for (var item in list) {
    if (item['resType'] == '갑구') {
      // ... 로직 한 번만 작성 ...
    }
  }
  return ownerNames;
}

List<String> extractOwnerNames(Map<String, dynamic> entry) {
  final ownerNames = <String>[];
  
  final registrationHisList = safeMapList(entry['resRegistrationHisList']);
  ownerNames.addAll(_extractOwnerNamesFromList(registrationHisList));
  
  final registrationSumList = safeMapList(entry['resRegistrationSumList']);
  ownerNames.addAll(_extractOwnerNamesFromList(registrationSumList));
  
  return ownerNames.toSet().toList(); // 중복 제거
}
```

**개선 효과:**
- 코드 줄 수: 90줄 → 약 50줄 (44% 감소)
- 유지보수성 향상
- 테스트 이름 하드코딩 제거 가능

---

## 🟡 중간 우선순위: 점진적 개선 권장

### 2. 비밀번호 검증 로직 중복

**발견 위치:**
- `lib/screens/signup_page.dart:108-117`
- `lib/screens/broker/broker_signup_page.dart:157-165`

**중복 내용:**
```dart
// 두 파일 모두 동일한 검증
if (_passwordController.text != _passwordConfirmController.text) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('비밀번호가 일치하지 않습니다.'),
      backgroundColor: Colors.red,
    ),
  );
  return;
}
```

**개선 방안:**
- 유틸리티 함수로 추출하거나 그대로 유지 (단순 구조 선호 시)

---

### 3. 이메일 형식 검증 중복

**발견 위치:**
- `lib/screens/signup_page.dart:73`
- `lib/screens/forgot_password_page.dart:37`
- `lib/screens/admin/admin_quote_requests_page.dart:802`

**중복 내용:**
- 이메일 형식 검증 RegExp 패턴이 여러 곳에 반복됨

**개선 방안:**
- 상수로 분리하거나 유틸리티 함수로 추출

---

### 4. API 응답 처리 패턴 중복

**발견 위치:**
- 모든 API 서비스 파일 (`address_service.dart`, `vworld_service.dart`, `apt_info_service.dart`, `seoul_broker_service.dart`, `broker_service.dart` 등)

**중복 패턴:**
```dart
// 모든 API 서비스에서 반복되는 패턴
final response = await http.get(uri).timeout(...);
if (response.statusCode == 200) {
  final responseBody = utf8.decode(response.bodyBytes);
  final data = json.decode(responseBody);
  // ... 처리 ...
} else {
  return null; // 또는 에러 처리
}
```

**개선 방안:**
- 공통 HTTP 클라이언트 유틸리티 생성 (단, 단순 구조 선호 시 현재 구조 유지 가능)

---

## 🟢 낮은 우선순위: 선택적 개선

### 5. 에러 처리 패턴 중복

**발견:**
- `mounted` 체크: 84번 사용
- `ScaffoldMessenger.showSnackBar`: 110번 사용
- 유사한 에러 메시지 표시 패턴 반복

**개선 방안:**
- 유틸리티 함수로 추출하거나 그대로 유지 (단순 구조 선호 시)

---

## 📊 개선 효과 예상

### 코드 규모 감소
- **owner_parser.dart 최적화**: 90줄 → 약 50줄 (44% 감소)
- **하드코딩된 테스트 데이터 제거**: 추가 정리

### 유지보수성 향상
- 중복 코드 제거로 버그 수정 시 한 곳만 수정
- 로직 변경 시 영향 범위 명확화

---

## 🚀 권장 작업 순서

### 즉시 실행 (1-2시간)
1. ✅ **owner_parser.dart 중복 코드 제거** - 가장 큰 개선 효과
2. ✅ **하드코딩된 테스트 이름 제거** - 함께 처리

### 선택적 실행
3. 비밀번호 검증 로직 통합 (선택)
4. 이메일 검증 통합 (선택)
5. API 응답 처리 통합 (선택, 단순 구조 유지 시 불필요)

---

## 💡 단순 구조 유지 원칙

현재 프로젝트는 **단순한 구조**를 선호하신다고 하셨으므로:

✅ **권장**: owner_parser.dart 중복 제거 (명확한 중복)
⚠️ **선택**: 나머지 패턴 통합 (과도한 추상화 방지)

단순한 구조를 유지하면서도 명확한 중복 코드는 제거하는 것이 좋습니다.

