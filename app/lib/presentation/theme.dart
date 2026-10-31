import 'package:flutter/material.dart';

import 'design.dart';
import 'tokens.dart';

const _stemBranchElement = {
  '甲': '木', '乙': '木', '丙': '火', '丁': '火', '戊': '土', '己': '土', '庚': '金', '辛': '金', '壬': '水', '癸': '水',
  '子': '水', '丑': '土', '寅': '木', '卯': '木', '辰': '土', '巳': '火', '午': '火', '未': '土', '申': '金', '酉': '金',
  '戌': '土', '亥': '水',
};

String _elementOf(String elementOrChar) => _stemBranchElement[elementOrChar] ?? elementOrChar;

/// Colour of a 五行 element ('木' …) or of a stem/branch character in the light theme, or with [dark] the dark one.
Color wuxingColor(String elementOrChar, {bool dark = false}) =>
    ThemeTokens.forBrightness(dark ? Brightness.dark : Brightness.light).wuxing(_elementOf(elementOrChar));

/// [wuxingColor] for the theme round [context], mixed while the theme changes.
Color wuxingColorOf(BuildContext context, String elementOrChar) =>
    ThemeTokens.of(context).wuxing(_elementOf(elementOrChar));

/// The type ramp (tech plan S24, the ui-design skill): 11 to 48 in steps of about 1.2, line heights in whole even
/// points set for Chinese text, no letter spacing; titles semibold. Colours come from the scheme. Material's roles left
/// out (display large and medium, headline large) are not used. Long text takes `ReadingText` (design.dart).
const _ramp = TextTheme(
  displaySmall: TextStyle(fontSize: 48, height: 56 / 48, fontWeight: FontWeight.w600, letterSpacing: 0),
  headlineMedium: TextStyle(fontSize: 32, height: 40 / 32, fontWeight: FontWeight.w600, letterSpacing: 0),
  headlineSmall: TextStyle(fontSize: 24, height: 32 / 24, fontWeight: FontWeight.w600, letterSpacing: 0),
  titleLarge: TextStyle(fontSize: 20, height: 28 / 20, fontWeight: FontWeight.w600, letterSpacing: 0),
  titleMedium: TextStyle(fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w600, letterSpacing: 0),
  titleSmall: TextStyle(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w600, letterSpacing: 0),
  bodyLarge: TextStyle(fontSize: 16, height: 24 / 16, letterSpacing: 0),
  bodyMedium: TextStyle(fontSize: 14, height: 22 / 14, letterSpacing: 0),
  bodySmall: TextStyle(fontSize: 12, height: 18 / 12, letterSpacing: 0),
  labelLarge: TextStyle(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w500, letterSpacing: 0),
  labelMedium: TextStyle(fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w500, letterSpacing: 0),
  labelSmall: TextStyle(fontSize: 11, height: 16 / 11, fontWeight: FontWeight.w600, letterSpacing: 0),
);

