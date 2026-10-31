// 维护通知 (S35; the owner, 2026-10-31: 「添加正在维护的通知，admin可以toggle 告知用户何时能够登录 by default 3-4 小时，可以
// 自己定时」): the app says when users may sign in again; a signed-in user waits on a page of its own; staff go on.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_app/application/providers.dart';

import 'keys.dart';
import 'support.dart';

/// Switched on at 12:00 here, three to four hours: 15:00 to 16:00; the app's clock at 13:00, the same day.
Map<String, Object?> window({DateTime? from, DateTime? to}) => {
      'since': DateTime(2026, 10, 31, 12).toUtc().toIso8601String(),
      'ends_from': (from ?? DateTime(2026, 10, 31, 15)).toUtc().toIso8601String(),
      'ends_by': (to ?? DateTime(2026, 10, 31, 16)).toUtc().toIso8601String(),
    };
final clock = clockProvider.overrideWithValue(() => DateTime(2026, 10, 31, 13));
const said = '預計 15:00 到 16:00 之間可以再登入。';

void main() {
  testWidgets('signed out: the introduction and sign-in pages say when; a sign-in waits, saying the same', (tester) async {
    final api = FakeApi()..maintenance = window();
    await tester.pumpWidget(testApp(api, signedIn: false, overrides: [clock]));
    await frames(tester, 12);
    expect(find.text('系統維護中'), findsOneWidget);
    expect(find.text(said), findsOneWidget);
    await openSignIn(tester);
    expect(find.byKey(const Key('maintenance-notice')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('login')), 'me@example.com');
    await tester.enterText(find.byKey(const Key('password')), 'long enough pw');
    await scrollAndTap(tester, find.byKey(const Key('auth-submit')), after: true);
    expect(find.byKey(const Key('entry-bazi')), findsNothing);
    // The refusal says the same, under the form.
    expect(find.text(said), findsNWidgets(2));
  });

  testWidgets('signed in: a page of its own until it is over; 再看看 then brings 首页 back', (tester) async {
    final api = FakeApi()..maintenance = window();
    await tester.pumpWidget(testApp(api, overrides: [clock]));
    await frames(tester, 12);
    expect(find.byKey(const Key('maintenance-banner')), findsOneWidget);
    expect(find.text(said), findsOneWidget);
    expect(find.byKey(const Key('entry-bazi')), findsNothing);

    api.maintenance = null;
    await tester.tap(find.byKey(const Key('maintenance-check')));
    await frames(tester, 12);
    expect(find.byKey(const Key('maintenance-banner')), findsNothing);
    expect(find.byKey(const Key('entry-bazi')), findsOneWidget);
  });

  testWidgets('staff work as usual: 首页, told what users see', (tester) async {
    final api = FakeApi()
      ..maintenance = window()
      ..staff = 'manager';
    await tester.pumpWidget(testApp(api, overrides: [clock]));
    await frames(tester, 12);
    expect(find.text(said), findsOneWidget);
    expect(find.text('你是後台人員，可以照常使用；使用者現在看到的是這則通知。'), findsOneWidget);
    // 首页's methods below the notice.
    await scrollTo(tester, const Key('entry-bazi'));
    expect(find.byKey(const Key('entry-bazi')), findsOneWidget);
  });

  testWidgets('a time an admin set is said as it is; one already past, "soon"', (tester) async {
    final api = FakeApi()..maintenance = window(from: DateTime(2026, 10, 31, 15, 30), to: DateTime(2026, 10, 31, 15, 30));
    await tester.pumpWidget(testApp(api, signedIn: false, overrides: [clock]));
    await frames(tester, 12);
    expect(find.text('預計 15:30 可以再登入。'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    api.maintenance = window(from: DateTime(2026, 10, 31, 12, 30), to: DateTime(2026, 10, 31, 12, 30));
    await tester.pumpWidget(testApp(api, signedIn: false, overrides: [clock]));
    await frames(tester, 12);
    expect(find.text('很快就可以再登入，請稍後再試。'), findsOneWidget);
  });
}
