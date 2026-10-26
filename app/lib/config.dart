import 'package:flutter/foundation.dart';

class AppConfig {
  /// Override with --dart-define=API_BASE_URL=https://...
  static const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl {
    if (_apiBaseUrl.isNotEmpty) return _apiBaseUrl;
    // The Android emulator reaches the host machine at 10.0.2.2.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:8787';
    return 'http://127.0.0.1:8787';
  }

  static const pollInterval = Duration(seconds: 5);
}
