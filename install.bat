@echo off
cd /d "C:\Users\chahy\OneDrive\문서\GitHub\odd-app"

echo ===================================
echo  ODD 앱 빌드 + 설치
echo ===================================
echo.

echo [1/5] flutter pub get...
call flutter pub get
if %errorlevel% neq 0 ( echo [오류] pub get 실패 & pause & exit /b )

echo.
echo [2/5] 전체 캐시 초기화 (build + android/app/build)...
call flutter clean
if exist "android\app\build" rmdir /s /q "android\app\build"

echo.
echo [3/5] APK 빌드 중... (2~3분 소요)
call flutter build apk --debug --android-skip-build-dependency-validation
REM Flutter가 경로 문제로 오류를 보고해도 Gradle이 성공하면 APK는 android 빌드 경로에 존재함

echo.
echo [4/5] APK 파일 위치 확인...

REM Flutter 표준 출력 경로 먼저 확인
if exist "build\app\outputs\flutter-apk\app-debug.apk" (
    set APK_PATH=build\app\outputs\flutter-apk\app-debug.apk
    echo [OK] Flutter 빌드 경로에서 발견: %APK_PATH%
    goto :install
)

REM OneDrive 한글 경로 이슈로 Gradle 직접 출력 경로 확인
if exist "android\app\build\outputs\flutter-apk\app-debug.apk" (
    set APK_PATH=android\app\build\outputs\flutter-apk\app-debug.apk
    echo [OK] Android 빌드 경로에서 발견: %APK_PATH%
    goto :install
)

echo [오류] APK 파일을 찾을 수 없습니다. 빌드가 실패했습니다.
echo.
echo 아래 명령어로 Gradle 오류를 확인하세요:
echo flutter build apk --debug --android-skip-build-dependency-validation 2^>^&1 ^| Select-String "error" ^| Select-Object -Last 20
pause
exit /b 1

:install
echo.
echo [5/5] 갤럭시에 설치 중 (R39M30ERHSH)...
adb -s R39M30ERHSH install -r "%APK_PATH%"
if %errorlevel% neq 0 ( echo [오류] 설치 실패 & pause & exit /b )

echo.
echo ===================================
echo  완료! ODD 앱 열어보세요 :)
echo ===================================
pause
