import 'package:flutter/material.dart';
import '../models/place_model.dart';
import '../utils/app_theme.dart';
import '../services/location_service.dart';
import '../services/naver_place_service.dart';
import '../services/google_places_service.dart';
import '../services/cultural_event_service.dart';
import 'home_screen.dart';
import 'chat_screen.dart';
import 'explore_screen.dart';
import 'my_course_screen.dart';
import 'my_screen.dart';

// ─────────────────────────────────────────────
// ODD 하단 네비게이션 — 5탭
// ─────────────────────────────────────────────

class MainNav extends StatefulWidget {
  final LocationResult location;
  final Map<String, List<Place>> initialPlaces;

  const MainNav({
    super.key,
    required this.location,
    required this.initialPlaces,
  });

  @override
  State<MainNav> createState() => _MainNavState();
}

class _MainNavState extends State<MainNav> {
  int _index = 0;
  String _initialExploreCategory = '전체';
  bool _initialExploreOpenNow = false;

  // 현재 선택된 지역 (기본값: GPS 위치)
  late String _currentRegion;
  late Map<String, List<Place>> _places;
  bool _loadingPlaces = false;

  // 문화포털 이벤트
  List<CulturalEvent> _culturalEvents = [];

  @override
  void initState() {
    super.initState();
    _currentRegion = widget.location.fullRegion;
    _places = Map.from(widget.initialPlaces);
    _enrichPhotosParallel(_places);
    _loadCulturalEvents(_currentRegion);
  }

  // ── 문화 이벤트 로딩 ──
  Future<void> _loadCulturalEvents(String region) async {
    try {
      final events = await CulturalEventService.fetchByArea(
        region: region, rows: 15);
      if (mounted) setState(() => _culturalEvents = events);
    } catch (_) {}
  }

  // ── 병렬 사진 enrichment (6카테고리 전체) ──
  Future<void> _enrichPhotosParallel(Map<String, List<Place>> placesSnapshot) async {
    // 모든 카테고리의 장소를 하나로 합치되 순서·인덱스 기록
    final allPlaces = placesSnapshot.values.expand((list) => list).toList();
    if (allPlaces.isEmpty) return;

    final futures = allPlaces.map(
        (p) => GooglePlacesService.fetchFirstPhotoUrl(p.name, p.address));
    final urls = await Future.wait(futures);

    if (!mounted) return;

    // id → enriched url 맵 생성
    final urlMap = <String, String>{};
    for (var i = 0; i < allPlaces.length; i++) {
      final url = urls[i];
      if (url != null) urlMap[allPlaces[i].id] = url;
    }

    // 카테고리별로 업데이트된 리스트 재구성
    final updated = <String, List<Place>>{};
    for (final entry in placesSnapshot.entries) {
      updated[entry.key] = entry.value.map((p) {
        final url = urlMap[p.id];
        return url != null ? p.copyWith(imageUrl: url) : p;
      }).toList();
    }

    setState(() => _places = updated);
  }

  // ── 지역 변경 콜백 ──
  Future<void> _onRegionChanged(String newRegion) async {
    // 단일 토큰 구/동(예: "서구")일 때만 GPS city 접두.
    // 이미 시 단위를 포함하거나(예: "경주시", "서울 강남구") 공백이 있으면 그대로 사용
    // — 타지역 도시 선택 시 GPS city가 잘못 접두되어 서울로 조회되는 버그 방지.
    final city = widget.location.city;
    final needsCityPrefix = city.isNotEmpty &&
        !newRegion.contains(city) &&
        !newRegion.contains('시') &&
        !newRegion.contains(' ');
    final fullRegion =
        needsCityPrefix ? '$city $newRegion'.trim() : newRegion;

    if (fullRegion == _currentRegion || _loadingPlaces) return;

    setState(() {
      _currentRegion = fullRegion;
      _loadingPlaces = true;
    });

    final newPlaces = await NaverPlaceService.fetchHomeData(fullRegion);
    if (!mounted) return;

    setState(() {
      _places = newPlaces;
      _loadingPlaces = false;
    });

    // 새 지역 사진 + 문화 이벤트도 병렬 로딩
    _enrichPhotosParallel(newPlaces);
    _loadCulturalEvents(fullRegion);
  }

