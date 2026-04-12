# VisitRequestService Test Record

File: `lib/api_request/visit_request_service.dart`
Tested: 2026-04-12
Status: ISSUES_FOUND

## Tests Performed
- [x] Static analysis (dart analyze: no warnings/errors)
- [x] Null safety check
- [x] Error handling review
- [x] Business logic verification
- [x] Firestore query validation
- [x] Firestore rules alignment

## Results

### 비즈니스 로직
- 중복 요청 방지 (pending 상태 확인) 정상
- ±30분 충돌 요청 reschedule 로직 정상
- visitRequestCount 카운터 set(merge:true) 패턴 안전
- 방문 승인 시 연락처 교환, 알림 전송 흐름 정상
- migrateAllVisitRequests의 isNotEqualTo 쿼리: 인덱스 불필요 (단순 필드 비교)

### Firestore 쿼리 분석
- `getVisitRequestsByBroker`: collectionGroup 쿼리 사용 — 인덱스 확인 필요
  - firestore.indexes.json에 `brokerId + createdAt DESC` (COLLECTION_GROUP) 인덱스 존재 → 정상
- `getPendingVisitRequests`: `status + createdAt DESC` 인덱스 존재 → 정상
- `getVisitRequestsByProperty`: `orderBy('createdAt')` 단일 인덱스 — 기본 인덱스로 처리됨

### 규칙 불일치 (CRITICAL)
`firestore.rules`에 `mlsProperties/{propertyId}/visitRequests/{requestId}` 서브컬렉션에 대한 규칙이 **완전히 없음**.
Firestore 기본 동작: 규칙이 없으면 **모든 접근 거부**. 실제로는 코드 실행 시 PermissionDenied 오류 발생.

## Issues Found

1. CRITICAL: Firestore visitRequests 서브컬렉션 보안 규칙 누락 → 문제 보고서 2026-04-12_001
