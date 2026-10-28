# 命理大师

Phase 0 (engines, ChartFact, compliance) and Phase 1 in progress (AI pipeline, v1 API, Flutter app).
**Start here: [docs/SUMMARY.md](docs/SUMMARY.md)** (what each phase delivered).
Details: [docs/phase-0-gate.md](docs/phase-0-gate.md) · [docs/phase-1-status.md](docs/phase-1-status.md) · agent instructions in [CLAUDE.md](CLAUDE.md).
Web test: **https://leonfighter1.github.io/suanming/** ([docs/web-test.md](docs/web-test.md)).

## 更新记录 (release notes)

Newest first. Every update adds an entry: version and date, then by area what changed for users, how to use it, and
how it was verified. Big updates (X.0.0) end a stage of the [tech plan](docs/tech-plan.md) and are the ones pushed;
medium (X.Y.0) and small (X.Y.Z) ones are listed here as they are made. The rules:
[.claude/skills/dev-workflow/SKILL.md](.claude/skills/dev-workflow/SKILL.md).

### v2.4.0 (2026-10-28): a tarot reading shows its cards

Stage S3 of the [tech plan](docs/tech-plan.md) (塔罗体验), work package 3.1. A medium update: committed locally,
pushed with v3.0.0.

- Reading page: a tarot reading opens with its spread at the top, as it was laid out, every card turned and drawn
  with its art. On a phone a Celtic Cross shows as thumbnails, and touching one opens it large, as on the 塔罗 page.
  八字 reading pages are unchanged.
- 历史记录: a tarot reading shows its cards' art in small (up to five, then 「+5」 for a Celtic Cross), a reversed
  card upside down as it was drawn, above the card names.
- API: a report now carries its `chart_id`, so a reading page can show its chart (GET /v1/charts/{chart_id}).
- Verified:
  - The API test checks `chart_id` on a pending and a passed report.
  - The tarot reading test now also checks the spread on top of the reading, every card turned.
  - 1 new app test: the art in 历史记录, a reversed card upside down.
  - All 287 server tests and 93 app tests pass; harness PASS.

### v2.3.0 (2026-10-28): 塔罗 reads like a tarot reading

Stage S2 of the [tech plan](docs/tech-plan.md), work package 2.2, which completes the stage (v2.1.0–v2.3.0). A medium
update: committed locally, pushed with the next big update.

- 塔罗 page
  - Under the question, a new row 「想看哪方面（可选）」: 不限, 事业, 感情, 健康 or 自我. It is taken when the cards
    are drawn, like the question, and the reading looks at that part of life. 不限 is the default.
  - Before the reading, the request card says the reading has three parts, instead of offering topic chips.
- The tarot reading
  - It has three parts, in the order of a classic reading:
    - 逐张解读: every card in dealing order, one paragraph each (all ten of a Celtic Cross).
    - 综合解读: the spread as one story, answering the question.
    - 建议: what the cards suggest doing.
  - Before, the spread was read four times over, for 性格, 事业财运, 婚姻感情 and 健康, which is 八字's way.
  - The actions follow the 建议.
  - One 破除运势 plan per reading, on 建议; 逐张解读 and 综合解读 have none. Readings made before keep their four
    plans.
  - If the AI leaves a card out, it is asked again and told which card.
- Keyboard: Tab reaches the focus chips right after the question, in order; Space or Enter picks one.
- API: POST /v1/reports takes `focus` for a tarot reading (400 for any other method), and the tarot sections are new
  topic values.
- Verified:
  - 4 new server tests: the three sections with every card read, the focus reaching the AI, a skipped card asked
    again, and focus refused for 八字 and for unknown values. Others now expect one tarot plan.
  - 2 new app tests: the focus in the request, with the three parts and one plan on the report page; Tab and Space
    on the focus chips. Two phone tests needed a frame after `ensureVisible` (rule 27, widened).
  - All 287 server tests and 92 app tests pass; harness PASS.
- S2 in short (v2.1.0–v2.3.0): every method has its own instructions; the AI reads a focused copy of a 八字 chart
  (about half the characters); 塔罗 reads like a tarot reading.

