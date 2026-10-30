import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// The colours of one theme (tech plan S24 WP24.1; the ui-design skill). Each theme defines its background, card,
/// text and accent (owner, 2026-10-30), and with them the borders, the status colours, the 五行 and the chart series.
/// [buildTheme] makes the Material scheme from these and puts them in the theme as an extension, so nothing else
/// defines a colour of the interface. Light and dark have the same fields: a theme change changes colours, never a
/// layout. A change of theme lerps every field ([lerp]), so colours fade instead of jumping halfway through.
///
/// Contrast (app/test/theme_test.dart): text, secondary, muted, accent, the status colours and the 五行 at least 4.5 : 1
/// on background, card and inset; on-accent on accent, each status colour on its soft fill.
@immutable
class ThemeTokens extends ThemeExtension<ThemeTokens> {
  const ThemeTokens({
    required this.brightness,
    required this.darkness,
    required this.background,
    required this.card,
    required this.raised,
    required this.inset,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.onAccentSoft,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.onDanger,
    required this.dangerSoft,
    required this.onDangerSoft,
    required this.info,
    required this.infoSoft,
    required this.inverse,
    required this.onInverse,
    required this.wood,
    required this.fire,
    required this.earth,
    required this.metal,
    required this.water,
    required this.series,
  });

  final Brightness brightness;

  /// 0 in the light theme, 1 in the dark, in between while the theme changes: what [pick] mixes by.
  final double darkness;

  /// The page behind everything.
  final Color background;

  /// A card, the side panel, the menu.
  final Color card;

  /// What lies above a card: a dialog, a sheet, a menu that opens.
  final Color raised;

  /// A tile, a field or a figure inside a card.
  final Color inset;

  /// The hairline round a card, between rows, a chart's gridlines.
  final Color border;

  /// A field's outline, a chart's axis.
  final Color borderStrong;

  /// Headings and body text.
  final Color text;

  /// Supporting text: details, captions, a figure's label.
  final Color textSecondary;

  /// Hints, placeholders, axis ticks; still 4.5 : 1 on every surface.
  final Color textMuted;

  /// The brand's cinnabar (朱砂): the main button, the selected item, links, a figure's value.
  final Color accent;
  final Color onAccent;

  /// A selected or highlighted fill (a chosen segment, an icon's tile), with its text.
  final Color accentSoft;
  final Color onAccentSoft;

  /// States, each with a soft fill. Never colour alone: an icon and a word go with them.
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color onDanger;
  final Color dangerSoft;
  final Color onDangerSoft;
  final Color info;
  final Color infoSoft;

  /// A SnackBar and a tooltip: the other theme's surface.
  final Color inverse;
  final Color onInverse;

  /// The 五行, as text and bars.
  final Color wood;
  final Color fire;
  final Color earth;
  final Color metal;
  final Color water;

  /// Chart series in this order, never cycled: seven slots (the 八字 trend's topics; the dashboard uses the first
  /// three). Validated with the dataviz skill's validator on [card]: below 3 : 1 in light, green, yellow and pink rely
  /// on the legend and a table, which every chart here has.
  final List<Color> series;

  static const light = ThemeTokens(
    brightness: Brightness.light,
    darkness: 0,
    background: Color(0xFFF6F3EE),
    card: Color(0xFFFFFFFF),
    raised: Color(0xFFFFFFFF),
    inset: Color(0xFFF0EBE4),
    border: Color(0xFFE3DCD2),
    borderStrong: Color(0xFFC9BFB2),
    text: Color(0xFF1F1A16),
    textSecondary: Color(0xFF5A5049),
    textMuted: Color(0xFF6F655D),
    accent: Color(0xFF8A3B2E),
    onAccent: Color(0xFFFFFFFF),
    accentSoft: Color(0xFFF6E7E2),
    onAccentSoft: Color(0xFF6B2A1F),
    success: Color(0xFF2E7046),
    successSoft: Color(0xFFE3F0E6),
    warning: Color(0xFF865800),
    warningSoft: Color(0xFFF7EBD3),
    danger: Color(0xFFB3261E),
    onDanger: Color(0xFFFFFFFF),
    dangerSoft: Color(0xFFFBE4E1),
    onDangerSoft: Color(0xFF6E1A14),
    info: Color(0xFF2B5F8F),
    infoSoft: Color(0xFFE2ECF6),
    inverse: Color(0xFF2F2925),
    onInverse: Color(0xFFF5EFE9),
    // 五行 on a light surface (v3.1.0; 金 darker in v12.1.0 to read on the inset too).
    wood: Color(0xFF387449),
    fire: Color(0xFFC0392B),
    earth: Color(0xFF8D6224),
    metal: Color(0xFF666666),
    water: Color(0xFF2B5F8F),
    series: [
      Color(0xFF2A78D6),
      Color(0xFFEB6834),
      Color(0xFF1BAF7A),
      Color(0xFFEDA100),
      Color(0xFFE87BA4),
      Color(0xFF008300),
      Color(0xFF6250D6),
    ],
  );

