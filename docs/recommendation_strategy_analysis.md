# ODD 추천 전략 전면 분석 및 실행 계획
> 작성일: 2026.06.26
> 분석 대상: API 기반 현행 방식 vs. 실제 후기 DB 수집 방식 vs. 유저 코스 등록 방식

---

## 1. 세 가지 접근법 정의

### A. 현행 + 개선 (API 기반)
Naver/Kakao/Google API로 실시간 장소를 가져오고,
PlaceRanker로 점수를 매기고, Gemini가 아키타입에 맞게 조합하는 방식.
브랜드 블랙리스트 + 체인점 페널티 + 아키타입별 쿼리 개선으로 고도화.

### B. 실제 후기 DB (정원님 제안)
네이버 블로그/SNS/각종 포털에서 지역별 데이트 후기를 수집해
Supabase DB에 저장하고, 이걸 추천의 1차 소스로 활용.

### C. 유저 직접 등록 (정원님 제안)
실제 이용자들이 자신의 데이트 코스를 앱에 직접 등록하고
누적된 코스들이 DB를 풍부하게 만드는 플라이휠.

---

## 2. 10가지 차원에서 완전 비교

### 2-1. 데이터 품질

| 차원 | A. API 기반 | B. 후기 DB | C. 유저 등록 |
|---|---|---|---|
| 아키타입 정합성 | ★★☆ 키워드 의존, 맥도날드 문제 | ★★★★ 실제 데이트한 사람이 직접 고른 장소 | ★★★★★ 직접 경험한 커플이 만든 코스 |
| 장소 신뢰도 | ★★★ API 반환값 기준 | ★★★★ 블로거 후기 기반 (사진+경험 포함) | ★★★★★ 실제 다녀온 커플 인증 |
| 코스 완성도 | ★★☆ Gemini가 조합 (오류 가능) | ★★★ 블로그 코스 참조하지만 구조화 필요 | ★★★★★ OPEN+PEAK+CLOSE 이미 완성된 코스 |
| 아키타입 레이블 | ★★ 코드가 추측 | ★★★ Gemini 분류 | ★★★★★ 유저가 직접 선택 |

**→ 품질 순위: C > B > A**
유저가 직접 등록한 코스가 품질 최상. Gemini가 조합하는 것보다 실제 커플이 짠 코스가 훨씬 정확.

---

### 2-2. 비용

| 항목 | A. API 기반 | B. 후기 DB | C. 유저 등록 |
|---|---|---|---|
| API 호출 비용 | 코스 생성마다 Naver+Kakao+Google 10~20회 호출 | **거의 없음** (DB 조회만) | **없음** |
| Supabase 비용 | Free 충분 | Free(500MB) → Pro($25) | Free → Pro |
| 초기 구축 공수 | 낮음 | 높음 (데이터 수집+분류) | 중간 (UI 개발) |
| 운영 비용 | API 사용량 비례 증가 | DB 저장 비용만 (고정) | 최소 |

**Supabase 스토리지 계산:**
- 코스 1개 = 약 2KB (장소명 3개 + 설명 + 태그)
- 코스 10,000개 = 20MB → Free 내 충분
- 코스 100,000개 = 200MB → Free 내 충분
- 코스 1,000,000개 = 2GB → Pro($25/월)

**API 호출 비용 비교:**
- 현행: 코스 생성 1회 = Naver 20회 + Kakao 5회 + Google 5회
- DB 방식: 코스 생성 1회 = Supabase 쿼리 1회 (비용 실질적 0)
- 사용자 1만명이 매주 코스 생성 시:
  - API 방식: 월 40만회 API 호출 (제한 및 비용 문제)
  - DB 방식: Supabase 쿼리만 (무제한)

**→ 비용 순위: C = B >> A**
규모가 커질수록 DB 기반이 압도적으로 저렴.

---

### 2-3. 기술적 실현 가능성

