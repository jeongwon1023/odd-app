import 'package:flutter/material.dart';
import '../models/place_model.dart';
import '../services/location_service.dart';
import '../services/naver_place_service.dart';
import '../services/gemini_service.dart';

import '../utils/app_theme.dart';
import 'course_result_screen.dart';

enum _Step { greeting, askMood, askTime, askNoodle, askBudget, generating, done }

class _Msg {
  final String text;
  final bool isBot;
  final List<String>? options;
  const _Msg({required this.text, required this.isBot, this.options});
}

class ChatScreen extends StatefulWidget {
  final LocationResult location;
  const ChatScreen({super.key, required this.location});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<_Msg> _msgs = [];
  final ScrollController _scroll = ScrollController();

  _Step _step = _Step.greeting;
  String _mood = '혼합';
  String _timeSlot = '낮';
  bool _excludeNoodle = false;
  String _budget = '무관';

  @override
  void initState() {
    super.initState();
    GeminiService.startNewChat();
    _botSay('안녕하세요 💕\n${widget.location.fullRegion.isNotEmpty ? "${widget.location.fullRegion} 근처" : "주변"} 데이트, ODD가 도와드릴게요!');
    Future.delayed(const Duration(milliseconds: 700), () {
      _botSay(
        '어떤 분위기의 데이트를 원하시나요?',
        options: ['✨ 감성적인 데이트', '🏃 활동적인 데이트', '💕 다 좋아요'],
      );
      setState(() => _step = _Step.askMood);
    });
  }

  void _botSay(String text, {List<String>? options}) {
    setState(() => _msgs.add(_Msg(text: text, isBot: true, options: options)));
    _scrollBottom();
  }

  void _userSay(String text) {
    setState(() => _msgs.add(_Msg(text: text, isBot: false)));
    _scrollBottom();
  }

  void _scrollBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
      }
    });
  }

  void _onOption(String opt) {
    // 선택지 비활성화 (이미 답한 질문)
    setState(() {
      final last = _msgs.lastWhere((m) => m.isBot && m.options != null,
          orElse: () => const _Msg(text: '', isBot: true));
      final idx = _msgs.indexOf(last);
      if (idx != -1) {
        _msgs[idx] = _Msg(text: last.text, isBot: true); // remove options
      }
    });

    _userSay(opt);
    Future.delayed(const Duration(milliseconds: 450), () => _next(opt));
  }

  void _next(String opt) {
    switch (_step) {
      case _Step.askMood:
        _mood = opt.contains('감성') ? '감성' : opt.contains('활동') ? '액티비티' : '혼합';
        _step = _Step.askTime;
        _botSay('언제 데이트를 즐기실 건가요?',
            options: ['☀️ 낮 데이트', '🌙 저녁 데이트', '🌅 하루 종일']);
      case _Step.askTime:
        _timeSlot = opt.contains('낮') ? '낮' : opt.contains('저녁') ? '저녁' : '하루종일';
        _step = _Step.askNoodle;
        _botSay('면 요리(파스타·국수·라면 등)는 어떠세요?',
            options: ['😋 면류도 좋아요', '🚫 면류는 제외해 주세요']);
      case _Step.askNoodle:
        _excludeNoodle = opt.contains('제외');
        _step = _Step.askBudget;
        _botSay('예산은 어느 정도로 생각하고 계세요?',
            options: ['💚 가성비 (저렴)', '💛 적당하게 (보통)', '❤️ 특별하게 (고급)', '💜 상관없어요']);
      case _Step.askBudget:
        _budget = opt.contains('저렴') ? '저렴' : opt.contains('보통') ? '보통' : opt.contains('고급') ? '고급' : '무관';
        _step = _Step.generating;
        _recommend();
      default:
        break;
    }
  }

  Future<void> _recommend() async {
    _botSay('완벽한 코스를 찾고 있어요 ✨');

    // 1. 네이버 검색
    final places = await NaverPlaceService.fetchForPreferences(
      region: widget.location.fullRegion,
      mood: _mood,
      timeSlot: _timeSlot,
      excludeNoodle: _excludeNoodle,
      budget: _budget,
    );

    // 2. Gemini로 코스 생성
    final courses = await GeminiService.generateCourses(
      region: widget.location.fullRegion,
      mood: _mood,
      timeSlot: _timeSlot,
      budget: _budget,
      places: places,
    );

    setState(() => _step = _Step.done);

    if (!mounted) return;
    if (courses.isEmpty) {
      _botSay('죄송해요, 잠시 후 다시 시도해주세요 🙏');
      return;
    }

    _botSay('${_mood == "혼합" ? "딱 맞는" : _mood} 코스 ${courses.length}가지를 골랐어요 💕');
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CourseResultScreen(courses: courses),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('ODD 데이트 상담',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppTheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '새로 시작',
            onPressed: () {
              setState(() {
                _msgs.clear();
                _step = _Step.greeting;
                _mood = '혼합';
                _timeSlot = '낮';
                _excludeNoodle = false;
                _budget = '무관';
              });
              GeminiService.startNewChat();
              _botSay('새로운 데이트 코스를 찾아볼까요? 💕');
              Future.delayed(const Duration(milliseconds: 600), () {
                _botSay('어떤 분위기의 데이트를 원하시나요?',
                    options: ['✨ 감성적인 데이트', '🏃 활동적인 데이트', '💕 다 좋아요']);
                setState(() => _step = _Step.askMood);
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: _msgs.length,
              itemBuilder: (_, i) => _buildMsg(_msgs[i]),
            ),
          ),
          if (_step == _Step.generating)
            Container(
              color: AppTheme.surface,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: const LinearProgressIndicator(
                color: AppTheme.primary,
                backgroundColor: Color(0xFFFFE0E0),
                minHeight: 3,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMsg(_Msg msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
            msg.isBot ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          if (msg.isBot)
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Text('O',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14)),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                        bottomLeft: Radius.circular(4),
                      ),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8)
                      ],
                    ),
                    child: Text(msg.text,
                        style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textDark,
                            height: 1.5)),
                  ),
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Text(msg.text,
                  style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w500)),
            ),
          if (msg.isBot && msg.options != null && _step != _Step.generating)
            Padding(
              padding: const EdgeInsets.only(left: 38, top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: msg.options!
                    .map((opt) => _OptionChip(
                          label: opt,
                          onTap: () => _onOption(opt),
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _OptionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 13,
                color: AppTheme.primary,
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}
