// S24 WP24.1 (v12.1.0): one theme system, light and dark, made from ThemeTokens (owner, 2026-10-30: 「建立统一的浅色和
// 深色主题系统，分别定义背景，卡片，文字和强调色，切换主题时保持布局和组件结构不变，让颜色，边框和状态自然过渡」).
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mingli_app/application/providers.dart';
import 'package:mingli_app/data/settings_store.dart';
import 'package:mingli_app/presentation/home_page.dart';
import 'package:mingli_app/presentation/theme.dart';
import 'package:mingli_app/presentation/tokens.dart';

import 'support.dart';

/// WCAG 2 contrast ratio of two colours.
double contrast(Color a, Color b) {
  final (x, y) = (a.computeLuminance(), b.computeLuminance());
  return (max(x, y) + 0.05) / (min(x, y) + 0.05);
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Every box on screen and where it is: what a change of theme must leave alone.
List<Rect> layoutOf(WidgetTester tester) {
  final rects = <Rect>[];
  void visit(RenderObject o) {
    if (o is RenderBox && o.hasSize) rects.add(o.localToGlobal(Offset.zero) & o.size);
    o.visitChildren(visit);
  }

  tester.binding.renderViews.first.visitChildren(visit);
  return rects;
}

/// Storage that can't be read, as in a private window.
class _BrokenStore implements SettingsStore {
  @override
  Future<String?> language() => Future.error(StateError('no storage'));
  @override
  Future<void> setLanguage(String apiLocale) => Future.error(StateError('no storage'));
  @override
  Future<String?> theme() => Future.error(StateError('no storage'));
  @override
  Future<void> setTheme(String mode) => Future.error(StateError('no storage'));
}

void main() {
  test('each theme defines its colours, and they read: text, muted, accent, states and 五行 at 4.5 : 1 everywhere', () {
    for (final t in [ThemeTokens.light, ThemeTokens.dark]) {
      final surfaces = {'background': t.background, 'card': t.card, 'raised': t.raised, 'inset': t.inset};
      final inks = {
        'text': t.text,
        'secondary': t.textSecondary,
        'muted': t.textMuted,
        'accent': t.accent,
        'success': t.success,
        'warning': t.warning,
        'danger': t.danger,
        'info': t.info,
        for (final e in ['木', '火', '土', '金', '水']) e: t.wuxing(e),
      };
      for (final MapEntry(key: ink, value: fg) in inks.entries) {
        for (final MapEntry(key: surface, value: bg) in surfaces.entries) {
          expect(contrast(fg, bg), greaterThanOrEqualTo(4.5), reason: '$ink on $surface, ${t.brightness}');
        }
      }
      for (final (name, fg, bg) in [
        ('on accent', t.onAccent, t.accent),
        ('on the soft accent', t.onAccentSoft, t.accentSoft),
        ('on danger', t.onDanger, t.danger),
        ('on the soft danger', t.onDangerSoft, t.dangerSoft),
        ('success on its fill', t.success, t.successSoft),
        ('warning on its fill', t.warning, t.warningSoft),
        ('danger on its fill', t.danger, t.dangerSoft),
        ('info on its fill', t.info, t.infoSoft),
        ('on inverse', t.onInverse, t.inverse),
      ]) {
        expect(contrast(fg, bg), greaterThanOrEqualTo(4.5), reason: '$name, ${t.brightness}');
      }
      // A card stands off the page by its hairline; a field's outline is stronger than a hairline.
      expect(contrast(t.border, t.card), greaterThan(1.2), reason: '${t.brightness}');
      expect(contrast(t.borderStrong, t.card), greaterThan(contrast(t.border, t.card)), reason: '${t.brightness}');
      expect(t.series, hasLength(7));
    }
  });

  test("Material's roles are the tokens under Material's names, and the two themes differ in colour only", () {
    final themes = {for (final b in Brightness.values) b: buildTheme(b)};
    for (final MapEntry(key: b, value: theme) in themes.entries) {
      final t = ThemeTokens.forBrightness(b);
      final s = theme.colorScheme;
      expect(theme.extension<ThemeTokens>(), same(t));
      expect(
        [s.surface, s.surfaceContainerLow, s.surfaceContainerHigh, s.surfaceContainerHighest, theme.scaffoldBackgroundColor],
        [t.background, t.card, t.raised, t.inset, t.background],
      );
      expect([s.onSurface, s.onSurfaceVariant, s.outlineVariant, s.outline], [t.text, t.textSecondary, t.border, t.borderStrong]);
      expect([s.primary, s.onPrimary, s.primaryContainer, s.secondaryContainer], [t.accent, t.onAccent, t.accentSoft, t.accentSoft]);
      expect([s.error, s.onError, s.errorContainer], [t.danger, t.onDanger, t.dangerSoft]);
      // The 五行 of a theme, by element and by stem or branch.
      expect(wuxingColor('甲', dark: b == Brightness.dark), t.wood);
      expect(wuxingColor('子', dark: b == Brightness.dark), t.water);
    }
    // Same type, same sizes: only colours change between the themes.
    TextStyle? geometry(TextStyle? s) => s?.copyWith(color: const Color(0x00000000), decorationColor: const Color(0x00000000));
    final (light, dark) = (themes[Brightness.light]!, themes[Brightness.dark]!);
    for (final (a, b) in [
      (light.textTheme.bodyMedium, dark.textTheme.bodyMedium),
      (light.textTheme.titleMedium, dark.textTheme.titleMedium),
      (light.textTheme.labelSmall, dark.textTheme.labelSmall),
      (light.textTheme.headlineSmall, dark.textTheme.headlineSmall),
    ]) {
      expect([geometry(a)?.fontSize, geometry(a)?.height, geometry(a)?.fontWeight], [geometry(b)?.fontSize, geometry(b)?.height, geometry(b)?.fontWeight]);
    }
    expect(light.inputDecorationTheme.contentPadding, dark.inputDecorationTheme.contentPadding);
    expect(light.dividerTheme.space, dark.dividerTheme.space);
  });

  testWidgets('light and dark lay the page out alike: every box in the same place, with the menu open too', (tester) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Future<(List<Rect>, List<Rect>)> layouts(ThemeMode mode) async {
      await tester.pumpWidget(const SizedBox()); // a fresh app (rule 24)
      await tester.pumpWidget(testApp(FakeApi(), theme: mode));
      await settle(tester);
      final page = layoutOf(tester);
      await tester.tap(find.byKey(const Key('open-menu')));
      await settle(tester);
      return (page, layoutOf(tester));
    }

    final (lightPage, lightMenu) = await layouts(ThemeMode.light);
    expect(Theme.of(tester.element(find.byType(HomePage))).brightness, Brightness.light);
    final (darkPage, darkMenu) = await layouts(ThemeMode.dark);
    expect(Theme.of(tester.element(find.byType(HomePage))).brightness, Brightness.dark);
    expect(lightPage.length, greaterThan(50));
    expect(darkPage, lightPage);
    expect(darkMenu, lightMenu);
  });

  testWidgets('外觀 in the menu: the page fades into the theme picked, the 五行 too, and it is kept', (tester) async {
    final store = InMemorySettingsStore();
    await tester.pumpWidget(testApp(FakeApi(), settings: store, theme: ThemeMode.light));
    await settle(tester);
    await tester.tap(find.byKey(const Key('open-menu')));
    await settle(tester);
    expect(tester.widget<Text>(find.byKey(const Key('theme-current'))).data, '淺色');
    await tester.tap(find.byKey(const Key('theme-menu')));
    await settle(tester);
    for (final (key, label) in [('theme-system', '跟隨系統'), ('theme-light', '淺色'), ('theme-dark', '深色')]) {
      expect(find.descendant(of: find.byKey(Key(key)), matching: find.text(label)), findsOneWidget);
    }
    expect(tester.widget<ListTile>(find.byKey(const Key('theme-light'))).selected, isTrue);

    await tester.tap(find.byKey(const Key('theme-dark')));
    await tester.pump();
    await tester.pump();
    // Half-way through the 300 ms change: every colour between the two themes, none jumped.
    await tester.pump(const Duration(milliseconds: 150));
    final page = tester.element(find.byType(HomePage));
    final mid = ThemeTokens.of(page);
    expect(mid.darkness, inExclusiveRange(0.3, 0.7));
    final background = Theme.of(page).scaffoldBackgroundColor;
    expect(background, isNot(ThemeTokens.light.background));
    expect(background, isNot(ThemeTokens.dark.background));
    expect(background.computeLuminance(),
        inExclusiveRange(ThemeTokens.dark.background.computeLuminance(), ThemeTokens.light.background.computeLuminance()));
    final wood = wuxingColorOf(page, '木');
    expect(wood, isNot(ThemeTokens.light.wood));
    expect(wood, isNot(ThemeTokens.dark.wood));

    await settle(tester);
    final after = tester.element(find.byType(HomePage));
    expect(ThemeTokens.of(after).darkness, 1);
    expect(Theme.of(after).scaffoldBackgroundColor, ThemeTokens.dark.background);
    expect(wuxingColorOf(after, '木'), ThemeTokens.dark.wood);
    expect(tester.widget<Text>(find.byKey(const Key('theme-current'))).data, '深色');
    expect(store.savedTheme, 'dark');
  });

  test('the app starts in the theme last picked, else by the time of day (跟随时间, S27)', () async {
    const byTime = (mode: ThemeMode.system, byTime: true);
    expect(await startTheme(InMemorySettingsStore()), byTime);
    expect(await startTheme(InMemorySettingsStore()..savedTheme = 'time'), byTime);
    expect(await startTheme(InMemorySettingsStore()..savedTheme = 'system'), (mode: ThemeMode.system, byTime: false));
    expect(await startTheme(InMemorySettingsStore()..savedTheme = 'dark'), (mode: ThemeMode.dark, byTime: false));
    expect(await startTheme(InMemorySettingsStore()..savedTheme = 'light'), (mode: ThemeMode.light, byTime: false));
    expect(await startTheme(InMemorySettingsStore()..savedTheme = 'sepia'), byTime);
    expect(await startTheme(_BrokenStore()), byTime);
  });
}
