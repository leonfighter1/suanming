# Phase 0 Gate status (2026-10-25)

## Deliverables

| #   | Deliverable                                                                 | Where                                                    | State                                                                                                               |
| --- | --------------------------------------------------------------------------- | -------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| 1   | Engine POC report + ADR                                                     | `docs/poc/README.md`, `docs/adr/0001–0003`               | done; ADRs **Proposed**                                                                                             |
| 2   | ChartFact v0.1 + JSON Schema                                                | `schemas/chart-fact.v0.1.schema.json`, `src/chart-fact/` | done; **needs reconciling with 《总体技术文档》§1.3**, which wasn't available                                       |
| 3   | `prohibited_patterns.yaml`, `geo_rule_matrix.json`, `ai_disclosure_spec.md` | `compliance/`                                            | done; all `legal_review: pending`                                                                                   |
| 4   | OpenAPI 3.1 skeleton + PostgreSQL schema v0                                 | `api/openapi.yaml`, `db/schema_v0.sql`                   | done; lint clean; schema applied in PGlite in tests                                                                 |
| 5   | CI/CD + three environments                                                  | `.github/workflows/ci.yml`                               | CI written but **never run** (no GitHub remote). **Deploy and environments not started**: cloud provider not chosen |
| 6   | Security baseline + data retention                                          | `docs/security-baseline.md`, `docs/data-retention.md`    | draft                                                                                                               |

## Gate checklist

- [ ] **Three engine POCs passed, or downgrade decision in an ADR**
  - [x] Tarot: chi-square α=0.01 over 1,000 draws on all positions; reversal rate; reproducible replay
  - [x] Astrology: `@gitstrology/engine` **fails** (Moon up to 8.1°); `astronomy-engine` **passes** (≤0.005°). ADR-0001 proposes the switch; needs sign-off
  - [ ] Bazi: engine, time policy (ADR-0002) and 节气 precision (≤1.6 min, 1900–2100) done; **0/50 golden cases**. These need an authoritative 排盘 tool and a named checker (`npm run poc:bazi-golden`)
- [ ] ChartFact schema signed off by backend, client and 算法
- [ ] Compliance rules confirmed by legal (US/GB/AU/CA minimum)
- [ ] CI/CD build + deploy + tests green once on staging

## Local harness (2026-10-25)

`HARNESS: PASS`: lint, typecheck, 70 tests, OpenAPI lint, schema validation,
`npm audit` with 0 vulnerabilities.

## Issues found in the plan documents

1. The sample compliance regexes block the product's own disclaimers ("No
   outcome is guaranteed", 「不付费也会看到基础解读」) and miss zh-Hant
   (「不轉運就會…」). Both are fixed in `prohibited_patterns.yaml` and pinned by
   test cases.
2. "Digest stored instead of birth data" is reversible with plain SHA-256,
   so the digest is now keyed (HMAC). The bazi ChartFact itself also reveals
   birth time and is treated as PII.
3. Phase 0's reproducible tarot audit and Phase 1's "don't store the seed"
   conflict. ADR-0003 resolves this with a key-derived seed.
4. Feeding local time to lunar-javascript breaks 节气 boundaries outside
   UTC+8. ADR-0002 fixes the time basis.
5. Swiss Ephemeris and `pyswisseph` are AGPL, which affects the Phase 3
   microservice plan (ADR-0001).
6. Not storing raw birth data means the server can't recompute charts
   (`docs/data-retention.md`). Product decision needed.
