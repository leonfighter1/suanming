// S4 WP4.3 (v3.3.0): the 大运 running now and this year are marked, tapping a 大运 opens its ten
// years, and the year's 流月 are shown. The fixture chart is 庚午 己卯 己卯 辛未 (born 1990), read in
// 2026: its 大运 are 庚辰 1997, 辛巳 2007, 壬午 2017, …, so 2026 falls in the third (2017–2026).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_app/application/providers.dart' show zhHant;
import 'package:mingli_app/domain/models.dart';

import 'keys.dart';
import 'support.dart';

Future<void> openChart(WidgetTester tester, {Locale locale = zhHant}) async {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(testApp(FakeApi(), locale: locale));
  await frames(tester, 10);
  await tester.tap(find.byKey(const Key('entry-bazi')));
  await frames(tester, 10);
  await scrollTo(tester, const Key('compute-chart'));
  await tester.tap(find.byKey(const Key('compute-chart')));
  await frames(tester, 10);
}

/// The strip item holding [key] with its badge (the badge sits beside it, on its top edge).
Finder itemOf(Key key) => find.ancestor(of: find.byKey(key), matching: find.byType(Stack)).first;
Finder decade(int index) => find.byKey(ValueKey('decade-$index'));
Finder inside(Finder of, String text) => find.descendant(of: of, matching: find.text(text));

