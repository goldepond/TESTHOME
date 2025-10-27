# 🚀 GitHub Pages 배포 가이드

## 📋 배포 전 체크리스트

### 1. GitHub 저장소 설정
- ✅ 저장소: `goldepond/TESTHOME`
- ✅ 메인 브랜치: `main`

### 2. GitHub Pages 활성화 (최초 1회만)

1. GitHub 저장소로 이동: https://github.com/goldepond/TESTHOME
2. **Settings** (설정) 클릭
3. 왼쪽 메뉴에서 **Pages** 클릭
4. **Source** 섹션에서:
   - **Branch**: `gh-pages` 선택
   - **Folder**: `/ (root)` 선택
5. **Save** 클릭

---

## 🎯 배포 방법

### 방법 1: 자동 배포 (GitHub Actions) ⭐ 추천

코드를 main 브랜치에 push하면 자동으로 배포됩니다.

```bash
git add .
git commit -m "배포할 내용"
git push origin main
```

또는 윈도우에서:

```bash
deploy_github_pages.bat
```

배포 스크립트가 자동으로:
1. Flutter 웹 빌드
2. Git에 커밋 & push
3. GitHub Actions가 자동 배포

---

### 방법 2: 수동 배포

GitHub에서 수동으로 배포 트리거:

1. https://github.com/goldepond/TESTHOME/actions
2. **Deploy to GitHub Pages** 워크플로우 선택
3. **Run workflow** 버튼 클릭
4. **Run workflow** 확인

---

## 🌐 배포 확인

### 배포 진행 상황 확인
https://github.com/goldepond/TESTHOME/actions

### 배포 완료 후 접속 (2-3분 소요)
https://goldepond.github.io/TESTHOME/

---

## 🔧 설정 파일

### `.github/workflows/deploy.yml`
GitHub Actions 자동 배포 설정 파일

### `deploy_github_pages.bat`
Windows용 원클릭 배포 스크립트

---

## ⚠️ 문제 해결

### 1. 404 에러 발생
**원인**: GitHub Pages 설정이 안되어 있음

**해결**:
- Settings > Pages > Source에서 `gh-pages` 브랜치 선택

### 2. GitHub Actions 실패
**확인사항**:
- https://github.com/goldepond/TESTHOME/actions 에서 에러 로그 확인
- Flutter 빌드 에러인 경우 로컬에서 `flutter build web` 테스트

### 3. Firebase 연동 안됨
**원인**: 웹용 Firebase 설정 필요

**해결**:
- Firebase Console에서 웹 앱 추가
- `web/index.html`에 Firebase config 추가

---

## 📝 배포 후 작업

### 1. 커스텀 도메인 설정 (선택)

도메인이 있다면:
1. Settings > Pages > Custom domain
2. 도메인 입력 (예: `myapp.com`)
3. DNS 설정에서 CNAME 추가

### 2. HTTPS 강제
Settings > Pages > **Enforce HTTPS** 체크

---

## 🎉 배포 완료!

웹사이트 주소:
**https://goldepond.github.io/TESTHOME/**

이제 코드를 수정하고 push하면 자동으로 배포됩니다! 🚀