### v2.2.0 (2026-10-28): the AI reads less, and what it reads matters

Stage S2 of the [tech plan](docs/tech-plan.md), work package 2.3. A medium update: committed locally, pushed with the
next big update.

- Nothing changes on screen. A 八字 reading, its 破除运势 plans and the 一生运势报告 are now written from a shorter,
  focused copy of the chart. They cost about half the tokens when the real AI is on, and the AI keeps to the periods
  that matter:
  - A reading sees the full detail (刑冲合害, 神煞, the reasons behind each score) of the current 大运 and the next,
    this year and the next two, and any year named in the question. Every other 大运 and 流年 it sees by name, age
    and 十神 only.
  - A 破除运势 plan sees in full the periods where its topic scores lowest from now on (two 大运, three 流年). Before,
    a plan could target a 大运 that was already over.
  - The 一生运势报告 no longer gets the 流月 and the 流年 scores, which it never used. No agent gets the 流月 now: no
    instruction used them.
- Measured on the sample chart: characters sent to the AI for a reading with all six topics, its six plans and the
  life report.

  | Agent (calls)                        | v2.1.0  | v2.2.0  |
  | ------------------------------------ | ------- | ------- |
  | Reading (1)                          | 32,418  | 17,524  |
  | Actions (1)                          | 2,628   | 2,576   |
  | 破除运势 plans (6)                   | 195,813 | 85,338  |
  | 一生运势报告 (2)                     | 73,681  | 62,743  |
  | Total                                | 304,540 | 168,181 |
  | Reviewer (8, only when review is on) | 267,738 | 137,098 |

  These are characters, not tokens: the JSON's spacing counts too.

- Fixed: the AI-evaluation check (`checkFaithfulness`) now knows the 干支 of 胎元 and of the 流月, so a reading that
  names them is no longer flagged as unknown.
- Verified:
  - 5 new server tests: a reading's focus (with a year asked about, and before the first 大运); every period keeps
    its place and only the focus ones keep their detail; a plan's focus is its topic's lowest from now on, never a
    past 大运; each 八字 agent reads its own view; the faithfulness check knows 胎元 and the 流月.
  - All 283 server tests and 90 app tests pass; harness PASS.

### v2.1.0 (2026-10-27): every method writes with its own instructions

Stage S2 of the [tech plan](docs/tech-plan.md), work package 2.1. A medium update: committed locally, pushed with the
next big update.

- 八字 readings
  - The 命盘事实 list of a report gains a line with the engine's 日主旺衰 and 喜用, as on the 五行 card:
    「日主旺衰（简化扶抑）：身弱；不得令；喜用：火、土；忌：金、水、木」.
  - An action that uses an element (a colour, a direction, a season) uses only the engine's 喜用. A balanced chart
    gets advice on balance, not on pushing one element.
  - 破除运势 plans base every 补 / 泄 step, colour and direction on the engine's 喜用 and 忌, and label ages 虚岁.
    Before, the AI chose the elements itself and wrote plain 岁.
- 塔罗 readings
  - Actions and 破除运势 plans have their own instructions. They rest on the cards drawn and their positions, with no
    五行, lucky colours, directions or other 八字 ideas.
  - A tarot plan names the cards it rests on, and ends with its own note
    (「以上建议依据所抽塔罗牌的牌义整理……」) instead of the 命理 one.
- Astrology (API only)
  - Readings and actions have their own instructions: the planets in their signs and their aspects, never houses or
    the ascendant, which the simplified chart doesn't compute. Before, astrology was read with 八字-style rules (for
    example health as 五行).
  - An astrology reading has no 破除运势 plan. None is prepared in the background, and a purchase is refused (400)
    before anything is charged.
- Behind the scenes: one table (`METHOD_PROMPTS`) says which instructions each method uses, and no two methods share
  them. A released prompt version never changes: a test pins all 15.
