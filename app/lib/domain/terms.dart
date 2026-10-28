import 'dart:convert';

import 'package:flutter/services.dart';

typedef _Names = Map<String, Map<String, String>>;

/// Protected term table, tarot card and position names, position meanings, each spread's
/// positions and what each 八字 term means. All copied from the server's single source by
/// `npm run sync:app` (never edited here).
class Terms {
  const Terms(
    this._terms,
    this._cards,
    this._positions, [
    this._meanings = const {},
    this._spreads = const {},
    this._keywords = const {},
    this._tips = const {},
  ]);

  static _Names _names(Object? v) => (v as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, (v as Map<String, dynamic>).cast<String, String>()),
      );

  static Future<Terms> load(AssetBundle bundle) async => Terms.parse(
        await bundle.loadString('assets/i18n/terms.json'),
        await bundle.loadString('assets/i18n/tarot_deck.json'),
        await bundle.loadString('assets/i18n/term_tips.json'),
      );

  factory Terms.parse(String termsJson, String deckJson, [String? tipsJson]) {
    final terms = jsonDecode(termsJson) as Map<String, dynamic>;
    final deck = jsonDecode(deckJson) as Map<String, dynamic>;
    return Terms(
      _names(terms['terms']),
      _names(deck['cards']),
      _names(deck['positions']),
      deck['position_meanings'] == null ? const {} : _names(deck['position_meanings']),
      ((deck['spreads'] as Map<String, dynamic>?) ?? const {}).map((k, v) => MapEntry(k, (v as List).cast<String>())),
      ((deck['keywords'] as Map<String, dynamic>?) ?? const {}).map(
        (id, byLocale) => MapEntry(
          id,
          (byLocale as Map<String, dynamic>).map((locale, words) => MapEntry(locale, (words as List).cast<String>())),
        ),
      ),
      tipsJson == null ? const {} : _names((jsonDecode(tipsJson) as Map<String, dynamic>)['tips']),
    );
  }

  final _Names _terms;
  final _Names _cards;
  final _Names _positions;
  final _Names _meanings;
  final Map<String, List<String>> _spreads;
  final Map<String, Map<String, List<String>>> _keywords;
  final _Names _tips;

  /// A spread's position keys in dealing order (deck.ts SPREADS), e.g. past, present, future.
  List<String> spreadPositions(String spreadId) => _spreads[spreadId] ?? const [];

  /// Every card id in deck order: the major arcana, then wands, cups, swords and pentacles.
  List<String> get cardIds => _cards.keys.toList();

  /// The three keywords painted on a card, in the reader's script (deck KEYWORDS).
  List<String> keywords(String cardId, String apiLocale) => _keywords[cardId]?[apiLocale] ?? const [];

  /// Display form of an engine term (simplified canonical key) for an API locale.
  String t(String key, String apiLocale) => _terms[key]?[apiLocale] ?? key;

  String card(String cardId, String apiLocale) => _cards[cardId]?[apiLocale] ?? cardId;

  String position(String key, String apiLocale) => _positions[key]?[apiLocale] ?? key;

  /// What a spread position stands for in a classic reading ('' if unknown).
  String positionMeaning(String key, String apiLocale) => _meanings[key]?[apiLocale] ?? '';

  /// What a 八字 term (simplified canonical key, e.g. 七杀 or 十二长生) means in plain words, for
  /// an API locale ('' if it has no tip). From src/ai/term-tips.ts (v3.2.0).
  String tip(String key, String apiLocale) => _tips[key]?[apiLocale] ?? '';
}
