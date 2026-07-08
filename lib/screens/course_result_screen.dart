import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import '../models/place_model.dart';
import '../services/cache_service.dart';
import '../services/google_places_service.dart';
import '../services/user_preference_service.dart';
import '../services/supabase_course_service.dart';
import '../services/supabase_saved_service.dart';
import '../utils/app_theme.dart';
import 'map_screen.dart';
import 'place_detail_screen.dart';

// ─────────────────────────────────────────────
// 이동 정보 모델
// ─────────────────────────────────────────────
class _TravelInfo {
  final String mode;
  final int minutes;
  const _TravelInfo(this.mode, this.minutes);
}

// ─────────────────────────────────────────────
// 코스 결과 화면
// ─────────────────────────────────────────────
class CourseResultScreen extends StatefulWidget {
  final List<DateCourse> courses;
  final String mood;
  final String specialDay;
  final String timeSlot;
  final VoidCallback? onRegenerate;

  const CourseResultScreen({
    super.key,
    required this.courses,
    this.mood = '혼합',
    this.specialDay = '일상',
    this.timeSlot = '낮',
    this.onRegenerate,
  });

  @override
  State<CourseResultScreen> createState() => _CourseResultScreenState();
}

class _CourseResultScreenState extends State<CourseResultScreen> {
  int _selected = 0;
  final Set<String> _savedTitles = {};
  final GlobalKey _cardKey = GlobalKey();

  // 진입 시점의 코스(사진이 채워지면 갱신). 홈 카드 등에서 사진 없이 들어와도
  // 여기서 Google 사진을 채워 회색 placeholder를 제거한다.
  late List<DateCourse> _courses = widget.courses;

  @override
  void initState() {
    super.initState();
    _enrichPhotos();
  }

  /// 사진(imageUrl)이 없는 장소만 Google Places로 보강 — 이미 채워진 코스는 건너뜀
  Future<void> _enrichPhotos() async {
    final needsPhoto = widget.courses
        .expand((c) => c.places)
        .any((p) => p.imageUrl.isEmpty);
    if (!needsPhoto) return;

    final updated = <DateCourse>[];
    for (final course in widget.courses) {
      final places = await Future.wait(course.places.map((p) async {
        if (p.imageUrl.isNotEmpty) return p;
        final url = await GooglePlacesService.fetchFirstPhotoUrl(p.name, p.address);
        return url != null ? p.copyWith(imageUrl: url) : p;
      }));
      updated.add(DateCourse(
        title: course.title,
        concept: course.concept,
        mood: course.mood,
        description: course.description,
        places: places,
        totalDuration: course.totalDuration,
        savedAt: course.savedAt,
      ));
    }
    if (mounted) setState(() => _courses = updated);
  }

