// The dates the app sends and names files by (S28 WP28.4; docs/refactor-plan.md F15): one home for what the API
// client, the providers, a document's file name and the 算卦 and 八字 forms each wrote.

String _two(int n) => n.toString().padLeft(2, '0');

/// [d]'s calendar date as `YYYY-MM-DD`.
String ymd(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

/// [t]'s wall clock to the minute as `YYYY-MM-DDTHH:mm`: a birth time, a cast time.
String localMinute(DateTime t) => '${ymd(t)}T${_two(t.hour)}:${_two(t.minute)}';