- Verified:
  - 7 new server tests: each method's prompts in every report; the hash of every prompt version; no 八字 rules in
    the tarot and astrology prompts; the tarot plan and its note; no astrology plan, in the pipeline and in the API;
    the 旺衰 line in three languages.
  - All 278 server tests and 90 app tests pass; harness PASS.

### v2.0.0 (2026-10-27): 八字 engine, complete: 日主旺衰, 喜用, and 运势 scores from the engine

Stage S1 of the [tech plan](docs/tech-plan.md) is complete: work packages 1.6–1.7 here, 1.1–1.5 in v1.3.0. The
stage summary is in the plan under 阶段总结. A big update: pushed, together with v1.3.0.

- 命盘 page, 五行 card: how strong the day master is, worked out by the engine.
  - It shows 身强, 身弱 or 中和, and 得令 or 不得令.
  - It lists the elements that help (「喜用：火、土」) and those to watch (「忌：金、水、木」).
  - An extreme chart (almost all support, or almost none) shows 专旺候选 or 从格候选 with 「宜请有经验的师傅细看」,
    and no 喜用.
- 运势走势 (in a 八字 reading): the engine computes the scores now, not the AI.
  - The same chart always gets the same scores, and scoring no longer costs a model call.
  - Every 大运 and 流年 has six scores from 20 to 85: 五行, 性格, 事业财运, 婚姻感情, 大运流年, 健康.
  - Each one has a one-line reason in 简体, 繁體 or English, for example
    「丙午：印星当头（学习和支持你的人）；五行多为对你有利的一方，与日支相破，宜多沟通。」
- 一生运势报告: each life stage is labelled with its 虚岁 and years (「虚岁 18–27（2007–2016）」). Its score is the
  engine's, so the report and the 运势走势 chart agree.
- AI readings of a 八字 chart have their own instructions (`narrative_bazi@5`). The AI explains the engine's 虚岁,
  旺衰 and 喜用, 刑冲合害, 神煞 and scores; it doesn't work them out again. Tarot and astrology readings are
  unchanged.
- How the engine decides:
  - 旺衰: a simplified 扶抑法 on the widely used 100-point scheme. 月支 counts 40; 日支, 时支, 月干 and 时干 12 each;
    年干 8; 年支 4. A branch's points go to its hidden stems (本气 / 中气 / 余气). The day master's own element and
    the one that generates it are its support: 55 or more is 身强, 45 or less 身弱.
  - 喜用 by 扶抑: a weak day master is helped by 印 and 比劫, a strong one by 食伤, 财 and 官杀. 调候, 合化 and the
    从格 itself are not considered.
  - Scores weigh three things: the period's elements against 喜用 and 忌, its 十神 for each topic, and its relations
    with the chart. A 冲 to the day or month branch lowers a score; a 合 raises it a little; 刑, 害 and 破 lower it a
    little. Gender doesn't change a score.
- Stage S1 in short (v1.3.0 + v2.0.0):
  - One age convention (虚岁) everywhere.
  - The 本命卦 on the same day as its hour.
  - All 合冲刑害破; 神煞, 空亡, 胎元 and 流月; the 子时 setting.
  - 旺衰 and 喜用, and scores from the engine.
  - Not yet: 命宫 / 身宫, waiting for a reference.
- Verified:
  - 7 new server tests: strength worked out by hand for 身弱, 身强 and both flags; the 2026 丙午 scores and note
    worked out by hand; the same chart always scores the same, within 20–85; a favourable period scores above an
    unfavourable one.
  - The 命盘 page test checks the strength pills.
  - All 271 server tests and 90 app tests pass; harness PASS.

### v1.3.0 (2026-10-27): 八字 engine, part 1: ages, the pillar day, 合冲刑害破, 神煞

Stage S1 of the [tech plan](docs/tech-plan.md), work packages 1.1–1.5. A medium update: committed locally, pushed
with v2.0.0.

