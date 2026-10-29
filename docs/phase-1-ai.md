# Phase 1 · AI 解讀管線（第一段）

Since v9.2.0 (2026-10-29, the owner's choice) every agent routes to **Claude Opus 5.5** (`claude-opus-5-5`);
DeepSeek stays selectable with `ACTIVE_AI_MODEL` (docs/web-test.md). The notes below are from the DeepSeek runs.

Status 2026-10-26: **running live on DeepSeek `deepseek-v4-pro`** (all three agents).
First live report (八字, zh-Hant, HK, six topics): `passed` on the first attempt
for every agent, no rule hits, every chart claim checked by hand against
ChartFact. **260 s end to end**, about 12k input and 22.5k output tokens (mostly
thinking), roughly USD 0.01.

## Flow

```
ChartFact (engine, deterministic)
  → Geo-Rule (resolveRegion; 451 before any model call)
  → Narrative agent   ─┐  each: structured JSON → schema check → grounding check
  → Action agent       ─┤        → protected-term fix → rule layer; ≤1 retry with feedback
  → Guard agent (model review of the whole draft)
  → Report: facts (engine) · interpretation (AI) · actions (AI) · expectation (fixed copy + AI label)
```

| Outcome         | When                                                                                                    | User sees                      |
| --------------- | ------------------------------------------------------------------------------------------------------- | ------------------------------ |
| `passed`        | rule layer clean, model review passes                                                                   | four layers                    |
| `blocked`       | a `block` rule still matches after the retry                                                            | nothing (status only)          |
| `manual_review` | `review` rule hit (e.g. G007 investment advice), model review fails, refusal, or no grounded paragraphs | nothing until a human approves |

## Topics

`wuxing` 五行 · `personality` 性格 · `career_wealth` 事业财运 · `relationships` 婚姻感情 ·
`dayun_liunian` 大运流年 · `health` 健康. The first and fifth are bazi-only.

New engine facts to support them (ChartFact v0.1, additive): `day_master`,
`month_command`, `wuxing_weighted` (stems 1; hidden stems 0.6/0.3/0.1, labelled
`simplified_rule`), `liunian` (10 years: 干支, 十神 for stem and branch, current
大运, 六冲/六合 with natal branches). Values in tests were derived by hand.

Topic guardrails are in the narrative prompt **and** enforced by rules:

- health: no disease names or diagnosis; the section must end with a see-a-doctor
  note. Rules G005 (cure claims), **G006** (disease prediction), E002 (English).
- career/wealth: no investment advice or promised income. **G003** now covers
  一定发财; **G007** (买入/加仓…) sends the report to manual review.
- relationships: no divorce/breakup prediction (G003).

## Model

Routing (`config/model_routing.json`): all three agents use **`deepseek-v4-pro`**
through `DeepSeekProvider` (OpenAI-compatible Chat Completions, JSON mode,
`reasoning_effort` low/high/max, retries on 429/5xx). DeepSeek's JSON mode checks
syntax only, so the schema goes at the end of the user message and the pipeline
validates and retries. The key lives in the git-ignored `.env` as `DEEPSEEK_API_KEY`.
`AnthropicProvider` (Claude, structured outputs, server-side refusal fallback)
is kept and can be selected per agent in the routing file. Since v9.2.0 it serves every
agent, streamed, with the usable models listed in `src/ai/models.ts`.

## Data sent to the model

`time_basis` (exact birth time and place offset) and the tarot audit block are
**removed** before the model sees the facts (`modelFacts`). The model still sees
the pillars, 大运 start date and 流年 ages, which imply the birth year and month.

## Not done in this segment

- Real-API run and prompt tuning: an eval set with 200 outputs (the Phase 1
  gate) is needed before launch.
- Embedding-similarity layer of the Guard (Phase 1 §2.2): the rule layer is regex only.
- Prompts and routing still live in files. The DB tables exist
  (`db/migrations/001_phase1_ai.sql`) but nothing reads them yet.
- Flutter app, auth, RevenueCat/Stripe, OneSignal, website, store materials.
