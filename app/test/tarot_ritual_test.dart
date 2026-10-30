// 洗牌 → 切牌 → 选牌 (v3.0.0): the user shuffles, cuts a pile and picks cards face down; the draw
// request carries the cut and the picks, places in the deck the engine shuffles.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'keys.dart';
import 'support.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The 塔罗 page, three cards (the default), with 抽牌 pressed: the ritual is open.
Future<FakeApi> openRitual(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = FakeApi();
  await tester.pumpWidget(testApp(api));
  await settle(tester);
  await openEntry(tester, 'tarot');
  await settle(tester);
  // The cards are drawn only for a question (v11.1.0).
  await ask(tester, 'tarot-question');
  await tester.ensureVisible(find.byKey(const Key('draw')));
  await tester.pump(); // rule 27
  await tester.tap(find.byKey(const Key('draw')));
  await settle(tester);
  expect(find.byKey(const Key('tarot-ritual')), findsOneWidget);
  return api;
}

Map<String, dynamic> chartRequest(FakeApi api) =>
    jsonDecode(api.requests.lastWhere((r) => r.method == 'POST' && r.url.path == '/v1/charts').body)
        as Map<String, dynamic>;

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pump(); // rule 27
  await tester.tap(find.byKey(Key(key)));
  await settle(tester);
}

void main() {
  testWidgets('shuffle, cut the middle pile, pick three: the request carries the cut and the picks', (tester) async {
    final api = await openRitual(tester);
    await tapKey(tester, 'ritual-shuffle');
    await tapKey(tester, 'ritual-cut-1'); // the second of three piles of 26: cut at 26
    for (final p in [7, 61]) {
      await tapKey(tester, 'ritual-pick-$p');
    }
    expect(find.text('選牌：憑直覺選 3 張（已選 2 張）'), findsOneWidget); // the test app reads 繁體
    await tapKey(tester, 'ritual-pick-7'); // a card picked once stays picked once
    await tapKey(tester, 'ritual-pick-0');
    expect(chartRequest(api)['ritual'], {
      'cut': 26,
      'picks': [7, 61, 0],
    });
    expect(chartRequest(api)['spread'], 'three_card');
    expect(find.byKey(const Key('tarot-ritual')), findsNothing);
    expect(find.byKey(const Key('tarot-card-1')), findsOneWidget); // the spread, face down, to turn
  });

  testWidgets('let the deck pick: a draw without a ritual, as before', (tester) async {
    final api = await openRitual(tester);
    await tapKey(tester, 'ritual-skip');
    expect(chartRequest(api).containsKey('ritual'), isFalse);
    expect(find.byKey(const Key('tarot-card-1')), findsOneWidget);
  });

  testWidgets('keyboard: Enter shuffles, Tab and Enter cut and pick', (tester) async {
    final api = await openRitual(tester);
    await tabTo(tester, 'ritual-shuffle');
    await press(tester, LogicalKeyboardKey.enter);
    await settle(tester);
    await tabTo(tester, 'ritual-cut-2');
    expect(ringShown(tester, find.byKey(const Key('ritual-cut-2'))), isTrue);
    await press(tester, LogicalKeyboardKey.enter);
    await settle(tester);
    for (final p in [0, 1, 2]) {
      await tabTo(tester, 'ritual-pick-$p');
      await press(tester, LogicalKeyboardKey.enter);
      await settle(tester);
    }
    expect(chartRequest(api)['ritual'], {
      'cut': 52,
      'picks': [0, 1, 2],
    });
  });
}
