// S24 WP24.2 (v12.2.0): the grid, the type ramp and the alignment rules of the ui-design skill (owner, 2026-10-30:
// 「统一网格系统，组件间距，字体比例和对齐规则，让整个页面更有秩序」).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_app/presentation/layout.dart';
import 'package:mingli_app/presentation/theme.dart';

import 'design_rules.dart';
import 'support.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  test('window classes: 4, 8 or 12 columns, their margins and gutters on the 4-point scale', () {
    expect([for (final w in [360.0, 599.0, 600.0, 839.0, 840.0, 1199.0, 1200.0, 1920.0]) WindowClass.of(w)], [
      WindowClass.compact,
      WindowClass.compact,
      WindowClass.medium,
      WindowClass.medium,
      WindowClass.expanded,
      WindowClass.expanded,
      WindowClass.large,
      WindowClass.large,
    ]);
    for (final c in WindowClass.values) {
      expect([4, 8, 12], contains(c.columns));
      expect(c.margin % 4, 0, reason: '$c');
      expect(c.gutter % 4, 0, reason: '$c');
    }
    // Eight of twelve columns in 1000 with 24 gutters: (1000 - 11 × 24) / 12 = 61.33 a column; × 8 + 7 × 24 = 658.67.
    expect(Grid.span(1000, 8, columns: 12, gutter: 24), closeTo(658.67, 0.01));
    expect(Grid.span(1000, 12, columns: 12, gutter: 24), closeTo(1000, 0.01));
  });

  test('one type ramp: 11 to 48, whole even line heights, no letter spacing, the same in both themes', () {
    for (final b in Brightness.values) {
      final t = buildTheme(b).textTheme;
      final ramp = {
        'displaySmall': t.displaySmall,
        'headlineMedium': t.headlineMedium,
        'headlineSmall': t.headlineSmall,
        'titleLarge': t.titleLarge,
        'titleMedium': t.titleMedium,
        'titleSmall': t.titleSmall,
        'bodyLarge': t.bodyLarge,
        'bodyMedium': t.bodyMedium,
        'bodySmall': t.bodySmall,
        'labelLarge': t.labelLarge,
        'labelMedium': t.labelMedium,
        'labelSmall': t.labelSmall,
      };
      for (final MapEntry(key: role, value: s) in ramp.entries) {
        expect([11, 12, 14, 16, 20, 24, 32, 48], contains(s!.fontSize), reason: role);
        expect(s.letterSpacing, 0, reason: role);
        final line = s.fontSize! * s.height!;
        expect(line, closeTo(line.roundToDouble(), 0.01), reason: role);
        expect(line.round().isEven, isTrue, reason: '$role: $line');
      }
      // The hero figure is the largest, then the headlines, titles, body and labels.
      expect(t.displaySmall!.fontSize, 48);
      expect(t.headlineSmall!.fontSize! > t.titleLarge!.fontSize!, isTrue);
      expect(t.titleLarge!.fontSize! > t.titleMedium!.fontSize!, isTrue);
      expect(t.bodyMedium!.fontSize! > t.bodySmall!.fontSize!, isTrue);
    }
  });

  testWidgets('the home page in the grid: 16 at the sides on a phone, 24 on a small tablet, a centred 720 on a desktop; '
      'the group titles on the cards\' edge', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1;
    // Window width → the cards' left edge and width: (390 - 2 × 16), (700 - 2 × 24), and (1280 - 720) / 2 = 280.
    for (final (width, left, cardWidth) in [(390.0, 16.0, 358.0), (700.0, 24.0, 652.0), (1280.0, 280.0, 720.0)]) {
      tester.view.physicalSize = Size(width, 1600);
      await tester.pumpWidget(const SizedBox()); // a fresh app (rule 24)
      await tester.pumpWidget(testApp(FakeApi()));
      await settle(tester);
      final card = tester.getRect(find.byKey(const Key('entry-bazi')));
      expect(card.left, left, reason: 'width $width');
      expect(card.width, cardWidth, reason: 'width $width');
      final title = find.descendant(of: find.byKey(const Key('group-east')), matching: find.byType(Text));
      expect(tester.getTopLeft(title).dx, left, reason: 'width $width');
    }
  });

  test('the design rules catch what they are for, and nothing else', () {
    final dir = Directory.systemTemp.createTempSync('design-rules-');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/bad.dart').writeAsStringSync([
      "final a = Color(0xFF112233);",
      "final b = Colors.green;",
      "final c = theme.brightness == Brightness.dark;",
      "final d = TextStyle(fontSize: 13);",
      "final e = EdgeInsets.only(top: 7, right: Space.s);",
      "final f = SizedBox(height: 120);",
      "final g = EdgeInsets.all(Space.l + 4);",
      "final h = BorderRadius.circular(6);",
      "final i = Radii.card + 4;",
      "final j = textTheme.displayLarge;",
      "final k = Space.page;",
      "final l = textTheme.bodyLarge?.copyWith(height: 1.8);",
    ].join('\n'));
    File('${dir.path}/good.dart').writeAsStringSync([
      '// Color(0xFF000000) in a comment is fine',
      'final a = ThemeTokens.of(context).success;',
      'final b = Colors.transparent;',
      'final c = EdgeInsets.fromLTRB(Space.l, 0, Space.l, Space.s);',
      'final d = SizedBox(width: 56, child: Text(label));',
      'final e = EdgeInsets.symmetric(horizontal: Space.s - _ring);',
      'final f = BorderRadius.circular(Radii.card);',
      'final g = textTheme.displaySmall;',
      'final h = pagePadding(context);',
      'final i = ReadingText.body(context);',
      'final j = Container(height: 12);',
    ].join('\n'));
    final found = designViolations(dir.path);
    expect(found.where((v) => v.contains('good.dart')), isEmpty);
    final names = [for (final v in found) RegExp(r':\d+: ([^(]+) \(').firstMatch(v)!.group(1)!.trim()];
    // g breaks two rules: a number in EdgeInsets, and Space plus a number.
    expect(names, [
      'raw colour',
      'named colour',
      'brightness check',
      'font size',
      'number in EdgeInsets',
      'number as a gap',
      'number in EdgeInsets',
      'Space plus a number',
      'number as a corner',
      'Radii plus a number',
      'role off the type ramp',
      'fixed page padding',
      'line height off the ramp',
    ]);
  });

  test("every screen keeps the design rules: colours, sizes, gaps and corners from the system", () {
    final found = designViolations('lib/presentation');
    expect(found, isEmpty, reason: '\n${found.join('\n')}');
  });
}
