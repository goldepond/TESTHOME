# 🚀 MVP 출시 전 준비사항 체크리스트

> 작성일: 2025-01-XX  
> 프로젝트: MyHome - 쉽고 빠른 부동산 상담  
> 목표: MVP 출시 준비 완료

---

## 📋 전체 체크리스트 요약

| 항목 | 필수 | 권장 | 상태 |
|------|------|------|------|
| **1. 환경 설정** | 5개 | 2개 | 🔴 |
| **2. 보안 설정** | 4개 | 3개 | 🔴 |
| **3. 배포 설정** | 3개 | 1개 | 🟡 |
| **4. 코드 정리** | 3개 | 2개 | 🟡 |
| **5. 테스트** | 2개 | 3개 | 🟡 |
| **6. 문서화** | 1개 | 2개 | 🟢 |
| **7. 운영 준비** | 2개 | 3개 | 🟡 |

---

## 🔴 필수 항목 (즉시 완료 필요)

### 1️⃣ 환경 설정

#### 1-1. API 키 확인 및 갱신
**파일:** `lib/constants/app_constants.dart`

**해야 할 일:**
- [ ] **VWorld API 키 확인**
  - 현재: `FA0D6750-3DC2-3389-B8F1-0385C5976B96`
  - 확인: VWorld 개발자 포털에서 키 유효성 확인
  - 확인: 도메인 제한 설정 확인 (CORS 설정)

- [ ] **Juso API 키 확인**
  - 현재: `devU01TX0FVVEgyMDI1MDkwNDE5NDkzNDExNjE1MTQ=`
  - 확인: 개발용 키인지 프로덕션 키인지 확인
  - 확인: 하루 호출 제한 확인 (일반적으로 10,000건)

- [ ] **Data.go.kr API 키 확인**
  - 현재: `lkFNy5FKYttNQrsdPfqBSmg8frydGZUlWeH5sHrmuILv0cwLvMSCDh+Tl1KORZJXQTqih1BTBLpxfdixxY0mUQ==`
  - 확인: API 키 유효성 확인
  - 확인: 사용량 제한 확인

- [ ] **CODEF API 키 확인** (등기부등본용)
  - 현재: 하드코딩됨
  - 확인: 등기부등본 기능 활성화 시 키 확인 필요
  - 참고: 현재 비활성화 상태 (`isRegisterFeatureEnabled = false`)

- [ ] **네이버 지도 API 키 확인**
  - 현재: `eb18xjawdk`
  - 확인: 네이버 클라우드 플랫폼에서 키 유효성 확인

**위험도:** 🔴 높음 (API 키가 만료되면 서비스 중단)

---

#### 1-2. Firebase 프로젝트 설정 확인
**파일:** `web/index.html`, `android/app/google-services.json`

**해야 할 일:**
- [ ] **Firebase 프로젝트 확인**
  - 현재 프로젝트 ID: `houseproject-18f44`
  - 확인: Firebase Console에서 프로젝트 상태 확인
  - 확인: 결제 플랜 확인 (Spark Plan 무료 제한 확인)

- [ ] **웹 앱 설정 확인**
  - 확인: `web/index.html`에 Firebase config가 올바르게 설정됨
  - 확인: 도메인 허용 목록에 배포 도메인 추가

- [ ] **Android 앱 설정 확인**
  - 확인: `android/app/google-services.json` 파일 존재 확인
  - 확인: SHA-1 인증서 지문 등록 (Google Sign-In 사용 시)

- [ ] **Firestore 인덱스 생성**
  - 확인: `firestore.indexes.json` 파일 확인
  - 실행: `firebase deploy --only firestore:indexes`

**위험도:** 🔴 높음 (Firebase 설정 오류 시 서비스 불가)

---

#### 1-3. VWorld API CORS 도메인 설정
**파일:** `lib/constants/app_constants.dart:51`

**해야 할 일:**
- [ ] **배포 도메인 확인**
  - 현재 코드: `domainCORSParam = 'http://localhost:8831'`
  - 변경 필요: 배포 도메인으로 변경 (예: `https://goldepond.github.io`)

- [ ] **VWorld 개발자 포털에서 도메인 등록**
  - VWorld 개발자 포털 접속
  - API 키 관리 페이지에서 허용 도메인 추가
  - 배포 도메인 추가 (예: `goldepond.github.io`)

**위험도:** 🔴 높음 (CORS 설정 없으면 API 호출 실패)

---

#### 1-4. 배포 URL 설정
**파일:** `lib/screens/admin/admin_quote_requests_page.dart:856`

