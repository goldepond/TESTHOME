# 다국어 지원 시 단순성 doctrine 재정립

> **상위 문서**: [`08-simplicity-doctrine.md`](../task/08-simplicity-doctrine.md) — *한국어 80세* nominal age 기준
> **카피 단일 진실원**: [`copy-deck.md`](copy-deck.md)
> **PR 자가 점검**: [`simplicity-checklist.md`](simplicity-checklist.md)
> **원천 문서**: [`MASTER v1.3 mvp handoff`](../task/2026-05-03-MASTER-v1.3-mvp-handoff.md) §3.3 P2-2 / [Task 08 handoff](../task/2026-05-03-task-08-simplicity-doctrine-handoff.md) §5.4 #33
> **버전**: v1.1.0 (P2-2, 2026-05-03)
> **적용 시점**: 영어/일본어/중국어 *최초 도입 PR* 부터 본 문서 강제. 한국어 단일 운영 시점에는 *백로그 참조*만 유지.
> **문서 성격**: **권고 가이드** — nominal age·알림 길이 한계는 *출시 직전 시장 데이터*로 재조정. 본 문서 수치는 *출발선*.

---

## 0. 결론 한 줄

> **80세 doctrine은 *한국어 80세* nominal age 기준이다. 다국어 도입 시 *각 언어권의 대상 사용자 nominal age + 단순성 기준*은 별도이며, 단순 번역만으로는 부족하다.**

기계 번역 + 폰트 교체로는 80세 doctrine을 보존할 수 없다. 본 문서는 *영어/일본어/중국어 도입 시 nominal age 재정립 룰 + 카피 시트 다국어화 절차 + 알림 길이 한계 + 운영 시점 전환 룰*을 정의한다.

---

## 1. 문제 — 왜 단순 번역으로 부족한가

현행 [`08-simplicity-doctrine.md`](../task/08-simplicity-doctrine.md) 는 **한국어 80세 nominal age** 한 점을 기준으로 모든 카피·흐름·알림 길이를 정의한다. 다국어 시장 확대 시 다음 세 변수가 동시에 흔들린다.

1. **각 문화권의 *대상 사용자* nominal age 가 다르다.** 한국 부동산 매도자 다수는 50~70대, 매수자 부모 세대(70~80대)가 의사결정에 동참한다. 영어권은 디지털 친화도 평균이 한국보다 높아 nominal age를 낮출 수 있으나, *비영어 모국어 사용자도 영어 UI 사용*하는 경우를 고려해야 한다. 일본은 고령자 디지털 사용률이 OECD 상위권이지만 한자·가타카나 외래어 회피 강도가 강하다. 중국 1·2선 도시 고령자는 위챗/알리페이 학습으로 신규 앱 진입장벽이 비교적 낮다.
2. **각 언어의 *단순성 기준 단어*가 다르다.** 한국어는 *한자 합성어*와 *영어 외래어*가 핵심 회피 대상이지만, 영어는 *라틴어·법률 약어*가, 일본어는 *한자 술어(熟語)*가, 중국어는 *고문체*·*영문 약어*가 회피 대상이다.
3. **각 언어의 *알림·문장 길이 한계*가 다르다.** 글자당 정보 밀도가 달라, 한국어 30자를 직역하면 영어 60자 / 일본어 35자 / 중국어 25자 근방으로 흩어진다.

이 세 변수를 함께 고려하지 않고 한국어 카피만 직역하면 **"기술적으론 다국어 지원되지만 nominal-age doctrine이 무너진 다국어"** 가 된다. 본 가이드는 그 붕괴를 막기 위한 *출발선*이다.

---

## 2. 언어별 nominal age 재정립 권고

> 모든 수치는 **출시 직전 시장 데이터**(통계청·각국 인구 디지털 사용률·실제 매도자 인터뷰)로 재조정된다. 본 표는 *기획·설계 단계의 출발선*이며, **시장 진입 결정과 함께 본 표를 갱신**한다.

