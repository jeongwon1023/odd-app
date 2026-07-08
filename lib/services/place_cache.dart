// ─────────────────────────────────────────────
// PlaceCache — 세션 레벨 인메모리 캐시
// 같은 지역+카테고리 조합을 30분 이내 재검색하면
// API 재호출 없이 즉시 반환 → 응답속도 + API 비용 절감
// ─────────────────────────────────────────────

import '../models/place_model.dart';

class PlaceCache {
  PlaceCache._();

  static final Map<String, _CacheEntry> _store = {};
  static const _ttl = Duration(minutes: 30);

  /// 캐시에서 조회. TTL 만료 시 null 반환
  static List<Place>? get(String key) {
    final entry = _store[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.timestamp) > _ttl) {
      _store.remove(key);
      return null;
    }
    return List.unmodifiable(entry.places);
  }

  /// 캐시에 저장
  static void set(String key, List<Place> places) {
    if (places.isEmpty) return; // 빈 결과는 캐시 안 함
    _store[key] = _CacheEntry(List.from(places), DateTime.now());
  }

  /// 특정 키 무효화 (지역 변경 등)
  static void invalidate(String key) => _store.remove(key);

  /// 전체 캐시 초기화
  static void clear() => _store.clear();

  /// 캐시 키 생성 — region + category 조합
  static String key(String region, String category) =>
      '${region.trim()}|$category';

  /// 현재 캐시 항목 수 (디버그용)
  static int get size => _store.length;
}

class _CacheEntry {
  final List<Place> places;
  final DateTime timestamp;
  _CacheEntry(this.places, this.timestamp);
}
