// 内容管理 (S29): what staff changed in the CMS shows in front of the app's own texts and images.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_app/application/providers.dart' show zhHans;
import 'package:mingli_app/domain/rich_text.dart';
import 'package:mingli_app/generated/content_rich.dart' show richWrittenColor;
import 'package:mingli_app/presentation/design.dart';
import 'package:mingli_app/presentation/keyboard.dart' show Pressable;
import 'package:mingli_app/presentation/tokens.dart';

import 'keys.dart';
import 'support.dart';

/// The art under the banner on screen.
ImageProvider? artOf(WidgetTester tester) {
  final box = tester.widget<Container>(find.descendant(of: find.byType(HeroBanner), matching: find.byType(Container)).first);
  return (box.decoration! as BoxDecoration).image?.image;
}

void main() {
  testWidgets('a text staff changed shows instead of the app\'s own; the others stay', (tester) async {
    final api = FakeApi()..content = (texts: const {'homeTarot': '塔罗占卜·新'}, images: const {});
    await tester.pumpWidget(testApp(api, locale: zhHans));
    await frames(tester, 12);
    await scrollTo(tester, const Key('entry-tarot'));
    expect(find.text('塔罗占卜·新'), findsOneWidget);
    expect(find.text('八字排盘'), findsWidgets, reason: 'unchanged texts are the app\'s own');
    expect(api.requests.where((r) => r.url.path == '/v1/content').single.url.queryParameters['locale'], 'zh-Hans');
  });

  testWidgets('a changed text keeps its placeholders, filled in', (tester) async {
    final api = FakeApi(email: 'test@mingli.local', pendingPolls: 0)
      ..pointsOn = true
      ..pointsBalance = 10000
      ..content = (texts: const {'pointsBalanceLine': '剩余 {balance} 积分'}, images: const {});
    await tester.pumpWidget(testApp(api, locale: zhHans));
    await frames(tester, 12);
    await tester.tap(find.byKey(const Key('open-menu')));
    await frames(tester, 12);
    await tester.tap(find.byKey(const Key('open-points')));
    await frames(tester, 12);
    expect(find.text('剩余 10000 积分'), findsWidgets);
  });

  // The test's network answers every image 400: one that can't load is no error, the banner keeps the sky's night.
  testWidgets('an image staff put in takes the banner\'s place, from the server', (tester) async {
    final api = FakeApi()..content = (texts: const {}, images: const {'banner': '/v1/content/images/banner?v=1'});
    await tester.pumpWidget(testApp(api));
    await frames(tester, 12);
    final art = artOf(tester);
    expect(art, isA<NetworkImage>());
    expect((art! as NetworkImage).url, endsWith('/v1/content/images/banner?v=1'));
  });

  // HTML and CSS (S33 WP33.4; the owner: 「同时可以让当前的改动支持HTML和CSS，不仅仅只是resource」).
  group('HTML and CSS', () {
    test('read tolerantly, and as words where a place takes words alone', () {
      expect(plainOf('<b>八字</b>排盘<br>看<span style="color: var(--accent)">命</span>'), '八字排盘\n看命');
      expect(plainOf('<ul><li>一</li><li>二</li></ul>后'), '• 一\n• 二\n后');
      expect(plainOf('&lt;b&gt; &amp; <p>段</p>'), '<b> & 段');
      expect(plainOf('<b>没有关上'), '没有关上');
      expect(plainOf('<marquee>不认识的</marquee>标签'), '不认识的标签');
      expect([hasMarkup('a < b'), hasMarkup('<b>x</b>'), hasMarkup('&amp;')], [false, true, true]);
    });

    /// [text]'s span inside the rich text that holds it.
    TextSpan spanOf(WidgetTester tester, String all, String text) {
      final rich = tester.widget<RichText>(find.text(all, findRichText: true).first);
      TextSpan? found;
      rich.text.visitChildren((s) {
        if (s is TextSpan && s.text == text) found = s;
        return found == null;
      });
      return found!;
    }

    testWidgets('a description staff wrote in HTML shows bold and in the theme\'s colour; a title keeps words', (tester) async {
      final api = FakeApi()
        ..content = (
          texts: const {
            'homeTarotDesc': '<b>抽牌</b>看<span style="color: var(--accent)">爱情</span>',
            // A title takes words alone (the server would refuse this): the tags never show.
            'homeTarot': '<b>塔罗</b>',
          },
          images: const {},
        );
      await tester.pumpWidget(testApp(api, locale: zhHans));
      await frames(tester, 12);
      await scrollTo(tester, const Key('entry-tarot'));
      final bold = spanOf(tester, '抽牌看爱情', '抽牌');
      expect(bold.style?.fontWeight, FontWeight.w700);
      final colour = spanOf(tester, '抽牌看爱情', '爱情');
      expect(colour.style?.color, ThemeTokens.of(tester.element(find.byKey(const Key('entry-tarot')))).accent);
      expect(find.text('塔罗'), findsWidgets);
      expect(find.textContaining('<b>'), findsNothing);
    });

    testWidgets('a colour written out shows as written (S34); a value the server refuses leaves the colour alone', (tester) async {
      final api = FakeApi()
        ..content = (
          texts: const {
            'homeBaziDesc': '<span style="color: #c0392b">红</span><span style="color: rgb(0, 128, 0)">绿</span>'
                '<span style="background-color: #FF0">黄</span><span style="color: red">原样</span>',
          },
          images: const {},
        );
      await tester.pumpWidget(testApp(api, locale: zhHans));
      await frames(tester, 12);
      await scrollTo(tester, const Key('entry-bazi'));
      const all = '红绿黄原样';
      expect(spanOf(tester, all, '红').style?.color, Color.fromARGB(255, 0xc0, 0x39, 0x2b));
      expect(spanOf(tester, all, '绿').style?.color, Color.fromARGB(255, 0, 128, 0));
      expect(spanOf(tester, all, '黄').style?.backgroundColor, Color.fromARGB(255, 255, 255, 0));
      expect(spanOf(tester, all, '原样').style?.color, isNot(Color.fromARGB(255, 255, 0, 0)));
      expect([richWrittenColor('rgb(256, 0, 0)'), richWrittenColor('#ff00'), richWrittenColor('#gg0000')], everyElement(isNull));
    });

    testWidgets('a link is a control of its own; off the web its address is copied, and a line says so', (tester) async {
      final clipboard = ClipboardWatch(tester);
      final api = FakeApi()
        ..content = (texts: const {'homeLiuyaoDesc': '摇卦，<a href="https://example.com/x">看说明</a>'}, images: const {});
      await tester.pumpWidget(testApp(api, locale: zhHans));
      await frames(tester, 12);
      await scrollTo(tester, const Key('entry-liuyao'));
      final link = find.descendant(of: find.byKey(const Key('entry-liuyao')), matching: find.byType(Pressable));
      expect(link, findsOneWidget);
      await tester.tap(link);
      await frames(tester, 6);
      expect(clipboard.copied, 'https://example.com/x');
      expect(find.text('已复制：https://example.com/x'), findsOneWidget);
      // The link opened, not the card: still 首页.
      expect(find.byKey(const Key('entry-liuyao')), findsOneWidget);
    });

    testWidgets('on the banner\'s dark art, staff\'s colours are the dark theme\'s, whatever the app\'s', (tester) async {
      final api = FakeApi()
        ..content = (texts: const {'introJoin': '加入<span style="color: var(--accent)">我们</span>'}, images: const {});
      await tester.pumpWidget(testApp(api, signedIn: false, locale: zhHans));
      await frames(tester, 12);
      expect(spanOf(tester, '加入我们', '我们').style?.color, ThemeTokens.dark.accent);
    });
  });

  testWidgets('a server from before the CMS (404): the app\'s own texts and art', (tester) async {
    final api = FakeApi()..content = null;
    await tester.pumpWidget(testApp(api, locale: zhHans));
    await frames(tester, 12);
    expect(artOf(tester), bannerArt);
    expect(find.text('八字排盘'), findsWidgets);
  });
}