| 언어 | 권고 nominal age | 근거 (출발선) | 재조정 트리거 |
|---|---|---|---|
| **한국어 (ko-KR)** | **80세** *(현행 유지)* | 한국 매도자 50~70대 + 매수자 부모 80대 의사결정 동참. 80세 통과 시 모든 연령대 통과. | 변경 없음. v1.0 ~ v1.x 유지. |
| **영어 (en)** | **70세** | 영어권 부동산 의사결정자 60~70대 중심, 디지털 적응도 한국 평균보다 높음. **단** *비영어 모국어 사용자도 영어 UI 사용* 케이스 존재 — 영어가 *제2 언어*인 사용자 비중 30% 이상 시장은 +5세 가산. | (1) SF Bay Area / Toronto 등 비영어 모국어 사용자 비중 높은 시장 → 75세 상향. (2) 베트남·필리핀 등 영어 제2 공식어 시장 → 별도 평가. |
| **일본어 (ja-JP)** | **75세** | 일본 고령자 디지털 사용률 OECD 상위권. 단 *한자·가타카나 외래어 회피 강도*가 한국보다 강함 — 어휘 부담은 더 크지만 사용자 친숙도는 더 높음. 균형점 75세. | 도쿄·오사카 외 지방 도시 진입 시 78~80세 상향 검토. |
| **중국어 간체 (zh-CN)** | **70세** | 1·2선 도시 고령자 위챗/알리페이 적응 매우 빠름. 위챗 친화 UI를 학습한 60~70대가 신규 앱 진입 장벽 낮음. 단 3·4선 도시는 별도. | 3·4선 도시 진입 시 75세 상향. *번체(臺灣·香港)* 진입 시 별도 가이드 필요. |

### 2.1 nominal age 결정 책임

본 표는 **권고**다. 출시 직전 *제품 책임자 + 현지 운영자 + 사용성 연구자* 가 다음 데이터로 재조정한다:
- 해당 시장의 부동산 매도자 평균 연령 (정부 통계)
- 60세 이상 모바일 앱 일일 사용 시간 (디지털 격차 보고서)
- 사전 사용성 인터뷰 5명 이상의 실제 어휘 이해도

### 2.2 nominal age는 *최저값* 기준

- 시장별 nominal age는 **모든 화면 카피·UI 패턴이 통과해야 하는 하한선**.
- "이 화면은 50대까지만 쓰겠지" 같은 *세그먼트별 면제*는 금지. 한 사용자가 여러 화면을 횡단하기 때문.
- *예외*: 운영자 화면(admin) — *직무 전문 사용자* 가정 (§5).

### 2.3 *경계* — 사용자 폄하 금지

- ❌ "영어니까 더 똑똑해서 80세 → 70세 낮춤" 식의 단순화는 금지. 사용자 폄하 0.
- ❌ 특정 국가/언어 사용자의 디지털 이해도를 일반화·평가절하해 표기하지 않는다.
- ✅ 본 표는 *부동산 의사결정자 평균 연령 + 디지털 친숙도 평균*의 합산 권고일 뿐, 개인 능력 비교가 아니다.
- ✅ 모든 nominal age 결정은 *해당 시장 진입 결정과 함께* 문서화 후 본 표 갱신.

### 2.4 nominal age 변경 절차

| 변경 사유 | 절차 |
|---|---|
| 시장 신규 진입 (예: 베트남 추가) | 본 §2 표에 1행 추가 → 시장 시니어 UX 자료 1차 출처 ≥ 2건 첨부 → 도입 PR 본문에 nominal age 명시 |
| 기존 시장 nominal age 조정 | 시니어 UX 자료 변경 인용 + 영향 받는 카피 재검토 PR (전수 통과 필수) |
| 운영자 화면 다국어화 | nominal age 적용 *제외*. 단 `lib/screens/admin/*` 외부 노출 (감사 자료) 시 §3 카피 시트로 별도 번역 |

---

## 3. 카피 시트 다국어화 절차

### 3.1 옵션 비교 — A안(분리 파일) vs B안(언어 컬럼)

[`copy-deck.md`](copy-deck.md) 는 현재 한국어 단일 진실원이다. 다국어 도입 시 두 옵션:

