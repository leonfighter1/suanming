import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../app/test/keys.dart';
import 'support.dart';

// The dashboard on a phone and on a wide screen, and from the keyboard (管理后台, tech plan S22; the keyboard-access
// skill's checklist).

/// Whether the keyboard focus is on the rail's entry for [label]: a control inside the rail, round the label.
bool railFocusOn(String label) {
  final focused = FocusManager.instance.primaryFocus?.context as Element?;
  if (focused == null) return false;
  var inRail = false;
  focused.visitAncestorElements((a) {
    inRail = a.widget is NavigationRail;
    return !inRail;
  });
  return inRail &&
      find.descendant(of: find.byElementPredicate((e) => e == focused), matching: find.text(label)).evaluate().isNotEmpty;
}

void main() {
  testWidgets('wide: a rail beside the pages', (tester) async {
    await pumpAdmin(tester);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('buttons size to their label (the app\'s compactButtons), side by side; a panel\'s span it', (tester) async {
    await pumpAdmin(tester);
    await go(tester, '导出');
    final pdf = tester.getRect(find.byKey(const Key('export-pdf')));
    final docx = tester.getRect(find.byKey(const Key('export-docx')));
    expect(pdf.width, lessThan(260));
    expect(pdf.height, greaterThanOrEqualTo(40));
    expect(docx.top, pdf.top);
    expect(docx.left, greaterThan(pdf.right));
    // In 收益's panel (S24 WP24.3) the exports stand one under another, each across the panel's column.
    await go(tester, '收益');
    final aside = tester.getRect(find.byKey(const Key('aside')));
    final png = tester.getRect(find.byKey(const Key('export-png')));
    final csv = tester.getRect(find.byKey(const Key('export-series-csv')));
    expect(png.width, closeTo(aside.width - 2 * 24, 1));
    expect(csv.top, greaterThan(png.bottom));
  });

  testWidgets('on a phone, a page of the menu takes the bar\'s place, with its name and a way back (S33)', (tester) async {
    await pumpAdmin(tester, size: phone);
    await go(tester, '用户');
    await go(tester, '内容');
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.descendant(of: find.byType(AppBar), matching: find.text('内容')), findsOneWidget);
    await tapOn(tester, 'menu-back');
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 1, reason: 'back to 用户');
  });

  testWidgets('on a phone: a bar under the pages, and every page fits the width', (tester) async {
    await pumpAdmin(tester, size: phone);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('管理后台'), findsOneWidget);
    for (final page in ['用户', '活跃', '收益', '用量', '导出', '概览']) {
      await go(tester, page);
      expect(tester.takeException(), isNull, reason: page);
    }
    // The hero across the phone, then two figures to a row.
    final hero = tester.getTopLeft(find.byKey(const ValueKey<String>('kpi-充值收入')));
    final a = tester.getTopLeft(find.byKey(const ValueKey<String>('kpi-AI 成本')));
    final b = tester.getTopLeft(find.byKey(const ValueKey<String>('kpi-毛利')));
    expect(hero.dy, lessThan(a.dy));
    expect(a.dy, b.dy);
    expect(b.dx, greaterThan(a.dx));
    await go(tester, '用户');
    // The search and filters come first on a phone; the table under them.
    await scrollToIt(tester, find.byKey(const Key('user-u-02')));
    await tester.tap(find.byKey(const Key('user-u-02')));
    await tester.pumpAndSettle();
    // On a phone the actions follow the account's figures.
    await scrollToIt(tester, find.byKey(const Key('switch-ai')));
    expect(find.byKey(const Key('switch-ai')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the sign-in page fits a phone', (tester) async {
    await pumpAdmin(tester, size: phone, signIn: false);
    expect(find.byKey(const Key('admin-submit')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tab reaches a rail entry and Enter opens its page', (tester) async {
    await pumpAdmin(tester);
    for (var i = 0; i < 40 && !railFocusOn('用户'); i++) {
      await press(tester, LogicalKeyboardKey.tab);
    }
    expect(railFocusOn('用户'), isTrue);
    await press(tester, LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('users-search')), findsOneWidget);
  });

  testWidgets('Tab reaches 刷新, the menu (退出登录 in it, S33), the period and the chart, whose focus shows', (tester) async {
    await pumpAdmin(tester);
    final stops = await tabStops(tester);
    expect(stops, containsAll(['refresh', 'admin-menu', 'period', 'chart']));
    // The menu's items are no Tab stops of the page: the arrows reach them once it is open.
    expect(stops, isNot(contains('sign-out')));
    await tabTo(tester, 'chart');
    expect(ringShown(tester, find.byKey(const Key('chart'))), isTrue);
  });

  testWidgets('the sign-in page: login, password, then 登录', (tester) async {
    await pumpAdmin(tester, signIn: false);
    expect(focusedKey(), 'admin-login');
    await press(tester, LogicalKeyboardKey.tab);
    expect(focusedKey(), 'admin-password');
    await press(tester, LogicalKeyboardKey.tab);
    expect(focusedKey(), 'admin-submit');
  });

  testWidgets('Ctrl+/ lists the keys, as in the app', (tester) async {
    await pumpAdmin(tester);
    await press(tester, LogicalKeyboardKey.slash, control: true);
    await tester.pumpAndSettle();
    expect(find.text('键盘快捷键'), findsOneWidget);
    await press(tester, LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('键盘快捷键'), findsNothing);
  });

  testWidgets('a table wider than a phone scrolls with ←/→ (Home, End) once it has the focus', (tester) async {
    await pumpAdmin(tester, size: phone);
    await go(tester, '用户');
    final grid = find.byKey(const ValueKey<String>('grid-用户'));
    final controller = tester
        .widget<SingleChildScrollView>(find.descendant(of: grid, matching: find.byType(SingleChildScrollView)))
        .controller!;
    expect(controller.position.maxScrollExtent, greaterThan(0));
    await tabTo(tester, 'grid-用户');
    await press(tester, LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(0));
    await press(tester, LogicalKeyboardKey.end);
    await tester.pumpAndSettle();
    expect(controller.offset, controller.position.maxScrollExtent);
    await press(tester, LogicalKeyboardKey.home);
    await tester.pumpAndSettle();
    expect(controller.offset, 0);
  });

  test('every tap target works from the keyboard: no bare GestureDetector in the dashboard', () {
    final bare = [
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>())
        if (f.path.endsWith('.dart') && RegExp(r'\b(Raw)?GestureDetector\(').hasMatch(f.readAsStringSync())) f.path,
    ];
    expect(bare, isEmpty);
  });
}
