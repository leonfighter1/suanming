import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_app/data/token_store.dart';

import 'support.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('signed out → sign-in page; registering lands on home', (tester) async {
    final api = FakeApi();
    final tokens = InMemoryTokenStore();
    await tester.pumpWidget(testApp(api, tokens: tokens));
    await settle(tester);
    expect(find.text('登入'), findsWidgets);
    expect(find.byKey(const Key('entry-bazi')), findsNothing);

    await tester.tap(find.byKey(const Key('auth-toggle')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('email')), 'new@example.com');
    await tester.enterText(find.byKey(const Key('password')), 'long enough pw');
    // Submit stays disabled until the age gate is confirmed.
    expect(tester.widget<FilledButton>(find.byKey(const Key('auth-submit'))).onPressed, isNull);
    await tester.tap(find.byKey(const Key('age-confirm')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('auth-submit')));
    await settle(tester);

    final reg = api.requests.firstWhere((r) => r.url.path == '/v1/auth/register');
    expect(jsonDecode(reg.body), {
      'email': 'new@example.com',
      'password': 'long enough pw',
      'country': 'HK',
      'locale': 'zh-Hant',
      'age_confirmed': true,
    });
    expect(await tokens.read(), isNotNull);
    expect(find.byKey(const Key('entry-bazi')), findsOneWidget);
  });

  testWidgets('wrong password shows the server message and stays signed out', (tester) async {
    await tester.pumpWidget(testApp(FakeApi(), signedIn: false));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('email')), 'me@example.com');
    await tester.enterText(find.byKey(const Key('password')), 'wrong pw here');
    await tester.tap(find.byKey(const Key('auth-submit')));
    await settle(tester);
    expect(find.text('email or password is incorrect'), findsOneWidget);
    expect(find.byKey(const Key('entry-bazi')), findsNothing);
  });

  testWidgets('an unreachable server explains the address instead of a raw ClientException', (tester) async {
    await tester.pumpWidget(testApp(FakeApi()..offline = true, signedIn: false));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('email')), 'xumei');
    await tester.enterText(find.byKey(const Key('password')), 'xumei');
    await tester.tap(find.byKey(const Key('auth-submit')));
    await settle(tester);
    expect(find.textContaining('連不上伺服器 http://api.test'), findsOneWidget);
    expect(find.textContaining('npm run api:lan'), findsOneWidget);
    expect(find.textContaining('ClientException'), findsNothing);
  });

  testWidgets('an expired access token is refreshed once and the call retried', (tester) async {
    final api = FakeApi();
    await tester.pumpWidget(testApp(api));
    await settle(tester);
    api.expireAccessOnce = true;
    await tester.tap(find.byKey(const Key('entry-bazi')));
    await settle(tester);
    await scrollTo(tester, const Key('compute-chart'));
    await tester.ensureVisible(find.byKey(const Key('compute-chart')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('compute-chart')));
    await settle(tester);

    final paths = api.requests.map((r) => '${r.method} ${r.url.path}').toList();
    expect(paths.sublist(paths.length - 3), ['POST /v1/charts', 'POST /v1/auth/refresh', 'POST /v1/charts']);
    expect(find.text('四柱'), findsOneWidget);
  });

  testWidgets('deleting the account calls the API and returns to sign-in', (tester) async {
    final api = FakeApi();
    final tokens = InMemoryTokenStore(Tokens(api.access, 'refresh-0'));
    await tester.pumpWidget(testApp(api, tokens: tokens));
    await settle(tester);
    // The gear opens 設定 directly, with the account in it.
    await tester.tap(find.byKey(const Key('open-settings')));
    await settle(tester);
    expect(find.widgetWithText(AppBar, '設定'), findsOneWidget);
    expect(find.text('me@example.com'), findsOneWidget);
    await tester.tap(find.byKey(const Key('delete-account')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await settle(tester);

    expect(api.requests.any((r) => r.method == 'DELETE' && r.url.path == '/v1/account'), isTrue);
    expect(await tokens.read(), isNull);
    expect(find.byKey(const Key('auth-submit')), findsOneWidget);
    expect(find.text('你的帳戶與資料已刪除。'), findsOneWidget);
  });
}
