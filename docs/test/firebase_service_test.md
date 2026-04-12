# FirebaseService Test Record

File: `lib/api_request/firebase_service.dart`
Tested: 2026-04-12
Status: ISSUES_FOUND

## Tests Performed
- [x] Static analysis (dart analyze: no warnings/errors)
- [x] Null safety check
- [x] Error handling review
- [x] Auth flow verification
- [x] Cache logic review
- [x] Admin permission check

## Results

### 인증 흐름
- `signInAnonymously`: 기존 로그인 여부 체크 후 문서 생성, 정상
- `authenticateUnified`: broker → user 순서 확인, 문서 없으면 생성, 정상
- `authenticateUser`: 문서가 없으면 null 반환 — Firebase Auth는 성공했으나 Firestore 문서 누락 시 로그인 실패처럼 동작 (LOW)
- `linkAnonymousAccountToEmail`: 이메일 형식 보정 로직 정상

### 관리자 권한
- `isAdmin()`: Firebase Custom Claims 기반 (`admin: true`) — 클라이언트 조작 불가 → 안전
- Firestore rules의 admin 확인과 일치

### 캐시 로직
- 10분 만료 캐시 (`_userCache`, `_brokerCache`) — 싱글톤이므로 앱 재시작 전까지 유지됨
- `getUser(id, useCache: false)` 파라미터로 강제 갱신 가능 → 적절한 설계

### 소셜 로그인 비밀번호 생성
- `_generateSocialPassword`: base64(provider + socialId + salt) — 가역적 인코딩이므로 단순 난독화 수준
  소셜 계정의 비밀번호 예측 가능성은 salt 비밀 유지에 의존 → 실제 보안 위협은 낮음 (코드 내 하드코딩 salt)

## Issues Found

1. LOW: `authenticateUser`에서 Firestore 문서 미존재 시 인증 성공임에도 null 반환 — 신규 가입 직후 로그인 시 edge case 가능 (문제 보고서 미작성, LOW)
2. LOW: `_generateSocialPassword`의 salt가 코드에 하드코딩 (`'myhome_social_auth_2024_salt'`) — 보안상 낮은 위험이나 코드 노출 시 소셜 계정 비밀번호 재현 가능
