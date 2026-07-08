import 'package:flutter/material.dart';
import '../models/place_model.dart';
import '../services/cache_service.dart';
import '../services/bookmark_service.dart';
import '../utils/app_theme.dart';
import 'course_result_screen.dart';
import 'place_detail_screen.dart';

// ─────────────────────────────────────────────
// 저장 화면 — 코스 / 장소 (Warm Natural 리디자인)
// ─────────────────────────────────────────────

class MyCourseScreen extends StatefulWidget {
  const MyCourseScreen({super.key});

  @override
  State<MyCourseScreen> createState() => _MyCourseScreenState();
}

class _MyCourseScreenState extends State<MyCourseScreen>
    with AutomaticKeepAliveClientMixin {
  String _tab = '코스';
  List<DateCourse> _courses = [];
  List<Place> _places = [];
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final raw = await CacheService.getSavedCourses();
    final places = await BookmarkService.getAll();
    if (mounted) {
      setState(() {
        _courses = raw.map(DateCourse.fromJson).toList();
        _places = places;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Text('저장',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark,
                      letterSpacing: -0.3)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _segment('코스'),
                    _segment('장소'),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.primary, strokeWidth: 2.5))
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppTheme.primary,
                      child: _tab == '코스' ? _courseView() : _placeView(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _segment(String label) {
    final selected = _tab == label;
    return GestureDetector(
      onTap: () => setState(() => _tab = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? Colors.white : AppTheme.textMid)),
      ),
    );
  }

  // ── 코스 그리드 ──
  Widget _courseView() {
    if (_courses.isEmpty) {
      return _empty(Icons.route_rounded, '마음에 든 코스를\n저장해 두세요',
          '저장한 코스는 언제든 다시 볼 수 있어요');
    }
    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 0.74,
      children: _courses.map(_courseCard).toList(),
    );
  }

  Widget _courseCard(DateCourse c) {
    final cover = c.places.isNotEmpty ? c.places.first.imageUrl : '';
    final hours = (c.totalDuration / 60).round();
    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => CourseResultScreen(
                  courses: [c],
                  mood: c.mood.isNotEmpty ? c.mood : c.concept))),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Color(0x0A3C2D1E), blurRadius: 10, offset: Offset(0, 3)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _netImage(cover, h: 110, emoji: '💕'),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textDark,
                          height: 1.4)),
                  const SizedBox(height: 5),
                  Text(
                    c.places.map((p) => p.name).take(3).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMid),
                  ),
                  const SizedBox(height: 4),
                  Text('⏱ ${hours > 0 ? '$hours시간' : '반나절'}',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textLight)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 장소 그리드 ──
  Widget _placeView() {
    if (_places.isEmpty) {
      return _empty(Icons.bookmark_rounded, '마음에 든 장소를\n저장해 두세요',
          '장소 상세에서 북마크하면 여기 모여요');
    }
    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 0.74,
      children: _places.map(_placeCard).toList(),
    );
  }

  Widget _placeCard(Place p) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => PlaceDetailScreen(place: p))),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Color(0x0A3C2D1E), blurRadius: 10, offset: Offset(0, 3)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _netImage(p.imageUrl, h: 110, emoji: '☕'),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textDark)),
                  const SizedBox(height: 4),
                  Text(
                    p.subcategory.isNotEmpty ? p.subcategory : p.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMid),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 12, color: Color(0xFFE8A844)),
                      const SizedBox(width: 3),
                      Text(p.rating > 0 ? p.rating.toStringAsFixed(1) : '–',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textDark)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _netImage(String url, {double? h, String emoji = '📷'}) {
    Widget ph() => Container(
          height: h,
          width: double.infinity,
          color: AppTheme.tintCafe,
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
        );
    if (url.isEmpty) return ph();
    return Image.network(url,
        height: h,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => ph());
  }

  Widget _empty(IconData icon, String title, String sub) {
    return ListView(
      // ListView so RefreshIndicator works even when empty
      children: [
        const SizedBox(height: 80),
        Center(
          child: Column(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                    color: AppTheme.tintCafe, shape: BoxShape.circle),
                child: Icon(icon, size: 44, color: AppTheme.primary),
              ),
              const SizedBox(height: 20),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark,
                      height: 1.5)),
              const SizedBox(height: 8),
              Text(sub,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textMid, height: 1.6)),
            ],
          ),
        ),
      ],
    );
  }
}
