import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_app/application/providers.dart';
import 'package:mingli_app/data/settings_store.dart';

import 'support.dart';

/// Storage that can't be read, as in a private window or without a secure context.
class _BrokenStore implements SettingsStore {
  @override
  Future<String?> language() => Future.error(StateError('no storage'));
  @override
  Future<void> setLanguage(String apiLocale) => Future.error(StateError('no storage'));
}

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

  // The Phase 3 gate's 「英语扩展：全量页面英语资源覆盖」 (v5.2.0): every string exists in all three languages,
  // and English shows Chinese only where it means to (the 体 / 用 / 互 / 变 hexagram roles, the surname example).
  test('every page is in English: the three languages have the same strings', () {
    Map<String, dynamic> arb(String f) => jsonDecode(File('lib/l10n/$f').readAsStringSync()) as Map<String, dynamic>;
    Set<String> keys(Map<String, dynamic> m) => m.keys.where((k) => !k.startsWith('@')).toSet();
    final en = arb('app_en.arb'), hans = arb('app_zh.arb'), hant = arb('app_zh_Hant.arb');
    expect(keys(en).length, greaterThan(400));
    expect(keys(hans), keys(en));
    expect(keys(hant), keys(en));
    final cjk = RegExp(r'[㐀-鿿]');
    final chineseInEnglish = keys(en).where((k) => cjk.hasMatch('${en[k]}')).toSet();
    expect(chineseInEnglish, {'lifeTi', 'lifeYong', 'lifeHu', 'lifeBian', 'namingSurnameHint'});
  });

  // v5.1.0 (tech plan WP8.3): a picked language is kept on the device for the next start.
  testWidgets('a picked language is kept, and the next start opens in it', (tester) async {
    final store = InMemorySettingsStore();
    final api = FakeApi(email: 'test@mingli.local');
    await tester.pumpWidget(testApp(api, locale: null, settings: store));
    await settle(tester);
    expect(find.text('八字排盘'), findsWidgets);
    await tester.tap(find.byKey(const Key('language-menu')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('language-en')));
    await settle(tester);
    expect(store.saved, 'en');

    // A restart: main() reads the saved language before the first frame.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(testApp(api, locale: await startLocale(store), settings: store));
    await settle(tester);
    expect(find.text('Bazi chart'), findsWidgets);
    expect(find.text('八字排盘'), findsNothing);
    expect(tester.widget<Text>(find.byKey(const Key('language-current'))).data, 'EN');
  });

  testWidgets('without a saved language, or without storage, the app starts in 简体中文', (tester) async {
    expect(await startLocale(InMemorySettingsStore()), zhHans);
    expect(await startLocale(_BrokenStore()), zhHans);
    expect(await startLocale(InMemorySettingsStore()..saved = 'zh-Hant'), zhHant);
    // Picking a language where it can't be saved still switches it.
    await tester.pumpWidget(testApp(FakeApi(email: 'test@mingli.local'), locale: null, settings: _BrokenStore()));
    await settle(tester);
    await tester.tap(find.byKey(const Key('language-menu')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('language-zh-Hant')));
    await settle(tester);
    expect(tester.widget<Text>(find.byKey(const Key('language-current'))).data, '繁');
  });
}
