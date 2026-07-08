// ─────────────────────────────────────────────
// place_model.dart — Place + DateCourse + Rich Data
// ─────────────────────────────────────────────

// ─────────────────────────────────────────────
// Place
// ─────────────────────────────────────────────
class Place {
  final String id;
  final String name;
  final String category;    // "카페" | "전시·문화" | "맛집" | "체험" 등
  final String subcategory;
  final List<String> tags;
  final String address;
  final double lat;
  final double lng;
  final double rating;
  final String priceRange;
  final int duration;        // 예상 소요 시간(분)
  final String imageUrl;
  final String description;
  final String openHours;
  final String phone;
  final String region;
  final String aiReason;    // AI 추천 이유 (코스 전용)
  final String tip;          // 방문 팁 (코스 전용)
  final int reviewCount;     // Google Places 리뷰 수
  final bool? isOpenNow;    // 현재 영업 여부 (null = 정보 없음)

  const Place({
    required this.id,
    required this.name,
    required this.category,
    required this.subcategory,
    required this.tags,
    required this.address,
    required this.lat,
    required this.lng,
    required this.rating,
    required this.priceRange,
    required this.duration,
    required this.imageUrl,
    required this.description,
    required this.openHours,
    required this.phone,
    required this.region,
    this.aiReason = '',
    this.tip = '',
    this.reviewCount = 0,
    this.isOpenNow,
  });

  // ── Naver Search API 응답 → Place ───────────
  factory Place.fromNaverJson(
    Map<String, dynamic> json, {
    required String category,
    required String region,
    required String imageUrl,
  }) {
    // Naver Local Search: mapx/mapy는 TM128 좌표 × 1e7 ≈ WGS84
    final mapx = json['mapx'] as String? ?? '0';
    final mapy = json['mapy'] as String? ?? '0';
    final lng = double.tryParse(mapx) != null ? double.parse(mapx) / 1e7 : 0.0;
    final lat = double.tryParse(mapy) != null ? double.parse(mapy) / 1e7 : 0.0;

    final rawName =
        (json['title'] as String? ?? '').replaceAll(RegExp(r'<[^>]*>'), '');
    final rawCategory = json['category'] as String? ?? '';
    final subcategory =
        rawCategory.contains('>') ? rawCategory.split('>').last : rawCategory;

    return Place(
      id: 'naver_${rawName.hashCode}_${lat.hashCode}',
      name: rawName,
      category: category,
      subcategory: subcategory,
      tags: _buildTags(rawCategory, category),
      address: json['roadAddress'] as String? ??
          json['address'] as String? ?? '',
      lat: lat,
      lng: lng,
      rating: 4.0 + (rawName.length % 10) * 0.1,
      priceRange: _inferPrice(rawCategory),
      duration: _inferDuration(category),
      imageUrl: imageUrl,
      description: (json['description'] as String? ?? '')
          .replaceAll(RegExp(r'<[^>]*>'), ''),
      openHours: '',
      phone: json['telephone'] as String? ?? '',
      region: region,
    );
  }

