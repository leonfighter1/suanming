// 算卦 (v6.0.0, tech plan WP10.4, the owner's request): the entry and the reminder before the cast, the three
// ways to cast (auto, pick, manual with its time) and what each sends, the reveal, the hexagram card with each
// text said straight out (直說), the reading, history, and the keyboard. The cast is chart_liuyao.json, real
// engine output: 天火同人 with 六二 moving, turning into 乾為天, cast 2026-10-25 08:00 in Hong Kong.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_app/platform/time_zone.dart';
import 'package:mingli_app/presentation/history_page.dart' show HistoryTile;

import 'keys.dart';
import 'support.dart';

Future<FakeApi> _open(WidgetTester tester, [FakeApi? fake]) async {
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = fake ?? FakeApi(finalReport: fixture('report_liuyao_passed'), pendingPolls: 0);
  await tester.pumpWidget(testApp(api));
  await frames(tester, 10);
  await tester.tap(find.byKey(const Key('entry-liuyao')));
  await frames(tester, 10);
  // The coins are cast only for a question (v11.1.0).
  await ask(tester, 'liuyao-question', '這個項目能不能做成？');
  return api;
}

Map<String, dynamic> _castBody(FakeApi api) =>
    jsonDecode(api.requests.lastWhere((r) => r.url.path == '/v1/charts' && r.method == 'POST').body) as Map<String, dynamic>;

bool _enabled(WidgetTester tester, String key) => tester.widget<ButtonStyleButton>(find.byKey(Key(key))).enabled;

Future<void> _mode(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(of: find.byKey(const Key('liuyao-mode')), matching: find.text(label)));
  await frames(tester);
}

final _chart = fixture('chart_liuyao')['chart_fact']['facts'] as Map<String, dynamic>;

/// The side each coin under [within] shows now, in order: `zi`, `bei` or `cover` (copper_coin.dart keys it).
List<String> _sides(Finder within) => [
      for (final e in find.descendant(of: within, matching: find.byType(CustomPaint)).evaluate())
        if (e.widget.key case ValueKey<String>(:final value) when value.startsWith('coin-side-')) value.substring(10),
    ];

