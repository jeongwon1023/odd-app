import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────
// ODD 컬러 팔레트 — Warm Natural (Figma Make v2, 2026.07)
//
// 방향: AI/테크 느낌 제거 → 따뜻한 로컬 큐레이션(크림 종이 + 테라코타 + 세이지)
// Primary:  테라코타 #C4664A  — 브랜드·주요 액션
// Secondary: 세이지 #6E7A5A   — 자연·차분 보조
// Accent:   소프트 코랄 #E58A5B — 저장·하이라이트(절제 사용)
// BG: 크림 #FAF6EF / Surface: #FFFFFF / textDark: #2C2825(웜 차콜)
// ─────────────────────────────────────────────

class AppTheme {
  // ── Brand — Terracotta ──
  /// 메인 액션 컬러: 테라코타
  static const Color primary   = Color(0xFFC4664A);
  /// 딥 테라코타 (pressed/강조, 그라디언트 엔드)
  static const Color primary2  = Color(0xFFA6522F);

  // ── Secondary — Sage/Olive ──
  static const Color secondary = Color(0xFF6E7A5A);

  // ── Accent — 소프트 코랄 ──
  static const Color accent    = Color(0xFFE58A5B);
  static const Color accentL   = Color(0xFFF7E6DB);

  // ── Background ──
  /// 스캐폴드 배경 — 크림 종이
  static const Color bg        = Color(0xFFFAF6EF);
  /// 카드·앱바 배경
  static const Color surface   = Color(0xFFFFFFFF);
  /// 검색바·입력 필드 배경 — 웜 베이지
  static const Color bg2       = Color(0xFFF3EDE4);
  /// 구분선 — 웜 헤어라인
  static const Color divider   = Color(0xFFECE4D8);

  // ── Text ──
  /// 헤드라인 — 웜 차콜(순수 검정/인디고 금지)
  static const Color textDark  = Color(0xFF2C2825);
  /// 서브 텍스트 — 웜 토프
  static const Color textMid   = Color(0xFF7B7167);
  /// 힌트·플레이스홀더
  static const Color textLight = Color(0xFFA79E92);

  // ── Chip / Highlight ──
  static const Color chipBg    = Color(0xFFF0E9DA);
  static const Color chipText  = Color(0xFFC4664A);

  // ── 카테고리 소프트 틴트 (배경) ──
  static const Color tintCafe    = Color(0xFFF3E7DA); // 카페
  static const Color tintFood    = Color(0xFFF1DED4); // 맛집
  static const Color tintPlay    = Color(0xFFE7ECDD); // 체험·이색
  static const Color tintCulture = Color(0xFFE5E0D3); // 전시·문화
  static const Color tintView    = Color(0xFFDFE3E6); // 야경·뷰

  // ── Gradient (절제 — 카드 전체 덮지 않기) ──
  /// 주요 버튼·배지용 테라코타 그라디언트
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFC4664A), Color(0xFFA6522F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  /// 강조 CTA용 코랄 그라디언트
  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFFE58A5B), Color(0xFFC4664A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  /// 이미지 위 다크 오버레이(텍스트 가독)
  static const LinearGradient darkOverlay = LinearGradient(
    colors: [Colors.transparent, Color(0xBB000000)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  /// 히어로 배경 — 웜 테라코타
  static const LinearGradient heroBannerGradient = LinearGradient(
    colors: [Color(0xFFC4664A), Color(0xFFB5643E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ).copyWith(surface: surface, secondary: secondary),
    // 손글씨 감성 폰트 — 고운돋움(Gowun Dodum) 전역 적용
    textTheme: GoogleFonts.gowunDodumTextTheme(),
    // 토스풍 부드러운 화면 전환 (전역 적용)
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: SoftPageTransitionsBuilder(),
        TargetPlatform.iOS: SoftPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: const IconThemeData(color: textDark),
      titleTextStyle: GoogleFonts.gowunDodum(
        color: textDark,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}

/// 토스풍 부드러운 화면 전환 — 살짝 떠오르며 페이드.
/// (release 빌드 kernel_snapshot에서 실패하는 CupertinoPageTransitionsBuilder 대체 —
///  순수 Dart 트랜지션이라 안전)
class SoftPageTransitionsBuilder extends PageTransitionsBuilder {
  const SoftPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.035),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
