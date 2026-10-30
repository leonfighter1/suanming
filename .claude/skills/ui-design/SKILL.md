---
name: ui-design
description:
  The design system of 命理大师 and its 管理后台 - the colour tokens and the light and dark themes, the grid, spacing,
  type scale, radii, alignment and motion, and the dashboard's figures and layout. Use when adding or changing any
  screen, widget, colour, size or layout in app/ or admin/, before choosing a colour, a padding, a font size or a
  breakpoint. The steps that finish every update are in the dev-workflow skill.
---

# UI design (命理大师 and its 管理后台)

The owner asked for this system on 2026-10-30 (tech plan S24):

> 「对于dashboard 可以采用非对称Dashboard布局，以大数字为视觉锚点，辅助数据采用紧凑网格，右侧设置独立纵向面板 通过模块比例，字号和
> 留白建立信息层级，在结合UI设计Skill， 对整个app进一步统一网格系统，组件间距，字体比例和对齐规则，让整个页面更有秩序。建立统一的
> 浅色和深色主题系统，分别定义背景，卡片，文字和强调色，切换主题时保持布局和组件结构不变，让颜色，边框和状态自然过渡。」

The app and the dashboard share one system: the dashboard depends on `../app` and uses the same theme, tokens and
building blocks. Every screen change follows the rules below, and the tests at the bottom hold the code to them.

## Where things are

| What                                      | File                                                                                                 |
| ----------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| Colour tokens, both themes side by side   | `app/lib/presentation/tokens.dart` `ThemeTokens.light`, `ThemeTokens.dark`                           |
| The theme made from them                  | `app/lib/presentation/theme.dart` `buildTheme`, `wuxingColorOf`                                      |
| Spacing, radii, motion, cards, focus ring | `app/lib/presentation/design.dart` `Space`, `Radii`, `Motion`, `AppCard`, `FocusRing`                |
| 外观 (the theme switch)                   | app: `widgets/app_menu.dart` `pickTheme`; dashboard: `admin/lib/presentation/shell.dart` `ThemeMenu` |
| Tests                                     | `app/test/theme_test.dart`, `admin/test/theme_test.dart`                                             |

## Colour

### The tokens

Each theme defines the same tokens (`ThemeTokens`). Material's roles are the same colours under Material's names, so
code may use either; prefer the token's name where Material has no role.

| Token                        | Light     | Dark      | Material role                            | Use                                                |
| ---------------------------- | --------- | --------- | ---------------------------------------- | -------------------------------------------------- |
| `background`                 | `#F6F3EE` | `#121010` | `surface`                                | the page behind everything                         |
| `card`                       | `#FFFFFF` | `#1C1917` | `surfaceContainerLow`                    | a card, the side panel, the menu                   |
| `raised`                     | `#FFFFFF` | `#24201D` | `surfaceContainerHigh`                   | a dialog, a sheet, a menu that opens               |
| `inset`                      | `#F0EBE4` | `#27221F` | `surfaceContainerHighest`                | a tile, a field or a figure inside a card          |
| `border`                     | `#E3DCD2` | `#37302B` | `outlineVariant`                         | the hairline round a card, between rows, gridlines |
| `borderStrong`               | `#C9BFB2` | `#50463F` | `outline`                                | a field's outline, a chart's axis                  |
| `text`                       | `#1F1A16` | `#F2EDE7` | `onSurface`                              | headings and body text                             |
| `textSecondary`              | `#5A5049` | `#C3B9AF` | `onSurfaceVariant`                       | details, captions, a figure's label                |
| `textMuted`                  | `#6F655D` | `#A0958B` | none                                     | hints, placeholders, axis ticks                    |
| `accent`, `onAccent`         | `#8A3B2E` | `#E6917D` | `primary`, `onPrimary`                   | the main button, the chosen item, a figure's value |
| `accentSoft`, `onAccentSoft` | `#F6E7E2` | `#3D2621` | `primaryContainer`, `secondaryContainer` | a chosen segment or chip, an icon's tile           |
| `success`, `warning`, `info` | see file  | see file  | none                                     | states, each with a `…Soft` fill                   |
| `danger`, `dangerSoft`       | `#B3261E` | `#F2B8B5` | `error`, `errorContainer`                | errors, a destructive button                       |
| `wood` … `water`             | see file  | see file  | none                                     | the 五行 (`wuxingColorOf`)                         |
| `series`                     | 7 slots   | 7 slots   | none                                     | chart lines and bars, in order, never cycled       |

