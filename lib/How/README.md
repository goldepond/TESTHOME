# MyHome 서비스 전체 로직 상세 문서

> 작성일: 2025-01-XX  
> 프로젝트: MyHome - 쉽고 빠른 부동산 상담  
> 목적: 서비스의 모든 로직을 코드와 함께 상세하게 정리

---

## 📚 문서 목록

이 문서는 전체 서비스 로직을 여러 섹션으로 나누어 설명합니다:

1. **[00_PROJECT_OVERVIEW.md](00_PROJECT_OVERVIEW.md)** - 프로젝트 개요 및 아키텍처
2. **[01_AUTHENTICATION_SYSTEM.md](01_AUTHENTICATION_SYSTEM.md)** - 인증 시스템
3. **[02_ADDRESS_SEARCH.md](02_ADDRESS_SEARCH.md)** - 주소 검색 및 부동산 정보 조회
4. **[03_BROKER_SEARCH.md](03_BROKER_SEARCH.md)** - 공인중개사 찾기
5. **[04_QUOTE_REQUEST.md](04_QUOTE_REQUEST.md)** - 견적 요청 시스템
6. **[05_QUOTE_MANAGEMENT.md](05_QUOTE_MANAGEMENT.md)** - 견적 관리 및 답변 시스템
7. **[06_ADMIN_SYSTEM.md](06_ADMIN_SYSTEM.md)** - 관리자 시스템
8. **[07_DATA_MODELS.md](07_DATA_MODELS.md)** - 데이터 모델 상세 설명
9. **[08_API_SERVICES.md](08_API_SERVICES.md)** - API 서비스 상세 설명
10. **[09_UI_COMPONENTS.md](09_UI_COMPONENTS.md)** - UI 컴포넌트 및 화면 플로우

---

## 🎯 서비스 핵심 가치

```
부동산 소유자가 주소만 입력하면
→ 등기부등본, 아파트 정보, 근처 공인중개사를 한번에 확인
→ 비대면으로 견적 요청
→ 여러 중개사 동시 비교
→ 계약서 작성까지 원스톱 서비스
```

---

## 🔄 핵심 사용자 플로우

### 1. 판매자 플로우
```
1. 주소 입력 (Juso API)
   ↓
2. 위치 정보 조회 (VWorld API)
   ↓
3. 등기부등본 조회 (CODEF API, 선택적)
   ↓
4. 아파트 정보 조회 (Data.go.kr API)
   ↓
5. 공인중개사 찾기 (VWorld + 서울시 API)
   ↓
6. 견적 요청 작성 및 전송 (Firebase)
   ↓
7. 견적 이력 확인 및 비교
   ↓
8. 중개사 선택 및 연락
```

### 2. 공인중개사 플로우
```
1. 이메일/링크 수신
   ↓
2. 링크 클릭 (/inquiry/{linkId})
   ↓
3. 문의 정보 확인
   ↓
4. 답변 작성 및 제출
   ↓
5. 판매자에게 자동 전달
```

### 3. 관리자 플로우
```
1. 관리자 대시보드 접속 (/admin-panel-myhome-2024)
   ↓
2. 견적문의 모니터링
   ↓
3. 중개사 이메일 확인 및 첨부
   ↓
4. 이메일 전송 또는 링크 복사
   ↓
5. 중개사 응답 모니터링
```

---

## 📁 프로젝트 구조

```
lib/
├── main.dart                    # 앱 진입점, 라우팅 설정
├── screens/                     # 화면 컴포넌트
│   ├── home_page.dart          # 내집팔기 (주소 검색, 부동산 조회)
│   ├── broker_list_page.dart   # 공인중개사 찾기 및 견적 요청
│   ├── quote_history_page.dart # 견적 이력 확인
│   ├── quote_comparison_page.dart # 견적 비교
│   ├── admin/                  # 관리자 페이지
│   ├── broker/                 # 중개사 페이지
│   └── ...
├── api_request/                 # API 서비스
│   ├── firebase_service.dart   # Firebase 통합 서비스
│   ├── address_service.dart    # 주소 검색 (Juso API)
│   ├── vworld_service.dart     # 좌표 변환, 토지 정보
│   ├── broker_service.dart     # 공인중개사 검색
│   ├── register_service.dart   # 등기부등본 조회 (CODEF API)
│   └── ...
├── models/                      # 데이터 모델
│   ├── quote_request.dart      # 견적문의 모델
│   ├── property.dart           # 부동산 모델
│   └── ...
└── utils/                       # 유틸리티
    ├── address_parser.dart     # 주소 파싱
    ├── owner_parser.dart       # 소유자 정보 추출
    └── current_state_parser.dart # 등기부등본 파싱
```

