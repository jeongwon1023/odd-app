import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/naver_map_status.dart';
import '../models/place_model.dart';

// ─────────────────────────────────────────────
// ODD 지도 화면 — 네이티브 네이버 지도 (flutter_naver_map)
// WebView origin 인증 벽을 우회 (앱 패키지명으로 인증)
// ─────────────────────────────────────────────

class MapScreen extends StatefulWidget {
  final List<Place> places;
  final String courseTitle;

  const MapScreen({
    super.key,
    required this.places,
    this.courseTitle = '데이트 코스',
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  int _selectedIdx = 0;
  NaverMapController? _controller;

  // 좌표 유효성 (대한민국 범위) — 0,0/범위 밖은 지도에 찍지 않는다.
  static bool _validCoord(Place p) =>
      p.lat >= 33.0 && p.lat <= 39.5 && p.lng >= 124.0 && p.lng <= 132.0;

  // 유효 좌표 장소 — 카드 번호와 맞추기 위해 원본 인덱스 유지
  List<MapEntry<int, Place>> get _valid =>
      widget.places.asMap().entries.where((e) => _validCoord(e.value)).toList();

  void _onMapReady(NaverMapController controller) {
    _controller = controller;
    final valid = _valid;
    if (valid.isEmpty) return;

    final coords = <NLatLng>[];
    for (final e in valid) {
      final p = e.value;
      final pos = NLatLng(p.lat, p.lng);
      coords.add(pos);

      final marker = NMarker(
        id: 'm${e.key}',
        position: pos,
        caption: NOverlayCaption(text: '${e.key + 1}. ${p.name}'),
      );
      marker.setOnTapListener((NMarker m) {
        if (mounted) setState(() => _selectedIdx = e.key);
      });
      controller.addOverlay(marker);
    }

    // 동선 폴리라인
    if (coords.length > 1) {
      controller.addOverlay(NPolylineOverlay(
        id: 'route',
        coords: coords,
        color: const Color(0xFFFF5A5F),
        width: 3,
      ));
    }

    // 카메라 맞춤
    if (coords.length == 1) {
      controller.updateCamera(
          NCameraUpdate.scrollAndZoomTo(target: coords.first, zoom: 15));
    } else {
      var minLat = coords.first.latitude, maxLat = coords.first.latitude;
      var minLng = coords.first.longitude, maxLng = coords.first.longitude;
      for (final c in coords) {
        if (c.latitude < minLat) minLat = c.latitude;
        if (c.latitude > maxLat) maxLat = c.latitude;
        if (c.longitude < minLng) minLng = c.longitude;
        if (c.longitude > maxLng) maxLng = c.longitude;
      }
      controller.updateCamera(NCameraUpdate.fitBounds(
        NLatLngBounds(
          southWest: NLatLng(minLat, minLng),
          northEast: NLatLng(maxLat, maxLng),
        ),
        padding: const EdgeInsets.all(48),
      ));
    }
  }

  void _focus(int idx) {
    final p = widget.places[idx];
    if (!_validCoord(p)) return;
    _controller?.updateCamera(
      NCameraUpdate.scrollAndZoomTo(target: NLatLng(p.lat, p.lng), zoom: 16),
    );
  }

  // 선택한 장소를 네이버 지도 앱으로 길찾기 (없으면 웹 검색으로 폴백)
  Future<void> _openNaverDirections(Place p) async {
    final nmap = Uri.parse(
        'nmap://route/public?dlat=${p.lat}&dlng=${p.lng}&dname=${Uri.encodeComponent(p.name)}&appname=com.odd.app');
    final web = Uri.parse(
        'https://map.naver.com/v5/search/${Uri.encodeComponent(p.name)}');
    if (await canLaunchUrl(nmap)) {
      await launchUrl(nmap);
    } else {
      await launchUrl(web, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final valid = _valid;
    final firstValid = valid.isNotEmpty ? valid.first.value : null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.courseTitle,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        actions: [
          if (firstValid != null)
            TextButton.icon(
              onPressed: () => _openNaverDirections(widget.places[_selectedIdx]),
              icon: const Icon(Icons.directions, size: 18, color: Color(0xFF03C75A)),
              label: const Text('길찾기',
                  style: TextStyle(
                      color: Color(0xFF03C75A), fontWeight: FontWeight.w700)),
            ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFEEEEEE)),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: firstValid == null
                      ? const Center(
                          child: Text('이 코스의 위치 정보를\n준비 중이에요',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey)),
                        )
                      : NaverMap(
                          options: NaverMapViewOptions(
                            initialCameraPosition: NCameraPosition(
                              target: NLatLng(firstValid.lat, firstValid.lng),
                              zoom: 13,
                            ),
                            mapType: NMapType.basic,
                          ),
                          onMapReady: _onMapReady,
                        ),
                ),
                // 인증 실패 진단 배너
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: ValueListenableBuilder<String?>(
                    valueListenable: NaverMapStatus.authError,
                    builder: (_, err, __) {
                      if (err == null) return const SizedBox.shrink();
                      return Container(
                        color: const Color(0xE6C0392B),
                        padding: const EdgeInsets.all(10),
                        child: Text('지도 인증 실패\n$err',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                height: 1.4)),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // ── 하단 장소 카드 슬라이더 ──
          if (widget.places.isNotEmpty)
            Container(
              height: 110,
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 8,
                      offset: Offset(0, -2))
                ],
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                itemCount: widget.places.length,
                itemBuilder: (_, i) {
                  final place = widget.places[i];
                  final isSelected = _selectedIdx == i;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedIdx = i);
                      _focus(i);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color:
                            isSelected ? const Color(0xFFFF5A5F) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFFF5A5F)
                              : Colors.grey[300]!,
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                    color: const Color(0xFFFF5A5F)
                                        .withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2))
                              ]
                            : [],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFFFF5A5F),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text('${i + 1}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? const Color(0xFFFF5A5F)
                                            : Colors.white,
                                      )),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 120),
                                child: Text(place.name,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFF1A1A1A),
                                    ),
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            place.subcategory.isNotEmpty
                                ? place.subcategory
                                : place.category,
                            style: TextStyle(
                              fontSize: 11,
                              color: isSelected
                                  ? Colors.white70
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
