// 牌义图鉴 (v2.7.0): all 78 cards with their art and the three keywords painted on each.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'keys.dart';
import 'support.dart';

Future<void> openGlossary(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(testApp(FakeApi()));
  await frames(tester, 10);
  await openEntry(tester, 'tarot');
  await frames(tester, 10);
  await tester.tap(find.byKey(const Key('open-glossary')));
  await frames(tester, 10);
}

void main() {
  testWidgets('every card in deck order, grouped; one opens with its keywords, in 繁體', (tester) async {
    await openGlossary(tester);
    // The major arcana first: 22 cards, 0 to XXI.
    final majors = find.descendant(of: find.byKey(const Key('glossary-group-major')), matching: find.byType(Image));
    expect(majors, findsNWidgets(22));
    expect(testTerms.cardIds, hasLength(78));

    await tester.tap(find.byKey(const Key('glossary-major_17'))); // 星星
    await frames(tester, 10);
    final words = find.descendant(of: find.byKey(const Key('glossary-keywords')), matching: find.byType(Text));
    expect([for (final t in tester.widgetList<Text>(words)) t.data], testTerms.keywords('major_17', 'zh-Hant'));
    expect(testTerms.keywords('major_17', 'zh-Hant'), contains('療癒')); // the reviewed 繁體 form (G18)
    await press(tester, LogicalKeyboardKey.escape);
    await frames(tester, 10);
    expect(find.byKey(const Key('glossary-card')), findsNothing);

    // The suits follow, down to the last card of the deck, 星幣國王.
    for (final suit in ['wands', 'cups', 'swords', 'pentacles']) {
      await scrollTo(tester, Key('glossary-group-$suit'));
      final cards = find.descendant(of: find.byKey(Key('glossary-group-$suit')), matching: find.byType(Image));
      expect(cards, findsNWidgets(14), reason: suit);
    }
    expect(find.byKey(const Key('glossary-pentacles_14')), findsOneWidget);
  });

  testWidgets('keyboard: Tab reaches a card, Enter opens it, Esc closes it', (tester) async {
    await openGlossary(tester);
    await tabTo(tester, 'glossary-major_00');
    await press(tester, LogicalKeyboardKey.enter);
    await frames(tester, 10);
    expect(find.byKey(const Key('glossary-card')), findsOneWidget);
    await press(tester, LogicalKeyboardKey.escape);
    await frames(tester, 10);
    expect(find.byKey(const Key('glossary-card')), findsNothing);
  });
}
