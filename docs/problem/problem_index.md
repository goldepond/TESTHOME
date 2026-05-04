# Problem Index

Last updated: 2026-05-05

| ID | Type | Severity | File | Title | Status | Task Spec |
|---|---|---|---|---|---|---|
| 2026-04-12_001 | bug | CRITICAL | `firestore.rules` | visitRequests 서브컬렉션 Firestore 보안 규칙 완전 누락 | FIXED | — |
| 2026-04-12_002 | bug | HIGH | `broker_stats_service.dart` | 문서 미존재 시 update() 호출로 인한 silent crash | FIXED | — |
| 2026-04-12_003 | bug | MEDIUM | `mls_property_service.dart` | 싱글톤 broadcast stream 캐시 — 로그아웃 후 stale 스트림 재사용 가능 | FIXED | — |

> **2026-05-04 라운드 4건 (001~004)**: 코드 작업 완료 후 본 인덱스에서 정리. 운영 배포(Firestore Rules + Functions + 35 exports) 완료. QA 인수 진행 중.
> 산출물 핸드오프: [`../task/2026-05-05_qa-handoff-tasks-001-004.md`](../task/2026-05-05_qa-handoff-tasks-001-004.md)
> git history 에 SPEC·problem 원문 보존.
