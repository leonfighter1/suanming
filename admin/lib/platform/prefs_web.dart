import 'package:web/web.dart' as web;

/// The browser's localStorage, or with [tab] this tab's sessionStorage (S33: the session, gone with the tab).
web.Storage _storage(bool tab) => tab ? web.window.sessionStorage : web.window.localStorage;

/// Web: the browser's storage. Storage that can't be used (a private window, blocked site data) keeps nothing, and
/// the dashboard starts with the system's theme (and signed out).
String? readPref(String key, {bool tab = false}) {
  try {
    return _storage(tab).getItem(key);
  } catch (_) {
    return null;
  }
}

/// [value] kept as [key]'s; an empty one takes the key away.
void writePref(String key, String value, {bool tab = false}) {
  try {
    if (value.isEmpty) {
      _storage(tab).removeItem(key);
    } else {
      _storage(tab).setItem(key, value);
    }
  } catch (_) {}
}