| 옵션 | 구조 | 장점 | 단점 |
|---|---|---|---|
| **A안 *(권고)*** | `copy-deck.md` (ko 원본) → `copy-deck.en.md` / `copy-deck.ja.md` / `copy-deck.zh-CN.md` 분리 | 언어별 *문화·법률 차이* 주석 가능. 다국어 카피 작성자가 자기 언어 파일만 보면 됨. | 동기 부담 — 한국어 변경 시 N개 파일 동시 갱신. PR 룰로 강제. |
| B안 | `copy-deck.md` 안에 *언어 컬럼 추가*: `상수명 \| 한국어 \| English \| 日本語 \| 中文` | 한 파일에서 동기 보장. 한국어 변경 시 빈 셀 즉시 가시. | 표가 매우 넓어짐(가로 스크롤). 언어별 *주석·문화 노트* 작성 공간 부족. |

**→ 권고: A안.** 사유:
1. 다국어 카피는 단순 번역이 아니라 *문화별 어휘 회피 정책 + nominal age 별 단순화*가 다르다. 언어별 별도 파일에서 그 노트를 풍부하게 작성할 수 있다.
2. B안의 "한 파일에서 동기 보장" 장점은 PR 체크리스트로 대체 가능하다.

### 3.2 A안 — 파일 구조

```
docs/common/
├── copy-deck.md           # 한국어 원본 (단일 진실원)
├── copy-deck.en.md        # 영어 (nominal age 70 기준)
├── copy-deck.ja.md        # 일본어 (nominal age 75 기준)
├── copy-deck.zh-CN.md     # 중국어 간체 (nominal age 70 기준)
└── simplicity-i18n.md     # 본 가이드
```

각 언어 파일 헤더에 다음 메타 명시:

```markdown
# Copy Deck (English) — Simplicity for nominal age 70

> **Source of Truth (Korean)**: [copy-deck.md](./copy-deck.md)
> **Nominal Age**: 70 (per [simplicity-i18n.md §2](./simplicity-i18n.md))
> **Sync Policy**: Korean source changes trigger sync PR within 7 days.
```

### 3.3 A안 — PR 동기화 룰 (강제)

`copy-deck.md` 한국어 원본 변경 시 PR 본문에 다음 첨부:

```
[ ] copy-deck.md (ko) 갱신 — 변경 라인 N
[ ] copy-deck.en.md 갱신 또는 *Pending Translation* 라벨 + GitHub Issue (label: i18n-pending)
[ ] copy-deck.ja.md 갱신 또는 *Pending Translation* 라벨 + GitHub Issue
[ ] copy-deck.zh-CN.md 갱신 또는 *Pending Translation* 라벨 + GitHub Issue
```

번역 미반영 상태로도 머지는 가능하나, *해당 언어 빌드는 한국어 폴백* 처리하고 GitHub Issue 로 추적한다.

### 3.4 한국어 → 타 언어 번역 룰 (8개)

번역가에게 *번역 의뢰서*에 본 8개 룰을 첨부한다. 기계 번역 + 검수 만으로는 부족하다.

| # | 룰 | 사유 |
|---|---|---|
| 1 | **금지 단어 시장별 사전 대체**: [copy-deck §1.1](copy-deck.md) 한국어 금지어 → 시장 nominal age에 *맞는* 일상 단어로 *재선정*. 한국어 대체어를 그대로 번역하지 *말 것* | 일본어 "私の順番"은 자연스럽지만 영어 "My turn"은 게임 어휘 — "I have this listing now" 같은 *행동 기반* 표현 권장 |
| 2 | **알림 글자 수 한계** — 시장별 재정의: 한국어 ≤30자 / 영어 ≤60자 / 일본어 ≤35자 / 중국어 ≤25자 (§6) | 언어별 정보 밀도 차이 |
| 3 | **3탭 이내** → 모든 시장 동일 | 인지부담은 언어 무관 |
| 4 | **백분율·점수·코드 노출 0** → 모든 시장 동일 | 본 doctrine 핵심 |
| 5 | **사유 코드 한 줄 변환** ([copy-deck §3](copy-deck.md))은 *언어별로 별도 결정*. 한국어 "받기 어려워요" → 영어 "Cannot accept" 보다 "We can't connect this listing yet" 권장 | 영어권 60대+는 *수동태 부드러운* 표현 학습 |
| 6 | **"우선권" 단어 정책** ([copy-deck §5](copy-deck.md)) → 시장별 등가어 사전 정의. 영어 "priority right" / 일본어 "優先権" / 중국어 "优先权" — 모두 *법무 사실 통지* 라인이므로 *법률 등가어* 필요 | 매도자 audit timeline 사실 통지 |
| 7 | **통일 라벨**: [copy-deck §1.3](copy-deck.md) 표 — 시장별 1:1 대응. *같은 동작에 다른 단어 0* 룰 그대로 | "Take this listing" 외 다른 표현 0 |
| 8 | **에러 메시지 = 원인 + 해결법** → 모든 시장 동일 | 사용자 행동 가이드라인 |

