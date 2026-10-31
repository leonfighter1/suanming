// 货币 and 收据 (S31; the owner: 「user is able to pick what ever currencies they like … always get 5% service charge from
// the conversion. - Generate a purchase receipt for user. user is able to view and print the money spent and points they
// purchased. (need to have an email address.)」).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_app/application/providers.dart' show shareProvider, zhHans;
import 'package:mingli_app/data/settings_store.dart';
import 'package:share_plus/share_plus.dart';

import 'keys.dart';
import 'support.dart';

FakeApi buyer() => FakeApi(email: 'test@mingli.local', pendingPolls: 0)
  ..pointsOn = true
  ..pointsBalance = 10000;

Future<void> openPoints(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('open-menu')));
  await frames(tester, 12);
  await tester.tap(find.byKey(const Key('open-points')));
  await frames(tester, 12);
}

Finder inPack(int yuan, String text) =>
    find.descendant(of: find.byKey(ValueKey<String>('points-pack-$yuan')), matching: find.text(text));

void main() {
  testWidgets('充值 in 港币: each pack at today\'s rate plus 5 %; the request names it; the device remembers it', (tester) async {
    final api = buyer();
    final settings = InMemorySettingsStore();
    await tester.pumpWidget(testApp(api, locale: zhHans, settings: settings));
    await frames(tester, 12);
    await openPoints(tester);
    for (final c in ['CNY', 'HKD', 'TWD']) {
      expect(find.byKey(ValueKey<String>('points-currency-$c')), findsOneWidget, reason: c);
    }
    // 元 first, as offered: the packs in 元, no rates line.
    expect(inPack(10, '10 元'), findsOneWidget);
    expect(find.byKey(const Key('points-rates')), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('points-currency-HKD')));
    await frames(tester, 6);
    expect(inPack(10, r'HK$11.42'), findsOneWidget); // 10 × 1.0876 × 1.05 = 11.4198
    expect(inPack(50, r'HK$57.10'), findsOneWidget); // 57.099
    expect(tester.widget<Text>(find.byKey(const Key('points-rates'))).data, '按 2026-10-29 的汇率换算，另加 5% 换算服务费');
    expect(settings.savedCurrency, 'HKD');

    await scrollAndTap(tester, find.byKey(const ValueKey<String>('points-pack-10')), after: true);
    final top = api.requests.lastWhere((r) => r.url.path == '/v1/points/top-ups');
    expect(jsonDecode(top.body), {'yuan': 10, 'currency': 'HKD'});
    expect(find.text('已充值 1000 积分（模拟，未收费）'), findsOneWidget);
  });

  testWidgets('the receipt: from the top-up\'s 查看收据, with the money, the rate, the charge and the email; printed',
      (tester) async {
    final api = buyer();
    final shared = <ShareParams>[];
    await tester.pumpWidget(
      testApp(api, locale: zhHans, overrides: [shareProvider.overrideWithValue((p) async => shared.add(p))]),
    );
    await frames(tester, 12);
    await openPoints(tester);
    await tester.tap(find.byKey(const ValueKey<String>('points-currency-TWD')));
    await frames(tester, 6);
    expect(inPack(20, r'NT$95'), findsOneWidget); // 20 × 4.4918 × 1.05 = 94.33, a whole 新台币 up
    await scrollAndTap(tester, find.byKey(const ValueKey<String>('points-pack-20')), after: true);
    await tester.tap(find.byKey(const Key('points-view-receipt')));
    await frames(tester, 12);

    expect(find.text('收据 MLDS-2026-000001'), findsOneWidget);
    for (final line in [
      'MLDS-2026-000001',
      'test@mingli.local',
      '20 元档，2200 积分',
      r'NT$95（TWD）',
      '1 元 = 4.4918 TWD（2026-10-29）',
      '5%，已含在支付金额里',
    ]) {
      expect(find.text(line), findsOneWidget, reason: line);
    }
    expect(find.byKey(const Key('receipt-simulated')), findsOneWidget);

    // On a phone or a desktop build, printing goes through the share sheet (the browser prints directly).
    await tester.tap(find.byKey(const Key('receipt-print')));
    await frames(tester, 4);
    expect(shared.single.subject, '收据 MLDS-2026-000001');
    expect(shared.single.text, contains(r'支付：NT$95（TWD）'));
  });

  testWidgets('收据 lists every 充值\'s receipt, newest first; none before the first', (tester) async {
    final api = buyer();
    await tester.pumpWidget(testApp(api, locale: zhHans));
    await frames(tester, 12);
    await openPoints(tester);
    await scrollAndTap(tester, find.byKey(const Key('points-receipts')), after: true);
    expect(find.text('还没有收据：充值后会有。'), findsOneWidget);
    await systemBack(tester);

    await scrollAndTap(tester, find.byKey(const ValueKey<String>('points-pack-10')), after: true);
    await scrollAndTap(tester, find.byKey(const ValueKey<String>('points-pack-30')), after: true);
    await scrollAndTap(tester, find.byKey(const Key('points-receipts')), after: true);
    final first = tester.getTopLeft(find.byKey(ValueKey<String>('receipt-${api.receipts.last['id']}')));
    final newest = tester.getTopLeft(find.byKey(ValueKey<String>('receipt-${api.receipts.first['id']}')));
    expect(newest.dy, lessThan(first.dy));
    expect(find.text('MLDS-2026-000002'), findsOneWidget);
  });

  testWidgets('no email on the account: the top-up says why one is needed, and 去设置 goes there', (tester) async {
    final api = buyer()..accountEmail = null;
    await tester.pumpWidget(testApp(api, locale: zhHans));
    await frames(tester, 12);
    await openPoints(tester);
    await scrollAndTap(tester, find.byKey(const ValueKey<String>('points-pack-10')), after: true);
    expect(find.byKey(const Key('points-email-needed')), findsOneWidget);
    expect(find.text('充值的收据上会写你的邮箱。请先在“设置”里填写邮箱，再来充值。'), findsOneWidget);
    expect(api.receipts, isEmpty);
    await tester.tap(find.byKey(const Key('points-go-settings')));
    await frames(tester, 12);
    expect(find.widgetWithText(AppBar, '设置'), findsOneWidget);
  });
}
