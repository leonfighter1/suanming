// S4 WP4.5 (v3.4.0): a reading opens with its chart (a 八字 reading's four pillars; a tarot
// reading's spread is in tarot_spread_test) and a jump list to every section and to 行动建议.
// report_passed has six sections, 五行 to 健康, and since v9.3.0 (S18) a 总结 and no actions; only 五行
// starts open. report_tarot_passed still has its actions.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_app/application/providers.dart' show shareProvider;
import 'package:mingli_app/generated/contract.g.dart' show conclusionParts;
import 'package:mingli_app/presentation/history_page.dart' show HistoryTile;
import 'package:mingli_app/presentation/theme.dart';
import 'package:share_plus/share_plus.dart' show ShareParams;

import 'keys.dart';
import 'support.dart';

/// A phone-sized view, so the last sections start out of sight.
Future<void> openReading(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(testApp(FakeApi(pendingPolls: 0)));
  await frames(tester, 10);
  await tester.tap(find.byKey(const Key('entry-bazi')));
  await frames(tester, 10);
  await scrollTo(tester, const Key('compute-chart'));
  await tester.tap(find.byKey(const Key('compute-chart')));
  await frames(tester, 10);
  await scrollTo(tester, const Key('generate-report'));
  await tester.tap(find.byKey(const Key('generate-report')));
  await frames(tester, 20);
}

/// 历史记录 holding one three-card tarot reading (report_tarot_passed).
List<Map<String, dynamic>> tarotHistory() {
  final cards = fixture('chart_tarot')['chart_fact']['facts']['cards'] as List;
  return [
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
        'cards': [for (final c in cards) {'card_id': c['card_id'], 'reversed': c['reversed']}],
      },
    },
  ];
}

/// The tarot reading, opened from 历史记录 on the same phone-sized view.
Future<void> openTarotReading(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(testApp(FakeApi(finalReport: fixture('report_tarot_passed'), pendingPolls: 0, history: tarotHistory())));
  await frames(tester, 10);
  await openFromMenu(tester, 'menu-history');
  await frames(tester, 10);
  await tester.tap(find.byType(HistoryTile).first);
  await frames(tester, 20);
}

/// A part of the 总结, as the fixture has it.
String conclusion(String part) =>
    ((((fixture('report_passed')['layers'] as Map)['conclusion'] as Map)[part]) as Map)['text'] as String;

/// The first paragraph of a section, as the fixture has it.
String paragraph(int section) =>
    (((fixture('report_passed')['layers'] as Map)['interpretation'] as List)[section] as Map)['paragraphs'][0]['text'] as String;

/// Whether [finder] lies inside the 800 px view.
bool onScreen(WidgetTester tester, Finder finder) {
  final r = tester.getRect(finder);
  return r.top >= 0 && r.top < 800;
}