### 3.5 검수 단계

1. **1차 번역**: 전문 번역가 (시니어 UX 경험 1건+ 필수).
2. **2차 검수**: 시장 *60세 이상 비전문가 3명* 시연 (한국 doctrine [`simplicity-checklist §5`](simplicity-checklist.md) 동일 룰).
3. **3차 검수**: 80세 가상 인터뷰 6질문 ([`simplicity-checklist §1`](simplicity-checklist.md)) — 시장 nominal age로 치환 후 답변 작성.
4. **PR 본문**: 번역본 + 시연 영상 + 6답변 첨부 후 머지.

### 3.6 자동 검출 — 다국어 동기 검증

P1-2 (`tools/audit_copy_deck.dart`) 의 다국어 확장 (제안 — 실제 구현은 후속 phase):

```dart
// tools/audit_copy_deck_i18n.dart (제안)
// 1. copy-deck.{locale}.md 의 영역별 표 N행 ↔ grant_messages.{locale}.dart 상수 N개 1:1 일치
// 2. reasonCopy 키 셋 모든 locale 일치 (한 locale에만 있는 키 0)
// 3. auditEventLabel 키 셋 모든 locale 일치
// 4. 누락 시 `[locale] missing key: <name>` 출력 후 exit 1
```

---

## 4. `GrantMessages` 다국어화 — Flutter 구현 권고

현행 `lib/constants/grant_messages.dart` 는 *한국어 상수*만 보유한다. 다국어화 시:

### 4.1 패키지 — `flutter_localizations` + `intl`

Flutter 표준 ARB(Application Resource Bundle) 파일 기반.

```yaml
# pubspec.yaml
dependencies:
  flutter_localizations:
    sdk: flutter
  intl: ^0.19.0
flutter:
  generate: true
```

### 4.2 ARB 파일 구조 (권고)

```
lib/l10n/
├── app_ko.arb     # 한국어 (원본)
├── app_en.arb     # 영어
├── app_ja.arb     # 일본어
└── app_zh.arb     # 중국어 간체
```

`app_ko.arb` 예시:

```json
{
  "@@locale": "ko",
  "actionTakeProperty": "이 매물 받기",
  "@actionTakeProperty": {
    "description": "Broker action button to take ownership of a listing"
  },
  "issuedSuccess": "받았어요. 14일 동안 내 차례입니다",
  "@issuedSuccess": {
    "description": "SnackBar after broker successfully takes a property",
    "context": "Length limit: ko 30, en 60, ja 35, zh 25 chars (per simplicity-i18n.md §6)"
  }
}
```

### 4.3 키 명명 룰 — `GrantMessages` 식별자 그대로

- **카피 시트 [§2](copy-deck.md) 표의 `상수명` 컬럼 = ARB 키.**
- 코드 마이그레이션 시 검색·치환 부담 최소화.
- 예: `actionTakeProperty`, `issuedSuccess`, `tierProgressT1` 등 그대로.

### 4.4 마이그레이션 절차 (단계적)

1. **Phase A — 추출**: 모든 `GrantMessages.xxxx` 호출을 `AppLocalizations.of(context).xxxx` 로 교체. 한국어 ARB 만 우선 생성. 동작 동일.
2. **Phase B — 번역 시드**: 영어 ARB 생성 → 1차 번역 → *언어별 nominal age 가이드(§2)에 따라 어휘 검수* → 5명 시연.
3. **Phase C — 일본어/중국어 추가**: 시장 진입 결정 시점에 추가.

