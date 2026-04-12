# BrokerStatsService Test Record

File: `lib/api_request/broker_stats_service.dart`
Tested: 2026-04-12
Status: ISSUES_FOUND

## Tests Performed
- [x] Static analysis (dart analyze: no warnings/errors)
- [x] Null safety check
- [x] Error handling review
- [x] Business logic verification
- [x] Firestore query validation

## Results

### 비즈니스 로직
- 방문 요청 생성(onVisitRequestCreated): set(merge:true) 사용 → 문서 미존재 시 생성 처리 OK
- createdAt 설정 로직: set 후 doc 재조회하여 createdAt 추가 — 정상이나 2번의 네트워크 호출 발생 (MEDIUM 수준 비효율)
- 상대평가 로직 (avgVisitSuccessRate, avgNoShowRate): 분모 0 체크 존재 → 안전

### update() 호출 패턴 문제 (HIGH)
다음 메서드들이 `.update()`를 직접 호출하지만, 호출 시점에 문서가 존재하지 않을 수 있음:
- `onVisitRequestResponded` (L162): 방문 요청에 응답했지만 brokerStats 문서가 아직 없는 경우
- `onVisitRequestCancelled` (L174): 중개사가 취소했지만 통계가 아직 초기화 안 된 경우
- `onVisitCompleted` (L189): 방문 완료 처리 시 통계 미초기화
- `onNoShow` (L204): 노쇼 처리 시 통계 미초기화
- `onDealCompleted` (L236): 거래 완료 시 통계 미초기화

Firestore `.update()`는 문서가 없으면 `not-found` 예외를 발생시킴. 
현재 try-catch로 에러를 묵살하므로 통계가 누락되는 silent failure 발생 가능.

`onVisitRequestCreated`만 `set(merge:true)`를 사용하여 문서를 보장하지만, 
그 이후 호출되는 메서드들은 문서 존재를 보장받지 못함.
(예: 방문 완료는 요청 생성 전에 이미 통계 문서가 삭제된 경우 등)

### getTopBrokersByRegion 쿼리
- `dealsByRegion.$region isGreaterThan` 동적 필드 쿼리: 인덱스 없음 인지 후 폴백 처리 존재 → 안전하나 프로덕션에서 성능 저하 가능

## Issues Found

1. HIGH: onVisitRequestResponded/Cancelled/Completed/NoShow/DealCompleted에서 문서 미존재 시 update() 실패 → silent 통계 누락 → 문제 보고서 2026-04-12_002
2. LOW: createdAt 초기화를 위한 2번째 Firestore 읽기 — set(merge:true)로 통합 가능 (테스트 기록에만 기재)
