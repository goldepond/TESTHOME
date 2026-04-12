# MLSPropertyService Test Record

File: `lib/api_request/mls_property_service.dart`
Tested: 2026-04-12
Status: ISSUES_FOUND

## Tests Performed
- [x] Static analysis (dart analyze: no warnings/errors)
- [x] Null safety check
- [x] Error handling review
- [x] Business logic verification
- [x] Firestore query validation
- [x] State transition logic

## Results

### 매물 상태 전이 로직
- draft → pending → active → inquiry → underOffer → depositTaken → sold 흐름 검증
- `updateStatus` 메서드: StatusHistory 누적 정상, sold 시 isActive=false 처리 정상
- visitSchedule 승인 시 active → inquiry 자동 전이 정상
- 첫 협의 로그 시 inquiry → underOffer 자동 전이 정상
- depositTaken/sold 시 pending brokerOffers 자동 정리 정상

### Firestore 쿼리 분석
- `getPropertiesByUser`: `userId + isDeleted + orderBy(createdAt)` — 인덱스 확인 필요
- `getAllActiveProperties` / `getAllActivePropertiesFast`: `isActive + isDeleted + status whereIn + orderBy(createdAt)` — `whereIn + orderBy` 복합 인덱스 존재 확인
- `getPropertiesBroadcastedToBroker`: `targetBrokerIds arrayContains + isDeleted + isActive + orderBy(broadcastedAt)` — 인덱스 존재 확인 (firestore.indexes.json L262)
- `getCompletedPropertiesByBroker`: `finalBrokerId + isDeleted + orderBy(depositTakenAt)` — 인덱스 존재 여부 별도 확인 필요

### 스트림 캐시 패턴 분석 (MEDIUM)
`_broadcastStreams` Map이 싱글톤에 영구 저장됨.
- `clearBrokerCache(brokerId)` 및 `clearAllCache()` 메서드 존재 → 로그아웃 시 호출 여부 확인 필요
- `clearBrowsableCache()`는 dashbord에서 region 변경 시 호출됨 (L203 확인)
- 그러나 `clearAllCache()`가 로그아웃 처리 흐름에 실제로 연결되었는지 코드에서 미확인

### 기타
- `broadcastProperty`에서 brokerIds 루프 내 개별 notification 전송: N개 순차 await — 대규모 배포 시 느릴 수 있음 (LOW)
- `completeTransaction`에서 visitRequests 조회 시 `property.visitRequests.where` 사용 — 레거시 리스트 방식. Sub-collection으로 마이그레이션 후에는 빈 리스트 반환 가능 (MEDIUM)

## Issues Found

1. MEDIUM: 싱글톤 broadcast stream 캐시 — clearAllCache() 미호출 시 로그아웃 후 stale 스트림 재사용 가능 → 문제 보고서 2026-04-12_003
2. MEDIUM: completeTransaction에서 visitRequests 레거시 리스트 조회 — Sub-collection 마이그레이션 후 제안가(proposedPrice) 조회 실패 가능 (테스트 기록에 LOW로 기재, 마이그레이션 완료 전까지 잠재 위험)
3. LOW: broadcastProperty N개 순차 알림 전송 (병렬화 기회 존재)
