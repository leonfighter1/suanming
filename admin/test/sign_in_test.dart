import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../app/test/keys.dart';
import 'support.dart';

// 管理员登录 and the session (管理后台, tech plan S22).

void main() {
  testWidgets('an admin signs in and lands on 概览', (tester) async {
    final f = await pumpAdmin(tester);
    expect(find.text('命理大师 管理后台'), findsOneWidget);
    expect(find.byKey(const Key('admin-me')), findsOneWidget);
    expect(textOf(tester, 'kpi-充值收入'), '¥2,700.00');
    // Signing in checks the account is an admin.
    expect(f.to('/v1/admin/me'), hasLength(1));
    expect(f.last('/v1/admin/overview').url.queryParameters['days'], '30');
  });

  testWidgets('an account without a staff role is turned away, and its session dropped', (tester) async {
    final f = FakeAdmin()..admin = false;
    await pumpAdmin(tester, fake: f);
    expect(find.text('这个账号没有后台权限'), findsOneWidget);
    expect(find.byKey(const Key('admin-submit')), findsOneWidget);
    expect(f.to('/v1/auth/logout', method: 'POST'), hasLength(1));
  });

  testWidgets('a wrong password and a suspended account each say so', (tester) async {
    final f = await pumpAdmin(tester, signIn: false);
    await signInAs(tester, password: 'wrong');
    expect(find.text('账号或密码不正确'), findsOneWidget);
    f.suspended = true;
    await signInAs(tester);
    expect(find.text('这个账号已被停用'), findsOneWidget);
    expect(find.byKey(const Key('admin-me')), findsNothing);
  });

  testWidgets('Enter moves to the password, Enter there signs in', (tester) async {
    await pumpAdmin(tester, signIn: false);
    await tester.enterText(find.byKey(const Key('admin-login')), 'boss');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(focusedKey(), 'admin-password');
    await tester.enterText(find.byKey(const Key('admin-password')), 'secret1');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('admin-me')), findsOneWidget);
  });

  testWidgets('the login the app hands over (☰ → 管理后台, S25) is filled in, and the password comes first', (tester) async {
    await pumpAdmin(tester, signIn: false, loginHint: 'boss');
    expect(tester.widget<TextField>(find.byKey(const Key('admin-login'))).controller!.text, 'boss');
    expect(focusedKey(), 'admin-password');
    await tester.enterText(find.byKey(const Key('admin-password')), 'secret1');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('admin-me')), findsOneWidget);
  });

  testWidgets('Ctrl+Enter signs in', (tester) async {
    await pumpAdmin(tester, signIn: false);
    await tester.enterText(find.byKey(const Key('admin-login')), 'boss');
    await tester.enterText(find.byKey(const Key('admin-password')), 'secret1');
    await press(tester, LogicalKeyboardKey.enter, control: true);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('admin-me')), findsOneWidget);
  });

  testWidgets('退出登录 ends the session on the server too', (tester) async {
    final f = await pumpAdmin(tester);
    await tester.tap(find.byKey(const Key('sign-out')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('admin-submit')), findsOneWidget);
    expect(f.bodyOf(f.last('/v1/auth/logout', method: 'POST')), {'refresh_token': 'r1'});
  });

  testWidgets('an expired access token is refreshed once and the request sent again', (tester) async {
    final f = await pumpAdmin(tester);
    f.expireOnce = true;
    await tester.tap(find.byKey(const Key('refresh')));
    await tester.pumpAndSettle();
    expect(f.to('/v1/auth/refresh', method: 'POST'), hasLength(1));
    expect(f.last('/v1/admin/overview').headers['authorization'], 'Bearer a2');
    expect(find.byKey(const Key('admin-me')), findsOneWidget);
  });

  testWidgets('a refresh that fails, or the admin role taken away, signs out', (tester) async {
    final f = await pumpAdmin(tester);
    f
      ..expireOnce = true
      ..refreshFails = true;
    await tester.tap(find.byKey(const Key('refresh')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('admin-submit')), findsOneWidget);

    f
      ..refreshFails = false
      ..admin = true;
    await signInAs(tester);
    expect(find.byKey(const Key('admin-me')), findsOneWidget);
    f.revokeNext = true;
    await tester.tap(find.byKey(const Key('refresh')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('admin-submit')), findsOneWidget);
  });
}
