# Git 저장소 설정 가이드

프로젝트가 최적화되었습니다! 이제 Git에 올릴 준비가 완료되었습니다.

## 📊 최적화 결과

### 삭제된 항목
✅ `build/` - Flutter 빌드 결과물  
✅ `android/build/` - Android 빌드 결과물  
✅ `android/.gradle/` - Gradle 캐시 (19.92MB)  
✅ `.dart_tool/` - Dart 도구 캐시  
✅ `target/` - Maven 빌드 결과물  
✅ `src/` - Java 소스 (Flutter 프로젝트에 불필요)  
✅ `property.db` - 로컬 데이터베이스  
✅ `android/local.properties` - 로컬 SDK 경로  
✅ `*.iml` - IntelliJ 모듈 파일  
✅ Maven 관련 파일 (`pom.xml`, `mvnw.cmd`)  

### .gitignore에 추가됨 (Git에서 제외)
⚠️ `assets/sample_house*.jpg` - 샘플 이미지 (26.34MB)  
⚠️ `android/.gradle/` - Gradle 캐시  
⚠️ `android/local.properties` - 로컬 설정  

### 예상 크기
- **정리 전**: ~500MB - 2GB
- **현재 전체**: ~91MB
- **Git 업로드 예상**: ~60MB (샘플 이미지 제외)

---

## 🚀 Git 저장소 생성

### 1단계: Git 초기화
```bash
# Git 초기화
git init

# 현재 상태 확인
git status
```

### 2단계: 파일 추가
```bash
# 모든 파일 스테이징 (.gitignore가 자동으로 불필요한 파일 제외)
git add .

# 스테이징된 파일 확인
git status
```

### 3단계: 첫 커밋
```bash
git commit -m "Initial commit: Property management Flutter app"
```

---

## 📤 GitHub에 업로드

### 방법 1: GitHub 웹에서 저장소 생성 후
```bash
# 원격 저장소 연결
git remote add origin https://github.com/your-username/property.git

# 푸시
git push -u origin main
```

### 방법 2: GitHub CLI 사용
```bash
# GitHub CLI로 저장소 생성 및 푸시
gh repo create property --private --source=. --push
```

---

## ⚠️ 업로드 전 확인사항

### Firebase 설정

✅ **Firebase 설정 파일이 포함되어 있습니다:**
- `android/app/google-services.json`
- `lib/firebase_options.dart`

협업자들이 클론하면 **별도 설정 없이 바로 실행 가능**합니다.

**저장소 타입 선택:**

#### 옵션 A: Private 저장소 ⭐ (권장)
```bash
# GitHub에서 Private 저장소 생성
gh repo create property --private --source=. --push
```
- ✅ Firebase 키가 안전하게 보호됨
- ✅ 협업자들이 바로 사용 가능
- ✅ 추가 설정 불필요

#### 옵션 B: Public 저장소
⚠️ **Firebase API 키가 공개됩니다!**

Public 저장소로 올리기 전 보안 조치:
```bash
# .gitignore에 Firebase 파일 추가 (주석 제거)
# 그리고 캐시에서 제거
git rm --cached android/app/google-services.json
git rm --cached lib/firebase_options.dart
git commit -m "Remove Firebase config for security"
```

**Public 저장소 권장하지 않음** - Private 저장소 사용을 강력히 권장합니다.

---

## 🔍 Git 상태 확인

### 추적되지 않는 파일 확인
```bash
# .gitignore가 제대로 작동하는지 확인
git status

# 예상 결과: build/, .dart_tool/, sample_house*.jpg 등이 보이지 않아야 함
```

### 파일 크기 확인
```bash
# Git에 추가될 파일 크기 확인 (PowerShell)
git ls-files | ForEach-Object { Get-Item $_ } | Measure-Object -Property Length -Sum | Select-Object @{Name='Size(MB)';Expression={[math]::Round($_.Sum/1MB, 2)}}
```

---

## 🛠️ 협업자 온보딩

다른 개발자가 클론할 때:

```bash
# 1. 클론
git clone https://github.com/your-username/property.git
cd property

# 2. 의존성 설치
flutter pub get

# 3. 로컬 설정 (android/local.properties 생성)
# SETUP.md 참조

# 4. 샘플 이미지 추가 (선택)
# assets/README_ASSETS.md 참조

# 5. 실행
flutter run
```

---

## 📝 .gitignore 최적화 완료

`.gitignore`에 포함된 주요 항목:
- ✅ 빌드 결과물 (`build/`, `android/build/`)
- ✅ IDE 설정 (`.idea/`, `*.iml`)
- ✅ 의존성 캐시 (`.dart_tool/`, `.pub/`)
- ✅ 로컬 설정 (`android/local.properties`)
- ✅ 데이터베이스 (`*.db`)
- ✅ Gradle 캐시 (`android/.gradle/`)
- ✅ 큰 샘플 이미지 (`assets/sample_house*.jpg`)

---

## 🔄 지속적인 유지관리

### 정기적인 정리
```bash
# Flutter 캐시 정리
flutter clean

# Gradle 캐시 정리
cd android
./gradlew clean
cd ..
```

### 큰 파일 확인
```bash
# 5MB 이상 파일 찾기
Get-ChildItem -Recurse -File | Where-Object { $_.Length -gt 5MB } | Select-Object FullName, @{Name='Size(MB)';Expression={[math]::Round($_.Length/1MB, 2)}}
```

### Git 히스토리 정리 (필요시)
```bash
# 실수로 큰 파일을 커밋한 경우
git filter-branch --tree-filter 'rm -rf build' HEAD
# 또는 BFG Repo-Cleaner 사용
```

---

## ✅ 최종 체크리스트

업로드 전 확인:
- [ ] `flutter clean` 실행 완료
- [ ] `.gitignore` 확인
- [ ] Firebase 보안 설정 확인 (Private/Public 선택)
- [ ] `README.md` 및 `SETUP.md` 업데이트
- [ ] `git status`로 불필요한 파일 확인
- [ ] 저장소 타입 결정 (Private/Public)

---

## 🆘 문제 해결

### "파일이 너무 큽니다" 에러
```bash
# Git LFS 설정 (100MB 이상 파일)
git lfs install
git lfs track "*.jpg"
git add .gitattributes
```

### 이미 커밋한 큰 파일 제거
```bash
# 캐시에서 제거
git rm --cached <large-file>
git commit -m "Remove large file"
```

---

**준비 완료!** 이제 `git push`하시면 됩니다! 🚀

