import 'package:flutter/foundation.dart';

class AppConfig {
  /// Override with --dart-define=API_BASE_URL=https://...
  static const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static final String apiBaseUrl = resolveApiBase(
    web: kIsWeb,
    page: kIsWeb ? Uri.base : null,
    define: _apiBaseUrl,
    android: !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
  );

  static const pollInterval = Duration(seconds: 5);
}

/// Where the API is, in this order:
/// 1. web: `?api=https://…` on the page URL (e.g. the GitHub Pages test with a tunnel);
/// 2. `--dart-define=API_BASE_URL` (`origin` = the page's own origin);
/// 3. web served over http from another machine (a phone opening
///    http://192.168.1.5:5000): the same host on port 8787. `127.0.0.1` on a phone
///    is the phone itself, which is why the default can't work there;
/// 4. the Android emulator's alias for the host machine, 10.0.2.2;
/// 5. http://127.0.0.1:8787.
String resolveApiBase({required bool web, Uri? page, String define = '', bool android = false}) {
  final q = page?.queryParameters['api'];
  if (web && q != null && q.startsWith(RegExp('https?://'))) return q.replaceAll(RegExp(r'/+$'), '');
  // "origin": the API serves this page itself (npm run api:public behind a tunnel).
  if (define == 'origin' && page != null) return page.origin;
  if (define.isNotEmpty) return define;
  if (web && page != null && page.scheme == 'http' && !_loopback(page.host)) return 'http://${page.host}:8787';
  if (android) return 'http://10.0.2.2:8787';
  return 'http://127.0.0.1:8787';
}

bool _loopback(String host) => host == 'localhost' || host == '127.0.0.1' || host == '::1' || host == '[::1]';
