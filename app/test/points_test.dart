// 积分 (v11.0.0, S20 WP20.4; the owner's requests 2026-10-29): 10元 = 1000 积分 and more in the larger packs, every AI
// request paid at what it cost (「看看有没有办法知道当前的提交问题给花费了多少，以此反馈到积分上去」), simulated for now
// (「暂时采用模拟策略」), and the 深度分析's 统一收费. The app shows the balance in the ☰ menu, 我的积分 (the packs, how
// charging works, every change), what each AI button costs, and 积分不足 with 去充值.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_app/application/providers.dart' show zhHans;

import 'keys.dart';
import 'support.dart';

Future<void> settle(WidgetTester tester) async {
  // Progress indicators animate forever, so pumpAndSettle would time out; 900 ms covers BringIntoView (rule 61).
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// A fake server with 积分 on: [balance] available, the dev grant as its one change.
FakeApi withPoints({int balance = 10000, String email = 'test@mingli.local'}) {
  final api = FakeApi(email: email, pendingPolls: 0)
    ..pointsOn = true
    ..pointsBalance = balance;
  api.pointsEntries.add({
    'id': '7c7c7c7c-0000-4000-8000-000000000001',
    'kind': 'grant',
    'points': balance,
    'balance': balance,
    'created_at': '2026-10-29T00:00:00.000Z',
    'reason': 'dev',
  });
  return api;
}

/// A fresh app on a phone (rule 59: 360 × 740).
Future<void> start(WidgetTester tester, FakeApi api, {Size size = const Size(360, 740)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const SizedBox.shrink()); // a fresh app (rule 24)
  await tester.pumpWidget(testApp(api, locale: zhHans));
  await settle(tester);
}

/// The 八字 chart page of the test account's default profile.
Future<void> openChart(WidgetTester tester) async {
  await openEntry(tester, 'bazi');
  await settle(tester);
  await scrollTo(tester, const Key('compute-chart'));
  await tester.tap(find.byKey(const Key('compute-chart')));
  await settle(tester);
}

String textOf(WidgetTester tester, Key key) => tester.widget<Text>(find.byKey(key)).data!;

void main() {
  testWidgets('with 积分 off the app shows none of them', (tester) async {
    await start(tester, FakeApi(email: 'test@mingli.local', pendingPolls: 0));
    await tester.tap(find.byKey(const Key('open-menu')));
    await settle(tester);
    // The menu is open (历史记录 and 个人资料 are on screen); 我的积分 is not in it.
    expect(find.byKey(const Key('menu-history')).hitTestable(), findsOneWidget);
    expect(find.byKey(const Key('open-profiles')).hitTestable(), findsOneWidget);
    expect(find.byKey(const Key('open-points')), findsNothing);
    await systemBack(tester);
    await settle(tester);
    await openChart(tester);
    await scrollTo(tester, const Key('generate-report'));
    expect(find.byKey(const Key('generate-report')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('price-report')), findsNothing);
    expect(find.byKey(const ValueKey<String>('price-inquiry')), findsNothing);
  });

  testWidgets('the menu shows what is available; 我的积分 has the packs, how charging works and every change; 充值 adds a pack',
      (tester) async {
    final api = withPoints();
    await start(tester, api);
    await tester.tap(find.byKey(const Key('open-menu')));
    await settle(tester);
    expect(textOf(tester, const Key('menu-points')), '10000');
    await tester.tap(find.byKey(const Key('open-points')));
    await settle(tester);

    expect(find.text('我的积分'), findsOneWidget);
    expect(textOf(tester, const Key('points-available')), '10000');
    expect(find.text('余额 10000 积分'), findsWidgets);
    expect(find.text('测试阶段为模拟充值：不收钱，点一下积分就到账。'), findsOneWidget);
    // The owner's packs: 10元 = 1000, then 5% more for each 10元, to 25% at 50元.
    for (final (yuan, points, bonus) in const [(10, 1000, 0), (20, 2200, 10), (30, 3450, 15), (40, 4800, 20), (50, 6250, 25)]) {
      final pack = find.byKey(ValueKey<String>('points-pack-$yuan'));
      expect(pack.hitTestable(), findsOneWidget, reason: 'on the first screen of a phone: $yuan');
      expect(find.descendant(of: pack, matching: find.text('$points 积分')), findsOneWidget);
      expect(find.descendant(of: pack, matching: find.text('多送 $bonus%')), bonus == 0 ? findsNothing : findsOneWidget);
    }

    await tester.tap(find.byKey(const ValueKey<String>('points-pack-50')));
    await settle(tester);
    expect(api.requests.where((r) => r.url.path == '/v1/points/top-ups'), hasLength(1));
    expect(find.text('已充值 6250 积分（模拟，未收费）'), findsOneWidget);
    // 10000 + 6250 = 16250.
    expect(textOf(tester, const Key('points-available')), '16250');

    // Every change, newest first: the top-up, then the dev accounts' start.
    await scrollTo(tester, const Key('points-entries'));
    await scrollToFinder(tester, find.text('开发测试赠送'));
    expect(find.text('充值 50 元（模拟）'), findsOneWidget);
    expect(find.text('+6250'), findsOneWidget);
    expect(find.text('+10000'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('充值 50 元（模拟）')).dy,
      lessThan(tester.getTopLeft(find.text('开发测试赠送')).dy),
    );
    await scrollToFinder(tester, find.byKey(const Key('points-how')), delta: -300);
    expect(find.textContaining('完成后按这次实际用掉的 AI 用量扣除'), findsOneWidget);
  });

  testWidgets('a charge says what it paid for, how it was priced and, while 充值 is simulated, what the AI cost', (tester) async {
    final api = withPoints()
      ..pointsEntries.insert(0, {
        'id': '7c7c7c7c-0000-4000-8000-000000000002',
        'kind': 'charge',
        'points': -665,
        'balance': 9335,
        'created_at': '2026-10-29T10:00:00.000Z',
        'for': {'kind': 'report', 'id': '22222222-2222-4222-8222-222222222222', 'system': 'bazi'},
        'basis': 'measured',
        'usd': 0.34,
      });
    await start(tester, api);
    await tester.tap(find.byKey(const Key('open-menu')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('open-points')));
    await settle(tester);
    await scrollToFinder(tester, find.text('八字 AI 解读'));
    expect(find.text('-665'), findsOneWidget);
    expect(find.text('余额 9335 积分'), findsOneWidget);
    expect(find.textContaining('按实际用量 · AI 成本 0.340 美元'), findsOneWidget);
  });

  testWidgets('every AI button says what it costs, priced by the topics asked', (tester) async {
    final api = withPoints();
    await start(tester, api, size: const Size(412, 900));
    await openChart(tester);
    await scrollTo(tester, const ValueKey<String>('price-report'));
    expect(textOf(tester, const ValueKey<String>('price-report')), '约 688 积分 · 完成后按实际用量扣除 · 可用 10000');
    // All six topics asked, in their order; the 一生运势 button reads the same quote, so it is asked for once.
    const all = 'wuxing,personality,career_wealth,relationships,dayun_liunian,health';
    expect(api.quoteTopics, [all]);
    await scrollTo(tester, const ValueKey<String>('price-inquiry'));
    expect(textOf(tester, const ValueKey<String>('price-inquiry')), '统一收费 747 积分，不论问几个问题；最终解读另计');
    await scrollTo(tester, const ValueKey<String>('price-life'));
    expect(textOf(tester, const ValueKey<String>('price-life')), '约 1208 积分 · 完成后按实际用量扣除 · 可用 10000');

    // One topic fewer: the price is asked for again, for the five left.
    final health = find.widgetWithText(FilterChip, '健康');
    await scrollToFinder(tester, health, delta: -300);
    await tester.tap(health);
    await settle(tester);
    expect(api.quoteTopics, [all, 'wuxing,personality,career_wealth,relationships,dayun_liunian']);
  });

  testWidgets('积分不足 says what the reading needs and what is available; 去充值 opens 我的积分', (tester) async {
    final api = withPoints(balance: 100);
    await start(tester, api, size: const Size(412, 900));
    await openChart(tester);
    await scrollTo(tester, const Key('generate-report'));
    await tester.tap(find.byKey(const Key('generate-report')));
    await settle(tester);
    expect(find.byKey(const Key('points-short')), findsOneWidget);
    expect(textOf(tester, const Key('points-short-body')), '这次约需 688 积分，你现在可用 100 积分。充值后再试一次。');
    // No reading was opened.
    expect(find.byKey(const Key('analyzing')), findsNothing);
    // 去充值 has the focus: Enter takes the reader there.
    expect(focusedKey(), 'points-go-top-up');
    await tester.tap(find.byKey(const Key('points-go-top-up')));
    await settle(tester);
    expect(find.byKey(const Key('points-balance')), findsOneWidget);
    expect(textOf(tester, const Key('points-available')), '100');
    await tester.tap(find.byKey(const ValueKey<String>('points-pack-10')));
    await settle(tester);
    // Back on the chart, the reading goes ahead: 100 + 1000 − 688 = 412.
    await systemBack(tester);
    await settle(tester);
    await scrollTo(tester, const Key('generate-report'));
    await tester.tap(find.byKey(const Key('generate-report')));
    await settle(tester);
    expect(api.requests.where((r) => r.method == 'POST' && r.url.path == '/v1/reports'), hasLength(2));
    expect(api.pointsBalance, 412);
  });

  testWidgets('追问 says what one more costs, and 积分不足 when there are too few', (tester) async {
    final api = withPoints(balance: 100, email: 'me@example.com');
    await start(tester, api, size: const Size(412, 900));
    await openFromMenu(tester, 'menu-history');
    await settle(tester);
    await tester.tap(find.text('八字排盘').last);
    await settle(tester);
    await tester.tap(find.byKey(const Key('followup-fab')));
    await settle(tester);
    expect(find.text('还可追问 20 次 · 每问约 270 积分'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('followup-field')), '明年我的事业怎么样？');
    await tester.pump(); // rule 19
    await tester.tap(find.byKey(const Key('followup-send')));
    await settle(tester);
    expect(textOf(tester, const Key('points-short-body')), '这次约需 270 积分，你现在可用 100 积分。充值后再试一次。');
    await tester.tap(find.text('取消'));
    await settle(tester);
    // The question stays, to send again after 充值.
    expect(find.text('明年我的事业怎么样？'), findsOneWidget);
  });

  testWidgets('a 破除运势 plan is paid in 积分', (tester) async {
    final api = withPoints(email: 'me@example.com');
    await start(tester, api, size: const Size(1000, 2400));
    await openFromMenu(tester, 'menu-history');
    await settle(tester);
    await tester.tap(find.text('八字排盘').last);
    await settle(tester);
    final buy = find.byKey(const Key('remedy-buy-career_wealth'));
    await scrollToFinder(tester, buy);
    await tester.ensureVisible(buy);
    await settle(tester);
    expect(find.descendant(of: buy, matching: find.text('解锁 · 约 303 积分')), findsOneWidget);
    await tester.tap(buy);
    await settle(tester);
    expect(find.text('“事业财运”的破除运势方案约需 303 积分，生成后按实际用量从积分中扣除。'), findsOneWidget);
    expect(find.text('确认支付 约 303 积分'), findsOneWidget);
    await tester.tap(find.byKey(const Key('remedy-pay')));
    await settle(tester);
    // 10000 − 303 = 9697; the plan opens, without the placeholder's 演示支付.
    expect(api.pointsBalance, 9697);
    expect(find.byKey(const Key('remedy-target')), findsOneWidget);
    expect(find.text('演示支付（未真实扣款）'), findsNothing);
  });

  testWidgets('我的积分 by keyboard: Tab reaches every pack, Enter adds one', (tester) async {
    final api = withPoints();
    await start(tester, api);
    await tester.tap(find.byKey(const Key('open-menu')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('open-points')));
    await settle(tester);
    final stops = await tabStops(tester);
    for (final yuan in [10, 20, 30, 40, 50]) {
      expect(stops, contains('points-pack-$yuan'));
    }
    expect(stops.indexOf('points-pack-10'), lessThan(stops.indexOf('points-pack-50')));
    await tabTo(tester, 'points-pack-20');
    await press(tester, LogicalKeyboardKey.enter);
    await settle(tester);
    // 10000 + 2200 = 12200.
    expect(api.pointsBalance, 12200);
  });

  testWidgets('繁體: 我的積分', (tester) async {
    final api = withPoints();
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(api));
    await settle(tester);
    await tester.tap(find.byKey(const Key('open-menu')));
    await settle(tester);
    expect(find.descendant(of: find.byKey(const Key('open-points')), matching: find.text('我的積分')), findsOneWidget);
    await tester.tap(find.byKey(const Key('open-points')));
    await settle(tester);
    expect(find.text('測試階段為模擬充值：不收錢，點一下積分就到帳。'), findsOneWidget);
    expect(find.text('餘額 10000 積分'), findsWidgets);
  });
}
