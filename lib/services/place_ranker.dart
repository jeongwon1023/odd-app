// ─────────────────────────────────────────────────────────────────────────
// PlaceRanker v2 — 6-Factor Composite Scoring Engine
//
// 리서치 기반 (Yelp · TripAdvisor · Google Maps · Foursquare · Netflix):
//
// finalScore = Σ(factor × weight)
//
//   ① bayesianScore   × 0.30  — TripAdvisor 방식: 리뷰 수 보정 별점 신뢰도
//   ② reviewVelocity  × 0.12  — Yelp 방식: 최신 리뷰 활성도 (리뷰수 기반 추정)
//   ③ timeSlotBonus   × 0.20  — Foursquare 방식: 시간대·요일 맥락 가중치
//   ④ distanceDecay   × 0.15  — Google Maps 방식: 지수함수 거리 감쇠
//   ⑤ userPrefScore   × 0.15  — Naver AiRS 방식: 취향 매칭 점수 (외부 주입)
//   ⑥ popularityProxy × 0.08  — Foursquare 방식: 인기도 프록시
//
// 곱셈 보정:
//   × freshnessMultiplier    — 최신성 보정 (리뷰수 클수록 1.0 유지)
//   × weekendBonus           — 주말/공휴일 인기 장소 보정
//
// Bayesian 공식 (TripAdvisor 실제 사용):
//   bayesianScore = (C × μ + n × r̄) / (C + n)
//   C = 신뢰도 상수(10), μ = 전체 평균 별점(4.0), n = 리뷰 수, r̄ = 장소 별점
//
// ─────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;
import '../models/place_model.dart';

class PlaceRanker {
  PlaceRanker._();

  // ── Bayesian 상수 ────────────────────────────────────────────────────────
  static const double _C = 10.0;   // 신뢰도 파라미터 (리뷰 10개 = 사전확률과 동등)
  static const double _MU = 4.0;   // 한국 앱 장소 평균 별점

  // ── 요소별 가중치 (합 = 1.0) ─────────────────────────────────────────────
  static const double _wBayesian   = 0.30;
  static const double _wVelocity   = 0.12;
  static const double _wTime       = 0.20;
  static const double _wDist       = 0.15;
  static const double _wUserPref   = 0.15;
  static const double _wPopularity = 0.08;

