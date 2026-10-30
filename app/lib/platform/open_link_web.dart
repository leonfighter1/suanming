import 'package:web/web.dart' as web;

/// Web: [url] in a new tab, cut off from this one (noopener). Called straight from a tap, so the browser takes it as
/// the user's own and doesn't block it.
Future<bool> openInNewTab(String url) async {
  web.window.open(url, '_blank', 'noopener');
  return true;
}
