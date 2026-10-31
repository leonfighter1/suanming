import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_app/application/providers.dart';
import 'package:mingli_app/presentation/widgets/app_menu.dart' show adminUrl;

import 'keys.dart';
import 'support.dart';

// ☰ → 管理后台 (tech plan S25 WP25.3b; the owner: 如果登陆者具备各项权限，在主页登陆时可以在下拉菜单设置中选择进入后台系统): staff
// (GET /v1/me's staff) see it, and it opens the dashboard with their login filled in; nobody else sees it. Off the web
// (these tests) there is no tab to open, so the dashboard's address is copied.

Future<void> openMenu(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('open-menu')));
  await frames(tester, 12);
}

void main() {
  testWidgets('without a staff role there is no 管理后台 in the menu', (tester) async {
    final api = FakeApi();
    await tester.pumpWidget(testApp(api, locale: zhHans));
    await frames(tester, 12);
    await openMenu(tester);
    // A positive anchor, then the absence (rule 43).
    expect(find.byKey(const Key('open-settings')), findsOneWidget);
    expect(find.byKey(const Key('open-admin')), findsNothing);
    // No one-time code is asked for either (S33).
    expect(api.requests.where((r) => r.url.path == '/v1/account/handoff'), isEmpty);
  });

  testWidgets('staff see 管理后台 with their role; it hands over the login, copied off the web', (tester) async {
    final clipboard = ClipboardWatch(tester);
    final api = FakeApi(username: 'mgr')..staff = 'manager';
    await tester.pumpWidget(testApp(api, locale: zhHans));
    await frames(tester, 12);
    await openMenu(tester);
    expect(find.descendant(of: find.byKey(const Key('open-admin')), matching: find.text('管理后台')), findsOneWidget);
    expect(find.text('以经理身份：复制地址，在浏览器里打开'), findsOneWidget);
    // The one-time code (S33) was asked for as the menu opened, ready for the tap.
    expect(api.requests.where((r) => r.method == 'POST' && r.url.path == '/v1/account/handoff'), hasLength(1));
    await tester.tap(find.byKey(const Key('open-admin')));
    await frames(tester, 12);
    // Off the web the address is copied without it: the code is for this moment only.
    expect(clipboard.copied, 'http://api.test/admin/?login=mgr');
    expect(find.text('已复制管理后台的地址：http://api.test/admin/?login=mgr'), findsOneWidget);
    expect(find.byKey(const Key('app-menu')), findsNothing);
  });

  test('on the web the address carries the one-time code, and the dashboard signs in with it (S33)', () {
    expect(adminUrl('http://api.test', 'mgr', handoff: 'a-b_c'), 'http://api.test/admin/?login=mgr&handoff=a-b_c');
    expect(adminUrl('http://api.test', 'mgr'), 'http://api.test/admin/?login=mgr');
  });

  testWidgets('繁體, an email login (encoded), and from the keyboard', (tester) async {
    final clipboard = ClipboardWatch(tester);
    final api = FakeApi(email: 'boss@example.com')..staff = 'integrator';
    await tester.pumpWidget(testApp(api, locale: zhHant));
    await frames(tester, 12);
    await openMenu(tester);
    expect(find.descendant(of: find.byKey(const Key('open-admin')), matching: find.text('管理後台')), findsOneWidget);
    expect(find.text('以集成人員身份：複製網址，在瀏覽器裡開啟'), findsOneWidget);
    // Tab reaches it in the menu; Enter opens it.
    await tabTo(tester, 'open-admin');
    await press(tester, LogicalKeyboardKey.enter);
    await frames(tester, 12);
    expect(clipboard.copied, 'http://api.test/admin/?login=boss%40example.com');
  });
}
