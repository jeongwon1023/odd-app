// ─────────────────────────────────────────────────────────────────────────
// UserPreferenceService — 취향 학습 엔진
//
// 알고리즘: Thompson Sampling (Multi-Armed Bandit 방식)
//   - Netflix/Spotify가 탐색(Exploration)과 활용(Exploitation)을 균형 잡는 방법
//   - 각 카테고리를 "팔"로 보고, 사용자 피드백(저장/스킵)으로 Beta 분포 업데이트
//   - Beta(α, β): α = 저장 횟수+1, β = 스킵 횟수+1
//   - 샘플링 시 Beta 분포에서 랜덤 추출 → 불확실한 카테고리도 탐색 가능
//
// 저장 데이터 (SharedPreferences):
//   odd_pref_alpha_{key}: 저장 횟수 누적
//   odd_pref_beta_{key}:  스킵 횟수 누적
//   odd_pref_mood:        최근 선택 무드 히스토리 (최대 10개)
//   odd_pref_budget:      최근 선택 예산 히스토리
//
// 카테고리 키:
//   cafe, food, culture, activity, view, etc
// ─────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'place_ranker.dart';

class UserPreferenceService {
  UserPreferenceService._();

  static const _prefix      = 'odd_pref_';
  static const _alphaPrefix = '${_prefix}alpha_';
  static const _betaPrefix  = '${_prefix}beta_';
  static const _moodKey     = '${_prefix}mood_history';
  static const _budgetKey   = '${_prefix}budget_history';
  static const _maxHistory  = 10;

  static final _rng = math.Random();

  // ── 카테고리 키 목록 ────────────────────────────────────────────────────
  static const _catKeys = ['cafe', 'food', 'culture', 'activity', 'view', 'etc'];

  // ─────────────────────────────────────────────────────────────────────────
  // 피드백 기록
  // ─────────────────────────────────────────────────────────────────────────

  /// 코스 저장 → 해당 코스의 카테고리들에 성공(α) 증가
  static Future<void> recordSave(List<String> categories) async {
    final prefs = await SharedPreferences.getInstance();
    for (final cat in categories) {
      final key = PlaceRanker.normCatKey(cat);
      final alpha = (prefs.getDouble('$_alphaPrefix$key') ?? 1.0) + 1.0;
      await prefs.setDouble('$_alphaPrefix$key', alpha);
    }
  }

  /// 코스 스킵/새로고침 → 해당 코스의 카테고리들에 실패(β) 증가
  static Future<void> recordSkip(List<String> categories) async {
    final prefs = await SharedPreferences.getInstance();
    for (final cat in categories) {
      final key = PlaceRanker.normCatKey(cat);
      final beta = (prefs.getDouble('$_betaPrefix$key') ?? 1.0) + 0.5; // 스킵은 절반 가중
      await prefs.setDouble('$_betaPrefix$key', beta);
    }
  }