void main() {
  test('a time zone from a whole-hour offset: IANA Etc names flip the sign', () {
    expect(offsetZone(const Duration(hours: 8)), 'Etc/GMT-8');
    expect(offsetZone(const Duration(hours: -5)), 'Etc/GMT+5');
    expect(offsetZone(Duration.zero), 'Etc/UTC');
    expect(offsetZone(const Duration(hours: 5, minutes: 30)), 'Etc/UTC');
  });

  testWidgets('the home lists 算卦 after 求籤, and the page reminds the reader before any cast', (tester) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(FakeApi()));
    await frames(tester, 10);
    final y = {for (final k in ['entry-qiuqian', 'entry-liuyao', 'entry-fengshui']) k: tester.getTopLeft(find.byKey(Key(k))).dy};
    expect(y['entry-qiuqian']! < y['entry-liuyao']!, isTrue);
    expect(y['entry-liuyao']! < y['entry-fengshui']!, isTrue);
    await tester.tap(find.byKey(const Key('entry-liuyao')));
    await frames(tester, 10);
    expect(find.descendant(of: find.byKey(const Key('liuyao-remind')), matching: find.text('先靜下心，把要問的事想清楚。一次只問一件事，同一件事不要一再重問。')),
        findsOneWidget);
  });

  testWidgets('自動擲幣: the server tosses, the tosses come one by one, then the hexagram and its texts said straight', (tester) async {
    final api = await _open(tester);
    await tester.tap(find.byKey(const Key('liuyao-toss')));
    await frames(tester);
    final body = _castBody(api);
    expect(body['system'], 'liuyao');
    expect(body['mode'], 'auto');
    expect((body['timezone'] as String).isNotEmpty, isTrue);

    // One toss at a time, the 初爻 first.
    expect(find.byKey(const Key('toss-0')), findsNothing);
    await tester.tap(find.byKey(const Key('liuyao-next')));
    await frames(tester);
    final first = (_chart['tosses'] as List).first as Map<String, dynamic>;
    final coins = (first['coins'] as List).map((c) => c == 'bei' ? '背' : '字').join(' ');
    final kind = {6: '老陰', 7: '少陽', 8: '少陰', 9: '老陽'}[first['value']];
    expect(find.text('初爻：$coins → $kind'), findsOneWidget);
    expect(find.byKey(const Key('hexagram-card')), findsNothing);
    await tester.tap(find.byKey(const Key('liuyao-skip')));
    await frames(tester);

    await scrollTo(tester, const Key('hexagram-card'));
    final card = find.byKey(const Key('hexagram-card'));
    Finder inCard(String text) => find.descendant(of: card, matching: find.text(text));
    // 天火同人 is 13 (上卦 乾, 下卦 離); with 六二 moving it turns into 乾為天, 1.
    expect(inCard('天火同人'), findsOneWidget);
    expect(inCard('第13卦'), findsOneWidget);
    expect(inCard('上卦 乾（天）\n下卦 離（火）'), findsOneWidget);
    expect(inCard('乾為天'), findsOneWidget);
    expect(inCard('第1卦'), findsOneWidget);
    expect(inCard('起卦於 2026-10-25 08:00 · 丙午年 戊戌月 壬申日 甲辰時'), findsOneWidget);
    expect(inCard('動爻：六二'), findsOneWidget);
    expect(inCard('六二：同人於宗，吝。'), findsOneWidget);
    expect(inCard('直說：${testTerms.liuyao!.plain('101111', 2, 'zh-Hant')}'), findsOneWidget);
    expect(inCard('直說：只和自己人抱團，格局太小，會吃虧。'), findsOneWidget);
  });

  testWidgets('自己挑幣: 24 coins laid out first; the 18 picks go with the cast in the order picked', (tester) async {
    final api = await _open(tester);
    await _mode(tester, '自己挑幣');
    expect(find.byKey(const Key('coin-0')), findsNothing);
    await tester.tap(find.byKey(const Key('liuyao-lay-out')));
    await frames(tester);
    expect(api.layouts, 1);
    for (var i = 0; i < 24; i++) {
      expect(find.byKey(Key('coin-$i')), findsOneWidget);
    }
    expect(_enabled(tester, 'liuyao-reveal'), isFalse);

    // A first try, started over.
    await tester.tap(find.byKey(const Key('coin-3')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('liuyao-pick-again')));
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const Key('liuyao-picked'))).data, '已挑 0 / 18 枚');

    final picks = [23, 0, 5, 7, 2, 19, 11, 4, 16, 9, 21, 1, 14, 8, 22, 6, 13, 10];
    for (final c in picks) {
      await tester.tap(find.byKey(Key('coin-$c')));
      await tester.pump();
    }
    expect(tester.widget<Text>(find.byKey(const Key('liuyao-picked'))).data, '已挑 18 / 18 枚');
    // The first pick carries its number, and a picked coin can't be picked again.
    expect(find.descendant(of: find.byKey(const Key('coin-23')), matching: find.text('1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('liuyao-reveal')));
    await frames(tester);
    final body = _castBody(api);
    expect(body['mode'], 'pick');
    expect(body['draw_id'], '9a9a9a9a-9a9a-49a9-89a9-9a9a9a9a9a9a');
    expect(body['picks'], picks);

    // Turned over: the first pick shows the 初爻's first coin, and says so.
    final first = ((_chart['tosses'] as List).first['coins'] as List).first as String;
    expect(_sides(find.byKey(const Key('coin-23'))), [first]);
    expect(tester.getSemantics(find.byKey(const Key('coin-23'))).label, contains('第 24 枚硬幣：${first == 'bei' ? '背' : '字'}'));
    expect(find.byKey(const Key('hexagram-card')), findsOneWidget);
  });

  testWidgets('the coins turn over like the tarot cards: a toss lands on its faces, a reveal turns the picks in order (owner, v6.1.0)', (tester) async {
    final tosses = [
      for (final t in _chart['tosses'] as List) [for (final c in (t as Map)['coins'] as List) c as String],
    ];
    String other(String face) => face == 'bei' ? 'zi' : 'bei';

    // 自動擲幣: thrown, each coin spins up from its other face and lands on the toss; then the line shows.
    await _open(tester);
    await tester.tap(find.byKey(const Key('liuyao-toss')));
    await frames(tester);
    await tester.tap(find.byKey(const Key('liuyao-next')));
    await tester.pump();
    final row = find.byKey(const ValueKey<String>('toss-0'));
    final line = find.descendant(of: row, matching: find.byType(Opacity));
    expect(_sides(row), [for (final c in tosses[0]) other(c)]);
    expect(tester.widget<Opacity>(line).opacity, 0);
    await tester.pump(const Duration(milliseconds: 1300)); // 900 ms spin, the third coin 240 ms behind
    await tester.pump(const Duration(milliseconds: 200));
    expect(_sides(row), tosses[0]);
    expect(tester.widget<Opacity>(line).opacity, 1);

    // 自己挑幣: once cast, the picked coins turn over one by one in the order picked; the others stay covered.
    await tester.pumpWidget(const SizedBox.shrink()); // a fresh app (rule 24)
    await _open(tester);
    await _mode(tester, '自己挑幣');
    await tester.tap(find.byKey(const Key('liuyao-lay-out')));
    await frames(tester);
    final picks = [23, 0, 5, 7, 2, 19, 11, 4, 16, 9, 21, 1, 14, 8, 22, 6, 13, 10];
    for (final c in picks) {
      await tester.tap(find.byKey(Key('coin-$c')));
      await tester.pump();
    }
    expect(_sides(find.byKey(const Key('liuyao-coins'))), List.filled(24, 'cover'));
    await tester.tap(find.byKey(const Key('liuyao-reveal')));
    for (var i = 0; i < 10 && find.byKey(const Key('hexagram-card')).evaluate().isEmpty; i++) {
      await tester.pump();
    }
    Finder coin(int i) => find.byKey(Key('coin-$i'));
    String faceOf(int order) => tosses[order ~/ 3][order % 3];
    expect(_sides(coin(picks.first)), ['cover']);
    await tester.pump(const Duration(milliseconds: 300)); // past the first coin's half-turn
    expect(_sides(coin(picks.first)), [faceOf(0)]);
    expect(_sides(coin(picks.last)), ['cover']); // the 18th waits 17 × 90 ms
    await tester.pump(const Duration(milliseconds: 2000));
    for (final (order, c) in picks.indexed) {
      expect(_sides(coin(c)), [faceOf(order)], reason: 'pick ${order + 1}');
    }
    for (final c in [3, 12, 15, 17, 18, 20]) {
      expect(_sides(coin(c)), ['cover'], reason: 'coin $c');
      expect(tester.widget<AnimatedOpacity>(find.descendant(of: coin(c), matching: find.byType(AnimatedOpacity))).opacity, 0.35);
    }
  });

  testWidgets('with the system\'s animations off, the coins show their faces at once', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _open(tester);
    await tester.tap(find.byKey(const Key('liuyao-toss')));
    await frames(tester);
    await tester.tap(find.byKey(const Key('liuyao-next')));
    await tester.pump();
    await tester.pump();
    final row = find.byKey(const ValueKey<String>('toss-0'));
    expect(_sides(row), [for (final c in ((_chart['tosses'] as List).first['coins'] as List)) c as String]);
    expect(tester.widget<Opacity>(find.descendant(of: row, matching: find.byType(Opacity))).opacity, 1);
  });

  testWidgets('自擲自填: nothing is cast without the time; the lines go as the coins counted', (tester) async {
    final api = await _open(tester);
    await _mode(tester, '自擲自填');
    expect(find.byKey(const Key('liuyao-time-missing')), findsOneWidget);
    expect(_enabled(tester, 'liuyao-cast'), isFalse);
    // 初爻 to 上爻: 一背, 三字, 二背, 三背, 一背, 二背 → 7, 6, 8, 9, 7, 8.
    const counts = ['一背', '三字', '二背', '三背', '一背', '二背'];
    for (final (i, label) in counts.indexed) {
      await scrollTo(tester, ValueKey<String>('liuyao-row-${i + 1}'));
      await tester.tap(find.descendant(of: find.byKey(ValueKey<String>('liuyao-row-${i + 1}')), matching: find.text(label)));
      await tester.pump();
    }
    expect(_enabled(tester, 'liuyao-cast'), isFalse); // still no time
    await scrollTo(tester, const Key('liuyao-time-now'));
    await tester.tap(find.byKey(const Key('liuyao-time-now')));
    await tester.pump();
    expect(find.byKey(const Key('liuyao-time-missing')), findsNothing);
    await scrollTo(tester, const Key('liuyao-cast'));
    await tester.tap(find.byKey(const Key('liuyao-cast')));
    await frames(tester);
    final body = _castBody(api);
    expect(body['mode'], 'manual');
    expect(body['local'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$')));
    expect(body['lines'], [
      {'coins': ['bei', 'zi', 'zi']},
      {'coins': ['zi', 'zi', 'zi']},
      {'coins': ['bei', 'bei', 'zi']},
      {'coins': ['bei', 'bei', 'bei']},
      {'coins': ['bei', 'zi', 'zi']},
      {'coins': ['bei', 'bei', 'zi']},
    ]);
    expect(find.byKey(const Key('hexagram-card')), findsOneWidget);
  });

  testWidgets('自己填 by line, for readers who count the faces another way', (tester) async {
    final api = await _open(tester);
    await _mode(tester, '自擲自填');
    await tester.tap(find.descendant(of: find.byKey(const Key('liuyao-enter-by')), matching: find.text('按爻')));
    await tester.pump();
    for (var p = 1; p <= 6; p++) {
      await scrollTo(tester, ValueKey<String>('liuyao-row-$p'));
      await tester.tap(find.descendant(of: find.byKey(ValueKey<String>('liuyao-row-$p')), matching: find.text(p.isEven ? '老陽' : '少陰')));
      await tester.pump();
    }
    await scrollTo(tester, const Key('liuyao-time-now'));
    await tester.tap(find.byKey(const Key('liuyao-time-now')));
    await tester.pump();
    // Ctrl+Enter casts once it is ready.
    await press(tester, LogicalKeyboardKey.enter, control: true);
    expect(_castBody(api)['lines'], [
      for (var p = 1; p <= 6; p++) {'value': p.isEven ? 9 : 8},
    ]);
  });

  testWidgets('the reading takes the question and the cast; history names it by its hexagram', (tester) async {
    final report = fixture('report_liuyao_passed');
    final api = await _open(
      tester,
      FakeApi(
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
            'topics': ['liuyao_hexagram', 'liuyao_answer', 'liuyao_advice'],
            'chart': {
              'system': 'liuyao',
              'mode': 'auto',
              'primary': {'zh-Hant': '天火同人', 'zh-Hans': '天火同人'},
              'changed': {'zh-Hant': '乾為天', 'zh-Hans': '乾为天'},
            },
          },
        ],
      ),
    );
    await tester.enterText(find.byKey(const Key('liuyao-question')), '要不要換工作？');
    await tester.pump();
    await tester.tap(find.byKey(const Key('liuyao-toss')));
    await frames(tester);
    await tester.tap(find.byKey(const Key('liuyao-skip')));
    await frames(tester);
    await scrollTo(tester, const Key('generate-report'));
    expect(find.byKey(const Key('liuyao-sections')), findsOneWidget);
    await tester.tap(find.byKey(const Key('generate-report')));
    await frames(tester, 10);
    final asked = jsonDecode(api.requests.firstWhere((q) => q.url.path == '/v1/reports' && q.method == 'POST').body) as Map;
    expect(asked['question'], '要不要換工作？');
    expect(asked['chart_id'], fixture('chart_liuyao')['chart_id']);
    expect(asked['topics'], ['liuyao_hexagram', 'liuyao_answer', 'liuyao_advice']);
    expect(find.byKey(const Key('reading-hexagram')), findsOneWidget);

    // From history.
    await tester.pumpWidget(const SizedBox.shrink()); // a fresh app (rule 24)
    await tester.pumpWidget(testApp(api));
    await frames(tester, 10);
    await openFromMenu(tester, 'menu-history');
    await frames(tester, 10);
    expect(find.text('算卦 · 天火同人'), findsOneWidget);
    await tester.tap(find.byType(HistoryTile).first);
    await frames(tester, 20);
    expect(find.byKey(const Key('reading-hexagram')), findsOneWidget);
  });

  testWidgets('keyboard: Tab reaches a coin and Enter picks it', (tester) async {
    await _open(tester);
    await _mode(tester, '自己挑幣');
    await tester.tap(find.byKey(const Key('liuyao-lay-out')));
    await frames(tester);
    await tabTo(tester, 'coin-0');
    expect(focusedKey(), 'coin-0');
    await press(tester, LogicalKeyboardKey.enter);
    expect(tester.widget<Text>(find.byKey(const Key('liuyao-picked'))).data, '已挑 1 / 18 枚');
    expect(find.descendant(of: find.byKey(const Key('coin-0')), matching: find.text('1')), findsOneWidget);
  });
}
