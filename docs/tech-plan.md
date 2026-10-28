# 技术文档：改进计划 (tech plan)

Owner request (2026-10-27): turn the review of the algorithms, code, 玩法 and UI into a staged plan, then work
through it. Payment and login are out of scope for now. How the plan is worked (stages, versions, stage summaries,
finishing steps, when to push): [.claude/skills/dev-workflow/SKILL.md](../.claude/skills/dev-workflow/SKILL.md).

## Rules for every work package

- CLAUDE.md hard rules: ChartFact is additive-only (new facts are new optional fields, and the schema gets new optional
  properties); engines compute, the AI only interprets; each method stands alone (rule 8); one source per fact (rule 4:
  app data and fixtures only through `npm run sync:app`).
- Lessons we must not repeat (docs/agent/MISTAKES.md, global rules). Read the ones listed in a work package before
  starting it:
  - **G7, P12**: work out every expected value independently (by hand or from a reference) and write the arithmetic
    into the test comment. Never edit an expectation to match the output.
  - **G4**: measure a library against an independent reference before relying on it (e.g. lunar-javascript's 命宫 /
    胎元 against the textbook formulas).
  - **P23**: after any change to `app/pubspec.yaml`, run `flutter pub get` and `flutter gen-l10n` through a throwaway
    junction, check git status, remove the junction, then run the harness.
  - **P15**: never run `dart format` on existing files. **P19**: pump between `enterText` and the next key.
    **P24**: pump an empty widget before a second `testApp` in one test. **P22**: goldens are 1× logical pixels.
    **G12**: scroll to lazily built widgets before finding them.
  - **G18**: after any 繁 ↔ 简 conversion, check the one-to-many characters (乾/干, 後/后, 鍾/钟, 髮/发).
  - **P2**: script-generated files stay out of formatters and linters.

## Stages

| Stage                      | What                                                        | Size   | Release when done | Status      |
| -------------------------- | ----------------------------------------------------------- | ------ | ----------------- | ----------- |
| S1 八字引擎：完整、确定    | ages, day basis, relations, 神煞, 旺衰, engine trend scores | big    | v2.0.0 + summary  | in progress |
| S2 方法独立 + 塔罗解读结构 | own prompts for every method; tarot-native reading          | medium | v2.1.0            | planned     |
| S3 塔罗体验                | cards on readings, 每日一牌, 图鉴, more spreads, the ritual | big    | v3.0.0 + summary  | planned     |
| S4 八字与全局 UI           | 五行 colours, term tips, timeline, home, reading page       | big    | v4.0.0 + summary  | planned     |
| S5 数据持久化              | readings survive a restart (PGlite store, encrypted)        | medium | v4.1.0            | planned     |
| S6 新玩法                  | 易经起卦 (六爻 / 梅花) as its own method, 合婚              | big    | v5.0.0 + summary  | planned     |

Inside a big stage, finished work packages go out as medium (X.Y.0) or small (X.Y.Z) releases; the stage's last
release is its X.0.0, with the stage summary below.

## S1 八字引擎：完整、确定 (big → v2.0.0)

Releases: **v1.3.0** = WP1.1–1.5 (fixes and the missing tables); **v2.0.0** = WP1.6–1.7 (strength and engine trend
scores) + the S1 summary. Lessons to read first: G4, G7, P12, P23.

### WP1.1 One age convention

- Now: `liunian[].age` = year − civil birth year; `dayun.cycles[].start_age` = lunar-javascript's 虚岁 (start year −
  birth year + 1, the birth year taken in UTC+8). A 大运 and a 流年 of the same year show ages one apart.
