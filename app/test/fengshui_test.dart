// 风水 (v4.4.0, tech plan WP6.3): Malaysia's entry order, the room page (room, facing, description, 看佈局),
// the principles card and a 风水 reading. The room is chart_fengshui.json (a bedroom facing east), real engine
// output; the texts come from the ARB files and the synced principles table.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_app/presentation/history_page.dart' show HistoryTile;

import 'keys.dart';
import 'support.dart';

final _table = testTerms.fengshui!;

Future<void> _openFengshui(WidgetTester tester, FakeApi api) async {
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(testApp(api));
  await frames(tester, 10);
  await tester.tap(find.byKey(const Key('entry-fengshui')));
  await frames(tester, 10);
}

void main() {
  testWidgets('the home page leads with 風水 where the region does (Malaysia)', (tester) async {
    // Tall enough that all four entries are built (the list is lazy, rule G12).
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = FakeApi()..methods = const ['fengshui', 'bazi', 'tarot', 'qiuqian', 'astrology'];
    await tester.pumpWidget(testApp(api));
    await frames(tester, 10);
    final y = {for (final k in ['entry-fengshui', 'entry-bazi', 'entry-qiuqian']) k: tester.getTopLeft(find.byKey(Key(k))).dy};
    expect(y['entry-fengshui']! < y['entry-bazi']!, isTrue);
    expect(y['entry-bazi']! < y['entry-qiuqian']!, isTrue);
  });

  testWidgets('看佈局 looks the room up, shows its principles and the facing, and reads it with the description', (tester) async {
    final api = FakeApi(finalReport: fixture('report_fengshui_passed'), pendingPolls: 0);
    await _openFengshui(tester, api);
    await tester.tap(find.byKey(const Key('room-kitchen')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('facing-west')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('fengshui-description')), '爐灶在窗下。');
    await tester.pump();
    await tester.tap(find.byKey(const Key('look-room')));
    await frames(tester);
    expect(jsonDecode(api.requests.last.body), {'system': 'fengshui', 'room': 'kitchen', 'facing': 'west'});

    // The card shows the room the server answered with (the fixture: a bedroom facing east).
    await scrollTo(tester, const Key('principles-card'));
    expect(tester.widget<Text>(find.byKey(const Key('fengshui-direction'))).data, '傳統上：東 · 震 · 木');
    for (final p in _table.principles('bedroom')) {
      expect(find.text(p.text('zh-Hant')), findsOneWidget);
    }
    expect(find.text('這些是通用的空間原則，不是對住宅吉凶的判斷。'), findsOneWidget);

    // The reading's sections are fixed, and the description goes with it.
    await scrollTo(tester, const Key('generate-report'));
    expect(find.byKey(const Key('fengshui-sections')), findsOneWidget);
    await tester.tap(find.byKey(const Key('generate-report')));
    await frames(tester, 10);
    final asked = jsonDecode(api.requests.firstWhere((q) => q.url.path == '/v1/reports' && q.method == 'POST').body) as Map;
    expect(asked['question'], '爐灶在窗下。');
    expect(asked['chart_id'], fixture('chart_fengshui')['chart_id']);
  });

  testWidgets('a new choice puts the looked-up room away', (tester) async {
    await _openFengshui(tester, FakeApi());
    await tester.tap(find.byKey(const Key('look-room')));
    await frames(tester);
    expect(find.byKey(const Key('principles-card')), findsOneWidget);
    await tester.tap(find.byKey(const Key('room-study')));
    await tester.pump();
    expect(find.byKey(const Key('principles-card')), findsNothing);
  });

  testWidgets('a 風水 reading opens with its room, and history names the room', (tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final report = fixture('report_fengshui_passed');
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
          'topics': ['fengshui_layout', 'fengshui_flow', 'fengshui_advice'],
          'chart': {'system': 'fengshui', 'room': 'bedroom', 'facing': 'east'},
        },
      ],
    );
    await tester.pumpWidget(testApp(api));
    await frames(tester, 10);
    await openFromMenu(tester, 'menu-history');
    await frames(tester, 10);
    expect(find.text('風水 · 臥室'), findsOneWidget);
    await tester.tap(find.byType(HistoryTile).first);
    await frames(tester, 20);
    expect(find.byKey(const Key('reading-room')), findsOneWidget);
    for (final title in ['佈局', '光線與動線', '建議']) {
      expect(find.text(title), findsWidgets);
    }
    // No share image for 風水: only the tarot and 求籤 readings have one.
    await tester.tap(find.byKey(const Key('report-menu')));
    await frames(tester);
    expect(find.byKey(const Key('share-image')), findsNothing);
  });
}