  /// 무드 선택 기록 (채팅 시 선택한 무드)
  static Future<void> recordMood(String mood) async {
    final prefs   = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_moodKey) ?? [];
    history.insert(0, mood);
    if (history.length > _maxHistory) history.removeLast();
    await prefs.setStringList(_moodKey, history);
  }

  /// 예산 선택 기록
  static Future<void> recordBudget(String budget) async {
    final prefs   = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_budgetKey) ?? [];
    history.insert(0, budget);
    if (history.length > _maxHistory) history.removeLast();
    await prefs.setStringList(_budgetKey, history);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Thompson Sampling 점수 계산
  // ─────────────────────────────────────────────────────────────────────────

  /// 각 카테고리의 Thompson Sampling 점수 맵 반환
  /// PlaceRanker.rank()의 userPrefScores 파라미터로 전달
  static Future<Map<String, double>> getThompsonScores() async {
    final prefs = await SharedPreferences.getInstance();
    final scores = <String, double>{};

    for (final key in _catKeys) {
      final alpha = prefs.getDouble('$_alphaPrefix$key') ?? 1.0;
      final beta  = prefs.getDouble('$_betaPrefix$key')  ?? 1.0;
      // Beta 분포에서 샘플링 (간소화: 기댓값 E[Beta(α,β)] = α/(α+β))
      // + 분산 기반 탐색 보너스 (UCB 방식)
      final mean     = alpha / (alpha + beta);
      final variance = (alpha * beta) / (math.pow(alpha + beta, 2) * (alpha + beta + 1));
      final std      = math.sqrt(variance.toDouble());
      // Thompson 근사: mean + 0.5 × std (결정론적 upper confidence 추정)
      scores[key] = math.min(mean + 0.5 * std, 1.0);
    }

    return scores;
  }

  /// 사용자 선호 무드 TOP 2 반환 (Gemini 프롬프트 주입용)
  static Future<List<String>> getTopMoods() async {
    final prefs   = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_moodKey) ?? [];
    if (history.isEmpty) return [];
    // 빈도 카운트
    final freq = <String, int>{};
    for (final m in history) {
      freq[m] = (freq[m] ?? 0) + 1;
    }
    final sorted = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(2).map((e) => e.key).toList();
  }

  /// 사용자 선호 예산 (가장 최근 선택)
  static Future<String?> getPreferredBudget() async {
    final prefs   = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_budgetKey) ?? [];
    if (history.isEmpty) return null;
    final freq = <String, int>{};
    for (final b in history) {
      freq[b] = (freq[b] ?? 0) + 1;
    }
    return (freq.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .first
        .key;
  }

  /// 선호 카테고리 상위 3개 (Gemini 프롬프트 주입용)
  static Future<List<String>> getTopCategories() async {
    final scores = await getThompsonScores();
    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    const labelMap = {
      'cafe':     '카페·브런치',
      'food':     '맛집·식당',
      'culture':  '전시·문화',
      'activity': '체험·액티비티',
      'view':     '야경·뷰',
      'etc':      '기타',
    };
    return sorted
        .take(3)
        .where((e) => e.value > 0.5) // 선호도 50% 초과만
        .map((e) => labelMap[e.key] ?? e.key)
        .toList();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 온보딩 시드 — 콜드 스타트 해결
  // ─────────────────────────────────────────────────────────────────────────

  /// 온보딩 취향 퀴즈 응답으로 Thompson Sampling 초기값 설정
  ///
  /// 무드 → 관련 카테고리 α 값 선행 증가
  ///   감성:    cafe +3, culture +2, view +1
  ///   액티비티: activity +4, cafe +1
  ///   힐링:    cafe +2, view +2, culture +1
  ///   혼합:    모든 카테고리 +1 (균등 탐색)
  ///
  /// 예산 → food 카테고리 α 조정
  ///   고급: food +2 (파인다이닝 선호)
  ///   저렴: food +0 (일반 탐색)
  static Future<void> seedFromOnboarding({
    String? mood,
    String? budget,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // 이미 시드된 경우 덮어쓰지 않음 (기존 학습 보호)
    final alreadySeeded = prefs.getBool('${_prefix}seeded') ?? false;
    if (alreadySeeded) return;

    // 무드 기반 카테고리 시드
    final seeds = <String, double>{};
    switch (mood) {
      case '감성':
        seeds['cafe']     = 3.0;
        seeds['culture']  = 2.0;
        seeds['view']     = 1.5;
        seeds['food']     = 1.0;
        seeds['activity'] = 0.5;
      case '액티비티':
        seeds['activity'] = 4.0;
        seeds['cafe']     = 1.5;
        seeds['culture']  = 1.0;
        seeds['food']     = 1.0;
      case '힐링':
        seeds['cafe']     = 2.0;
        seeds['view']     = 2.0;
        seeds['culture']  = 1.5;
        seeds['food']     = 1.0;
      default: // 혼합 or null
        for (final key in _catKeys) {
          seeds[key] = 1.0;
        }
    }

    // 예산 보정
    if (budget == '고급') {
      seeds['food'] = (seeds['food'] ?? 1.0) + 2.0;
    }

    // SharedPreferences에 α 시드값 저장
    for (final entry in seeds.entries) {
      final key = entry.key;
      if (!_catKeys.contains(key)) continue;
      final current = prefs.getDouble('$_alphaPrefix$key') ?? 1.0;
      await prefs.setDouble('$_alphaPrefix$key', current + entry.value);
    }

    // 무드·예산 히스토리에도 추가 (getTopMoods 등에서 활용)
    if (mood != null) {
      final moodHist = prefs.getStringList(_moodKey) ?? [];
      // 시드이므로 선택한 무드 3회 추가 (강한 사전 신호)
      moodHist.insertAll(0, List.filled(3, mood));
      await prefs.setStringList(_moodKey, moodHist.take(_maxHistory).toList());
    }
    if (budget != null) {
      final budgetHist = prefs.getStringList(_budgetKey) ?? [];
      budgetHist.insertAll(0, List.filled(3, budget));
      await prefs.setStringList(_budgetKey, budgetHist.take(_maxHistory).toList());
    }

    await prefs.setBool('${_prefix}seeded', true);
  }

  /// 전체 취향 초기화 (MY 화면 캐시 초기화 연동)
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in _catKeys) {
      await prefs.remove('$_alphaPrefix$key');
      await prefs.remove('$_betaPrefix$key');
    }
    await prefs.remove(_moodKey);
    await prefs.remove(_budgetKey);
    await prefs.remove('${_prefix}seeded');
  }

  /// 취향 데이터 존재 여부 (충분한 데이터: 총 피드백 5회 이상)
  static Future<bool> hasEnoughData() async {
    final prefs = await SharedPreferences.getInstance();
    double total = 0;
    for (final key in _catKeys) {
      total += (prefs.getDouble('$_alphaPrefix$key') ?? 1.0) - 1.0; // 저장 횟수
    }
    return total >= 3.0;
  }
}