- Do: add `age_xu` (虚岁 = year − civil birth year + 1) to every 流年 and every 大运 cycle; keep the old fields (their
  meaning doesn't change). The app, the facts layer and the trend layer show 虚岁 with the label 虚岁; the AI sees both.
- Accept: born 1990-03-15: the 2026 流年 is age 36, 虚岁 37; a 大运 starting in 2026 has 虚岁 37.

### WP1.2 本命卦 on the same day as its hour

- Now: 本命卦 takes the 农历 day from the civil date and the hour from the 时柱 after 真太阳时. When the correction
  crosses midnight (far-west China, Spain in summer) the two come from different days.
- Do: add `lunar_pillar_day`, the 农历 date of the day the pillars are read on (true solar day when applied); the
  yijing engine uses it, the display keeps `lunar` (the 农历生日 people know).
- Accept: 2000-06-15 01:00 in Kashgar (Asia/Shanghai, 75.99°E): true solar ≈ 22:03 on 06-14 → 亥 hour, and the
  本命卦 uses the 农历 of 06-14.

### WP1.3 All 合冲刑害破

- Now: only 六冲 / 六合 between a 流年 branch and the natal branches.
- Do: `relations` on the natal chart (pairs and triples among the four pillars), on every 大运 cycle (with the natal
  chart) and every 流年 (with the natal chart and its 大运). `branch_relations` stays as it is. Types:
  - 天干五合: 甲己 土, 乙庚 金, 丙辛 水, 丁壬 木, 戊癸 火. 天干相冲: 甲庚, 乙辛, 丙壬, 丁癸.
  - 六合: 子丑 土, 寅亥 木, 卯戌 火, 辰酉 金, 巳申 水, 午未 土. 六冲: 子午, 丑未, 寅申, 卯酉, 辰戌, 巳亥.
  - 三合: 申子辰 水, 亥卯未 木, 寅午戌 火, 巳酉丑 金; 半合 = two of them including the middle (子卯午酉).
  - 三会: 寅卯辰 木, 巳午未 火, 申酉戌 金, 亥子丑 水.
  - 相刑: 寅巳申 (and its pairs), 丑戌未 (and its pairs), 子卯; 自刑: 辰辰, 午午, 酉酉, 亥亥.
  - 六害: 子未, 丑午, 寅巳, 卯辰, 申亥, 酉戌. 相破: 子酉, 卯午, 巳申, 寅亥, 辰丑, 戌未.
  - One relation lists its type, its element where it has one, and its members (pillar + character).
- Accept: hand-made charts that hold each type once; the triples only when all three are present.

### WP1.4 空亡, 神煞, 命宫 / 身宫 / 胎元, 流月

- 空亡 from the day pillar's 旬 (and the year pillar's), checked against the 旬 formula, not only lunar-javascript.
- 神煞, a curated set, from fixed tables: 天乙贵人 (甲戊庚 丑未, 乙己 子申, 丙丁 亥酉, 壬癸 卯巳, 辛 午寅), 文昌, 禄神,
  羊刃 (阳干 only), and from the year and day branch: 桃花, 驿马, 华盖. Each lists the natal pillars (and periods)
  that hold it.
- 胎元 by its formula (month stem + 1, month branch + 3), checked against lunar-javascript. 命宫 / 身宫 moved to
  WP1.8: two derivations of the formula disagreed, so they wait for a reference (G4).
- 流月: the twelve months of the current year from 立春: 干支, start date, 十神.
- Accept: tables checked case by case against their 歌诀; 胎元 / 命宫 against hand-computed cases.

### WP1.5 子时流派 as a setting

- The engine supports both schools; the app always sends the default (晚子时 counts as the same day).
- Do: a profile switch 「23:00 后出生：日柱算当天（默认）/ 算次日」 → `options.ziHourSect`.
- Accept: the request carries it; a 23:30 birth gives the next day's 日柱 with 算次日.

### WP1.6 日主旺衰 + 喜用 (扶抑法, simplified)

- Weights: the three other stems 1 each; branches year 1, month 3 (月令), day 1.5, hour 1, each split over its hidden
  stems 0.6 / 0.3 / 0.1 (two: 0.7 / 0.3). Support = the day master's element (比劫) and the one that generates it
  (印); total = everything.
- Verdict: support / total ≥ 0.55 身强, ≤ 0.45 身弱, between 中和. Above 0.8 or below 0.15: flagged as a possible
  专旺 / 从格 for a human; 喜用 not set.
- 喜用: 身弱 → 印, 比劫 favourable; 食伤, 财, 官杀 unfavourable. 身强 → the reverse. 中和 → none set.
- Facts `strength` (method, weights, support, total, ratio, verdict, 得令, 通根 pillars, favourable, unfavourable,
  special). Provenance simplified_rule: 「扶抑法简化计分；未计调候、合化、从格」.
- Accept: hand-computed charts (arithmetic in the test) for each verdict and both flags.

### WP1.7 运势走势 from the engine

- Now: the trend agent (a model) scores every period; the same chart can score differently, and it costs tokens.
- Do: the engine scores every 大运 and 流年 for all six topics from the facts: the period's elements against 喜用 /
  忌, its 十神, and its relations with the natal chart (冲 the day branch or month branch lowers, 合 raises a little,
  刑 / 害 lower a little), each topic weighting the 十神 that concern it, the same for every gender. Score =
  clamp(50 + 35 × composite, 20, 85), with a one-line note from templates in the three languages. Facts `trend`.