- 命盘 page
  - Ages are 虚岁 everywhere and labelled 虚岁: the 大运 and 流年 strips, the 运势走势 chart and 破除运势. Before,
    流年 showed 周岁 and 大运 虚岁 under the same 「岁」, one year apart.
  - New card 神煞 · 空亡 · 胎元: 天乙贵人, 文昌, 禄神, 羊刃, 桃花, 驿马 and 华盖 with the pillars that hold them; 空亡
    from the day pillar and the pillars that fall in it; 胎元.
  - New card 原局刑冲合害: every 天干五合 / 相冲, and every 六合, 六冲, 三合, 半合, 三会, 相刑, 自刑, 六害 and 相破 between
    the four pillars.
- 个人资料: a new switch 「23:00–24:00 出生，日柱算次日」 for the other 子时 school. It is off by default, so a birth after
  23:00 keeps the same day, as before.
- 八字 engine (new facts only; nothing existing changed):
  - 虚岁 on every 大运 and 流年.
  - The 农历 of the day the pillars are read on. The 一生运势报告's 本命卦 now takes its date from it, so date and hour
    come from the same day even when 真太阳时 crosses midnight (far-west China, Spain in summer).
  - 合冲刑害破 for the chart, for every 大运 (with the chart) and every 流年 (with the chart and its 大运); 神煞 for the
    chart and each period; 空亡; 胎元; 流月 (the twelve months of the current year from 立春, with 干支, start time and
    十神; shown in a later update).
  - 20 new protected terms (the relation types, the 神煞, 空亡, 胎元, 流月, 虚岁) in 简体, 繁體 and English.
- Not yet: 命宫 / 身宫. Two textbook formulas disagree, and there is no reference at hand to settle it (WP1.8).
- Verified: 11 new server tests (each relation type, full 三合 / 三刑 without their pairs, the sample chart's relations
  and 神煞 worked out by hand, 空亡 across the 旬, 胎元 and 日空亡 against lunar-javascript, 流月 against the library's
  month pillar, 虚岁, the Kashgar pillar day and its 本命卦) and 2 app tests (虚岁 on both strips, the two new cards,
  the 子时 switch in the request); all 265 server tests and 90 app tests pass; harness PASS.

### v1.2.0 (2026-10-27): 塔罗 the classic way

Checked against the classic method (owner request). Already right: a fair shuffle dealt into the positions in order,
and the Celtic Cross positions and their order (after Rachel Pollack: 1 现在, 2 挑战 across it, 3 根基 below, 4 近期过去
behind, 5 潜能 above, 6 近期未来 ahead, 7–10 the staff). Not right before, fixed now:

- 塔罗 page
  - The question first: an optional 你想问的问题 box before the draw. It shows above the cards and goes with the
    reading.
  - Each spread lies as it prescribes: one card in the middle; three cards in one row, 过去 → 现在 → 未来 from left to
    right; the Celtic Cross as the cross (1 in the centre, 2 lying across 1, 3 below, 4 left, 5 above, 6 right) and the
    staff (7 at the bottom up to 10 at the top). Before, every spread was a grid of cards.
  - Cards are numbered and turned in dealing order: touching any face-down card turns the next one, which glows
    gold, and the line above the cards names it (按牌阵顺序翻牌，下一张：第 3 张 · 根基).
  - Phones: the Celtic Cross (and three cards on a narrow phone) are thumbnails; touching one opens it large, and it is
    turned there. iPad and desktop show the whole spread on one screen, and cards turn where they lie.
  - A turned card opens large with its position and what that position means. Under the Celtic Cross every position
    is listed with its meaning; a turned card's row opens it too (card 1 lies under card 2).
  - Keyboard: Tab reaches the turned cards and the next one, Enter or Space turns it; in the enlarged view Enter
    turns the card and Esc closes it; Enter in the question box or Ctrl+Enter draws.
- 塔罗 readings (AI)
  - Tarot reads with its own prompt, `narrative_tarot@1`, written for tarot alone: the cards in dealing order, each in
    the light of its position; the spread's own method (three cards past → present → future; Celtic Cross: 1 with 2,
    then the lines 3 → 5 and 4 → 6, then the staff 7 → 10, comparing 10 with 5 and 1); upright and reversed; major and
    minor arcana and the four suits; the user's question answered.
  - The model now gets the spread ready to read (`<spread>`): each position's number, name and meaning, where it lies,
    the card's name in the user's language, upright or reversed, and the path to cite. Before, it saw only ids such
    as `major_09`.
  - The facts in a reading are numbered in dealing order (1. 过去: 隐士).
  - Each method stays separate (owner rule): 八字 and astrology still read with `narrative@4`, unchanged byte for byte
    (a test pins it); nothing in this update reaches another method.