### 4.5 사유 코드(reasonCopy) / audit eventLabel 다국어화

`functions/index.js` 의 `REASON` 상수는 백엔드에서 *코드만* 반환. 한국어 변환은 클라이언트 `reasonCopy` 가 담당. 다국어 시:

- 백엔드는 **변경 없이 코드만** 반환.
- 클라이언트 `reasonCopy` 를 ARB 기반으로 전환 — 사유 코드 26종을 모두 ARB 키로 등록.
- audit `eventType` 라벨 17종도 동일 처리.

이 구조는 백엔드 다국어 분기 부담 0을 유지한다.

### 4.6 `GrantMessages` legacy 호환

- 마이그레이션 *Phase A* 진행 중에는 `GrantMessages.xxxx` 와 `AppLocalizations.of(context).xxxx` 가 공존.
- 새 카피 추가는 ARB 만 사용. `GrantMessages` 에는 추가 *금지*.
- 모든 호출이 ARB 로 전환 완료되면 `GrantMessages` 파일 삭제.

---

## 5. 언어별 회피 단어 차트

| 카테고리 | 한국어 회피 | 영어 회피 | 일본어 회피 | 중국어(간체) 회피 |
|---|---|---|---|---|
| **법률 용어** | 우선권, 권리, 자격, 유효기간, 만료 | priority right, eligibility, expiration, void, hereby | 優先権, 失効, 有効期限 | 优先权, 失效, 期限 |
| **기술 용어** | 매칭, 인콰이어리, 인플레이트, score, tier | matching, inquiry, score, tier, throttle | マッチング, スコア, インカムリ | 匹配, 评分, 层级 |
| **외래어/약어** | grant, exclusive, listing, broker | (라틴어 약어) etc., e.g., i.e., re: ; (약어) FYI, ASAP | 가타카나 외래어 (リスティング, ブローカー) | 英文缩写 (FAQ, FYI) |
| **합성어/한자술어** | 한자 합성어 | (해당 없음) | 한자 술어 (登録抹消, 不動産仲介業者) | 古文체 (兹, 系, 之 등) |
| **법률 약어** | 부동산공인중개사법 §X | "§", "et seq.", "Sec." | 宅地建物取引業法 §X | 房地产经纪管理办法 §X |
| **숫자 추상화** | 백분율(%), 점수, D-12 | percentages, scores, "D-12" | パーセント, スコア, D-12 | 百分比, 评分, D-12 |
| **대체 권장** | 일상 한국어, 순우리말, 풀어쓰기 | plain English, Anglo-Saxon roots | 平仮名, 和語 | 白话文, 现代汉语 |

### 5.1 언어별 *추가* 룰

#### 영어 (nominal age 70)
- *Anglo-Saxon roots over Latin/Greek*: "use" 〉 "utilize", "help" 〉 "assist", "end" 〉 "terminate"
- *Active voice 강제*: "Your turn ended" 〉 "The priority has been revoked"
- *축약 금지*: "you are" (○) ~~"you're"~~ — 비영어 모국어 사용자 가독성

#### 일본어 (nominal age 75)
- *和語 우선, 漢語 차순, 가타카나 최후*
- 평이한 動詞: "受け取る" (○) / "取得する" (△, 한자술어)
- 외래어 가타카나 회피 강도 한국보다 *더 높음* — 일본 고령자는 가타카나 외래어를 한국 고령자보다 더 어려워하는 경향
- 경어(敬語)는 *です・ます* 정중체 통일. 尊敬語·謙譲語 혼용 금지

#### 중국어 (nominal age 70, 간체)
- *白话文 (현대 구어체) 우선*. 古文체 회피.
- 동사 1자 우선: "拿" 〉 "获取", "给" 〉 "授予"
- 영문 약어 한자 풀이 또는 회피: "FAQ" → "常见问题"
- 번체(臺灣·香港) 진입 시 별도 가이드 필수 — 어휘 차이 큼 (例: 软件/軟體, 中介/仲介)

---

## 6. 언어별 알림 길이 한계 (출발선)

