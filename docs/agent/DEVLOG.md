# Dev log: 命理大师

Newest first. One entry per working session, key points only.

## 2026-10-28 (af): S10 算卦, the server half; the owner's updates planned (S11); release v5.3.0

- **Owner request: 算卦** (the coins cast automatically, half-automatically by picking from coins laid out before, or by the reader with the exact time and a reminder first; the 八卦, the texts at once or an AI reading; 「卦辞都是直抒胸臆，不用绕」). 六爻 had been parked in S6 as not in the owner's document; now it is their own request.
- G4 before building: the coin rule checked against 漢典「單錢」 (二面一背 = 少陽, so 背 3, 字 2). lunar-javascript's 干支 probed against hand counts from 2000-01-01 (戊午).
- WP10.1:
  - the engine (`src/engines/liuyao`): auto (DRBG), pick (24 coins committed before 18 picks), manual (lines or coins, time required);
  - the 干支 by the 八字 clock policy; 朱熹's focus rule; `verifyCast`;
  - schema, migration 006, API (`POST /v1/liuyao/layouts`), matrix 0.6.0;
  - `npm run verify:liuyao` as a harness and CI gate (10 checks, non-vacuity tested).
- WP10.2: 450 直說 in 繁體 (scripts/liuyao-plain), 简体 by `npm run build:liuyao`; checked against data/yijing (ids, 用九/用六), the global rules and length.
- WP10.3:
  - `narrative_liuyao@1` / `action_liuyao@1` (pinned), with 直抒胸臆 written into them;
  - the brief, AI label, facts layer, glossary 1.7.0;
  - faithfulness: wrong_hexagram, misquoted_text, and the cast's 干支 (rule 29);
  - Chinese only.
- **Owner, mid-task:** the tarot spread icons the same size with the name below, English removed, and the admin located in Beijing. Planned as S11 (v5.4.0), before 算卦's app pages so those are built without English. The English 直說 already written was dropped.
- Slips:
  - JSON.stringify reformatted the schema and .harness.json (rule 45);
  - backslashes in a heredoc broke an OpenAPI pattern (global rule 1 again, caught by validate:openapi);
  - a three-card mock narrative with one paragraph retried into clean text (the tests now give one paragraph per card);
  - the mock didn't cite 算卦's paths.
- v5.3.0 committed and tagged locally, not pushed.

## 2026-10-28 (ae): S9 Phase 3 门禁; release v5.2.0

- The owner's documents end with 「Gate 未通过不进入下一阶段」. So nothing of Phase 4 starts before Phase 3's gate passes.
- Of the gate's five items, one needed no owner input and was open: 起名's 专项规则. 风水 had F001 / F002; 起名 had nothing.
- WP9.1: rule group `naming` (N001 a name decides fate, N002 a name as a cure or charm, N003 a 吉凶 verdict), applied to 起名 only.
  - Negations are exempt both before and after the verb.
  - The AI labels (all three languages) and the card note are allow cases.
  - Tests: a 起名 reading is held, and the same text in tarot is not.
