import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_app/data/token_store.dart';
import 'package:mingli_app/presentation/buttons.dart';

import 'keys.dart';
import 'support.dart';

void main() {
  testWidgets('signed out → the introduction page, then sign-in (S29); registering lands on home', (tester) async {
    final api = FakeApi();
    final tokens = InMemoryTokenStore();
    await tester.pumpWidget(testApp(api, tokens: tokens));
    await frames(tester, 10);
    expect(find.byKey(const Key('intro-sign-in')), findsOneWidget);
    await openSignIn(tester);
    expect(find.text('登入'), findsWidgets);
    expect(find.byKey(const Key('entry-bazi')), findsNothing);

    await tester.tap(find.byKey(const Key('auth-toggle')));
    await frames(tester, 10);
    // Sign-up (v8.2.0): a username, the email optional.
    await tester.enterText(find.byKey(const Key('email')), 'new@example.com');
    await tester.enterText(find.byKey(const Key('password')), 'long enough pw');
    await tester.tap(find.byKey(const Key('age-confirm')));
    await frames(tester, 10);
    // Submit stays disabled until there is a username and the age gate is confirmed.
    expect(tester.widget<AppFilledButton>(find.byKey(const Key('auth-submit'))).onPressed, isNull);
    await tester.enterText(find.byKey(const Key('username')), 'new_user');
    await frames(tester, 10);
    await tester.tap(find.byKey(const Key('age-confirm')));
    await frames(tester, 10);
    expect(tester.widget<AppFilledButton>(find.byKey(const Key('auth-submit'))).onPressed, isNull);
    await tester.tap(find.byKey(const Key('age-confirm')));
    await frames(tester, 10);
    // The sign-up form runs past a short window (v12.2.0's type ramp: helper lines of 18).
    await scrollTo(tester, const Key('auth-submit'));
    await tester.tap(find.byKey(const Key('auth-submit')));
    await frames(tester, 10);

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
    await frames(tester, 10);
    await openSignIn(tester);
    await tester.enterText(find.byKey(const Key('login')), 'me@example.com');
    await tester.enterText(find.byKey(const Key('password')), 'wrong pw here');
    await tester.tap(find.byKey(const Key('auth-submit')));
    await frames(tester, 10);
    // One answer for a username, an email or a phone (v8.2.0), not the server's English.
    expect(find.text('帳戶或密碼不正確'), findsOneWidget);
    expect(find.byKey(const Key('entry-bazi')), findsNothing);
  });

  testWidgets('管理后台 (v11.2.0): a suspended account is told so at sign-in, and signed out if it was in', (tester) async {
    final api = FakeApi()..suspended = true;
    await tester.pumpWidget(testApp(api, signedIn: false));
    await frames(tester, 10);
    await openSignIn(tester);
    await tester.enterText(find.byKey(const Key('login')), 'me@example.com');
    await tester.enterText(find.byKey(const Key('password')), 'long enough pw');
    await tester.tap(find.byKey(const Key('auth-submit')));
    await frames(tester, 10);
    expect(find.text('這個帳戶已被管理員停用，暫時不能登入。如有疑問請聯絡客服。'), findsOneWidget);
    expect(find.byKey(const Key('entry-bazi')), findsNothing);

    // Signed in when the admin suspends it: the next call signs the app out.
    await tester.pumpWidget(const SizedBox.shrink()); // a fresh app (rule 24)
    final inside = FakeApi();
    final tokens = InMemoryTokenStore(Tokens(inside.access, 'refresh-0'));
    await tester.pumpWidget(testApp(inside, tokens: tokens));
    await frames(tester, 10);
    expect(find.byKey(const Key('entry-bazi')), findsOneWidget);
    inside.suspended = true;
    await tester.tap(find.byKey(const Key('open-menu')));
    await frames(tester, 10);
    // Whatever asks the server next meets the refusal: the menu's balance, or else 历史记录.
    final history = find.byKey(const Key('menu-history'));
    if (history.evaluate().isNotEmpty) {
      await tester.tap(history);
      await frames(tester, 10);
    }
    expect(await tokens.read(), isNull);
    // Out, at the introduction page (S29).
    expect(find.byKey(const Key('intro-sign-in')), findsOneWidget);
  });

  testWidgets('signing in sends what was typed as the login: a username, an email or a phone (v8.2.0)', (tester) async {
    final api = FakeApi();
    await tester.pumpWidget(testApp(api, signedIn: false));
    await frames(tester, 10);
    await openSignIn(tester);
    // The field says what it takes, and that a phone must be bound first.
    expect(find.text('用戶名稱 / 電子郵件 / 手機號碼'), findsOneWidget);
    expect(find.text('手機號碼要先在「設定」裡綁定'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('login')), ' +852 9123 4567 ');
    await tester.enterText(find.byKey(const Key('password')), 'long enough pw');
    await tester.tap(find.byKey(const Key('auth-submit')));
    await frames(tester, 10);
    final login = api.requests.firstWhere((r) => r.url.path == '/v1/auth/login');
    expect(jsonDecode(login.body), {'login': '+852 9123 4567', 'password': 'long enough pw'});
    expect(find.byKey(const Key('entry-bazi')), findsOneWidget);
  });

  testWidgets('sign-up without an email sends none; a taken username says so', (tester) async {
    final api = FakeApi();
    await tester.pumpWidget(testApp(api, signedIn: false));
    await frames(tester, 10);
    await openSignIn(tester);
    await tester.tap(find.byKey(const Key('auth-toggle')));
    await frames(tester, 10);
    await tester.enterText(find.byKey(const Key('username')), 'taken');
    await tester.enterText(find.byKey(const Key('password')), 'long enough pw');
    await tester.tap(find.byKey(const Key('age-confirm')));
    await frames(tester, 10);
    await scrollTo(tester, const Key('auth-submit'));
    await tester.tap(find.byKey(const Key('auth-submit')));
    await frames(tester, 10);
    expect(find.text('這個用戶名稱已被使用'), findsOneWidget);
    expect(find.byKey(const Key('entry-bazi')), findsNothing);

    // Back up to the username (rule 25).
    await scrollToFinder(tester, find.byKey(const Key('username')), delta: -300);
    await tester.enterText(find.byKey(const Key('username')), '徐梅');
    await frames(tester, 10);
    // The error line moved 注册 down the page.
    await scrollTo(tester, const Key('auth-submit'));
    await tester.tap(find.byKey(const Key('auth-submit')));
    await frames(tester, 10);
    final reg = jsonDecode(api.requests.lastWhere((r) => r.url.path == '/v1/auth/register').body) as Map;
    expect(reg['username'], '徐梅');
    expect(reg.containsKey('email'), isFalse);
    expect(find.byKey(const Key('entry-bazi')), findsOneWidget);
  });

  testWidgets('an unreachable server explains the address instead of a raw ClientException', (tester) async {
    await tester.pumpWidget(testApp(FakeApi()..offline = true, signedIn: false));
    await frames(tester, 10);
    await openSignIn(tester);
    await tester.enterText(find.byKey(const Key('login')), 'xumei');
    await tester.enterText(find.byKey(const Key('password')), 'xumei');
    await tester.tap(find.byKey(const Key('auth-submit')));
    await frames(tester, 10);
    expect(find.textContaining('連不上伺服器 http://api.test'), findsOneWidget);
    expect(find.textContaining('npm run api:lan'), findsOneWidget);
    expect(find.textContaining('ClientException'), findsNothing);
  });

  testWidgets('an expired access token is refreshed once and the call retried', (tester) async {
    final api = FakeApi();
    await tester.pumpWidget(testApp(api));
    await frames(tester, 10);
    api.expireAccessOnce = true;
    await tester.tap(find.byKey(const Key('entry-bazi')));
    await frames(tester, 10);
    await scrollTo(tester, const Key('compute-chart'));
    await tester.ensureVisible(find.byKey(const Key('compute-chart')));
    await frames(tester, 10);
    await tester.tap(find.byKey(const Key('compute-chart')));
    await frames(tester, 10);

    final paths = api.requests.map((r) => '${r.method} ${r.url.path}').toList();
    expect(paths.sublist(paths.length - 3), ['POST /v1/charts', 'POST /v1/auth/refresh', 'POST /v1/charts']);
    expect(find.text('四柱'), findsOneWidget);
  });

  testWidgets('deleting the account calls the API and returns to the introduction page', (tester) async {
    final api = FakeApi();
    final tokens = InMemoryTokenStore(Tokens(api.access, 'refresh-0'));
    await tester.pumpWidget(testApp(api, tokens: tokens));
    await frames(tester, 10);
    // 設定 is in the ☰ menu (v8.1.0), with the account in it.
    await openFromMenu(tester, 'open-settings');
    await frames(tester, 10);
    expect(find.widgetWithText(AppBar, '設定'), findsOneWidget);
    // The email row shows the address and whether it is verified (v8.2.0).
    expect(find.text('me@example.com · 未驗證，點此驗證'), findsOneWidget);
    // At the foot of 設定, below 報告 (v9.0.0): out of a test screen's lazily built list until scrolled to.
    await scrollTo(tester, const Key('delete-account'));
    await tester.tap(find.byKey(const Key('delete-account')));
    await frames(tester, 10);
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await frames(tester, 10);

    expect(api.requests.any((r) => r.method == 'DELETE' && r.url.path == '/v1/account'), isTrue);
    expect(await tokens.read(), isNull);
    expect(find.byKey(const Key('intro-sign-in')), findsOneWidget);
    expect(find.text('你的帳戶與資料已刪除。'), findsOneWidget);
  });
}