| 언어 | 권고 한계 | 근거 (출발선) |
|---|---|---|
| **한국어** | **30자** | 현행 [`08-simplicity-doctrine.md §3.3`](../task/08-simplicity-doctrine.md). 한 줄 + 3초 안에 의미 이해 가능. |
| **영어** | **60자** | 영어는 한 글자당 정보 밀도가 한국어 대비 약 1/2. iOS 푸시 알림 본문 1줄 표시 한계(약 50~65자) 참조. |
| **일본어** | **35자** | 한 글자당 정보 밀도 한국어와 유사하나 한자가 정보를 압축 + 가타카나·히라가나 혼합으로 가독 부담 → 한국어보다 약간 느슨. |
| **중국어 (간체)** | **25자** | 한자 정보 밀도가 가장 높음. 25자에 한국어 30자, 영어 60자에 해당하는 정보 담을 수 있음. |

### 6.1 참고 출처 (지시값으로 사용 금지 — 출시 전 직접 측정)

- iOS Push Notification UI 가이드 (Apple HIG, lock screen body line break point)
- Android `Notification.Builder.setContentText` 사실상 길이 (대부분 단말 1~2줄)
- 한국어 30자: `08-simplicity-doctrine.md` 자체 검증
- 영어 60자: 트위터/X 초기 140자 시절 헤드라인 미디어 가이드 (단축 헤드라인 평균)
- 일본어 35자: 야후재팬·라쿠텐 푸시 알림 평균 (관찰 기반, 출처 명시 필요)
- 중국어 25자: 위챗 공식 푸시 가이드 라인 (관찰 기반, 출처 명시 필요)

### 6.2 검증 절차 (각 언어 진입 시)

- 실제 단말(iOS / Android 각 1대씩) 잠금 화면에서 푸시 표시.
- 1줄에 들어가는지 확인. 줄바꿈 발생 시 **±5자 조정**.
- 본 표 갱신 후 PR 본문에 *측정 캡처* 첨부.

---

## 7. 운영 시점 전환 룰

### 7.1 도입 트리거 (다국어 시작 조건)

**한 가지라도 충족 시** PRD에서 다국어 P1 우선순위 승격:

- [ ] 활성 사용자 중 *비한국어* 추정치 > 5%
- [ ] 한국 외 시장 진출 의사결정 (사업)
- [ ] 외국인 매수자 임장 신청 비율 > 3%
- [ ] 앱스토어 리뷰에 영어/중국어 negative feedback ≥ 3건

### 7.2 단계별 도입 (1년 plan)

| 단계 | 시점 | 작업 |
|---|---|---|
| **0. 기반** | T-12주 | `flutter_localizations` 통합 + `app_localizations.dart` wrapper + `MaterialApp.router` locale switch + 사용자 설정에 언어 선택 |
| **1. 영어 (en)** | T-9주 | `copy-deck.en.md` 번역 + ARB `app_en.arb` + 60세+ 시연 (US·UK·SG 각 1명) |
| **2. 일본어 (ja-JP)** | T-6주 | 영어와 동일 절차. 도쿄·오사카 분리 시연 권장 |
| **3. 중국어 (zh-CN)** | T-3주 | 도시 *3명* 농촌 *2명* — 디지털 격차 검증 |
| **4. 안정화** | T+0~4주 | 시장별 60세+ 시니어 UX 정량 측정 (성공률·도달 시간) |

### 7.3 하이브리드 운영 시 기본 언어

- **출시 진입 전 결정.** 진입 후 추가는 카피 누적 부채를 키운다.
- *기본 한국어로 시작.* 한국 시장이 v1.x MVP 의 *유일한* 출시 시장.
- 영어 시범 도입 시 **앱 설정에서 언어 선택**. 시스템 로케일 기준 자동 분기 *지양* (사용자 의도 우선).
- 비로그인 공개 페이지(`/listings`, `/property/:id`)도 동일 — *기본 한국어*, 사용자 명시 선택만 영어로 전환.

### 7.4 운영 중 카피 변경 (한국어 변경 → 다른 시장 동기)

