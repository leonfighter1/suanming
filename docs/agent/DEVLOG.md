# Dev log: 命理大师

Newest first. One entry per working session, key points only.

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
