# 数据保留与删除策略 v0.1

Status: draft. Retention periods are proposals pending legal review
(PDPO / PDPA SG / PDPA MY / Taiwan PDPA; Phase 2: PIPEDA, Québec Law 25,
CCPA, UK GDPR, EU GDPR).

| Data                                 | Stored?                                            | Form                                                                           | Retention (proposed)                                                          |
| ------------------------------------ | -------------------------------------------------- | ------------------------------------------------------------------------------ | ----------------------------------------------------------------------------- |
| Raw birth date/time/place            | **No.** Used in memory to compute, then discarded. | –                                                                              | –                                                                             |
| `input_digest`                       | yes                                                | HMAC-SHA256 with pepper                                                        | with the ChartFact                                                            |
| ChartFact facts                      | yes                                                | encrypted with the user DEK (it reveals birth time to about 2 h, so it is PII) | until account deletion                                                        |
| Reports (four layers)                | yes                                                | encrypted                                                                      | 24 months, then deleted (Phase 4: cold archive at 12 months, still encrypted) |
| Tarot audit (draw_id, digest, cards) | yes                                                | plaintext; no PII for anonymous draws                                          | 24 months                                                                     |
| Email                                | yes                                                | encrypted, plus an HMAC lookup column                                          | until account deletion                                                        |
| Logs                                 | yes                                                | no PII by rule (security-baseline.md)                                          | 30 days hot, 1 year cold                                                      |
| Deletion evidence                    | yes                                                | no PII (`subject_hash`, counts)                                                | 5 years                                                                       |

## Product consequence

Because raw birth data isn't stored, the app cannot "re-run" a chart with a
new engine version on the server. Either the client keeps the birth data
locally (encrypted device storage) and resubmits it, or the user re-enters
it. **Decision needed from product before Phase 1 UI.**

## Deletion flow (`DELETE /v1/account`, Phase 1)

1. Insert a `deletion_requests` row (`due_at` = now + 24 h, per the Phase 1
   E2E requirement).
2. Set `users.deleted_at` and revoke sessions and tokens.
3. **Crypto-shred** by destroying the user's DEK, which makes every encrypted
   ChartFact and report unreadable at once, including copies in backups.
4. Hard-delete the user's rows. The FK cascades cover `chart_facts` and
   `reports`, as tested in `test/db-schema.test.ts`.
5. External processors: RevenueCat/Stripe customer deletion API, OneSignal
   player deletion, and email list unsubscribe (Phase 3).
6. Write `evidence` (counts, `dek_shredded: true`, processor responses) and
   set `completed_at`.

Backups: the DEK shred covers encrypted columns. Backup retention must not
exceed the 30-day log policy, or a restore procedure must re-apply pending
deletions.
