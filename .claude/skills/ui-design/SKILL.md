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
| Long text, empty pages, marks before text | `app/lib/presentation/design.dart` `ReadingText`, `EmptyState`, `firstLineInset`                     |
| The type ramp                             | `app/lib/presentation/theme.dart` `_ramp` (through `Theme.of(context).textTheme`)                    |
| Window classes, columns, page padding     | `app/lib/presentation/layout.dart` `WindowClass`, `Grid`, `pagePadding`                              |
| 外观 (the theme switch)                   | app: `widgets/app_menu.dart` `pickTheme`; dashboard: `admin/lib/presentation/shell.dart` menu → 外观 |
| The rules as checks                       | `app/test/design_rules.dart` (run by `grid_test.dart` and `admin/test/design_rules_test.dart`)       |
| Tests                                     | `app/test/theme_test.dart`, `app/test/grid_test.dart`, `admin/test/theme_test.dart`                  |

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
Staff's own colours in 内容's HTML (S34) meet the same bar where they are written: the editor previews a text in both
themes and warns below 4.5 : 1 (`contrastRatio` in tokens.dart).

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
- **The switch:** 外观 in the app's ☰ menu, kept on the device like the language (`SettingsStore.theme`); in the
  dashboard's bar, kept in the browser (`prefsProvider`).
  - The app offers 跟随时间, 跟随系统, 浅色 and 深色.
  - 跟随时间 (S27) is the default where nothing was picked: dark from 19:00 to 06:00 local time, light otherwise.
    `nightProvider` turns it by itself at 06:00 and 19:00 (owner, 2026-10-30: 「当地时间7点到第二天凌晨6点为深色，其余为
    浅色」).
  - The app's banner (首页, the sign-in page) shows the time of day, whatever 外观 is: `sunOrMoon` gives the sun by
    day and the moon at night.
  - Every banner (`HeroBanner`: 首页, the sign-in page, each method's page, 八字's chart) stands on 命理罗盘
    (`bannerArt`; owner, 2026-10-30: 「Update the banner background using this … luopan.svg for all pages」), the
    owner's art from JingyaoPaint, made into `app/assets/art` by `npm run mirror:banner`. The art is night in both
    themes, so the banner doesn't change with 外观: its words take the dark theme's text colours, over the art's own
    night laid deepest under them, and what a page puts on it (`trailing`, 八字's day pillar) reads the dark tokens.
- **The change fades:** `MaterialApp(themeAnimationStyle: AnimationStyle(duration: Motion.theme, curve:
Motion.themeCurve))`. Every colour lerps: the Material scheme and `ThemeTokens` (a `ThemeExtension`). The tests switch
  the theme and check colours half-way, the 五行 and the chart series too.
- **Component themes:** a `WidgetStateProperty` in a component theme resolves to a value for every state, the empty
  set included. `ChipThemeData.lerp`, which every change of theme runs, fails on null (rule 76).
- **States:** hover, press and focus tints are Material's state layers on the token colours. The keyboard focus outline
  (`focusOutline`, the text colour, 2.5 outside the edge) fades in over `Motion.fast` (`FocusRing`). A chosen item is
  `accentSoft` with `onAccentSoft`; a disabled one Material's 38 %.

## Motion

| Token                      | Value              | For                                                                           |
| -------------------------- | ------------------ | ----------------------------------------------------------------------------- |
| `Motion.fast`              | 150 ms             | a state: hover, focus, a choice                                               |
| `Motion.medium`            | 250 ms             | a size: a card that grows                                                     |
| `Motion.theme`             | 300 ms             | light ↔ dark (`Motion.themeCurve`, ease in and out)                           |
| `Motion.enter`             | 420 ms             | an entrance (`FadeSlideIn`)                                                   |
| `Motion.press`             | 100 ms             | a press going in (`PressBounce`, to 96 %)                                     |
| `Motion.pressSpring`       | spring             | a press let go: about 1.4 % past 100 %, settled in about half a second        |
| `Motion.switchSpring`      | spring             | a switch's thumb: a little past its end, settled in about a third of a second |
| `Motion.roll`, `rollCurve` | 600 ms, decelerate | a number rolling to its new value (`RollingNumber`)                           |
| `Motion.skeleton`          | 1200 ms            | a skeleton's bars breathing (`Skeleton`)                                      |
| `Motion.signOut`           | 500 ms             | 登出: 首页 sinks back and fades as the introduction page comes forward (S29)  |

Things that move or grow use `Motion.curve` (ease out). Reduce motion (`MediaQuery.disableAnimations`) jumps.

## Interactions (S30)

The owner's twelve (2026-10-30: 「对于现在已有的前端各种元素 做以下的所有应该有的元素交互功能」), each where the app has the
element, each from one building block, each still under reduce motion. A new screen gets them by using the blocks.

| #   | Interaction | How                                                                                                                                                                                                                                                                                                                   |
| --- | ----------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | 按压回弹    | `PressBounce`: 96 % while pressed, a spring past 100 % when let go, even on a quick tap. Every button is the app's (`buttons.dart`: `AppFilledButton`, `AppOutlinedButton`, `AppTextButton`, `AppIconButton`, `AppFab`); a tappable `AppCard` and a button-like `Pressable` bounce too, a chart (`onTapDown`) doesn't |
| 2   | 弹性开关    | `AppSwitchTile` with `ElasticSwitch` (`widgets/elastic_switch.dart`): the thumb stretches with its speed, up to a 1.6× capsule, and rests round after a slight rebound; the row is the control                                                                                                                        |
| 3   | 波纹跟手    | the theme's `splashFactory: InkSplash.splashFactory`: the ripple stays centred where the finger went down                                                                                                                                                                                                             |
| 4   | 点赞炸一下  | only for 点赞 and 收藏 buttons; the app has none yet: build it in with the first one                                                                                                                                                                                                                                  |
| 5   | 勾选画出来  | Material's `Checkbox` (and `CheckboxListTile`) draws its tick from the bottom left to the top right in 200 ms: keep Material's                                                                                                                                                                                        |
| 6   | 液态滑块    | no slider yet: a slider's fill, thumb and value move on one duration and curve                                                                                                                                                                                                                                        |
| 7   | 数字滚动    | `RollingNumber<T>`: from the old value to the new on `Motion.roll` / `rollCurve`; its first value at once; screen readers get the end value. 我的积分, the menu, the 管理后台's figures (`HeroFigure` / `StatTile` `number:` + `format:`)                                                                             |
| 8   | 骨架屏      | `Skeleton.cover` over the page's own build of typical data (every text, icon and picture under a bar of its size), or `SkeletonText` / `SkeletonBox` in the item's own frame; nothing moves when the data come                                                                                                        |
| 9   | 卡片翻面    | the tarot card turns about Y and draws each side only while it faces the viewer, the face turned back half a turn (`tarot_spread.dart`); 算卦's coins the same                                                                                                                                                        |
| 10  | 汉堡变叉    | `MenuMorph` (once, app.dart): ☰ and the menu's close button draw `AnimatedIcons.menu_close` from one progress, at the same place                                                                                                                                                                                     |
| 11  | 卡片堆叠    | no stacked cards yet: lower cards offset down and smaller, the top one swiped away                                                                                                                                                                                                                                    |
| 12  | 底部抽屉    | no bottom sheet yet: half and full stops, closed when dragged down past half                                                                                                                                                                                                                                          |

`design_rules.dart` keeps Material's own buttons and switches out of the screens ("Material's own button",
"Material's own switch"): use the app's.

