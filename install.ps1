Set-Location "C:\Users\chahy\OneDrive\문서\GitHub\odd-app"

Write-Host "===================================" -ForegroundColor Cyan
Write-Host " ODD 앱 빌드 + 설치" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan

Write-Host "`n[1/5] flutter pub get..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) { Write-Host "[오류] pub get 실패" -ForegroundColor Red; Read-Host "Enter 키로 종료"; exit 1 }

Write-Host "`n[2/5] 전체 캐시 초기화..." -ForegroundColor Yellow
flutter clean
if (Test-Path "android\app\build") { Remove-Item -Recurse -Force "android\app\build" }

Write-Host "`n[3/5] APK 빌드 중... (2~3분 소요)" -ForegroundColor Yellow
flutter build apk --debug --android-skip-build-dependency-validation

Write-Host "`n[4/5] APK 파일 위치 확인..." -ForegroundColor Yellow
$apkPath = $null

if (Test-Path "build\app\outputs\flutter-apk\app-debug.apk") {
    $apkPath = "build\app\outputs\flutter-apk\app-debug.apk"
    Write-Host "[OK] Flutter 빌드 경로에서 발견: $apkPath" -ForegroundColor Green
} elseif (Test-Path "android\app\build\outputs\flutter-apk\app-debug.apk") {
    $apkPath = "android\app\build\outputs\flutter-apk\app-debug.apk"
    Write-Host "[OK] Android 빌드 경로에서 발견: $apkPath" -ForegroundColor Green
} else {
    Write-Host "[오류] APK 파일 없음 - 빌드 실패" -ForegroundColor Red
    Read-Host "Enter 키로 종료"
    exit 1
}

Write-Host "`n[5/5] 갤럭시에 설치 중 (R39M30ERHSH)..." -ForegroundColor Yellow
adb -s R39M30ERHSH install -r $apkPath
if ($LASTEXITCODE -ne 0) { Write-Host "[오류] 설치 실패" -ForegroundColor Red; Read-Host "Enter 키로 종료"; exit 1 }

Write-Host "`n===================================" -ForegroundColor Cyan
Write-Host " 완료! ODD 앱 열어보세요 :)" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan
