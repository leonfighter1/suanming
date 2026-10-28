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
| S3 塔罗体验                | cards on readings, 每日一牌, 图鉴, more spreads, the ritual | big    | v3.0.0 + summary  | done        |
| S4 八字与全局 UI           | 五行 colours, term tips, timeline, home, reading page       | big    | v4.0.0 + summary  | done        |
| S5 数据持久化              | readings survive a restart (PGlite store, encrypted)        | medium | v4.1.0            | done        |
| S6 新玩法                  | 求籤 · 擲筊, 风水, 起名 (the owner's phase document)        | big    | v5.0.0 + summary  | in progress |
| S7 分享图                  | a reading as an image, made on the server (owner's spec)    | medium | v4.2.0            | in progress |

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
  - As built (v2.8.0):
    - `two_paths` and `relationship` in deck.ts `SPREADS`, with their own position keys (`choice_now`,
      `path_a` …; `rel_you` …), labels and meanings in three scripts. The relationship spread doesn't reuse the
      Celtic Cross's 挑战.
    - Their places for the reading agent. `narrative_tarot@3` adds each method (never choose for the user;
      card 2 is a tendency, never a claim about the other person; never a breakup) and the synthesis shapes.
    - The schema and OpenAPI enums extended (additive). The tarot battery covers them by itself (it loops over
      `SPREADS`).
    - App: `spreadRects` lays out every two-dimensional spread (the Celtic Cross as before, the V, the two
      rows) for both `TarotSpread` and `SpreadDiagram`. The picker became wrapping `ChoiceChip`s: five
      segments overflow a phone.
- WP3.6 洗牌 → 切牌 → 选牌: the engine still shuffles; the user's picks are positions in the seeded deck, stored in
  the draw so the audit replays it.
  - As built (v3.0.0):
    - `drawWithRitual`: a full Fisher–Yates of the 78 cards from the seed, each place with its orientation from
      the seed. The cut moves the cards from it to the top, and each pick is a place in the cut deck.
    - `ritualProblem` validates (the spread's count, all different, 0–77). `audit.ritual {cut, picks}` is a new
      optional ChartFact property, and `verifyDraw` replays with it. A draw without a ritual is the old partial
      shuffle, unchanged.
    - API: `ritual` on the tarot chart request.
    - Battery: the same nine checks on a fixed ritual (three cards, cut 26, picks 7·61·0), all passing; the battery
      takes 25 s instead of 13 s.
    - App: `TarotRitualSteps` (shuffle as a gesture; three piles of 26 to cut; 78 backs to pick, numbered as picked)
      opens on 抽牌, with 「让牌组替我选」 at every step. `CardBack` is in the deck's colours.

## S4 八字与全局 UI (big → v4.0.0)

Releases, one per work package (medium, committed and tagged locally): **v3.1.0** = WP4.1, **v3.2.0** = WP4.2,
**v3.3.0** = WP4.3, **v3.4.0** = WP4.5 (WP4.4 closed), **v3.5.0** = WP4.6 + WP4.7, and **v4.0.0** = WP4.8 with the
S4 summary, pushed with every release since v3.1.0 (WP4.9 moved to S7). Lessons to read first: P3 (borders on fixed boxes), P7 (buttons in rows), P15 (no dart
format), P19, P24, P25, P27 (widget tests), P31 (简体 copy), P32 (non-empty checks), P33 (typed keys), the
keyboard-access checklist.

- WP4.1 Stems and branches coloured by 五行; 藏干 / 长生 / 纳音 rows folded under 更多.
  - As built (v3.1.0):
    - The 干支 were already coloured (`GanZhiText`, `wuxingColor` in theme.dart), but not readably in every
      case. Measured against the cards (surfaceContainerLow), light 木 was 4.45 : 1, 土 about 3.9 and 金 about
      3.0, and in dark mode the fixed colours fell to 2.6 (水). Light 木, 土 and 金 are now darker, and dark mode
      has its own lighter set (`wuxingColorOf(context, …)`).
    - A test computes the WCAG ratio of every colour on the page and on the card in both themes: all at least
      4.5.
    - The life report's private palette (金 as gold, 3.1 : 1) is gone; it uses the shared one.
    - The pillar grid shows 十神, 天干 and 地支. `pillar-more` opens 藏干 with its 十神, 长生 and 纳音 (unshaded,
      so the small coloured 藏干 keep their contrast).
- WP4.2 Term tips: a glossary (十神, 十二长生, 纳音, 空亡, 神煞, 大运, 流年, 旺衰 …) in three languages, one source on
  the server, synced; tapping a term opens its plain explanation.
  - As built (v3.2.0):
    - One source, `src/ai/term-tips.ts`, synced as `app/assets/i18n/term_tips.json`. It has 63 tips. 简体 and
      English are written by hand. 繁體 is built at sync: protected terms first, then OpenCC cn → tw, then the
      reviewed fixes.
    - The G18 review of all 63 found five slips, now fixed:
      - the branch 丑 had become 醜;
      - 三合 had become 三閤;
      - 藏干 had become 藏幹 once;
      - 克 appeared where 命理 writes 剋;
      - the 简体 “” quotes needed to be 「」.
    - The tips use tendency language only: 羊刃 is drive, 桃花 charm, 空亡 a quieter area, and 死 strength at rest.
    - On the 命盘 page, these terms are underlined with dots and open their tip (`TermTip`, built on `Pressable`, so
      Tab and Enter work):
      - the 四柱 row labels, every 十神 and every 十二长生;
      - the 旺衰 pills (one tip covers 喜用 and 忌);
      - 神煞, 空亡 and 胎元;
      - the 刑冲合害 types.
    - The 五行, 神煞, 大运 and 流年 cards have a 什么是…？ button (`TermTipButton`), and a line under the table says
      the dotted terms can be tapped.
    - Found and fixed: 衰, 病, 死, 墓 and 胎 were missing from the term table, so the English page showed them in
      Chinese. They are single characters, which `glossaryFor`, `normalizeTerms` and the faithfulness check skip,
      so no prompt changed and no fixture changed.
    - Tests (`test/term-tips.test.ts`):
      - Every term the page can show has a tip. The 十神 and 十二长生 come from the engine's own `tenGod` and
        `diShi`. A `Record` over each engine union (relations, 神煞, 旺衰) fails the typecheck when a new member is
        added.
      - Quotes are right for each script.
      - The G18 fixes hold.
      - A hash pins the reviewed tips, so any change means a new review (`scripts/print-term-tips.ts`).
      - The compliance rule layer finds nothing in any region.
    - App tests: tap, English, and keyboard (Tab, Enter, Esc; the focus returns to the term).
    - Not yet: short English names in the table (WP4.8). (The 一生运势报告's terms were planned for WP4.6, which
      dropped them; see there.)
- WP4.3 Timeline: the current 大运 and 流年 marked; tapping a 大运 shows its ten years; 流月 shown.
  - As built (v3.3.0):
    - Engine: a new fact, `dayun_years`, holds the ten years of every 大运 (80 for the sample chart). Each year is
      the same entry as in `liunian`, without its relations and 神煞; one helper builds both, so `liunian` is
      unchanged. The schema gets an optional property.
    - No prompt reads `dayun_years`: `baziView` and the life report drop it, as they drop `liuyue`. The
      faithfulness check leaves it out too: 80 years hold every 干支, so counting them would let any 干支 through.
      A test pins that with 甲子 (2044).
    - The 命盘 page:
      - 大运: a 当前 badge marks the 大运 running in the chart's year (its first 流年). Tapping a 大运 (or Tab and
        Enter) opens its ten years under the strip, titled e.g. 辛巳大运 · 2007–2016年; tapping it again closes
        them. A hint says so until one is opened. Charts made before v3.3.0 have no years to open.
      - 流年: a 今年 badge marks this year, here and in an open 大运's years.
      - 流月: a new card, 2026年流月. Each month shows its 干支, the date it begins (北京时间), its 节 and its 十神.
    - Term table 1.2.0: the twelve 节 (惊蛰 → 驚蟄, 芒种 → 芒種) with English names. They occur only in 流月,
      which no prompt reads, so no model input changed; no reading fixture changed.
    - Found and fixed: in English a 流年's relation read 「YearSix Clashes」; it reads 「Year Six Clashes」 now.
    - Tests:
      - Engine: ten years per 大运 from each start year; 2007 丁亥 and 2029 己酉 worked out by hand; equal to
        `liunian` where they meet; every 节 in the term table.
      - Views: no `dayun_years` in a reading, a plan or a life report prompt.
      - App: the badges, opening and closing, the keyboard path, 流月, the English line and an old chart.
- WP4.4 首页: 一生运势报告 as its own entry, 今日 (每日一牌), recent readings.
  - Closed without a release (2026-10-28):
    - The owner asked on 2026-10-27 to put 一生运势 inside 八字排盘 as a second option ("把一生运势放到八字排盘内，
      作为同另一个选项"). It became the 排盘解读 / 一生运势报告 switch, and the separate 首页 card was removed. A
      首页 entry would undo that, so there is none.
    - 首页 already has the rest: 今日 (每日一牌, v2.6.0) and the three most recent readings with 查看全部.
    - Lesson (rule 34): check for an owner decision before building a plan item.
- WP4.5 Reading page: the chart or spread on top, a jump list. (Sharing moved to WP4.9; see there.)
  - As built (v3.4.0):
    - `ReadingChart` (was `ReadingSpread`) puts the reading's chart on top. A tarot reading keeps its spread
      (v2.4.0). A 八字 reading now opens with its four pillars, coloured by 五行, and 日主. Astrology shows nothing
      there yet; its facts are in the layers.
    - The jump list is the page's first line, 「跳到」 followed by a chip per section and 行动建议. It is one row,
      which scrolls sideways on a phone. It is a `Row` in a `SingleChildScrollView`, not a lazy list, so Tab
      reaches every chip.
    - A chip opens its section if it was closed, scrolls it into view and moves the focus to it, so the next Tab
      goes on inside that section. The page now builds all its cards (a large `scrollCacheExtent`), so the last
      one can be reached from the top.
    - A reading with a single section shows no jump list.
    - Tests: the pillars and their order; a chip opens and reveals a closed section, and 行动建议 too; on a phone
      Tab reaches the last chip, which was off the edge; Enter jumps and Tab goes on inside. The tarot test now
      finds section titles inside the tiles, since the chips repeat their names.
- WP4.6 Split `life_report_page.dart` (991 lines) and `profiles_page.dart` (596) into widgets. The split
  life report's terms get the WP4.2 tips (`TermTip`).
  - As built (v3.5.0, with WP4.7):
    - `life_report_page.dart` is down from 1029 lines to about 460: the page, its states and the entry button.
      The rest moved to three widget files:
      - `widgets/life_blocks.dart`: the text blocks, `LifeSection`, `LifeQuote`, `LifeLabeled` and the rest;
      - `widgets/life_figures.dart`: `HexagramFigure`, `MeihuaTable`, `BazhaiCompass` and the other figures;
      - `widgets/life_stages.dart`: `StageChart` and the topic and stage rows.
    - `profiles_page.dart` is down from 637 lines to about 315. The birth inputs moved to
      `widgets/birth_fields.dart` (`BirthFields`, `LunarDatePicker`, `ShichenPicker`, `LunarPreview`).
    - The moved private classes are public now, with a `Life…` prefix where the name was generic. Each has a key
      parameter and a doc comment.
    - A script cut the files at checked line boundaries, so the code itself is unchanged; the 119 app tests are
      the check.
    - Dropped by rule 34: the tips on the life report. It follows the owner's sample template (易经, 梅花, 八宅)
      and holds few 八字 terms. Its 喜用 / 忌 come from the reading, not from the simplified count the 喜用 tip
      describes, so that tip would mislead there.
- WP4.7 (found in S1) Widget tests reach cards through `scrollTo()` in `test/support.dart` (rule 27). Ten test files
  still call `scrollUntilVisible` directly.
  - As built (v3.5.0):
    - `scrollToFinder(tester, finder, {delta, scrollable})` joins `scrollTo()` in `support.dart`, with the same
      pumps around `scrollUntilVisible`.
    - All 21 direct calls in 12 test files go through one or the other, and the four local `scrollAndTap` helpers
      call it.
    - `test/test_rules_test.dart` fails on any direct `scrollUntilVisible` outside `support.dart`.
- WP4.8 (found in WP4.2) On a phone, the English names in the 四柱 table break mid-word ("Compani on (Bi Jian)"):
  give the table a short English form (Companion), with the full name kept for the tip's title. The strips'
  English lines are cut off too ("nominal age…", "Indirect Res…"), and the short forms serve them as well.
  - As built (v4.0.0):
    - `Terms.short` is the brief form: English without its trailing pinyin (Companion for Companion (Bi Jian));
      Chinese is unchanged. It is a rule over the one term table, not a second list of names.
    - The 四柱 table, the strips and the relations labels show the brief form; each tip's title keeps the full
      name. Abbreviations (DR, 7K …) were not used: they would need English names other than the table's.
    - In a cell, a name of one word shrinks to fit instead of breaking (`TermTip(shrinkOneWord:)`). Names of
      several words wrap between their words.
    - The strips are 128 px wide in English, and a 流年 gives its year, 虚岁 and each 十神 a line of their own.
      The 流月 do the same for their two 十神. Chinese keeps 96 px and its three lines; ←/→ step by the item's
      width.
    - Checked by rendering the English page: no word breaks, no line cut off in the 流年 strip. A long 节 name
      (Awakening of Insects) can still end in an ellipsis.
- WP4.9 (split from WP4.5 by rule 34) moved to S7 as WP7.1 (2026-10-28). It needs a server-side renderer and
  fonts, and a deep link needs readings that persist (S5). It is a stage's worth of work, not a UI touch.

## S5 数据持久化 (medium → v4.1.0)

- WP5.1 A PGlite store on disk (`db/schema_v0.sql` and migrations) behind the same `Store` interface, report and fact
  bodies encrypted (AES-GCM, key in `.env`), data in a git-ignored folder; the store tests run on both stores.
  - Spec, detailed 2026-10-28 from the owner's documents (rule 34). The phase document asks for AES-256 at rest for
    birth data and consultation content, and keys never in the database or the code. `db/schema_v0.sql` and
    `docs/data-retention.md` fix the rest:
    - Envelope encryption. Each user gets a data key (DEK, 32 random bytes), stored only wrapped by the key
      encryption key (KEK). The KEK is `MINGLI_DATA_KEY` in `.env` here and a KMS in production. Facts, report,
      plan and life report bodies, the life context and the email are sealed with the owner's DEK (AES-256-GCM,
      random nonce, the table and row id as associated data, so a body can't be moved to another row).
    - Plain columns only where the schema has them: ids, owner, system, versions, digest, status, locale, topics,
      times. Raw birth data is never stored. That is already so: a chart record holds only the ChartFact.
    - Deletion follows data-retention.md:
      1. a `deletion_requests` row first;
      2. the DEK shredded with the user row, which cascades to everything they own;
      3. evidence recorded (counts, `dek_shredded`), then `completed_at`.
         The request row holds no PII (`subject_hash`).
    - Reports expire 24 months after creation (`expires_at`). Purging them is a later WP; this one only records the
      date.
    - The store is opt-in: `MINGLI_STORE=pglite` with `MINGLI_DATA_DIR` (git-ignored). Without it, the server keeps
      the in-memory store, so tests and the owner's setup are unchanged until the owner turns it on.
    - When on, the server refuses to start without a valid `MINGLI_DATA_KEY`, or with ephemeral secrets: a random
      pepper would break email lookups after a restart.
    - Tests:
      - one contract suite run on both stores;
      - a restart (close, reopen the folder, read);
      - no plaintext in the stored rows (a birth date, a reading's text, an email);
      - a wrong KEK, or a body moved to another row, fails loudly;
      - deletion leaves only its evidence.
- WP5.2 Accounts survive a restart too: the same database's `users` table behind `UserStore`. The email is sealed with
  the user's DEK, with the HMAC lookup column beside it. Readings that survive while their owners vanish would be of
  no use.
- As built (v4.1.0, WP5.1 + WP5.2):
  - `src/db/envelope.ts`: AES-256-GCM with a version byte, a random 96-bit nonce and the row as associated data;
    each DEK is wrapped under the KEK and bound to its user.
  - `src/db/pg-store.ts`: `PgStore` is both `Store` and `UserStore` on PGlite. It applies `schema_v0.sql`, then the
    migrations it hasn't recorded (`schema_migrations`).
  - `db/migrations/002_store.sql` adds:
    - `failed` to the status enum, and nullable region and matrix for pending reports;
    - `updated_at`, the 每日一牌 date and the social lookups;
    - tables for plans and life reports;
    - a `seq` that keeps rows of one millisecond in the order they came, as the in-memory lists do.
  - The bodies are the whole records, sealed. The plain columns are the schema's lookup columns only, and the
    violations are rule ids only.
  - Wiring:
    - `openStore` in `src/service/runtime.ts` (memory by default) and `npm run keygen`;
    - `.data/` git-ignored;
    - the X-Dev-User shortcut off with the store;
    - the database closed after the jobs drain;
    - how to turn it on in docs/web-test.md.
  - Found on the way:
    - Every background job now goes through `track()`: a failed write is logged, not an unhandled rejection that
      would end the process. Memory never threw; a database can.
    - PGlite moved into `dependencies`. The term tips stopped reaching the server through the ai index: since
      v3.2.0 they had pulled OpenCC, a dev tool, into every server process. `test/runtime-deps.test.ts` now walks
      the server's imports. Rule 36.
  - Tests (`test/pg-store.test.ts`, 12, plus the dependency walk):
    - one contract on both stores (round trip, replace, lists and their order, held, deletion);
    - a restart, and a wrong key;
    - no plaintext in any stored row (birth date, reading, life context, email, social subject);
    - deletion leaving only its record, without the id or its bytes;
    - the real API end to end on the database, the deletion race included;
    - the envelope itself.

## S6 新玩法 (big → v5.0.0)

**Owner (2026-10-28): 「继续吧不要停」**, with no choice made between the methods. So S6 follows the owner's phase
document (rule 34), which this plan's own ideas never override:

- Phase 3 §2.1: 起名 and 风水, each with its own spec.
- Phase 3 §2.4: the 擲筊 / 求签 entry comes first for Taiwan and Hong Kong (「台湾/香港（擲筊/求签入口前置）」), and
  风水 gets more weight in Malaysia.
- This plan's own proposals, 六爻 / 梅花 起卦 and 合婚, are parked: the document mentions neither.

Order: WP6.1 求籤 (+ WP6.2, the entry order) as v4.3.0, WP6.3 风水 as v4.4.0, WP6.4 起名 as v4.5.0, then the stage
summary and v5.0.0.

### WP6.1 求籤 · 擲筊, its own method (medium → v4.3.0)

**The lot set: 關聖帝君一百籤 (雷雨師一百籤, 關帝籤).** It is used at 臺北行天宮, 日月潭文武廟 and 新竹城隍廟, and is
Taiwan's second most used set (六十甲子籤 first, 觀音一百籤 third, by the survey temples.tw cites). It comes first
because its text can be verified:

- two independent transcriptions:
  - A: 維基文庫 「關聖帝君靈籤」. Lots 1–10 are from a Qing print, 11–100 from another transcription.
  - B: temples.tw 「關聖帝君一百籤」.
- a public-domain primary source to settle their disagreements: the Qing print 「關帝靈籤」 (姑蘇鈕氏藏板), Harvard DRS
  53239458, scanned on Wikimedia Commons (page = lot + 2).

六十甲子籤 (the 媽祖 temples) and 黃大仙靈籤 (Hong Kong) have no such sources yet. They wait for a reference, like
WP1.8.

**The text (G4, G7):**

- The poem is the temples' text, where A and B agree character for character: 85 of 100 lots (measured 2026-10-28).
- Where they disagree (16 lines in 15 lots), the print decides, written in the modern form (the print's 孝弟 is
  孝悌). In #35 neither has the print's reading (A 分折, B 分析, print 分拆).
- All 100 lots were then read in the print. A and B share a few plain errors, so their agreement alone is not
  proof.
  - 5 such lines take the print's reading: #25 戍 → 戌 (the branch), #47 祗 → 祇, #50 步多 → 步步, #87 敵圖 → 敵國,
    #90 咨嘆 → 咨嗟 (the rhyme).
  - 38 other lines differ from the print as variants that read well either way. They stay as the temples print
    them, and the print's reading is listed. For example, #1 「玉殿千官」 (print 仙官; its own note gives both) and #81
    「幸有高臺」 (print 當堂).
- 干支 labels follow the set's rule, 甲甲 … 癸癸 (lot n = 天干[(n−1) ÷ 10] + 天干[(n−1) mod 10]). All 100 headings
  in the print follow it.
- **No 吉凶 grade.** Editions disagree (2 of the 14 lots checked differ between A and the print), and many Taiwanese
  temples print none. The reading follows the poem.
- No 聖意, 典故 or modern commentary in v1: only the verified poem.
- 简体 by OpenCC in the build script (`npm run build:qiuqian`), never on the server (rule 36). It keeps 乾 in 乾坤 and
  乾亥 and makes three fixes (祇欲 → 只欲, 斲 → 斫, 𫗴 → 饘), with the G18 one-to-many check.
- The evidence is in `docs/verification/qiuqian-guandi-100.md`: the sources, the 16 decisions with their scan pages,
  the 5 corrections and the 38 variants.

**The ritual**, as temples commonly do it, simplified:

1. The user may type what they ask. It is private, like a tarot question: never on the share image.
2. 搖籤筒: a stick falls.
3. 擲筊 confirms it.
   - 聖筊 (one block flat, one round) confirms the stick.
   - 笑筊 (both flat) or 陰筊 (both round) puts it back, and the user draws again.
   - Each block lands either way with probability ½, a simplification, so a 聖筊 comes half the time.
   - The engine stops at 64 rounds (2⁻⁶⁴).
4. The engine draws everything from the seed (HMAC-DRBG, HMAC(drawKey, draw id)), so a draw replays like a tarot
   draw. The app reveals the recorded steps one by one.

**Facts** (ChartFact `system: "qiuqian"`, additive):

- `{ lot_set: "guandi_100", lot: { n, ganzhi, poem[4] }, rounds: [{ lot, blocks: [face, face], result }], audit }`
- provenance: `/lot/poem` is traditional_text; `/rounds` is common_consensus.

**The reading**, with its own prompts: narrative_qiuqian@1 and action_qiuqian@1. There is no plan (破除運勢), as
for astrology. Sections:

- 籤詩 (`qiuqian_poem`): the poem couplet by couplet, in plain words.
- 所問之事 (`qiuqian_answer`): what the lot says to the question, or to the reader's situation without one.
- 建議 (`qiuqian_advice`): what the lot invites the reader to do.
- The actions follow the advice.

Limits on the reading:

- Tendency language. A sad lot asks for patience and care, never a fixed fate.
- Never donations, 添香油錢, 點光明燈, 安太歲, 祭改, amulets, or going back to undo a lot.
- No health, legal or money predictions.
- Faithfulness: a quoted poem line must be one of the lot's lines.

**API and data:**

- `POST /v1/charts {system: "qiuqian"}`; reports as for tarot (a question, no focus).
- 分享图片 for passed 求籤 readings: the lot, its poem, the main point; never the question.
- Migration 003 adds `qiuqian` to `chart_system`.
- Geo matrix: `qiuqian` available by default.

**App:**

- a 求籤 entry on the home page;
- the 求籤 page: the question, the ritual (Enter / Space), the lot card;
- the lot card on the reading page;
- history;
- term tips for 聖筊, 笑筊, 陰筊 and 籤詩.

**Tests:**

- engine:
  - replay;
  - the stop rule;
  - 100 000 draws: 聖筊 half the time, lots uniform, rounds geometric. `npm run verify:qiuqian` becomes a harness gate.
- data:
  - 100 lots × 4 lines × 7 characters;
  - the 15 decisions pinned;
  - the 干支 rule;
  - the 简体 checks.
- prompts: pinned and distinct.
- pipeline: a passed mock reading.
- faithfulness: a misquoted line is caught.
- API: chart, report, share, methods, geo.
- app:
  - the ritual;
  - the reading page;
  - the home order for TW;
  - keyboard.

Lessons: G4, G7 / P12, G18, P26, P27, P33, P37, rules 29 and 36.

As built (v4.3.0), beyond the spec above:

- The text policy changed once the print was read in full: the two transcriptions share errors (rule 39). The
  numbers and lists are in the evidence file.
- 求籤 has its own AI label (「依據所得籤詩生成」); the shared one says 命盤. Other methods are unchanged.
- The model sees the lot without the rounds, so it never reads meaning into how many draws it took.
- Compliance rule G008 holds offerings or rituals framed as what undoes a lot.
- The app reveals the rounds one step at a time (擲筊, 放回再搖, 直接看結果). Each lot's title comes from the server's
  `lotTitle`, synced with the set.

### WP6.2 The entry order by region (with WP6.1, v4.3.0)

- `GET /v1/methods` returns the caller's region's methods in `entry_weight` order (the matrix, so it changes without a
  release).
- Taiwan and Hong Kong give `qiuqian` 1.5, ahead of 八字's 1.2.
- The home page orders its entries by it. Offline, it keeps the default order.

### WP6.3 风水 (medium → v4.4.0)

The owner's spec (Phase 3 §2.1, §4):

- Only general principles of direction and space (「书桌宜背靠实墙」), from the room's use and, optionally, its
  facing. The input is anonymous.
- Never a 吉凶 judgement of a home.
- ChartFact `system: "fengshui"`, every principle tagged `simplified_rule`.
- A compliance rule set against 吉凶 phrasing.
- Malaysia gives it more weight (§2.4).

Design:

- **Input:**
  - the room: 臥室, 書房 / 工作桌, 客廳, 廚房, 玄關, 餐廳 or 兒童房;
  - optionally its facing: eight directions, the way the main window faces;
  - optionally a short description of the room ("the bed is under the window …"), private like a question.
  - No address, no birth data, no floor plan.
- **Engine** (`src/engines/fengshui`):
  - a fixed table of principles per room, each with:
    - the principle;
    - its everyday reason (light, air, sleep, safety, privacy, how people move);
    - the traditional idea behind it, said without 吉凶 (for example 「背後有靠」).
  - The facing adds its traditional direction note: 後天八卦 and 五行, e.g. 南 · 離 · 火.
  - Its own table: it shares none with 一生运势's 八宅 (rule 8). 八宅 assigns 吉凶 directions, which the spec
    rules out.
  - Facts: `{ room, facing?, principles: [{ id, area }], direction? }`. Every provenance entry is
    `simplified_rule`.
- **Texts:** 繁體 and English written by hand; 简体 written too, and a test holds it to OpenCC's conversion
  except for listed words (rule 31, G18). They live in the engine's table: the server never loads OpenCC
  (rule 36).
- **Reading:** its own prompts, `narrative_fengshui@1` and `action_fengshui@1`, with no plan. Sections:
  - 佈局 (`fengshui_layout`): the room's principles, and the description when given;
  - 光線與動線 (`fengshui_flow`);
  - 建議 (`fengshui_advice`).
  - Tendency language. Never 吉 / 凶, 旺 / 衰 or 煞; never wealth, health, marriage or children tied to the home;
    never buying objects (charms, crystals, 羅盤 items) or renovating as a cure.
- **Compliance:** method rule groups. A `fengshui` group, applied only to 风水 output, blocks 吉凶 phrasing
  (凶宅, 犯煞, 招財, 破財, 旺丁, 損丁 and their 简体 forms). Allow cases cover the disclaimer in both scripts (G5).
- **Geo matrix:** `fengshui` available by default; Malaysia 1.3, so it leads there (§2.4).
- **App:**
  - the 风水 entry;
  - a page: room chips, facing chips (or 不確定), the description, 看佈局, then the principles card and
    生成 AI 解讀;
  - the principles card on the reading page;
  - history.
- **Tests:**
  - every principle is `simplified_rule`, and every room has principles;
  - the 简体 texts are OpenCC's;
  - the method rule group blocks 吉凶 phrasing and allows the disclaimer;
  - prompts pinned and distinct;
  - a mock reading;
  - the API and the geo order (MY);
  - the app page and the reading page.

As built (v4.4.0):

- 30 principles for the 7 rooms.
- Method rule groups are new in the pipeline (`METHOD_RULE_GROUPS`). The `fengshui` group (F001: 凶宅, 犯煞, 风水不好;
  F002: 招財, 破財, 旺丁, 轉運) applies to 风水 readings only. A test shows it holds a 风水 text and leaves the same
  text in a tarot reading alone.
- Every paragraph's `source_level` is pinned to `simplified_rule` in the pipeline, so the spec's 100 % doesn't rest
  on the model.
- 风水 and 求籤 have their own AI labels (`METHOD_LABELS`).
- No share image for 风水: the owner's spec asks for none.

### WP6.4 起名 (medium → v4.5.0)

The owner's spec (Phase 3 §2.1, §4):

- 五行补益 from the 八字 五行 count.
- A 字义库 with 繁 and 简 forms, checked by hand. It ships marked unreviewed until the owner checks it, like the 50
  八字 cases.
- 音律 rules (tone patterns).
- ChartFact `system: "naming"` with candidates, each with its basis and `source_level`.
- Tests: 字义库 coverage 100 %, unit tests for the tone rules, and checks of the 繁體 forms.

Parked, not in the owner's document: 六爻 / 梅花 起卦 as its own method, and 合婚 between two saved profiles.

## S7 分享图 (medium → v4.2.0, before S6 while S6 waits)

From S4 (WP4.9), to the owner's phase document (「Pick-a-Pile 截图分享（分享图由服务端生成，带水印与免责声明）」).

- WP7.1 Share a reading as an image:
  - the server renders it, with a watermark and the disclaimer, never the app's screen;
  - the app offers it through the system share sheet;
  - a deep link back to the reading once the app is in the stores (the link needs S5's stored readings).
  - First measure a renderer with CJK fonts on the server (G4): SVG through sharp/librsvg against a headless
    browser, for fidelity, size and time.
  - Measured 2026-10-28: sharp alone composited three card arts and 简体 and 繁體 text set in a given font file
    (Pango) at 1080 × 1350 in about 150 ms, a 139 kB JPEG, every glyph right. No headless browser is needed.
  - Spec (v4.2.0), the owner's Pick-a-Pile case first: **tarot readings**.
    - `GET /v1/reports/{id}/share.jpg`, for the owner only and passed readings only, 1080 × 1350:
      - 命理大师 · 塔羅 at the top, in the reader's script;
      - every card with its position, its name and 逆位 when reversed (drawn upside down, as in the app);
      - the 综合解读's main point;
      - at the bottom, the report's own AI label (仅供娱乐和玄学学习使用) and the watermark with the date.
    - Never the question, the life context or a name: they stay private.
    - The font is a system dependency, like libvips: `MINGLI_SHARE_FONT` (+ `_FAMILY`), or one found in the usual
      places:
      - Noto Sans CJK from `fonts-noto-cjk` on Linux, its TC face for 繁體 readers;
      - Noto Sans SC or 微软雅黑 on Windows;
      - PingFang on a Mac.
        Without a font: 503 with what to install. CI installs `fonts-noto-cjk`.
    - The app's reading menu offers 分享图片 for tarot readings, through the system share sheet (`share_plus`).
    - Tests:
      - the image (JPEG, size, a three-card and a Celtic Cross reading);
      - the endpoint (owner only, passed only, 503 without a font);
      - privacy (the question is not in the image's text);
      - the app menu.
    - Later: a 八字 reading's card (the four pillars), and the deep link.
  - As built (v4.2.0):
    - Server: `src/share/tarot-image.ts` and `src/share/font.ts`.
      - `renderTarotShare` composes the image with sharp: art from `app/assets/tarot`, reversed cards turned, text
        set by Pango in the found font. Measured: about 200 ms and 140 kB for three cards, 410 ms and 196 kB for a
        Celtic Cross (two rows of five).
      - `shareTexts` is everything the image says, kept apart so a test can show the question is not among it.
      - The label's place follows its height: English wraps it to two lines.
    - The API: `GET /v1/reports/{id}/share.jpg` (OpenAPI) carries the AI headers. It answers 404 to anyone but the
      owner, 409 for anything but a passed tarot reading, and 503 with what to install when the server has no font.
      sharp is a runtime dependency now.
    - The app:
      - 分享图片 in a tarot reading's menu fetches the image (`ApiClient.shareImage`, with the same token refresh
        as every call) and hands it to the share sheet through `shareProvider`, which tests replace. The 下载
        item uses the provider too.
      - A failure shows a message.
    - CI installs `fonts-noto-cjk`.
    - Tests:
      - server: the texts and privacy, the image for three cards in 繁體 and a Celtic Cross in English, and the
        endpoint (owner, passed, method, no font);
      - app: the menu shares the server's JPEG; a 八字 reading has no such item.
- WP7.2 A 八字 reading's share card: the four pillars coloured by 五行, the reading's main point, the same footer.
  - **Waits for the owner (privacy, rule 34).** The four pillars give away the birth date to about two hours, which
    is why `docs/data-retention.md` counts a 八字 chart as personal data. A tarot draw gives nothing away, so its
    image could go out as the owner's spec asks. Whether a 八字 image may show the pillars, show only the reading,
    or not exist is the owner's decision.
- WP7.3 The deep link back to the reading, once the app is in the stores.

## 阶段总结 (stage summaries)

Written when a stage completes, before its X.0.0 release (dev-workflow skill). Medium stages get a short one.

### S5 数据持久化 (done 2026-10-28: v4.1.0, medium)

1. **Delivered**: WP5.1 + WP5.2 in v4.1.0.
   - Readings, plans, life reports and accounts survive a restart in an encrypted database (PGlite), when the owner
     turns it on (`MINGLI_STORE=pglite`).
   - Envelope encryption with a key per user. Deletion as docs/data-retention.md says.
2. **Numbers**
   - Server tests: 312 → 325. App tests: 121 (unchanged).
   - Migrations: 001 → 002.
3. **Changed against the plan**
   - WP5.2 (accounts) was added once the spec was read against the owner's documents (rule 34): readings that
     outlive their owners would be no use.
   - The store is opt-in, so the owner's setup didn't change.
   - Two finds came along: unhandled job failures, and a dev tool loaded by the server since v3.2.0.
4. **Mistakes recorded**
   - Rule 35: PGlite and enum arrays.
   - Rule 36: sync-only code reached the server through an index.
   - Rule 32 caught a vacuous assertion before it was committed (a value compared with itself).
5. **Next**: S6 新玩法 (big → v5.0.0), then S7 分享图.

### S4 八字与全局 UI (done 2026-10-28: v3.1.0–v4.0.0)

1. **Delivered**
   - v3.1.0, WP4.1: 五行 colours that read on the cards in both themes (4.5 : 1 or more, pinned by a test); the 四柱
     table opens on 十神, 天干 and 地支, the rest under 更多.
   - v3.2.0, WP4.2: term tips.
     - 63 plain explanations in three scripts, one source on the server, 繁體 reviewed (G18) and pinned by hash.
     - Tap or Tab + Enter on any dotted term of the 命盘, or a card's ? button.
     - 衰 病 死 墓 胎 got English names.
   - v3.3.0, WP4.3: the timeline.
     - 当前 and 今年 badges.
     - Any 大运 opens its ten years (`dayun_years`, kept out of every prompt and out of the faithfulness check).
     - 流月 shown.
     - The twelve 节 in the term table.
   - v3.4.0, WP4.5: a reading opens with its chart (the four pillars of a 八字 reading) and a jump list that opens a
     section, brings it into view and moves the focus there.
   - v3.5.0, WP4.6 + WP4.7: the two largest pages split into widget files (1029 → 460 and 637 → 315 lines); every
     widget test scrolls through `scrollTo()` / `scrollToFinder()`, and a test keeps it so.
   - v4.0.0, WP4.8: English names without pinyin in the table and the strips, which are wider in English with a
     line per part; one-word names shrink instead of breaking.
2. **Numbers**
   - Server tests: 301 → 312. App tests: 103 → 121.
   - The term table: 1.0.0 → 1.2.0 (5 stages, 11 节). Prompts unchanged: the 15 pinned hashes held, and no reading,
     plan or life fixture changed in the stage.
   - The sample chart's facts: 17.0k → 28.5k characters, all of it `dayun_years`, which no model reads.
3. **Changed against the plan**
   - WP4.4 (a 首页 entry for the 一生运势报告) was closed: the owner had put it inside 八字排盘 on 2026-10-27.
     首页 already had 今日 and the recent readings.
   - Sharing as an image left WP4.5. The owner's phase document wants it made on the server, with a watermark and
     the disclaimer. It is S7 now (WP7.1), after S5, whose stored readings its deep link needs.
   - WP4.6 dropped the tips on the life report (the owner's template, few 八字 terms, its 喜用 is the reading's),
     and went out with WP4.7 as one code-health release.
   - WP4.8 was found in WP4.2 and became the stage's last release.
4. **Mistakes recorded**
   - New:
     - rule 32: `expect.any(String)` matches `''`;
     - rule 33: a key built from a nullable id is a `ValueKey<String?>`;
     - rule 34: look for an owner decision before building a plan item.
   - Widened:
     - rule 3: a border on a fixed box costs its text room, which only a render shows;
     - rule 22: render the root layer to include a dialog;
     - rule 27: `scrollToFinder`, and the test that enforces it;
     - rule 29: a fact no prompt reads may stay out of the faithfulness check;
     - rule 30: no `tsx -e`; check CJK text in a script.
   - The rule 23 retry cost a second harness run at every release.
   - What they teach:
     - read why the app is as it is before changing it;
     - check every assertion for what it would let through;
     - look at a render, not only at the tests, whenever space is tight.
5. **Next**: S5 数据持久化 (medium → v4.1.0): readings that survive a restart. Then S6 新玩法 (big → v5.0.0) and S7
   分享图. WP1.8 still waits for a reference.

### S3 塔罗体验 (done 2026-10-28: v2.4.0–v3.0.0)

1. **Delivered**
   - v2.4.0, WP3.1: a reading shows its spread on top (the report's `chart_id`); 历史记录 shows the cards' art.
   - v2.5.0, WP3.2: each spread drawn small in the picker, its positions before the draw (deck `SPREADS`
     synced), example questions, the Celtic Cross list at 1.5× or more.
   - v2.6.0, WP3.3: 每日一牌 (`GET /v1/tarot/daily`), the same card all day from the account and the date under the
     draw key, on 首页.
   - v2.7.0, WP3.4: 牌义图鉴, the 78 cards with the keywords painted on the art, 繁體 reviewed (G18), English to
     the RWS meanings.
   - v2.8.0, WP3.5: 二选一 and 关系牌阵, with positions, layouts and their methods (`narrative_tarot@3`).
   - v3.0.0, WP3.6: 洗牌 → 切牌 → 选牌, the user's cut and picks in the deck the engine shuffles, kept in the audit.
2. **Numbers**
   - Server tests: 287 → 301. App tests: 92 → 103.
   - The draw battery: 64 checks on 100,000 draws each (five spreads and the ritual), 25 s.
   - Prompt versions pinned by hash: 15.
3. **Changed against the plan**
   - The spread picker went from a segmented row (v2.5.0) to wrapping chips (v2.8.0): five spreads overflow a
     phone row.
   - "1.5× text" became a floor, max(scale, 1.5): wide screens were already at 2×.
   - 每日一牌 is kept as the account's chart but not listed among the charts (`ChartRecord.daily`).
   - The keywords live in `keywords.ts` beside deck.ts: deck.ts reads no files, and the build script needs it.
   - The ritual's checks run on one spread: a full shuffle costs more per draw.
4. **Mistakes recorded**:
   - Rule 4 widened: a synchronous dataset sweep timed out under the full suite.
   - Rule 27 widened (v2.3.0) and applied again: a frame after `ensureVisible`.
   - Rule 31: 「」 in 简体 copy.
   - On the way: the G18 review needed the full output (疗愈 → 療癒 was missing from the one-to-many list), a Tab
     loop counted one stop short, and an info-level lint would have failed analyze.
   - What they teach: read every converted string, not only the flagged ones; run the whole suite before calling
     a test fast; let each script's copy be written as that script.
5. **Next**: S4 八字与全局 UI (big → v4.0.0): 五行 colours, term tips, the timeline, 首页 and the reading page, and
   the two long app files split.

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

| WP        | Status                     | Release |
| --------- | -------------------------- | ------- |
| WP1.1     | done                       | v1.3.0  |
| WP1.2     | done                       | v1.3.0  |
| WP1.3     | done                       | v1.3.0  |
| WP1.4     | done (命宫 / 身宫 → WP1.8) | v1.3.0  |
| WP1.5     | done                       | v1.3.0  |
| WP1.6     | done                       | v2.0.0  |
| WP1.7     | done                       | v2.0.0  |
| WP1.8     | waiting for a reference    | —       |
| WP2.1     | done                       | v2.1.0  |
| WP2.3     | done                       | v2.2.0  |
| WP2.2     | done                       | v2.3.0  |
| WP3.1     | done                       | v2.4.0  |
| WP3.2     | done                       | v2.5.0  |
| WP3.3     | done                       | v2.6.0  |
| WP3.4     | done                       | v2.7.0  |
| WP3.5     | done                       | v2.8.0  |
| WP3.6     | done                       | v3.0.0  |
| WP4.1     | done                       | v3.1.0  |
| WP4.2     | done                       | v3.2.0  |
| WP4.3     | done                       | v3.3.0  |
| WP4.4     | closed (owner decision)    | —       |
| WP4.5     | done                       | v3.4.0  |
| WP4.6–4.7 | done                       | v3.5.0  |
| WP4.8     | done                       | v4.0.0  |
| WP4.9     | moved to S7 (WP7.1)        | —       |
| WP5.1–5.2 | done                       | v4.1.0  |
| WP7.1     | done                       | v4.2.0  |
| WP7.2     | waits for the owner        | —       |
| WP7.3     | waits for the stores       | —       |
| WP6.1–6.2 | done                       | v4.3.0  |
| WP6.3     | done                       | v4.4.0  |
| WP6.4     | planned                    | v4.5.0  |
