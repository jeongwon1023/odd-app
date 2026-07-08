import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/user_preference_service.dart';
import '../utils/app_theme.dart';
import 'splash_screen.dart';

// ─────────────────────────────────────────────────────────────────────────
// OnboardingScreen — 브랜드 소개 3페이지 + 취향 퀴즈 1페이지
//
// 마지막 페이지(취향 퀴즈)에서 수집한 무드·예산 선택으로
// UserPreferenceService.seedFromOnboarding() 호출 → Thompson Sampling 시드 주입
// 콜드 스타트 문제 해결: 첫 추천부터 개인화된 결과 제공
// ─────────────────────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageCtrl = PageController();
  int _page = 0;

  // ── 취향 퀴즈 선택값 ──
  String? _selectedMood;
  String? _selectedBudget;

  static const _introPages = [
    _IntroData(
      emoji: '💕',
      title: '특별한 하루를\n함께 만들어요',
      subtitle: 'ODD는 여러분의 데이트를\n더 특별하게 만들어드립니다',
      bg1: Color(0xFFFFE8F0),
      bg2: Color(0xFFFFF0F6),
      accent: AppTheme.primary,
    ),
    _IntroData(
      emoji: '✨',
      title: 'AI가 완벽한 코스를\n추천해드려요',
      subtitle: '분위기·특별한 날·예산·교통수단에 맞춰\n최적의 데이트 코스를 설계합니다',
      bg1: Color(0xFFEEF0FF),
      bg2: Color(0xFFF8F0FF),
      accent: Color(0xFF7C6FE8),
    ),
    _IntroData(
      emoji: '📍',
      title: '지금 계신 곳 근처\n핫플레이스',
      subtitle: '위치를 허용하면 주변의 인기 장소를\n실시간으로 찾아드립니다',
      bg1: Color(0xFFE8F5FF),
      bg2: Color(0xFFF0FBFF),
      accent: Color(0xFF2196F3),
    ),
  ];

  // 퀴즈 페이지는 4번째 (index 3)
  static const int _quizPageIdx = 3;
  static const int _totalPages  = 4; // 소개 3 + 퀴즈 1

  bool get _isQuizPage => _page == _quizPageIdx;

  void _next() {
    if (_page < _totalPages - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    // 취향 퀴즈 응답이 있으면 Thompson Sampling 시드
    if (_selectedMood != null || _selectedBudget != null) {
      await UserPreferenceService.seedFromOnboarding(
        mood: _selectedMood,
        budget: _selectedBudget,
      );
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SplashScreen()),
    );
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Color get _accentColor {
    if (_isQuizPage) return AppTheme.primary;
    return _introPages[_page].accent;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _isQuizPage
                ? [const Color(0xFFFFF0F6), const Color(0xFFF5F0FF)]
                : [_introPages[_page].bg1, _introPages[_page].bg2],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── 스킵 버튼
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: _finish,
                  child: Text(
                    '건너뛰기',
                    style: TextStyle(
                      color: _accentColor.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                ),
              ),

              // ── 페이지 내용
              Expanded(
                child: PageView.builder(
                  controller: _pageCtrl,
                  physics: const NeverScrollableScrollPhysics(), // 퀴즈 페이지 스와이프 방지
                  onPageChanged: (i) => setState(() => _page = i),
                  itemCount: _totalPages,
                  itemBuilder: (_, i) {
                    if (i == _quizPageIdx) {
                      return _QuizPage(
                        selectedMood: _selectedMood,
                        selectedBudget: _selectedBudget,
                        onMoodChanged: (v) => setState(() => _selectedMood = v),
                        onBudgetChanged: (v) => setState(() => _selectedBudget = v),
                      );
                    }
                    return _IntroPage(data: _introPages[i]);
                  },
                ),
              ),

              // ── 도트 인디케이터
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _totalPages,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _page ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page
                          ? _accentColor
                          : _accentColor.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ── CTA 버튼
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      _page == _totalPages - 1 ? '시작하기 🚀' : '다음',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// 소개 페이지 (기존 스타일 유지)
// ─────────────────────────────────────────────────────────────────────────

class _IntroPage extends StatelessWidget {
  final _IntroData data;
  const _IntroPage({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: data.accent.withOpacity(0.15),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Text(data.emoji, style: const TextStyle(fontSize: 60)),
            ),
          ),
          const SizedBox(height: 48),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E1218),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            data.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: const Color(0xFF1E1218).withOpacity(0.55),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// 취향 퀴즈 페이지 — Thompson Sampling 시드용 선택지
// ─────────────────────────────────────────────────────────────────────────

class _QuizPage extends StatelessWidget {
  final String? selectedMood;
  final String? selectedBudget;
  final ValueChanged<String> onMoodChanged;
  final ValueChanged<String> onBudgetChanged;

  const _QuizPage({
    required this.selectedMood,
    required this.selectedBudget,
    required this.onMoodChanged,
    required this.onBudgetChanged,
  });

  static const _moods = [
    {'label': '🌸 감성',    'value': '감성',    'desc': '분위기·인테리어·감성 공간'},
    {'label': '🎯 액티비티', 'value': '액티비티', 'desc': '체험·방탈출·볼링·활동'},
    {'label': '🌿 힐링',    'value': '힐링',    'desc': '여유·산책·로컬 탐방'},
    {'label': '✨ 다 좋아요', 'value': '혼합',    'desc': '그날그날 달라요'},
  ];

  static const _budgets = [
    {'label': '💚 알뜰하게', 'value': '저렴', 'desc': '1인 2만원 이하'},
    {'label': '💛 적당하게', 'value': '보통', 'desc': '1인 3~6만원'},
    {'label': '💜 특별하게', 'value': '고급', 'desc': '1인 8만원+'},
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),

          // 헤더
          Center(
            child: Container(
              width: 80, height: 80,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('🎨', style: TextStyle(fontSize: 40)),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Center(
            child: Text(
              '취향을 알려주세요',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E1218),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              '더 잘 맞는 코스를 추천해드릴게요',
              style: TextStyle(
                fontSize: 14,
                color: const Color(0xFF1E1218).withOpacity(0.5),
              ),
            ),
          ),

          const SizedBox(height: 28),

          // ── Q1: 무드 ──────────────────────────────
          _QuizSection(
            question: '어떤 데이트를 좋아하세요?',
            children: _moods.map((m) => _QuizChip(
              label:    m['label']!,
              desc:     m['desc']!,
              selected: selectedMood == m['value'],
              onTap:    () => onMoodChanged(m['value']!),
              color:    AppTheme.primary,
            )).toList(),
          ),

          const SizedBox(height: 20),

          // ── Q2: 예산 ──────────────────────────────
          _QuizSection(
            question: '보통 어느 정도 쓰세요?',
            children: _budgets.map((b) => _QuizChip(
              label:    b['label']!,
              desc:     b['desc']!,
              selected: selectedBudget == b['value'],
              onTap:    () => onBudgetChanged(b['value']!),
              color:    const Color(0xFF7C6FE8),
            )).toList(),
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _QuizSection extends StatelessWidget {
  final String question;
  final List<Widget> children;
  const _QuizSection({required this.question, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E1218),
          ),
        ),
        const SizedBox(height: 10),
        ...children,
      ],
    );
  }
}

class _QuizChip extends StatelessWidget {
  final String label;
  final String desc;
  final bool selected;
  final VoidCallback onTap;
  final Color color;
  const _QuizChip({
    required this.label, required this.desc,
    required this.selected, required this.onTap, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : const Color(0xFFE8E0EE),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(label, style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: selected ? color : const Color(0xFF1E1218),
            )),
            const SizedBox(width: 8),
            Text(desc, style: TextStyle(
              fontSize: 12,
              color: const Color(0xFF1E1218).withOpacity(0.45),
            )),
            const Spacer(),
            if (selected)
              Icon(Icons.check_circle_rounded, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── 인트로 데이터 클래스 ──────────────────────────
class _IntroData {
  final String emoji;
  final String title;
  final String subtitle;
  final Color bg1;
  final Color bg2;
  final Color accent;

  const _IntroData({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.bg1,
    required this.bg2,
    required this.accent,
  });
}
