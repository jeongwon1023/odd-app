import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/env.dart';
import '../models/place_model.dart';

// ─────────────────────────────────────────────
// KakaoPlaceService — Kakao Local 키워드 장소 검색
// Naver와 별개 DB → 풀 확장용 2차 소스
// 특징: 한 번에 최대 15개, 별점·리뷰 수 포함
// Docs: https://developers.kakao.com/docs/latest/ko/local/dev-guide#search-by-keyword
// ─────────────────────────────────────────────

/// 카테고리별 대표 이미지 (Unsplash — NaverPlaceService와 동일)
const _kakaoImages = {
  '카페': 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=800',
  '브런치': 'https://images.unsplash.com/photo-1550547660-d9450f859349?w=800',
  '전시': 'https://images.unsplash.com/photo-1571115764595-644a1f56a55c?w=800',
  '공연': 'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=800',
  '체험': 'https://images.unsplash.com/photo-1565793419680-e68d36703c72?w=800',
  '액티비티': 'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=800',
  '한식': 'https://images.unsplash.com/photo-1580822184713-fc5400e7fe10?w=800',
  '양식': 'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=800',
  '일식': 'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?w=800',
  '파인다이닝': 'https://images.unsplash.com/photo-1559339352-11d035aa65de?w=800',
  '야경': 'https://images.unsplash.com/photo-1477959858617-67f85cf4f1df?w=800',
  '기본': 'https://images.unsplash.com/photo-1477959858617-67f85cf4f1df?w=800',
};

class KakaoPlaceService {
  static const _baseUrl     = 'https://dapi.kakao.com/v2/local/search/keyword.json';
  static const _categoryUrl = 'https://dapi.kakao.com/v2/local/search/category.json';

  // ── 카테고리 코드 ────────────────────────────────────
  // Kakao Local API 카테고리 그룹 코드
  static const catFood    = 'FD6'; // 음식점 (한식·양식·일식·중식 등 전체)
  static const catCafe    = 'CE7'; // 카페·베이커리
  static const catCulture = 'CT1'; // 문화시설 (극장·박물관·미술관·전시관)
  static const catAttr    = 'AT4'; // 관광명소 (명소·레저·공원·테마파크)

  static final _headers = {
    'Authorization': 'KakaoAK ${Env.kakaoRestApiKey}',
  };

