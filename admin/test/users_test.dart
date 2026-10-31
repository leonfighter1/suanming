import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_app/presentation/buttons.dart';

import '../../app/test/keys.dart';
import 'support.dart';

// 用户 and each account's page (管理后台, tech plan S22): the list's search, filters, sorting and pages; suspending,
// the admin role, permissions, 增加积分 and signing out everywhere.

const tall = Size(1280, 1800);

Map<String, String> lastQuery(FakeAdmin f) => f.last('/v1/admin/users').url.queryParameters;

Future<void> tapOn(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> openUser(WidgetTester tester, String id, {String? search}) async {
  if (find.byKey(const Key('users-search')).evaluate().isEmpty) await go(tester, '用户');
  if (search != null) {
    await tester.enterText(find.byKey(const Key('users-search')), search);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
  }
  await tapOn(tester, 'user-$id');
}

SwitchListTile switchOf(WidgetTester tester, String key) => tester.widget<SwitchListTile>(find.byKey(Key(key)));

Finder inTable(String text) => find.descendant(of: find.byType(DataTable), matching: find.text(text));

void main() {
  testWidgets('用户 lists every account, 25 to a page, with what sets each apart', (tester) async {
    final f = await pumpAdmin(tester);
    await go(tester, '用户');
    expect(find.text('共 30 个账户（全部时间的数字）'), findsOneWidget);
    expect(textOf(tester, 'users-page'), '第 1 / 2 页 · 共 30 个');
    expect(lastQuery(f), {'demo': 'include', 'sort': 'created', 'order': 'desc', 'page': '1', 'per_page': '25'});
    // The newest first.
    expect(find.byKey(const Key('user-u-01')), findsOneWidget);
    expect(find.byKey(const Key('user-root-1')), findsNothing);
    expect(inTable('已停用'), findsOneWidget);
    expect(inTable('AI 已关'), findsOneWidget);
    expect(inTable('演示'), findsNWidgets(23));
    expect(find.byKey(const Key('page-prev')), findsOneWidget);
    expect(tester.widget<AppIconButton>(find.byKey(const Key('page-prev'))).onPressed, isNull);

    await tapOn(tester, 'page-next');
    expect(lastQuery(f)['page'], '2');
    expect(textOf(tester, 'users-page'), '第 2 / 2 页 · 共 30 个');
    expect(find.byKey(const Key('user-root-1')), findsOneWidget);
    expect(inTable('管理员（服务器指定）'), findsOneWidget);
    expect(tester.widget<AppIconButton>(find.byKey(const Key('page-next'))).onPressed, isNull);
  });

  testWidgets('the search waits for a pause in the typing; Enter searches at once', (tester) async {
    final f = await pumpAdmin(tester);
    await go(tester, '用户');
    final before = f.to('/v1/admin/users').length;
    await tester.enterText(find.byKey(const Key('users-search')), 'user1');
    await tester.pump(const Duration(milliseconds: 100));
    expect(f.to('/v1/admin/users').length, before);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(lastQuery(f)['q'], 'user1');
    expect(textOf(tester, 'users-page'), '第 1 / 1 页 · 共 10 个');

    await tester.enterText(find.byKey(const Key('users-search')), '');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(lastQuery(f).containsKey('q'), isFalse);
    expect(textOf(tester, 'users-page'), '第 1 / 2 页 · 共 30 个');
  });

  testWidgets('the filters and the sorting go to the server; a new column starts with the largest', (tester) async {
    final f = await pumpAdmin(tester);
    await go(tester, '用户');
    Future<void> pick(String filter, String label) async {
      await tester.tap(find.descendant(of: find.byKey(Key(filter)), matching: find.text(label)));
      await tester.pumpAndSettle();
    }

    await pick('filter-status', '已停用');
    expect(lastQuery(f)['status'], 'suspended');
    expect(textOf(tester, 'users-page'), '第 1 / 1 页 · 共 1 个');
    await pick('filter-status', '全部状态');
    expect(lastQuery(f).containsKey('status'), isFalse);
    await pick('filter-role', '管理员');
    expect(lastQuery(f)['role'], 'admin');
    expect(textOf(tester, 'users-page'), '第 1 / 1 页 · 共 2 个');
    await pick('filter-role', '全部角色');
    await pick('filter-demo', '不含演示');
    expect(lastQuery(f)['demo'], 'exclude');
    expect(textOf(tester, 'users-page'), '第 1 / 1 页 · 共 4 个');
    await pick('filter-demo', '含演示');

    await tester.tap(find.text('积分余额'));
    await tester.pumpAndSettle();
    expect(lastQuery(f), containsPair('sort', 'balance'));
    expect(lastQuery(f), containsPair('order', 'desc'));
    expect(find.byKey(const Key('user-u-28')), findsOneWidget);
    expect(find.byKey(const Key('user-u-01')), findsNothing);
    await tester.tap(find.text('积分余额'));
    await tester.pumpAndSettle();
    expect(lastQuery(f), containsPair('order', 'asc'));
    expect(find.byKey(const Key('user-u-01')), findsOneWidget);
    expect(find.byKey(const Key('user-u-28')), findsNothing);
    // Another column: the largest first again.
    await tester.tap(find.text('AI 次数'));
    await tester.pumpAndSettle();
    expect(lastQuery(f), containsPair('sort', 'jobs'));
    expect(lastQuery(f), containsPair('order', 'desc'));
  });

  testWidgets('an account\'s page: its numbers, its 积分 ledger and AI jobs; Esc goes back', (tester) async {
    await pumpAdmin(tester, size: tall);
    await openUser(tester, 'u-02');
    expect(find.text('u-02'), findsOneWidget);
    expect(textOf(tester, 'account-balance'), '200');
    expect(find.text('充值 10 元'), findsOneWidget);
    expect(find.text('管理员赠送'), findsOneWidget);
    expect(find.text('活动奖励'), findsOneWidget);
    expect(find.text('-688'), findsOneWidget);
    expect(find.text('+1,000'), findsOneWidget);
    // The ledger's charge, the job and the by-method row.
    expect(find.text('八字 AI 解读'), findsNWidgets(3));
    expect(find.text('claude-opus-5-5'), findsOneWidget);
    expect(find.text('已完成'), findsOneWidget);
    await press(tester, LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('users-search')), findsOneWidget);
  });

  testWidgets('suspending asks first, restoring doesn\'t; AI and 充值 switch at once', (tester) async {
    final f = await pumpAdmin(tester, size: tall);
    await openUser(tester, 'u-02');
    const path = '/v1/admin/users/u-02';
    await tapOn(tester, 'switch-suspended');
    expect(find.text('停用 user02？'), findsOneWidget);
    await tapOn(tester, 'confirm-no');
    expect(f.to(path, method: 'PATCH'), isEmpty);
    expect(switchOf(tester, 'switch-suspended').value, isFalse);

    await tapOn(tester, 'switch-suspended');
    await tapOn(tester, 'confirm-yes');
    expect(f.bodyOf(f.last(path, method: 'PATCH')), {'status': 'suspended'});
    expect(find.text('已停用 user02'), findsOneWidget);
    expect(switchOf(tester, 'switch-suspended').value, isTrue);

    await tapOn(tester, 'switch-suspended');
    expect(find.byType(AlertDialog), findsNothing);
    expect(f.bodyOf(f.last(path, method: 'PATCH')), {'status': 'active'});

    await tapOn(tester, 'switch-ai');
    expect(f.bodyOf(f.last(path, method: 'PATCH')), {
      'permissions': {'ai': false},
    });
    await tapOn(tester, 'switch-topup');
    expect(f.bodyOf(f.last(path, method: 'PATCH')), {
      'permissions': {'top_up': false},
    });
    expect(switchOf(tester, 'switch-topup').value, isFalse);
    // The list shows it too.
    await press(tester, LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(inTable('AI 已关'), findsNWidgets(2));
    expect(inTable('充值已关'), findsOneWidget);
  });

  testWidgets('the role (S25): asked first; not for the server\'s own admins; never on oneself', (tester) async {
    final f = await pumpAdmin(tester, size: tall);
    await openUser(tester, 'u-01');
    expect(textOf(tester, 'role-now'), '普通用户');
    await tapOn(tester, 'role');
    // An admin may give every role.
    for (final r in ['user', 'integrator', 'manager', 'admin']) {
      expect(find.byKey(ValueKey<String>('role-$r')), findsOneWidget, reason: r);
    }
    await tapOn(tester, 'role-admin');
    expect(find.text('设 user01 为管理员？'), findsOneWidget);
    await tapOn(tester, 'confirm-yes');
    expect(f.bodyOf(f.last('/v1/admin/users/u-01', method: 'PATCH')), {'role': 'admin'});
    expect(textOf(tester, 'role-now'), '管理员');
    expect(find.text('user01 已是管理员'), findsOneWidget);
    // Back to 普通用户: asked too, and the account leaves the dashboard.
    await tapOn(tester, 'role');
    await tapOn(tester, 'role-user');
    expect(find.text('取消 user01 的后台角色？'), findsOneWidget);
    await tapOn(tester, 'confirm-no');
    expect(f.to('/v1/admin/users/u-01', method: 'PATCH'), hasLength(1));
    await press(tester, LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    await openUser(tester, 'root-1', search: 'root');
    expect(tester.widget<PopupMenuButton<String>>(find.byKey(const Key('role'))).enabled, isFalse);
    expect(find.text('由服务器设置（MINGLI_ADMINS）指定，不能在这里改'), findsOneWidget);
    await press(tester, LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    await openUser(tester, 'admin-1', search: 'boss');
    expect(tester.widget<PopupMenuButton<String>>(find.byKey(const Key('role'))).enabled, isFalse);
    expect(switchOf(tester, 'switch-suspended').onChanged, isNull);
    expect(find.text('不能停用自己'), findsOneWidget);
    expect(find.text('不能改自己的角色'), findsOneWidget);
  });

  testWidgets('增加积分: a number and a note, asked first; a bad number goes nowhere; Ctrl+Enter, Esc', (tester) async {
    final f = await pumpAdmin(tester, size: tall);
    await openUser(tester, 'u-02');
    const path = '/v1/admin/users/u-02/points';
    await tester.enterText(find.byKey(const Key('grant-points')), '0');
    await tapOn(tester, 'grant-submit');
    expect(find.text('积分请填 1 到 1,000,000 之间的整数'), findsOneWidget);
    expect(f.to(path, method: 'POST'), isEmpty);

    await tapOn(tester, 'grant-1000');
    await tester.enterText(find.byKey(const Key('grant-note')), '补偿');
    await tapOn(tester, 'grant-submit');
    expect(find.text('给 user02 增加 1,000 积分？'), findsOneWidget);
    expect(find.text('备注：补偿'), findsOneWidget);
    await tapOn(tester, 'confirm-yes');
    expect(f.bodyOf(f.last(path, method: 'POST')), {'points': 1000, 'note': '补偿'});
    expect(find.text('已增加 1,000 积分，余额 1,200'), findsOneWidget);
    expect(textOf(tester, 'account-balance'), '1,200');
    expect(tester.widget<TextField>(find.byKey(const Key('grant-points'))).controller!.text, isEmpty);

    // Ctrl+Enter is the page's main button; Esc closes the question, and nothing is granted.
    await tester.enterText(find.byKey(const Key('grant-points')), '5');
    await press(tester, LogicalKeyboardKey.enter, control: true);
    await tester.pumpAndSettle();
    expect(find.text('给 user02 增加 5 积分？'), findsOneWidget);
    await press(tester, LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byKey(const Key('grant-points')), findsOneWidget);
    expect(f.to(path, method: 'POST'), hasLength(1));
  });

  testWidgets('在所有设备上退出 signs the account out everywhere', (tester) async {
    final f = await pumpAdmin(tester, size: tall);
    await openUser(tester, 'u-02');
    await tapOn(tester, 'sign-out-everywhere');
    expect(f.to('/v1/admin/users/u-02/sign-out', method: 'POST'), hasLength(1));
    expect(find.text('user02 已在所有设备上退出'), findsOneWidget);
  });

  testWidgets('the server\'s refusal shows as a message', (tester) async {
    final f = await pumpAdmin(tester, size: tall);
    await openUser(tester, 'u-02');
    f.failPaths.add('/v1/admin/users/u-02');
    await tapOn(tester, 'switch-ai');
    expect(find.text('服务器出错了'), findsOneWidget);
  });
}