**해야 할 일:**
- [ ] **이메일 링크 URL 변경**
  - 현재: `const baseUrl = 'https://goldepond.github.io/TESTHOME';`
  - 확인: 실제 배포 URL과 일치하는지 확인
  - 변경: 다른 도메인 사용 시 변경

- [ ] **중개사 답변 페이지 URL 확인**
  - 현재: `$baseUrl/#/inquiry/$linkId`
  - 확인: 실제 배포 환경에서 링크 작동 확인

**위험도:** 🟡 중간 (URL 오류 시 중개사 답변 불가)

---

#### 1-5. 등기부등본 기능 활성화 여부 결정
**파일:** `lib/screens/home_page.dart:620`

**해야 할 일:**
- [ ] **기능 활성화 여부 결정**
  - 현재: `isRegisterFeatureEnabled = false` (비활성화)
  - 결정: MVP 출시 시 활성화할지 결정
  - 활성화 시:
    - CODEF API 키 확인 필요
    - 테스트 계정 정보 설정 필요 (`TestConstants`)

**위험도:** 🟢 낮음 (현재 비활성화 상태이므로 선택사항)

---

### 2️⃣ 보안 설정

#### 2-1. Firestore 보안 규칙 추가
**파일:** `firestore.rules`

**해야 할 일:**
- [ ] **견적문의 컬렉션 보안 규칙 추가**
  - 현재: `quoteRequests` 컬렉션 규칙 없음
  - 추가 필요:
    ```javascript
    // 견적문의
    match /quoteRequests/{requestId} {
      allow read: if request.auth != null && (
        resource.data.userId == request.auth.uid || 
        resource.data.brokerRegistrationNumber != null
      );
      allow create: if request.auth != null && 
        request.resource.data.userId == request.auth.uid;
      allow update: if request.auth != null && (
        resource.data.userId == request.auth.uid ||
        resource.data.brokerRegistrationNumber != null
      );
    }
    
    // 공인중개사 정보
    match /brokers/{brokerId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == brokerId;
    }
    ```

- [ ] **보안 규칙 테스트**
  - Firebase Console에서 시뮬레이터로 테스트
  - 각 컬렉션별 읽기/쓰기 권한 확인

- [ ] **규칙 배포**
  - 실행: `firebase deploy --only firestore:rules`

**위험도:** 🔴 높음 (보안 규칙 없으면 데이터 노출 위험)

---

#### 2-2. 관리자 페이지 보안 강화
**파일:** `lib/main.dart:106`

**해야 할 일:**
- [ ] **관리자 인증 추가**
  - 현재: URL만으로 접근 가능 (`/admin-panel-myhome-2024`)
  - 추가: Firebase Auth로 관리자 인증 확인
  - 추가: 관리자 UID 화이트리스트

- [ ] **보안 URL 변경 고려**
  - 현재: `/admin-panel-myhome-2024`
  - 고려: 더 복잡한 URL 사용 또는 완전히 제거하고 인증만 사용

**위험도:** 🔴 높음 (누구나 관리자 페이지 접근 가능)

---

#### 2-3. 테스트 계정 정보 제거/보안 처리
**파일:** `lib/constants/app_constants.dart:74-82`

**해야 할 일:**
- [ ] **테스트 계정 정보 보안 처리**
  - 현재: `TestConstants`에 테스트 계정 정보 하드코딩
  - 옵션 1: 주석 처리 (권장)
  - 옵션 2: 환경 변수로 분리
  - 옵션 3: 완전 제거 (등기부등본 기능 비활성화 시)

**위험도:** 🟡 중간 (테스트 계정 정보 노출 위험)

---

#### 2-4. API 키 보안 (향후 개선)
**파일:** `lib/constants/app_constants.dart`

**현재 상태:** API 키가 하드코딩되어 있음

**해야 할 일:**
- [ ] **단기 (MVP):**
  - 현재 상태 유지 (빠른 출시 우선)
  - API 키 사용량 모니터링 설정

- [ ] **중기 (출시 후):**
  - Firebase Remote Config로 API 키 관리
  - 또는 환경 변수 사용
  - 또는 백엔드 프록시 서버 구축

**위험도:** 🟡 중간 (현재는 공개 API 키이므로 MVP에서는 허용 가능)

---

### 3️⃣ 배포 설정

#### 3-1. GitHub Pages 배포 설정
**파일:** `deploy_github_pages.bat`, `.github/workflows/deploy.yml`

**해야 할 일:**
- [ ] **GitHub Pages 활성화 확인**
  - 저장소: `goldepond/TESTHOME`
  - Settings > Pages에서 `gh-pages` 브랜치 선택 확인

- [ ] **배포 스크립트 테스트**
  - 실행: `deploy_github_pages.bat`
  - 확인: 빌드 성공 여부 확인
  - 확인: GitHub Actions 실행 확인

