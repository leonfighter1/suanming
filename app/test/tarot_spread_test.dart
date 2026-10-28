// 塔罗 the classic way: each spread laid out as it prescribes, cards turned in dealing order,
// thumbnails opened large on a phone, the question asked before the draw.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mingli_app/presentation/widgets/tarot_spread.dart';

import 'keys.dart';
import 'support.dart';

Future<void> settle(WidgetTester tester) async {
  // Progress indicators animate forever, so pumpAndSettle would time out.
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// A fresh app of [size] on the 塔罗 page, [question] typed, [focus] chosen, [spread] picked,
/// cards drawn. With [finalReport], a requested reading comes back as that report at once.
Future<FakeApi> drawAt(
  WidgetTester tester,
  Size size, {
  String? spread,
  String question = '',
  String? focus,
  Map<String, dynamic>? finalReport,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = finalReport == null ? FakeApi() : FakeApi(finalReport: finalReport, pendingPolls: 0);
  await tester.pumpWidget(const SizedBox.shrink()); // a fresh app, not the last one updated (rule 24)
  await tester.pumpWidget(testApp(api));
  await settle(tester);
  await tester.tap(find.byKey(const Key('entry-tarot')));
  await settle(tester);
  if (question.isNotEmpty) await tester.enterText(find.byKey(const Key('tarot-question')), question);
  if (focus != null) {
    await tester.pump(); // a frame after enterText (rule 19)
    await tester.ensureVisible(find.byKey(Key('focus-$focus')));
    await tester.pump(); // a frame after the jump, before the tap (rule 27)
    await tester.tap(find.byKey(Key('focus-$focus')));
    await settle(tester);
  }
  if (spread != null) {
    await tester.ensureVisible(find.byKey(Key('spread-$spread')));
    await tester.pump(); // a frame after the jump, before the tap (rule 27)
    // The segment's button takes the touch; its label isn't in the hit path, hence no warning.
    await tester.tap(find.byKey(Key('spread-$spread')), warnIfMissed: false);
    await settle(tester);
  }
  await tester.ensureVisible(find.byKey(const Key('draw')));
  await tester.pump(); // a frame after the jump, before the tap (rule 27)
  await tester.tap(find.byKey(const Key('draw')));
  await settle(tester);
  return api;
}

Rect card(WidgetTester tester, int n) => tester.getRect(find.byKey(Key('tarot-card-$n')));
String spoken(WidgetTester tester, int n) => tester.getSemantics(find.byKey(Key('tarot-card-$n'))).label;

void main() {
  const celtic = 'celtic_cross'; // a spread picker segment (v2.5.0); the test app reads 繁體

  Future<void> openTarot(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const SizedBox.shrink()); // rule 24
    await tester.pumpWidget(testApp(FakeApi()));
    await settle(tester);
    await tester.tap(find.byKey(const Key('entry-tarot')));
    await settle(tester);
  }

  testWidgets('the picker draws each spread small and lists its positions before the draw', (tester) async {
    await openTarot(tester);
    String listed() => tester.widget<Text>(find.byKey(const Key('spread-positions'))).data!;
    String expected(String id) => [
          for (final (i, p) in testTerms.spreadPositions(id).indexed) '${i + 1} ${testTerms.position(p, 'zh-Hant')}',
        ].join(' · ');
    expect(testTerms.spreadPositions('celtic_cross'), hasLength(10)); // deck.ts SPREADS, synced
    expect(listed(), expected('three_card')); // the default
    for (final id in ['celtic_cross', 'single']) {
      await tester.tap(find.byKey(Key('spread-$id')), warnIfMissed: false); // the segment takes it
      await settle(tester);
      expect(listed(), expected(id));
    }
    // Each segment carries its small drawing: 1, 3 and 10 card outlines.
    for (final (id, n) in [('single', 1), ('three_card', 3), ('celtic_cross', 10)]) {
      final diagram = find.descendant(of: find.byKey(Key('spread-$id')), matching: find.byType(SpreadDiagram));
      expect(find.descendant(of: diagram, matching: find.byType(DecoratedBox)), findsNWidgets(n), reason: id);
    }
  });

  testWidgets('an example question goes into the field with one touch', (tester) async {
    await openTarot(tester);
    await tester.tap(find.byKey(const Key('example-1')));
    await tester.pump();
    expect(tester.widget<TextField>(find.byKey(const Key('tarot-question'))).controller!.text, '我們的關係會往哪裡走？');
  });

  testWidgets('three cards lie in one row: past, present, future', (tester) async {
    // Phone, 360 wide: content 360 − 2×16 (page) − 2×(20 + 1) (card padding + border) = 286;
    // three cards of ⌊(286 − 2×12) / 3⌋ = ⌊87.3⌋ = 87, side by side.
    await drawAt(tester, const Size(360, 2000));
    expect([for (final n in [1, 2, 3]) card(tester, n).width], [87, 87, 87]);
    expect([card(tester, 2).top, card(tester, 3).top], [card(tester, 1).top, card(tester, 1).top]);
    expect(card(tester, 1).left, lessThan(card(tester, 2).left));
    expect(card(tester, 2).left, lessThan(card(tester, 3).left));

    // Desktop, 1000 wide: the cap, twice the first 104-pt card = 208; still one row.
    await drawAt(tester, const Size(1000, 2000));
    expect(card(tester, 1).width, 208);
    expect(card(tester, 3).top, card(tester, 1).top);
  });

  testWidgets('Celtic Cross on a desktop: the cross and the staff, all on one screen', (tester) async {
    // 1000 × 900: content 926 wide. A card is the smaller of 926 / 5.6 = 165.4 (width) and
    // (900 − 160) / (4 × 12/7 + 3 × 0.1) = 740 / 7.157 = 103.4 (height): ⌊103.4⌋ = 103.
    await drawAt(tester, const Size(1000, 900), spread: celtic);
    final r = {for (var n = 1; n <= 10; n++) n: card(tester, n)};
    expect(r[1]!.width, 103);
    // 2 lies across 1: the same centre, turned sideways (103 × 12/7 = 176.6 wide, 103 tall).
    expect(r[2]!.center.dx, closeTo(r[1]!.center.dx, 0.01));
    expect(r[2]!.center.dy, closeTo(r[1]!.center.dy, 0.01));
    expect(r[2]!.width, closeTo(103 * 12 / 7, 0.01));
    expect(r[2]!.height, 103);
    // 3 below, 5 above (the crown), 4 behind (left), 6 ahead (right), clear of card 2.
    expect(r[3]!.left, r[1]!.left);
    expect(r[3]!.top, greaterThan(r[1]!.bottom));
    expect(r[5]!.left, r[1]!.left);
    expect(r[5]!.bottom, lessThan(r[1]!.top));
    expect(r[4]!.top, r[1]!.top);
    expect(r[4]!.right, lessThan(r[2]!.left));
    expect(r[6]!.top, r[1]!.top);
    expect(r[6]!.left, greaterThan(r[2]!.right));
    // The staff: one column right of the cross, 7 at the bottom up to 10 at the top.
    expect(r[7]!.left, greaterThan(r[6]!.right));
    for (final n in [8, 9, 10]) {
      expect(r[n]!.left, r[7]!.left);
      expect(r[n]!.bottom, lessThan(r[n - 1]!.top));
    }
    // The whole spread is 7.157 × 103 = 737 tall: it fits the 900-tall screen.
    expect(r[7]!.bottom - r[10]!.top, closeTo(103 * (4 * 12 / 7 + 0.3), 0.01));
  });

  testWidgets('cards turn in dealing order; a turned card opens large with its meaning', (tester) async {
    await drawAt(tester, const Size(1000, 2000)); // three cards of 208: they turn where they lie
    final semantics = tester.ensureSemantics();
    // Touching the third card first turns the first one: the classic order.
    await tester.tap(find.byKey(const Key('tarot-card-3')));
    await settle(tester);
    expect(spoken(tester, 1), isNot(contains('未翻開')));
    expect(spoken(tester, 2), contains('下一張'));
    expect(spoken(tester, 3), contains('未翻開'));
    // A turned card opens large with what its position stands for.
    await tester.tap(find.byKey(const Key('tarot-card-1')));
    await settle(tester);
    final view = find.byKey(const Key('tarot-card-view'));
    expect(find.descendant(of: view, matching: find.text(testTerms.positionMeaning('past', 'zh-Hant'))), findsOneWidget);
    await tester.tap(find.byKey(const Key('tarot-card-view-close')));
    await settle(tester);
    expect(view, findsNothing);
    semantics.dispose();
  });

  testWidgets('a phone shows the Celtic Cross as thumbnails: one opens large and turns there', (tester) async {
    // 360 × 800: content 286. A card is the smaller of 286 / 5.6 = 51.1 and
    // (800 − 160) / 7.157 = 89.4: ⌊51.1⌋ = 51, a thumbnail (under 96).
    await drawAt(tester, const Size(360, 800), spread: celtic);
    expect(card(tester, 1).width, 51);
    // The list under it reads at 1.5× text even on a phone (v2.5.0): here the spread's own
    // scale is (286 − 12) / 2 / 104 = 1.32, so the list takes 1.5.
    final row = find.descendant(of: find.byKey(const Key('tarot-slot-1')), matching: find.byType(Text)).first;
    final base = Theme.of(tester.element(row)).textTheme.bodyMedium!.fontSize!;
    expect(tester.widget<Text>(row).style!.fontSize, base * 1.5);
    // Touching any face-down thumbnail opens the next card, card 1, still face down.
    await tester.ensureVisible(find.byKey(const Key('tarot-card-5')));
    await tester.pump(); // a frame after the jump, before the tap (rule 27)
    await tester.tap(find.byKey(const Key('tarot-card-5')));
    await settle(tester);
    final view = find.byKey(const Key('tarot-card-view'));
    expect(find.descendant(of: view, matching: find.text('第 1 張 · 現在')), findsOneWidget);
    // Touching it there turns it; closed again, the spread shows it turned.
    await tester.tap(find.byKey(const Key('tarot-card-view-card')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('tarot-card-view-close')));
    await settle(tester);
    expect(view, findsNothing);
    final semantics = tester.ensureSemantics();
    expect(spoken(tester, 1), isNot(contains('未翻開')));
    expect(find.textContaining('下一張：第 2 張 · 挑戰'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('keyboard: the enlarged card has the focus, Enter turns it, Esc closes it', (tester) async {
    await drawAt(tester, const Size(360, 800), spread: celtic);
    await tester.ensureVisible(find.byKey(const Key('tarot-card-5')));
    await tester.pump(); // a frame after the jump, before the tap (rule 27)
    await tester.tap(find.byKey(const Key('tarot-card-5'))); // opens card 1, face down
    await settle(tester);
    await press(tester, LogicalKeyboardKey.enter);
    await settle(tester);
    final first = (fixture('chart_tarot_celtic')['chart_fact']['facts']['cards'] as List).first as Map;
    final view = find.byKey(const Key('tarot-card-view'));
    expect(find.descendant(of: view, matching: find.textContaining(testTerms.card(first['card_id'] as String, 'zh-Hant'))), findsWidgets);
    await press(tester, LogicalKeyboardKey.escape);
    expect(view, findsNothing);
  });

  testWidgets('the question asked before drawing goes with the reading request', (tester) async {
    final api = await drawAt(tester, const Size(1000, 2000), question: '我該不該換工作？');
    expect(find.text('問題：我該不該換工作？'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const Key('tarot-card-3'))); // each touch turns the next card
      await settle(tester);
    }
    await tester.scrollUntilVisible(find.byKey(const Key('generate-report')), 300, scrollable: mainScrollable);
    await tester.tap(find.byKey(const Key('generate-report')));
    await settle(tester);
    final sent = api.requests.lastWhere((r) => r.method == 'POST' && r.url.path == '/v1/reports');
    expect((jsonDecode(sent.body) as Map)['question'], '我該不該換工作？');
    expect((jsonDecode(sent.body) as Map).containsKey('focus'), isFalse); // 不限 by default
  });

  testWidgets('the focus beside the question goes with the request; the reading has three parts and one plan', (
    tester,
  ) async {
    final api = await drawAt(
      tester,
      const Size(1000, 2000),
      question: '這份工作還要繼續嗎？',
      focus: 'career_wealth',
      finalReport: fixture('report_tarot_passed'),
    );
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const Key('tarot-card-3')));
      await settle(tester);
    }
    // A tarot reading's parts are fixed: no topic chips to pick.
    await scrollTo(tester, const Key('generate-report'));
    expect(find.byKey(const Key('tarot-sections')), findsOneWidget);
    expect(find.byType(FilterChip), findsNothing);
    await tester.tap(find.byKey(const Key('generate-report')));
    await settle(tester);
    final sent = jsonDecode(api.requests.lastWhere((r) => r.method == 'POST' && r.url.path == '/v1/reports').body) as Map;
    expect(sent['focus'], 'career_wealth');
    expect(sent['topics'], ['tarot_cards', 'tarot_synthesis', 'tarot_advice']);

    // The reading page shows the spread on top, with its art, every card turned (v2.4.0).
    final spread = find.byKey(const Key('reading-spread'));
    expect(spread, findsOneWidget);
    final semantics = tester.ensureSemantics();
    for (var n = 1; n <= 3; n++) {
      final c = find.descendant(of: spread, matching: find.byKey(Key('tarot-card-$n')));
      expect(tester.getSemantics(c).label, isNot(contains('未翻開')));
    }
    semantics.dispose();
    expect(tester.getTopLeft(spread).dy, lessThan(tester.getTopLeft(find.text('逐張解讀').first).dy));

    // The reading: 逐張解讀, 綜合解讀 and 建議, in that order; a plan for 建議 only.
    final tops = [for (final t in ['逐張解讀', '綜合解讀', '建議']) tester.getTopLeft(find.text(t).first).dy];
    expect(tops, [...tops]..sort());
    expect(find.byKey(const Key('remedy-inline-tarot_cards')), findsNothing); // the first part, open
    await scrollTo(tester, const Key('remedy-card'));
    expect(find.byKey(const Key('remedy-buy-tarot_advice')), findsOneWidget);
    expect(find.byKey(const Key('remedy-buy-tarot_cards')), findsNothing);
    expect(find.byKey(const Key('remedy-buy-tarot_synthesis')), findsNothing);
  });

  testWidgets('历史记录 shows a tarot reading with its cards\' art, a reversed card upside down', (tester) async {
    final draw = fixture('chart_tarot')['chart_fact']['facts']['cards'] as List;
    final api = FakeApi(
      history: [
        {
          'report_id': '55555555-5555-4555-8555-555555555555',
          'chart_id': '33333333-3333-4333-8333-333333333333',
          'status': 'passed',
          'created_at': '2026-10-25T00:00:00.000Z',
          'updated_at': '2026-10-25T00:00:00.000Z',
          'locale': 'zh-Hant',
          'topics': ['tarot_cards', 'tarot_synthesis', 'tarot_advice'],
          'chart': {
            'system': 'tarot',
            'spread': 'three_card',
            'cards': [for (final c in draw) {'card_id': c['card_id'], 'reversed': c['reversed']}],
          },
        },
      ],
    );
    await tester.pumpWidget(testApp(api));
    await settle(tester);
    await tester.tap(find.byKey(const Key('open-history')));
    await settle(tester);
    final art = find.byKey(const Key('history-art'));
    expect(art, findsOneWidget);
    expect(find.descendant(of: art, matching: find.byType(Image)), findsNWidgets(draw.length));
    final turns = tester
        .widgetList<RotatedBox>(find.descendant(of: art, matching: find.byType(RotatedBox)))
        .map((b) => b.quarterTurns)
        .toList();
    expect(turns, [for (final c in draw) c['reversed'] == true ? 2 : 0]);
  });
}
