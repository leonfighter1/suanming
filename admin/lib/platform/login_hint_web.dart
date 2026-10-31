import 'package:web/web.dart' as web;

/// Web: the page's parameters among [names] (`?login=`, S25), then the address without them (the others, such as
/// `?api=`, stay): read once, all in one change of the address.
Map<String, String> takeAddressParameters(Set<String> names) {
  final here = Uri.base;
  final taken = {
    for (final MapEntry(:key, :value) in here.queryParameters.entries)
      if (names.contains(key) && value.trim().isNotEmpty) key: value.trim(),
  };
  if (!here.queryParameters.keys.any(names.contains)) return taken;
  final rest = Map.of(here.queryParameters)..removeWhere((k, _) => names.contains(k));
  final query = rest.isEmpty ? '' : '?${Uri(queryParameters: rest).query}';
  final fragment = here.hasFragment ? '#${here.fragment}' : '';
  web.window.history.replaceState(null, '', '${here.path}$query$fragment');
  return taken;
}

/// Web: this tab to [url] (S35: 返回应用, the app again where it handed over).
void goTo(String url) => web.window.location.assign(url);
