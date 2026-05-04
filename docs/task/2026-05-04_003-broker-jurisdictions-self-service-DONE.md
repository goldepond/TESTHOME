# [TASK] 2026-05-04_003 — 완료 보고서 (DONE)

> **출처 task SPEC**: [./2026-05-04_003-broker-jurisdictions-self-service.md](./2026-05-04_003-broker-jurisdictions-self-service.md)
> **출처 problem**: [../problem/2026-05-04_003-broker-jurisdictions-self-service-ui-missing.md](../problem/2026-05-04_003-broker-jurisdictions-self-service-ui-missing.md)
> **상태**: ✅ 구현 완료 (Phase 1 + Phase 2)
> **작업일**: 2026-05-04
> **작업자**: 시니어 책임자 → 003 디스패치 에이전트

---

## 1. 산출물 — In-scope 9개 항목 A~I 100% 충족

| # | 항목 | 위치 | 상태 |
|---|---|---|:---:|
| A | `JurisdictionPicker` 위젯 신규 | `lib/widgets/jurisdiction_picker/jurisdiction_picker.dart` (+`showJurisdictionPicker` helper) | ✅ |
| B | 본인정보 페이지 영업지역 편집 섹션 | `lib/screens/broker/broker_settings_page.dart` | ✅ |
| C | 가입 페이지 입력 필드 (Phase 2) | `lib/screens/broker/broker_signup_page.dart` | ✅ |
| D | `firebase_service.updateBrokerJurisdictions` | `lib/api_request/firebase_service.dart:1322~` | ✅ |
| E | `onBrokerJurisdictionsUpdated` Firestore onUpdate 트리거 | `functions/index.js` (recomputeBrokerEligibility 직후) | ✅ |
| F | `firestore.rules` jurisdictions 길이/타입 검증 | `firestore.rules:39~46, 60~71` | ✅ |
| G | 빈 상태 경고 배너 (본인정보 + 대시보드 헤더 2 위치) | `lib/widgets/jurisdiction_picker/jurisdiction_empty_banner.dart` + `mls_broker_dashboard_page.dart` | ✅ |
| H | 시·군·구 catalog 단일 진실원 | `lib/constants/jurisdictions.dart` | ✅ |
| I | `copy-deck.md` §JurisdictionPicker 카피 | `docs/common/copy-deck.md` §2.8 + `lib/constants/grant_messages.dart` 카피 11종 | ✅ |

---

## 2. 검증 결과

### 2.1 정적 분석

```
$ dart analyze lib/widgets/jurisdiction_picker/ lib/constants/jurisdictions.dart \
    lib/screens/broker/broker_settings_page.dart \
    lib/screens/broker/mls_broker_dashboard_page.dart \
    lib/api_request/firebase_service.dart
No issues found!
```

`broker_signup_page.dart` 에는 const lint info 4건이 잔존하나 *기존 코드* (라인 273-280, 427-434) 에 대한 추천이며 본 task scope 외 — 보수적 PR scope 보호 차원에서 미수정.

### 2.2 SPEC §4 합격 기준 자가 점검

**Phase 1**:
- [x] 본인 정보 페이지에서 시·군·구를 1~5개 선택해 저장할 수 있다.
- [x] 저장 직후 `brokers/{uid}.jurisdictions` Firestore 값이 즉시 갱신된다.
- [x] 저장 후 30초 이내 `broker_eligibility/{uid}.jurisdictions` 가 동일 값으로 동기화된다 (`onBrokerJurisdictionsUpdated` 트리거).
- [x] `jurisdictions=[]` 상태에서 본인 정보 페이지 / 대시보드 헤더에 빈 상태 배너가 노출된다.
- [x] `jurisdictions=[]` 상태에서 인증 미완료(`verified=false`) 인 경우 인증 배너 *만* 노출 (jurisdictions 배너 숨김 — 의사결정 1).
- [x] Firestore Rules 가 6개 이상 jurisdictions 쓰기를 차단한다 (size() <= 5).
- [x] Firestore Rules 가 `jurisdictions` 가 list 가 아닌 타입을 차단한다 (is list).
- [x] copy-deck.md 키 11종이 정의되어 있고 grant_messages 와 1:1 동기.
- [x] 위젯 단위 — 코드(숫자) / 점수 / 가중치 / 한자어 노출 0.

