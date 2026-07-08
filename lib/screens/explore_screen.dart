import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/naver_map_status.dart';
import '../models/place_model.dart';
import '../services/cultural_event_service.dart';
import '../services/google_places_service.dart';
import '../services/kakao_place_service.dart';
import '../services/location_service.dart';
import '../services/naver_place_service.dart';
import '../services/place_cache.dart';
import '../services/place_ranker.dart';
import '../services/bookmark_service.dart';
import '../utils/app_theme.dart';
import 'place_detail_screen.dart';
import 'course_result_screen.dart';
import '../services/supabase_course_service.dart';

// ─────────────────────────────────────────────
// 탐색 화면 — 검색 + 카테고리 필터
// ─────────────────────────────────────────────

class ExploreScreen extends StatefulWidget {
  final LocationResult location;
  final String initialCategory;
  final bool initialOpenNowOnly;

  const ExploreScreen({
    super.key,
    required this.location,
    this.initialCategory = '전체',
    this.initialOpenNowOnly = false,
  });

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _searchCtrl  = TextEditingController();
  final _focusNode   = FocusNode();
  final _scrollCtrl  = ScrollController();

  List<Place> _results = [];
  List<CulturalEvent> _eventResults = [];   // 문화행사 전용 결과
  bool _loading      = false;
  bool _loadingMore  = false;
  bool _searched     = false;
  bool _hasMore      = true;     // 더 불러올 결과가 있는지
  late String _selectedCategory;
  String _lastKeyword = '';
  int _pageStart      = 1;       // Naver API start 파라미터 (1-based)

  // 내 주변 검색 반경 (km 단위 — 슬라이더용)
  double _nearbyRadius = 2.0; // 기본 2km
  bool   _nearbyMode   = false;

  // 지금 영업중 필터
  bool _openNowOnly = false;

  // 정렬 기준
  String _sortBy = '거리순'; // '거리순' | '평점순' | '인기순'

  // Naver API는 한 번에 최대 5개 → 4번 병렬 = 20개
  static const _batchSize = 20;
  // 문화행사 전용 카테고리 key
  static const _eventCategory = '🎪 문화행사';
  // Figma 순서: 전체 → 코스요리(맛집) → 카페 → 루프탑 → 체험 → 전시 → 문화행사 → 코스 검색
  static const _categories = [
    '전체', '맛집', '카페·브런치', '야경·뷰', '체험·액티비티', '이색 데이트', '전시·문화',
    _eventCategory, '코스 검색',
  ];

  // Figma 디자인 표시 레이블 (내부 키는 그대로 유지)
  static const _categoryLabels = {
    '전체':          '전체',
    '맛집':          '코스요리',
    '카페·브런치':   '카페',
    '야경·뷰':       '루프탑',
    '체험·액티비티': '체험',
    '이색 데이트':   '🎲 이색',
    '전시·문화':     '전시·문화',
    _eventCategory:  '문화행사',
    '코스 검색':     '코스 검색',
  };

  // 카테고리 → 단일 키워드 폴백 (레거시 호환)
  static const _categoryKeywords = {
    '카페·브런치':   '감성 카페 브런치 데이트',
    '전시·문화':    '전시 갤러리 미술관 복합문화공간',
    '체험·액티비티': '체험 클래스 방탈출 보드게임 커플',
    '이색 데이트':   '만화카페 카트장 방탈출 이색 데이트',
    '맛집':         '커플 레스토랑 맛집 저녁',
    '야경·뷰':      '야경 루프탑 뷰맛집 한강',
  };

  // 카테고리별 다중 쿼리 (병렬 실행 → 결과 합산으로 훨씬 많은 장소 확보)
  static const _categoryMultiKeywords = {
    '카페·브런치':   [
      '감성 카페 인스타 핫플',
      '브런치 카페 베이커리',
      '루프탑 카페 뷰',
      '북카페 독립서점 힙한',
      '디저트 카페 케이크',
      '테라스 카페 야외',
    ],
    '전시·문화':    [
      '전시회 갤러리 현대미술',
      '복합문화공간 팝업 트렌디',
      '포토스팟 인스타 사진 전시',
      '미술관 박물관 문화',
      '공연장 소극장 음악',
    ],
    '체험·액티비티': [
      '방탈출 실내 커플 오락',
      '볼링 보드게임 VR 체험',
      '공방 클래스 공예 DIY',
      '클라이밍 스포츠 레저',
      '수영 스키 서핑 야외',
      '노래방 오락실 PC방 실내',
      '스크린 골프 당구 스포츠',
      '체험 클래스 쿠킹 바리스타',
    ],
    '이색 데이트':  [
      '만화카페 만화방 데이트',
      '실내 카트장 레이싱 고카트',
      '방탈출 추리 미스터리 게임',
      'VR 체험관 가상현실 게임',
      '동물카페 고양이 강아지 이색',
      '미디어아트 몰입형 전시 이색',
      '실내 양궁 사격 다트 이색',
      '클라이밍 실내 암벽 짚라인',
      '보드게임 카페 이색 놀거리',
      '원데이클래스 공방 도자기 향수',
      '이색 카페 테마 컨셉',
      '아쿠아리움 식물원 이색 나들이',
    ],
    '맛집':         [
      '분위기 좋은 레스토랑 커플',
      '한식 한정식 맛집 저녁',
      '이탈리안 파스타 피자',
      '오마카세 일식 고급',
      'BBQ 고기 삼겹살 회식',
      '해산물 해물 포차 야장',
    ],
    '야경·뷰':      [
      '야경 루프탑 뷰맛집',
      '야경 드라이브 야외',
      '전망대 뷰포인트 스팟',
      '강변 호수 공원 산책',
    ],
  };

