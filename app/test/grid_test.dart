// S24 WP24.2 (v12.2.0): the grid, the type ramp and the alignment rules of the ui-design skill (owner, 2026-10-30:
// 「统一网格系统，组件间距，字体比例和对齐规则，让整个页面更有秩序」).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_app/presentation/design.dart';
import 'package:mingli_app/presentation/layout.dart';
import 'package:mingli_app/presentation/theme.dart';

import 'design_rules.dart';
import 'keys.dart';
import 'support.dart';

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

  // S26 (owner, 2026-10-30): 「大于 1620px 时要设置一个max-width 1620px。本体可以是fluid…在tablet和mobile device 可以不用有这
  // 限制了」, 「在超大屏幕布局时可以采用2X2布局。如果只有一个那就采用1x1」.
  // Window width → the content's left edge and width, the margin inside the container: 390 - 2 × 16 = 358,
  // 700 - 2 × 24 = 652, 1024 - 2 × 24 = 976 (a tablet, no limit), 1280 - 2 × 32 = 1216; on 2560 the container is
  // 1620 at (2560 - 1620) / 2 = 470, so the content starts at 470 + 32 = 502 and is 1620 - 2 × 32 = 1556 wide.
  const widths = [(390.0, 16.0, 358.0), (700.0, 24.0, 652.0), (1024.0, 24.0, 976.0), (1280.0, 32.0, 1216.0), (2560.0, 502.0, 1556.0)];

  testWidgets('首页 in the app\'s container: fluid on a phone and a tablet, at most 1620 wider; on a desktop the methods '
      'two to a row (东方 2 × 2, 西方 1 × 1); the group titles on the cards\' edge', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1;
    for (final (width, left, content) in widths) {
      tester.view.physicalSize = Size(width, 1600);
      await tester.pumpWidget(const SizedBox()); // a fresh app (rule 24)
      await tester.pumpWidget(testApp(FakeApi()));
      await frames(tester, 12);
      final desktop = width >= 1200;
      // 东方 in the region's order (the fake's: 八字, 求签, 算卦, 风水), then 西方's 塔罗.
      final east = [for (final m in ['bazi', 'qiuqian', 'liuyao', 'fengshui']) tester.getRect(find.byKey(Key('entry-$m')))];
      final tarot = tester.getRect(find.byKey(const Key('entry-tarot')));
      expect(east.first.left, left, reason: 'width $width');
      expect(tarot.left, left, reason: 'width $width');
      // 1 × 1: a group's only method spans the content.
      expect(tarot.width, content, reason: 'width $width');
      if (desktop) {
        // Two to a row with the gutter (24) between: (1216 - 24) / 2 = 596 and (1556 - 24) / 2 = 766 a card.
        final card = (content - 24) / 2;
        for (final r in east) {
          expect(r.width, card, reason: 'width $width');
        }
        expect(east[1].left, east[0].right + 24, reason: 'width $width');
        expect(east[1].right, left + content, reason: 'width $width');
        expect(east[2].left, left, reason: 'width $width: 2 × 2');
        // Tops through the parts' entrance, which slides them in (rule 61): closeTo.
        expect(east[1].top, closeTo(east[0].top, 0.01), reason: 'width $width: 2 × 2');
        expect(east[2].top, closeTo(east[0].bottom, 0.01), reason: 'width $width: the second row under the first');
        expect(east[3].top, closeTo(east[2].top, 0.01), reason: 'width $width');
      } else {
        for (final r in east) {
          expect([r.left, r.width], [left, content], reason: 'width $width');
        }
        for (var i = 1; i < east.length; i++) {
          expect(east[i].top, closeTo(east[i - 1].bottom, 0.01), reason: 'width $width: one under another');
        }
      }
      final title = find.descendant(of: find.byKey(const Key('group-east')), matching: find.byType(Text));
      expect(tester.getTopLeft(title).dx, left, reason: 'width $width');
    }
  });

  testWidgets('the sign-in page in the container: one column on a phone and a tablet; on a desktop the banner at the '
      'left as tall as the form at the right, five of the twelve columns', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1;
    for (final (width, left, content) in widths) {
      tester.view.physicalSize = Size(width, 1600);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(testApp(FakeApi(), signedIn: false));
      await frames(tester, 12);
      final banner = tester.getRect(find.byKey(const Key('auth-banner')));
      final login = tester.getRect(find.byKey(const Key('login')));
      // The form's last control: Google, coming soon.
      final google = tester.getRect(find.byType(OutlinedButton).last);
      expect(banner.left, left, reason: 'width $width');
      if (width >= 1200) {
        // Five columns of twelve, gutters of 24: (1216 - 11 × 24) / 12 × 5 + 4 × 24 = 492.67; (1556 - 264) / 12 × 5
        // + 96 = 634.33.
        final form = (content - 11 * 24) / 12 * 5 + 4 * 24;
        expect(login.width, closeTo(form, 0.01), reason: 'width $width');
        expect(login.right, closeTo(left + content, 0.01), reason: 'width $width');
        expect(banner.right, closeTo(login.left - 24, 0.01), reason: 'width $width');
        expect([banner.top, banner.bottom], [login.top, google.bottom], reason: 'width $width: as tall as the form');
        // Signing up, the longer form (the region's menu, the age box): the banner grows with it.
        await tester.tap(find.byKey(const Key('auth-toggle')));
        await frames(tester, 12);
        final tall = tester.getRect(find.byKey(const Key('auth-banner')));
        expect(tester.getTopLeft(find.byKey(const Key('username'))).dy, tall.top, reason: 'width $width');
        expect(tall.bottom, tester.getRect(find.byType(OutlinedButton).last).bottom, reason: 'width $width');
        expect(tall.height, greaterThan(banner.height), reason: 'width $width');
      } else {
        expect([banner.width, login.left, login.width], [content, left, content], reason: 'width $width');
        expect(login.top, greaterThanOrEqualTo(banner.bottom), reason: 'width $width: the form under the banner');
      }
    }
  });

  // S27 (owner, 2026-10-30): 「对于所有的页面，基本框架在大屏时都要有这个尺寸限制（包括设置页面）」.
  testWidgets('every page in the container on a wide window: the methods, the place picker, 设置', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(2560, 1600);
    Future<void> fresh() async {
      await tester.pumpWidget(const SizedBox()); // rule 24
      await tester.pumpWidget(testApp(FakeApi()));
      await frames(tester, 12);
    }

    // The container: (2560 - 1620) / 2 = 470 beyond it at each side; the content 32 inside it, from 502, 1556 wide.
    for (final m in ['bazi', 'tarot', 'qiuqian', 'liuyao', 'fengshui']) {
      await fresh();
      await openEntry(tester, m);
      await frames(tester, 12);
      final card = tester.getRect(find.byType(AppCard).first);
      expect([card.left, card.width], [502.0, 1556.0], reason: m);
    }
    // The place picker, from 八字's form, and 设置: their rows carry their own inset (16), so the list is the
    // container itself, 470 to 2090.
    await fresh();
    await openEntry(tester, 'bazi');
    await frames(tester, 12);
    await scrollTo(tester, const Key('city'));
    await tester.tap(find.byKey(const Key('city')));
    await frames(tester, 12);
    final search = tester.getRect(find.byKey(const Key('place-search')));
    expect([search.left, search.width], [470.0 + 16, 1620.0 - 32]);
    await fresh();
    await tester.tap(find.byKey(const Key('open-menu')));
    await frames(tester, 12);
    await tester.tap(find.byKey(const Key('open-settings')));
    await frames(tester, 12);
    final tile = tester.getRect(find.byKey(const Key('settings-username')));
    expect([tile.left, tile.width], [470.0, 1620.0]);
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
