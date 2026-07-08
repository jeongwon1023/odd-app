import 'package:flutter/foundation.dart';

/// 네이버 지도 SDK 인증 실패 메시지 전역 홀더.
/// main.dart의 onAuthFailed에서 set → 지도 화면에서 배너로 노출(진단용).
class NaverMapStatus {
  static final ValueNotifier<String?> authError = ValueNotifier<String?>(null);
}
