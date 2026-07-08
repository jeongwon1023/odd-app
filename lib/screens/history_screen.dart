import 'package:flutter/material.dart';
import '../models/place_model.dart';
import '../services/cache_service.dart';
import '../utils/app_theme.dart';
import 'course_result_screen.dart';

// ─────────────────────────────────────────────
// HistoryScreen — 생성한 코스 히스토리 (날짜순)
// ─────────────────────────────────────────────

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<DateCourse> _courses = [];
  List<String> _dates = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final raw = await CacheService.getHistoryCourses();
    if (mounted) {
      setState(() {
        _courses = raw.map(DateCourse.fromJson).toList();
        _dates   = raw.map((m) => m['savedAt'] as String? ?? '').toList();
        _loading = false;
      });
    }
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('히스토리 삭제',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('생성한 코스 기록을 모두 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소', style: TextStyle(color: AppTheme.textMid))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제',
                style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (ok == true) {
      await CacheService.clearHistory();
      _load();
    }
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return '방금 전';
      if (diff.inHours < 1) return '${diff.inMinutes}분 전';
      if (diff.inDays < 1) return '${diff.inHours}시간 전';
      if (diff.inDays < 7) return '${diff.inDays}일 전';
      return '${dt.month}/${dt.day}';
    } catch (_) {
      return '';
    }
  }

  String _moodEmoji(String mood) {
    return switch (mood) {
      '감성'    => '🎨',
      '액티비티' => '⚡',
      '힐링'    => '🌿',
      _        => '💕',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        title: const Text('코스 히스토리',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800,
                color: AppTheme.textDark, letterSpacing: -0.3)),
        actions: [
          if (_courses.isNotEmpty)
            TextButton(
              onPressed: _clearAll,
              child: const Text('전체 삭제',
                  style: TextStyle(color: AppTheme.primary, fontSize: 13)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(
              color: AppTheme.primary, strokeWidth: 2.5))
          : _courses.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppTheme.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    itemCount: _courses.length,
                    itemBuilder: (_, i) => _CourseHistoryCard(
                      course: _courses[i],
                      dateStr: _formatDate(_dates[i]),
                      emoji: _moodEmoji(_courses[i].mood),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CourseResultScreen(
                            courses: [_courses[i]],
                            mood: _courses[i].mood,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.08),
              shape: BoxShape.circle),
            child: const Center(
              child: Text('📋', style: TextStyle(fontSize: 36))),
          ),
          const SizedBox(height: 20),
          const Text('아직 생성한 코스가 없어요',
              style: TextStyle(fontSize: 16,
                  fontWeight: FontWeight.w700, color: AppTheme.textDark)),
          const SizedBox(height: 8),
          const Text('AI 코스 탭에서 데이트 코스를\n만들어보세요 💕',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppTheme.textMid, height: 1.6)),
        ],
      ),
    );
  }
}

// ── 히스토리 카드 ──────────────────────────────
class _CourseHistoryCard extends StatelessWidget {
  final DateCourse course;
  final String dateStr;
  final String emoji;
  final VoidCallback onTap;

  const _CourseHistoryCard({
    required this.course,
    required this.dateStr,
    required this.emoji,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            // 이모지 원형 뱃지
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                shape: BoxShape.circle),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 14),
            // 텍스트
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(course.title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700,
                          color: AppTheme.textDark),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _Tag(course.mood),
                      const SizedBox(width: 6),
                      Text('${course.places.length}곳',
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textLight)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(course.description,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textMid, height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // 날짜 + 화살표
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(dateStr,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textLight)),
                const SizedBox(height: 6),
                const Icon(Icons.chevron_right_rounded,
                    color: AppTheme.textLight, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  const _Tag(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: const TextStyle(
              fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w600)),
    );
  }
}
