import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_app/domain/export.dart';
import 'package:mingli_app/domain/models.dart';

import 'support.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Opens the passed fixture report from the history page.
Future<FakeApi> openReport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = FakeApi(pendingPolls: 0);
  await tester.pumpWidget(testApp(api));
  await settle(tester);
  await tester.tap(find.byKey(const Key('open-history')));
  await settle(tester);
  await tester.tap(find.text('八字排盤').last);
  await settle(tester);
  return api;
}

void main() {
  final report = ReportView.fromJson(fixture('report_passed'));
  final trend = report.layers!.trend!;

  test('trend fixture: 8 大運 and 10 流年, server-computed total', () {
    expect(trend.dayun, hasLength(8));
    expect(trend.liunian, hasLength(10));
    expect(trend.total, (trend.dayun.map((d) => d.overall).reduce((a, b) => a + b) / 8).round());
    expect(trend.dayun.first.label, '8–17');
  });

  testWidgets('trend chart: total, mode switch, topic filters and period details', (tester) async {
    await openReport(tester);
    expect(find.byKey(const Key('trend-card')), findsOneWidget);
    expect(find.textContaining('${trend.total}'), findsWidgets);

    // 大運 view selects the period containing this year; switch to 流年.
    await tester.tap(find.text('按年份（流年）'));
    await settle(tester);
    final first = trend.liunian.first;
    Finder inDetail(String text) =>
        find.descendant(of: find.byKey(const Key('trend-detail')), matching: find.textContaining(text));
    expect(inDetail('${first.year} ${first.ganzhi}'), findsOneWidget);

    // Add a topic to compare against 綜合, then tap the last year on the plot.
    await tester.tap(find.byKey(const Key('trend-series-health')));
    await settle(tester);
    final plot = tester.getRect(find.byKey(const Key('trend-plot')));
    await tester.tapAt(Offset(plot.right - 4, plot.center.dy));
    await settle(tester);
    final last = trend.liunian.last;
    expect(inDetail('${last.year} ${last.ganzhi}'), findsOneWidget);
    expect(inDetail('健康 ${last.scores['health']}'), findsOneWidget);
  });

  testWidgets('only the first topic starts open; expand all opens the rest', (tester) async {
    await openReport(tester);
    final secs = report.layers!.interpretation;
    expect(find.text(secs.first.paragraphs.first.text), findsOneWidget);
    expect(find.text(secs[1].paragraphs.first.text), findsNothing);

    await tester.tap(find.byKey(const Key('expand-all')));
    await settle(tester);
    expect(find.text('收起全部'), findsOneWidget);
    await scrollToFinder(tester, find.text(secs[1].paragraphs.first.text));
    expect(find.text(secs[1].paragraphs.first.text), findsOneWidget);
  });

  testWidgets('破除運勢: pay popup charges directly (placeholder), then the plan opens', (tester) async {
    final api = await openReport(tester);
    final buy = find.byKey(const Key('remedy-buy-career_wealth'));
    await scrollToFinder(tester, buy);
    await tester.ensureVisible(buy);
    await settle(tester);
    expect(find.textContaining('HKD 18'), findsWidgets);
    await tester.tap(buy);
    await settle(tester);

    expect(find.byKey(const Key('remedy-confirm')), findsOneWidget);
    expect(find.textContaining('事業財運'), findsWidgets);
    await tester.tap(find.byKey(const Key('remedy-pay')));
    await settle(tester);

    final post = api.requests.where((r) => r.method == 'POST' && r.url.path.endsWith('/remedies'));
    expect(post, hasLength(1));
    expect(find.byKey(const Key('remedy-dialog')), findsOneWidget);
    expect(find.byKey(const Key('remedy-target')), findsOneWidget);
    expect(find.textContaining('事業財運'), findsWidgets);
    for (final k in ['remedy-save', 'remedy-send', 'remedy-print', 'remedy-copy']) {
      expect(find.byKey(Key(k)), findsOneWidget);
    }
    expect(find.text('示範付款（未實際收費）'), findsOneWidget);
  });

  test('remedy export keeps the target, steps, disclaimer and AI label', () {
    final r = RemedyView.fromJson(fixture('remedy_passed'));
    final md = exportRemedyMarkdown(
      remedy: r,
      title: '破除運勢：事業財運',
      aiLabel: 'AI 生成',
      horizonLabel: (h) => h,
      headings: {'target': '針對項目', 'focus': '重點時期', 'steps': '具體做法', 'basis': '命理依據'},
    );
    expect(md, contains(r.target));
    expect(md, contains(r.steps.first.text));
    expect(md, contains(r.closing));
    expect(md, contains('AI 生成'));
  });
}
