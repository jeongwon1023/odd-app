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

  /// city + district 합체. "대전광역시 서구", "서울특별시 강남구" 형태
  /// district가 이미 city를 포함하면 district만 반환 (이중 city 방지)
  String get fullRegion {
    final c = city.isNotEmpty ? city : '';
    final d = district.isNotEmpty ? district : '';
    if (c.isNotEmpty && d.isNotEmpty) {
      // "서울특별시 강남구".startsWith("서울특별시") → true → "서울특별시 강남구" 그대로
      if (d.startsWith(c)) return d;
      return '$c $d';
    }
    return c.isNotEmpty ? c : d;
  }
}

// 영어 state → 한국어 시/도명 매핑 (OpenWeather state 필드 대응)
const _stateKo = {
  'Seoul':                   '서울특별시',
  'Busan':                   '부산광역시',
  'Daegu':                   '대구광역시',
  'Incheon':                 '인천광역시',
  'Gwangju':                 '광주광역시',
  'Daejeon':                 '대전광역시',
  'Ulsan':                   '울산광역시',
  'Sejong':                  '세종특별자치시',
  'Gyeonggi-do':             '경기도',
  'Gangwon-do':              '강원도',
  'Gangwon':                 '강원도',
  'North Chungcheong':       '충청북도',
  'Chungcheongbuk-do':       '충청북도',
  'South Chungcheong':       '충청남도',
  'Chungcheongnam-do':       '충청남도',
  'North Jeolla':            '전라북도',
  'Jeollabuk-do':            '전라북도',
  'South Jeolla':            '전라남도',
  'Jeollanam-do':            '전라남도',
  'North Gyeongsang':        '경상북도',
  'Gyeongsangbuk-do':        '경상북도',
  'South Gyeongsang':        '경상남도',
  'Gyeongsangnam-do':        '경상남도',
  'Jeju':                    '제주특별자치도',
  'Jeju-do':                 '제주특별자치도',
};

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
      desiredAccuracy: LocationAccuracy.medium,
      timeLimit: const Duration(seconds: 10),
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
          final stateRaw = data['state'] as String? ?? '';
          // OpenWeather state 필드는 영어 → 한국어 시/도명으로 변환
          final cityKo = _stateKo[stateRaw] ?? stateRaw;

          return LocationResult(
            lat: lat,
            lng: lng,
            district: koName,
            city: cityKo,
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
