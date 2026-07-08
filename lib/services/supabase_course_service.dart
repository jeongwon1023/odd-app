// ─────────────────────────────────────────────
// SupabaseCourseService — 큐레이션 DB 코스 조회
// ─────────────────────────────────────────────
// Q1: address 없을 때 city 힌트 자동 보충 → Google Photo 매칭 정확도 개선
// Q2: _seenIds 세션 캐시 → 재생성 시 이미 본 코스 자동 제외
// Q3: _titleToId 맵 + incrementSaveCount / incrementViewCount → Supabase 카운터 동기화

import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../config/env.dart';
import '../models/place_model.dart';

class SupabaseCourseService {
  static const _base = '${Env.supabaseUrl}/rest/v1';
  static const _hdrs = {
    'apikey': Env.supabaseAnonKey,
    'Authorization': 'Bearer ${Env.supabaseAnonKey}',
  };
  static const _patchHdrs = {
    'apikey': Env.supabaseAnonKey,
    'Authorization': 'Bearer ${Env.supabaseAnonKey}',
    'Content-Type': 'application/json',
    'Prefer': 'return=minimal',
  };

  // ── 데이트 부적합 장소 블랙리스트 ───────────
  static const List<String> _dateBlacklist = [
    '사원', '교회', '성당', '절', '불교', '이슬람', '종교',
    '관공서', '주민센터', '시청', '구청', '동사무소', '공공',
    '병원', '의원', '약국', '응급', '산부인과',
    '보리밥', '국밥', '해장국', '순대국', '곱창',
    '장례', '세탁', '은행', '우체국', '학원',
  ];

  static bool _isBlacklisted(String name, String cat) {
    final n = name.toLowerCase();
    final c = cat.toLowerCase();
    return _dateBlacklist.any((b) => n.contains(b) || c.contains(b));
  }

  // ── Q2: 세션 내 이미 본 코스 ID ─────────────
  static final Set<String> _seenIds = {};

  // ── Q3: title → DB UUID 맵 ─────────────────
  static final Map<String, String> _titleToId = {};

  /// 새 대화 시작 시 세션 초기화
  static void resetSession() {
    _seenIds.clear();
    _titleToId.clear();
  }

  // ── mood → archetype 매핑 ──────────────────
  static String? _archetype(String mood) => switch (mood) {
    '감성 로맨스' || '감성'       => '감성 로맨스',
    '액티비티'                    => '액티비티 챌린지',
    '힐링'                        => '로컬 힐링',
    '야경 데이트' || '야경'       => '야경 데이트',
    '미식 투어'   || '미식'       => '미식 투어',
    '자연 힐링'   || '자연'       => '자연 힐링',
    '힙스터 컬처'                 => '힙스터 컬처',
    '럭셔리 스페셜'               => '럭셔리 스페셜',
    '인스타 포토'                 => '인스타 포토',
    _                             => null,
  };

  // ── 광역시/도 → 짧은 city명 ────────────────
  static String _shortCity(String city) {
    if (city.contains('서울')) return '서울';
    if (city.contains('대전')) return '대전';
    if (city.contains('부산')) return '부산';
    if (city.contains('대구')) return '대구';
    if (city.contains('인천')) return '인천';
    if (city.contains('광주')) return '광주';
    if (city.contains('울산')) return '울산';
    if (city.contains('세종')) return '세종';
    if (city.contains('경기')) return '경기';
    if (city.contains('강원')) return '강원';
    if (city.contains('충북') || city.contains('충청북')) return '충북';
    if (city.contains('충남') || city.contains('충청남')) return '충남';
    if (city.contains('전북') || city.contains('전라북')) return '전북';
    if (city.contains('전남') || city.contains('전라남')) return '전남';
    if (city.contains('경북') || city.contains('경상북')) return '경북';
    if (city.contains('경남') || city.contains('경상남')) return '경남';
    if (city.contains('제주')) return '제주';
    // 그 외 일반 시(전주시·경주시·춘천시 등) — 행정구역 접미사를 제거해
    // DB에 저장된 짧은 city명(전주·경주…)과 매칭. 미제거 시 'eq.전주시'로 조회돼
    // 업로드된 비서울 코스를 못 찾는 버그 발생.
    return city
        .replaceAll(RegExp(r'(특별|광역|특별자치)(시|도)$'), '')
        .replaceAll(RegExp(r'(시|군)$'), '')
        .trim();
  }

