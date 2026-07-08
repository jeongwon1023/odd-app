# ODD 앱 — 셋업 가이드

## 아키텍처 개요

```
앱 시작
  └─ SplashScreen
       ├─ GPS 위치 획득 (geolocator)
       ├─ OpenWeather 역지오코딩 → 한국 지역명
       ├─ SharedPreferences 캐시 확인 (24h 유효)
       │   └─ 없으면 네이버 로컬 검색 API 호출
       └─ MainNav (홈 + 채팅 탭)

채팅 탭 (데이트 상담)
  └─ 선호도 수집 (분위기/시간/면류/예산)
       ├─ 네이버 검색으로 주변 장소 조회
       ├─ Gemini 1.5 Flash → 코스 3개 JSON 생성
       └─ CourseResultScreen → MapScreen
```

## ▶️ iOS (iPhone) 실행 방법

```bash
cd odd_app

# 1. Flutter 패키지 설치
flutter pub get

# 2. CocoaPods 설치 (처음 한 번만)
cd ios && pod install && cd ..

# 3. iPhone 연결 후 실행
flutter run
# 또는 Xcode에서 ios/Runner.xcworkspace 열고 실행
```

> **주의**: `Runner.xcodeproj` 가 아니라 **`Runner.xcworkspace`** 로 Xcode를 열어야 합니다.

## ▶️ Android 실행 방법

```bash
flutter pub get
flutter run
```

## API 키 현황 (모두 적용 완료)

| 서비스 | 파일 | 상태 |
|--------|------|------|
| 네이버 지도 (NCP) | `env.dart` + `AndroidManifest.xml` + `Info.plist` | ✅ |
| 네이버 검색 API | `env.dart` | ✅ |
| OpenWeather | `env.dart` | ✅ |
| Gemini AI | `env.dart` | ✅ |

## 전체 파일 구조

```
lib/
├── main.dart
├── config/env.dart
├── models/place_model.dart
├── services/
│   ├── location_service.dart      # GPS + OpenWeather 역지오코딩
│   ├── naver_place_service.dart   # 네이버 로컬 검색 API
│   ├── gemini_service.dart        # Gemini 1.5 Flash 코스 생성
│   └── cache_service.dart         # SharedPreferences 24h 캐시
├── screens/
│   ├── splash_screen.dart
│   ├── main_nav.dart
│   ├── home_screen.dart
│   ├── chat_screen.dart
│   ├── course_result_screen.dart
│   ├── place_detail_screen.dart
│   └── map_screen.dart
├── widgets/place_card.dart
└── utils/app_theme.dart

ios/                               # iPhone 빌드
  Runner.xcworkspace               # ← Xcode에서 이걸 열어야 함
  Runner.xcodeproj/
  Runner/
    AppDelegate.swift
    Info.plist                     # 네이버 지도 키 + 위치 권한
    ...

android/                           # Android 빌드
  app/src/main/
    AndroidManifest.xml            # 네이버 지도 키 + 위치 권한
    kotlin/com/odd/app/MainActivity.kt
```

## Golden Rules 준수

- **Rule 1 (큐레이션)**: 네이버 검색 결과를 Gemini가 선별 → API 쿼리 노출 없음
- **Rule 2 (폴백)**: 지역 검색 실패 → 지역 없이 재검색 → Gemini 폴백 코스
- **Rule 3 (성능)**: SharedPreferences 로컬 캐시 우선(24h), 홈은 캐시된 데이터 즉시 표시
- **Rule 4 (UX)**: 기술 용어 완전 제거, 데이트 감성 언어만 사용
