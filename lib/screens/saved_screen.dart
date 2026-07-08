import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../models/place_model.dart';
import '../services/cache_service.dart';
import '../services/supabase_saved_service.dart';
import '../services/supabase_service.dart';
import '../utils/app_theme.dart';
import 'course_result_screen.dart';

// ─────────────────────────────────────────────
// 저장 화면 — 저장한 데이트 코스 목록
// ─────────────────────────────────────────────

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<DateCourse> _courses = [];
  List<DateCourse> _partnerCourses = [];
  bool _loading = true;
  bool _partnerLoading = false;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _isLoggedIn = SupabaseService.isLoggedIn;
    _tab = TabController(length: _isLoggedIn ? 2 : 1, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    List<Map<String, dynamic>> raw;
    if (SupabaseService.isLoggedIn) {
      raw = await SupabaseSavedService.getSavedCourses();
      if (raw.isEmpty) {
        final local = await CacheService.getSavedCourses();
        if (local.isNotEmpty) {
          await SupabaseSavedService.migrateLocalToDb(local);
          raw = await SupabaseSavedService.getSavedCourses();
        }
      }
    } else {
      raw = await CacheService.getSavedCourses();
    }
    if (mounted) {
      setState(() { _courses = raw.map(DateCourse.fromJson).toList(); _loading = false; });
    }
    if (_isLoggedIn) _loadPartner();
  }

  Future<void> _loadPartner() async {
    if (!_isLoggedIn) return;
    setState(() => _partnerLoading = true);
    final raw = await SupabaseSavedService.getPartnerCourses();
    if (mounted) {
      setState(() {
        _partnerCourses = raw.map(DateCourse.fromJson).toList();
        _partnerLoading = false;
      });
    }
  }

  Future<void> _delete(String title) async {
    await CacheService.removeCourse(title);
    await SupabaseSavedService.removeCourse(title);
    setState(() => _courses.removeWhere((c) => c.title == title));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('코스를 삭제했어요'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('저장한 코스',
            style: TextStyle(fontSize: 20,
                fontWeight: FontWeight.w900, color: AppTheme.textDark)),
        actions: [
          if (_tab.index == 0 && _courses.isNotEmpty)
            TextButton(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    title: const Text('전체 삭제',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    content: const Text('저장된 코스를 모두 삭제할까요?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false),
                          child: const Text('취소')),
                      TextButton(onPressed: () => Navigator.pop(context, true),
                          child: const Text('삭제',
                              style: TextStyle(color: AppTheme.primary))),
                    ],
                  ),
                );
                if (ok == true) {
                  for (final c in [..._courses]) {
                    await CacheService.removeCourse(c.title);
                    await SupabaseSavedService.removeCourse(c.title);
                  }
                  setState(() => _courses = []);
                }
              },
              child: const Text('전체삭제',
                  style: TextStyle(fontSize: 13,
                      color: AppTheme.textMid, fontWeight: FontWeight.w600)),
            ),
        ],
        bottom: _isLoggedIn
            ? TabBar(
                controller: _tab,
                onTap: (_) => setState(() {}),
                labelColor: AppTheme.primary,
                unselectedLabelColor: AppTheme.textMid,
                indicatorColor: AppTheme.primary,
                indicatorWeight: 2.5,
                labelStyle: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700),
                tabs: const [
                  Tab(text: '내 코스'),
                  Tab(text: '파트너 코스'),
                ],
              )
            : null,
      ),
      body: _isLoggedIn
          ? TabBarView(
              controller: _tab,
              children: [
                _buildMyCoursesTab(),
                _buildPartnerTab(),
              ],
            )
          : _buildMyCoursesTab(),
    );
  }

  Widget _buildMyCoursesTab() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(
          color: AppTheme.primary, strokeWidth: 2.5));
    }
    if (_courses.isEmpty) return _buildEmpty('저장한 코스가 없어요', '마음에 드는 코스를 저장해두세요');
    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _courses.length,
        itemBuilder: (_, i) => _CourseCard(
          course: _courses[i],
          onTap: () => Navigator.push(context,
              MaterialPageRoute(
                  builder: (_) => CourseResultScreen(
                    courses: [_courses[i]],
                    mood: _courses[i].mood,
                  ))),
          onDelete: () => _delete(_courses[i].title),
        ),
      ),
    );
  }

  Widget _buildPartnerTab() {
    if (_partnerLoading) {
      return const Center(child: CircularProgressIndicator(
          color: AppTheme.primary, strokeWidth: 2.5));
    }
    if (_partnerCourses.isEmpty) {
      return _buildEmpty('파트너가 저장한 코스가 없어요', '파트너와 커플 연동 후 함께 코스를 모아보세요');
    }
    return RefreshIndicator(
      onRefresh: _loadPartner,
      color: AppTheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _partnerCourses.length,
        itemBuilder: (_, i) => _CourseCard(
          course: _partnerCourses[i],
          onTap: () => Navigator.push(context,
              MaterialPageRoute(
                  builder: (_) => CourseResultScreen(
                    courses: [_partnerCourses[i]],
                    mood: _partnerCourses[i].mood,
                  ))),
          readOnly: true,
        ),
      ),
    );
  }

  Widget _buildEmpty(String title, String sub) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppTheme.chipBg, borderRadius: BorderRadius.circular(40)),
            child: const Center(
              child: Icon(Icons.bookmark_outline_rounded,
                  size: 36, color: AppTheme.primary)),
          ),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(fontSize: 18,
                  fontWeight: FontWeight.w700, color: AppTheme.textDark)),
          const SizedBox(height: 8),
          Text(sub,
              style: const TextStyle(fontSize: 14, color: AppTheme.textMid)),
        ],
      ),
    );
  }
}

