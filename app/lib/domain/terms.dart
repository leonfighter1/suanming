import 'dart:convert';

import 'package:flutter/services.dart';

typedef _Names = Map<String, Map<String, String>>;

/// Protected term table, tarot card and position names, position meanings and each spread's
/// positions. All copied from the server's single source by `npm run sync:app` (never edited here).
class Terms {
  const Terms(this._terms, this._cards, this._positions, [this._meanings = const {}, this._spreads = const {}]);

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
    return Terms(
      _names(terms['terms']),
      _names(deck['cards']),
      _names(deck['positions']),
      deck['position_meanings'] == null ? const {} : _names(deck['position_meanings']),
      ((deck['spreads'] as Map<String, dynamic>?) ?? const {}).map((k, v) => MapEntry(k, (v as List).cast<String>())),
    );
  }

  final _Names _terms;
  final _Names _cards;
  final _Names _positions;
  final _Names _meanings;
  final Map<String, List<String>> _spreads;

  /// A spread's position keys in dealing order (deck.ts SPREADS), e.g. past, present, future.
  List<String> spreadPositions(String spreadId) => _spreads[spreadId] ?? const [];

  /// Display form of an engine term (simplified canonical key) for an API locale.
  String t(String key, String apiLocale) => _terms[key]?[apiLocale] ?? key;

  String card(String cardId, String apiLocale) => _cards[cardId]?[apiLocale] ?? cardId;

  String position(String key, String apiLocale) => _positions[key]?[apiLocale] ?? key;

  /// What a spread position stands for in a classic reading ('' if unknown).
  String positionMeaning(String key, String apiLocale) => _meanings[key]?[apiLocale] ?? '';
}
