// S27 WP27.3 (owner, 2026-10-30): 「Theme加上太阳和月亮到banner上去, 表示时间，皮肤会跟随时间变化而变化。当地时间7点到第二天
// 凌晨6点为深色，其余为浅色。」 跟随时间: dark from 19:00 to 06:00 by the local clock, light otherwise, turning by itself;
// the banner shows the sun by day and the moon at night.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_app/application/providers.dart';
import 'package:mingli_app/data/settings_store.dart';
import 'package:mingli_app/presentation/design.dart';
import 'package:mingli_app/presentation/home_page.dart';

import 'support.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The banner's picture of the time: the sun, or the moon.
Finder bannerIcon(IconData icon) => find.descendant(of: find.byType(HeroBanner), matching: find.byIcon(icon));

void main() {
  test('night is 19:00 to 06:00 by the local clock; the next turn is 06:00 or 19:00', () {
    DateTime at(int h, [int m = 0]) => DateTime(2026, 10, 30, h, m);
    expect([for (final t in [at(0), at(5, 59), at(6), at(18, 59), at(19), at(23, 59)]) isNight(t)],
        [true, true, false, false, true, true]);
    expect([nextTurn(at(0)), nextTurn(at(5, 59)), nextTurn(at(6)), nextTurn(at(18, 59))], [at(6), at(6), at(19), at(19)]);
    expect(nextTurn(at(19)), DateTime(2026, 10, 31, 6));
    expect(nextTurn(DateTime(2026, 12, 31, 23)), DateTime(2027, 1, 1, 6)); // over the year's end
  });

  testWidgets('跟随时间: light by day with the sun, dark from 19:00 with the moon, turning by itself in the open app',
      (tester) async {
    var now = DateTime(2026, 10, 30, 18, 59, 30);
    await tester.pumpWidget(testApp(FakeApi(), byTime: true, overrides: [clockProvider.overrideWithValue(() => now)]));
    await settle(tester);
    final home = find.byType(HomePage);
    expect(Theme.of(tester.element(home)).brightness, Brightness.light);
    expect(bannerIcon(Icons.wb_sunny_rounded), findsOneWidget);
    expect(bannerIcon(Icons.nightlight_round), findsNothing);

    // 30 s later it is 19:00: the turn comes by itself, and the page fades into the dark theme.
    now = DateTime(2026, 10, 30, 19);
    await tester.pump(const Duration(seconds: 30));
    await settle(tester);
    expect(Theme.of(tester.element(home)).brightness, Brightness.dark);
    expect(bannerIcon(Icons.nightlight_round), findsOneWidget);
    expect(bannerIcon(Icons.wb_sunny_rounded), findsNothing);

    // At 06:00, light again.
    now = DateTime(2026, 10, 31, 6);
    await tester.pump(const Duration(hours: 11));
    await settle(tester);
    expect(Theme.of(tester.element(home)).brightness, Brightness.light);
    expect(bannerIcon(Icons.wb_sunny_rounded), findsOneWidget);
  });

  testWidgets('the banner tells the time whatever 外观 is: the moon at night on a light page', (tester) async {
    await tester.pumpWidget(testApp(
      FakeApi(),
      theme: ThemeMode.light,
      overrides: [clockProvider.overrideWithValue(() => DateTime(2026, 10, 30, 22))],
    ));
    await settle(tester);
    expect(Theme.of(tester.element(find.byType(HomePage))).brightness, Brightness.light);
    expect(bannerIcon(Icons.nightlight_round), findsOneWidget);
  });

  testWidgets('外觀 → 跟隨時間, first, with its hours: picked, the page follows the clock, and it is kept', (tester) async {
    final store = InMemorySettingsStore();
    await tester.pumpWidget(testApp(
      FakeApi(),
      settings: store,
      theme: ThemeMode.light,
      overrides: [clockProvider.overrideWithValue(() => DateTime(2026, 10, 30, 22))],
    ));
    await settle(tester);
    await tester.tap(find.byKey(const Key('open-menu')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('theme-menu')));
    await settle(tester);
    final options = find.descendant(of: find.byType(SimpleDialog), matching: find.byType(ListTile)).evaluate();
    expect([for (final e in options) (e.widget.key! as ValueKey<String>).value], ['theme-time', 'theme-system', 'theme-light', 'theme-dark']);
    final time = find.byKey(const Key('theme-time'));
    expect(find.descendant(of: time, matching: find.text('跟隨時間')), findsOneWidget);
    expect(find.descendant(of: time, matching: find.text('晚上 7 點到早上 6 點為深色，其餘為淺色')), findsOneWidget);

    await tester.tap(time);
    await settle(tester);
    expect(Theme.of(tester.element(find.byType(HomePage))).brightness, Brightness.dark); // 22:00
    expect(tester.widget<Text>(find.byKey(const Key('theme-current'))).data, '跟隨時間');
    expect(store.savedTheme, 'time');
  });
}