| 시나리오 | 절차 |
|---|---|
| 한국어 카피 1줄 변경 (오타·표현) | `copy-deck.md` 갱신 → 다른 locale 모든 `copy-deck.{locale}.md` 동시 변경 PR. *지연 머지 금지* (1주 SLA). |
| 한국어 신규 카피 (신규 기능) | locale 별 placeholder `[TODO: en]` 허용 (단 화면 노출 시 한국어 폴백 명시). 1주 내 정식 번역 PR. |
| reasonCopy / auditEventLabel 신규 | 한국어 커밋과 *동일 PR* 에 모든 locale 추가. 한 locale 누락 시 PR 거절. |

### 7.5 RULEBOOK 다국어화

[`PRIORITY_RULEBOOK.md`](../public/PRIORITY_RULEBOOK.md) 는 `PRIORITY_RULEBOOK.{locale}.md` 분기. 단 *법무 효력*은 한국어 원본만 보장 — 타 locale은 *참고 번역* 명시:

```markdown
# Priority Rulebook (en, reference translation)
> Original (legally binding): [PRIORITY_RULEBOOK.md](PRIORITY_RULEBOOK.md) (Korean).
> This English version is a reference only. In case of discrepancy, Korean prevails.
```

### 7.6 언어 fallback 룰

- 사용자 선택 언어 ARB 키 누락 → 한국어 ARB 폴백 → 그래도 없으면 키 자체 노출 (개발 모드 한정).
- 운영 모드는 ARB CI 검증으로 키 누락 0 강제.

---

## 8. 실사용 검증 — 다국어 권고 (P0-7 다국어 확장)

[`08-simplicity-doctrine.md §5.3`](../task/08-simplicity-doctrine.md) 에서 한국어 **60대 이상 비전문가 3명** 시연 절차를 정의한다. 이를 다국어로 확장:

### 8.1 언어별 시연 대상 — 각 언어 nominal age ±5세 비전문가 3명

| 언어 | 시연 대상 연령대 | 인원 | 모집 방법 (예시) |
|---|---|---|---|
| 한국어 | 75~85세 (nominal 80 ±5) | 3명 | 동네 부동산 / 가족 / 노인복지관 |
| 영어 | 65~75세 (nominal 70 ±5) | 3명 | 현지 시니어 센터, AARP 네트워크 |
| 일본어 | 70~80세 (nominal 75 ±5) | 3명 | 현지 シルバー人材センター |
| 중국어 | 65~75세 (nominal 70 ±5) | 3명 | 1·2선 도시 老年大学 또는 지역 위챗 그룹 |

### 8.2 측정 항목 (모든 언어 공통, [`08-simplicity-doctrine.md §5.3`](../task/08-simplicity-doctrine.md) 동일)

- 매물 등록 성공률 > 90%
- 임장 신청 성공률 > 90%
- 첫 진입 후 핵심 화면 도달 시간 < 60초
- 사용 후 "다시 쓰겠다" 응답 ≥ 2/3

미달 시 단순화 추가 작업 후 재시험.

### 8.3 다국어 추가 측정 항목

- *어휘 회피 차트(§5)* 위반 횟수 — 한 언어당 0건 목표
- *알림 길이 한계(§6)* 초과 알림 0건 목표
- 시연 중 사용자가 *문의한 단어* 수집 → 본 §5 "회피 단어" 차트 갱신 데이터로 활용

---

## 9. 한국 doctrine과 다른 시장 doctrine 통합 룰

### 9.1 *최강 룰* 채택 — 충돌 시 가장 엄격한 룰

| 충돌 사례 | 한국 (80세) | 미국 (70세) | 통합 적용 |
|---|---|---|---|
| 알림 글자 수 | ≤30자 | ≤60자 | 시장별 그대로 (한국 30 / 영어 60 / 일본어 35 / 중국어 25) |
| 한 화면 결정 수 | ≤2 | ≤3 (Pew 2024 권장) | 모든 시장 ≤2 (한국 룰 채택) |
| 백분율 노출 | 0건 | 일부 허용 (Trulia 등) | 모든 시장 0건 (한국 룰 채택) |

### 9.2 시장별 분리 룰 — 통합하지 않는다

- 폰트 (Noto Sans KR / Noto Sans / Noto Sans JP / Noto Sans SC).
- 통화 표기 (₩ / $ / ¥ / 元) — 사용자 locale 자동 매핑.
- 날짜 형식 (YYYY-MM-DD / MM/DD/YYYY / YYYY年MM月DD日 / YYYY-MM-DD).
- 주소 입력 — 시장별 외부 API 연동 (juso.go.kr / Google Maps Places / 日本郵便番号 등).

