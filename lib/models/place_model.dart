class Place {
  final String id;
  final String name;
  final String category;   // "감성" | "액티비티"
  final String subcategory;
  final List<String> tags;
  final String address;
  final double lat;
  final double lng;
  final double rating;
  final String priceRange;
  final int duration;       // 예상 소요 시간(분)
  final String imageUrl;
  final String description;
  final String openHours;
  final String phone;
  final String region;      // 지역명 (예: 강남구)

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
  });

  factory Place.fromNaverJson(Map<String, dynamic> json, {
    required String category,
    required String region,
    required String imageUrl,
  }) {
    // Naver Local Search returns mapx/mapy in TM128 (* 1e-7 ≈ WGS84)
    final mapx = json['mapx'] as String? ?? '0';
    final mapy = json['mapy'] as String? ?? '0';
    final lng = double.tryParse(mapx) != null
        ? double.parse(mapx) / 1e7
        : 0.0;
    final lat = double.tryParse(mapy) != null
        ? double.parse(mapy) / 1e7
        : 0.0;

    // Strip HTML tags from title
    final rawName = (json['title'] as String? ?? '')
        .replaceAll(RegExp(r'<[^>]*>'), '');

    final rawCategory = (json['category'] as String? ?? '');
    final subcategory = rawCategory.contains('>')
        ? rawCategory.split('>').last
        : rawCategory;

    return Place(
      id: 'naver_${rawName.hashCode}_${lat.hashCode}',
      name: rawName,
      category: category,
      subcategory: subcategory,
      tags: _buildTags(rawCategory, category),
      address: json['roadAddress'] as String? ?? json['address'] as String? ?? '',
      lat: lat,
      lng: lng,
      rating: 4.0 + (rawName.length % 10) * 0.1, // Naver API doesn't expose rating
      priceRange: _inferPrice(rawCategory),
      duration: _inferDuration(category),
      imageUrl: imageUrl,
      description: (json['description'] as String? ?? '').replaceAll(RegExp(r'<[^>]*>'), ''),
      openHours: '',
      phone: json['telephone'] as String? ?? '',
      region: region,
    );
  }

  factory Place.fromSupabase(Map<String, dynamic> row) {
    return Place(
      id: row['id'] as String,
      name: row['name'] as String,
      category: row['category'] as String,
      subcategory: row['subcategory'] as String? ?? '',
      tags: List<String>.from(row['tags'] ?? []),
      address: row['address'] as String? ?? '',
      lat: (row['lat'] as num).toDouble(),
      lng: (row['lng'] as num).toDouble(),
      rating: (row['rating'] as num? ?? 4.0).toDouble(),
      priceRange: row['price_range'] as String? ?? '보통',
      duration: row['duration'] as int? ?? 60,
      imageUrl: row['image_url'] as String? ?? '',
      description: row['description'] as String? ?? '',
      openHours: row['open_hours'] as String? ?? '',
      phone: row['phone'] as String? ?? '',
      region: row['region'] as String? ?? '',
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
  };

  static List<String> _buildTags(String rawCategory, String category) {
    final tags = <String>[category];
    if (rawCategory.contains('카페')) tags.addAll(['카페', '감성', '데이트']);
    if (rawCategory.contains('레스토랑') || rawCategory.contains('음식점')) tags.add('맛집');
    if (rawCategory.contains('공원')) tags.addAll(['산책', '야외', '자연']);
    if (rawCategory.contains('영화')) tags.addAll(['영화', '실내']);
    if (rawCategory.contains('전시') || rawCategory.contains('미술')) tags.addAll(['전시', '문화']);
    return tags.toSet().toList();
  }

  static String _inferPrice(String category) {
    if (category.contains('카페') || category.contains('빵')) return '저렴';
    if (category.contains('한식') || category.contains('분식')) return '저렴';
    if (category.contains('양식') || category.contains('이탈리안')) return '보통';
    if (category.contains('오마카세') || category.contains('파인')) return '고급';
    return '보통';
  }

  static int _inferDuration(String category) {
    if (category == '감성') return 90;
    if (category == '액티비티') return 120;
    return 90;
  }
}

class DateCourse {
  final String title;
  final String mood;
  final String description;  // Gemini가 생성한 소개 문구
  final List<Place> places;
  final int totalDuration;

  const DateCourse({
    required this.title,
    required this.mood,
    required this.description,
    required this.places,
    required this.totalDuration,
  });
}