Contrast is a test (`theme_test.dart`): every text colour, the accent, the states and the 五行 are at least 4.5 : 1 on
background, card, raised and inset in both themes, and each "on" colour on its fill. A new token gets a row there.

### Rules

1. **Never write a colour in a widget.** Take it from the theme: `Theme.of(context).colorScheme.<role>` or
   `ThemeTokens.of(context).<token>`. Raw `Color(0x…)` belongs in tokens.dart and in things drawn as objects (the coins,
   the 签, the tarot backs, the title's mark).
2. **Never pick a colour by brightness** (`brightness == Brightness.dark`): during a change of theme the brightness
   flips half-way and the colour would jump. Something drawn whose colour differs by theme uses
   `ThemeTokens.of(context).pick(light, dark)`, and a painter takes `darkness` (0 light, 1 dark), so it fades with the
   rest.
3. **One accent per area:** the main action, the chosen item or the figure that matters. Everything else is text,
   secondary or muted.
4. **A state is never colour alone:** a success, warning or error carries an icon and a word.
5. **Charts** take `ThemeTokens.series` in its order and never cycle it (the dataviz skill); a series keeps its slot
   whatever the filter shows.

## Light and dark

- **Same layout, colours only.** Both themes have the same fields, the same borders (width), paddings and widgets.
  `theme_test` lays the home page out in both, with the menu open too, and finds every box in the same place.
- **The switch:** 外观 (跟随系统, 浅色, 深色) in the app's ☰ menu, kept on the device like the language
  (`SettingsStore.theme`); in the dashboard's bar, kept in the browser (`prefsProvider`).
- **The change fades:** `MaterialApp(themeAnimationStyle: AnimationStyle(duration: Motion.theme, curve:
Motion.themeCurve))`. Every colour lerps: the Material scheme and `ThemeTokens` (a `ThemeExtension`). The tests switch
  the theme and check colours half-way, the 五行 and the chart series too.
- **Component themes:** a `WidgetStateProperty` in a component theme resolves to a value for every state, the empty
  set included. `ChipThemeData.lerp`, which every change of theme runs, fails on null (rule 76).
- **States:** hover, press and focus tints are Material's state layers on the token colours. The keyboard focus outline
  (`focusOutline`, the text colour, 2.5 outside the edge) fades in over `Motion.fast` (`FocusRing`). A chosen item is
  `accentSoft` with `onAccentSoft`; a disabled one Material's 38 %.

## Motion

| Token           | Value  | For                                                 |
| --------------- | ------ | --------------------------------------------------- |
| `Motion.fast`   | 150 ms | a state: hover, focus, a choice                     |
| `Motion.medium` | 250 ms | a size: a card that grows                           |
| `Motion.theme`  | 300 ms | light ↔ dark (`Motion.themeCurve`, ease in and out) |
| `Motion.enter`  | 420 ms | an entrance (`FadeSlideIn`)                         |

Things that move or grow use `Motion.curve` (ease out). Reduce motion (`MediaQuery.disableAnimations`) jumps.

## Tests that hold the rules

| Test                                | Checks                                                                                                                                        |
| ----------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| `app/test/theme_test.dart`          | token contrast; Material's roles are the tokens; same layout in both themes; 外觀 fades, half-way colours, kept on the device; start-up theme |
| `admin/test/theme_test.dart`        | the bar's 外观: half-way colours, same layout, kept in the browser; Tab, Enter, ↓                                                             |
| `app/test/wuxing_colours_test.dart` | the 五行 on page, card and inset                                                                                                              |