- WP9.2: docs/phase-3-gate.md (deliverables, the §4 tests, the gate checklist, the owner's decisions and what each opens). Linked from the README and CLAUDE.md.
  - English coverage now has tests: ARB parity and English's Chinese limited to listed keys (app); the glossary in three languages (server).
- Everything left in the owner's Phase 3 (and Phase 4) now needs the owner: listed in the gate record.
- v5.2.0 committed and tagged locally, not pushed (medium).

## 2026-10-28 (ad): S8 地区精细化 from the rest of Phase 3; release v5.1.0

- After v5.0.0, I looked for leftover work as the owner's standing rule asks. The owner's document set (pasted in this session's first message) still lists:
  - for Phase 3: Action Kit, TikTok support, Geo-Rule 精细化, English everywhere, RAG and fine-tuning;
  - nothing on any of these in the DEVLOG, README or git log (rule 34).
- Planned as S8 (tech plan) only what needs no owner input:
  - §2.4: Indonesia's blocks, Singapore's languages, the five-region gate test;
  - §2.5: the language kept, and the glossary gaps.
  - The rest is listed in the plan as waiting for the owner, each with the reason (payment, accounts, consent, the real model, vendors).
- Owner decision kept (2026-10-26): 简体中文 is the main language, and the app starts in 简体. So Singapore's 「双语权重」 adds English to its languages and changes no start language.
- WP8.1:
  - `ID` in the matrix (0.5.0) with `content_blocks` (a new dimension, in the schema too), unserved while `legal_review` is pending;
  - rule group `id` (I001–I003, zh both scripts + en, with negations);
  - `contentBlockLine` reaches every model call's user message. System prompts are unchanged, so no prompt versions move;
  - an invariant: pending ⇒ not served.
- WP8.2: test/geo-regions.test.ts, the Phase 3 gate. Rules routed per region on a real reading text, orders through `/v1/methods`, languages, and a hot update on a running server.
- Found: the API server and AuthService cached the matrix at start. My 起名 steps' "no restart" was wrong; both now read it per request (rule 44).
- WP8.3: `SettingsStore` (secure storage), `startLocale`, read in `main()` before the first frame. Glossary 1.6.0 (双声, 叠韵, also in `NAMING_TERMS`).
- Test slip: a scripted tarot narrative had one paragraph for three cards. The check retried with the mock's clean text, so the routing test saw no hits. Each scripted 逐张解读 now has one paragraph per card.
- v5.1.0 committed and tagged locally, not pushed (medium).

## 2026-10-28 (ac): S6 WP6.4, 起名 behind the owner's review; S6 complete; releases v4.5.0 and v5.0.0

- v4.4.0 committed and tagged (e899046) after a harness PASS (rule 23 again: the first run failed at analyze, the second passed).
- Spec from the owner's Phase 3 §2.1, §4: 五行补益 from the 八字 chart, a 字义库 in 繁 and 简 checked by hand, 音律 rules, candidates with their basis. Written into the plan before code.
- The 字义库 is a draft (100 characters, 83 surnames), so the owner's 人工校订 is a gate:
  - `naming` ships off in the matrix (0.4.0);
  - `LIBRARY.reviewed` is false;
  - a test holds the two together (on ⇒ reviewed);
  - the card's draft note follows the chart's `library.reviewed`.
- Checks: pinyin against pinyin-pro (G4), 简体 against OpenCC (G18), the element against the radical rule. 鉅 → 鑄: OpenCC makes 鉅 巨 and loses the 金.
- Engine: the 音律 rules, each its own function, unit-tested with hand-worked values. The tie order is hashed from the surname's 繁 form, so 張 and 张 give one list.
- AI, rule 8: `narrative_naming@1` and `action_naming@1` (pinned), no plan, its own brief, facts layer and AI label. Each method's user message is now built from shared arguments plus its own.
- API: `POST /v1/charts {system: "naming", bazi_chart_id, surname, length}`. It reads only the caller's own 八字 chart (404 otherwise). Migration 005, OpenAPI.
- App: 「為這個命盤起名」 on the 八字 chart page when the region offers it, `NamingPage`, `NamesCard`, the reading page and history (「起名 · 陳」 in the reader's script).
- Tried the owner's switch (reviewed, on, matrix 0.5.0, sync), ran every test, then undid it:
  - 7 tests pinned the shipped state. They now use `withNaming(available)` or read the matrix (rule 42).
  - With the fixes, all pass after the switch.
- A negative test was vacuous: a scrolled-past widget was still built. It is now anchored on the neighbouring button (rule 43).
- Owner's steps to turn 起名 on: docs/web-test.md.
- v4.5.0 committed and tagged (970efef) after a harness PASS (rule 23: the first run failed at analyze, the second passed).
- S6 stage summary written (tech plan, 阶段总结), and the v5.0.0 README entry.
- v5.0.0: committed and tagged after a fresh harness PASS on the final tree. Pushed main and the tags, carrying v4.1.0–v5.0.0 (owner rule: big updates only).

## 2026-10-28 (ab): S6 WP6.3, 风水 to the owner's spec; release v4.4.0

- v4.3.0 committed and tagged (16c00ea) after a harness PASS. The first run failed at analyze (rule 23, the pubspec bump); the second passed.
- Spec first, from the owner's Phase 3 §2.1, §4: room use + optional facing, anonymous, never 吉凶, all `simplified_rule`, a compliance rule set, and more weight in Malaysia. Written into the plan before code.
- Content: a table of 30 principles for 7 rooms (`src/engines/fengshui/principles.ts`).
  - Each has an everyday reason and the tradition without 吉凶.
  - 繁體, 简体 and English are written by hand; a test holds 简体 to OpenCC apart from 屏幕 and the quotes (rules 31, 36).
  - Facings: its own 後天八卦 table (rule 8, not 一生运势's 八宅, which assigns 吉凶), hand-checked in a test.
- Pipeline:
  - method rule groups (`METHOD_RULE_GROUPS`: the `fengshui` group, F001 and F002, on top of the region's);
  - every 风水 paragraph pinned to `simplified_rule`;
  - the description goes in as `<user_description>`;
  - its own AI label (`METHOD_LABELS`, which now holds 求籤's too).
- API: the 风水 chart request, matrix 0.3.0 (MY 1.3), migration 004, OpenAPI.
- App:
  - `FengshuiPage` (room chips with icons, facings, the description, 看佈局) and `PrinciplesCard`;
  - the reading page, history, the home entry;
  - rendered and looked at in 繁體 (throwaway test, Noto Sans SC loaded).
- A test missed the fourth home entry in the default 800 × 600 view: the list is lazy (G12 again). It now uses a tall view.
- v4.4.0 committed and tagged locally, not pushed.

## 2026-10-28 (aa): S6 WP6.1 + 6.2, 求籤 · 擲筊 and the entry order by region; release v4.3.0

- **Owner (2026-10-28): 「继续吧不要停」**, after v4.2.0 asked which S6 methods come first. No choice made, so (rule 34) S6 follows the owner's phase document:
  - Phase 3 §2.1: 起名 and 风水;
  - §2.4: the 擲筊 / 求签 entry first for Taiwan and Hong Kong.
  - The plan's own 六爻 / 合婚 are parked.
  - WP7.2 stays open, and pushing waits for S6's big update (both unanswered; the defaults kept).
- The lot set (G4, rule 39):
  - Searched for verifiable texts: 六十甲子籤 and 黃大仙靈籤 have no full primary source online; the 關聖帝君一百籤 (雷雨師一百籤, 行天宮) has two transcriptions (Wikisource, temples.tw) and a Qing print scan (Harvard DRS 53239458, public domain).
  - A ∩ B agreed on 85 lots. Reading the print showed they also share errors, so all 100 lots were read in it (montages of the poem columns, zooms on each difference).
  - Policy: the temples' text, with the print settling the 16 disagreements and 5 plain errors; 38 variants listed. Evidence: docs/verification/qiuqian-guandi-100.md. 简体 via OpenCC in `npm run build:qiuqian`, with 乾坤 / 乾亥 kept and three fixes (G18).
- Engine: rounds of one stick and one throw, until a 聖筊 (cap 64), from HMAC-DRBG on its own seed label. `verifyDraw` replays it. `npm run verify:qiuqian` (100k draws, 8 checks) is a new harness gate, with a non-vacuity test.
- AI, rule 8:
  - `narrative_qiuqian@1` and `action_qiuqian@1`, pinned;
  - no plan;
  - its own brief (`src/ai/qiuqian.ts`: the lot in the reader's script; rounds hidden from the model);
  - its own AI label (「依據所得籤詩生成」: the shared one said 命盤);
  - faithfulness: a quoted line must be the lot's, and the lot keeps its number;
  - compliance rule G008 (offerings or rituals framed as what undoes a lot).
- API and data:
  - `/v1/methods` (matrix 0.2.0: qiuqian 1.5 in TW and HK);
  - the share image for 求籤 (`src/share/qiuqian-image.ts`, laid out and looked at in 繁體 and English);
  - migration 003 (enum value).
- App:
  - home order from `methodsProvider` (default order offline);
  - `QiuqianPage` (the rounds revealed one step at a time, Enter throws, skip);
  - `LotCard` and `JiaobeiBlocks`;
  - the reading page, history and 分享图片 for 求籤;
  - the lot set synced with each lot's title from the server's `lotTitle`;
  - rendered and checked in a throwaway test with Noto Sans SC loaded.
- Mistakes recorded:
  - 38: a file written to a retyped `C:\命理大師`. The empty folder stays: the guard blocks removing it.
  - 39: modern copies share errors.
  - 40: the owner's email went out once in a User-Agent; told the owner.
  - 41: summarising fetches don't give verbatim text.
  - 30 corrected in place: absolute `C:/` imports fail in project-root scratch scripts.
- v4.3.0 committed and tagged locally, not pushed.

## 2026-10-28 (z): S6 waits for the owner; S7 WP7.1, the tarot share image; release v4.2.0

- v4.1.0: the first harness run failed at the app gate (rule 23, the pubspec bump); the second passed. Committed and tagged (188d1c6).
- Rule 34 on S6:
  - The owner's phase document plans 起名 and 风水 (Phase 3, with specs), and puts 擲筊 / 求签 first for Taiwan and Hong Kong.
  - It never mentions 六爻 or 合婚, which came from this plan's review.
  - S6 is marked as waiting for the owner's choice. S7, the owner's own spec, goes first.
- G4 before building: a scratch probe showed sharp alone sets CJK text in a given font (Pango) and composites the WebP art: 150 ms, 139 kB, every glyph right. No headless browser is needed.
- Font: a system dependency, not a binary in the repo:
  - `MINGLI_SHARE_FONT`, or found: Noto Sans CJK (TC face for 繁體), Noto Sans SC or 微软雅黑, PingFang;
  - CI installs fonts-noto-cjk;
  - no font gives a 503 that says what to install.
- Fixed on the way:
  - the card path from `URL.pathname` is percent-encoded under 命理大师 (`fileURLToPath` now);
  - the AI label ran into the watermark in English (its place follows its height now).
- App:
  - `ApiClient._withAccess` (the refresh logic, shared) with `_bytes` and `_problem`;
  - `shareProvider` (tests replace it), and `testApp(overrides:)`;
  - Riverpod 3 keeps `Override` in `misc.dart`.
- Tests: on the VM, `XFile.fromData` keeps no name, so the test checks `fileNameOverrides`. A racy "still pending" assertion against the mock was dropped (rule 37).
- v4.2.0 committed and tagged locally, not pushed.

## 2026-10-28 (y): S5 数据持久化, the encrypted database store; release v4.1.0

- v4.0.0 pushed with v3.1.0–v3.5.0 after a fresh harness PASS on the final tree (second run, rule 23). CI and Pages green for 1770341. No gh CLI here: the Actions REST API was polled from node.
- Spec first (rule 34): the phase document (AES-256 at rest; keys never in the DB or code), `schema_v0.sql` (DEK per user, KEK, crypto-shred, deletion_requests) and data-retention.md gave the design. WP5.2 (accounts) was added because readings without their owners are useless.
- Probed PGlite types in a scratch script before writing the store: jsonb objects, bytea, `timestamptz` → Date, `date::text`, text[], `affectedRows`, transactions. The one surprise came later: an enum array parameter (rule 35).
- `PgStore` seals whole records and fills only the schema's lookup columns. The DEK is cached only after its row is in. `rawRows` is limited to the store's tables.
- Rule 32 at work: an assertion compared `users.get(b)` with itself (`x && await y`), and the deletion record's "no PII" check missed the bytes of `subject_hash`. Both fixed before commit.
- Found: jobs had no catch, so a database write failure would have been an unhandled rejection (`track()` now). And the term tips' OpenCC import reached the server through the ai index (since v3.2.0); rule 36 and `runtime-deps.test.ts` cover it.
- Smoke run of the real `scripts/api-server.ts` with the store on (throwaway keys and folder in the child's environment only; `.env` untouched; AI on the mock):
  - the start line says `data: kept in …, encrypted`;
  - register gives 201 and X-Dev-User 401;
  - after a SIGKILL (no shutdown handler) and a restart, login gives 200.
- v4.1.0 committed and tagged locally, not pushed (a medium update).

## 2026-10-28 (x): S4 WP4.8, English names that fit; S4 summary; release v4.0.0

- v3.5.0: the first harness run failed at the app gate (rule 23); the second passed. Committed and tagged (3b9a904).
- WP4.8:
  - `Terms.short` (English minus its trailing pinyin) is a rule over the one term table, so there is no second name list. Abbreviations (DR, 7K) were set aside because they would need names other than the table's.
  - `TermTip(shrinkOneWord:)` puts a one-word name in a `FittedBox(scaleDown)`; several words still wrap.
  - Strips: 128 px in English with a line per part (`_Step.lines`); ←/→ step by the width. The zh-Hant keyboard test keeps its 104 px.
  - Checked by rendering the English page; the relations labels then got the brief form too.
- The release is v4.0.0, not v3.6.0. WP4.9 (the share image) moved to a new stage, S7, because it needs a server renderer and S5's stored readings, so WP4.8 was S4's last WP. The code comments said v3.6.0 and were changed.
- S4 summary written. Since v3.0.0 no reading, plan, life or review fixture and no prompt changed (git diff checked).
- v4.0.0: harness on the final tree, then committed, tagged and pushed with v3.1.0–v3.5.0.

## 2026-10-28 (w): S4 WP4.6 + WP4.7, code health; release v3.5.0

- v3.4.0: the first harness run failed at the app gate (rule 23); the second passed. Committed and tagged (c05a1ee).
- WP4.6:
  - A node script cut `life_report_page.dart` and `profiles_page.dart` at line boundaries it checked first, then renamed the moved private classes across the files (lookaround regex, split/join, global rule 16).
  - Then: a key parameter on every newly public widget (the lint asked), six unused imports dropped, and `birth_fields.dart` imported by the 八字 form.
  - Kept: `LifeReportPage`, `LifeReportButton` and `startLifeReport` stay in the page file (other files use them).
- Rule 34 again: the tips on the life report are dropped (owner's template, few 八字 terms, its 喜用 is the reading's).
- WP4.7:
  - `scrollToFinder` in `support.dart`; 21 calls in 12 files moved onto it or `scrollTo`.
  - The four local `scrollAndTap` helpers stay: they differ on settling after the tap, and merging them could change what a test sees.
  - `test_rules_test.dart` scans `test/` for a direct `scrollUntilVisible`; its pattern is escaped so it doesn't match its own source. Rule 27 widened.
- v3.5.0 committed and tagged locally, not pushed.

## 2026-10-28 (v): WP4.4 closed (owner decision), WP4.9 split off; S4 WP4.5, the reading page; release v3.4.0

- v3.3.0: the first harness run failed at the app gate (rule 23); the second passed. Committed and tagged (385c426).
- WP4.4:
  - Before building the 首页 一生运势 entry I read why there was none. The owner had asked on 2026-10-27 to put 一生运势 inside 八字排盘 (「把一生运势放到八字排盘内，作为同另一个选项」), and that change removed the home card. The DEVLOG line had said "Improve" without "(owner)".
  - WP4.4 is closed with that reason; 首页 already has 今日 and the recent readings. The DEVLOG line is relabelled. Rule 34.
- Rule 34 on the rest of S4: WP4.5's "share as an image" meets the owner's phase document (「分享图由服务端生成，带水印与免责声明」). It is now WP4.9: server-rendered, a watermark, the disclaimer, a deep link later.
- WP4.5:
  - `ReadingChart` (renamed from `ReadingSpread`): a 八字 reading shows `_ReadingPillars`. The fake API serves the 八字 chart now.
  - `FourLayerReport` has the jump list (chips in a horizontal `SingleChildScrollView`), a `GlobalKey` and a `Focus(skipTraversal)` per target, and `scrollCacheExtent` (the new name of `cacheExtent` in this Flutter).
  - The tarot spread test found section titles by text and met the chips first; it now looks inside the tiles.
  - Checked by rendering: the first jump list wrapped to four rows in English, so it is one scrolling row now. The 行动建议 chip read 「行動建議 · AI 生成」, so it has its own string.
- v3.4.0 committed and tagged locally, not pushed.

## 2026-10-28 (u): S4 WP4.3, the 命盘 timeline; release v3.3.0

- v3.2.0: the first harness run failed at the app gate (rule 23); the second passed. Committed and tagged (ccd7ab5).
- Engine:
  - `dayun_years`: one `yearEntry` helper builds both it and `liunian`, so `liunian`'s JSON is unchanged. Optional in the schema; a provenance entry (filtered out of prompts, since the view lacks the path).
  - Kept out of every model input (`baziView`, `lifeBazi`) and out of `knownGanzhi`: 80 years cover all 60 干支. The existing 甲子 test now says why (2044 is among them). Rule 29 widened.
- Term table 1.2.0: the twelve 节. A scratch scan showed they occur nowhere a model reads (only in shensha.ts `liuyue`), so no glossary and no fixture changed.
- App:
  - `BaziChart.dayunYears`, `liuyue`, `thisYear`, `currentDayun`, `yearsOf`.
  - `_DayunCard` holds which 大运 is open.
  - `_Timeline` items take a badge, a selected border and an `onTap` (a `Pressable` per item inside the strip's).
  - The new 流月 card.
- Found while checking a render:
  - The new 2 px border cost the year line its 虚岁 (an ellipsis, which tests can't see with their square-glyph font): the padding gives the 2 px back. Rule 3 widened.
  - English relation lines ran together (`pillarRelation` now).
- Mistakes: rule 33. `ValueKey(s.id)` on a `String?` made `ValueKey<String?>`, so no finder and no `focusedKey()` matched it, and the first timeline tests failed.
- Plan: WP4.8 now also covers the strips' English lines.
- v3.3.0 committed and tagged locally, not pushed.

## 2026-10-28 (t): S4 WP4.2, term tips on the 命盘; release v3.2.0

- Server:
  - `src/ai/term-tips.ts` holds 63 tips. 简体 and English are written by hand; 繁體 goes through `normalizeTerms`, then OpenCC, then `TERM_TIP_HANT_FIXES`.
  - The G18 review (`scripts/print-term-tips.ts`, plus a scratch sweep of the one-to-many characters) found 子醜, 三閤, 藏幹, 克 for 剋, and “” in 繁體. All are fixed.
  - The tips are synced as `term_tips.json`.
  - `test/term-tips.test.ts` derives every 十神 and 十二长生 from the engine, and uses `Record`s over the engine unions so a new relation or 神煞 fails the typecheck. It also pins the reviewed text with a hash and runs the rule layer over all regions.
- Found: 衰 病 死 墓 胎 were missing from `i18n/terms.json`, so the English page showed them in Chinese. They are added (term table 1.1.0). Single characters stay out of the glossary and normalisation, so no fixture changed, which confirms the prompts are untouched. The pipeline test now lists all 12 stages.
- App:
  - `Terms.tip`; `TermTip` (dotted underline, `Pressable`); `TermTipButton` (the cards' ? button); `Pill(dotted:)`.
  - Applied to the 四柱 labels and cells, the 旺衰 pills, 神煞 / 空亡 / 胎元 and the relation types.
  - Hint line under the table.
  - Checked by rendering the page and the dialog in both languages.
- Mistakes:
  - Rule 32 (`expect.any(String)` matches `''`, caught on review).
  - Rule 22 widened: render the root layer to include a dialog.
  - Rule 30 widened: no `tsx -e`; check CJK in a script, since Git Bash's grep isn't UTF-8 here.
  - G3 again: I reached for `python` for an edit, and it is still the store stub.
- Plan:
  - WP4.6 now also gives the split life report its tips.
  - New WP4.8: short English names for the 四柱 table, whose cells break mid-word on a phone.
- v3.2.0 committed and tagged locally, not pushed (a medium update).

## 2026-10-28 (s): v3.0.0 pushed; S4 WP4.1, readable 五行 colours, folded 四柱 rows; release v3.1.0

- v3.0.0 pushed with v2.1.0–v2.8.0 after a fresh harness PASS; CI and Pages green for ca14148.
- WP4.1:
  - The colours already existed, so the work was making them readable. I measured each one before choosing, with a probe that printed every WCAG ratio: the card (surfaceContainerLow) costs about 5% against the plain page, and that put light 木 at 4.45. Light 木, 土 and 金 are now darker; `wuxingColorOf(context, …)` gives dark mode its own lighter set. A test pins at least 4.5 : 1 for all 20 pairs.
  - The life report's private palette was removed (reuse-first).
  - `_PillarGrid` is stateful with `pillar-more`; the coloured 藏干 lost its shading.
- v3.1.0 committed and tagged locally, not pushed (a medium update).

## 2026-10-28 (r): S3 WP3.6, 洗牌 → 切牌 → 选牌; S3 summary; release v3.0.0

- v2.8.0: harness PASS after the rule 23 retry; committed and tagged.
- WP3.6:
  - Engine: `drawWithRitual` (full seeded shuffle, orientation per place, cut, picks), `ritualProblem`, `audit.ritual` (schema: optional), `verifyDraw` replays either path.
  - Service and API: `ritual` on the chart request (OpenAPI).
  - Battery: `spreadChecks` refactor (names unchanged), plus 9 ritual checks. 64/64 pass.
- App:
  - `TarotRitualSteps`, `CardBack`. 抽牌 starts the ritual; skipping it draws the classic way.
  - Tests that draw now skip the ritual (`drawAt`, widget_test, keyboard_test).
- Failure fixed: 「洗牌」 in 简体 copy (locale_test caught it), rule 31.
- S3 summary written; S3 done. v3.0.0 committed, tagged and pushed with v2.1.0–v2.8.0 after a fresh harness PASS.

## 2026-10-28 (q): S3 WP3.5, 二选一 and 关系牌阵; release v2.8.0

- v2.7.0: harness PASS after the rule 23 retry; committed and tagged.
- WP3.5:
  - Spreads `two_paths` (5) and `relationship` (6) with their own position keys, labels and meanings; `PLACES`, typed by spread, made the compiler ask for theirs.
  - narrative_tarot@3, built with swap() on @2.
  - Schema and OpenAPI enums extended; fixtures for both through sync:app.
- App:
  - `spreadRects` + `_spreadWide` / `_spreadTall` generalize the two-dimensional layout. The Celtic Cross keeps its exact sizing, so the hand-worked widths still hold.
  - The picker moved from SegmentedButton to wrapping ChoiceChips (five spreads overflow a phone row). The keyboard test's next stop is `spread-single`.
- Fixed on the way: an info-level lint (a `for` without braces) would have failed `flutter analyze` in the harness.
- v2.8.0 committed and tagged locally, not pushed (a medium update).

## 2026-10-28 (p): S3 WP3.4, 牌义图鉴; release v2.7.0

- v2.6.0: harness PASS after the rule 23 retry; committed and tagged.
- WP3.4:
  - Keywords from the art: JingyaoPaint's card code (`keywords:` on each major, `_meanings` for the minors) → `build-tarot-keywords.ts` → `data/tarot/keywords.json` (ignored by prettier, rule P2).
  - 繁體 by OpenCC with a G18 review list. I reviewed all 234: one fix, 疗愈 → 療癒, which my one-to-many list had missed until I read the full output.
  - English in `keywords-en.ts`; `KEYWORDS` in `keywords.ts`; synced as `keywords` in tarot_deck.json (`Terms.keywords`, `Terms.cardIds`).
  - `TarotGlossaryPage` from the 塔罗 bar.
- Failure fixed: places.test's sweep (sync) passed alone in 2.5 s but finished at 9.8 s in the full run and failed the 5 s default. It now has an explicit 30 s timeout; rule 4 widened in place to cover dataset sweeps.
- v2.7.0 committed and tagged locally, not pushed (a medium update).

## 2026-10-28 (o): S3 WP3.3, 每日一牌; release v2.6.0

- v2.5.0: harness PASS after the rule 23 retry; committed and tagged.
- WP3.3 (`src/service/daily.ts` + route `GET /v1/tarot/daily`):
  - `keyedUuid` (UUIDv8 from an HMAC under the draw key) for the draw id and the chart id.
  - The date must be within a day of the server's UTC date.
  - Geo-Rule first. Stored once with `ChartRecord.daily`; left out of `listCharts`.
- App:
  - `dailyCardProvider` with the device date; `daily_card.dart` (`DailyCard` on 首页, `DailyCardPage` with the spread and a reading request).
  - Fake API route; `tabTo` moved to `test/keys.dart` (reuse-first).
- Test fixes on the way: the home Tab-order test pressed Tab exactly six times, so the seventh stop never showed. It now presses seven, and Shift+Tab goes back to 塔罗 so its Enter check stays.
- v2.6.0 committed and tagged locally, not pushed (a medium update).

## 2026-10-28 (n): S3 WP3.2, choosing a spread and asking; release v2.5.0

- v2.4.0: the harness hit rule 23 on the first run; the automatic retry passed. Committed and tagged.
- WP3.2:
  - Spread picker as `SegmentedButton` + `SegmentKeys`, with a `SpreadDiagram` per segment, built from `celticRects`.
  - The positions line under it comes from deck.ts `SPREADS`, synced as `spreads` in tarot_deck.json (`Terms.spreadPositions`).
  - Four example question chips.
  - The Celtic Cross list takes max(scale, 1.5).
- Tests: `drawAt` picks a spread by its segment key. Taps on a segment label pass `warnIfMissed: false`: the segment's button takes the touch and the label isn't in the hit path.
- v2.5.0 committed and tagged locally, not pushed (a medium update).

## 2026-10-28 (m): S3 WP3.1, a tarot reading shows its cards; release v2.4.0

- v2.3.0: the first harness run failed at analyze (rule 23); the second passed. Committed and tagged.
- WP3.1:
  - `publicReport` carries `chart_id` (additive; OpenAPI updated).
  - The app's `ReportView.chartId`. `ReadingSpread` on the reading page shows a tarot spread, all turned, via `chartProvider`.
  - `FourLayerReport.header` takes no stagger slot, so 八字 pages animate exactly as before.
  - History tiles show the cards' art: up to five, reversed ones turned, from the chart summary's `reversed`.
- Fixture: the tarot report now names its real chart (`33333333-…`, chart_tarot.json). The fake API serves that chart, and takes an optional `history` list.
- v2.4.0 committed and tagged locally, not pushed (a medium update).

## 2026-10-28 (l): S2 WP2.2, a tarot-native reading; S2 done; release v2.3.0

- Sections `tarot_cards`, `tarot_synthesis` and `tarot_advice` (TOPICS); 八字 got an explicit list (`bazi: TOPICS` would have taken them, rule 8).
- `focus` (tarot only, validated in the pipeline and the API) goes into `<focus>`.
- New prompts: narrative_tarot@2, action_tarot@2 (actions on 建议 only) and remedy_tarot@2, all derived from @1 through swap().
- The pipeline:
  - The four-paragraph cap is lifted for 逐张解读.
  - A skipped card brings one retry naming its path.
- Plans: NO_PLAN_TOPICS (逐张解读, 综合解读) are refused by the API and never preloaded. A new tarot reading gets one plan; old readings keep theirs.
- App:
  - Focus chips under the question.
  - No topic chips for tarot.
  - Plan buttons skip `noPlanTopics`.
  - The contract and a tarot report fixture come through sync:app.
- Failures fixed:
  - Two phone tests tapped an old position after ensureVisible. The tap warning gave y 873 on an 800-px screen. Fixed with a pump; rule 27 widened in place.
  - My own test read `layers.actions.actions` (the layer is the array).
- S2 summary written; S2 done. Next: S3 塔罗体验 (big, v3.0.0, pushed with v2.1.0–v2.3.0).
- v2.3.0 committed and tagged locally, not pushed (a medium update).

## 2026-10-28 (k): S2 WP2.3, what each agent reads; release v2.2.0

- v2.1.0: the first harness run failed at analyze (rule 23: the IDE's pub get after the pubspec bump); the second passed. Committed and tagged locally.
- WP2.3 (`src/ai/bazi-view.ts`):
  - A reading reads its focus in full (the current 大运 and the next; this year and two more; any year in the question).
  - A plan reads its topic's lowest-scoring periods from now on.
  - Every other period keeps its place with its 干支, ages and 十神, so cited paths still match the stored chart.
  - `view` names the focus; 流月 is gone; the life agents lose 流月 and the 流年 scores.
  - narrative_bazi@6 and remedy_bazi@4 describe the view.
- Measured (sample chart, mock, characters sent for a reading + six plans + life report): 304.5k → 168.2k without the reviewer, 572.3k → 305.3k with it. Plans alone went from 195.8k to 85.3k.
- Found while measuring: checkFaithfulness didn't know the 干支 of 胎元 or the 流月 (rule 29). The measuring script failed three times on tsx details first (rule 30).
- v2.2.0 committed and tagged locally, not pushed (a medium update).

## 2026-10-27 (j): S2 WP2.1, every method's own prompts; release v2.1.0

- v2.0.0 pushed with v1.3.0 after a fresh harness PASS. The first run failed at analyze (rule 23: the junction the guard wouldn't let me remove); the second passed. CI and Pages green for 0d2c698.
- WP2.1:
  - `METHOD_PROMPTS` names each method's narrative, action and remedy prompt.
  - New prompts: action_bazi@4, remedy_bazi@3 (the engine's 喜用 / 忌, 虚岁), action_tarot@1, remedy_tarot@1 (cards only; its own closing note), narrative_astrology@1, action_astrology@1.
  - Astrology has no plan: refused at the API (400), never preloaded.
  - The 八字 facts layer shows 旺衰 / 喜用.
- Found while reading: astrology was read with narrative@4 (health as 五行), and remedy@2 told tarot plans to use 五行 colours and directions. Both were rule 8 leaks, now closed.
- Hashes: the nine existing versions were taken from the committed file before the edit, so the new pin test proves none changed (G7).
- Plan: S2 is now three medium releases (v2.1.0 WP2.1, v2.2.0 WP2.3, v2.3.0 WP2.2). Rule 23 was corrected in place (the guard blocks removing the junction). Memory updated (the project now follows the tech plan).
- v2.1.0 committed and tagged locally, not pushed (a medium update).

## 2026-10-27 (i): S1 part 2 (旺衰, 喜用, 运势 scores from the engine); S1 summary; release v2.0.0

- WP1.6 strength.ts:
  - 扶抑法 on the 100-point position scheme. The plan's weights had no source behind them (G4).
  - 得令, 通根, 喜用 / 忌 and the 专旺 / 从格 flag, shown on the 五行 card.
- WP1.7 trend-scores.ts:
  - Six topic scores for every 大运 and 流年, from the facts, with what each rests on.
  - Notes from templates (trend.ts).
  - The trend agent left the 八字 pipeline, so a reading makes one model call fewer.
  - narrative_bazi@5. life_methods@2 and life_topics@2 take the engine's stage scores and 虚岁 labels.
  - Schema: new optional properties only.
- The S1 summary is written in docs/tech-plan.md. Found on the way:
  - WP2.3: the facts the model reads grew from 3.3k to 17.0k characters over S1.
  - WP4.7: the other widget tests move to scrollTo().
- Mistakes:
  - Rule 27: back-to-back scrollUntilVisible. A probe of the scroll offsets showed that ensureVisible leaves no frame, so the next check saw the old layout and its first drag went past the card.
  - Rule 28: the trend notes called every 刑, 害 and 破 「刑害」. Caught while taking a README example from real output.
- Tooling: the guard now blocks `cmd /c rmdir` on a junction that points at the repo, so the scratchpad junction from the manual Flutter runs stays (rule 23).
- v2.0.0 committed and tagged, then pushed with v1.3.0 after a fresh harness PASS.

## 2026-10-27 (h): tech plan and dev-workflow skill; S1 part 1, release v1.3.0

- Owner: turn the review into a technical plan in stages, write a stage summary after each big stage, version by size (big X.0.0, medium X.Y.0, small X.Y.Z), push only big updates and only after a fresh harness PASS, describe every update in the README, never forget past mistakes, then work through the plan. Written: docs/tech-plan.md (stages S1–S6) and .claude/skills/dev-workflow (the finishing steps moved there from keyboard-access); CLAUDE.md points to both; memory updated (push rule).
- S1 WP1.1–1.5: 虚岁 on every 大运 / 流年 and in every display; `lunar_pillar_day` for the 本命卦; relations.ts (all 合冲刑害破, natal, 大运, 流年); shensha.ts (神煞, 空亡, 胎元, 流月); the 子时 switch. Schema: new optional properties only. 20 new protected terms.
- 命宫 / 身宫 deferred to WP1.8: two derivations of the formula disagreed and there was no reference to check against.
- Mistakes: a test scrolled past lazily built cards (rule 25); the app's term table was stale after editing i18n/terms.json (rule 26). Two of my own expectations were wrong before the first run (寅申 冲 missed; 庚 against 己 is 伤官); re-deriving by hand caught them, not the run.
- v1.3.0 committed and tagged locally, not pushed (a medium update).

## 2026-10-27 (g): 塔罗 the classic way; each method separate; release v1.2.0

- Owner: check the tarot rules (above all the Celtic Cross layout, the classic order and method) and fix the UI and AI prompts. While at it: phones may use thumbnails opened large to turn, iPad and desktop show everything; and every method must stay separate, never affecting another.
- Audit: the engine was right (fair shuffle dealt in order; Pollack's position order). Wrong: every spread a grid, cards turned in any order, no numbers or position meanings, no question before the draw (the API took one, the app never sent it), and the AI shared the 八字 narrative prompt with no tarot method, saw card ids only and had to guess that position n is /cards/(n−1).
- UI (widgets/tarot_spread.dart): single centred, three in a row, Celtic cross + staff (`celticRects`, 5.6 w × 7.157 w, sized to the width and the screen height, w ≤ 150); cards under 96 pt are thumbnails that open large and turn there; touching any face-down card turns the next; numbers, gold glow on the next card, waiting cards out of the Tab order; enlarged view with the position's meaning; Celtic list whose rows open turned cards. Question box before the draw (Enter / Ctrl+Enter draws), sent with the reading. `Pressable(autofocus:)` added for the enlarged card.
- AI: `narrative_tarot@1`, self-contained, with `tarotUser` and `<spread>` (src/ai/tarot.ts `spreadBrief`); `runAgent` takes a method's own prompt; `narrative@4` untouched, its hash pinned in test/tarot-reading.test.ts; tarot facts numbered. `POSITION_MEANINGS` in deck.ts → tarot_deck.json; fixtures for the Celtic Cross and the single card.
- CLAUDE.md hard rule 8: each method stands alone.

## 2026-10-27 (f): tarot names match the art; two cards to a row on phones; release v1.1.2

- Owner: push once all tasks are done (v1.1.0 tags and v1.1.1 pushed), then "yes for both" open questions: phone-fitted cards, and the six names that differed between the art and the app. "Yes" didn't pick a side for the names; the app now uses the painted ones (Mainland usage, the main language since 2026-10-26), leaving the art and JingyaoPaint untouched.
- Names: 愚人, 皇后, 权杖一 … 星币一 (繁 likewise) in deck.ts; sync:app → tarot_deck.json. The facts layer and checkFaithfulness use them; `NAME_ALIASES` keeps 愚者 / 女皇 / …王牌 for the check, and a 一-word guard stops 「宝剑一样」 counting as the Ace of Swords (both tested). mirror:tarot reports no differences now.
- Layout: `_scaleFor(width)` fits two cards side by side, between 1× and 2× of 104 pt (137 on a 360 phone, 208 from 502 wide); text, back frame and gaps follow the scale; the width is rounded down so two exactly fitting cards don't wrap.
- Mistakes: a second pumpWidget of the same app kept its navigator (rule 24).

## 2026-10-27 (e): tarot cards twice as large; release v1.1.1

- Owner request: 卡牌界面字体和牌面需要放大2倍. Cards 104 → 208 pt wide (7:12, 357 tall); the card area's text at twice the body size (hint, position, name; 逆位 12 → 24); the back's frame and star scaled too. Corners 12: at 16 the clip would touch the painted gold frame. One `_scale` constant in tarot_page.dart.
- Pictures made again at 700×1200 (350×600 would be stretched 1.8× on a 3× phone): 4.4 MB for 78, largest 78 KB.
- Phones fit one 208-pt card per row, so spreads stack (three-card about three screens, Celtic cross ten rows); told the owner, with a phone-fitted size as an option.
- The first harness run failed at analyze again (l10n files deleted) although pub get + gen-l10n had run right after the pubspec change, so rule 23's cause was wrong: the deletion follows a Flutter run from another path that still exists (the kept scratchpad junction, the IDE's real path). Rule 23 corrected; the rerun passed.
- Not pushed: the v1.1.0 push was blocked by the permission system; v1.1.0 and v1.1.1 wait for the owner.

## 2026-10-27 (d): tarot card art from JingyaoPaint; release v1.1.0

- Owner request: bring the tarot cards in `C:\AIProjects\JingyaoPaint\local_art\out\tarot` into the app's cards, in a folder of their own in the repo.
- Source: 78 PNGs (1400×2400 = 7:12, opaque) and their .jypaint files, painted by code in JingyaoPaint's `local_art/tarot` (git-ignored there, so on this computer only). Names `NN 名字 Name.png` in deck order, matching `deck.ts` (wands, cups, swords, pentacles).
- Built: `scripts/tarot-art.ts` (names, file → card check by number and English name, WebP header) and `scripts/mirror-tarot-art.ts` (`npm run mirror:tarot`; sharp 0.35.5 dev dependency): 350×600 WebP q85, lanczos3, only changed cards written, strays removed; a second run changes 0 of 78. `app/assets/tarot/<card id>.webp`, 1.7 MB. CLAUDE.md rule 4 now names the folder.
- App: the face shows the picture (104 × 178, radius 8 so the painted gold frame isn't cut), reversed = upside down, the name in the reader's language under the card, back in the deck's navy and gold, pictures precached on draw, the name as fallback. Picture and captions are left out of semantics (the card's label reads them).
- Checks: all text painted on the art (367 names and keywords) through every compliance rule group: 0 hits. Rendered light and dark and looked at.
- For the owner: six painted names differ from the deck's (愚人/愚者, 皇后/女皇, 权杖一…星币一 vs …王牌); the painted text is 简体 in every language.
- Mistakes: a golden is captured at 1× logical size whatever the view's pixel ratio (rule 22). Every first `flutter pub get` after a pubspec change (manual, the IDE's, the app gate's) deleted the committed l10n files, so the first harness run failed at analyze; `flutter gen-l10n` restored them unchanged and the rerun passed (rule 23).

## 2026-10-27 (c): keyboard access for web users; release v1.0.0

- Owner request: keyboard support for web users. Esc goes back one level, and on a 测算 page it first reminds that going back starts over; Tab, Enter to expand, Ctrl+Tab and the rest considered. Plan listed by area first, then built area by area.
- Built `app/lib/presentation/keyboard.dart`: `KeyboardShell` around the Navigator (Esc = close the nearest open layer, else pop the page; Ctrl+/ or ? = 键盘快捷键 list; Ctrl+Enter = the page's `SubmitShortcut`), `LeaveGuard` (返回将重新开始 on the 八字 form once edited, 命盘, 塔罗 once drawn; 放弃未保存的修改？ in the profile editors; also covers the ← button and system back), `Pressable` (tarot cards, the trend chart, the 大运 / 流年 strips), `SegmentKeys` (←/→ on every option row), `keyboardInUse` (date / time pickers open in input mode, the 出生地 search autofocuses). Focus look: `FocusRing` / `focusOutline` in design.dart, button and chip outline in the theme. Sign-in: Enter moves on and submits. 出生地: Enter picks the first match, Esc clears then steps back. 设置 → 键盘快捷键.
- Ctrl+Tab: browsers keep it (Chrome never passes it to a page), so the app leaves it alone and uses ←/→ for switching options; written into the shortcut list.
- Fixed on the way: a chart or tarot draw finishing after the page was left opened on top of 首页 / called setState on a closed page (`mounted` checks).
- Tests: keyboard_shell_test (7, no fixtures), keyboard_test (13, every area, plus a source rule banning a bare GestureDetector in screens); helpers in test/keys.dart. Focus look checked on rendered images in light and dark.
- Mistakes: Esc swallowed by a focused text field (rule 18); a key right after enterText met the old page (rule 19); a closed DropdownMenu keeps its entries in the tree (rule 20); `flutter test --platform chrome` never loads on this machine (rule 21; meant for the global list, which this session could not write: access denied).
- Owner requests during the work: README gets a detailed 更新记录 entry per update, and every update ends with the harness; both written into the new keyboard-access skill (.claude/skills) and CLAUDE.md. Released as v1.0.0 (package.json 1.0.0; app 1.0.0+1), tag v1.0.0.

## 2026-10-27 (b): cleaner top bar; mock or real AI switch

- Owner request: 个人资料 and 语言 straight on the bar, 设置 as its own icon instead of ⋮. Home bar now: 历史记录 · 个人资料 · 语言 (translate icon + 简/繁/EN, one-tap menu) · 设置 (gear). The gear opens the 设置 page (the old 账号 page renamed: account details, 内容审核 for reviewers, sign-out, deletion). The sign-in bar has 语言 too. The four buttons fit a 360-wide phone in all three languages (test).
- Owner request: save tokens by showing mock answers until the owner flips a toggle. The owner's `.env` switches now decide: `IS_AI_MOCK=TRUE` (or `IS_AI_MODEL=FALSE`) puts every AI step on the mock (（示范） text, instant); otherwise the real model runs when its key is set. The API re-reads `.env` when it changes (no restart, so the public URL stays), prints `AI switched: …`, and /v1/health shows `ai`. Daily AI caps don't count while the mock answers; `eval:ai --live` refuses while the switch says mock; under the test suite no real provider is built.
- Verified: the real start script with a throwaway `.env` (fake key, health only) flipped mock → deepseek → mock; with the owner's `.env`, a 八字 reading passed in about 0.1 s with （示范） text.
- Mistakes: the verify script guessed the report id field (rule 16); the switch notified its listener before storing the new mode, caught in review, now tested (rule 17).

## 2026-10-27 (a): 为谁排盘 fixes, 一生运势 inside 八字排盘

- Bugs (owner): the picked person's name was not editable; the picker looked like an input; no way to add or edit a person from the form.
- Fix: read-only picker with 添加新的测试者 and 编辑“X”的资料 entries that open a pop-up editor (ProfileDialog, same fields as the profile page); saving stores the person and loads them into the form; cancel keeps the current person. The form has its own editable 姓名 field.
- Improve (owner request, 「把一生运势放到八字排盘内，作为同另一个选项」): 一生运势报告 is a mode of 八字排盘 (排盘解读 / 一生运势报告 switch); the separate home card is gone.
- Bug (owner): 出生地 was in no report. The chart only gets timezone + longitude (privacy), and nothing carried the name. Now: the birthplace label goes with the reading context (UserContext.birthplace), shows first in the facts card and in the 一生运势报告 header, and is kept per chart on the device (ProfileBook.chartPlaces) for reports reopened from history.

## 2026-10-26 (n): review console, then review paused; disclaimer wording

- Asked what "团队审核" is: readings the rule layer / guard held (manual_review, blocked). There was no review tool and held text was discarded.
- Built 内容审核: held content is kept (held_layers / held_content), reviewers (MINGLI_ADMINS) list items with reasons, rule hits and the guard's quoted findings, and approve (manual_review only) or reject with a recorded decision; app page for reviewers.
- Owner decision right after: pause all content review until the legal & obligations work. `review: false` (default in npm run api / public; MINGLI_REVIEW=on re-enables): no guard call, rule hits recorded but never rewrite or hold, the console closed (role stays user, endpoints 404), /v1/health shows content_review: paused. Tests run with review on; review-paused.test.ts covers paused mode.
- Disclaimer wording (owner): 「文化参考与自我反思」 → 「仅供娱乐和玄学学习使用」 in the app copy, the expectation footer, the AI label (ai_disclosure_spec.md), the 一生运势报告 note and the 破除运势 closing; the new wording is an allow-case in compliance-cases.yaml.

## 2026-10-26 (m): 一生运势报告

- Owner request: a whole-life report section, downloadable as a package, modelled on the owner's sample (吴勇, 1987-11-23 03:30, 江苏靖江).
- Engine (src/engines/yijing): 本命卦 by 先天数 (年支 + 农历月 + 农历日 → 上卦, + 时支 → 下卦, mod 6 → 命爻), 之卦, 互卦, 六爻配年 (15-year stages); 梅花 体/用/互/变 with 五行 relations and 旺相休囚死; 八宅 命卦 from the 干支 year and gender, directions by the 大游年 line flips. Golden test = the owner's sample (all values match), plus hand-checked 噬嗑/颐/蹇 and an independent 坎命 table.
- Texts: data/yijing/hexagrams.json from @freizl/yijing 2.1.0 (MIT) zh-TW; 简体 by OpenCC with 乾 shielded (OpenCC writes 干); errata 不災畬 → 不菑畬.
- AI: life_methods@1 and life_topics@1 run in parallel, then guard@2; same plain-language, context and date rules, plus life-report safety (no lifespan or relatives' illness, no property/investment advice, neutral partners). API /v1/life-reports.
- App: home entry + chart-page button; report page with hexagram figures (命爻 in red), 梅花 table, 五行 bars, 八宅 compass, stage chart, six sections; download = ZIP (styled printable HTML + Markdown), print/PDF, copy. 起卦 lines match the sample text exactly (test).
- Places: 靖江 was missing (cities15000 skips unpopulated seats). Added every 省/地级/县级 seat for CN/TW/HK/MO/MY/SG from the full dumps, names borrowed from the division (靖江市); Chinese-name gaps in CN 873 → 415.

## 2026-10-26 (l): 简体中文 as the main language, Mainland usage

- Owner decision: the main language is 简体中文 with Mainland grammar and vocabulary.
- App: starts in 简体 (SettingsNotifier default), 简体中文 first in the language menu, page title 命理大师, html lang zh-CN; test profiles 测试用户 / 管理员 / 测试家人; dev accounts default to zh-Hans.
- 简体 copy reviewed for HK/TW wording left by script conversion: 账号, 邮箱, 注销账号, 添加/创建资料, 点击, 支付, 演示, “” quotes, 根据…和…, 跳槽, 无法连接服务器, 当地时间. A test fails if 「」 or those HK/TW forms come back.
- AI: zh-Hans output must use Mainland vocabulary, grammar and “” punctuation (user-message language line).
- Not changed: the Geo-Rule matrix still has CN service_available=false; serving mainland users is a legal decision (licensing / AI service filing), not a language one.

## 2026-10-26 (k): life context, plain language, preloaded 破除運勢

- Owner feedback: readings felt generic (same chart for everyone born at the same time and place) and hard to read; plans should open faster.
- Life context: optional name use, current residence, marital status, children, occupation, family situation and question, stored with the profile on the device and sent as `context` with a report request (never with the chart). The model sees it in <user_context> as information, not instructions; chart facts still decide every chart claim. Trend scores stay chart-only.
- Plain language: narrative@4, action@3, trend@2, remedy@2 share a 大白話 rule (short sentences, conclusion first, every 命理 term explained in brackets, everyday examples) plus a one-sentence plain `summary` per topic, shown even when the topic is collapsed.
- Preload: after a report passes, every topic's plan is generated (two at a time) and kept locked; buying only unlocks it, so it opens at once. Background preloads count against the daily total AI cap only.
- Live checks (DeepSeek, 徐梅 profile with context): first run said 明年 = 丙午 (it is 2027 丁未) and named the user in the third person; two of three preloaded plans were held as fabricated_fact. Fixes: every prompt gets <today> (date + 去年/今年/明年 干支), names only as direct address, guard@2 also sees <user_context>, <trend> and <today>, and checkFaithfulness flags 今年/明年/去年 + wrong 干支. Rerun: years right, all three plans passed, buying opened in 11 ms.
- A held preloaded plan is never sold: buying regenerates it. Held reports/plans log their rule ids and guard categories (no quotes).
- Places: America/Coyhaique (tzdb 2025b) is unknown to Node's 2024b tzdb; build:places maps such split zones to their parent and fails on any unknown zone. Found by widening the places test to every city.

## 2026-10-26 (j): phone browsers can sign in

- Cause: the web app called http://127.0.0.1:8787, which on a phone is the phone; the API listened on loopback only; dev CORS allowed only localhost.
- Fix: app resolveApiBase (?api= > API_BASE_URL > same host :8787 for http pages > emulator > loopback); `npm run api:lan` (all interfaces, private-network CORS, X-Dev-User shortcut off); sign-in names the unreachable address and how to fix it; Pages build no longer hard-codes 127.0.0.1.
- DeepSeek key: stays in .env on the machine running the API; never in GitHub or the Pages build (docs/web-test.md).

## 2026-10-26 (i): birthplace picker (國家和地區 → 省／州 → 城市)

- Owner request: birthplace by country/region, then province, then city.
- `npm run build:places` builds data/places from GeoNames cities15000 (CC BY 4.0): 244 countries, 31 780 places, each with IANA timezone and longitude. Country names from Node ICU; Chinese province/city names from GeoNames for 20 main countries, 繁↔简 by OpenCC so both scripts agree; Taiwan grouped by 直轄市/縣市 (admin2); HK/MO short names.
- API: public `GET /v1/places` and `GET /v1/places/{country}` (cacheable). App: PlaceField + PlacePickerPage (search at every step, common countries first, one-region countries skip the region step); profiles store the picked place; older profiles fall back to their city key.

## 2026-10-26 (h): report UI, trend scores, 破除運勢, web test

- CI fix: the app fixture embedded the runner's Node tzdb (2026c vs 2024b local), which changed input_digest. `BaziContext.tzdb` pins it for fixtures.
- Trend agent (trend@1, 八字 only) runs in parallel with the narrative: per-topic 0–100 scores for every 大運 and 流年 with a one-line reason. Periods come from the ChartFact; combined and total are computed by the server. A trend failure drops the chart, never the report.
- Prompts: narrative@3 (2–4 longer, concrete paragraphs naming periods), action@2 (2–3 detailed actions per topic).
- 破除運勢: remedy@1 → Guard, one paid plan per (report, topic) naming its target periods; `/v1/reports/{id}/remedies`, `/v1/remedies/{id}`. Payment is a placeholder (TODO Phase 4); buying twice returns the same plan.
- App: trend chart (by age / by year, topic filters to compare, tap for scores and reason, total), only the first topic open with expand/collapse all, left-aligned text, remedy module + pay popup + plan dialog with save/send/print/copy.
- Web: no-cache index.html + cache-busting bootstrap; GitHub Pages workflow (docs/web-test.md); API allows the Pages origin and answers Private Network Access preflights.
- Dev account xumei/xumei with its own editable profile.
- Compliance note: selling remedies sits next to the fear_or_paywall rule. The plan text is Guard-checked and the sales copy makes no harm claims, but legal review must confirm the paid model per region before real charging.
- Mistakes: shell-inlined scripts mangled backslashes and `$'` (global rule 16); web-only interop code only fails in `flutter build web` (rule 6); theme full-width buttons in rows (rule 7).

## 2026-10-26 (g): 八字 / 塔羅 technical verification

- Plan change (owner): payments, subscriptions and push moved to Phase 4 (operations); focus on the app and on 八字 / 塔羅 verification.
- 八字: independent oracle (Swiss Ephemeris + JDN + 五虎遁/五鼠遁) vs the engine on 7000 births: 0 errors, 1 boundary case within formula precision. Mutation tests prove the comparison detects real faults.
- 塔羅: 32-check statistical battery on 100k draws per spread: all pass. Bias-injection tests prove it detects faults.
- AI: `checkFaithfulness` (干支, year 干支, cards, 正逆位, script) plus `eval:ai`; live DeepSeek run 6/6 passed, 0 issues; the 時辰 precision is stated in the facts layer and in the AI text.
- verify:bazi and verify:tarot added to the harness and CI. Details: docs/verification/README.md.
- Mistake: the tarot test assumed independence for sampling without replacement (MISTAKES rule 5).

## 2026-10-26 (f): 農曆 date input, 時辰 time input, admin test account

- Date: 公曆 / 農曆 switch; 農曆 year → month (incl. 閏月, only months that exist) → day, converted on the server (`GET /v1/calendar/lunar-months`, `GET /v1/calendar/solar`).
- Time: 精確時間 / 時辰 switch; 13 chips with the day's 干支 (早子 00:00–00:59, 丑 … 亥, 晚子 23:00–23:59, from `GET /v1/calendar/lunar` → `shichen`); a pick sets the 時辰 midpoint.
- To the AI: `facts.input_basis` {date, time, shichen, shichen_after_correction}; facts-layer lines; prompt `narrative@2` tells the model the hour is a two-hour window and to mention a 真太陽時 shift.
- Dev accounts seeded on each dev-mode API start: `admin` / `admin` (bypasses sign-up rules; refused outside dev mode) and `test@mingli.local`. In the app, admin gets 管理員 (台北, 辰時) and 測試家人 (農曆 1960 正月初一, 午時).
- Harness: PASS (backend 161 tests; app analyze 0 issues, 21 tests, build web).

## 2026-10-26 (e): profiles, 農曆, live AI progress, history, export, UI redesign

- Requested by the product owner after the first local test.
- Profiles: stored encrypted **on the device only** (names never sent to the server); a default "我" plus profiles for others; 「為誰排盤」 picker with this-run-only edits; test accounts (`test…`) get an editable 測試用戶 default; charts are labelled with the person's name locally.
- 農曆: engine adds `facts.lunar` (年干支, 生肖, 月 incl. 閏月, 日); `GET /v1/calendar/lunar` for live preview in date pickers; facts layer line; 春節 vs 立春 note when years differ. 生肖, 閏, 臘, 時 added to the protected-term table.
- AI progress: pipeline `onProgress`; pending reports expose `progress.stage`; the app shows the real stage (解讀 → 行動建議 → 合規審查), elapsed time, a pulse animation and a "rewriting" note on retries.
- History: `GET /v1/reports`, `GET /v1/charts`, `GET /v1/charts/{id}`; app history page plus 最近紀錄 on home.
- Export: Markdown download (share sheet on mobile, file download on web) and copy-all; the AI label and disclaimer are always included.
- UI: design tokens (spacing, radii), AppCard/HeroBanner/Pill, page zoom transitions, staggered fade-ins, animated bars and card flips, collapsible report topics, drop-down menus (「更多」, profile picker, city, spread).
- Mistakes: zero-interval poller hang in a widget test; killed flutter test left gen-l10n output deleted (global rules 14–15).
- Harness: PASS (backend 153 tests; app analyze 0 issues, 18 tests, build web).

## 2026-10-26 (d): Phase 0 gate passed provisionally

- Decision (product owner): defer the 50 authoritative 八字 golden cases; pass the legal review provisionally.
- Done: added `legal_review: provisional` (schema, type, demo label) and set it for every region; listed both deferred items in `docs/phase-0-gate.md` with what closes them. Neither is marked as done.
- Harness: PASS (backend 147 tests; app analyze 0 issues, 13 tests, build web).

## 2026-10-26 (c): Phase 1 segment 3, sign-in and account deletion

- Done: `src/auth/`: Argon2id passwords (OWASP params); 15-min HS256 access tokens; rotating refresh tokens with reuse → family revocation; Apple/Google ID-token verification (jose JWKS); captcha after 3 failures (Turnstile proposed), lock after 10; Geo-Rule and age gate at sign-up; keyed email lookup.
- Done: v1 API `/v1/auth/{register,login,oauth,refresh,logout}`, `GET /v1/me`, `DELETE /v1/account` (deletes account, charts, reports and sessions immediately; a report still generating can't write back). Region now comes from the account.
- Done: App sign-in/registration (age confirmation, region at sign-up), tokens in secure storage, single-flight refresh on 401, account page with sign-out and delete. The dev region picker is removed.
- Mistakes: formatter ran in the wrong cwd; PGlite timeout under parallel load (MISTAKES rule 4, global rule 13).
- Harness: PASS (backend 147 tests; app analyze 0 issues, 13 tests, build web).
- Next: Apple/Google buttons in the app need the platform SDKs and client ids; PostgreSQL store; payments (segment 4).

## 2026-10-26 (b): Phase 1 segment 2, v1 API and Flutter app

- Done: chart service and runtime wiring extracted from the demo (`src/service/`) and HTTP helpers (`src/http/`); v1 API with async reports (202 → poll), Idempotency-Key, owner scoping, 451/400/422, `failed` vs compliance holds, dev CORS.
- Done: Flutter app (Riverpod, zh-Hant/zh-Hans/en): 八字 form → 四柱/五行/大運/流年 → AI reading; tarot draw → flip → reading; four-layer report with a fixed AI-label footer; polling.
- Done: `npm run sync:app` copies terms, deck/positions and topics (as generated Dart) plus real engine fixtures into the app; a drift test fails when they're stale. Added all 30 納音 to the protected-term table.
- Mistakes: heredoc again (global rule 1 widened); Dart analysis server crash on the CJK path (harness now uses an ASCII junction); lazy-list and rootBundle traps in widget tests; 流年 cell overflow.
- Harness: PASS. Live smoke test against the API process passed.

## 2026-10-26 (a): Phase 1 segment 1, AI pipeline on DeepSeek

- Done: Narrative → Action → Guard pipeline with structured JSON, grounding (every paragraph cites ChartFact paths), protected-term fixing, rule-layer retry, model review; DeepSeek `deepseek-v4-pro` provider (JSON mode, retries); Claude and mock providers kept.
- Done: six topics (五行, 性格, 事业财运, 婚姻感情, 大运流年, 健康); engine adds 日主, 月令, weighted 五行, 10 years of 流年 with 十神 and 六冲/六合; rules G006 (disease prediction), G007 (investment advice), E002.
- Live: first real report passed on the first attempt, every chart claim checked by hand; 260 s, about USD 0.01.
- Mistakes: curl with Chinese text in Git Bash (global rule 10).

## 2026-10-25: Phase 0, engines, contract, compliance base

- Done: BaziEngine (tzdb + historical DST, true solar time, 节气 by instant), TarotEngine (HMAC-DRBG, audit replay), astrology POC; ChartFact v0.1 schema; keyed input digest; compliance rule set and geo matrix; OpenAPI and PostgreSQL v0; CI; demo UI and CLI.
- Findings: `@gitstrology/engine` fails accuracy (Moon off by up to 8°) → `astronomy-engine` (≤0.005°); Swiss Ephemeris is AGPL; draft regexes blocked our own disclaimers and missed zh-Hant.
- Created the skills in `C:\Users\AgentSkills` (harness-check, mistake-memory, reuse-first).
- Harness: PASS.
