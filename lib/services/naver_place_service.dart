import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/env.dart';
import '../models/place_model.dart';
import 'kakao_place_service.dart';  // keyword + category search
import 'google_places_service.dart'; // nearby search

// ─────────────────────────────────────────────
// NaverPlaceService v2 — 데이트 아크 기반 리아키텍처
// OPEN(카페) → PEAK(경험/문화) → CLOSE(식사) 3슬롯
// 카테고리 오염 이중 필터링 탑재
// ─────────────────────────────────────────────

/// 카테고리별 대표 이미지 (Unsplash)
const _categoryImages = {
  '카페': [
    'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=800',
    'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=800',
    'https://images.unsplash.com/photo-1554118811-1e0d58224f24?w=800',
    'https://images.unsplash.com/photo-1442512595331-e89e73853f31?w=800',
    'https://images.unsplash.com/photo-1521017432531-fbd92d768814?w=800',
  ],
  '브런치': [
    'https://images.unsplash.com/photo-1550547660-d9450f859349?w=800',
    'https://images.unsplash.com/photo-1565299507177-b0ac66763828?w=800',
    'https://images.unsplash.com/photo-1482049016688-2d3e1b311543?w=800',
  ],
  '베이커리': [
    'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=800',
    'https://images.unsplash.com/photo-1555507036-ab1f4038808a?w=800',
    'https://images.unsplash.com/photo-1517433670267-08bbd4be890f?w=800',
  ],
  '디저트': [
    'https://images.unsplash.com/photo-1488477181946-6428a0291777?w=800',
    'https://images.unsplash.com/photo-1563729784474-d77dbb933a9e?w=800',
    'https://images.unsplash.com/photo-1551024506-0bccd828d307?w=800',
  ],
  '전시': [
    'https://images.unsplash.com/photo-1571115764595-644a1f56a55c?w=800',
    'https://images.unsplash.com/photo-1518998053901-5348d3961a04?w=800',
    'https://images.unsplash.com/photo-1545987796-200677ee1011?w=800',
    'https://images.unsplash.com/photo-1580136607897-5b4f2b3e9d1c?w=800',
  ],
  '공연': [
    'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=800',
    'https://images.unsplash.com/photo-1514320291840-2e0a9bf2a9ae?w=800',
    'https://images.unsplash.com/photo-1470229722913-7c0e2dbbafd3?w=800',
  ],
  '체험': [
    'https://images.unsplash.com/photo-1565793419680-e68d36703c72?w=800',
    'https://images.unsplash.com/photo-1516321497487-e288fb19713f?w=800',
    'https://images.unsplash.com/photo-1528360983277-13d401cdc186?w=800',
  ],
  '액티비티': [
    'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=800',
    'https://images.unsplash.com/photo-1502904550040-7534597429ae?w=800',
    'https://images.unsplash.com/photo-1526976668912-1a811878dd37?w=800',
  ],
  '한식': [
    'https://images.unsplash.com/photo-1580822184713-fc5400e7fe10?w=800',
    'https://images.unsplash.com/photo-1498654896293-37aacf113fd9?w=800',
    'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=800',
  ],
  '양식': [
    'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=800',
    'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=800',
    'https://images.unsplash.com/photo-1424847651672-bf20a4b0982b?w=800',
  ],
  '일식': [
    'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?w=800',
    'https://images.unsplash.com/photo-1617196034183-421b4040ed20?w=800',
    'https://images.unsplash.com/photo-1569050467447-ce54b3bbc37d?w=800',
  ],
  '파인다이닝': [
    'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=800',
    'https://images.unsplash.com/photo-1559339352-11d035aa65de?w=800',
    'https://images.unsplash.com/photo-1600891964092-4316c288032e?w=800',
  ],
  '야경': [
    'https://images.unsplash.com/photo-1477959858617-67f85cf4f1df?w=800',
    'https://images.unsplash.com/photo-1519567241046-7f570eee3ce6?w=800',
    'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800',
  ],
  '기본': [
    'https://images.unsplash.com/photo-1477959858617-67f85cf4f1df?w=800',
    'https://images.unsplash.com/photo-1519567241046-7f570eee3ce6?w=800',
    'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800',
  ],
};

// ─────────────────────────────────────────────
// 슬롯별 카테고리 오염 필터
// ─────────────────────────────────────────────

