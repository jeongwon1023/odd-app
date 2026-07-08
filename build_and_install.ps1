# ─────────────────────────────────────────────
# ODD 앱 빌드 & 설치 자동화 스크립트
# ★ robocopy 로 동기화 (한글 경로 완벽 지원)
# ★ C:\dev\odd-app 에서 빌드 (한글 경로 우회)
# ★ flutter analyze 로 컴파일 전 오류 사전 감지
# ★ APK 경로 재귀 탐색 (AGP 버전별 경로 차이 대응)
# 사용: PowerShell에서 .\build_and_install.ps1 실행
# ─────────────────────────────────────────────

$SRC  = "C:\Users\chahy\OneDrive\문서\GitHub\odd-app"
$DEST = "C:\dev\odd-app"
# APK 경로는 빌드 후 재귀 탐색으로 결정 (하단 참조)
$APK  = ""

function Log($msg) { Write-Host "`n[ODD] $msg" -ForegroundColor Cyan }
function Ok($msg)  { Write-Host "[OK] $msg"   -ForegroundColor Green }
function Err($msg) { Write-Host "[ERR] $msg"  -ForegroundColor Red; exit 1 }

function RoboCp($from, $to, $excludeDirs = @()) {
  $args = @($from, $to, '/E', '/PURGE', '/NP', '/NFL', '/NDL', '/NS', '/NC', '/NJS', '/NJH')
  foreach ($d in $excludeDirs) { $args += "/XD"; $args += $d }
  robocopy @args | Out-Null
  # robocopy 반환코드 0-7 은 정상 (8 이상이 실제 오류)
  if ($LASTEXITCODE -ge 8) { Err "robocopy 실패: $from → $to (코드 $LASTEXITCODE)" }
}

# ── 버전 확인 ──────────────────────────────────
$bi = Get-Content "$SRC\lib\config\build_info.dart" -Raw -EA SilentlyContinue
if ($bi -match "version\s*=\s*'([^']+)'") { Log "ODD v$($Matches[1]) 빌드 시작" }
else { Log "빌드 시작" }

# ── 1. 대상 폴더 보장 + Gradle 캐시 + 데몬 클린 ──
if (!(Test-Path $DEST)) { New-Item -ItemType Directory $DEST -Force | Out-Null }

# Gradle 데몬 중지 (gradle.properties 변경 시 데몬이 구 설정 캐시를 물고 있을 수 있음)
$gradlew = "$DEST\android\gradlew.bat"
if (Test-Path $gradlew) {
  & $gradlew --stop 2>$null | Out-Null
  Ok "Gradle 데몬 중지"
}

# 프로젝트 .gradle 캐시 클린 (플러그인 버전 변경 시 충돌 방지)
$gradleCache = "$DEST\android\.gradle"
if (Test-Path $gradleCache) {
  Remove-Item $gradleCache -Recurse -Force -EA SilentlyContinue
  Ok ".gradle 캐시 클린 완료"
}

# ── 2. robocopy 동기화 ─────────────────────────
Log "robocopy 동기화 중... ($SRC → $DEST)"

# lib 전체
RoboCp "$SRC\lib"     "$DEST\lib"
# android (build/.gradle 제외)
RoboCp "$SRC\android" "$DEST\android" @('build', '.gradle')
# assets
if (Test-Path "$SRC\assets") { RoboCp "$SRC\assets" "$DEST\assets" }

# 단일 파일들
foreach ($f in @('pubspec.yaml','pubspec.lock','analysis_options.yaml')) {
  $s = "$SRC\$f"
  if (Test-Path $s) { Copy-Item $s "$DEST\$f" -Force }
}
Ok "동기화 완료"

# ── 3. 버전 재확인 ─────────────────────────────
$biD = Get-Content "$DEST\lib\config\build_info.dart" -Raw -EA SilentlyContinue
if ($biD -match "version\s*=\s*'([^']+)'") { Ok "빌드 버전 확인: v$($Matches[1])" }
else { Err "build_info.dart 동기화 실패" }

Push-Location $DEST

