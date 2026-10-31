import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_app/presentation/widgets/elastic_switch.dart';

import '../../app/test/keys.dart';
import 'support.dart';

// The 管理后台's roles (tech plan S25 WP25.3; the owner: admin具备超级权限，manager可以进行权限分配，但是不能对用户的数据进行操作。
// integrator可以进入后台面板，但是只能对邮件和短信系统进行操作): what each role sees and may do. The server decides
// (src/admin/roles.ts, and FakeAdmin as it does); the dashboard leaves out what it would refuse.

const tall = Size(1440, 1800);

List<String> railLabels(WidgetTester tester) => [
      for (final d in tester.widget<NavigationRail>(find.byType(NavigationRail)).destinations) (d.label as Text).data!,
    ];

AppSwitchTile switchOf(WidgetTester tester, String key) => tester.widget<AppSwitchTile>(find.byKey(Key(key)));

Future<void> openAccount(WidgetTester tester, String id, {String? search}) async {
  await go(tester, '用户');
  if (search != null) {
    await tester.enterText(find.byKey(const Key('users-search')), search);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
  }
  await tapOn(tester, 'user-$id');
}

void main() {
  testWidgets('an admin: every page, 消息 last', (tester) async {
    await pumpAdmin(tester);
    expect(railLabels(tester), ['概览', '用户', '活跃', '收益', '用量', '导出', '消息']);
    expect(find.text('boss · 管理员'), findsOneWidget);
  });

  testWidgets('an integrator: 消息 alone, without a rail or a bar; nothing else asked for', (tester) async {
    final f = FakeAdmin()..role = 'integrator';
    await pumpAdmin(tester, fake: f, size: tall);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byKey(const Key('message-code_mail')), findsOneWidget);
    expect(find.text('integ · 集成人员'), findsOneWidget);
    expect(f.to('/v1/admin/overview'), isEmpty);
    expect(f.to('/v1/admin/users'), isEmpty);

    // On a phone too.
    await tester.pumpWidget(const SizedBox());
    await pumpAdmin(tester, fake: f, size: phone);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byKey(const Key('message-code_mail')), findsOneWidget);
  });

  testWidgets('a manager: the numbers and the accounts; no 导出, no 消息, no CSV beside the curve', (tester) async {
    final f = FakeAdmin()..role = 'manager';
    await pumpAdmin(tester, fake: f, size: tall);
    expect(railLabels(tester), ['概览', '用户', '活跃', '收益', '用量']);
    expect(find.text('mgr · 经理'), findsOneWidget);
    await go(tester, '收益');
    expect(find.byKey(const Key('export-png')), findsOneWidget);
    expect(find.byKey(const Key('export-series-csv')), findsNothing);
  });

  testWidgets('a manager on an account: its permissions and its role, not its 积分 or its sessions', (tester) async {
    final f = FakeAdmin()..role = 'manager';
    await pumpAdmin(tester, fake: f, size: tall);
    await openAccount(tester, 'u-02');
    expect(find.byKey(const Key('grant-points')), findsNothing);
    expect(find.byKey(const Key('sign-out-everywhere')), findsNothing);
    // Ctrl+Enter, 增加积分 for an admin, does nothing.
    await press(tester, LogicalKeyboardKey.enter, control: true);
    await tester.pumpAndSettle();
    expect(f.to('/v1/admin/users/u-02/points', method: 'POST'), isEmpty);

    // The roles a manager may give: all but 管理员.
    await tapOn(tester, 'role');
    expect(find.byKey(const Key('role-user')), findsOneWidget);
    expect(find.byKey(const Key('role-integrator')), findsOneWidget);
    expect(find.byKey(const Key('role-admin')), findsNothing);
    await tapOn(tester, 'role-manager');
    expect(find.text('设 user02 为经理？'), findsOneWidget);
    await tapOn(tester, 'confirm-yes');
    expect(f.bodyOf(f.last('/v1/admin/users/u-02', method: 'PATCH')), {'role': 'manager'});
    expect(textOf(tester, 'role-now'), '经理');
    expect(textOf(tester, 'role-about'), '查看数据，给账户分配角色和权限；不能增加积分、让账户退出登录或导出数据');
    await tapOn(tester, 'switch-ai');
    expect(f.bodyOf(f.last('/v1/admin/users/u-02', method: 'PATCH')), {
      'permissions': {'ai': false},
    });
  });

  testWidgets('a manager on an admin\'s account: nothing to change, and why', (tester) async {
    final f = FakeAdmin()..role = 'manager';
    await pumpAdmin(tester, fake: f, size: tall);
    await openAccount(tester, 'admin-1', search: 'boss');
    expect(textOf(tester, 'locked-note'), '只有管理员可以修改管理员的账户');
    for (final key in ['switch-suspended', 'switch-ai', 'switch-topup']) {
      expect(switchOf(tester, key).onChanged, isNull, reason: key);
    }
    expect(tester.widget<PopupMenuButton<String>>(find.byKey(const Key('role'))).enabled, isFalse);
    expect(f.to('/v1/admin/users/admin-1', method: 'PATCH'), isEmpty);
  });

  testWidgets('a role changed mid-session: the refusal says so, and the pages follow the new role', (tester) async {
    final f = await pumpAdmin(tester);
    await go(tester, '导出');
    // Another admin made boss a manager.
    f.role = 'manager';
    await tester.tap(find.byKey(const Key('export-pdf')));
    await tester.pumpAndSettle();
    expect(find.text('你的角色不能做这件事'), findsOneWidget);
    expect(f.to('/v1/admin/me'), hasLength(2));
    expect(railLabels(tester), ['概览', '用户', '活跃', '收益', '用量']);
    // 导出 is gone: the first page the role has.
    expect(find.byKey(const Key('page-概览')), findsOneWidget);
    expect(find.text('mgr · 经理'), findsOneWidget);
  });
}
