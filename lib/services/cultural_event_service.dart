import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/env.dart';
import '../models/place_model.dart';

// ─────────────────────────────────────────────
// CulturalEventService
// 공공데이터포털 — 한국문화정보원 한눈에보는문화정보조회서비스
// End Point: https://apis.data.go.kr/B553457/cultureinfo
// 포맷: XML → 내부 파서로 처리
// ─────────────────────────────────────────────

/// 문화 이벤트 모델 (공연 / 전시 / 축제 / 체험)
class CulturalEvent {
  final String seq;
  final String title;
  final String place;
  final String area;
  final String startDate;
  final String endDate;
  final String realmName;  // 분야명 (전시, 공연, 축제 등)
  final String thumbnail;
  final String url;
  final String price;
  final String description;

  const CulturalEvent({
    required this.seq,
    required this.title,
    required this.place,
    required this.area,
    required this.startDate,
    required this.endDate,
    required this.realmName,
    required this.thumbnail,
    required this.url,
    this.price = '',
    this.description = '',
  });

  /// 편의 alias — thumbnail / startDate 의 다른 이름
  String get imageUrl => thumbnail;
  String get date => startDate;

  /// 이벤트 분야 → Date Arc 슬롯 매핑
  String get dateArcSlot {
    if (realmName.contains('전시')) return 'peak';
    if (realmName.contains('공연') || realmName.contains('뮤지컬') ||
        realmName.contains('연극') || realmName.contains('음악') ||
        realmName.contains('국악') || realmName.contains('무용')) return 'peak';
    if (realmName.contains('축제') || realmName.contains('행사')) return 'peak';
    if (realmName.contains('체험') || realmName.contains('교육')) return 'peak';
    return 'peak';
  }

  /// 분야 이모지
  String get emoji {
    if (realmName.contains('전시')) return '🎨';
    if (realmName.contains('뮤지컬') || realmName.contains('오페라')) return '🎭';
    if (realmName.contains('공연') || realmName.contains('음악')) return '🎵';
    if (realmName.contains('연극')) return '🎬';
    if (realmName.contains('국악') || realmName.contains('무용')) return '🥁';
    if (realmName.contains('축제')) return '🎉';
    if (realmName.contains('체험')) return '✏️';
    return '🎪';
  }

  /// 날짜 포맷: "20260619" → "6/19"
  String get formattedDate {
    try {
      if (startDate.length == 8) {
        final m = int.parse(startDate.substring(4, 6));
        final d = int.parse(startDate.substring(6, 8));
        if (endDate.length == 8) {
          final em = int.parse(endDate.substring(4, 6));
          final ed = int.parse(endDate.substring(6, 8));
          if (startDate == endDate) return '$m/$d';
          return '$m/$d ~ $em/$ed';
        }
        return '$m/$d~';
      }
      return '';
    } catch (_) {
      return '';
    }
  }

  /// CulturalEvent → Place 변환 (Gemini 슬롯 풀에 직접 투입용)
  Place toPlace() {
    // 문화포털 API는 좌표 미제공 → 지역 중심 좌표 폴백으로 Gemini 동선 최적화 참여
    final coords = _regionCenter(area);
    return Place(
      id: 'culture_$seq',
      name: title,
      category: '전시·문화',
      subcategory: realmName,
      tags: [realmName, '문화', '이벤트', if (isOngoing) '진행중'],
      address: place,
      lat: coords.$1,
      lng: coords.$2,
      rating: 4.3,
      priceRange: price.isNotEmpty ? price : '별도 확인',
      duration: realmName.contains('공연') || realmName.contains('뮤지컬') ? 120 : 90,
      imageUrl: thumbnail,
      description: '${formattedDate}  |  $place',
      openHours: formattedDate,
      phone: '',
      region: area,
      aiReason: isOngoing ? '지금 진행 중인 $realmName 행사예요' : '$realmName 특별 이벤트예요',
      tip: url.isNotEmpty ? '공식 페이지에서 예매 확인하세요' : '',
    );
  }

  /// 현재 진행 중인지
  bool get isOngoing {
    try {
      final now = DateTime.now();
      final todayStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      return startDate.compareTo(todayStr) <= 0 && endDate.compareTo(todayStr) >= 0;
    } catch (_) {
      return false;
    }
  }
}

// ─────────────────────────────────────────────
// 지역 코드 매핑
// ─────────────────────────────────────────────
const _areaCodeMap = {
  '서울': '11',
  '부산': '26',
  '대구': '27',
  '인천': '28',
  '광주': '29',
  '대전': '30',
  '울산': '31',
  '세종': '36',
  '경기': '41',
  '강원': '42',
  '충북': '43',
  '충남': '44',
  '전북': '45',
  '전남': '46',
  '경북': '47',
  '경남': '48',
  '제주': '50',
};

