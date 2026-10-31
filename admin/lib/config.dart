/// Where the admin API is (管理后台, tech plan S22): `?api=` in the address; else API_BASE_URL at build time; else,
/// served by the API itself at /admin/, the page's own origin; else the dev server on this machine.
String adminApiBase([Uri? page]) {
  final uri = page ?? Uri.base;
  final asked = uri.queryParameters['api'];
  if (asked != null && asked.isNotEmpty) return asked.replaceAll(RegExp(r'/+$'), '');
  const built = String.fromEnvironment('API_BASE_URL');
  if (built.isNotEmpty) return built;
  if ((uri.scheme == 'http' || uri.scheme == 'https') && uri.path.startsWith('/admin')) return uri.origin;
  return 'http://127.0.0.1:8787';
}

/// The app's address for 返回应用 (S35): [given] (what the app's ☰ → 管理后台 handed over, or kept since) when it is an
/// http(s) address on the page's own host or on this computer; else null, so nobody's link sends staff elsewhere.
String? appAddressFrom(String? given, [Uri? page]) {
  final app = given == null ? null : Uri.tryParse(given);
  if (app == null || (app.scheme != 'http' && app.scheme != 'https') || app.host.isEmpty) return null;
  const local = {'localhost', '127.0.0.1', '::1'};
  return app.host == (page ?? Uri.base).host || local.contains(app.host) ? app.toString() : null;
}
