import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/env.dart';
import '../models/place_model.dart';

// 카테고리별 fallback 이미지 (Nearby Search 결과 이미지 없을 때 사용)
const _googleFallbackImages = {
  '카페·브런치': 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=800',
  '맛집':       'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=800',
  '전시·문화':  'https://images.unsplash.com/photo-1571115764595-644a1f56a55c?w=800',
  '체험·액티비티': 'https://images.unsplash.com/photo-1565793419680-e68d36703c72?w=800',
  '야경·뷰':    'https://images.unsplash.com/photo-1477959858617-67f85cf4f1df?w=800',
};

/// Google Places API (New) — 장소 사진·영업시간·리뷰 가져오기
class GooglePlacesService {
  static const _searchUrl  = 'https://places.googleapis.com/v1/places:searchText';
  static const _nearbyUrl  = 'https://places.googleapis.com/v1/places:searchNearby';
  static const _baseUrl    = 'https://places.googleapis.com/v1';

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': Env.googlePlacesKey,
        'X-Goog-FieldMask': [
          'places.id',
          'places.displayName',
          'places.photos',
          'places.currentOpeningHours',
          'places.regularOpeningHours',
          'places.rating',
          'places.userRatingCount',
          'places.reviews',
          'places.priceLevel',
          'places.nationalPhoneNumber',
          'places.websiteUri',
          'places.formattedAddress',
        ].join(','),
      };

  /// 사진 URL 생성 (Places API Photo Name 기반)
  static String photoUrl(String photoName, {int maxWidth = 800}) =>
      '$_baseUrl/$photoName/media?maxWidthPx=$maxWidth&key=${Env.googlePlacesKey}';

  /// 장소명 + 주소로 Google Places 상세 정보 조회
  static Future<PlaceDetail?> fetchDetail({
    required String placeName,
    required String address,
  }) async {
    try {
      final query =
          address.isNotEmpty ? '$placeName $address' : placeName;

      final res = await http
          .post(
            Uri.parse(_searchUrl),
            headers: _headers,
            body: json.encode({
              'textQuery': query,
              'languageCode': 'ko',
              'maxResultCount': 1,
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (res.statusCode != 200) {
        return null;
      }

      final data = json.decode(utf8.decode(res.bodyBytes));
      final places = data['places'] as List?;
      if (places == null || places.isEmpty) return null;

      final place = places[0] as Map<String, dynamic>;

      // ── 사진 ──
      final rawPhotos = place['photos'] as List? ?? [];
      final photoUrls = rawPhotos
          .take(20)
          .map((p) => photoUrl(p['name'] as String))
          .toList()
          .cast<String>();

      // ── 영업시간 ──
      final hoursMap =
          (place['currentOpeningHours'] ?? place['regularOpeningHours'])
              as Map<String, dynamic>?;
      final isOpenNow = hoursMap?['openNow'] as bool? ?? false;
      final weekdays = ((hoursMap?['weekdayDescriptions'] as List?) ?? [])
          .cast<String>();

      // 오늘 요일 (0=월 … 6=일, DateTime.weekday 1=월 … 7=일)
      final todayIdx = DateTime.now().weekday - 1;
      final todayHours =
          weekdays.length > todayIdx ? weekdays[todayIdx] : '';

      // ── Google 리뷰 ──
      final rawReviews = place['reviews'] as List? ?? [];
      final googleReviews = rawReviews
          .map((r) {
            final m = r as Map<String, dynamic>;
            final text = (m['originalText'] as Map?)?['text'] as String? ??
                (m['text'] as Map?)?['text'] as String? ??
                '';
            if (text.isEmpty) return null;
            return GoogleReview(
              authorName:
                  (m['authorAttribution'] as Map?)?['displayName'] as String? ??
                      '익명',
              rating: (m['rating'] as num? ?? 5).toInt(),
              text: text,
              relativeTime:
                  m['relativePublishTimeDescription'] as String? ?? '',
            );
          })
          .whereType<GoogleReview>()
          .toList();

      // ── 가격대 ──
      final priceLevel = _priceLabel(place['priceLevel'] as String? ?? '');

      return PlaceDetail(
        googlePlaceId: place['id'] as String? ?? '',
        photoUrls: photoUrls,
        isOpenNow: isOpenNow,
        todayHours: todayHours,
        weekdayDescriptions: weekdays,
        googleRating: (place['rating'] as num? ?? 0).toDouble(),
        reviewCount: (place['userRatingCount'] as num? ?? 0).toInt(),
        googleReviews: googleReviews,
        naverReviews: const [],
        menuItems: const [],
        aiDescription: '',
        website: place['websiteUri'] as String? ?? '',
        nationalPhone: place['nationalPhoneNumber'] as String? ?? '',
        priceLevel: priceLevel,
      );
    } catch (_) {
      return null;
    }
  }

  /// 홈 카드용 경량 조회 — 첫 번째 사진 URL만 반환 (field mask 최소화)
  static Future<String?> fetchFirstPhotoUrl(
      String placeName, String address) async {
    final result = await fetchPlaceEnrichment(placeName, address);
    return result['imageUrl'] as String?;
  }

  /// 코스 카드용 — 사진 URL + 평점 + 리뷰 수 한 번에 반환
  /// {'imageUrl': String?, 'rating': double?, 'reviewCount': int?}
  static Future<Map<String, dynamic>> fetchPlaceEnrichment(
      String placeName, String address) async {
    try {
      final query = address.isNotEmpty ? '$placeName $address' : placeName;
      final res = await http
          .post(
            Uri.parse(_searchUrl),
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': Env.googlePlacesKey,
              'X-Goog-FieldMask': 'places.photos,places.rating,places.userRatingCount',
            },
            body: json.encode({
              'textQuery': query,
              'languageCode': 'ko',
              'maxResultCount': 1,
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) return {};
      final data = json.decode(utf8.decode(res.bodyBytes));
      final places = data['places'] as List?;
      if (places == null || places.isEmpty) return {};
      final place = places[0] as Map<String, dynamic>;

      final photos = place['photos'] as List?;
      final imgUrl = (photos != null && photos.isNotEmpty)
          ? photoUrl(photos[0]['name'] as String, maxWidth: 600)
          : null;
      final rating = (place['rating'] as num?)?.toDouble();
      final reviewCount = (place['userRatingCount'] as num?)?.toInt();

      return {
        if (imgUrl != null) 'imageUrl': imgUrl,
        if (rating != null) 'rating': rating,
        if (reviewCount != null) 'reviewCount': reviewCount,
      };
    } catch (_) {
      return {};
    }
  }

  // ─────────────────────────────────────────────
  // 좌표 + 반경 기반 주변 장소 검색 (Nearby Search)
  // 네이버지도의 "이 지역 맛집" 방식과 동일한 지리 우선 탐색
  // includedTypes: Google Places 장소 유형 배열
  // ─────────────────────────────────────────────

  // ODD 카테고리 → Google Places 유형 매핑 (단일 그룹 — 기존 호환)
  static const _nearbyTypes = {
    '카페·브런치':    ['cafe', 'bakery', 'coffee_shop'],
    '맛집':          ['restaurant', 'korean_restaurant', 'japanese_restaurant',
                     'italian_restaurant', 'chinese_restaurant'],
    '전시·문화':     ['museum', 'art_gallery', 'cultural_center',
                     'performing_arts_theater'],
    '체험·액티비티': ['tourist_attraction', 'bowling_alley', 'movie_theater',
                     'amusement_park', 'event_venue'],
    '야경·뷰':       ['tourist_attraction', 'park', 'national_park'],
  };

  // 다중 타입 그룹 — 그룹당 20개 × 그룹 수 = 더 많은 결과
  // 카페: 2그룹 × 20 = 40개 / 맛집: 3그룹 × 20 = 60개 / 체험: 2그룹 × 40개 / 야경: 2그룹 × 40개
  static const _nearbyTypeGroups = {
    '카페·브런치': [
      ['cafe', 'coffee_shop', 'espresso_bar'],
      ['bakery', 'dessert_restaurant', 'tea_house'],
    ],
    '맛집': [
      ['restaurant', 'korean_restaurant', 'japanese_restaurant'],
      ['italian_restaurant', 'chinese_restaurant', 'pizza_restaurant'],
      ['seafood_restaurant', 'ramen_restaurant', 'barbecue_restaurant'],
    ],
    '전시·문화': [
      ['museum', 'art_gallery', 'cultural_center', 'performing_arts_theater'],
      ['movie_theater', 'concert_hall'],
    ],
    '체험·액티비티': [
      ['tourist_attraction', 'bowling_alley', 'movie_theater'],
      ['amusement_park', 'event_venue', 'cultural_center'],
    ],
    '야경·뷰': [
      ['tourist_attraction', 'park', 'national_park'],
      ['observation_deck', 'viewpoint', 'rooftop_bar'],
    ],
  };

  /// 다중 타입 그룹 병렬 검색 — 그룹당 20개 × 그룹 수
  /// 맛집은 3그룹 = 최대 60개, 체험은 2그룹 = 40개
  static Future<List<Place>> searchNearbyMulti({
    required double lat,
    required double lng,
    required String category,
    int radius = 2000,
  }) async {
    if (lat == 0.0 && lng == 0.0) return [];
    final groups = _nearbyTypeGroups[category];
    if (groups == null || groups.isEmpty) {
      return searchNearby(lat: lat, lng: lng, category: category, radius: radius);
    }

    final futures = groups.map((types) => _searchNearbyGroup(
        lat: lat, lng: lng, types: types, category: category, radius: radius));
    final results = await Future.wait(futures);
    return _dedupeByName(results.expand((r) => r).toList());
  }

  /// 단일 타입 배열로 Nearby 호출 — 내부 공용 함수
  static Future<List<Place>> _searchNearbyGroup({
    required double lat,
    required double lng,
    required List<String> types,
    required String category,
    int radius = 2000,
  }) async {
    if (types.isEmpty) return [];
    final fallback = _googleFallbackImages[category]
        ?? 'https://images.unsplash.com/photo-1477959858617-67f85cf4f1df?w=800';
    try {
      final res = await http.post(
        Uri.parse(_nearbyUrl),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': Env.googlePlacesKey,
          'X-Goog-FieldMask': [
            'places.id', 'places.displayName', 'places.rating',
            'places.userRatingCount', 'places.photos',
            'places.formattedAddress', 'places.location',
            'places.currentOpeningHours.openNow',
          ].join(','),
        },
        body: json.encode({
          'includedTypes': types,
          'maxResultCount': 20,
          'locationRestriction': {
            'circle': {
              'center': {'latitude': lat, 'longitude': lng},
              'radius': radius.toDouble(),
            },
          },
          'languageCode': 'ko',
          'rankPreference': 'POPULARITY',
        }),
      ).timeout(const Duration(seconds: 12));

      if (res.statusCode != 200) return [];
      final data  = json.decode(utf8.decode(res.bodyBytes));
      final items = data['places'] as List? ?? [];

      return items.map((p) {
        final place      = p as Map<String, dynamic>;
        final name       = (place['displayName'] as Map?)?['text'] as String? ?? '';
        final address    = place['formattedAddress'] as String? ?? '';
        final rating     = (place['rating'] as num?)?.toDouble() ?? 0.0;
        final reviews    = (place['userRatingCount'] as num?)?.toInt() ?? 0;
        final loc        = place['location'] as Map<String, dynamic>?;
        final photos     = place['photos'] as List?;
        final imgUrl     = (photos != null && photos.isNotEmpty)
            ? photoUrl(photos[0]['name'] as String, maxWidth: 600)
            : fallback;
        final openNow    = (place['currentOpeningHours'] as Map?)?['openNow'] as bool?;
        return Place(
          id:          'google_${place['id'] ?? name.hashCode}',
          name:        name,
          category:    category,
          subcategory: '',
          tags:        const [],
          address:     address,
          lat:         (loc?['latitude']  as num?)?.toDouble() ?? lat,
          lng:         (loc?['longitude'] as num?)?.toDouble() ?? lng,
          rating:      rating,
          priceRange:  '',
          duration:    60,
          imageUrl:    imgUrl,
          description: '',
          openHours:   '',
          phone:       '',
          region:      '',
          reviewCount: reviews,
          isOpenNow:   openNow,
        );
      }).where((p) => p.name.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  /// 이름 정규화 기반 중복 제거
  static List<Place> _dedupeByName(List<Place> places) {
    final seen = <String>{};
    return places.where((p) => seen.add(_normName(p.name))).toList();
  }

  static String _normName(String name) =>
      name.toLowerCase().replaceAll(RegExp(r'[\s\-_·\(\)\[\]]'), '');

  /// 근방 장소 검색 — lat/lng 중심 반경 내 최대 20개 반환 (단일 그룹 — 호환용)
  static Future<List<Place>> searchNearby({
    required double lat,
    required double lng,
    required String category,
    int radius = 2000,
  }) async {
    final types = _nearbyTypes[category];
    if (types == null || (lat == 0.0 && lng == 0.0)) return [];
    return _searchNearbyGroup(
        lat: lat, lng: lng, types: types, category: category, radius: radius);
  }

  static String _priceLabel(String level) {
    switch (level) {
      case 'PRICE_LEVEL_FREE':
        return '무료';
      case 'PRICE_LEVEL_INEXPENSIVE':
        return '₩';
      case 'PRICE_LEVEL_MODERATE':
        return '₩₩';
      case 'PRICE_LEVEL_EXPENSIVE':
        return '₩₩₩';
      case 'PRICE_LEVEL_VERY_EXPENSIVE':
        return '₩₩₩₩';
      default:
        return '';
    }
  }
}
