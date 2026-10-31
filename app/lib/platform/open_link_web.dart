import 'package:web/web.dart' as web;

/// Web: [url] in a new tab, cut off from this one (noopener). Called straight from a tap, so the browser takes it as
/// the user's own and doesn't block it.
Future<bool> openInNewTab(String url) async {
  web.window.open(url, '_blank', 'noopener');
  return true;
}

/// Web: [url] in this tab (S35: ☰ → 管理后台, 「不需要单独打开新的页面，留在app本体」); the browser's Back returns.
Future<bool> openHere(String url) async {
  web.window.location.assign(url);
  return true;
}
