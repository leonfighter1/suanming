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
    // Sign-up (v8.2.0): a username, the email optional.
    await tester.enterText(find.byKey(const Key('email')), 'new@example.com');
    await tester.enterText(find.byKey(const Key('password')), 'long enough pw');
    await tester.tap(find.byKey(const Key('age-confirm')));
    await settle(tester);
    // Submit stays disabled until there is a username and the age gate is confirmed.
    expect(tester.widget<FilledButton>(find.byKey(const Key('auth-submit'))).onPressed, isNull);
    await tester.enterText(find.byKey(const Key('username')), 'new_user');
    await settle(tester);
    await tester.tap(find.byKey(const Key('age-confirm')));
    await settle(tester);
    expect(tester.widget<FilledButton>(find.byKey(const Key('auth-submit'))).onPressed, isNull);
    await tester.tap(find.byKey(const Key('age-confirm')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('auth-submit')));
    await settle(tester);

    final reg = api.requests.firstWhere((r) => r.url.path == '/v1/auth/register');
    expect(jsonDecode(reg.body), {
      'username': 'new_user',
      'email': 'new@example.com',
      'password': 'long enough pw',
      'country': 'HK',
      'locale': 'zh-Hant',
      'age_confirmed': true,
    });
    expect(await tokens.read(), isNotNull);
    expect(find.byKey(const Key('entry-bazi')), findsOneWidget);
  });

  testWidgets('a wrong password says so in the reader\'s language and stays signed out', (tester) async {
    await tester.pumpWidget(testApp(FakeApi(), signedIn: false));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('login')), 'me@example.com');
    await tester.enterText(find.byKey(const Key('password')), 'wrong pw here');
    await tester.tap(find.byKey(const Key('auth-submit')));
    await settle(tester);
    // One answer for a username, an email or a phone (v8.2.0), not the server's English.
    expect(find.text('帳戶或密碼不正確'), findsOneWidget);
    expect(find.byKey(const Key('entry-bazi')), findsNothing);
  });

  testWidgets('signing in sends what was typed as the login: a username, an email or a phone (v8.2.0)', (tester) async {
    final api = FakeApi();
    await tester.pumpWidget(testApp(api, signedIn: false));
    await settle(tester);
    // The field says what it takes, and that a phone must be bound first.
    expect(find.text('用戶名稱 / 電子郵件 / 手機號碼'), findsOneWidget);
    expect(find.text('手機號碼要先在「設定」裡綁定'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('login')), ' +852 9123 4567 ');
    await tester.enterText(find.byKey(const Key('password')), 'long enough pw');
    await tester.tap(find.byKey(const Key('auth-submit')));
    await settle(tester);
    final login = api.requests.firstWhere((r) => r.url.path == '/v1/auth/login');
    expect(jsonDecode(login.body), {'login': '+852 9123 4567', 'password': 'long enough pw'});
    expect(find.byKey(const Key('entry-bazi')), findsOneWidget);
  });

  testWidgets('sign-up without an email sends none; a taken username says so', (tester) async {
    final api = FakeApi();
    await tester.pumpWidget(testApp(api, signedIn: false));
    await settle(tester);
    await tester.tap(find.byKey(const Key('auth-toggle')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('username')), 'taken');
    await tester.enterText(find.byKey(const Key('password')), 'long enough pw');
    await tester.tap(find.byKey(const Key('age-confirm')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('auth-submit')));
    await settle(tester);
    expect(find.text('這個用戶名稱已被使用'), findsOneWidget);
    expect(find.byKey(const Key('entry-bazi')), findsNothing);

    await tester.enterText(find.byKey(const Key('username')), '徐梅');
    await settle(tester);
    // The error line moved 注册 down the page.
    await scrollTo(tester, const Key('auth-submit'));
    await tester.tap(find.byKey(const Key('auth-submit')));
    await settle(tester);
    final reg = jsonDecode(api.requests.lastWhere((r) => r.url.path == '/v1/auth/register').body) as Map;
    expect(reg['username'], '徐梅');
    expect(reg.containsKey('email'), isFalse);
    expect(find.byKey(const Key('entry-bazi')), findsOneWidget);
  });

  testWidgets('an unreachable server explains the address instead of a raw ClientException', (tester) async {
    await tester.pumpWidget(testApp(FakeApi()..offline = true, signedIn: false));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('login')), 'xumei');
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
    // 設定 is in the ☰ menu (v8.1.0), with the account in it.
    await openFromMenu(tester, 'open-settings');
    await settle(tester);
    expect(find.widgetWithText(AppBar, '設定'), findsOneWidget);
    // The email row shows the address and whether it is verified (v8.2.0).
    expect(find.text('me@example.com · 未驗證，點此驗證'), findsOneWidget);
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
