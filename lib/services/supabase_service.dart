import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/env.dart';

// ─────────────────────────────────────────────
// SupabaseService — ODD 백엔드 연결 레이어
//
// 사용 전 Env.supabaseUrl / Env.supabaseAnonKey 를 채워야 합니다.
// main.dart에서 SupabaseService.initialize() 호출 필요.
// ─────────────────────────────────────────────

class SupabaseService {
  static SupabaseClient get _client => Supabase.instance.client;

  /// 앱 시작 시 1회 호출 (main.dart)
  /// URL/Key가 플레이스홀더면 → 안전하게 건너뜀 (로컬 전용 모드 유지)
  static Future<void> initialize() async {
    if (Env.supabaseUrl == 'YOUR_SUPABASE_URL') return;
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );
  }

  /// Supabase가 실제로 연결되어 있는지 확인
  static bool get isConnected => Env.supabaseUrl != 'YOUR_SUPABASE_URL';

  // ── Auth ────────────────────────────────────

  static User? get currentUser =>
      isConnected ? _client.auth.currentUser : null;
  static bool get isLoggedIn => currentUser != null;

  /// 이메일 + 비밀번호 로그인
  static Future<AuthResponse?> signInWithEmail(
      String email, String password) async {
    if (!isConnected) return null;
    return await _client.auth.signInWithPassword(
        email: email, password: password);
  }

  /// 이메일 회원가입
  static Future<AuthResponse?> signUpWithEmail(
      String email, String password, String nickname) async {
    if (!isConnected) return null;
    return await _client.auth
        .signUp(email: email, password: password, data: {'nickname': nickname});
  }

  /// 카카오 OAuth 로그인 (브라우저 → 앱 딥링크 복귀)
  /// Supabase Dashboard > Auth > Providers > Kakao 설정 필요
  static Future<bool> signInWithKakao() async {
    if (!isConnected) return false;
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.kakao,
        redirectTo: 'odd://login-callback',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 로그아웃
  static Future<void> signOut() async {
    if (!isConnected) return;
    await _client.auth.signOut();
  }

  // ── 커뮤니티 피드 ────────────────────────────

  /// 공개 코스 피드 조회
  /// [sort] — 'new' | 'popular'
  static Future<List<Map<String, dynamic>>> fetchCommunityFeed({
    String sort = 'new',
    int limit = 20,
    int offset = 0,
  }) async {
    if (!isConnected) return [];
    try {
      final q = _client.from('shared_courses').select('''
        id, title, mood, description, places, like_count, save_count, created_at,
        profiles!user_id (nickname, avatar_url)
      ''');
      if (sort == 'popular') {
        q.order('like_count', ascending: false);
      } else {
        q.order('created_at', ascending: false);
      }
      final data = await q.range(offset, offset + limit - 1);
      return List<Map<String, dynamic>>.from(data as Iterable);
    } catch (_) {
      return [];
    }
  }

  /// 내 코스 커뮤니티 공유 (shared_courses 테이블에 upsert)
  static Future<bool> publishCourse(Map<String, dynamic> courseJson) async {
    if (!isConnected || !isLoggedIn) return false;
    try {
      await _client.from('shared_courses').insert({
        'user_id': currentUser!.id,
        'title': courseJson['title'],
        'mood': courseJson['mood'],
        'description': courseJson['description'] ?? '',
        'places': courseJson['places'],
        'like_count': 0,
        'save_count': 0,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 좋아요 토글
  static Future<void> toggleLike(String courseId) async {
    if (!isConnected || !isLoggedIn) return;
    try {
      final existing = await _client
          .from('likes')
          .select()
          .eq('user_id', currentUser!.id)
          .eq('course_id', courseId)
          .maybeSingle();
      if (existing == null) {
        await _client.from('likes').insert({
          'user_id': currentUser!.id,
          'course_id': courseId,
        });
        await _client.rpc('increment_like', params: {'row_id': courseId});
      } else {
        await _client.from('likes')
            .delete()
            .eq('user_id', currentUser!.id)
            .eq('course_id', courseId);
        await _client.rpc('decrement_like', params: {'row_id': courseId});
      }
    } catch (_) {}
  }

  // ── 프로필 ────────────────────────────────────

  /// 프로필 조회 (닉네임, 아바타)
  static Future<Map<String, dynamic>?> fetchProfile(String userId) async {
    if (!isConnected) return null;
    try {
      return await _client.from('profiles').select().eq('id', userId).single();
    } catch (_) {
      return null;
    }
  }

  /// 닉네임으로 프로필 검색
  static Future<List<Map<String, dynamic>>> searchProfiles(
      String nickname) async {
    if (!isConnected) return [];
    try {
      final data = await _client
          .from('profiles')
          .select()
          .ilike('nickname', '%$nickname%')
          .limit(20);
      return List<Map<String, dynamic>>.from(data as Iterable);
    } catch (_) {
      return [];
    }
  }

  // ── 커플 연동 ─────────────────────────────────

  /// 커플 연동 요청 전송
  static Future<void> sendCoupleRequest(String targetUserId) async {
    if (!isConnected || !isLoggedIn) return;
    await _client.from('couple_requests').insert({
      'from_user_id': currentUser!.id,
      'to_user_id': targetUserId,
      'status': 'pending',
    });
  }

  /// 커플 캘린더 코스 등록
  static Future<void> addCourseToCalendar({
    required String coupleId,
    required Map<String, dynamic> courseJson,
    required DateTime date,
  }) async {
    if (!isConnected || !isLoggedIn) return;
    await _client.from('couple_calendar').insert({
      'couple_id': coupleId,
      'course': courseJson,
      'date': date.toIso8601String(),
      'created_by': currentUser!.id,
    });
  }

  // ── 커플 코드 시스템 ──────────────────────────

  /// 내 활성 커플 코드 조회 (없으면 null)
  static Future<String?> getMyCoupleCode() async {
    if (!isConnected || !isLoggedIn) return null;
    try {
      final row = await _client
          .from('couple_codes')
          .select('code')
          .eq('user_id', currentUser!.id)
          .eq('used', false)
          .gt('expires_at', DateTime.now().toIso8601String())
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return row?['code'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// 새 커플 코드 생성
  static Future<bool> createCoupleCode(String code) async {
    if (!isConnected || !isLoggedIn) return false;
    try {
      // 기존 미사용 코드 삭제
      await _client
          .from('couple_codes')
          .delete()
          .eq('user_id', currentUser!.id)
          .eq('used', false);
      // 새 코드 삽입
      await _client.from('couple_codes').insert({
        'user_id': currentUser!.id,
        'code': code,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 파트너 코드로 커플 연동
  /// 성공 시 true, 코드 없거나 만료·이미 사용됐으면 false
  static Future<bool> linkWithCoupleCode(String code) async {
    if (!isConnected || !isLoggedIn) return false;
    try {
      final row = await _client
          .from('couple_codes')
          .select('id, user_id')
          .eq('code', code.toUpperCase())
          .eq('used', false)
          .gt('expires_at', DateTime.now().toIso8601String())
          .maybeSingle();
      if (row == null) return false;

      final partnerId = row['user_id'] as String;
      if (partnerId == currentUser!.id) return false; // 자신의 코드

      final coupleId = '${currentUser!.id}_$partnerId';

      // 두 프로필에 couple_id 설정
      await Future.wait([
        _client
            .from('profiles')
            .upsert({'id': currentUser!.id, 'couple_id': coupleId}),
        _client
            .from('profiles')
            .upsert({'id': partnerId, 'couple_id': coupleId}),
      ]);

      // 코드 사용 처리
      await _client
          .from('couple_codes')
          .update({'used': true, 'partner_id': currentUser!.id})
          .eq('id', row['id']);

      return true;
    } catch (_) {
      return false;
    }
  }

  /// 커플 연동 여부 확인
  static Future<String?> getMyCoupleId() async {
    if (!isConnected || !isLoggedIn) return null;
    try {
      final row = await _client
          .from('profiles')
          .select('couple_id')
          .eq('id', currentUser!.id)
          .maybeSingle();
      return row?['couple_id'] as String?;
    } catch (_) {
      return null;
    }
  }
}
