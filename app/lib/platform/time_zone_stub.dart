import 'time_zone.dart';

/// Not on the web: the zone of the current UTC offset.
String deviceTimeZone() => offsetZone(DateTime.now().timeZoneOffset);
