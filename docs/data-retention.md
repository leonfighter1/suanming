# 数据保留与删除策略 v0.1

Status: draft. Retention periods are proposals pending legal review
(PDPO / PDPA SG / PDPA MY / Taiwan PDPA; Phase 2: PIPEDA, Québec Law 25,
CCPA, UK GDPR, EU GDPR).

| Data                                                                                              | Stored?                                                                                                          | Form                                                                                                | Retention (proposed)                                                                                                                 |
| ------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| Raw birth date/time/place                                                                         | **No.** Used in memory to compute, then discarded.                                                               | –                                                                                                   | –                                                                                                                                    |
| `input_digest`                                                                                    | yes                                                                                                              | HMAC-SHA256 with pepper                                                                             | with the ChartFact                                                                                                                   |
| ChartFact facts                                                                                   | yes                                                                                                              | encrypted with the user DEK (it reveals birth time to about 2 h, so it is PII)                      | until account deletion                                                                                                               |
| Reports (four layers)                                                                             | yes                                                                                                              | encrypted                                                                                           | 24 months, then deleted (Phase 4: cold archive at 12 months, still encrypted)                                                        |
| Tarot audit (draw_id, digest, cards)                                                              | yes                                                                                                              | plaintext; no PII for anonymous draws                                                               | 24 months                                                                                                                            |
| Life context (name if allowed, residence, marital status, children, occupation, family, question) | on the device with the profile; on the server with the report it was sent for (for that report's 破除運勢 plans) | sent to the AI provider inside the prompt, marked as user information; never written into ChartFact | until account deletion (server copy: with the report, sealed under the user DEK in the database store, v4.1.0; in memory without it) |
| Email                                                                                             | yes                                                                                                              | encrypted, plus an HMAC lookup column                                                               | until account deletion                                                                                                               |
| Logs                                                                                              | yes                                                                                                              | no PII by rule (security-baseline.md)                                                               | 30 days hot, 1 year cold                                                                                                             |
| Deletion evidence                                                                                 | yes                                                                                                              | no PII (`subject_hash`, counts)                                                                     | 5 years                                                                                                                              |

## Personal profiles (decided 2026-10-26)

Names and saved birth details ("profiles") live **only on the device**, encrypted
(Keychain/Keystore via flutter_secure_storage), keyed by account and deleted with
the account. The server receives birth fields only inside a single chart request
and never receives names. History labels (chart → person name) are device-only too.

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

As built (v4.1.0, `src/db/pg-store.ts`, `MINGLI_STORE=pglite`): steps 1, 3, 4 and 6. Step 2's tokens
are revoked by the auth service, and step 5 waits for Phase 3. `deleteOwnerData` opens the request
(`in_progress`, with the counts), and deleting the user row completes it. The user's DEK goes with
that row (`dek_shredded: true`). The KEK that wraps each DEK is `MINGLI_DATA_KEY` here and a KMS in
production. `test/pg-store.test.ts` checks that a deletion leaves only its record, without personal
data.

Backups: the DEK shred covers encrypted columns. Backup retention must not
exceed the 30-day log policy, or a restore procedure must re-apply pending
deletions.