/// OPEN(카페) 슬롯 — 식당·공원 차단
const _cafeBlacklist = [
  '음식점', '식당', '레스토랑', '맛집', '고깃집', '삼겹살',
  '횟집', '순대', '공원', '산책', '방탈출', '볼링', '전시',
  '갤러리', '미술관', '박물관', '노래방', '술집', '바',
];

/// PEAK(경험) 슬롯 — 식당·카페·공원 차단
const _experienceBlacklist = [
  '음식점', '식당', '레스토랑', '맛집', '카페',
  '커피', '브런치', '케이크', '빵집', '베이커리',
  '고깃집', '삼겹살', '횟집', '술집', '바', '이자카야',
];

/// CLOSE(식사) 슬롯 — 카페·전시·공원·패스트푸드·체인 차단
const _mealBlacklist = [
  '카페', '커피', '브런치', '케이크', '마카롱', '디저트',
  '빵집', '베이커리', '전시', '갤러리', '미술관',
  '공원', '방탈출', '볼링', '체험', '노래방',
  // 업종 차단
  '패스트푸드', '패스트 푸드', '분식', '테이크아웃', '드라이브스루',
  // 브랜드 직접 차단
  '맥도날드', '버거킹', '롯데리아', 'kfc', '맘스터치', '파파이스',
  '서브웨이', '노브랜드버거', '빕스', '아웃백', '베니건스',
  '도미노', '피자헛', '파파존스', '미스터피자',
];

// ─────────────────────────────────────────────
// 2단계 카테고리 서브타입 정의
// ─────────────────────────────────────────────
enum DateSlot { open, peak, close }

/// 슬롯별 검색 쿼리 번들
class _SlotQuery {
  final String query;
  final String category;
  final String imageKey;
  const _SlotQuery(this.query, this.category, this.imageKey);
}

class NaverPlaceService {
  static const _baseUrl = 'https://openapi.naver.com/v1/search/local.json';

  static final _headers = {
    'X-Naver-Client-Id': Env.naverClientId,
    'X-Naver-Client-Secret': Env.naverClientSecret,
  };

