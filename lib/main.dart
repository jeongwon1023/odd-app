import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'config/env.dart';
import 'screens/splash_screen.dart';
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 네이버 지도 초기화
  await NaverMapSdk.instance.initialize(
    clientId: Env.naverMapClientId,
    onAuthFailed: (e) => debugPrint('[NaverMap] 인증 실패: $e'),
  );

  runApp(const OddApp());
}

class OddApp extends StatelessWidget {
  const OddApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ODD - 데이트 플래너',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}
