import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_app/application/providers.dart';

import 'keys.dart';
import 'support.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

String current(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('language-current'))).data!;

final menu = find.byKey(const Key('app-menu'));

void main() {
  // The owner, v8.1.0: the settings go into the ☰ menu and the bar stays clean. This replaces the 2026-10-27 bar,
  // where 个人资料, 语言 and 设置 each had a button.
  testWidgets('the home bar holds ☰ and 历史记录 only', (tester) async {
    await tester.pumpWidget(testApp(FakeApi(email: 'test@mingli.local'), locale: zhHans));
    await settle(tester);
    final bar = find.byType(AppBar);
    for (final tip in ['菜单', '历史记录']) {
      expect(find.descendant(of: bar, matching: find.byTooltip(tip)), findsOneWidget, reason: tip);
    }
    for (final tip in ['个人资料', '语言', '设置']) {
      expect(find.descendant(of: bar, matching: find.byTooltip(tip)), findsNothing, reason: tip);
    }
    expect(find.descendant(of: bar, matching: find.byIcon(Icons.settings_outlined)), findsNothing);
    expect(find.descendant(of: bar, matching: find.byIcon(Icons.more_vert)), findsNothing);
    expect(find.descendant(of: bar, matching: find.byType(IconButton)), findsNWidgets(2));
  });

  testWidgets('☰ opens the menu: the icon, the account, then every page and setting in order', (tester) async {
    await tester.pumpWidget(testApp(FakeApi(email: 'test@mingli.local'), locale: zhHans));
    await settle(tester);
    expect(menu, findsNothing);
    await tester.tap(find.byKey(const Key('open-menu')));
    await settle(tester);
    expect(menu, findsOneWidget);
    expect(find.descendant(of: menu, matching: find.byKey(const Key('menu-icon'))), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('menu-account'))).data, 'test@mingli.local');
    final order = ['menu-history', 'open-profiles', 'language-menu', 'open-settings', 'open-shortcuts', 'menu-sign-out'];
    final tops = [for (final k in order) tester.getTopLeft(find.byKey(Key(k))).dy];
    expect(tops, [...tops]..sort(), reason: 'top to bottom: $order');
    // Not a reviewer: no 内容审核.
    expect(find.byKey(const Key('open-review')), findsNothing);

    // 个人资料: one tap in the menu; the menu closes behind it.
    await tester.tap(find.byKey(const Key('open-profiles')));
    await settle(tester);
    expect(find.widgetWithText(AppBar, '个人资料'), findsOneWidget);
    await systemBack(tester);
    await settle(tester);
    expect(menu, findsNothing);
  });

  testWidgets('设置 opens from the menu, with the account under 账号与登录', (tester) async {
    await tester.pumpWidget(testApp(FakeApi(email: 'test@mingli.local'), locale: zhHans));
    await settle(tester);
    await openFromMenu(tester, 'open-settings');
    await settle(tester);
    expect(find.widgetWithText(AppBar, '设置'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('settings-account')), matching: find.text('账号与登录')), findsOneWidget);
    expect(find.text('test@mingli.local · 未验证，点此验证'), findsOneWidget);
    expect(find.byKey(const Key('sign-out')), findsOneWidget);
    expect(find.byKey(const Key('delete-account')), findsOneWidget);
  });

  testWidgets('语言 in the menu shows the current language and switches in one dialog', (tester) async {
    await tester.pumpWidget(testApp(FakeApi(email: 'test@mingli.local'), locale: zhHans));
    await settle(tester);
    await openFromMenu(tester, 'language-menu');
    await settle(tester);
    // Chinese only (the owner removed English, v5.4.0): 简体 and 繁體, nothing else.
    expect(find.byKey(const Key('language-zh-Hans')), findsOneWidget);
    expect(find.byKey(const Key('language-en')), findsNothing);
    await tester.tap(find.byKey(const Key('language-zh-Hant')));
    await settle(tester);
    // The menu stays open, showing the new language.
    expect(current(tester), '繁體中文');
    expect(find.descendant(of: menu, matching: find.text('語言')), findsOneWidget);
    await tester.tap(find.byKey(const Key('open-settings')));
    await settle(tester);
    expect(find.widgetWithText(AppBar, '設定'), findsOneWidget);
    await systemBack(tester);
    await settle(tester);
    expect(find.descendant(of: find.byKey(const Key('entry-bazi')), matching: find.text('八字排盤')), findsOneWidget);
  });

  testWidgets('退出登录 in the menu signs out', (tester) async {
    await tester.pumpWidget(testApp(FakeApi(email: 'test@mingli.local'), locale: zhHans));
    await settle(tester);
    await openFromMenu(tester, 'menu-sign-out');
    await settle(tester);
    expect(find.byKey(const Key('auth-submit')), findsOneWidget);
  });

  testWidgets('from the keyboard: Tab reaches ☰, Enter opens the menu, Tab stays in it, Esc closes it', (tester) async {
    await tester.pumpWidget(testApp(FakeApi(email: 'test@mingli.local'), locale: zhHans));
    await settle(tester);
    await press(tester, LogicalKeyboardKey.tab);
    expect(focusedKey(), 'open-menu');
    await press(tester, LogicalKeyboardKey.enter);
    await settle(tester);
    expect(menu, findsOneWidget);
    final stops = <String?>[];
    for (var i = 0; i < 8; i++) {
      await press(tester, LogicalKeyboardKey.tab);
      stops.add(focusedKey());
    }
    // Round the menu's items and back to the first: nothing behind the menu takes the focus.
    expect(stops, [
      'menu-history',
      'open-profiles',
      'language-menu',
      'open-settings',
      'open-shortcuts',
      'menu-sign-out',
      'menu-history',
      'open-profiles',
    ]);
    await press(tester, LogicalKeyboardKey.escape);
    await settle(tester);
    expect(menu, findsNothing);
    expect(find.byKey(const Key('entry-bazi')), findsOneWidget); // still on 首页
    // Esc on 首页 itself does nothing.
    await press(tester, LogicalKeyboardKey.escape);
    await settle(tester);
    expect(find.byKey(const Key('entry-bazi')), findsOneWidget);
  });

  testWidgets('signed out, the sign-in bar has 语言 too', (tester) async {
    await tester.pumpWidget(testApp(FakeApi(), signedIn: false, locale: zhHans));
    await settle(tester);
    final submit = find.byKey(const Key('auth-submit'));
    expect(find.descendant(of: submit, matching: find.text('登录')), findsOneWidget);

    await tester.tap(find.byKey(const Key('language-menu')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('language-zh-Hant')));
    await settle(tester);
    expect(current(tester), '繁');
    expect(find.descendant(of: submit, matching: find.text('登入')), findsOneWidget);
  });

  for (final locale in supportedAppLocales) {
    testWidgets('the bar and the menu fit a 360-wide phone (${apiLocale(locale)})', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(testApp(FakeApi(email: 'test@mingli.local'), locale: locale));
      await settle(tester);
      for (final key in ['open-menu', 'open-history']) {
        final r = tester.getRect(find.byKey(Key(key)));
        expect(r.left >= 0 && r.right <= 360, isTrue, reason: '$key at $r');
      }
      // The title stays whole.
      final name = locale.scriptCode == 'Hans' ? '命理大师' : '命理大師';
      final title = tester.renderObject<RenderParagraph>(find.descendant(of: find.byType(AppBar), matching: find.text(name)));
      expect(title.getMaxIntrinsicWidth(double.infinity), lessThanOrEqualTo(title.size.width + 0.5));

      await tester.tap(find.byKey(const Key('open-menu')));
      await settle(tester);
      expect(tester.takeException(), isNull);
      final last = tester.getRect(find.byKey(const Key('menu-sign-out')));
      expect(last.bottom, lessThanOrEqualTo(740), reason: 'the whole menu on one phone screen');
    });
  }
}
