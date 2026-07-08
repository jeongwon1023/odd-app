# ODD 앱 Figma AI Make 프롬프트

---

## 앱 아이콘 디자인 프롬프트

```
Design a modern mobile app icon for a Korean dating course recommendation app called "ODD" (Oddly Date Discovery).

Style: Clean, minimal, premium white-tone with soft indigo/lavender accent.
Shape: Rounded square (iOS/Android standard superellipse).
Background: Pure white (#FFFFFF) or very light gray (#F5F5F8).
Central graphic: A stylized heart combined with a location pin, or two overlapping circles (representing a couple) with a subtle route/path connecting them. Use indigo (#5C6BC0) as the primary color with a gentle coral accent (#FF6B6B) for warmth.
Typography: "ODD" in a bold, modern sans-serif. Small subtitle "date" in light weight below.
Mood: Sophisticated, warm, approachable. Not too playful, not too corporate.
Avoid: Gradients that are too bright, overly complex illustrations, clutter.
```

---

## 전체 앱 UI 디자인 프롬프트

```
Design a complete mobile app UI for "ODD" — a Korean dating course discovery and recommendation app. The app helps couples find date courses (café + experience + restaurant routes) in Korean cities.

=== DESIGN SYSTEM ===
Color palette (white-tone, minimal):
- Background: #FFFFFF (primary), #F5F5F8 (secondary surfaces)
- Primary accent: #5C6BC0 (indigo/lavender)
- Secondary accent: #FF6B6B (soft coral — sparingly, for CTAs only)
- Text dark: #1A1A2E
- Text mid: #6B7280
- Text light: #9CA3AF
- Card background: #FFFFFF with subtle shadow (0px 4px 12px rgba(0,0,0,0.06))
- Chip background: #EEF0F8 (light indigo tint)

Typography:
- Headings: Bold, tight letter-spacing (-0.5px), 20-24px
- Body: Regular 14-15px, line-height 1.6
- Labels/chips: Semibold 11-12px
- Font: System UI (Apple/Android default), or Pretendard if web

Corner radius: 12-16px for cards, 20-24px for bottom sheets and modals, 8px for chips.

Spacing: 16-20px horizontal padding, 12-16px between sections.

=== SCREENS TO DESIGN ===

**1. HOME SCREEN**
Layout: Vertical scroll. White background.
- Top bar: Location selector (city name + chevron) left, notification bell right. No search bar here.
- Section 1: "오늘의 데이트 코스" — 2 horizontal scrollable large cards (320×180px). Each card shows: course image (full bleed), gradient overlay bottom, course title, 3 place names as horizontal pills, heart/save icon.
- Section 2: "이번 주 인기 코스" — horizontal row of 3 compact vertical cards (150×200px). Course name, 3 places, save count badge.
- Section 3: "내 주변 핫플" — 2-column grid of place cards. Each card: place photo top 60%, name, category chip, rating (star icon + number), distance badge.
- Bottom section: "특별한 날 코스" banner — full-width card with subtle indigo gradient, title "기념일·발렌타인 코스", 3 course thumbnails as overlapping circles.

**2. EXPLORE SCREEN (탐색)**
Layout: Fixed header, scrollable content below.
- Header: White background. Search bar (rounded, light gray fill, search icon). Below search: horizontal scrollable category chips (전체, 코스요리, 카페, 루프탑, 체험, 전시·문화, 문화행사). Active chip: indigo fill + white text. Inactive: white/light gray border.
- Filter row (below chips): left = "32개의 장소" in indigo bold + gray text. Right = sort button "거리순 ▾" as small pill with border, tappable.
- Also show a small "지금 영업중" toggle chip in green when active.
- Content: 2-column grid of place cards. Each card: photo top (aspect ratio ~1:1), bookmark icon top-right, name (bold 13px), "✦AI [reason text]" pill in indigo tint below name, meta text (category · address), 3 date chips at bottom (오늘/내일/날짜 as small pills).
- Cultural event tab view: full-width list cards (horizontal layout). Left: square thumbnail or emoji box (88px). Right: realm tag chip, title (bold 14px, 2 lines), venue, date range. Right edge: chevron or external link icon.

**3. CULTURAL EVENT DETAIL SCREEN (문화행사 상세)**
Layout: Full-screen modal/push.
- Hero image: full-width, 220px tall, with AppBar overlaid (back arrow, transparent).
- Below hero: Padding 20px all sides.
  - Tags row: realm chip (indigo) + "진행중" chip (green) if active.
  - Title: 20px bold, tight.
  - Info rows: icon + text for date, venue, region, price. Each row 16px with left icon.
  - "행사 소개" section header + body text.
  - At bottom: outlined button "공식 페이지에서 더 보기" — indigo border, indigo text, external link icon.

**4. COURSE RESULT SCREEN (코스 결과)**
Layout: TabBar (3 tabs: 💕 감성 로맨스 / 🎯 액티비티 챌린지 / 🌿 로컬 힐링) at top. Each tab shows one complete course.
- Tab bar: white background, indigo indicator underline, bold tab text.
- Course card (each stop): large card (full width), place photo 180px tall, gradient overlay, place name white bold at bottom. Below image: AI reason text in small indigo pill. Then: duration chip, category chip.
- Timeline between cards: thin vertical line with dot connector.
- Bottom: "이 코스 저장하기" button (indigo gradient, full width, 54px tall).

**5. PLACE DETAIL SCREEN (장소 상세)**
Layout: TabBar with 5 tabs: 홈 / 사진 / 리뷰 / 코스 추천 / 매장정보.
- Top hero: full-width image 240px, gradient overlay. Back arrow + bookmark icon overlaid.
- Below hero: place name 22px bold, category chip row, rating + review count.
- Info chips: address, hours, open/closed status, 예약 필수 (if applicable).
- "코스 추천" tab: gradient header card (indigo), 3 archetype preview chips (감성/액티비티/힐링 as colored mini cards), time slot selector (4 options as equal-width buttons), info note, large CTA button "✨ 3가지 코스 추천받기".

**6. AI COURSE (코스 탭)**
Layout: Gradient header section (indigo to purple), white body.
- Header: "ODD 코스" large title white, subtitle "AI가 맞춤 데이트 코스를 추천해드려요".
- Quick chips: 오늘 데이트 / 이번 주말 / 기념일 as horizontal scrollable chips.
- Suggestion chips: pre-set query chips in light indigo.
- Chat input: bottom fixed bar, text field, send button.

=== DESIGN PRINCIPLES ===
- Whitespace is a feature — don't fill every pixel.
- Cards breathe with 12-16px internal padding.
- Primary action buttons always use indigo gradient (#5C6BC0 → #7986CB).
- Secondary actions use outlined style (indigo border, white fill).
- All touch targets minimum 44px.
- Photos always have a bottom gradient overlay for text legibility.
- Consistent 16px horizontal screen margin throughout.
- Avoid drop shadows heavier than 0.06 opacity.
```

---

## 추가 컴포넌트 프롬프트 (선택)

```
Design individual UI components for the ODD dating app:

1. Course card (horizontal): 320×180px, full-bleed photo, gradient bottom overlay, white title text, 3 place name pills, heart icon top-right.

2. Place card (vertical, 2-col grid): white background, rounded 12px, photo top 55% with bookmark icon, then name (13px bold), AI reason pill (indigo tint), meta text (gray 10px), 3 date chips at bottom.

3. Category chip (active/inactive states): active = indigo fill white text, inactive = light gray fill dark text, both 8px radius, 8px vertical / 14px horizontal padding.

4. Sort dropdown button: small pill "거리순 ▾", light gray border, 12px semibold, indigo when alternate sort is active.

5. Cultural event list card: full-width horizontal card, 88px square thumbnail left, text right (realm chip, title 2-line, venue, date), chevron right.

6. Bottom navigation bar: 5 tabs — 홈 (home icon), 탐색 (compass), 코스 (route icon, center FAB elevated), 저장 (bookmark), MY (person). Center FAB: circular, indigo gradient, elevated 8dp shadow. Active icons: indigo, inactive: gray #9CA3AF. White background, subtle top border.
```
