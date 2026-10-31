import 'package:web/web.dart' as web;

/// Web: the browser's localStorage, shared by the dashboard's tabs (S34: the session too). Storage that can't be used
/// (a private window, blocked site data) keeps nothing, and the dashboard starts with the system's theme (and signed
/// out).
String? readPref(String key) {
  try {
    return web.window.localStorage.getItem(key);
  } catch (_) {
    return null;
  }
}

/// [value] kept as [key]'s; an empty one takes the key away.
void writePref(String key, String value) {
  try {
    if (value.isEmpty) {
      web.window.localStorage.removeItem(key);
    } else {
      web.window.localStorage.setItem(key, value);
    }
  } catch (_) {}
}
