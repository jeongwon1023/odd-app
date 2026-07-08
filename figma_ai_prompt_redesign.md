# ODD 앱 전면 리디자인 — Figma AI(Make) 프롬프트 v2

> 목표: **AI/테크 느낌 제거 → 따뜻한 자연색 · 한눈에 들어오는 밀도 · 모든 탭 재창작.**
> 아래 큰 블록을 Figma Make(또는 Figma AI)에 그대로 붙여넣으면 됩니다. 필요 시 상단 "붙여넣기용 프롬프트"만 복사하세요.

---

## 0. 방향 요약 (사람이 먼저 읽는 부분)

- **브랜드 재정의**: "AI 데이트 플래너" → **"우리 동네 데이트 큐레이션"**. 손으로 고른 신뢰감, 따뜻한 로컬 매거진/시티가이드 감성.
- **덜어낼 것**: ✦ 반짝이·로봇 아이콘·"AI가 설계하는" 카피·인디고 테크 그라디언트·중복 CTA·화면 밖으로 내보내는 배너 캐러셀·챗봇을 코스의 메인 플로우로 두는 구조.
- **더할 것**: 항상 보이는 지역 선택, "코스=3스톱 동선"이 한 줄에 읽히는 카드, 이색 데이트 발견 영역, 신뢰 신호(실제 사진·검증 배지·평점·동네명), 지도 우선.
- **한눈에**: 큰 히어로 캐러셀 축소, 2열 그리드로 스캔성↑, 카드당 정보는 이미지+제목+메타 2개 이하, 여백은 넉넉하되 장식용 원·블롭 제거.

---

## 붙여넣기용 프롬프트 (여기부터 복사)