  /// DB에서 코스 조회.
  /// 반환값이 ≥ 3이면 DB 코스 사용, 미만이면 Gemini 폴백.
  static Future<List<DateCourse>> fetchCourses({
    required String city,
    required String mood,
    String budget = '보통',
    String timeSlot = '낮',
    int limit = 20,
  }) async {
    final short = _shortCity(city);
    final arch  = _archetype(mood);

    final params = <String, String>{
      'is_active': 'eq.true',
      'city': 'eq.$short',
      'select': '*',
      'limit': '$limit',
      'order': 'quality_score.desc.nullslast,save_count.desc',
    };

    if (arch != null) params['archetype'] = 'eq.$arch';
    if (budget == '저렴') params['budget_level'] = 'eq.1';
    if (budget == '고급') params['budget_level'] = 'eq.3';
    if (timeSlot == '저녁' || mood == '야경 데이트') {
      params['time_slot'] = 'in.(저녁,야간)';
    }

    // Q2: 이미 본 코스 제외 (Supabase not=in 필터)
    if (_seenIds.isNotEmpty) {
      params['id'] = 'not.in.(${_seenIds.join(',')})';
    }

    final uri = Uri.parse('$_base/curated_courses')
        .replace(queryParameters: params);

    try {
      final res = await http
          .get(uri, headers: _hdrs)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return [];

      final rows = jsonDecode(res.body) as List;
      if (rows.isEmpty) return [];

      // 셔플 후 최대 3개 변환
      final pool = List<Map<String, dynamic>>.from(rows)..shuffle(Random());
      final courses = pool
          .map((r) => _toCourse(r, mood, short))
          .whereType<DateCourse>()
          .take(3)
          .toList();

      // Q2: 이번에 본 코스 ID를 세션 캐시에 추가
      for (final r in pool.take(courses.length)) {
        final id = r['id']?.toString();
        if (id != null) _seenIds.add(id);
      }

      return courses;
    } catch (_) {
      return [];
    }
  }