// ── 저장 코스 카드 ──
class _CourseCard extends StatelessWidget {
  final DateCourse course;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final bool readOnly;

  const _CourseCard({
    required this.course,
    required this.onTap,
    this.onDelete,
    this.readOnly = false,
  });

  void _share() {
    final places = course.places.asMap().entries
        .map((e) => '  ${e.key + 1}. ${e.value.name}')
        .join('\n');
    Share.share(
      '💕 ODD 데이트 코스\n\n${course.mood}  ${course.title}\n\n📍 코스\n$places\n\nODD 앱으로 만든 코스예요 ✨',
      subject: course.title,
    );
  }

  @override
  Widget build(BuildContext context) {
    final thumb = course.places.isNotEmpty ? course.places.first.imageUrl : '';
    final savedDate = course.savedAt.isNotEmpty
        ? DateTime.tryParse(course.savedAt)
        : null;
    final dateStr = savedDate != null
        ? '${savedDate.month}/${savedDate.day} 저장'
        : '';

    return Dismissible(
      key: Key(course.title),
      direction: readOnly ? DismissDirection.none : DismissDirection.endToStart,
      onDismissed: readOnly ? null : (_) => onDelete?.call(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFF6B8A).withOpacity(0.12),
          borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.delete_outline_rounded,
            color: AppTheme.primary, size: 24),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 썸네일 영역
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                child: Stack(
                  children: [
                    thumb.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: thumb, height: 130,
                            width: double.infinity, fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _placeholderBanner(),
                          )
                        : _placeholderBanner(),
                    // 다크 오버레이
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.transparent,
                                Colors.black.withOpacity(0.5)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter)),
                      ),
                    ),
                    // 날짜 배지
                    if (dateStr.isNotEmpty)
                      Positioned(top: 10, right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.45),
                            borderRadius: BorderRadius.circular(20)),
                          child: Text(dateStr,
                            style: const TextStyle(color: Colors.white,
                                fontSize: 10, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    // 무드 배지
                    Positioned(bottom: 10, left: 12,
                      child: Text(course.mood,
                        style: const TextStyle(color: Colors.white,
                            fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
              // 텍스트
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(course.title,
                      style: const TextStyle(fontSize: 15,
                          fontWeight: FontWeight.w800, color: AppTheme.textDark,
                          letterSpacing: -0.3)),
                    const SizedBox(height: 5),
                    if (course.description.isNotEmpty)
                      Text(course.description,
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12,
                            color: AppTheme.textMid, height: 1.5)),
                    const SizedBox(height: 10),
                    Row(children: [
                      const Icon(Icons.location_on_rounded,
                          size: 12, color: AppTheme.primary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          course.places.map((p) => p.name).join('  →  '),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11,
                              color: AppTheme.textMid)),
                      ),
                      // 공유 버튼
                      GestureDetector(
                        onTap: _share,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.chipBg,
                            borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.ios_share_rounded,
                              size: 14, color: AppTheme.primary),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholderBanner() => Container(
    height: 130, width: double.infinity,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [AppTheme.primary.withOpacity(0.6),
            AppTheme.primary2.withOpacity(0.4)],
        begin: Alignment.topLeft, end: Alignment.bottomRight)),
    child: const Center(
      child: Text('💕', style: TextStyle(fontSize: 40))),
  );
}
