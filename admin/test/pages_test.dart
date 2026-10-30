import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_admin/presentation/widgets/dashboard.dart';
import 'package:mingli_app/presentation/tokens.dart';

import '../../app/test/keys.dart';
import 'support.dart';

// 概览, 收益, 用量, 活跃 and 导出 (管理后台, tech plan S22), against the fake admin API.

void main() {
  testWidgets('概览 shows the period\'s money, accounts, activity, tokens and 积分', (tester) async {
    await pumpAdmin(tester);
    expect(find.text('2026-09-30 至 2026-10-29（北京时间）'), findsOneWidget);
    // The hero, then the figures in the grid (S24 WP24.3).
    expect(textOf(tester, 'kpi-充值收入'), '¥2,700.00');
    expect(find.text('净收入 ¥2,521.80（扣除支付手续费和增值税）'), findsOneWidget);
    expect(textOf(tester, 'kpi-AI 成本'), '¥449.10');
    expect(textOf(tester, 'kpi-毛利'), '¥2,072.70');
    expect(textOf(tester, 'kpi-毛利率'), '82.2%');
    expect(textOf(tester, 'kpi-新增账户'), '4');
    expect(textOf(tester, 'kpi-AI 请求'), '150');
    expect(textOf(tester, 'kpi-Tokens'), '153.0万');
    expect(textOf(tester, 'kpi-售出积分'), '270,000');
    expect(textOf(tester, 'kpi-消耗积分'), '210,000');
    // The panel: who is on now, how many were active, the accounts and the 积分.
    expect(textOf(tester, 'online-count'), '3');
    expect(find.byKey(const Key('online-admin-1')), findsOneWidget);
    expect(find.text('8 / 30'), findsOneWidget);
    expect(textOf(tester, 'panel-accounts'), '30');
    expect(textOf(tester, 'panel-outstanding'), '120,000');
    // What each kind of AI job cost, below the curve.
    await scrollToIt(tester, find.text('八字 AI 解读'));
    expect(find.text('八字 AI 解读'), findsOneWidget);
    expect(find.text('一生运势报告'), findsOneWidget);
    expect(find.text('塔罗 追问'), findsOneWidget);
  });

  testWidgets('every figure on 概览 says how it changed against the period before: arrow, sign and colour', (tester) async {
    await pumpAdmin(tester);
    // The fake's period before (support.dart): each change worked out there.
    Text said(String label, String text) => tester.widget<Text>(
          find.descendant(
            of: find.ancestor(
              of: find.byKey(ValueKey<String>('kpi-$label')),
              matching: find.byWidgetPredicate((w) => w is StatTile || w is HeroFigure),
            ),
            matching: find.text(text),
          ),
        );
    final t = ThemeTokens.light;
    for (final (label, text, colour) in [
      ('充值收入', '+12.5%', t.success), // 90 against 80
      ('AI 成本', '-6.3%', t.success), // 14.97 against 15.97: down, and up is bad
      ('毛利', '+19.1%', t.success), // 69.09 against 58
      ('毛利率', '+4.2 个百分点', t.success), // 82.2 % against 78 %
      ('新增账户', '持平', t.textMuted),
      ('AI 请求', '+25.0%', t.success), // 5 against 4
      ('Tokens', '-15.0%', t.danger), // 51,000 against 60,000: down, and up is good
      ('售出积分', '持平', t.textMuted),
      ('消耗积分', '+40.0%', t.success), // 7,000 against 5,000
    ]) {
      expect(said(label, text).style?.color, colour, reason: label);
    }
    // Never colour alone: an arrow with the sign, and the period in words. Up: 充值, 毛利, 毛利率, AI 请求, 消耗积分 (5);
    // down: AI 成本, Tokens (2); flat: 新增账户, 售出积分 (2); 9 in all.
    expect(find.byIcon(Icons.arrow_upward), findsNWidgets(5));
    expect(find.byIcon(Icons.arrow_downward), findsNWidgets(2));
    expect(find.byIcon(Icons.remove), findsNWidgets(2));
    expect(find.text('较前 30 天'), findsNWidgets(9));
  });

  testWidgets('the period picker asks for 7 or 90 days, and ←/→ move it', (tester) async {
    final f = await pumpAdmin(tester);
    await tester.tap(find.text('7 天'));
    await tester.pumpAndSettle();
    expect(f.last('/v1/admin/overview').url.queryParameters['days'], '7');
    expect(f.last('/v1/admin/series').url.queryParameters['days'], '7');
    expect(f.last('/v1/admin/breakdown').url.queryParameters['days'], '7');
    expect(textOf(tester, 'kpi-充值收入'), '¥630.00');
    // From the keyboard: → selects 30 天, → again 90 天.
    await tabTo(tester, 'period');
    await press(tester, LogicalKeyboardKey.arrowRight);
    await press(tester, LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(f.last('/v1/admin/overview').url.queryParameters['days'], '90');
    expect(textOf(tester, 'kpi-充值收入'), '¥8,100.00');
  });

  testWidgets('the revenue curve: End picks the last day, ← the one before, a tap a day', (tester) async {
    await pumpAdmin(tester);
    expect(textOf(tester, 'chart-picked'), '点一下曲线，或用左右方向键，看某一天的数字');
    await tabTo(tester, 'chart');
    await press(tester, LogicalKeyboardKey.end);
    expect(textOf(tester, 'chart-picked'), '2026-10-29 · 充值 ¥180.00 · AI 成本 ¥14.97 · 毛利 ¥153.15');
    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(textOf(tester, 'chart-picked'), '2026-10-28 · 充值 ¥0.00 · AI 成本 ¥14.97 · 毛利 -¥14.97');
    await tester.tapAt(tester.getTopLeft(find.byKey(const Key('chart'))) + const Offset(64, 40));
    await tester.pump();
    expect(textOf(tester, 'chart-picked'), startsWith('2026-09-30 · '));
  });

  testWidgets('收益: each day or added up, and every day in a table under the sums', (tester) async {
    await pumpAdmin(tester);
    await go(tester, '收益');
    // 毛利 leads (S24 WP24.3); the 充值 is in the grid and in the table's sums.
    expect(textOf(tester, 'kpi-毛利'), '¥2,072.70');
    expect(textOf(tester, 'kpi-充值收入'), '¥2,700.00');
    await scrollToIt(tester, find.text('合计'));
    expect(find.text('每日明细'), findsOneWidget);
    // The sums' 充值, in the table.
    expect(
      find.descendant(of: find.byKey(const ValueKey<String>('grid-每日明细')), matching: find.text('¥2,700.00')),
      findsOneWidget,
    );
    await scrollToIt(tester, find.byKey(const Key('chart')), delta: -300);
    await tabTo(tester, 'chart');
    await press(tester, LogicalKeyboardKey.end);
    expect(textOf(tester, 'chart-picked'), '2026-10-29 · 充值 ¥180.00 · AI 成本 ¥14.97 · 毛利 ¥153.15');
    // 每日 / 累计 heads the card, above the chart.
    await scrollToIt(tester, find.byKey(const Key('cumulative')), delta: -300);
    await tester.tap(find.text('累计'));
    await tester.pumpAndSettle();
    // Added up over the 30 days: 15 days with a 充值.
    expect(textOf(tester, 'chart-picked'), '2026-10-29 · 充值 ¥2,700.00 · AI 成本 ¥449.10 · 毛利 ¥2,072.70');
  });

  testWidgets('收益 saves the curve as CSV from the server, and as a PNG of the chart', (tester) async {
    final f = await pumpAdmin(tester);
    await go(tester, '收益');
    await tester.tap(find.byKey(const Key('export-series-csv')));
    await tester.pumpAndSettle();
    expect(f.last('/v1/admin/reports').url.queryParameters, {'days': '30', 'format': 'csv', 'kind': 'series'});
    expect(f.saved.single.name, '命理大师-收益曲线-2026-09-30_2026-10-29.csv');
    expect(find.text('已导出 命理大师-收益曲线-2026-09-30_2026-10-29.csv'), findsOneWidget);

    // Making the picture is the engine's real work: real time passes between the frames.
    await tester.tap(find.byKey(const Key('export-png')));
    for (var i = 0; i < 40 && f.saved.length < 2; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    final png = f.saved.last;
    expect(png.name, '命理大师-收益曲线-2026-09-30_2026-10-29.png');
    expect(png.mime, 'image/png');
    expect(png.bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
  });

  testWidgets('用量 shows tokens, requests and cost, by kind of job and by model', (tester) async {
    await pumpAdmin(tester, size: const Size(1280, 2000));
    await go(tester, '用量');
    expect(textOf(tester, 'kpi-Tokens'), '153.0万');
    expect(textOf(tester, 'kpi-AI 请求'), '150');
    expect(find.text('完成 148'), findsOneWidget);
    expect(textOf(tester, 'kpi-每次平均'), '¥2.99');
    expect(find.text('claude-opus-5-5'), findsOneWidget);
    expect(find.text('八字 AI 解读'), findsOneWidget);
    await tabTo(tester, 'chart');
    await press(tester, LogicalKeyboardKey.end);
    expect(textOf(tester, 'chart-picked'), '2026-10-29 · 输入 40,000 · 输出 11,000');
  });

  testWidgets('活跃 lists who is using the app now and today; an account opens its page', (tester) async {
    final f = await pumpAdmin(tester);
    await go(tester, '活跃');
    expect(textOf(tester, 'kpi-15 分钟内'), '3');
    expect(textOf(tester, 'kpi-24 小时内'), '7');
    expect(find.byKey(const Key('active-now-admin-1')), findsOneWidget);
    expect(find.byKey(const Key('active-now-u-06')), findsNothing);
    expect(find.byKey(const Key('active-day-u-06')), findsOneWidget);
    expect(find.text('3 分钟前'), findsWidgets);
    await tester.tap(find.byKey(const Key('active-now-u-02')));
    await tester.pumpAndSettle();
    expect(find.text('user02'), findsWidgets);
    expect(f.to('/v1/admin/users/u-02'), hasLength(1));
  });

  testWidgets('活跃 fetches itself again every minute', (tester) async {
    final f = await pumpAdmin(tester);
    await go(tester, '活跃');
    final before = f.to('/v1/admin/active').length;
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    expect(f.to('/v1/admin/active').length, before + 1);
  });

  testWidgets('导出 makes the report as PDF or Word and the data as CSV, and says when it can\'t', (tester) async {
    final f = await pumpAdmin(tester);
    await go(tester, '导出');
    await tester.tap(find.text('90 天'));
    await tester.pumpAndSettle();
    for (final (key, format, kind) in [
      ('export-docx', 'docx', 'series'),
      ('export-series', 'csv', 'series'),
      ('export-users', 'csv', 'users'),
    ]) {
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
      expect(f.last('/v1/admin/reports').url.queryParameters, {'days': '90', 'format': format, 'kind': kind});
    }
    expect([for (final s in f.saved) s.name], [
      '命理大师-经营报表-2026-08-01_2026-10-29.docx',
      '命理大师-收益曲线-2026-08-01_2026-10-29.csv',
      '命理大师-用户-2026-08-01_2026-10-29.csv',
    ]);
    // No Chinese font on the server: no PDF, and the page says what to do.
    f.failFormats.add('pdf');
    await tester.tap(find.byKey(const Key('export-pdf')));
    await tester.pumpAndSettle();
    expect(find.text('服务器上没有中文字体，做不了 PDF：先导出 Word'), findsOneWidget);
    expect(f.saved, hasLength(3));
  });

  testWidgets('a part that could not load is asked for again a few times, then says why; 重试 fetches it', (tester) async {
    final f = FakeAdmin()..failPaths.add('/v1/admin/breakdown');
    await pumpAdmin(tester, fake: f);
    // The first try and four more, 0.2 to 1.6 s apart.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(f.to('/v1/admin/breakdown'), hasLength(5));
    expect(textOf(tester, 'kpi-充值收入'), '¥2,700.00');
    await scrollToIt(tester, find.byKey(const Key('problem')));
    expect(textOf(tester, 'problem'), '服务器出错了');
    expect(find.text('八字 AI 解读'), findsNothing);
    f.failPaths.clear();
    final before = f.to('/v1/admin/breakdown').length;
    await tester.ensureVisible(find.byKey(const Key('retry')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('retry')));
    await tester.pumpAndSettle();
    expect(f.to('/v1/admin/breakdown').length, before + 1);
    expect(find.byKey(const Key('problem')), findsNothing);
    expect(find.text('八字 AI 解读'), findsOneWidget);
  });
}
