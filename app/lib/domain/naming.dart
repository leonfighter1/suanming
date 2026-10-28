import 'dart:convert';

import 'models.dart' show Json;

/// One character of 起名's 字义库 (a draft awaiting the owner's review), synced from the server
/// (src/engines/naming/characters.ts) by `npm run sync:app`.
class NameCharacter {
  const NameCharacter(this.hant, this.hans, this.pinyin, this.element, this._meaning);

  factory NameCharacter.fromJson(Json j) => NameCharacter(
        j['hant'] as String,
        j['hans'] as String,
        j['pinyin'] as String,
        j['element'] as String,
        (j['meaning'] as Json).cast<String, String>(),
      );

  final String hant;
  final String hans;
  final String pinyin;
  final String element;
  final Map<String, String> _meaning;

  String meaning(String apiLocale) => _meaning[apiLocale] ?? '';
}

/// 起名's 字义库 (assets/i18n/naming_chars.json, v4.5.0).
class NamingLibrary {
  NamingLibrary(this.version, this.reviewed, List<NameCharacter> chars)
      : _byChar = {for (final c in chars) ...{c.hant: c, c.hans: c}};

  factory NamingLibrary.parse(String json) {
    final j = jsonDecode(json) as Json;
    return NamingLibrary(
      j['version'] as String,
      j['reviewed'] as bool,
      [for (final c in j['chars'] as List) NameCharacter.fromJson(c as Json)],
    );
  }

  final String version;

  /// False until the owner's 人工校订.
  final bool reviewed;
  final Map<String, NameCharacter> _byChar;

  NameCharacter? char(String c) => _byChar[c];
}

/// One candidate name: the given name in both scripts, its pinyin and its characters' elements.
class NameCandidate {
  const NameCandidate(this._given, this.pinyin, this.elements);
  final Map<String, String> _given;
  final String pinyin;
  final List<String> elements;

  String given(String apiLocale) => _given[apiLocale == 'zh-Hans' ? 'zh-Hans' : 'zh-Hant'] ?? '';
}

/// A 起名 chart's facts (v4.5.0): the surname, the elements the names serve, and the candidates.
class NamingChart {
  const NamingChart(this._surname, this.elements, this.basis, this.candidates, {this.reviewed = false});

  factory NamingChart.fromFacts(Json f) => NamingChart(
        (f['surname'] as Json).map((k, v) => MapEntry(k, v as String)),
        (f['elements'] as List).cast<String>(),
        f['basis'] as String,
        reviewed: (f['library'] as Json?)?['reviewed'] as bool? ?? false,
        [
          for (final c in f['candidates'] as List)
            NameCandidate(
              ((c as Json)['given'] as Json).cast<String, String>(),
              c['pinyin'] as String,
              (c['elements'] as List).cast<String>(),
            ),
        ],
      );

  final Map<String, String> _surname;
  final List<String> elements;

  /// 'favorable' (the 八字 chart's 喜用) or 'balance' (it has none).
  final String basis;
  final List<NameCandidate> candidates;

  /// Whether the 字义库 the names came from had the owner's review (the chart's `library.reviewed`).
  final bool reviewed;

  String surname(String apiLocale) => _surname[apiLocale == 'zh-Hans' ? 'zh-Hans' : 'zh-Hant'] ?? '';
}
