# ADR-0003: 塔罗随机源与审计复现

- Status: **Proposed**
- Date: 2026-10-25
- Code: `src/engines/tarot/`

## Context

The two phase documents pull in opposite directions:

- Phase 0 §2.1: `seed + spread + timestamp` must reproduce a spread from the
  audit log.
- Phase 1 §2.1: use a cryptographic random source, and **don't store the
  seed**, only a digest.

## Decision

- `draw_id` = UUIDv4 from `crypto.randomUUID()`, which is the cryptographic
  randomness.
- `seed = HMAC-SHA256(draw_key, "tarot-seed/v1:" + draw_id)`. `draw_key` lives
  in the secrets manager.
- Cards come from an HMAC-SHA256 counter DRBG with partial Fisher–Yates and
  rejection sampling (no modulo bias). Each reversal is one 32-bit draw
  against `reversed_rate`.
- Stored per draw: `draw_id`, `drawn_at`, spread, `reversed_rate`, cards,
  `result_digest = sha256(canonical({draw_id, spread, cards}))`. **The seed is
  never stored.**
- Replay (`verifyDraw`): anyone holding `draw_key` re-derives the seed. A
  draw passes only if digest(replayed) == digest(stored cards) == stored
  digest.

This satisfies both documents: reproducible with key + id, and no seed at
rest.

## Consequences

- Rotating `draw_key` breaks replay of older draws. Keep retired keys,
  versioned, for the report retention period.
- Whoever holds `draw_key` could predict draws for a known `draw_id`, but ids
  are generated server-side at draw time, so this is an insider-only risk.
  Restrict the key to the engine service.
- Evidence: `test/tarot.test.ts`. Chi-square α=0.01 passes for all 3
  positions over 1,000 draws; reversal rate |z| < 3; tamper detection.
