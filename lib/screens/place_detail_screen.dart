import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import '../models/place_model.dart';
import '../services/google_places_service.dart';
import '../services/naver_review_service.dart';
import '../services/gemini_service.dart';
import '../services/cache_service.dart';
import '../services/bookmark_service.dart';
import '../services/supabase_course_service.dart';
import '../utils/app_theme.dart';
import 'course_result_screen.dart';
import 'map_screen.dart';

// ─────────────────────────────────────────────
// ODD 장소 상세 화면
// 탭: 홈 / 사진 / 리뷰 / 코스 추천 / 매장정보
// ─────────────────────────────────────────────

class PlaceDetailScreen extends StatefulWidget {
  final Place place;

  const PlaceDetailScreen({super.key, required this.place});

  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen>
    with SingleTickerProviderStateMixin {
  static const _tabs = ['홈', '사진', '리뷰', '코스 추천', '매장정보'];

  late final TabController _tabController;

  PlaceDetail? _detail;
  bool _loadingDetail = true;
  bool _loadingExtra = false;
  int _photoPage = 0;
  bool _isBookmarked = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _fetchAll();
    BookmarkService.isBookmarked(widget.place.id)
        .then((v) => mounted ? setState(() => _isBookmarked = v) : null);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── 순차 로딩: 사진/시간 먼저 → 리뷰/설명 나중 ──
  Future<void> _fetchAll() async {
    setState(() => _loadingDetail = true);

    final detail = await GooglePlacesService.fetchDetail(
      placeName: widget.place.name,
      address: widget.place.address,
    );

    if (mounted) {
      setState(() {
        _detail = detail;
        _loadingDetail = false;
        _loadingExtra = true;
      });
    }

    // 리뷰 + AI 설명 병렬 fetch
    final results = await Future.wait([
      NaverReviewService.fetchReviews(widget.place.name),
      GeminiService.generatePlaceDescription(
        placeName: widget.place.name,
        subcategory: widget.place.subcategory,
        address: widget.place.address,
      ).catchError((_) => ''),
    ]);

    if (mounted) {
      setState(() {
        _loadingExtra = false;
        if (_detail != null) {
          _detail = _detail!.copyWith(
            naverReviews: results[0] as List<NaverBlogReview>,
            aiDescription: results[1] as String,
          );
        }
      });
    }
  }

  List<String> get _photos {
    final urls = _detail?.photoUrls ?? [];
    if (urls.isEmpty && widget.place.imageUrl.isNotEmpty) {
      return [widget.place.imageUrl];
    }
    return urls;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, innerScrolled) => [
          _buildSliverAppBar(),
          SliverToBoxAdapter(child: _buildBasicInfo()),
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyTabBarDelegate(
              TabBar(
                controller: _tabController,
                tabs: _tabs.map((t) => Tab(text: t)).toList(),
                labelColor: AppTheme.primary,
                unselectedLabelColor: Colors.grey,
                indicatorColor: AppTheme.primary,
                indicatorWeight: 2,
                labelStyle: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600),
                isScrollable: true,
                tabAlignment: TabAlignment.start,
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _HomeTab(
                place: widget.place,
                detail: _detail,
                loading: _loadingDetail || _loadingExtra,
                onCourseTabTap: () => _tabController.animateTo(3),
                onReviewTabTap: () => _tabController.animateTo(2)),
            _PhotoTab(photos: _photos, loading: _loadingDetail),
            _ReviewTab(
              googleReviews: _detail?.googleReviews ?? [],
              naverReviews: _detail?.naverReviews ?? [],
              loading: _loadingDetail || _loadingExtra,
            ),
            _CourseTab(place: widget.place),
            _InfoTab(
                place: widget.place,
                detail: _detail,
                loading: _loadingDetail),
          ],
        ),
      ),
    );
  }

  SliverAppBar _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12, top: 8, bottom: 8),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: _heroButton(Icons.arrow_back_ios_new_rounded),
        ),
      ),
      actions: [
        _heroButton(
          _isBookmarked
              ? Icons.bookmark_rounded
              : Icons.bookmark_border_rounded,
          _toggleBookmark,
        ),
        _heroButton(Icons.ios_share_rounded),
        const SizedBox(width: 4),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // 이미지
            _loadingDetail
                ? Shimmer.fromColors(
                    baseColor: Colors.grey[400]!,
                    highlightColor: Colors.grey[300]!,
                    child: Container(color: Colors.white),
                  )
                : _photos.isEmpty
                    ? _placeholderImage()
                    : PageView.builder(
                        itemCount: _photos.length,
                        onPageChanged: (i) =>
                            setState(() => _photoPage = i),
                        itemBuilder: (_, i) => CachedNetworkImage(
                          imageUrl: _photos[i],
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              _placeholderImage(),
                        ),
                      ),
            // 하단 그라디언트 오버레이 (IgnorePointer — PageView 스와이프 통과)
            const Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Color(0xAA000000)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.45, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            // 페이지 인디케이터
            if (!_loadingDetail && _photos.length > 1)
              Positioned(
                bottom: 50, left: 0, right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _photos.length.clamp(0, 8),
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin:
                          const EdgeInsets.symmetric(horizontal: 3),
                      width: _photoPage == i ? 16 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _photoPage == i
                            ? Colors.white
                            : Colors.white54,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleBookmark() async {
    final saved = await BookmarkService.toggle(widget.place);
    if (mounted) {
      setState(() => _isBookmarked = saved);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(saved ? '찜 목록에 저장했어요 💜' : '찜 목록에서 제거했어요'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  /// 히어로 영역 플로팅 원형 버튼
  Widget _heroButton(IconData icon, [VoidCallback? onTap]) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.35),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: Colors.white),
      ),
    );
  }

  Widget _buildBasicInfo() {
    final isOpen = _detail?.isOpenNow;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 이름 + 찜 ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  widget.place.name,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold,
                      color: AppTheme.textDark, height: 1.2),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _toggleBookmark,
                child: Column(
                  children: [
                    Icon(
                      _isBookmarked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: _isBookmarked
                          ? AppTheme.primary
                          : AppTheme.textMid,
                      size: 22,
                    ),
                    const SizedBox(height: 2),
                    Text('찜',
                        style: TextStyle(
                            fontSize: 10,
                            color: _isBookmarked
                                ? AppTheme.primary
                                : AppTheme.textMid)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // ── 카테고리 · 지역 ──
          Text(
            _categoryLocation(),
            style: const TextStyle(fontSize: 13, color: AppTheme.textMid),
          ),
          const SizedBox(height: 10),
          // ── 별점 ──
          if (!_loadingDetail && _detail != null && _detail!.googleRating > 0) ...[
            Row(
              children: [
                ...List.generate(
                  5,
                  (i) => Icon(
                    i < _detail!.googleRating.round()
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: const Color(0xFFFFB800), size: 18,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _detail!.googleRating.toStringAsFixed(1),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: AppTheme.textDark),
                ),
                Text(
                  ' (${_detail!.reviewCount}개 리뷰)',
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textMid),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ] else
            const SizedBox(height: 4),
          // ── 정보 칩 ──
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _infoChip(Icons.location_on_outlined, _shortAddress()),
              if (_detail?.todayHours.isNotEmpty == true)
                _infoChip(Icons.access_time_rounded, _detail!.todayHours),
              if (isOpen != null) _statusChip(isOpen),
              if (widget.place.tags.any((t) => t.contains('예약')))
                _infoChip(Icons.phone_outlined, '예약 필수'),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.textMid),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textDark,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _statusChip(bool isOpen) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isOpen
            ? const Color(0xFFE8F5E9)
            : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isOpen ? '영업 중' : '영업 종료',
        style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isOpen
                ? const Color(0xFF2E7D32)
                : const Color(0xFFC62828)),
      ),
    );
  }

  String _categoryLocation() {
    final parts = <String>[];
    if (widget.place.subcategory.isNotEmpty) {
      parts.add(widget.place.subcategory);
    } else if (widget.place.category.isNotEmpty) {
      parts.add(widget.place.category);
    }
    final addr = widget.place.address.split(' ');
    if (addr.length >= 3) {
      parts.add(addr[2]);
    } else if (addr.length >= 2) {
      parts.add(addr[1]);
    }
    return parts.join(' · ');
  }

  String _shortAddress() {
    final parts = widget.place.address.split(' ');
    return parts.take(3).join(' ');
  }

  Widget _placeholderImage() => Container(
        color: Colors.grey[200],
        child: const Center(
          child: Icon(Icons.image_not_supported_outlined,
              size: 48, color: Colors.grey),
        ),
      );
}

