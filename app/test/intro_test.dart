// 欢迎 (S29): what a signed-out start shows: the welcome, 登录 / 注册 and the services. A service picked before signing
// in opens once signed in; signing up goes to 首页 alone.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_app/application/providers.dart' show zhHans;

import 'keys.dart';
import 'support.dart';

final home = find.byKey(const Key('entry-bazi'));
final signInForm = find.byKey(const Key('login'));

Future<void> start(WidgetTester tester, [FakeApi? api]) async {
  await tester.pumpWidget(testApp(api ?? FakeApi(), signedIn: false, locale: zhHans));
  await frames(tester, 12);
}

/// The service [system] picked on the introduction page.
Future<void> pick(WidgetTester tester, String system) async {
  await scrollAndTap(tester, find.byKey(Key('intro-$system')), after: true, n: 10);
}

Future<void> signIn(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('login')), 'me@example.com');
  await tester.enterText(find.byKey(const Key('password')), 'long enough pw');
  await scrollAndTap(tester, find.byKey(const Key('auth-submit')), after: true);
}

void main() {
  testWidgets('signed out: the welcome with the app\'s mark, 登录 / 注册, and the services under 东方 and 西方',
      (tester) async {
    await start(tester);
    expect(find.text('欢迎来到命理大师'), findsOneWidget);
    expect(find.byKey(const Key('intro-mark')), findsOneWidget);
    expect(find.byKey(const Key('intro-sign-in')), findsOneWidget);
    for (final s in ['bazi', 'qiuqian', 'liuyao', 'fengshui', 'tarot']) {
      await scrollTo(tester, Key('intro-$s'));
      expect(find.byKey(Key('intro-$s')), findsOneWidget, reason: s);
    }
    expect(find.byKey(const Key('intro-group-west')), findsOneWidget);
  });

  testWidgets('on a desktop window the services two to a row: 东方 2 × 2, 西方 across', (tester) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await start(tester);
    Rect at(String s) => tester.getRect(find.byKey(Key('intro-$s')));
    expect(at('qiuqian').top, at('bazi').top);
    expect(at('fengshui').top, at('liuyao').top);
    expect(at('liuyao').top, greaterThan(at('bazi').bottom - 1));
    expect(at('tarot').width, greaterThan(at('bazi').width * 1.5));
  });

  testWidgets('登录 / 注册 opens the sign-in page, Esc comes back; signed in, 首页 with nothing behind it', (tester) async {
    await start(tester);
    await openSignIn(tester);
    expect(signInForm, findsOneWidget);
    await press(tester, LogicalKeyboardKey.escape);
    expect(signInForm, findsNothing);
    expect(find.byKey(const Key('intro-sign-in')), findsOneWidget);

    await openSignIn(tester);
    await signIn(tester);
    expect(home, findsOneWidget);
    expect(signInForm, findsNothing);
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('a service picked before signing in opens once signed in; back from it, 首页', (tester) async {
    await start(tester);
    await pick(tester, 'tarot');
    expect(signInForm, findsOneWidget);
    await signIn(tester);
    expect(find.byKey(const Key('tarot-question')), findsOneWidget);
    await systemBack(tester);
    expect(home, findsOneWidget);
    expect(signInForm, findsNothing);
  });

  testWidgets('signing up after picking a service: 首页, not the service', (tester) async {
    await start(tester);
    await pick(tester, 'tarot');
    await scrollAndTap(tester, find.byKey(const Key('auth-toggle')), after: true);
    await tester.enterText(find.byKey(const Key('username')), 'newcomer');
    await tester.enterText(find.byKey(const Key('password')), 'long enough pw');
    await scrollAndTap(tester, find.byKey(const Key('age-confirm')), after: true);
    await scrollAndTap(tester, find.byKey(const Key('auth-submit')), after: true);
    expect(home, findsOneWidget);
    expect(find.byKey(const Key('tarot-question')), findsNothing);
  });

  testWidgets('from the keyboard: Tab reaches 登录 / 注册, then the services; Enter on one opens sign-in',
      (tester) async {
    await start(tester);
    await tabTo(tester, 'intro-sign-in');
    await tabTo(tester, 'intro-bazi');
    await press(tester, LogicalKeyboardKey.enter);
    expect(signInForm, findsOneWidget);
  });

  testWidgets('what staff changed shows here too: the welcome\'s words, and a logo for the app\'s mark',
      (tester) async {
    final api = FakeApi()
      ..content = (texts: const {'introWelcome': '欢迎光临命理大师'}, images: const {'logo': '/v1/content/images/logo?v=1'});
    await start(tester, api);
    expect(find.text('欢迎光临命理大师'), findsOneWidget);
    final logo = tester.widget<Image>(find.byKey(const Key('intro-logo')));
    expect((logo.image as NetworkImage).url, endsWith('/v1/content/images/logo?v=1'));
    // The test's network answers 400: the app's own mark instead, without an error.
    expect(find.byKey(const Key('intro-mark')), findsOneWidget);
  });
}
