// S4 WP4.2 (v3.2.0): tapping a term on the 命盘 (or Tab to it and Enter) opens its plain explanation,
// in the reader's script, from term_tips.json (synced from src/ai/term-tips.ts). The fixture chart is
// 庚午 己卯 己卯 辛未 with the day master 己 (yin 土).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_app/application/providers.dart' show zhHant;

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

final tipDialog = find.byKey(const Key('term-tip'));
Finder inTip(String text) => find.descendant(of: tipDialog, matching: find.textContaining(text));
Finder inGrid(String text) => find.descendant(of: find.byKey(const Key('pillar-grid')), matching: find.text(text));

void main() {
  test('the brief form (v4.0.0): English without its pinyin, Chinese as it is', () {
    expect(testTerms.short('伤官', 'en'), 'Hurting Officer'); // Hurting Officer (Shang Guan)
    expect(testTerms.short('病', 'en'), 'Sickness'); // Sickness (Bing)
    expect(testTerms.short('日主', 'en'), 'Day Master'); // no pinyin to drop
    expect(testTerms.short('伤官', 'zh-Hant'), '傷官');
    expect(testTerms.short('伤官', 'zh-Hans'), '伤官');
  });

  testWidgets('a tapped term opens its tip in 繁體; 關閉 closes it', (tester) async {
    await openChart(tester);
    // 年干 庚 is yang 金, which 己 土 generates, of the opposite yin/yang: 傷官.
    await tester.tap(inGrid('傷官'));
    await frames(tester);
    expect(inTip('傷官'), findsOneWidget); // the title
    expect(inTip('敢說敢做'), findsOneWidget);
    await tester.tap(find.descendant(of: tipDialog, matching: find.text('關閉')));
    await frames(tester);
    expect(tipDialog, findsNothing);

    // A row label explains its row; 長生 counts back from 酉 for the yin 己: 午 臨官, 卯 病, 未 冠帶.
    await tester.tap(inGrid('天干'));
    await frames(tester);
    expect(inTip('甲乙丙丁戊己庚辛壬癸'), findsOneWidget);
    await tester.tap(find.descendant(of: tipDialog, matching: find.text('關閉')));
    await frames(tester);
    await tester.tap(find.byKey(const Key('pillar-more')));
    await frames(tester);
    expect(inGrid('病'), findsNWidgets(2)); // 月柱 and 日柱
    await tester.tap(inGrid('病').first);
    await frames(tester);
    expect(inTip('不是指身體生病'), findsOneWidget);
    await tester.tap(find.descendant(of: tipDialog, matching: find.text('關閉')));
    await frames(tester);

    // A card about one term has a 什麼是…？ button: 大運.
    await scrollTo(tester, const Key('dayun-strip'));
    await tester.tap(find.byKey(const Key('tip-大运')));
    await frames(tester);
    expect(inTip('大運'), findsOneWidget);
    expect(inTip('每十年換一段'), findsOneWidget);
  });

  testWidgets('in English the life stages have names and the tips are English', (tester) async {
    await openChart(tester, locale: const Locale('en'));
    await tester.tap(find.byKey(const Key('pillar-more')));
    await frames(tester);
    // 病 had no English name before v3.2.0 and showed as 病. Since v4.0.0 the cell drops the pinyin
    // (WP4.8); the tip's title keeps the full name.
    expect(inGrid('Sickness'), findsNWidgets(2));
    await tester.tap(inGrid('Sickness').first);
    await frames(tester);
    expect(inTip('Sickness (Bing)'), findsOneWidget);
    expect(inTip('a time to rest (not illness)'), findsOneWidget);
    await tester.tap(find.descendant(of: tipDialog, matching: find.text('Close')));
    await frames(tester);
    await scrollTo(tester, const Key('dayun-strip'));
    expect(find.byTooltip('About Luck pillars'), findsOneWidget);
  });

  testWidgets('from the keyboard: Tab reaches a term, Enter opens its tip, Esc closes it', (tester) async {
    await openChart(tester);
    // 己卯 lies in the 甲戌 旬, which leaves 申酉 空.
    await tabTo(tester, 'tip-空亡');
    expect(ringShown(tester, find.byKey(const Key('tip-空亡'))), isTrue);
    await press(tester, LogicalKeyboardKey.enter);
    expect(inTip('空亡'), findsOneWidget);
    expect(inTip('不代表失去'), findsOneWidget);
    await press(tester, LogicalKeyboardKey.escape);
    expect(tipDialog, findsNothing);
    expect(find.text('四柱'), findsOneWidget); // Esc closed the tip, not the page
    expect(focusedKey(), 'tip-空亡');
  });
}