## The grid

Window classes are Material's, by the window's width (`WindowClass.of`, `layout.dart`):

| Class      | Width       | Columns | Margin | Gutter | What                         |
| ---------- | ----------- | ------- | ------ | ------ | ---------------------------- |
| `compact`  | below 600   | 4       | 16     | 16     | a phone                      |
| `medium`   | 600 to 839  | 8       | 24     | 24     | a small tablet, a phone wide |
| `expanded` | 840 to 1199 | 12      | 24     | 24     | a tablet wide, a window      |
| `large`    | 1200 and up | 12      | 32     | 24     | a desktop                    |

- **Every page is in the app's container** (owner, 2026-10-30: 「大于 1620px 时要设置一个max-width 1620px。本体可以是
  fluid…在tablet和mobile device 可以不用有这限制了」, then 「对于所有的页面，基本框架在大屏时都要有这个尺寸限制（包括设置页面）」). A
  page's scrolling list takes `pagePadding(context)`:
  - on a phone and a tablet the content is fluid, with only the class's margin;
  - on a wider window it is at most `Grid.container` (1620) wide and centred, with the margin inside.
  - A list whose rows carry their own inset (设置's tiles, the place picker) takes `pagePadding(margin: false)`: the
    container only.
  - The list keeps its scrollbar at the window's edge. The tarot cards keep their full size (owner v1.1.x), with
    more room.
  - The 管理后台 keeps its own container, 1440 (「管理员界面就不用改了」).
- **Columns on a desktop window** (the large class; 「在超大屏幕布局时可以采用2X2布局。如果只有一个那就采用1x1」):
  - `CardGrid` sets cards two to a row with a gutter between; a card alone in its row spans it. On 首页, 东方's four
    methods are 2 × 2 and 西方's one is 1 × 1. Each group's card of the day follows its methods across the container:
    今日一卦 or 今日一签 under 东方, 今日一牌 under 西方. Its picture is 44 × 76: the card, the lot's slip (`LotSlip`)
    or the hexagram's lines.
  - The sign-in page puts its banner at the left, as tall as the form at the right (5 of 12 columns).
  - The introduction page (S29, 「各种服务的类型 … 2x2 grid」) shows the services as 首页 does: the same groups and
    `CardGrid`, 东方 2 × 2; its 登录 / 注册 spans a phone's column and takes its label's width beyond
    (`compactButtons`).
  - Phones and tablets keep one column.
- **Columns** for a layout of parts side by side: `Grid.span(width, n, columns:, gutter:)`. The dashboard's main column
  and panel are 8 : 4 at large widths.
- **A dialog** keeps its own width (`ConstrainedBox`, 520–640), as Material's dialogs do.

## Spacing

A 4-point scale (`Space`): `xxs` 2, `xs` 4, `s` 8, `m` 12, `l` 16, `xl` 24, `xxl` 32, `xxxl` 48. Named uses:
`Space.card` 20 (inside a card), `Space.field` 14 (a field's text to its edge: a 52-high field, as tall as the main
button), `Space.empty` 96 (above an empty page's message), `Space.fab` 104 (a page's foot under the floating 追问).

| Between                                     | Space                                                |
| ------------------------------------------- | ---------------------------------------------------- |
| an icon and its text; buttons in a row      | `s` (8)                                              |
| a label and its value; a title and its text | `xs` (4)                                             |
| cards in a column                           | `m` (12)                                             |
| inside a card                               | `card` (20)                                          |
| sections of a page; the dashboard's modules | `xl` (24)                                            |
| the page's top / foot                       | `m` / `xxl`                                          |
| `xxs` (2)                                   | only inside small parts (a pill, a key cap, a badge) |

A drawing (a hexagram's lines, a coin, the 签) keeps its own geometry as named constants at the top of its file
(`_lineGap`), never a bare number in `EdgeInsets`.

## Type

One ramp (`buildTheme`'s `_ramp`): sizes 11, 12, 14, 16, 20, 24, 32, 48, line heights in whole even points set for
Chinese text, no letter spacing.

| Role             | Size / line | Weight | Use                                                   |
| ---------------- | ----------- | ------ | ----------------------------------------------------- |
| `displaySmall`   | 48 / 56     | 600    | the one hero figure on a dashboard page               |
| `headlineMedium` | 32 / 40     | 600    | a large figure on a page (我的积分's balance)         |
| `headlineSmall`  | 24 / 32     | 600    | a page's title, a stat tile's value, the banner title |
| `titleLarge`     | 20 / 28     | 600    | a method's name on 首页, a section's title            |
| `titleMedium`    | 16 / 24     | 600    | a card's title                                        |
| `titleSmall`     | 14 / 20     | 600    | a sub-heading, a term, a panel section's title        |
| `bodyLarge`      | 16 / 24     | 400    | fields and list rows                                  |
| `bodyMedium`     | 14 / 22     | 400    | the interface's text (the default)                    |
| `bodySmall`      | 12 / 18     | 400    | details, captions                                     |
| `labelLarge`     | 14 / 20     | 500    | buttons, a figure's label                             |
| `labelMedium`    | 12 / 16     | 500    | small labels, key caps                                |
| `labelSmall`     | 11 / 16     | 600    | pills, chart ticks                                    |

- **Long text** takes `ReadingText`: `body` 16 / 28 for a reading's paragraphs, `small` 14 / 24 for notes, examples
  and intros, `caption` 12 / 20. Never a line height of your own (`height: 1.6`).
- **Numbers** in a column (tables, ticks, a panel's rows) use tabular figures; a figure standing alone (the hero, a
  tile's value) keeps proportional ones (the dataviz skill).
- **Weight** sets hierarchy with size: a title is semibold, a reading's term bold, body regular.

## Radii

`Radii`: `xxs` 2 (a bar, a tiny thumbnail), `xs` 4 (a thumbnail, a key cap, a meter), `chip` 8, `field` 12 (fields,
buttons, segments, a box inside a card), `tile` 16 (an icon's tile), `card` 20, `hero` 24. A rounded box inside another
takes a smaller step than its parent.

## Alignment

1. **One left edge a column.** A section's title starts on its cards' left edge (首页's 东方 and 西方); inside a card,
   everything starts at `Space.card`.
2. **Numbers right-aligned in columns**, with tabular figures (`DataColumn(numeric: true)`, `NumberRow`).
3. **A mark before text that may wrap** (a bullet, an icon) sits centred on the first line:
   `EdgeInsets.only(top: firstLineInset(style, size))`, never a guessed nudge.
4. **Text starts at the start** (left). Only empty states, a hero banner's single line and centred figures centre.
5. **Buttons:** a form's main button spans its column; buttons in a row size to their label (`compactButtons`) with
   the main one last.
6. **A table's row label** sits level with its cells' middle (`Table(defaultVerticalAlignment: middle)`, the 四柱 grid),
   not at their top.
7. **The app bar is the window's,** across its full width; the content below it keeps to its column.
8. **A column inside a panel or card stretches** (`CrossAxisAlignment.stretch`): a Column's default centres its
   children, which pulls short lines off the left edge.

## The dashboard

The 管理后台's pages are asymmetric (owner, 2026-10-30): a hero figure as the anchor, the supporting figures in a
compact grid, and a panel of its own at the right. The building blocks are in
`admin/lib/presentation/widgets/dashboard.dart`; the rules come from the dataviz skill.

- **The container** (owner, 2026-10-30: 「for wider screen user, make sure have a container to limit the size of it」):
  every page, its main column and its panel together, is at most `pageMax` (1440) wide and centred in what the rail
  leaves, the window class's margin inside it (`containerSide`). `PageBody` (a page without a panel: 活跃, 导出) keeps
  to the same container, so every page has one left edge. The app bar and the rail stay the window's.
- **`DashboardLayout(main:, aside:, narrowAt:, panelWidth:)`:** in the container, the main column and, once the
  content is `asideFrom` (1080) wide (a window of 1200 and up beside the rail), the panel at the right: a card of its
  own (card colour, a hairline, `Radii.card`), level with the column's top, as tall as the window lets it be, with a
  scroll of its own; a gutter between. `asideWidth` (360) by default; `asideWide` (480) where it shows a document (the
  消息 editor's mail preview). Narrower, the panel joins the column after `narrowAt` of its parts (the end by default;
  1 where it holds what one does: 用户's filters, an account's actions). The panel is a `Material`, so the switches
  and rows inside show their ink.
- **`HeroFigure`:** one per page, the page's first figure: its label, the value at `displaySmall` (48), its change, a
  caption, and its days as a `Sparkline` beside it (5 : 7) or under it on a narrow card.
- **`StatTile` in a `StatGrid`:** the supporting figures, at `headlineSmall` (24), in one card with hairlines between,
  up to four across (never more columns than tiles), two on a phone. Each value has the key `kpi-<label>`.
- **`Change` and `ChangeLabel`:** against the period before (`Overview.previous`, the server's `previous`), signed,
  with an arrow, coloured by direction and whether up is good (success or danger), grey and 持平 when flat, 无数据 when
  there was nothing before; a ratio's change in 个百分点. Never colour alone.
- **The panel's parts:** `PanelSection` (a heading, a hairline between parts), `NumberRow` (a label and its number at
  the right, tabular figures), `Meter` (a count out of a whole on the accent's soft step).
- **Hierarchy:** size (48, 24, 14, 12), weight, and room: `xl` (24) between modules, `l` (16) inside a tile.
- **The pages:** 概览 leads with 充值收入 (the panel: 此刻在线, 活跃, 账户, 积分); 收益 with 毛利 (the panel: the
  exports, 怎么算); 用量 with Tokens (the panel: each model); 活跃 with who is on now; an account with its 积分余额 (the
  panel: permissions, the role, 增加积分, 在所有设备上退出, as far as the caller's role may); 用户 is its table, the
  search and filters in the panel; 消息 (S25) its messages as cards by channel, two to a row (the panel: how they
  leave, 最近发送), and each message's editor beside its preview (the panel, `asideWide`).
- **By role** (S25): the rail shows only the pages the role may see (a role with one page gets it alone, without a
  rail; an integrator has 消息 and 内容 since S29), and a page leaves out what the server would refuse it. The server
  decides; the dashboard follows.
- **The menu at the top right** (S33): the staff member's name and role open 内容, 消息 and 导出 (as the role may), then
  外观 and 退出登录 (a `MenuAnchor`, its button's focus node its `childFocusNode`, so ↓ moves in). A page of the menu
  leaves the rail without a choice; on a phone it takes the bar's place, with its name and a way back.
- **内容** (S29): the app's texts in the main column, 30 at a time (再显示 adds more), each opening its editor (a dialog,
  both languages, the app's own under each field); the search, 已修改 and the images in the panel, before the texts on
  a narrow screen (`narrowAt: 1`, as 用户). By page since S33: an `ExpansionTile` a page (its headings and rows
  stretched to the tile's left edge), its texts grouped by the way in, each with where else it shows; a text that may
  hold HTML previews it under its field, drawn by the app's `richSpans`.
- **设置** (S31): the settings by group, each group an `AppCard`, each setting its label and line, its control (a number
  with its unit and 保存, 跟随 .env / 开 / 关, a menu, `FilterChip`s for the accepted currencies; S32: the packs' rows,
  元 2 : 积分 3 and the ⊖, at most 400 wide, then 添加套餐 and 保存 last), its default and 恢复默认; the panel says
  what answers AI calls and the rates' day (a warning colour when real tokens are spent, or the rates are stale).
- **Money** shows in 设置's dashboard currency (`yuan()` in format.dart, from the session's `MoneyUnit`): one change in
  the formatter, never at the figures.
- **A mail's preview** is the server's own page in a frame (the web) or its text (elsewhere), light or dark as the
  dashboard is: the mail's colours are `MAIL_PALETTE` (`src/export/render-html.ts`), the app's tokens, held to
  tokens.dart by a test. A sent mail follows the reader's system (`prefers-color-scheme`).

## Checklist for a new screen or widget

1. **Colours** from `Theme.of(context).colorScheme` or `ThemeTokens.of(context)`; a drawn object's two colours through
   `pick` or the theme's `darkness`. A new token goes into both themes and into theme_test's contrast check.
2. **The page's list** takes `pagePadding(context)` (a list of tiles: `margin: false`; a dashboard page:
   `DashboardLayout`); nothing stretches past the container on a wide window.
3. **Every gap and padding** is a `Space` step or a named use; a corner a `Radii` step; a drawing's own geometry a
   named constant.
4. **Text** takes a role of the ramp; long text `ReadingText`; numbers in a column tabular figures.
5. **Alignment:** one left edge, a mark before wrapping text by `firstLineInset`, a column in a card stretched.
6. **Light and dark:** look at it in both (a render with the real font, rule 22); nothing changes but colour.
7. **States** (hover, focus, chosen, disabled) come from the theme and fade (`Motion.fast`); the keyboard-access
   skill's checklist for focus and keys.
8. **A dashboard page:** one hero figure, the rest in a `StatGrid`, each change a `Change` against the period before,
   the page's tools in the panel.
9. **Run** grid_test and the 管理后台's design_rules_test (or the harness): they fail on a broken rule.
10. **Interactions:** buttons from `buttons.dart`, switches as `AppSwitchTile`, changing figures as `RollingNumber`, a
    loading state as a skeleton of the page's own frame (the table above).

## Tests that hold the rules

| Test                                | Checks                                                                                                                                                                                                                                                                                                                  |
| ----------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `app/test/theme_test.dart`          | token contrast; Material's roles are the tokens; same layout in both themes; 外觀 fades, half-way colours, kept on the device; start-up theme                                                                                                                                                                           |
| `admin/test/theme_test.dart`        | the bar's 外观: half-way colours, same layout, kept in the browser; Tab, Enter, ↓                                                                                                                                                                                                                                       |
| `admin/test/dashboard_test.dart`    | the container at 2560 (1440, centred, one left edge for every page); the panel at the right at 1440, its own scroll both ways, after the column at 1024; the hero at 48 or more; four figures to a row; 用户's filters and an account's actions in the panel (before the table on a phone); Tab to who is online, Enter |
| `admin/test/pages_test.dart`        | every figure and its change against the period before: sign, arrow, colour, 较前 N 天                                                                                                                                                                                                                                   |
| `app/test/banner_art_test.dart`     | every banner on 命理罗盘 (the sign-in page, 首页, each method); its words, and 八字's day pillar, in the dark theme's colours in either theme                                                                                                                                                                           |
| `app/test/interactions_test.dart`   | the twelve interactions: the press and its spring, the switch's stretch and keys, the ripple's place, the rolling numbers, the skeletons' places (以往记录, 我的积分), ☰ → ✕                                                                                                                                           |
| `app/test/wuxing_colours_test.dart` | the 五行 on page, card and inset                                                                                                                                                                                                                                                                                        |
| `app/test/grid_test.dart`           | window classes; the type ramp; 首页 at 390 to 2560 (the 1620 container, 2 × 2, 1 × 1, titles on the cards' edge); the sign-in page; every page at 2560; rules                                                                                                                                                           |
| `app/test/design_rules.dart`        | over `lib/presentation` (app) and `lib` (dashboard): no raw or named colour, brightness check, font size, number in `EdgeInsets` or as a gap, `Space`/`Radii` plus a number, number as a corner, role off the ramp, `Space.page`, line height of one's own                                                              |

A drawn object (coins, the 签 and its tube, tarot backs, the title's mark) may break the colour, size and corner rules
in its own file (`drawings` in design_rules.dart): its colours are the object's, not the interface's.