  /// 키워드 검색 — title/description/neighborhood/district ilike
  static Future<List<DateCourse>> searchCourses({
    required String query,
    String city = '',
    int limit = 20,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final short = city.isNotEmpty ? _shortCity(city) : '';
    final orFilter =
        '(title.ilike.*$q*,description.ilike.*$q*,neighborhood.ilike.*$q*,district.ilike.*$q*)';
    final params = <String, String>{
      'is_active': 'eq.true',
      'select': '*',
      'limit': '$limit',
      'order': 'quality_score.desc.nullslast,save_count.desc',
      'or': orFilter,
    };
    if (short.isNotEmpty) params['city'] = 'eq.$short';

    final uri = Uri.parse('$_base/curated_courses')
        .replace(queryParameters: params);
    try {
      final res = await http
          .get(uri, headers: _hdrs)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return [];
      final rows = jsonDecode(res.body) as List;
      final displayCity = short.isNotEmpty ? short : '전국';
      return rows
          .map((r) => _toCourse(r, '', displayCity))
          .whereType<DateCourse>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── row → DateCourse 변환 ─────────────────
  static DateCourse? _toCourse(
      Map<String, dynamic> r, String mood, String city) {
    try {
      final id        = r['id']?.toString() ?? '';
      final openName  = r['open_name']  as String? ?? '';
      final peakName  = r['peak_name']  as String? ?? '';
      final closeName = r['close_name'] as String? ?? '';
      if (openName.isEmpty || peakName.isEmpty || closeName.isEmpty) return null;

      // 데이트 부적합 장소가 하나라도 포함되면 코스 전체 제외
      final openCat  = r['open_category']  as String? ?? '';
      final peakCat  = r['peak_category']  as String? ?? '';
      final closeCat = r['close_category'] as String? ?? '';
      if (_isBlacklisted(openName, openCat) ||
          _isBlacklisted(peakName, peakCat) ||
          _isBlacklisted(closeName, closeCat)) return null;

      // Q1: 주소 없을 때 city를 힌트로 보충 → Google Photo 검색 정확도 개선
      String addrHint(String prefix) {
        final addr = r['${prefix}_address'] as String? ?? '';
        return addr.isNotEmpty ? addr : city;
      }

      Place slot(String prefix, String defaultCat, int dur) => Place(
        id:          r['${prefix}_id'] as String? ?? 'db_${prefix}_$id',
        name:        r['${prefix}_name'] as String? ?? '',
        category:    r['${prefix}_category'] as String? ?? defaultCat,
        subcategory: r['${prefix}_category'] as String? ?? defaultCat,
        tags:        [defaultCat, '데이트'],
        address:     addrHint(prefix),  // Q1: city 힌트 포함
        lat:         (r['${prefix}_lat'] as num? ?? 0).toDouble(),
        lng:         (r['${prefix}_lng'] as num? ?? 0).toDouble(),
        rating:      4.3,
        priceRange:  '보통',
        duration:    dur,
        imageUrl:    '',
        description: '',
        openHours:   '',
        phone:       '',
        region:      r['city'] as String? ?? city,
        tip:         r['${prefix}_tip'] as String? ?? '',
      );

      final title = r['title'] as String? ?? '${r['archetype']} 코스';

      // Q3: title → DB UUID 역색인
      if (id.isNotEmpty) _titleToId[title] = id;

      return DateCourse(
        title:         title,
        concept:       r['archetype'] as String? ?? '',
        mood:          mood,
        description:   r['description'] as String? ?? '',
        places: [
          slot('open',  '카페',   60),
          slot('peak',  '체험',   90),
          slot('close', '맛집',   90),
        ],
        totalDuration: 240,
      );
    } catch (_) {
      return null;
    }
  }

  /// 홈 화면용 — 무드 무관, 도시 기준 상위 코스 조회
  /// [preferredTimeSlot]: '낮' | '저녁' | '야간' — null이면 전체
  /// [preferredBudget]:   1(저렴) | 2(보통) | 3(고급) — null이면 전체
  static Future<List<DateCourse>> fetchTopCourses({
    required String city,
    String? preferredTimeSlot,
    int? preferredBudget,
    int limit = 10,
  }) async {
    final short = _shortCity(city);

    // ① 조건 있는 1차 쿼리
    Future<List> _query({bool filtered = true}) async {
      final params = <String, String>{
        'is_active': 'eq.true',
        'city':      'eq.$short',
        'select':    '*',
        'limit':     '$limit',
        'order':     'quality_score.desc.nullslast,save_count.desc',
      };
      if (filtered) {
        // 시간대 필터 — 야간이면 저녁·야간 모두 포함
        if (preferredTimeSlot != null) {
          params['time_slot'] = preferredTimeSlot == '야간'
              ? 'in.(저녁,야간)'
              : 'eq.$preferredTimeSlot';
        }
        // 예산 필터 (1·3만 제한, 2=보통은 전체 포함)
        if (preferredBudget == 1) params['budget_level'] = 'eq.1';
        if (preferredBudget == 3) params['budget_level'] = 'eq.3';
      }
      final uri = Uri.parse('$_base/curated_courses').replace(queryParameters: params);
      final res = await http.get(uri, headers: _hdrs).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return [];
      return jsonDecode(res.body) as List;
    }

    try {
      var rows = await _query(filtered: true);
      // 결과 부족 시 필터 없이 재시도 (폴백)
      if (rows.length < 3) rows = await _query(filtered: false);
      if (rows.isEmpty) return [];

      final pool = List<Map<String, dynamic>>.from(rows)..shuffle(Random());
      return pool
          .map((r) => _toCourse(r, r['archetype'] as String? ?? '감성 로맨스', short))
          .whereType<DateCourse>()
          .take(limit)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// 인기 코스 — save_count 기준 상위 코스
  static Future<List<DateCourse>> fetchPopularCourses({
    required String city,
    int limit = 8,
  }) async {
    final short = _shortCity(city);
    final params = <String, String>{
      'is_active': 'eq.true',
      'city':      'eq.$short',
      'select':    '*',
      'limit':     '$limit',
      'order':     'save_count.desc,view_count.desc',
    };
    final uri = Uri.parse('$_base/curated_courses').replace(queryParameters: params);
    try {
      final res = await http.get(uri, headers: _hdrs).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return [];
      final rows = jsonDecode(res.body) as List;
      return List<Map<String, dynamic>>.from(rows)
          .map((r) => _toCourse(r, r['archetype'] as String? ?? '감성 로맨스', short))
          .whereType<DateCourse>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// 특별한 날 코스 — 럭셔리·야경·감성 로맨스 아키타입 우선
  static Future<List<DateCourse>> fetchSpecialDayCourses({
    required String city,
    int limit = 6,
  }) async {
    final short = _shortCity(city);
    final params = <String, String>{
      'is_active': 'eq.true',
      'city':      'eq.$short',
      'archetype': 'in.(럭셔리 스페셜,야경 데이트,감성 로맨스)',
      'select':    '*',
      'limit':     '$limit',
      'order':     'quality_score.desc,save_count.desc',
    };
    final uri = Uri.parse('$_base/curated_courses').replace(queryParameters: params);
    try {
      final res = await http.get(uri, headers: _hdrs).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return [];
      final rows = jsonDecode(res.body) as List;
      final pool = List<Map<String, dynamic>>.from(rows)..shuffle(Random());
      return pool
          .map((r) => _toCourse(r, r['archetype'] as String? ?? '감성 로맨스', short))
          .whereType<DateCourse>()
          .take(limit)
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Q3: save_count / view_count 증가 ────────
  /// 코스 저장 시 호출 — save_count +1
  static Future<void> incrementSaveCount(String courseTitle) async {
    final id = _titleToId[courseTitle];
    if (id == null) return;
    await _incrementField(id, 'save_count');
  }

  /// 코스 노출 시 호출 — view_count +1
  static Future<void> incrementViewCount(String courseTitle) async {
    final id = _titleToId[courseTitle];
    if (id == null) return;
    await _incrementField(id, 'view_count');
  }

  static Future<void> _incrementField(String id, String field) async {
    try {
      // 1. 현재 값 조회
      final getRes = await http.get(
        Uri.parse('$_base/curated_courses?id=eq.$id&select=$field'),
        headers: _hdrs,
      ).timeout(const Duration(seconds: 3));
      if (getRes.statusCode != 200) return;

      final rows = jsonDecode(getRes.body) as List;
      if (rows.isEmpty) return;
      final current = (rows.first[field] as num? ?? 0).toInt();

      // 2. +1 업데이트
      await http.patch(
        Uri.parse('$_base/curated_courses?id=eq.$id'),
        headers: _patchHdrs,
        body: jsonEncode({field: current + 1}),
      ).timeout(const Duration(seconds: 3));
    } catch (_) {}
  }
}
