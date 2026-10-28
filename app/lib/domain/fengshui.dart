import 'dart:convert';

import 'models.dart' show Json;

/// One 风水 principle in each script, with its everyday reason. From the server's table
/// (src/engines/fengshui/principles.ts) via `npm run sync:app`.
class FengshuiPrinciple {
  const FengshuiPrinciple(this.id, this.area, this._text, this._why);

  factory FengshuiPrinciple.fromJson(Json j) => FengshuiPrinciple(
        j['id'] as String,
        j['area'] as String,
        (j['text'] as Json).cast<String, String>(),
        (j['why'] as Json).cast<String, String>(),
      );

  final String id;
  final String area;
  final Map<String, String> _text;
  final Map<String, String> _why;

  String text(String apiLocale) => _text[apiLocale] ?? id;
  String why(String apiLocale) => _why[apiLocale] ?? '';
}

/// 风水's rooms and facings (assets/i18n/fengshui.json, v4.4.0).
class FengshuiTable {
  const FengshuiTable(this._rooms, this._roomNames, this._facings);

  factory FengshuiTable.parse(String json) {
    final j = jsonDecode(json) as Json;
    final rooms = j['rooms'] as Json;
    return FengshuiTable(
      {
        for (final e in rooms.entries)
          e.key: [for (final p in (e.value as Json)['principles'] as List) FengshuiPrinciple.fromJson(p as Json)],
      },
      {for (final e in rooms.entries) e.key: ((e.value as Json)['name'] as Json).cast<String, String>()},
      {
        for (final e in (j['facings'] as Json).entries)
          e.key: (e.value as Json).map((k, v) => MapEntry(k, (v as Json).cast<String, String>())),
      },
    );
  }

  final Map<String, List<FengshuiPrinciple>> _rooms;
  final Map<String, Map<String, String>> _roomNames;
  final Map<String, Map<String, Map<String, String>>> _facings;

  /// Room ids in the table's order: bedroom, study, living, kitchen, entrance, dining, kids.
  List<String> get rooms => _roomNames.keys.toList();

  /// Facing ids, north first and clockwise.
  List<String> get facings => _facings.keys.toList();

  String roomName(String room, String apiLocale) => _roomNames[room]?[apiLocale] ?? room;
  List<FengshuiPrinciple> principles(String room) => _rooms[room] ?? const [];

  /// A facing's name, its 後天八卦 trigram and its 五行, e.g. 南 · 離 · 火.
  ({String name, String trigram, String element}) facing(String facing, String apiLocale) {
    final f = _facings[facing];
    return (
      name: f?['name']?[apiLocale] ?? facing,
      trigram: f?['trigram']?[apiLocale] ?? '',
      element: f?['element']?[apiLocale] ?? '',
    );
  }
}

/// A 风水 chart's facts (v4.4.0): the room, its facing when given, and its principles' ids.
class FengshuiChart {
  const FengshuiChart(this.room, this.facing, this.principleIds);

  factory FengshuiChart.fromFacts(Json f) => FengshuiChart(
        f['room'] as String,
        f['facing'] as String?,
        [for (final p in f['principles'] as List) (p as Json)['id'] as String],
      );

  final String room;
  final String? facing;
  final List<String> principleIds;
}
