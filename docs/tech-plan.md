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
| S1 八字引擎：完整、确定    | ages, day basis, relations, 神煞, 旺衰, engine trend scores | big    | v2.0.0 + summary  | done        |
| S2 方法独立 + 塔罗解读结构 | own prompts for every method; tarot-native reading          | medium | v2.1.0–v2.3.0     | done        |
| S3 塔罗体验                | cards on readings, 每日一牌, 图鉴, more spreads, the ritual | big    | v3.0.0 + summary  | in progress |
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

- Weights (as built in v2.0.0): the 100-point position scheme. 年干 8, 月干 12, 时干 12, 年支 4, 月支 40 (月令), 日支
  12, 时支 12; each branch split over its hidden stems 0.6 / 0.3 / 0.1 (two: 0.7 / 0.3). Support = the points of the
  day master's element (比劫) and of the one that generates it (印). First planned: stems 1 each, branches 1 / 3 /
  1.5 / 1; replaced (S1 summary).
- Verdict: support ≥ 55 身强, ≤ 45 身弱, between 中和. 80 or more, or 15 or less: flagged as a possible 专旺 / 从格
  for a human; 喜用 not set.
- 喜用: 身弱 → 印, 比劫 favourable; 食伤, 财, 官杀 unfavourable. 身强 → the reverse. 中和 → none set.
- Facts `strength` (method `fuyi_100`, points, by_element, support, verdict, de_ling, tong_gen, favorable,
  unfavorable, special). Provenance simplified_rule: 「扶抑法简化计分（百分制…）；未计调候、合化、从格」.
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
- As built (v2.0.0): 六冲 −0.25 with the day pillar, −0.15 with the month, −0.1 otherwise; 天干相冲 −0.15 with the
  日主, −0.05 otherwise; 相刑 / 自刑 −0.08; 六害 −0.05; 相破 −0.03; 合 +0.06 into a 喜用 element, −0.04 into a 忌
  one, +0.02 otherwise; 天干五合 +0.04; the sum kept within −0.6 … 0.3. 婚姻感情 also weighs the relation with the day
  branch. The scores take no gender. The 一生运势报告 takes its stage scores from `trend` too. Notes name the
  day-branch relation as it is (rule 28).

### WP1.8 命宫 / 身宫 (waiting for a reference)

- Settle the formula against a named source (a 排盘 tool's output for several charts, or a textbook example with its
  answer), then add both as facts. Not before.

## S2 方法独立 + 塔罗解读结构 (medium → v2.1.0–v2.3.0)

Releases, one per work package (medium, committed and tagged locally; pushed with v3.0.0): **v2.1.0** = WP2.1;
**v2.2.0** = WP2.3; **v2.3.0** = WP2.2. Lessons to read first: G7, P12, P26, P28.

