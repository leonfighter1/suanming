// 求籤 (v4.3.0, tech plan WP6.1 + 6.2): the entry order by region, the ritual round by round, the lot
// card, and a 求籤 reading with its lot on top and its share image. The draw is chart_qiuqian.json, real
// engine output; the texts the page shows come from the ARB files and the synced lot set.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_app/application/providers.dart' show shareProvider;
import 'package:mingli_app/presentation/history_page.dart' show HistoryTile;
import 'package:mingli_app/presentation/widgets/qiuqian_stage.dart' show QiuqianStage;
import 'package:share_plus/share_plus.dart' show ShareParams;

import 'keys.dart';
import 'support.dart';

/// The stage at work (v9.1.0): until the stick lies on the floor, or the blocks have landed.
Future<void> _shaken(WidgetTester tester) => frames(tester, QiuqianStage.shake.inMilliseconds ~/ 100 + 2);
Future<void> _landed(WidgetTester tester) => frames(tester, QiuqianStage.toss.inMilliseconds ~/ 100 + 2);

final _facts = fixture('chart_qiuqian')['chart_fact']['facts'] as Map<String, dynamic>;
final _rounds = (_facts['rounds'] as List).cast<Map<String, dynamic>>();
final _n = (_facts['lot'] as Map)['n'] as int;
final _lot = testTerms.lots!.lot(_n)!;

/// What the page says after a throw, in 繁體 (app_zh_Hant.arb).
String _meaning(String result) => switch (result) {
      'sheng' => '聖筊：神明應允，就是這一支',
      'xiao' => '笑筊：神明一笑，把籤放回再求',
      _ => '陰筊：神明未允，把籤放回再求',
    };

Future<void> _openQiuqian(WidgetTester tester, FakeApi api) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(testApp(api));
  await frames(tester, 10);
  await tester.tap(find.byKey(const Key('entry-qiuqian')));
  await frames(tester, 10);
}

