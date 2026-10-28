import 'dart:js_interop';

import 'time_zone.dart';

@JS('Intl.DateTimeFormat')
extension type _DateTimeFormat._(JSObject _) implements JSObject {
  external _DateTimeFormat();
  external _ResolvedOptions resolvedOptions();
}

extension type _ResolvedOptions._(JSObject _) implements JSObject {
  external String? get timeZone;
}

/// The web: the browser's own IANA zone, e.g. Asia/Hong_Kong; the offset's if the browser gives none.
String deviceTimeZone() {
  try {
    final zone = _DateTimeFormat().resolvedOptions().timeZone;
    if (zone != null && zone.isNotEmpty) return zone;
  } catch (_) {}
  return offsetZone(DateTime.now().timeZoneOffset);
}