  // ── Supabase / SharedPreferences JSON ↔ Place ─
  factory Place.fromSupabase(Map<String, dynamic> row) {
    return Place(
      id: row['id'] as String? ?? '',
      name: row['name'] as String? ?? '',
      category: row['category'] as String? ?? '',
      subcategory: row['subcategory'] as String? ?? '',
      tags: List<String>.from(row['tags'] ?? []),
      address: row['address'] as String? ?? '',
      lat: (row['lat'] as num? ?? 0).toDouble(),
      lng: (row['lng'] as num? ?? 0).toDouble(),
      rating: (row['rating'] as num? ?? 4.0).toDouble(),
      priceRange: row['price_range'] as String? ?? '보통',
      duration: row['duration'] as int? ?? 60,
      imageUrl: row['image_url'] as String? ?? '',
      description: row['description'] as String? ?? '',
      openHours: row['open_hours'] as String? ?? '',
      phone: row['phone'] as String? ?? '',
      region: row['region'] as String? ?? '',
      aiReason: row['ai_reason'] as String? ?? '',
      tip: row['tip'] as String? ?? '',
      reviewCount: row['review_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toSupabase() => {
        'id': id,
        'name': name,
        'category': category,
        'subcategory': subcategory,
        'tags': tags,
        'address': address,
        'lat': lat,
        'lng': lng,
        'rating': rating,
        'price_range': priceRange,
        'duration': duration,
        'image_url': imageUrl,
        'description': description,
        'open_hours': openHours,
        'phone': phone,
        'region': region,
        'ai_reason': aiReason,
        'tip': tip,
        'review_count': reviewCount,
      };

  Place copyWith({
    String? imageUrl,
    String? aiReason,
    String? tip,
    double? rating,
    int? reviewCount,
    String? description,
    bool? isOpenNow,
  }) =>
      Place(
        id: id,
        name: name,
        category: category,
        subcategory: subcategory,
        tags: tags,
        address: address,
        lat: lat,
        lng: lng,
        rating: rating ?? this.rating,
        priceRange: priceRange,
        duration: duration,
        imageUrl: imageUrl ?? this.imageUrl,
        description: description ?? this.description,
        openHours: openHours,
        phone: phone,
        region: region,
        aiReason: aiReason ?? this.aiReason,
        tip: tip ?? this.tip,
        reviewCount: reviewCount ?? this.reviewCount,
        isOpenNow: isOpenNow ?? this.isOpenNow,
      );

  // ── 헬퍼 ───────────────────────────────────
  static List<String> _buildTags(String rawCategory, String category) {
    final tags = <String>[category];
    if (rawCategory.contains('카페')) tags.addAll(['카페', '감성', '데이트']);
    if (rawCategory.contains('레스토랑') || rawCategory.contains('음식점')) {
      tags.add('맛집');
    }
    if (rawCategory.contains('공원')) tags.addAll(['산책', '야외', '자연']);
    if (rawCategory.contains('영화')) tags.addAll(['영화', '실내']);
    if (rawCategory.contains('전시') || rawCategory.contains('미술')) {
      tags.addAll(['전시', '문화']);
    }
    return tags.toSet().toList();
  }

  static String _inferPrice(String category) {
    if (category.contains('카페') || category.contains('디저트')) return '1~2만원';
    if (category.contains('레스토랑') || category.contains('음식점')) return '2~5만원';
    if (category.contains('영화') || category.contains('공연')) return '1~3만원';
    if (category.contains('오마카세') || category.contains('파인')) return '5만원+';
    if (category.contains('공원') || category.contains('산책')) return '무료';
    return '보통';
  }

  static int _inferDuration(String category) {
    if (category.contains('레스토랑') || category.contains('음식점') ||
        category.contains('맛집')) return 90;
    if (category.contains('영화') || category.contains('공연')) return 120;
    if (category.contains('카페') || category.contains('브런치') ||
        category.contains('디저트')) return 60;
    if (category.contains('공원') || category.contains('산책')) return 60;
    if (category.contains('전시') || category.contains('미술') ||
        category.contains('갤러리')) return 90;
    if (category.contains('체험') || category.contains('클래스')) return 120;
    if (category.contains('액티비티') || category.contains('방탈출')) return 90;
    return 60;
  }
}

// ─────────────────────────────────────────────
// DateCourse — AI가 생성한 데이트 코스
// ─────────────────────────────────────────────
class DateCourse {
  final String title;
  final String concept;   // 아키타입 컨셉명: "감성 로맨스" | "힙스터 컬처" 등
  final String mood;
  final String description;
  final List<Place> places;
  final int totalDuration; // 분 단위
  final String savedAt;   // ISO8601, 기본 ''

  const DateCourse({
    required this.title,
    this.concept = '',
    required this.mood,
    required this.description,
    required this.places,
    required this.totalDuration,
    this.savedAt = '',
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'concept': concept,
        'mood': mood,
        'description': description,
        'totalDuration': totalDuration,
        'savedAt': savedAt.isNotEmpty
            ? savedAt
            : DateTime.now().toIso8601String(),
        'places': places.map((p) => p.toSupabase()).toList(),
      };

  factory DateCourse.fromJson(Map<String, dynamic> json) => DateCourse(
        title: json['title'] as String? ?? '',
        concept: json['concept'] as String? ?? '',
        mood: json['mood'] as String? ?? '혼합',
        description: json['description'] as String? ?? '',
        totalDuration: json['totalDuration'] as int? ?? 0,
        savedAt: json['savedAt'] as String? ?? '',
        places: (json['places'] as List? ?? [])
            .map((p) => Place.fromSupabase(p as Map<String, dynamic>))
            .toList(),
      );
}

// ─────────────────────────────────────────────
// 장소 상세 리치 데이터 (on-demand 로딩)
// ─────────────────────────────────────────────

class GoogleReview {
  final String authorName;
  final int rating;
  final String text;
  final String relativeTime;

  const GoogleReview({
    required this.authorName,
    required this.rating,
    required this.text,
    required this.relativeTime,
  });
}

class NaverBlogReview {
  final String bloggerName;
  final String title;
  final String description;
  final String link;
  final String postDate;

  const NaverBlogReview({
    required this.bloggerName,
    required this.title,
    required this.description,
    required this.link,
    required this.postDate,
  });
}

class MenuItem {
  final String name;
  final String price;
  final String description;

  const MenuItem({
    required this.name,
    required this.price,
    required this.description,
  });
}

class PlaceDetail {
  final String googlePlaceId;
  final List<String> photoUrls;
  final bool isOpenNow;
  final String todayHours;
  final List<String> weekdayDescriptions;
  final double googleRating;
  final int reviewCount;
  final List<GoogleReview> googleReviews;
  final List<NaverBlogReview> naverReviews;
  final List<MenuItem> menuItems;
  final String aiDescription;
  final String website;
  final String nationalPhone;
  final String priceLevel;

  const PlaceDetail({
    required this.googlePlaceId,
    required this.photoUrls,
    required this.isOpenNow,
    required this.todayHours,
    required this.weekdayDescriptions,
    required this.googleRating,
    required this.reviewCount,
    required this.googleReviews,
    required this.naverReviews,
    required this.menuItems,
    required this.aiDescription,
    required this.website,
    required this.nationalPhone,
    required this.priceLevel,
  });

  PlaceDetail copyWith({
    List<NaverBlogReview>? naverReviews,
    List<MenuItem>? menuItems,
    String? aiDescription,
  }) =>
      PlaceDetail(
        googlePlaceId: googlePlaceId,
        photoUrls: photoUrls,
        isOpenNow: isOpenNow,
        todayHours: todayHours,
        weekdayDescriptions: weekdayDescriptions,
        googleRating: googleRating,
        reviewCount: reviewCount,
        googleReviews: googleReviews,
        naverReviews: naverReviews ?? this.naverReviews,
        menuItems: menuItems ?? this.menuItems,
        aiDescription: aiDescription ?? this.aiDescription,
        website: website,
        nationalPhone: nationalPhone,
        priceLevel: priceLevel,
      );
}
