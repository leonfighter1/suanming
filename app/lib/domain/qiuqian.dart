import 'dart:convert';

import 'models.dart' show Json;

/// One lot of a 求籤 set: its title in each script (第五十二籤 / 第五十二签 / Lot 52), its label
/// (甲甲 … 癸癸) and its poem, four lines in 繁體 and 简体. From the server's data via `npm run sync:app`.
class Lot {
  const Lot(this.n, this._title, this.ganzhi, this._poem);

  factory Lot.fromJson(Json j) => Lot(
        j['n'] as int,
        (j['title'] as Json).cast<String, String>(),
        j['ganzhi'] as String,
        (j['poem'] as Json).map((k, v) => MapEntry(k, (v as List).cast<String>())),
      );

  final int n;
  final Map<String, String> _title;
  final String ganzhi;
  final Map<String, List<String>> _poem;

  String title(String apiLocale) => _title[apiLocale] ?? '$n';

  /// The poem in the reader's script; English readers see the original 繁體.
  List<String> poem(String apiLocale) => _poem[apiLocale == 'zh-Hans' ? 'zh-Hans' : 'zh-Hant'] ?? const [];
}

/// A 求籤 lot set (assets/i18n/qiuqian_lots.json): the 關聖帝君一百籤 so far.
class LotSet {
  const LotSet(this.id, this._name, this.lots);

  factory LotSet.parse(String json) {
    final j = jsonDecode(json) as Json;
    return LotSet(
      j['id'] as String,
      (j['name'] as Json).cast<String, String>(),
      [for (final l in j['lots'] as List) Lot.fromJson(l as Json)],
    );
  }

  final String id;
  final Map<String, String> _name;
  final List<Lot> lots;

  String name(String apiLocale) => _name[apiLocale] ?? id;

  /// Lot [n] (1-based), or null when the set has no such lot.
  Lot? lot(int n) => n >= 1 && n <= lots.length ? lots[n - 1] : null;
}

/// One round of a draw: the stick that fell, how the two blocks landed, and what that throw is.
class QiuqianRound {
  const QiuqianRound(this.lot, this.blocks, this.result);
  final int lot;

  /// 'flat' or 'round' for each block: the face that lies up.
  final List<String> blocks;

  /// 'sheng' 聖筊 (one of each), 'xiao' 笑筊 (both flat), 'yin' 陰筊 (both round).
  final String result;

  bool get confirmed => result == 'sheng';
}

/// A 求籤 chart's facts (v4.3.0): the lot and every round it took, the last one its 聖筊.
class QiuqianChart {
  const QiuqianChart(this.lotSet, this.lotNumber, this.ganzhi, this.poem, this.rounds);

  factory QiuqianChart.fromFacts(Json f) {
    final lot = f['lot'] as Json;
    return QiuqianChart(
      f['lot_set'] as String,
      lot['n'] as int,
      lot['ganzhi'] as String,
      (lot['poem'] as List).cast<String>(),
      [
        for (final r in f['rounds'] as List)
          QiuqianRound(
            (r as Json)['lot'] as int,
            (r['blocks'] as List).cast<String>(),
            r['result'] as String,
          ),
      ],
    );
  }

  final String lotSet;
  final int lotNumber;
  final String ganzhi;

  /// The poem in 繁體, as the chart holds it; [Lot.poem] gives it in the reader's script.
  final List<String> poem;
  final List<QiuqianRound> rounds;
}
