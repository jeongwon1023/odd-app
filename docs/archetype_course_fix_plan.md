# ODD 아키타입-코스 정합성 수정 플랜
> 작성일: 2026.06.26
> 핵심 문제: "감성 로맨스 선택 → 맥도날드 등장" 처럼 아키타입과 코스가 전혀 맞지 않음

---

## 문제 원인 요약

### 실패 체인
```
1. [데이터 수집] Naver/Kakao API가 "맛집" 검색 → 맥도날드 포함해서 반환
2. [필터] _mealBlacklist에 "패스트푸드/버거" 같은 업종 단어 없음 → 통과
3. [랭킹] PlaceRanker가 리뷰 많은 체인점에 높은 점수 → 상위 노출
4. [Gemini] "목록에서만 골라라" 제약 → 맥도날드를 감성 로맨스 CLOSE로 선택
```

### 핵심 문제 3가지
1. **데이터 품질**: API가 데이트 부적합 장소를 걸러주지 않음
2. **아키타입별 필터 없음**: 감성 로맨스에도 액티비티에도 동일한 블랙리스트 적용
3. **브랜드 페널티 없음**: 체인점이 리뷰 수로 상위권 차지

---

## 수정 계획

### Phase 1 — 즉시 (1~2시간)
**파일**: `lib/services/naver_place_service.dart`

```dart
// 기존 _mealBlacklist에 추가
const _mealBlacklist = [
  // 기존 슬롯 오염 단어들 유지
  '카페', '커피', '브런치', '케이크', '마카롱', '디저트',
  '빵집', '베이커리', '전시', '갤러리', '미술관',
  '공원', '방탈출', '볼링', '체험', '노래방',
  
  // ↓ 신규 추가: 업종 필터
  '패스트푸드', '패스트 푸드', '분식', '테이크아웃',
  '드라이브스루', '드라이브 스루', '포장 전문',
  
  // ↓ 신규 추가: 브랜드 명시 차단
  '맥도날드', '버거킹', '롯데리아', 'kfc', '맘스터치',
  '파파이스', '서브웨이', '이삭토스트', '노브랜드버거',
  '쌍용', '도미노', '파파존스', '피자헛',
];
```

---

### Phase 2 — 이번 주 (반나절)
**파일**: `lib/services/place_ranker.dart`

체인점 감지 배수를 `computeScore()` 마지막에 추가:

```dart
// ── 체인점 페널티 배수 ──────────────────────────────
static const _chainBrands = [
  '맥도날드', '버거킹', '롯데리아', 'kfc', '맘스터치',
  '이디야', '메가커피', '컴포즈', '빽다방', '파리바게뜨',
  '뚜레쥬르', '던킨', '배스킨라빈스', '스타벅스',
  '올리브영', 'gs25', 'cu편의점', '세븐일레븐',
];

static double _chainMultiplier(String name) {
  final lower = name.toLowerCase();
  for (final brand in _chainBrands) {
    if (lower.contains(brand.toLowerCase())) return 0.15;
  }
  return 1.0;
}
```

`computeScore()`의 return문에 곱셈 추가:
```dart
return weighted * weekendMul * openMul * _chainMultiplier(p.name);
```

---

### Phase 3 — 아키타입별 PEAK 쿼리 전면 재설계
**파일**: `lib/services/naver_place_service.dart`

현재 코드의 `peakQueries` 케이스를 다음으로 교체:

#### 감성 로맨스 PEAK (mood == '감성')
```dart
// 기존
const _SlotQuery('전시회 갤러리 감성 아트', '전시·문화', '전시'),
const _SlotQuery('복합문화공간 감성 핫플', '문화', '전시'),
// ...

// 개선 — 더 구체적이고 실제 데이트 블로그에서 검증된 키워드
const _SlotQuery('갤러리 인디 전시 감성 아트 팝업', '전시·문화', '전시'),
const _SlotQuery('복합문화공간 팝업스토어 감각적인', '전시·문화', '전시'),
const _SlotQuery('향수 조향 클래스 프래그런스 체험', '체험·클래스', '체험'),
const _SlotQuery('커플링 반지 팔찌 공방 만들기', '체험·클래스', '체험'),
const _SlotQuery('소극장 뮤지컬 공연 라이브', '공연', '공연'),
const _SlotQuery('포토스팟 감성 사진 인스타 명소', '문화', '전시'),
const _SlotQuery('필름카메라 아날로그 감성 체험', '체험·클래스', '체험'),
```

#### 액티비티 챌린지 PEAK (mood == '액티비티')
```dart
// 개선 — 실제 인기 액티비티 장소 키워드
const _SlotQuery('방탈출 카페 추리 미스터리 커플', '액티비티', '액티비티'),
const _SlotQuery('실내 클라이밍 스포츠 센터', '액티비티', '체험'),
const _SlotQuery('트램폴린 파크 점프 실내', '액티비티', '액티비티'),
const _SlotQuery('레이저 태그 서바이벌 실내 게임', '액티비티', '액티비티'),
const _SlotQuery('VR 가상현실 체험 어트랙션', '액티비티', '체험'),
const _SlotQuery('볼링장 커플 스포츠', '액티비티', '액티비티'),
const _SlotQuery('스크린야구 타격연습장 스포츠', '액티비티', '액티비티'),
const _SlotQuery('보드게임카페 테이블게임 실내', '액티비티', '액티비티'),
```

