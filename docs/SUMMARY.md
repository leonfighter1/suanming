# Summary: what has been built

A one-page view of the completed work, by phase. Details are in the linked documents.

## Phase 0: technical foundation and compliance base ✅ (gate passed provisionally)

| Area        | Delivered                                                                                                                                                                                                                                  |
| ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 八字 engine | `lunar-javascript` + IANA tzdb (historical DST), true solar time (longitude + equation of time), 节气 compared by instant (correct overseas), 十神/十二长生/纳音, 大运, plus 日主, 月令, weighted 五行 and 10 years of 流年 with 六冲/六合 |
| 塔罗 engine | 78-card RWS deck, three spreads, HMAC-DRBG with no stored seed, audit replay (ADR-0003)                                                                                                                                                    |
| 占星 POC    | `astronomy-engine`, ≤0.005° against Swiss Ephemeris; `@gitstrology/engine` rejected (ADR-0001)                                                                                                                                             |
| Contract    | ChartFact v0.1 JSON Schema; keyed (HMAC) input digest; four frozen source levels                                                                                                                                                           |
| Compliance  | `prohibited_patterns.yaml` (zh-Hant + zh-Hans, negation-aware), `geo_rule_matrix.json`, AI disclosure spec                                                                                                                                 |
| Skeleton    | OpenAPI 3.1, PostgreSQL schema v0 + migration 001, CI, security baseline, data retention                                                                                                                                                   |

**Gate passed provisionally** by product-owner decision (2026-10-26). Deferred, and
required before the first public launch: 50 authoritative 八字 test cases, and the
formal legal review (`legal_review: provisional` for now). See [phase-0-gate.md](phase-0-gate.md).

## Phase 1: core loop for the 繁體 launch (in progress)

| Segment                               | State                                                                        | Delivered                                                                                                                                                                                                                                                                                       |
| ------------------------------------- | ---------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1. AI interpretation                  | ✅                                                                           | Narrative → Action → Guard; six topics (五行, 性格, 事业财运, 婚姻感情, 大运流年, 健康); grounding to ChartFact; protected terms; live on DeepSeek `deepseek-v4-pro` ([phase-1-ai.md](phase-1-ai.md))                                                                                           |
| 2. v1 API + Flutter App               | ✅                                                                           | Async reports (202 → poll); App with 八字, 塔羅 and the four-layer report with a fixed AI label; 繁/简/EN                                                                                                                                                                                       |
| 3. Sign-in + account deletion         | ✅ backend and email sign-in in the App · ⏳ Apple/Google buttons in the App | Argon2id, rotating refresh tokens, Apple/Google ID-token verification, captcha and lockout, Geo-Rule and age gate at sign-up, `DELETE /v1/account`                                                                                                                                              |
| 3b. Owner feedback round              | ✅                                                                           | Device-only personal profiles (默认 + 为他人), 农历对照 and 农历 date input, 时辰 (干支) time input passed to the AI, live AI stage + elapsed time, history, Markdown export/copy, UI redesign with transitions and drop-down menus                                                             |
| 4. Payments, subscriptions, push      | ↪ moved to Phase 4 (operations) by owner decision 2026-10-26                 | RevenueCat, Stripe, OneSignal                                                                                                                                                                                                                                                                   |
| 5. 八字 + 塔羅 technical verification | ✅                                                                           | 7000 births vs an independent oracle (0 errors), 32-check tarot battery on 100k draws, AI faithfulness 6/6 live ([verification/README.md](verification/README.md))                                                                                                                              |
| 5b. Report UI + 破除運勢 + web test   | ✅ (payment TODO)                                                            | Trend chart (大運/流年 scores 0–100 per topic, combined, total); first topic open + expand all; longer, concrete readings (narrative@3, action@2); paid per-topic 破除運勢 plans (remedy@1 → Guard) with save/send/print; no-cache web loading; GitHub Pages build ([web-test.md](web-test.md)) |
| 6. Website (Next.js)                  | ⏳                                                                           | —                                                                                                                                                                                                                                                                                               |
| 7. Store materials                    | ⏳                                                                           | —                                                                                                                                                                                                                                                                                               |

## Quality

- `HARNESS: PASS` on every gate in [`.harness.json`](../.harness.json): backend
  lint, typecheck, 161 tests, OpenAPI, schemas, `npm audit` (0); app analyze
  (0 issues), 21 tests, web build.
- Lessons are recorded as rules: [agent/MISTAKES.md](agent/MISTAKES.md) (project) and the global file of the mistake-memory skill.
- Work log: [agent/DEVLOG.md](agent/DEVLOG.md). Module registry: [../MODULES.md](../MODULES.md).

## Decisions waiting on the product owner

1. Report speed: 4 minutes at `high` effort. The proposal is `low` effort for the action and guard steps (about 2 minutes).
2. Captcha provider (Turnstile proposed).
3. Apple / Google developer accounts and client ids.
4. Whether the App keeps raw birth data on the device for re-computation ([data-retention.md](data-retention.md)).
5. The 子时 school default (`ziHourSect`) and the ADR sign-offs.
