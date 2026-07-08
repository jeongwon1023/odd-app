import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/env.dart';

// ─────────────────────────────────────────────
// WeatherService — 현재 날씨 조회
// OpenWeatherMap Current Weather API (무료 티어)
// 30분 메모리 캐시: 코스 생성할 때마다 API 호출 방지
// ─────────────────────────────────────────────

class WeatherInfo {
  final String condition;   // 'clear' | 'rain' | 'snow' | 'clouds' | 'thunder'
  final double tempC;       // 섭씨
  final int humidity;       // 습도 %
  final String description; // 한국어 날씨 설명

  const WeatherInfo({
    required this.condition,
    required this.tempC,
    required this.humidity,
    required this.description,
  });

  /// Gemini 프롬프트용 한 줄 요약
  String get promptLine {
    final tempStr = '${tempC.round()}°C';
    final extra = switch (condition) {
      'rain'    => ' | 우천 → 실내 위주 코스 구성, 야외 PEAK 지양',
      'snow'    => ' | 눈 → 실내 위주 코스 구성, 이동 시간 최소화',
      'thunder' => ' | 뇌우 → 실내 전용 코스, 야외 일체 제외',
      'clear'   => tempC > 32 ? ' | 폭염 → 냉방 실내 카페 우선' : '',
      _         => '',
    };
    return '날씨: $description $tempStr$extra';
  }

  /// 날씨가 나빠서 실내를 강제해야 하는지
  bool get forceIndoor =>
      condition == 'rain' || condition == 'snow' || condition == 'thunder';
}

class WeatherService {
  static const _baseUrl = 'https://api.openweathermap.org/data/2.5/weather';

  // 30분 메모리 캐시
  static WeatherInfo? _cached;
  static DateTime? _cachedAt;
  static const _cacheDuration = Duration(minutes: 30);

  /// 현재 날씨 반환. 좌표 없으면 위도/경도 기본값(서울) 사용.
  static Future<WeatherInfo?> current({
    double lat = 37.5665,
    double lng = 126.9780,
  }) async {
    // 캐시 유효하면 즉시 반환
    if (_cached != null && _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < _cacheDuration) {
      return _cached;
    }

    try {
      final uri = Uri.parse(
          '$_baseUrl?lat=$lat&lon=$lng&appid=${Env.openWeatherKey}&units=metric&lang=kr');

      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;

      final data = json.decode(res.body) as Map<String, dynamic>;
      final weather = (data['weather'] as List).first as Map<String, dynamic>;
      final main    = data['main'] as Map<String, dynamic>;

      final id = weather['id'] as int;
      final condition = _idToCondition(id);
      final description = weather['description'] as String? ?? '맑음';
      final tempC = (main['temp'] as num).toDouble();
      final humidity = (main['humidity'] as num).toInt();

      _cached = WeatherInfo(
        condition: condition,
        tempC: tempC,
        humidity: humidity,
        description: description,
      );
      _cachedAt = DateTime.now();
      return _cached;
    } catch (_) {
      return null;
    }
  }

  /// OpenWeatherMap weather ID → 조건 문자열
  static String _idToCondition(int id) {
    if (id >= 200 && id < 300) return 'thunder';
    if (id >= 300 && id < 600) return 'rain';
    if (id >= 600 && id < 700) return 'snow';
    if (id >= 800 && id < 801) return 'clear';
    if (id >= 801) return 'clouds';
    return 'clear';
  }
}