#### 로컬 힐링 PEAK (mood == '힐링')
```dart
// 개선 — 실제 힐링 데이트 장소 키워드
const _SlotQuery('도예 흙빚기 도자기 공방 체험', '체험·클래스', '체험'),
const _SlotQuery('캔들 향초 디퓨저 만들기 공방', '체험·클래스', '체험'),
const _SlotQuery('플라워 꽃꽂이 클래스 체험', '체험·클래스', '체험'),
const _SlotQuery('한옥 전통 마을 산책 골목', '문화', '전시'),
const _SlotQuery('정원 식물원 자연 산책 공원', '야외', '야경'),
const _SlotQuery('독립서점 북카페 조용한 힐링', '문화', '전시'),
const _SlotQuery('테라리움 미니정원 만들기 체험', '체험·클래스', '체험'),
```

---

### Phase 4 — Gemini 프롬프트 아키타입 제약 강화
**파일**: `lib/services/gemini_service.dart`

`_selectArchetypes()` 아래의 `_peakConstraint` switch를 확장:

```dart
final peakConstraint = switch (a['concept']) {
  '감성 로맨스' => '''※ PEAK는 반드시 이 중 하나: 
    전시/갤러리/복합문화공간, 향수/커플링/공방 체험, 소극장/공연, 포토스팟.
    방탈출·볼링·일반 카페 금지.
  ※ CLOSE는 반드시 이 중 하나:
    이탈리안, 이자카야(고급), 와인바, 한식 코스.
    패스트푸드·체인 식당·분식 절대 금지.''',
    
  '액티비티 챌린지' => '''※ PEAK는 반드시 이 중 하나:
    방탈출, 볼링, 클라이밍, VR, 레이저태그, 트램폴린, 스크린골프, 보드게임.
    갤러리·카페·공원 PEAK 절대 금지.
  ※ CLOSE는 든든한 것:
    고기집(삼겹살/갈비), 이자카야, 라멘, 한식 맛집.
    파인다이닝·분위기 위주 레스토랑 비추천.''',
    
  '로컬 힐링' => '''※ PEAK는 반드시 이 중 하나:
    도예/캔들/향수/플라워 공방, 한옥마을/전통 산책, 독립서점, 자연 정원.
    소란스러운 방탈출·볼링·VR 절대 금지.
  ※ CLOSE는 조용하고 아늑한 것:
    한식(한정식/소박한 집밥형), 건강식, 채식 레스토랑.
    시끄러운 이자카야·고기집 비추천.''',
    
  '힙스터 컬처' => '※ PEAK는 팝업·독립갤러리·복합문화공간·트렌디 전시만.',
  '럭셔리 스페셜' => '※ PEAK는 고급 공연·전시·갤러리·프리미엄 체험만. 방탈출·볼링·일반 카페 금지.',
  '인스타 포토' => '※ PEAK는 포토스팟·루프탑·감각적 전시·SNS 비주얼 최강 공간만.',
  _ => '',
};
```

---

### Phase 5 — Supabase 큐레이션 DB (중기, 1~2주)

#### 테이블 구조
```sql
create table date_places (
  id text primary key,           -- 고유 ID
  name text not null,             -- 장소명
  city text not null,             -- 서울/부산/대전/인천
  district text,                  -- 성수/홍대/한남/강남
  slot text not null,             -- open/peak/close
  archetype text[],               -- 적합한 아키타입 목록
                                  -- ['감성 로맨스', '힙스터 컬처']
  vibe_tags text[],               -- ['조명어두움', '프라이빗', '인스타']
  tier int default 1,             -- 1=독립 로컬, 2=준체인, 3=대형체인
  price_level int,                -- 1~4 (₩~₩₩₩₩)
  lat float8,
  lng float8,
  naver_url text,
  thumbnail text,
  is_active bool default true,
  created_at timestamp default now()
);
```

#### 첫 번째 시드 데이터 (서울 감성 로맨스 PEAK)
| name | district | slot | archetype | tier |
|---|---|---|---|---|
| 리움미술관 | 한남 | peak | 감성 로맨스, 럭셔리 스페셜 | 1 |
| 대림창고 | 성수 | peak | 감성 로맨스, 힙스터 컬처 | 1 |
| 문화역서울 284 | 을지로 | peak | 힙스터 컬처, 감성 로맨스 | 1 |
| 닷노트 강남 | 강남 | peak | 감성 로맨스, 로컬 힐링 | 1 |
| 닷노트 성수 | 성수 | peak | 감성 로맨스, 로컬 힐링 | 1 |
| 논픽션 한남 | 한남 | peak | 감성 로맨스 | 1 |
| 오포르쇼룸 | 홍대 | peak | 감성 로맨스 | 1 |
| 위에트 홍대 | 홍대 | peak | 감성 로맨스 | 1 |

---

## 우선순위 실행 순서

| 순위 | 작업 | 파일 | 예상 시간 | 기대 효과 |
|---|---|---|---|---|
| 1 | 브랜드 블랙리스트 추가 | naver_place_service.dart | 30분 | 맥도날드 즉시 제거 |
| 2 | 체인점 페널티 배수 | place_ranker.dart | 1시간 | 체인점 전체 하위권 |
| 3 | 아키타입별 PEAK 쿼리 전면 개선 | naver_place_service.dart | 2~3시간 | 아키타입 정합성 향상 |
| 4 | Gemini CLOSE 제약 강화 | gemini_service.dart | 1시간 | Gemini 필터링 강화 |
| 5 | Supabase 큐레이션 DB | Supabase | 1~2주 | 근본적 품질 해결 |

---

*이 파일은 ODD 앱 코스 품질 개선의 로드맵. 모든 Phase 완료 후 v3.12.0으로 빌드 권장.*
