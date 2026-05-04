# Material Design vs 80세 doctrine — 충돌 매트릭스 가이드

> **상위 문서**: [`08-simplicity-doctrine.md`](../task/08-simplicity-doctrine.md)
> **카피 단일 진실원**: [`copy-deck.md`](copy-deck.md)
> **PR 자가 점검**: [`simplicity-checklist.md`](simplicity-checklist.md)
> **연결 task**: [`task/2026-05-03-MASTER-v1.3-mvp-handoff.md §3.3 P2-1`](../task/2026-05-03-MASTER-v1.3-mvp-handoff.md)
> **버전**: v1.1.0 (P2-1 확장, 2026-05-03)
> **유지 책임**: 새 위젯 도입 시 Material 기본 동작과 doctrine §3 절 충돌 여부 검토 → 본 §2 매트릭스에 1행 추가.
> **구현 영향**: 본 문서는 *판단 기준 문서*. 코드 변경은 본 문서를 근거로 별도 PR에서 수행.

---

## 1. 목적

### 1.1 Material Design의 *암묵적 가정*

MyHome은 `useMaterial3: false` (Material 2)로 빌드되지만, Flutter SDK가 제공하는 Material 위젯 — `Scaffold`, `BottomNavigationBar`, `FloatingActionButton`, `Chip`, `SnackBar`, `Tooltip`, `DatePicker`, `TimePicker`, `Switch`, `Drawer`, `TabBar`, `Stepper` — 는 모두 **Material Design 3 가이드라인의 암묵적 가정**을 default로 갖고 있다.

