/// The device's IANA time zone, for 算卦's cast time (v6.0.0): the browser's own on the web; elsewhere the zone of
/// the current UTC offset ([offsetZone]), which is right for now and close enough for a cast just made.
library;

export 'time_zone_stub.dart' if (dart.library.js_interop) 'time_zone_web.dart';

/// An IANA zone for a whole-hour UTC offset: UTC+8 is Etc/GMT-8 (IANA's Etc names flip the sign). An offset
/// that isn't whole hours has no such zone: UTC.
String offsetZone(Duration offset) {
  if (offset.inMinutes % 60 != 0 || offset == Duration.zero) return 'Etc/UTC';
  final h = offset.inHours;
  return h > 0 ? 'Etc/GMT-$h' : 'Etc/GMT+${-h}';
}
