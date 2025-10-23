@echo off
chcp 65001 >nul
echo ========================================
echo 🚀 GitHub Pages 배포 스크립트
echo ========================================
echo.

echo [1/4] 📦 Flutter 웹 빌드 중...
flutter build web --release --base-href "/TESTHOME/"

if errorlevel 1 (
    echo ❌ 빌드 실패!
    pause
    exit /b 1
)

echo.
echo [2/4] ✅ 빌드 완료!
echo.

echo [3/4] 📤 Git에 push 중...
git add .
git commit -m "Deploy: Update web build"
git push origin main

if errorlevel 1 (
    echo ⚠️ Git push 실패 또는 변경사항 없음
    echo 💡 GitHub Actions가 자동으로 배포합니다
) else (
    echo ✅ Git push 완료!
    echo 💡 GitHub Actions가 자동으로 배포합니다
)

echo.
echo [4/4] ========================================
echo ✅ 배포 프로세스 완료!
echo.
echo 🌐 배포 상황 확인:
echo    https://github.com/goldepond/TESTHOME/actions
echo.
echo 🌐 배포 완료 후 접속 (2-3분 소요):
echo    https://goldepond.github.io/TESTHOME/
echo ========================================
echo.
pause

