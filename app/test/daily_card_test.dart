// 每日一牌 on 首页 (v2.6.0): the account's card of the day, opened large, with an AI reading.
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

void main() {
  testWidgets('首页 shows the card of the day; it opens large, with an AI reading to ask for', (tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = FakeApi();
    await tester.pumpWidget(testApp(api));
    await settle(tester);

    final card = (fixture('chart_tarot_single')['chart_fact']['facts']['cards'] as List).first as Map;
    final name = testTerms.card(card['card_id'] as String, 'zh-Hant'); // the test app reads 繁體
    await scrollTo(tester, const Key('daily-card'));
    expect(
      tester.widget<Text>(find.byKey(const Key('daily-card-name'))).data,
      card['reversed'] == true ? '$name · 逆位' : name,
    );
    // Asked for the device's calendar date.
    final asked = api.requests.where((r) => r.url.path == '/v1/tarot/daily').map((r) => r.url.queryParameters['date']);
    expect(asked, isNotEmpty);
    expect(asked.every((d) => RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(d ?? '')), isTrue);

    await tester.tap(find.byKey(const Key('daily-card')));
    await settle(tester);
    expect(find.byKey(const Key('daily-card-spread')), findsOneWidget);
    expect(find.byKey(const Key('tarot-card-1')), findsOneWidget);
    await scrollTo(tester, const Key('generate-report'));
    expect(find.byKey(const Key('tarot-sections')), findsOneWidget); // a tarot reading of the one card
    // Only 八字's button asks for 用AI做更精确解读 (v9.3.0); every other method keeps its label.
    expect(find.descendant(of: find.byKey(const Key('generate-report')), matching: find.text('生成 AI 解讀')),
        findsOneWidget);
  });

  testWidgets('keyboard: Tab reaches the card of the day, Enter opens it, Esc comes back', (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(FakeApi()));
    await settle(tester);
    await tabTo(tester, 'daily-card');
    expect(ringShown(tester, find.byKey(const Key('daily-card'))), isTrue);
    await press(tester, LogicalKeyboardKey.enter);
    await settle(tester);
    expect(find.byKey(const Key('daily-card-spread')), findsOneWidget);
    await press(tester, LogicalKeyboardKey.escape);
    await settle(tester);
    expect(find.byKey(const Key('daily-card')), findsOneWidget);
  });
}