- For developers: `app/lib/presentation/widgets/tarot_spread.dart` (`TarotSpread`, `celticRects`), `src/ai/tarot.ts`
  (`spreadBrief`), `POSITION_MEANINGS` in `deck.ts` (synced to the app), fixtures `chart_tarot_celtic` and
  `chart_tarot_single`, CLAUDE.md hard rule 8.
- Verified: new server tests (the spread in dealing order, tarot on its own prompt with `<spread>` and the question,
  `narrative@4` unchanged, numbered facts) and app tests (three in a row; the Celtic Cross on a desktop; turning in
  order; phone thumbnails turned large; Enter and Esc in the enlarged view; the question sent with the reading); all 88
  app tests and 254 server tests pass; harness PASS. Rendered on a phone, a laptop and a desktop.

### v1.1.2 (2026-10-27): tarot names match the art; two cards to a row on phones

- 塔罗
  - On a phone the cards are as large as two side by side allow, 137 pt on a 360-wide phone (208 left room for
    only one per row), and the text in the card area scales with them. Screens from about 500 pt wide keep twice
    the first size (208-pt cards, 28-pt text).
  - Card names now match the names painted on the art: 愚人 (was 愚者), 皇后 (was 女皇), 权杖一 / 圣杯一 / 宝剑一 /
    星币一 (were …王牌); in 繁體 the same (權杖一 …). 塔罗 readings use the new names too.
- For developers
  - `src/engines/tarot/deck.ts` has the new names, and `NAME_ALIASES` keeps the earlier ones, so the faithfulness
    check still catches a reading that writes 愚者 or 权杖王牌 for a card that wasn't drawn. The check no longer
    reads 「宝剑一样」 ("like a sword") as the Ace of Swords.
  - `npm run mirror:tarot` no longer reports names that differ.
- Verified: new tests for the phone layout (two 137-pt cards to a row at 360 wide, 208 at 1000), the earlier names
  and 「寶劍一樣」; all 83 app tests and 248 server tests pass; harness PASS. Rendered on a 360-wide phone in 简体 and
  English.

### v1.1.1 (2026-10-27): tarot cards twice as large

- 塔罗 (owner request: the cards and their text twice as large)
  - Cards are twice the size: 208 × 357 instead of 104 × 178. The text in the card area is doubled with them: the
    hint 点击卡牌翻开 and each card's position and name (28 instead of 14), and 逆位 (24 instead of 12). The back's
    gold frame and star grow too.
  - At this size the name, English name and keywords painted on a card can be read on the card itself.
  - Wide screens (tablet, desktop) show a three-card spread in one row. A phone has room for one card per row, so the
    cards stack and the page scrolls.
  - The rest of the page (牌阵, 抽牌, the reading request) keeps its size.
- For developers
  - The pictures are now 700×1200, the size the art was painted at and enough for the 208-pt card on a 3× screen:
    4.4 MB for all 78, made again with `npm run mirror:tarot`.
  - One constant, `_scale` in `app/lib/presentation/tarot_page.dart`, sets the size of the cards and their text.
- Verified: all 82 app tests and 247 server tests pass (the bundle test now checks 700×1200); harness PASS. The page
  was rendered at phone and desktop width and looked at.

### v1.1.0 (2026-10-27): tarot card art

**塔罗 cards with pictures** (new): every card of the 78-card deck now has its own picture, painted in
JingyaoPaint.

