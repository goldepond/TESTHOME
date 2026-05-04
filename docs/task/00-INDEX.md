# Anti-Poaching System — Task Index

> **상위 목표 문서**: [../goal/multi_agent_competition_solutions_cross_industry.md](../goal/multi_agent_competition_solutions_cross_industry.md)
> **버전 타깃**: v1.4.1 (현재 v1.2.1+24)
> **🚀 진행 상태**: ✅ **코드 작업 100% 완료** (2026-05-03 기준) — 운영 게이트 통과 시 정식 출시
> **📍 다음 세션 진입점**: [`FINAL-v1.4.1-handoff.md`](FINAL-v1.4.1-handoff.md) — Task 01~08 + 라운드 1·2·3 통합 / 운영 게이트 / 컨벤션 / 후속 phase 백로그

---

## 0. 이 문서가 하는 일

목표 문서의 **M1(선등록 우선권) + M2(시간기록) + 4가지 보완 + 알고리즘 투명성**을 *코드로 강제 가능한 단위*로 분해. 8개 task 모두 완료 + 라운드 2·3 sub-task 31건 모두 처리.

> **2026-05-04 정리**: 완료된 정식 task spec 8개(01~08) 및 분석 완료 문서 3개(p0-10, p1-7, p1-14)는 git history에 보존되며, 현재 이 인덱스는 **운영 게이트 통과 전까지 활성인 핸드오프 / 미채택 제안 / 운영 가이드만** 추적한다. 완료 문서 원본이 필요하면 git log 참조.

---

## 1. 핸드오프 (운영 게이트 진행 중)

| # | 제목 | 상태 |
|---|---|:---:|
| [FINAL-v1.4.1-handoff](FINAL-v1.4.1-handoff.md) | Task 01~08 + 라운드 1·2·3 통합 / 운영 게이트 / 컨벤션 / 후속 phase 백로그 | 🔄 진행 중 |

**RULEBOOK_VERSION**: `v1.5.0` / **MATCHING_VERSION**: `matching_v1.3.0`

---

## 1.5 2026-05-04 라운드 — ✅ 코드 작업 100% 완료 / 운영 배포 완료 / QA 인수 진행 중

> **2026-05-05 정리**: 4건(001~004) 모두 코드 작업·운영 배포 완료. SPEC·problem 문서는 git history 보존 후 인덱스에서 제거.
> **현재 단계 진입점**: [`2026-05-05_qa-handoff-tasks-001-004.md`](2026-05-05_qa-handoff-tasks-001-004.md) — Task 인벤토리 / 운영 배포 결과 / QA 인수 체크리스트 / 후속 라운드 위임.

| # | 영역 | 상태 |
|---|---|:---:|
| 001 | 중개사 인증 신청·승인 흐름 (callable 3개 + 신청 폼 + 관리자 큐) | ✅ 배포 |
| 002 | Functions 운영 강화 (Phase 3 region · Phase 4 NOT_FOUND 가드 · Phase 5 diff · Phase 6 Node 22+v6) | ✅ 배포 (Phase 2 CI/CD는 owner 권한 후속) |
| 003 | 중개사 영업 동네(jurisdictions) 셀프-서비스 UI | ✅ 배포 |
| 004 | 규칙서 v1.5.0 사용자 노출 갭 봉합 (매도자 이의 + 자진 만료) | ✅ 배포 |

---

## 2. 후속 phase 입력 (제안)

| # | 제목 | 상태 |
|---|---|:---:|
| [p2-7-trust-score-proposal](p2-7-trust-score-proposal.md) | 중개사 신뢰 점수 제안 | 💡 제안 |
| [p2-8-contribution-recognition-proposal](p2-8-contribution-recognition-proposal.md) | WGA 33% 기여 인정 패턴 제안 | 💡 제안 |

---

## 3. 운영 가이드

| # | 제목 | 사용처 |
|---|---|---|
| [usability-test-protocol](usability-test-protocol.md) | 60대 비전문가 3명 시연 가이드 | 운영 phase P0-7 |

---

## 4. 횡단 설계 원칙 (모든 후속 PR 자가 점검)

| 원칙 | 의미 | 구현 체크 |
|---|---|---|
| **80세 노인 테스트 (P0)** | 모든 화면·문구·결정이 80세 노인이 이해 가능 | [`simplicity-checklist.md`](../common/simplicity-checklist.md) 100% 통과 없이 PR 거절 |
| **Code-level Enforcement** | 약관·자율약정 금지. Firestore Rules + Cloud Functions로 강제 | Rules 패치 없는 PR 금지 |
| **Dynamic Matching** | 단순 시간 외 다중 변수 가중 — *내부* 산정만, UI엔 단순 표현 | 가중치·점수 *절대 노출 금지* |
| **Use-it-or-Lose-it** | 활동 80% 미달 시 자동 만료 | scheduled function 필수 |
| **Threshold Recognition** | 분배·크레딧 X. *마크·인정만* | 보수 분배 코드 절대 금지 |
| **§32·§33 무관성** | 보수 분배·차감 코드 금지 | 모든 PR 법무 자가 점검 |
| **카카오 회피** | 점유율 30% 도달 시 외부 감사 | 점유율 텔레메트리 (06) |
| **3-레이어 카피 동기** | functions REASON ↔ grant_messages reasonCopy ↔ copy-deck §3 | audit eventType 추가 시 3 레이어 동기 |

---

## 5. 절대 금지 패턴 (PR 거절 사유)

1. **약관·UI 안내문으로만 강제** — Firestore Rules 또는 Cloud Functions가 강제하지 않으면 무효
2. **보수에 손대는 어떤 코드** — `commission`, `fee_share`, `payout_split` 같은 필드 신설 금지
3. **`targetBrokerIds` 직접 변형으로 우선권 표현** — 우선권은 별도 `priority_grants` 컬렉션
4. **선착순 단일 변수만으로 우선권 부여** — Dynamic Matching 위반 (카카오 패턴)
5. **이의 제기 채널 없는 자동 결정** — 투명성 task 미적용 PR 거절
6. **테스트 케이스 없는 만료 로직** — Use-it-or-Lose-it 시간 시뮬레이션 필수
7. **80세 노인이 이해 못 하는 화면·문구** — 점수·가중치·복잡 용어 노출, 한 화면 의사결정 ≥3개, 알림 한 줄에 안 들어가는 길이 등 단순성 헌장 어김

---

## 6. 한 줄 정의

> **MyHome v1.4.1 = "한국 부동산에 부재했던 *시간기록 기반 우선권 시스템*을 코드로 강제하는 첫 플랫폼 — 80세 노인도 따라 할 수 있는 단순함으로."**

---

## 7. 외부 참조

### 7.1 거버넌스 인프라 (Task 08 산출물 — 모든 후속 PR 강제)
- 카피 단일 진실원: [`../common/copy-deck.md`](../common/copy-deck.md)
- PR 자가 점검: [`../common/simplicity-checklist.md`](../common/simplicity-checklist.md)
- 공개 룰북: [`../public/PRIORITY_RULEBOOK.md`](../public/PRIORITY_RULEBOOK.md) — `/rulebook` v1.5.0

### 7.2 법령·산업 자료 (설계 근거)
- 법령 리스크: [`../common/platform_commission_intervention_legal_check.md`](../common/platform_commission_intervention_legal_check.md)
- 한국 실무 검증: [`../common/korean_real_estate_practice_verification.md`](../common/korean_real_estate_practice_verification.md)
- 산업 사례: [`../common/cross_industry_anti_poaching_complete_catalog.md`](../common/cross_industry_anti_poaching_complete_catalog.md)