void main() {
  testWidgets('當前 marks the running 大运 and 今年 this year', (tester) async {
    await openChart(tester);
    await scrollTo(tester, const Key('dayun-strip'));
    expect(inside(find.byKey(const Key('dayun-strip')), '當前'), findsOneWidget);
    expect(inside(itemOf(const ValueKey('dayun-3')), '當前'), findsOneWidget); // 壬午, 2017–2026
    await scrollTo(tester, const Key('liunian-strip'));
    final strip = find.byKey(const Key('liunian-strip'));
    expect(inside(strip, '今年'), findsOneWidget);
    // The badge is on the first 流年, 2026 (虛歲 2026 − 1990 + 1 = 37).
    final first = find.ancestor(of: inside(strip, '2026 · 虛歲 37'), matching: find.byType(Stack)).first;
    expect(inside(first, '今年'), findsOneWidget);
  });

  testWidgets('tapping a 大运 opens its ten years; tapping it again closes them', (tester) async {
    await openChart(tester);
    await scrollTo(tester, const Key('dayun-strip'));
    expect(find.text('點選一步大運，查看它的十年。'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('dayun-2')));
    await frames(tester);
    // 辛巳, the second 大运: 2007–2016. 2007 is 丁亥: 丁 阴火 generates 己 阴土, same polarity → 偏印;
    // 亥's 本气 壬 阳水 is what 土 controls, opposite polarity → 正財. 虛歲 2007 − 1990 + 1 = 18.
    expect(find.text('辛巳大運 · 2007–2016年'), findsOneWidget);
    expect(inside(decade(2), '2007 · 虛歲 18'), findsOneWidget);
    expect(inside(decade(2), '偏印 / 正財'), findsOneWidget);
    expect(inside(decade(2), '2017 · 虛歲 28'), findsNothing); // the next 大运's first year
    expect(find.text('點選一步大運，查看它的十年。'), findsNothing);

    // Another 大运 replaces it; the current one's years carry 今年 on 2026.
    await tester.tap(find.byKey(const ValueKey('dayun-3')));
    await frames(tester);
    expect(decade(2), findsNothing);
    await tester.drag(find.descendant(of: decade(3), matching: find.byType(Scrollable)), const Offset(-2000, 0));
    await frames(tester);
    expect(inside(decade(3), '今年'), findsOneWidget);
    expect(inside(decade(3), '2026 · 虛歲 37'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('dayun-3')));
    await frames(tester);
    expect(decade(3), findsNothing);
  });

  testWidgets('from the keyboard: Tab reaches a 大运, Enter opens and closes its years', (tester) async {
    await openChart(tester);
    await tabTo(tester, 'dayun-2');
    expect(ringShown(tester, find.byKey(const ValueKey('dayun-2'))), isTrue);
    await press(tester, LogicalKeyboardKey.enter);
    expect(decade(2), findsOneWidget);
    await press(tester, LogicalKeyboardKey.enter);
    expect(decade(2), findsNothing);
    expect(focusedKey(), 'dayun-2');
  });

  testWidgets('流月: the year from 立春, each month with its 节, date and 十神', (tester) async {
    await openChart(tester);
    await scrollTo(tester, const Key('liuyue-card'));
    final card = find.byKey(const Key('liuyue-card'));
    expect(inside(card, '2026年流月'), findsOneWidget);
    // 寅月 庚寅 from 立春 (2026-02-04): 庚 阳金 is what 己 土 generates, opposite polarity → 傷官;
    // 寅's 本气 甲 阳木 controls 土, opposite polarity → 正官. Then 卯月 辛卯 from 驚蟄 (2026-03-05):
    // 辛 阴金, same polarity → 食神; 卯's 本气 乙 阴木 → 七殺.
    for (final text in ['2026-02-04', '立春', '傷官 / 正官', '2026-03-05', '驚蟄', '食神 / 七殺']) {
      expect(inside(card, text), findsOneWidget, reason: text);
    }
  });

  testWidgets('in English a 流年 relation reads with a space: Hour Six Harmonies', (tester) async {
    await openChart(tester, locale: const Locale('en'));
    await scrollTo(tester, const Key('liunian-strip'));
    // 2026's 午 and the hour pillar's 未 make a 六合 (it read 「HourSix Harmonies」 before v3.3.0).
    expect(inside(find.byKey(const Key('liunian-strip')), 'Hour Six Harmonies'), findsOneWidget);
    expect(inside(find.byKey(const Key('liunian-strip')), 'This year'), findsOneWidget);
  });

  testWidgets('in English (v4.0.0) the strips give each part a line, in wider items, without pinyin', (tester) async {
    await openChart(tester, locale: const Locale('en'));
    // The 四柱 table: 年干 庚 is 伤官, Hurting Officer, without (Shang Guan).
    expect(find.descendant(of: find.byKey(const Key('pillar-grid')), matching: find.text('Hurting Officer')), findsOneWidget);
    await scrollTo(tester, const Key('liunian-strip'));
    final strip = find.byKey(const Key('liunian-strip'));
    // 2026 丙午: 丙 阳火 generates 己 阴土, opposite polarity → 正印, Direct Resource; 午's 本气 丁 阴火, same
    // polarity → 偏印, Indirect Resource. Year, 虚岁 (2026 − 1990 + 1 = 37) and each 十神 on a line of its own.
    for (final text in ['2026', 'nominal age 37', 'Direct Resource', 'Indirect Resource']) {
      expect(inside(strip, text), findsWidgets, reason: text);
    }
    final item = find.ancestor(of: inside(strip, 'nominal age 37'), matching: find.byType(Container)).first;
    expect(tester.getSize(item).width, 128);
  });

  test('a chart made before v3.3.0 has no years to open', () {
    final facts = Map<String, dynamic>.of(fixture('chart_bazi')['chart_fact']['facts'] as Map<String, dynamic>)
      ..remove('dayun_years');
    final old = BaziChart.fromFacts(facts);
    expect(old.dayunYears, isEmpty);
    expect(old.yearsOf(2), isEmpty);
    expect(old.currentDayun, 3); // still marked: from the first 流年
    final now = BaziChart.fromFacts(fixture('chart_bazi')['chart_fact']['facts'] as Map<String, dynamic>);
    expect(now.yearsOf(2).map((y) => y.year), [for (var y = 2007; y <= 2016; y++) y]);
  });
}
