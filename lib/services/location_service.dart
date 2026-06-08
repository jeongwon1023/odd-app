import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../config/env.dart';

class LocationResult {
  final double lat;
  final double lng;
  final String district; // 구/군 (예: 강남구)
  final String city;     // 시/도 (예: 서울특별시)

  const LocationResult({
    required this.lat,
    required this.lng,
    required this.district,
    required this.city,
  });

  String get fullRegion => district.isNotEmpty ? district : city;
}

class LocationService {
  /// GPS 권한 요청 + 현재 위치 반환
  static Future<Position?> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 10),
      ),
    );
  }

  /// OpenWeather 역지오코딩 → 한국 지역명
  static Future<LocationResult> reverseGeocode(double lat, double lng) async {
    try {
      final uri = Uri.parse(
        'https://api.openweathermap.org/geo/1.0/reverse'
        '?lat=$lat&lon=$lng&limit=1&appid=${Env.openWeatherKey}',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final list = json.decode(res.body) as List;
        if (list.isNotEmpty) {
          final data = list[0] as Map<String, dynamic>;
          final localNames = data['local_names'] as Map<String, dynamic>?;
          final koName = localNames?['ko'] as String? ?? data['name'] as String? ?? '';
          final state = data['state'] as String? ?? '';

          // koName might be "강남구" or "서울특별시" depending on zoom level
          return LocationResult(
            lat: lat,
            lng: lng,
            district: koName,
            city: state,
          );
        }
      }
    } catch (_) {}
    return LocationResult(lat: lat, lng: lng, district: '', city: '');
  }

  /// 기본 위치 (서울 중심) — 위치 권한 거부 시 사용
  static LocationResult get seoulDefault => const LocationResult(
        lat: 37.5665,
        lng: 126.9780,
        district: '중구',
        city: '서울특별시',
      );
}
