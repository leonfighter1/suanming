import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_app/application/providers.dart';

import 'support.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

String current(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('language-current'))).data!;

void main() {
  testWidgets('the home bar shows 个人资料, 语言 and a 设置 gear, no ⋮ menu', (tester) async {
    await tester.pumpWidget(testApp(FakeApi(email: 'test@mingli.local'), locale: zhHans));
    await settle(tester);
    final bar = find.byType(AppBar);
    expect(find.descendant(of: bar, matching: find.byIcon(Icons.more_vert)), findsNothing);
    expect(find.descendant(of: bar, matching: find.byIcon(Icons.settings_outlined)), findsOneWidget);
    for (final tip in ['历史记录', '个人资料', '语言', '设置']) {
      expect(find.descendant(of: bar, matching: find.byTooltip(tip)), findsOneWidget, reason: tip);
    }

    // 个人资料: one tap, no menu in between.
    await tester.tap(find.byKey(const Key('open-profiles')));
    await settle(tester);
    expect(find.widgetWithText(AppBar, '个人资料'), findsOneWidget);
  });

  testWidgets('语言 on the bar shows the current language and switches in one tap', (tester) async {
    await tester.pumpWidget(testApp(FakeApi(email: 'test@mingli.local'), locale: zhHans));
    await settle(tester);
    expect(current(tester), '简');

    await tester.tap(find.byKey(const Key('language-menu')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('language-en')));
    await settle(tester);
    expect(current(tester), 'EN');
    expect(find.descendant(of: find.byKey(const Key('entry-bazi')), matching: find.text('Bazi chart')), findsOneWidget);
    expect(find.byTooltip('Settings'), findsOneWidget);
  });

  testWidgets('signed out, the sign-in bar has 语言 too', (tester) async {
    await tester.pumpWidget(testApp(FakeApi(), signedIn: false, locale: zhHans));
    await settle(tester);
    final submit = find.byKey(const Key('auth-submit'));
    expect(find.descendant(of: submit, matching: find.text('登录')), findsOneWidget);

    await tester.tap(find.byKey(const Key('language-menu')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('language-zh-Hant')));
    await settle(tester);
    expect(current(tester), '繁');
    expect(find.descendant(of: submit, matching: find.text('登入')), findsOneWidget);
  });

  for (final locale in supportedAppLocales) {
    testWidgets('the bar fits a 360-wide phone (${apiLocale(locale)})', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(testApp(FakeApi(email: 'test@mingli.local'), locale: locale));
      await settle(tester);
      for (final key in ['open-history', 'open-profiles', 'language-menu', 'open-settings']) {
        final r = tester.getRect(find.byKey(Key(key)));
        expect(r.left >= 0 && r.right <= 360, isTrue, reason: '$key at $r');
      }
      // The Chinese titles stay whole. (The test font is wider than real Latin
      // fonts, so the English title may be shortened with … here.)
      if (locale.languageCode == 'zh') {
        final name = locale.scriptCode == 'Hans' ? '命理大师' : '命理大師';
        final title = tester.renderObject<RenderParagraph>(find.descendant(of: find.byType(AppBar), matching: find.text(name)));
        expect(title.getMaxIntrinsicWidth(double.infinity), lessThanOrEqualTo(title.size.width + 0.5));
      }
    });
  }
}