  // ─────────────────────────────────────────────
  // 기본 검색 (최대 15개/페이지)
  // ─────────────────────────────────────────────
  static Future<List<Place>> search({
    required String region,
    required String keyword,
    required String category,
    String imageKey = '기본',
    int size = 15,   // Kakao 최대 15
    int page = 1,    // 1~3
    List<String> blacklist = const [],
  }) async {
    final query = '$region $keyword'.trim();
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'query': query,
      'size': '$size',
      'page': '$page',
      'sort': 'accuracy',   // accuracy(정확도순) | distance(거리순)
    });

    try {
      final res = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];

      final data = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final documents = data['documents'] as List? ?? [];

      final places = <Place>[];
      for (final doc in documents) {
        final item = doc as Map<String, dynamic>;
        // 블랙리스트 필터 (카테고리 이름 기준)
        if (!_passFilter(item, blacklist)) continue;

        final place = _fromKakaoJson(item,
            category: category, region: region, imageKey: imageKey);
        if (place != null) places.add(place);
      }
      return places;
    } catch (_) {
      return [];
    }
  }

  /// 2페이지 병렬 배치 검색 (최대 30개)
  static Future<List<Place>> searchBatch({
    required String region,
    required String keyword,
    required String category,
    String imageKey = '기본',
    List<String> blacklist = const [],
    int pages = 2,   // 15×2 = 30개
  }) async {
    final futures = List.generate(
      pages.clamp(1, 3),
      (i) => search(
        region: region,
        keyword: keyword,
        category: category,
        imageKey: imageKey,
        blacklist: blacklist,
        page: i + 1,
      ),
    );
    final results = await Future.wait(futures);
    return _dedupeList(results.expand((r) => r).toList());
  }

  // ─────────────────────────────────────────────
  // 카테고리 코드 + 좌표 + 반경 기반 지리 검색
  // Naver Maps처럼 "이 지역의 모든 음식점" 방식 — 3페이지 병렬 = 최대 45개
  // ─────────────────────────────────────────────
  static Future<List<Place>> searchByCategory({
    required double lat,
    required double lng,
    required String categoryCode, // catFood / catCafe / catCulture / catAttr
    required String category,     // ODD 카테고리명 (Place.category 용)
    String imageKey = '기본',
    List<String> blacklist = const [],
    int radius = 2000,            // 반경 미터 (기본 2km)
  }) async {
    // 3페이지 병렬: 15×3 = 최대 45개
    final futures = [1, 2, 3].map((page) => _categoryPage(
      lat: lat, lng: lng, categoryCode: categoryCode,
      category: category, imageKey: imageKey,
      blacklist: blacklist, radius: radius, page: page,
    ));
    final results = await Future.wait(futures);
    return _dedupeList(results.expand((r) => r).toList());
  }

  static Future<List<Place>> _categoryPage({
    required double lat,
    required double lng,
    required String categoryCode,
    required String category,
    required String imageKey,
    required List<String> blacklist,
    required int radius,
    required int page,
  }) async {
    // Kakao 좌표계: x=경도(lng), y=위도(lat)
    final uri = Uri.parse(_categoryUrl).replace(queryParameters: {
      'category_group_code': categoryCode,
      'x': '$lng',
      'y': '$lat',
      'radius': '$radius',
      'size': '15',
      'page': '$page',
      'sort': 'accuracy',
    });
    try {
      final res = await http.get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];

      final data = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final docs = data['documents'] as List? ?? [];

      final places = <Place>[];
      for (final doc in docs) {
        final item = doc as Map<String, dynamic>;
        if (!_passFilter(item, blacklist)) continue;
        final place = _fromKakaoJson(item,
            category: category, region: '', imageKey: imageKey);
        if (place != null) places.add(place);
      }
      return places;
    } catch (_) {
      return [];
    }
  }

  // ─────────────────────────────────────────────
  // 다중 반경 카테고리 검색 — 1km + 3km 병렬
  // 각 반경에서 45개(3페이지×15) → 합산 후 이름 중복제거 → ~60-80 고유 장소
  // ─────────────────────────────────────────────
  static Future<List<Place>> searchByMultiRadius({
    required double lat,
    required double lng,
    required String categoryCode,
    required String category,
    String imageKey = '기본',
    List<String> blacklist = const [],
    bool extend = false, // 결과 부족 시 5km까지 확장
  }) async {
    if (lat == 0.0 && lng == 0.0) return [];
    final results = await Future.wait([
      searchByCategory(lat: lat, lng: lng, categoryCode: categoryCode,
          category: category, imageKey: imageKey,
          blacklist: blacklist, radius: 1000),
      searchByCategory(lat: lat, lng: lng, categoryCode: categoryCode,
          category: category, imageKey: imageKey,
          blacklist: blacklist, radius: 3000),
    ]);
    final combined = _dedupeByName(results.expand((r) => r).toList());
    // 결과가 15개 미만이거나 extend 요청 시 5km 추가 검색
    if (combined.length < 15 || extend) {
      final wider = await searchByCategory(
        lat: lat, lng: lng, categoryCode: categoryCode,
        category: category, imageKey: imageKey,
        blacklist: blacklist, radius: 5000,
      );
      return _dedupeByName([...combined, ...wider]);
    }
    return combined;
  }

  /// 이름 기반 중복 제거 — 크로스 API 동일 장소 처리
  static List<Place> _dedupeByName(List<Place> places) {
    final seen = <String>{};
    final result = <Place>[];
    for (final p in places) {
      final key = _normName(p.name);
      if (seen.add(key)) result.add(p);
    }
    return result;
  }

  /// 이름 정규화 — 공백·특수문자 제거, 지점명 suffix 제거
  static String _normName(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[\s\-_·\(\)\[\]]'), '')
        .replaceAll(RegExp(r'(카페|café|cafe|점|지점|본점|[0-9]+호점)$'), '');
  }

  // ─────────────────────────────────────────────
  // 코스 슬롯별 Kakao 검색 (Naver 보완용)
  // Naver fetchForCourseSlots와 동일한 인터페이스
  // ─────────────────────────────────────────────
  static Future<Map<String, List<Place>>> fetchForCourseSlots({
    required String region,
    required String mood,
    required String specialDay,
    required String timeSlot,
    required String transport,
    required String budget,
  }) async {
    final r = _simplifyRegion(region);
    final isEvening = timeSlot == '저녁' || timeSlot == '하루종일';
    final isLuxury  = budget == '고급';

    // ── OPEN 슬롯 (카페 계열) ─────────────────
    final openQueries = [
      (q: '감성 카페 핫플레이스',    cat: '카페',   img: '카페'),
      (q: '브런치 카페 베이커리',    cat: '카페',   img: '브런치'),
      (q: '루프탑 카페 뷰 맛있는',   cat: '카페',   img: '카페'),
      (q: '디저트 카페 케이크',      cat: '카페',   img: '카페'),
    ];

    // ── PEAK 슬롯 (경험/문화) ─────────────────
    final peakQueries = switch (mood) {
      '감성'    => [
          (q: '전시회 갤러리 현대미술',  cat: '전시·문화', img: '전시'),
          (q: '복합문화공간 팝업 트렌디', cat: '전시·문화', img: '전시'),
          (q: '포토스팟 인스타 사진',    cat: '전시·문화', img: '전시'),
        ],
      '액티비티' => [
          (q: '방탈출 실내 오락',       cat: '액티비티', img: '액티비티'),
          (q: '볼링 보드게임 커플',     cat: '액티비티', img: '액티비티'),
          (q: 'VR 체험 첨단',           cat: '체험',    img: '체험'),
        ],
      '힐링'    => [
          (q: '전시 갤러리 조용한',     cat: '전시·문화', img: '전시'),
          (q: '공예 체험 클래스',       cat: '체험',    img: '체험'),
          (q: '북카페 독립서점',        cat: '카페',    img: '카페'),
        ],
      _         => [
          (q: '전시 갤러리 미술관',     cat: '전시·문화', img: '전시'),
          (q: '체험 클래스 공방',       cat: '체험',    img: '체험'),
          (q: '방탈출 볼링 실내',       cat: '액티비티', img: '액티비티'),
        ],
    };

    // ── CLOSE 슬롯 (식사) ─────────────────────
    final closeQueries = isEvening && isLuxury
        ? [
            (q: '파인다이닝 코스요리',    cat: '맛집', img: '파인다이닝'),
            (q: '오마카세 고급 일식',     cat: '맛집', img: '일식'),
            (q: '스테이크 와인 레스토랑', cat: '맛집', img: '파인다이닝'),
          ]
        : isEvening
        ? [
            (q: '분위기 좋은 저녁 레스토랑', cat: '맛집', img: '양식'),
            (q: '이자카야 일식 저녁',        cat: '맛집', img: '일식'),
            (q: '피자 파스타 이탈리안',      cat: '맛집', img: '양식'),
          ]
        : [
            (q: '점심 레스토랑 분위기',  cat: '맛집', img: '양식'),
            (q: '한식 한정식 점심',     cat: '맛집', img: '한식'),
            (q: '덮밥 돈카츠 일식',     cat: '맛집', img: '일식'),
          ];

    // ── 블랙리스트 ──────────────────────────────
    const cafeBlack = ['음식점', '식당', '레스토랑', '고기', '방탈출'];
    const peakBlack = ['음식점', '식당', '카페', '커피', '맛집'];
    const mealBlack = ['카페', '커피', '전시', '갤러리', '방탈출'];

    // ── 병렬 실행 ────────────────────────────────
    final openFutures  = openQueries.map((q) => searchBatch(
        region: r, keyword: q.q, category: q.cat,
        imageKey: q.img, blacklist: cafeBlack));
    final peakFutures  = peakQueries.map((q) => searchBatch(
        region: r, keyword: q.q, category: q.cat,
        imageKey: q.img, blacklist: peakBlack));
    final closeFutures = closeQueries.map((q) => searchBatch(
        region: r, keyword: q.q, category: q.cat,
        imageKey: q.img, blacklist: mealBlack));

    final allFutures = [...openFutures, ...peakFutures, ...closeFutures];
    final allResults = await Future.wait(allFutures);

    final oc = openQueries.length;
    final pc = peakQueries.length;

    return {
      'start':  _dedupeList(allResults.sublist(0, oc).expand((r) => r).toList()),
      'main':   _dedupeList(allResults.sublist(oc, oc + pc).expand((r) => r).toList()),
      'finish': _dedupeList(allResults.sublist(oc + pc).expand((r) => r).toList()),
    };
  }

  // ─────────────────────────────────────────────
  // 내부 유틸
  // ─────────────────────────────────────────────

  static Place? _fromKakaoJson(Map<String, dynamic> doc, {
    required String category,
    required String region,
    required String imageKey,
  }) {
    try {
      final name    = doc['place_name'] as String? ?? '';
      final address = doc['road_address_name'] as String?
          ?? doc['address_name'] as String? ?? '';
      final latStr  = doc['y'] as String? ?? '0';
      final lngStr  = doc['x'] as String? ?? '0';
      final url     = doc['place_url'] as String? ?? '';
      final phone   = doc['phone'] as String? ?? '';
      final catName = doc['category_name'] as String? ?? '';

      if (name.isEmpty) return null;

      // Kakao는 별점/리뷰 수를 Local 검색에서 제공하지 않음
      // (Place Detail API에서는 가능하나 별도 호출 필요)
      // → rating은 기본값 유지, 향후 enrichment 가능

      final imgUrl = _kakaoImages[imageKey] ?? _kakaoImages['기본']!;

      return Place(
        id:          'kakao_${doc['id'] ?? name}',
        name:        name,
        category:    category,
        subcategory: _resolveSubcat(catName),
        tags:        _extractTags(catName),
        address:     address,
        lat:         double.tryParse(latStr) ?? 0.0,
        lng:         double.tryParse(lngStr) ?? 0.0,
        rating:      0.0,   // Kakao Local 검색은 별점 미제공
        priceRange:  '별도 확인',
        duration:    60,
        imageUrl:    imgUrl,
        description: catName,
        openHours:   '',
        phone:       phone,
        region:      region,
        aiReason:    '',
        tip:         url.isNotEmpty ? '카카오맵에서 자세한 정보 확인' : '',
      );
    } catch (_) {
      return null;
    }
  }

  static bool _passFilter(Map<String, dynamic> doc, List<String> blacklist) {
    if (blacklist.isEmpty) return true;
    final catName = (doc['category_name'] as String? ?? '').toLowerCase();
    for (final bad in blacklist) {
      if (catName.contains(bad)) return false;
    }
    return true;
  }

  static String _resolveSubcat(String kakaoCategory) {
    // Kakao 카테고리는 "음식점 > 카페" 형태
    final parts = kakaoCategory.split(' > ');
    return parts.length > 1 ? parts.last : kakaoCategory;
  }

  static List<String> _extractTags(String kakaoCategory) {
    return kakaoCategory
        .split(' > ')
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static List<Place> _dedupeList(List<Place> places) {
    final seen = <String>{};
    return places.where((p) => seen.add(p.id)).toList();
  }

  /// "서울 마포구 홍대입구" → "서울 마포구" (Kakao는 긴 지역명도 잘 처리)
  static String _simplifyRegion(String region) {
    final parts = region.split(' ');
    return parts.length >= 2 ? '${parts[0]} ${parts[1]}' : parts[0];
  }
}
