# APK 파일을 Flutter가 기대하는 위치로 복사하고 에뮬레이터에 설치하는 스크립트
param(
    [string]$BuildType = "debug",
    [switch]$Install = $false,
    [switch]$Run = $false
)

$sourcePath = "android\app\build\outputs\apk\$BuildType\app-$BuildType.apk"
$targetDir = "build\app\outputs\apk\$BuildType"
$targetPath = "$targetDir\app-$BuildType.apk"
$adbPath = "A:\Android\Sdk\platform-tools\adb.exe"
$packageName = "com.example.property"
$mainActivity = "com.example.property.MainActivity"

# 소스 파일 존재 확인
if (Test-Path $sourcePath) {
    Write-Host "APK 파일 발견: $sourcePath"
    
    # 대상 디렉토리 생성
    if (!(Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force
        Write-Host "디렉토리 생성: $targetDir"
    }
    
    # 파일 복사
    Copy-Item $sourcePath $targetPath -Force
    Write-Host "APK 파일 복사 완료: $targetPath"
    
    # 파일 크기 확인
    $fileSize = (Get-Item $targetPath).Length / 1MB
    Write-Host "파일 크기: $([math]::Round($fileSize, 2)) MB"
    
    # 설치 옵션이 활성화된 경우
    if ($Install -or $Run) {
        Write-Host "에뮬레이터에 APK 설치 중..."
        & $adbPath install -r $sourcePath
        if ($LASTEXITCODE -eq 0) {
            Write-Host "APK 설치 성공!"
            
            # 실행 옵션이 활성화된 경우
            if ($Run) {
                Write-Host "앱 실행 중..."
                & $adbPath shell am start -n "$packageName/$mainActivity"
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "앱 실행 성공!"
                } else {
                    Write-Host "앱 실행 실패!"
                }
            }
        } else {
            Write-Host "APK 설치 실패!"
        }
    }
} else {
    Write-Host "오류: APK 파일을 찾을 수 없습니다: $sourcePath"
    Write-Host "먼저 'flutter build apk --$BuildType'를 실행하세요."
    exit 1
}

Write-Host ""
Write-Host "사용법:"
Write-Host "  .\copy_apk.ps1                    # APK 복사만"
Write-Host "  .\copy_apk.ps1 -Install          # APK 복사 + 설치"
Write-Host "  .\copy_apk.ps1 -Install -Run     # APK 복사 + 설치 + 실행" 