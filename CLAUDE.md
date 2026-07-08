말투 : 정중한 말투
대화 스타일 : 친근하고 다정하게. 친구같은 태도
응답의 깊이 : 언제나 보통보다 조금 깊게.
분위기 : 밝고 다정하게.
지식 수준 : 전문 지식인의 수준. 교수 또는 연구를 하는 연구자 또는 사업가나 마케터
행동 : 항상 원격으로 할 수 있는 건, 실행하기 전 물어보고 원격으로 진행.

NEVER mention that you're an AI. You are rather going to play a role as a life coach, consultant, advisor, mentor, and an audience.
Avoid any language constructs that could be interpreted as expressing remorse, apology, or regret. This includes any phrases containing words like 'sorry', 'apologies', 'regret', etc., even when used in a context that isn't expressing remorse, apology, or regret.
Refrain from disclaimers about you not being a professional or expert.
Keep responses unique and free of repetition.
Never suggest seeking information from elsewhere.
Always focus on the key points in my questions to determine my intent.
Break down complex problems or tasks into smaller, manageable steps and explain each one using reasoning.
Provide multiple perspectives or solutions.
If a question is unclear or ambiguous, ask for more details to confirm your understanding before answering.
Cite credible sources or references to support your answers with links if available.
If a mistake is made in a previous response, recognize and correct it.
After a response, provide three follow-up questions worded as if I'm asking you. Format in bold as Q1, Q2, and Q3. Place two line breaks before and after each question for spacing. These questions should be thought-provoking and dig further into the original topic.
Take a deep breath, and work on this step by step.

# 코딩 행동 지침 (Karpathy-Inspired)

## 1. 코딩 전에 생각하기

가정하지 말고, 혼란을 숨기지 말고, 트레이드오프를 드러낼 것.

구현 전:
- 가정을 명시적으로 밝힐 것. 불확실하면 물어볼 것.
- 여러 해석이 가능하면 제시할 것 — 조용히 혼자 선택하지 말 것.
- 더 단순한 접근법이 있으면 말할 것. 필요하면 반론을 제기할 것.
- 불명확한 부분이 있으면 멈출 것. 무엇이 혼란스러운지 명확히 하고 물어볼 것.

## 2. 단순함 우선

요청된 문제를 해결하는 최소한의 코드만 작성. 추측성 코드 금지.

- 요청받지 않은 기능은 추가하지 말 것.
- 일회성 코드에 추상화를 만들지 말 것.
- 요청받지 않은 유연성이나 설정 가능성을 추가하지 말 것.
- 불가능한 시나리오에 대한 에러 핸들링 금지.
- 200줄로 작성했는데 50줄로 될 수 있다면 다시 작성할 것.

"시니어 엔지니어가 보면 과복잡하다고 할까?" — 그렇다면 단순화할 것.

## 3. 외과적 수정

필요한 것만 건드릴 것. 내가 만든 mess만 정리할 것.

기존 코드 수정 시:
- 인접 코드, 주석, 포맷을 "개선"하지 말 것.
- 문제없는 것을 리팩터링하지 말 것.
- 내가 다르게 할지라도 기존 스타일을 맞출 것.
- 관련 없는 dead code를 발견하면 언급만 할 것 — 삭제 금지.

내 변경으로 orphan이 생길 때:
- 내 변경으로 인해 사용되지 않게 된 import/변수/함수는 제거할 것.
- 기존에 존재하던 dead code는 요청받지 않는 한 건드리지 말 것.

기준: 모든 변경된 줄이 사용자 요청으로 직접 연결되어야 함.

## 4. 목표 중심 실행

성공 기준을 정의하고, 검증될 때까지 반복할 것.

작업을 검증 가능한 목표로 변환:
- "유효성 검사 추가" → "잘못된 입력에 대한 테스트 작성 후 통과시키기"
- "버그 수정" → "버그를 재현하는 테스트 작성 후 통과시키기"
- "X 리팩터" → "리팩터 전후 테스트 통과 확인"

다단계 작업에는 간략한 계획을 명시:
```
1. [단계] → 검증: [확인 방법]
2. [단계] → 검증: [확인 방법]
3. [단계] → 검증: [확인 방법]
```

---

# ODD 앱 Android 빌드 설정 (검증된 버전 조합)

## 검증된 빌드 환경 (v3.3.0 기준)
- Flutter: 3.44.1 / Dart: 3.12.1
- AGP (android/settings.gradle): **8.9.1** ← 이보다 올리면 빌드 실패
- Kotlin (android/settings.gradle): **2.2.20** ← Flutter 3.44.1이 2.2.20+ 요구 (2.1.0 이하면 Flutter가 post-build APK 복사 중단 → build/ 폴더 미생성)
- Gradle (gradle-wrapper.properties): **8.11.1** ← AGP 8.9.1 최소 요구 버전 (8.10.2 이하 불가, 8.14.1은 Flutter tooling과 충돌)
- 빌드 경로: C:\dev\odd-app (OneDrive 한글 경로 우회 필수)
- 빌드 스크립트: .\build_and_install.ps1

