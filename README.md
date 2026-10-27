# 命理大师

Phase 0 (engines, ChartFact, compliance) and Phase 1 in progress (AI pipeline, v1 API, Flutter app).
**Start here: [docs/SUMMARY.md](docs/SUMMARY.md)** (what each phase delivered).
Details: [docs/phase-0-gate.md](docs/phase-0-gate.md) · [docs/phase-1-status.md](docs/phase-1-status.md) · agent instructions in [CLAUDE.md](CLAUDE.md).
Web test: **https://leonfighter1.github.io/suanming/** ([docs/web-test.md](docs/web-test.md)).

## 更新记录 (release notes)

Newest first. Every update adds an entry: version and date, then by area what changed for users, how to use it, and
how it was verified. The steps that finish an update (harness, this entry, version) are in
[.claude/skills/keyboard-access/SKILL.md](.claude/skills/keyboard-access/SKILL.md).

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
