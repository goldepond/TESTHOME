# 관리자 페이지 분리 및 배포 가이드

## 개요
이 프로젝트는 **"단일 리포지토리 + 멀티 진입점(Entry Point)"** 방식을 사용하여 일반 사용자용 앱과 관리자용 웹 페이지를 분리하여 관리합니다.

- **사용자 앱:** `lib/main.dart` (관리자 기능 포함 안 됨)
- **관리자 웹:** `lib/main_admin.dart` (관리자 기능 전용)

---

## 1. 개발 환경 실행 방법

### 관리자 페이지 실행 (웹)
관리자 기능을 개발하거나 테스트할 때는 아래 명령어로 실행하세요.
```bash
flutter run -d chrome -t lib/main_admin.dart --web-port 8080
```
- `-t lib/main_admin.dart`: 시작 파일을 관리자용으로 지정합니다.
- `--web-port 8080`: 고정 포트로 실행하여 Redirect URL 설정 등을 용이하게 합니다.

### 사용자 앱 실행 (모바일/웹)
일반 사용자 기능을 개발할 때는 기존과 동일하게 실행하거나 명시적으로 `main.dart`를 지정합니다.
```bash
flutter run -t lib/main.dart
```

---

## 2. 배포(Build) 방법

배포 시에는 용도에 따라 빌드 명령어가 다릅니다.

### 관리자용 웹사이트 배포
관리자 페이지는 웹으로 빌드하여 Firebase Hosting이나 Github Pages 등에 배포합니다.
```bash
flutter build web -t lib/main_admin.dart --release
```
- 빌드 결과물은 `build/web` 폴더에 생성됩니다.
- 이 결과물에는 사용자용 불필요한 라우팅 로직보다는 관리자 대시보드가 메인으로 설정되어 있습니다.

### 사용자용 앱 배포 (Android/iOS)
사용자 앱에는 관리자 코드가 포함되지 않도록 `main.dart`를 타겟으로 빌드합니다. (Tree-shaking으로 관리자 코드 자동 제거)
```bash
# Android APK
flutter build apk -t lib/main.dart --release

# iOS (macOS 필요)
flutter build ios -t lib/main.dart --release
```

---

## 3. 구조 설명

### 파일 구조
```
lib/
├── main.dart           # [사용자용 진입점] 관리자 코드 import 없음
├── main_admin.dart     # [관리자용 진입점] 관리자 대시보드로 직행
├── screens/
│   ├── admin/          # 관리자 관련 화면들 (main.dart에서는 참조 안 함)
│   └── ...
└── ...
```

### 장점
1. **보안:** 사용자 앱을 디컴파일해도 관리자 페이지 관련 코드나 라우팅 정보가 포함되지 않습니다.
2. **유지보수:** 데이터 모델(`models`)과 API 서비스(`api_request`)를 공유하므로, 로직 수정 시 두 번 작업할 필요가 없습니다.
3. **용량 최적화:** 사용자 앱 용량이 줄어듭니다.

## 4. 주의사항
- 공통 로직(`models`, `api_request`) 수정 시 사용자 앱과 관리자 웹 양쪽에 모두 영향을 미치므로 주의 깊게 테스트해야 합니다.
- `main.dart`에는 실수로라도 `screens/admin/` 하위 파일들을 import 하지 않도록 주의하세요.

