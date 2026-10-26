import 'package:flutter/material.dart';

import 'design.dart';

class AppColors {
  static const accent = Color(0xFF8A3B2E);
  static const wood = Color(0xFF3F7D4E);
  static const fire = Color(0xFFC0392B);
  static const earth = Color(0xFFA0712C);
  static const metal = Color(0xFF8C8C8C);
  static const water = Color(0xFF2B5F8F);
}

const _stemBranchElement = {
  '甲': '木', '乙': '木', '丙': '火', '丁': '火', '戊': '土', '己': '土', '庚': '金', '辛': '金', '壬': '水', '癸': '水',
  '子': '水', '丑': '土', '寅': '木', '卯': '木', '辰': '土', '巳': '火', '午': '火', '未': '土', '申': '金', '酉': '金',
  '戌': '土', '亥': '水',
};

/// Colour of a 五行 element ('木' …) or of a stem/branch character.
Color wuxingColor(String elementOrChar) {
  switch (_stemBranchElement[elementOrChar] ?? elementOrChar) {
    case '木':
      return AppColors.wood;
    case '火':
      return AppColors.fire;
    case '土':
      return AppColors.earth;
    case '金':
      return AppColors.metal;
    case '水':
      return AppColors.water;
  }
  return Colors.grey;
}

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  );
  final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.field));
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: scheme.surface,
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
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: rounded),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: rounded),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(style: SegmentedButton.styleFrom(shape: rounded)),
    chipTheme: ChipThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.chip))),
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
              TextSpan(text: ch, style: TextStyle(color: wuxingColor(ch))),
          ],
        ),
        style: TextStyle(fontSize: size, fontWeight: FontWeight.w600),
      );
}
