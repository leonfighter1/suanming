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
  await scrollToFinder(tester, finder);
  await tester.ensureVisible(finder);
  await settle(tester);
  await tester.tap(finder);
}

void main() {
  testWidgets('home shows both entries in 繁體 by default', (tester) async {
    await tester.pumpWidget(testApp(FakeApi()));
    await settle(tester);
    expect(find.text('命理大師'), findsWidgets); // app bar + greeting banner
    expect(find.byKey(const Key('entry-bazi')), findsOneWidget);
    await scrollTo(tester, const Key('entry-tarot')); // 西方, below 東方 (v6.1.0)
    expect(find.text('塔羅'), findsOneWidget);
  });

  testWidgets('home groups the methods: 東方 (八字, 求籤, 算卦, 風水), then 西方 (塔羅) (owner, v6.1.0)', (tester) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = FakeApi();
    await tester.pumpWidget(testApp(api));
    await settle(tester);
    double y(String key) => tester.getTopLeft(find.byKey(Key(key))).dy;
    expect(find.descendant(of: find.byKey(const Key('group-east')), matching: find.text('東方')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('group-west')), matching: find.text('西方')), findsOneWidget);
    // 東方 in the region's order (the default here), all above 西方.
    final east = [for (final k in ['entry-bazi', 'entry-qiuqian', 'entry-liuyao', 'entry-fengshui']) y(k)];
    expect(east, [...east]..sort());
    expect(east.first, greaterThan(y('group-east')));
    expect(east.last, lessThan(y('group-west')));
    expect(y('entry-tarot'), greaterThan(y('group-west')));

    // A region whose matrix leaves out every 西方 method shows no 西方 heading.
    api.methods = const ['qiuqian', 'bazi'];
    await tester.pumpWidget(const SizedBox.shrink()); // a fresh app (rule 24)
    await tester.pumpWidget(testApp(api));
    await settle(tester);
    expect(find.byKey(const Key('group-east')), findsOneWidget); // the anchor (rule 43)
    expect(y('entry-qiuqian'), lessThan(y('entry-bazi')));
    expect(find.byKey(const Key('entry-tarot')), findsNothing);
    expect(find.byKey(const Key('group-west')), findsNothing);
  });

  testWidgets('bazi: compute chart → pillars with protected 繁體 terms', (tester) async {
    final api = FakeApi();
    await tester.pumpWidget(testApp(api));
    await settle(tester);
    await tester.tap(find.byKey(const Key('entry-bazi')));
    await settle(tester);
    await scrollAndTap(tester, find.byKey(const Key('compute-chart')));
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
    await scrollToFinder(tester, find.text('流年'));
    expect(find.text('流年'), findsOneWidget);
  });

  testWidgets('report: polls pending → passed and shows layers with the AI label', (tester) async {
    final api = FakeApi(pendingPolls: 2);
    await tester.pumpWidget(testApp(api));
    await settle(tester);
    await tester.tap(find.byKey(const Key('entry-bazi')));
    await settle(tester);
    await scrollAndTap(tester, find.byKey(const Key('compute-chart')));
    await settle(tester);
    await scrollAndTap(tester, find.byKey(const Key('generate-report')));
    await settle(tester);
    await settle(tester);

    final createReport = api.requests.firstWhere((r) => r.method == 'POST' && r.url.path == '/v1/reports');
    expect((jsonDecode(createReport.body) as Map)['locale'], 'zh-Hant');
    expect(find.byKey(const Key('ai-label')), findsOneWidget);
    // The trend chart comes first; the facts card is below it.
    expect(find.byKey(const Key('trend-card')), findsOneWidget);
    await scrollToFinder(tester, find.text('命盤事實 · 引擎計算，非 AI'));
    expect(find.text('命盤事實 · 引擎計算，非 AI'), findsOneWidget);
    expect(find.textContaining('四柱：庚午 己卯 己卯 辛未'), findsOneWidget);
    final polls = RegExp(r'^/v1/reports/[^/]+$');
    expect(api.requests.where((r) => polls.hasMatch(r.url.path)).length, 3); // 2 pending + 1 passed
  });

  testWidgets('report: blocked reports show no content', (tester) async {
    final blocked = {...fixture('report_passed'), 'status': 'blocked', 'layers': null, 'ai_disclosure': null};
    await tester.pumpWidget(testApp(FakeApi(finalReport: blocked, pendingPolls: 0)));
    await settle(tester);
    await tester.tap(find.byKey(const Key('entry-bazi')));
    await settle(tester);
    await scrollAndTap(tester, find.byKey(const Key('compute-chart')));
    await settle(tester);
    await scrollAndTap(tester, find.byKey(const Key('generate-report')));
    await settle(tester);

    expect(find.textContaining('未通過內容審查'), findsOneWidget);
    expect(find.byKey(const Key('ai-label')), findsNothing);
  });

  testWidgets('tarot: draw, reveal all cards, then the reading request appears', (tester) async {
    await tester.pumpWidget(testApp(FakeApi()));
    await settle(tester);
    await openEntry(tester, 'tarot');
    await settle(tester);
    await ask(tester, 'tarot-question'); // drawn only for a question (v11.1.0)
    await scrollAndTap(tester, find.byKey(const Key('draw')));
    await settle(tester);
    // The ritual opens first (v3.0.0); here the deck picks (tarot_ritual_test.dart has the rest).
    await scrollAndTap(tester, find.byKey(const Key('ritual-skip')));
    await settle(tester);
    expect(find.byKey(const Key('generate-report')), findsNothing);
    for (final pos in ['過去', '現在', '未來']) {
      await scrollAndTap(tester, find.text(pos));
      await settle(tester);
    }
    // Each turned card shows its art; the name in the reader's language goes under it.
    for (final id in ['major_09', 'major_05', 'swords_07']) {
      expect(find.image(AssetImage('assets/tarot/$id.webp')), findsOneWidget);
    }
    expect(find.text('隱士'), findsOneWidget);
    await scrollTo(tester, const Key('generate-report'));
    expect(find.byKey(const Key('generate-report')), findsOneWidget);
  });
}