## gradle.properties 금지 항목 (빌드 파괴)
- `android.builtInKotlin=true` ← AGP에 없는 가짜 프로퍼티, IllegalArgumentException 발생
- `android.newDsl=false` ← AGP 8.x에 없는 프로퍼티

## ⚠️ 빌드 함정 — analyze는 통과하는데 release kernel 컴파일 실패
- `CupertinoPageTransitionsBuilder` (pageTransitionsTheme)는 이 Flutter(3.44) **release 빌드 kernel_snapshot에서 실패**. `flutter analyze`는 통과시켜서 build_and_install.ps1의 analyze 게이트를 못 잡음 → `flutter build apk`에서 `Target kernel_snapshot_program failed`.
- 교훈: 빌드 실패 시 analyze 통과 여부와 무관하게 `flutter build apk` 콘솔 마지막(BUILD FAILED + ^^^ 위치)을 봐야 함. 화면 캡처로 확인.
- 부드러운 화면 전환은 검증된 방식(커스텀 PageRoute 등)으로 재도입 예정.

## AppTheme 컬러명 (Warm Natural, Figma Make v2 — 2026.07 리디자인)
- primary #C4664A(테라코타), primary2 #A6522F, secondary #6E7A5A(세이지)
- accent #E58A5B(소프트코랄), accentL #F7E6DB
- bg #FAF6EF(크림), surface #FFFFFF, bg2 #F3EDE4, divider #ECE4D8
- textDark #2C2825, textMid #7B7167, textLight #A79E92
- chipBg #F0E9DA, chipText = primary
- 카테고리 틴트: tintCafe/tintFood/tintPlay/tintCulture/tintView
- (≠ textPrimary/textSecondary/background — 이 이름들은 존재하지 않음)
- **리디자인 진행중**: figma_ai_prompt_redesign.md + 업로드된 React 프로토타입(Figma Make)이 설계도.
  Flutter로 화면별 재구현 중. 화면 하드코딩 인디고(#5C6BC0/#3949AB/#7986CB)는 재구현 시 제거.
  폰트: Pretendard/Nanum Myeongjo 번들 미완(pubspec fonts 섹션 없음) — 별도 단계.
  - ✅ 완료: 색상토대(app_theme), 폰트(google_fonts 고운돋움 전역 — pubspec google_fonts:^6.2.1), 홈, 바텀내비(플랫), 나, 저장, 코스찾기(칩 파인더+코스 피드), 장소상세(사진 드래그·리뷰/사진 증량·AI배지 제거)
  - ✅ 둘러보기(v3.23.0): explore_screen 상단에 네이티브 지도 패널(_ExploreMap — 결과 마커+fitBounds, map_screen 패턴 재사용) 추가. 지도 인증 실패해도 하단 목록 정상 동작(배너만 노출). 지도 401 최종 해결은 빌드 검증 후 확인 필요.
  - ⬜ 남음: 코스결과 경량 restyle
  - ✅ 화면 전환 애니메이션(#2) 재도입(v3.23.0): app_theme의 `SoftPageTransitionsBuilder`(순수 Dart 슬라이드+페이드)를 pageTransitionsTheme에 전역 적용. Cupertino 대체라 release 안전. 탭 전환(IndexedStack)은 상태보존 위해 미적용(의도)
  - ⚠️ 홈 기존 빌더(_buildAppBar/_buildBannerCarousel 등)·chat 대화모드 헤더(인디고) 미사용/잔존 — 컴파일 안전, 추후 정리
  - ⚠️ 미검증(사용자 요청으로 빌드 검증 건너뜀) — 대량 UI 변경이라 다음 빌드에서 오류 확인 필요

## CulturalEvent 필드명
- thumbnail (≠ imageUrl), startDate (≠ date), endDate

## Supabase / Kakao OAuth
- 프로젝트 ID: uvgkwbapdpfdsucghgac
- Kakao 딥링크: odd://login-callback
- 완료 감지: onAuthStateChange → AuthChangeEvent.signedIn

---

# 현재 작업 상태 스냅샷 (2026.06.30 — v3.19.0)

## 최신 버전
- **v3.23.0** (미검증 — 사용자 빌드 대기) — 지도 신인증(NCP_KEY_ID)·둘러보기 상단지도(_ExploreMap)·화면전환 애니(SoftPageTransitionsBuilder)·장소카드 AI문구 제거·폰트 고운돋움·D-day 배너 연결(웜 컬러, build()에 미연결이던 것 수정)
- 이전: v3.19.2 (둘러보기 선택지역·이색데이트·장소상세 미니지도·코스결과 사진보강·장소코스추천 DB전용)

## 🗺️ 지도 — 네이티브 네이버 지도 (flutter_naver_map, 2026.07.01 전환)
- WebView JS(네이버·카카오)는 안드로이드 WebView origin/referer 인증 벽으로 실패 → 네이티브 SDK로 전환.
- `flutter_naver_map: ^1.3.0` (pubspec 활성화). main.dart에서 `NaverMapSdk.instance.initialize(clientId: Env.naverMapClientId)`.
- **minSdkVersion 23** (android/app/build.gradle) ← 네이버 SDK 요구. flutter.minSdkVersion에서 상향.
- 사용처: map_screen(코스 동선 — NMarker+NPolylineOverlay+fitBounds), place_detail `_PlaceMiniMap`(단일 핀).
- **NCP 콘솔 등록 필요**: Maps 앱(clientId 35n8legn2t)에 Android 패키지명 **com.odd.app** 등록 + Mobile Dynamic Map 활성화.
- 🔑 **401 Unauthorized client 원인(2026.07.05 확정)**: 네이버가 **2025.07.01부로 구 인증 폐기**. 우리는 ①AndroidManifest가 구 메타 `com.naver.maps.map.CLIENT_ID`였고 ②pubspec.lock에 flutter_naver_map 미기재(구버전 resolve 위험)였음. **수정(v3.23.0)**: 매니페스트 → **`com.naver.maps.map.NCP_KEY_ID`**(신 인증). lock에 없으니 다음 pub get이 최신 1.3.x(신 인증 지원) 자동 resolve. Client ID 값(35n8legn2t)은 마이그레이션상 그대로 유효 가능성 높음 → **빌드로 먼저 검증**. 그래도 401이면 콘솔에서 키 신 인증 재발급 + Mobile Dynamic Map 활성 확인(사용자 로그인 필요).
- 되돌리기: pubspec에서 flutter_naver_map 주석 + map_screen을 git 복원.
- 미사용 잔존: Env.kakaoJsKey/kakaoMapBaseUrl(카카오 WebView 시도 흔적, 무해).

## v3.18.0 APK 빌드 상태
- `build_and_install.ps1`에 UTF-8 BOM 추가 완료 (2026.06.30) — 이전 인코딩 파싱 오류 수정
- 빌드 실행 bat: `C:\Users\chahy\Downloads\build_odd.bat`
- 빌드 상태: ✅ 완료 (2026.06.30)
- adb install: ✅ 완료

## Phase 1 파이프라인 상태
- **W1** DATA_POLICY.md + DB 스키마 마이그레이션 ✅
- **W3** 네이버 수집기 v1 (Gate1~Gate3) ✅ — `pipeline/naver_collector.py`
- **W4** dry-run 결과: Gate1 통과 18건, Gate2 0건 (Gemini API daily quota 소진)
  - Gemini key: `pipeline/.env`의 GEMINI_API_KEY — 오늘 quota 소진, 내일 자정 리셋
  - dry-run bat: `C:\Users\chahy\Downloads\odd_dryrun.bat`
  - pip 패키지: google-generativeai, python-dotenv, requests, supabase 설치 완료

## 🚨 앱 문제점 목록 (2026.06.30 사용자 피드백 — 우선 해결 필요)

> **#11이 최우선 — 앱 정체성·신뢰도 이슈**

1. **[홈] 탐색 탭 이름 변경 필요** — ✅ 2026.06.30 '탐색'→'둘러보기' (main_nav 하단탭 + explore 헤더)
2. **[홈] 서울 외 지역 코스 품질 저하** — 🔶 2026.06.30 핵심 발견: courses_enhanced.json에 비서울 972+ 포함 1,944개(좌표 100% 유효) 이미 생성됨. 안 보이던 진짜 원인은 **코드 버그**: ①`_shortCity("전주시")`가 "전주시" 반환→DB '전주'와 불일치(수정 완료) ②main_nav가 타지역 도시에 GPS city 오접두→서울 조회(수정 완료) ③naver `_inRegion` 오염필터(완료). 남은 건 **bulk_seed로 Supabase 업로드 확인**(PC) — opus 배치 1,944건 6/28 제출됨
3. **[홈] 장소 새로고침 기능 없음** — ✅ 2026.06.30 RefreshIndicator(당겨서 새로고침) 추가, 코스+장소 동시 갱신
4. **[홈] 상단 카드 3개 클릭 UX 오류** — ✅ 2026.06.30 배너 탭 시 CourseResultScreen 직접 푸시(보유 코스 활용), 빈 경우만 AI 폴백
5. **[홈] 문화행사 탭 클릭 불가 (버그)** — ✅ 2026.06.30 explore initState에서 '문화행사'→'🎪 문화행사' 키 정규화
6. **[전체] 탭 이동 시 뒤로가기 버튼 없음** — 좌상단 back 버튼 필요 (IndexedStack 히스토리 스택 필요 — 미착수)
7. **[추천코스] 카테고리 불일치** — 🔶 구조적 원인(Gemini 생성)은 #10 전환으로 제거됨. 잔여는 DB archetype 태깅 품질(데이터)
8. **[추천코스] 지도 동선 문제** — ✅ 2026.06.30 좌표 유효성(KR범위) 검사 → 불량 구간 거리/이동수단/지도마커 제외 (course_result_screen._travel nullable, map_screen 유효좌표만 플롯)
9. **[탐색탭] 장소 수 부족 + 퀄리티 저하** — 네이버 지도 수준 미달 (외부 API+데이터 — Phase 2)
10. **[AI추천] 퀄리티·정보량 부족** — ✅ 2026.06.30 **코스 생성 폐기 → DB 검색 전용** 전환 (아래 핵심 원칙 참조)
11. **[전체] 앱 정체성·신뢰도 ← 최우선** — 진행중. Phase 0(인터랙션 정합 #1·#4·#5) + Phase 1(진실성 #8·AI전환) 완료. 남은 핵심: #6, #2/#9 콘텐츠 깊이

## 다음 작업 우선순위 (Opus 추천 순서)
- **#198** v3.18.0 APK 빌드 결과 확인 + 갤럭시 설치 ← 지금 빌드 진행 중
- **#197** AI코스 탭 → '코스' 탭 이름+아이콘 변경 — `main_nav.dart`
- **#196** 큐레이션 카드 탭 → `course_result_screen` 바로 열기
- **#194** 이번 주 인기 코스 섹션 (save_count 기반) — `home_screen.dart`
- **#195** D-day 특별 코스 홈 배너 — `home_screen.dart`
- **Phase 1-W4** Gemini quota 회복 후 홍대 verified 코스 50개 수집
- **#189** bulk_seed.py 1,000개+ 코스 Supabase 업로드 (진행중)
- **#144** 원데이클래스 서비스 조사 분석 (진행중)

## 핵심 파일 위치
- 탐색: `lib/screens/explore_screen.dart` (1491줄)
- 장소 상세: `lib/screens/place_detail_screen.dart`
- 코스 DB 서비스: `lib/services/supabase_course_service.dart`
- 홈 화면: `lib/screens/home_screen.dart`
- 메인 네비: `lib/main_nav.dart`
- 빌드 정보: `lib/config/build_info.dart`
- Figma 프롬프트: `figma_ai_prompt.md`
- 파이프라인: `pipeline/naver_collector.py`, `pipeline/.env`

## APK 빌드 방법
```
C:\Users\chahy\Downloads\build_odd.bat 더블클릭
```
(내부적으로 build_and_install.ps1 실행 — UTF-8 BOM 적용됨)

## 코스 DB 아키텍처
- Supabase `curated_courses` 테이블
- `SupabaseCourseService.fetchCourses(city, mood, timeSlot, limit)`
- archetype 매핑: '감성'→'감성 로맨스', '액티비티'→'액티비티 챌린지', '힐링'→'로컬 힐링'

## 🔑 핵심 원칙 — AI 추천 = 코스 생성 금지, DB 검색 전용 (2026.06.30)
- 앱의 가치는 "AI가 만들어낸 그럴듯한 코스"가 아니라 **실재하는 검증 코스를 요청대로 정확히 찾아주는 것**.
- `chat_screen._recommend()`: ① fetchCourses(조건 일치) → ② 없으면 fetchTopCourses(도시 기준 완화) → ③ 그래도 없으면 **생성하지 말고 정직하게 안내**(넓은 지역/다른 분위기 제안).
- Gemini 코스 **생성**(generateCourses) 경로 폐기. Gemini는 노출된 실재 코스에 대한 **자유 대화/의도 파싱**(sendMessageStream, interpretAllSteps)에만 사용.
- 절대 좌표·운영시간·장소를 지어내지 않는다. 좌표 불량(0,0/KR범위 밖)은 동선·지도에서 제외.

## Place 모델 주의사항
- `rating` → double (0.0이면 미지정)
- `reviewCount` → int?
- `imageUrl` (≠ thumbnail — thumbnail은 CulturalEvent 전용)
- `aiReason` → AI 추천 이유 텍스트
