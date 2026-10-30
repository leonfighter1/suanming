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
| S6 新玩法                  | 求籤 · 擲筊, 风水, 起名 (the owner's phase document)        | big    | v5.0.0 + summary  | done        |
| S7 分享图                  | a reading as an image, made on the server (owner's spec)    | medium | v4.2.0            | in progress |
| S8 地区精细化              | Indonesia's blocks, the five-region test, languages kept    | medium | v5.1.0            | done        |
| S9 Phase 3 门禁            | 起名's own rule group; the Phase 3 gate record              | medium | v5.2.0            | done        |
| S10 算卦                   | 六爻 by coins: auto, pick and manual casts; 直說; AI        | big    | v6.0.0 + summary  | done        |
| S11 Owner updates          | tarot spread icons, English removed, the admin in Beijing   | medium | v5.4.0            | done        |
| S12 Owner updates          | tarot spreads 3 a row, 东方 / 西方 home, coins that turn    | medium | v6.1.0            | done        |
| S13 AI 追问 + 通俗解读     | 术语 → 评论 → 例子 in every reading; 追问 on every reading  | big    | v7.0.0 + summary  | done        |
| S14 以往记录               | by month and person; Word / PDF; send; file; delete         | big    | v8.0.0 + summary  | done        |
| S15 菜单、图标、登录、邮件 | the menu, app icon, sign-in three ways, reports by email    | big    | v9.0.0 + summary  | done        |
| S16 Owner updates          | home bar, new parts come into view, the 求签 altar          | medium | v9.1.0            | done        |
| S17 Claude 与模型选择      | Claude as the AI service; the models to choose from         | medium | v9.2.0            | done        |
| S18 八字 AI 解读           | the AI's own reading, a 总结, no 行动建议, the skill        | medium | v9.3.0            | done        |
| S19 深度分析               | the master asks first; 麦克风; 同名重算                     | big    | v10.0.0 + summary | done        |
| S20 积分                   | points paid at the measured cost, ≥ 50% margin              | big    | v11.0.0 + summary | done        |
| S21 有所求才能去求         | 塔罗, 求签 and 算卦 drawn only for a question               | medium | v11.1.0           | done        |
| S22 管理后台               | admin dashboard: accounts, tokens, money, users, exports    | big    | v12.0.0 + summary | in progress |

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

Design:

- **Input:**
  - one of the user's own 八字 charts (`bazi_chart_id`);
  - the surname, one or two characters;
  - the given name's length, one or two.
  - Nothing else. There is no gender filter: every character is open to everyone.
- **五行补益:** from the 八字 engine's 喜用 (`strength.favorable`).
  - Without one (中和, or a chart flagged for a closer look), the names keep a balance instead: the two weakest
    elements by `wuxing_weighted`.
  - The naming chart copies only those elements and the 八字 chart's digest, never birth data.
- **字义库** (`src/engines/naming/characters.ts`): a draft of about 100 characters. Each has its 繁 and 简 forms,
  pinyin with tone, a 五行 by 字形 (its radical, one simplified school of several), and a short meaning in three
  languages. Tests check:
  - the pinyin against pinyin-pro, an independent reference (G4);
  - the 简体 against OpenCC (G18);
  - the element against the radical rule.
- **It ships unreviewed:** the owner's 人工校订 is a gate. Until the owner has checked it, `naming` is off in the
  geo matrix (`available: false`), so nobody sees it; the owner turns it on.
- **音律** (each rule a unit test):
  - no character repeats the surname;
  - no two adjacent syllables alike;
  - the tones are not all the same;
  - points for tones that rise and fall (平仄), deductions for 双声 and 叠韵.
- **Candidates:**
  - every combination whose elements serve the 喜用 is scored, and the top 12 are kept;
  - each carries its basis (五行, 音律);
  - source_level is simplified_rule for 五行 and 音律, common_consensus for the meanings.
- **Reading:** `narrative_naming@1` and `action_naming@1`, no plan. Sections:
  - 候選名字 (`naming_candidates`): the strongest few, one paragraph each, on meaning, 五行 and sound;
  - 建議 (`naming_advice`): how to choose (say it aloud, write it, hear it in the family's dialect).
  - Never a verdict on fate or fortune from a name; never a fee or a ritual.
- **API:** `POST /v1/charts {system: "naming", bazi_chart_id, surname, length}`; migration 005; OpenAPI.
- **App:** on a 八字 chart, 「為此命盤起名」 when the region offers `naming`: the surname and the length, 起名, the
  candidate cards, then the reading.

As built (v4.5.0):

- The draft 字义库: 100 characters (20 per element) and 83 surnames with their readings as surnames (3 double).
  Characters whose meaning is wealth itself (鑫) are left out, and so are polyphones whose name reading is unsure.
  鉅 became 鑄: OpenCC turns 鉅 into 巨, which loses the 金 radical.
- The score: 2 per character that serves the targets, +1 when a two-character name covers both, plus the sound.
  Ties fall in a hashed order from the surname's 繁 form, so 張 and 张 give one list. No character is in more than
  two names.
- The review gate holds both ways:
  - a test fails if any region of the shipped matrix offers 起名 while `LIBRARY.reviewed` is false;
  - the card's draft note follows the chart's `library.reviewed`.
  - The owner's steps are in docs/web-test.md. Tried on 2026-10-28 and undone: after them every test passes, once
    `npm run sync:app` has run.
- Tests switch the matrix through `MINGLI_GEO_MATRIX` (`withNaming` in test/helpers.ts), which the server also
  honours for ops.
  - Four tests would have failed on the owner's switch: two pinned the matrix version, two each region's method
    list. They now read the version from the matrix, and leave 起名 out of the order checks.
- Each method's user message is now built from shared `common` arguments plus the method's own. Every other method
  gets the same fields as before, and the prompt hashes still hold.
- 起名 has its own AI label (「依據候選名字生成」), its own facts layer (「陳氏 · 火、土」), and up to six
  paragraphs in 候選名字. History shows 「起名 · 陳」 in the reader's script.

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

## S8 地区精细化 (medium → v5.1.0)

Planned 2026-10-28, after S6, from what the owner's Phase 3 document still lists (rule 34: no owner decision on any
of it is recorded). Phase 3 §2.4 asks for a 国家 × 内容维度 matrix that covers five markets:

- 印尼: 屏蔽前世 / 通灵 / 降头;
- 马来西亚: 风水内容权重提升 (done, v4.4.0);
- 新加坡: 英语 / 中文双语权重;
- 台湾 / 香港: 擲筊 / 求签入口前置 (done, v4.3.0).

Its gate is 「Geo-Rule 五地区规则路由测试通过」. §2.5 (English everywhere) is mostly in place: every one of the app's
445 strings exists in English, and the glossary has English for the 风水 and 起名 terms except 双声 and 叠韵.

### WP8.1 Indonesia and its content blocks

- **Matrix 0.5.0:** a region `ID` (Indonesia, phase 3) with:
  - `legal_review: "pending"` and `service_available: false`, since every launch needs the owner's sign-off (the
    matrix's own note);
  - rule groups `global`, `en_common` and `id`;
  - a new content dimension, `content_blocks: ["past_lives", "mediumship", "black_magic"]`.
- **Rule group `id`** (compliance/prohibited_patterns.yaml), on top of the region's other groups. Like every rule,
  it is recorded while review is paused, and holds once it is on:
  - I001, past lives: 前世, 前生, 轉世 / 转世, 輪迴 / 轮回; past life, previous life, reincarnation.
  - I002, mediumship: 通靈 / 通灵, 靈媒 / 灵媒, 招魂, 問米 / 问米, 觀落陰 / 观落阴; spirit medium, mediumship,
    séance, channelling spirits, contacting the dead.
  - I003, black magic: 降頭 / 降头, 下蠱 / 下蛊, 蠱毒 / 蛊毒, 黑魔法, 黑巫術 / 黑巫术; black magic, santet,
    guna-guna, voodoo.
  - Each rule has `unless` negations (「不涉及前世」, "nothing about past lives") and block and allow cases (G5).
- **The model is told too**, since review is paused and a recorded hit still reaches the reader.
  - In a region with content blocks, every model call's user message ends with one line naming them:
    - the report's narrative and action;
    - 破除運勢 plans;
    - 一生运势.
  - The system prompts stay as they are, so no prompt version changes. Without blocks, the user messages are
    byte-identical to before (a test).
- **Tests:**
  - the rule cases;
  - an Indonesian reading, with ID switched on by a test matrix: the line in every call, a hit recorded;
  - Hong Kong's messages unchanged;
  - ID refused as shipped;
  - an invariant: no region of the shipped matrix serves while its `legal_review` is `pending` (rule 42).

### WP8.2 The five-region routing test, and Singapore's languages

- `test/geo-regions.test.ts`, the Phase 3 gate. For ID, MY, SG, TW and HK it checks:
  - service;
  - rule groups and content blocks;
  - the methods in entry order (起名 left out, rule 42);
  - the languages.
    ID is checked switched on by a test matrix, and refused as shipped.
- Singapore: English joins its languages, alongside 简体 (`locales: ["zh-Hans", "en", "zh-Hant"]`).
  - The app keeps starting in 简体 (owner, 2026-10-26).
  - Anything more the bilingual weight should change in the app is left to the owner.

### WP8.3 The reader's language is remembered

- Now: the app starts in 简体 (owner, 2026-10-26), and a language the reader picks is lost at the next start or
  reload. For English readers (§2.5) that means switching every time.
- Do:
  - save the picked language on the device, in secure storage like the profiles (no new dependency);
  - at start, use the saved language, or 简体 when none is saved.
- The glossary gains 双声 and 叠韵 (起名's sound notes) in three languages.
- Tests: a picked language survives a restart; without one the app starts in 简体 (the existing locale test).

Lessons: G5, rules 8, 34 and 42; P23 for the app.

### Phase 3, the rest: waits for the owner

- §2.2 Action Kit:
  - the tiers are products, and payment is out of scope (owner, 2026-10-27);
  - the audio tier needs a TTS vendor and its human review;
  - the 大师包 needs teachers (Phase 2 真人).
- §2.3 TikTok support:
  - the `/link` page and the email list need consent wording and a mail provider;
  - WhatsApp Business needs a Meta account and approved templates;
  - the free 生肖运势 PDF needs content from the real model (the owner's AI switch).
- §2.5:
  - an English model route (the owner chose one model for every agent: `deepseek-v4-pro`, and since v9.2.0
    `claude-opus-5-5`);
  - the App Store English listing (WP7.3).
- §2.6:
  - the RAG knowledge base needs a vector store and an embeddings provider, with their cost;
  - the fine-tuning evaluation spends on the real model.
- Indonesia's launch (the legal sign-off), and Singapore's bilingual weight beyond its languages.

### As built (v5.1.0)

- The content-block line goes to every user-message builder through `regionLine`. Without blocks it is empty and
  filtered out: a test compares the builders' output with and without it.
- The guard's `<region>` carries `content_blocks` too. Without blocks the key is left out, so its JSON is unchanged.
- **Found on the way:** the API server and `AuthService` read the matrix once, at start.
  - So docs/web-test.md's "no restart" for 起名 was wrong in v4.5.0 and v5.0.0 (rule 44).
  - Both now read it per request, as the pipeline always did and as Phase 3 asks (「矩阵支持热更新」).
  - A test registers in Indonesia on one running server, before and after the change. It fails against the old
    caching.
- `withMatrix(edit, work)` in test/helpers.ts replaces the one-off naming helper. `withNaming` and
  `withIndonesiaOn` are built on it.
- The saved language is read in `main()` before the first frame, so the app never flashes 简体 first. Storage that
  can't be read starts in 简体, and a save that fails only loses the choice.

## S9 Phase 3 门禁 (medium → v5.2.0)

The owner's documents end with: 「建议每个阶段结束前做一次 Gate 评审…Gate 未通过不进入下一阶段」. So Phase 4 (operations,
monitoring, A/B, the content back office) does not start until Phase 3's gate has passed. Phase 3's gate has five
items:

| Gate item                                       | State                                                         |
| ----------------------------------------------- | ------------------------------------------------------------- |
| 起名/风水输出全部通过 Compliance Guard 专项规则 | 风水: F001 / F002 (v4.4.0). 起名: no rule group yet → WP9.1   |
| Action Kit 音频审核流程跑通并留痕               | waits for the owner (Action Kit, a TTS vendor)                |
| WhatsApp 模板消息审核通过                       | waits for the owner (a Meta account, templates)               |
| Geo-Rule 五地区规则路由测试通过                 | done: test/geo-regions.test.ts (v5.1.0)                       |
| Fine-tuning 评估结论写入 ADR                    | waits for the owner (the evaluation spends on the real model) |

### WP9.1 起名's own rule group

- `naming` in compliance/prohibited_patterns.yaml, applied to 起名 output only (`METHOD_RULE_GROUPS`, as for 风水):
  - N001, a name decides fate: 名字 … 決定 / 注定 … 命運 / 一生; "a name decides … fate".
  - N002, a name as a cure or a charm: 改名 … 轉運 / 化解 / 招財, 旺夫名, 招財名; "change your name to fix your
    luck", "lucky name".
  - N003, a 吉凶 verdict on a name: 此名大吉, 名字大凶, 不吉.
- Negations are exempt (`unless`), so the AI label and the names card's note are allowed in all three languages
  (「不決定任何人的命運」, "a name decides no one's fate").
- Tests:
  - block and allow cases for each rule;
  - a 起名 reading holds N001;
  - the same text in a tarot reading is left alone (rule 8).

### WP9.2 The Phase 3 gate record

docs/phase-3-gate.md, in the form of docs/phase-0-gate.md:

- Phase 3's six deliverables, each with where it lives and its state;
- the five gate items, with evidence or what each waits for.

It is the material for the owner's gate review.

As built (v5.2.0):

- `naming` joins `METHOD_RULE_GROUPS` beside `fengshui`. The `unless` patterns also cover a negation after the
  verb (「改名不會帶來轉運」).
- The gate record gained the Phase 3 §4 test table, with each standard's test. Two tests were added for the English
  rows:
  - `app/test/locale_test.dart`: the same strings in all three languages, and English's Chinese limited to five
    listed keys;
  - `test/glossary.test.ts`: every term in three languages, keyed by its 简体 form.
- With this, nothing in the owner's Phase 3 can go further without the owner. Phase 4 waits for the gate.

## S10 算卦 (big → v6.0.0)

**Owner request (2026-10-28):**

> 添加算卦功能，对应自动撒钱币正反面，可以自己撒完自己填写，也可以自动填写。如果是自己填写撒卦，还需要自己填写精确时间，并且撒卦前提醒用户。也可以半自动撒卦，提前随机摆放好，然后让用户自己挑，等用户一个个选的时候记录顺序。也可以全自动。如果是自己填写的，需要提交；可以出八卦阴阳和各种词，可以预先对应卦辞，也可以等待更精准的AI卜卦。要求卦辞都是直抒胸臆，不用绕。

So 六爻 by coins (金錢卦), which S6 had parked as "not in the owner's document", is now the owner's own request. It is
its own method, `liuyao` (rule 8). It reads the 周易 text from `data/yijing/hexagrams.json`, the one source the
一生运势 report already reads (rule 4), and changes nothing of that report.

### WP10.1 The engine, the three ways to cast, and the API

- **The coins** (金錢卦, the classical rule): three coins per line, six tosses, the first toss the 初爻.
  - 背 counts 3 and 字 counts 2, so one 背 is 少陽 (7), two 背 少陰 (8), three 背 老陽 (9, moving ○) and three 字 老陰
    (6, moving ×).
  - Reference: 漢典「單錢」: 「擲三錢而成二面一背，象徵少陽之爻」.
  - Each coin falls either way with chance ½, so a line is 老陰 1/8, 少陽 3/8, 少陰 3/8, 老陽 1/8.
- **Three ways to cast**, as the owner asks:
  - `auto`: the server tosses. Like 求籤, all 18 coins come from HMAC-DRBG on the cast's own seed
    (HMAC(drawKey, "liuyao-seed/v1:" + draw id)), so the cast replays.
  - `pick` (半自動): 24 coins are laid out face down _before_ the reader chooses.
    - `POST /v1/liuyao/layouts` returns a draw id, the size and a commitment. The commitment is the SHA-256 of the
      layout, which comes from HMAC(drawKey, "liuyao-layout/v1:" + draw id).
    - The reader picks 18, one at a time, and the app keeps the order. Picks 1–3 make the 初爻, and so on up to
      16–18 for the 上爻.
    - The server rebuilds the layout from the draw id. The chart keeps the layout, the commitment and the picks, so
      anyone with the key can check that the coins were set out before the picking.
  - `manual`: the reader tosses real coins and enters each line, either three coins (字 / 背) or the line itself
    (6–9, for readers who count the faces another way).
    - The **cast time is required**: the local date and time, to the minute, and the time zone. A time that
      doesn't exist (a DST gap) or lies in the future is refused.
- **The cast time** gives the 年月日時 干支, with the year from 立春, the month from its 節 and the hour from the
  wall clock (子時 as the 八字 engine counts it). `auto` and `pick` use the server's time in the reader's zone.
- **The hexagrams:**
  - 本卦 from the six lines;
  - 變卦 with the moving lines turned, when any move;
  - 上卦 and 下卦 (八卦) with their images;
  - the King Wen number.
- **Which texts the reading rests on**, by 朱熹《易學啟蒙·考變占》, the common rule:

  | Moving lines | The texts read                                      |
  | ------------ | --------------------------------------------------- |
  | 0            | 本卦 卦辭                                           |
  | 1            | that line's 爻辭                                    |
  | 2            | both lines' 爻辭, the upper one first               |
  | 3            | 本卦 and 變卦 卦辭, 本卦 first                      |
  | 4            | the 變卦's two still lines, the lower one first     |
  | 5            | the 變卦's one still line                           |
  | 6            | 乾 用九, 坤 用六; any other hexagram: the 變卦 卦辭 |

- **Facts** (ChartFact `system: "liuyao"`, additive):
  - `{ mode, cast: { local, timezone, utc, ganzhi }, tosses, lines, primary, changed?, focus, pick?, audit? }`;
  - provenance: the texts are `traditional_text` (周易 通行本), and the coin rule and the focus rule are
    `common_consensus`.
- **API:**
  - `POST /v1/charts {system: "liuyao", mode, …}`;
  - `POST /v1/liuyao/layouts`;
  - migration 006 and OpenAPI;
  - the geo matrix offers `liuyao` by default.
- **Statistics:** `npm run verify:liuyao` (a harness gate, like 求籤). It covers 100 000 casts: the coins are fair,
  the lines come at 1/8 : 3/8 : 3/8 : 1/8, the hexagrams are uniform, and the layouts are fair. There is a
  non-vacuity test.

### WP10.2 直說: plain words for every hexagram and line

- The owner: 「卦辞都是直抒胸臆，不用绕」. Each of the 64 hexagrams, each of the 384 lines, and 用九 and 用六 gets
  one or two plain sentences that say straight out what it means for the reader.
  - Written by hand in 繁體 and English. 简体 comes from OpenCC in the build script, with 乾 kept (G18). The server
    never loads OpenCC (rule 36).
  - Tendency, never fate: no 注定 or 一定會, and no promises about money or health.
  - They follow the common readings (程頤, 朱熹), so their level is `common_consensus`.
- They are shown beside the original texts at once, with no AI and no waiting, as the owner asks (「可以预先对应
  卦辞」).
- Tests:
  - all 450 are present in three languages;
  - 简体 matches OpenCC;
  - English has no Chinese;
  - none matches the global rules.

### WP10.3 The AI reading

- Its own prompts, `narrative_liuyao@1` and `action_liuyao@1`, and no plan. Sections:
  - 卦象 (`liuyao_hexagram`): the hexagrams and the moving lines, in plain words;
  - 所問之事 (`liuyao_answer`): the answer to the question, said in the first sentence (go ahead, wait, or change
    course), then why;
  - 建議 (`liuyao_advice`).
- The style, the owner's words: 直抒胸臆, 不用繞. There is no hedging filler and no unexplained jargon. It is still
  tendency language, never a fixed fate.
- The brief: the hexagrams, the lines, the focus texts with their 直說, and the cast's 干支, in the reader's script.
- Faithfulness: a quoted text must be one of the cast's own, and a hexagram name must be one of its two.
- Its own AI label and facts layer.

### WP10.4 The app

- A 「算卦」 entry. The page offers the question, then the three ways to cast.
- **Before casting, a reminder**: be calm, ask one thing, and don't ask it again and again. For `manual` it adds
  how to toss (three coins together, six times, record from the bottom up) and to note the time.
- Each way to cast:
  - `auto`: the six tosses are shown one at a time, with a skip;
  - `pick`: 24 face-down coins. Each pick gets its number, the picks can be started over, and after 18 the cast
    turns them over in order;
  - `manual`: the time is required, then six rows (上爻 at the top), each with three coins or a line choice.
- **The hexagram card:**
  - the six lines, with the moving ones marked;
  - 本卦 → 變卦, with their trigrams, the time and its 干支;
  - the focus texts, each with its 直說.
- Then the AI reading, the reading page and history (「算卦 · 天雷無妄」).
- Keyboard access (the keyboard-access skill).

### WP10.5 The 周易 text checked

- `data/yijing/hexagrams.json` comes from one transcription, and 算卦 shows all 450 texts. It is compared with an
  independent one (維基文庫 周易, fetched raw, rule 41). Disagreements are settled against a scanned print
  (rule 39).
- The evidence goes in `docs/verification/zhouyi.md`.
- A correction changes the one source, so the 一生运势 report gains it too.

Lessons: G4, G7, G18, rules 8, 29, 34, 36, 39, 41, 42, 43; P23 for the app.

Order: WP10.1–10.3 as v5.3.0; then the owner's updates (S11) as v5.4.0, since one of them removes English and the
app's pages are better built after it; then WP10.4–10.5, the stage summary and v6.0.0 (pushed).

As built (v5.3.0):

- **The owner removed English support while S10 was under way** (S11). So the 直說 are in Chinese only: 繁體 by
  hand, 简体 by OpenCC. The English half already written was dropped, and 算卦 readings refuse `en`.
- The cast time follows the 八字 engine's clock policy, checked by hand in the tests:
  - 立春 counted by the instant: a New York cast on 3 Feb 2026 is 乙巳 at 13:00 and 丙午 at 17:00;
  - the day by the local date.
- The faithfulness check catches only what's clearly wrong, so the reader's own words in quotes pass:
  - another hexagram's full name;
  - a quoted phrase found only in other hexagrams' texts;
  - a 干支 that is neither the cast's nor last, this or next year's.
- A layout's coins never leave the server. The pick cast rebuilds them from the draw key and the id.
- `zhouyiText` is a read-only accessor in the yijing module, so 算卦 reads the one 周易 source. The 一生运势 facts
  are unchanged.

As built (v6.0.0):

- **WP10.4**: the page as specified, in Chinese only (after S11).
  - The texts on the card come from the facts. The 直說 and the trigrams' names come from
    `app/assets/i18n/liuyao.json`, synced from the server.
  - Every cast sends the device's time zone (`platform/time_zone*.dart`): the browser's IANA zone on the web, a
    whole-hour `Etc/GMT∓N` elsewhere.
  - The pick grid's coins are Pressables, so Tab and Enter pick them.
- **WP10.5** went further than planned, because a print turned up with a page transcription:
  - The text was compared with two transcriptions (維基文庫《周易》 and 《周易正義》). Then every text was looked up in
    維基文庫's line-for-line transcription of the 四部叢刊 photo-reprint of a 宋 print. The disputed readings were
    read in the scan itself, on 16 pages.
  - 125 strings were corrected. Most were 简繁 slips, some shared by all three transcriptions: 姤 初六 繫, 噬嗑 六三
    腊, 復 初九 and 坎 九五 祇. A whole line was in the wrong hexagram: 大有 九二 held 同人 六二's text.
  - The 大象 was checked too, since the 一生运势 brief reads it. 9 more errors were found there, e.g. 震's
    「虩雷…修身」 for 「洊雷…修省」.
  - Each correction is pinned to its match count in `ERRATA`, and `test/yijing.test.ts` holds the layout and the
    hand-checked lines.
  - Not done: reading the print page by page for the texts where its transcription already agrees with ours
    (docs/verification/zhouyi.md).

## S11 Owner updates (medium → v5.4.0)

**Owner request (2026-10-28), while S10 was under way:**

> 完成之后进行一定更新：塔罗牌内的简化的选择不同玩法的图标大小框要一样大，现在大小不一（单张，三张，凯尔特十字等等），干脆都
> 用一样大的图标，把字放在下方。另外这个软件不需要英文支持，可以移除英文。更新管理员信息，把位置定位北京。

- **WP11.1 The tarot spread choices:**
  - every spread gets the same size of box and the same size of icon, with its name below;
  - a test checks that every choice has the same size.
- **WP11.2 English removed:**
  - The app keeps only 简体 and 繁體. That means the language menu, the ARB files (the template becomes 简体) and
    the English branches in the app code.
  - A language saved as English starts in 简体.
  - Tests that assert English are removed or changed.
  - The server's `en` stays accepted for now: nothing calls it, and removing it touches every method's prompts and
    tables. Whether to strip it too is the owner's call.
- **WP11.3 The admin's location:** the seeded 管理员 profile is located in Beijing (北京).

As built (v5.4.0):

- `SpreadIcon` (tarot_spread.dart) picks the card width so each spread fits a 56 px square. A scaled picture would
  thicken the borders; this keeps them. Every choice is 84 px wide, with its name under the icon on one line. I
  looked at it rendered with Noto Sans SC.
- The ARB template is `app_zh.arb`. Its 34 metadata entries (placeholder types) moved over from the English file,
  which is deleted along with its generated class. The English branches in the app code are gone: the timeline
  widths, the 流年 and 流月 lines, the separators, and `Terms.short`.
- 管理员 is seeded in 北京 with the picked-place form, plus a legacy `beijing` key. `movedAdminSeed` moves only the
  untouched old Taipei seed.
- Server English (`en` in the API, prompts and tables) is kept: nothing calls it now. Removing it is the owner's
  call.

## S12 Owner updates (medium → v6.1.0)

**Owner requests (2026-10-28), after v6.0.0, three in a row:**

> 针对做好UI 算卦的铜钱，给动画翻拍。类似于塔罗牌那样的翻牌
>
> 塔罗牌 牌阵在手机版上要三个一排。现在只有两个一排。很难看
>
> 将算命分为东方和西方，东方的八字算卦风水求签为一组，西方的目前只有塔罗牌。之后可以添加。

- **WP12.1 The tarot spread choices three to a row on a phone.**
  - All five go in one row where they fit; elsewhere they share the width three to a row, every name in full.
  - A test checks 320, 360 and 412 px, a keyboard-focused chip, and a wide screen.
- **WP12.2 The home page in two groups:** 东方 (八字, 算卦, 风水, 求签) and 西方 (塔罗 for now).
  - Each group keeps the region's order inside it (求籤 first in Taiwan and Hong Kong, 风水 first in Malaysia).
  - A group none of whose methods the region offers is not shown.
  - A new method joins a group in one place.
- **WP12.3 The coins turn over like the tarot cards.** 算卦's coins are drawn as 銅錢: round, with a square hole.
  - 字 reads 乾隆通寶 round the hole, and 背 is plain.
  - 自動擲幣: each toss's three coins are thrown and spin from their other face, then land, and only then does
    the line show.
  - 自己挑幣: the coins lie covered in the tarot back's colours. A picked coin glows and carries its number. Once
    cast, the picks turn over one by one in the order picked; the rest dim.
  - The system's reduce-motion setting shows the faces at once.

Lessons: rules 3, 7, 15, 19, 22, 23, 24, 25, 27, 43, 46; the keyboard-access skill.

As built (v6.1.0):

- **WP12.1:** a chip is its label plus its 1 px outline, drawn inside on each side (measured: 96 → 98 px). A
  focused chip draws its outline outside, so focus never widens it.
  - At 360 px the card's inner width is 286 px: three chips of 90 px and two 8 px gaps.
  - The chips have no padding of their own.
- **WP12.2:** the groups are two sets in `home_page.dart`, beside the entries, in the region's order from
  `GET /v1/methods`. No region puts a 西方 method first today, so 东方 always leads.
  - Tests that open 塔罗 from home now scroll to it first (`openEntry` in test/support.dart): it sits below the
    东方 group, off a phone's first screen.
- **WP12.3:** `CopperCoin` (widgets/copper_coin.dart) turns as a tarot card does (`rotateY` with perspective, the far
  side mirrored back), over the same 500 ms.
  - A toss spins through five half-turns in 900 ms, rising as it goes, the coins 120 ms apart.
  - A reveal turns the picks 90 ms apart.
  - The face-down colours moved to `FaceDown` in design.dart, shared with the tarot back.
  - The inscription is drawn in the page's font. A TextPainter takes none of its own, and a test render without it
    showed boxes.
  - Two-digit pick numbers scale down rather than wrap.
  - Looked at rendered with Noto Sans SC: the toss rows, the covered grid, and the grid mid-turn and turned.

## S13 AI 追问 + 通俗解读 (big → v7.0.0)

**Owner request (2026-10-28):**

> 添加新功能，给每种算命添加AI追问功能，可以在其回答的基础上继续追问其他问题。不能胡编乱造，一定要基于之前的回答和各个
> 卦象所表达的东西持续给出后续问题。继续追问必须放在显眼的位置。另外给出的AI回答依旧很笼统，太多的术语，可以这样，术语在
> 前，评论在后，评论要尽量详细，比如说一个人性格很好，尽量可以通过举个例子去简单描述这个人。

Two parts. Every reading is written term first, then a detailed plain commentary, then an example (WP13.1). Every
reading can then be asked about further, from what it rests on and what it already said (追问, WP13.2–13.3). No
earlier owner decision touches either (rule 34: DEVLOG, README and git log searched).

### WP13.1 术语在前，评论在后 (medium → v6.2.0)

- **Every reading paragraph gets two fields**, additive: readings made before keep showing as they were.
  - `term` (术语): the facts the paragraph rests on, said the tradition's way, in one short line. Examples:
    「日主甲木，生于寅月（得令）」, 「第 3 张·根基：宝剑七（正位）」, a quoted 爻辭, 「床头靠实墙（背后有靠）」.
  - `text` (评论): what it means for the reader, in plain words and in detail. The conclusion comes first, then why.
  - `example` (举例): one everyday scene that shows it. For a kind nature: 「比如同事临时找你帮忙，你嘴上说“没事”，其实
    已经开始帮他想办法了」.
- **Prompts.** Each method gets a new reading prompt version with term examples of its own (rule 8):
  - narrative_bazi@7, narrative_tarot@4, narrative_astrology@2, narrative_qiuqian@2, narrative_fengshui@2,
    narrative_naming@2 and narrative_liuyao@2;
  - the 一生运势 report's two agents, life_methods@3 and life_topics@3. Each of their texts names its basis first,
    then gives the commentary and an example. Their fields stay as they are: the page already shows the 卦辭 or
    the period first.
- **Checks.**
  - As with `summary`, both fields are asked for but optional in the schema: a missing one never costs a
    regeneration.
  - Both are normalised for terms, scanned by the rule layer and read by the faithfulness checks.
- **The app.** The term comes first (bold, accent colour), then the commentary, then the example in a tinted box.
  Copy and download include them.
- **The mock** writes all three, so the layout shows with `IS_AI_MOCK=TRUE`.
- **Not provable here:** how well the real model follows the new prompts. `IS_AI_MOCK` is the owner's switch, so the
  first real readings are the owner's check (`npm run eval:ai -- --live` once the switch allows it).
- Lessons: rules 28, 29, 31, 32 and 42; G5.

As built (v6.2.0):

- `explained()` in prompts.ts writes each method's block from its own term and example; each new version is its
  previous one plus that block, so the old text stays pinned through the new hash.
- `paragraphTexts` (pipeline.ts) is what the rule layer and the faithfulness checks read. The app's
  `ReadingParagraph` shows a paragraph, and 追问 answers will reuse it.
- **Two more owner requests went out in v6.2.0:**
  - **The bug report** (「当我login不同账户时……运势报告人的姓名和出生地没有在表的record上体现出来」): the person's
    name and birthplace label now go with the chart as `person`. The server keeps them on the chart record, sealed
    in the database store, out of ChartFact and away from the model, and history and the reports show them on every
    device. This reverses the 2026-10-26 device-only rule (docs/data-retention.md). Rules 52 and 53.
  - **Three dev accounts:** qianli, wuyong and leonfighter, each with its login as its password.

### WP13.2 追问, the server (with WP13.3 → v7.0.0)

- **What can be asked about:** a passed reading of any method, or a 一生运势报告, by its owner.
  - One question at a time, 1–200 characters, and up to 20 per reading.
  - Each one takes one from the daily AI caps.
- **Its own pipeline, `generateFollowUp` (src/ai/followup.ts)**, as hard rule 2 asks:
  - Geo-Rule first: the reading's method must be offered in the account's region;
  - then the follow-up agent;
  - then the rule layer (the region's groups and the method's own);
  - then the guard, while review is on.
- **What the model reads:**
  - the same facts and brief the reading read: the spread, lot, cast, room or names, and for 八字 the focused view
    with any year the question names;
  - the reading itself: summaries, paragraphs and actions;
  - the earlier 追问 and their answers (the last six);
  - the original question, the context and the new question.
- **Not making things up** (the owner: 不能胡编乱造):
  - Every answer paragraph cites the facts it rests on (`fact_refs`, JSON pointers that must exist). One that cites
    none is dropped, and the answer is sent back.
  - The deterministic faithfulness checks run on every answer: 干支, cards and orientations, the lot's lines and
    number, the cast's hexagrams and texts, and script. An issue sends the answer back once, and a paragraph that
    still fails is dropped.
  - A question the reading can't answer gets `in_scope: false` and a plain reply saying what the reading does and
    doesn't speak to, with no claims. Such questions include another matter than the lot or the cast was for (一事
    一占), someone else's chart, exact dates, amounts, diagnoses and verdicts.
- **Each answer:**
  - 1–3 paragraphs in the WP13.1 form;
  - 2–3 suggested next questions that the reading can answer, shown as chips (the owner: 持续给出后续问题).
- **Prompts:** each method has its own, and each is pinned in method-prompts.test.ts:
  - followup_bazi@1, followup_tarot@1, followup_astrology@1, followup_qiuqian@1;
  - followup_fengshui@1, followup_naming@1, followup_liuyao@1;
  - followup_life@1.
- **API:**
  - `GET` and `POST /v1/reports/{id}/followups` (`{question}` → 202), and `GET /v1/followups/{id}`;
  - the same under `/v1/life-reports/{id}/followups`;
  - 409 while one is being answered or at the limit, and 400 for an empty or overlong question;
  - held answers appear in the review console (kind `followup`);
  - deleting the account removes them;
  - the database store has a table `followups` (migration 007), sealed under the owner's key;
  - the reading's own question is kept with it (sealed), so a 追问 knows what was asked.
- **Mock:** a grounded （示范） answer with suggestions.
- Lessons: rules 1, 16, 17, 32, 35, 37 and 44.

### WP13.3 追问, the app (→ v7.0.0)

- **Where it goes** (the owner: 显眼的位置): on every reading page and on the 一生运势 page.
  - A 「继续追问」 button floats at the bottom right from the moment the reading is ready. It brings the 追问 card
    into view and puts the cursor in its field.
  - On a reading page the card comes right after the reading, before 行动建议, in the accent colour. The jump
    list starts with 「追问」.
- **The card** holds, in order:
  - one line on what it does: the answer rests only on this reading;
  - the thread: each question, then its answer in the WP13.1 form;
  - the suggested questions (the method's starters before the first question);
  - the field with 发送.
  - While an answer is being written it shows the progress. At the limit, the field says so.
- **Keyboard access:** the button, the chips and the field can be reached with Tab, and Enter sends.
- **Tests:**
  - the card and the button on each method's reading and on the 一生运势 report;
  - asking, waiting and the answer;
  - a suggestion asks its question;
  - the limit, and the 409 and 429 messages;
  - the keyboard.
- Lessons: rules 7, 12, 17, 19, 25, 27, 33, 43 and 46; the keyboard-access skill.

As built (v7.0.0):

- **WP13.2, the server.**
  - `generateFollowUp` reads what the reading read: `readingInputs`, now shared with `generateReport`. For a
    一生运势报告 it reads `lifeModelInput`, the report's facts without the birth clock.
  - The answer is checked twice:
    - fact_refs must resolve;
    - `checkTexts` (faithfulness on any text) checks the paragraphs and the suggestions.
      A failing paragraph is dropped and the answer sent back once, with what was wrong.
  - Suggestions already asked, over 40 characters, or naming what the reading lacks are dropped.
  - A report now keeps its own question and focus, and a life report its context: the 追问 needs them for 一事一占.
  - `HttpError` carries a `code`: `followup_pending` and `followup_limit`.
  - `npm run eval:ai` asks one 追问 per passed case.
- **WP13.3, the app.**
  - The floating 「继续追问」 steps aside while the field and 发送 are on screen (`FollowUpScope` measures on every
    scroll). It is then out of the Tab order too. Found by a hitTestable check: at 412 × 900 it covered 发送 (rule 55).
  - The field is one line, so Enter sends. A field of several lines takes Enter as a new line.
  - The 一生运势 page builds all its cards (the cache extent, as the reading page does), so the button can bring up
    the last one.

## S14 以往记录：整理、下载、发送、删除 (big → v8.0.0)

**Owner request (2026-10-28):**

> 对于以往记录可以进行整理，也可以进行下载，发送和删除，下载后可以生成Word文档和PDF。点击发送也可以发送选择的文档。另外所有
> 归档文件可以按年和月排，日期由近及远。 如果给多人算过不同的类型，那么可以按人名字去归类。

No earlier owner decision touches it (rule 34). Since v6.2.0 a 八字 chart keeps its person on the server, which is what
grouping by person needs. Deleting a single record is new: until now only deleting the whole account removed anything.

### WP14.1 Word and PDF documents

- **Who builds what:**
  - The app builds a record's document: the reading or 一生运势报告, its chart summary, the 追问 thread, and the AI
    label with the disclaimer, which every export must carry (compliance/ai_disclosure_spec.md §4). It already
    builds the same content for copy and Markdown, and it has the labels, names and local dates.
  - The server renders it. `POST /v1/documents {format: pdf | docx, filename, document}` takes a neutral document:
    a title, then blocks (h2, h3, meta, p, summary, term, example, quote, bullet, kv rows, note, question,
    divider). It is checked (types, counts, lengths), needs a signed-in caller, and calls no model.
- **Word:** `docx` 9.8.1, a month-old release; 9.15.0 was a day old. The text is in an East Asian font
  (Microsoft YaHei), with the zh-CN or zh-TW language.
- **PDF:** PDFKit 0.19.1, with the server's Chinese font (`shareFont`, as share images use) embedded as a subset.
  - Measured first (G4): pdf-lib 1.17.1 + @pdf-lib/fontkit kept the text layer but drew no Chinese glyphs with the
    OTF and only some with the variable TTF, and failed on the TTC.
  - PDFKit drew every glyph with all three, at 24–64 KB, and wraps Chinese lines itself.
  - A TTC needs its face (msyh.ttc: MicrosoftYaHei).
  - No font on the server: 503, as for share images.
- Both file types carry the record's title as the file name: 命理大师-八字排盘-徐梅-2026-10-28.pdf.

### WP14.2 整理: by year and month, by person, filed under a person, deleted

- **The history page:**
  - **按时间:** year, then month, newest first. 一生运势报告 sit among the readings by date, no longer on top.
  - **按人:** one group per person, the group with the latest record first, each group newest first; records with
    no person under 未归类, last.
  - Up to 100 readings load (the API's most).
- **Whose record it is:**
  - The person kept with the chart (v6.2.0); then this device's label, for charts made before v6.2.0.
  - 起名 takes its 八字 chart's person.
  - New 塔罗, 求签, 算卦 and 风水 charts carry the reader's default profile name.
  - **归类到…** files any record under a person: a profile's name, a name typed in, or none. It goes through
    `POST /v1/charts/{id}/person`, which sets or clears the name and keeps a birth chart's birthplace.
- **Deleting**, after a confirmation that it can't be undone:
  - `DELETE /v1/reports/{id}` removes the reading, its 破除運勢 plans and its 追问;
  - `DELETE /v1/life-reports/{id}` removes the report and its 追问;
  - the chart goes too when no other record reads it (never a 每日一牌's).
  - A job still running for a deleted record never writes it back.

### WP14.3 Download and send, one or several

- **Each record's ⋮ menu:** 下载 PDF, 下载 Word, 发送, 归类到…, 删除.
- **Select (the toolbar button, or a long press):** tick several, then 下载, 发送 or 删除 for all. Download and
  send first ask PDF or Word.
- **发送** opens the system's share sheet with the documents. On the web that is the browser's share where it can
  share files (phones), and a download elsewhere.
- **The reading page and the 一生运势 page** offer 下载 PDF and 下载 Word in their own menus too.
- **Keyboard:** the view switch, the menus, the checkboxes and the action bar can all be reached with Tab.
- Lessons: rules 4, 6, 7, 12, 17, 25, 27, 33, 36, 43, 46, 52 and 53; G4 and G6.

As built (v8.0.0):

- **Libraries:**
  - `docx` 9.8.1 was a month old; 9.15.0 was a day old, and a release that fresh is a supply-chain risk.
  - PDFKit 0.19.1 (fontkit 2 inside), plus `@types/pdfkit` as a dev dependency.
  - pdf-lib and its fontkit were measured, then removed.
  - `npm audit`: 0 vulnerabilities after each step.
- **The PDF layout:**
  - A4 with 56 pt margins.
  - Bold is drawn as a fill with a thin stroke of the same colour, since one face is embedded.
  - The example sits in a tinted panel with an accent bar, a quote has a grey bar, and a question a grey panel.
  - Page numbers go in the bottom margin.
  - Looked at rendered: two pages, every block, page break included.
- **The font for a TTC:** `ShareFont.face` is the face's PostScript name: MicrosoftYaHei, NotoSansCJKsc/tc-Regular
  (CI's `fonts-noto-cjk`), PingFangSC/TC-Regular, or `MINGLI_SHARE_FONT_FACE`.
- **Deleting:**
  - the store gains `deleteReport`, `deleteLifeReport` and `deleteChartIfUnused`, a contract test on both stores;
  - the chart's rows go only when no reading or life report reads it.
- **Whose record:**
  - the server's person comes first now, so 归类到… shows at once; the device label is the fallback;
  - `relabelChart` keeps the device label in step, and clears it on 不归类;
  - `parsePerson` takes a name for any chart and a birthplace for birth charts only. The v6.2.0 test changed with
    the owner's request.
- **The app:**
  - the history page builds every record (up to 100 readings);
  - selecting is a mode, entered by the toolbar button or a long press;
  - a record's menu is a PopupMenuButton, its checkbox a Checkbox, so Tab reaches both.

## S15 菜单、图标、多种登录、报告发到邮箱 (big → v9.0.0)

**Owner request (2026-10-28):**

> 将各种设置放到breadcrum 菜单内，保证navigation干净。 同时给整个app一个合理的ICON。 同时还得做以下步骤，用户可以用用户名
> 或者邮箱登录或者手机号登录，手机号需要绑定用户本人。另外每当一个算法AI 算完成后，可以选择给邮箱发送报告结果（当然也可以不
> 用，这个可以再设置中默认， 默认为否，改为是后自动发送）。目前可以先把框架搭好，后面的设置可以慢慢来，包括手机号也是。至于需
> 要用什么技术和工具做这些，我们留到下一步再做。 做完了 你可以push。

Earlier decisions it touches (rule 34):

- **2026-10-27 (b), owner:** 个人资料, 语言 and 设置 went straight onto the home bar, "instead of ⋮". This request
  reverses that: the settings go into one menu.
- **"breadcrum 菜单"** is read as the ☰ menu (often called a hamburger menu): one button that opens the list of pages
  and settings. A breadcrumb trail holds no settings.
- **Phase 3 gate, item 3:** the email list waits for consent wording and a mail provider. Report emails are not that
  list. They go only to the account's own verified address, and only when its user turns them on.
- **Which provider sends mail and SMS** waits for the owner (留到下一步). This stage builds the framework: the
  interfaces, the flows and the settings, with a development outbox in place of a provider.

### WP15.1 ☰ 菜单 (medium → v8.1.0)

- **The home bar:** ☰, the title and 历史记录. The other buttons move into the menu.
- **☰ opens a side menu** (a Drawer):
  - a header with the app icon, the name and the signed-in account;
  - 历史记录, 个人资料, 语言 (the current one shown; 简体中文 / 繁體中文), 设置, 内容审核 (reviewers only),
    键盘快捷键 and 退出登录.
- **设置 in groups:** 账号与登录, 报告, 其他, then 退出登录 and 注销账号.
- **The sign-in page keeps 语言 on its bar:** there is no menu before signing in.
- **Keyboard:** ☰ is a Tab stop and Enter opens it. Focus moves into the menu, Tab stays inside it, and Esc closes it.
- **Tests:** the bar holds ☰ and 历史记录 only; each item opens its page; 语言 switches; Esc closes the menu; everything
  fits a 360-wide phone.

### WP15.2 App 图标 (with WP15.1 → v8.1.0)

- **One source:** the drawing in `scripts/app-icons.ts`, a 太极 inside the eight trigrams, gold on the app's 赭红
  accent. It is also written out as `app/assets/icon/icon.svg`.
- **`npm run build:icons`** (scripts/build-icons.ts, with sharp) renders every size from it:
  - Android's mipmaps;
  - iOS's AppIcon set, opaque as Apple requires;
  - the web favicon and the PWA icons, the maskable ones with their safe zone;
  - Windows's app_icon.ico.
- **Names:** under the icon the app is 命理大师, on Android, iOS, Windows and in the web manifest (it was mingli_app),
  with the accent as the theme colour.
- **The menu header** shows the same icon.
- **Tests:** every output exists at its size, the ICO holds its sizes, and the names are set.

As built (v8.1.0):

- **The menu** is the home page's Drawer.
  - Opening it adds a local history entry to the page, so the keyboard layer's Esc closes it with no new code, and
    Flutter moves the focus into it.
  - An item closes the menu first, then opens its page. 键盘快捷键 opens its list from the navigator.
  - 语言 opens a small dialog with the current language ticked and focused.
  - 内容审核 and 键盘快捷键 left 设置 for the menu. 退出登录 is in both: it ends 设置, as before.
- **The icon:**
  - 40 files from one drawing. iOS's set has 19 entries over 15 files, and each file is drawn once.
  - Up to 32 px the drawing is the 太极 alone, which stays legible on a browser tab.
  - Android gets an adaptive icon (a gradient background layer and a foreground in the safe zone) besides the legacy
    one.
  - The Windows title is written as UTF-16 code units, so main.cpp stays ASCII: the Edit tool turns a `\u` escape
    into the character itself (rule 56).
- **Looked at rendered**, with Noto Sans SC loaded: the bar, the menu (as a reviewer) and the 语言 dialog at 412×900,
  and the icon at 16–1024 px.

### WP15.3 用户名、邮箱或手机号登录 (medium → v8.2.0)

- **Every account can have three identifiers.** Each is unique and works with the same password:
  - a 用户名: 2–24 letters, digits, Han characters, `_ . -`, starting with a letter or a Han character;
  - an email;
  - a 手机号, which counts only once bound.
- **Login** takes one field, 用户名 / 邮箱 / 手机号, and tells the three apart:
  - with an @, it's an email;
  - digits, or a leading +, make it a phone;
  - anything else is a username.
- **Binding proves the number is the user's own:**
  - a 6-digit code goes to it, valid 10 minutes, 5 tries;
  - sending is limited per account and per number;
  - a number bound to another account is refused.
  - An email is verified the same way; reports go only to a verified email.
- **Delivery is a framework:** `MailTransport` and `SmsTransport`, with a development outbox for now.
  - Every message is written to `.outbox/` (git-ignored): .eml files for mail, which open in any mail program.
  - The console line names neither the address nor the content (security-baseline.md).
  - The provider comes next step, from the owner's choice. Until then, the app says that codes and mail stay on
    the server.
- **Sign-up:** 用户名 and 密码, the email optional. A phone is bound later, in 设置.
- **The dev accounts become usernames:** admin, xumei, qianli, wuyong and leonfighter. test@mingli.local stays an
  email. An account seeded before keeps its records: its seed is moved over.
- **Storage:**
  - the username and the phone are sealed with the email under the account's key;
  - HMAC lookups find them for login (migration 008);
  - pending codes are kept in memory only, as hashes, and expire.
- Data retention and OpenAPI are updated.

As built (v8.2.0):

- **Logins** (`src/auth/identifiers.ts`):
  - A phone number is kept in E.164. Plans give the national number's length for HK, TW, SG, MY, MO, CN, US, CA, GB
    and AU; any other calling code is taken as written.
  - A trunk 0 is dropped first: Malaysia's 012-345 6789 has 10 digits and fits its plan as written. This came to
    light while working the test's expectation out by hand.
  - A local number at login is read in every region whose length fits (8 digits: HK, SG, MO). It names an account
    only when exactly one of them is bound.
  - Every failed login gets one answer, whatever its kind.
- **Codes** (`src/auth/verify.ts`):
  - They are kept in memory, hashed with a per-process key.
  - A request is counted before the server looks for another holder, so a refused one counts too. That slows anyone
    probing which numbers have accounts.
- **The account** (`src/auth/account.ts`, routes `/v1/account/username | email | phone | settings`):
  - Problems carry codes: `username_taken`, `phone_taken`, `wrong_code`, `wait`, `last_login`, `email_unverified`,
    `delivery_unavailable` and more.
  - Sign-up's 400s carry them too (`username_invalid`, `email_invalid`, `password_weak`), so the app shows Chinese
    instead of the server's English.
- **The store:**
  - Migration 008 adds `username_lookup` and `phone_lookup`, unique as the email's lookup is.
  - The sealed column gains the username, the phone, when each was proved, and the settings.
  - A contract test covers a restart; the plaintext test now looks for a username and a phone too.
- **The dev accounts:** a login without an @ seeds a username. An account seeded before is moved over: the same id
  and records, the email removed. Reviewers match the username or the email.
- **The outbox:**
  - `OutboxMail` writes an .eml file, with a .txt beside it.
  - `OutboxSms` writes a .txt, and its console line shows the message (the code, never the number).
  - Without a provider, mail and SMS are off outside dev mode, and asking for a code answers 503.
- **The app:**
  - `AppUser` gains `username`, `emailVerified`, `phone`, `emailReports` and `login`.
  - The sign-in page has one `login` field; sign-up asks for a 用户名, with 邮箱 optional.
  - 设置 rows open `showContactDialog` and `showUsernameDialog`; `accountProblem` maps the codes to the reader's
    language.
- **Tests changed on purpose:** `auth.test.ts` (the 401's wording; the dev accounts are usernames) and the app's
  sign-in tests (the `login` field, the Chinese 401 message).

### WP15.4 报告发到邮箱 (→ v9.0.0)

- **The setting 测算完成后发到邮箱** is 否 by default, and can be turned on only with a verified email. When on:
  - every reading, of any method, and every 一生运势报告 that passes is mailed to that address;
  - the reading is in the message and attached as a PDF.
  - Held, blocked and failed reports are never mailed.
- **The server builds the automatic email's document** from the stored report's own layers. It renders the
  document as the message (HTML and text) and as the PDF.
- **Sending by hand:** 发到邮箱 in a record's menu and in the select bar sends the same PDF or Word file as 下载,
  built by the app as for 下载 (`POST /v1/documents/email`).
- **Each record notes its last mailing** (sent or failed, and when), and the reading page shows it. A failure is
  logged and never retried on its own.
- Lessons: rules 16, 17, 32, 36, 37, 42, 44, 52 and 54; G6.

As built (v9.0.0):

- **The documents the server writes** (`src/export/report-doc.ts`):
  - they use the app's labels in 简体 and 繁體, the time in the account's region, and the title as the app gives it;
  - a reading carries its details, the facts layer, the trend, the reading in three parts, the actions, the
    expectation and the AI label with the model;
  - a 一生运势报告 carries its six sections with the 卦辭 and 爻辭, and every text of the report. The figures stay
    in the app, and the mail says where to find them.
- **The mail** (`src/notify/report-mail.ts`, `src/export/render-html.ts`):
  - HTML with every style inline, a text part, and the PDF (named as the app names a download);
  - a line saying why it came and how to turn it off;
  - without a Chinese font on the server, the message goes alone.
- **When:** `mailWhenDone` runs after a reading or a 一生运势报告 is stored as passed, and when a reviewer releases a
  held one. It skips a held, blocked or failed report, a setting at 否, an unverified email, and a server with mail
  off.
- **发到邮箱** (`POST /v1/documents/email`):
  - 1–10 of the app's documents in one message;
  - 409 without a verified email, 503 with mail off, 502 when the provider fails, 429 past 20 a day.
- **The MIME** keeps every line within 78 characters:
  - encoded words of at most 39 bytes, so even the first, after the header's name, fits;
  - RFC 2231 pieces for file names;
  - parameters each on a line of their own.
  - The first draft let a header's name and its first piece run to 81.
- **The app:**
  - 设置 → 报告 has the switch, disabled until the email is verified, and a line when the server has no provider;
  - 发到邮箱 is in the record menu, and 发邮箱 in the select bar. The bar is now four equal slots, an icon over its
    label: four labelled buttons side by side overflowed a 360-wide phone by 15 px (caught by the test, rule 49);
  - the result replaces the 正在生成 note (rule 57);
  - the reading page shows 这份报告已发到你的邮箱, or that it failed. The 一生运势 page doesn't yet.
- **Looked at:** a real reading's mail in headless Chrome at 480 px wide; the select bar and 设置 → 报告 with Noto
  Sans SC.

## S16 Owner updates (medium → v9.1.0)

**Owner requests (2026-10-29), after v9.0.0, five in a row:**

> UI 的小改动，首先关于主页的历史记录，可以添加到breadcrumb里去。breadcrumb需要添加外框，更加明显。然后将其移动到右侧。
> 命理大师的text可以添加一些效果，比如前置一个svg的decor。
>
> 塔罗牌测试时，当选好牌阵 点击抽牌后，要navigate 到洗牌切牌和选牌的区域，否则用户不知道板块刷新了
>
> 最后求签要添加新的动画效果。目前太单调了。比如有个甩签的画面。
>
> 还有风水也是，点击看布局要 navigate 到新的生成的区域。
>
> 所以这类新生成的component 要避免用户下滑后再点击。最好点击的时候自动集中到当前的UI component

- **WP16.1 首页's bar.** 历史记录 off the bar and first in the ☰ menu (it was in both). ☰ framed and on the right, the
  menu sliding in from there. A mark before 命理大师, the name given an effect.
- **WP16.2 What a tap brings up comes into view.** One building block, used wherever a tap makes something below its
  button: 塔罗 (the ritual, its pick step, the spread, the reading request), 风水 (the principles), 求签 (the altar, the
  lot), 算卦 (the tosses, the coins laid out, the hexagram), 起名 (the names).
- **WP16.3 求签's animation.** The 签筒 shaken until a stick falls (甩签), and the 筊杯 thrown, in place of a text line
  that appeared at once.
- **WP16.4 The rule kept.** A MISTAKES rule and a test per page on a phone, so a new page keeps to it.

Lessons: rules 3, 22, 27, 43, 49, 50, 53, 55, 58; the keyboard-access skill.

As built (v9.1.0):

- **WP16.1:**
  - "breadcrumb" read as the ☰ menu, as in S15.
  - The mark is `BaguaMark` (widgets/app_title.dart): the icon's 太极 and 先天八卦, in the icon's order, drawn with a
    CustomPainter. Flutter shows no SVG without a package; a painter adds none and takes the theme's colours, light
    and dark. Its trigram lines are thicker than the icon's, for 34 px.
  - The name is bold, spaced 3 px, shading from the theme's 赭红 to gold (a ShaderMask).
  - ☰ is `MenuButton` (widgets/app_menu.dart): a 1.5 px 赭红 frame on a light tint. While it has the keyboard focus
    the theme's focus outline takes the frame's place.
  - The menu is the page's end drawer. Tab still reaches ☰ first; Esc and Tab inside the menu work as before.
- **WP16.2:** `BringIntoView` (design.dart).
  - When the part first shows, and again whenever its trigger changes, the page scrolls as little as it takes: the
    part ends 16 px inside the bottom, with what was tapped still above it. One taller than the view comes to the top.
  - A trigger waits 300 ms first: AppCard animates its size, and the part is measured once it has grown.
  - It scrolls with its own scroll activity, which lets taps through. Flutter ignores taps on a list during an animated
    scroll, and the test lost the tap on 擲筊 as it came up (rule 60).
  - When several parts ask at once, the last to ask wins. The throw that brought the lot also grew the rounds card,
    whose reveal came later and scrolled the lot away (rule 60).
  - With the system's reduce-motion on, it jumps.
  - The tarot ritual and the spread now line up at the top while one gives way to the other, so the one coming is
    measured where it stays.
- **WP16.3:** `QiuqianStage` (widgets/qiuqian_stage.dart).
  - The shake (1.8 s): the 签筒 rests, leans 35°, takes five thrusts along its length while its sticks rattle and one
    works its way out, then rights itself as the stick drops, bounces once and glows. The rounds card says 摇签中…….
  - The throw (1.1 s): the blocks leave a moment apart, tumble through six half-turns and land on their faces,
    painted by the rows' own `JiaobeiPainter`.
  - The rows and the button wait for each step: the round's row once its stick lies still, the throw's meaning once
    the blocks land, the next button after that.
  - 直接看结果 and reduce-motion show each step's end at once. The label on the cylinder is 签 or 籤, in the page's
    font (rule 50).
- **Fixed on the way:** VS Code's CMake extension made `.vscode/` and `build/` at the top of the project. Prettier
  reads them, so the lint gate would have failed. Both are now git-ignored (Prettier 3 reads .gitignore).
- **Looked at rendered** with the real font: the bar in light and dark, the menu, eight frames of the shake and five of
  the throw, the stage in dark, and the tarot ritual and 风水 principles after the tap on a 360 × 740 phone.

## S17 Claude 与模型选择 (medium → v9.2.0)

**Owner request (2026-10-29), after v9.1.0:**

> 添加除了添加deepseek ai之外也添加cluade ai api call service. 并且再添加可以用的modal。现在希望用claude opus 5.5作为api service

Read as: keep DeepSeek, add Claude as a second AI service, list the models that can be used ("modal" read as model),
and answer with Claude Opus 5.5 from now on. This replaces the owner's choice of 2026-10-26 (`deepseek-v4-pro` for
every agent). The owner's switch stays as it is: `IS_AI_MOCK=TRUE` keeps every step on the mock until the owner flips
it, and Claude needs a key in `.env`, which only the owner can add (the owner added `CLAUDE_API_KEY` and
`ACTIVE_AI_MODEL` during the work).

- **WP17.1 Claude ready to serve.** `AnthropicProvider` has been kept since Phase 1 but never routed. It streams every
  request (the SDK refuses an unstreamed one above about 21,000 max_tokens, and the narrative route asks for 32,000),
  sends only what each model accepts, counts cache writes, and is tested through the real SDK over a fake network as
  well as with a fake client.
- **WP17.2 The models to choose from.** One list of the usable models (`src/ai/models.ts`): provider, limits, list
  prices, what each is for. The routing table is checked against it. `ACTIVE_AI_MODEL=<id>` in `.env` picks one model
  for every AI step, followed without a restart like the AI switch; `npm run ai:models` lists them; `eval:ai --model`.
- **WP17.3 Claude Opus 5.5 by default.** Every route goes to `claude-opus-5-5`, with an effort and max_tokens sized for
  its thinking; the console line, `/v1/health` and the docs name the model.

Lessons: rules 12, 26, 42, 44, 54; G7.

As built (v9.2.0):

- **WP17.1:**
  - `AnthropicProvider` streams (`beta.messages.stream(...).finalMessage()`). A probe confirmed the SDK's guard: an
    unstreamed request reaches the network up to 21,333 max_tokens and is refused from 21,334 (rule 62).
  - Structured outputs, the cached system prompt and the route's effort, as before; no thinking parameter (adaptive is
    the only mode on Claude Opus 5.5). The refusal fallback (`fallbacks: "default"`) goes only to models that have one
    (`MODELS[].fallback`: not Claude Haiku 5.5, nor a model outside the list). The answer is read by block type, after
    any thinking block. Usage keeps cache writes (`cache_creation_input_tokens`, additive; other traces keep their
    shape).
  - The key: `CLAUDE_API_KEY` (the owner's name) before the SDK's own `ANTHROPIC_API_KEY` / `ANTHROPIC_AUTH_TOKEN`. A
    test checks it is the key sent while other Anthropic variables are set too.
  - Checked once with the owner's key against Anthropic's Models API (free, no tokens): accepted from this computer;
    `claude-opus-5-5` reports a 1M context, 128,000 output tokens, structured outputs, adaptive thinking and medium
    effort; all four Claude models in the list are open to the account.
- **WP17.2:**
  - `src/ai/models.ts`: Claude Opus 5.5, Fable 5.1, Sonnet 5.5 and Haiku 5.5 from Anthropic's catalog (2026-10-29), and
    DeepSeek V4 Pro, without a price (not checked). `checkRouting`, `withModel`, `costUsd`.
  - `ACTIVE_AI_MODEL` (the owner's name; first written as `MINGLI_AI_MODEL`) is read with the AI switch by `watchAi`,
    which replaces `watchAiMode`: one notice per saved change; an id outside the list is said and ignored. The API takes
    its routing per job (`ApiOptions.routing` is a getter now), and so do the demo and the eval.
  - The owner's `.env` said `ACTIVE_AI_MODEL=claude-v1`, Claude 1's name, long retired. It now says `claude-opus-5-5`,
    as the owner asked. The switch (`IS_AI_MOCK=TRUE`) is untouched.
  - `npm run ai:models`; `eval:ai --model <id>`, which records each case's model and its cost at list price.
- **WP17.3:**
  - `config/model_routing.json` v6: every agent on `claude-opus-5-5` at effort medium, Opus 5.5's own default
    (Anthropic's notes put it above Opus 5 at high). max_tokens is 64,000 for the reading and the 一生运势 steps and
    32,000 for the rest, since thinking counts toward it.
  - The console line names the model and what is still missing (a key, the switch). `/v1/health` adds `ai_model` while
    a real model answers (OpenAPI updated).
  - Tests no longer pin the shipped model, except one that records the owner's choice. Five tests that had scripted a
    provider under `deepseek` alone now set it under both keys (rule 63).
- **Not done:** a real Claude reading. It waits for the owner's switch.

## S18 八字 AI 解读 (medium → v9.3.0)

**Owner requests (2026-10-29), after v9.2.0, two messages:**

> 八字排盘AI算法需要更新，当给AI去运算时，只需要给出当前人的资料和具体背景和问题，让AI给一个详细且具体并且符合UI 的角度过程。
> 行动建议可以不用做了。还有运势要尽量详实具体，且不绕弯子直接说就行了。另外·比如XXX` 这样的例子可以不用做了，可以移除。一定要给出
> 总结，比如XXX 你是一个XXX样的人，过去怎么样，现在怎么样，可能会有什么问题，会有什么得势或者得失，未来的运势怎么怎么样，从什么时候开始
> 要注意，从什么时候开始要发力，当你遇到问题时该怎么办等等等等，越详尽越好。
>
> 一个是引擎解读，一个是ai解读，可以把button label改成 ~用AI做更精确解读~，ai解读时尽量不采用引擎数据，但是ai prompt要做好规范，且
> 回馈数据要完整符合用户需求。这些要求可以写到skill去

Read as: for 八字 only (rule 8), the AI reading becomes the AI's own analysis beside the engine's. The engine's reading
stays where it is (the 命盘事实 card, the trend chart, the 破除运势 plans). "尽量不采用引擎数据" is read as: the AI gets
the person (the 排盘, their background from the profile, their question) and none of the engine's judgements. The
排盘 itself stays the engine's (pillars, 大运, 流年 years and 干支): a model left to reckon 干支 gets years wrong (the
DeepSeek runs once called 2027 丙午), and every reading must match the chart on its page (CLAUDE.md rule 1).

- **WP18.1 What the AI reads.** The 八字 reading's view leaves out the engine's judgements: `strength` (its 扶抑
  count, 得令, 喜用 and 忌), `wuxing_weighted` (its weighted score) and `trend` (its period scores). It keeps the
  排盘: pillars with 藏干, 十神, 十二长生 and 纳音, 日主, 月令, the five-element count, 合冲刑害破, 神煞, 空亡, 胎元,
  every 大运 and 流年. 追问 reads the same view.
- **WP18.2 What the AI writes (narrative_bazi@8).** A new, self-contained prompt: the AI judges 旺衰, 格局, 调候, 喜用
  and each period itself and says how. Every UI section (五行, 性格, 事业财运, 婚姻感情, 大运流年, 健康) in detail, 术语 then
  评论, no 比如 example; 大运流年 the most detailed, by years; said straight (不绕弯子), with the safety basics kept. A
  required 总结 in nine parts: who they are, the past, now, what may go wrong, 得势与得失, the years ahead, from when to
  take care, from when to push, what to do when trouble comes. No 行动建议: 八字 has no action step any more.
- **WP18.3 The app.** The 八字 button says 用AI做更精确解读. The reading opens with the 总结 card (a jump chip too); the
  行动建议 card shows only when a reading has actions (older 八字 readings, other methods). Exports, report emails and
  追问 carry the 总结.
- **WP18.4 The rules kept.** A project skill, `ai-reading`, with the owner's requirements for AI readings and how they
  are checked; CLAUDE.md names it. Tests pin the new prompt, the view, the 总结 and the pages.

Lessons: rules 12, 26, 28, 29, 32, 42, 53, 54, 58, 59; the keyboard-access skill.

As built (v9.3.0):

- **WP18.1:** `baziView(…, { trend: false, judgements: false })` in `readingInputs`, so the reading and its 追问 read
  the 排盘 alone. A 破除运势 plan's view is byte for byte as before: it keeps the engine's 喜用. A probe that sent the
  judgements again failed both view tests.
- **WP18.2:**
  - narrative_bazi@8 is self-contained: the analysis (旺衰, 格局, 调候, 喜用 and how each period meets the chart)
    is the model's, every section's content is spelled out, 大运流年 gets one paragraph per period in focus, and the
    text says it straight with the safety basics kept.
  - narrative_bazi@7 and action_bazi@4 moved to `RETIRED_PROMPTS`, still pinned at their released hashes.
  - `baziNarrativeSchema` has no `example` and requires `conclusion`, whose nine parts are all required. Each part is
    grounded as a paragraph is: one that cites nothing is sent back, then left out and counted.
  - 大运流年 keeps up to six paragraphs.
  - The rule layer and `checkFaithfulness` read the 总结.
  - `METHOD_PROMPTS.bazi` has no action prompt; the pipeline skips the step and the review sees the 总结.
  - The mock writes a （示范） 总结, and gives an old scripted 八字 narrative one, so tests keep reading their own
    sections.
- **WP18.3:**
  - The 八字 ReportRequest says 用AI做更精确解读; every other method keeps 生成 AI 解读.
  - The 总结 card opens the AI part, after the engine's facts, with a 总结 chip in the jump list.
  - The 行动建议 card and its chip show only when a reading has actions.
  - Word / PDF, Markdown, the report email and 追问 carry the 总结. The parts' list reaches the app through
    sync:app (`conclusionParts`), with their labels in the ARB files.
- **WP18.4:** `.claude/skills/ai-reading` holds the owner's requirements and how each is checked; CLAUDE.md lists it
  and notes the reading under hard rule 1. Every test that used the 八字 fixture for 举例 or 行动建议 now uses the
  tarot one.
- **Not done:** a real reading, which waits for the owner's switch. `npm run eval:ai` now records each 八字 case's
  总结 and how many of its parts came back.

## S19 深度分析、麦克风、同名重算 (big → v10.0.0)

**Owner requests (2026-10-29), after v9.3.0, in several messages** (the 积分 ones went to S20 when the owner wrote
「收费系统可以留到以后做，现在主要要精炼一下ai测算系统」):

> 可以添加补充细节功能，细节对话功能，相当于在进行ai分析结果的时候会根据卦象或者推算结果再去问对方问题，越多了解越好。对于打字不方便的
> 用户可以增加麦克风输入的要求。还可以根据用户的问题进行补充，打个比方，·你说你最近像要跟对方分手，你对象知道吗？· 然后他说，知道，可以以此
> 再做补充，，你还可以说，·我从结果上看到你跟她现在的确有问题，可能事她在外面有了别的什么事你都了解吗· 他说·不知道，不过我也不想知道，我就像
> 跟她分了之后我还能不能找到对象等等...· 要根据用户的输入做出合理推断。使用细节对话可能要需要更多的token，但是功能更加齐全，如果用户一开始没有
> 给出具体背景，要提醒用户，使用这一功能一定要给出个明确的目标才行。
>
> 对于已经算完的卦，对于同一人名的人要提问说之前已经算过，是否还要重新再算一次
>
> 引入积分系统，按 10元=1000积分 …… 保证利润在50%基础以上查看一下目前opus5.5的token兑换，做一个详细的规划和实现。看看有没有办法知道当前的
> 提交问题给花费了多少，以此反馈到积分上去。为了节省预算，我们可以暂时采用模拟策略。给所有dev给个相应的分数去进行计算。
>
> 对话了解阶段给一个统一的收费，对于比较不顺的命盘可以多问几个问题，顺的命盘少问一些，最多不超过6个问题。
>
> 在深度分析时，问问题时要提醒用户，~大师现在有问题要问你~，问完后才能给你最终解答
>
> 需要更改一下，50快不是1250积分。是增加25%。我算错了。每多10块加5%

Read as:

- **深度分析** (the owner's 细节对话 / 对话了解阶段): before the reading, the master asks the user about their
  situation, one question at a time, from what the chart or the draw shows and what they said they want to know. It
  infers from every answer (「合理推断」), may shift what the reading answers (the breakup example: from "does she
  have someone" to "will I find someone after"), and asks 1–6 questions: fewer for a smooth chart, more for a hard
  one, never more than six. The page says 「大师现在有问题要问你」 and that the final reading comes after the
  questions. It needs a clear goal: without one the app asks for it first. The final reading then reads the whole
  conversation. For 八字, 塔罗, 求签, 算卦 and 风水 (起名 is off; astrology has no page).
- **麦克风:** a mic button types what the user says, where the browser can (the web's speech recognition); elsewhere
  it isn't shown, and the phone keyboard's own voice input does the same.
- **同名重算:** before a new 测算 for a person with a finished one of the same method (for a 卦, the same question too),
  the app asks 「之前已经算过，是否还要重新再算一次？」 and offers the earlier one.
- **积分** waits (S20), and with it the 深度分析's flat fee.

### WP19.1 深度分析, the server (→ v10.0.0)

- `generateInquiryTurn` (src/ai/inquiry.ts), a fifth pipeline (CLAUDE.md rule 2): Geo-Rule → the method's own
  inquiry prompt (`inquiry_<method>@1`, rule 8) → grounding, faithfulness and the rule scan. A turn: what the master
  says (an opening observation, or an inference from the last answer, citing the facts it rests on), the next
  question, how many questions it plans (1–6, by how smooth the chart is for the goal), what the user most wants to
  know now (focus), or done. It reads the reading's own view of the chart (for 八字 the 排盘 alone, S18).
- `POST /v1/inquiries` (a chart and a goal of at least 4 characters, else 400 `goal_required`),
  `POST /v1/inquiries/{id}/answers`, `GET /v1/inquiries/{id}`: one turn at a time in the background, at most six
  questions; when the master is done, or the sixth is answered, it is ready. A failed turn after the first ends
  the questions (the reading goes on with what was said); a failed first turn fails the 深度分析.
- `POST /v1/reports` with `inquiry_id`: the reading reads the conversation (`<inquiry>`: the goal, every question
  and answer, the master's understanding), through a new narrative prompt version per method with the rules for
  it. The report keeps the `inquiry_id`; deleting the report deletes its conversation.
- The store keeps the conversation sealed under its owner's key (PGlite migration 009).

### WP19.2 深度分析, the app (→ v10.0.0)

- 深度分析 beside the AI button, for the methods that have it. Without a goal (the question asked before the draw,
  or the profile's 想了解的事 for 八字), a dialog asks for one first: 使用深度分析，一定要先给出一个明确的目标.
- The conversation page: 「大师现在有问题要问你」 and 回答完才能给你最终解答, the master's words and question, the
  answers, which question it is, 跳过剩下的问题, then 开始最终解读 to the reading. Leaving asks first.
- The reading shows its conversation (大师问了你 N 个问题), folded.

### WP19.3 麦克风 (→ v10.0.0)

- A mic button on the 深度分析 answer, the goal and the 追问 fields: the browser's speech recognition on the web
  (简体 zh-CN, 繁體 zh-TW), hidden where there is none. Chrome sends speech to Google, which mainland China can't
  reach: Edge and Safari work there; the button says so when the browser fails.

### WP19.4 同名重算 (→ v10.0.0)

- The history items carry the reading's question. Before 排盘 (八字) for a person with a chart, or a new 卦 (塔罗,
  求签, 算卦, 风水) for the same person and the same question as a finished reading: 「之前已经算过，是否还要重新再算一
  次？」 with 查看之前的 and 重新再算.

Lessons: rules 17, 37, 42, 44, 52, 53, 55, 58, 59, 61, 63, 64; the keyboard-access and ai-reading skills.

As built (v10.0.0):

- **WP19.1:**
  - `inquiry_bazi@1`, `inquiry_tarot@1`, `inquiry_qiuqian@1`, `inquiry_liuyao@1`, `inquiry_fengshui@1`, written from one
    frame: what each method reads, what makes its result smooth or hard for the goal (more questions for a hard one),
    the turn's fields, and the safety basics. A question may ask what the user knows of another person's situation,
    never claim or hint that anyone cheats, lies, is ill or breaks the law: the owner's example
    「可能是她在外面有了别的什么事你都了解吗」 becomes 「她那边最近有没有什么你还不清楚的情况？」.
  - The pipeline drops `fact_refs` that don't exist, sends back a turn naming a card, a line or a 干支 the result
    doesn't have, a repeated question and a first turn without a question; `planned` is clamped to 1–6, and after
    the sixth answer the master only closes. The `inquiry` route is Claude Opus 5.5 at effort low (the user waits for
    each question), max_tokens 8,000. `withModel` now leaves a route alone when `ACTIVE_AI_MODEL` names the model it
    already has: the owner's `.env` names claude-opus-5-5, which had put every step, these questions too, at medium.
  - The readings: `narrative_bazi@9`, `narrative_tarot@5`, `narrative_qiuqian@3`, `narrative_liuyao@3`,
    `narrative_fengshui@3` = the released texts plus `inquiryRules`; the five released versions moved to
    `RETIRED_PROMPTS`, still hashing to their pins.
  - The API: `/v1/inquiries` (thinking → asking → … → ready, failed, closed), `inquiry_id` on a reading, the
    receipts count `inquiries`; migration 009 (sealed bodies); history items carry `question`.
- **WP19.2:** `InquiryPage` (banner, bubbles, progress, answer field, 跳过, ready card, 重新开始); the 深度分析 button and
  its note on the methods in `inquirySystems` (synced from the server); the goal dialog; `InquiryRecap` on the
  reading. Each BringIntoView has its own key (rule 65).
- **WP19.3:** `SpeechInput` with the browser's recognition on the web (`webkitSpeechRecognition` or
  `SpeechRecognition`), `VoiceInputButton.suffix` on the answer, goal and 追问 fields; errors say what to do.
- **WP19.4:** `confirmRecalc` before 排盘 (八字, and 一生运势 by its reports), 抽牌, 求签, 摇卦 and 看布局.
- **Not done:** a real conversation, which waits for the owner's switch; 追问 after a 深度分析 reading reads the
  reading, not the conversation; exports don't carry the conversation; held turns have no review console.

## S20 积分 (big → v11.0.0)

**Owner requests (2026-10-29):** planned during S19 (「引入积分系统，按 10元=1000积分 … 保证利润在50%基础以上 … 看看有没有
办法知道当前的提交问题给花费了多少，以此反馈到积分上去。为了节省预算，我们可以暂时采用模拟策略。给所有dev给个相应的分数去进行计算」;
「对话了解阶段给一个统一的收费」; 「50快不是1250积分。是增加25%」, 「每多10块加5%」), then deferred
(「收费系统可以留到以后做」), then asked for: 「GO AND BUILD THE POINTS SYSTEM NOW」.

Read as:

- **Packs:** 1 元 = 100 积分, 5% more for each 10 元 from 20 元 up, to 25% at 50 元: 10 元 = 1000, 20 元 = 2200,
  30 元 = 3450, 40 元 = 4800, 50 元 = 6250. They live in config/points.json, so the owner can change them.
- **Every AI request is paid at what it cost:** each call reports its tokens and each record keeps them per step
  (`agents[].usage`); `costUsd` prices them at the model's list price (Claude Opus 5.5: $4 / $20 per million input /
  output tokens, the claude-api skill). The charge is that cost at the price that keeps a gross margin of at least
  50% on the cheapest 积分 (the 50 元 pack's), after the payment fee (0.6%, 微信 / 支付宝) and VAT (6%), at a cautious
  7.3 CNY per USD: 50 × (1 − 0.006 − 0.06) / 6250 = 0.007472 元 per 积分, so 7.3 / (0.5 × 0.007472) = 1,953.96 积分
  per dollar of tokens. A model without a list price (DeepSeek) is priced as Claude Opus 5.5.
- **模拟策略:** while the mock answers (`IS_AI_MOCK=TRUE`) no tokens are reported, and a request is charged its
  estimate instead, so the whole flow can be tried without spending. 充值 is simulated in development (a pack's
  积分 arrive without payment); the dev accounts start with 10,000 积分 each, given once.
- **The 深度分析's 统一收费:** one flat fee for the conversation, however many questions the master asks (1–6), charged
  once its first question has come; the reading after it is paid as any reading. The fee covers five typical turns
  and one at its largest; a turn that would take the spending past what the fee allows at the margin closes the
  conversation instead (the reading goes on with what was said).

### WP20.1 The price of a request (→ v11.0.0)

- config/points.json: the packs, the pricing terms, the hold factor (1.5), the dev grant and the estimates.
  Estimates are tokens per request (all its steps, without the guard, which is paused): measured inputs from the
  prompts the pipelines build (2026-10-29, a scratch script over the mock, 1.3 tokens per CJK character and 3.5 per
  other character), and the output a reading of each kind should write, Claude's thinking included (it bills as
  output). 八字 grows per topic asked, 塔罗 per card.
- src/points: `pointsPerUsd`, `pointsFor` (rounded up), `quote` (the estimate at the price of the model the routing
  gives the request's main step now, so `ACTIVE_AI_MODEL` moves every price), `inquiryFee`, `measuredCost`.
- At Claude Opus 5.5:

  | Request                    | Input tokens | Output tokens | Cost   | 积分  |
  | -------------------------- | ------------ | ------------- | ------ | ----- |
  | 八字 AI 解读 (six topics)  | 8,000        | 16,000        | $0.352 | 688   |
  | 塔罗, one card             | 9,440        | 8,820         | $0.214 | 419   |
  | 塔罗, three cards          | 10,720       | 9,860         | $0.240 | 470   |
  | 塔罗, ten cards (凯尔特)   | 15,200       | 13,500        | $0.331 | 647   |
  | 求签                       | 7,000        | 7,000         | $0.168 | 329   |
  | 算卦                       | 8,000        | 8,000         | $0.192 | 376   |
  | 风水                       | 6,800        | 7,000         | $0.167 | 327   |
  | 一生运势报告               | 24,500       | 26,000        | $0.618 | 1,208 |
  | 追问 on 八字               | 17,000       | 3,500         | $0.138 | 270   |
  | 追问 on 一生运势报告       | 25,000       | 3,500         | $0.170 | 333   |
  | 追问 on the other methods  | 8,000        | 3,000         | $0.092 | 180   |
  | 破除运势 plan, 八字        | 8,700        | 6,000         | $0.155 | 303   |
  | 破除运势 plan, 塔罗        | 4,500        | 5,000         | $0.118 | 231   |
  | 深度分析 (统一收费, 5 + 1) | 6,200 a turn | 1,500 a turn  | $0.382 | 747   |

### WP20.2 The ledger (→ v11.0.0)

- Per account: the balance, every change (grant, top-up, charge: what it paid for, how it was priced, the measured
  cost) and the holds of running jobs. In both stores (memory; PGlite migration 010); holding is atomic, so two
  requests can't spend the same 积分. Holds belong to running jobs and no job survives a restart: a database opens
  with none. Deleted with the account (simulated 积分 only; real payments keep records by law, Phase 4).

### WP20.3 Charging every AI request (→ v11.0.0)

- Readings, 一生运势报告, 追问, 破除运势 plans and the 深度分析: the price is held before the job (402 `points_short`
  with what it needs and what is available, before anything is made or any daily AI cap is taken); when the job
  delivers, its measured cost is charged, at most what was held; a failed or held job is charged nothing.
- With 积分 on, 破除运势 plans are made when bought, never preloaded: a preload spends tokens nobody pays for, which
  the margin can't carry (the preload came from the owner's 「plans should open faster」, 2026-10-26; a bought plan
  now takes about a minute).
- API: `GET /v1/points` (the balance, what is held, the packs, the latest changes), `POST /v1/points/top-ups`
  (simulated in development; 501 elsewhere until Phase 4), `GET /v1/charts/{id}/quote` (what each request on the
  chart costs), and the price on the 追问 and plan lists. `MINGLI_POINTS=off` turns it all off.

### WP20.4 积分 in the app (→ v11.0.0)

- 我的积分 in the ☰ menu with the balance; its page: what is available and held, the packs (模拟充值 while
  simulated), how charging works, and every change.
- Every AI button says what it costs (约 N 积分; the 深度分析 its 统一收费); 积分不足 offers 去充值.

Lessons: rules 12, 17, 35, 37, 42, 44, 45, 49, 58, 59, 63, 66; G7; the keyboard-access skill.

As built (v11.0.0):

- **WP20.1:** `src/points/pricing.ts` and `config/points.json` as specified; `checkPointsConfig` holds the packs to at
  least 100 积分 a 元 and every method to an estimate. The prices in the table above are pinned in
  test/points.test.ts with their arithmetic, at Claude Opus 5.5 and through `withModel` (Sonnet 5.5 halves them, a
  model without a list price is priced as Opus 5.5).
- **WP20.2:** `PointsLedger` in both stores: the in-memory one checks and writes without awaiting in between; PGlite's
  `holdPoints` locks the balance row (`FOR UPDATE`, right on PostgreSQL too) in a transaction, and PGlite runs every
  query through its transaction lock, so two holds at once can't both succeed (tested with 2 and with 10 at once).
  Migration 010 (`points_balances`, `points_entries`, `points_holds`); the receipts count `points`.
- **WP20.3:** `holdForJob` (the price held, then the daily AI caps; a refusal of either takes nothing) and
  `settleHold` in every job: the reading, the 一生运势报告, 追问, the plan and the 深度分析 (its fee settles after the
  first turn; `fee` is kept on the conversation, and `inquiryOverBudget` closes it before a turn the fee can't carry).
  The reading's checks (focus, context) moved before the hold, so a bad request holds nothing. The plan record's
  payment is `{ status: "points" }`. `MINGLI_POINTS` (`pointsOn`), `grantDevPoints`, `/v1/health` `points`. 402
  problems carry `need` and `available` (`HttpError` takes extra fields).
- **WP20.4:** 我的积分 (`PointsPage`) and its ☰ entry with the balance; `PriceLine` under the AI, 深度分析 and 一生运势
  buttons (the reading's quote is asked for with the topics chosen, and shared with the 一生运势 button); the 追问 line
  says what one more costs; plans say 约 N 积分; `showPointsShort` on every AI request (积分不足 → 去充值).
- **Not done:** real payments and their records (Phase 4, with its legal review); app-store packs (a store takes
  15–30%: they need their own prices); a review console for what 积分 bought. A real charge waits for the owner's real
  model run: measured charges are tested with scripted token counts.

## S21 有所求才能去求 (medium → v11.1.0)

**Owner requests (2026-10-29), after v11.0.0:** 「求签和算卦 算法必须要有所问之问题之后才能去求。也就是说问题不能为空 是必须要有所求才能去
求」, then 「塔罗牌也是一样」.

Read as: a 塔罗, 求签 or 算卦 draw can happen only once a question has been asked, on the server as in the app; the
reading answers that question. It replaces S6's 所問之事 「or to the reader's situation without one」. 每日一牌 is the
day's card, dealt by the server without a draw, and needs none; 八字 and 风水 aren't drawn.

### WP21.1 The server (→ v11.1.0)

- `POST /v1/charts` for 塔罗, 求签 and 算卦 needs `question` (trimmed, at most 300 characters): 400
  `question_required` without one, after the Geo-Rule and before anything is drawn. The question is kept with the
  chart record (`ChartRecord.question`, sealed like it; never in its ChartFact) and returned with the chart.
- The reading and the 深度分析 take the question the chart was drawn for; a chart drawn before v11.1.0, which kept
  none, the request's (400 `question_required` when neither has one).

### WP21.2 The app (→ v11.1.0)

- On each of the three pages, every way to draw (the button, Enter in the field, Ctrl+Enter; for 算卦 also laying
  out the coins) waits for the question, and a line under the button says 先写下…才能求签 / 起卦 / 抽牌. The labels lose
  （可选）. The draw request carries the question; 塔罗's field is locked while the deck is shuffled, cut and picked,
  so the cards are drawn for the question asked at 抽牌.

Lessons: rules 19, 37, 58, 63, 67, 68.

As built (v11.1.0): `QUESTION_SYSTEMS`, `asksQuestion`, `parseQuestion` in src/service/charts.ts and
`questionRequired` in the server; the OpenAPI draw requests list `question` as required; tests in
test/ask-first.test.ts and app/test/ask_first_test.dart. About thirty older server tests and eight app test files
now ask before they draw; three tests that expected a 400 for another reason (a bad lot set, a manual cast without
its time, 17 picks) ask too, so they still fail for their own reason (rule 63).

## S22 管理后台 (big → v12.0.0)

**Owner request (2026-10-29):** 「新建一个新的project folder- admin dashboard，这个专门用来管理app下的所有账户，查看所用的所有token和所有
盈利和收益等等数据。除此之外管理员登录后可以查看和管理active user 也可以控制用户权限，还有可以给用户增加积分。还可以导出收益曲线和
report。这是一个单独的数据系统，为了展示效果，可以设置一些preset的data 到各个用户，这样我们可以只管的再数据表里看见。这是一个很大的
系统，做好tech plan 按照步骤一步步去做」; then 「做完了可以直接push 不需要等我回复」.

Read as:

- **A project of its own:** `admin/`, a Flutter web app with its own pubspec and tests, for admins only. It signs in
  with an admin account and reads everything through the API's `/v1/admin/*`. It reuses the app's theme, design
  system and keyboard layer (a path dependency on `../app`), so it looks and works like the app. It is served by
  the API at `/admin/` once built (`npm run admin:build`).
- **One database:** the dashboard reads the data the app makes. PGlite is one process's database, so the admin API
  lives in the API server, beside the app's; the dashboard is the separate system on top.
- **账户管理:** every account with its balance, spending, AI use and last activity: search, filters, sorting. Per
  account its details, its 积分 changes, its AI use by method, and actions: suspend or reactivate, the admin role,
  permissions (AI readings, 充值), sign out everywhere, 增加积分 (a grant with a note).
- **Token and money:** every AI job's steps recorded with their tokens and cost (plain numbers, no text); revenue
  (充值), its net after the payment fee and VAT, the AI cost, gross profit and margin, 积分 sold, used and still
  held by users; by day, by method and by model.
- **Active users:** active in the last 15 minutes, today, 7 and 30 days; sign one out or suspend them from there.
- **Exports:** the revenue curve (CSV, and the chart as a PNG) and a period's report (PDF, Word, CSV).
- **Preset data (展示效果):** demo accounts with 90 days of history (sign-ups, 充值, readings across the methods, 追问,
  深度分析), made from a fixed seed so tests can pin their numbers, marked demo, in development only;
  `MINGLI_ADMIN_DEMO=off` leaves them out. Demo accounts can't sign in.

### WP22.1 Accounts and AI use, on the server (→ v11.2.0)

- Accounts gain a role (`user` | `admin`), a status (`active` | `suspended`), permissions (`ai`, `top_up`), the last
  time they were active (to the minute, written at most every five minutes) and a demo mark: plain columns
  (migration 011), none of them personal text.
- Enforced: a suspended account can't sign in (403 `account_suspended`) and its sessions end; `ai: false` refuses
  every AI request (403 `ai_not_allowed`), `top_up: false` 充值 (403 `top_up_not_allowed`).
- Admins: the role, given to the `admin` dev account and to the logins in `MINGLI_ADMINS`. The admin routes don't
  depend on 内容审核, which stays paused.
- AI use: one row per step of every AI job (`ai_usage`, migration 011): who, what (kind, method, step), the model,
  input, output and cache tokens, the cost at list price, whether it delivered. Kept when an account is deleted,
  without its owner. The store lists accounts, every 积分 change and every usage row for the admin.

### WP22.2 The admin API (→ v11.2.0, with WP22.1)

- `GET /v1/admin/me`; `GET /v1/admin/overview?days=` (the KPIs); `GET /v1/admin/series?days=` (by day: revenue,
  net, AI cost, profit, 积分 sold and used, tokens, AI requests, new and active accounts); `GET /v1/admin/breakdown`
  (by method and by model); `GET /v1/admin/users?q=&status=&role=&sort=&page=`; `GET /v1/admin/users/{id}`;
  `PATCH /v1/admin/users/{id}` (status, role, permissions); `POST /v1/admin/users/{id}/points` (a grant with a
  note); `POST /v1/admin/users/{id}/sign-out`; `GET /v1/admin/active`; `GET /v1/admin/reports?days=&format=csv|pdf|docx`.
- The numbers come from pure functions in `src/admin` over the rows, tested with hand-worked values. An admin can't
  suspend or demote themselves (409), so the dashboard always keeps one way in.

### WP22.3 Preset data (→ v11.3.0)

- `seedAdminDemo` (src/admin/demo.ts): about 36 demo accounts over the last 90 days, from a fixed seed: sign-ups,
  充值 by the packs, readings by method, 追问, 深度分析, each with tokens near the estimates and its 积分 charged,
  balances that never go below nothing, last activity; a few suspended. Seeded at a dev start when there are none.

### WP22.4 The dashboard (→ v11.4.0)

- `admin/`: sign-in (admins only); a shell with 概览, 用户, 活跃用户, 收益, 用量, 报表; KPI tiles; the revenue curve
  (a painter: revenue, cost, profit by day, a period of 7, 30 or 90 days, arrow keys move along it); the users table
  (search, filters, sorting, pages) and an account's page with its actions; the active users; exports.
- Keyboard: Tab reaches every control, Enter presses, Esc goes back (the app's keyboard layer).

### WP22.5 Serving, the harness, the release (→ v12.0.0)

- The API serves `admin/build/web` at `/admin/`; `npm run admin:build` builds it through an ASCII junction; a
  harness gate runs the dashboard's pub get, analyze, tests and web build (`scripts/check-admin.ps1`, a junction to
  the repository root, since the dashboard needs `../app`).
- docs/web-test.md, MODULES, the README entry, the stage summary; pushed.

Lessons: rules 12, 17, 35, 36, 37, 42, 44, 45, 52, 58, 59, 63, 67, 68; G7; the keyboard-access skill.

As built:

- **v11.2.0 (WP22.1–22.2):** `src/admin` (`usage.ts` the rows, `stats.ts` the numbers, `report.ts` the exports,
  `routes.ts` the API); the account fields and `touch` / `list` in both user stores; `recordUsage` / `listUsage`,
  `allPoints` / `allBalances` in both stores; migration 011 (the account columns, `ai_usage`, a grant's `note`);
  `recordJob` at every AI job's end, `assertAllowed` in `holdForJob`, 充值, a 深度分析's answers and a preloaded
  plan's purchase. The app signs a suspended account out and says why at sign-in, and shows an admin's grant as
  管理员赠送 with its note. An account with the admin role reviews in 内容审核 too.
- **v11.3.0 (WP22.3):** `seedAdminDemo` (src/admin/demo.ts, a seeded mulberry32): 36 accounts, about 570 jobs,
  108 top-ups over 90 days; seeded by scripts/api-server.ts at a dev start, once per store. Each account's events
  run in time order, so its history's balances follow one another.
- **v11.4.0 (WP22.4):** `admin/` (package `mingli_admin`): `data/admin_api.dart` (the session in memory, one shared
  refresh), `application/providers.dart` (the period, the queries, `retryAdmin`), the pages 概览, 用户 + an account's
  page, 活跃, 收益, 用量, 导出 (named so for short rail labels; the plan's 活跃用户 and 报表), `widgets/line_chart.dart`
  (hover, tap, ←/→; round steps), `widgets/common.dart` (PageBody, PeriodPicker, AsyncView, DataGrid),
  `platform/download*.dart` (the browser's download). The active list opens each account's page, where it can be
  signed out or suspended. CORS exposes `content-disposition`. 45 dashboard tests against a fake API.

## 阶段总结 (stage summaries)

Written when a stage completes, before its X.0.0 release (dev-workflow skill). Medium stages get a short one.

### S21 有所求才能去求 (done 2026-10-29: v11.1.0, medium)

1. **Delivered (v11.1.0):** WP21.1 a draw needs its question on the server, which keeps it with the chart for the
   reading; WP21.2 the three pages wait for the question before any draw.
2. **Numbers:** 8 new server tests (647 in all); 3 new app tests (237 in all).
3. **Against the plan:** none; 每日一牌 stays without a question, since nothing is drawn for it (said to the owner).
4. **Mistakes:** none new; rule 63 kept three refusal tests honest.
5. **Next:** as at S20's end.

### S20 积分 (done 2026-10-29: v11.0.0)

1. **Delivered (v11.0.0):** WP20.1 the price of every AI request, from config/points.json at the routed model's list
   price, with a 50% margin on the cheapest 积分; WP20.2 the ledger with atomic holds in both stores; WP20.3 every AI
   request held, then charged its measured cost (its estimate under the mock), the 深度分析's 统一收费 with its guard,
   no preloaded plans, simulated 充值 and the dev accounts' 10,000; WP20.4 我的积分, the price on every AI button and
   积分不足.
2. **Numbers:** 26 new server tests (test/points.test.ts), 639 in all; 9 new app tests (app/test/points_test.dart),
   234 in all, and three older app tests now find the request they check by its path. Migration 010. Prompt input
   sizes measured from the pipelines' own prompts (八字 7,768 tokens, 塔罗 3,619 + 116 a card, 一生运势 24,135).
3. **Against the plan:** S20 was deferred mid-S19 and then asked for at once (「GO AND BUILD THE POINTS SYSTEM NOW」).
   A request holds 1.5 times its estimate (but never more than is available), so a reading needs only its price to
   start; the plans are charged their measured cost like every request (the HKD 18 placeholder stays for a server
   without 积分); the 深度分析's fee is one for every method (统一), priced from 八字's, the largest.
4. **Mistakes:** rule 67 (a comma in a YAML flow mapping split an OpenAPI description, as in S19); rule 68 (a test that
   read the last request met the new balance request). The locale test caught 示范 in 简体 copy (演示 is the Mainland
   word).
5. **Next:** the owner tries 积分 with the real model (each charge then shows its dollars) and, if the prices should
   change, edits config/points.json. Waiting for the owner: Phase 4 payments, the mail and SMS providers, the Phase 3
   gate, WP7.2, WP7.3, WP1.8.

### S19 深度分析、麦克风、同名重算 (done 2026-10-29: v10.0.0)

1. **Delivered (v10.0.0):** WP19.1 the 深度分析 pipeline, its five prompts, the API and the readings that read it;
   WP19.2 its page, the goal reminder and the conversation on the reading; WP19.3 the mic on the web; WP19.4 同名重算
   before every method's new 测算.
2. **Numbers:** 19 new server tests (18 in test/inquiry.test.ts, one for the model choice), 613 in all; 12 new app
   tests (app/test/inquiry_test.dart), 225 in all. Ten new prompt pins and five retired ones; migration 009. The
   harness passed three times, the last on the final tree.
3. **Against the plan:** the owner moved 积分 to later mid-stage (「收费系统可以留到以后做」), and with it the
   深度分析's flat fee; S20 keeps what was measured. The owner's affair example became a question about what the user
   knows, not a hint. 同名重算 matches a 卦 only on the same question, since a new question is a new 卦.
4. **Mistakes:** rule 65 (a BringIntoView that takes another's place in a list needs its own key); rule 66 (a route's
   settings reach the model only through the server's routing: test it with the owner's ACTIVE_AI_MODEL too).
5. **Next:** the owner tries a real 深度分析 with the real model. Open: 追问 and the exports with the conversation;
   S20 积分 when the owner wants it; still waiting for the owner: the mail and SMS providers, the Phase 3 gate,
   WP7.2, WP7.3, WP1.8.

### S18 八字 AI 解读 (done 2026-10-29: v9.3.0)

1. **Delivered (v9.3.0):** WP18.1 the 排盘 alone for the AI; WP18.2 narrative_bazi@8 with its required 总结, no 举例
   and no 行动建议; WP18.3 the button, the 总结 card and every place a reading goes; WP18.4 the ai-reading skill.
2. **Numbers:** 9 new server tests (7 in test/bazi-ai-reading.test.ts), and 15 changed where 八字 no longer has
   actions or examples (594 in all). 5 new app tests and 8 changed (213 in all).
3. **Against the plan:** "尽量不采用引擎数据" is read as no engine judgements, while the 排盘 stays the engine's; this
   is said to the owner. The 总结 opens the AI reading instead of closing it, so it is read first.
4. **Mistakes:** rule 64 (a card below the screen is offstage to find()).
5. **Next:** the owner tries a real reading. Still waiting for the owner: the mail and SMS providers, the Phase 3 gate,
   WP7.2, WP7.3 and WP1.8.

### S17 Claude 与模型选择 (done 2026-10-29: v9.2.0)

1. **Delivered (v9.2.0):** WP17.1 Claude streamed, tested through the real SDK, on the owner's key; WP17.2 the usable
   models, `ACTIVE_AI_MODEL`, `npm run ai:models` and `eval:ai --model`; WP17.3 every route on Claude Opus 5.5.
2. **Numbers:** 14 new server tests (585 in all); 208 app tests, unchanged (their fixtures name the new model). The SDK
   refuses an unstreamed request from 21,334 max_tokens; the reading asked for 32,000.
3. **Against the plan:** the owner added `CLAUDE_API_KEY` and `ACTIVE_AI_MODEL` during the work. The code took their
   names, and their `claude-v1` became `claude-opus-5-5`.
4. **Mistakes:** rules 62 (test a provider through its real SDK client; stream Claude) and 63 (a scripted provider goes
   under every key; a failure test checks its own reason).
5. **Next:** the owner flips `IS_AI_MOCK=FALSE` and tries `npm run eval:ai -- --live`; effort can go up per route if
   the eval shows a gain. Still waiting for the owner: the mail and SMS providers, the Phase 3 gate, WP7.2, WP7.3 and
   WP1.8.

### S16 Owner updates (done 2026-10-29: v9.1.0)

1. **Delivered (v9.1.0):** WP16.1 the home bar (历史记录 in the menu, a framed ☰ on the right, the mark and the
   shaded name); WP16.2 `BringIntoView` on every page where a tap makes something below its button; WP16.3 the 求签
   altar (甩签 and 掷筊); WP16.4 the rule and the phone tests.
2. **Numbers:** 12 new app tests (208 in all); 571 server tests, unchanged. The phone tests fail with the scroll off.
   Before the fix, the tarot ritual started 3 px above the screen's bottom edge.
3. **Against the plan:** the owner named 塔罗 and 风水; the same fix went to every page where a tap adds a part below
   its button, as the owner's last message asked. The SVG became a painter (no new package), drawn from the icon.
4. **Mistakes:** rules 59 (the owner's rule: what a tap makes comes into view, tested on a phone), 60 (an animated
   scroll swallows taps; two reveals from one tap must not fight) and 61 (tests wait for a growing card; transformed
   rects use closeTo).
5. **Next:** nothing in progress. Waiting for the owner: the mail and SMS providers (S15), the Phase 3 gate, WP7.2,
   WP7.3 and WP1.8.

### S15 菜单、图标、多种登录、报告发到邮箱 (done 2026-10-29: v8.1.0–v9.0.0)

1. **Delivered**, the owner's request of 2026-10-28:
   - WP15.1 (v8.1.0): the ☰ menu. The home bar holds ☰, the title and 历史记录; 设置 is grouped.
   - WP15.2 (v8.1.0): the app icon, a 太极 in the 先天八卦 drawn once and written in 40 files for every platform; the
     name under it is 命理大师.
   - WP15.3 (v8.2.0): sign-in by username, email or bound phone; phones bound and emails verified by a code; mail
     and SMS transports with the development outbox.
   - WP15.4 (v9.0.0): 测算完成后发到邮箱 (否 by default) and 发到邮箱; the record notes its mailing.
2. **Numbers:**
   - server tests 528 → 571; app tests 175 → 196;
   - harness runs: v8.1.0 and v8.2.0 passed the first time; v9.0.0 failed once, in two app tests that the new 报告
     group broke (rule 58), then passed;
   - renders looked at: the icon at 16–1024 px; the menu, the sign-in pages, 设置, the binding dialog and the
     select bar with the real font; a mail in headless Chrome.
3. **Against the plan:**
   - The icon's source is the drawing in the script, not a hand-made SVG; the SVG is written out from it.
   - The mailed 一生运势报告 has every text but not the figures, which the app draws from the facts.
   - The select bar's buttons became icon-over-label slots, since four labelled buttons didn't fit.
   - Only the reading page shows the mail line, not the 一生运势 page.
   - The providers wait for the owner, as asked (留到下一步): until then the server writes to `.outbox/`.
4. **Mistakes recorded:**
   - **Rule 56:** the Edit tool turns `\u` escapes into characters, so the Windows title is written as code units.
     It also notes G16 recurring: a shell script dropped a regex's backslash.
   - **Rule 57:** a result SnackBar waited behind the 正在生成 one.
   - **Rule 58:** adding 报告 to 设置 pushed two older tests' rows past the built part of the list. Only the new tests
     had been run; now every test that opens a changed page runs before the harness.
   - **Rules that worked:** rule 49's test caught the bar overflowing; rule 27 explained the taps that missed after
     an error line; working the Malaysian number out by hand (G7) caught the trunk-0 bug.
5. **Next:**
   - The owner chooses the providers: an SMTP service or a mail API, and an SMS gateway. Each plugs in as a
     transport in `src/notify`, and the outbox stays for development.
   - Possible follow-ups, if the owner wants them: sign-up or sign-in by phone code alone; the mail line on the
     一生运势 page; 发到邮箱 on the reading pages too.
   - Still waiting for the owner: WP7.2, WP7.3, WP1.8, the 起名 review, Indonesia's sign-off, and the Phase 3 gate
     before any Phase 4.

### S14 以往记录：整理、下载、发送、删除 (done 2026-10-28: v8.0.0)

1. **Delivered** in v8.0.0, the owner's request:
   - WP14.1: Word and PDF for every reading and 一生运势报告, with its 追问 and the AI label;
   - WP14.2: history by year and month or by person, records filed under a person (归类到…), and deleting one record
     with what hangs off it;
   - WP14.3: download and send, one record or several selected, also from the reading page and the 一生运势 page.
2. **Numbers:**
   - server tests 515 → 528;
   - app tests 165 → 175;
   - a PDF of a reading is about 85 KB (two pages, subset font).
3. **Changed against the plan:** nothing in scope.
   - The 一生运势 page's 下载 became a menu (PDF, Word, and the old ZIP).
   - The reading page's menu gained PDF and Word beside its Markdown download.
4. **Mistakes recorded:** none new. Rule 4 (G4, measure first) paid off: pdf-lib would have shipped PDFs with blank
   Chinese.
5. **Next:** what the owner picks; the open items stand as at S13's end.

### S13 AI 追问 + 通俗解读 (done 2026-10-28: v6.2.0–v7.0.0)

1. **Delivered**, the owner's request:
   - **v6.2.0, WP13.1:** every reading in three parts, term → commentary → example. Each method has a new reading
     prompt with its own terms and scenes, and the 一生运势 report puts the basis first in each text.
   - **v6.2.0, also:** the owner's bug report (a chart's person kept with it on the server) and three dev accounts.
   - **v7.0.0, WP13.2–13.3:** 追问 on every reading and 一生运势报告.
     - Its own pipeline and a prompt per method.
     - Grounded by cited facts and the faithfulness checks; questions out of scope are said to be so.
     - Suggested next questions.
     - The card after the reading, the floating button and the jump chip.
2. **Numbers:** server tests 487 → 495 → 515; app tests 151 → 156 → 165. Eight 追问 prompts and seven reading prompts
   (plus two life prompts) pinned. Migration 007.
3. **Changed against the plan:**
   - the floating button steps aside over its own target;
   - the field is one line, so Enter sends;
   - the reading's question and the life report's context are now stored for 追问;
   - `npm run eval:ai` asks a 追问 too.
4. **Mistakes recorded:**
   - rule 52: labels kept in browser storage vanish with the origin;
   - rule 53: unkeyed AnimatedSwitcher states;
   - rule 54: check formatting after the last edit;
   - rule 55: a floating control covering its target;
   - rule 37 recurred, for a job other than a report.
5. **Next:**
   - The owner reads real readings and 追问 with the model switched on. The new prompts are untried live:
     `npm run eval:ai -- --live`.
   - Otherwise the open items stand as at S10's end.

### S12 Owner updates (done 2026-10-28: v6.1.0, medium)

1. **Delivered** in v6.1.0, the owner's three requests:
   - WP12.1: the tarot spread choices three to a row on a phone;
   - WP12.2: the home page in 东方 and 西方 groups;
   - WP12.3: 算卦's coins drawn as 銅錢, turning over like the tarot cards.
2. **Numbers**: app tests 147 → 151; server tests 487.
3. **Changed against the plan**: nothing. The face-down colours moved into design.dart, so the coins and the tarot
   back share one look.
4. **Mistakes recorded**:
   - rule 49: measure a widget before laying out by its size;
   - rule 50: a painter's text needs the page's font;
   - rule 51: open home entries through `openEntry`.
5. **Next**: what the owner picks. The open items are as at S10's end.

### S10 算卦 (done 2026-10-28: v5.3.0–v6.0.0)

1. **Delivered**: the owner's 算卦, a method of its own (rule 8).
   - **v5.3.0, the server half:**
     - WP10.1, the engine and API: the classical coin rule (背 3, 字 2), auto, pick and manual casts, the cast
       time's 干支, and 朱熹's rule for the texts;
     - WP10.2, 450 直說 written by hand in 繁體 and converted to 简体;
     - WP10.3, the AI reading: its own prompts, and a faithfulness check on hexagrams, quotes and 干支.
   - **v6.0.0, the rest:**
     - WP10.4, the app pages: the reminder, the three ways to cast, the hexagram card, the reading and history;
     - WP10.5, the 周易 text checked against two transcriptions and a 宋 print, and corrected
       (docs/verification/zhouyi.md).
   - S11 (v5.4.0) went out in the middle, as the owner asked, so the pages were built in Chinese only.
2. **Numbers**:
   - Server tests 449 → 487 (v5.3.0 added 34); app tests 139 → 147.
   - `verify:liuyao`: 10 of 10 checks over 100 000 casts.
   - The 周易: all 514 卦辭, 爻辭 and 大象 checked. B = C against ours fell from 77 to 4, and those 4 are the
     print's readings. 125 of 578 strings corrected, and 16 scan pages read.
3. **Changed against the plan**:
   - The English 直說 were dropped when the owner removed English (S11).
   - WP10.5 checked the 大象 as well as the 450 texts 算卦 shows, because the 一生运势 brief reads it.
   - It found a print to settle disputes (the 四部叢刊 宋本 with a page transcription) instead of a print read
     alone.
   - Every 卦辭 now opens with 「名：」, also where the name is its first word: a layout change the print comparison
     needed.
4. **Mistakes recorded**:
   - Rules 45–46, in the server and app halves: JSON round-trips, and full-width buttons in a Row.
   - Rule 47: digital copies can share a 简繁 slip, so a merged character is unverified until a print settles it.
   - Rule 48: Commons rate-limits page renders.
   - Global rule 1 recurred twice (backslashes through a heredoc). Both were caught at once and redone with Edit.
5. **Next**:
   - Nothing of S10 is open.
   - Still waiting for the owner:
     - WP7.2 (whether a 八字 share card may show the four pillars);
     - 起名's 字义库 review, before 起名 goes on;
     - Indonesia's sign-off;
     - whether to strip the server's English;
     - the Phase 3 gate items.
   - A full page-by-page reading of the 周易 print is a candidate small update, should the owner want it.

### S11 Owner updates (done 2026-10-28: v5.4.0, medium)

1. **Delivered** in v5.4.0: WP11.1, the tarot spread choices one size; WP11.2, English out of the app; WP11.3, the
   admin in 北京.
2. **Numbers**: app tests 140 → 139 (English-only checks removed, new checks added); server tests 483.
3. **Changed against the plan**: done before 算卦's app pages, so those pages are built in Chinese only.
4. **Mistakes recorded**: none new. Global rule 1 (no backslashes through a shell) nearly recurred; I used the Edit
   tool for the regex instead.
5. **Next**: S10's remaining work: WP10.4 (算卦's pages), WP10.5 (the 周易 text check), the stage summary and v6.0.0.

### S9 Phase 3 门禁 (done 2026-10-28: v5.2.0, medium)

1. **Delivered** (v5.2.0): WP9.1, 起名's rule group (N001–N003); WP9.2, docs/phase-3-gate.md.
2. **Numbers**: server tests 429 → 449, app tests 139 → 140. Phase 3 gate: 2 of 5 items passed; the other 3 wait
   for the owner.
3. **Changed against the plan**: the English coverage got tests of its own, so the gate record points at tests
   rather than at a one-off count.
4. **Mistakes recorded**: none new.
5. **Next**: the owner's gate review (docs/phase-3-gate.md, its last table). Phase 4 starts after the gate.

### S8 地区精细化 (done 2026-10-28: v5.1.0, medium)

1. **Delivered**, in v5.1.0:
   - WP8.1: Indonesia, with its content blocks (前世, 通灵, 降头), unserved until the owner's sign-off;
   - WP8.2: the five-region routing test, the Phase 3 gate; Singapore's English;
   - WP8.3: the reader's language kept on the device; 双声 and 叠韵 in the glossary.
2. **Numbers**
   - Server tests 401 → 429; app tests 137 → 139.
   - Geo-Rule matrix 0.5.0; glossary 1.6.0.
3. **Changed against the plan**
   - The matrix now updates hot in the running server too: a finding, not a plan item (rule 44).
   - Singapore's weight stayed at its languages: the start language is the owner's decision.
4. **Mistakes recorded**: rule 44. A claim about a running system needs a test on a running system.
5. **Next**: the rest of Phase 3 waits for the owner, listed above. So do WP7.2, WP7.3 and WP1.8.

### S6 新玩法 (done 2026-10-28: v4.3.0–v5.0.0)

1. **Delivered**, the three new methods of the owner's phase document (Phase 3 §2.1, §2.4). Each stands alone
   (rule 8): its own engine, prompts, brief, AI label and app page.
   - **WP6.1 + 6.2, v4.3.0: 求籤 · 擲筊.**
     - The 關聖帝君一百籤, text verified against two transcriptions and the Qing print. Evidence:
       docs/verification/qiuqian-guandi-100.md.
     - The ritual draws from its own seed (HMAC-DRBG), so a draw can be replayed.
     - A share image of the lot.
     - The home order now comes from the region (`GET /v1/methods`): 求籤 first in Taiwan and Hong Kong.
   - **WP6.3, v4.4.0: 风水.**
     - General principles of space for 7 rooms, with an optional facing (後天八卦), never 吉凶.
     - Every paragraph is pinned to `simplified_rule`.
     - A 风水-only compliance rule group. First in Malaysia.
   - **WP6.4, v4.5.0: 起名.**
     - 五行补益 from a 八字 chart's 喜用, a draft 字义库 and 音律 rules.
     - It ships off until the owner's 人工校订, behind a gate that tests hold both ways.
   - New shared pieces, each scoped per method:
     - `METHOD_RULE_GROUPS` and `METHOD_LABELS`;
     - entry weights in the Geo-Rule matrix;
     - `MINGLI_GEO_MATRIX`, to switch the matrix without a release.
2. **Numbers**
   - Server tests 329 → 401; app tests 122 → 137 (v4.3.0: 364 / 127; v4.4.0: 385 / 131; v4.5.0: 401 / 137).
   - A new harness gate: `verify:qiuqian`, 100 000 draws, 8 checks.
   - Content:
     - 100 lots: 85 agreed between the copies, 16 lines settled by the print, 5 corrections, 38 variants listed;
     - 30 风水 principles for 7 rooms;
     - 100 name characters and 83 surnames.
   - Prompts: 6 new, each pinned, none shared. Compliance: G008, and F001 / F002 for 风水 only.
   - Migrations 003–005. Geo-Rule matrix 0.1.0 → 0.4.0.
3. **Changed against the plan**
   - The owner made no choice of methods (「继续吧不要停」). S6 followed the owner's phase document instead
     (rule 34), and this plan's own 六爻 / 合婚 ideas were parked.
   - 求籤's text policy changed once the print was read in full: the two modern copies share errors (rule 39).
   - 起名 shipped off. The spec asks for a hand-checked 字义库, and only the owner can sign that off. The owner's
     switch was tried once and undone, and 7 tests that would have failed were fixed (rule 42).
   - Only 求籤 has a share image: the 风水 and 起名 specs ask for none.
4. **Mistakes recorded**
   - Rules 38 and 40, about care with the machine and the owner's data:
     - 38: a file was written to a retyped path, 命理大師, a folder the guard won't let me remove;
     - 40: the owner's email went out once in a User-Agent.
   - Rules 39 and 41, about evidence: modern copies can share errors, and summarising fetches don't give verbatim
     text.
   - Rules 42 and 43, about tests:
     - 42: tests must not pin a switch the owner will flip;
     - 43: a `findsNothing` needs a positive anchor.
   - Rule 30 was corrected in place (absolute imports in project-root scripts).
   - Rule 23 cost one harness run per release, three times in this stage: the first run after a pubspec bump
     fails at analyze. That is a fix for the harness tooling, outside this repository.
5. **Next**
   - Waiting for the owner:
     - the 起名 字义库 review (docs/web-test.md, 起名);
     - WP7.2, a 八字 share card, which would show the birth date.
   - Waiting for others: WP7.3, the deep link (needs the stores); WP1.8, 命宫 / 身宫 (needs a reference).
   - New lot sets (六十甲子籤, 黃大仙靈籤) wait for verifiable sources. 六爻 / 合婚 stay parked.
   - Then a fresh look for leftover work against the owner's documents, for the next stage.

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

| WP        | Status                       | Release |
| --------- | ---------------------------- | ------- |
| WP1.1     | done                         | v1.3.0  |
| WP1.2     | done                         | v1.3.0  |
| WP1.3     | done                         | v1.3.0  |
| WP1.4     | done (命宫 / 身宫 → WP1.8)   | v1.3.0  |
| WP1.5     | done                         | v1.3.0  |
| WP1.6     | done                         | v2.0.0  |
| WP1.7     | done                         | v2.0.0  |
| WP1.8     | waiting for a reference      | —       |
| WP2.1     | done                         | v2.1.0  |
| WP2.3     | done                         | v2.2.0  |
| WP2.2     | done                         | v2.3.0  |
| WP3.1     | done                         | v2.4.0  |
| WP3.2     | done                         | v2.5.0  |
| WP3.3     | done                         | v2.6.0  |
| WP3.4     | done                         | v2.7.0  |
| WP3.5     | done                         | v2.8.0  |
| WP3.6     | done                         | v3.0.0  |
| WP4.1     | done                         | v3.1.0  |
| WP4.2     | done                         | v3.2.0  |
| WP4.3     | done                         | v3.3.0  |
| WP4.4     | closed (owner decision)      | —       |
| WP4.5     | done                         | v3.4.0  |
| WP4.6–4.7 | done                         | v3.5.0  |
| WP4.8     | done                         | v4.0.0  |
| WP4.9     | moved to S7 (WP7.1)          | —       |
| WP5.1–5.2 | done                         | v4.1.0  |
| WP7.1     | done                         | v4.2.0  |
| WP7.2     | waits for the owner          | —       |
| WP7.3     | waits for the stores         | —       |
| WP6.1–6.2 | done                         | v4.3.0  |
| WP6.3     | done                         | v4.4.0  |
| WP6.4     | done (off until review)      | v4.5.0  |
| WP8.1     | done (ID off until sign-off) | v5.1.0  |
| WP8.2     | done                         | v5.1.0  |
| WP8.3     | done                         | v5.1.0  |
| WP9.1     | done                         | v5.2.0  |
| WP9.2     | done                         | v5.2.0  |
| WP10.1    | done                         | v5.3.0  |
| WP10.2    | done                         | v5.3.0  |
| WP10.3    | done                         | v5.3.0  |
| WP10.4    | done                         | v6.0.0  |
| WP10.5    | done                         | v6.0.0  |
| WP11.1    | done                         | v5.4.0  |
| WP11.2    | done (app; server en kept)   | v5.4.0  |
| WP11.3    | done                         | v5.4.0  |
| WP12.1    | done                         | v6.1.0  |
| WP12.2    | done                         | v6.1.0  |
| WP12.3    | done                         | v6.1.0  |
| WP13.1    | done                         | v6.2.0  |
| WP13.2    | done                         | v7.0.0  |
| WP13.3    | done                         | v7.0.0  |
| WP14.1    | done                         | v8.0.0  |
| WP14.2    | done                         | v8.0.0  |
| WP14.3    | done                         | v8.0.0  |
| WP15.1    | done                         | v8.1.0  |
| WP15.2    | done                         | v8.1.0  |
| WP15.3    | done                         | v8.2.0  |
| WP15.4    | done                         | v9.0.0  |
| WP16.1    | done                         | v9.1.0  |
| WP16.2    | done                         | v9.1.0  |
| WP16.3    | done                         | v9.1.0  |
| WP16.4    | done                         | v9.1.0  |
| WP17.1    | done                         | v9.2.0  |
| WP17.2    | done                         | v9.2.0  |
| WP17.3    | done                         | v9.2.0  |
| WP18.1    | done                         | v9.3.0  |
| WP18.2    | done                         | v9.3.0  |
| WP18.3    | done                         | v9.3.0  |
| WP18.4    | done                         | v9.3.0  |
| WP19.1    | done                         | v10.0.0 |
| WP19.2    | done                         | v10.0.0 |
| WP19.3    | done                         | v10.0.0 |
| WP19.4    | done                         | v10.0.0 |
| WP20.1    | done                         | v11.0.0 |
| WP20.2    | done                         | v11.0.0 |
| WP20.3    | done                         | v11.0.0 |
| WP20.4    | done                         | v11.0.0 |
| WP21.1    | done                         | v11.1.0 |
| WP21.2    | done                         | v11.1.0 |
| WP22.1    | done                         | v11.2.0 |
| WP22.2    | done                         | v11.2.0 |
| WP22.3    | done                         | v11.3.0 |
| WP22.4    | done                         | v11.4.0 |
| WP22.5    | next                         | v12.0.0 |
