import 'package:web/web.dart' as web;

/// Web: the browser's localStorage. Storage that can't be used (a private window, blocked site data) keeps nothing,
/// and the dashboard starts with the system's theme.
String? readPref(String key) {
  try {
    return web.window.localStorage.getItem(key);
  } catch (_) {
    return null;
  }
}

void writePref(String key, String value) {
  try {
    web.window.localStorage.setItem(key, value);
  } catch (_) {}
}