  // ODD 카테고리 → Kakao 카테고리 그룹 코드
  // Naver Maps와 동일한 지리 기반 탐색을 위해 사용
  static const _kakaoCategoryCodes = {
    '카페·브런치':    KakaoPlaceService.catCafe,    // CE7
    '맛집':          KakaoPlaceService.catFood,    // FD6
    '전시·문화':     KakaoPlaceService.catCulture, // CT1
    '체험·액티비티': KakaoPlaceService.catAttr,    // AT4
    '이색 데이트':   KakaoPlaceService.catAttr,    // AT4
    '야경·뷰':       KakaoPlaceService.catAttr,    // AT4
  };

  // 카테고리 블랙리스트 (카테고리 오염 방지)
  static const _exploreBlacklist = {
    '카페·브런치':    ['음식점', '식당', '레스토랑', '방탈출', '전시'],
    '맛집':          ['카페', '커피', '빵집', '전시', '방탈출'],
    '전시·문화':     ['음식점', '식당', '카페', '커피'],
    '체험·액티비티': ['음식점', '카페', '커피'],
    // 이색 데이트: 만화카페·동물카페처럼 '카페'가 들어간 이색 장소를 막지 않도록 비움
    '이색 데이트':   <String>[],
    '야경·뷰':       <String>[],
  };

  @override
  void initState() {
    super.initState();
    // 홈 등 외부 진입점이 이모지 없는 '문화행사' 별칭을 넘겨도
    // 문화행사 카테고리로 정규화 (키 불일치 버그 방지)
    _selectedCategory =
        widget.initialCategory == '문화행사' ? _eventCategory : widget.initialCategory;
    _openNowOnly = widget.initialOpenNowOnly;

    // 무한 스크롤: 하단 80px 남으면 자동 로드
    _scrollCtrl.addListener(() {
      if (!_scrollCtrl.hasClients) return;
      final pos = _scrollCtrl.position;
      if (pos.pixels >= pos.maxScrollExtent - 80) {
        _loadMore();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selectedCategory == _eventCategory) {
        _loadCulturalEvents();
      } else if (_selectedCategory != '전체') {
        _searchCategory(_selectedCategory);
      } else {
        _search('데이트 핫플');
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// city + district 합체 → "대전광역시 서구", "서울특별시 강남구"
  /// district가 이미 city를 포함하면 그대로 사용
  String get _region => widget.location.fullRegion;

  /// 카테고리 검색용 광역 지역 — 시+구 수준 (동 이하 제거)
  /// fullRegion = "대전광역시 서구 둔산동" → "대전광역시 서구"
  String _cityLevelRegion() {
    final full = widget.location.fullRegion.trim();
    if (full.isEmpty) return widget.location.city;
    final tokens = full.split(RegExp(r'\s+'));
    // 시/구/군 토큰까지만 유지 (동·읍·면 이하 제거)
    final keep = <String>[];
    for (final t in tokens) {
      keep.add(t);
      if (t.endsWith('시') || t.endsWith('구') || t.endsWith('군')) {
        if (keep.length >= 2) break; // 시 + 구 2개면 충분
      }
    }
    return keep.join(' ');
  }

  // ── 새 검색 (초기화 후 1페이지, 병렬 배치로 20개) ──
  /// 코스 DB 검색 — 탐색 화면 '코스 검색' 탭 전용
  Future<void> _searchCourses(String query) async {
    setState(() { _loading = true; _searched = true; });
    _focusNode.unfocus();
    final city = widget.location.city.isNotEmpty ? widget.location.city : '';
    final results = await SupabaseCourseService.searchCourses(
      query: query.isNotEmpty ? query : city,
      city: city,
      limit: 20,
    );
    setState(() => _loading = false);
    if (!mounted) return;
    if (results.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('코스를 찾을 수 없어요. 다른 키워드로 검색해보세요.'),
            behavior: SnackBarBehavior.floating));
      return;
    }
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => CourseResultScreen(
        courses: results,
        mood: query.isNotEmpty ? query : '코스 검색',
      ),
    ));
  }

  Future<void> _search([String? overrideQuery]) async {
    final query = overrideQuery ?? _searchCtrl.text.trim();

    // 코스 검색 모드
    if (_selectedCategory == '코스 검색') {
      await _searchCourses(query);
      return;
    }

    if (query.isEmpty) return;

    setState(() {
      _loading     = true;
      _searched    = true;
      _results     = [];
      _pageStart   = 1;
      _hasMore     = true;
      _lastKeyword = query;
    });
    _focusNode.unfocus();

    try {
      // searchBatch: 4개 병렬 요청 × 5개 = 최대 20개
      final places = await NaverPlaceService.searchBatch(
        keyword: query,
        region: _region,
        category: _selectedCategory == '전체' ? '탐색' : _selectedCategory,
        blacklist: _blacklistFor(_selectedCategory),
        count: _batchSize,
        fromStart: 1,
      );

      if (mounted) {
        if (places.isEmpty && widget.location.lat != 0.0) {
          // GPS 자동 폴백: 카카오 근방 검색
          _autoFallbackNearby(query);
          return;
        }
        setState(() {
          _results   = places;
          _loading   = false;
          _pageStart = 1 + _batchSize;
          _hasMore   = places.length >= _batchSize;
        });
        _enrichPhotos(places);
      }
    } catch (_) {
      if (mounted) {
        // 네트워크 오류 시에도 GPS 폴백 시도
        if (widget.location.lat != 0.0) {
          _autoFallbackNearby(query);
        } else {
          setState(() => _loading = false);
        }
      }
    }
  }

