# 프로젝트 설치 및 실행 가이드

Flutter 기반 부동산 관리 애플리케이션입니다.

## 🚀 빠른 시작 (Quick Start)

```bash
# 1. 저장소 클론
git clone <repository-url>
cd property

# 2. 의존성 설치
flutter pub get

# 3. 로컬 설정 파일 생성
# android/local.properties 파일 생성 (아래 참조)

# 4. 실행
flutter run
```

---

## 📋 사전 요구사항

### 필수 설치
- **Flutter SDK** 3.0.0 이상 ([설치 가이드](https://flutter.dev/docs/get-started/install))
- **Android SDK** (Android Studio 설치 권장)

### 설치 확인
```bash
flutter doctor
```
모든 항목이 체크(✓)되어야 합니다.

문제가 있다면:
```bash
# Android 라이선스 동의
flutter doctor --android-licenses
```

---

## ⚙️ 설정

### 1. 샘플 이미지 추가 (선택사항)

샘플 이미지 파일들은 용량이 커서 Git에 포함되지 않습니다.

앱을 테스트하려면:
```bash
# assets 폴더에 샘플 이미지 추가
# sample_house.jpg, sample_house2.jpg, sample_house3.jpg
```

자세한 내용은 `assets/README_ASSETS.md` 참조

### 2. android/local.properties 파일 생성

프로젝트 루트에서:
```bash
touch android/local.properties
```

파일 내용 (본인의 경로로 수정):

#### Windows:
```properties
sdk.dir=C:\\Users\\YourName\\AppData\\Local\\Android\\Sdk
flutter.sdk=C:\\flutter
flutter.buildMode=debug
flutter.versionName=1.0.0
flutter.versionCode=1
```

#### macOS:
```properties
sdk.dir=/Users/yourname/Library/Android/sdk
flutter.sdk=/Users/yourname/flutter
flutter.buildMode=debug
flutter.versionName=1.0.0
flutter.versionCode=1
```

#### Linux:
```properties
sdk.dir=/home/yourname/Android/Sdk
flutter.sdk=/home/yourname/flutter
flutter.buildMode=debug
flutter.versionName=1.0.0
flutter.versionCode=1
```

#### 💡 SDK 경로 찾기:
```bash
# Android SDK 경로
echo $ANDROID_HOME          # macOS/Linux
echo $env:ANDROID_HOME      # Windows PowerShell

# Flutter SDK 경로
which flutter               # macOS/Linux
where flutter               # Windows
```

### 2. 템플릿 파일 사용 (선택)
```bash
# 템플릿 파일이 있다면
cp android/local.properties.template android/local.properties
# 그리고 에디터로 본인의 경로로 수정
```

---

## 🎯 실행 방법

### 방법 1: 기본 실행
```bash
flutter run
```

### 방법 2: 특정 기기 지정
```bash
# 사용 가능한 기기 목록 확인
flutter devices

# 특정 기기에서 실행
flutter run -d <device-id>

# Windows 데스크톱
flutter run -d windows

# Android 에뮬레이터
flutter run -d emulator-5554
```

### 방법 3: Windows 배치 파일 (Windows만 해당)
```bash
run_app.bat
```
이 스크립트는 자동으로 APK를 빌드하고 에뮬레이터에 설치합니다.

### 방법 4: PowerShell 스크립트 (Windows만 해당)
```powershell
.\copy_apk.ps1 -Install -Run
```

---

## 🔧 개발 환경 설정

### VS Code
권장 Extensions:
- Flutter
- Dart
- Flutter Intl (국제화용, 선택)

### Android Studio
권장 Plugins:
- Flutter
- Dart

---

## 🏗️ 빌드

### Android APK
```bash
# Debug 빌드
flutter build apk --debug

# Release 빌드
flutter build apk --release
```
출력 위치: `build/app/outputs/flutter-apk/`

### Windows 앱
```bash
flutter build windows
```
출력 위치: `build/windows/x64/runner/Release/`

---

## 🐛 문제 해결

### "SDK location not found" 에러
**원인**: `android/local.properties` 파일이 없거나 경로가 잘못됨

**해결**:
1. `android/local.properties` 파일 생성
2. 올바른 SDK 경로 입력
3. Windows는 백슬래시를 `\\`로 이중 작성

### "Gradle build failed" 에러
```bash
# 빌드 캐시 정리
flutter clean

# Gradle 캐시 정리
cd android
./gradlew clean
cd ..

# 의존성 재설치
flutter pub get

# 다시 실행
flutter run
```

### 의존성 설치 실패
```bash
# Pub 캐시 복구
flutter pub cache repair

# 의존성 재설치
flutter pub get
```

### Firebase 관련 에러
이 프로젝트는 Firebase를 사용합니다. 

**✅ Firebase 설정 파일이 이미 포함되어 있습니다:**
- `android/app/google-services.json`
- `lib/firebase_options.dart`

별도의 Firebase 설정 없이 바로 실행 가능합니다.

⚠️ **Public 저장소에서 클론한 경우**: Firebase 설정 파일이 보안상 제외되었을 수 있습니다. 
프로젝트 소유자에게 Firebase 설정 파일을 요청하거나, 별도의 Firebase 프로젝트를 생성하세요.

### 에뮬레이터가 보이지 않음
```bash
# 사용 가능한 에뮬레이터 목록
flutter emulators

# 에뮬레이터 실행
flutter emulators --launch <emulator_name>

# 또는 Android Studio → AVD Manager에서 생성
```

### Windows PowerShell 스크립트 실행 불가
```powershell
# 실행 정책 변경
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# 또는 일회성 실행
powershell -ExecutionPolicy Bypass -File .\copy_apk.ps1
```

---

## 📁 프로젝트 구조

```
property/
├── lib/                        # Dart 소스 코드
│   ├── main.dart              # 앱 진입점
│   ├── screens/               # 화면 UI
│   ├── models/                # 데이터 모델
│   ├── services/              # API 및 비즈니스 로직
│   ├── utils/                 # 유틸리티 함수
│   ├── widgets/               # 재사용 가능한 위젯
│   └── constants/             # 상수 정의
├── assets/                    # 리소스 파일
│   ├── contracts/             # 계약서 템플릿
│   ├── fonts/                 # 폰트 파일
│   └── download/              # 데이터 파일
├── android/                   # Android 네이티브 코드
├── ios/                       # iOS 네이티브 코드
├── windows/                   # Windows 데스크톱 코드
├── pubspec.yaml               # 패키지 의존성
└── README.md                  # 프로젝트 설명
```

---

## 🛠️ 유용한 명령어

```bash
# 의존성 설치
flutter pub get

# 프로젝트 정리
flutter clean

# 의존성 업그레이드
flutter pub upgrade

# 코드 분석
flutter analyze

# 테스트 실행
flutter test

# 연결된 기기 확인
flutter devices

# 로그 확인
flutter logs

# 핫 리로드 (앱 실행 중)
# 'r' 키 - 핫 리로드
# 'R' 키 - 핫 리스타트
# 'q' 키 - 종료
```

---

## 🔐 보안 주의사항

### Firebase 설정
이 프로젝트는 **Firebase가 이미 설정되어 있습니다.**

`android/app/google-services.json` 파일이 포함되어 있으며, 프로젝트 소유자의 Firebase 프로젝트에 연결됩니다.

**⚠️ Public 저장소로 배포하는 경우**:
Firebase API 키가 노출되므로 보안에 주의하세요. Public 저장소에 올릴 경우:
1. `.gitignore`에 Firebase 파일 추가
2. README에 Firebase 설정 가이드 작성
3. 또는 **Private 저장소 사용 권장**

**✅ Private 저장소 사용 시**: 현재 상태 그대로 사용 가능

---

## 🚀 Git 워크플로우

### 저장소 초기화 (프로젝트 소유자)
```bash
git init
git add .
git commit -m "Initial commit"
git remote add origin <repository-url>
git push -u origin main
```

### 클론 및 개발 (협업자)
```bash
# 클론
git clone <repository-url>
cd property

# 설정
flutter pub get
# android/local.properties 생성

# 브랜치 생성
git checkout -b feature/your-feature

# 개발 후 커밋
git add .
git commit -m "Add your feature"
git push origin feature/your-feature
```

---

## 📦 의존성 패키지

주요 패키지:
- `firebase_core`, `cloud_firestore` - Firebase 연동
- `sqflite` - 로컬 데이터베이스
- `http` - HTTP 요청
- `geolocator`, `geocoding` - 위치 서비스
- `webview_flutter` - 웹뷰
- `fl_chart` - 차트
- `intl` - 국제화

전체 목록은 `pubspec.yaml` 참조

---

## 📄 라이선스

MIT License

---

## 🆘 지원

문제가 발생하면:
1. `flutter doctor -v` 실행
2. 에러 로그 확인
3. Issues 탭에 버그 리포트 작성

**개발 환경**:
- Flutter: 3.32.5
- Dart SDK: 3.0.0+
- Android SDK: API 33+

---

**마지막 업데이트**: 2025년 11월 4일