- WP2.1 Every method's own prompts: `action_tarot`, `remedy_tarot` (no 五行 colours or directions in a tarot plan),
  and astrology's own narrative (or astrology out of the API until it is a real method). The compliance guard stays
  one reviewer for every method; method context goes into its user message only. Test: no two methods share a
  reading prompt; every prompt version keeps its hash.
  - As built (v2.1.0): `METHOD_PROMPTS` names each method's narrative, action and remedy prompt. 八字:
    `narrative_bazi@5`, `action_bazi@4` (the engine's 喜用 for any element in an action), `remedy_bazi@3` (the
    engine's 喜用 / 忌, ages labelled 虚岁). 塔罗: `narrative_tarot@1`, `action_tarot@1`, `remedy_tarot@1`, with its
    own closing note. Astrology: `narrative_astrology@1` and `action_astrology@1`, and no 破除运势 plan (its chart has
    no houses or transits; the API refuses one with a 400 and preloads none). The 八字 facts layer gained the
    旺衰 / 喜用 line, so the action agent and the report see the engine's judgement. Old versions stay registered;
    `test/method-prompts.test.ts` pins all 15 hashes (the nine older ones taken from the file before the change).
- WP2.2 A tarot-native reading: sections 逐张解读 / 综合 / 建议 instead of 八字's four topics, with an optional focus
  (事业, 感情, 健康, 自我) beside the question.
  - As built (v2.3.0), as designed below, plus: 逐张解读 is exempt from the four-paragraph cap (a Celtic Cross
    has ten cards); a skipped card brings one retry naming its path; a tarot report fixture
    (`report_tarot_passed.json`) for the app; the focus chips are `ChoiceChip`s (they wrap on a phone, and the
    theme gives chips the focus border), tested with Tab and Space.
  - Design (v2.3.0):
    - Sections are tarot's own topic keys `tarot_cards`, `tarot_synthesis` and `tarot_advice`, appended to
      `TOPICS`. 八字 gets an explicit list, since `bazi: TOPICS` would otherwise pick them up (rule 8). The labels
      are 逐张解读 / 综合解读 / 建议.
    - Focus: an optional `focus` on POST /v1/reports, tarot only (`career_wealth`, `relationships`, `health`,
      `personality`). It travels like the question (not stored) into `<focus>` of the tarot reading.
    - `narrative_tarot@2`: one paragraph per card in dealing order (the pipeline checks that every card path is
      cited), the whole story with the answer to the question, then the advice. `action_tarot@2`: 3–5 actions,
      all on `tarot_advice`.
    - Plans: `tarot_cards` and `tarot_synthesis` get none (`NO_PLAN_TOPICS`, refused by the API and never
      preloaded), so a new tarot reading offers one plan, on 建议 (`remedy_tarot@2`). Old tarot reports keep
      their per-area plans.
    - App: focus chips under the question, taken at draw time with it. For tarot, no topic chips (the sections
      are fixed). The plan buttons skip `noPlanTopics` (synced from the server).
    - Accept: the three sections in order, with every card read; the focus reaches the prompt; one plan; old
      tarot reports still show and sell their plans; 八字 untouched (its topics, prompts and hashes).
- WP2.3 (found in S1) What each agent reads. The 八字 facts sent to the narrative agent grew from 3.3k to 17.0k
  characters over S1 (relations and 神煞 on every period, 流月, `trend`), and the guard reads them all too while
  review is on. Give each agent the facts it needs (the natal chart, strength, relations, 神煞, the current 大运, the
  流年 a question is about, the trend basis). Keep every path it may cite resolvable. Measure characters per agent
  before and after.
  - As built (v2.2.0): `src/ai/bazi-view.ts`.
    - A reading's focus (`readingFocus`): the current 大运 and the next, this year and the next two, and any 流年
      year the question names.
    - A plan's focus (`planFocus`): its topic's two lowest-scoring 大运 and three lowest-scoring 流年 from now on.
      Before, a plan could target a 大运 already past.
    - Every other period keeps its place in its list and its 干支, years, ages and 十神, so a cited path means the
      same in the stored chart. `view` names the focus. 流月 is dropped (no prompt read it). The life agents lose
      流月 and the 流年 scores.
    - `narrative_bazi@6` and `remedy_bazi@4` say what the view holds.
    - Found on the way: `checkFaithfulness` didn't know the 干支 of 胎元 and 流月 (rule 29).
    - Measured on the sample: characters sent for a reading, its six plans and the life report went from 304.5k to
      168.2k without the reviewer (−45%), and from 572.3k to 305.3k with it.

## S3 塔罗体验 (big → v3.0.0)

Releases, one per work package (medium, committed and tagged locally): **v2.4.0** = WP3.1, then one X.Y.0 per WP;
the last WP goes out as **v3.0.0** with the S3 summary, pushed together with every release since v2.1.0. Lessons to
read first: P19, P24, P25, P27 (widget tests), G18 (繁简 in card text), P26 (sync before app tests).

- WP3.1 The reading page and 历史记录 show the spread with its art.
  - As built (v2.4.0): the report view carries `chart_id` (additive). The reading page shows a tarot reading's spread
    on top with every card turned (`ReadingSpread`, reusing `TarotSpread`; `FourLayerReport` takes a `header` that
    takes no stagger slot, so 八字 pages animate as before). A tarot item in 历史记录 shows up to five cards' art,
    reversed ones upside down, above their names.
- WP3.2 Each spread drawn small in the picker (positions before drawing); example questions as chips; the Celtic
  Cross list at 1.5× text.
  - As built (v2.5.0): the dropdown became a `SegmentedButton` in `SegmentKeys` (←/→, focus ring), each segment
    carrying a `SpreadDiagram` drawn with the spread's own geometry (`celticRects`). The positions come from deck.ts
    `SPREADS`, newly synced into tarot_deck.json (`Terms.spreadPositions`), in a line under the picker. Four example
    questions as chips fill the field. The Celtic Cross list takes the larger of the spread's text scale and 1.5, so
    phones get 1.5× and wide screens keep 2×.
- WP3.3 每日一牌: draw id from the account and the date, so the card stays the same all day; on 首页.
  - As built (v2.6.0): `GET /v1/tarot/daily?date=` (`src/service/daily.ts`).
    - The draw id and the chart id are version-8 UUIDs from an HMAC of the account and the date under the draw
      key (separate labels), so a card is stable, unguessable and replayable.
    - The date must be within a day of the server's UTC date (any time zone's today; no reading ahead). The
      Geo-Rule runs first.
    - The chart is stored once as the account's own (`ChartRecord.daily`): `GET /v1/charts/{id}` opens it and a
      reading can be asked of it, but `GET /v1/charts` doesn't list it.
    - App: a 今日一牌 card on 首页 after the two entries (hidden when there is none), opening a page with the card
      large and an AI reading request; a Tab stop after `entry-tarot`. `tabTo` moved into `test/keys.dart`.