- [ ] **배포 URL 확인**
  - 접속: `https://goldepond.github.io/TESTHOME/`
  - 확인: 앱이 정상적으로 로드되는지 확인

**위험도:** 🟡 중간 (배포 실패 시 서비스 불가)

---

#### 3-2. 프로덕션 빌드 설정
**해야 할 일:**
- [ ] **디버그 모드 제거**
  - 확인: `flutter build web --release` 실행
  - 확인: `main.dart`에서 `debugShowCheckedModeBanner: false` 확인됨

- [ ] **압축 최적화**
  - 확인: 빌드 후 파일 크기 확인
  - 확인: 불필요한 라이브러리 제거

**위험도:** 🟡 중간 (최적화되지 않으면 성능 저하)

---

#### 3-3. 도메인 및 SSL 확인
**해야 할 일:**
- [ ] **HTTPS 확인**
  - 확인: GitHub Pages는 자동으로 HTTPS 제공
  - 확인: SSL 인증서 유효성 확인

- [ ] **커스텀 도메인 설정 (선택)**
  - 필요 시: 커스텀 도메인 설정
  - VWorld API CORS 도메인도 함께 변경 필요

**위험도:** 🟢 낮음 (GitHub Pages는 자동 HTTPS 제공)

---

### 4️⃣ 코드 정리

#### 4-1. 디버그 로그 제거
**해야 할 일:**
- [ ] **print 문 제거 또는 주석 처리**
  - 검색: `grep -r "print(" lib/`
  - 제거: 프로덕션 빌드에서 불필요한 print 문 제거
  - 대체: 필요 시 로깅 라이브러리 사용

**위험도:** 🟡 중간 (과도한 로그는 성능 저하)

---

#### 4-2. 테스트 코드 제거
**해야 할 일:**
- [ ] **테스트용 데이터 제거**
  - 확인: `TestConstants` 사용 여부 확인
  - 제거: 등기부등본 기능 비활성화 시 테스트 코드 제거

**위험도:** 🟢 낮음 (기능에 영향 없음)

---

#### 4-3. 불필요한 파일 정리
**해야 할 일:**
- [ ] **빌드 파일 제거**
  - 확인: `build/` 폴더가 `.gitignore`에 포함되어 있는지 확인

- [ ] **임시 파일 제거**
  - 확인: `assets/assets.zip` 같은 임시 파일 제거

**위험도:** 🟢 낮음 (저장소 크기 감소)

---

### 5️⃣ 테스트

#### 5-1. 핵심 기능 테스트
**해야 할 일:**
- [ ] **사용자 플로우 테스트**
  - [ ] 회원가입/로그인
  - [ ] 주소 검색
  - [ ] 중개사 찾기
  - [ ] 견적 요청
  - [ ] 견적 답변 확인
  - [ ] 견적 비교

- [ ] **중개사 플로우 테스트**
  - [ ] 중개사 회원가입
  - [ ] 견적 확인
  - [ ] 답변 제출

- [ ] **관리자 플로우 테스트**
  - [ ] 관리자 페이지 접근
  - [ ] 견적문의 확인
  - [ ] 이메일 전송

**위험도:** 🔴 높음 (기능 오류 시 서비스 불가)

---

#### 5-2. 크로스 브라우저 테스트
**해야 할 일:**
- [ ] **주요 브라우저 테스트**
  - [ ] Chrome (최신 버전)
  - [ ] Safari (최신 버전)
  - [ ] Firefox (최신 버전)
  - [ ] Edge (최신 버전)

- [ ] **모바일 브라우저 테스트**
  - [ ] Chrome Mobile
  - [ ] Safari Mobile

**위험도:** 🟡 중간 (일부 브라우저에서 작동 안 할 수 있음)

---

### 6️⃣ 문서화

#### 6-1. 운영 매뉴얼 작성
**해야 할 일:**
- [ ] **관리자 매뉴얼 작성**
  - 견적문의 관리 방법
  - 중개사 이메일 전송 방법
  - 문제 해결 가이드

- [ ] **사용자 가이드 작성 (선택)**
  - 주요 기능 사용법
  - FAQ 작성

**위험도:** 🟢 낮음 (운영 편의성 향상)

---

### 7️⃣ 운영 준비

#### 7-1. 모니터링 설정
**해야 할 일:**
- [ ] **Firebase Analytics 확인**
  - 확인: Firebase Console에서 Analytics 활성화 확인
  - 확인: 이벤트 추적 설정 확인

- [ ] **에러 로깅 설정**
  - 고려: Firebase Crashlytics 설정 (선택)
  - 확인: 주요 에러 발생 시 알림 설정

**위험도:** 🟡 중간 (문제 발생 시 빠른 대응 가능)

