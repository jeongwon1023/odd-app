import 'dart:convert';
import 'dart:math' as math;
import 'package:google_generative_ai/google_generative_ai.dart';
import '../config/env.dart';
import '../models/place_model.dart';
import 'weather_service.dart';

class GeminiService {
  static GenerativeModel? _model;
  static ChatSession? _chat;

  // 데이트 부적합 장소 블랙리스트 — 슬롯 검증 전 최우선 배제
  static const List<String> _dateBlacklist = [
    '사원', '교회', '성당', '절', '불교', '이슬람', '종교',
    '관공서', '주민센터', '시청', '구청', '동사무소', '공공',
    '병원', '의원', '약국', '응급', '산부인과',
    '보리밥', '국밥', '해장국', '순대국', '곱창',
    '장례', '세탁', '은행', '우체국', '학원',
  ];

  static GenerativeModel get _instance {
    _model ??= GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: Env.geminiApiKey,
      systemInstruction: Content.system('''
당신은 ODD의 데이트 플래너 AI "ODD AI"입니다.

[페르소나]
- 20대 커플의 데이트를 진심으로 응원하는 따뜻한 친구 같은 조언자
- 서울·부산·대전 등 한국 전국의 핫플레이스와 데이트 문화에 정통한 로컬 전문가
- 유행하는 카페·전시·맛집·야경 스팟 트렌드를 꿰뚫고 있는 감성 큐레이터

[대화 원칙]
1. 따뜻하고 설레는 언어로 짧게 답변 — 문어체 금지, 친구에게 말하듯
2. "AI", "API", "검색 중", "데이터베이스" 등 기술적 표현 절대 언급 금지
3. 항상 한국어로 답변
4. 장소 설명은 데이트 감성을 담아 시각적이고 감성적으로 표현
5. 코스 추천 시 OPEN(카페/브런치) → PEAK(경험/문화) → CLOSE(식사) 흐름 유지
6. 모르는 장소를 만들어내지 말고, 실제 제공된 목록에서만 선택
7. 질문은 한 번에 하나씩, 공감 → 정보 → 추천 순으로 자연스럽게 흐르게

[추천 철학]
- 단순 목록 나열이 아닌, 스토리가 있는 데이트 동선을 만들어라
- 계절·시간대·날씨·요일 컨텍스트를 항상 반영해라
- 같이 경험할 때 생기는 설렘과 추억을 중심으로 설명해라
'''),
    );
    return _model!;
  }

  /// 새 채팅 세션 시작
  static void startNewChat() {
    _chat = _instance.startChat();
  }

  /// 생성된 코스를 채팅 세션에 컨텍스트로 주입
  /// → 이후 "1번 코스 어디야?", "카페 이름이 뭐야?" 같은 질문에 답변 가능
  static Future<void> injectCourseContext(List<DateCourse> courses) async {
    if (courses.isEmpty) return;
    _chat ??= _instance.startChat();
    final sb = StringBuffer();
    sb.writeln('[방금 사용자에게 추천된 코스 — 이 내용을 기억하고 대화에 활용하라]');
    for (int i = 0; i < courses.length; i++) {
      final c = courses[i];
      sb.writeln('\n${i + 1}번 코스: ${c.title} (${c.mood})');
      sb.writeln('  설명: ${c.description}');
      for (int j = 0; j < c.places.length; j++) {
        final p = c.places[j];
        final slotLabel = ['OPEN', 'PEAK', 'CLOSE'][j.clamp(0, 2)];
        sb.writeln('  [$slotLabel] ${p.name} — ${p.category} — ${p.address}');
        if (p.aiReason?.isNotEmpty == true) sb.writeln('    이유: ${p.aiReason}');
      }
    }
    sb.writeln('\n[위 코스를 기억하고, 사용자가 특정 코스나 장소에 대해 물어보면 정확히 답하라]');
    try {
      await _chat!.sendMessage(Content.text(sb.toString()));
    } catch (_) { /* 실패해도 무시 */ }
  }

  /// 코스 수정 의도 감지 — "다른 카페로", "맛집 바꿔줘" 등
  static bool isModificationRequest(String text) {
    const modKeywords = ['바꿔', '다른', '대신', '말고', '빼줘', '추가', '바꿔줘', '교체'];
    const placeKeywords = ['카페', '맛집', '식당', '코스', '장소', '체험', '전시'];
    final hasModifier = modKeywords.any((k) => text.contains(k));
    final hasPlace    = placeKeywords.any((k) => text.contains(k));
    return hasModifier && hasPlace;
  }

  /// 일반 채팅 메시지 전송 (단발 응답)
  static Future<String> sendMessage(String message) async {
    _chat ??= _instance.startChat();
    try {
      final response = await _chat!.sendMessage(Content.text(message));
      return response.text ?? '잠시 후 다시 시도해주세요.';
    } catch (_) {
      return '연결이 불안정해요. 잠시 후 다시 시도해주세요.';
    }
  }

  /// 스트리밍 채팅 — 글자가 실시간으로 흘러나오는 타이핑 효과
  static Stream<String> sendMessageStream(String message) async* {
    _chat ??= _instance.startChat();
    try {
      final stream = _chat!.sendMessageStream(Content.text(message));
      await for (final chunk in stream) {
        final text = chunk.text;
        if (text != null && text.isNotEmpty) yield text;
      }
    } catch (_) {
      yield '연결이 불안정해요. 잠시 후 다시 시도해주세요.';
    }
  }

  /// 코스 관련 상황인지 판단 (스트리밍 vs 단발 선택용)
  static bool isCourseRequest(String message) {
    const courseKeywords = ['코스', '추천', '데이트', '어디', '장소', '어때', '좋아', '가고 싶'];
    return courseKeywords.any((kw) => message.contains(kw));
  }

  /// 사용자의 자유 입력 한 문장에서 5개 단계를 모두 한 번에 추론
  /// 반환: {mood, specialDay, time, transport, budget} — 추론 불가 필드는 'unknown'
  static Future<Map<String, String>> interpretAllSteps(String userText) async {
    final prompt = '''
사용자가 데이트 코스를 요청했습니다: "$userText"

아래 5가지 항목을 최대한 추론하세요. 추론 불가는 "unknown".
JSON만 반환, 설명/마크다운 없음.

{
  "mood": "감성" | "액티비티" | "힐링" | "혼합" | "unknown",
  "specialDay": "일상" | "기념일" | "첫만남" | "unknown",
  "time": "낮" | "저녁" | "하루종일" | "unknown",
  "transport": "도보" | "차량" | "대중교통" | "unknown",
  "budget": "저렴" | "보통" | "고급" | "unknown"
}

예시:
- "내일 낮에 감성 데이트" → mood:감성, time:낮, 나머지 unknown
- "기념일 저녁 파인다이닝" → specialDay:기념일, time:저녁, budget:고급
- "차 타고 힐링하고 싶어" → mood:힐링, transport:차량
''';

    try {
      final resp = await _instance.generateContent([Content.text(prompt)]);
      final raw = resp.text ?? '';
      final start = raw.indexOf('{');
      final end   = raw.lastIndexOf('}');
      if (start == -1 || end == -1) return _unknownSteps();
      final parsed = json.decode(raw.substring(start, end + 1)) as Map<String, dynamic>;
      return {
        'mood':       parsed['mood']?.toString()       ?? 'unknown',
        'specialDay': parsed['specialDay']?.toString() ?? 'unknown',
        'time':       parsed['time']?.toString()       ?? 'unknown',
        'transport':  parsed['transport']?.toString()  ?? 'unknown',
        'budget':     parsed['budget']?.toString()     ?? 'unknown',
      };
    } catch (_) {
      return _unknownSteps();
    }
  }

  static Map<String, String> _unknownSteps() => {
    'mood': 'unknown', 'specialDay': 'unknown',
    'time': 'unknown', 'transport': 'unknown', 'budget': 'unknown',
  };

  // ─────────────────────────────────────────────
  // 9개 코스 아키타입 정의 (이모티콘 없음)
  // ─────────────────────────────────────────────
  static const List<Map<String, String>> _archetypes = [
    {
      'concept': '감성 로맨스',
      'desc': '분위기와 감성을 최우선으로. 조명·인테리어·감성 공간 위주 조합.',
    },
    {
      'concept': '힙스터 컬처',
      'desc': '독특하고 트렌디한 문화 공간 탐방. 팝업·갤러리·복합문화공간 위주.',
    },
    {
      'concept': '인스타 포토',
      'desc': 'SNS 비주얼이 최우선. 루프탑·뷰맛집·포토스팟·사진 퀄리티 최고 조합.',
    },
    {
      'concept': '액티비티 챌린지',
      'desc': '신나고 활동적인 경험 위주. 방탈출·볼링·클라이밍·체험형 공간.',
    },
    {
      'concept': '럭셔리 스페셜',
      'desc': '프리미엄 경험으로 특별한 날을 완성. 파인다이닝·고급 공연·분위기 최고 공간.',
    },
    {
      'concept': '로컬 힐링',
      'desc': '여유롭고 소소한 로컬 탐방. 골목 카페·공방·건강식·자연 친화 공간.',
    },
    {
      'concept': '야경 데이트',
      'desc': '저녁 이후 시작하는 밤 데이트. 루프탑·야경 뷰포인트·야간 레스토랑 위주.',
    },
    {
      'concept': '미식 투어',
      'desc': '먹는 즐거움 중심의 코스. 유명 카페·줄 서는 맛집·달달한 디저트 위주.',
    },
    {
      'concept': '자연 힐링',
      'desc': '자연 속에서 재충전. 공원 카페·트레킹·계곡·식물원·로컬 밥집.',
    },
  ];

  /// 분위기/예산/특별한날/시간대에 따라 3개 아키타입 선택
  /// _archetypes 인덱스: 0=감성로맨스, 1=힙스터컬처, 2=인스타포토,
  ///   3=액티비티챌린지, 4=럭셔리스페셜, 5=로컬힐링,
  ///   6=야경데이트, 7=미식투어, 8=자연힐링
  static List<Map<String, String>> _selectArchetypes({
    required String mood,
    required String budget,
    required String specialDay,
    required String timeSlot,
  }) {
    // 야간 시간대: 야경 데이트 우선
    if (timeSlot == '야간' || timeSlot == '저녁') {
      if (budget == '고급') return [_archetypes[4], _archetypes[6], _archetypes[0]];
      return [_archetypes[6], _archetypes[0], _archetypes[1]];
    }
    // 기념일: 럭셔리 + 감성 + 야경
    if (specialDay == '기념일') {
      return [_archetypes[4], _archetypes[0], _archetypes[6]];
    }
    // 첫만남: 힙스터 + 인스타 + 감성
    if (specialDay == '첫만남') {
      return [_archetypes[1], _archetypes[2], _archetypes[0]];
    }
    // 고급 예산: 럭셔리 + 감성 + 인스타
    if (budget == '고급') {
      return [_archetypes[4], _archetypes[0], _archetypes[2]];
    }
    switch (mood) {
      case '감성':
        return [_archetypes[0], _archetypes[1], _archetypes[2]];
      case '액티비티':
        return [_archetypes[3], _archetypes[0], _archetypes[2]];
      case '힐링':
        return [_archetypes[5], _archetypes[8], _archetypes[0]];
      case '야경':
        return [_archetypes[6], _archetypes[0], _archetypes[4]];
      case '미식':
        return [_archetypes[7], _archetypes[0], _archetypes[1]];
      default: // 혼합
        return [_archetypes[0], _archetypes[2], _archetypes[1]];
    }
  }

  // ─────────────────────────────────────────────
  // 슬롯별 카테고리 유효성 검사
  // 0=OPEN(카페), 1=PEAK(체험/문화), 2=CLOSE(식사)
  // ─────────────────────────────────────────────
  static bool _isValidForSlot(Place p, int slotIdx, String timeSlot) {
    final name = p.name.toLowerCase();
    final cat = '${p.category} ${p.subcategory}'.toLowerCase();
    // 블랙리스트 우선 검사 — 데이트 부적합 장소는 슬롯 무관 배제
    for (final b in _dateBlacklist) {
      if (name.contains(b) || cat.contains(b)) return false;
    }
    switch (slotIdx) {
      case 0: // OPEN — 반드시 카페·브런치 계열
        return cat.contains('카페') || cat.contains('cafe') ||
               cat.contains('커피') || cat.contains('coffee') ||
               cat.contains('브런치') || cat.contains('베이커리') ||
               cat.contains('디저트') || cat.contains('bakery');
      case 1: // PEAK — 체험·문화. 카페·식당 제외
        return !cat.contains('카페') && !cat.contains('커피') &&
               !cat.contains('맛집') && !cat.contains('식당') &&
               !cat.contains('레스토랑') && !cat.contains('한식') &&
               !cat.contains('양식') && !cat.contains('일식') &&
               !cat.contains('파인다이닝');
      case 2: // CLOSE — 반드시 식당·레스토랑. 카페 제외.
              // 저녁 + 야경·뷰 허용
        final isYaGyeong = cat.contains('야경') || cat.contains('뷰');
        final isRestaurant = cat.contains('맛집') || cat.contains('식당') ||
            cat.contains('레스토랑') || cat.contains('한식') ||
            cat.contains('양식') || cat.contains('일식') ||
            cat.contains('파인다이닝') || cat.contains('restaurant');
        final isCafe = cat.contains('카페') || cat.contains('커피');
        if (isCafe) return false;
        return isRestaurant || (timeSlot == '저녁' && isYaGyeong);
      default:
        return true;
    }
  }

  /// 슬롯 인덱스에 맞는 풀에서 우선 검색
  static Place? _pickForSlot(
      int slotIdx, String timeSlot, List<Place> slotPool,
      List<Place> fallbackPool, List<Place> exclude) {
    final excludeIds = exclude.map((e) => e.id).toSet();
    // 1차: 슬롯 전용 풀 + 카테고리 검증
    for (final p in slotPool) {
      if (excludeIds.contains(p.id)) continue;
      if (_isValidForSlot(p, slotIdx, timeSlot)) return p;
    }
    // 2차: 폴백 풀 + 카테고리 검증
    for (final p in fallbackPool) {
      if (excludeIds.contains(p.id)) continue;
      if (_isValidForSlot(p, slotIdx, timeSlot)) return p;
    }
    // 3차: 슬롯 풀에서 카테고리 무시 (최후 수단) — 단, 블랙리스트는 반드시 통과
    for (final p in slotPool) {
      if (excludeIds.contains(p.id)) continue;
      final name = p.name.toLowerCase();
      final cat = '${p.category} ${p.subcategory}'.toLowerCase();
      if (_dateBlacklist.any((b) => name.contains(b) || cat.contains(b))) continue;
      return p;
    }
    return null;
  }

  /// 슬롯 기반 데이트 코스 3개 생성 (풀 3등분 파티션 + 아키타입별 전용 서브풀)
  static Future<List<DateCourse>> generateCourses({
    required String region,
    required String mood,
    required String timeSlot,
    required String budget,
    required Map<String, List<Place>> slots,
    String specialDay = '일상',
    String transport = '무관',
    WeatherInfo? weather,                      // 날씨 컨텍스트 (null = 맑음으로 간주)
    List<String> recentPlaces = const [],      // 히스토리 기반 중복 방지
    List<String> userTopCategories = const [], // Thompson Sampling 취향 카테고리
  }) async {
    // ── 풀 구성: 더 넓게 가져오기 ──────────────────────────────────────────
    final rawStart  = _dedupeById(slots['start']  ?? []);
    final rawMain   = _dedupeById(slots['main']   ?? []);
    final rawFinish = _dedupeById(slots['finish'] ?? []);

    // 최대 48개씩 (코스당 16개 확보 목표)
    final startFull  = rawStart.take(48).toList();
    final mainFull   = rawMain.take(48).toList();
    final finishFull = rawFinish.take(48).toList();

    final allPool = _dedupeById([...startFull, ...mainFull, ...finishFull]);
    if (allPool.isEmpty) return _fallbackCourses([], timeSlot: timeSlot);

    // ── 풀 라운드로빈 분배: 코스1(A) / 코스2(B) / 코스3(C) ─────────────────
    // 인덱스 기준 3등분 → 라운드로빈으로 교체:
    // 쿼리 순서 편향 제거 — 모든 쿼리 결과가 A/B/C에 균등 분산됨
    List<List<Place>> _roundRobin(List<Place> pool) {
      final a = <Place>[], b = <Place>[], c = <Place>[];
      for (int i = 0; i < pool.length; i++) {
        switch (i % 3) {
          case 0: a.add(pool[i]);
          case 1: b.add(pool[i]);
          case 2: c.add(pool[i]);
        }
      }
      // 어느 하나라도 비면 전체 풀로 폴백
      if (a.isEmpty || b.isEmpty || c.isEmpty) {
        return [pool, pool, pool];
      }
      return [a, b, c];
    }

    final startParts  = _roundRobin(startFull);
    final mainParts   = _roundRobin(mainFull);
    final finishParts = _roundRobin(finishFull);

    final startA = startParts[0];
    final startB = startParts[1];
    final startC = startParts[2];
    final mainA  = mainParts[0];
    final mainB  = mainParts[1];
    final mainC  = mainParts[2];
    final finA   = finishParts[0];
    final finB   = finishParts[1];
    final finC   = finishParts[2];

    // ── 아키타입 선택 ──────────────────────────────────────────────────────
    final archetypes = _selectArchetypes(
      mood: mood, budget: budget, specialDay: specialDay, timeSlot: timeSlot);

    // ── 컨텍스트 ──────────────────────────────────────────────────────────
    final now = DateTime.now();
    final hour = now.hour;
    final dayNames = ['월', '화', '수', '목', '금', '토', '일'];
    final dayStr = dayNames[now.weekday - 1];
    final season = _seasonHint(now.month);

    final transportGuide = switch (transport) {
      '도보' => '도보 위주 (1.5km 이내)',
      '차량' => '차량 이동 (넓은 반경 가능)',
      _     => '대중교통 (30분 이내)',
    };
    final budgetGuide = switch (budget) {
      '저렴' => '1인 2만원 이하',
      '고급' => '1인 8만원 이상 (파인다이닝 급)',
      _     => '1인 3~6만원',
    };
    final specialGuide = switch (specialDay) {
      '기념일' => ' | 🎉 기념일 — 특별하고 감동적인 조합 우선',
      '첫만남' => ' | 💬 첫만남 — 대화 편하고 자연스러운 조합 우선',
      _      => '',
    };

    // ── 장소 목록 문자열 생성 ──────────────────────────────────────────────
    String slotStr(List<Place> pool, String label) {
      if (pool.isEmpty) return '  [$label] (없음)';
      return pool.map((p) {
        final cat = p.subcategory.isNotEmpty ? p.subcategory : p.category;
        final coord = (p.lat != 0.0 && p.lng != 0.0)
            ? '${p.lat.toStringAsFixed(4)},${p.lng.toStringAsFixed(4)}'
            : '좌표없음';
        return '  - ${p.name} | $cat | ${p.priceRange} | $coord';
      }).join('\n');
    }

    String courseBlock(int idx, List<Place> sPool, List<Place> mPool, List<Place> fPool) {
      final a = archetypes[idx];
      // 아키타입별 PEAK 제약 (컨셉 오염 방지)
      final peakConstraint = switch (a['concept']) {
        '감성 로맨스'    => '※ PEAK는 갤러리/전시/공방/향수조향/커플링/소극장 중 하나. 방탈출·볼링 금지.\n'
                         '※ CLOSE는 이탈리안/이자카야/와인바/비스트로 중 하나. 패스트푸드·체인 절대 금지.',
        '액티비티 챌린지' => '※ PEAK는 방탈출/볼링/클라이밍/VR/레이저태그/트램폴린/스크린야구 중 하나. 갤러리·카페 금지.\n'
                          '※ CLOSE는 고기집/라멘/이자카야/치킨 계열. 파인다이닝 비추천.',
        '로컬 힐링'      => '※ PEAK는 도예/캔들/플라워공방/한옥/북카페/식물원 중 하나. 소란스러운 액티비티 금지.\n'
                          '※ CLOSE는 한식/건강식/채식/소박한 밥집. 시끄러운 이자카야 비추천.',
        '힙스터 컬처'    => '※ PEAK는 팝업·독립갤러리·복합문화공간·트렌디 전시만.',
        '럭셔리 스페셜'  => '※ PEAK는 고급 공연·전시·갤러리·프리미엄 체험만. 방탈출·볼링·일반 카페 금지.\n'
                          '※ CLOSE는 파인다이닝/오마카세/한정식코스. 체인 식당 절대 금지.',
        '인스타 포토'    => '※ PEAK는 포토스팟·루프탑·감각적 전시·SNS 비주얼 최강 공간만.',
        '야경 데이트'    => '※ PEAK는 야경 뷰포인트/루프탑/전망대/한강. 실내 체험 위주 금지.\n'
                          '※ CLOSE는 루프탑 레스토랑/야경뷰 레스토랑/야간 운영 이자카야.',
        '미식 투어'      => '※ PEAK는 유명 맛집/줄 서는 식당/특색있는 노포. 체험·전시 금지.\n'
                          '※ CLOSE는 달달한 디저트/아이스크림/디저트카페로 마무리.',
        '자연 힐링'      => '※ PEAK는 공원/산/둘레길/계곡/숲/식물원. 실내 체험 금지.\n'
                          '※ CLOSE는 로컬 식당/농가 밥상/시골 한식.',
        _                => '',
      };
      return '''
━━━ 코스${idx + 1}: ${a['concept']} ━━━
컨셉: ${a['desc']}
$peakConstraint
[OPEN — 반드시 아래 목록에서만 선택]
${slotStr(sPool, 'OPEN')}

[PEAK — 반드시 아래 목록에서만 선택]
${slotStr(mPool, 'PEAK')}

[CLOSE — 반드시 아래 목록에서만 선택]
${slotStr(fPool, 'CLOSE')}''';
    }

    // ── 날씨 컨텍스트 ─────────────────────────────────────────────────────
    final weatherLine = weather != null ? '\n${weather.promptLine}' : '';
    final weatherRule = (weather?.forceIndoor == true)
        ? '\n7. 날씨 주의: 우천/눈/뇌우 — PEAK는 반드시 실내(전시·체험·공연·카페 등), 야외 장소 절대 선택 금지'
        : '';

    // ── 히스토리 중복 방지 ────────────────────────────────────────────────
    final historyLine = recentPlaces.isNotEmpty
        ? '\n[최근 방문 장소 — 가능하면 다른 곳 선택]\n${recentPlaces.take(20).map((p) => '  - $p').join('\n')}'
        : '';

    // ── 사용자 취향 컨텍스트 (Thompson Sampling → 상위 카테고리) ─────────────
    final prefLine = userTopCategories.isNotEmpty
        ? '\n[사용자 선호 카테고리 — 이 스타일 장소를 우선적으로 선택]\n  ${userTopCategories.join(', ')}'
        : '';

    final prompt = '''
[ ODD 데이트 아크 — 3코스 독립 생성 ]
지역: $region | $hour시 $dayStr요일 $season | 시간대: $timeSlot
분위기: $mood | 이동: $transportGuide | 예산: $budgetGuide$specialGuide$weatherLine$prefLine

[ 추천 철학 — Chain of Thought ]
각 코스를 선정할 때 다음 순서로 사고하라:
  Step 1: 아키타입 컨셉을 먼저 파악 → 이 코스가 전달해야 할 감성/경험의 핵심은 무엇인가?
  Step 2: OPEN 장소 선택 → 이 아키타입에 어울리는 카페·브런치를 고르되, 도심 접근성·인테리어·대기시간 고려
  Step 3: PEAK 장소 선택 → OPEN과 도보 or 이동 동선이 이어지는가? 아키타입 컨셉 부합도는?
  Step 4: CLOSE 장소 선택 → 저녁 식사 분위기가 하루의 흐름을 완성하는가? 좌표 기준 가장 가까운가?
  Step 5: 코스 제목과 description 작성 → 3 장소의 이야기 흐름을 설레는 2문장으로

[ 핵심 규칙 — 반드시 준수 ]
1. 각 코스는 반드시 OPEN(카페/브런치) → PEAK(경험/문화) → CLOSE(식사) 순서, 각 1곳
2. 목록에 없는 장소 절대 만들지 말 것 (허구 장소명 금지)
3. ⚠️ 슬롯 카테고리 엄수 (위반 시 코스 전체 무효):
   - OPEN: 카페·브런치·베이커리·디저트만. 식당/레스토랑/체험시설 절대 금지
   - PEAK: 전시·갤러리·체험·공연·방탈출·볼링·액티비티만. 카페·식당 완전 금지
   - CLOSE: 맛집·식당·레스토랑·한식·양식·일식·파인다이닝만. 카페 완전 금지
4. ⚠️ 같은 카테고리 2개 이상 절대 금지: 카페+카페, 식당+식당 조합 불허
5. 코스1·2·3은 각각 지정된 목록에서만 선택 (다른 코스 목록 혼용 금지)
6. 좌표 기준 동선이 현실적인 조합 (가까운 순서로)
7. 각 장소: reason(25자 감성 설명)과 tip(20자 실전 꿀팁) 필수
8. 3개 코스는 서로 겹치는 장소 없이 완전히 다른 조합$weatherRule$historyLine

${courseBlock(0, startA, mainA, finA)}

${courseBlock(1, startB, mainB, finB)}

${courseBlock(2, startC, mainC, finC)}

[ 출력: JSON 배열만 — 마크다운·설명 없음 ]
[
  {
    "concept": "${archetypes[0]['concept']}",
    "title": "감성적 코스 제목 (15자 이내)",
    "mood": "${archetypes[0]['emoji']} ${archetypes[0]['concept']}",
    "description": "OPEN→PEAK→CLOSE 흐름을 담은 설레는 소개 2문장",
    "places": [
      {"name": "OPEN 장소명 (목록에서)", "reason": "창가 자리에서 커피 한잔, 설레는 시작", "tip": "시그니처 음료 주문 필수"},
      {"name": "PEAK 장소명 (목록에서)", "reason": "...", "tip": "..."},
      {"name": "CLOSE 장소명 (목록에서)", "reason": "...", "tip": "..."}
    ]
  },
  {
    "concept": "${archetypes[1]['concept']}",
    "title": "감성적 코스 제목 (15자 이내)",
    "mood": "${archetypes[1]['emoji']} ${archetypes[1]['concept']}",
    "description": "OPEN→PEAK→CLOSE 흐름을 담은 설레는 소개 2문장",
    "places": [
      {"name": "OPEN 장소명", "reason": "...", "tip": "..."},
      {"name": "PEAK 장소명", "reason": "...", "tip": "..."},
      {"name": "CLOSE 장소명", "reason": "...", "tip": "..."}
    ]
  },
  {
    "concept": "${archetypes[2]['concept']}",
    "title": "감성적 코스 제목 (15자 이내)",
    "mood": "${archetypes[2]['emoji']} ${archetypes[2]['concept']}",
    "description": "OPEN→PEAK→CLOSE 흐름을 담은 설레는 소개 2문장",
    "places": [
      {"name": "OPEN 장소명", "reason": "...", "tip": "..."},
      {"name": "PEAK 장소명", "reason": "...", "tip": "..."},
      {"name": "CLOSE 장소명", "reason": "...", "tip": "..."}
    ]
  }
]
''';

    try {
      final response = await _instance.generateContent([Content.text(prompt)]);
      final text = response.text ?? '';
      final jsonStr = _extractJson(text);
      if (jsonStr == null) return _fallbackCourses(allPool, slots: slots, timeSlot: timeSlot);

      final parsed = json.decode(jsonStr) as List;

      // 각 코스별 전용 서브풀을 슬롯으로 묶어서 _buildCourses 호출
      final subSlots = [
        {'start': startA, 'main': mainA, 'finish': finA},
        {'start': startB, 'main': mainB, 'finish': finB},
        {'start': startC, 'main': mainC, 'finish': finC},
      ];
      return _buildCourses(parsed, allPool,
          subSlotsList: subSlots, archetypesList: archetypes,
          timeSlot: timeSlot);
    } catch (_) {
      return _fallbackCourses(allPool, slots: slots, timeSlot: timeSlot);
    }
  }

  static String? _extractJson(String text) {
    final start = text.indexOf('[');
    final end = text.lastIndexOf(']');
    if (start == -1 || end == -1 || end <= start) return null;
    return text.substring(start, end + 1);
  }

  static List<DateCourse> _buildCourses(
      List<dynamic> parsed, List<Place> allPlaces,
      {List<Map<String, List<Place>>>? subSlotsList,
       List<Map<String, String>>? archetypesList,
       String timeSlot = '낮'}) {
    final courses = <DateCourse>[];

    for (int ci = 0; ci < math.min(parsed.length, 3); ci++) {
      final item = parsed[ci];
      final map = item as Map<String, dynamic>;

      // 아키타입 컨셉명 강제 덮어쓰기 (Gemini가 임의로 바꿀 수 없음)
      if (archetypesList != null && ci < archetypesList.length) {
        map['concept'] = archetypesList[ci]['concept'] ?? map['concept'];
        // mood도 아키타입 이모지+컨셉으로 강제 (Gemini 출력 무시)
        final emoji = archetypesList[ci]['emoji'] ?? '';
        final concept = archetypesList[ci]['concept'] ?? '';
        if (emoji.isNotEmpty && concept.isNotEmpty) {
          map['mood'] = '$emoji $concept';
        }
      }

      // 이 코스 전용 서브풀
      final sub = subSlotsList != null && ci < subSlotsList.length
          ? subSlotsList[ci]
          : <String, List<Place>>{};
      final startPool  = sub['start']  ?? <Place>[];
      final mainPool   = sub['main']   ?? <Place>[];
      final finishPool = sub['finish'] ?? <Place>[];

      // places가 객체 배열({name, reason, tip}) 또는 문자열 배열 모두 처리
      final rawPlaces = map['places'] as List? ?? [];
      final placeEntries = rawPlaces.map((e) {
        if (e is String) return {'name': e, 'reason': '', 'tip': ''};
        final m = e as Map<String, dynamic>;
        return {
          'name': m['name'] as String? ?? '',
          'reason': m['reason'] as String? ?? '',
          'tip': m['tip'] as String? ?? '',
        };
      }).toList();

      final matched = <Place>[];
      for (int i = 0; i < placeEntries.length; i++) {
        final entry = placeEntries[i];
        final name = entry['name']!;

        // 슬롯 위치 기반 우선 풀: 0→start, 1→main, 2→finish
        final preferredPool = switch (i) {
          0 => startPool,
          1 => mainPool,
          _ => finishPool,
        };

        // 1차: 해당 코스의 슬롯 서브풀에서 매칭
        Place? found = preferredPool.isNotEmpty
            ? _fuzzyMatch(name, preferredPool, matched)
            : null;
        // 2차: 이 코스의 전체 서브풀 fallback
        final coursePool = _dedupeById([...startPool, ...mainPool, ...finishPool]);
        found ??= _fuzzyMatch(name, coursePool, matched);
        // 3차: 전체 풀 fallback (드문 케이스)
        found ??= _fuzzyMatch(name, allPlaces, matched);

        if (found != null && !matched.any((p) => p.id == found!.id)) {
          matched.add(found.copyWith(
            aiReason: entry['reason']!.isNotEmpty ? entry['reason']! : null,
            tip: entry['tip']!.isNotEmpty ? entry['tip']! : null,
          ));
        }
      }

      // 부족하면 슬롯별로 정확한 풀에서 카테고리 검증 후 채우기
      final allSlotPool = _dedupeById([...startPool, ...mainPool, ...finishPool]);
      while (matched.length < 3) {
        final slotIdx = matched.length; // 0=OPEN, 1=PEAK, 2=CLOSE
        final slotPool = slotIdx == 0
            ? startPool
            : slotIdx == 1
                ? mainPool
                : finishPool;
        final next = _pickForSlot(slotIdx, timeSlot, slotPool, allSlotPool, matched)
            ?? allPlaces.firstWhere(
                (p) => !matched.any((m) => m.id == p.id),
                orElse: () => allPlaces.isNotEmpty ? allPlaces.first : matched.first);
        if (!matched.any((m) => m.id == next.id)) matched.add(next);
        else break; // 무한 루프 방지
      }

      // 최근접 이웃 동선 최적화
      final optimized = _optimizeRoute(matched);
      final total = optimized.fold<int>(0, (s, p) => s + p.duration);
      courses.add(DateCourse(
        title:   map['title']   as String? ?? '추천 코스 ${courses.length + 1}',
        concept: map['concept'] as String? ?? '',
        mood:    map['mood']    as String? ?? '💕 데이트',
        description:
            map['description'] as String? ?? '오늘 하루, 특별한 시간을 만들어보세요.',
        places: optimized,
        totalDuration: total,
      ));
    }
    return courses.isEmpty ? _fallbackCourses(allPlaces) : courses;
  }

  /// 퍼지 장소명 매칭: 완전 포함 → 토큰 부분 매칭 순으로 시도
  static Place? _fuzzyMatch(
      String name, List<Place> all, List<Place> exclude) {
    final excludeIds = exclude.map((e) => e.id).toSet();

    // 1단계: 완전 포함 매칭
    for (final p in all) {
      if (excludeIds.contains(p.id)) continue;
      if (p.name.contains(name) || name.contains(p.name)) return p;
    }

    // 2단계: 토큰 기반 매칭 (공백/특수문자로 분리 후 2글자 이상 토큰 비교)
    final tokens = name
        .replaceAll(RegExp(r'[^\w가-힣]'), ' ')
        .split(' ')
        .where((t) => t.length >= 2)
        .toList();

    for (final token in tokens) {
      for (final p in all) {
        if (excludeIds.contains(p.id)) continue;
        if (p.name.contains(token)) return p;
      }
    }

    return null;
  }

  /// 최근접 이웃 동선 최적화 (첫 장소 고정, 나머지 거리 순 정렬)
  static List<Place> _optimizeRoute(List<Place> places) {
    if (places.length <= 2) return places;
    final result = [places.first];
    final remaining = places.skip(1).toList();

    while (remaining.isNotEmpty) {
      final last = result.last;
      remaining.sort((a, b) {
        final da = _distKm(last.lat, last.lng, a.lat, a.lng);
        final db = _distKm(last.lat, last.lng, b.lat, b.lng);
        return da.compareTo(db);
      });
      result.add(remaining.removeAt(0));
    }
    return result;
  }

  /// Haversine 거리 (km)
  static double _distKm(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  /// 계절 힌트
  static String _seasonHint(int month) {
    if (month >= 3 && month <= 5) return '봄';
    if (month >= 6 && month <= 8) return '여름';
    if (month >= 9 && month <= 11) return '가을';
    return '겨울';
  }

  /// 중복 제거
  static List<Place> _dedupeById(List<Place> places) {
    final seen = <String>{};
    return places.where((p) => seen.add(p.id)).toList();
  }

  // ─────────────────────────────────────────────
  // 장소 상세: AI 한줄 설명 + 메뉴 추정
  // ─────────────────────────────────────────────

  /// 장소 AI 한줄 설명 생성 (데이트 감성)
  static Future<String> generatePlaceDescription({
    required String placeName,
    required String subcategory,
    required String address,
  }) async {
    final prompt = '''
장소명: $placeName
카테고리: $subcategory
위치: $address

커플 데이트앱 ODD에서 이 장소를 소개하는 한줄 감성 설명을 작성해주세요.
- 2030 커플의 데이트 감성에 맞게
- 이모지 1~2개 포함
- 30자 이내
- 설레는 분위기
- 다른 텍스트 없이 설명만 출력
''';
    try {
      final response =
          await _instance.generateContent([Content.text(prompt)]);
      return response.text?.trim() ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Gemini 실패 시 로컬 폴백 코스 3개 — 슬롯별 카테고리 강제
  static List<DateCourse> _fallbackCourses(List<Place> places,
      {Map<String, List<Place>>? slots, String timeSlot = '낮'}) {
    // 슬롯 풀이 있으면 그걸 우선 사용
    final openPool   = slots?['start']  ?? [];
    final peakPool   = slots?['main']   ?? [];
    final closePool  = slots?['finish'] ?? [];
    final fullPool   = _dedupeById([...openPool, ...peakPool, ...closePool, ...places]);

    if (fullPool.length < 3) return [];

    return List.generate(3, (courseIdx) {
      final used = <String>{};
      final picked = <Place>[];

      for (int slotIdx = 0; slotIdx < 3; slotIdx++) {
        final slotPool = slotIdx == 0
            ? openPool
            : slotIdx == 1
                ? peakPool
                : closePool;
        Place? found;
        // 카테고리 검증 + 미사용 우선
        for (final p in [...slotPool, ...fullPool]) {
          if (used.contains(p.id)) continue;
          if (_isValidForSlot(p, slotIdx, timeSlot)) { found = p; break; }
        }
        // 최후 수단: 카테고리 무관
        found ??= fullPool.firstWhere((p) => !used.contains(p.id),
            orElse: () => fullPool.first);
        used.add(found.id);
        picked.add(found);
      }

      final optimized = _optimizeRoute(picked);
      final total = optimized.fold<int>(0, (s, p) => s + p.duration);
      return DateCourse(
        title:   ['로맨틱 감성 코스', '활기찬 액티비티 코스', '오늘의 베스트'][courseIdx],
        concept: ['감성 로맨스', '액티비티 챌린지', '로컬 힐링'][courseIdx],
        mood:    ['🌸 감성 로맨스', '🎯 액티비티 챌린지', '🌿 로컬 힐링'][courseIdx],
        description: '특별한 하루를 만들어드릴게요. 설레는 마음으로 떠나볼까요?',
        places: optimized,
        totalDuration: total,
      );
    });
  }
}
