import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

Future<void> settle(WidgetTester tester) async {
  // Progress indicators animate forever, so pumpAndSettle would time out.
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Scroll a lazily built list until [finder] exists, centre it, then tap it.
Future<void> scrollAndTap(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 300, scrollable: mainScrollable);
  await tester.ensureVisible(finder);
  await settle(tester);
  await tester.tap(finder);
}

void main() {
  testWidgets('home shows both entries in 繁體 by default', (tester) async {
    await tester.pumpWidget(testApp(FakeApi()));
    await settle(tester);
    expect(find.text('命理大師'), findsOneWidget);
    expect(find.text('八字排盤'), findsOneWidget);
    expect(find.text('塔羅'), findsOneWidget);
  });

  testWidgets('bazi: compute chart → pillars with protected 繁體 terms', (tester) async {
    final api = FakeApi();
    await tester.pumpWidget(testApp(api));
    await settle(tester);
    await tester.tap(find.byKey(const Key('entry-bazi')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('compute-chart')));
    await settle(tester);

    final body = jsonDecode(api.requests.singleWhere((r) => r.url.path == '/v1/charts').body) as Map<String, dynamic>;
    expect(body, containsPair('system', 'bazi'));
    expect(body, containsPair('timezone', 'Asia/Hong_Kong'));
    expect(body['local'], '1990-03-15T14:30');

    expect(find.text('四柱'), findsOneWidget);
    // 年干庚 is 傷官 to 己 — engine emits 伤官, the term table must render 繁體.
    expect(find.text('傷官'), findsWidgets);
    expect(find.text('伤官'), findsNothing);
    // ListView builds lazily: scroll before looking for lower cards.
    await tester.scrollUntilVisible(find.text('流年'), 300, scrollable: mainScrollable);
    expect(find.text('流年'), findsOneWidget);
  });

  testWidgets('report: polls pending → passed and shows layers with the AI label', (tester) async {
    final api = FakeApi(pendingPolls: 2);
    await tester.pumpWidget(testApp(api));
    await settle(tester);
    await tester.tap(find.byKey(const Key('entry-bazi')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('compute-chart')));
    await settle(tester);
    await scrollAndTap(tester, find.byKey(const Key('generate-report')));
    await settle(tester);
    await settle(tester);

    final createReport = api.requests.firstWhere((r) => r.url.path == '/v1/reports');
    expect((jsonDecode(createReport.body) as Map)['locale'], 'zh-Hant');
    expect(find.byKey(const Key('ai-label')), findsOneWidget);
    expect(find.text('命盤事實 · 引擎計算，非 AI'), findsOneWidget);
    expect(find.textContaining('四柱：庚午 己卯 己卯 辛未'), findsOneWidget);
    expect(api.requests.where((r) => r.url.path.startsWith('/v1/reports/')).length, 3); // 2 pending + 1 passed
  });

  testWidgets('report: blocked reports show no content', (tester) async {
    final blocked = {...fixture('report_passed'), 'status': 'blocked', 'layers': null, 'ai_disclosure': null};
    await tester.pumpWidget(testApp(FakeApi(finalReport: blocked, pendingPolls: 0)));
    await settle(tester);
    await tester.tap(find.byKey(const Key('entry-bazi')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('compute-chart')));
    await settle(tester);
    await scrollAndTap(tester, find.byKey(const Key('generate-report')));
    await settle(tester);

    expect(find.textContaining('未通過內容審查'), findsOneWidget);
    expect(find.byKey(const Key('ai-label')), findsNothing);
  });

  testWidgets('tarot: draw, reveal all cards, then the reading request appears', (tester) async {
    await tester.pumpWidget(testApp(FakeApi()));
    await settle(tester);
    await tester.tap(find.byKey(const Key('entry-tarot')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('draw')));
    await settle(tester);
    expect(find.byKey(const Key('generate-report')), findsNothing);
    for (final pos in ['過去', '現在', '未來']) {
      await tester.tap(find.text(pos));
      await settle(tester);
    }
    await tester.scrollUntilVisible(find.byKey(const Key('generate-report')), 300, scrollable: mainScrollable);
    expect(find.byKey(const Key('generate-report')), findsOneWidget);
  });
}