---

#### 7-2. 백업 및 복구 계획
**해야 할 일:**
- [ ] **Firestore 백업 설정**
  - 확인: Firebase Console에서 자동 백업 설정 확인
  - 확인: 백업 주기 설정 (일별 권장)

- [ ] **복구 절차 문서화**
  - 문서: 데이터 복구 방법 문서화
  - 문서: 롤백 절차 문서화

**위험도:** 🟡 중간 (데이터 손실 시 복구 가능)

---

## 🟡 권장 항목 (출시 후 개선)

### 8. 성능 최적화
- [ ] 이미지 최적화 (WebP 포맷)
- [ ] 코드 스플리팅
- [ ] 캐싱 전략 개선

### 9. 보안 강화
- [ ] API 키 환경 변수화
- [ ] Firebase Remote Config 사용
- [ ] Rate Limiting 구현

### 10. 사용자 경험 개선
- [ ] 로딩 상태 개선
- [ ] 에러 메시지 개선
- [ ] 접근성 개선

---

## 📝 출시 전 최종 체크리스트

### 출시 직전 확인사항

- [ ] **환경 설정 완료**
  - [ ] 모든 API 키 확인 완료
  - [ ] Firebase 설정 완료
  - [ ] VWorld CORS 도메인 설정 완료
  - [ ] 배포 URL 설정 완료

- [ ] **보안 설정 완료**
  - [ ] Firestore 보안 규칙 추가 완료
  - [ ] 관리자 페이지 보안 강화 완료
  - [ ] 테스트 계정 정보 처리 완료

- [ ] **배포 설정 완료**
  - [ ] GitHub Pages 배포 테스트 완료
  - [ ] 프로덕션 빌드 성공 확인
  - [ ] 배포 URL 정상 작동 확인

- [ ] **테스트 완료**
  - [ ] 핵심 기능 테스트 완료
  - [ ] 크로스 브라우저 테스트 완료
  - [ ] 모바일 테스트 완료

- [ ] **문서화 완료**
  - [ ] 운영 매뉴얼 작성 완료
  - [ ] 문제 해결 가이드 작성 완료

---

## 🚀 출시 순서

### 1단계: 사전 준비 (1-2일)
1. 환경 설정 완료
2. 보안 설정 완료
3. 코드 정리 완료

### 2단계: 테스트 (1일)
1. 핵심 기능 테스트
2. 크로스 브라우저 테스트
3. 모바일 테스트

### 3단계: 배포 (반일)
1. 프로덕션 빌드
2. GitHub Pages 배포
3. 배포 확인

### 4단계: 출시 후 모니터링 (지속)
1. 에러 모니터링
2. 사용자 피드백 수집
3. 성능 모니터링

---

## ⚠️ 출시 전 필수 확인사항

### 🔴 즉시 해결 필요 (MVP 출시 필수)

1. **Firestore 보안 규칙 추가** ⭐⭐⭐
   - `quoteRequests` 컬렉션 규칙 없음
   - 보안 위험 높음

2. **관리자 페이지 보안 강화** ⭐⭐⭐
   - 현재 누구나 접근 가능
   - 인증 추가 필요

3. **VWorld API CORS 도메인 설정** ⭐⭐⭐
   - 배포 도메인으로 변경 필요
   - 설정 없으면 API 호출 실패

4. **배포 URL 설정** ⭐⭐
   - 이메일 링크 URL 확인 필요

5. **API 키 확인** ⭐⭐
   - 모든 API 키 유효성 확인
   - 사용량 제한 확인

### 🟡 빠른 시일 내 해결 권장

6. **테스트 계정 정보 보안 처리** ⭐
7. **디버그 로그 제거** ⭐
8. **핵심 기능 테스트** ⭐

---

## 📞 문제 발생 시 연락처

### API 키 문제
- VWorld: https://www.vworld.kr/
- Juso: https://www.juso.go.kr/
- Data.go.kr: https://www.data.go.kr/

### Firebase 문제
- Firebase Console: https://console.firebase.google.com/
- Firebase 문서: https://firebase.google.com/docs

### 배포 문제
- GitHub Pages 문서: https://pages.github.com/
- Flutter 웹 빌드 문서: https://flutter.dev/docs/deployment/web

---

## ✅ 완료 체크

출시 준비가 완료되면 각 항목에 체크표시하세요:

- [ ] 환경 설정 완료
- [ ] 보안 설정 완료
- [ ] 배포 설정 완료
- [ ] 코드 정리 완료
- [ ] 테스트 완료
- [ ] 문서화 완료
- [ ] 운영 준비 완료

**모든 항목이 체크되면 MVP 출시 준비 완료!** 🎉