| Material 암묵적 가정 | 출처 (공식 문서) |
|---|---|
| **밀도(density) 우선** — 한 화면에 가능한 많은 정보를 압축 (dense list, dense form, compact density) | [m3.material.io/foundations/layout](https://m3.material.io/foundations/layout/applying-layout/window-size-classes) |
| **아이콘 우선** — 라벨 없는 FAB·IconButton으로 직관 전달, tooltip은 long-press로 보조 | [m3.material.io/components/floating-action-button](https://m3.material.io/components/floating-action-button) |
| **축약 선호** — Snackbar 짧은 영문, Chip 약어 라벨, Numeric badge raw count | [m3.material.io/components/snackbar](https://m3.material.io/components/snackbar) |
| **호버 의존** — Tooltip은 데스크톱 호버, 모바일 long-press 가정 (alternative 미보장) | [m3.material.io/components/tooltips](https://m3.material.io/components/tooltips) |
| **컬러 의미 부여 자율** — 빨간 텍스트만으로 에러 표시, 컬러 단독 상태 표현 가능 | [m3.material.io/foundations/accessible-design/color-contrast](https://m3.material.io/foundations/accessible-design/color-contrast) |

### 1.2 80세 doctrine과의 충돌

이 가정들은 **MyHome doctrine §3 (80세 노인 테스트)** 와 정면 충돌한다. doctrine §3은 다음을 강제한다:

- **§3.1 언어**: 일상 한국어. 한자어보다 순우리말. 영어 외래어 절대 금지.
- **§3.2 한 화면 = 한 결정**: 의사결정 ≤ 2개.
- **§3.3 알림 한 줄**: 30자 이내, 한 줄.
- **§3.4 숫자**: 백분율 0, 점수 0, 코드 노출 0.
- **§3.5 색상·아이콘**: 신호등 3색 + 글씨. 아이콘 단독 의미 전달 금지.
- **§3.6 흐름 깊이**: 3 탭 이내 완료. "더 보기" 안에 핵심 기능 숨기기 금지.
- **§3.7 에러 메시지**: 원인 + 해결법 노인 화법.

### 1.3 사전 결정 원칙

이 매트릭스는 *Material 일방 비판*이 아니다. 모든 충돌 지점에서 **doctrine 화면(매도자/매수자/중개사/공개)** vs **Material 화면(admin)** 사전 분류를 강제하여 PR 검토 시 *어느 룰을 적용할지* 즉시 판단 가능하게 한다.

```
이 화면을 누가 보는가?
├── 일반 사용자 (매도자/매수자/중개사/공개)
│     → doctrine §3 절대 우선. 본 §2 매트릭스 12행 전체 적용.
├── 운영자 (lib/screens/admin/*)
│     → Material default 허용. 본 §4 사례.
└── 하이브리드 (매도자가 보는 audit timeline, 운영자→사용자 통지문)
      → doctrine §5 우선. copy-deck.md §5·§6 단어 정책 준수.
```

---

## 2. 충돌 매트릭스 (12행)

> **표 읽는 법**: 각 행 = Material 권장 / doctrine 위반 사유 / MyHome 적용 / 코드 예시 (부정 → 긍정).

### 2.1 Dense layout (간격 축소)

| 항목 | 내용 |
|---|---|
| **Material 권장** | `ListTile(dense: true)`, `VisualDensity.compact`, `AlertDialog(contentPadding: EdgeInsets.fromLTRB(16,12,16,12))` — 한 화면에 더 많은 항목 표시 |
| **doctrine 위반** | §3.5 시각 — *작은 글씨(<14sp) 핵심 정보 사용 0*. 80세 노인은 행간이 좁으면 같은 줄을 두 번 읽고 다음 줄을 못 찾는다 |
| **MyHome 적용** | 사용자 화면 — `dense: false` (default) 강제. 행간 `AppSpacing.md(16)` 이상. ListTile 높이 최소 56dp. `materialTapTargetSize: MaterialTapTargetSize.padded` 유지 |

```dart
// X Material default 추종
ListTile(dense: true, title: Text('내 차례'))

// O doctrine 권고
ListTile(
  contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
  title: Text(GrantMessages.badgeMineActive, style: AppTypography.body),
)
```

### 2.2 Icon-only FAB

| 항목 | 내용 |
|---|---|
| **Material 권장** | `FloatingActionButton(child: Icon(Icons.add))` — 단일 아이콘으로 primary action 전달. tooltip은 long-press 보조 |
| **doctrine 위반** | §3.5 — *아이콘 단독 의미 전달 금지. 모든 아이콘에 글씨 동반*. 80세 노인은 `+`가 "추가"인지 "더하기 계산"인지 구분 못 함. tooltip long-press는 학습되지 않음 |
| **MyHome 적용** | `FloatingActionButton.extended(label: Text('매물 올리기'), icon: Icon(Icons.add))` — *반드시 label 동반*. copy-deck §1.3 통일 라벨 사용 |

```dart
// X Material default
FloatingActionButton(onPressed: _create, child: Icon(Icons.add))

// O doctrine
FloatingActionButton.extended(
  onPressed: _create,
  icon: Icon(Icons.add),
  label: Text('매물 올리기'), // copy-deck §1.3
)
```

### 2.3 Bottom navigation 5+ 탭

| 항목 | 내용 |
|---|---|
| **Material 권장** | `BottomNavigationBar` 3~5 탭 — Material 3는 `BottomNavigationBarType.fixed`로 최대 5탭 지원. 이상은 Drawer로 |
| **doctrine 위반** | §3.6 — *흐름 깊이 ≤ 3 탭*. §3.2 *한 화면 의사결정 ≤ 2*. 5탭은 첫 진입에서 *5개 의사결정* 강제. 80세 노인 인지 부담 |
| **MyHome 적용** | 사용자 화면 — 최대 **3 탭**. 4번째부터는 화면 *없애기* (분리 X — "더 보기" 안에 핵심 숨기는 안티패턴 §7). 중개사 대시보드: 받은 매물 / 매수 손님 / 활동 = 3탭 |

```dart
// X 5탭 사용자 화면
BottomNavigationBar(items: [home, search, listings, chat, profile])

// O 3탭
BottomNavigationBar(items: [home, listings, profile])
// "검색"은 home 내부 SearchBar, "채팅"은 listings 카드 진입 후
```

### 2.4 Snackbar 짧은 영문

| 항목 | 내용 |
|---|---|
| **Material 권장** | Snackbar 1줄 ~80자, "Saved", "Removed", "Error: 503" 같은 짧은 영문 통지. `SnackBarAction(label: 'UNDO')` 4초 노출 |
| **doctrine 위반** | §3.7 — *원인 + 해결법 노인 화법*. "Error: 503"은 코드 노출(§3.4 위반). UNDO action은 4초 안에 *읽고 결정 누르기* 80세 불가능 |
| **MyHome 적용** | 모든 SnackBar는 [copy-deck §3](copy-deck.md) `reasonCopy` 한국어 매핑. 30자 이내, 원인+해결법 동시. action 버튼 금지. 되돌리기는 명시적 화면 진입으로 |

```dart
// X Material default
SnackBar(
  content: Text('Network error: 503'),
  action: SnackBarAction(label: 'UNDO', onPressed: _undo),
)

// O doctrine
SnackBar(
  content: Text('지금 인터넷이 약해요. 잠시 후 다시 해보세요'),
  duration: Duration(seconds: 6), // 4초 -> 6초 허용
)
```

### 2.5 Tooltip 호버 (모바일에서 부재)

| 항목 | 내용 |
|---|---|
| **Material 권장** | `Tooltip(message: '도움말', child: Icon(Icons.help_outline))` — 데스크톱 호버 또는 모바일 long-press로 노출 |
| **doctrine 위반** | §3.5·§7 안티패턴 — *입력 필드 옆 작은 (?) 도움말 아이콘 금지*. 80세 노인은 호버·long-press 모름. 핵심 정보가 숨겨지면 *없는 것과 동일* |
| **MyHome 적용** | 사용자 화면 — Tooltip이 *유일한* 의미 전달 채널 금지. 핵심 정보는 본문 또는 "자세히" 별도 화면. tooltip은 보조 정보 전용 (Semantics 접근성용 동반 가능) |

```dart
// X Tooltip만 의미 전달
IconButton(tooltip: '즐겨찾기', icon: Icon(Icons.favorite_border), onPressed: _toggle)

// O 글씨 동반
TextButton.icon(
  onPressed: _toggle,
  icon: Icon(Icons.favorite_border),
  label: Text('즐겨찾기'),
)
```

### 2.6 Color-only 상태 (빨간 텍스트만으로 에러)

| 항목 | 내용 |
|---|---|
| **Material 권장** | `Text('Invalid', style: TextStyle(color: Colors.red))` — 컬러로 에러 의미 부여. 점·뱃지 컬러 단독 상태 표시 |
| **doctrine 위반** | §3.5 — *신호등 3색 + 글씨*. 80세 노인은 회색·연한 빨강 구분 어려움. WCAG AA 1.4.1 컬러 단독 의미 전달은 색맹 사용자 차단 |
| **MyHome 적용** | 모든 상태 신호는 *컬러 + 글씨 + 아이콘* 3중. 신호등 3색(빨/주/녹) 외 상태 신호 금지. `AirbnbColors.textLight` 단독 핵심 정보 표시 0 |

```dart
// X 컬러 단독
Text(errorText, style: TextStyle(color: Colors.red))

// O 컬러 + 아이콘 + 글씨
Row(children: [
  Icon(Icons.error_outline, color: AirbnbColors.error, size: 20),
  SizedBox(width: AppSpacing.xs),
  Text('전화번호는 숫자만 적어주세요',
       style: AppTypography.withColor(AppTypography.body, AirbnbColors.error)),
])
```

### 2.7 Tab + Drawer 중첩

| 항목 | 내용 |
|---|---|
| **Material 권장** | 상단 `TabBar(3 tabs) + Drawer(NavigationDrawer)` — 한 화면에 두 종류 navigation 동시 제공 (M3 권장 패턴) |
| **doctrine 위반** | §3.6 — *흐름 깊이 ≤ 3 탭*. Tab + Drawer 중첩은 사용자에게 "지금 어디에 있는가?" 혼란 + 결정 채널 2개 강제 |
| **MyHome 적용** | 사용자 화면 — Drawer 사용 금지. BottomNavigationBar 단일 navigation. TabBar는 *동일 컨텍스트 내 sub-view*에 한함. 햄버거 메뉴(좌상단 ≡) 금지 — ZDNet Korea 60대 인지율 33% |

```dart
// X Drawer + Tab 중첩
Scaffold(
  drawer: NavigationDrawer(...),
  appBar: AppBar(bottom: TabBar(tabs: [...])),
)

// O 단일 navigation
Scaffold(
  bottomNavigationBar: BottomNavigationBar(items: [...]),
  body: TabBarView(...),
)
```

### 2.8 Chip filter (제목 약어)

| 항목 | 내용 |
|---|---|
| **Material 권장** | `FilterChip(label: Text('1R'))` — 약어 라벨로 가로 공간 절약. M3 chip 가이드 short label 권장 |
| **doctrine 위반** | §3.1 — *일상 한국어. 한자어보다 순우리말. 영어 외래어 절대 금지*. "1R", "OF", "EX", "Tier 1" 등 약어는 80세 노인에게 외계어 |
| **MyHome 적용** | 모든 Chip 라벨은 [copy-deck §1.3](copy-deck.md) 통일 라벨 사용. "원룸", "오피스텔" 풀네임. 가로 부족 시 chip을 *가로 스크롤* (`SingleChildScrollView`) 또는 카드 분리 |

```dart
// X 약어
FilterChip(label: Text('1R'), selected: ...)

// O 풀네임
FilterChip(label: Text('원룸'), selected: ...)
```

### 2.9 Date picker (영문 월)

| 항목 | 내용 |
|---|---|
| **Material 권장** | `showDatePicker(...)` — locale에 따라 'April 12, 2026' 또는 '4월 12, 2026'. default English 가능 |
| **doctrine 위반** | §3.4·§3.1 — *"○○월 ○○일 ○○시 시작"*. "April 12"는 외래어, "4/12"는 추상 |
| **MyHome 적용** | `MaterialApp(locale: Locale('ko'), localizationsDelegates: GlobalMaterialLocalizations.delegate)` 강제. 표시 포맷 "4월 12일 (목)" — 요일 동반 |

```dart
// X locale 미지정
showDatePicker(context: ctx, initialDate: now, firstDate: ..., lastDate: ...)

// O ko locale + 한국어 포맷
showDatePicker(context: ctx, locale: Locale('ko'), ...);
DateFormat('M월 d일 (E)', 'ko_KR').format(date) // "4월 12일 (목)"
```

### 2.10 Time picker (24시)

| 항목 | 내용 |
|---|---|
| **Material 권장** | `showTimePicker(...)` — 시스템 24시·12시 설정 따라감. "14:00" 가능 |
| **doctrine 위반** | §3.4·§3.1 — *"오후 2시"*. "14:00"은 군대·기관 화법, 노인은 12시 자연어 우선 |
| **MyHome 적용** | `MediaQuery.copyWith(alwaysUse24HourFormat: false)` 강제. 결과 표시 "오후 2시" — 분 0이면 분 생략. copy-deck §2.6 audit timeline 형식과 일치 |

```dart
// X 24시 표시
Text('14:00')

// O 12시 한국어
MediaQuery(
  data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
  child: showTimePicker(...),
);
DateFormat('a h시', 'ko_KR').format(time) // "오후 2시"
```

### 2.11 Numeric badge (4자리+)

| 항목 | 내용 |
|---|---|
| **Material 권장** | `Badge(label: Text('1234'))` — 카운트 그대로 노출. 99+ 정도만 잘라냄 |
| **doctrine 위반** | §3.4 — *백분율 0, 카운트는 "5개 중 3개"*. "1234"는 추상 숫자, 의미 없음. raw count는 노인에 부담 |
| **MyHome 적용** | 사용자 화면 카운트는 *맥락 동반*. "5개 중 3개", "12일 남았어요". 4자리 이상은 "많이"·"여러 건"으로 추상화. copy-deck §1.4 백분율 절대 금지 |

```dart
// X raw 4자리
Badge(label: Text('1234'), child: Icon(Icons.notifications))

// O 99+ 또는 텍스트 라인
Badge(label: Text('99+'), child: Icon(Icons.notifications))
// 또는
Text('읽지 않은 알림 12건', style: AppTypography.bodySmall)
```

### 2.12 Material Switch (label 옆 상태 표시)

| 항목 | 내용 |
|---|---|
| **Material 권장** | `Switch(value: true, onChanged: ...)` — on/off는 토글 위치(좌/우)와 컬러로만 표현. 빠른 토글 |
| **doctrine 위반** | §3.5 — *상태 색·글씨 동반*. 80세 노인은 토글 위치만으로 "켜진 상태"인지 인식 어려움. Switch는 미세 조작·실수 클릭 빈번 |
| **MyHome 적용** | `SwitchListTile(title, subtitle: Text(value ? '켜짐' : '꺼짐'), value, onChanged)` — 상태 텍스트 명시. 컬러는 보조. 중요 결정은 Radio + Confirm 패턴으로 (matrix §2.7 본 doctrine 우선 사례 4번 참조) |

```dart
// X Switch 단독
Switch(value: pushEnabled, onChanged: _toggle)

// O SwitchListTile + 상태 글씨
SwitchListTile(
  title: Text('알림 받기'),
  subtitle: Text(pushEnabled ? '켜짐' : '꺼짐'),
  value: pushEnabled,
  onChanged: _toggle,
)
```

---

## 3. doctrine이 우선하는 케이스 5가지 (사례 인용)

다음 5건은 사용자 화면에서 **Material default를 거부하고 doctrine을 따른 실제 사례**다. [copy-deck.md](copy-deck.md) 등록된 카피를 인용한다.

### 3.1 SnackBar 카피 — `reasonCopy` 한국어 매핑 강제

[copy-deck §3](copy-deck.md) 사유 코드 26종 모두 `lib/constants/grant_messages.dart::reasonCopy` 에서 한국어 변환. Cloud Functions의 `error.code` raw 값이 SnackBar에 절대 노출되지 않도록 3-레이어 동기 (`functions/index.js REASON` ↔ `reasonCopy` ↔ `copy-deck §3`).

**예**: `cap_exceeded` → "이미 5개를 맡고 있어요" (Material default라면 "Cap exceeded" 노출 가능)

### 3.2 매물 등록 액션 라벨 — `actionTakeProperty` 통일

[copy-deck §1.3·§2.1](copy-deck.md) 통일 라벨 표 — 같은 동작에 화면마다 다른 단어 금지. Material `FloatingActionButton.extended` 라벨은 화면별로 자유 작성 가능하지만, MyHome에서는 "이 매물 받기" 단일 라벨 강제 ("참여 등록"·"수락" 금지). **§2.2 본 매트릭스 row 직접 적용**.

### 3.3 Tier 진행 안내 — Tier/단계 단어 금지

[copy-deck §2.5](copy-deck.md) — Material default라면 "Tier 1: 1km radius" 같은 영어 직역체 가능. doctrine §3.1에 따라 "오늘은 우리 동네 중개사들이 봅니다" 자연어 매핑. **§2.8 Chip filter 약어 금지 규칙**과 동일 원칙.

### 3.4 활동 잔여 표시 — 백분율 절대 금지

[copy-deck §2.1](copy-deck.md) `sellerActivityRemainingParticipation` — Material `LinearProgressIndicator(value: 0.8)` + "80%" 라벨 default 가능. doctrine §3.4에 따라 "남은 일: 임장 1건"으로 *행위 단위* 표시. **§2.11 Numeric badge 룰 적용**.

### 3.5 매수자 담당 중개사 변경 — 다이얼로그 내부 부가 설명 분리

[copy-deck §2.3](copy-deck.md) `buyerSwitchConfirmBody` — Material `AlertDialog`는 본문에 자유 텍스트 가능하지만, doctrine §3.2에 따라 다이얼로그 안에 부가 설명 *최소화* 원칙. 한 줄 결정 + 카드/버튼만. 부가 설명은 별도 화면 또는 (자세히) 링크. 또한 모달 위 모달(다이얼로그 중첩) 금지 — [simplicity-checklist §4](simplicity-checklist.md) 안티패턴.

---

## 4. Material이 더 적합한 케이스 (admin 화면 한정)

[copy-deck §6](copy-deck.md) "운영자(Admin) 화면 — 별도 룰" 에 따라 다음 admin 화면은 **Material default 허용** — 운영자는 직무 전문 사용자이므로 정보 밀도가 *효율*이며, 약어·점수·코드는 운영 디버깅의 *공통 언어*다.

| Admin 화면 | Material default 허용 항목 (본 §2 매트릭스 면제) |
|---|---|
| `lib/screens/admin/admin_dashboard.dart` | §2.1 dense ListTile (운영자는 한 화면에 50+ 항목 봐야 함), §2.7 Drawer navigation, §2.3 BottomNav 5+ 탭 |
| `lib/screens/admin/admin_matching_page.dart` | §2.8 Chip 약어 ("매칭 중", "EX" 등 운영 약어), §2.6 Color-only status (빨강/노랑/녹색 단독), §2.11 Numeric badge raw count |
| `lib/screens/admin/admin_broker_stats_page.dart` | 백분율 차트 ("활동률 80%"), 점수 노출 ("신뢰도 87"), §2.10 24시 표시 ("14:32"), §2.9 영문 월 가능 |
| `lib/screens/admin/admin_appeals_page.dart` | eventType raw value ("grant_issued"), §2.5 Tooltip 호버 도움말, §2.1 dense form 필드 다수 |
| `lib/screens/admin/admin_priority_audit_page.dart` | audit eventType raw, 가중치 변수 노출, §2.12 Switch 단독 토글 |

**근거**: 80세 노인 테스트는 *비전문 사용자* 보호용이며 운영자에게 적용 시 오히려 작업 효율을 해친다. [copy-deck §6](copy-deck.md) 명시적 허용.

**예외 (도로 doctrine 적용)**: 운영자가 *결과를 사용자에게 전달*하는 자리:
- 이의 제기 처리 *결과 통지문* (운영자 입력 → 매수자/매도자/중개사 노출)
- 매물 거절 *사유 안내* (운영자 코멘트 → 매도자 노출)
- 단독 모드 강제 변경 시 *매도자 알림* ([master handoff P1-11](../task/2026-05-03-MASTER-v1.3-mvp-handoff.md) `adminOverrideListingMode`)

→ 이 경로의 카피는 본 §2 매트릭스 + [simplicity-checklist §3](simplicity-checklist.md) 통과 필수.

---

## 5. 충돌 해결 원칙

### 5.1 우선순위 매트릭스

```
사용자 화면 (lib/screens/{seller,broker,public,auth}/*)
  → doctrine 절대 우선
  → Material default 거부, 본 §2 12행 적용

운영자 화면 (lib/screens/admin/*)
  → Material default 허용
  → 단, 사용자 노출 통지문 경로는 사용자 화면 룰

하이브리드 영역 (사실 통지)
  ├── 매도자 audit timeline (auditEventLabel)
  │   → doctrine §5 우선 — "우선권" 단어 허용 (사실 전달 필수)
  │     copy-deck §5 표 참조
  ├── 매도자 보유자 강조 (participationHolderBadge)
  │   → doctrine §5 우선 — "현재 우선권 보유" (1건 허용)
  │     master handoff P1-15 가드 — *중개사 시야* 노출 차단
  └── 운영자→사용자 통지문 (admin_appeals 결과, 거절 사유)
      → 사용자 화면 룰 적용
```

### 5.2 PR 검토 흐름

1. **이 PR이 사용자 화면을 건드리는가?** → §2 12행 매트릭스 전체 검토. 위반 발견 시 즉시 거절.
2. **이 PR이 admin 화면 한정인가?** → Material default 허용. 단, *사용자 노출 통지 경로*가 있는지 한 번 더 확인 ([copy-deck §6](copy-deck.md) 마지막 단락).
3. **하이브리드 영역인가?** → [copy-deck §5](copy-deck.md) "우선권" 단어 정책 표 확인. *허용 화면 (매도자 audit / 매도자 보유자)* 외에는 사용 금지.

### 5.3 PR 본문 첨부 체크리스트

```markdown
## Material vs doctrine 충돌 검토 (P2-1)
- [ ] §2.1 dense layout 사용 여부 (`dense: true` / 패딩 축소) — 사용자 화면 0
- [ ] §2.2 icon-only FAB / icon-only IconButton — 0 (또는 글씨 라벨 동반)
- [ ] §2.3 BottomNavigationBar 4탭 이상 — 0
- [ ] §2.4 SnackBarAction (`UNDO`) 또는 raw error code — 0
- [ ] §2.5 Tooltip이 *유일한* 의미 전달 채널 — 0
- [ ] §2.6 컬러 단독 상태 표시 — 0
- [ ] §2.7 Drawer + TabBar 중첩 — 0
- [ ] §2.8 Chip 약어 라벨 — 0
- [ ] §2.9 Date picker locale 미지정 / 영문 월 표시 — 0
- [ ] §2.10 24시 표시 — 0
- [ ] §2.11 Numeric badge 4자리+ raw count — 0 (또는 99+ 처리)
- [ ] §2.12 Switch 단독 (상태 글씨 미동반) — 0
```

`lib/screens/admin/**` 화이트리스트 — 본 체크리스트 적용 제외 (단, 운영자→사용자 통지 경로는 적용).

### 5.4 새 위젯 도입 시

Flutter SDK가 새 Material 위젯을 추가하거나 (M3 → M4 등) MyHome에 새 위젯을 도입할 때:

1. 본 §2 매트릭스에 새 행 추가 검토. 충돌이 발견되면 *반드시 1행 추가*.
2. doctrine §3 절 (언어/한 화면 한 결정/알림/숫자/색상·아이콘/흐름 깊이/에러 메시지) 7개 절 중 어느 절과 충돌하는지 명시.
3. PR 본문에 본 문서 갱신 라인 첨부.

---

## 6. Material 표준을 *그대로* 사용해도 좋은 패턴 (충돌 없음)

본 doctrine과 충돌하지 않는 Material 표준은 적용 권장:

| 패턴 | 사용처 |
|---|---|
| `Card` (`elevation`·`borderRadius`) | 매물 카드 — `CommonDesignSystem.cardDecoration` |
| `AppBar` / `BackButton` | 모든 페이지 상단. 되돌리기 경로 명시 ([simplicity-checklist §2 흐름](simplicity-checklist.md)) |
| `BottomSheet` (단일 액션) | 매물 카드 액션 메뉴 — 단, 액션 ≤ 2개 |
| `AlertDialog` (확인 다이얼로그) | "이 매물 놓기" 확인 등. *모달 위 모달 금지* |
| `CircularProgressIndicator` | 비동기 작업 진행 표시 |
| `RefreshIndicator` (pull-to-refresh) | 목록 화면 |
| `Theme` / `ColorScheme` | `AirbnbColors.primary` 기반 — 변경 없음 |
| `TabBar` (상단, 동일 컨텍스트 sub-view) | 일상 한국어 라벨 동반 시 5탭까지 허용 (BottomNav와 다름 — 분류 진입) |

---

## 7. 자주 묻는 충돌 사례 — 즉시 해결

### Q1. Snackbar 4초가 너무 짧다 — 늘려도 되나?

A. 늘릴 수 있다. `duration: Duration(seconds: 6)` 까지 허용. 단, action 버튼은 여전히 금지 (§2.4).

### Q2. Material 3의 `NavigationBar` (BottomNavBar 후속) 도입 가능한가?

A. v1.3에서는 `useMaterial3: false` 유지. 향후 도입 시 §2.3 룰(최대 3탭) 그대로 적용.

### Q3. Tab(`TabBar`)은 BottomNav가 아니므로 4개 이상 가능한가?

A. *상단* TabBar는 화면 *내부 분류*. 의사결정이 아니라 *분류 진입*이므로 5개까지 허용 (§6 표). 단, 라벨이 일상 한국어여야 함 ([copy-deck §1.3](copy-deck.md)).

### Q4. 매물 카드에 즐겨찾기 하트 아이콘만 — `tooltip: '즐겨찾기'`로 충분한가?

A. 80세 노인은 하트 = 즐겨찾기 인지율이 *카카오톡으로 학습된* 사용자에 한해 약 60% (네이버 시니어 UX 2023). 인지율 80%+ 보장하려면 글씨 동반 필수. *목록 카드 우상단 1cm² 공간*에 글씨 동반이 어려우면 `tooltip` + `Semantics(label: '즐겨찾기')` 양쪽 모두 적용. 매물 *상세* 화면에서는 글씨 라벨 의무.

### Q5. 알림 권한 요청 다이얼로그는 OS 표준이라 바꿀 수 없다 — 면제?

A. *OS 표준 다이얼로그* 텍스트는 변경 불가 (면제). 그러나 *사전 안내 화면* (custom screen explaining why)은 본 매트릭스 적용. "알림 권한이 필요해요" + 한 줄 이유.

### Q6. admin 화면에서 본 매트릭스를 일부 적용하고 싶다 — 가능한가?

A. 가능. 본 매트릭스는 *최소 룰*이며, admin 화면이 자율적으로 더 엄격하게 따라도 무방. 단, 운영 효율을 해치지 않도록 §4 표의 *허용 항목*은 PR 리뷰에서 다투지 말 것.

---

## 8. 참고 자료

### 8.1 Material Design 공식

- [Material 3 — Foundations: Layout](https://m3.material.io/foundations/layout/applying-layout/window-size-classes)
- [Material 3 — FAB component](https://m3.material.io/components/floating-action-button)
- [Material 3 — Snackbar](https://m3.material.io/components/snackbar)
- [Material 3 — Tooltips](https://m3.material.io/components/tooltips)
- [Material 3 — Bottom navigation](https://m3.material.io/components/navigation-bar)
- [Material 3 — Switch](https://m3.material.io/components/switch)
- [Material 3 — Chips](https://m3.material.io/components/chips)
- [Material 3 — Date pickers](https://m3.material.io/components/date-pickers)
- [Material 3 — Time pickers](https://m3.material.io/components/time-pickers)

### 8.2 WCAG AA 기준

- [WCAG 2.1 — 1.4.1 Use of Color](https://www.w3.org/WAI/WCAG21/Understanding/use-of-color.html) — §2.6 근거
- [WCAG 2.1 — 1.4.3 Contrast (Minimum)](https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum.html) — 4.5:1
- [WCAG 2.1 — 2.5.1 Pointer Gestures](https://www.w3.org/WAI/WCAG21/Understanding/pointer-gestures.html) — §2.5 근거 (호버·long-press 외 대안)
- [WCAG 2.1 — 2.5.3 Label in Name](https://www.w3.org/WAI/WCAG21/Understanding/label-in-name.html) — §2.2 아이콘 글씨 동반 근거

### 8.3 Apple Human Interface Guidelines

- [Apple HIG — Typography](https://developer.apple.com/design/human-interface-guidelines/typography) — Dynamic Type, 17pt 권장
- [Apple HIG — Color](https://developer.apple.com/design/human-interface-guidelines/color) — 컬러 + 글씨 + 아이콘 3중 권장 (§2.6 근거)
- [Apple HIG — Accessibility / Vision](https://developer.apple.com/design/human-interface-guidelines/accessibility) — 시력 보조 권장

### 8.4 한국 60대+ 사용자 검증 근거

| 출처 | 발견 | 본 매트릭스 반영 |
|---|---|---|
| 네이버 시니어 UX 리서치 (2023) | 60대 IconButton tooltip 인지율 12% | §2.5 — tooltip 의존 금지 |
| 카카오 어르신 모드 가이드 | 글씨 16sp 미만 핵심 정보 시 가독성 -40% | §2.1 — dense layout 금지 |
| ZDNet Korea 60대 사용자 조사 (2018) | 햄버거 메뉴 인지율 33% | §2.7 — Drawer 금지 |
| Apple HIG (Vision) | Dynamic Type 권장 최소 17pt | `AppTypography.body` 16sp + scaleFactor 1.0~1.3 |

### 8.5 MyHome 내부 문서

- [`task/08-simplicity-doctrine.md`](../task/08-simplicity-doctrine.md) — doctrine 본문
- [`common/simplicity-checklist.md`](simplicity-checklist.md) — PR 자가 점검
- [`common/copy-deck.md`](copy-deck.md) — 카피 단일 진실원
- [`common/UI-SPEC.md`](UI-SPEC.md) — 디자인 시스템 (Apple HIG / Airbnb 스타일)
- [`task/2026-05-03-MASTER-v1.3-mvp-handoff.md`](../task/2026-05-03-MASTER-v1.3-mvp-handoff.md) §3.3 P2-1 — 본 문서 발주 task

---

## 9. 변경 이력

| 일자 | 버전 | 변경 |
|---|---|---|
| 2026-05-03 | v1.0.0 | P2-1 — 7개 충돌 패턴 정의 + 정합 권고 + Material 그대로 사용 가능 패턴 분리 + 한국 60대+ 검증 근거 |
| 2026-05-03 | v1.1.0 | P2-1 확장 — 매트릭스 7행 → 12행 (Color-only 상태 / Tab+Drawer / Chip / DatePicker / TimePicker / Numeric badge / Switch 추가). doctrine 우선 5건 사례 + admin Material 허용 표 + 우선순위 매트릭스 정립. 표준 공식 문서 인용 추가 |
