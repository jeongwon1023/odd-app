import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/place_model.dart';

/// Supabase 없이 기기 로컬에 장소 데이터를 24시간 캐시합니다.
class CacheService {
  static const _ttlHours = 24;

  static String _key(String region, String category) =>
      'places_${region}_$category';
  static String _tsKey(String region, String category) =>
      'places_ts_${region}_$category';

  /// 캐시에서 장소 목록 읽기 (24h 유효)
  static Future<List<Place>> getPlaces(String region, String category) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tsStr = prefs.getString(_tsKey(region, category));
      if (tsStr == null) return [];

      final saved = DateTime.parse(tsStr);
      if (DateTime.now().difference(saved).inHours >= _ttlHours) return [];

      final jsonStr = prefs.getString(_key(region, category));
      if (jsonStr == null) return [];

      final list = json.decode(jsonStr) as List;
      return list.map((e) => Place.fromSupabase(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// 장소 목록 저장
  static Future<void> savePlaces(
      String region, String category, List<Place> places) async {
    if (places.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = places.map((p) => p.toSupabase()).toList();
      await prefs.setString(_key(region, category), json.encode(data));
      await prefs.setString(
          _tsKey(region, category), DateTime.now().toIso8601String());
    } catch (_) {}
  }

  // ─────────────────────────────────────────────
  // 최근 방문 지역 (최대 3개)
  // ─────────────────────────────────────────────

  // ─────────────────────────────────────────────
  // 닉네임
  // ─────────────────────────────────────────────
  static const _nicknameKey = 'user_nickname';

  static Future<String> getNickname() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_nicknameKey) ?? 'ODD 사용자';
  }

  static Future<void> setNickname(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nicknameKey, name);
  }

  static const _recentRegionsKey = 'recent_regions';
  static const _maxRecentRegions = 3;

  /// 최근 지역 목록 반환 (label + query 쌍)
  static Future<List<Map<String, String>>> getRecentRegions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_recentRegionsKey) ?? [];
      return raw.map((s) {
        final parts = s.split('||');
        return {'label': parts[0], 'query': parts.length > 1 ? parts[1] : parts[0]};
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// 지역 선택 시 호출 — 중복 제거 후 앞에 삽입
  static Future<void> addRecentRegion(String label, String query) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_recentRegionsKey) ?? [];
      final entry = '$label||$query';
      raw.removeWhere((s) => s.startsWith('$label||'));
      raw.insert(0, entry);
      if (raw.length > _maxRecentRegions) raw.removeLast();
      await prefs.setStringList(_recentRegionsKey, raw);
    } catch (_) {}
  }

  // ─────────────────────────────────────────────
  // 저장된 코스 (DateCourse JSON)
  // ─────────────────────────────────────────────

  static const _savedCoursesKey = 'saved_courses';

  /// 저장된 코스 JSON 목록 반환
  static Future<List<Map<String, dynamic>>> getSavedCourses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_savedCoursesKey) ?? [];
      return raw.map((s) => json.decode(s) as Map<String, dynamic>).toList();
    } catch (_) {
      return [];
    }
  }

  /// 코스 저장 (id 중복 방지)
  static Future<void> saveCourse(Map<String, dynamic> courseJson) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_savedCoursesKey) ?? [];
      // 이미 동일 제목 있으면 덮어쓰기
      final title = courseJson['title'] as String? ?? '';
      raw.removeWhere((s) {
        try {
          return (json.decode(s) as Map)['title'] == title;
        } catch (_) {
          return false;
        }
      });
      raw.insert(0, json.encode(courseJson));
      await prefs.setStringList(_savedCoursesKey, raw);
    } catch (_) {}
  }

  /// 코스 삭제
  static Future<void> removeCourse(String title) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_savedCoursesKey) ?? [];
      raw.removeWhere((s) {
        try {
          return (json.decode(s) as Map)['title'] == title;
        } catch (_) {
          return false;
        }
      });
      await prefs.setStringList(_savedCoursesKey, raw);
    } catch (_) {}
  }

  /// 모든 캐시 초기화 (설정 화면 등에서 사용 가능)
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where(
        (k) => k.startsWith('places_'));
    for (final k in keys) {
      await prefs.remove(k);
    }
  }

  // ─────────────────────────────────────────────
  // 코스 히스토리 (생성된 모든 코스 자동 기록)
  // ─────────────────────────────────────────────

  static const _historyKey = 'course_history';
  static const _maxHistory = 50;

  /// 히스토리 전체 반환 (최신순)
  static Future<List<Map<String, dynamic>>> getHistoryCourses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_historyKey) ?? [];
      return raw
          .map((s) => json.decode(s) as Map<String, dynamic>)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// 코스 히스토리에 추가 (생성 시 자동 호출)
  static Future<void> addToHistory(Map<String, dynamic> courseJson) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_historyKey) ?? [];
      final entry = Map<String, dynamic>.from(courseJson);
      entry['savedAt'] ??= DateTime.now().toIso8601String();
      raw.insert(0, json.encode(entry));
      if (raw.length > _maxHistory) raw.removeLast();
      await prefs.setStringList(_historyKey, raw);
    } catch (_) {}
  }

  /// 히스토리 전체 삭제
  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }

  // ─────────────────────────────────────────────
  // 히스토리에서 최근 장소명 목록 추출
  // Gemini 프롬프트에 "가능하면 피하기" soft constraint로 사용
  // ─────────────────────────────────────────────

  /// 최근 생성 코스에서 장소명 목록 반환 (중복 제거, 최신순)
  static Future<List<String>> getRecentPlaceNames({int limit = 20}) async {
    try {
      final history = await getHistoryCourses();
      final seen = <String>{};
      final names = <String>[];

      for (final course in history) {
        final places = course['places'] as List? ?? [];
        for (final p in places) {
          final name = (p is Map ? p['name'] : p?.toString()) ?? '';
          if (name.isNotEmpty && seen.add(name)) {
            names.add(name);
            if (names.length >= limit) return names;
          }
        }
      }
      return names;
    } catch (_) {
      return [];
    }
  }
}
