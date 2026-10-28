import 'dart:convert';

import 'models.dart' show Json;

typedef _Text = Map<String, String>;

/// The text in the reader's script (the app is in Chinese only: 简体 or 繁體).
String _of(_Text t, String apiLocale) => t[apiLocale == 'zh-Hans' ? 'zh-Hans' : 'zh-Hant'] ?? '';
_Text _text(Object? v) => (v as Json).cast<String, String>();

/// 算卦's table (assets/i18n/liuyao.json, synced from the server by `npm run sync:app`, v6.0.0): the eight
/// trigrams' names and images, and the 直說 of every 卦辭 and 爻辭 (the owner: 「卦辞都是直抒胸臆，不用绕」).
class LiuyaoTable {
  LiuyaoTable(this._trigrams, this._plain);

  factory LiuyaoTable.parse(String json) {
    final j = jsonDecode(json) as Json;
    return LiuyaoTable(
      {
        for (final t in (j['trigrams'] as List).cast<Json>()) t['id'] as String: (name: _text(t['name']), image: _text(t['image'])),
      },
      {
        for (final h in (j['hexagrams'] as List).cast<Json>())
          h['id'] as String: (gua: _text(h['gua']), lines: [for (final l in h['lines'] as List) _text(l)]),
      },
    );
  }

  final Map<String, ({_Text name, _Text image})> _trigrams;
  final Map<String, ({_Text gua, List<_Text> lines})> _plain;

  /// A trigram with its image, e.g. 乾（天）.
  String trigram(String id, String apiLocale) {
    final t = _trigrams[id];
    return t == null ? id : '${_of(t.name, apiLocale)}（${_of(t.image, apiLocale)}）';
  }

  /// The 直說 of a hexagram's 卦辭 (no [line]), or of one of its lines (1–6, 7 for 用九 / 用六).
  String? plain(String hexagramId, int? line, String apiLocale) {
    final h = _plain[hexagramId];
    if (h == null) return null;
    if (line == null) return _of(h.gua, apiLocale);
    return line <= h.lines.length ? _of(h.lines[line - 1], apiLocale) : null;
  }
}

/// A hexagram of a cast: its lines (初爻 first, '1' = yang), King Wen number, names, trigrams and 卦辭.
class LiuyaoHexagram {
  const LiuyaoHexagram(this.id, this.number, this._fullName, this.upper, this.lower, this._guaCi);

  factory LiuyaoHexagram.fromJson(Json j) => LiuyaoHexagram(
        j['id'] as String,
        j['number'] as int,
        _text(j['full_name']),
        j['upper'] as String,
        j['lower'] as String,
        _text(j['gua_ci']),
      );

  final String id;
  final int number;
  final _Text _fullName;
  final String upper;
  final String lower;
  final _Text _guaCi;

  /// e.g. 天雷無妄
  String fullName(String apiLocale) => _of(_fullName, apiLocale);
  String guaCi(String apiLocale) => _of(_guaCi, apiLocale);
}

/// One text the reading rests on (朱熹's rule): a 卦辭, or a line (1–6, 7 for 用九 / 用六).
class LiuyaoFocus {
  const LiuyaoFocus(this.ofChanged, this.line, this.main, this._text);
  final bool ofChanged;
  final int? line;
  final bool main;
  final _Text _text;
  String text(String apiLocale) => _of(_text, apiLocale);
}

/// A 算卦 cast's facts (v6.0.0): how it was cast and when, its six tosses and lines, the 本卦 and 變卦, and the
/// texts to read.
class LiuyaoChart {
  const LiuyaoChart({
    required this.mode,
    required this.castLocal,
    required this.ganzhi,
    required this.coins,
    required this.values,
    required this.primary,
    required this.changed,
    required this.focus,
  });

  factory LiuyaoChart.fromFacts(Json f) {
    final cast = f['cast'] as Json;
    final g = cast['ganzhi'] as Json;
    final tosses = (f['tosses'] as List).cast<Json>();
    final focus = f['focus'] as Json;
    return LiuyaoChart(
      mode: f['mode'] as String,
      castLocal: cast['local'] as String,
      ganzhi: (year: g['year'] as String, month: g['month'] as String, day: g['day'] as String, hour: g['hour'] as String),
      coins: [for (final t in tosses) (t['coins'] as List?)?.cast<String>()],
      values: [for (final t in tosses) t['value'] as int],
      primary: LiuyaoHexagram.fromJson(f['primary'] as Json),
      changed: f['changed'] == null ? null : LiuyaoHexagram.fromJson(f['changed'] as Json),
      focus: [
        for (final t in (focus['texts'] as List).cast<Json>())
          LiuyaoFocus(t['hexagram'] == 'changed', t['line'] as int?, t['role'] == 'main', _text(t['text'])),
      ],
    );
  }

  /// auto, pick or manual
  final String mode;

  /// The local time of the cast, to the minute (YYYY-MM-DDTHH:mm).
  final String castLocal;
  final ({String year, String month, String day, String hour}) ganzhi;

  /// Each toss's three coins ('zi' 字, 'bei' 背), 初爻 first; null where the reader entered the line itself.
  final List<List<String>?> coins;

  /// Each line, 初爻 first: 6 老陰, 7 少陽, 8 少陰, 9 老陽.
  final List<int> values;
  final LiuyaoHexagram primary;
  final LiuyaoHexagram? changed;
  final List<LiuyaoFocus> focus;

  static bool yang(int value) => value == 7 || value == 9;
  static bool moving(int value) => value == 6 || value == 9;
}
