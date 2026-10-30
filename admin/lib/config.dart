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