void main() {
  testWidgets('a tarot reading offers 分享圖片: the server’s JPEG goes to the share sheet; a 八字 one doesn’t', (tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final shared = <ShareParams>[];
    final api = FakeApi(finalReport: fixture('report_tarot_passed'), pendingPolls: 0, history: tarotHistory());
    await tester.pumpWidget(
      testApp(api, overrides: [shareProvider.overrideWithValue((p) async => shared.add(p))]),
    );
    await frames(tester, 10);
    await openFromMenu(tester, 'menu-history');
    await frames(tester, 10);
    await tester.tap(find.byType(HistoryTile).first);
    await frames(tester, 20);
    await tester.tap(find.byKey(const Key('report-menu')));
    await frames(tester);
    await tester.tap(find.byKey(const Key('share-image')));
    await frames(tester);
    expect(api.requests.map((r) => r.url.path), contains('/v1/reports/55555555-5555-4555-8555-555555555555/share.jpg'));
    expect(shared, hasLength(1));
    final file = shared.single.files!.single;
    expect(file.mimeType, 'image/jpeg');
    expect((await file.readAsBytes()).sublist(0, 3), [0xff, 0xd8, 0xff]);
    // XFile.fromData keeps a name only on the web; the share sheet takes it from fileNameOverrides.
    expect(shared.single.fileNameOverrides, ['mingli-tarot-55555555.jpg']);

    // A 八字 reading's menu has no image.
    await tester.pumpWidget(const SizedBox.shrink()); // a fresh app (rule 24)
    await openReading(tester);
    await tester.tap(find.byKey(const Key('report-menu')));
    await frames(tester);
    expect(find.byKey(const Key('download-report')), findsOneWidget);
    expect(find.byKey(const Key('share-image')), findsNothing);
  });

  testWidgets('a 八字 reading opens with its four pillars and 日主', (tester) async {
    await openReading(tester);
    final pillars = find.byKey(const Key('reading-pillars'));
    expect(pillars, findsOneWidget);
    final ganzhi = tester.widgetList<GanZhiText>(find.descendant(of: pillars, matching: find.byType(GanZhiText)));
    expect([for (final g in ganzhi) g.text], ['庚午', '己卯', '己卯', '辛未']);
    expect(find.descendant(of: pillars, matching: find.text('日主 己土（陰）')), findsOneWidget);
    // The jump list comes first, the chart under it.
    expect(tester.getTopLeft(find.byKey(const Key('jump-list'))).dy, lessThan(tester.getTopLeft(pillars).dy));
  });

  testWidgets('a chip opens its section and brings it into view; the 總結 too', (tester) async {
    await openReading(tester);
    // 健康, the sixth section: closed, so its text isn't there yet. Its chip is past the right
    // edge of the row: bring it into view first, as a swipe would (and pump, rule 27).
    expect(find.text(paragraph(5)), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('jump-health')));
    await frames(tester);
    await tester.tap(find.byKey(const Key('jump-health')));
    await frames(tester);
    expect(find.text(paragraph(5)), findsOneWidget);
    expect(onScreen(tester, find.text(paragraph(5))), isTrue);
    expect(find.text(paragraph(0)), findsOneWidget); // 五行 stays open

    // Back at the top, the 總結 starts below the fold; its chip brings it up (v9.3.0). The list builds
    // every card, so the finder must look past the screen too.
    await scrollToFinder(tester, find.byKey(const Key('jump-list')), delta: -300);
    await frames(tester);
    final portrait = find.text(conclusion('portrait'), skipOffstage: false);
    expect(onScreen(tester, portrait), isFalse);
    await tester.ensureVisible(find.byKey(const Key('jump-conclusion')));
    await frames(tester);
    await tester.tap(find.byKey(const Key('jump-conclusion')));
    await frames(tester);
    expect(onScreen(tester, portrait), isTrue);
  });

  testWidgets('on a phone the chips scroll sideways, and Tab still reaches the last, 健康', (tester) async {
    await openReading(tester);
    final last = find.byKey(const Key('jump-health'));
    expect(find.descendant(of: last, matching: find.text('健康')), findsOneWidget);
    expect(tester.getRect(last).right, greaterThan(400)); // past the edge of the 400 px view
    await tabTo(tester, 'jump-health');
    expect(tester.getRect(last).right, lessThanOrEqualTo(400)); // scrolled into view
    await press(tester, LogicalKeyboardKey.enter);
    expect(onScreen(tester, find.text(paragraph(5))), isTrue);
  });

  testWidgets('a 八字 reading opens the AI part with its 總結, in order, and has no 行動建議 (v9.3.0)', (tester) async {
    await openReading(tester);
    // The list builds every card, below the screen too (rule 43): look there as well.
    Finder key(String k) => find.byKey(Key(k), skipOffstage: false);
    Finder text(String t) => find.text(t, skipOffstage: false);
    final card = key('conclusion');
    expect(card, findsOneWidget);
    expect(key('jump-conclusion'), findsOneWidget);
    // After the engine's facts, before the AI's sections.
    final top = tester.getTopLeft(card).dy;
    expect(top, greaterThan(tester.getTopLeft(text('命盤事實 · 引擎計算，非 AI')).dy));
    expect(top, lessThan(tester.getTopLeft(text('解讀 · AI 生成')).dy));
    expect(find.descendant(of: card, matching: text('總結 · AI 生成')), findsOneWidget);
    // The nine parts in order, each under its label.
    final ys = [for (final p in conclusionParts) tester.getTopLeft(key('conclusion-label-$p')).dy];
    for (var k = 1; k < ys.length; k++) {
      expect(ys[k], greaterThan(ys[k - 1]));
    }
    expect(tester.widget<Text>(key('conclusion-label-portrait')).data, '你是怎樣的人');
    expect(tester.widget<Text>(key('conclusion-label-momentum')).data, '何時開始要發力');
    expect(tester.widget<Text>(key('conclusion-coping')).data, conclusion('coping'));
    // No 行動建議: neither its card nor its chip (the tarot reading below has both).
    expect(text('行動建議 · AI 生成'), findsNothing);
    expect(key('jump-actions'), findsNothing);
  });

  testWidgets('a tarot reading keeps its 行動建議 and has no 總結', (tester) async {
    await openTarotReading(tester);
    expect(find.byKey(const Key('jump-actions'), skipOffstage: false), findsOneWidget);
    expect(find.text('行動建議 · AI 生成', skipOffstage: false), findsOneWidget);
    expect(find.byKey(const Key('conclusion'), skipOffstage: false), findsNothing);
    expect(find.byKey(const Key('jump-conclusion'), skipOffstage: false), findsNothing);
  });

  testWidgets('the 八字 page asks the AI for its own reading: 用AI做更精確解讀 (v9.3.0)', (tester) async {
    await tester.pumpWidget(testApp(FakeApi(pendingPolls: 0)));
    await frames(tester, 10);
    await tester.tap(find.byKey(const Key('entry-bazi')));
    await frames(tester, 10);
    await scrollTo(tester, const Key('compute-chart'));
    await tester.tap(find.byKey(const Key('compute-chart')));
    await frames(tester, 10);
    await scrollTo(tester, const Key('generate-report'));
    expect(find.descendant(of: find.byKey(const Key('generate-report')), matching: find.text('用AI做更精確解讀')),
        findsOneWidget);
  });

  testWidgets('from the keyboard: Enter on a chip jumps, and Tab goes on inside that section', (tester) async {
    await openReading(tester);
    await tabTo(tester, 'jump-career_wealth');
    await press(tester, LogicalKeyboardKey.enter);
    expect(find.text(paragraph(2)), findsOneWidget);
    expect(onScreen(tester, find.text(paragraph(2))), isTrue);
    // The next Tab stop is the 事業財運 section's own header (its tile is the third, topic-2-…).
    await press(tester, LogicalKeyboardKey.tab);
    expect(focusedKey(), startsWith('topic-2-'));
  });
}
