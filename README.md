# 부동산 관리 애플리케이션

Flutter 기반의 종합 부동산 관리 플랫폼

## ✨ 주요 기능

- 📍 **주소 검색** - 공공데이터포털 API 연동
- 🏠 **부동산 등기부 조회** - 건물 정보 및 소유자 확인
- 📝 **전자 체크리스트** - 부동산 상태 점검
- 💰 **관리비 투명성** - 관리비 내역 시각화
- 📄 **스마트 계약서** - 맞춤형 특약 조항 추천
- 🔥 **Firebase 연동** - 실시간 데이터 동기화

## 🚀 시작하기

### 사전 요구사항

- Flutter SDK 3.0.0 이상
- Android SDK (Android Studio 권장)
- Git

### ✅ Firebase 설정 완료
이 프로젝트는 **Firebase가 이미 설정**되어 있습니다. 별도의 Firebase 설정 없이 바로 실행 가능합니다.

### 설치

```bash
# 저장소 클론
git clone <repository-url>
cd property

# 의존성 설치
flutter pub get

# android/local.properties 파일 생성 및 SDK 경로 설정
# 자세한 내용은 SETUP.md 참조

# 실행
flutter run
```

**자세한 설치 가이드는 [SETUP.md](SETUP.md)를 참조하세요.**

## 📱 지원 플랫폼

- ✅ Android
- ✅ Windows
- ⚠️ iOS (설정 필요)
- ⚠️ Web (부분 지원)

## 🏗️ 프로젝트 구조

```
lib/
├── main.dart              # 앱 진입점
├── screens/               # UI 화면
│   ├── home_screen.dart
│   ├── property_detail_screen.dart
│   └── ...
├── models/                # 데이터 모델
│   ├── property.dart
│   ├── checklist_item.dart
│   └── ...
├── services/              # 비즈니스 로직 및 API
│   ├── address_service.dart
│   ├── firebase_service.dart
│   └── ...
├── utils/                 # 유틸리티
├── widgets/               # 재사용 가능한 위젯
└── constants/             # 상수
```

## 🔧 기술 스택

### 프레임워크
- **Flutter** - UI 프레임워크
- **Dart** - 프로그래밍 언어

### 주요 패키지
- `firebase_core` / `cloud_firestore` - Firebase 백엔드
- `sqflite` - 로컬 SQLite 데이터베이스
- `http` - REST API 통신
- `geolocator` / `geocoding` - 위치 기반 서비스
- `fl_chart` - 데이터 시각화
- `webview_flutter` - 웹뷰 렌더링

전체 의존성: [pubspec.yaml](pubspec.yaml)

## 📖 문서

- [설치 및 실행 가이드](SETUP.md) - 개발 환경 설정
- [개발자 가이드](SETUP_DEV.md) - 빠른 시작
- [HOW 문서](lib/HOW/) - 기능별 상세 가이드

## 🛠️ 개발

### 개발 서버 실행
```bash
flutter run
```

### 빌드
```bash
# Android APK (Debug)
flutter build apk --debug

# Android APK (Release)
flutter build apk --release

# Windows
flutter build windows
```

### 테스트
```bash
flutter test
```

### 코드 정리
```bash
flutter clean
flutter pub get
```

## 🤝 기여 방법

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 🐛 버그 리포트

버그를 발견하셨나요? [Issues](../../issues)에 리포트해주세요.

리포트 시 포함할 정보:
- 에러 메시지 전문
- `flutter doctor -v` 출력
- 재현 단계
- 예상 동작 vs 실제 동작

## 📄 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다. 자세한 내용은 [LICENSE](LICENSE) 파일을 참조하세요.

## 👥 제작자

프로젝트 개발자 정보

## 🙏 감사의 말

- Flutter 팀
- Firebase
- 공공데이터포털 API
- 오픈소스 커뮤니티

---

**개발 환경**: Flutter 3.32.5 | Dart 3.0.0+ | Android API 33+

**마지막 업데이트**: 2025년 10월 12일