// ─────────────────────────────────────────────
// 탭 1: 홈
// ─────────────────────────────────────────────

class _HomeTab extends StatelessWidget {
  final Place place;
  final PlaceDetail? detail;
  final bool loading;
  final VoidCallback? onCourseTabTap;
  final VoidCallback? onReviewTabTap;

  const _HomeTab({
    required this.place,
    required this.detail,
    required this.loading,
    this.onCourseTabTap,
    this.onReviewTabTap,
  });

  @override
  Widget build(BuildContext context) {
    final reviews = detail?.googleReviews ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 위치 미니 지도 (지도앱 스타일 상단 지도) ──
          if (_validCoord(place)) ...[
            _label('위치'),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 160,
                child: Stack(
                  children: [
                    Positioned.fill(child: _PlaceMiniMap(place: place)),
                    Positioned.fill(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MapScreen(
                                  places: [place], courseTitle: place.name),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.92),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('지도 크게 보기',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primary)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ── 소개 ──
          _label('소개'),
          const SizedBox(height: 10),
          if (loading)
            _shimmerBox(double.infinity, 88)
          else if (detail?.aiDescription.isNotEmpty == true)
            Text(
              detail!.aiDescription,
              style: const TextStyle(
                  fontSize: 14, color: AppTheme.textDark, height: 1.7),
            )
          else
            Text(_fallbackIntro(),
                style: const TextStyle(
                    fontSize: 14, color: AppTheme.textDark, height: 1.7)),
          const SizedBox(height: 24),

          // ── 리뷰 ──
          Row(
            children: [
              _label('리뷰'),
              const Spacer(),
              if (onReviewTabTap != null)
                GestureDetector(
                  onTap: onReviewTabTap,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('전체',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600)),
                      Icon(Icons.chevron_right_rounded,
                          size: 16, color: AppTheme.primary),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (loading) ...[
            _shimmerBox(double.infinity, 80),
            const SizedBox(height: 8),
            _shimmerBox(double.infinity, 80),
          ] else if (reviews.isNotEmpty)
            ...reviews
                .take(3)
                .map((r) => _GoogleReviewCard(review: r))
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('아직 리뷰가 없어요',
                  style: TextStyle(fontSize: 14, color: Colors.grey[400])),
            ),
          const SizedBox(height: 24),

          // ── 코스 추천 단축 버튼 ──
          if (onCourseTabTap != null) ...[
            GestureDetector(
              onTap: onCourseTabTap,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: AppTheme.primary.withOpacity(0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome, size: 16, color: Colors.white),
                    SizedBox(width: 8),
                    Text('이 장소로 코스 짜기',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  bool _validCoord(Place p) =>
      p.lat >= 33.0 && p.lat <= 39.5 && p.lng >= 124.0 && p.lng <= 132.0;

  String _districtOf(String address) {
    for (final t in address.split(' ')) {
      if (t.endsWith('구') || t.endsWith('군') || t.endsWith('시')) return t;
    }
    return '';
  }

  /// Gemini 소개가 없을 때 — 실제 장소 데이터로 정직한 소개 구성(지어내지 않음)
  String _fallbackIntro() {
    if (place.description.isNotEmpty) return place.description;
    final cat = place.subcategory.isNotEmpty ? place.subcategory : place.category;
    final loc = _districtOf(place.address);
    final buf = StringBuffer(place.name);
    if (loc.isNotEmpty || cat.isNotEmpty) {
      buf.write('은(는) ');
      if (loc.isNotEmpty) buf.write('$loc ');
      if (cat.isNotEmpty) buf.write(cat);
      buf.write(' 입니다.');
    } else {
      buf.write(' 정보를 준비 중이에요.');
    }
    if (place.rating > 0) {
      buf.write(' 이용자 평점 ${place.rating.toStringAsFixed(1)}점');
      if (place.reviewCount > 0) buf.write(' · 리뷰 ${place.reviewCount}개');
      buf.write('.');
    }
    if (place.aiReason.isNotEmpty) buf.write('\n\n${place.aiReason}');
    return buf.toString();
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1A1A1A)));

  Widget _shimmerBox(double w, double h) => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          width: w,
          height: h,
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8)),
        ),
      );
}

// ─────────────────────────────────────────────
// 탭 2: 사진
// ─────────────────────────────────────────────

class _PhotoTab extends StatelessWidget {
  final List<String> photos;
  final bool loading;

  const _PhotoTab({required this.photos, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return GridView.builder(
        padding: const EdgeInsets.all(2),
        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2),
        itemCount: 9,
        itemBuilder: (_, __) => Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(color: Colors.white),
        ),
      );
    }

    if (photos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library_outlined,
                size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text('등록된 사진이 없어요',
                style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
      itemCount: photos.length,
      itemBuilder: (ctx, i) => GestureDetector(
        onTap: () => Navigator.push(
          ctx,
          MaterialPageRoute(
            builder: (_) => _FullscreenViewer(
                photos: photos, initialIndex: i),
          ),
        ),
        child: CachedNetworkImage(
          imageUrl: photos[i],
          fit: BoxFit.cover,
          placeholder: (_, __) => Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(color: Colors.white),
          ),
          errorWidget: (_, __, ___) => Container(
            color: Colors.grey[200],
            child: const Icon(Icons.broken_image_outlined,
                color: Colors.grey),
          ),
        ),
      ),
    );
  }
}

