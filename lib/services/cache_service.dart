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

  /// 모든 캐시 초기화 (설정 화면 등에서 사용 가능)
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where(
        (k) => k.startsWith('places_'));
    for (final k in keys) {
      await prefs.remove(k);
    }
  }
}