- The report's trend layer reads `trend`; the trend agent and `trend@2` leave the 八字 pipeline.
- Accept: the same chart always gives the same scores; a favourable period scores above an unfavourable one with the
  same relations; male and female give the same scores for the same periods.

### WP1.8 命宫 / 身宫 (waiting for a reference)

- Settle the formula against a named source (a 排盘 tool's output for several charts, or a textbook example with its
  answer), then add both as facts. Not before.

## S2 方法独立 + 塔罗解读结构 (medium → v2.1.0)

- WP2.1 Every method's own prompts: `action_tarot`, `remedy_tarot` (no 五行 colours or directions in a tarot plan),
  and astrology's own narrative (or astrology out of the API until it is a real method). The compliance guard stays
  one reviewer for every method; method context goes into its user message only. Test: no two methods share a
  reading prompt; every prompt version keeps its hash.
- WP2.2 A tarot-native reading: sections 逐张解读 / 综合 / 建议 instead of 八字's four topics, with an optional focus
  (事业, 感情, 健康, 自我) beside the question.

## S3 塔罗体验 (big → v3.0.0)

- WP3.1 The reading page and 历史记录 show the spread with its art.
- WP3.2 Each spread drawn small in the picker (positions before drawing); example questions as chips; the Celtic
  Cross list at 1.5× text.
- WP3.3 每日一牌: draw id from the account and the date, so the card stays the same all day; on 首页.
- WP3.4 牌义图鉴: all 78 cards with their art and keywords (from the art; 繁 by OpenCC and checked by G18; English
  written to the RWS meanings), one source in `deck.ts`.
- WP3.5 More spreads: 二选一 (five cards) and 关系牌阵 (six), with positions, meanings, layouts and their method in
  the tarot prompt.
- WP3.6 洗牌 → 切牌 → 选牌: the engine still shuffles; the user's picks are positions in the seeded deck, stored in
  the draw so the audit replays it.

## S4 八字与全局 UI (big → v4.0.0)

- WP4.1 Stems and branches coloured by 五行; 藏干 / 长生 / 纳音 rows folded under 更多.
- WP4.2 Term tips: a glossary (十神, 十二长生, 纳音, 空亡, 神煞, 大运, 流年, 旺衰 …) in three languages, one source on
  the server, synced; tapping a term opens its plain explanation.
- WP4.3 Timeline: the current 大运 and 流年 marked; tapping a 大运 shows its ten years; 流月 shown.
- WP4.4 首页: 一生运势报告 as its own entry, 今日 (每日一牌), recent readings.
- WP4.5 Reading page: the chart or spread on top, a jump list, share as an image.
- WP4.6 Split `life_report_page.dart` (991 lines) and `profiles_page.dart` (596) into widgets.

## S5 数据持久化 (medium → v4.1.0)

- WP5.1 A PGlite store on disk (`db/schema_v0.sql` and migrations) behind the same `Store` interface, report and fact
  bodies encrypted (AES-GCM, key in `.env`), data in a git-ignored folder; the store tests run on both stores.

## S6 新玩法 (big → v5.0.0)

- WP6.1 易经起卦 as its own method: 六爻 (three coins, six tosses: 本卦, 变卦, 动爻) and 梅花 (time or numbers),
  its own engine, prompts and screens.
- WP6.2 合婚 between two saved profiles: 日柱 / 年柱 relations, 五行 complement, 生肖, its own prompt (every relationship
  type the same, never a prediction of a breakup).

## 阶段总结 (stage summaries)

Written when a stage completes, before its X.0.0 release (dev-workflow skill).

## Status

| WP    | Status                     | Release |
| ----- | -------------------------- | ------- |
| WP1.1 | done                       | v1.3.0  |
| WP1.2 | done                       | v1.3.0  |
| WP1.3 | done                       | v1.3.0  |
| WP1.4 | done (命宫 / 身宫 → WP1.8) | v1.3.0  |
| WP1.5 | done                       | v1.3.0  |
| WP1.6 | todo                       | v2.0.0  |
| WP1.7 | todo                       | v2.0.0  |
| WP1.8 | waiting for a reference    | —       |
| S2–S6 | todo                       | above   |
