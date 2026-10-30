// S26 WP26.2 (owner, 2026-10-30): 「我看到西方有今日一牌功能， 那么东方系列，我们剋增加今日一卦或者今日一签功能，可以随机出现」.
// 今日一卦 / 今日一签 under 东方: the account's 东方 draw of the day, a 签 or a 卦 as the server deals it, opened with the
// method's own card and an AI reading asked without a question.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'keys.dart';
import 'support.dart';

Future<void> settle(WidgetTester tester) async {
  // The last part of 首页 comes in after the others (FadeSlideIn's index): let them all arrive.
  for (var i = 0; i < 14; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// 首页 with the server dealing [kind] today ('qiuqian', 'liuyao', or null: neither is served).
Future<FakeApi> openHome(WidgetTester tester, String? kind, {Size size = const Size(1000, 2400)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = FakeApi()..eastDaily = kind;
  await tester.pumpWidget(testApp(api));
  await settle(tester);
  return api;
}

/// The reading asked for last: POST /v1/reports's body.
Map<String, dynamic> lastReading(FakeApi api) =>
    jsonDecode(api.requests.lastWhere((r) => r.method == 'POST' && r.url.path == '/v1/reports').body)
        as Map<String, dynamic>;

void main() {
  testWidgets('the day\'s 签 under 东方: its title and label; opened, its lot and a reading asked without a question',
      (tester) async {
    final api = await openHome(tester, 'qiuqian');
    // The fixture's lot: 89, labelled 壬壬, 第八十九籤 in 繁體 (the test app's script; qiuqian_lots.json).
    expect((fixture('chart_qiuqian')['chart_fact']['facts']['lot'] as Map)['n'], 89);
    await scrollTo(tester, const Key('east-daily'));
    final card = find.byKey(const Key('east-daily'));
    expect(find.descendant(of: card, matching: find.text('今日一籤')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('east-daily-name'))).data, '第八十九籤 · 壬壬');
    // Under 东方: right after its last method, before 西方's heading.
    // Measured through the parts' entrance (rule 61): closeTo.
    expect(tester.getRect(card).top, closeTo(tester.getRect(find.byKey(const Key('entry-fengshui'))).bottom, 0.01));
    expect(tester.getRect(find.byKey(const Key('group-west'))).top, greaterThanOrEqualTo(tester.getRect(card).bottom));
    // Asked for the device's calendar date and time zone.
    final asked = api.requests.where((r) => r.url.path == '/v1/east/daily').toList();
    expect(asked, isNotEmpty);
    for (final r in asked) {
      expect(r.url.queryParameters['date'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
      expect(r.url.queryParameters['timezone'], isNotEmpty);
    }

    await tester.tap(card);
    await settle(tester);
    expect(find.byKey(const Key('east-daily-lot')), findsOneWidget);
    expect(find.text('樽前無事且高歌'), findsOneWidget); // the lot's first line
    await scrollTo(tester, const Key('generate-report'));
    expect(find.byKey(const Key('qiuqian-sections')), findsOneWidget); // read as 求签 reads
    await tester.tap(find.byKey(const Key('generate-report')));
    await frames(tester, 10);
    final reading = lastReading(api);
    expect(reading['chart_id'], fixture('chart_qiuqian')['chart_id']);
    expect(reading.containsKey('question'), isFalse); // nothing was drawn for one
  });

  testWidgets('the day\'s 卦: its number and names and its lines; opened, its hexagram and a reading', (tester) async {
    final api = await openHome(tester, 'liuyao');
    await scrollTo(tester, const Key('east-daily'));
    final card = find.byKey(const Key('east-daily'));
    expect(find.descendant(of: card, matching: find.text('今日一卦')), findsOneWidget);
    // The fixture's cast: lines 7 6 7 7 7 7 from the 初爻, so 本卦 13 天火同人 and, its second line moving, 乾為天.
    expect(tester.widget<Text>(find.byKey(const Key('east-daily-name'))).data, '第13卦 · 天火同人 → 乾為天');
    expect(find.descendant(of: card, matching: find.byKey(const Key('hexagram-lines'))), findsOneWidget);

    await tester.tap(card);
    await settle(tester);
    expect(find.byKey(const Key('east-daily-hexagram')), findsOneWidget);
    await scrollTo(tester, const Key('generate-report'));
    await tester.tap(find.byKey(const Key('generate-report')));
    await frames(tester, 10);
    final reading = lastReading(api);
    expect(reading['chart_id'], fixture('chart_liuyao')['chart_id']);
    expect(reading.containsKey('question'), isFalse);
  });

  testWidgets('none to be had (neither 求签 nor 算卦 served): no card, 东方 as before', (tester) async {
    await openHome(tester, null);
    // The anchor first (rule 43): 东方's last method, which the card would follow.
    expect(find.byKey(const Key('entry-fengshui')), findsOneWidget);
    expect(find.byKey(const Key('east-daily'), skipOffstage: false), findsNothing);
    expect(find.byKey(const Key('daily-card')), findsOneWidget); // 西方's 今日一牌 is still there
  });

  testWidgets('on a desktop window it spans 东方 under the 2 × 2', (tester) async {
    await openHome(tester, 'liuyao', size: const Size(1280, 1600));
    // The content: 1280 - 2 × 32 = 1216 wide from 32; the card right under the second row (算卦 and 风水).
    final card = tester.getRect(find.byKey(const Key('east-daily')));
    expect(card.left, closeTo(32, 0.01));
    expect(card.width, closeTo(1216, 0.01));
    expect(card.top, closeTo(tester.getRect(find.byKey(const Key('entry-fengshui'))).bottom, 0.01));
    expect(card.top, closeTo(tester.getRect(find.byKey(const Key('entry-liuyao'))).bottom, 0.01));
  });

  testWidgets('keyboard: Tab reaches it after 东方\'s methods, Enter opens it, Esc comes back', (tester) async {
    await openHome(tester, 'qiuqian');
    await tabTo(tester, 'east-daily');
    expect(ringShown(tester, find.byKey(const Key('east-daily'))), isTrue);
    await press(tester, LogicalKeyboardKey.enter);
    await settle(tester);
    expect(find.byKey(const Key('east-daily-lot')), findsOneWidget);
    await press(tester, LogicalKeyboardKey.escape);
    await settle(tester);
    expect(find.byKey(const Key('east-daily')), findsOneWidget);
  });
}
