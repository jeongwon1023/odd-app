import 'package:flutter/material.dart';
import '../config/build_info.dart';
import '../services/cache_service.dart';
import '../services/supabase_service.dart';
import '../services/user_preference_service.dart';
import '../utils/app_theme.dart';
import 'auth_screen.dart';
import 'couple_link_screen.dart';
import 'history_screen.dart';

// ─────────────────────────────────────────────
// MY 화면 — 프로필 & 설정
// ─────────────────────────────────────────────

class MyScreen extends StatefulWidget {
  const MyScreen({super.key});

  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  String _nickname    = 'ODD 사용자';
  int _savedCount     = 0;
  int _historyCount   = 0;
  bool _loading       = true;
  bool _isLoggedIn    = false;
  String? _coupleId;

  static String get _appVersion => BuildInfo.version;
  static String get _buildDate  => BuildInfo.buildDate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final saved     = await CacheService.getSavedCourses();
    final history   = await CacheService.getHistoryCourses();
    final nick      = await CacheService.getNickname();
    final loggedIn  = SupabaseService.isLoggedIn;
    String? coupleId;
    if (loggedIn) coupleId = await SupabaseService.getMyCoupleId();
    if (mounted) {
      setState(() {
        _savedCount   = saved.length;
        _historyCount = history.length;
        _nickname     = nick;
        _isLoggedIn   = loggedIn;
        _coupleId     = coupleId;
        _loading      = false;
      });
    }
  }

  Future<void> _goAuth() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
    if (result == true) _load();
  }

  Future<void> _goCouple() async {
    if (!_isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 로그인해 주세요 😊')),
      );
      return;
    }
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CoupleLinkScreen()),
    );
    if (result == true) _load();
  }

  Future<void> _signOut() async {
    await SupabaseService.signOut();
    _load();
  }

  void _showChangelog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.divider,
                  borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(8)),
                  child: Text('v${BuildInfo.version}',
                    style: const TextStyle(color: Colors.white,
                        fontSize: 12, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 10),
                Text(BuildInfo.buildDate,
                  style: const TextStyle(fontSize: 13,
                      color: AppTheme.textMid, fontWeight: FontWeight.w600)),
                const Spacer(),
                const Text('최근 업데이트',
                  style: TextStyle(fontSize: 12, color: AppTheme.textLight)),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFFF0F0F2)),
            const SizedBox(height: 12),
            ...BuildInfo.changelog.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6, right: 10),
                    width: 6, height: 6,
                    decoration: const BoxDecoration(
                      color: AppTheme.primary, shape: BoxShape.circle),
                  ),
                  Expanded(
                    child: Text(item,
                      style: const TextStyle(fontSize: 13,
                          color: AppTheme.textDark, height: 1.5)),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Future<void> _editNickname() async {
    final ctrl = TextEditingController(text: _nickname);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('닉네임 변경',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: TextField(
          controller: ctrl,
          maxLength: 12,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '닉네임을 입력하세요',
            hintStyle: const TextStyle(color: AppTheme.textLight),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.divider)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
            counterStyle: const TextStyle(color: AppTheme.textLight),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('취소', style: TextStyle(color: AppTheme.textMid))),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('저장',
                style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await CacheService.setNickname(result);
      setState(() => _nickname = result);
    }
  }

  Future<void> _clearCache() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('캐시 초기화',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('임시 장소 데이터를 모두 삭제할까요?\n저장한 코스는 유지됩니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('취소', style: TextStyle(color: AppTheme.textMid))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('초기화',
                style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await CacheService.clearAll();
      await UserPreferenceService.clear(); // 취향 학습 데이터도 함께 초기화
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('캐시를 초기화했어요 ✨'),
            backgroundColor: AppTheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator(
              color: AppTheme.primary, strokeWidth: 2.5))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppTheme.primary,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildFigmaHeader(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!_isLoggedIn) ...[
                          _buildLoginBanner(),
                          const SizedBox(height: 16),
                        ],
                        _buildSection('활동', [
                          _buildTile(
                            icon: Icons.route_rounded,
                            label: '다녀온 코스',
                            badge: _historyCount > 0 ? '$_historyCount' : null,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const HistoryScreen()),
                            ).then((_) => _load()),
                          ),
                          _buildTile(
                            icon: Icons.rate_review_outlined,
                            label: '작성한 리뷰',
                            onTap: () {},
                          ),
                          _buildTile(
                            icon: Icons.bookmark_rounded,
                            label: '저장한 코스',
                            badge: '$_savedCount',
                            onTap: () {},
                          ),
                        ]),
                        const SizedBox(height: 16),
                        _buildSection('설정', [
                          _buildTile(
                            icon: Icons.notifications_outlined,
                            label: '알림 설정',
                            onTap: () {},
                          ),
                          _buildTile(
                            icon: Icons.tune_rounded,
                            label: '취향 설정',
                            onTap: () {},
                          ),
                          _buildTile(
                            icon: Icons.manage_accounts_outlined,
                            label: '계정 관리',
                            onTap: _isLoggedIn ? _signOut : _goAuth,
                          ),
                        ]),
                        const SizedBox(height: 16),
                        _buildSection('기타', [
                          _buildTile(
                            icon: Icons.campaign_outlined,
                            label: '공지사항',
                            onTap: () {},
                          ),
                          _buildTile(
                            icon: Icons.info_outline_rounded,
                            label: '버전 정보',
                            trailing: 'v$_appVersion',
                            onTap: _showChangelog,
                          ),
                        ]),
                        const SizedBox(height: 40),
                        Center(
                          child: Text('ODD v$_appVersion · $_buildDate',
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.textLight)),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ── 로그인 유도 배너 (비로그인 시) ──
  Widget _buildLoginBanner() {
    return GestureDetector(
      onTap: _goAuth,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.primary.withOpacity(0.08), AppTheme.primary.withOpacity(0.03)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.person_outline_rounded, color: AppTheme.primary, size: 22),
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('로그인하고 더 많은 기능 이용하기',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
                  SizedBox(height: 3),
                  Text('코스 저장 · 리뷰 작성 · 파트너 연동',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMid)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: const Text('로그인', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  // ── 계정 & 커플 섹션 (사용하지 않음, 기능 참조용 유지) ──
  Widget _buildAccountSection() {
    return _buildSection('계정 & 커플', [
      if (!_isLoggedIn)
        _buildTile(
          icon: Icons.login_rounded,
          label: '로그인 / 회원가입',
          onTap: _goAuth,
        )
      else ...[
        _buildTile(
          icon: Icons.person_rounded,
          label: SupabaseService.currentUser?.email ?? '내 계정',
          trailing: '로그인됨',
          onTap: () {},
        ),
        _buildTile(
          icon: Icons.logout_rounded,
          label: '로그아웃',
          onTap: _signOut,
        ),
      ],
      _buildTile(
        icon: Icons.favorite_rounded,
        label: _coupleId != null ? '커플 연동됨 💑' : '파트너 연동하기',
        badge: _coupleId != null ? '연결' : null,
        onTap: _goCouple,
      ),
    ]);
  }

  // ── 프로필 헤더 (Warm Natural) ──
  Widget _buildFigmaHeader() {
    final coupleLinked = _coupleId != null;
    return Container(
      color: AppTheme.surface,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _editNickname,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: const BoxDecoration(
                          color: AppTheme.tintCafe, shape: BoxShape.circle),
                      child: const Center(
                          child: Icon(Icons.person_rounded,
                              size: 28, color: AppTheme.primary)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_nickname,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textDark)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.tintPlay,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.divider),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.favorite_rounded,
                                  size: 11,
                                  color: coupleLinked
                                      ? AppTheme.accent
                                      : AppTheme.textLight),
                              const SizedBox(width: 5),
                              Text(coupleLinked ? '커플 연결됨' : '커플 미연결',
                                  style: const TextStyle(
                                      fontSize: 12, color: AppTheme.textMid)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _editNickname,
                    child: const Text('편집',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppTheme.divider),
                  bottom: BorderSide(color: AppTheme.divider),
                ),
              ),
              child: Row(
                children: [
                  _statCell('$_savedCount', '저장한 코스', true),
                  _statCell('$_historyCount', '방문 기록', true),
                  _statCell('0', '리뷰', false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCell(String num, String label, bool rightBorder) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: rightBorder
              ? const Border(right: BorderSide(color: AppTheme.divider))
              : null,
        ),
        child: Column(
          children: [
            Text(num,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(fontSize: 11, color: AppTheme.textMid)),
          ],
        ),
      ),
    );
  }

  // ── 섹션 ──
  Widget _buildSection(String title, List<Widget> tiles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(title,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMid,
                  letterSpacing: 0.3)),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            children: tiles.asMap().entries.map((e) {
              final isLast = e.key == tiles.length - 1;
              return Column(
                children: [
                  e.value,
                  if (!isLast)
                    Divider(height: 1, indent: 56,
                        color: Colors.black.withOpacity(0.04)),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── 타일 ──
  Widget _buildTile({
    required IconData icon,
    required String label,
    String? badge,
    String? trailing,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: AppTheme.primary, size: 18)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600,
                      color: AppTheme.textDark))),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(10)),
                child: Text(badge,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.white,
                        fontWeight: FontWeight.w700))),
            if (trailing != null)
              Text(trailing,
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textLight)),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded,
                color: AppTheme.textLight, size: 20),
          ],
        ),
      ),
    );
  }
}

