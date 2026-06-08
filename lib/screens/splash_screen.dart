import 'package:flutter/material.dart';
import '../services/location_service.dart';
import '../services/naver_place_service.dart';
import '../services/cache_service.dart';
import '../models/place_model.dart';
import '../utils/app_theme.dart';
import 'main_nav.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  String _status = '위치를 확인하고 있어요 📍';

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
    _init();
  }

  Future<void> _init() async {
    await Future.delayed(const Duration(milliseconds: 600));

    LocationResult location;
    try {
      final pos = await LocationService.getCurrentPosition();
      if (pos != null) {
        setState(() => _status = '주변 데이트 코스를 찾고 있어요 💕');
        location = await LocationService.reverseGeocode(
            pos.latitude, pos.longitude);
      } else {
        location = LocationService.seoulDefault;
      }
    } catch (_) {
      location = LocationService.seoulDefault;
    }

    setState(() => _status = '${location.fullRegion} 핫플을 불러오는 중 ✨');

    // 로컬 캐시 우선 → 없으면 네이버 API 호출
    final region = location.fullRegion;
    var cached감성 = await CacheService.getPlaces(region, '감성');
    var cached액티비티 = await CacheService.getPlaces(region, '액티비티');

    Map<String, List<Place>> placeMap;
    if (cached감성.isNotEmpty && cached액티비티.isNotEmpty) {
      placeMap = {'감성': cached감성, '액티비티': cached액티비티};
    } else {
      placeMap = await NaverPlaceService.fetchHomeData(region);

      // 백그라운드 캐시 저장
      if (placeMap['감성']?.isNotEmpty == true) {
        CacheService.savePlaces(region, '감성', placeMap['감성']!);
      }
      if (placeMap['액티비티']?.isNotEmpty == true) {
        CacheService.savePlaces(region, '액티비티', placeMap['액티비티']!);
      }
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MainNav(
          location: location,
          initialPlaces: placeMap,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: FadeTransition(
        opacity: _fade,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Center(
                  child: Text(
                    'O',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 46,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'ODD',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'AI 데이트 플래너',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 60),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _status,
                style:
                    const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
