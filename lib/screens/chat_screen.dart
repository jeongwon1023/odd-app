import 'dart:async';
import 'package:flutter/material.dart';
import '../models/place_model.dart';
import '../services/cache_service.dart';
import '../services/location_service.dart';
import '../services/gemini_service.dart';
import '../services/google_places_service.dart';
import '../services/supabase_course_service.dart';
import '../utils/app_theme.dart';
import 'course_result_screen.dart';

// 빠른 시작 시나리오
const _quickScenarios = [
  {'label': '오늘 저녁 코스',   'text': '오늘 저녁 낭만적인 데이트 코스 추천해줘'},
  {'label': '주말 당일기',      'text': '주말 하루 종일 즐길 수 있는 데이트 코스 추천해줘'},
  {'label': '기념일 특별코스',  'text': '기념일 저녁 특별한 데이트 코스 추천해줘'},
  {'label': '예산 세우기',      'text': '가성비 좋은 데이트 코스 추천해줘'},
];

// ─────────────────────────────────────────────
// 데이트 상담 — 5단계 질문 기반 AI 코스 빌더
// ─────────────────────────────────────────────

enum _Step {
  greeting,
  askMood,       // 1. 분위기
  askSpecialDay, // 2. 특별한 날?
  askTime,       // 3. 시간대
  askTransport,  // 4. 이동수단
  askBudget,     // 5. 예산
  generating,
  done,
}

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

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final List<_Msg> _msgs = [];
  final ScrollController _scroll = ScrollController();
  final TextEditingController _textCtrl = TextEditingController();
  Timer? _loadingTimer;
  StreamSubscription<String>? _streamSub;

  _Step _step = _Step.greeting;
  String _mood       = '혼합';
  String _specialDay = '일상';
  late String _timeSlot;   // 현재 시각에서 자동 감지
  String _transport  = '무관';
  String _budget     = '무관';

  // ── 칩 파인더 상태 (챗봇 대신 기본 진입) ──
  bool _finderMode = true;
  final Set<String> _fMood = {};
  String _fTime = '';
  String _fBudget = '';
  String? _finderNote;
  List<DateCourse> _feed = []; // 코스 피드(브라우즈)

  // 스트리밍 상태
  bool _isStreaming = false;
  String _streamingText = '';

  /// 현재 시각 → 시간대 자동 추론
  static String _detectTimeSlot() {
    final h = DateTime.now().hour;
    if (h >= 6 && h < 13) return '낮';
    if (h >= 13 && h < 19) return '낮';
    if (h >= 19 && h < 24) return '저녁';
    return '저녁'; // 자정 이후도 저녁 취급
  }

  late AnimationController _typingCtrl;
  bool _showTyping = false;

  static const _totalSteps = 5;

  int get _currentProgress => switch (_step) {
    _Step.greeting    => 0,
    _Step.askMood     => 0,
    _Step.askSpecialDay => 1,
    _Step.askTime     => 2,
    _Step.askTransport => 3,
    _Step.askBudget   => 4,
    _                 => 5,
  };

  @override
  void initState() {
    super.initState();
    _timeSlot = _detectTimeSlot();  // 앱 실행 시각으로 자동 감지
    _typingCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    GeminiService.startNewChat();
    SupabaseCourseService.resetSession(); // Q2: 새 대화마다 세션 초기화
    // 기본은 칩 파인더 + 코스 피드. 대화는 '말로 자세히' 링크로 시작.
    _loadFeed();
  }

  // ── 코스 피드 로드 (지역 검증 코스 브라우즈) ──
  Future<void> _loadFeed() async {
    final raw = widget.location.fullRegion;
    final city = raw.split(' ').first.isNotEmpty ? raw.split(' ').first : '서울';
    final courses =
        await SupabaseCourseService.fetchTopCourses(city: city, limit: 12);
    if (mounted) setState(() => _feed = courses);
    // 커버 사진만 보강
    final withCovers = await Future.wait(courses.take(10).map((c) async {
      if (c.places.isEmpty || c.places.first.imageUrl.isNotEmpty) return c;
      final url = await GooglePlacesService.fetchFirstPhotoUrl(
          c.places.first.name, c.places.first.address);
      if (url == null) return c;
      final places = List<Place>.from(c.places);
      places[0] = places[0].copyWith(imageUrl: url);
      return DateCourse(
        title: c.title,
        concept: c.concept,
        mood: c.mood,
        description: c.description,
        places: places,
        totalDuration: c.totalDuration,
        savedAt: c.savedAt,
      );
    }));
    if (mounted) setState(() => _feed = withCovers);
  }

  void _openFeedCourse(DateCourse c) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CourseResultScreen(
          courses: [c],
          mood: c.mood.isNotEmpty ? c.mood : c.concept,
          timeSlot: _timeSlot,
        ),
      ),
    );
  }

  // ── 대화 모드 시작 (칩 파인더의 '말로 자세히' 링크) ──
  void _startConversation() {
    setState(() => _finderMode = false);
    _botSay(
      '안녕하세요 💕\n${widget.location.fullRegion.isNotEmpty ? "${widget.location.fullRegion} 근처" : "주변"} 데이트, ODD가 도와드릴게요!',
    );
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      _botSay(
        '오늘 어떤 분위기의 데이트를 원하시나요?',
        options: ['감성 로맨스', '액티비티', '힐링', '야경 데이트', '미식 투어', '자연 힐링', '힙스터 컬처', '럭셔리 스페셜', '인스타 포토', '다 좋아요'],
      );
      setState(() => _step = _Step.askMood);
    });
  }

  // ── 칩 파인더 실행 → DB 검색(_recommend) ──
  void _runFinder() {
    if (_fMood.isEmpty && _fTime.isEmpty && _fBudget.isEmpty) return;
    if (_fMood.length == 1) {
      final m = _fMood.first;
      _mood = m == '이색' ? '혼합' : m;
    } else {
      _mood = '혼합';
    }
    if (_fTime.isNotEmpty) {
      _timeSlot = _fTime.contains('낮')
          ? '낮'
          : _fTime.contains('저녁')
              ? '저녁'
              : '하루종일';
    }
    if (_fBudget.isNotEmpty) {
      _budget = _fBudget.contains('가성')
          ? '저렴'
          : _fBudget.contains('특별')
              ? '고급'
              : '보통';
    }
    setState(() {
      _step = _Step.generating;
      _finderNote = null;
    });
    _recommend();
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    _streamSub?.cancel();
    _typingCtrl.dispose();
    _scroll.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  void _botSay(String text, {List<String>? options}) {
    setState(() {
      _showTyping = false;
      _msgs.add(_Msg(text: text, isBot: true, options: options));
    });
    _scrollBottom();
  }

  void _userSay(String text) {
    setState(() => _msgs.add(_Msg(text: text, isBot: false)));
    _scrollBottom();
    setState(() => _showTyping = true);
  }

  void _scrollBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
      }
    });
  }

  void _onOption(String opt) {
    setState(() {
      final last = _msgs.lastWhere((m) => m.isBot && m.options != null,
          orElse: () => const _Msg(text: '', isBot: true));
      final idx = _msgs.indexOf(last);
      if (idx != -1) {
        _msgs[idx] = _Msg(text: last.text, isBot: true);
      }
    });
    _userSay(opt);
    Future.delayed(const Duration(milliseconds: 500), () => _next(opt));
  }

  void _next(String opt) {
    setState(() => _showTyping = false);
    switch (_step) {

      // ── 1단계: 분위기 ──
      case _Step.askMood:
        if (opt.contains('감성')) {
          _mood = '감성';
          _botSay('감성 로맨스 코스로 준비해드릴게요. 분위기 있는 카페와 갤러리로 채워볼게요.');
        } else if (opt.contains('액티비티')) {
          _mood = '액티비티';
          _botSay('활기차게 즐기는 코스! 에너지 넘치는 체험 위주로 찾아드릴게요.');
        } else if (opt.contains('힐링')) {
          _mood = '힐링';
          _botSay('힐링 코스로 준비할게요. 조용하고 여유로운 공간들로 채워드릴게요.');
        } else if (opt.contains('야경')) {
          _mood = '야경';
          _botSay('야경 데이트 코스! 저녁 이후 빛나는 도시에서 특별한 시간을 만들어드릴게요.');
        } else if (opt.contains('미식')) {
          _mood = '미식';
          _botSay('미식 투어 코스! 맛있는 곳들로만 가득 채워드릴게요.');
        } else if (opt.contains('자연')) {
          _mood = '자연 힐링';
          _botSay('자연 힐링 코스! 도심 밖 자연 속에서 재충전하는 코스로 찾아드릴게요.');
        } else if (opt.contains('힙스터')) {
          _mood = '힙스터 컬처';
          _botSay('힙스터 컬처 코스! 을지로·성수·혜화의 인디 감성 가득한 공간들로 채워드릴게요.');
        } else if (opt.contains('럭셔리')) {
          _mood = '럭셔리 스페셜';
          _botSay('럭셔리 스페셜 코스! 청담·압구정의 프리미엄 데이트, 오늘만큼은 특별하게 꾸며드릴게요.');
        } else if (opt.contains('인스타')) {
          _mood = '인스타 포토';
          _botSay('인스타 포토 코스! 감성 사진 맛집 명소들로 기억에 남는 하루를 만들어드릴게요.');
        } else {
          _mood = '혼합';
          _botSay('자유롭게! 감성도 있고 맛도 있는 코스로 골고루 담아드릴게요.');
        }
        _step = _Step.askSpecialDay;
        setState(() => _showTyping = true);
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) _botSay(
            '오늘 특별한 날인가요? 💝',
            options: ['일상 데이트', '생일·기념일', '첫 만남', '상관없어요'],
          );
        });

      // ── 2단계: 특별한 날 ──
      case _Step.askSpecialDay:
        if (opt.contains('생일') || opt.contains('기념')) {
          _specialDay = '기념일';
          _botSay('기념일이군요. 오늘만큼은 정말 특별한 공간으로 더 신경 써서 골라드릴게요!');
        } else if (opt.contains('첫')) {
          _specialDay = '첫만남';
          _botSay('첫 만남이라니, 설레겠네요. 대화하기 편하고 자연스러운 코스로 준비해드릴게요.');
        } else {
          _specialDay = '일상';
          _botSay('일상 속 소중한 데이트. 편안하면서도 특별한 장소들을 찾아드릴게요.');
        }
        _step = _Step.askTime;
        setState(() => _showTyping = true);
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) _botSay(
            '언제 데이트하실 건가요?',
            options: ['☀️ 낮 데이트', '🌙 저녁 데이트', '🌅 하루 종일'],
          );
        });

      // ── 3단계: 시간대 ──
      case _Step.askTime:
        _timeSlot = opt.contains('낮')
            ? '낮'
            : opt.contains('저녁')
                ? '저녁'
                : '하루종일';
        if (_timeSlot == '저녁') {
          _botSay('저녁 데이트 🌙 조명이 예쁜 곳, 분위기 좋은 곳으로 찾아드릴게요.');
        } else if (_timeSlot == '하루종일') {
          _botSay('하루 종일 함께! 🌅 풍성하고 알찬 코스로 채워드릴게요.');
        } else {
          _botSay('낮 데이트 ☀️ 활기차고 밝은 분위기의 장소들로 준비할게요!');
        }
        _step = _Step.askTransport;
        setState(() => _showTyping = true);
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) _botSay(
            '어떻게 이동하실 건가요?',
            options: ['🚶 도보·산책 위주', '🚗 차량 이동', '🚇 대중교통'],
          );
        });

      // ── 4단계: 이동수단 ──
      case _Step.askTransport:
        if (opt.contains('도보') || opt.contains('산책')) {
          _transport = '도보';
          _botSay('걸어다니는 데이트도 낭만 있죠 🚶 가까운 거리의 장소들로 동선 짧게 잡아드릴게요!');
        } else if (opt.contains('차량') || opt.contains('차')) {
          _transport = '차량';
          _botSay('차로 이동하시는군요 🚗 주차 편한 곳, 조금 더 넓은 반경에서 좋은 곳들을 찾아드릴게요!');
        } else {
          _transport = '대중교통';
          _botSay('대중교통으로 이동! 🚇 접근하기 좋은 위치의 장소들로 골라드릴게요.');
        }
        _step = _Step.askBudget;
        setState(() => _showTyping = true);
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) _botSay(
            '마지막으로, 예산은 어느 정도로 생각하고 계세요?',
            options: ['가성비 (저렴)', '적당하게', '특별하게 (고급)', '상관없어요'],
          );
        });

      // ── 5단계: 예산 ──
      case _Step.askBudget:
        if (opt.contains('저렴') || opt.contains('가성')) {
          _budget = '저렴';
        } else if (opt.contains('적당')) {
          _budget = '보통';
        } else if (opt.contains('고급') || opt.contains('특별')) {
          _budget = '고급';
        } else {
          _budget = '무관';
        }
        _step = _Step.generating;
        _recommend();

      default:
        break;
    }
  }

  Future<void> _recommend() async {
    final budgetLabel = switch (_budget) {
      '저렴' => '가성비 좋은',
      '고급' => '특별하고 럭셔리한',
      _ => '딱 맞는',
    };
    _botSay('$budgetLabel $_mood 코스를 찾고 있어요 ✨\n${widget.location.fullRegion}의 검증된 데이트 코스를 살펴보는 중이에요!');

    // ── DB 검색 전용 ───────────────────────────────────────────────────────
    // ODD의 신뢰는 "실재하는 검증 코스"에서 나온다. 코스를 생성하지 않고
    // curated_courses DB에서 이용자 조건에 맞는 코스를 찾아 그대로 보여준다.

    // 조회 city — 현재 선택 지역(fullRegion) 기준. widget.location.city는 원래 GPS
    // 시/도라서, 사용자가 다른 지역을 골랐을 때(또는 GPS city가 비었을 때) 빈 결과가
    // 나오는 버그가 있었다. 홈과 동일하게 fullRegion 첫 토큰을 사용.
    final cityForQuery = () {
      final first = widget.location.fullRegion.split(' ').first;
      if (first.isNotEmpty) return first;
      return widget.location.city.isNotEmpty ? widget.location.city : '서울';
    }();

    // ① 조건에 정확히 맞는 코스 검색
    var courses = await SupabaseCourseService.fetchCourses(
      city: cityForQuery,
      mood: _mood,
      budget: _budget,
      timeSlot: _timeSlot,
    );

    // ② 조건에 맞는 코스가 없으면 조건을 완화해 도시 기준 검증 코스로 재검색
    var relaxed = false;
    if (courses.isEmpty) {
      relaxed = true;
      courses = await SupabaseCourseService.fetchTopCourses(
        city: cityForQuery,
        preferredTimeSlot: _timeSlot == '하루종일' ? null : _timeSlot,
        limit: 3,
      );
    }

    _loadingTimer?.cancel();

    // ③ 그래도 없으면 — 생성하지 않고 정직하게 안내
    if (courses.isEmpty) {
      setState(() {
        _step = _Step.done;
        if (_finderMode) {
          _finderNote =
              '아직 이 지역엔 조건에 맞는 검증 코스가 충분치 않아요. 넓은 지역이나 다른 분위기로 찾아보세요.';
        }
      });
      if (!mounted) return;
      if (!_finderMode) {
        _botSay(
          '아직 ${widget.location.fullRegion}에는 검증된 코스가 충분하지 않아요 🙏\n'
          '조금 더 넓은 지역(예: 서울 강남, 부산 해운대)이나 다른 분위기로 다시 찾아보시겠어요?',
        );
      }
      return;
    }

    final enriched = await _enrichCoursePhotos(courses);
    setState(() => _step = _Step.done);
    if (!mounted) return;

    _botSay(relaxed
        ? '딱 맞는 조건은 많지 않아, 이 지역에서 가장 사랑받는 검증 코스로 골라봤어요 💕\n마음에 드는 코스를 골라보세요~'
        : '검증된 코스 ${enriched.length}가지를 찾았어요! 마음에 드는 코스를 골라보세요~');

    for (final c in enriched) {
      await CacheService.addToHistory(c.toJson());
      unawaited(SupabaseCourseService.incrementViewCount(c.title)); // Q3: 노출 카운터
    }
    GeminiService.injectCourseContext(enriched);

    if (!mounted) return;
    Navigator.push(context,
        MaterialPageRoute(
            builder: (_) => CourseResultScreen(
              courses: enriched,
              mood: _mood,
              specialDay: _specialDay,
              timeSlot: _timeSlot,
              onRegenerate: () {
                Navigator.pop(context);
                setState(() {
                  _step = _Step.generating;
                  _showTyping = false;
                });
                _botSay('다시 찾아볼게요! 조금 다른 코스로 준비해드릴게요 🔄');
                Future.delayed(const Duration(milliseconds: 600), _recommend);
              },
            )));
  }

  /// 각 코스의 장소에 Google Places 사진 + 평점 + 리뷰 수 적용
  Future<List<DateCourse>> _enrichCoursePhotos(List<DateCourse> courses) async {
    final allPlaces = courses.expand((c) => c.places).toList();
    final futures = allPlaces.map(
        (p) => GooglePlacesService.fetchPlaceEnrichment(p.name, p.address));
    final results = await Future.wait(futures);

    // id → enrichment 맵
    final enrichMap = <String, Map<String, dynamic>>{};
    for (var i = 0; i < allPlaces.length; i++) {
      if (results[i].isNotEmpty) enrichMap[allPlaces[i].id] = results[i];
    }

    return courses.map((course) {
      final enriched = course.places.map((p) {
        final e = enrichMap[p.id];
        if (e == null) return p;
        return p.copyWith(
          imageUrl:    e['imageUrl']    as String?,
          rating:      e['rating']      as double?,
          reviewCount: e['reviewCount'] as int?,
        );
      }).toList();
      return DateCourse(
        title:       course.title,
        concept:     course.concept,
        mood:        course.mood,
        description: course.description,
        places:      enriched,
        totalDuration: course.totalDuration,
      );
    }).toList();
  }

  /// step 값 → _mood/_specialDay 등에 적용, 'unknown'이면 건너뜀
  void _applyParsed(Map<String, String> parsed) {
    final mood       = parsed['mood']!;
    final specialDay = parsed['specialDay']!;
    final time       = parsed['time']!;
    final transport  = parsed['transport']!;
    final budget     = parsed['budget']!;

    if (mood != 'unknown') {
      _mood = switch (mood) {
        '감성'    => '감성',
        '액티비티' => '액티비티',
        '힐링'    => '힐링',
        _        => '혼합',
      };
    }
    if (specialDay != 'unknown') {
      _specialDay = switch (specialDay) {
        '기념일' => '기념일',
        '첫만남' => '첫만남',
        _      => '일상',
      };
    }
    if (time != 'unknown') {
      _timeSlot = switch (time) {
        '저녁'    => '저녁',
        '하루종일' => '하루종일',
        _        => '낮',
      };
    }
    if (transport != 'unknown') {
      _transport = switch (transport) {
        '도보' => '도보',
        '차량' => '차량',
        _     => '대중교통',
      };
    }
    if (budget != 'unknown') {
      _budget = switch (budget) {
        '저렴' => '저렴',
        '고급' => '고급',
        _     => '보통',
      };
    }
  }

  /// 현재 step에서 parsed 값이 있으면 건너뛰고, 없으면 질문
  void _advanceWithParsed(Map<String, String> parsed) {
    // 옵션 칩 제거
    setState(() {
      final idx = _msgs.lastIndexWhere((m) => m.isBot && m.options != null);
      if (idx != -1) _msgs[idx] = _Msg(text: _msgs[idx].text, isBot: true);
    });

    _applyParsed(parsed);

    // 현재 단계부터 순서대로 값이 없는 첫 단계로 점프
    if (_step == _Step.askMood || _step.index <= _Step.askMood.index) {
      if (parsed['mood'] != 'unknown') {
        _step = _Step.askSpecialDay;
      } else {
        // mood 모름 → 기본값 혼합 + 다음 진행
        _mood = '혼합';
        _step = _Step.askSpecialDay;
      }
    }
    if (_step == _Step.askSpecialDay) {
      if (parsed['specialDay'] != 'unknown') {
        _step = _Step.askTime;
      } else {
        _specialDay = '일상';
        _step = _Step.askTime;
      }
    }
    if (_step == _Step.askTime) {
      if (parsed['time'] != 'unknown') {
        _step = _Step.askTransport;
      } else {
        // time 모름 → 질문 필요
        setState(() => _showTyping = true);
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) _botSay('언제 데이트하실 건가요?',
              options: ['☀️ 낮 데이트', '🌙 저녁 데이트', '🌅 하루 종일']);
        });
        return;
      }
    }
    if (_step == _Step.askTransport) {
      if (parsed['transport'] != 'unknown') {
        _step = _Step.askBudget;
      } else {
        setState(() => _showTyping = true);
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) _botSay('어떻게 이동하실 건가요?',
              options: ['🚶 도보·산책 위주', '🚗 차량 이동', '🚇 대중교통']);
        });
        return;
      }
    }
    if (_step == _Step.askBudget) {
      if (parsed['budget'] != 'unknown') {
        _step = _Step.generating;
        _recommend();
      } else {
        setState(() => _showTyping = true);
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) _botSay('마지막으로, 예산은 어느 정도로 생각하고 계세요?',
              options: ['💚 가성비 (저렴)', '💛 적당하게', '❤️ 특별하게 (고급)', '💜 상관없어요']);
        });
        return;
      }
    }
    // 모든 정보가 채워졌으면 바로 생성
    if (_step != _Step.generating) {
      _step = _Step.generating;
      _recommend();
    }
  }

  /// 사용자가 텍스트를 직접 입력했을 때
  void _onFreeText(String text) {
    text = text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();

    // 완료 단계: 수정 의도 감지 → 재생성 OR Gemini 스트리밍 자유 대화
    if (_step == _Step.done) {
      _userSay(text);

      // ── 코스 수정 요청 감지 ──────────────────────────────────────────────
      if (GeminiService.isModificationRequest(text)) {
        // 수정 파라미터 파싱 후 재생성
        GeminiService.interpretAllSteps(text).then((parsed) {
          if (!mounted) return;
          // 변경된 값만 업데이트 (unknown 유지)
          if (parsed['mood'] != 'unknown') _mood = switch (parsed['mood']!) {
            '감성' => '감성', '액티비티' => '액티비티', '힐링' => '힐링', _ => _mood,
          };
          if (parsed['budget'] != 'unknown') _budget = switch (parsed['budget']!) {
            '저렴' => '저렴', '고급' => '고급', _ => '보통',
          };
          if (parsed['time'] != 'unknown') _timeSlot = switch (parsed['time']!) {
            '저녁' => '저녁', '하루종일' => '하루종일', _ => '낮',
          };
          setState(() => _step = _Step.generating);
          _botSay('알겠어요! 조건을 바꿔서 다시 찾아볼게요 🔄');
          Future.delayed(const Duration(milliseconds: 600), _recommend);
        });
        return;
      }

      // ── 일반 자유 대화 (코스 맥락 포함 스트리밍) ────────────────────────
      _streamSub?.cancel();
      setState(() { _isStreaming = true; _streamingText = ''; _showTyping = false; });
      _streamSub = GeminiService.sendMessageStream(text).listen(
        (chunk) {
          if (mounted) setState(() { _streamingText += chunk; });
          _scrollBottom();
        },
        onDone: () {
          if (!mounted) return;
          final finalText = _streamingText.trim();
          setState(() { _isStreaming = false; _streamingText = ''; });
          if (finalText.isNotEmpty) _botSay(finalText);
        },
        onError: (_) {
          if (!mounted) return;
          setState(() { _isStreaming = false; _streamingText = ''; });
          _botSay('잠시 후 다시 시도해주세요 🙏');
        },
      );
      return;
    }

    // 질문 단계: 한 문장으로 전체 파싱 후 다단계 스킵
    if (_step == _Step.greeting || _step == _Step.generating) return;

    _userSay(text);
    GeminiService.interpretAllSteps(text).then((parsed) {
      if (!mounted) return;
      setState(() => _showTyping = false);
      _advanceWithParsed(parsed);
    });
  }

  Widget _buildTextInput() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF0F0F2))),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom > 0
            ? 10
            : MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F8),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _textCtrl,
                textInputAction: TextInputAction.send,
                onSubmitted: _onFreeText,
                decoration: const InputDecoration(
                  hintText: '직접 입력하거나 위 버튼을 선택하세요',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: Color(0xFFBBBBCC),
                    fontWeight: FontWeight.w400,
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  border: InputBorder.none,
                ),
                style: const TextStyle(
                    fontSize: 14, color: AppTheme.textDark),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _onFreeText(_textCtrl.text),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  void _resetChat() {
    setState(() {
      _msgs.clear();
      _step       = _Step.greeting;
      _mood       = '혼합';
      _specialDay = '일상';
      _timeSlot   = _detectTimeSlot();  // 리셋 시에도 현재 시각 기준
      _transport  = '무관';
      _budget     = '무관';
      _showTyping = false;
    });
    GeminiService.startNewChat();
    _botSay('새로운 데이트 코스를 찾아볼까요? 💕');
    Future.delayed(const Duration(milliseconds: 600), () {
      _botSay(
        '오늘 어떤 분위기의 데이트를 원하시나요?',
        options: ['감성 로맨스', '액티비티', '힐링', '야경 데이트', '미식 투어', '자연 힐링', '힙스터 컬처', '럭셔리 스페셜', '인스타 포토', '다 좋아요'],
      );
      setState(() => _step = _Step.askMood);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_finderMode) {
      return Scaffold(
        backgroundColor: AppTheme.bg,
        body: SafeArea(
          child: _step == _Step.generating
              ? _buildFinderLoading()
              : _buildFinder(),
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          _buildHeader(),
          if (_step != _Step.greeting && _step != _Step.done)
            _buildStepDots(),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              itemCount: _msgs.length + (_showTyping ? 1 : 0) + (_isStreaming ? 1 : 0),
              itemBuilder: (_, i) {
                if (_showTyping && i == _msgs.length) {
                  return _buildTypingIndicator();
                }
                // 스트리밍 버블 (항상 마지막)
                if (_isStreaming && i == _msgs.length + (_showTyping ? 1 : 0)) {
                  return _buildStreamingBubble();
                }
                return _AnimatedChatMessage(
                  key: ValueKey(i),
                  isBot: _msgs[i].isBot,
                  child: _buildMsg(_msgs[i], i),
                );
              },
            ),
          ),
          // 빠른 시작 칩 (첫 인사 직후 or done 상태)
          if (_step == _Step.askMood) _buildQuickStartChips(),
          if (_step == _Step.generating) _buildGeneratingBar(),
          if (_step != _Step.generating && _step != _Step.greeting)
            _buildTextInput(),
        ],
      ),
    );
  }

  // ── 칩 파인더 UI ──
  Widget _buildFinder() {
    final canSearch =
        _fMood.isNotEmpty || _fTime.isNotEmpty || _fBudget.isNotEmpty;
    final region = widget.location.district.isNotEmpty
        ? widget.location.district
        : (widget.location.city.isNotEmpty ? widget.location.city : '내 주변');
    final regionShort = region
        .replaceAll('광역시', '')
        .replaceAll('특별시', '')
        .replaceAll('특별자치시', '')
        .replaceAll('특별자치도', '')
        .split(' ')
        .where((t) => t.isNotEmpty)
        .take(2)
        .join(' ');
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('어떤 데이트가\n좋아요?',
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                  height: 1.3,
                  letterSpacing: -0.5)),
          const SizedBox(height: 6),
          const Text('원하는 조건을 골라보세요',
              style: TextStyle(fontSize: 13, color: AppTheme.textMid)),
          const SizedBox(height: 28),
          _fChipRow('분위기', const ['감성', '액티비티', '힐링', '이색'], multi: true),
          _fChipRow('시간대', const ['낮 데이트', '저녁 데이트', '하루 종일'],
              multi: false, group: 'time'),
          _fChipRow('예산 (1인)', const ['가성비', '적당히', '특별하게'],
              multi: false, group: 'budget'),
          const Text('지역',
              style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textMid,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on_rounded,
                    size: 14, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text(regionShort,
                    style: const TextStyle(
                        fontSize: 14, color: AppTheme.textDark)),
              ],
            ),
          ),
          if (_finderNote != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.accentL,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_finderNote!,
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textDark, height: 1.5)),
            ),
          ],
          const SizedBox(height: 32),
          GestureDetector(
            onTap: canSearch ? _runFinder : null,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: canSearch ? AppTheme.primary : AppTheme.textLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Text('이 조건으로 코스 찾기',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: GestureDetector(
              onTap: _startConversation,
              child: const Text('말로 자세히 말할래요 →',
                  style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textMid,
                      decoration: TextDecoration.underline)),
            ),
          ),
          if (_feed.isNotEmpty) ...[
            const SizedBox(height: 36),
            const Text('이런 코스는 어때요?',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                    letterSpacing: -0.2)),
            const SizedBox(height: 12),
            ..._feed.take(10).map(_feedCard),
          ],
        ],
      ),
    );
  }

  Widget _feedCard(DateCourse c) {
    final cover = c.places.isNotEmpty ? c.places.first.imageUrl : '';
    final hours = (c.totalDuration / 60).round();
    Widget img() => cover.isEmpty
        ? Container(
            color: AppTheme.tintCafe,
            child: const Center(child: Text('💕', style: TextStyle(fontSize: 24))))
        : Image.network(cover, fit: BoxFit.cover, errorBuilder: (_, __, ___) {
            return Container(
                color: AppTheme.tintCafe,
                child: const Center(
                    child: Text('💕', style: TextStyle(fontSize: 24))));
          });
    return GestureDetector(
      onTap: () => _openFeedCourse(c),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Color(0x0A3C2D1E), blurRadius: 10, offset: Offset(0, 3)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            SizedBox(width: 96, height: 96, child: img()),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(c.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textDark)),
                    const SizedBox(height: 4),
                    Text(c.places.map((p) => p.name).take(3).join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textMid)),
                    const SizedBox(height: 6),
                    Text('⏱ ${hours > 0 ? '$hours시간' : '반나절'}',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textLight)),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppTheme.textLight),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fChipRow(String label, List<String> options,
      {required bool multi, String? group}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textMid,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((opt) {
              final on = multi
                  ? _fMood.contains(opt)
                  : (group == 'time' ? _fTime == opt : _fBudget == opt);
              return GestureDetector(
                onTap: () => setState(() {
                  if (multi) {
                    on ? _fMood.remove(opt) : _fMood.add(opt);
                  } else if (group == 'time') {
                    _fTime = on ? '' : opt;
                  } else {
                    _fBudget = on ? '' : opt;
                  }
                }),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                  decoration: BoxDecoration(
                    color: on ? AppTheme.primary : AppTheme.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                        color: on ? AppTheme.primary : AppTheme.divider,
                        width: 1.5),
                  ),
                  child: Text(opt,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                          color: on ? Colors.white : AppTheme.textDark)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFinderLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _typingCtrl,
            builder: (_, __) => Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final t = (_typingCtrl.value + i * 0.33) % 1.0;
                final op = 0.3 + (t < 0.5 ? t * 2 : (1 - t) * 2) * 0.7;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(op.clamp(0.0, 1.0)),
                    shape: BoxShape.circle,
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 22),
          const Text('검증된 코스를 찾고 있어요',
              style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark)),
          const SizedBox(height: 8),
          const Text('잠깐만 기다려 주세요',
              style: TextStyle(fontSize: 13, color: AppTheme.textMid)),
        ],
      ),
    );
  }

  // ── 스트리밍 버블 (글자가 실시간으로 흘러나옴) ──
  Widget _buildStreamingBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 32, height: 32,
            margin: const EdgeInsets.only(right: 8, bottom: 2),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(child: Text('O',
                style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w900, fontSize: 16))),
          ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      _streamingText.isEmpty ? '...' : _streamingText,
                      style: const TextStyle(fontSize: 14,
                          color: AppTheme.textDark, height: 1.5),
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedBuilder(
                    animation: _typingCtrl,
                    builder: (_, __) => Container(
                      width: 7, height: 14,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.6 + _typingCtrl.value * 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 빠른 시작 칩 ──
  Widget _buildQuickStartChips() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 6),
            child: Text('⚡ 빠른 시작',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: AppTheme.textLight)),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _quickScenarios.map((s) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => _onFreeText(s['text']!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(s['label']!,
                      style: const TextStyle(
                        color: Colors.white, fontSize: 12,
                        fontWeight: FontWeight.w700)),
                  ),
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF5C6BC0), Color(0xFF7986CB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // 아바타
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.auto_awesome,
                          size: 20, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ODD AI 플래너',
                          style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800,
                            color: Colors.white, letterSpacing: -0.3),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 6, height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF22C55E),
                                shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '온라인 · 즉시 답변',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.8)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // 리셋 버튼
                  GestureDetector(
                    onTap: _resetChat,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.refresh_rounded,
                          size: 18, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 퀵 칩
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _quickScenarios.map((s) => GestureDetector(
                    onTap: () => _onFreeText(s['text']!),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.3)),
                      ),
                      child: Text(
                        s['label']!,
                        style: const TextStyle(
                          fontSize: 12, color: Colors.white,
                          fontWeight: FontWeight.w500),
                      ),
                    ),
                  )).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepDots() {
    const labels = ['분위기', '특별한날', '시간대', '교통', '예산'];
    final current = _currentProgress;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: LayoutBuilder(
        builder: (_, __) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Connecting line behind dots
              Positioned(
                top: 10,
                left: 11,
                right: 11,
                child: Row(
                  children: List.generate(4, (i) {
                    return Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 2,
                        color: i < current
                            ? AppTheme.primary
                            : const Color(0xFFEEEEF2),
                      ),
                    );
                  }),
                ),
              ),
              // Dots + labels
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(5, (dotIdx) {
                  final done = dotIdx < current;
                  final active = dotIdx == current;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: done
                              ? AppTheme.primary
                              : active
                                  ? Colors.white
                                  : const Color(0xFFF2F2F6),
                          border: active
                              ? Border.all(
                                  color: AppTheme.primary, width: 2.5)
                              : null,
                          shape: BoxShape.circle,
                          boxShadow: active
                              ? [
                                  BoxShadow(
                                    color:
                                        AppTheme.primary.withOpacity(0.3),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  )
                                ]
                              : null,
                        ),
                        child: done
                            ? const Icon(Icons.check_rounded,
                                size: 12, color: Colors.white)
                            : active
                                ? Center(
                                    child: Container(
                                      width: 7,
                                      height: 7,
                                      decoration: const BoxDecoration(
                                        color: AppTheme.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  )
                                : null,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        labels[dotIdx],
                        style: TextStyle(
                          fontSize: 9,
                          color: (done || active)
                              ? AppTheme.primary
                              : AppTheme.textLight,
                          fontWeight:
                              active ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGeneratingBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppTheme.primary),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '검증된 코스를 찾고 있어요',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '잠시만 기다려주세요 ✨',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildBotAvatar(),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 3)),
              ],
            ),
            child: AnimatedBuilder(
              animation: _typingCtrl,
              builder: (_, __) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final offset = (i * 0.3).clamp(0.0, 1.0);
                    final val =
                        (_typingCtrl.value - offset).clamp(0.0, 1.0);
                    return Container(
                      margin: EdgeInsets.only(right: i < 2 ? 4.0 : 0),
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color:
                            AppTheme.primary.withOpacity(0.4 + val * 0.6),
                        shape: BoxShape.circle,
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
              color: AppTheme.primary.withOpacity(0.25),
              blurRadius: 6,
              offset: const Offset(0, 3)),
        ],
      ),
      child: const Center(
        child: Icon(Icons.auto_awesome, size: 16, color: Colors.white),
      ),
    );
  }

  Widget _buildMsg(_Msg msg, int index) {
    // ── 첫 메시지: 웰컴 카드 ──
    if (msg.isBot && index == 0) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primary.withOpacity(0.09),
                AppTheme.primary.withOpacity(0.03),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.primary.withOpacity(0.13),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(11),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text('O',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          )),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text('ODD AI',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary,
                      )),
                  const Spacer(),
                  const Text('💕', style: TextStyle(fontSize: 22)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                msg.text,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textDark,
                  height: 1.65,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment:
            msg.isBot ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          if (msg.isBot)
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildBotAvatar(),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(18),
                        bottomRight: Radius.circular(18),
                        bottomLeft: Radius.circular(4),
                      ),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Text(
                      msg.text,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textDark,
                        height: 1.55,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 40),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const SizedBox(width: 50),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(18),
                        bottomLeft: Radius.circular(18),
                        bottomRight: Radius.circular(4),
                      ),
                      boxShadow: [
                        BoxShadow(
                            color: AppTheme.primary.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Text(
                      msg.text,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          if (msg.isBot &&
              msg.options != null &&
              _step != _Step.generating)
            Padding(
              padding: const EdgeInsets.only(left: 40, top: 10),
              child: Column(
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

// ── 선택지 칩 ──
class _OptionChip extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _OptionChip({required this.label, required this.onTap});

  @override
  State<_OptionChip> createState() => _OptionChipState();
}

class _OptionChipState extends State<_OptionChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: _pressed ? const Color(0xFFEEF0F8) : Colors.white,
          border: Border.all(color: const Color(0xFFE8E8F0), width: 1),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.label,
                style: TextStyle(
                  fontSize: 14,
                  color: _pressed ? AppTheme.primary : AppTheme.textDark,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.1,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: _pressed ? AppTheme.primary : AppTheme.textLight,
            ),
          ],
        ),
      ),
    );
  }
}

// ── 메시지 슬라이드인 애니메이션 ──
class _AnimatedChatMessage extends StatefulWidget {
  final Widget child;
  final bool isBot;
  const _AnimatedChatMessage(
      {super.key, required this.child, required this.isBot});

  @override
  State<_AnimatedChatMessage> createState() => _AnimatedChatMessageState();
}

class _AnimatedChatMessageState extends State<_AnimatedChatMessage>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: Offset(widget.isBot ? -0.06 : 0.06, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
