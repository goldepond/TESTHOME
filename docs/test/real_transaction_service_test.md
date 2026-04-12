# RealTransactionService Test Record

File: `lib/api_request/real_transaction_service.dart`
Tested: 2026-04-12
Status: PASSED

## Tests Performed
- [x] Static analysis (dart analyze: no warnings/errors)
- [x] Null safety check
- [x] Error handling review
- [x] 3단계 캐싱 로직 검증 (메모리 → 로컬스토리지 → API)
- [x] 페이지네이션 로직 검증
- [x] 데이터 파싱 로직 검증
- [x] 필터링 로직 검증

## Results

### 3단계 캐싱 로직
1. 메모리 캐시 (`_cache` Map): 만료 여부 `isExpired(_cacheTTL)` 체크 → 정상
2. 로컬 저장소 캐시 (SharedPreferences): 만료 캐시 자동 삭제 → 정상
3. API 호출: 성공 후 메모리 + 로컬 저장소 동시 저장 → 정상
- `_saveToLocalStorage` 비동기 호출 시 await 없이 fire-and-forget — 저장 실패해도 기능에 영향 없음, 의도적 설계로 판단

### 페이지네이션
- `numOfRows = 1000`, 최대 10페이지 루프 → 최대 10,000건 처리 가능
- `fetchedCount >= totalCount || itemList.length < _numOfRows` 종료 조건 → 정상

### JSON 파싱
- 6가지 팩토리 메서드 (아파트/연립다세대/단독다가구 × 매매/전월세) 모두 null-safe 처리 확인
- `_parseDealAmount`: int/double/String 타입 모두 처리 → 정상
- `_isCancelled`: cdealType 'O'/'o' 처리 → 정상

### 필터링 로직
- 10가지 필터 (면적/층수/건축년도/거래유형/계약구분/매도자/매수자/가격대/갱신요구권/검색범위) 정상
- 검색 범위 필터: sameDong이지만 umdNm null이면 필터 미적용 → 의도적 폴백

### 캐시 한도
- `_cacheLimit = 100`: 메모리 캐시 100개 제한 (이전 50→100으로 확장) → 정상

## Issues Found

없음
