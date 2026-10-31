// 内容管理 (S29): what staff changed in the CMS shows in front of the app's own texts and images.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_app/application/providers.dart' show zhHans;
import 'package:mingli_app/presentation/design.dart';

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

  testWidgets('a server from before the CMS (404): the app\'s own texts and art', (tester) async {
    final api = FakeApi()..content = null;
    await tester.pumpWidget(testApp(api, locale: zhHans));
    await frames(tester, 12);
    expect(artOf(tester), bannerArt);
    expect(find.text('八字排盘'), findsWidgets);
  });
}
