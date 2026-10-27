import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_app/application/providers.dart';

import 'support.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('the app starts in 简体中文, listed first in the language menu', (tester) async {
    await tester.pumpWidget(testApp(FakeApi(email: 'test@mingli.local'), locale: null));
    await settle(tester);
    expect(find.text('八字排盘'), findsWidgets);
    expect(find.text('你好，测试用户'), findsOneWidget);
    expect(supportedAppLocales.first, zhHans);

    await tester.tap(find.byKey(const Key('language-menu')));
    await settle(tester);
    final labels = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).whereType<String>().toList();
    expect(labels.indexOf('简体中文'), lessThan(labels.indexOf('繁體中文')));
  });

  test('简体 copy uses Mainland wording and punctuation', () {
    final arb = jsonDecode(File('lib/l10n/app_zh.arb').readAsStringSync()) as Map<String, dynamic>;
    final strings = arb.entries.where((e) => !e.key.startsWith('@')).map((e) => '${e.value}').join('\n');
    // HK/TW forms that a character-by-character conversion leaves behind.
    for (final hkTw in ['「', '」', '账户', '电子邮件', '点选', '示范', '转工作', '连不上', '民用时', '新增资料', '建立资料']) {
      expect(strings.contains(hkTw), isFalse, reason: 'found $hkTw');
    }
    expect(arb['email'], '邮箱');
    expect(arb['account'], '账号');
    expect(arb['deleteAccount'], '注销账号并删除数据');
  });
}