| 항목 | A. API 기반 | B. 후기 DB | C. 유저 등록 |
|---|---|---|---|
| 즉시 구현 가능 | ✅ 이미 작동 중 | ⚠️ 데이터 수집 파이프라인 필요 | ✅ UI 개발만 |
| 네이버 블로그 수집 | N/A | ⚠️ 공식 검색 API 사용 (크롤링 불가) | N/A |
| 법적 리스크 | 없음 | 낮음 (공식 API만 사용 시) | 없음 |
| 자동화 가능성 | ✅ 이미 자동 | ⚠️ 반자동 (Gemini 분류 필요) | ✅ 사용자가 채워줌 |

**네이버 블로그 API 현실:**
- 공식 검색 API: 일 25,000회 호출 가능
- 1회 호출 = 최대 100개 결과 반환
- 최대 1,099개/키워드 (start 파라미터 한계)
- 제목+요약만 반환, 본문 전체는 별도 파싱 필요
- 크롤링은 Naver ToS 위반 → 공식 API만 사용

**실제 데이터 수집 흐름 (법적 안전):**
```
Naver Blog Search API
  → 키워드: "홍대 데이트 코스", "성수동 데이트 후기" 등
  → 결과: 제목, URL, 날짜, 요약
  → Gemini: 장소명 추출 + 아키타입 분류
  → Supabase: 구조화된 데이터로 저장
```

**→ 가능성: A > C > B (구현 순서 기준), B는 반자동화 파이프라인 필요**

---

### 2-4. 신선도 (데이터 최신성)

| | A. API 기반 | B. 후기 DB | C. 유저 등록 |
|---|---|---|---|
| 새 장소 반영 | 즉시 (API 실시간) | 느림 (주기적 수집 필요) | 실시간 (사용자 등록) |
| 폐업 장소 처리 | 영업시간 API로 감지 | 수동 확인 필요 | 사용자 신고로 처리 |
| 계절/트렌드 반영 | 즉시 | 수집 주기 의존 | 실시간 |

**→ 신선도: A > C > B**
API는 항상 최신. DB는 주기적 갱신 필요. 단, 유저 등록은 자연스럽게 최신 트렌드 반영됨.

---

### 2-5. 지역 커버리지

| | A. API 기반 | B. 후기 DB | C. 유저 등록 |
|---|---|---|---|
| 전국 커버 | ✅ 즉시 | ⚠️ 수집한 지역만 | ⚠️ 사용자 있는 지역만 |
| 소도시 커버 | ✅ (품질 낮을 수 있음) | ❌ 데이터 희박 | ❌ 사용자 없으면 없음 |
| 신규 지역 | ✅ 즉시 | 수집 후 | 사용자 생기면 |

**→ 커버리지: A >> B = C**
API 방식은 전국 어디든 즉시 작동. DB 방식은 커버된 지역에서만 고품질.

---

### 2-6. 확장성

| | A. API 기반 | B. 후기 DB | C. 유저 등록 |
|---|---|---|---|
| 사용자 증가 시 | API 비용 비례 증가 ⚠️ | DB 조회 비용 거의 고정 ✅ | 사용자가 DB를 키워줌 ✅✅ |
| 데이터 증가 시 | 무관 | 품질 향상 | 플라이휠 — 쓸수록 좋아짐 |
| 지역 확장 | 즉시 | 수집 필요 | 사용자 이동에 따라 자연 확장 |

**→ 확장성: C > B > A**
유저 등록 방식은 사용자가 많아질수록 DB가 더 풍부해지는 플라이휠. Airbnb와 동일한 구조.

---

### 2-7. 경쟁 우위 (Moat)

| | A. API 기반 | B. 후기 DB | C. 유저 등록 |
|---|---|---|---|
| 복제 가능성 | 높음 (누구나 같은 API 씀) | 중간 (수집 노력 필요) | 낮음 (커뮤니티 데이터는 복제 불가) |
| 차별화 요소 | 낮음 | 중간 | **높음** — 커플들의 실제 코스 DB는 ODD만의 자산 |
| 진입장벽 | 없음 | 낮음 | 높음 (시간+커뮤니티) |

**→ 경쟁 우위: C >>> B > A**
유저가 등록한 코스 데이터는 ODD만의 독점 자산. 돈으로 살 수 없음.

---

### 2-8. 초기 데이터 콜드스타트 문제

