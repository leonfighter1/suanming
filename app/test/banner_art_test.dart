// The banners' art (owner, 2026-10-30: 「Update the banner background using this … luopan.svg for all pages」): every
// banner stands on 命理罗盘 (assets/art/luopan.webp, made by `npm run mirror:banner`), and its words, on the art's own
// night, are the same light text in either theme.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_app/presentation/design.dart';
import 'package:mingli_app/presentation/theme.dart';
import 'package:mingli_app/presentation/tokens.dart';

import 'keys.dart';
import 'support.dart';

/// The art under the banner on screen.
ImageProvider? artOf(WidgetTester tester) {
  final box = tester.widget<Container>(find.descendant(of: find.byType(HeroBanner), matching: find.byType(Container)).first);
  return (box.decoration! as BoxDecoration).image?.image;
}

void main() {
  testWidgets('the introduction and sign-in pages stand on 命理罗盘', (tester) async {
    await tester.pumpWidget(testApp(FakeApi(), signedIn: false));
    await frames(tester, 12);
    expect(artOf(tester), bannerArt, reason: 'the introduction page');
    await openSignIn(tester);
    expect(artOf(tester), bannerArt);
  });

  for (final method in ['tarot', 'qiuqian', 'liuyao', 'fengshui']) {
    testWidgets('首页 and $method stand on 命理罗盘', (tester) async {
      await tester.pumpWidget(testApp(FakeApi()));
      await frames(tester, 12);
      expect(artOf(tester), bannerArt, reason: '首页');
      await openEntry(tester, method);
      await frames(tester, 12);
      expect(find.byType(HeroBanner), findsOneWidget);
      expect(artOf(tester), bannerArt);
    });
  }

  testWidgets("八字's day pillar on the art takes the dark theme's 五行 colours, in the light theme too", (tester) async {
    await tester.pumpWidget(testApp(FakeApi()));
    await frames(tester, 10);
    await openBaziChart(tester);
    expect(artOf(tester), bannerArt);
    final pillar = find.descendant(of: find.byType(HeroBanner), matching: find.byType(GanZhiText));
    final colours = <String, Color?>{};
    tester.widget<RichText>(find.descendant(of: pillar, matching: find.byType(RichText))).text.visitChildren((span) {
      if (span is TextSpan && span.text != null) colours[span.text!] = span.style?.color;
      return true;
    });
    expect(colours.keys.join(), '己卯');
    for (final MapEntry(key: ch, value: colour) in colours.entries) {
      expect(colour, wuxingColor(ch, dark: true), reason: ch);
    }
  });

  testWidgets("its words are the dark theme's text in either theme: the art is night in both", (tester) async {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      await tester.pumpWidget(testApp(FakeApi(), theme: mode));
      await frames(tester, 12);
      final title = tester.widget<Text>(find.descendant(of: find.byType(HeroBanner), matching: find.byType(Text)).first);
      expect(title.style?.color, ThemeTokens.dark.text, reason: mode.name);
    }
  });
}