class _FullscreenViewer extends StatefulWidget {
  final List<String> photos;
  final int initialIndex;

  const _FullscreenViewer(
      {required this.photos, required this.initialIndex});

  @override
  State<_FullscreenViewer> createState() => _FullscreenViewerState();
}

class _FullscreenViewerState extends State<_FullscreenViewer> {
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_current + 1} / ${widget.photos.length}',
            style: const TextStyle(color: Colors.white)),
      ),
      body: PageView.builder(
        controller: PageController(initialPage: widget.initialIndex),
        itemCount: widget.photos.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (_, i) => InteractiveViewer(
          child: Center(
            child: CachedNetworkImage(
              imageUrl: widget.photos[i],
              fit: BoxFit.contain,
              placeholder: (_, __) => const CircularProgressIndicator(
                  color: Colors.white),
              errorWidget: (_, __, ___) => const Icon(
                  Icons.broken_image,
                  color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 탭 3: 리뷰
// ─────────────────────────────────────────────

class _ReviewTab extends StatelessWidget {
  final List<GoogleReview> googleReviews;
  final List<NaverBlogReview> naverReviews;
  final bool loading;

  const _ReviewTab({
    required this.googleReviews,
    required this.naverReviews,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 3,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
                height: 100,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10))),
          ),
        ),
      );
    }

    final hasAny = googleReviews.isNotEmpty || naverReviews.isNotEmpty;
    if (!hasAny) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.rate_review_outlined,
                size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text('아직 리뷰가 없어요',
                style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (googleReviews.isNotEmpty) ...[
          _sectionHeader('구글 리뷰', 'Google'),
          const SizedBox(height: 8),
          ...googleReviews.map((r) => _GoogleReviewCard(review: r)),
          const SizedBox(height: 20),
        ],
        if (naverReviews.isNotEmpty) ...[
          _sectionHeader('블로그 후기', 'NAVER'),
          const SizedBox(height: 8),
          ...naverReviews.map((r) => _NaverBlogCard(review: r)),
        ],
      ],
    );
  }

  Widget _sectionHeader(String title, String source) => Row(
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: source == 'Google'
                  ? const Color(0xFFE3F2FD)
                  : const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              source,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: source == 'Google'
                      ? const Color(0xFF1565C0)
                      : const Color(0xFF1B5E20)),
            ),
          ),
        ],
      );
}

