import 'dart:convert';

import 'package:flutter/services.dart';

typedef _Names = Map<String, Map<String, String>>;

/// Protected term table, tarot card and position names. All copied from the
/// server's single source by `npm run sync:app` (never edited here).
class Terms {
  const Terms(this._terms, this._cards, this._positions);

  static _Names _names(Object? v) => (v as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, (v as Map<String, dynamic>).cast<String, String>()),
      );

  static Future<Terms> load(AssetBundle bundle) async => Terms.parse(
        await bundle.loadString('assets/i18n/terms.json'),
        await bundle.loadString('assets/i18n/tarot_deck.json'),
      );

  factory Terms.parse(String termsJson, String deckJson) {
    final terms = jsonDecode(termsJson) as Map<String, dynamic>;
    final deck = jsonDecode(deckJson) as Map<String, dynamic>;
    return Terms(_names(terms['terms']), _names(deck['cards']), _names(deck['positions']));
  }

  final _Names _terms;
  final _Names _cards;
  final _Names _positions;

  /// Display form of an engine term (simplified canonical key) for an API locale.
  String t(String key, String apiLocale) => _terms[key]?[apiLocale] ?? key;

  String card(String cardId, String apiLocale) => _cards[cardId]?[apiLocale] ?? cardId;

  String position(String key, String apiLocale) => _positions[key]?[apiLocale] ?? key;
}