  // ── 현재 지역 장소 강제 새로고침 (홈 pull-to-refresh) ──
  Future<void> _refreshPlaces() async {
    if (_loadingPlaces) return;
    setState(() => _loadingPlaces = true);
    final newPlaces = await NaverPlaceService.fetchHomeData(_currentRegion);
    if (!mounted) return;
    setState(() {
      _places = newPlaces;
      _loadingPlaces = false;
    });
    _enrichPhotosParallel(newPlaces);
    _loadCulturalEvents(_currentRegion);
  }

  void _navigateTo(int tabIndex, {String? category, bool openNow = false}) {
    setState(() {
      _index = tabIndex;
      if (category != null) _initialExploreCategory = category;
      _initialExploreOpenNow = openNow;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 현재 지역으로 오버라이드된 LocationResult 생성.
    // city는 GPS가 아니라 '선택 지역' 기준으로 — GPS city를 쓰면 fullRegion이
    // "서울특별시 경주시"처럼 오염되어, 둘러보기가 선택 지역 대신 GPS 지역을
    // 검색하는 버그가 있었다. _currentRegion의 첫 토큰(시/도)을 city로 사용.
    final regionCity = _currentRegion.split(' ').first.isNotEmpty
        ? _currentRegion.split(' ').first
        : widget.location.city;
    final displayLocation = LocationResult(
      lat: widget.location.lat,
      lng: widget.location.lng,
      district: _currentRegion,
      city: regionCity,
    );

    final screens = [
      HomeScreen(
        location: displayLocation,
        places: _places,
        isLoadingPlaces: _loadingPlaces,
        culturalEvents: _culturalEvents,
        onCategoryTap: (cat) => _navigateTo(1, category: cat),
        onExploreTap: () => _navigateTo(1),
        onAiCourseTap: () => _navigateTo(2),
        onSavedTap: () => _navigateTo(3),
        onRegionChanged: _onRegionChanged,
        gpsDistrict: widget.location.fullRegion,
        onOpenNowTap: () => _navigateTo(1, openNow: true),
        onRefreshPlaces: _refreshPlaces,
      ),
      ExploreScreen(
        key: ValueKey('${_initialExploreCategory}_${_initialExploreOpenNow}'),
        location: displayLocation,
        initialCategory: _initialExploreCategory,
        initialOpenNowOnly: _initialExploreOpenNow,
      ),
      ChatScreen(location: displayLocation),
      const MyCourseScreen(),
      const MyScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: AppTheme.divider)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 58,
            child: Row(
              children: [
                _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded,
                    label: '홈', selected: _index == 0,
                    onTap: () => setState(() => _index = 0)),
                _NavItem(icon: Icons.explore_outlined, activeIcon: Icons.explore_rounded,
                    label: '둘러보기', selected: _index == 1,
                    onTap: () => setState(() => _index = 1)),
                _NavItem(icon: Icons.route_outlined, activeIcon: Icons.route_rounded,
                    label: '코스', selected: _index == 2, dot: true,
                    onTap: () => setState(() => _index = 2)),
                _NavItem(icon: Icons.bookmark_border_rounded, activeIcon: Icons.bookmark_rounded,
                    label: '저장', selected: _index == 3,
                    onTap: () => setState(() => _index = 3)),
                _NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded,
                    label: '나', selected: _index == 4,
                    onTap: () => setState(() => _index = 4)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final bool selected;
  final bool dot;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon, required this.activeIcon,
    required this.label, required this.selected, required this.onTap,
    this.dot = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.primary : AppTheme.textLight;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? activeIcon : icon, size: 23, color: color),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(
              fontSize: 10,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: color,
            )),
            if (dot)
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 4, height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(selected ? 1 : 0.35),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
