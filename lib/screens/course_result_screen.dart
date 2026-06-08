import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/place_model.dart';
import '../utils/app_theme.dart';
import 'map_screen.dart';
import 'place_detail_screen.dart';

class CourseResultScreen extends StatefulWidget {
  final List<DateCourse> courses;
  const CourseResultScreen({super.key, required this.courses});

  @override
  State<CourseResultScreen> createState() => _CourseResultScreenState();
}

class _CourseResultScreenState extends State<CourseResultScreen> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final course = widget.courses[_selected];

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('추천 코스', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppTheme.surface,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 코스 탭 선택
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: List.generate(widget.courses.length, (i) {
                final c = widget.courses[i];
                final active = i == _selected;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selected = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: EdgeInsets.only(right: i < widget.courses.length - 1 ? 8 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: active ? AppTheme.primary : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(c.mood,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: active ? Colors.white : AppTheme.textMid)),
                          const SizedBox(height: 2),
                          Text('코스 ${i + 1}',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: active ? Colors.white70 : AppTheme.textLight)),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 코스 제목 + 소개
                  Text(course.title,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textDark)),
                  const SizedBox(height: 6),
                  Text(
                    '총 ${course.totalDuration ~/ 60}시간 ${course.totalDuration % 60}분',
                    style: const TextStyle(fontSize: 13, color: AppTheme.textMid),
                  ),
                  if (course.description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        course.description,
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textMid,
                            height: 1.6),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // 타임라인 장소 목록
                  ...List.generate(course.places.length, (i) => _PlaceRow(
                        place: course.places[i],
                        index: i,
                        isLast: i == course.places.length - 1,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                PlaceDetailScreen(place: course.places[i]),
                          ),
                        ),
                      )),

                  const SizedBox(height: 24),

                  // 지도 버튼
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              MapScreen(places: course.places),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('지도에서 동선 보기',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceRow extends StatelessWidget {
  final Place place;
  final int index;
  final bool isLast;
  final VoidCallback onTap;

  const _PlaceRow({
    required this.place,
    required this.index,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 타임라인 선
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                      color: AppTheme.primary, shape: BoxShape.circle),
                  child: Center(
                    child: Text('${index + 1}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13)),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: AppTheme.primary.withOpacity(0.2),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // 장소 카드
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(14)),
                      child: CachedNetworkImage(
                        imageUrl: place.imageUrl,
                        width: 80,
                        height: 90,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          width: 80,
                          height: 90,
                          color: Colors.grey[100],
                          child: const Icon(Icons.place,
                              color: AppTheme.textLight),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(place.name,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textDark)),
                            const SizedBox(height: 4),
                            Text(
                              place.subcategory.isNotEmpty
                                  ? place.subcategory
                                  : place.address,
                              style: const TextStyle(
                                  fontSize: 11, color: AppTheme.textMid),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.timer_outlined,
                                    size: 12, color: AppTheme.textLight),
                                const SizedBox(width: 3),
                                Text('${place.duration}분',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textLight)),
                                const SizedBox(width: 10),
                                const Icon(Icons.attach_money,
                                    size: 12, color: AppTheme.textLight),
                                Text(place.priceRange,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textLight)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: Icon(Icons.chevron_right,
                          size: 18, color: AppTheme.textLight),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