class _GoogleReviewCard extends StatelessWidget {
  final GoogleReview review;

  const _GoogleReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.primary,
                child: Text(
                  review.authorName.isNotEmpty
                      ? review.authorName[0]
                      : '?',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review.authorName,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    Text(review.relativeTime,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[500])),
                  ],
                ),
              ),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < review.rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: const Color(0xFFFFB800),
                    size: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(review.text,
              style: const TextStyle(fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }
}

class _NaverBlogCard extends StatefulWidget {
  final NaverBlogReview review;

  const _NaverBlogCard({required this.review});

  @override
  State<_NaverBlogCard> createState() => _NaverBlogCardState();
}

class _NaverBlogCardState extends State<_NaverBlogCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                      color: const Color(0xFF03C75A),
                      borderRadius: BorderRadius.circular(6)),
                  child: const Center(
                    child: Text('N',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.review.bloggerName,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      Text(widget.review.postDate,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[500])),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () =>
                      setState(() => _expanded = !_expanded),
                  child: Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Text(
              widget.review.title,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          AnimatedCrossFade(
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Text(
                widget.review.description,
                style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: Colors.grey[700]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Text(
                widget.review.description,
                style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: Colors.grey[700]),
              ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
            child: GestureDetector(
              onTap: () {
                if (widget.review.link.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _BlogWebViewScreen(
                        url: widget.review.link,
                        title: widget.review.bloggerName,
                      ),
                    ),
                  );
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '앱에서 원문 보기',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF03C75A),
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      decorationColor: Color(0xFF03C75A),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.article_outlined,
                      size: 12, color: Color(0xFF03C75A)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 탭 5: 매장정보
// ─────────────────────────────────────────────

class _InfoTab extends StatelessWidget {
  final Place place;
  final PlaceDetail? detail;
  final bool loading;

  const _InfoTab(
      {required this.place,
      required this.detail,
      required this.loading});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow(
            icon: Icons.location_on_outlined,
            label: '주소',
            value: place.address.isNotEmpty ? place.address : '정보 없음',
          ),
          const SizedBox(height: 16),

          if (loading)
            _shimmerRow()
          else
            _infoRow(
              icon: Icons.phone_outlined,
              label: '전화번호',
              value: detail?.nationalPhone.isNotEmpty == true
                  ? detail!.nationalPhone
                  : place.phone.isNotEmpty
                      ? place.phone
                      : '정보 없음',
              onTap: () {
                final phone = detail?.nationalPhone ?? place.phone;
                if (phone.isNotEmpty) {
                  launchUrl(Uri.parse('tel:$phone'));
                }
              },
            ),
          const SizedBox(height: 16),

          _label('영업시간'),
          const SizedBox(height: 8),
          if (loading)
            ...List.generate(
                7,
                (_) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _shimmerRow()))
          else if (detail?.weekdayDescriptions.isNotEmpty == true)
            ...detail!.weekdayDescriptions.map((line) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(line,
                      style:
                          const TextStyle(fontSize: 13, height: 1.4)),
                ))
          else
            Text(
              place.openHours.isNotEmpty
                  ? place.openHours
                  : '영업시간 정보 없음',
              style: const TextStyle(fontSize: 13),
            ),
          const SizedBox(height: 16),

          if (!loading && detail?.website.isNotEmpty == true) ...[
            _infoRow(
              icon: Icons.language_outlined,
              label: '웹사이트',
              value: detail!.website,
              onTap: () => launchUrl(Uri.parse(detail!.website),
                  mode: LaunchMode.externalApplication),
              isLink: true,
            ),
            const SizedBox(height: 16),
          ],

          if (!loading && detail?.priceLevel.isNotEmpty == true)
            _infoRow(
              icon: Icons.attach_money_outlined,
              label: '가격대',
              value: detail!.priceLevel,
            ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1A1A1A)));

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
    bool isLink = false,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[500])),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: isLink
                          ? const Color(0xFF1565C0)
                          : const Color(0xFF1A1A1A),
                      decoration: isLink
                          ? TextDecoration.underline
                          : TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right,
                  size: 18, color: Colors.grey),
          ],
        ),
      );

  Widget _shimmerRow() => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          height: 16,
          width: 200,
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4)),
        ),
      );
}

