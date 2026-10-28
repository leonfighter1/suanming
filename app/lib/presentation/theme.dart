import 'package:flutter/material.dart';

import 'design.dart';

class AppColors {
  static const accent = Color(0xFF8A3B2E);
  // 五行 on a light surface: at least 4.5 : 1 contrast on a card (surfaceContainerLow), so small
  // 干支 (藏干) read too (v3.1.0: 木, 土 and 金 darker; they were 4.45, 3.9 and 3.0 on a card).
  static const wood = Color(0xFF387449);
  static const fire = Color(0xFFC0392B);
  static const earth = Color(0xFF8D6224);
  static const metal = Color(0xFF6A6A6A);
  static const water = Color(0xFF2B5F8F);
  // The same on a dark surface, lighter (water was 2.6 : 1 there).
  static const woodDark = Color(0xFF7CC08A);
  static const fireDark = Color(0xFFEF7B6E);
  static const earthDark = Color(0xFFD9A55B);
  static const metalDark = Color(0xFFBDBDBD);
  static const waterDark = Color(0xFF7FB2E5);
}

const _stemBranchElement = {
  '甲': '木', '乙': '木', '丙': '火', '丁': '火', '戊': '土', '己': '土', '庚': '金', '辛': '金', '壬': '水', '癸': '水',
  '子': '水', '丑': '土', '寅': '木', '卯': '木', '辰': '土', '巳': '火', '午': '火', '未': '土', '申': '金', '酉': '金',
  '戌': '土', '亥': '水',
};

/// Colour of a 五行 element ('木' …) or of a stem/branch character; [dark] for a dark surface.
Color wuxingColor(String elementOrChar, {bool dark = false}) {
  switch (_stemBranchElement[elementOrChar] ?? elementOrChar) {
    case '木':
      return dark ? AppColors.woodDark : AppColors.wood;
    case '火':
      return dark ? AppColors.fireDark : AppColors.fire;
    case '土':
      return dark ? AppColors.earthDark : AppColors.earth;
    case '金':
      return dark ? AppColors.metalDark : AppColors.metal;
    case '水':
      return dark ? AppColors.waterDark : AppColors.water;
  }
  return Colors.grey;
}

/// [wuxingColor] for the theme in [context] (light or dark).
Color wuxingColorOf(BuildContext context, String elementOrChar) =>
    wuxingColor(elementOrChar, dark: Theme.of(context).brightness == Brightness.dark);

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  );
  final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.field));
  // Keyboard focus: the same clear outline on every button and chip.
  final focusSide = WidgetStateBorderSide.resolveWith(
    (states) => states.contains(WidgetState.focused) ? focusOutline(scheme) : null,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: scheme.surface,
    // Focus tint of list rows, section headers and cards (Material's default is faint grey).
    focusColor: scheme.primary.withValues(alpha: 0.14),
    // One transition everywhere: shared-axis style zoom + fade.
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        for (final p in TargetPlatform.values) p: const ZoomPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 2,
    ),
    cardTheme: CardThemeData(
      margin: const EdgeInsets.only(bottom: Space.m),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.card)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: Space.m + 2),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.field), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.field), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.field),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
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
    chipTheme: ChipThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.chip)), side: focusSide),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.5), space: Space.xl),
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