| | A. API 기반 | B. 후기 DB | C. 유저 등록 |
|---|---|---|---|
| 즉시 사용 가능 | ✅ | ❌ 수집 기간 필요 | ❌ 사용자 먼저 필요 |
| 콜드스타트 해결책 | 없음 필요 | 수동 큐레이션으로 시드 | 관리자가 먼저 코스 등록 |

**→ 콜드스타트: A가 유일한 즉시 해결책**. B와 C는 시드 데이터 필요.

---

### 2-9. 사용자 경험 (UX) 영향

| | A. API 기반 | B. 후기 DB | C. 유저 등록 |
|---|---|---|---|
| 추천 품질 | 현재: 낮음, 개선 후: 중간 | 높음 | 최고 |
| 신뢰감 | "AI가 골라줬어요" | "실제 블로거 후기 기반" | "실제 커플 OO쌍이 다녀온 코스" |
| 커뮤니티 감 | 없음 | 낮음 | **높음** — 내 코스가 다른 커플에게 추천됨 |
| 사용자 리텐션 | 낮음 | 중간 | **높음** — 내 코스의 반응이 궁금해서 재방문 |

**→ UX: C > B > A**

---

### 2-10. 법적/윤리적 리스크

| | A. API 기반 | B. 후기 DB | C. 유저 등록 |
|---|---|---|---|
| 법적 리스크 | 없음 | 블로그 내용 저장 시 저작권 이슈 → 공식 API 메타데이터만 저장하면 OK | 없음 |
| 개인정보 | 없음 | 없음 | 닉네임 공개 동의 필요 |
| 장소 오정보 | 중간 | 낮음 (후기 있는 장소) | 낮음 (실제 다녀온 곳) |

---

## 3. 종합 점수

| 차원 | A. API | B. 후기 DB | C. 유저 등록 | 가중치 |
|---|---|---|---|---|
| 데이터 품질 | 2 | 4 | 5 | 25% |
| 비용 효율 | 2 | 5 | 5 | 15% |
| 기술 실현 | 5 | 3 | 4 | 10% |
| 신선도 | 5 | 2 | 4 | 10% |
| 커버리지 | 5 | 2 | 2 | 10% |
| 확장성 | 2 | 4 | 5 | 15% |
| 경쟁 우위 | 1 | 3 | 5 | 10% |
| UX 영향 | 2 | 3 | 5 | 5% |
| **가중 합산** | **3.0** | **3.3** | **4.4** | 100% |

---

## 4. 결론: 3단계 하이브리드 전략

**A, B, C 중 하나를 고르는 문제가 아니다.**
세 가지를 계층으로 쌓아야 한다.

```
추천 소스 우선순위 (Tier 시스템):

Tier 1 — 유저 등록 코스 (C)
  ↓ 해당 지역/아키타입 코스 없으면
Tier 2 — 후기 DB 기반 큐레이션 코스 (B)
  ↓ 그것도 없으면
Tier 3 — API 실시간 조합 (A, 현행)
```

**이 구조의 핵심 논리:**
- 유저 코스가 있으면 → 가장 신뢰도 높은 걸 보여줌
- 없으면 → 후기 DB에서 검증된 코스 보여줌
- 그것도 없으면 → 현행 AI 조합으로 폴백
- 시간이 지날수록 Tier 1, 2가 채워지면서 Tier 3 의존도가 자연스럽게 감소

---

## 5. DB 설계

### 핵심 원칙
> **장소(place)가 아니라 코스(course)를 저장한다.**
>
> 장소를 저장하면 Gemini가 다시 조합해야 하고 거기서 오류가 생긴다.
> 이미 완성된 3슬롯 코스를 통째로 저장하면 바로 보여줄 수 있다.

### Supabase 테이블 구조

