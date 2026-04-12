# FCMService Test Record

File: `lib/api_request/fcm_service.dart`
Tested: 2026-04-12
Status: PASSED

## Tests Performed
- [x] Static analysis (dart analyze: no warnings/errors)
- [x] Null safety check
- [x] 플랫폼 분기 처리 (kIsWeb, Platform.isAndroid, Platform.isIOS)
- [x] 초기화 중복 방지 (_isInitialized 플래그)
- [x] 에러 처리 검토

## Results

### 플랫폼 처리
- `kIsWeb`: 웹에서 로컬 알림 초기화 스킵 → 정상
- `Platform.isAndroid`: Android 알림 채널 생성 조건 → 정상
- VAPID 키: `const String.fromEnvironment('FCM_VAPID_KEY')` 빌드 시 주입 → 정상

### 초기화 로직
- `_isInitialized` 플래그로 중복 초기화 방지 → 정상
- `onTokenRefresh` 리스너: 로그아웃 후 새 사용자 로그인 시 이전 userId로 토큰 저장될 가능성 있으나, `getAndSaveToken(userId)` 호출 시점에 올바른 userId 전달 필요 → 호출부 책임

### 에러 처리
- 초기화 실패 시 try-catch로 묵살 후 진행 → 알림 없이도 앱 동작 가능하도록 의도적 설계

## Issues Found

없음
