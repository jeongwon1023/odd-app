import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../services/supabase_service.dart';
import '../utils/app_theme.dart';

// ─────────────────────────────────────────────
// CoupleLinkScreen — 6자리 코드로 커플 연동
//
// 두 가지 플로우:
//   A. 내 코드 생성 → 공유
//   B. 파트너 코드 입력 → 연동
// ─────────────────────────────────────────────

class CoupleLinkScreen extends StatefulWidget {
  const CoupleLinkScreen({super.key});

  @override
  State<CoupleLinkScreen> createState() => _CoupleLinkScreenState();
}

class _CoupleLinkScreenState extends State<CoupleLinkScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  // 내 코드
  String? _myCode;
  bool _generatingCode = false;

  // 파트너 코드 입력
  final List<TextEditingController> _inputs =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _foci = List.generate(6, (_) => FocusNode());
  bool _linking = false;
  String? _linkError;
  bool _linked = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadMyCode();
  }

  @override
  void dispose() {
    _tab.dispose();
    for (final c in _inputs) c.dispose();
    for (final f in _foci) f.dispose();
    super.dispose();
  }

  Future<void> _loadMyCode() async {
    final existing = await SupabaseService.getMyCoupleCode();
    if (existing != null && mounted) {
      setState(() => _myCode = existing);
      return;
    }
    await _generateCode();
  }

  Future<void> _generateCode() async {
    setState(() => _generatingCode = true);
    try {
      final code = _randomCode();
      final ok = await SupabaseService.createCoupleCode(code);
      if (mounted) setState(() => _myCode = ok ? code : null);
    } finally {
      if (mounted) setState(() => _generatingCode = false);
    }
  }

  String _randomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  void _shareCode() {
    if (_myCode == null) return;
    Share.share(
      '💑 ODD 커플 연동 코드: $_myCode\n'
      '파트너에게 이 코드를 알려주세요!\n'
      '(48시간 유효)',
      subject: 'ODD 커플 코드',
    );
  }

  void _copyCode() {
    if (_myCode == null) return;
    Clipboard.setData(ClipboardData(text: _myCode!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('코드가 복사됐어요 ✅'), duration: Duration(seconds: 2)),
    );
  }

  Future<void> _confirmLink() async {
    final code = _inputs.map((c) => c.text.toUpperCase()).join();
    if (code.length < 6) {
      setState(() => _linkError = '6자리 코드를 모두 입력해 주세요');
      return;
    }
    setState(() { _linking = true; _linkError = null; });
    try {
      final ok = await SupabaseService.linkWithCoupleCode(code);
      if (!mounted) return;
      if (ok) {
        setState(() => _linked = true);
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) Navigator.pop(context, true);
      } else {
        setState(() => _linkError = '코드를 찾을 수 없어요. 다시 확인해 주세요');
      }
    } catch (_) {
      setState(() => _linkError = '연동 중 오류가 발생했어요');
    } finally {
      if (mounted) setState(() => _linking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.textDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('커플 연동', style: TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppTheme.accent,
          labelColor: AppTheme.accent,
          unselectedLabelColor: AppTheme.textMid,
          tabs: const [
            Tab(text: '내 코드 공유'),
            Tab(text: '코드 입력'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [_buildMyCodeTab(), _buildEnterCodeTab()],
      ),
    );
  }

  // ── 내 코드 공유 탭 ────────────────────────────
  Widget _buildMyCodeTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          _heartHeader(),
          const SizedBox(height: 32),
          // 코드 박스
          _generatingCode
              ? const CircularProgressIndicator(color: AppTheme.accent)
              : _codeBox(),
          const SizedBox(height: 12),
          Text(
            '이 코드를 파트너에게 공유해 주세요\n(48시간 유효)',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textMid, fontSize: 13, height: 1.6),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _copyCode,
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('복사'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _shareCode,
                  icon: const Icon(Icons.share, size: 16, color: Colors.white),
                  label: const Text('공유하기', style: TextStyle(color: Colors.white)),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _generateCode,
            child: const Text('새 코드 생성', style: TextStyle(color: AppTheme.textMid, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _heartHeader() {
    return Column(
      children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.accent.withOpacity(0.8), AppTheme.primary],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.favorite, color: Colors.white, size: 36),
        ),
        const SizedBox(height: 12),
        const Text('우리 연결해요 💑',
            style: TextStyle(color: AppTheme.textDark, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('연동하면 함께 코스를 저장하고 공유할 수 있어요',
            style: TextStyle(color: AppTheme.textMid, fontSize: 13), textAlign: TextAlign.center),
      ],
    );
  }

  Widget _codeBox() {
    final code = _myCode ?? '------';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.accent.withOpacity(0.4), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: code.split('').map((ch) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 38,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              ch,
              style: const TextStyle(
                color: AppTheme.primary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── 코드 입력 탭 ──────────────────────────────
  Widget _buildEnterCodeTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          _heartHeader(),
          const SizedBox(height: 32),
          // 6자리 입력 필드
          _linkedSuccess
              ? _successBadge()
              : _codeInputRow(),
          if (_linkError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_linkError!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ),
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _linking ? null : _confirmLink,
              child: _linking
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('연동하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  bool get _linkedSuccess => _linked;

  Widget _codeInputRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (i) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 42,
          height: 52,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _foci[i].hasFocus ? AppTheme.primary : AppTheme.surface,
              width: 1.5,
            ),
          ),
          child: TextField(
            controller: _inputs[i],
            focusNode: _foci[i],
            maxLength: 1,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(
              color: AppTheme.textDark,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            decoration: const InputDecoration(
              counterText: '',
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (val) {
              if (val.isNotEmpty && i < 5) {
                _foci[i + 1].requestFocus();
              } else if (val.isEmpty && i > 0) {
                _foci[i - 1].requestFocus();
              }
              setState(() {});
            },
          ),
        );
      }),
    );
  }

  Widget _successBadge() {
    return Column(
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 64),
        const SizedBox(height: 12),
        const Text('연동 완료! 🎉',
            style: TextStyle(color: AppTheme.textDark, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