# ── 4. pub get ─────────────────────────────────
Log "flutter pub get..."
flutter pub get
if ($LASTEXITCODE -ne 0) { Pop-Location; Err "flutter pub get 실패" }
Ok "패키지 준비 완료"

# ── 5. flutter analyze ─────────────────────────
Log "flutter analyze (오류 사전 감지)..."
$analyzeOut = flutter analyze --no-pub 2>&1
$errors = $analyzeOut | Where-Object { $_ -match "^\s+error •" }
if ($errors.Count -gt 0) {
  Pop-Location
  Write-Host "`n[ANALYZE] 빌드 전 수정 필요한 오류:" -ForegroundColor Yellow
  $errors | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
  # 에러를 OneDrive 저장소에 파일로도 저장 (분석/자동수정용)
  $errors | Out-File -FilePath "C:\Users\chahy\OneDrive\문서\GitHub\odd-app\analyze_errors.txt" -Encoding UTF8
  Err "analyze 오류 발견 — 빌드 중단"
}
Ok "analyze 통과 (error 없음)"

# ── 6. APK 빌드 ────────────────────────────────
Log "flutter build apk --release (2~3분 소요)..."
flutter build apk --release
$buildExit = $LASTEXITCODE

# Flutter 빌드 출력 경로 우선, 없으면 Gradle 직접 출력 경로도 탐색
# Flutter 경로: $DEST\build\app\outputs\flutter-apk\
# Gradle 경로:  $DEST\android\app\build\outputs\apk\release\
$searchPaths = @("$DEST\build", "$DEST\android\app\build")
$APK = $null
foreach ($sp in $searchPaths) {
  if (Test-Path $sp) {
    $found = Get-ChildItem -Path $sp -Recurse -Filter "*.apk" -EA SilentlyContinue |
             Where-Object { $_.Name -notmatch "unsigned" } |
             Sort-Object LastWriteTime -Descending |
             Select-Object -First 1 -ExpandProperty FullName
    if ($found) { $APK = $found; break }
  }
}
# signed 없으면 unsigned도 허용
if (-not $APK) {
  foreach ($sp in $searchPaths) {
    if (Test-Path $sp) {
      $found = Get-ChildItem -Path $sp -Recurse -Filter "*.apk" -EA SilentlyContinue |
               Sort-Object LastWriteTime -Descending |
               Select-Object -First 1 -ExpandProperty FullName
      if ($found) { $APK = $found; break }
    }
  }
}

if ($APK) {
  Ok "APK 빌드 완료: $APK"
} else {
  # APK가 전혀 없음 — build/app/outputs 구조 출력해서 원인 파악
  Write-Host "`n[ODD] build 디렉토리 상태 확인..." -ForegroundColor Yellow
  $outputsDir = "$DEST\build\app\outputs"
  if (Test-Path $outputsDir) {
    Write-Host "  build\app\outputs 내 파일 목록:" -ForegroundColor Yellow
    Get-ChildItem -Path $outputsDir -Recurse -EA SilentlyContinue |
      ForEach-Object { Write-Host "    $($_.FullName)" -ForegroundColor Gray }
  } else {
    Write-Host "  build\app\outputs 디렉토리 없음 — Gradle이 실행되지 않았거나 경로 오류" -ForegroundColor Red
    # build 최상위라도 확인
    if (Test-Path "$DEST\build") {
      Write-Host "  build\ 내 디렉토리:" -ForegroundColor Yellow
      Get-ChildItem -Path "$DEST\build" -Depth 3 -EA SilentlyContinue |
        ForEach-Object { Write-Host "    $($_.FullName)" -ForegroundColor Gray }
    } else {
      Write-Host "  C:\dev\odd-app\build 자체가 없음" -ForegroundColor Red
    }
  }
  Pop-Location
  Err "APK 없음 — 위 경로 목록으로 원인 파악 필요"
}
Pop-Location

# ── 7. APK 설치 ────────────────────────────────
Log "기기에 APK 설치 중..."
adb install -r $APK
if ($LASTEXITCODE -ne 0) { Err "adb install 실패 (기기 연결 및 저장공간 확인)" }

Ok "=============================="
Ok " ODD 앱 설치 완료!"
Ok " APK: $APK"
Ok "=============================="
