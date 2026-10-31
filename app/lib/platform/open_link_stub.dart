/// Not on the web: no browser tab to open (false).
Future<bool> openInNewTab(String url) async => false;

/// Not on the web: no page to go to in this tab (false).
Future<bool> openHere(String url) async => false;
