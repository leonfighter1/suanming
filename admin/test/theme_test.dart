import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_admin/application/providers.dart';
import 'package:mingli_admin/presentation/overview_page.dart';
import 'package:mingli_app/presentation/tokens.dart';

import '../../app/test/keys.dart';
import 'support.dart';

// 外观 in the dashboard (tech plan S24 WP24.1, v12.1.0; owner, 2026-10-30: 「切换主题时保持布局和组件结构不变，让颜色，边框和
// 状态自然过渡」).

/// Every box on screen and where it is: what a change of theme must leave alone.
List<Rect> layoutOf(WidgetTester tester) {
  final rects = <Rect>[];
  void visit(RenderObject o) {
    if (o is RenderBox && o.hasSize) rects.add(o.localToGlobal(Offset.zero) & o.size);
    o.visitChildren(visit);
  }

  tester.binding.renderViews.first.visitChildren(visit);
  return rects;
}

void main() {
  testWidgets('外观 in the menu: 深色 fades the page over, moves nothing, and is kept in the browser', (tester) async {
    final prefs = <String, String>{};
    await pumpAdmin(tester, prefs: prefs);
    final before = layoutOf(tester);
    expect(before.length, greaterThan(50));
    await openMenu(tester);
    await tester.tap(find.byKey(const Key('theme')));
    await tester.pumpAndSettle();
    // The one in use is ticked.
    Finder ticked(String mode) =>
        find.descendant(of: find.byKey(Key('theme-$mode')), matching: find.byIcon(Icons.check));
    expect(ticked('system'), findsOneWidget);
    expect(ticked('dark'), findsNothing);
    expect(find.text('浅色'), findsOneWidget);
    await tester.tap(find.byKey(const Key('theme-dark')));
    await tester.pump();
    await tester.pump();
    // Half-way through the 300 ms change, every colour lies between the two themes.
    await tester.pump(const Duration(milliseconds: 150));
    final page = tester.element(find.byType(OverviewPage));
    expect(ThemeTokens.of(page).darkness, inExclusiveRange(0.3, 0.7));
    expect(ThemeTokens.of(page).series.first, isNot(ThemeTokens.light.series.first));
    expect(ThemeTokens.of(page).series.first, isNot(ThemeTokens.dark.series.first));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.byType(OverviewPage))).brightness, Brightness.dark);
    expect(prefs[ThemeModeNotifier.key], 'dark');
    expect(layoutOf(tester), before);
    await openMenu(tester);
    expect(find.descendant(of: find.byKey(const Key('theme')), matching: find.byIcon(Icons.dark_mode_outlined)), findsOneWidget);
  });

  testWidgets('the dashboard opens in the theme kept in this browser, the sign-in page too', (tester) async {
    await pumpAdmin(tester, prefs: {ThemeModeNotifier.key: 'dark'}, signIn: false);
    expect(Theme.of(tester.element(find.byKey(const Key('admin-login')))).brightness, Brightness.dark);
    await signInAs(tester);
    expect(Theme.of(tester.element(find.byType(OverviewPage))).brightness, Brightness.dark);
  });

  testWidgets('from the keyboard: Tab reaches the menu, Enter opens it, the arrows reach 外观 and pick', (tester) async {
    final prefs = <String, String>{};
    await pumpAdmin(tester, prefs: prefs);
    expect(await tabStops(tester), contains('admin-menu'));
    await tabTo(tester, 'admin-menu');
    await press(tester, LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    // ↓ moves into the menu and down to 外观; → opens it; ↓ moves through the choices to 浅色.
    for (var i = 0; i < 8 && focusedKey() != 'theme'; i++) {
      await press(tester, LogicalKeyboardKey.arrowDown);
    }
    expect(focusedKey(), 'theme');
    await press(tester, LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('theme-light')), findsOneWidget);
    for (var i = 0; i < 3 && focusedKey() != 'theme-light'; i++) {
      await press(tester, LogicalKeyboardKey.arrowDown);
    }
    expect(focusedKey(), 'theme-light');
    await press(tester, LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(prefs[ThemeModeNotifier.key], 'light');
    expect(Theme.of(tester.element(find.byType(OverviewPage))).brightness, Brightness.light);
  });
}
