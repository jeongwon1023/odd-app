import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import '../models/place_model.dart';
import '../utils/app_theme.dart';

class MapScreen extends StatefulWidget {
  final List<Place> places;
  const MapScreen({super.key, required this.places});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  NaverMapController? _ctrl;
  int _activeIndex = 0;
  final PageController _pageCtrl = PageController();

  List<Place> get _validPlaces =>
      widget.places.where((p) => p.lat != 0 && p.lng != 0).toList();

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final places = _validPlaces;
    if (places.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('데이트 동선',
              style: TextStyle(fontWeight: FontWeight.w800)),
          backgroundColor: AppTheme.surface,
          elevation: 0,
        ),
        body: const Center(
          child: Text('지도 정보를 불러올 수 없어요 😢',
              style: TextStyle(color: AppTheme.textMid)),
        ),
      );
    }

    final centerLat =
        places.map((p) => p.lat).reduce((a, b) => a + b) / places.length;
    final centerLng =
        places.map((p) => p.lng).reduce((a, b) => a + b) / places.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('데이트 동선',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppTheme.surface,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // 네이버 지도
          NaverMap(
            options: NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target: NLatLng(centerLat, centerLng),
                zoom: places.length == 1 ? 15 : 13,
              ),
              mapType: NMapType.basic,
              activeLayerGroups: [NLayerGroup.building, NLayerGroup.transit],
              locale: const Locale('ko'),
            ),
            onMapReady: (controller) async {
              _ctrl = controller;
              await _addMarkers(controller, places);
              if (places.length > 1) await _fitBounds(controller, places);
            },
          ),

          // 하단 장소 카드
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomSheet(places),
          ),
        ],
      ),
    );
  }

  Future<void> _addMarkers(
      NaverMapController ctrl, List<Place> places) async {
    for (int i = 0; i < places.length; i++) {
      final p = places[i];
      final marker = NMarker(
        id: p.id,
        position: NLatLng(p.lat, p.lng),
        caption: NOverlayCaption(
          text: '${i + 1}. ${p.name}',
          textSize: 12,
          color: AppTheme.textDark,
          haloColor: Colors.white,
        ),
        icon: await NOverlayImage.fromWidget(
          widget: _MarkerDot(number: i + 1),
          size: const Size(36, 36),
          context: context,
        ),
      );
      marker.setOnTapListener((_) {
        setState(() => _activeIndex = i);
        _pageCtrl.animateToPage(i,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut);
        ctrl.updateCamera(NCameraUpdate.withParams(
            target: NLatLng(p.lat, p.lng), zoom: 15));
      });
      ctrl.addOverlay(marker);
    }
  }

  Future<void> _fitBounds(
      NaverMapController ctrl, List<Place> places) async {
    final lats = places.map((p) => p.lat).toList();
    final lngs = places.map((p) => p.lng).toList();
    final bounds = NLatLngBounds(
      southWest: NLatLng(
        lats.reduce((a, b) => a < b ? a : b) - 0.005,
        lngs.reduce((a, b) => a < b ? a : b) - 0.005,
      ),
      northEast: NLatLng(
        lats.reduce((a, b) => a > b ? a : b) + 0.005,
        lngs.reduce((a, b) => a > b ? a : b) + 0.005,
      ),
    );
    await ctrl.updateCamera(
      NCameraUpdate.fitBounds(
        bounds,
        padding: const EdgeInsets.only(
            bottom: 220, top: 60, left: 40, right: 40),
      ),
    );
  }

  Widget _buildBottomSheet(List<Place> places) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
              color: Colors.black12, blurRadius: 16, offset: Offset(0, -4))
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 96,
            child: PageView.builder(
              controller: _pageCtrl,
              itemCount: places.length,
              onPageChanged: (i) {
                setState(() => _activeIndex = i);
                final p = places[i];
                _ctrl?.updateCamera(NCameraUpdate.withParams(
                    target: NLatLng(p.lat, p.lng), zoom: 15));
              },
              itemBuilder: (_, i) {
                final p = places[i];
                final active = i == _activeIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: active
                        ? AppTheme.primary.withOpacity(0.07)
                        : Colors.grey[50],
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: active
                          ? AppTheme.primary.withOpacity(0.4)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle),
                        child: Center(
                          child: Text('${i + 1}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(p.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textDark,
                                    fontSize: 14)),
                            const SizedBox(height: 4),
                            Text(p.address,
                                style: const TextStyle(
                                    fontSize: 11, color: AppTheme.textMid),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text('약 ${p.duration}분 · ${p.priceRange}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textLight)),
                          ],
                        ),
                      ),
                    ],
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

class _MarkerDot extends StatelessWidget {
  final int number;
  const _MarkerDot({required this.number});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppTheme.primary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
              color: AppTheme.primary.withOpacity(0.4),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Center(
        child: Text('$number',
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16)),
      ),
    );
  }
}
