@echo off
chcp 65001 >nul
echo ========================================
echo Flutter 앱 빌드 및 실행 스크립트
echo ========================================
echo.

echo 1. Android APK 빌드 중...
cd android
call gradlew assembleDebug
if %ERRORLEVEL% neq 0 (
    echo APK 빌드 실패!
    pause
    exit /b 1
)
cd ..

echo.
echo 2. APK 복사 및 설치 중...
powershell -ExecutionPolicy Bypass -File copy_apk.ps1 -Install -Run

echo.
echo 완료!
pause 