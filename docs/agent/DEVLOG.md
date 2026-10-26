# Dev log: 命理大师

Newest first. One entry per working session, key points only.

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