// 분야 코드 (realm)
const _realmCodeMap = {
  '전시':   'D000',
  '공연':   'A000',
  '연극':   'B000',
  '음악':   'C000',
  '뮤지컬': 'E000',
  '국악':   'F000',
  '축제':   'H000',
  '체험':   'I000',
};

class CulturalEventService {
  static const _baseUrl = 'https://apis.data.go.kr/B553457/cultureinfo';

  // ─────────────────────────────────────────────
  // 지역별 문화 이벤트 조회 (/area2)
  // ─────────────────────────────────────────────
  static Future<List<CulturalEvent>> fetchByArea({
    required String region,
    String? realmCode,   // null = 전체
    int rows = 10,
    int pageNo = 1,
    String? from,        // YYYYMMDD (null = 오늘)
    String? to,          // YYYYMMDD (null = 3개월 후)
  }) async {
    final areaCode = _resolveAreaCode(region);
    final fromDate = from ?? _todayStr();
    final toDate   = to   ?? _monthsLaterStr(3);

    final params = {
      'serviceKey': Env.culturePortalKey,
      'area':       areaCode,
      'from':       fromDate,
      'to':         toDate,
      'rows':       '$rows',
      'pageNo':     '$pageNo',
      if (realmCode != null) 'realmCode': realmCode,
    };

    return _fetch('/area2', params);
  }

  // ─────────────────────────────────────────────
  // 분야별 문화 이벤트 조회 (/realm2)
  // ─────────────────────────────────────────────
  static Future<List<CulturalEvent>> fetchByRealm({
    required String realmCode,
    String? region,
    int rows = 10,
    int pageNo = 1,
  }) async {
    final params = {
      'serviceKey': Env.culturePortalKey,
      'realmCode':  realmCode,
      'rows':       '$rows',
      'pageNo':     '$pageNo',
      if (region != null && region.isNotEmpty)
        'area': _resolveAreaCode(region),
    };

    return _fetch('/realm2', params);
  }

  // ─────────────────────────────────────────────
  // 홈 화면용: 지역 이벤트 5종 병렬 조회
  // 반환 Map 키: '진행중전시' | '공연·뮤지컬' | '축제·행사' | '체험클래스' | '전체이벤트'
  // ─────────────────────────────────────────────
  static Future<Map<String, List<CulturalEvent>>> fetchHomeEvents({
    required String region,
  }) async {
    final results = await Future.wait([
      fetchByRealm(realmCode: 'D000', region: region, rows: 8),   // 전시
      fetchByRealm(realmCode: 'A000', region: region, rows: 8),   // 공연
      fetchByRealm(realmCode: 'H000', region: region, rows: 8),   // 축제
      fetchByRealm(realmCode: 'I000', region: region, rows: 8),   // 체험
      fetchByArea(region: region, rows: 10),                       // 전체
    ]);

    return {
      '진행중·전시':   results[0],
      '공연·뮤지컬':  results[1],
      '축제·행사':    results[2],
      '체험·클래스':  results[3],
      '전체이벤트':   results[4],
    };
  }

  // ─────────────────────────────────────────────
  // 코스 슬롯용: PEAK 후보 이벤트 조회
  // (전시 + 공연 + 축제를 합쳐 최대 15개)
  // ─────────────────────────────────────────────
  static Future<List<CulturalEvent>> fetchPeakCandidates({
    required String region,
    required String mood,
  }) async {
    final realmCodes = _moodToRealmCodes(mood);
    final futures = realmCodes.map((code) =>
        fetchByRealm(realmCode: code, region: region, rows: 5));
    final results = await Future.wait(futures);

    final all = results.expand((r) => r).toList();

    // 진행 중인 것 우선 정렬
    all.sort((a, b) {
      if (a.isOngoing && !b.isOngoing) return -1;
      if (!a.isOngoing && b.isOngoing) return 1;
      return a.startDate.compareTo(b.startDate);
    });

    // 중복 제거 (seq 기준)
    final seen = <String>{};
    return all.where((e) => seen.add(e.seq)).take(15).toList();
  }

