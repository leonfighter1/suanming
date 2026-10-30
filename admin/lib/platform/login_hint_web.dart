import 'package:web/web.dart' as web;

/// Web: the page's `?login=`, if any, then the address without it (the other parameters, such as `?api=`, stay).
String? takeLoginHint() {
  final here = Uri.base;
  final login = here.queryParameters['login'];
  if (login == null) return null;
  final rest = Map.of(here.queryParameters)..remove('login');
  final query = rest.isEmpty ? '' : '?${Uri(queryParameters: rest).query}';
  final fragment = here.hasFragment ? '#${here.fragment}' : '';
  web.window.history.replaceState(null, '', '${here.path}$query$fragment');
  final hint = login.trim();
  return hint.isEmpty ? null : hint;
}