```
Design a complete, cohesive mobile app UI (iOS/Android, 390pt width) for "ODD (오드)" — a Korean date-course curation app for couples in their 20s–30s. It helps couples discover verified, real date courses (a route of 3 stops: 카페 → 체험/문화 → 맛집) and places across Korean cities.

CRITICAL BRAND DIRECTION
- Feel: warm, human, editorial — like a cozy local city-guide zine / lifestyle magazine. NOT techy, NOT "AI".
- REMOVE any "AI" cues: no sparkles (✦/✨), no robot/auto_awesome icons, no "AI가 설계", no glowing indigo/purple tech gradients, no neon.
- Voice: warm and personal Korean ("정원님, 오늘 우리 동네 데이트 어때요?"), trust-forward ("검증된 코스", "실제 사진", "손으로 고른").
- Everything should be readable AT A GLANCE: strong hierarchy, generous whitespace, but dense enough to scan quickly.

=== COLOR PALETTE (natural, warm — use exactly) ===
- Background (paper): #FAF6EF  (warm cream)
- Surface / card: #FFFFFF  (with a very soft warm shadow: 0 6px 16px rgba(60,45,30,0.06))
- Primary (brand + primary actions): #C4664A  (terracotta clay)
- Primary deep (pressed / emphasis): #A6522F
- Secondary (calm natural): #6E7A5A  (sage / olive)
- Accent (save/heart, small highlights — use sparingly): #E58A5B  (soft warm coral)
- Text primary: #2C2825  (warm near-black, never pure black, never indigo)
- Text secondary: #7B7167  (warm taupe)
- Text tertiary / muted: #A79E92
- Divider / hairline: #ECE4D8
- Category soft tint chips (backgrounds):
   카페 #F3E7DA · 맛집 #F1DED4 · 체험·이색 #E7ECDD · 전시·문화 #E5E0D3 · 야경·뷰 #DFE3E6
(Overall impression: cream paper + terracotta + sage + warm neutrals. Earthy, inviting, analog.)

=== TYPOGRAPHY (kill the AI feel with editorial type) ===
- Display / section titles: a warm Korean SERIF for editorial warmth (e.g., Nanum Myeongjo / RIDIBatang style). Large, calm, -1% tracking.
- Body / labels / meta / buttons: Pretendard (humanist sans). Body 14–15px, line-height 1.6.
- Numbers/ratings: Pretendard semibold.
- Avoid monospace and geometric-techno fonts entirely.

=== SHAPE & SPACING ===
- Corner radius: cards 16px, images 14px, chips 20px (pill), sheets/modals 24px top.
- Screen horizontal margin: 20px. Section vertical gap: 28px. Card inner padding: 14–16px.
- Shadows: max opacity 0.06, warm-tinted. No hard borders except 1px #ECE4D8 hairlines.
- Touch targets ≥ 44px.

=== SIGNATURE COMPONENT: "한눈에 코스 카드" (at-a-glance course card) ===
The most important reusable component. A course must be scannable in one glance:
- Layout A (feature, full-width ~ 358×230): top = a 3-photo route strip (three small rounded thumbnails of the 3 stops connected by a thin dashed terracotta line with numbers 1·2·3). Below: course title (serif, 18px), then ONE meta row of small pills: ⏱ 4시간 · ₩ 3만원대 · 🚶 도보 · 📍유성구. Save heart top-right. Soft cream card.
- Layout B (compact, 2-col grid ~ 170×210): one cover photo (top ~55%) with the 3 stops as a tiny numbered route overlay at the bottom of the photo; below photo: title (2 lines), meta row (⏱·₩·동네). 
No gradients over the whole card — keep it paper/white with real photos.

=== BOTTOM NAVIGATION (flat, warm, labeled — no elevated glowing FAB) ===
5 tabs, flat and equal, labels always visible:
홈 · 둘러보기 · 코스 · 저장 · 나
- Icons: simple line icons (house, compass/map-pin, route, bookmark, person). Active = terracotta #C4664A filled + label; inactive = #A79E92.
- Bar: #FFFFFF, 1px top hairline #ECE4D8. The center "코스" is slightly emphasized with a small terracotta dot under the label, NOT a raised gradient circle.

=== SCREENS (redesign ALL, new layouts — do not copy typical templates) ===

1) 홈 "오늘의 데이트"
- Cream background. Top row: small wordmark "ODD" (serif) left; region chip "📍 대전 유성구 ▾" center-left (tappable, prominent); bell icon right (single small red dot).
- Editorial hero line (serif, 22px): "정원님, 오늘 유성구에서\n느긋한 데이트 어때요?" — personal, no AI.
- Primary block: ONE big "오늘의 추천 코스" at-a-glance course card (Layout A), horizontally swipeable (dots below). Real photos, route strip, meta pills.
- Section "이번 주 인기 코스": 2-column grid of compact course cards (Layout B). Small "인기 1·2·3" ranking tag in sage.
- Section "이색 데이트": a row of soft-tint category tiles (만화카페 · 카트장 · 방탈출 · 동물카페 · 원데이클래스) as rounded chips with tiny illustrations/photos, then 2–3 compact course cards.
- Section "가까운 카페 · 맛집": 2-column place grid (compact place cards).
- Section "지금 우리 동네 문화행사": horizontal compact list cards (thumbnail + title 2 lines + date).
- Pull-to-refresh. Remove all decorative gradient banners and floating circles.

2) 둘러보기 "장소 · 지도" (map-forward)
- Top ~42% = a NAVER-style map area (rounded bottom corners) showing pins for the current region / nearby. A small segmented control floats on the map: "내 주변" | "선택 지역" (clear which is active). A radius slider chip only in 내 주변 mode.
- Below the map = a draggable bottom sheet (rounded 24px top, cream). Inside: horizontal category chips (전체 · 카페 · 맛집 · 루프탑 · 체험 · 이색 · 전시·문화 · 문화행사), a compact filter row ("32곳" bold + "정렬 ▾" + "지금 영업중" toggle in sage), then a 2-column place grid.
- Place card (compact): square photo, bookmark top-right, name (bold 14px), meta "카페 · 봉명동", ⭐4.6 (36 리뷰). Keep it tight — no "AI 이유" pills.

3) 코스 "코스 찾기" (reimagined — NOT a chatbot as the hero)
- Warm intro (serif): "어떤 데이트가 좋아요?"
- Tap-to-pick chip groups (big, friendly, one screen, no typing required):
   분위기: 감성 · 액티비티 · 힐링 · 이색   |   시간: 낮 · 저녁 · 하루 종일
   예산: 가성비 · 적당 · 특별하게   |   지역: (현재 지역 chip, 변경 가능)
   Selected chips fill terracotta.
- One primary button: "이 조건으로 코스 찾기" (terracotta, full width).
- A subtle secondary text link below: "말로 자세히 말할래요 →" (opens the optional conversational flow). Conversation is secondary, never the main surface.
- Loading copy while searching: "검증된 코스를 찾고 있어요" (never "AI가 만들고").

4) 코스 결과 "한눈에 동선"
- Top: a NAVER-style route map hero (~230px) showing the 3 stops + dashed terracotta route + numbered pins.
- Just under the map: a single at-a-glance summary bar: ⏱ 총 4시간 · ₩ 1인 3만원대 · 🚶 도보 위주 · 📍유성구.
- 3 course variations as swipeable segmented cards labeled by real vibe (감성 · 액티비티 · 힐링) shown as small sage tabs — NOT big colored gradient tabs.
- Timeline: each stop = a horizontal card (photo thumbnail left, name + category + ⏱ + ₩ + one-line tip right), connected by a thin dashed line with "도보 6분" chips between. Per-stop small actions: 지도 · 예약.
- Bottom sticky: primary "코스 저장" (terracotta) + small 공유 icon. Remove duplicate map buttons (the hero map already covers it).

5) 저장
- Two segmented tabs: 코스 | 장소. 2-column grid of saved items using the same course/place cards. Empty state: warm illustration + "마음에 든 코스를 저장해 두세요".

6) 나 (MY)
- Warm profile header (avatar, 닉네임, 커플 연결 상태). 
- Rows: 취향 설정 · 저장한 코스 · 방문 기록 · 커플 연결 · 알림 · 앱 정보(버전). Clean list, hairline dividers, terracotta accents. No tech gradients.

7) 장소 상세
- Image hero (full-width ~240px) with back + bookmark overlaid (subtle). 
- Below: place name (serif 22px); ONE meta row: 카페 · 봉명동 · ⭐4.6 (320); status chip 영업중/영업종료.
- A compact NAVER-style mini map (rounded, ~150px) with "지도 크게 보기".
- 소개 (short, human — 2–3 lines). 리뷰 (2–3 preview cards). 사진 그리드.
- Primary CTA (sticky bottom): "이 장소로 코스 짜기" (terracotta). Directions live inside the full map screen, not as a second big button here.

=== DELIVERY ===
Produce a consistent multi-screen design: 홈, 둘러보기, 코스 찾기, 코스 결과, 저장, 나, 장소 상세 — plus the shared components (한눈에 코스 카드 A/B, 장소 카드, 카테고리 chip, bottom nav, region selector sheet, 지역 선택 bottom sheet). Keep one cohesive warm-natural system across every screen. Prioritize glanceability and trust over decoration.
```