---

## 🔧 기술 스택

### Frontend
- **Framework:** Flutter 3.x (Dart)
- **상태 관리:** setState (기본), StreamBuilder (실시간 데이터)
- **UI:** Material Design 3

### Backend
- **인증:** Firebase Authentication
- **데이터베이스:** Cloud Firestore
- **호스팅:** GitHub Pages

### 외부 API
- **Juso API** (행정안전부) - 주소 검색
- **VWorld API** - 좌표 변환, 토지 정보, 공인중개사 검색
- **CODEF API** - 등기부등본 조회
- **Data.go.kr API** - 아파트 정보 조회
- **서울시 공개 API** - 공인중개사 상세 정보

---

## 📖 상세 문서 읽는 순서

1. **프로젝트 개요** (00_PROJECT_OVERVIEW.md)
   - 전체 구조 이해
   - 아키텍처 개요

2. **인증 시스템** (01_AUTHENTICATION_SYSTEM.md)
   - 로그인/회원가입
   - 세션 관리

3. **주소 검색** (02_ADDRESS_SEARCH.md)
   - 주소 검색 로직
   - 부동산 정보 조회

4. **공인중개사 찾기** (03_BROKER_SEARCH.md)
   - 중개사 검색 알고리즘
   - 필터링 및 정렬

5. **견적 요청** (04_QUOTE_REQUEST.md)
   - 견적 작성 및 전송
   - 다중 요청 처리

6. **견적 관리** (05_QUOTE_MANAGEMENT.md)
   - 견적 이력 관리
   - 답변 시스템

7. **관리자 시스템** (06_ADMIN_SYSTEM.md)
   - 관리자 대시보드
   - 수동 작업 프로세스

8. **데이터 모델** (07_DATA_MODELS.md)
   - 모든 모델 상세 설명

9. **API 서비스** (08_API_SERVICES.md)
   - 각 API 서비스 상세 설명

10. **UI 컴포넌트** (09_UI_COMPONENTS.md)
    - 화면별 상세 플로우

---

## 🎯 주요 기능 요약

### ✅ 완료된 기능

1. **사용자 인증**
   - 회원가입/로그인 (Firebase Auth)
   - 자동 로그인 (세션 유지)
   - 비밀번호 찾기

2. **주소 검색**
   - Juso API 연동
   - 페이지네이션
   - 디바운싱

3. **부동산 정보 조회**
   - 등기부등본 조회 (CODEF API)
   - 아파트 정보 조회 (Data.go.kr)
   - 토지 정보 조회 (VWorld)

4. **공인중개사 찾기**
   - 주변 중개사 검색 (VWorld)
   - 서울시 API 병합
   - 필터링 및 정렬

5. **견적 요청**
   - 개별 요청
   - 다중 요청 (MVP 핵심)
   - 상태 관리

6. **견적 관리**
   - 이력 확인
   - 견적 비교
   - 중개사 답변 확인

7. **관리자 시스템**
   - 견적문의 모니터링
   - 이메일 전송 (수동)
   - 통계 대시보드

---

## 📝 코드 읽기 가이드

각 문서는 다음 형식으로 작성됩니다:

### 코드 참조 형식
```startLine:endLine:filepath
// 실제 코드 내용
```

### 설명 형식
- **기능 설명**: 무엇을 하는지
- **코드 흐름**: 어떻게 동작하는지
- **주요 로직**: 핵심 알고리즘
- **에러 처리**: 예외 상황 처리
- **관련 파일**: 연관된 파일들

---

## 🚀 시작하기

다음 문서부터 읽어보세요:

👉 **[00_PROJECT_OVERVIEW.md](00_PROJECT_OVERVIEW.md)** - 프로젝트 개요

---

**작성 기준:**
- 모든 코드는 실제 프로젝트 코드를 기반으로 작성
- 각 기능의 동작 방식을 상세하게 설명
- 코드 라인 번호와 파일 경로 포함
- 실제 사용 예시 포함

