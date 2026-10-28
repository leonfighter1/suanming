import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The art comes from `npm run mirror:tarot`; this checks what the app gets: every
  // card of the deck in the bundle (pubspec), decoded by Flutter itself, 7:12.
  testWidgets('every card of the deck has its picture in the app bundle', (tester) async {
    final deck = jsonDecode(File('assets/i18n/tarot_deck.json').readAsStringSync()) as Map<String, dynamic>;
    final ids = (deck['cards'] as Map<String, dynamic>).keys.toList();
    expect(ids, hasLength(78));
    await tester.runAsync(() async {
      for (final id in ids) {
        final data = await rootBundle.load('assets/tarot/$id.webp');
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final image = (await codec.getNextFrame()).image;
        expect((image.width, image.height), (700, 1200), reason: id);
        image.dispose();
        codec.dispose();
      }
    });
  });
}