## (여기까지 복사)

---

## 1. 색상 대안 (원하면 프롬프트의 팔레트만 교체)

- **A. 테라코타 + 크림 + 세이지 (기본 추천, 위 프롬프트)** — 따뜻하고 데이트 감성, 신뢰감. 20~30대 커플에 무난히 사랑받는 톤.
- **B. 세이지 포워드(차분·자연)** — Primary #6E7A5A(sage), Accent #C08552(clay), bg #F6F4EC. 더 차분·중성적. 감성/힐링 강조 시.
- **C. 딥 그린 + 오트밀(고급·로컬)** — Primary #3E5C4B(forest), bg #F4F1E9(oat), Accent #D2A24C(mustard). 프리미엄·로컬 큐레이션 느낌.

세 가지 모두 "AI/테크"에서 멀고 자연스러워요. 기본은 A로 두었습니다.

## 2. 왜 이렇게 바꿨나 (의사결정 메모)

- **AI 느낌 제거**: 인디고 그라디언트·✦·"AI 플래너"가 테크·비인간 느낌의 핵심이라 전부 걷어내고, 크림 종이색 + 따뜻한 세리프 제목으로 "사람이 큐레이션한" 감성으로 전환.
- **한눈에**: 코스의 본질은 "3스톱 동선"인데 기존엔 큰 카드 여러 개로 흩어져 스캔이 안 됐어요. → **route strip(3썸네일+번호선) + 메타 1줄** 하나로 코스를 한 줄에 읽게. 브라우즈는 2열 그리드로 밀도↑.
- **코스 탭 재창작**: 5단계 챗봇을 메인에서 내리고 **탭 몇 번으로 조건 선택 → 검증 코스 결과**로. (대화는 옵션.) 우리 원칙(생성 금지·DB 검색)과도 일치.
- **지도 우선**: 둘러보기·코스 결과를 네이버 지도 상단 구조로 — 이미 네이티브 지도가 붙었으니 UX가 일관돼요.
- **덜어냄**: 중복 지도 버튼·장식 배너·과한 배지·이모지 남발 제거로 시선 정리.
