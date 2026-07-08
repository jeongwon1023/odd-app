import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/env.dart';
import 'config/naver_map_status.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/supabase_service.dart';
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 네이버 지도 네이티브 SDK 초기화 (실패해도 앱은 계속 — 지도만 미표시)
  try {
    await NaverMapSdk.instance.initialize(
      clientId: Env.naverMapClientId,
      onAuthFailed: (e) {
        NaverMapStatus.authError.value = e.toString();
        debugPrint('NaverMap auth failed: $e');
      },
    );
  } catch (e) {
    debugPrint('NaverMap init error: $e');
  }
  // Supabase 초기화 (URL이 설정되지 않으면 안전하게 스킵)
  await SupabaseService.initialize();
  final prefs = await SharedPreferences.getInstance();
  final onboardingDone = prefs.getBool('onboarding_done') ?? false;
  runApp(OddApp(showOnboarding: !onboardingDone));
}

class OddApp extends StatelessWidget {
  final bool showOnboarding;
  const OddApp({super.key, required this.showOnboarding});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ODD - 데이트 플래너',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      home: showOnboarding ? const OnboardingScreen() : const SplashScreen(),
    );
  }
}