void main() {
  Future<Map<String, double>> homeTops(WidgetTester tester, FakeApi api) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(api));
    await frames(tester, 10);
    return {for (final k in ['entry-qiuqian', 'entry-bazi', 'entry-tarot']) k: tester.getTopLeft(find.byKey(Key(k))).dy};
  }

  testWidgets('the home page puts 求籤 first where the region does (Taiwan, Hong Kong)', (tester) async {
    final top = await homeTops(tester, FakeApi()..methods = const ['qiuqian', 'bazi', 'tarot', 'astrology']);
    expect(top['entry-qiuqian']! < top['entry-bazi']!, isTrue);
    expect(top['entry-bazi']! < top['entry-tarot']!, isTrue);
  });

  testWidgets('elsewhere the default order: 東方 八字, 求籤, then 西方 塔羅 (v6.1.0)', (tester) async {
    final top = await homeTops(tester, FakeApi());
    expect(top['entry-bazi']! < top['entry-qiuqian']!, isTrue);
    expect(top['entry-qiuqian']! < top['entry-tarot']!, isTrue);
  });

  testWidgets('drawing a lot: each stick, each throw, then the lot and a reading of the question', (tester) async {
    final api = FakeApi(finalReport: fixture('report_qiuqian_passed'), pendingPolls: 0);
    await _openQiuqian(tester, api);
    await tester.enterText(find.byKey(const Key('qiuqian-question')), '今年適合換工作嗎？');
    await tester.pump();
    await tester.tap(find.byKey(const Key('draw-lot')));
    await frames(tester, 3);
    // The lot is drawn for the question (v11.1.0, the owner: 必须要有所求才能去求).
    expect(jsonDecode(api.requests.lastWhere((r) => r.method == 'POST' && r.url.path == '/v1/charts').body), {
      'system': 'qiuqian',
      'question': '今年適合換工作嗎？',
    });

    for (final (i, r) in _rounds.indexed) {
      final stick = testTerms.lots!.lot(r['lot'] as int)!.title('zh-Hant');
      // The cylinder is shaken first (v9.1.0): the stick and the button wait until it lies on the floor.
      expect(find.text('搖籤中……'), findsOneWidget);
      expect(find.byKey(const Key('skip-rounds')), findsOneWidget);
      expect(find.text('搖出$stick'), findsNothing);
      expect(find.byKey(const Key('throw-blocks')), findsNothing);
      await _shaken(tester);
      expect(find.text('搖出$stick'), findsWidgets);
      // The blocks aren't thrown yet, and the lot isn't shown.
      expect(find.byKey(ValueKey<String>('throw-$i')), findsNothing);
      expect(find.byKey(const Key('lot-card')), findsNothing);
      await tester.tap(find.byKey(const Key('throw-blocks')));
      await frames(tester, 3);
      // In the air: how they landed waits until they have.
      expect(find.text('擲筊中……'), findsOneWidget);
      expect(find.byKey(ValueKey<String>('throw-$i')), findsNothing);
      await _landed(tester);
      expect(find.text('擲筊中……'), findsNothing);
      expect(tester.widget<Text>(find.byKey(ValueKey<String>('throw-$i'))).data, _meaning(r['result'] as String));
      if (i < _rounds.length - 1) {
        await tester.tap(find.byKey(const Key('shake-again')));
        await frames(tester, 3);
      }
    }
    // The last throw was the 聖筊: the lot, as the set prints it, and no further step.
    expect(_rounds.last['result'], 'sheng');
    expect(find.byKey(const Key('throw-blocks')), findsNothing);
    expect(find.byKey(const Key('shake-again')), findsNothing);
    await scrollTo(tester, const Key('lot-card'));
    expect(find.text('${_lot.title('zh-Hant')} · ${_lot.ganzhi}'), findsOneWidget);
    for (final line in _lot.poem('zh-Hant')) {
      expect(find.text(line), findsOneWidget);
    }
    // The reading reads the question asked; its sections are fixed.
    await scrollTo(tester, const Key('generate-report'));
    expect(find.byKey(const Key('qiuqian-sections')), findsOneWidget);
    await tester.tap(find.byKey(const Key('generate-report')));
    await frames(tester, 10);
    final asked = jsonDecode(api.requests.firstWhere((q) => q.url.path == '/v1/reports' && q.method == 'POST').body) as Map;
    expect(asked['question'], '今年適合換工作嗎？');
    expect(asked['chart_id'], fixture('chart_qiuqian')['chart_id']);
    expect(asked.containsKey('focus'), isFalse);
  });

  testWidgets('直接看結果 shows every round and the lot at once; Enter throws from the keyboard', (tester) async {
    await _openQiuqian(tester, FakeApi());
    await ask(tester, 'qiuqian-question', '今年適合換工作嗎？');
    await tester.tap(find.byKey(const Key('draw-lot')));
    await _shaken(tester);
    // The fixture's draw: a 陰筊 on the first stick, the 聖筊 on the second.
    expect(_rounds.map((r) => r['result']), ['yin', 'sheng']);
    // The throw button has the focus as soon as the stick lies on the floor: Enter throws.
    await press(tester, LogicalKeyboardKey.enter);
    await _landed(tester);
    expect(tester.widget<Text>(find.byKey(const ValueKey<String>('throw-0'))).data, _meaning('yin'));
    await tester.tap(find.byKey(const Key('skip-rounds')));
    await frames(tester, 3);
    expect(tester.widget<Text>(find.byKey(const ValueKey<String>('throw-1'))).data, _meaning('sheng'));
    await scrollTo(tester, const Key('lot-card'));
    expect(find.text('${_lot.title('zh-Hant')} · ${_lot.ganzhi}'), findsOneWidget);
  });

  group('the altar (v9.1.0)', () {
    late List<int> shaken, thrown;
    setUp(() {
      shaken = [];
      thrown = [];
    });
    Widget stage(int round, List<String>? blocks, {bool settled = false, bool still = false}) => MaterialApp(
          builder: (context, child) =>
              MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: still), child: child!),
          home: Scaffold(
            body: QiuqianStage(
              round: round,
              blocks: blocks,
              label: '籤',
              settled: settled,
              onShaken: shaken.add,
              onThrown: thrown.add,
            ),
          ),
        );
    const tick = Duration(milliseconds: 100);

    testWidgets('the stick lies still at the end of the shake, the blocks at the end of the throw', (tester) async {
      await tester.pumpWidget(stage(0, null));
      expect(find.text('籤'), findsOneWidget); // on the cylinder's label
      await tester.pump(QiuqianStage.shake - tick);
      expect(shaken, isEmpty);
      await tester.pump(tick * 2);
      expect(shaken, [0]);
      await tester.pumpWidget(stage(0, const ['flat', 'round']));
      await tester.pump(QiuqianStage.toss - tick);
      expect(thrown, isEmpty);
      await tester.pump(tick * 2);
      expect(thrown, [0]);
      // A new round puts the stick back and shakes again.
      await tester.pumpWidget(stage(1, null));
      await tester.pump(QiuqianStage.shake + tick);
      expect(shaken, [0, 1]);
      expect(thrown, [0]);
    });

    testWidgets('直接看結果 in the middle of a shake shows the end at once, and the page hears nothing more', (tester) async {
      await tester.pumpWidget(stage(0, null));
      await tester.pump(QiuqianStage.shake ~/ 3);
      await tester.pumpWidget(stage(1, const ['flat', 'round'], settled: true));
      await tester.pump(QiuqianStage.shake + QiuqianStage.toss);
      expect(shaken, isEmpty);
      expect(thrown, isEmpty);
    });

    testWidgets('with the system animations off each step ends at once', (tester) async {
      await tester.pumpWidget(stage(0, null, still: true));
      await tester.pump();
      expect(shaken, [0]);
      await tester.pumpWidget(stage(0, const ['round', 'round'], still: true));
      await tester.pump();
      expect(thrown, [0]);
    });
  });

  testWidgets('a 求籤 reading opens with its lot, lists it in history and offers 分享圖片', (tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final shared = <ShareParams>[];
    final report = fixture('report_qiuqian_passed');
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
          'topics': ['qiuqian_poem', 'qiuqian_answer', 'qiuqian_advice'],
          'chart': {'system': 'qiuqian', 'lot_set': 'guandi_100', 'lot': _n, 'ganzhi': _lot.ganzhi},
        },
      ],
    );
    await tester.pumpWidget(testApp(api, overrides: [shareProvider.overrideWithValue((p) async => shared.add(p))]));
    await frames(tester, 10);
    await openFromMenu(tester, 'menu-history');
    await frames(tester, 10);
    expect(
      tester.widget<Text>(find.byKey(const Key('history-lot'))).data,
      '${_lot.title('zh-Hant')} · ${_lot.ganzhi} · ${_lot.poem('zh-Hant').first}',
    );
    await tester.tap(find.byType(HistoryTile).first);
    await frames(tester, 20);
    expect(find.byKey(const Key('reading-lot')), findsOneWidget);
    for (final title in ['籤詩', '所問之事', '建議']) {
      expect(find.text(title), findsWidgets);
    }
    await tester.tap(find.byKey(const Key('report-menu')));
    await frames(tester);
    await tester.tap(find.byKey(const Key('share-image')));
    await frames(tester);
    expect(shared.single.fileNameOverrides!.single, startsWith('mingli-qiuqian-'));
  });
}
