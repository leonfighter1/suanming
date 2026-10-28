# Dev log: 命理大师

Newest first. One entry per working session, key points only.

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
- Improve: 一生运势报告 is a mode of 八字排盘 (排盘解读 / 一生运势报告 switch); the separate home card is gone.
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