// ─────────────────────────────────────────────
// 탭 4: 코스 추천 — 이 장소 기반 AI 코스 생성
// ─────────────────────────────────────────────

class _CourseTab extends StatefulWidget {
  final Place place;
  const _CourseTab({required this.place});

  @override
  State<_CourseTab> createState() => _CourseTabState();
}

class _CourseTabState extends State<_CourseTab> {
  bool _loading = false;
  String _loadingMsg = '코스를 불러오는 중...';
  late String _timeSlot;

  @override
  void initState() {
    super.initState();
    _timeSlot = _currentTimeSlot();
  }

  static const _timeSlots = ['오전', '낮', '저녁', '밤'];
  static const _timeSlotEmojis = ['🌅', '☀️', '🌙', '✨'];

  // 3가지 고정 아키타입 — 항상 다른 탭으로 표시됨
  static const _archetypes = [
    {'mood': '감성', 'label': '감성 로맨스', 'concept': '💕 감성 로맨스'},
    {'mood': '액티비티', 'label': '액티비티', 'concept': '🎯 액티비티 챌린지'},
    {'mood': '힐링', 'label': '로컬 힐링', 'concept': '🌿 로컬 힐링'},
  ];

  /// DB 검색 전용 — 이 장소를 포함한 서로 다른 아키타입 검증 코스 (생성 금지)
  Future<void> _generateCourse() async {
    setState(() {
      _loading = true;
      _loadingMsg = '검증된 코스를 불러오는 중...';
    });

    try {
      final city = _extractCity(widget.place.address);
      final timeSlot = _timeSlot;

      // 3개 아키타입(감성·액티비티·힐링) DB 병렬 조회
      final dbResults = await Future.wait(
        _archetypes.map((a) => SupabaseCourseService.fetchCourses(
          city: city,
          mood: a['mood']!,
          timeSlot: timeSlot,
          limit: 5,
        )),
      );
      if (!mounted) return;

      // 있는 아키타입만 1개씩 — 서로 다른 컨셉으로(모두 감성 방지) + 선택 장소 주입
      final courses = <DateCourse>[
        for (final r in dbResults)
          if (r.isNotEmpty) _injectSelectedPlace(r.first),
      ];

      // 생성하지 않고 정직하게 안내
      if (courses.isEmpty) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$city에는 아직 이 장소로 묶을 검증 코스가 충분하지 않아요.')),
        );
        return;
      }