/// The app's theme (and the 管理后台's), made from [ThemeTokens] (tech plan S24): Material's colour roles are the
/// tokens under Material's names, and the tokens themselves ride along as a theme extension for what Material has no
/// role for. The two themes differ in colour only. The type is one ramp ([_ramp]).
ThemeData buildTheme(Brightness brightness) {
  final t = ThemeTokens.forBrightness(brightness);
  // Secondary and tertiary come from the accent; every other role is a token.
  final scheme = ColorScheme.fromSeed(
    seedColor: ThemeTokens.light.accent,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  ).copyWith(
    primary: t.accent,
    onPrimary: t.onAccent,
    primaryContainer: t.accentSoft,
    onPrimaryContainer: t.onAccentSoft,
    // A chosen segment or chip: the soft accent, as every selected state.
    secondaryContainer: t.accentSoft,
    onSecondaryContainer: t.onAccentSoft,
    error: t.danger,
    onError: t.onDanger,
    errorContainer: t.dangerSoft,
    onErrorContainer: t.onDangerSoft,
    surface: t.background,
    onSurface: t.text,
    onSurfaceVariant: t.textSecondary,
    surfaceContainerLowest: t.card,
    surfaceContainerLow: t.card,
    surfaceContainer: t.card,
    surfaceContainerHigh: t.raised,
    surfaceContainerHighest: t.inset,
    surfaceTint: Colors.transparent,
    outline: t.borderStrong,
    outlineVariant: t.border,
    inverseSurface: t.inverse,
    onInverseSurface: t.onInverse,
    inversePrimary: ThemeTokens.forBrightness(brightness == Brightness.dark ? Brightness.light : Brightness.dark).accent,
  );
  final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.field));
  // Keyboard focus: the same clear outline on every button and chip.
  final focusSide = WidgetStateBorderSide.resolveWith(
    (states) => states.contains(WidgetState.focused) ? focusOutline(scheme) : null,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    // 波纹跟手 (S30; owner, 2026-10-30: 「从手指按下的位置生成圆形波纹向外扩散，而不是从按钮中心开始」): the splash keeps its
    // centre where the finger went down as it spreads. Material 3's own ripple drifts to the centre on the way.
    splashFactory: InkSplash.splashFactory,
    textTheme: _ramp,
    extensions: [t],
    scaffoldBackgroundColor: t.background,
    cardColor: t.card,
    dividerColor: t.border,
    // Focus tint of list rows, section headers and cards (Material's default is faint grey).
    focusColor: t.accent.withValues(alpha: 0.14),
    // One transition everywhere: shared-axis style zoom + fade.
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        for (final p in TargetPlatform.values) p: const ZoomPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: t.background,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 2,
    ),
    cardTheme: CardThemeData(
      color: t.card,
      margin: const EdgeInsets.only(bottom: Space.m),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.card)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: t.inset,
      hintStyle: TextStyle(color: t.textMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: Space.field),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.field), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.field), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.field),
        borderSide: BorderSide(color: t.accent, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: rounded).copyWith(side: focusSide),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: rounded).copyWith(side: focusSide),
    ),
    textButtonTheme: TextButtonThemeData(style: ButtonStyle(side: focusSide)),
    iconButtonTheme: IconButtonThemeData(style: ButtonStyle(side: focusSide)),
    segmentedButtonTheme: SegmentedButtonThemeData(style: SegmentedButton.styleFrom(shape: rounded)),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.chip)),
      // The focus outline, else the chip's own (Material's flat chips: a transparent one once chosen, so a chip keeps
      // its size). Never null: ChipThemeData's lerp, which every change of theme runs, fails on a side that resolves to
      // nothing (v12.1.0).
      side: WidgetStateBorderSide.resolveWith((states) {
        if (states.contains(WidgetState.focused)) return focusOutline(scheme);
        if (states.contains(WidgetState.selected)) return const BorderSide(color: Colors.transparent);
        if (states.contains(WidgetState.disabled)) return BorderSide(color: scheme.onSurface.withValues(alpha: 0.12));
        return BorderSide(color: scheme.outlineVariant);
      }),
    ),
    dividerTheme: DividerThemeData(color: t.border, space: Space.xl),
    listTileTheme: const ListTileThemeData(contentPadding: EdgeInsets.symmetric(horizontal: Space.l)),
  );
}

/// 干支 text with each character coloured by its element.
class GanZhiText extends StatelessWidget {
  const GanZhiText(this.text, {super.key, this.size = 20});
  final String text;
  final double size;

  @override
  Widget build(BuildContext context) => Text.rich(
        TextSpan(
          children: [
            for (final ch in text.characters)
              TextSpan(text: ch, style: TextStyle(color: wuxingColorOf(context, ch))),
          ],
        ),
        style: TextStyle(fontSize: size, fontWeight: FontWeight.w600),
      );
}