  /// 결과 없음 / 오류 시 GPS 근방으로 자동 폴백
  Future<void> _autoFallbackNearby(String keyword) async {
    if (!mounted) return;
    // 로딩 메시지를 바꾸지 않고 조용히 폴백
    final cat = _selectedCategory == '전체' ? '맛집' : _selectedCategory;
    final blacklist = _exploreBlacklist[cat] ?? const [];
    final kakaoCode = _kakaoCategoryCodes[cat];

    try {
      final results = await Future.wait([
        if (kakaoCode != null)
          KakaoPlaceService.searchByMultiRadius(
            lat: widget.location.lat,
            lng: widget.location.lng,
            categoryCode: kakaoCode,
            category: cat,
            blacklist: blacklist,
          )
        else
          Future.value(<Place>[]),
        GooglePlacesService.searchNearbyMulti(
          lat: widget.location.lat,
          lng: widget.location.lng,
          category: cat,
          radius: 3000,
        ),
      ]);

      final combined = _dedupeByName(
          _dedupeById(results.expand((r) => r).toList()));
      final ranked = PlaceRanker.rank(combined,
          category: cat,
          userLat: widget.location.lat,
          userLng: widget.location.lng);

      if (mounted) {
        setState(() {
          _results  = ranked;
          _loading  = false;
          _hasMore  = false;
          _nearbyMode = true;
        });
        if (ranked.isNotEmpty) _enrichPhotos(ranked);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Google Places 실사진 병렬 로드 (탐색 결과에도 동일 적용)
  Future<void> _enrichPhotos(List<Place> snapshot) async {
    if (snapshot.isEmpty) return;
    final futures = snapshot.map(
        (p) => GooglePlacesService.fetchFirstPhotoUrl(p.name, p.address));
    final urls = await Future.wait(futures);
    if (!mounted) return;

    final updated = <Place>[];
    for (var i = 0; i < snapshot.length; i++) {
      final url = urls[i];
      updated.add(url != null ? snapshot[i].copyWith(imageUrl: url) : snapshot[i]);
    }

    // _results 중 snapshot과 동일한 항목만 교체 (페이지 변경 중일 수도 있으므로 안전하게)
    setState(() {
      final ids = {for (final p in updated) p.id: p};
      _results = _results.map((p) => ids[p.id] ?? p).toList();
    });
  }

  // ── 추가 로드 (페이지네이션 — 배치 단위로 20개씩 추가) ──
  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _lastKeyword.isEmpty) return;
    setState(() => _loadingMore = true);

    try {
      final places = await NaverPlaceService.searchBatch(
        keyword: _lastKeyword,
        region: _region,
        category: _selectedCategory == '전체' ? '탐색' : _selectedCategory,
        blacklist: _blacklistFor(_selectedCategory),
        count: _batchSize,
        fromStart: _pageStart,
      );

      // 중복 제거
      final existingIds = _results.map((p) => p.id).toSet();
      final newPlaces = places.where((p) => !existingIds.contains(p.id)).toList();

      if (mounted) {
        setState(() {
          _results.addAll(newPlaces);
          _loadingMore = false;
          _pageStart  += _batchSize;
          _hasMore     = places.length >= _batchSize;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _searchCategory(String cat) async {
    // 코스 검색 탭: 현재 검색어로 코스 DB 검색
    if (cat == '코스 검색') {
      setState(() { _selectedCategory = cat; _searched = true; });
      await _searchCourses(_searchCtrl.text.trim());
      return;
    }

    setState(() {
      _selectedCategory = cat;
      _loading  = true;
      _searched = true;
      _results  = [];
      _nearbyMode = false;
    });

    // 문화행사 탭: 문화포털 API 호출
    if (cat == _eventCategory) {
      _searchCtrl.clear();
      await _loadCulturalEvents();
      return;
    }

    if (cat == '전체') {
      final q = _searchCtrl.text.trim();
      _search(q.isNotEmpty ? q : '데이트 핫플');
      return;
    }

    _searchCtrl.clear();

    // ── 캐시 우선 확인 (30분 TTL) ─────────────────────
    final region   = _cityLevelRegion();
    final cacheKey = PlaceCache.key(region, cat);
    final cached   = PlaceCache.get(cacheKey);
    if (cached != null && cached.isNotEmpty) {
      if (mounted) {
        setState(() {
          _results     = cached;
          _loading     = false;
          _lastKeyword = _categoryMultiKeywords[cat]?.first ?? cat;
          _pageStart   = 21;
          _hasMore     = false;
        });
      }
      return;
    }

    // ── Source 1: Naver 키워드 다중 쿼리 (15개/쿼리, 3페이지 병렬) ──
    final keywords  = _categoryMultiKeywords[cat] ?? [_categoryKeywords[cat] ?? cat];
    final blacklist = _exploreBlacklist[cat] ?? const [];

    final naverFutures = keywords.map((kw) => NaverPlaceService.searchBatch(
      keyword: kw, region: region, category: cat,
      blacklist: blacklist, count: 15, // ↑ 10→15 (3페이지 = 15개/쿼리)
    ));

    // ── Source 2: Kakao 다중반경 검색 (1km + 3km 병렬) ──
    // 각 반경 3페이지×15개 → 최대 90개 원본 → 이름중복제거 후 ~70 고유
    final kakaoCode = _kakaoCategoryCodes[cat];
    final Future<List<Place>> kakaoFuture = (_nearbyMode && kakaoCode != null &&
            widget.location.lat != 0.0 && widget.location.lng != 0.0)
        ? KakaoPlaceService.searchByMultiRadius(
            lat: widget.location.lat,
            lng: widget.location.lng,
            categoryCode: kakaoCode,
            category: cat,
            blacklist: blacklist,
          )
        : Future.value([]);

    // ── Source 3: Google 다중타입그룹 병렬 (맛집 60개, 체험 40개) ──
    final Future<List<Place>> googleFuture =
        (_nearbyMode && widget.location.lat != 0.0 && widget.location.lng != 0.0)
            ? GooglePlacesService.searchNearbyMulti(
                lat: widget.location.lat,
                lng: widget.location.lng,
                category: cat,
                radius: (_nearbyRadius * 1000).toInt(),
              )
            : Future.value([]);

    try {
      final allFutures = [...naverFutures, kakaoFuture, googleFuture];
      final allResults = await Future.wait(allFutures);

      final naverList  = allResults.sublist(0, keywords.length).expand((r) => r).toList();
      final kakaoList  = allResults[keywords.length] as List<Place>;
      final googleList = allResults[keywords.length + 1] as List<Place>;

      // ── 3단계 정제 파이프라인 ──────────────────────────
      // 1) ID 기반 중복제거 (같은 API 내 중복)
      final idDeduped = _dedupeById([...naverList, ...kakaoList, ...googleList]);
      // 2) 이름 유사도 중복제거 (크로스-API 동일 장소)
      final nameDeduped = _dedupeByName(idDeduped);
      // 3) 다요소 랭킹 (베이지안 평점 × 시간대 가중치 × 거리 감쇠)
      final ranked = PlaceRanker.rank(
        nameDeduped,
        category: cat,
        userLat: widget.location.lat,
        userLng: widget.location.lng,
      );

      // 결과 캐시 저장 (30분 TTL)
      PlaceCache.set(cacheKey, ranked);

      if (mounted) {
        setState(() {
          _results     = ranked;
          _loading     = false;
          _lastKeyword = keywords.first;
          _pageStart   = 21;
          _hasMore     = naverList.length >= 15;
        });
        _enrichPhotos(ranked);
      }
    } catch (_) {
      if (mounted) {
        if (widget.location.lat != 0.0) {
          // 카테고리 API 실패 → GPS 폴백
          _autoFallbackNearby(cat);
        } else {
          setState(() => _loading = false);
        }
      }
    }
  }

  // ── 내 주변 반경 검색 (GPS 기반, 지역 선택 불필요) ──────────────────
  Future<void> _searchNearby(String cat) async {
    if (widget.location.lat == 0.0 && widget.location.lng == 0.0) return;
    setState(() {
      _selectedCategory = cat;
      _loading    = true;
      _searched   = true;
      _results    = [];
      _nearbyMode = true;
    });

    final blacklist = _exploreBlacklist[cat] ?? const [];
    final kakaoCode = _kakaoCategoryCodes[cat];
    final radiusM   = (_nearbyRadius * 1000).toInt();

    try {
      final results = await Future.wait([
        if (kakaoCode != null)
          KakaoPlaceService.searchByMultiRadius(   // 1km+3km 병렬
            lat: widget.location.lat, lng: widget.location.lng,
            categoryCode: kakaoCode, category: cat,
            blacklist: blacklist,
          ),
        GooglePlacesService.searchNearbyMulti(     // 다중타입그룹 병렬
          lat: widget.location.lat, lng: widget.location.lng,
          category: cat, radius: radiusM,
        ),
      ]);

      final idDeduped   = _dedupeById(results.expand((r) => r).toList());
      final nameDeduped = _dedupeByName(idDeduped);
      final ranked      = PlaceRanker.rank(nameDeduped,
          category: cat,
          userLat: widget.location.lat,
          userLng: widget.location.lng);
      if (mounted) {
        setState(() { _results = ranked; _loading = false; _hasMore = false; });
        _enrichPhotos(ranked);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// ID 기반 중복 제거 (1차 — 같은 API 내 중복)
  List<Place> _dedupeById(List<Place> places) {
    final seen = <String>{};
    return places.where((p) => seen.add(p.id)).toList();
  }

  /// 이름 유사도 기반 중복 제거 (2차 — 크로스 API 동일 장소)
  /// 예: "스타벅스 강남역점"(Naver) = "스타벅스강남역점"(Google) 처리
  List<Place> _dedupeByName(List<Place> places) {
    final seen = <String>{};
    final result = <Place>[];
    for (final p in places) {
      final key = p.name
          .toLowerCase()
          .replaceAll(RegExp(r'[\s\-_·\(\)\[\]]'), '')
          .replaceAll(RegExp(r'(카페|café|cafe|점|지점|본점|[0-9]+호점)$'), '');
      if (seen.add(key)) result.add(p);
    }
    return result;
  }

  // ── 문화행사 로딩 ─────────────────────────────────────────────────
  Future<void> _loadCulturalEvents() async {
    setState(() { _loading = true; _searched = true; _eventResults = []; });
    try {
      // fullRegion 사용: "대전광역시 대덕구" → "대전" 매핑이 가능하도록
      // district("대덕구") 기준이면 areaCodeMap에서 못 찾아 서울로 폴백됨
      final regionForApi = widget.location.fullRegion.isNotEmpty
          ? widget.location.fullRegion
          : widget.location.district;
      final events = await CulturalEventService.fetchByArea(
        region: regionForApi, rows: 30);
      if (mounted) setState(() { _eventResults = events; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // 카테고리별 블랙리스트 (카테고리 오염 방지)
  static List<String> _blacklistFor(String cat) {
    switch (cat) {
      case '카페·브런치':
        return ['음식점', '레스토랑', '공원', '전시', '갤러리', '방탈출'];
      case '전시·문화':
        return [
          '음식점', '식당', '카페', '커피', '레스토랑',
          '한식', '중식', '일식', '양식', '고기', '부대찌개',
          '치킨', '피자', '분식', '주점', '술집', '고깃집',
          '편의점', '마트', '수퍼', '슈퍼',
        ];
      case '체험·액티비티':
        return ['음식점', '식당', '카페', '커피', '레스토랑'];
      case '맛집':
        return ['카페', '전시', '갤러리', '공원', '방탈출'];
      default:
        return const [];
    }
  }

  // 카테고리별 화이트리스트 — 최소 하나라도 포함되어야 통과
  // null이면 화이트리스트 미적용 (전체 통과)
  static const _categoryWhitelist = {
    '전시·문화': [
      '전시', '갤러리', '미술관', '박물관', '공연', '뮤지컬', '연극',
      '음악', '문화', '예술', '팝업', '사진관', '사진', '포토',
      '복합문화', '아트', '소극장', '대극장', '전시장',
    ],
  };

  List<Place> get _filtered {
    List<Place> base = _openNowOnly
        ? _results.where((p) => p.isOpenNow != false).toList()
        : List<Place>.from(_results);

    // 카테고리 화이트리스트 post-filter
    final whitelist = _categoryWhitelist[_selectedCategory];
    if (whitelist != null) {
      base = base.where((p) {
        final combined = '${p.category} ${p.subcategory} ${p.tags.join(' ')}'.toLowerCase();
        // 블랙리스트 키워드 포함 시 제외
        final foodTerms = [
          '부대찌개', '고기', '한식', '중식', '일식', '치킨', '피자',
          '분식', '주점', '술집', '음식점', '식당', '레스토랑',
        ];
        if (foodTerms.any((term) => combined.contains(term))) return false;
        // 화이트리스트 키워드 없으면 제외
        return whitelist.any((w) => combined.contains(w));
      }).toList();
    }

    // 정렬 적용
    switch (_sortBy) {
      case '평점순':
        base.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
        break;
      case '인기순':
        base.sort((a, b) => (b.reviewCount ?? 0).compareTo(a.reviewCount ?? 0));
        break;
      default: // '거리순' — PlaceRanker 기본 순서 유지
        break;
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 헤더 ──
            _buildHeader(),

            // ── 지도 (상단) — 결과 위치를 한눈에 ──
            Container(
              height: 190,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.divider),
              ),
              child: _ExploreMap(
                places: _results,
                location: widget.location,
                onTapPlace: (p) => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PlaceDetailScreen(place: p)),
                ),
              ),
            ),

            // ── 내 주변 검색 배너 ──
            _buildNearbyBanner(),

            // ── 카테고리 필터 ──
            _buildCategoryFilter(),
            const SizedBox(height: 4),

            // ── 부가 필터: 지금 영업중 ──
            if (_searched && _selectedCategory != _eventCategory)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: GestureDetector(
                  onTap: () => setState(() => _openNowOnly = !_openNowOnly),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _openNowOnly
                          ? const Color(0xFFE8F5E9)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _openNowOnly
                            ? const Color(0xFF2E7D32)
                            : Colors.grey[300]!,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.circle,
                          size: 8,
                          color: _openNowOnly
                              ? const Color(0xFF2E7D32)
                              : Colors.grey[400],
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '지금 영업중',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _openNowOnly
                                ? const Color(0xFF2E7D32)
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ── 결과 / 빈 상태 ──
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  // ── 내 주변 검색 배너 ─────────────────────────────────────────
  Widget _buildNearbyBanner() {
    final hasGps = widget.location.lat != 0.0 || widget.location.lng != 0.0;
    if (!hasGps) return const SizedBox.shrink();

    final radiusLabel = _nearbyRadius >= 1.0
        ? '${_nearbyRadius.toStringAsFixed(0)}km'
        : '${(_nearbyRadius * 1000).toStringAsFixed(0)}m';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _nearbyMode
            ? AppTheme.primary.withOpacity(0.08)
            : AppTheme.bg2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _nearbyMode
              ? AppTheme.primary.withOpacity(0.4)
              : Colors.transparent),
      ),
      child: Row(
        children: [
          Icon(Icons.my_location_rounded,
              size: 16,
              color: _nearbyMode ? AppTheme.primary : AppTheme.textLight),
          const SizedBox(width: 8),
          Text(
            _nearbyMode ? '내 주변 $radiusLabel 검색 중' : '📍 내 주변으로 검색',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _nearbyMode ? AppTheme.primary : AppTheme.textMid,
            ),
          ),
          const Spacer(),
          // 반경 슬라이더
          SizedBox(
            width: 100,
            child: Slider(
              value: _nearbyRadius,
              min: 0.5, max: 5.0, divisions: 9,
              activeColor: AppTheme.primary,
              inactiveColor: AppTheme.divider,
              label: radiusLabel,
              onChanged: (v) => setState(() => _nearbyRadius = v),
              onChangeEnd: (_) {
                if (_nearbyMode && _selectedCategory != '전체' &&
                    _selectedCategory != _eventCategory) {
                  _searchNearby(_selectedCategory);
                }
              },
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () {
              final cat = _selectedCategory == '전체' || _selectedCategory == _eventCategory
                  ? '맛집' : _selectedCategory;
              _searchNearby(cat);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: _nearbyMode ? null : AppTheme.primaryGradient,
                color: _nearbyMode ? AppTheme.primary.withOpacity(0.15) : null,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _nearbyMode ? '새로고침' : '검색',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _nearbyMode ? AppTheme.primary : Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '둘러보기',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: AppTheme.textDark,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 12),
          // 검색바
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.bg2,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    focusNode: _focusNode,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      hintText: '지역, 분위기, 음식 종류 검색',
                      hintStyle: const TextStyle(
                          color: AppTheme.textLight, fontSize: 14),
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: AppTheme.textLight, size: 20),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  color: AppTheme.textLight, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() {
                                  _results  = [];
                                  _searched = false;
                                  _selectedCategory = '전체';
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onChanged: (v) => setState(() {}),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _search,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.search_rounded,
                      color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (_, i) {
          final cat      = _categories[i];
          final selected = cat == _selectedCategory;
          return GestureDetector(
            onTap: () => _searchCategory(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? AppTheme.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected
                      ? AppTheme.primary
                      : const Color(0xFFE0E0E8),
                ),
                boxShadow: selected
                    ? [BoxShadow(
                        color: AppTheme.primary.withOpacity(0.25),
                        blurRadius: 6, offset: const Offset(0, 2))]
                    : [],
              ),
              child: Text(
                _categoryLabels[cat] ?? cat,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? Colors.white : AppTheme.textDark,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return _buildShimmer();
    // 문화행사 탭
    if (_selectedCategory == _eventCategory) {
      if (!_searched) return _buildInitialState();
      if (_eventResults.isEmpty) return _buildNoResult();
      return _buildEventList();
    }
    if (!_searched) return _buildInitialState();
    if (_filtered.isEmpty) return _buildNoResult();
    return _buildResultList();
  }

  Widget _buildEventList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _eventResults.length,
      itemBuilder: (_, i) => _CulturalEventTile(event: _eventResults[i]),
    );
  }

  Widget _buildInitialState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.chipBg,
              borderRadius: BorderRadius.circular(40),
            ),
            child: const Center(
                child: Text('🔍', style: TextStyle(fontSize: 36))),
          ),
          const SizedBox(height: 16),
          const Text(
            '장소를 검색해보세요',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '카페, 맛집, 공원, 전시 등',
            style: TextStyle(fontSize: 14, color: AppTheme.textLight),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResult() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppTheme.chipBg,
              borderRadius: BorderRadius.circular(40),
            ),
            child: const Center(child: Text('😅', style: TextStyle(fontSize: 36))),
          ),
          const SizedBox(height: 16),
          const Text('결과를 불러오지 못했어요',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
          const SizedBox(height: 6),
          const Text('네트워크 상태를 확인하거나\n다른 카테고리를 눌러보세요',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textLight, height: 1.6)),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => _searchCategory(_selectedCategory),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: const Text('다시 시도', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 12,
        mainAxisSpacing: 12, childAspectRatio: 0.62,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey[200]!,
        highlightColor: Colors.grey[50]!,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildResultList() {
    final itemCount = _filtered.length + (_loadingMore ? 1 : 0);

    return CustomScrollView(
      controller: _scrollCtrl,
      slivers: [
        // 결과 수
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${_filtered.length}',
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.primary,
                            fontWeight: FontWeight.w700),
                      ),
                      const TextSpan(
                        text: '개의 장소',
                        style: TextStyle(fontSize: 13, color: AppTheme.textMid),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () async {
                    final options = ['거리순', '평점순', '인기순'];
                    final picked = await showMenu<String>(
                      context: context,
                      position: RelativeRect.fromLTRB(
                        MediaQuery.of(context).size.width - 120, 140, 12, 0),
                      items: options.map((o) => PopupMenuItem(
                        value: o,
                        child: Row(
                          children: [
                            if (_sortBy == o)
                              const Icon(Icons.check, size: 16, color: AppTheme.primary)
                            else
                              const SizedBox(width: 16),
                            const SizedBox(width: 6),
                            Text(o, style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      )).toList(),
                    );
                    if (picked != null && picked != _sortBy) {
                      setState(() => _sortBy = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _sortBy != '거리순'
                          ? AppTheme.primary.withOpacity(0.1)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _sortBy != '거리순'
                            ? AppTheme.primary.withOpacity(0.3)
                            : Colors.grey[300]!,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _sortBy,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _sortBy != '거리순'
                                ? AppTheme.primary
                                : AppTheme.textMid,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.expand_more_rounded,
                          size: 14,
                          color: _sortBy != '거리순'
                              ? AppTheme.primary
                              : AppTheme.textMid,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // 2열 그리드
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                if (i < _filtered.length) {
                  return _FigmaPlaceCard(place: _filtered[i]);
                }
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator(
                      color: AppTheme.primary, strokeWidth: 2.5)),
                );
              },
              childCount: itemCount,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.62,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// 문화행사 카드
// ─────────────────────────────────────────────

class _CulturalEventTile extends StatelessWidget {
  final CulturalEvent event;
  const _CulturalEventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _CulturalEventDetailScreen(event: event),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              child: event.thumbnail.isNotEmpty
                  ? CachedNetworkImage(imageUrl: event.thumbnail, width: 88, height: 88, fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _emojiBox(event.emoji))
                  : _emojiBox(event.emoji),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(color: AppTheme.chipBg, borderRadius: BorderRadius.circular(6)),
                        child: Text(event.realmName, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                      ),
                      if (event.isOngoing) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(6)),
                          child: const Text('진행중', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF2E7D32))),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 5),
                    Text(event.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textDark, letterSpacing: -0.3), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    if (event.place.isNotEmpty) Text(event.place, style: const TextStyle(fontSize: 12, color: AppTheme.textLight), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (event.formattedDate.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text('📅 ${event.formattedDate}', style: const TextStyle(fontSize: 11, color: AppTheme.textLight)),
                    ],
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.chevron_right_rounded, color: AppTheme.textLight, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emojiBox(String emoji) => Container(
    width: 88, height: 88, color: AppTheme.chipBg,
    child: Center(child: Text(emoji, style: const TextStyle(fontSize: 36))),
  );
}

// ─────────────────────────────────────────────
// Figma 스타일 2열 그리드 카드
// ─────────────────────────────────────────────

class _FigmaPlaceCard extends StatefulWidget {
  final Place place;
  const _FigmaPlaceCard({required this.place});
  @override
  State<_FigmaPlaceCard> createState() => _FigmaPlaceCardState();
}

class _FigmaPlaceCardState extends State<_FigmaPlaceCard> {
  bool _bookmarked = false;

  @override
  void initState() {
    super.initState();
    BookmarkService.isBookmarked(widget.place.id)
        .then((v) => mounted ? setState(() => _bookmarked = v) : null);
  }

  Future<void> _toggle() async {
    final saved = await BookmarkService.toggle(widget.place);
    if (mounted) setState(() => _bookmarked = saved);
  }

  @override
  Widget build(BuildContext context) {
    final cat = widget.place.category;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlaceDetailScreen(place: widget.place))),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Stack(children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  child: widget.place.imageUrl.isNotEmpty
                      ? CachedNetworkImage(imageUrl: widget.place.imageUrl, width: double.infinity, fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _placeholderImg(cat))
                      : _placeholderImg(cat),
                ),
                Positioned(
                  top: 6, right: 6,
                  child: GestureDetector(
                    onTap: _toggle,
                    child: Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                        color: _bookmarked ? AppTheme.primary : Colors.black.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(_bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ]),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.place.name,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textDark, height: 1.3),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 5),
                    Text(_metaText(widget.place),
                        style: const TextStyle(fontSize: 10, color: AppTheme.textMid, height: 1.4),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const Spacer(),
                    Row(
                      children: List.generate(3, (i) {
                        final date = DateTime.now().add(Duration(days: i));
                        final label = i == 0 ? '오늘' : i == 1 ? '내일' : '${date.month}/${date.day}';
                        final isFirst = i == 0;
                        return Container(
                          margin: const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isFirst ? const Color(0xFFFFF0EC) : AppTheme.bg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isFirst ? const Color(0xFFFFD5C8) : const Color(0xFFE0E0E8)),
                          ),
                          child: Text(label,
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
                                  color: isFirst ? AppTheme.accent : AppTheme.textLight)),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderImg(String cat) {
    const emojis = {'카페·브런치': '☕', '맛집': '🍽️', '전시·문화': '🎨', '체험·액티비티': '🎯', '야경·뷰': '🌃'};
    return Container(color: AppTheme.chipBg, child: Center(child: Text(emojis[cat] ?? '📍', style: const TextStyle(fontSize: 36))));
  }

  String _metaText(Place p) {
    final parts = <String>[];
    if (p.rating > 0) parts.add('${p.rating.toStringAsFixed(1)}');
    final addr = p.address.split(' ');
    if (addr.length >= 2) parts.add(addr.take(2).join(' '));
    if (p.subcategory.isNotEmpty) parts.add(p.subcategory);
    else if (p.category.isNotEmpty) parts.add(p.category);
    return parts.join(' · ');
  }
}

// ─────────────────────────────────────────────
// 문화행사 인앱 상세 화면
// ─────────────────────────────────────────────

class _CulturalEventDetailScreen extends StatelessWidget {
  final CulturalEvent event;
  const _CulturalEventDetailScreen({required this.event});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220, pinned: true, backgroundColor: AppTheme.primary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: event.thumbnail.isNotEmpty
                  ? CachedNetworkImage(imageUrl: event.thumbnail, fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _emojiHeader())
                  : _emojiHeader(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(spacing: 8, children: [
                    _tag(event.realmName, AppTheme.primary, AppTheme.chipBg),
                    if (event.isOngoing) _tag('진행중', const Color(0xFF2E7D32), const Color(0xFFE8F5E9)),
                  ]),
                  const SizedBox(height: 12),
                  Text(event.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textDark, height: 1.35, letterSpacing: -0.5)),
                  const SizedBox(height: 16),
                  if (event.formattedDate.isNotEmpty) _infoRow(Icons.calendar_today_rounded, event.formattedDate),
                  if (event.place.isNotEmpty) _infoRow(Icons.location_on_rounded, event.place),
                  if (event.area.isNotEmpty) _infoRow(Icons.map_outlined, event.area),
                  if (event.price.isNotEmpty) _infoRow(Icons.attach_money_rounded, event.price),
                  if (event.description.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Divider(height: 1, color: Color(0xFFF0F0F5)),
                    const SizedBox(height: 20),
                    const Text('행사 소개', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
                    const SizedBox(height: 8),
                    Text(event.description, style: const TextStyle(fontSize: 14, color: AppTheme.textMid, height: 1.6)),
                  ],
                  if (event.url.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final uri = Uri.tryParse(event.url);
                          if (uri == null) return;
                          try { await launchUrl(uri, mode: LaunchMode.externalApplication); }
                          catch (_) { try { await launchUrl(uri, mode: LaunchMode.inAppWebView); } catch (_) {} }
                        },
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: const Text('공식 페이지에서 더 보기'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: const BorderSide(color: AppTheme.primary),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emojiHeader() => Container(color: AppTheme.chipBg, child: Center(child: Text(event.emoji, style: const TextStyle(fontSize: 64))));
  Widget _tag(String label, Color tc, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
    child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tc)),
  );
  Widget _infoRow(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 16, color: AppTheme.textLight),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 14, color: AppTheme.textMid, height: 1.4))),
    ]),
  );
}

// ─────────────────────────────────────────────
// 둘러보기 상단 지도 — 결과 마커를 네이티브 네이버 지도에 표시
// (map_screen 패턴 재사용. 인증 실패 시 아래 리스트는 정상 동작)
// ─────────────────────────────────────────────

class _ExploreMap extends StatefulWidget {
  final List<Place> places;
  final LocationResult location;
  final void Function(Place) onTapPlace;

  const _ExploreMap({
    required this.places,
    required this.location,
    required this.onTapPlace,
  });

  @override
  State<_ExploreMap> createState() => _ExploreMapState();
}

class _ExploreMapState extends State<_ExploreMap> {
  NaverMapController? _controller;

  // 대한민국 범위 좌표만 지도에 표시
  static bool _valid(Place p) =>
      p.lat >= 33.0 && p.lat <= 39.5 && p.lng >= 124.0 && p.lng <= 132.0;

  List<Place> get _validPlaces => widget.places.where(_valid).toList();

  @override
  void didUpdateWidget(covariant _ExploreMap old) {
    super.didUpdateWidget(old);
    // 결과 리스트가 바뀌면 마커 갱신
    if (!identical(old.places, widget.places)) _refresh();
  }

  Future<void> _refresh() async {
    final c = _controller;
    if (c == null) return;
    await c.clearOverlays();
    _plot(c);
  }

  void _onMapReady(NaverMapController c) {
    _controller = c;
    _plot(c);
  }

  void _plot(NaverMapController c) {
    final valid = _validPlaces;
    if (valid.isEmpty) return;

    final coords = <NLatLng>[];
    for (var i = 0; i < valid.length; i++) {
      final p = valid[i];
      final pos = NLatLng(p.lat, p.lng);
      coords.add(pos);
      final marker = NMarker(
        id: 'e$i',
        position: pos,
        caption: NOverlayCaption(text: p.name),
      );
      marker.setOnTapListener((NMarker m) => widget.onTapPlace(p));
      c.addOverlay(marker);
    }

    if (coords.length == 1) {
      c.updateCamera(NCameraUpdate.scrollAndZoomTo(target: coords.first, zoom: 14));
      return;
    }
    var minLat = coords.first.latitude, maxLat = coords.first.latitude;
    var minLng = coords.first.longitude, maxLng = coords.first.longitude;
    for (final co in coords) {
      if (co.latitude < minLat) minLat = co.latitude;
      if (co.latitude > maxLat) maxLat = co.latitude;
      if (co.longitude < minLng) minLng = co.longitude;
      if (co.longitude > maxLng) maxLng = co.longitude;
    }
    c.updateCamera(NCameraUpdate.fitBounds(
      NLatLngBounds(
        southWest: NLatLng(minLat, minLng),
        northEast: NLatLng(maxLat, maxLng),
      ),
      padding: const EdgeInsets.all(40),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final hasGps = widget.location.lat != 0.0 || widget.location.lng != 0.0;
    final center = hasGps
        ? NLatLng(widget.location.lat, widget.location.lng)
        : const NLatLng(37.5665, 126.9780); // 폴백: 서울 시청

    return Stack(
      children: [
        Positioned.fill(
          child: NaverMap(
            options: NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(target: center, zoom: 12),
              mapType: NMapType.basic,
            ),
            onMapReady: _onMapReady,
          ),
        ),
        // 인증 실패 시 아래 리스트는 그대로 쓰고, 지도 영역만 안내
        Positioned(
          top: 0, left: 0, right: 0,
          child: ValueListenableBuilder<String?>(
            valueListenable: NaverMapStatus.authError,
            builder: (_, err, __) {
              if (err == null) return const SizedBox.shrink();
              return Container(
                color: const Color(0xE6C0392B),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: const Text(
                  '지도를 준비 중이에요 · 아래 목록은 그대로 이용하실 수 있어요',
                  style: TextStyle(color: Colors.white, fontSize: 11, height: 1.3),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
