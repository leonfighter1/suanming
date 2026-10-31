// 登出 (S29; the owner: 「增加登出动画，如果用户登出」): going out, 首页 sinks back and fades as the introduction page comes
// forward; at once under reduce motion; signing in again finds ☰, not the ✕ of the menu it went out from.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_app/presentation/design.dart';
import 'package:mingli_app/presentation/home_page.dart';
import 'package:mingli_app/presentation/intro_page.dart';

import 'keys.dart';
import 'support.dart';

/// [page]'s opacity and scale, as the gate's switch shows it.
(double, double) look(WidgetTester tester, Type page) {
  T nearest<T extends Widget>() =>
      tester.widget<T>(find.ancestor(of: find.byType(page), matching: find.byType(T)).first);
  return (nearest<FadeTransition>().opacity.value, nearest<ScaleTransition>().scale.value);
}

/// 退出登录 from the menu, up to the frame the introduction page comes in.
Future<void> signOut(WidgetTester tester) async {
  await openFromMenu(tester, 'menu-sign-out');
  for (var i = 0; i < 20 && find.byType(IntroPage).evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(find.byType(IntroPage), findsOneWidget);
}

void main() {
  testWidgets('going out: 首页 sinks back and fades as the introduction page comes forward; then ☰ again',
      (tester) async {
    await tester.pumpWidget(testApp(FakeApi()));
    await frames(tester, 12);
    await signOut(tester);
    expect(find.byType(HomePage), findsOneWidget, reason: 'still there, leaving');

    await tester.pump(Motion.signOut ~/ 2);
    final (homeOpacity, homeScale) = look(tester, HomePage);
    final (introOpacity, introScale) = look(tester, IntroPage);
    expect(homeOpacity, inExclusiveRange(0, 1));
    expect(homeScale, inExclusiveRange(0.94, 1));
    expect(introOpacity, inExclusiveRange(0, 1));
    expect(introScale, inExclusiveRange(0.94, 1));

    await tester.pump(Motion.signOut);
    expect(find.byType(HomePage), findsNothing);
    expect(look(tester, IntroPage), (1.0, 1.0));

    // In again (at once): ☰, not the ✕ of the menu it went out from.
    await openSignIn(tester);
    await tester.enterText(find.byKey(const Key('login')), 'me@example.com');
    await tester.enterText(find.byKey(const Key('password')), 'long enough pw');
    await scrollAndTap(tester, find.byKey(const Key('auth-submit')), after: true);
    expect(find.byType(IntroPage), findsNothing);
    final icon = tester.widget<AnimatedIcon>(
      find.descendant(of: find.byKey(const Key('open-menu')), matching: find.byType(AnimatedIcon)),
    );
    expect(icon.progress.value, 0);
  });

  testWidgets('reduce motion: going out is at once', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(testApp(FakeApi()));
    await frames(tester, 12);
    await signOut(tester);
    expect(find.byType(HomePage), findsNothing);
    expect(look(tester, IntroPage), (1.0, 1.0));
  });
}
