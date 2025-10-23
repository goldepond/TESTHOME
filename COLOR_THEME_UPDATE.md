# 🎨 색상 테마 통일 업데이트

## 📅 업데이트 날짜
2025-10-23

## 🎯 목표
전체 앱의 색상을 HouseMVP 보라색 테마로 통일

---

## ✅ 변경된 색상

### 기존 (불일치)
```dart
kBrown = #1976D2  (파란색)
kLightBrown = #F5F5F5 (회색)
kDarkBrown = #0D1333 (진한 파란색)
```

### 신규 (통일)
```dart
// 메인 컬러
kPrimary = #8b5cf6     (메인 보라색)
kSecondary = #6366f1   (인디고)
kAccent = #7c3aed      (진한 보라색)

// 배경 & 텍스트
kBackground = #F8F9FA   (밝은 회색)
kSurface = #FFFFFF      (흰색)
kTextPrimary = #333333  (진한 회색)
kTextSecondary = #666666 (보통 회색)
kTextLight = #999999    (밝은 회색)

// 그라데이션
kGradientStart = #87CEEB (Sky Blue)
kGradientEnd = #8b5cf6   (Purple)

// 상태 컬러
kSuccess = #10b981  (녹색)
kWarning = #f59e0b  (주황)
kError = #ef4444    (빨강)
kInfo = #3b82f6     (파랑)
```

---

## 📝 수정된 파일

### 1. `lib/constants/app_constants.dart`
- ✅ 새로운 색상 상수 추가
- ✅ 하위 호환성을 위한 별칭 유지 (kBrown → kPrimary)
- ✅ 그라데이션 색상 추가
- ✅ 상태 컬러 추가

### 2. `lib/main.dart`
- ✅ 전체 앱 테마를 보라색으로 변경
- ✅ ElevatedButton 기본 스타일 통일
- ✅ OutlinedButton 기본 스타일 통일
- ✅ TextButton 기본 스타일 통일
- ✅ FloatingActionButton 기본 스타일 통일
- ✅ Card 기본 스타일 통일
- ✅ InputDecoration 기본 스타일 통일
- ✅ AppBar 기본 스타일 통일

### 3. `lib/screens/landing_page.dart`
- ✅ 하드코딩된 색상 값을 AppColors 상수로 변경
- ✅ 그라데이션 배경 색상 통일
- ✅ 버튼 색상 통일
- ✅ 텍스트 색상 통일

---

## 🎨 적용된 디자인 원칙

