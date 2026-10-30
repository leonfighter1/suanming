import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_app/application/providers.dart';

import 'keys.dart';
import 'support.dart';

// ☰ → 管理后台 (tech plan S25 WP25.3b; the owner: 如果登陆者具备各项权限，在主页登陆时可以在下拉菜单设置中选择进入后台系统): staff
// (GET /v1/me's staff) see it, and it opens the dashboard with their login filled in; nobody else sees it. Off the web
// (these tests) there is no tab to open, so the dashboard's address is copied.

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> openMenu(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('open-menu')));
  await settle(tester);
}

/// What the app puts on the clipboard (the platform's Clipboard.setData), the latest in [copied].
class ClipboardWatch {
  ClipboardWatch(WidgetTester tester) {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
  }
  String? copied;
}

void main() {
  testWidgets('without a staff role there is no 管理后台 in the menu', (tester) async {
    await tester.pumpWidget(testApp(FakeApi(), locale: zhHans));
    await settle(tester);
    await openMenu(tester);
    // A positive anchor, then the absence (rule 43).
    expect(find.byKey(const Key('open-settings')), findsOneWidget);
    expect(find.byKey(const Key('open-admin')), findsNothing);
  });

  testWidgets('staff see 管理后台 with their role; it hands over the login, copied off the web', (tester) async {
    final clipboard = ClipboardWatch(tester);
    final api = FakeApi(username: 'mgr')..staff = 'manager';
    await tester.pumpWidget(testApp(api, locale: zhHans));
    await settle(tester);
    await openMenu(tester);
    expect(find.descendant(of: find.byKey(const Key('open-admin')), matching: find.text('管理后台')), findsOneWidget);
    expect(find.text('以经理身份：复制地址，在浏览器里打开'), findsOneWidget);
    await tester.tap(find.byKey(const Key('open-admin')));
    await settle(tester);
    expect(clipboard.copied, 'http://api.test/admin/?login=mgr');
    expect(find.text('已复制管理后台的地址：http://api.test/admin/?login=mgr'), findsOneWidget);
    expect(find.byKey(const Key('app-menu')), findsNothing);
  });

  testWidgets('繁體, an email login (encoded), and from the keyboard', (tester) async {
    final clipboard = ClipboardWatch(tester);
    final api = FakeApi(email: 'boss@example.com')..staff = 'integrator';
    await tester.pumpWidget(testApp(api, locale: zhHant));
    await settle(tester);
    await openMenu(tester);
    expect(find.descendant(of: find.byKey(const Key('open-admin')), matching: find.text('管理後台')), findsOneWidget);
    expect(find.text('以集成人員身份：複製網址，在瀏覽器裡開啟'), findsOneWidget);
    // Tab reaches it in the menu; Enter opens it.
    await tabTo(tester, 'open-admin');
    await press(tester, LogicalKeyboardKey.enter);
    await settle(tester);
    expect(clipboard.copied, 'http://api.test/admin/?login=boss%40example.com');
  });
}
