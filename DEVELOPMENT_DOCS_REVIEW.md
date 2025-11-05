# 📁 개발 문서 폴더 정리

> 작성일: 2025-01-XX  
> 3번: 개발 문서 폴더 검토 및 정리

---

## ✅ 1번, 2번 정리 완료

### 1번: 즉시 삭제 완료
- ✅ `lib/constants/app_constants_template.dart` 삭제
- ✅ `public/index.html` 삭제
- ✅ `web/test_markers.html` 삭제
- ✅ `test/widget_test.dart` 삭제
- ✅ `assets/sample_house.jpg` 삭제
- ✅ `assets/sample_house2.jpg` 삭제
- ✅ `assets/sample_house3.jpg` 삭제
- ✅ `assets/assets.zip` 삭제

### 2번: pubspec.yaml 정리 완료
- ✅ 주석 처리된 `flutter_pdfview` 제거
- ✅ 삭제된 샘플 이미지 3개를 assets에서 제거
- ✅ 미사용 `sqflite` 패키지 3개 제거 (`sqflite`, `sqflite_common_ffi`, `sqflite_common_ffi_web`)

---

## 📋 3번: 개발 문서 폴더 목록

### 1️⃣ `lib/HOW/` 폴더 (11개 파일)

개발 가이드 문서 모음

#### 파일 목록:
1. `how.txt` - 부동산 관리 앱 세부 프로세스 분석
2. `how_address_search.txt` - 주소 검색 프로세스
3. `how_contract_creation.txt` - 계약서 작성 프로세스
4. `how_detail_form.txt` - 상세 폼 작성
5. `how_electronic_checklist.txt` - 전자 체크리스트
6. `how_maintenance_fee_transparency.txt` - 관리비 투명성
7. `how_overview.txt` - 전체 개요
8. `how_property_management.txt` - 매물 관리
9. `how_register_lookup.txt` - 등기부등본 조회
10. `how_smart_clause_recommendation.txt` - 스마트 특약 조항 추천
11. `how_utils_functions.txt` - 유틸리티 함수

**용도:** 개발 가이드 문서, 프로세스 설명, 코드 구조 설명

---

### 2️⃣ `_AI_Doc/` 폴더 (17개 파일)

AI 개발 문서 모음

#### 파일 목록:
1. `README.md` - AI 문서 메인 README
2. `README_ASSETS.md` - 에셋 관련 README
3. `ADMIN_QUOTE_REQUEST_SYSTEM.md` - 관리자 견적문의 시스템
4. `BROKER_API_VERIFICATION.md` - 중개사 API 검증
5. `BROKER_FEATURE.md` - 중개사 기능
6. `BROKER_UI_IMPROVEMENT.md` - 중개사 UI 개선
7. `DEPLOYMENT_GUIDE.md` - 배포 가이드
8. `FEATURE_OVERVIEW.md` - 기능 개요
9. `IMPROVEMENTS_REQUIRED.md` - 필요한 개선사항
10. `MOBILE_READINESS_CHECKLIST.md` - 모바일 준비 체크리스트
11. `MVP_GOAL_ANALYSIS.md` - MVP 목표 분석
12. `QA_SCENARIOS.md` - QA 시나리오
13. `REGISTER_FEATURE_TOGGLE.md` - 등기부등본 기능 토글
14. `RELEASE_CHECKLIST.md` - 릴리스 체크리스트
15. `SETUP.md` - 설정 가이드
16. `SYSTEM_FLOW_COMPLETE.md` - 시스템 플로우 완성
17. `TEST_EXPLANATION_SIMPLE.md` - 테스트 설명 간단 버전

**용도:** AI 개발 과정 문서, 기능 설명, 릴리스 및 배포 관련

---

## 📊 통계

- **`lib/HOW/` 폴더:** 11개 파일 (~100-500KB)
- **`_AI_Doc/` 폴더:** 17개 파일 (~500KB-2MB)
- **총 예상 용량:** ~600KB-2.5MB

---

## 💡 정리 옵션

### 옵션 1: 완전 삭제
- ✅ 프로덕션 빌드 크기 감소
- ✅ 프로젝트 구조 간소화
- ❌ 개발 히스토리 손실

### 옵션 2: 보관 (권장)
- ✅ 개발 히스토리 보존
- ✅ 향후 참고 가능
- ❌ 프로젝트 크기 증가 (미미함)

### 옵션 3: 별도 저장소로 이동
- ✅ 프로젝트는 깔끔하게 유지
- ✅ 개발 문서는 별도 보관
- ⚠️ 관리 복잡도 증가

---

## ✅ 정리할 파일 선택

아래에서 삭제할 파일/폴더를 알려주시면 정리하겠습니다:

### `lib/HOW/` 폴더
- [ ] 전체 삭제
- [ ] 특정 파일만 삭제 (파일명 지정)

### `_AI_Doc/` 폴더
- [ ] 전체 삭제
- [ ] 특정 파일만 삭제 (파일명 지정)

---

**어떤 파일들을 삭제할지 알려주세요!** 🗑️