  // ─────────────────────────────────────────────
  // 기본 검색
  // ─────────────────────────────────────────────
  static Future<List<Place>> search({
    required String region,
    required String keyword,
    required String category,
    String imageKey = '기본',
    int display = 5,
    int start = 1,
    List<String> blacklist = const [],
  }) async {
    final query = Uri.encodeComponent('$region $keyword'.trim());
    final uri = Uri.parse(
        '$_baseUrl?query=$query&display=${display.clamp(1, 5)}&start=$start&sort=comment');

    try {
      final res = await http.get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];

      final data = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final items = data['items'] as List? ?? [];

      final places = <Place>[];
      for (var i = 0; i < items.length; i++) {
        final item = items[i] as Map<String, dynamic>;
        // ── 카테고리 오염 필터 ──
        if (!_passFilter(item, blacklist)) continue;
        // ── 지역 오염 필터 (타지역 장소 차단) ──
        if (!_inRegion(item, region)) continue;

        final imgs = _categoryImages[imageKey] ?? _categoryImages['기본']!;
        final imageUrl = imgs[(start + i) % imgs.length];
        places.add(Place.fromNaverJson(
          item,
          category: category,
          region: region,
          imageUrl: imageUrl,
        ));
      }
      return places;
    } catch (_) {
      return [];
    }
  }

  /// 카테고리 오염 필터 — Naver 응답의 category 필드 검사
  static bool _passFilter(Map<String, dynamic> item, List<String> blacklist) {
    if (blacklist.isEmpty) return true;
    final rawCategory = (item['category'] as String? ?? '').toLowerCase();
    for (final bad in blacklist) {
      if (rawCategory.contains(bad)) return false;
    }
    return true;
  }

  // ── 지역 일치 필터 ───────────────────────────────────────────────
  // Naver 지역검색은 텍스트 매칭이라 키워드만 맞으면 타지역 장소도 섞인다
  // (비서울 지역에서 "엉뚱한 장소" 노출의 원인). 결과 주소가 요청 지역에
  // 실제로 속하는지 검사해 사후 차단한다.
  static const _metroCities = ['서울', '부산', '대구', '인천', '광주', '대전', '울산', '세종'];

  static String _guToken(String region) {
    for (final t in region.trim().split(RegExp(r'\s+'))) {
      if (t.endsWith('구') || t.endsWith('군')) return t;
    }
    return '';
  }

  static String _siToken(String region) {
    for (final t in region.trim().split(RegExp(r'\s+'))) {
      if (t.endsWith('시')) return t;
    }
    return '';
  }

  static String _cityToken(String region) {
    for (final c in _metroCities) {
      if (region.contains(c)) return c;
    }
    return '';
  }

  /// 결과 주소가 요청 지역과 일치하는지 — 광역시 + 구 토큰을 함께 검사해
  /// '중구·서구' 같은 흔한 구 이름의 타도시 충돌을 방지한다.
  static bool _inRegion(Map<String, dynamic> item, String region) {
    if (region.isEmpty) return true;
    final addr =
        '${item['roadAddress'] ?? ''} ${item['address'] ?? ''}'.trim();
    if (addr.isEmpty) return true; // 주소 없으면 보수적으로 통과

    final gu   = _guToken(region);
    final city = _cityToken(region);
    if (gu.isNotEmpty && !addr.contains(gu)) return false;
    if (city.isNotEmpty && !addr.contains(city)) return false;
    if (gu.isEmpty && city.isEmpty) {
      final si = _siToken(region);
      if (si.isNotEmpty && !addr.contains(si)) return false;
    }
    return true;
  }

  // ─────────────────────────────────────────────
  // 배치 검색 (4페이지 병렬 = 최대 20개)
  // ─────────────────────────────────────────────
  static Future<List<Place>> searchBatch({
    required String region,
    required String keyword,
    required String category,
    String imageKey = '기본',
    List<String> blacklist = const [],
    int count = 20,
    int fromStart = 1,
  }) async {
    const maxPerCall = 5;
    final numCalls = (count / maxPerCall).ceil().clamp(1, 8);
    final futures = List.generate(numCalls, (i) => search(
      region: region,
      keyword: keyword,
      category: category,
      imageKey: imageKey,
      blacklist: blacklist,
      display: maxPerCall,
      start: fromStart + i * maxPerCall,
    ));
    final results = await Future.wait(futures);
    return _dedupeList(results.expand((r) => r).toList());
  }

  // ─────────────────────────────────────────────
  // 홈 화면 데이터 — 5섹션 × 10개 (v2 세분화)
  // ─────────────────────────────────────────────
  static Future<Map<String, List<Place>>> fetchHomeData(String region) async {
    final r = _simplifyRegion(region);
    final results = await Future.wait([
      // ① 카페 & 브런치
      searchBatch(region: r, keyword: '감성 카페 인스타 핫플', category: '카페', imageKey: '카페', blacklist: _cafeBlacklist, count: 5),
      searchBatch(region: r, keyword: '브런치 카페 베이커리', category: '카페', imageKey: '브런치', blacklist: _cafeBlacklist, count: 5),
      // ② 전시 & 문화 (오염 강력 차단)
      searchBatch(region: r, keyword: '전시회 갤러리 미술관', category: '전시·문화', imageKey: '전시', blacklist: _experienceBlacklist, count: 5),
      searchBatch(region: r, keyword: '복합문화공간 전시 팝업', category: '전시·문화', imageKey: '전시', blacklist: _experienceBlacklist, count: 5),
      // ③ 공연 & 체험
      searchBatch(region: r, keyword: '체험 클래스 도예 공예', category: '체험·클래스', imageKey: '체험', blacklist: _experienceBlacklist, count: 5),
      searchBatch(region: r, keyword: '방탈출 보드게임 카페 커플', category: '액티비티', imageKey: '액티비티', blacklist: _cafeBlacklist, count: 5),
      // ④ 맛집 (카테고리별)
      searchBatch(region: r, keyword: '한식 한정식 맛집', category: '맛집', imageKey: '한식', blacklist: _mealBlacklist, count: 5),
      searchBatch(region: r, keyword: '이탈리안 파스타 양식 레스토랑', category: '맛집', imageKey: '양식', blacklist: _mealBlacklist, count: 5),
      // ⑤ 야경 & 뷰맛집
      searchBatch(region: r, keyword: '야경 루프탑 뷰맛집', category: '야경·뷰', imageKey: '야경', count: 5),
      searchBatch(region: r, keyword: '한강 야경 뷰포인트', category: '야경·뷰', imageKey: '야경', count: 5),
    ]);

    // 결과 병합 + 폴백 (지역 유지 — 빈 region으로 검색하면 서울 결과가 반환됨)
    Future<List<Place>> merge(int a, int b, String fallbackQ, String cat, String imgKey, List<String> bl) async {
      var list = _dedupeList([...results[a], ...results[b]]);
      if (list.isEmpty) list = await searchBatch(region: r, keyword: fallbackQ, category: cat, imageKey: imgKey, blacklist: bl, count: 10);
      return list;
    }

    return {
      '카페·브런치':    await merge(0, 1, '감성 카페 브런치', '카페', '카페', _cafeBlacklist),
      '전시·문화':     await merge(2, 3, '전시 갤러리 미술관', '전시·문화', '전시', _experienceBlacklist),
      '체험·액티비티':  await merge(4, 5, '체험 클래스 방탈출', '체험', '체험', _experienceBlacklist),
      '맛집':          await merge(6, 7, '분위기 좋은 레스토랑', '맛집', '양식', _mealBlacklist),
      '야경·뷰':       await merge(8, 9, '야경 루프탑 명소', '야경·뷰', '야경', const []),
    };
  }

  // ─────────────────────────────────────────────
  // 데이트 아크 슬롯 fetch — OPEN → PEAK → CLOSE
  // ─────────────────────────────────────────────
  static Future<Map<String, List<Place>>> fetchForCourseSlots({
    required String region,
    required String mood,
    required String specialDay,
    required String timeSlot,
    required String transport,
    required String budget,
    double lat = 0.0,  // GPS 좌표 (Kakao 카테고리 검색용)
    double lng = 0.0,
  }) async {
    final r = _simplifyRegion(region);
    final isEvening = timeSlot == '저녁' || timeSlot == '하루종일';
    final isLuxury  = budget == '고급';
    final isCar     = transport == '차량';

    // ── OPEN 슬롯: 카페·브런치 다양화 (7-8개 쿼리) ──
    final openQueries = <_SlotQuery>[
      const _SlotQuery('감성 카페 인스타 핫플', '카페', '카페'),
      const _SlotQuery('브런치 카페 커플 데이트', '카페', '브런치'),
      const _SlotQuery('루프탑 카페 뷰맛집', '카페', '카페'),
      const _SlotQuery('대형 카페 분위기 좋은', '카페', '카페'),
      const _SlotQuery('베이커리 디저트 카페', '카페', '베이커리'),
      const _SlotQuery('한옥 감성 카페 전통', '카페', '카페'),
      const _SlotQuery('북카페 독립서점 감성', '카페', '카페'),
    ];
    if (isEvening) {
      openQueries.add(const _SlotQuery('야경 뷰 카페 저녁', '카페', '카페'));
    } else {
      openQueries.add(const _SlotQuery('아침 브런치 카페 샌드위치', '카페', '브런치'));
    }

    // ── PEAK 슬롯: 분위기·특별한 날 기반 (7-10개 쿼리) ──
    // 공통 베이스 (모든 케이스에 추가)
    final peakBase = <_SlotQuery>[
      const _SlotQuery('팝업스토어 복합문화공간 전시', '전시·문화', '전시'),
      const _SlotQuery('미술관 갤러리 현대미술', '전시·문화', '전시'),
    ];

    final peakQueries = <_SlotQuery>[];
    switch (specialDay) {
      case '기념일':
        peakQueries.addAll([
          const _SlotQuery('전시 갤러리 기념일 감성', '전시·문화', '전시'),
          const _SlotQuery('공연 뮤지컬 연극 커플', '공연', '공연'),
          const _SlotQuery('체험 클래스 도예 커플', '체험·클래스', '체험'),
          const _SlotQuery('포토스튜디오 커플사진 셀프', '체험·클래스', '체험'),
          const _SlotQuery('야경 뷰포인트 드라이브', '야외', '야경'),
        ]);
      case '첫만남':
        peakQueries.addAll([
          const _SlotQuery('갤러리 전시 대화하기 좋은', '전시·문화', '전시'),
          const _SlotQuery('팝업스토어 트렌디 전시', '문화', '전시'),
          const _SlotQuery('보드게임카페 방탈출 커플', '액티비티', '액티비티'),
          const _SlotQuery('볼링 실내 오락 데이트', '액티비티', '액티비티'),
          const _SlotQuery('플라워 공예 클래스 체험', '체험·클래스', '체험'),
        ]);
      default:
        switch (mood) {
          case '액티비티':
            peakQueries.addAll([
              const _SlotQuery('방탈출 카페 커플 인기', '액티비티', '액티비티'),
              const _SlotQuery('볼링 실내 오락 스포츠', '액티비티', '액티비티'),
              const _SlotQuery('클라이밍 짚라인 익스트림', '액티비티', '체험'),
              const _SlotQuery('보드게임 오락 실내 게임', '액티비티', '액티비티'),
              const _SlotQuery('VR 가상현실 체험 첨단', '액티비티', '체험'),
              const _SlotQuery('사격 당구 실내 스포츠', '액티비티', '액티비티'),
            ]);
          case '힐링':
            peakQueries.addAll([
              const _SlotQuery('전시 갤러리 조용한 힐링', '전시·문화', '전시'),
              const _SlotQuery('도예 공예 체험 클래스', '체험·클래스', '체험'),
              const _SlotQuery('향수 플라워 클래스 만들기', '체험·클래스', '체험'),
              const _SlotQuery('공원 산책 자연 정원', '야외', '야경'),
              const _SlotQuery('독서 북카페 힐링 조용한', '문화', '전시'),
              const _SlotQuery('캔들 테라리움 DIY 공방', '체험·클래스', '체험'),
            ]);
          case '감성':
            peakQueries.addAll([
              const _SlotQuery('전시회 갤러리 감성 아트', '전시·문화', '전시'),
              const _SlotQuery('복합문화공간 감성 핫플', '문화', '전시'),
              const _SlotQuery('포토스팟 인스타 사진 명소', '문화', '전시'),
              const _SlotQuery('뮤지컬 소극장 공연 감성', '공연', '공연'),
              const _SlotQuery('필름 사진 암실 체험', '체험·클래스', '체험'),
              const _SlotQuery('조향 향수 클래스 감성', '체험·클래스', '체험'),
            ]);
          default: // 혼합
            peakQueries.addAll([
              const _SlotQuery('전시 갤러리 미술관 인기', '전시·문화', '전시'),
              const _SlotQuery('팝업 문화공간 복합 트렌디', '문화', '전시'),
              const _SlotQuery('체험 클래스 공방 만들기', '체험·클래스', '체험'),
              const _SlotQuery('방탈출 보드게임 실내 오락', '액티비티', '액티비티'),
              const _SlotQuery('공연 뮤지컬 소극장', '공연', '공연'),
            ]);
        }
    }
    peakQueries.addAll(peakBase);
    if (isCar) {
      peakQueries.add(const _SlotQuery('드라이브 야외 뷰포인트 명소', '야외', '야경'));
    }

    // ── CLOSE 슬롯: 식사 다양화 (6-8개 쿼리) ─────────
    final closeQueries = <_SlotQuery>[];
    if (isEvening && isLuxury) {
      closeQueries.addAll([
        const _SlotQuery('파인다이닝 코스요리 레스토랑', '맛집', '파인다이닝'),
        const _SlotQuery('오마카세 고급 일식 코스', '맛집', '일식'),
        const _SlotQuery('야경 루프탑 레스토랑 고급', '맛집', '파인다이닝'),
        const _SlotQuery('스테이크 와인 파인 다이닝', '맛집', '파인다이닝'),
        const _SlotQuery('미슐랭 가이드 레스토랑 서울', '맛집', '파인다이닝'),
      ]);
    } else if (isEvening) {
      closeQueries.addAll([
        const _SlotQuery('분위기 좋은 저녁 레스토랑', '맛집', '양식'),
        const _SlotQuery('야경 뷰맛집 저녁 레스토랑', '맛집', '야경'),
        const _SlotQuery('이자카야 일식 이자카야 저녁', '맛집', '일식'),
        const _SlotQuery('와인바 칵테일 바 커플', '맛집', '양식'),
        const _SlotQuery('라멘 우동 일식 분위기', '맛집', '일식'),
        const _SlotQuery('피자 파스타 이탈리안 저녁', '맛집', '양식'),
      ]);
    } else {
      // 낮/점심
      closeQueries.addAll([
        const _SlotQuery('분위기 좋은 점심 레스토랑', '맛집', '양식'),
        const _SlotQuery('한식 한정식 점심 맛집', '맛집', '한식'),
        const _SlotQuery('이탈리안 파스타 피자 점심', '맛집', '양식'),
        const _SlotQuery('덮밥 돈카츠 일식 점심', '맛집', '일식'),
        const _SlotQuery('샐러드 건강식 브런치 레스토랑', '맛집', '양식'),
        const _SlotQuery('곱창 순대국 로컬 맛집', '맛집', '한식'),
      ]);
    }

    // mood/specialDay별 식사 추가
    switch (mood) {
      case '감성':
        closeQueries.add(const _SlotQuery('감성 레스토랑 이탈리안 분위기', '맛집', '양식'));
      case '힐링':
        closeQueries.add(const _SlotQuery('자연 건강식 샐러드 채식 레스토랑', '맛집', '한식'));
      case '액티비티':
        closeQueries.add(const _SlotQuery('고기집 삼겹살 소고기 구이', '맛집', '한식'));
    }
    if (specialDay == '기념일') {
      closeQueries.insert(0, const _SlotQuery('기념일 코스 레스토랑 스테이크', '맛집', '파인다이닝'));
    }

    // ── 모두 병렬 실행 — 쿼리당 2페이지(10개) 병렬 수집 ──────────────
    // searchBatch(count:10) = display:5로 start=1, start=6 두 번 → 쿼리당 최대 10개
    final allQueries = [...openQueries, ...peakQueries, ...closeQueries];
    final allResults = await Future.wait(
      allQueries.map((q) => searchBatch(
        region: r,
        keyword: q.query,
        category: q.category,
        imageKey: q.imageKey,
        blacklist: _slotBlacklist(q.category),
        count: 10,   // ← 쿼리당 10개 (2페이지 병렬)
      )),
    );

    final ol = openQueries.length;
    final pl = peakQueries.length;

    var naverOpen  = _dedupeList(allResults.sublist(0, ol).expand((e) => e).toList());
    var naverPeak  = _dedupeList(allResults.sublist(ol, ol + pl).expand((e) => e).toList());
    var naverClose = _dedupeList(allResults.sublist(ol + pl).expand((e) => e).toList());

    // ── Kakao 병렬 호출 (Naver와 동시 실행하지 않고 후속 호출 — 슬롯 부족 보완) ──
    // Naver 결과 + Kakao 결과를 합산 → 라운드로빈 파티셔닝 효과 극대화
    Map<String, List<Place>> kakaoSlots = {'start': [], 'main': [], 'finish': []};
    try {
      kakaoSlots = await KakaoPlaceService.fetchForCourseSlots(
        region: r,
        mood: mood,
        specialDay: specialDay,
        timeSlot: timeSlot,
        transport: transport,
        budget: budget,
      );
    } catch (_) {
      // Kakao 실패 시 Naver만으로 진행
    }

    // ── Kakao 다중반경(1+3+5km auto) + Google Nearby — 슬롯별 풀 대폭 확보 ──
    List<Place> kakaoCatOpen  = [];
    List<Place> kakaoCatPeak  = [];
    List<Place> kakaoCatClose = [];
    List<Place> googleOpen    = [];
    List<Place> googlePeak    = [];
    List<Place> googleClose   = [];
    if (lat != 0.0 && lng != 0.0) {
      try {
        // Kakao 다중반경 (1+3km, 결과 15개 미만 시 자동 5km)
        final kakaoResults = await Future.wait([
          KakaoPlaceService.searchByMultiRadius(
            lat: lat, lng: lng,
            categoryCode: KakaoPlaceService.catCafe,
            category: '카페', imageKey: '카페',
            blacklist: _cafeBlacklist,
          ),
          KakaoPlaceService.searchByMultiRadius(
            lat: lat, lng: lng,
            categoryCode: KakaoPlaceService.catCulture,
            category: '전시·문화', imageKey: '전시',
            blacklist: _experienceBlacklist,
          ),
          KakaoPlaceService.searchByMultiRadius(
            lat: lat, lng: lng,
            categoryCode: KakaoPlaceService.catAttr,
            category: '체험·액티비티', imageKey: '체험',
            blacklist: _experienceBlacklist,
          ),
          KakaoPlaceService.searchByMultiRadius(
            lat: lat, lng: lng,
            categoryCode: KakaoPlaceService.catFood,
            category: '맛집', imageKey: '양식',
            blacklist: _mealBlacklist,
          ),
        ]);
        kakaoCatOpen  = kakaoResults[0];
        kakaoCatPeak  = _dedupeList([...kakaoResults[1], ...kakaoResults[2]]);
        kakaoCatClose = kakaoResults[3];

        // Google Nearby — 슬롯별 추가 (반경 2.5km)
        final googleResults = await Future.wait([
          GooglePlacesService.searchNearbyMulti(
            lat: lat, lng: lng, category: '카페·브런치', radius: 2500),
          GooglePlacesService.searchNearbyMulti(
            lat: lat, lng: lng, category: '전시·문화', radius: 3000),
          GooglePlacesService.searchNearbyMulti(
            lat: lat, lng: lng, category: '체험·액티비티', radius: 3000),
          GooglePlacesService.searchNearbyMulti(
            lat: lat, lng: lng, category: '맛집', radius: 2500),
        ]);
        googleOpen  = googleResults[0];
        googlePeak  = _dedupeList([...googleResults[1], ...googleResults[2]]);
        googleClose = googleResults[3];
      } catch (_) {}
    }

    // ── 합산: Naver + Kakao keyword + Kakao 다중반경 + Google Nearby → 중복제거 ──
    var openPlaces  = _dedupeList([...naverOpen,  ...(kakaoSlots['start']  ?? []), ...kakaoCatOpen,  ...googleOpen]);
    var peakPlaces  = _dedupeList([...naverPeak,  ...(kakaoSlots['main']   ?? []), ...kakaoCatPeak,  ...googlePeak]);
    var closePlaces = _dedupeList([...naverClose, ...(kakaoSlots['finish'] ?? []), ...kakaoCatClose, ...googleClose]);

    // 슬롯 폴백 (Naver + Kakao 합쳐도 비면) — region 유지로 타 지역 오염 방지
    if (openPlaces.isEmpty) {
      openPlaces = await searchBatch(region: r, keyword: '감성 카페 인기', category: '카페', imageKey: '카페', blacklist: _cafeBlacklist, count: 10);
    }
    if (peakPlaces.isEmpty) {
      final fallback = mood == '액티비티' ? '방탈출 볼링 커플' : '전시 갤러리 문화';
      peakPlaces = await searchBatch(region: r, keyword: fallback, category: '문화', imageKey: '전시', blacklist: _experienceBlacklist, count: 10);
    }
    if (closePlaces.isEmpty) {
      final fallback = isEvening ? '분위기 저녁 레스토랑' : '점심 맛집 레스토랑';
      closePlaces = await searchBatch(region: r, keyword: fallback, category: '맛집', imageKey: '양식', blacklist: _mealBlacklist, count: 10);
    }

    return {
      'start':  openPlaces,   // OPEN  — 카페/브런치 (Naver + Kakao 합산)
      'main':   peakPlaces,   // PEAK  — 전시/체험/공연 (Naver + Kakao 합산)
      'finish': closePlaces,  // CLOSE — 식사 (Naver + Kakao 합산)
    };
  }

  /// 카테고리에 따른 블랙리스트 선택
  static List<String> _slotBlacklist(String category) {
    if (category.contains('카페') || category.contains('브런치') || category.contains('베이커리') || category.contains('디저트')) {
      return _cafeBlacklist;
    }
    if (category.contains('맛집') || category.contains('레스토랑') || category.contains('한식') || category.contains('양식') || category.contains('일식') || category.contains('파인다이닝')) {
      return _mealBlacklist;
    }
    if (category.contains('전시') || category.contains('문화') || category.contains('공연') || category.contains('체험') || category.contains('액티비티')) {
      return _experienceBlacklist;
    }
    return const [];
  }

  // ─────────────────────────────────────────────
  // 지역명 전처리: 동 수준 → 시/구 수준으로
  // ─────────────────────────────────────────────
  static String _simplifyRegion(String region) {
    if (region.isEmpty) return region;
    final tokens = region.trim().split(RegExp(r'\s+'));
    final keep = <String>[];
    for (final t in tokens) {
      keep.add(t);
      if (t.endsWith('시') || t.endsWith('구') || t.endsWith('군')) {
        if (keep.length >= 2) break;
      }
    }
    return keep.take(3).join(' ');
  }

  // ─────────────────────────────────────────────
  // 중복 제거
  // ─────────────────────────────────────────────
  static List<Place> _dedupeList(List<Place> places) {
    final seen = <String>{};
    return places.where((p) => seen.add(p.id)).toList();
  }
}
