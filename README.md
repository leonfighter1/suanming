# 命理大师

Phase 0 (engines, ChartFact, compliance) and Phase 1 in progress (AI pipeline, v1 API, Flutter app).
**Start here: [docs/SUMMARY.md](docs/SUMMARY.md)** (what each phase delivered).
Details: [docs/phase-0-gate.md](docs/phase-0-gate.md) · [docs/phase-1-status.md](docs/phase-1-status.md) · agent instructions in [CLAUDE.md](CLAUDE.md).
Web test: **https://leonfighter1.github.io/suanming/** ([docs/web-test.md](docs/web-test.md)).

## 更新记录 (release notes)

Newest first. Every update adds an entry: version and date, then by area what changed for users, how to use it, and
how it was verified. The steps that finish an update (harness, this entry, version) are in
[.claude/skills/keyboard-access/SKILL.md](.claude/skills/keyboard-access/SKILL.md).

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
