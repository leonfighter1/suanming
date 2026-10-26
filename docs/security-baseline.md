# 安全基线 v0.1

| Area         | Baseline                                                                                                                                                                         | Status                                  |
| ------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------- |
| Secrets      | AWS Secrets Manager (or equivalent). Nothing in the repo, code, CI logs or env files. `.gitignore` blocks `.env*`, `*.pem`, `*.key`.                                             | infra not chosen                        |
| Keys in use  | `digest_pepper` (≥32 B, HMAC for `input_digest`), `tarot_draw_key` (≥32 B, ADR-0003), KMS KEK for per-user DEKs. All versioned; retired versions kept for replay/decrypt.        | defined                                 |
| At rest      | AES-256-GCM application-level envelope encryption for ChartFact facts, report bodies and email (`db/schema_v0.sql`). Disk/RDS encryption on top.                                 | schema done                             |
| In transit   | TLS 1.3 at the edge. Internal engine ↔ API over mTLS or private network.                                                                                                         | infra                                   |
| Passwords    | Argon2id (Phase 1), login rate limiting, captcha after N failures.                                                                                                               | Phase 1                                 |
| Logs         | Structured JSON. Never log raw birth data, ChartFact facts, report text or email. Birth year as a 10-year bucket (`198x`) at most. Compliance violations logged by rule id only. | to implement in logger                  |
| Dependencies | `npm audit --audit-level=high` in CI and the harness, **0 high/critical** today. Versions pinned for engines (`lunar-javascript`, `astronomy-engine`).                           | done                                    |
| Licences     | No AGPL in production. Swiss Ephemeris is dev-only (ADR-0001).                                                                                                                   | done                                    |
| CI           | PR must pass lint, typecheck, tests, schema validation, OpenAPI lint and audit (`.github/workflows/ci.yml`).                                                                     | workflow written, not yet run on GitHub |

## Why `input_digest` is keyed

Birth data is low-entropy: about 36,500 dates × 1,440 minutes × a few hundred
cities ≈ 10¹⁰ inputs. A plain SHA-256 of it can be reversed offline in hours,
so "raw birth data not stored, digest stored" protects nothing unless the
digest is an HMAC with a secret pepper.

## ChartFact is PII

A bazi ChartFact (four pillars plus the 大运 start date) pins the birth time to
within about 2 hours. Encrypt it and delete it with the user, the same as
raw birth data.