#### `curated_courses` — 관리자 큐레이션 코스
```sql
create table curated_courses (
  id uuid primary key default gen_random_uuid(),
  
  -- 코스 기본 정보
  title text not null,              -- "성수 인더스트리얼 감성 하루"
  description text,                 -- 코스 소개 2~3줄
  archetype text not null,          -- 'romantic' | 'activity' | 'healing' | 'luxury' | 'hipster' | 'instaphoto'
  mood text,                        -- '감성' | '액티비티' | '힐링' | '혼합'
  
  -- 지역
  city text not null,               -- '서울' | '부산' | '대전'
  district text,                    -- '성수' | '홍대' | '한남'
  
  -- OPEN 슬롯
  open_name text not null,          -- "어니언 성수"
  open_category text,               -- '카페' | '브런치' | '베이커리'
  open_address text,
  open_lat float8,
  open_lng float8,
  open_tip text,                    -- "시그니처 오르에르 라떼 주문 필수"
  open_reason text,                 -- "높은 천장과 자연광, 조용한 시작"
  
  -- PEAK 슬롯
  peak_name text not null,
  peak_category text,               -- '전시' | '체험' | '공연' | '액티비티' | '산책'
  peak_address text,
  peak_lat float8,
  peak_lng float8,
  peak_tip text,
  peak_reason text,
  
  -- CLOSE 슬롯
  close_name text not null,
  close_category text,              -- '한식' | '양식' | '이자카야' | '파인다이닝'
  close_address text,
  close_lat float8,
  close_lng float8,
  close_tip text,
  close_reason text,
  
  -- 메타
  time_slot text,                   -- '낮' | '저녁' | '하루종일'
  budget_level int,                 -- 1=저렴(~2만) 2=보통(3~6만) 3=고급(8만+)
  transport text,                   -- '도보' | '대중교통' | '차량'
  special_day text,                 -- '일상' | '기념일' | '첫만남'
  
  -- 품질 지표
  source text,                      -- 'admin' | 'blog_extract' | 'user'
  view_count int default 0,
  save_count int default 0,
  rating float4,                    -- 평균 별점
  
  -- 상태
  is_active bool default true,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 인덱스: 추천 쿼리 최적화
create index idx_courses_region on curated_courses(city, district);
create index idx_courses_archetype on curated_courses(archetype);
create index idx_courses_timeslot on curated_courses(time_slot);
create index idx_courses_budget on curated_courses(budget_level);
```

#### `user_courses` — 유저 등록 코스
```sql
create table user_courses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users,
  
  -- curated_courses와 동일한 필드들
  title text not null,
  archetype text,
  city text not null,
  district text,
  
  open_name text not null,
  open_category text,
  open_address text,
  open_tip text,
  
  peak_name text not null,
  peak_category text,
  peak_address text,
  peak_tip text,
  
  close_name text not null,
  close_category text,
  close_address text,
  close_tip text,
  
  time_slot text,
  budget_level int,
  transport text,
  special_day text,
  
  -- 유저 코스 전용
  one_line text,                    -- "성수에서 하루 종일 놀았는데 최고였어요"
  photo_urls text[],                -- 직접 찍은 사진
  date_of_visit date,               -- 실제 방문일 (선택)
  
  -- 커뮤니티
  like_count int default 0,
  save_count int default 0,
  
  -- 검수 상태
  status text default 'pending',   -- 'pending' | 'approved' | 'rejected'
  approved_at timestamptz,
  
  created_at timestamptz default now()
);
```

#### `blog_extracted_places` — 블로그에서 추출한 장소 데이터
```sql
create table blog_extracted_places (
  id uuid primary key default gen_random_uuid(),
  
  name text not null,               -- "어니언 성수"
  city text,
  district text,
  category text,                    -- '카페' | '전시' | '맛집' 등
  
  -- 블로그 추출 정보
  blog_mention_count int default 1, -- 언급 횟수 (많을수록 신뢰도 높음)
  blog_url text,                    -- 참조 블로그 URL (공식 API 반환값)
  
  -- Gemini 분류 결과
  archetype_fit text[],             -- 이 장소가 맞는 아키타입들
  vibe_tags text[],                 -- ['감성','조용함','인스타']
  slot text,                        -- 'open' | 'peak' | 'close'
  
  -- 장소 데이터
  address text,
  lat float8,
  lng float8,
  
  -- 품질
  confidence float4,                -- Gemini 분류 신뢰도 0~1
  is_verified bool default false,   -- 관리자 검증 여부
  
  created_at timestamptz default now()
);
```