### 1. 메인 컬러
- **Primary (#8b5cf6)**: 메인 액션 버튼, 강조 요소
- **Secondary (#6366f1)**: 서브 액션, 보조 강조
- **Accent (#7c3aed)**: 호버, 선택 상태

### 2. 텍스트 계층
- **TextPrimary (#333333)**: 제목, 중요 텍스트
- **TextSecondary (#666666)**: 본문, 일반 텍스트
- **TextLight (#999999)**: 보조 정보, 힌트

### 3. 배경 계층
- **Surface (#FFFFFF)**: 카드, 모달
- **Background (#F8F9FA)**: 전체 배경

### 4. 그라데이션
- **시작 (#87CEEB)**: Sky Blue
- **끝 (#8b5cf6)**: Purple
- **방향**: TopLeft → BottomRight

---

## 📱 적용된 컴포넌트

### 버튼
```dart
// ElevatedButton
backgroundColor: AppColors.kPrimary (#8b5cf6)
foregroundColor: Colors.white
borderRadius: 8px

// OutlinedButton
foregroundColor: AppColors.kPrimary
borderColor: AppColors.kPrimary
borderRadius: 8px

// TextButton
foregroundColor: AppColors.kPrimary
```

### 입력 필드
```dart
// 기본 Border
borderColor: Colors.grey[300]
borderRadius: 8px

// Focus Border
borderColor: AppColors.kPrimary (#8b5cf6)
borderWidth: 2px
```

### AppBar
```dart
backgroundColor: AppColors.kPrimary (#8b5cf6)
foregroundColor: Colors.white
elevation: 2
```

### Card
```dart
elevation: 2
borderRadius: 12px
```

### FloatingActionButton
```dart
backgroundColor: AppColors.kPrimary (#8b5cf6)
foregroundColor: Colors.white
```

---

## 🔧 하위 호환성

기존 코드와의 호환을 위해 별칭 유지:
```dart
kBrown = kPrimary
kLightBrown = kBackground
kDarkBrown = kAccent
```

이렇게 하면 기존 코드를 수정하지 않아도 새 색상이 적용됨!

---

## 🚀 사용 방법

### 색상 사용
```dart
// ✅ 권장
Container(
  color: AppColors.kPrimary,
)

// ⚠️ 사용 가능 (하위 호환)
Container(
  color: AppColors.kBrown,
)

// ❌ 지양
Container(
  color: Color(0xFF8b5cf6),
)
```

### 테마 활용
```dart
// 자동으로 테마 색상 적용
ElevatedButton(
  onPressed: () {},
  child: Text('버튼'),
)

// 커스텀 색상이 필요한 경우
ElevatedButton(
  onPressed: () {},
  style: ElevatedButton.styleFrom(
    backgroundColor: AppColors.kSuccess, // 녹색 버튼
  ),
  child: Text('성공'),
)
```

---

## 📊 색상 팔레트

### 메인 컬러
| 색상 | Hex | 용도 |
|------|-----|------|
| 🟣 Primary | #8b5cf6 | 메인 액션, 강조 |
| 🔵 Secondary | #6366f1 | 서브 액션, 보조 강조 |
| 🟣 Accent | #7c3aed | 호버, 선택 상태 |

### 배경 & 텍스트
| 색상 | Hex | 용도 |
|------|-----|------|
| ⬜ Surface | #FFFFFF | 카드, 모달 |
| ⬜ Background | #F8F9FA | 전체 배경 |
| ⬛ TextPrimary | #333333 | 제목 |
| ⬛ TextSecondary | #666666 | 본문 |
| ⬛ TextLight | #999999 | 보조 정보 |

### 상태 컬러
| 색상 | Hex | 용도 |
|------|-----|------|
| 🟢 Success | #10b981 | 성공 메시지 |
| 🟠 Warning | #f59e0b | 경고 메시지 |
| 🔴 Error | #ef4444 | 에러 메시지 |
| 🔵 Info | #3b82f6 | 정보 메시지 |

### 그라데이션
| 색상 | Hex | 용도 |
|------|-----|------|
| 🔵 Gradient Start | #87CEEB | Sky Blue |
| 🟣 Gradient End | #8b5cf6 | Purple |

---

## 🎯 통일 효과

### Before (불일치)
- 랜딩 페이지: 보라색 (#8b5cf6)
- 로그인 페이지: 파란색 (#1976D2)
- 메인 페이지: 파란색 (#1976D2)
- 각 페이지마다 다른 색상

### After (통일)
- 모든 페이지: 보라색 (#8b5cf6) ✅
- 일관된 디자인 ✅
- 브랜드 정체성 강화 ✅
- 사용자 경험 향상 ✅

---

## 📱 테스트 체크리스트

### 화면별 확인
- ✅ 랜딩 페이지: 그라데이션 배경, 검색 버튼
- ⏳ 로그인 페이지: 로그인 버튼, 링크
- ⏳ 메인 페이지: AppBar, FAB, 버튼들
- ⏳ 매물 목록: 카드, 필터 버튼
- ⏳ 매물 상세: 액션 버튼들
- ⏳ 계약서 작성: 단계별 버튼

### 컴포넌트별 확인
- ✅ ElevatedButton: 보라색 배경
- ✅ OutlinedButton: 보라색 테두리
- ✅ TextButton: 보라색 텍스트
- ⏳ AppBar: 보라색 배경
- ⏳ FloatingActionButton: 보라색 배경
- ⏳ TextField: 포커스 시 보라색 테두리
- ⏳ Card: 일관된 elevation과 border radius

---

## 💡 추가 개선 사항

### 다크 모드 지원 (향후)
```dart
ThemeData.dark().copyWith(
  colorScheme: ColorScheme.dark(
    primary: AppColors.kPrimary,
    secondary: AppColors.kSecondary,
    ...
  ),
)
```

### 접근성 개선
- 색상 대비 비율 확인 (WCAG AA 기준)
- 색맹 사용자를 위한 아이콘/텍스트 병기

---

## ✨ 완료!

이제 전체 앱이 일관된 보라색 테마로 통일되었습니다! 🎉

**Hot Reload로 즉시 확인하세요:**
```bash
# 앱이 실행 중이면
R 키 누르기 (Hot Reload)

# 앱을 새로 실행하려면
flutter run -d chrome
```

**주요 변경점:**
- 🎨 모든 메인 액션 버튼: 보라색
- 📝 모든 입력 필드 포커스: 보라색 테두리
- 📱 모든 AppBar: 보라색 배경
- 🎯 일관된 사용자 경험

