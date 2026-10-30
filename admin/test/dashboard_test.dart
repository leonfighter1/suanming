import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_admin/presentation/widgets/dashboard.dart';
import 'package:mingli_app/presentation/design.dart';
import 'package:mingli_app/presentation/layout.dart';

import '../../app/test/keys.dart';
import 'support.dart';

// The asymmetric dashboard (tech plan S24 WP24.3; owner, 2026-10-30: 「非对称Dashboard布局，以大数字为视觉锚点，辅助数据采用紧凑网格，
// 右侧设置独立纵向面板」).

void main() {
  testWidgets('wide: the hero leads the main column, the figures in a grid of four, the panel at the right', (tester) async {
    await pumpAdmin(tester, size: const Size(1440, 900));
    final hero = tester.getRect(find.byKey(const Key('hero')));
    final aside = tester.getRect(find.byKey(const Key('aside')));
    expect(aside.width, asideWidth);
    expect(aside.left, greaterThan(hero.right));
    // In the container (pageMax), the window's margin beyond the panel.
    expect(aside.right, 1440 - WindowClass.large.margin);
    // The hero figure at 48 or more; a supporting figure smaller.
    final figure = tester.widget<Text>(find.byKey(const ValueKey<String>('kpi-充值收入')));
    final tile = tester.widget<Text>(find.byKey(const ValueKey<String>('kpi-AI 成本')));
    expect(figure.style!.fontSize, greaterThanOrEqualTo(48));
    expect(tile.style!.fontSize, lessThan(figure.style!.fontSize!));
    // Eight figures, four to a row, under the hero.
    final cost = tester.getRect(find.byKey(const ValueKey<String>('kpi-AI 成本')));
    final requests = tester.getRect(find.byKey(const ValueKey<String>('kpi-AI 请求')));
    final margin = tester.getRect(find.byKey(const ValueKey<String>('kpi-毛利率')));
    expect(cost.top, greaterThan(hero.bottom));
    expect(margin.top, cost.top);
    expect(requests.top, greaterThan(cost.top));
    expect(requests.left, cost.left);
    expect(find.byKey(const Key('sparkline')), findsOneWidget);
  });

  testWidgets('a wider window keeps every page in one centred container; the bar and the rail stay the window\'s', (tester) async {
    // Owner, 2026-10-30: 「for wider screen user, make sure have a container to limit the size of it」.
    const size = Size(2560, 1200);
    await pumpAdmin(tester, size: size);
    final margin = WindowClass.large.margin;
    // The main list runs from the rail to the panel, the room beyond the container included.
    final area = tester.getRect(find.byKey(const Key('page-main')));
    final hero = tester.getRect(find.byKey(const Key('hero')));
    final aside = tester.getRect(find.byKey(const Key('aside')));
    final left = hero.left - margin;
    final right = aside.right + margin;
    expect(right - left, pageMax);
    // Centred in what the rail leaves: as much room beyond it at each side. The rail is at the window's edge.
    expect(left - area.left, greaterThan(0));
    expect(left - area.left, closeTo(size.width - right, 0.5));
    expect(tester.getRect(find.byType(NavigationRail)).left, 0);
    // The panel is a card of its own, level with the column's top (its page header).
    expect(aside.top, area.top + Space.xl);

    // A page without a panel keeps the same left edge.
    await go(tester, '活跃');
    final title = tester.getRect(find.descendant(of: find.byKey(const Key('page-活跃')), matching: find.text('活跃')));
    expect(title.left, hero.left);

    // So does an account's page, which has no rail: the container centred in the window.
    await go(tester, '用户');
    await tester.tap(find.byKey(const Key('user-u-02')));
    await tester.pumpAndSettle();
    final balance = tester.getRect(find.byKey(const Key('hero')));
    final panel = tester.getRect(find.byKey(const Key('aside')));
    expect(panel.right + margin - (balance.left - margin), pageMax);
    expect(balance.left - margin, closeTo(size.width - (panel.right + margin), 0.5));
  });

  testWidgets('the panel scrolls on its own: the main column moves, the panel stays, and the other way round', (tester) async {
    await pumpAdmin(tester, size: const Size(1440, 700));
    final panelRow = find.byKey(const Key('panel-accounts'));
    final before = tester.getTopLeft(panelRow);
    final heroBefore = tester.getTopLeft(find.byKey(const Key('hero')));
    await tester.drag(mainList, const Offset(0, -240));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(panelRow), before);
    expect(tester.getTopLeft(find.byKey(const Key('hero'))).dy, lessThan(heroBefore.dy));
    final asideList = find.descendant(of: find.byKey(const Key('aside')), matching: find.byType(Scrollable)).first;
    final heroNow = tester.getTopLeft(find.byKey(const Key('hero')));
    await tester.drag(asideList, const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(panelRow).dy, lessThan(before.dy));
    expect(tester.getTopLeft(find.byKey(const Key('hero'))), heroNow);
  });

  testWidgets('narrower: the panel follows the main column, in the same column', (tester) async {
    await pumpAdmin(tester, size: const Size(1024, 900));
    final hero = tester.getRect(find.byKey(const Key('hero')));
    await scrollToIt(tester, find.byKey(const Key('aside')));
    final aside = tester.getRect(find.byKey(const Key('aside')));
    expect(aside.left, hero.left);
    expect(aside.width, hero.width);
    expect(find.byKey(const Key('panel-accounts')), findsOneWidget);
  });

  testWidgets('用户: the search and filters in the panel; on a phone before the table', (tester) async {
    await pumpAdmin(tester, size: const Size(1440, 900));
    await go(tester, '用户');
    final aside = tester.getRect(find.byKey(const Key('aside')));
    expect(tester.getRect(find.byKey(const Key('users-search'))).left, greaterThan(aside.left));
    expect(tester.getRect(find.byKey(const Key('filter-demo'))).left, greaterThan(aside.left));
    expect(tester.getRect(find.byKey(const ValueKey<String>('grid-用户'))).right, lessThan(aside.left));

    // A phone's width, tall enough that the panel and the table are both laid out.
    await tester.pumpWidget(const SizedBox());
    await pumpAdmin(tester, size: Size(phone.width, 2400));
    await go(tester, '用户');
    final panel = tester.getRect(find.byKey(const Key('aside')));
    expect(tester.getRect(find.byKey(const Key('filter-demo'))).bottom, lessThan(panel.bottom));
    expect(tester.getRect(find.byKey(const ValueKey<String>('grid-用户'))).top, greaterThan(panel.bottom));
  });

  testWidgets('an account: 积分余额 leads; the actions in the panel at the right, near the top on a phone', (tester) async {
    await pumpAdmin(tester, size: const Size(1440, 1000));
    await go(tester, '用户');
    await tester.tap(find.byKey(const Key('user-u-02')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('account-balance')), findsOneWidget);
    final aside = tester.getRect(find.byKey(const Key('aside')));
    for (final key in ['switch-suspended', 'switch-ai', 'grant-points', 'grant-submit']) {
      expect(tester.getRect(find.byKey(Key(key))).left, greaterThanOrEqualTo(aside.left), reason: key);
    }
    expect(tester.getRect(find.byKey(const Key('hero'))).right, lessThan(aside.left));
  });

  testWidgets('from the keyboard: Tab reaches who is online in the panel, Enter opens the account', (tester) async {
    await pumpAdmin(tester, size: const Size(1440, 900));
    final stops = await tabStops(tester);
    expect(stops, containsAllInOrder(['period', 'online-admin-1']));
    await tabTo(tester, 'online-u-01');
    await press(tester, LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('account-balance')), findsOneWidget);
    await press(tester, LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('hero')), findsOneWidget);
  });
}
