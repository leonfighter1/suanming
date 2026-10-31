// S4 WP4.1 (v3.1.0): 五行 colours that read on the app's cards, light and dark, and the pillar
// grid's detail rows folded under 更多.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_app/presentation/theme.dart';
import 'package:mingli_app/presentation/tokens.dart' show contrastRatio;

import 'keys.dart';
import 'support.dart';

void main() {
  test('every 五行 colour reads as small text (4.5 : 1) on the cards, in light and in dark', () {
    for (final brightness in Brightness.values) {
      final scheme = buildTheme(brightness).colorScheme;
      for (final element in ['木', '火', '土', '金', '水']) {
        final colour = wuxingColor(element, dark: brightness == Brightness.dark);
        // AppCard is surfaceContainerLow; pages are surface; a tile inside a card the inset (v12.1.0).
        for (final (name, background) in [
          ('surface', scheme.surface),
          ('card', scheme.surfaceContainerLow),
          ('inset', scheme.surfaceContainerHighest),
        ]) {
          expect(contrastRatio(colour, background), greaterThanOrEqualTo(4.5), reason: '$element on $name, $brightness');
        }
      }
    }
    // A stem or branch takes its element's colour: 甲 and 寅 are 木, 壬 and 子 are 水.
    expect([wuxingColor('甲'), wuxingColor('寅')], [wuxingColor('木'), wuxingColor('木')]);
    expect(wuxingColor('子', dark: true), wuxingColor('水', dark: true));
  });

  testWidgets('the pillar grid opens on 十神, 天干 and 地支; 更多 shows 藏干, 长生 and 纳音', (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(FakeApi()));
    await frames(tester, 10);
    await openBaziChart(tester);

    final grid = find.byKey(const Key('pillar-grid'));
    int rows() => (tester.widget<Table>(grid).children).length;
    expect(rows(), 4); // pillar names, 十神, 天干, 地支
    expect(find.descendant(of: grid, matching: find.text('納音')), findsNothing); // the test app reads 繁體
    await tester.tap(find.byKey(const Key('pillar-more')));
    await frames(tester, 10);
    expect(rows(), 8);
    expect(find.descendant(of: grid, matching: find.text('納音')), findsOneWidget);
    await tester.tap(find.byKey(const Key('pillar-more')));
    await frames(tester, 10);
    expect(rows(), 4);
  });
}