- WP3.4 牌义图鉴: all 78 cards with their art and keywords (from the art; 繁 by OpenCC and checked by G18; English
  written to the RWS meanings), one source in `deck.ts`.
  - As built (v2.7.0):
    - `npm run build:tarot-keywords` reads the keywords painted on each card from JingyaoPaint's card code (majors
      by `number`, minors from `_meanings[suit][rank]`; 3 per card, all 78 checked) into `data/tarot/keywords.json`.
      简体 is as painted; 繁體 is OpenCC cn → tw, with every one-to-many character listed for review (G18).
    - Review: of 234 keywords, one fix (疗愈 → 療癒, OpenCC kept 愈), kept in `HANT_FIXES` and pinned by a test.
    - English in `keywords-en.ts`. `KEYWORDS` (`src/engines/tarot/keywords.ts`, beside deck.ts: deck.ts has no
      file reads and the build script needs it) is the one source, synced into tarot_deck.json.
    - App: `TarotGlossaryPage` from the 塔罗 bar, the deck in five groups, each card a `Pressable` opening its art
      large with the keywords.
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
- WP4.7 (found in S1) Widget tests reach cards through `scrollTo()` in `test/support.dart` (rule 27). Ten test files
  still call `scrollUntilVisible` directly.

## S5 数据持久化 (medium → v4.1.0)

- WP5.1 A PGlite store on disk (`db/schema_v0.sql` and migrations) behind the same `Store` interface, report and fact
  bodies encrypted (AES-GCM, key in `.env`), data in a git-ignored folder; the store tests run on both stores.

## S6 新玩法 (big → v5.0.0)

- WP6.1 易经起卦 as its own method: 六爻 (three coins, six tosses: 本卦, 变卦, 动爻) and 梅花 (time or numbers),
  its own engine, prompts and screens.
- WP6.2 合婚 between two saved profiles: 日柱 / 年柱 relations, 五行 complement, 生肖, its own prompt (every relationship
  type the same, never a prediction of a breakup).

## 阶段总结 (stage summaries)

Written when a stage completes, before its X.0.0 release (dev-workflow skill). Medium stages get a short one.

### S2 方法独立 + 塔罗解读结构 (done 2026-10-28: v2.1.0–v2.3.0, medium)

1. **Delivered**
   - v2.1.0, WP2.1: `METHOD_PROMPTS`; every method's own narrative, action and plan prompts; astrology without plans.
   - v2.2.0, WP2.3: `bazi-view.ts`, so the AI reads a focused copy of a 八字 chart; the life agents read less too.
   - v2.3.0, WP2.2: tarot's own sections (逐张解读 / 综合解读 / 建议), the focus beside the question, one plan per
     reading.
2. **Numbers**
   - Server tests: 271 → 287. App tests: 90 → 92.
   - Characters sent for a 八字 reading, its six plans and the life report: 304.5k → 168.2k (without the reviewer).
   - Prompt versions pinned by hash: 15.
3. **Changed against the plan**: one release per work package instead of a single v2.1.0. WP2.3 came before WP2.2,
   being smaller and server-only. Astrology kept its readings (its own prompts) but lost its plans.
4. **Mistakes recorded**: rules 27 (widened to ensureVisible), 28, 29 and 30. They teach: run a frame after any jump
   in a widget test; take examples and measurements from real output; keep a checker in step with the facts it
   checks.
5. **Next**: S3 塔罗体验 (big → v3.0.0, pushed with v2.1.0–v2.3.0).

### S1 八字引擎：完整、确定 (done 2026-10-27: v1.3.0 + v2.0.0)

