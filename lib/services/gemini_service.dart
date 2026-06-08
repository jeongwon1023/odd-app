import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../config/env.dart';
import '../models/place_model.dart';

class GeminiService {
  static GenerativeModel? _model;
  static ChatSession? _chat;

  static GenerativeModel get _instance {
    _model ??= GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: Env.geminiApiKey,
      systemInstruction: Content.system('''
당신은 ODD 데이트 플래너 AI입니다.
- 20대 커플을 위한 데이트 코스를 추천하는 전문가입니다.
- 항상 따뜻하고 설레는 언어로 답변하세요.
- 기술적 정보(API, 검색 중 등)는 절대 언급하지 마세요.
- 응답은 항상 한국어로 하세요.
- 장소 설명은 데이트 감성에 맞게 감성적으로 표현하세요.
'''),
    );
    return _model!;
  }

  /// 새 채팅 세션 시작
  static void startNewChat() {
    _chat = _instance.startChat();
  }

  /// 일반 채팅 메시지 전송
  static Future<String> sendMessage(String message) async {
    _chat ??= _instance.startChat();
    try {
      final response = await _chat!.sendMessage(Content.text(message));
      return response.text ?? '잠시 후 다시 시도해주세요.';
    } catch (_) {
      return '연결이 불안정해요. 잠시 후 다시 시도해주세요.';
    }
  }

  /// 장소 목록 기반으로 데이트 코스 3개 생성
  static Future<List<DateCourse>> generateCourses({
    required String region,
    required String mood,
    required String timeSlot,
    required String budget,
    required List<Place> places,
  }) async {
    if (places.isEmpty) return _fallbackCourses(places);

    final placeList = places
        .take(15)
        .map((p) => '- ${p.name} (${p.subcategory}, ${p.address})')
        .join('\n');

    final prompt = '''
현재 위치: $region
원하는 분위기: $mood
시간대: $timeSlot
예산: $budget

아래 장소들 중에서 데이트 코스 3가지를 만들어주세요.
각 코스는 3곳의 장소로 구성되며, 동선이 자연스러워야 합니다.

장소 목록:
$placeList

다음 JSON 형식으로만 답변하세요 (다른 텍스트 없이):
[
  {
    "title": "코스 제목",
    "mood": "이모지 + 한마디",
    "description": "이 코스의 감성적인 소개 (2-3문장)",
    "places": ["장소명1", "장소명2", "장소명3"]
  }
]
''';

    try {
      final response =
          await _instance.generateContent([Content.text(prompt)]);
      final text = response.text ?? '';
      final jsonStr = _extractJson(text);
      if (jsonStr == null) return _fallbackCourses(places);

      final parsed = json.decode(jsonStr) as List;
      return _buildCourses(parsed, places);
    } catch (_) {
      return _fallbackCourses(places);
    }
  }

  static String? _extractJson(String text) {
    final start = text.indexOf('[');
    final end = text.lastIndexOf(']');
    if (start == -1 || end == -1 || end <= start) return null;
    return text.substring(start, end + 1);
  }

  static List<DateCourse> _buildCourses(
      List<dynamic> parsed, List<Place> allPlaces) {
    final courses = <DateCourse>[];
    for (final item in parsed.take(3)) {
      final map = item as Map<String, dynamic>;
      final placeNames = (map['places'] as List?)?.cast<String>() ?? [];

      final matched = <Place>[];
      for (final name in placeNames) {
        final found = allPlaces.firstWhere(
          (p) => p.name.contains(name) || name.contains(p.name),
          orElse: () => allPlaces[matched.length % allPlaces.length],
        );
        if (!matched.any((p) => p.id == found.id)) matched.add(found);
      }
      while (matched.length < 3 && allPlaces.isNotEmpty) {
        final next = allPlaces.firstWhere(
          (p) => !matched.any((m) => m.id == p.id),
          orElse: () => allPlaces.first,
        );
        matched.add(next);
      }

      final total = matched.fold<int>(0, (s, p) => s + p.duration);
      courses.add(DateCourse(
        title: map['title'] as String? ?? '추천 코스 ${courses.length + 1}',
        mood: map['mood'] as String? ?? '💕 데이트',
        description: map['description'] as String? ??
            '오늘 하루, 특별한 시간을 만들어보세요.',
        places: matched,
        totalDuration: total,
      ));
    }
    return courses.isEmpty ? _fallbackCourses(allPlaces) : courses;
  }

  /// Gemini 실패 시 로컬 폴백 코스 3개
  static List<DateCourse> _fallbackCourses(List<Place> places) {
    if (places.length < 3) return [];
    final pool = [...places];

    return List.generate(3, (i) {
      final slice = pool.skip(i * 3).take(3).toList();
      while (slice.length < 3) {
        slice.add(pool[slice.length % pool.length]);
      }
      final total = slice.fold<int>(0, (s, p) => s + p.duration);
      return DateCourse(
        title: ['로맨틱 감성 코스', '활기찬 액티비티 코스', '오늘의 베스트'][i],
        mood: ['✨ 감성', '🏃 액티비티', '⭐ 베스트'][i],
        description: '특별한 하루를 만들어드릴게요. 설레는 마음으로 떠나볼까요?',
        places: slice,
        totalDuration: total,
      );
    });
  }
}