---

## 6. 블로그 데이터 수집 파이프라인

### 법적으로 안전한 방식 (Naver 공식 검색 API)
```
하루 25,000회 호출 가능
키워드 1개당 최대 1,099개 결과
반환 데이터: 제목, URL, 날짜, 발췌문(요약)
→ 본문 전체 저장 X, 장소명 추출만 O
```

### 수집 키워드 세트 (아키타입별)

**감성 로맨스:**
```
"홍대 감성 데이트 코스", "성수 감성 데이트 후기",
"한남동 데이트 코스", "을지로 감성 데이트",
"부산 감성 데이트", "데이트 코스 추천 갤러리"
```

**액티비티:**
```
"방탈출 데이트 후기", "커플 액티비티 데이트",
"볼링 데이트 저녁 코스", "트램폴린 데이트",
"VR 체험 커플", "클라이밍 데이트"
```

**힐링:**
```
"공방 데이트 후기", "도예 체험 커플",
"향수 조향 데이트", "북촌 데이트 힐링",
"한강 산책 데이트", "양평 커플 당일치기"
```

### 파이프라인 흐름 (Python 배치 스크립트)
```python
# 1. Naver Blog Search API로 블로그 메타데이터 수집
# 2. Gemini로 발췌문에서 장소명 추출
# 3. Gemini로 아키타입/슬롯 분류
# 4. Naver Place API로 장소 좌표 조회
# 5. blog_extracted_places에 저장

def extract_places_from_blog_summary(summary: str) -> list[dict]:
    prompt = f"""
    다음 블로그 발췌문에서 데이트 장소명을 추출하고 분류하세요.
    발췌문: "{summary}"
    
    JSON 배열로만 반환:
    [
      {{"name": "장소명", "slot": "open|peak|close", 
        "archetype": ["romantic","activity","healing"],
        "vibe": ["감성","조용함"]}}
    ]
    장소가 없으면 빈 배열 반환.
    """
    # Gemini Haiku로 비용 최소화
```

---

## 7. 유저 코스 등록 UX 설계

### 등록 흐름 (4단계)

```
Step 1: 코스 유형 선택
  ● 감성 로맨스  ● 액티비티  ● 힐링
  ○ 기념일 특별  ○ 첫만남   ○ 인스타 포토

Step 2: 지역 입력
  [시] 서울 ▼  [구/동] 성수 ▼

Step 3: 3슬롯 입력 (각 장소명 + 한줄팁)
  ☕ OPEN (카페/브런치)
  → 장소 검색: [어니언 성수          🔍]
  → 팁: [시그니처 라떼 꼭 드세요!      ]

  🎨 PEAK (경험/문화)
  → 장소 검색: [대림창고               🔍]
  → 팁: [저녁에 가면 전시+공연 같이 봐요]

  🍽️ CLOSE (저녁 식사)
  → 장소 검색: [성수플레이트            🔍]
  → 팁: [파스타 추천, 예약 필수        ]

Step 4: 코스 마무리
  → 제목: [성수 감성 하루 코스          ]
  → 한줄 후기: [진짜 분위기 대박이었어요]
  → 예산: ○ 저렴  ● 보통  ○ 고급
  → 등록하기 →
```

### 진입 트리거 (앱 내 자연스러운 유도)

1. **코스 생성 후 7일**: "지난 주 코스 어떠셨어요? 직접 등록해서 다른 커플에게 공유해보세요 💕"
2. **찜 화면**: "가봤던 장소들로 코스 만들기 →"
3. **MY 화면**: "내 코스 등록" 메뉴
4. **홈 배너**: "이 코스가 47쌍 커플에게 추천됐어요 — 나도 내 코스 올리기"

### 게임화 요소 (리텐션)

| 달성 | 뱃지/보상 |
|---|---|
| 첫 코스 등록 | 💫 "코스 크리에이터" 뱃지 |
| 10쌍이 코스 저장 | 🌸 "인기 코스" 뱃지 |
| 50쌍이 코스 저장 | ❤️ "ODD 큐레이터" 뱃지 |
| 100쌍이 코스 저장 | ✦ 코스 홈 화면 노출 |