      setState(() => _loadingMsg = '사진을 불러오는 중...');
      final enriched = await _enrichCoursePhotos(courses);
      for (final c in enriched) {
        await CacheService.addToHistory(c.toJson());
      }
      setState(() => _loading = false);
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => CourseResultScreen(
          courses: enriched, mood: '혼합', specialDay: '일상', timeSlot: timeSlot,
        ),
      ));
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('오류가 발생했어요. 다시 시도해주세요.')),
        );
      }
    }
  }

  /// 선택 장소를 카테고리에 맞는 슬롯에 주입 — 카페→시작, 맛집→마무리, 그 외→중간.
  /// PEAK 고정 주입은 카페를 체험 자리에 넣어 어색했던 문제를 해결한다.
  DateCourse _injectSelectedPlace(DateCourse c) {
    final places = List<Place>.from(c.places);
    if (places.isEmpty) {
      places.add(widget.place);
    } else {
      final cat = '${widget.place.category}${widget.place.subcategory}';
      int slot;
      if (cat.contains('카페') || cat.contains('브런치') ||
          cat.contains('베이커리') || cat.contains('디저트')) {
        slot = 0;
      } else if (cat.contains('맛집') || cat.contains('레스토랑') ||
          cat.contains('한식') || cat.contains('양식') || cat.contains('일식')) {
        slot = places.length - 1;
      } else {
        slot = places.length >= 2 ? 1 : 0;
      }
      places[slot.clamp(0, places.length - 1)] = widget.place;
    }
    return DateCourse(
      title: c.title,
      concept: c.concept,
      mood: c.mood,
      description: c.description,
      places: places,
      totalDuration: c.totalDuration,
      savedAt: c.savedAt,
    );
  }

  String _extractCity(String address) {
    // "대한민국 대전광역시 서구..." 처럼 국가명이 앞에 오는 경우가 있어 제외
    final parts = address
        .split(' ')
        .where((p) => p.isNotEmpty && p != '대한민국')
        .toList();
    if (parts.isEmpty) return '서울';
    return parts[0]
        .replaceAll('특별시', '')
        .replaceAll('광역시', '')
        .replaceAll('특별자치시', '')
        .replaceAll('특별자치도', '')
        .replaceAll('도', '');
  }

  /// Google Places 사진 + 평점 + 리뷰 수 일괄 enrichment
  Future<List<DateCourse>> _enrichCoursePhotos(List<DateCourse> courses) async {
    final allPlaces = courses.expand((c) => c.places).toList();
    final results = await Future.wait(
      allPlaces.map((p) => GooglePlacesService.fetchPlaceEnrichment(p.name, p.address)),
    );
    final enrichMap = <String, Map<String, dynamic>>{};
    for (var i = 0; i < allPlaces.length; i++) {
      if (results[i].isNotEmpty) enrichMap[allPlaces[i].id] = results[i];
    }
    return courses.map((course) {
      final enriched = course.places.map((p) {
        final e = enrichMap[p.id];
        if (e == null) return p;
        return p.copyWith(
          imageUrl:    e['imageUrl']    as String?,
          rating:      e['rating']      as double?,
          reviewCount: e['reviewCount'] as int?,
        );
      }).toList();
      return DateCourse(
        title:         course.title,
        concept:       course.concept,
        mood:          course.mood,
        description:   course.description,
        places:        enriched,
        totalDuration: course.totalDuration,
      );
    }).toList();
  }

  String _currentTimeSlot() {
    final h = DateTime.now().hour;
    if (h < 12) return '오전';
    if (h < 17) return '낮';
    if (h < 21) return '저녁';
    return '밤';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 헤더 ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('✨', style: TextStyle(fontSize: 28)),
                const SizedBox(height: 8),
                Text(
                  widget.place.name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                const Text(
                  '이 장소를 포함한 데이트 코스를\nAI가 3가지 컨셉으로 추천해드릴게요',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.5),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── 3가지 코스 아키타입 프리뷰 ──
          const Text('추천 코스 타입',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF757575))),
          const SizedBox(height: 10),
          Row(
            children: [
              _archetypeChip('💕', '감성 로맨스', const Color(0xFFFCE4EC), const Color(0xFFE91E63)),
              const SizedBox(width: 6),
              _archetypeChip('🎯', '액티비티', const Color(0xFFE3F2FD), const Color(0xFF1565C0)),
              const SizedBox(width: 6),
              _archetypeChip('🌿', '로컬 힐링', const Color(0xFFE8F5E9), const Color(0xFF2E7D32)),
            ],
          ),

          const SizedBox(height: 16),

          // ── 시간대 선택 ──
          const Text('시간대',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF757575))),
          const SizedBox(height: 8),
          Row(
            children: List.generate(_timeSlots.length, (i) {
              final slot = _timeSlots[i];
              final emoji = _timeSlotEmojis[i];
              final selected = _timeSlot == slot;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _timeSlot = slot),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.primary.withOpacity(0.10)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? AppTheme.primary
                            : Colors.grey[300]!,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(emoji,
                            style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 3),
                        Text(slot,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? AppTheme.primary
                                  : Colors.grey[600],
                            )),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 24),

          // ── 코스 흐름 미리보기 ──
          const Text('코스 구성',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A))),
          const SizedBox(height: 12),
          Row(
            children: [
              _slotChip('☕', '카페·브런치', const Color(0xFFFFF3E0), const Color(0xFFE65100)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.arrow_forward_ios, size: 10, color: Colors.grey),
              ),
              _slotChip('⭐', widget.place.name.length > 7 ? '${widget.place.name.substring(0, 6)}…' : widget.place.name,
                  const Color(0xFFEEF0F8), AppTheme.primary),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.arrow_forward_ios, size: 10, color: Colors.grey),
              ),
              _slotChip('🍽️', '저녁 맛집', const Color(0xFFE8F5E9), const Color(0xFF2E7D32)),
            ],
          ),

          const SizedBox(height: 28),

          // ── 안내 텍스트 ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 16, color: Color(0xFF9E9E9E)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'DB에 등록된 검증된 코스를 먼저 추천해드려요.\n감성 로맨스·액티비티·로컬 힐링\n3가지 코스를 한 번에 비교해보세요.',
                    style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF757575),
                        height: 1.6),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ── CTA 버튼 ──
          SizedBox(
            width: double.infinity,
            child: _loading
                ? Container(
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(AppTheme.primary)),
                        ),
                        const SizedBox(width: 12),
                        Text(_loadingMsg,
                            style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF757575),
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  )
                : GestureDetector(
                    onTap: _generateCourse,
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                              color: AppTheme.primary.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4)),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          '✨ 3가지 코스 추천받기',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _slotChip(String emoji, String label, Color bg, Color fg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 10,
                    color: fg,
                    fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _archetypeChip(String emoji, String label, Color bg, Color fg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: fg.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 3),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 10,
                    color: fg,
                    fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 인앱 WebView 화면 — 네이버 블로그 원문 보기
// ─────────────────────────────────────────────

class _BlogWebViewScreen extends StatefulWidget {
  final String url;
  final String title;

  const _BlogWebViewScreen({required this.url, required this.title});

  @override
  State<_BlogWebViewScreen> createState() => _BlogWebViewScreenState();
}

class _BlogWebViewScreenState extends State<_BlogWebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 13; SM-G973N) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/120.0.0.0 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) => setState(() => _progress = p / 100.0),
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: (_) => setState(() => _loading = false),
        onWebResourceError: (_) => setState(() => _loading = false),
        onNavigationRequest: (req) {
          final url = req.url;
          // 네이버 로그인 페이지로 리다이렉트 감지 → PC 버전으로 전환
          if (url.contains('nid.naver.com') ||
              url.contains('/login') ||
              (url.contains('naver.com') && url.contains('loginType'))) {
            final pcUrl = _toPcUrl(widget.url);
            if (pcUrl != widget.url) {
              _controller.loadRequest(Uri.parse(pcUrl));
              return NavigationDecision.prevent;
            }
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  /// m.blog.naver.com → blog.naver.com (PC 버전)
  String _toPcUrl(String url) =>
      url.replaceFirst('m.blog.naver.com', 'blog.naver.com')
         .replaceFirst('://m.', '://');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          // PC 버전 전환 (로그인 벽 우회)
          IconButton(
            icon: const Icon(Icons.computer_outlined, size: 20),
            onPressed: () {
              final pcUrl = _toPcUrl(widget.url);
              _controller.loadRequest(Uri.parse(pcUrl));
            },
            tooltip: 'PC 버전으로 보기',
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser, size: 20),
            onPressed: () async {
              final uri = Uri.tryParse(widget.url);
              if (uri != null) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            tooltip: '브라우저에서 열기',
          ),
        ],
        bottom: _loading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF03C75A)),
                ),
              )
            : null,
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}

