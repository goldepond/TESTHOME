# Admin 화면 외부 노출 시 부연 설명 가이드

> **작성**: 2026-05-03 / 총괄 책임자 직접 작성 (sub-agent 사용량 한계 후 인계)
> **상위 문서**: [copy-deck.md §6](copy-deck.md) (운영자 별도 룰), [Task 08 §5.1 #2](../task/2026-05-03-task-08-simplicity-doctrine-handoff.md) (admin 외부 감사 자료 risk)
> **유지 책임**: 외부(공정위·법무) 자료 제출 시 본 가이드 §3 부연 설명을 *반드시* 함께 첨부

---

## 0. 한 줄 요약

admin 화면(`lib/screens/admin/*`)은 80세 doctrine 면제로 "매칭"·"점수"·"가중치" 기술 용어 그대로 사용. 단 외부 감사·법무 분쟁 시 *캡처가 외부에 노출*되면 §33①9호 *MyHome 의지 개입* 신호 또는 카카오 *고정 우대 패턴* 신호로 오인될 수 있다. 본 가이드는 admin 캡처 첨부 시 함께 제출할 *부연 설명 카피 템플릿* + *5단계 법무 대응 절차*를 정립.

---

## 1. 배경

### 1.1 admin 화면이 doctrine 면제인 이유
[copy-deck.md §6](copy-deck.md) 정립:
- 운영자(admin)는 *직무 전문 사용자* — 80세 일반 사용자 아님
- "매칭"·"점수"·"가중치" 같은 용어는 운영자 직무에 *직접 필요*
- 운영자 화면을 노인 화법으로 강제하면 *직무 효율 저하*

### 1.2 외부 노출 시 risk
admin 화면 캡처가 *MyHome 외부*로 나갈 수 있는 케이스:
- 공정거래위원회 자료 요구 (§33②4호 시세 부당 영향 의심)
- §33①9호 단체결성 공동중개 제한 분쟁 (broker 진정)
- 법원·중재기관 증거 자료
- 언론·블로그 노출 (캡처 유출)

이때 admin 카피만 보면 다음 *오해* 가능:
- "매칭" → MyHome이 *broker-buyer 매칭에 적극 개입*했다는 인상
- "점수" → MyHome이 *broker별 고정 우대 패턴* 형성했다는 인상
- "가중치" → 카카오모빌리티 *알고리즘 우대* 패턴 동일

본 가이드는 *오해를 사전에 차단할 부연 설명*을 정립.

---

## 2. 위험 시나리오 3건

### 2.1 시나리오 A — 공정위 자료 요구 (§33②4호)
**상황**: 공정거래위원회가 MyHome에 *시세 부당 영향* 의심하여 자료 요구. admin "매칭" 화면 캡처 첨부.

**오해 risk**: "MyHome이 broker-buyer 매칭을 *알고리즘으로 강제 결정*했다" → §33②4호 위반 신호.

**대응**: §3.1 부연 설명 + audit log 첨부로 *Dynamic Matching 6변수 자동 산정*임을 증명.

### 2.2 시나리오 B — §33①9호 broker 진정
**상황**: broker가 *MyHome이 단체결성 공동중개 제한*에 개입했다고 진정. admin "매칭 관리" 화면 캡처.

**오해 risk**: "MyHome이 *특정 broker*를 매칭에서 *배제*하거나 *우대*했다" → §33①9호 단체결성 신호.

**대응**: §3.1 부연 설명 + Task 07 *exclusive 모드는 매도자 자율 지정*임을 명시 + audit log로 매도자 자발성 증명.

### 2.3 시나리오 C — 카카오 패턴 의심 (운영 점유율 30%+ 도달 시)
**상황**: 점유율 30% 도달 + admin "broker 활동 점수" 화면 노출 → 카카오모빌리티 *알고리즘 우대* 패턴 의심.

**오해 risk**: "broker별 점수가 *고정 우대 패턴*을 형성한다" → 카카오 257억 과징금 패턴.

**대응**: §3.1 부연 설명 + `algorithm_config/active` 외부화 증명 + computeDailyMetricsScheduled 점유율 모니터링 자체 구현 증명.

---

## 3. 부연 설명 카피 템플릿

### 3.1 admin 화면 단어 → 외부 노출 시 부연 설명 매핑

| admin 단어 | 외부 노출 시 첨부 설명 |
|---|---|
| **매칭** | "broker-buyer 자율 연결 기록. MyHome이 결정한 매칭 0건 — 매수자가 [BrokerPickerDialog](../../lib/widgets/broker_picker_dialog.dart)에서 직접 선택하거나 broker가 [이 매물 받기](../../lib/screens/broker/_widgets/broker_property_card.dart)로 자발 등록. 시간 우선 + Dynamic Matching 6변수(jurisdictionMatch / activityScore / distance / 등) 자동 산정. 가중치는 [`algorithm_config/active`](../../firestore.rules) Firestore 외부화 — 운영팀이 코드 배포 없이 변경 가능 + 모든 변경 [`priority_audit_logs`](../../firestore.rules)에 기록." |
| **점수** | "broker 활동 누적 데이터 — *사용자 노출 0건* (copy-deck §3.4). admin은 운영 모니터링용으로만 점수 노출. broker 본인에게도 *카테고리* (상위 30%/중간/하위 30%)만 노출, 절대값 점수 X. 점수 변동 룰은 [PRIORITY_RULEBOOK.md](../public/PRIORITY_RULEBOOK.md) 공개." |
| **가중치** | "Dynamic Matching 6변수 가중치. [`algorithm_config/active`](../../firestore.rules) 컬렉션에 *외부화*. 변경 시 `replayDecision` callable로 과거 결정 재현 가능. 코드 상수에 박혀있지 않음 → 카카오 패턴 회피의 핵심." |
| **활동률 / 80%** | "[copy-deck §2 §3](copy-deck.md) 정립된 *Use-it-or-Lose-it* 룰. 우선권 부여 후 7일 내 80% 활동 미달 시 자동 만료. broker 본인 화면에는 '남은 일: ○○ 1건' 행위 단위 표시 (copy-deck §3.4)." |
| **이상해요 / 이의 제기** | "[priority_appeals](../../firestore.rules) 컬렉션. 매도자·broker가 우선권 결정에 이의 제기 시 자동 [`replayDecision`](../../functions/index.js) → admin resolve → 통보 풀 사이클. 모든 결정의 *재현 가능성* 보장." |
| **점유율 / alertLevel** | "MyHome 자체 카카오 패턴 회피 텔레메트리. 시군구별 등록 매물 수 / 추정 거래량 비교. 30% yellow / 40% red 도달 시 *외부 감사 자체 트리거*. 운영팀 자율 모니터링." |
| **Tier (1km / 동 / 인접동 / 광역)** | "[Task 04 tiered release](../task/04-tiered-release.md) — 신규 매물 1km broker 우선 → 24h 후 같은 동 → 인접동 → 광역 점진 노출. 봇 광역 선점 차단. 단계 진척 중 활성 우선권 보유자 있으면 정지 → 우선권 보유자 보호." |

### 3.2 외부 자료 제출 시 1세트 동봉

admin 캡처 N장 첨부 시, 다음 *4종 동봉*:

1. **본 가이드 §3.1 표** — 단어 → 부연 매핑
2. **[PRIORITY_RULEBOOK.md](../public/PRIORITY_RULEBOOK.md)** — 비로그인 공개 룰북 (사용자 화면용 80세 화법)
3. **[copy-deck.md §5](copy-deck.md)** — "우선권" 단어 정책 (사용자/admin 분리 정립)
4. **audit log 발췌** — 시점별 결정 입력·결과 (Dynamic Matching 6변수 증명)

---

## 4. 5단계 법무 분쟁 대응 절차

### Step 1. admin 캡처 + 부연 설명 표 첨부
§3.1 표를 그대로 첨부. *MyHome 의지 개입 0* 인상 강조.

### Step 2. audit log 시점별 기록
[`priority_audit_logs`](../../firestore.rules)에서 분쟁 grant ID 또는 시점 기준 모든 이벤트 export. 입력 변수 + 결정 결과 *함께*. *재현 가능성* 증명.

### Step 3. Dynamic Matching 외부화 증명
- [`algorithm_config/active`](../../firestore.rules) 컬렉션 캡처 — 코드 외부 저장
- 가중치 변경 이력 (`updateAlgorithmConfig` 미구현이므로 P1-10 도입 후) audit log 첨부
- `replayDecision` callable로 과거 결정 재현 결과 *동일*한지 증명

### Step 4. simplicity-checklist 33 파일 검증 첨부
- [`simplicity-checklist.md`](simplicity-checklist.md) 21항목 통과
- 사용자 화면 raw 위반 0건 (Task 08 독립 감사 결과)
- *사용자 노출은 80세 화법 / admin은 직무 효율*이라는 *별도 룰* 정립 증명

### Step 5. 매도자 자율성 증명 (§33①9호 분쟁 시)
- Task 07 [exclusive 모드 매도자 자율 지정](../task/07-seller-autonomy.md) — MyHome 추천 어휘 0건
- "추천" / "권장" 카피 *0건* (Task 07 §6.2 검증 누적)
- 매도자 self-attestation 체크박스 — *MyHome이 추천한 게 아님* 명시 동의

---

## 5. 거버넌스 통합

### 5.1 외부 자료 제출 책임자
- **법무 책임자** (또는 담당 임원) — 본 가이드 §3·§4 절차 직접 수행
- **운영팀** — admin 캡처 + audit log export 제공
- **개발팀** — 코드 인용 (algorithm_config / replayDecision 등) 추출 지원

### 5.2 자료 제출 전 체크리스트
- [ ] §3.1 부연 설명 표 첨부됨
- [ ] PRIORITY_RULEBOOK.md 첨부됨
- [ ] copy-deck.md §5 (우선권 정책) 첨부됨
- [ ] audit log 시점별 발췌 첨부됨
- [ ] §4 5단계 절차 모두 수행됨
- [ ] 매도자 자율성 증명 (§33①9호 분쟁 시)

### 5.3 미충족 시 위험
부연 설명 누락 시 외부에 다음 인상:
- "MyHome이 broker 단체결성에 개입" → §33①9호 위반 신호 (3년 이하 징역)
- "MyHome이 알고리즘으로 특정 broker 우대" → 공정거래법 위반 (카카오 257억 사례)
- "MyHome이 시세 부당 영향" → §33②4호 위반 신호

본 가이드는 *위험 사전 차단 도구*로서 활용.

---

## 6. 변경 이력

| 일자 | 버전 | 변경 |
|---|---|---|
| 2026-05-03 | v1.0.0 | 신설. Task 08 §5.1 #2 + §5.4 #29 후속. admin 화면 카피 *변경 0* — 외부 노출 시 부연 설명만 정립. |

---

## 7. 변경 통계

| 항목 | 값 |
|---|---|
| admin 코드 변경 | 0 |
| 신규 파일 | 본 가이드 1건 |
| 위험 시나리오 정립 | 3건 |
| 부연 카피 매핑 | 7종 |
| 5단계 법무 절차 | 정립 완료 |