---

## 8. Flutter 연동 설계

### 추천 우선순위 로직

```dart
// chat_screen.dart → _recommend() 개선안
Future<List<DateCourse>> _recommend() async {
  
  // === Tier 1: Supabase 큐레이션/유저 코스 ===
  final dbCourses = await SupabaseCourseService.query(
    city: widget.location.city,
    district: widget.location.district,
    archetype: _mood,
    timeSlot: _timeSlot,
    budgetLevel: _budgetLevel,
    specialDay: _specialDay,
    limit: 10,
  );
  
  if (dbCourses.length >= 3) {
    // DB에서 3개 이상 나오면 → Gemini 없이 바로 보여줌
    // 비용 0, 속도 빠름, 품질 최고
    return _selectAndPersonalize(dbCourses);
  }
  
  // === Tier 2: DB 부족 → 블로그 추출 장소로 Gemini 조합 ===
  final extractedPlaces = await SupabaseCourseService.getExtractedPlaces(
    city: widget.location.city,
    archetype: _mood,
  );
  
  if (extractedPlaces.isNotEmpty) {
    return await GeminiService.generateCoursesFromCurated(
      places: extractedPlaces,
      mood: _mood,
      // ...
    );
  }
  
  // === Tier 3: 기존 API 방식 폴백 ===
  return await _legacyApiRecommend();
}
```

### DB 쿼리 서비스

```dart
class SupabaseCourseService {
  static final _client = Supabase.instance.client;
  
  static Future<List<DateCourse>> query({
    required String city,
    String? district,
    required String archetype,
    String timeSlot = '낮',
    int budgetLevel = 2,
    String specialDay = '일상',
    int limit = 10,
  }) async {
    var query = _client
      .from('curated_courses')
      .select()
      .eq('city', city)
      .eq('archetype', archetype)
      .eq('is_active', true)
      .order('save_count', ascending: false)
      .limit(limit);
    
    // district 있으면 우선 검색, 없으면 city 전체
    if (district != null && district.isNotEmpty) {
      query = query.eq('district', district);
    }
    
    final data = await query;
    return (data as List).map((e) => DateCourse.fromSupabase(e)).toList();
  }
  
  // 유저 코스 등록
  static Future<void> submitUserCourse(UserCourse course) async {
    await _client.from('user_courses').insert(course.toJson());
  }
  
  // 검수 완료된 유저 코스를 curated_courses로 이전 (관리자)
  static Future<void> promoteUserCourse(String userCourseId) async {
    final course = await _client
      .from('user_courses')
      .select()
      .eq('id', userCourseId)
      .single();
    
    await _client.from('curated_courses').insert({
      ...course,
      'source': 'user',
      'status': 'approved',
    });
  }
}
```

---

## 9. 단계별 실행 계획

### Phase 0 — 즉시 (오늘, 2~3시간)
**목표:** 현재 맥도날드 문제 즉시 해소

| 작업 | 파일 | 시간 |
|---|---|---|
| 브랜드/업종 블랙리스트 추가 | naver_place_service.dart | 30분 |
| PlaceRanker 체인점 페널티 배수 | place_ranker.dart | 1시간 |
| Gemini CLOSE 슬롯 제약 강화 | gemini_service.dart | 1시간 |
| v3.12.0 빌드 + 설치 | | 30분 |

---

### Phase 1 — 이번 주 (3~5일)
**목표:** Supabase 큐레이션 코스 DB 구축 + 앱 연결

| 작업 | 상세 | 시간 |
|---|---|---|
| Supabase 테이블 생성 | curated_courses, user_courses, blog_extracted_places SQL | 2시간 |
| 초기 시드 데이터 입력 | 서울 5개 지역 × 3 아키타입 × 3코스 = 45개 코스 | 3~4시간 |
| SupabaseCourseService 작성 | Flutter 서비스 클래스 | 2시간 |
| chat_screen.dart Tier 연동 | Tier 1/2/3 우선순위 로직 | 2시간 |
| v3.13.0 빌드 + 설치 | | 30분 |

