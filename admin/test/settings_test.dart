import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

// 设置 (tech plan S31; the owner: 「Move all the configurations into separate files, CMS controlling panel is able to read
// and adjust those values … switch the AI modal in the panel … turn on or off the Modal mocking. checkbox on different
// accepted currencies … Admin can choose the main displayed currencies for dashboard」). FakeAdmin answers as
// src/admin/settings.ts does.

const tall = Size(1440, 2000);

Future<FakeAdmin> openSettings(WidgetTester tester, {FakeAdmin? fake}) async {
  final f = await pumpAdmin(tester, fake: fake, size: tall);
  await go(tester, '设置');
  return f;
}

Finder inRow(String key, Finder f) => find.descendant(of: find.byKey(ValueKey<String>('setting-$key')), matching: f);

void main() {
  testWidgets('every setting by group, with its value, its default and what holds now', (tester) async {
    await openSettings(tester);
    for (final g in ['sessions', 'ai', 'currencies']) {
      expect(find.byKey(ValueKey<String>('group-$g')), findsOneWidget, reason: g);
    }
    expect(tester.widget<TextField>(find.byKey(const ValueKey<String>('setting-sessions.idle_days-field'))).controller!.text, '2');
    expect(inRow('sessions.idle_days', find.text('默认：2 天')), findsOneWidget);
    expect(inRow('ai.mock', find.text('默认：跟随 .env')), findsOneWidget);
    expect(textOf(tester, 'now-ai'), '模拟：示范回答，不花 token');
    expect(textOf(tester, 'now-rates'), '2026-10-29 的，每天更新');
  });

  testWidgets('a number kept with 保存; out of range, the server\'s words under it; 恢复默认 puts it back', (tester) async {
    final f = await openSettings(tester);
    await tester.enterText(find.byKey(const ValueKey<String>('setting-sessions.idle_days-field')), '0.5');
    await tester.pump();
    await tapOn(tester, 'setting-sessions.idle_days-save');
    expect(f.bodyOf(f.last('/v1/admin/settings/sessions.idle_days', method: 'PUT')), {'value': 0.5});
    expect(find.byKey(const ValueKey<String>('setting-sessions.idle_days-changed')), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey<String>('setting-sessions.idle_days-field')), '400');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(textOf(tester, 'setting-sessions.idle_days-refused'), '要在 0.01 到 365 之间');
    expect(f.settingValues['sessions.idle_days'], 0.5);

    await tapOn(tester, 'setting-sessions.idle_days-reset');
    expect(f.to('/v1/admin/settings/sessions.idle_days', method: 'DELETE'), hasLength(1));
    expect(find.byKey(const ValueKey<String>('setting-sessions.idle_days-changed')), findsNothing);
  });

  testWidgets('the AI mock: 关 asks first (real tokens); 开 and 跟随 .env don\'t', (tester) async {
    final f = await openSettings(tester);
    Finder segment(String label) => inRow('ai.mock', find.text(label));
    await tester.tap(segment('关'));
    await tester.pumpAndSettle();
    expect(find.text('关掉 AI 模拟？'), findsOneWidget);
    await tapOn(tester, 'confirm-no');
    expect(f.to('/v1/admin/settings/ai.mock', method: 'PUT'), isEmpty);

    await tester.tap(segment('关'));
    await tester.pumpAndSettle();
    await tapOn(tester, 'confirm-yes');
    expect(f.bodyOf(f.last('/v1/admin/settings/ai.mock', method: 'PUT')), {'value': false});

    await tester.tap(segment('开'));
    await tester.pumpAndSettle();
    expect(find.text('关掉 AI 模拟？'), findsNothing);
    expect(f.bodyOf(f.last('/v1/admin/settings/ai.mock', method: 'PUT')), {'value': true});

    await tester.tap(segment('跟随 .env'));
    await tester.pumpAndSettle();
    expect(f.to('/v1/admin/settings/ai.mock', method: 'DELETE'), hasLength(1));
    expect(f.settingValues.containsKey('ai.mock'), isFalse);
  });

  testWidgets('the accepted currencies as checkboxes: one more, one less; none is refused', (tester) async {
    final f = await openSettings(tester);
    await tapOn(tester, 'setting-currencies.accepted-TWD');
    expect(f.bodyOf(f.last('/v1/admin/settings/currencies.accepted', method: 'PUT')), {
      'value': ['CNY', 'HKD', 'TWD'],
    });
    await tapOn(tester, 'setting-currencies.accepted-CNY');
    expect(f.bodyOf(f.last('/v1/admin/settings/currencies.accepted', method: 'PUT')), {
      'value': ['HKD', 'TWD'],
    });
    f.settingValues['currencies.accepted'] = ['HKD'];
    await tapOn(tester, 'refresh');
    await tapOn(tester, 'setting-currencies.accepted-HKD');
    expect(textOf(tester, 'setting-currencies.accepted-refused'), '至少选一个');
  });

  testWidgets('the dashboard\'s currency: chosen here, the money follows it', (tester) async {
    final f = await openSettings(tester);
    await tapOn(tester, 'setting-currencies.dashboard-menu');
    await tester.tap(find.text('HKD').last);
    await tester.pumpAndSettle();
    expect(f.bodyOf(f.last('/v1/admin/settings/currencies.dashboard', method: 'PUT')), {'value': 'HKD'});
    expect(f.to('/v1/admin/me'), hasLength(2), reason: 'the session asked again, for its currency');

    await go(tester, '概览');
    expect(find.textContaining('HK\$'), findsWidgets);
    expect(find.textContaining('¥'), findsNothing);
  });

  testWidgets('a manager has no 设置', (tester) async {
    await pumpAdmin(tester, fake: FakeAdmin()..role = 'manager', size: tall);
    expect(find.text('设置'), findsNothing);
  });
}