  // ─────────────────────────────────────────────
  // 내부: HTTP + XML 파싱
  // ─────────────────────────────────────────────
  static Future<List<CulturalEvent>> _fetch(
      String path, Map<String, String> params) async {
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: params);

    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return [];
      final body = utf8.decode(res.bodyBytes);
      return _parseXml(body);
    } catch (_) {
      return [];
    }
  }

  /// 경량 XML 파서 — xml 패키지 없이 String 기반으로 <item> 추출
  static List<CulturalEvent> _parseXml(String xml) {
    final events = <CulturalEvent>[];

    // 결과 코드 확인
    final resultCode = _tagValue(xml, 'resultCode');
    if (resultCode != null && resultCode != '00') return [];

    // <item> ... </item> 블록들 추출
    final itemPattern = RegExp(r'<item>([\s\S]*?)</item>');
    final matches = itemPattern.allMatches(xml);

    for (final m in matches) {
      final block = m.group(1) ?? '';
      final event = CulturalEvent(
        seq:        _tagValue(block, 'seq')        ?? '',
        title:      _clean(_tagValue(block, 'title')    ?? ''),
        place:      _clean(_tagValue(block, 'place')    ?? ''),
        area:       _tagValue(block, 'area')       ?? '',
        startDate:  _tagValue(block, 'startDate')  ?? '',
        endDate:    _tagValue(block, 'endDate')    ?? '',
        realmName:  _tagValue(block, 'realmName')  ?? '',
        thumbnail:  _tagValue(block, 'thumbnail')  ?? '',
        url:        _tagValue(block, 'url')        ?? '',
        price:      _clean(_tagValue(block, 'price')    ?? ''),
        description:_clean(_tagValue(block, 'contents') ?? ''),
      );
      if (event.title.isNotEmpty) events.add(event);
    }

    return events;
  }

  /// XML 태그 값 추출
  static String? _tagValue(String xml, String tag) {
    final pattern = RegExp('<$tag>([\\s\\S]*?)</$tag>');
    final match = pattern.firstMatch(xml);
    if (match == null) return null;
    return match.group(1)?.trim();
  }

  /// HTML 엔티티 + 태그 제거
  static String _clean(String s) => s
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&nbsp;', ' ')
      .trim();

  // ─────────────────────────────────────────────
  // 유틸
  // ─────────────────────────────────────────────

  /// 지역명 → 지역코드 (2자리)
  static String _resolveAreaCode(String region) {
    for (final entry in _areaCodeMap.entries) {
      if (region.contains(entry.key)) return entry.value;
    }
    return '11'; // 기본 서울
  }

  /// 분위기 → 관련 분야코드 목록
  static List<String> _moodToRealmCodes(String mood) {
    switch (mood) {
      case '감성':
        return ['D000', 'B000', 'E000']; // 전시, 연극, 뮤지컬
      case '액티비티':
        return ['I000', 'H000', 'A000']; // 체험, 행사, 공연
      case '힐링':
        return ['D000', 'F000', 'I000']; // 전시, 국악/무용, 체험
      default: // 혼합
        return ['D000', 'A000', 'H000']; // 전시, 공연, 축제
    }
  }

  static String _todayStr() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  }

  static String _monthsLaterStr(int months) {
    final later = DateTime.now().add(Duration(days: 30 * months));
    return '${later.year}${later.month.toString().padLeft(2, '0')}${later.day.toString().padLeft(2, '0')}';
  }
}

// ─────────────────────────────────────────────
// 지역 중심 좌표 폴백
// 문화포털 API는 좌표를 제공하지 않아 지역 중심 좌표를 사용
// Gemini 동선 최적화가 "좌표없음" 장소를 회피하는 문제 해결
// ─────────────────────────────────────────────
(double, double) _regionCenter(String area) {
  // area는 문화포털 응답의 지역명 (예: "서울", "경기", "부산" 등)
  const centers = <String, (double, double)>{
    '서울': (37.5665, 126.9780),
    '부산': (35.1796, 129.0756),
    '대구': (35.8714, 128.6014),
    '인천': (37.4563, 126.7052),
    '광주': (35.1595, 126.8526),
    '대전': (36.3504, 127.3845),
    '울산': (35.5384, 129.3114),
    '세종': (36.4801, 127.2890),
    '경기': (37.4138, 127.5183),
    '강원': (37.8228, 128.1555),
    '충북': (36.6358, 127.4913),
    '충남': (36.5184, 126.8000),
    '전북': (35.7175, 127.1530),
    '전남': (34.8679, 126.9910),
    '경북': (36.4919, 128.8889),
    '경남': (35.4606, 128.2132),
    '제주': (33.4996, 126.5312),
  };
  for (final entry in centers.entries) {
    if (area.contains(entry.key)) return entry.value;
  }
  return (37.5665, 126.9780); // 기본값: 서울 중심
}