- 塔罗
  - Turning a card shows its picture: the scene, its number, its name (简体 and English) and three keywords, in the
    deck's navy and gold. A reversed card lies upside down, with 逆位 under it, as with a real deck.
  - Under each card: the position, and once the card is turned, its name in the chosen language (the name painted on
    the picture is small and always 简体).
  - Cards have the pictures' shape (7:12, 104 × 178) with small rounded corners. The back is the deck's navy and gold
    in light and dark mode alike (before: the app's red-to-green gradient).
  - The pictures load while the cards lie face down, so each card shows its picture as it turns. A card whose picture
    can't load shows its name, as before.
  - Keyboard and screen readers work as before: Tab to a card, Enter or Space turns it; the card is read out as its
    position, then its name and 逆位.
- For developers
  - `app/assets/tarot/`: one picture per card, named by card id (`major_00.webp` … `pentacles_14.webp`), 350×600
    WebP, 1.7 MB for all 78.
  - `npm run mirror:tarot` makes that folder from JingyaoPaint's `local_art/out/tarot` (1400×2400 PNG, about 2.4 MB
    each). It checks every file against the deck by its number and English name, fits it to 350×600 (enough for the
    104-pt card on a 3× screen), and makes the folder match: changed cards are rewritten, unchanged ones left alone,
    anything else removed. Run it again whenever the art changes (another folder: `npm run mirror:tarot -- <folder>`).
    Never edit the folder by hand.
  - New dev dependency: sharp 0.35.5 (image resizing; only the mirror script uses it).
- Verified: new server test (the folder holds exactly the deck's 78 cards, each a 350×600 WebP; file names map to
  cards by number and English name) and app test (all 78 pictures in the app bundle decode in Flutter at 350×600;
  turned cards show their picture and name); all 82 app tests and 247 server tests pass; harness PASS. The page was
  checked on rendered images in light and dark. The text painted on the cards (names and keywords, 367 in all) hits no
  compliance rule.
- Note: six cards are named differently on the picture and in the app (the deck in `src/engines/tarot/deck.ts`):
  愚人 (app: 愚者), 皇后 (女皇), 权杖一 / 圣杯一 / 宝剑一 / 星币一 (app: …王牌). The app shows its own name under the
  card.

### v1.0.0 (2026-10-27): keyboard access; first numbered release

The first numbered version. It contains everything delivered so far ([docs/SUMMARY.md](docs/SUMMARY.md)) and the
updates below.

**Keyboard access for web users** (new): the whole app works without a mouse.