**시드 데이터 우선 지역:**
1. 서울 성수 (감성, 힐링)
2. 서울 홍대/연남 (감성, 액티비티)
3. 서울 한남 (감성, 럭셔리)
4. 서울 을지로 (힙스터)
5. 서울 강남 (액티비티, 럭셔리)

---

### Phase 2 — 2~3주차
**목표:** 블로그 반자동 추출 파이프라인 + 지역 확장

| 작업 | 상세 | 시간 |
|---|---|---|
| Naver Blog API 배치 스크립트 | Python 스크립트, 서버리스 or 로컬 실행 | 1일 |
| Gemini 장소 추출 분류기 | 발췌문 → 장소명 + 슬롯 + 아키타입 | 반나절 |
| 부산/대전 지역 DB 확장 | 수집 후 큐레이션 | 1~2일 |
| blog_extracted_places 활용 | Tier 2 로직 구현 | 반나절 |

---

### Phase 3 — 1개월차
**목표:** 유저 코스 등록 UI 구현

| 작업 | 상세 | 시간 |
|---|---|---|
| 유저 코스 등록 화면 | 4단계 Form UI (Flutter) | 2~3일 |
| 장소 검색 연동 | 등록 중 Naver Place 자동완성 | 1일 |
| MY 화면 "내 코스" 섹션 | 등록한 코스 보기 + 저장된 횟수 | 반나절 |
| 홈/커뮤니티 화면 노출 | 인기 유저 코스 카드 형태 노출 | 1일 |

---

### Phase 4 — 2개월차
**목표:** 커뮤니티 + 게임화

| 작업 | 상세 |
|---|---|
| 유저 코스 좋아요/저장 | 코스 카드에 인터랙션 추가 |
| 뱃지 시스템 | MY 화면에 뱃지 노출 |
| 관리자 검수 대시보드 | Supabase Dashboard or 간단한 웹 어드민 |
| 인기 코스 홈 노출 | 홈 화면 "이번 주 인기 코스" 섹션 |

---

## 10. 비용 시뮬레이션

### 사용자 1,000명 기준 (월)

| 항목 | 현행 API 방식 | 하이브리드 방식 |
|---|---|---|
| Naver API | 월 20만~50만 호출 → 제한 도달 | Tier 3 폴백만 → 5만 호출 이하 |
| Supabase | Free ($0) | Free → Pro 전환 전 ($0) |
| Gemini API | 코스 생성마다 호출 (월 수만원) | Tier 1 DB 히트 시 0원 |
| **총 인프라 비용** | **월 5~10만원 예상** | **월 0~2만원** |

### 사용자 10,000명 기준 (월)

| 항목 | 현행 API 방식 | 하이브리드 방식 |
|---|---|---|
| API 비용 | API 제한 초과 → 유료 전환 필요 | Tier 1/2 히트율 80% → API 20%만 |
| Supabase | Pro ($25) | Pro ($25) |
| Gemini | 월 30~50만원 | 월 5~10만원 |
| **총 인프라 비용** | **월 50~100만원** | **월 10~20만원** |

---

## 11. 최종 권고안

> **"정원님의 방향이 전략적으로 옳다."**

단, 실행 순서가 중요하다:

1. **오늘**: Phase 0 코드 수정 → 맥도날드 즉시 제거
2. **이번 주**: Supabase 코스 DB 구축 → 추천 품질 즉시 향상
3. **2~3주**: 블로그 반자동 추출 → DB 자동 확장
4. **1개월**: 유저 코스 등록 UI → 플라이휠 점화
5. **2개월 이후**: 커뮤니티 기능 → 경쟁 우위 확보

**가장 중요한 설계 원칙:**
> 장소(place)가 아니라 완성된 코스(course)를 저장한다.
> Gemini가 조합하는 과정에서 오류가 생기는 것이므로,
> 검증된 완성 코스를 DB에서 꺼내 바로 보여주는 것이 핵심.

---

*다음 단계: Phase 0 코드 수정 → Phase 1 Supabase 테이블 생성 + 시드 데이터 입력*
