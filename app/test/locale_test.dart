import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_app/application/providers.dart';
import 'package:mingli_app/data/settings_store.dart';

import 'keys.dart';
import 'support.dart';

void main() {
  testWidgets('the app starts in 简体中文, listed first in the language menu', (tester) async {
    await tester.pumpWidget(testApp(FakeApi(email: 'test@mingli.local'), locale: null));
    await frames(tester, 12);
    expect(find.text('八字排盘'), findsWidgets);
    expect(find.text('你好，测试用户'), findsOneWidget);
    expect(supportedAppLocales.first, zhHans);

    await openFromMenu(tester, 'language-menu');
    await frames(tester, 12);
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

  // The owner removed English (v5.4.0): 简体 is the template, 繁體 has every one of its strings, and there is no
  // English file or locale left.
  test('the app is in Chinese only: 简体 and 繁體 have the same strings, and no English', () {
    Map<String, dynamic> arb(String f) => jsonDecode(File('lib/l10n/$f').readAsStringSync()) as Map<String, dynamic>;
    Set<String> keys(Map<String, dynamic> m) => m.keys.where((k) => !k.startsWith('@')).toSet();
    final hans = arb('app_zh.arb'), hant = arb('app_zh_Hant.arb');
    expect(keys(hans).length, greaterThan(400));
    expect(keys(hant), keys(hans));
    expect(File('lib/l10n/app_en.arb').existsSync(), isFalse);
    expect(supportedAppLocales, [zhHans, zhHant]);
  });

  // v5.1.0 (tech plan WP8.3): a picked language is kept on the device for the next start.
  testWidgets('a picked language is kept, and the next start opens in it', (tester) async {
    final store = InMemorySettingsStore();
    final api = FakeApi(email: 'test@mingli.local');
    await tester.pumpWidget(testApp(api, locale: null, settings: store));
    await frames(tester, 12);
    expect(find.text('八字排盘'), findsWidgets);
    await openFromMenu(tester, 'language-menu');
    await frames(tester, 12);
    await tester.tap(find.byKey(const Key('language-zh-Hant')));
    await frames(tester, 12);
    expect(store.saved, 'zh-Hant');

    // A restart: main() reads the saved language before the first frame.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(testApp(api, locale: await startLocale(store), settings: store));
    await frames(tester, 12);
    expect(find.text('八字排盤'), findsWidgets);
    expect(find.text('八字排盘'), findsNothing);
    // The ☰ menu (v8.1.0) shows the language it started in.
    await tester.tap(find.byKey(const Key('open-menu')));
    await frames(tester, 12);
    expect(tester.widget<Text>(find.byKey(const Key('language-current'))).data, '繁體中文');
  });

  testWidgets('without a saved language, or without storage, the app starts in 简体中文', (tester) async {
    expect(await startLocale(InMemorySettingsStore()), zhHans);
    expect(await startLocale(BrokenSettingsStore()), zhHans);
    expect(await startLocale(InMemorySettingsStore()..saved = 'zh-Hant'), zhHant);
    // English saved before the owner removed it starts in 简体.
    expect(await startLocale(InMemorySettingsStore()..saved = 'en'), zhHans);
    // Picking a language where it can't be saved still switches it.
    await tester.pumpWidget(testApp(FakeApi(email: 'test@mingli.local'), locale: null, settings: BrokenSettingsStore()));
    await frames(tester, 12);
    await openFromMenu(tester, 'language-menu');
    await frames(tester, 12);
    await tester.tap(find.byKey(const Key('language-zh-Hant')));
    await frames(tester, 12);
    expect(tester.widget<Text>(find.byKey(const Key('language-current'))).data, '繁體中文');
  });
}
