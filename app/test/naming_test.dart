// 起名 (v4.5.0, tech plan WP6.4): hidden until the region turns it on (it ships off, awaiting the owner's review
// of the 字义库); then the 八字 chart page leads to the naming page (surname, length, 起名), the names card and a
// 起名 reading. The candidates are chart_naming.json (陳, 火、土), real engine output; the texts come from the ARB
// files and the synced 字义库.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_app/application/providers.dart' show zhHans, zhHant;
import 'package:mingli_app/presentation/history_page.dart' show HistoryTile;

import 'keys.dart';
import 'support.dart';

const _withNaming = ['bazi', 'tarot', 'qiuqian', 'fengshui', 'naming', 'astrology'];

/// 八字排盘 → the chart page, with the region's [methods].
Future<void> _openChart(WidgetTester tester, FakeApi api, {Locale locale = zhHant}) async {
  tester.view.physicalSize = const Size(1000, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(testApp(api, locale: locale));
  await frames(tester, 10);
  await tester.tap(find.byKey(const Key('entry-bazi')));
  await frames(tester, 10);
  await scrollTo(tester, const Key('compute-chart'));
  await tester.tap(find.byKey(const Key('compute-chart')));
  await frames(tester, 10);
}

/// … then 為這個命盤起名.
Future<void> _openNaming(WidgetTester tester, FakeApi api, {Locale locale = zhHant}) async {
  await _openChart(tester, api, locale: locale);
  await scrollTo(tester, const Key('open-naming'));
  await tester.tap(find.byKey(const Key('open-naming')));
  await frames(tester, 10);
}

bool _enabled(WidgetTester tester) => tester.widget<ButtonStyleButton>(find.byKey(const Key('naming-suggest'))).enabled;

/// chart_naming with its 字义库 reviewed or not, whatever the synced fixture says (the owner's review flips it).
Map<String, dynamic> _chart({required bool reviewed}) {
  final chart = fixture('chart_naming');
  ((chart['chart_fact'] as Map)['facts'] as Map)['library'] = {'version': reviewed ? '1.0.0' : '0.1.0-draft', 'reviewed': reviewed};
  return chart;
}

void main() {
  testWidgets('起名 stays hidden where the region has it off (its default until the review)', (tester) async {
    await _openChart(tester, FakeApi());
    // The page's last button, right above where 起名's would be.
    await scrollTo(tester, const Key('life-generate'));
    await frames(tester);
    expect(find.byKey(const Key('open-naming')), findsNothing);
    // Nor is it ever an entry of its own on the home page.
    await tester.pumpWidget(testApp(FakeApi()..methods = _withNaming));
    await frames(tester, 10);
    expect(find.byKey(const Key('entry-naming')), findsNothing);
  });

  testWidgets('from the 八字 chart: the surname and length go with the chart, and the names come back', (tester) async {
    final api = FakeApi(finalReport: fixture('report_naming_passed'), pendingPolls: 0)
      ..methods = _withNaming
      ..namingChart = _chart(reviewed: false);
    await _openNaming(tester, api);

    // One or two Han characters only.
    expect(_enabled(tester), isFalse);
    await tester.enterText(find.byKey(const Key('naming-surname')), 'Li');
    await tester.pump();
    expect(_enabled(tester), isFalse);
    await tester.enterText(find.byKey(const Key('naming-surname')), '陳');
    await tester.pump();
    expect(_enabled(tester), isTrue);

    await tester.tap(find.byKey(const Key('naming-length-1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('naming-suggest')));
    await frames(tester);
    expect(jsonDecode(api.requests.lastWhere((r) => r.method == 'POST' && r.url.path == '/v1/charts').body), {
      'system': 'naming',
      'bazi_chart_id': fixture('chart_bazi')['chart_id'],
      'surname': '陳',
      'length': 1,
    });

    // The card shows the names the server answered with (the fixture: 陳, 火、土, twelve names).
    await scrollTo(tester, const Key('names-card'));
    expect(tester.widget<Text>(find.byKey(const Key('naming-elements'))).data, '名字所補：火、土');
    expect(find.text('陳燁峰'), findsOneWidget);
    expect(find.text('yè fēng'), findsOneWidget);
    final ye = testTerms.naming!.char('燁')!;
    expect(find.textContaining('燁 ${ye.element} ${ye.meaning('zh-Hant')}', findRichText: true), findsWidgets);
    // While the 字义库 is a draft (library.reviewed false), the card says so.
    await scrollTo(tester, const Key('naming-note'));
    expect(tester.widget<Text>(find.byKey(const Key('naming-note'))).data, '這些名字所用的字義庫仍待專家校訂。名字是祝福與聲音，不決定任何人的命運。');

    // The reading's sections are fixed, and it reads the naming chart.
    await scrollTo(tester, const Key('generate-report'));
    expect(find.byKey(const Key('naming-sections')), findsOneWidget);
    await tester.tap(find.byKey(const Key('generate-report')));
    await frames(tester, 10);
    final asked = jsonDecode(api.requests.firstWhere((q) => q.url.path == '/v1/reports' && q.method == 'POST').body) as Map;
    expect(asked['chart_id'], fixture('chart_naming')['chart_id']);
    expect(asked['topics'], ['naming_candidates', 'naming_advice']);
  });

  testWidgets('Ctrl+Enter asks for names; a new surname puts the old names away', (tester) async {
    final api = FakeApi()..methods = _withNaming;
    await _openNaming(tester, api);
    await tester.enterText(find.byKey(const Key('naming-surname')), '歐陽');
    await press(tester, LogicalKeyboardKey.enter, control: true);
    expect((jsonDecode(api.requests.lastWhere((r) => r.method == 'POST' && r.url.path == '/v1/charts').body) as Map)['surname'], '歐陽');
    expect(find.byKey(const Key('names-card')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('naming-surname')), '陳');
    await tester.pump();
    expect(find.byKey(const Key('names-card')), findsNothing);
  });

  testWidgets('once the owner has reviewed the 字义库, the card stops calling it a draft', (tester) async {
    final api = FakeApi()
      ..methods = _withNaming
      ..namingChart = _chart(reviewed: true);
    await _openNaming(tester, api);
    await tester.enterText(find.byKey(const Key('naming-surname')), '陳');
    await tester.pump();
    await tester.tap(find.byKey(const Key('naming-suggest')));
    await frames(tester);
    await scrollTo(tester, const Key('naming-note'));
    expect(tester.widget<Text>(find.byKey(const Key('naming-note'))).data, '名字是祝福與聲音，不決定任何人的命運。');
  });

  testWidgets('简体 shows the names in 简体', (tester) async {
    await _openNaming(tester, FakeApi()..methods = _withNaming, locale: zhHans);
    await tester.enterText(find.byKey(const Key('naming-surname')), '陈');
    await tester.pump();
    await tester.tap(find.byKey(const Key('naming-suggest')));
    await frames(tester);
    await scrollTo(tester, const Key('names-card'));
    expect(find.text('陈烨峰'), findsOneWidget);
    expect(find.text('陳燁峰'), findsNothing);
  });

  testWidgets('a 起名 reading opens with its names, and history names the surname', (tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final report = fixture('report_naming_passed');
    final api = FakeApi(
      finalReport: report,
      pendingPolls: 0,
      history: [
        {
          'report_id': report['report_id'],
          'chart_id': report['chart_id'],
          'status': 'passed',
          'created_at': '2026-10-25T00:00:00.000Z',
          'updated_at': '2026-10-25T00:00:00.000Z',
          'locale': 'zh-Hant',
          'topics': ['naming_candidates', 'naming_advice'],
          'chart': {
            'system': 'naming',
            'surname': {'zh-Hant': '陳', 'zh-Hans': '陈'},
            'first': {'zh-Hant': '燁峰', 'zh-Hans': '烨峰'},
          },
        },
      ],
    );
    await tester.pumpWidget(testApp(api));
    await frames(tester, 10);
    await openFromMenu(tester, 'menu-history');
    await frames(tester, 10);
    expect(find.text('起名 · 陳'), findsOneWidget);
    await tester.tap(find.byType(HistoryTile).first);
    await frames(tester, 20);
    expect(find.byKey(const Key('reading-names')), findsOneWidget);
    expect(find.text('候選名字'), findsWidgets);
    // No share image for 起名: only the tarot and 求籤 readings have one.
    await tester.tap(find.byKey(const Key('report-menu')));
    await frames(tester);
    expect(find.byKey(const Key('share-image')), findsNothing);
  });
}
