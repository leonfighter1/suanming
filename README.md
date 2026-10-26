# 命理大师

Phase 0 (engines, ChartFact, compliance) and Phase 1 in progress (AI pipeline, v1 API, Flutter app).
**Start here: [docs/SUMMARY.md](docs/SUMMARY.md)** (what each phase delivered).
Details: [docs/phase-0-gate.md](docs/phase-0-gate.md) · [docs/phase-1-status.md](docs/phase-1-status.md) · agent instructions in [CLAUDE.md](CLAUDE.md).
Web test: **https://leonfighter1.github.io/suanming/** ([docs/web-test.md](docs/web-test.md)).

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