1. **Delivered**
   - v1.3.0:
     - WP1.1: 虚岁 on every 大运 and 流年 (`start_age_xu`, `age_xu`) and in every display.
     - WP1.2: `lunar_pillar_day`, the 本命卦's date.
     - WP1.3: `relations.ts`, all 合冲刑害破 for the chart, every 大运 and every 流年.
     - WP1.4: `shensha.ts`, seven 神煞, 空亡, 胎元 and 流月.
     - WP1.5: the 子时 switch (`options.ziHourSect`).
   - v2.0.0:
     - WP1.6: `strength.ts`, 日主旺衰 with 得令, 通根, 喜用 / 忌 and the 专旺 / 从格 flag, shown on the 五行 card.
     - WP1.7: `trend-scores.ts`, six topic scores for every 大运 and 流年 with what each rests on, and notes from
       templates in three languages.
     - The trend agent left the 八字 pipeline. `narrative_bazi@5` explains the new facts.
     - The 一生运势报告 (`life_methods@2`, `life_topics@2`) labels stages by 虚岁 and takes their scores from the
       engine.
   - Still open: WP1.8 (命宫 / 身宫), waiting for a reference.
2. **Numbers**
   - Server tests: 265 at v1.3.0 (11 new). 271 at v2.0.0 (7 new, 1 rewritten; the test of a blocked trend note went
     with the trend agent).
   - App tests: 90. The 命盘 page test now also checks the strength pills.
   - Every harness run checks 7,000 charts against the oracle and 100,000 tarot draws.
   - The sample chart's facts grew from 3.3k to 13.0k characters at v1.3.0 and 17.0k at v2.0.0 (compact JSON).
   - A 八字 reading makes one model call fewer: narrative and action, plus the guard while review is on.
3. **Changed against the plan**
   - 命宫 / 身宫 moved to WP1.8. Two derivations of the formula disagreed, and no reference was at hand to settle
     them (G4).
   - WP1.6's weights. The planned ones (stems 1 each, branches 1 / 3 / 1.5 / 1) had no source behind them (G4). The
     engine uses the widely cited 100-point position scheme instead, so support reads as points out of 100 against
     the planned thresholds.
   - The 一生运势报告's stage scores come from the engine too. Otherwise the report and the 运势走势 chart could
     disagree about the same 大运.
   - Part of S2's WP2.1 came early. 八字 got its own reading prompt (`narrative_bazi@5`), needed to explain the new
     facts. `narrative@4` stays pinned for astrology, and `trend@2` stays registered for stored reports.
   - Not planned: the facts the model reads grew about 5×. WP2.3 trims them.
4. **Mistakes recorded** (docs/agent/MISTAKES.md):
   - Rule 25: a test looked for a card above the one it had just scrolled to.
   - Rule 26: the app's term table was stale after editing i18n/terms.json.
   - Rule 27: a second `scrollUntilVisible` checked the layout from before the jump, and its first drag went past
     the next card.
   - Rule 28: the trend notes called every 刑, 害 and 破 「刑害」. Found while taking a release-note example from real
     output, and fixed before release.
   - What they teach: in widget tests, go top to bottom, give the list a frame after every jump, and sync before
     testing. When a test fails for no clear reason, print what it sees step by step: a probe of the scroll offsets
     found rule 27's cause in one run, where guessing had not. Name every relation by its own type.
   - Expected values I wrote wrong, all caught by re-deriving by hand before the first run (G7, P12): in v1.3.0, a
     missed 寅申 冲 and 庚 against 己 (伤官); in v2.0.0, the 繁體 note template said 当头 for 當頭 (G18).
5. **Next**: S2 (v2.1.0).
   - WP2.1: the action and remedy prompts for tarot, and astrology's.
   - WP2.2: a tarot-native reading.
   - WP2.3 (new): what each agent reads.
   - Also new, in S4: WP4.7, the other widget tests move to `scrollTo()`.

## Status

| WP        | Status                     | Release        |
| --------- | -------------------------- | -------------- |
| WP1.1     | done                       | v1.3.0         |
| WP1.2     | done                       | v1.3.0         |
| WP1.3     | done                       | v1.3.0         |
| WP1.4     | done (命宫 / 身宫 → WP1.8) | v1.3.0         |
| WP1.5     | done                       | v1.3.0         |
| WP1.6     | done                       | v2.0.0         |
| WP1.7     | done                       | v2.0.0         |
| WP1.8     | waiting for a reference    | —              |
| WP2.1     | done                       | v2.1.0         |
| WP2.3     | done                       | v2.2.0         |
| WP2.2     | done                       | v2.3.0         |
| WP3.1     | done                       | v2.4.0         |
| WP3.2     | done                       | v2.5.0         |
| WP3.3     | done                       | v2.6.0         |
| WP3.4     | done                       | v2.7.0         |
| WP3.5–3.6 | todo                       | v2.8.0, v3.0.0 |
| S4–S6     | todo                       | above          |