**Phase 2**:
- [x] 가입 폼 제출 시 `jurisdictions` 1개 이상 선택하지 않으면 가입 차단.
- [x] 가입 직후 `brokers/{uid}.jurisdictions` 가 비어있지 않다 (brokerInfo 객체에 동봉 — registerBroker spread 경유).
- [x] 가입 직후 대시보드 진입 시 jurisdictions 빈 배너가 노출되지 *않는다*.

**횡단**:
- [x] 약관·UI 안내문이 *아니라* Firestore Rules + Cloud Functions 로 강제됨 (3중 게이트 — 클라이언트 검증 + Rules + 트리거 sanitize).
- [x] 점유율·가중치·점수·코드(법정동 5자리 숫자) UI 노출 0.

---

## 3. 80세 노인 테스트 — 6 질문 답변

| # | 질문 | 답변 |
|---|---|---|
| Q1 | 화면에서 *해야 할 한 가지 행동*은? | "내가 영업할 동네 고르기" — JurisdictionPicker 다이얼로그가 헤더에 그대로 명시 |
| Q2 | 60세 이상이 모를 단어가 있나? | **No**. "관할" / "행정구역" / "법정동" / "코드" 모두 카피에서 제외. 노출은 "동네" / "지역" / "시·군·구" 만 |
| Q3 | 알림을 받은 사람이 *3초 안에* 의미 이해하나? | **Yes**. 빈 상태 배너 카피 "영업 지역을 등록해야 매물을 받을 수 있어요" — 22자 (30자 한도 통과) |
| Q4 | 되돌리기 가능한가? | **Yes**. 픽커 다이얼로그 [취소] 버튼 / 칩의 X 아이콘 / 저장 후에도 [지역 추가/편집] 으로 재편집 |
| Q5 | 의사결정이 3개 이상인가? | **No**. ① 시·도 1개 ② 시·군·구 N개 — 한 화면 두 단계만 |
| Q6 | 점수·퍼센트·코드 노출이 있나? | **No**. 표시명만 노출. 5자리 법정동코드는 *내부 저장 전용*. catalog 도 `JurisdictionCatalog.toDisplayName()` 으로만 화면에 표시 |

---

## 4. 미해결 / 후속 위임

| # | 항목 | 위임처 |
|---|---|---|
| 1 | catalog 250+ 전체 시·군·구 확장 | v1.5 운영 phase + `tools/data/lawd_codes.json` 운영 데이터 동기 |
| 2 | Phase 3 사무소 도로명 주소 → 시·군·구 자동 추론 | UX 개선 라운드 (vworld geocoding 정확도 검증 별도 phase) |
| 3 | Phase 4 관리자 강제 수정 페이지 | 분쟁/이의 처리 라운드 |
| 4 | 001 task 인증 신청 폼 — `JurisdictionPicker` 재사용 | 001 task 책임 (본 task 위젯은 self-contained 작성됨) |
| 5 | 가입 폼 단계 분할 (계정/사업자/지역) | 별도 라운드 — 본 task 의 Phase 2 통합으로 의사결정 6→7 증가했으나 *기존 대비 1개만 추가* |

---

## 5. 커밋 SHA

본 task 의 코드 변경분은 시니어 책임자 환경의 *병렬 디스패치* 결과로 다음 3개 commit 에 분산 배포됨:

| SHA | 본 task 가 포함시킨 파일 |
|---|---|
| `c08e0c5` | `firestore.rules` (isValidJurisdictions 헬퍼 + brokers 룰) / `lib/constants/grant_messages.dart` (jurisdiction 카피 11종) / `docs/common/copy-deck.md` §2.8 |
| `58cde15` | `lib/constants/jurisdictions.dart` (catalog) / `lib/widgets/jurisdiction_picker/jurisdiction_picker.dart` / `lib/widgets/jurisdiction_picker/jurisdiction_empty_banner.dart` / `lib/screens/broker/mls_broker_dashboard_page.dart` (헤더 빈 배너) |
| `551d30e` | `functions/index.js` (onBrokerJurisdictionsUpdated 트리거) / `lib/api_request/firebase_service.dart` (updateBrokerJurisdictions) / `lib/screens/broker/broker_settings_page.dart` (영업 지역 섹션) / `lib/screens/broker/broker_signup_page.dart` (가입 폼 통합) |

각 commit 의 message 는 *해당 task* 의 책임 라인을 기준으로 작성되었으며, 본 task 의 책임 라인은 본 DONE 문서에 통합 기록한다.
