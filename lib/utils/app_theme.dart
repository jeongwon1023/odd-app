import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFFFF6B6B);
  static const Color secondary = Color(0xFFFFE66D);
  static const Color bg = Color(0xFFF8F6F3);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF2D2D2D);
  static const Color textMid = Color(0xFF6B6B6B);
  static const Color textLight = Color(0xFFAAAAAA);

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: surface,
          elevation: 0,
          iconTheme: IconThemeData(color: textDark),
          titleTextStyle: TextStyle(
            color: textDark,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        cardTheme: CardTheme(
          elevation: 0,
          color: surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: surface,
          selectedItemColor: primary,
          unselectedItemColor: textLight,
          type: BottomNavigationBarType.fixed,
        ),
      );
}
