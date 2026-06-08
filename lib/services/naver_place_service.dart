import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/env.dart';
import '../models/place_model.dart';

/// 카테고리별 대표 이미지 (Unsplash 고정 URL — API 없이 안정적으로 사용)
const _categoryImages = {
  '카페': [
    'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=800',
    'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=800',
    'https://images.unsplash.com/photo-1554118811-1e0d58224f24?w=800',
  ],
  '레스토랑': [
    'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=800',
    'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=800',
    'https://images.unsplash.com/photo-1552566626-52f8b828add9?w=800',
  ],
  '공원': [
    'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=800',
    'https://images.unsplash.com/photo-1501854140801-50d01698950b?w=800',
    'https://images.unsplash.com/photo-1504233529578-6d46baba6d34?w=800',
  ],
  '영화': [
    'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=800',
    'https://images.unsplash.com/photo-1524985069026-dd778a71c7b4?w=800',
  ],
  '전시': [
    'https://images.unsplash.com/photo-1571115764595-644a1f56a55c?w=800',
    'https://images.unsplash.com/photo-1518998053901-5348d3961a04?w=800',
  ],
  '기본': [
    'https://images.unsplash.com/photo-1477959858617-67f85cf4f1df?w=800',
    'https://images.unsplash.com/photo-1519567241046-7f570eee3ce6?w=800',
    'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800',
  ],
};

class NaverPlaceService {
  static const _baseUrl = 'https://openapi.naver.com/v1/search/local.json';

  static final _headers = {
    'X-Naver-Client-Id': Env.naverClientId,
    'X-Naver-Client-Secret': Env.naverClientSecret,
  };

  /// 지역 + 카테고리 쿼리로 장소 검색
  static Future<List<Place>> search({
    required String region,      // "강남구", "해운대구" 등
    required String keyword,     // "카페 데이트", "공원" 등
    required String category,    // "감성" | "액티비티"
    int display = 5,
  }) async {
    final query = Uri.encodeComponent('$region $keyword');
    final uri = Uri.parse('$_baseUrl?query=$query&display=$display&sort=comment');

    try {
      final res = await http.get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return [];

      final data = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final items = data['items'] as List? ?? [];

      return items.asMap().entries.map((entry) {
        final i = entry.key;
        final item = entry.value as Map<String, dynamic>;
        final imgKey = _imageKeyFor(keyword);
        final imgs = _categoryImages[imgKey] ?? _categoryImages['기본']!;
        final imageUrl = imgs[i % imgs.length];

        return Place.fromNaverJson(
          item,
          category: category,
          region: region,
          imageUrl: imageUrl,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// 홈 화면용: 감성/액티비티 각 5개씩 병렬 조회
  static Future<Map<String, List<Place>>> fetchHomeData(String region) async {
    final results = await Future.wait([
      search(region: region, keyword: '카페 감성 데이트', category: '감성', display: 6),
      search(region: region, keyword: '레스토랑 분위기', category: '감성', display: 4),
      search(region: region, keyword: '공원 산책', category: '액티비티', display: 5),
      search(region: region, keyword: '영화관 전시 체험', category: '액티비티', display: 5),
    ]);

    final romantic = [...results[0], ...results[1]];
    final active = [...results[2], ...results[3]];

    // Fallback: 결과가 없으면 지역 없이 재검색 (Rule 2)
    if (romantic.isEmpty) {
      final fallback = await search(
          region: '', keyword: '카페 데이트 감성', category: '감성', display: 8);
      romantic.addAll(fallback);
    }
    if (active.isEmpty) {
      final fallback = await search(
          region: '', keyword: '공원 산책 데이트', category: '액티비티', display: 8);
      active.addAll(fallback);
    }

    return {'감성': romantic, '액티비티': active};
  }

  /// 채팅 선호도 기반 검색
  static Future<List<Place>> fetchForPreferences({
    required String region,
    required String mood,
    required String timeSlot,
    required bool excludeNoodle,
    required String budget,
  }) async {
    final queries = <String>[];

    if (mood == '감성' || mood == '혼합') {
      queries.add('카페 감성 데이트');
      queries.add(timeSlot == '저녁' ? '레스토랑 야경 분위기' : '브런치 감성 맛집');
    }
    if (mood == '액티비티' || mood == '혼합') {
      queries.add('공원 산책 커플');
      queries.add('체험 전시 액티비티');
    }
    if (budget == '고급') queries.add('파인다이닝 오마카세');
    if (timeSlot == '저녁') queries.add('바 야경 루프탑');

    final results = await Future.wait(
      queries.map((q) => search(
        region: region,
        keyword: q,
        category: mood == '액티비티' ? '액티비티' : '감성',
        display: 4,
      )),
    );

    final all = results.expand((r) => r).toList();

    // 면류 제외 (설명/카테고리에 면 관련 키워드가 있으면 필터)
    if (excludeNoodle) {
      all.removeWhere((p) =>
          p.subcategory.contains('라면') ||
          p.subcategory.contains('국수') ||
          p.name.contains('라멘') ||
          p.name.contains('우동'));
    }

    return all;
  }

  static String _imageKeyFor(String keyword) {
    if (keyword.contains('카페')) return '카페';
    if (keyword.contains('레스토랑') || keyword.contains('맛집') || keyword.contains('브런치')) return '레스토랑';
    if (keyword.contains('공원') || keyword.contains('산책')) return '공원';
    if (keyword.contains('영화')) return '영화';
    if (keyword.contains('전시') || keyword.contains('미술')) return '전시';
    return '기본';
  }
}
