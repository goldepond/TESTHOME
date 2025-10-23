# Flutter 버전 호환성 수정 내역

## 📅 수정 날짜
2025-10-23

## 🔧 문제 상황
친구가 올린 코드가 낮은 Flutter 버전으로 작성되어, 최신 Flutter에서 컴파일 에러 발생

## ❌ 발생한 에러

### 1. Radio 위젯 에러
```
Error: Required named parameter 'groupValue' must be provided.
  Radio<String>(value: opt['value']!)
```

### 2. RadioGroup 에러
```
Error: The method 'RadioGroup' isn't defined for the class.
  RadioGroup<String>(...)
```

### 3. Switch 위젯 에러 (deprecated)
```
Error: No named parameter with the name 'activeThumbColor'.
  activeThumbColor: Colors.green,
```

---

## ✅ 수정 내용

### 수정한 파일 목록
1. `lib/screens/contract/contract_step2_contract_conditions.dart`
2. `lib/screens/contract/contract_step3_deposit_management.dart`
3. `lib/screens/contract/contract_step4_direct_details.dart`
4. `lib/screens/contract/contract_step5_registration.dart`
5. `lib/screens/contract/contract_input_form.dart` ⭐ 추가 수정

---

## 📝 상세 수정 내역

### 1. Radio 위젯 수정

#### ❌ 이전 (에러 발생)
```dart
RadioGroup<String>(
  groupValue: state.value,
  onChanged: (v) {
    state.didChange(v);
    setState(() {
      _formData[key] = v;
    });
  },
  child: Wrap(
    spacing: 16,
    children: options.map((opt) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Radio<String>(value: opt['value']!),  // ❌ groupValue 없음
        Text(opt['label']!),
      ],
    )).toList(),
  ),
)
```

#### ✅ 이후 (정상 작동)
```dart
Wrap(
  spacing: 16,
  children: options.map((opt) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Radio<String>(
        value: opt['value']!,
        groupValue: state.value,  // ✅ 추가
        onChanged: (v) {          // ✅ 추가
          state.didChange(v);
          setState(() {
            _formData[key] = v;
          });
        },
      ),
      Text(opt['label']!),
    ],
  )).toList(),
)
```

**변경 사유**: 최신 Flutter에서는 Radio 위젯에 `groupValue`와 `onChanged`가 필수 파라미터입니다.

---

### 2. RadioGroup 제거

#### ❌ 이전
```dart
RadioGroup<String>(...)  // ❌ 존재하지 않는 위젯
```

#### ✅ 이후
```dart
Wrap(...)  // ✅ Flutter 표준 위젯 사용
```

**변경 사유**: `RadioGroup`은 Flutter 표준 위젯이 아닙니다. 친구가 커스텀 위젯을 사용하려 했거나 잘못 작성한 것으로 보입니다.

---

### 3. Switch 위젯 수정 (contract_step4_direct_details.dart만 해당)

#### ❌ 이전 (deprecated)
```dart
Switch(
  value: isSelected,
  onChanged: (value) {
    setState(() {
      _formData['clause_$key'] = value;
    });
  },
  activeThumbColor: Colors.green,  // ❌ deprecated
)
```

#### ✅ 이후 (최신 방식)
```dart
Switch(
  value: isSelected,
  onChanged: (value) {
    setState(() {
      _formData['clause_$key'] = value;
    });
  },
  thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
    if (states.contains(WidgetState.selected)) {
      return Colors.green;
    }
    return Colors.grey;
  }),
)
```

**변경 사유**: `activeThumbColor`는 최신 Flutter에서 deprecated되었습니다. `thumbColor`와 `WidgetStateProperty`를 사용해야 합니다.

---

## 🎯 결과

모든 컴파일 에러가 해결되어 앱이 정상적으로 실행됩니다.

---

## 📌 참고사항

### Flutter 버전 확인 방법
```bash
flutter --version
```

### 의존성 업데이트 방법
```bash
flutter pub get
flutter pub upgrade
```

### 향후 유사한 문제 발생 시
1. Flutter 버전을 팀원과 맞추기 (권장)
2. 또는 코드를 최신 Flutter 버전에 맞게 수정

---

## 💡 추가 권장사항

### 1. Flutter 버전 통일
팀원들끼리 Flutter 버전을 맞추는 것을 권장합니다:
```bash
flutter channel stable
flutter upgrade
```

### 2. .fvm 사용 (Flutter Version Management)
프로젝트별로 Flutter 버전을 고정하고 싶다면 FVM 사용을 권장:
```bash
# FVM 설치
dart pub global activate fvm

# 특정 버전 사용
fvm use 3.24.0

# .fvmrc 파일 생성하여 버전 고정
```

### 3. CI/CD 파이프라인에서 Flutter 버전 지정
GitHub Actions, GitLab CI 등에서 Flutter 버전을 명시적으로 지정하세요.

---

## 📞 문의사항
추가 문제가 발생하면 Flutter 버전과 에러 메시지를 함께 공유해주세요.