  /// 장소 목록을 복합 점수로 정렬하여 반환
  ///
  /// [userLat], [userLng]: GPS 좌표 (0.0이면 거리 가중치 중립)
  /// [category]: 카테고리 문자열 (시간대 가중치 선택)
  /// [userPrefScores]: category→선호도점수(0.0~1.0) 맵 (UserPreferenceService 주입)
  static List<Place> rank(
    List<Place> places, {
    String category = '',
    double userLat = 0.0,
    double userLng = 0.0,
    Map<String, double> userPrefScores = const {},
  }) {
    if (places.isEmpty) return places;

    final now        = DateTime.now();
    final hour       = now.hour;
    final isWeekend  = now.weekday >= 6; // 토(6)·일(7)
    final hasGps     = userLat != 0.0 && userLng != 0.0;

    // ── 풀 전체 통계 (정규화 기준값) ────────────────────────────────────────
    final allRatings   = places.where((p) => p.rating > 0).map((p) => p.rating).toList();
    final allReviews   = places.where((p) => p.reviewCount > 0).map((p) => p.reviewCount).toList();
    final maxReviews   = allReviews.isEmpty ? 1.0 : allReviews.reduce(math.max).toDouble();

    double computeScore(Place p) {
      // ① Bayesian 별점 신뢰도 (TripAdvisor·IMDB 방식)
      final bayesian = p.rating > 0
          ? (_C * _MU + p.reviewCount * p.rating) / (_C + p.reviewCount)
          : _MU * 0.5; // 별점 없으면 평균의 절반

      // ② Review Velocity — 최신 리뷰 활성도 추정
      //    리뷰 수 로그 스케일 → 0~1 정규화 (Yelp Elite 가중치 개념)
      final logReviews = p.reviewCount > 0
          ? math.log(p.reviewCount.toDouble() + 1) / math.log(maxReviews + 1)
          : 0.0;
      final velocity = math.min(logReviews, 1.0);

      // ③ 시간대·요일 가중치 (Foursquare contextual signals)
      final timeBonus = _timeSlotBonus(
        catStr: '${p.category} ${p.subcategory}',
        hour: hour,
        isWeekend: isWeekend,
      );

      // ④ 거리 감쇠 — 지수함수 (Google Maps 거리 페널티보다 부드러운 감쇠)
      double distScore = 1.0;
      if (hasGps && p.lat != 0.0 && p.lng != 0.0) {
        final km = _haversineKm(userLat, userLng, p.lat, p.lng);
        distScore = _expDistDecay(km);
      }

      // ⑤ 사용자 취향 매칭 (Naver AiRS·Netflix 개인화)
      final prefKey = _normCat(p.category);
      final prefScore = userPrefScores[prefKey] ?? 0.5; // 데이터 없으면 중립

      // ⑥ 인기도 프록시 (Foursquare foot traffic 대체)
      //    별점 × 로그(리뷰수) — 유명도 보정 지표
      final popularity = p.rating > 0 && p.reviewCount > 0
          ? (p.rating / 5.0) * (math.log(p.reviewCount + 1) / math.log(10000))
          : 0.0;

      // ── 가중합 ────────────────────────────────────────────────────────
      final weighted =
          (bayesian / 5.0) * _wBayesian +   // 5점 만점 → 0~1 정규화
          velocity          * _wVelocity   +
          timeBonus         * _wTime       +
          distScore         * _wDist       +
          prefScore         * _wUserPref   +
          popularity        * _wPopularity;

      // ── 주말 보너스 곱셈 ──────────────────────────────────────────────
      final weekendMul = isWeekend ? _weekendMultiplier(p.category) : 1.0;

      // ── 영업 상태 보정 (isOpenNow) ────────────────────────────────────
      // true  → ×1.25: 지금 열려있는 장소 우선
      // false → ×0.30: 닫힌 장소는 거의 노출 안 함
      // null  → ×1.00: 정보 없으면 중립
      final openMul = p.isOpenNow == null
          ? 1.00
          : (p.isOpenNow! ? 1.25 : 0.30);

      // ── 체인점 페널티 ──────────────────────────────────────────────────
      // 대형 체인은 리뷰 수가 많아 Bayesian 점수를 끌어올리므로 명시적 억제
      final chainMul = _chainMultiplier(p.name);

      return weighted * weekendMul * openMul * chainMul;
    }

    // 평점 있는 장소 → 점수 정렬, 없는 것은 뒤에 붙임
    final scored = places
        .map((p) => _Scored(p, computeScore(p)))
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return scored.map((s) => s.place).toList();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 체인점 페널티 배수
  // 대형 프랜차이즈는 데이트 코스 품질을 낮추므로 × 0.15로 억제
  // ─────────────────────────────────────────────────────────────────────────

  static const _chainBrands = [
    '맥도날드', '버거킹', '롯데리아', 'kfc', '맘스터치', '파파이스', '서브웨이',
    '이디야', '메가커피', '컴포즈', '빽다방', '투썸플레이스', '커피빈',
    '탐앤탐스', '폴바셋', '할리스', '엔젤리너스', '드롭탑', '파스쿠찌',
    '파리바게뜨', '뚜레쥬르', '던킨', '배스킨라빈스', '크리스피크림',
    '빕스', '아웃백', '베니건스', '씨즐러',
    '도미노피자', '피자헛', '파파존스', '미스터피자',
    'gs25', 'cu편의점', '세븐일레븐', '미니스톱',
  ];

  static double _chainMultiplier(String name) {
    final lower = name.toLowerCase();
    for (final brand in _chainBrands) {
      if (lower.contains(brand.toLowerCase())) return 0.15;
    }
    return 1.0;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 시간대·요일 가중치 (Foursquare style)
  // ─────────────────────────────────────────────────────────────────────────

  static double _timeSlotBonus({
    required String catStr,
    required int hour,
    required bool isWeekend,
  }) {
    final c = catStr.toLowerCase();

    // 카페·브런치
    if (c.contains('카페') || c.contains('커피') || c.contains('브런치') ||
        c.contains('cafe') || c.contains('bakery') || c.contains('디저트')) {
      if (hour >= 8  && hour <= 11) return 1.0;  // 아침 브런치 — 최고
      if (hour >= 14 && hour <= 16) return 0.95; // 오후 커피 타임
      if (hour >= 12 && hour <= 13) return 0.85; // 점심 직후
      if (hour >= 20)               return 0.60; // 야간 — 대부분 닫힘
      return 0.75;
    }

    // 식당·맛집
    if (c.contains('맛집') || c.contains('식당') || c.contains('레스토랑') ||
        c.contains('한식') || c.contains('양식') || c.contains('일식') ||
        c.contains('파인다이닝') || c.contains('restaurant')) {
      if (hour >= 11 && hour <= 13) return 1.0;  // 점심 피크
      if (hour >= 17 && hour <= 21) return 1.0;  // 저녁 피크
      if (hour >= 14 && hour <= 16) return 0.60; // 브레이크타임
      if (hour >= 22)               return 0.50; // 야간 영업 드묾
      return 0.70;
    }

    // 야경·뷰
    if (c.contains('야경') || c.contains('뷰') || c.contains('루프탑') ||
        c.contains('rooftop') || c.contains('observation')) {
      if (hour >= 19) return 1.0;  // 야경 최적
      if (hour >= 17) return 0.85; // 석양
      if (hour >= 10 && hour <= 16) return 0.55; // 낮 — 야경 의미 없음
      return 0.45;
    }

    // 전시·문화
    if (c.contains('전시') || c.contains('갤러리') || c.contains('박물관') ||
        c.contains('museum') || c.contains('gallery') || c.contains('공연')) {
      if (hour >= 10 && hour <= 18) return 1.0;  // 정규 관람시간
      if (hour >= 18 && hour <= 20) return 0.80; // 야간 개장 일부
      return 0.50;
    }

    // 체험·액티비티
    if (c.contains('체험') || c.contains('액티비티') || c.contains('볼링') ||
        c.contains('방탈출') || c.contains('bowling') || c.contains('amusement')) {
      if (isWeekend && hour >= 12 && hour <= 21) return 1.0; // 주말 낮
      if (hour >= 14 && hour <= 21) return 0.90;
      if (hour >= 10 && hour <= 14) return 0.75;
      return 0.55;
    }

    return 0.80; // 기타 카테고리 중립
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 주말 보너스 (체험·맛집 인기도 주말에 상승)
  // ─────────────────────────────────────────────────────────────────────────

  static double _weekendMultiplier(String category) {
    final c = category.toLowerCase();
    if (c.contains('체험') || c.contains('액티비티')) return 1.15;
    if (c.contains('맛집') || c.contains('식당'))    return 1.10;
    if (c.contains('전시') || c.contains('문화'))    return 1.08;
    if (c.contains('카페') || c.contains('커피'))    return 1.05;
    return 1.0;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 거리 지수 감쇠 (Google Maps 스타일 — 부드러운 곡선)
  // exp(-λ × km) 형태: 2km 기준 1.0, 멀수록 0으로 수렴
  // ─────────────────────────────────────────────────────────────────────────

  static double _expDistDecay(double km) {
    if (km < 0.3) return 1.0;   // 300m 이내 — 패널티 없음
    // λ = 0.15 → 2km = 0.74, 5km = 0.47, 10km = 0.22
    final decay = math.exp(-0.15 * km);
    return math.max(decay, 0.10); // 최소 10% — 아예 0으로 안 만듦
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Haversine 거리 (km)
  // ─────────────────────────────────────────────────────────────────────────

  static double _haversineKm(
      double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.pow(math.sin(dLng / 2), 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 카테고리 정규화 (취향 맵 키 통일)
  // ─────────────────────────────────────────────────────────────────────────

  static String _normCat(String cat) {
    final c = cat.toLowerCase();
    if (c.contains('카페') || c.contains('커피') || c.contains('브런치')) return 'cafe';
    if (c.contains('맛집') || c.contains('식당') || c.contains('레스토랑')) return 'food';
    if (c.contains('전시') || c.contains('갤러리') || c.contains('박물관')) return 'culture';
    if (c.contains('체험') || c.contains('액티비티')) return 'activity';
    if (c.contains('야경') || c.contains('뷰'))      return 'view';
    return 'etc';
  }

  /// 카테고리 정규화 키 — UserPreferenceService와 공유
  static String normCatKey(String cat) => _normCat(cat);
}

class _Scored {
  final Place place;
  final double score;
  _Scored(this.place, this.score);
}
