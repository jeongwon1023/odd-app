import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../utils/app_theme.dart';

// ─────────────────────────────────────────────
// AuthScreen — 이메일 로그인 / 회원가입
// ─────────────────────────────────────────────

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _emailCtrl    = TextEditingController();
  final _pwCtrl       = TextEditingController();
  final _nickCtrl     = TextEditingController();
  final _confirmCtrl  = TextEditingController();
  bool _loading       = false;
  bool _obscurePw     = true;
  String? _error;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _tab.dispose();
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    _nickCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final email = _emailCtrl.text.trim();
    final pw    = _pwCtrl.text;
    if (email.isEmpty || pw.isEmpty) {
      setState(() => _error = '이메일과 비밀번호를 입력해 주세요');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final res = await SupabaseService.signInWithEmail(email, pw);
      if (!mounted) return;
      if (res?.user != null) {
        Navigator.pop(context, true);
      } else {
        setState(() => _error = '로그인 정보를 확인해 주세요');
      }
    } catch (e) {
      setState(() => _error = '로그인 중 오류가 발생했어요');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signUp() async {
    final email    = _emailCtrl.text.trim();
    final pw       = _pwCtrl.text;
    final confirm  = _confirmCtrl.text;
    final nick     = _nickCtrl.text.trim();
    if (email.isEmpty || pw.isEmpty || nick.isEmpty) {
      setState(() => _error = '모든 항목을 입력해 주세요');
      return;
    }
    if (pw != confirm) {
      setState(() => _error = '비밀번호가 일치하지 않아요');
      return;
    }
    if (pw.length < 6) {
      setState(() => _error = '비밀번호는 6자 이상이어야 해요');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final res = await SupabaseService.signUpWithEmail(email, pw, nick);
      if (!mounted) return;
      if (res?.user != null) {
        Navigator.pop(context, true);
      } else {
        setState(() => _error = '회원가입에 실패했어요. 다시 시도해 주세요');
      }
    } catch (e) {
      setState(() => _error = '이미 사용 중인 이메일이에요');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FF),
      body: SafeArea(
        child: Column(
          children: [
            // ── 상단 헤더 (닫기 버튼) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  const Spacer(),
                  const Text('ODD 계정',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textDark)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.close,
                          size: 18, color: AppTheme.textDark),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // ── 커스텀 탭 토글 ──
            _buildTabToggle(),
            // ── 탭 콘텐츠 ──
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [_buildLoginForm(), _buildSignUpForm()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFFEEF0F8),
          borderRadius: BorderRadius.circular(25),
        ),
        child: TabBar(
          controller: _tab,
          indicator: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(21),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.28),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: AppTheme.textMid,
          labelStyle: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 14),
          unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500, fontSize: 14),
          padding: const EdgeInsets.all(4),
          tabs: const [Tab(text: '로그인'), Tab(text: '회원가입')],
        ),
      ),
    );
  }

  Future<void> _signInWithKakao() async {
    setState(() { _loading = true; _error = null; });
    try {
      // 브라우저 열기 (즉시 반환)
      final ok = await SupabaseService.signInWithKakao();
      if (!mounted) return;
      if (!ok) {
        setState(() { _loading = false; _error = '카카오 로그인 설정을 확인해 주세요'; });
        return;
      }
      // 딥링크 복귀 후 세션 확립 시점을 스트림으로 감지
      _authSub?.cancel();
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        if (data.event == AuthChangeEvent.signedIn) {
          _authSub?.cancel();
          _authSub = null;
          if (mounted) Navigator.pop(context, true);
        }
      });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = '카카오 로그인 중 오류가 발생했어요'; });
    }
  }

  Widget _buildLoginForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _figmaLogo(),
          const SizedBox(height: 28),
          // 피처 카드 3개 — Figma 세로 리스트
          _featureCard('✦', 'AI 맞춤 코스 추천', '취향 분석 기반 개인화 추천'),
          const SizedBox(height: 8),
          _featureCard('📍', '실시간 예약 정보', '오늘 예약 가능한 장소만 모아서'),
          const SizedBox(height: 8),
          _featureCard('💑', '커플 취향 분석', '두 사람의 취향을 모두 반영'),
          const SizedBox(height: 28),
          // 카카오 로그인
          _kakaoBtn(),
          const SizedBox(height: 12),
          // 네이버 로그인
          _naverBtn(),
          const SizedBox(height: 16),
          _divider(),
          const SizedBox(height: 16),
          _emailField(),
          const SizedBox(height: 12),
          _pwField(_pwCtrl, '비밀번호'),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _errorBox(),
          ],
          const SizedBox(height: 20),
          _primaryBtn('이메일로 로그인', _loading ? null : _signIn),
          const SizedBox(height: 16),
          // 둘러보기 버튼
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('로그인 없이 둘러보기',
                    style: TextStyle(fontSize: 13, color: AppTheme.textMid)),
                const SizedBox(width: 2),
                const Icon(Icons.chevron_right_rounded,
                    size: 16, color: AppTheme.textMid),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '계속하면 이용약관 및 개인정보처리방침에 동의한 것으로 간주됩니다.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: AppTheme.textLight, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _featureCard(String emoji, String title, String desc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: AppTheme.bg2,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 16))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: AppTheme.textDark)),
              const SizedBox(height: 2),
              Text(desc,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textMid)),
            ],
          )),
        ],
      ),
    );
  }

  Widget _buildSignUpForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          _logo(),
          const SizedBox(height: 32),
          _field(_nickCtrl, '닉네임', Icons.person_outline),
          const SizedBox(height: 12),
          _emailField(),
          const SizedBox(height: 12),
          _pwField(_pwCtrl, '비밀번호 (6자 이상)'),
          const SizedBox(height: 12),
          _pwField(_confirmCtrl, '비밀번호 확인'),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _errorBox(),
          ],
          const SizedBox(height: 24),
          _primaryBtn('가입하기', _loading ? null : _signUp),
        ],
      ),
    );
  }

  Widget _figmaLogo() {
    return Column(
      children: [
        // ODD 로고 박스
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF5C6BC0), Color(0xFF7986CB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF5C6BC0).withOpacity(0.35),
                    blurRadius: 20, offset: const Offset(0, 8)),
                ],
              ),
              child: const Center(
                child: Text('ODD',
                    style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w900, fontSize: 24,
                        letterSpacing: -0.5)),
              ),
            ),
            // heart badge 우상단
            Positioned(
              top: 0, right: 0,
              child: Container(
                width: 22, height: 22,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF6B6B),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('♥', style: TextStyle(
                      color: Colors.white, fontSize: 11)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // "ODD." 타이틀
        RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
                color: AppTheme.textDark, letterSpacing: -0.5),
            children: [
              TextSpan(text: 'ODD'),
              TextSpan(text: '.', style: TextStyle(color: Color(0xFFFF6B6B))),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Text('AI 데이트 코스 플래너',
            style: TextStyle(fontSize: 13, color: AppTheme.textMid)),
        const SizedBox(height: 8),
        const Text('우리만의 완벽한 데이트를\nAI가 설계해드려요',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                color: AppTheme.textDark, height: 1.4)),
      ],
    );
  }

  // 기존 _logo 호환용 (signup form에서 사용)
  Widget _logo() => _figmaLogo();

  Widget _emailField() => _field(_emailCtrl, '이메일', Icons.email_outlined,
      type: TextInputType.emailAddress);

  Widget _pwField(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      obscureText: _obscurePw,
      style: const TextStyle(color: AppTheme.textDark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.textMid),
        prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.textMid),
        suffixIcon: IconButton(
          icon: Icon(_obscurePw ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: AppTheme.textMid),
          onPressed: () => setState(() => _obscurePw = !_obscurePw),
        ),
        filled: true,
        fillColor: AppTheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint, IconData icon,
      {TextInputType type = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      style: const TextStyle(color: AppTheme.textDark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.textMid),
        prefixIcon: Icon(icon, color: AppTheme.textMid),
        filled: true,
        fillColor: AppTheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _errorBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
    );
  }

  Widget _kakaoBtn() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFEE500),
        foregroundColor: const Color(0xFF191919),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
      onPressed: _loading ? null : _signInWithKakao,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 카카오 로고 아이콘 (말풍선 모양)
          Container(
            width: 22, height: 22,
            decoration: const BoxDecoration(
              color: Color(0xFF191919), shape: BoxShape.circle),
            child: const Center(
              child: Text('K', style: TextStyle(color: Color(0xFFFEE500),
                  fontWeight: FontWeight.w900, fontSize: 13)),
            ),
          ),
          const SizedBox(width: 10),
          const Text('카카오로 시작하기',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _naverBtn() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF03C75A),
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
      onPressed: null, // 네이버 OAuth 미구현 — 비활성 표시
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('N', style: TextStyle(
              fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white)),
          SizedBox(width: 10),
          Text('네이버로 시작하기',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _divider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFE0E0E0))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('또는', style: TextStyle(color: AppTheme.textMid, fontSize: 12)),
        ),
        const Expanded(child: Divider(color: Color(0xFFE0E0E0))),
      ],
    );
  }

  Widget _primaryBtn(String label, VoidCallback? onTap) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.primary,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onTap,
      child: _loading
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
    );
  }
}
