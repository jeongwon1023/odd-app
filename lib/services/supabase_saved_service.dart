// ─────────────────────────────────────────────
// SupabaseSavedService — 저장 코스 DB CRUD
//
// 로그인 사용자: Supabase user_saved_courses 테이블
// 비로그인: 이 서비스 사용 안 함 (CacheService 로컬만)
// ─────────────────────────────────────────────

import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class SupabaseSavedService {
  static SupabaseClient get _db => Supabase.instance.client;

  /// 저장 코스 목록 조회 (최신순)
  static Future<List<Map<String, dynamic>>> getSavedCourses() async {
    if (!SupabaseService.isConnected || !SupabaseService.isLoggedIn) return [];
    try {
      final rows = await _db
          .from('user_saved_courses')
          .select('course_data, saved_at')
          .eq('user_id', SupabaseService.currentUser!.id)
          .order('saved_at', ascending: false)
          .limit(100);
      return (rows as List).map((r) {
        final data = Map<String, dynamic>.from(r['course_data'] as Map);
        // saved_at이 없으면 DB 타임스탬프 주입
        data['savedAt'] ??= r['saved_at'] as String;
        return data;
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// 코스 저장 (title 중복이면 덮어쓰기)
  static Future<bool> saveCourse(Map<String, dynamic> courseJson) async {
    if (!SupabaseService.isConnected || !SupabaseService.isLoggedIn) return false;
    try {
      final uid = SupabaseService.currentUser!.id;
      final title = courseJson['title'] as String? ?? '';
      await _db.from('user_saved_courses').upsert({
        'user_id':     uid,
        'title':       title,
        'course_data': courseJson,
        'saved_at':    DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,title');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 코스 삭제 (title 기준)
  static Future<void> removeCourse(String title) async {
    if (!SupabaseService.isConnected || !SupabaseService.isLoggedIn) return;
    try {
      await _db
          .from('user_saved_courses')
          .delete()
          .eq('user_id', SupabaseService.currentUser!.id)
          .eq('title', title);
    } catch (_) {}
  }

  /// 특정 코스 저장 여부 확인
  static Future<bool> isSaved(String title) async {
    if (!SupabaseService.isConnected || !SupabaseService.isLoggedIn) return false;
    try {
      final row = await _db
          .from('user_saved_courses')
          .select('id')
          .eq('user_id', SupabaseService.currentUser!.id)
          .eq('title', title)
          .maybeSingle();
      return row != null;
    } catch (_) {
      return false;
    }
  }

  /// 파트너(커플 연동 상대)의 저장 코스 조회
  static Future<List<Map<String, dynamic>>> getPartnerCourses() async {
    if (!SupabaseService.isConnected || !SupabaseService.isLoggedIn) return [];
    try {
      // 1. 내 couple_id 조회
      final profile = await _db
          .from('profiles')
          .select('couple_id')
          .eq('id', SupabaseService.currentUser!.id)
          .maybeSingle();
      final coupleId = profile?['couple_id'] as String?;
      if (coupleId == null) return [];

      // 2. couple_id에서 파트너 user_id 추출 (형식: uid1_uid2)
      final parts = coupleId.split('_');
      final myId = SupabaseService.currentUser!.id;
      final partnerId = parts.firstWhere((p) => p != myId, orElse: () => '');
      if (partnerId.isEmpty) return [];

      // 3. 파트너의 저장 코스 조회
      final rows = await _db
          .from('user_saved_courses')
          .select('course_data, saved_at')
          .eq('user_id', partnerId)
          .order('saved_at', ascending: false)
          .limit(50);
      return (rows as List).map((r) {
        final data = Map<String, dynamic>.from(r['course_data'] as Map);
        data['savedAt'] ??= r['saved_at'] as String;
        return data;
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// 로컬 → DB 마이그레이션 (첫 로그인 시 로컬 저장 코스를 DB로 옮김)
  static Future<void> migrateLocalToDb(
      List<Map<String, dynamic>> localCourses) async {
    if (!SupabaseService.isConnected || !SupabaseService.isLoggedIn) return;
    if (localCourses.isEmpty) return;
    try {
      final uid = SupabaseService.currentUser!.id;
      final rows = localCourses.map((c) => {
        'user_id':     uid,
        'title':       c['title'] as String? ?? '',
        'course_data': c,
        'saved_at':    c['savedAt'] as String? ?? DateTime.now().toIso8601String(),
      }).toList();
      // upsert로 중복 무시
      await _db.from('user_saved_courses').upsert(rows, onConflict: 'user_id,title');
    } catch (_) {}
  }
}