---

## 10. 운영자 화면 — 다국어 별도 룰

[`copy-deck.md §6`](copy-deck.md) 와 동일하게 운영자 화면(`lib/screens/admin/*`) 은 nominal age 적용 *제외*. 단 다국어 도입 시:

- 운영자 화면도 시장 진입 시 *해당 시장 운영자가 사용*하므로 번역 필요.
- 그러나 nominal age는 *해당 시장 직무 전문 사용자* (40~50대 부동산 admin 가정).
- 따라서 운영자 화면 카피는 *기술 용어 그대로* 번역. "matching score" → "Matching Score" / "マッチングスコア" / "匹配分数" 모두 허용.

---

## 11. 다국어 도입 시 PR 자가 점검 (i18n 추가 항목)

기존 [`simplicity-checklist.md §2`](simplicity-checklist.md) 에 *i18n 4항목* 추가:

```markdown
### i18n (4건, 다국어 도입 시점부터)
- [ ] copy-deck.{locale}.md 모든 신규/변경 카피 등록
- [ ] ARB 파일(app_{locale}.arb) 동시 갱신 (한 locale 누락 0)
- [ ] reasonCopy / auditEventLabel 모든 locale 키 셋 일치
- [ ] 알림 글자 수 시장별 한도 통과 (영어 ≤60자 / 일본어 ≤35자 / 중국어 ≤25자)
```

---

## 12. 한국어 단일 운영 시점 — 본 문서의 위치

본 문서는 **다국어 도입 시 활성화**. 한국어 단일 운영(2026-05-03 현재) 시점에는:

- 본 문서는 *백로그 참조*. **코드·설정 변경 0**.
- 한국 doctrine ([`08-simplicity-doctrine.md`](../task/08-simplicity-doctrine.md)) 그대로 적용.
- 다국어 도입 트리거(§7.1) 충족 시 본 문서 **§7.2 단계별 도입 절차** 시작.

---

## 13. 미해결 의문점 (출시 전 결정 필요)

1. **번체 중국어(臺灣·香港) 별도 처리 여부** — 현재 본 가이드는 간체 기준만. 번체 도입 결정 시 별도 sub-doc 신설.
2. **영어 *비모국어* 사용자 가산점 +5세 정량 근거** — 본 §2 권고는 *경험적*. 실제 사용성 데이터로 검증 필요.
3. **위챗 푸시 25자 / 야후재팬 35자 출처** — §6.1 참고 출처 중 일본어 35자 / 중국어 25자는 관찰 기반. 출시 전 공식 가이드 인용으로 보강.
4. **일본어 경어 정중체 통일 vs 부분 尊敬語 혼용 — 사용자 친화도 비교 필요** (예: 매도자 알림은 尊敬語 적정?).
5. **다국어 카피 시트 자동 동기 도구** — A안(분리 파일) 채택 시 한국어 변경 → 다국어 미반영 자동 검출 CI 도구 필요. (예: `copy-deck-sync-checker`)
6. **백엔드 사유 코드 다국어화 책임 경계** — 클라이언트가 모든 언어 변환을 담당하는 것이 맞는가? 추후 운영자(admin) 화면 다국어화 시 백엔드도 일부 다국어 라벨 보유해야 할 수 있다.

---

## 14. 변경 이력

| 일자 | 버전 | 변경 |
|---|---|---|
| 2026-05-03 | v1.0.0 | P2-2 초안 — 시장별 nominal age 5건 + 카피 시트 다국어화 8룰 + 운영 시점 전환 절차 + 운영자 화면 별도 룰. |
| 2026-05-03 | v1.1.0 | nominal age 권고 재정립 (영어 70 / 일본어 75 / 중국어 70). 알림 길이 한계 4종(30/60/35/25) + ARB 기반 GrantMessages 마이그레이션 절차 + 언어별 회피 단어 차트 + 실사용 검증 다국어 확장 추가. 본 수치는 *출발선*이며 출시 직전 시장 데이터로 재조정 명시. |
