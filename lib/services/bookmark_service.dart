import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/place_model.dart';

// ─────────────────────────────────────────────
// 북마크(찜) 서비스 — SharedPreferences 로컬 저장
// ─────────────────────────────────────────────

class BookmarkService {
  static const _key = 'bookmarked_places';

  /// 저장된 찜 목록 로드
  static Future<List<Place>> getAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key) ?? [];
      return raw
          .map((s) => Place.fromSupabase(json.decode(s) as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// ID 기반 찜 여부 확인
  static Future<bool> isBookmarked(String placeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key) ?? [];
      return raw.any((s) {
        final m = json.decode(s) as Map<String, dynamic>;
        return m['id'] == placeId;
      });
    } catch (_) {
      return false;
    }
  }

  /// 찜 추가
  static Future<void> add(Place place) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key) ?? [];
      // 중복 방지
      if (raw.any((s) {
        final m = json.decode(s) as Map<String, dynamic>;
        return m['id'] == place.id;
      })) return;
      raw.insert(0, json.encode(place.toSupabase()));
      await prefs.setStringList(_key, raw);
    } catch (_) {}
  }

  /// 찜 제거
  static Future<void> remove(String placeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key) ?? [];
      raw.removeWhere((s) {
        final m = json.decode(s) as Map<String, dynamic>;
        return m['id'] == placeId;
      });
      await prefs.setStringList(_key, raw);
    } catch (_) {}
  }

  /// 토글 (찜 ↔ 해제) — 결과 bool 반환 (true=찜됨)
  static Future<bool> toggle(Place place) async {
    final already = await isBookmarked(place.id);
    if (already) {
      await remove(place.id);
      return false;
    } else {
      await add(place);
      return true;
    }
  }
}