  static const dark = ThemeTokens(
    brightness: Brightness.dark,
    darkness: 1,
    background: Color(0xFF121010),
    card: Color(0xFF1C1917),
    raised: Color(0xFF24201D),
    inset: Color(0xFF27221F),
    border: Color(0xFF37302B),
    borderStrong: Color(0xFF50463F),
    text: Color(0xFFF2EDE7),
    textSecondary: Color(0xFFC3B9AF),
    textMuted: Color(0xFFA0958B),
    accent: Color(0xFFE6917D),
    onAccent: Color(0xFF2E0F09),
    accentSoft: Color(0xFF3D2621),
    onAccentSoft: Color(0xFFF7CFC5),
    success: Color(0xFF7DCB98),
    successSoft: Color(0xFF1E3326),
    warning: Color(0xFFE6BA5C),
    warningSoft: Color(0xFF3A2E16),
    danger: Color(0xFFF2B8B5),
    onDanger: Color(0xFF601410),
    dangerSoft: Color(0xFF41221F),
    onDangerSoft: Color(0xFFF9DEDC),
    info: Color(0xFF8DB8E8),
    infoSoft: Color(0xFF1D2B3A),
    inverse: Color(0xFFEDE7E0),
    onInverse: Color(0xFF2A2420),
    wood: Color(0xFF7CC08A),
    fire: Color(0xFFEF7B6E),
    earth: Color(0xFFD9A55B),
    metal: Color(0xFFBDBDBD),
    water: Color(0xFF7FB2E5),
    series: [
      Color(0xFF3987E5),
      Color(0xFFD95926),
      Color(0xFF199E70),
      Color(0xFFC98500),
      Color(0xFFD55181),
      Color(0xFF008300),
      Color(0xFF9085E9),
    ],
  );

  /// The tokens of the theme round [context]: mixed while the theme changes. Under a theme not made by buildTheme (a
  /// bare MaterialApp in a test), the tokens of its brightness.
  static ThemeTokens of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<ThemeTokens>() ?? forBrightness(theme.brightness);
  }

  /// The tokens of a theme, outside a widget (a painter's default, a test).
  static ThemeTokens forBrightness(Brightness brightness) => brightness == Brightness.dark ? dark : light;

  /// A colour of something drawn (a lot's paper, the title's mark) that differs by theme: [lightColour] in the light
  /// theme, [darkColour] in the dark, mixed while the theme changes, so it fades with everything else.
  Color pick(Color lightColour, Color darkColour) => Color.lerp(lightColour, darkColour, darkness)!;

  /// The colour of a 五行 element ('木' …); grey for anything else.
  Color wuxing(String element) => switch (element) {
        '木' => wood,
        '火' => fire,
        '土' => earth,
        '金' => metal,
        '水' => water,
        _ => textMuted,
      };

  /// The tokens are fixed: a variant is a theme of its own.
  @override
  ThemeTokens copyWith() => this;

  @override
  ThemeTokens lerp(ThemeTokens? other, double t) {
    if (other == null || identical(this, other)) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return ThemeTokens(
      brightness: t < 0.5 ? brightness : other.brightness,
      darkness: lerpDouble(darkness, other.darkness, t)!,
      background: c(background, other.background),
      card: c(card, other.card),
      raised: c(raised, other.raised),
      inset: c(inset, other.inset),
      border: c(border, other.border),
      borderStrong: c(borderStrong, other.borderStrong),
      text: c(text, other.text),
      textSecondary: c(textSecondary, other.textSecondary),
      textMuted: c(textMuted, other.textMuted),
      accent: c(accent, other.accent),
      onAccent: c(onAccent, other.onAccent),
      accentSoft: c(accentSoft, other.accentSoft),
      onAccentSoft: c(onAccentSoft, other.onAccentSoft),
      success: c(success, other.success),
      successSoft: c(successSoft, other.successSoft),
      warning: c(warning, other.warning),
      warningSoft: c(warningSoft, other.warningSoft),
      danger: c(danger, other.danger),
      onDanger: c(onDanger, other.onDanger),
      dangerSoft: c(dangerSoft, other.dangerSoft),
      onDangerSoft: c(onDangerSoft, other.onDangerSoft),
      info: c(info, other.info),
      infoSoft: c(infoSoft, other.infoSoft),
      inverse: c(inverse, other.inverse),
      onInverse: c(onInverse, other.onInverse),
      wood: c(wood, other.wood),
      fire: c(fire, other.fire),
      earth: c(earth, other.earth),
      metal: c(metal, other.metal),
      water: c(water, other.water),
      series: [for (var i = 0; i < series.length; i++) c(series[i], other.series[i])],
    );
  }
}
