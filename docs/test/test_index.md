# Test Index

Last updated: 2026-04-12

## Tested Services

| Service File | Last Tested | Status | Notes |
|---|---|---|---|
| `firebase_service.dart` | 2026-04-12 | ISSUES | 1개 LOW 이슈 (authenticateUser doc없으면 null 반환) |
| `mls_property_service.dart` | 2026-04-12 | ISSUES | 스트림 캐시 메모리 누수 가능성 (MEDIUM) |
| `real_transaction_service.dart` | 2026-04-12 | PASSED | 3단계 캐싱 로직 정상, 페이지네이션 정상 |
| `broker_stats_service.dart` | 2026-04-12 | ISSUES | HIGH: update() 호출 시 문서 미존재 crash 가능성 |
| `visit_request_service.dart` | 2026-04-12 | ISSUES | HIGH: Firestore 규칙 미설정 (visitRequests 서브컬렉션) |
| `fcm_service.dart` | 2026-04-12 | PASSED | 플랫폼별 조건 처리 정상 |
| `firestore.rules` | 2026-04-12 | ISSUES | CRITICAL: visitRequests 서브컬렉션 규칙 누락 |
| `firestore.indexes.json` | 2026-04-12 | PASSED | visitRequests 복합 인덱스 존재 확인 |

## Static Analysis (dart analyze)

- 실행일: 2026-04-12
- 결과: 130 issues (모두 `info` 레벨, `warning`/`error` 0개)
- 주요 패턴: `prefer_const_constructors` (대다수), `avoid_redundant_argument_values`
- 심각 이슈 없음

## 미테스트 서비스

| 파일 | 이유 |
|---|---|
| `address_service.dart` | 외부 API 프록시 중계 서비스, 비즈니스 로직 최소 |
| `apt_info_service.dart` | 외부 API 래퍼 |
| `broker_service.dart` | 중개사 CRUD, 향후 테스트 필요 |
| `broker_verification_service.dart` | 검증 로직, 향후 테스트 필요 |
| `notification_firebase_service.dart` | 알림 CRUD |
| `register_service.dart` | 등기 API 래퍼 |
| `remote_config_service.dart` | Firebase Remote Config 래퍼 |
| `storage_service.dart` | Firebase Storage 래퍼 |
| `vworld_service.dart` | 지도 API 래퍼 |
| `log_service.dart` | 로그 기록 서비스 |
| `search_analytics_service.dart` | 분석 서비스 |
