import 'package:flutter/material.dart';

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
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.accent, brightness: brightness);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    cardTheme: const CardThemeData(margin: EdgeInsets.symmetric(vertical: 6)),
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