  // ── 하빌사인 거리(km) ──
  static double _distKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLng = (lng2 - lng1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
            sin(dLng / 2) * sin(dLng / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  // ── 좌표 유효성 (대한민국 범위) ──
  // 좌표가 0,0이거나 범위 밖이면 '동떨어진' 가짜 동선이 계산되므로 거리/이동수단을 숨긴다.
  static bool _validCoord(Place p) =>
      p.lat >= 33.0 && p.lat <= 39.5 && p.lng >= 124.0 && p.lng <= 132.0;

  // ── 이동수단 + 예상 시간 (좌표 불량 시 null → 표시 생략) ──
  static _TravelInfo? _travel(Place from, Place to) {
    if (!_validCoord(from) || !_validCoord(to)) return null;
    final km = _distKm(from.lat, from.lng, to.lat, to.lng);
    if (km < 0.05) return const _TravelInfo('도보', 1);
    if (km <= 1.2) return _TravelInfo('도보', (km * 1000 / 80).ceil());
    if (km <= 5.0) return _TravelInfo('대중교통', (km / 0.4).ceil());
    return _TravelInfo('차량', (km / 0.6).ceil());
  }

  // ── 가격대 ₩ 심볼 ──
  static String _wonSymbol(String p) {
    switch (p) {
      case '저렴': return '₩';
      case '보통': return '₩₩';
      case '고급': return '₩₩₩';
      default:     return '₩₩';
    }
  }

  // ── 1인 예산 중간값 ──
  static int _priceMid(String p) {
    switch (p) {
      case '저렴': return 15000;
      case '보통': return 35000;
      case '고급': return 70000;
      default:     return 25000;
    }
  }

  static String _wonFmt(int won) =>
      won >= 10000 ? '${(won / 10000).round()}만원' : '${won ~/ 1000}천원';


  /// 현재 코스 카드를 이미지로 캡처해서 공유
  Future<void> _shareAsImage(DateCourse course) async {
    try {
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final tmpDir = await getTemporaryDirectory();
      final file = File('${tmpDir.path}/odd_course_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      await Share.shareXFiles(
        [XFile(file.path)],
        text: '${course.title}\nODD로 만든 오늘의 데이트 코스 #ODD데이트',
      );
    } catch (_) {
      // 캡처 실패 시 텍스트 공유로 폴백
      _shareCourse(course);
    }
  }

  void _shareCourse(DateCourse course) {
    final places = course.places.asMap().entries
        .map((e) => '  ${e.key + 1}. ${e.value.name}  (${e.value.subcategory})')
        .join('\n');
    final budget = course.places.fold(0, (s, p) => s + _priceMid(p.priceRange));
    Share.share('''
ODD 데이트 코스 추천

${course.mood}  ${course.title}

${course.description}

코스 순서
$places

총 소요시간: ${course.totalDuration ~/ 60}시간 ${course.totalDuration % 60}분
예상 예산: 1인 ${_wonFmt(budget)} 내외

ODD 앱으로 만든 데이트 코스예요'''.trim(), subject: course.title);
  }

  Future<void> _toggleSave(DateCourse course) async {
    final title = course.title;
    if (_savedTitles.contains(title)) {
      await CacheService.removeCourse(title);
      unawaited(SupabaseSavedService.removeCourse(title)); // DB 삭제 (로그인 시)
      setState(() => _savedTitles.remove(title));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('저장이 취소됐어요'),
                duration: Duration(seconds: 1)));
      }
    } else {
      final json = course.toJson();
      await CacheService.saveCourse(json);
      unawaited(SupabaseSavedService.saveCourse(json)); // DB 저장 (로그인 시)
      final cats = course.places.map((p) => p.category).toList();
      // Thompson Sampling — 기본 저장 신호 (후기 팝업에서 가중치 추가 적용)
      unawaited(UserPreferenceService.recordSave(cats));
      // Q3: DB 코스면 save_count 증가
      unawaited(SupabaseCourseService.incrementSaveCount(course.title));
      setState(() => _savedTitles.add(title));

      // ── 후기 팝업 (저장 직후 2초 딜레이 후 표시) ────────────────────────
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('코스를 저장했어요'),
          duration: const Duration(seconds: 2),
          backgroundColor: AppTheme.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        // 스낵바 사라진 후 후기 팝업 표시
        Future.delayed(const Duration(milliseconds: 2400), () {
          if (mounted) _showReviewPopup(course);
        });
      }
    }
  }

  /// 저장 직후 후기 팝업 — 별점 + 한 줄 피드백으로 Thompson Sampling 강화
  Future<void> _showReviewPopup(DateCourse course) async {
    int hoveredStar = 0;
    int selectedStar = 0;
    final cats = course.places.map((p) => p.category).toList();

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A24),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 드래그 바
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '이 코스, 마음에 드세요?',
                style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '다음에 더 잘 맞는 코스를 추천해드릴게요',
                style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.5)),
              ),
              const SizedBox(height: 20),

              // 별점 선택
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final active = i < (hoveredStar > 0 ? hoveredStar : selectedStar);
                  return GestureDetector(
                    onTap: () {
                      setModal(() => selectedStar = i + 1);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        active ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 40,
                        color: active ? const Color(0xFFFFD700) : Colors.white24,
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 8),
              Text(
                selectedStar == 0 ? '별점을 선택해주세요'
                    : selectedStar >= 4 ? '완벽한 코스네요!'
                    : selectedStar == 3 ? '괜찮은 코스였군요'
                    : '다음엔 더 잘 맞는 코스를 찾아드릴게요',
                style: TextStyle(
                  fontSize: 13,
                  color: selectedStar == 0
                      ? Colors.white24
                      : selectedStar >= 4
                          ? const Color(0xFFFFD700)
                          : Colors.white54,
                ),
              ),

              const SizedBox(height: 20),

              // 확인 버튼
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        '건너뛰기',
                        style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: selectedStar == 0 ? null : () {
                        // 별점에 따른 Thompson Sampling 신호 강화
                        if (selectedStar >= 4) {
                          // 4~5점: 강한 성공 신호 (추가 +2)
                          unawaited(UserPreferenceService.recordSave(cats));
                          unawaited(UserPreferenceService.recordSave(cats));
                        } else if (selectedStar <= 2) {
                          // 1~2점: 스킵 신호 (이 카테고리 조합 피하기)
                          unawaited(UserPreferenceService.recordSkip(cats));
                        }
                        // 3점: 중립 — 추가 신호 없음
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                        disabledBackgroundColor: Colors.white12,
                      ),
                      child: const Text('완료', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContextTags() {
    final tags = <String>[
      widget.mood == '혼합' ? '자유로운 데이트' : '${widget.mood} 데이트',
      if (widget.specialDay != '일상') widget.specialDay,
      widget.timeSlot == '하루종일' ? '하루 종일' : '${widget.timeSlot} 데이트',
    ];
    return Wrap(
      spacing: 6, runSpacing: 6,
      children: tags.map((label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.chipBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
        ),
        child: Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: AppTheme.primary)),
      )).toList(),
    );
  }

  // ── 코스 요약 카드 ──
  Widget _buildSummaryCard(DateCourse course) {
    final budget = course.places.fold(0, (s, p) => s + _priceMid(p.priceRange));
    final modes = <String>{};
    for (int i = 0; i < course.places.length - 1; i++) {
      final t = _travel(course.places[i], course.places[i + 1]);
      if (t != null) modes.add(t.mode);
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          _SummaryItem(icon: Icons.schedule_rounded, label: '총 시간',
              value: '${course.totalDuration ~/ 60}h ${course.totalDuration % 60}m'),
          _vDivider(),
          _SummaryItem(icon: Icons.account_balance_wallet_outlined,
              label: '1인 예산', value: '${_wonFmt(budget)} 내외'),
          _vDivider(),
          _SummaryItem(icon: Icons.directions_rounded, label: '이동수단',
              value: modes.isEmpty ? '도보' : modes.join('·')),
        ],
      ),
    );
  }

  Widget _vDivider() => Container(
      width: 1, height: 32, margin: const EdgeInsets.symmetric(horizontal: 12),
      color: AppTheme.primary.withOpacity(0.15));

  // ── 인앱 동선 지도 (네이티브 네이버 지도, 탭 → 전체 지도) ──
  Widget _buildRouteMap(DateCourse course) {
    final valid = course.places.where(_validCoord).toList();
    if (valid.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                MapScreen(places: course.places, courseTitle: course.title),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 190,
            child: Stack(
              children: [
                Positioned.fill(
                  child: NaverMap(
                    key: ValueKey('routemap_$_selected'),
                    options: NaverMapViewOptions(
                      initialCameraPosition: NCameraPosition(
                        target: NLatLng(valid.first.lat, valid.first.lng),
                        zoom: 12,
                      ),
                      scrollGesturesEnable: false,
                      zoomGesturesEnable: false,
                      tiltGesturesEnable: false,
                      rotationGesturesEnable: false,
                      stopGesturesEnable: false,
                    ),
                    onMapReady: (c) => _drawRoute(c, valid),
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('동선 크게 보기',
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
      ),
    );
  }

  void _drawRoute(NaverMapController c, List<Place> valid) {
    final coords = <NLatLng>[];
    for (var i = 0; i < valid.length; i++) {
      final p = valid[i];
      final pos = NLatLng(p.lat, p.lng);
      coords.add(pos);
      c.addOverlay(NMarker(
        id: 'r$i',
        position: pos,
        caption: NOverlayCaption(text: '${i + 1}'),
      ));
    }
    if (coords.length > 1) {
      c.addOverlay(NPolylineOverlay(
        id: 'route',
        coords: coords,
        color: const Color(0xFFFF5A5F),
        width: 3,
      ));
      var minLat = coords.first.latitude, maxLat = coords.first.latitude;
      var minLng = coords.first.longitude, maxLng = coords.first.longitude;
      for (final v in coords) {
        if (v.latitude < minLat) minLat = v.latitude;
        if (v.latitude > maxLat) maxLat = v.latitude;
        if (v.longitude < minLng) minLng = v.longitude;
        if (v.longitude > maxLng) maxLng = v.longitude;
      }
      c.updateCamera(NCameraUpdate.fitBounds(
        NLatLngBounds(
          southWest: NLatLng(minLat, minLng),
          northEast: NLatLng(maxLat, maxLng),
        ),
        padding: const EdgeInsets.all(40),
      ));
    } else {
      c.updateCamera(
          NCameraUpdate.scrollAndZoomTo(target: coords.first, zoom: 14));
    }
  }

  @override
  Widget build(BuildContext context) {
    final course = _courses[_selected];
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('추천 코스', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppTheme.surface,
        elevation: 0,
        actions: [
          if (widget.onRegenerate != null)
            TextButton.icon(
              onPressed: widget.onRegenerate,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('다시 만들기', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.image_outlined, color: AppTheme.textMid, size: 22),
            tooltip: '카드로 공유',
            onPressed: () => _shareAsImage(_courses[_selected]),
          ),
          IconButton(
            icon: const Icon(Icons.ios_share_rounded, color: AppTheme.textMid, size: 22),
            onPressed: () => _shareCourse(_courses[_selected]),
          ),
          IconButton(
            icon: Icon(
              _savedTitles.contains(_courses[_selected].title)
                  ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
              color: _savedTitles.contains(_courses[_selected].title)
                  ? AppTheme.primary : AppTheme.textMid,
            ),
            onPressed: () => _toggleSave(_courses[_selected]),
          ),
        ],
      ),
      body: Column(children: [
        // 코스 탭
        Container(
          color: AppTheme.surface,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: List.generate(_courses.length, (i) {
              final c = _courses[i];
              final active = i == _selected;
              final label = c.concept.isNotEmpty ? c.concept : '코스 ${i+1}';
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selected = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: EdgeInsets.only(right: i < _courses.length - 1 ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    decoration: BoxDecoration(
                      color: active ? AppTheme.primary : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: active ? [BoxShadow(
                        color: AppTheme.primary.withOpacity(0.3),
                        blurRadius: 8, offset: const Offset(0, 3))] : null,
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(label, style: TextStyle(fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: active ? Colors.white : AppTheme.textMid)),
                      Text('코스 ${i + 1}', style: TextStyle(fontSize: 9,
                          color: active ? Colors.white70 : AppTheme.textLight)),
                    ]),
                  ),
                ),
              );
            }),
          ),
        ),

        Expanded(
          child: RepaintBoundary(
            key: _cardKey,
            child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(course.title, style: const TextStyle(fontSize: 20,
                    fontWeight: FontWeight.w900, color: AppTheme.textDark)),
                const SizedBox(height: 10),
                _buildContextTags(),
                const SizedBox(height: 12),

                // ── 요약 카드 ──
                _buildSummaryCard(course),

                // 코스 설명
                if (course.description.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(course.description, style: const TextStyle(
                        fontSize: 13, color: AppTheme.textMid, height: 1.6)),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── 인앱 동선 지도 (탭 → 전체 지도) ──
                _buildRouteMap(course),

                // ── 타임라인 ──
                ...List.generate(course.places.length, (i) {
                  final isLast = i == course.places.length - 1;
                  final tInfo = !isLast
                      ? _travel(course.places[i], course.places[i + 1])
                      : null;
                  return Column(children: [
                    _PlaceRow(
                      place: course.places[i], index: i, isLast: isLast,
                      wonSymbol: _wonSymbol(course.places[i].priceRange),
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) =>
                              PlaceDetailScreen(place: course.places[i]))),
                    ),
                    if (tInfo != null) _TravelConnector(info: tInfo),
                  ]);
                }),

                const SizedBox(height: 24),

                // 지도 버튼
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) =>
                            MapScreen(places: course.places, courseTitle: course.title))),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('지도에서 동선 보기',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// 요약 아이템 위젯
// ─────────────────────────────────────────────
class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _SummaryItem({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Icon(icon, size: 16, color: AppTheme.primary),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textLight)),
      const SizedBox(height: 2),
      Text(value, textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
              color: AppTheme.textDark)),
    ]),
  );
}