- Every page
  - **Esc goes back one level.** An open dropdown or menu closes first, then a dialog, then the page. On 首页 it
    does nothing.
  - **Leaving a reading asks first.** On the 八字 form once you have changed something (or while it computes), on the
    命盘 page, and on 塔罗 once cards are drawn, going back asks 返回将重新开始 with 继续测算 / 返回. Enter = 返回,
    Esc = stay. The ← button, the browser's Back and a phone's back button ask the same. The profile editor and the
    为谁排盘 pop-up ask 放弃未保存的修改？ when edited.
  - **Tab / Shift+Tab** reach every control in reading order; **Enter / Space** press it and open or close a section.
  - **A clear focus outline** shows where you are while you use the keyboard: buttons, chips, cards, tarot cards,
    charts, option rows. It never shows for mouse or touch.
  - **Ctrl+/** (⌘/ on a Mac), or **?** outside a text field: the 键盘快捷键 list. Also in 设置 → 键盘快捷键.
  - **Ctrl+Enter** (⌘+Enter): the main button of the page: 登录, 排盘, 保存.
  - **Ctrl+Tab / Ctrl+Shift+Tab** stay the browser's (switching browser tabs; browsers never pass them to a page),
    as do Ctrl+W/T/L, F5 and Alt+←/→. Switching between options inside the app is **← / →**.
- 登录: Enter in 邮箱 moves to 密码; Enter in 密码 signs in.
- 八字排盘
  - 为谁排盘 from the keyboard: Tab to its arrow, Enter or ↓ opens, ↑ / ↓ move, Enter picks.
  - ← / → switch 排盘解读 / 一生运势报告, 公历 / 农历, 精确时间 / 时辰 and 男 / 女.
  - The 公历 date and the time, opened from the keyboard, start in typing mode (type 1990-03-15 instead of arrowing
    back through the years).
  - On the 命盘 page the 大运 / 流年 strips take focus: ← / → scroll, Home / End jump to the ends.
- 塔罗: every card is a Tab stop; Enter or Space turns it over. Screen readers hear the position, and the card once
  turned.
- 解读报告: the 运势走势 chart takes focus: ← / → previous / next period, Home / End first / last; ← / → switch
  大运 / 流年; Enter opens or closes each topic.
- 出生地: opened from the keyboard, type straight away; Enter takes the first match; Esc clears the search, then
  steps back 城市 → 省 → 国家.
- Fixed on the way: a chart or tarot draw that finishes after you have left no longer opens on top of 首页 or
  touches a closed page.
- For developers: `app/lib/presentation/keyboard.dart` (`KeyboardShell`, `LeaveGuard`, `SubmitShortcut`,
  `Pressable`, `SegmentKeys`), the focus look in `design.dart` / `theme.dart`, and the rules for new screens in the
  keyboard-access skill. A test fails if a screen adds a tap target without keyboard support.
- Verified: 20 new app tests (7 for the keyboard layer, 13 across every area above); all 81 app tests and 244
  server tests pass; harness PASS (lint, typecheck, tests, OpenAPI, schemas, audit, 八字 7000 cases vs the oracle,
  塔罗 100k draws, app analyze + tests + web build). The focus outline was checked on rendered images in light and
  dark. Not run: browser-based tests, which don't load on this machine.

**Also in v1.0.0** (earlier updates of this release):

- Top bar: 历史记录 · 个人资料 · 语言 (简 / 繁 / EN) · 设置 gear instead of the ⋮ menu; 语言 also on the sign-in page.
- Mock or real AI: `IS_AI_MOCK=TRUE` in `.env` answers every AI step with the mock (（示范）, no tokens);
  `IS_AI_MOCK=FALSE` with `IS_AI_MODEL=TRUE` uses DeepSeek. The API follows `.env` without a restart
  ([docs/web-test.md](docs/web-test.md)).
- 为谁排盘: pick, add or edit a person in a pop-up; 一生运势报告 is a mode of 八字排盘; the birthplace appears in
  readings.
- 一生运势报告: 易经本命卦, 梅花易数, 五行, 八卦; download (HTML + Markdown in a ZIP), print / PDF, copy.
- Content review paused by owner decision (`MINGLI_REVIEW=on` turns it back on); new disclaimer wording.
- 简体中文 is the main language, alongside 繁體中文 and English.

```
src/chart-fact/      ChartFact types, canonical JSON, keyed input digest, schema validator
src/engines/bazi/    BaziEngine (lunar-javascript + tz/DST + true solar time)
src/engines/tarot/   78-card RWS deck, spreads, HMAC-DRBG, audit replay
src/engines/astrology/  POC adapter on astronomy-engine
src/compliance/      rule-layer scanner + Geo-Rule resolver
src/ai/              AI Interp pipeline, providers (DeepSeek, Claude, mock), prompts, terms
src/api/             v1 API server (auth, account, charts, async reports)
src/auth/            passwords, tokens, Apple/Google ID tokens, login limits
src/service/         chart validation + runtime wiring shared by API and demo
app/                 Flutter app (Riverpod, zh-Hant/zh-Hans/en)
compliance/          prohibited_patterns.yaml, geo_rule_matrix.json, ai_disclosure_spec.md
schemas/             JSON Schemas (ChartFact v0.1, geo matrix)
api/openapi.yaml     OpenAPI 3.1 skeleton
db/schema_v0.sql     PostgreSQL schema v0
docs/                ADRs, POC report, security baseline, data retention, agent records
MODULES.md           reusable module registry. Check it before adding code.
```

Requires Node ≥ 20.

```
npm ci
npm run lint && npm test && npm run validate:schemas && npm run validate:openapi
```

Or run the full harness:
`powershell -ExecutionPolicy Bypass -File C:\Users\AgentSkills\harness-check\scripts\check.ps1 -Project .`