// ─────────────────────────────────────────────
// 장소 위치 미니 지도 (네이티브 네이버 지도, 단일 핀 · 제스처 잠금)
// ─────────────────────────────────────────────
class _PlaceMiniMap extends StatelessWidget {
  final Place place;
  const _PlaceMiniMap({required this.place});

  @override
  Widget build(BuildContext context) {
    final pos = NLatLng(place.lat, place.lng);
    return NaverMap(
      options: NaverMapViewOptions(
        initialCameraPosition: NCameraPosition(target: pos, zoom: 15),
        mapType: NMapType.basic,
        scrollGesturesEnable: false,
        zoomGesturesEnable: false,
        tiltGesturesEnable: false,
        rotationGesturesEnable: false,
        stopGesturesEnable: false,
      ),
      onMapReady: (controller) {
        controller.addOverlay(NMarker(id: 'place', position: pos));
      },
    );
  }
}

// ─────────────────────────────────────────────
// SliverPersistentHeader — 탭바 고정
// ─────────────────────────────────────────────

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  const _StickyTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
          BuildContext ctx, double shrinkOffset, bool overlapsContent) =>
      Container(color: Colors.white, child: tabBar);

  @override
  bool shouldRebuild(_StickyTabBarDelegate old) =>
      tabBar != old.tabBar;
}