// ─────────────────────────────────────────────
// 장소 간 이동 커넥터
// ─────────────────────────────────────────────
class _TravelConnector extends StatelessWidget {
  final _TravelInfo info;
  const _TravelConnector({required this.info});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 14, top: 0, bottom: 4),
      child: Row(children: [
        const SizedBox(width: 14),
        Container(width: 2, height: 8,
            color: AppTheme.primary.withOpacity(0.2)),
        const SizedBox(width: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('${info.mode} 약 ${info.minutes}분',
                style: const TextStyle(fontSize: 11,
                    fontWeight: FontWeight.w600, color: AppTheme.textMid)),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// 리뷰 수 포맷 헬퍼 (top-level — _PlaceRow에서 접근 가능)
// ─────────────────────────────────────────────
String _fmtCount(int n) =>
    n >= 1000 ? '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}k' : '$n';

// ─────────────────────────────────────────────
// 장소 카드 행
// ─────────────────────────────────────────────
class _PlaceRow extends StatelessWidget {
  final Place place;
  final int index;
  final bool isLast;
  final String wonSymbol;
  final VoidCallback onTap;

  const _PlaceRow({
    required this.place, required this.index, required this.isLast,
    required this.wonSymbol, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasReason = place.aiReason.isNotEmpty;
    final hasTip = place.tip.isNotEmpty;

    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // 타임라인
        SizedBox(
          width: 40,
          child: Column(children: [
            Container(
              width: 28, height: 28,
              decoration: const BoxDecoration(
                  color: AppTheme.primary, shape: BoxShape.circle),
              child: Center(child: Text('${index + 1}',
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w800, fontSize: 13))),
            ),
            if (!isLast)
              Expanded(child: Container(
                  width: 2, margin: const EdgeInsets.symmetric(vertical: 4),
                  color: AppTheme.primary.withOpacity(0.2))),
          ]),
        ),
        const SizedBox(width: 12),

        // 카드
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 4),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
                    blurRadius: 10, offset: const Offset(0, 3))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 상단: 사진 + 기본 정보
                  Row(children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          bottomLeft: Radius.circular(16)),
                      child: place.imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: place.imageUrl,
                              width: 90, height: 100, fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => _placeholderImg())
                          : _placeholderImg(),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(place.name, style: const TextStyle(fontSize: 14,
                              fontWeight: FontWeight.w800, color: AppTheme.textDark),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 3),
                          Text(
                            place.subcategory.isNotEmpty ? place.subcategory : place.address,
                            style: const TextStyle(fontSize: 11, color: AppTheme.textMid),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(children: [
                            const Icon(Icons.timer_outlined, size: 11, color: AppTheme.textLight),
                            const SizedBox(width: 3),
                            Text('${place.duration}분',
                                style: const TextStyle(fontSize: 11, color: AppTheme.textLight)),
                            const SizedBox(width: 8),
                            Text(wonSymbol, style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700,
                                color: AppTheme.primary.withOpacity(0.8))),
                          ]),
                          if (place.rating > 0) ...[
                            const SizedBox(height: 4),
                            Row(children: [
                              const Icon(Icons.star_rounded, size: 11, color: Color(0xFFFFC107)),
                              const SizedBox(width: 2),
                              Text(place.rating.toStringAsFixed(1),
                                  style: const TextStyle(fontSize: 11,
                                      color: AppTheme.textMid, fontWeight: FontWeight.w600)),
                              if (place.reviewCount > 0) ...[
                                const SizedBox(width: 4),
                                Text('리뷰 ${_fmtCount(place.reviewCount)}',
                                    style: const TextStyle(fontSize: 10, color: AppTheme.textLight)),
                              ],
                            ]),
                          ],
                        ]),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(right: 10),
                      child: Icon(Icons.chevron_right, size: 18, color: AppTheme.textLight),
                    ),
                  ]),

                  // AI 이유 (있을 때만)
                  if (hasReason) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.05),
                        border: Border(top: BorderSide(color: AppTheme.primary.withOpacity(0.08))),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('💡', style: TextStyle(fontSize: 11)),
                          const SizedBox(width: 5),
                          Expanded(child: Text(place.aiReason,
                              style: const TextStyle(fontSize: 11,
                                  color: AppTheme.primary, fontWeight: FontWeight.w600,
                                  height: 1.4))),
                        ],
                      ),
                    ),
                  ],

                  // 팁 (있을 때만)
                  if (hasTip) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3E0),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFFFCC80)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Text('⭐', style: TextStyle(fontSize: 10)),
                              const SizedBox(width: 4),
                              Text(place.tip, style: const TextStyle(
                                  fontSize: 10, color: Color(0xFFE65100),
                                  fontWeight: FontWeight.w700)),
                            ]),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── 딥링크 버튼 영역 ─────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        // 네이버 지도 (항상)
                        _LinkChip(
                          label: '지도 보기',
                          textColor: const Color(0xFF2E7D32),
                          bgColor: const Color(0xFFE8F5E9),
                          borderColor: const Color(0xFF81C784),
                          onTap: () async {
                            final q = Uri.encodeComponent(
                                place.address.isNotEmpty
                                    ? '${place.name} ${place.address}'
                                    : place.name);
                            final uri = Uri.parse('https://map.naver.com/v5/search/$q');
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          },
                        ),
                        // 네이버 예약 (맛집·카페·체험)
                        if (_isNaverBookable(place.category))
                          _LinkChip(
                            label: '네이버 예약',
                            textColor: const Color(0xFF1565C0),
                            bgColor: const Color(0xFFE3F2FD),
                            borderColor: const Color(0xFF90CAF9),
                            onTap: () async {
                              final q = Uri.encodeComponent(place.name);
                              final uri = Uri.parse(
                                  'https://m.booking.naver.com/booking/13/bizes/search?keyword=$q');
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            },
                          ),
                        // CatchTable (맛집만)
                        if (_isCatchTableEligible(place.category))
                          _LinkChip(
                            label: 'CatchTable',
                            textColor: const Color(0xFFBF360C),
                            bgColor: const Color(0xFFFBE9E7),
                            borderColor: const Color(0xFFFF8A65),
                            onTap: () async {
                              final q = Uri.encodeComponent(place.name);
                              final uri = Uri.parse(
                                  'https://catchtable.co.kr/search?keyword=$q');
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _placeholderImg() => Container(
    width: 90, height: 100, color: const Color(0xFFF8F0F5),
    child: const Center(child: Icon(Icons.place_outlined, color: AppTheme.primary, size: 28)),
  );
}

// ── 딥링크 노출 조건 헬퍼 ────────────────────────────────────────────────
bool _isNaverBookable(String category) {
  final c = category.toLowerCase();
  return c.contains('맛집') || c.contains('식당') || c.contains('레스토랑') ||
      c.contains('카페') || c.contains('브런치') || c.contains('체험');
}

bool _isCatchTableEligible(String category) {
  final c = category.toLowerCase();
  return c.contains('맛집') || c.contains('식당') || c.contains('레스토랑');
}

// ─────────────────────────────────────────────
// 딥링크 칩 버튼 위젯
// ─────────────────────────────────────────────
class _LinkChip extends StatelessWidget {
  final String label;
  final Color textColor;
  final Color bgColor;
  final Color borderColor;
  final VoidCallback onTap;

  const _LinkChip({
    required this.label,
    required this.textColor,
    required this.bgColor,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 0.8),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 11,
          color: textColor,
          fontWeight: FontWeight.w700,
        )),
      ),
    );
  }
}
