// S4 WP4.5 (v3.4.0): a reading opens with its chart (a 八字 reading's four pillars; a tarot
// reading's spread is in tarot_spread_test) and a jump list to every section and to 行动建议.
// report_passed has six sections, 五行 to 健康, and six actions; only 五行 starts open.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_app/presentation/theme.dart';

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

/// The first paragraph of a section, as the fixture has it.
String paragraph(int section) =>
    (((fixture('report_passed')['layers'] as Map)['interpretation'] as List)[section] as Map)['paragraphs'][0]['text'] as String;

/// Whether [finder] lies inside the 800 px view.
bool onScreen(WidgetTester tester, Finder finder) {
  final r = tester.getRect(finder);
  return r.top >= 0 && r.top < 800;
}

void main() {
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

  testWidgets('a chip opens its section and brings it into view; 行动建议 too', (tester) async {
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

    final firstAction = ((fixture('report_passed')['layers'] as Map)['actions'] as List).first['text'] as String;
    await scrollToFinder(tester, find.byKey(const Key('jump-list')), delta: -300);
    await frames(tester);
    await tester.ensureVisible(find.byKey(const Key('jump-actions')));
    await frames(tester);
    await tester.tap(find.byKey(const Key('jump-actions')));
    await frames(tester);
    expect(onScreen(tester, find.text(firstAction)), isTrue);
  });

  testWidgets('on a phone the chips scroll sideways, and Tab still reaches the last, 行動建議', (tester) async {
    await openReading(tester);
    final last = find.byKey(const Key('jump-actions'));
    expect(find.descendant(of: last, matching: find.text('行動建議')), findsOneWidget);
    expect(tester.getRect(last).right, greaterThan(400)); // past the edge of the 400 px view
    await tabTo(tester, 'jump-actions');
    expect(tester.getRect(last).right, lessThanOrEqualTo(400)); // scrolled into view
    await press(tester, LogicalKeyboardKey.enter);
    final firstAction = ((fixture('report_passed')['layers'] as Map)['actions'] as List).first['text'] as String;
    expect(onScreen(tester, find.text(firstAction)), isTrue);
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
