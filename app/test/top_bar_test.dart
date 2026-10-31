import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_app/application/providers.dart';
import 'package:mingli_app/presentation/buttons.dart';
import 'package:mingli_app/presentation/design.dart' show Space, focusOutline;

import 'keys.dart';
import 'support.dart';

String current(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('language-current'))).data!;

final menu = find.byKey(const Key('app-menu'));

void main() {
  // The owner, v8.1.0: the settings go into the ☰ menu and the bar stays clean; v9.1.0: 历史记录 goes in too, and ☰
  // moves to the right, framed, with a mark before the name. This replaces the 2026-10-27 bar, where 个人资料, 语言
  // and 设置 each had a button.
  testWidgets('the home bar: the mark and the name, then a framed ☰ at the right end, nothing else', (tester) async {
    await tester.pumpWidget(testApp(FakeApi(email: 'test@mingli.local'), locale: zhHans));
    await frames(tester, 12);
    final bar = find.byType(AppBar);
    expect(find.descendant(of: bar, matching: find.byTooltip('菜单')), findsOneWidget);
    for (final tip in ['历史记录', '个人资料', '语言', '设置']) {
      expect(find.descendant(of: bar, matching: find.byTooltip(tip)), findsNothing, reason: tip);
    }
    expect(find.descendant(of: bar, matching: find.byIcon(Icons.history)), findsNothing);
    expect(find.descendant(of: bar, matching: find.byType(IconButton)), findsOneWidget);

    final mark = tester.getRect(find.descendant(of: bar, matching: find.byKey(const Key('title-mark'))));
    final name = tester.getRect(find.descendant(of: bar, matching: find.text('命理大师')));
    final button = tester.getRect(find.byKey(const Key('open-menu')));
    expect(mark.right, lessThanOrEqualTo(name.left));
    expect(name.right, lessThan(button.left));
    expect(tester.getRect(bar).right - button.right, lessThanOrEqualTo(Space.m + 4), reason: 'at the right end: $button');

    // Framed in the theme's 赭红, 1.5 px; the focus outline takes its place while it has the keyboard focus.
    final style = tester.widget<AppIconButton>(find.byKey(const Key('open-menu'))).style!;
    final scheme = Theme.of(tester.element(bar)).colorScheme;
    final frame = style.side!.resolve(const <WidgetState>{})!;
    expect((frame.width, frame.color), (1.5, scheme.primary));
    expect(style.side!.resolve(const {WidgetState.focused}), focusOutline(scheme));
  });

  testWidgets('☰ opens the menu from the right: the icon, the account, then every page and setting in order', (tester) async {
    await tester.pumpWidget(testApp(FakeApi(email: 'test@mingli.local'), locale: zhHans));
    await frames(tester, 12);
    expect(menu, findsNothing);
    await tester.tap(find.byKey(const Key('open-menu')));
    await frames(tester, 12);
    expect(menu, findsOneWidget);
    // An end drawer, flush with the screen's right edge, where ☰ is.
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    final drawer = tester.getRect(menu);
    expect(drawer.right, screen.width);
    expect(drawer.left, greaterThan(screen.width / 3));
    expect(find.descendant(of: menu, matching: find.byKey(const Key('menu-icon'))), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('menu-account'))).data, 'test@mingli.local');
    final order = ['menu-history', 'open-profiles', 'language-menu', 'open-settings', 'open-shortcuts', 'menu-sign-out'];
    final tops = [for (final k in order) tester.getTopLeft(find.byKey(Key(k))).dy];
    expect(tops, [...tops]..sort(), reason: 'top to bottom: $order');
    // Not a reviewer: no 内容审核.
    expect(find.byKey(const Key('open-review')), findsNothing);

    // 个人资料: one tap in the menu; the menu closes behind it.
    await tester.tap(find.byKey(const Key('open-profiles')));
    await frames(tester, 12);
    expect(find.widgetWithText(AppBar, '个人资料'), findsOneWidget);
    await systemBack(tester);
    await frames(tester, 12);
    expect(menu, findsNothing);

    // 历史记录 too (v9.1.0: off the bar, first in the menu).
    await openFromMenu(tester, 'menu-history');
    await frames(tester, 12);
    expect(find.widgetWithText(AppBar, '历史记录'), findsOneWidget);
    await systemBack(tester);
    await frames(tester, 12);
    expect(find.byKey(const Key('entry-bazi')), findsOneWidget); // back on 首页
    expect(menu, findsNothing);
  });

  testWidgets('设置 opens from the menu, with the account under 账号与登录', (tester) async {
    await tester.pumpWidget(testApp(FakeApi(email: 'test@mingli.local'), locale: zhHans));
    await frames(tester, 12);
    await openFromMenu(tester, 'open-settings');
    await frames(tester, 12);
    expect(find.widgetWithText(AppBar, '设置'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('settings-account')), matching: find.text('账号与登录')), findsOneWidget);
    expect(find.text('test@mingli.local · 未验证，点此验证'), findsOneWidget);
    // Then 报告 (v9.0.0), then the account's end, in page order (rule 25).
    await scrollTo(tester, const Key('settings-reports'));
    expect(find.descendant(of: find.byKey(const Key('settings-reports')), matching: find.text('报告')), findsOneWidget);
    await scrollTo(tester, const Key('sign-out'));
    expect(find.byKey(const Key('sign-out')), findsOneWidget);
    await scrollTo(tester, const Key('delete-account'));
    expect(find.byKey(const Key('delete-account')), findsOneWidget);
  });

  testWidgets('语言 in the menu shows the current language and switches in one dialog', (tester) async {
    await tester.pumpWidget(testApp(FakeApi(email: 'test@mingli.local'), locale: zhHans));
    await frames(tester, 12);
    await openFromMenu(tester, 'language-menu');
    await frames(tester, 12);
    // Chinese only (the owner removed English, v5.4.0): 简体 and 繁體, nothing else.
    expect(find.byKey(const Key('language-zh-Hans')), findsOneWidget);
    expect(find.byKey(const Key('language-en')), findsNothing);
    await tester.tap(find.byKey(const Key('language-zh-Hant')));
    await frames(tester, 12);
    // The menu stays open, showing the new language.
    expect(current(tester), '繁體中文');
    expect(find.descendant(of: menu, matching: find.text('語言')), findsOneWidget);
    await tester.tap(find.byKey(const Key('open-settings')));
    await frames(tester, 12);
    expect(find.widgetWithText(AppBar, '設定'), findsOneWidget);
    await systemBack(tester);
    await frames(tester, 12);
    expect(find.descendant(of: find.byKey(const Key('entry-bazi')), matching: find.text('八字排盤')), findsOneWidget);
  });

  testWidgets('退出登录 in the menu signs out', (tester) async {
    await tester.pumpWidget(testApp(FakeApi(email: 'test@mingli.local'), locale: zhHans));
    await frames(tester, 12);
    await openFromMenu(tester, 'menu-sign-out');
    await frames(tester, 12);
    // Back at the introduction page (S29).
    expect(find.byKey(const Key('intro-sign-in')), findsOneWidget);
  });

  testWidgets('from the keyboard: Tab reaches ☰, Enter opens the menu, Tab stays in it, Esc closes it', (tester) async {
    await tester.pumpWidget(testApp(FakeApi(email: 'test@mingli.local'), locale: zhHans));
    await frames(tester, 12);
    await press(tester, LogicalKeyboardKey.tab);
    expect(focusedKey(), 'open-menu');
    await press(tester, LogicalKeyboardKey.enter);
    await frames(tester, 12);
    expect(menu, findsOneWidget);
    final stops = <String?>[];
    for (var i = 0; i < 9; i++) {
      await press(tester, LogicalKeyboardKey.tab);
      stops.add(focusedKey());
    }
    // Round the menu's items and back to the first, its close button (S30): nothing behind the menu takes the focus.
    expect(stops, [
      'menu-close',
      'menu-history',
      'open-profiles',
      'language-menu',
      'theme-menu',
      'open-settings',
      'open-shortcuts',
      'menu-sign-out',
      'menu-close',
    ]);
    await press(tester, LogicalKeyboardKey.escape);
    await frames(tester, 12);
    expect(menu, findsNothing);
    expect(find.byKey(const Key('entry-bazi')), findsOneWidget); // still on 首页
    // Esc on 首页 itself does nothing.
    await press(tester, LogicalKeyboardKey.escape);
    await frames(tester, 12);
    expect(find.byKey(const Key('entry-bazi')), findsOneWidget);
  });

  testWidgets('signed out, the sign-in bar has 语言 too', (tester) async {
    await tester.pumpWidget(testApp(FakeApi(), signedIn: false, locale: zhHans));
    await frames(tester, 12);
    await openSignIn(tester);
    final submit = find.byKey(const Key('auth-submit'));
    expect(find.descendant(of: submit, matching: find.text('登录')), findsOneWidget);

    await tester.tap(find.byKey(const Key('language-menu')));
    await frames(tester, 12);
    await tester.tap(find.byKey(const Key('language-zh-Hant')));
    await frames(tester, 12);
    expect(current(tester), '繁');
    expect(find.descendant(of: submit, matching: find.text('登入')), findsOneWidget);
  });

  for (final locale in supportedAppLocales) {
    testWidgets('the bar and the menu fit a 360-wide phone (${apiLocale(locale)})', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(testApp(FakeApi(email: 'test@mingli.local'), locale: locale));
      await frames(tester, 12);
      for (final key in ['title-mark', 'open-menu']) {
        final r = tester.getRect(find.byKey(Key(key)));
        expect(r.left >= 0 && r.right <= 360, isTrue, reason: '$key at $r');
      }
      // The title stays whole.
      final name = locale.scriptCode == 'Hans' ? '命理大师' : '命理大師';
      final title = tester.renderObject<RenderParagraph>(find.descendant(of: find.byType(AppBar), matching: find.text(name)));
      expect(title.getMaxIntrinsicWidth(double.infinity), lessThanOrEqualTo(title.size.width + 0.5));

      await tester.tap(find.byKey(const Key('open-menu')));
      await frames(tester, 12);
      expect(tester.takeException(), isNull);
      expect(tester.getRect(menu).right, 360, reason: 'from the right, where ☰ is');
      final last = tester.getRect(find.byKey(const Key('menu-sign-out')));
      expect(last.bottom, lessThanOrEqualTo(740), reason: 'the whole menu on one phone screen');
    });
  }
}
