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
| 求籤 draw (draw_id, digest, the rounds, the lot; v4.3.0)                                          | yes                                                                                                              | no PII: the question goes with the report, as a tarot question does, and never on a share image     | 24 months                                                                                                                            |
| 风水 room (room, facing, principle ids; v4.4.0)                                                   | yes                                                                                                              | no PII: no address or floor plan; the room's description goes with the report, as a question does   | 24 months                                                                                                                            |
| 起名 names (surname, length, elements, the 八字 chart's digest, candidates; v4.5.0)               | yes                                                                                                              | the surname, as typed; no birth data: only the elements the names serve and the 八字 chart's digest | 24 months                                                                                                                            |
| 算卦 cast (mode, the cast time and zone, coins and lines, hexagrams; layout and draw id; v5.3.0)  | yes                                                                                                              | no PII: the time is of the toss, not a birth; the question goes with the report, as for tarot       | 24 months                                                                                                                            |
| The app language picked (v5.1.0)                                                                  | on the device only, in secure storage                                                                            | no PII: one of zh-Hans, zh-Hant, en; never sent to the server as a setting                          | until the app (or the browser's site data) is removed                                                                                |
| Whose birth chart it is: the person's name and birthplace label (v6.2.0)                          | yes, with the chart record (owner, 2026-10-28)                                                                   | sealed with the chart under the user DEK; never in ChartFact; never sent to the AI provider         | until account deletion (in memory without the database store)                                                                        |
| 追问: each question and its answer (v7.0.0)                                                       | yes, one record per question, beside the reading it asks about                                                   | sealed under the user DEK; the question goes to the AI provider inside the prompt, as user text     | until account deletion (in memory without the database store)                                                                        |
| A reading's own question, focus and life context (v7.0.0), and a 一生运势报告's context           | yes, with the report, for its 追问                                                                               | sealed with the report under the user DEK, as the context already was                               | with the report, until account deletion                                                                                              |
| Life context (name if allowed, residence, marital status, children, occupation, family, question) | on the device with the profile; on the server with the report it was sent for (for that report's 破除運勢 plans) | sent to the AI provider inside the prompt, marked as user information; never written into ChartFact | until account deletion (server copy: with the report, sealed under the user DEK in the database store, v4.1.0; in memory without it) |
| Email                                                                                             | yes                                                                                                              | encrypted, plus an HMAC lookup column                                                               | until account deletion                                                                                                               |
| Logs                                                                                              | yes                                                                                                              | no PII by rule (security-baseline.md)                                                               | 30 days hot, 1 year cold                                                                                                             |
| Deletion evidence                                                                                 | yes                                                                                                              | no PII (`subject_hash`, counts)                                                                     | 5 years                                                                                                                              |

## Personal profiles (decided 2026-10-26)

Names and saved birth details ("profiles") live **only on the device**, encrypted
(Keychain/Keystore via flutter_secure_storage), keyed by account and deleted with
the account. The server receives birth fields only inside a single chart request
and never receives names. History labels (chart → person name) are device-only too.

**Changed 2026-10-28 (owner, v6.2.0).** The owner reported as a bug that stored readings showed no name or
birthplace when signed in elsewhere. Browser storage belongs to one origin, and `npm run public` gives the app a new
one on every run. So a chart now carries its person, the name and the birthplace label the app shows, as
`person` in `POST /v1/charts`.

- The server keeps it on the chart record. In the database store it is sealed with the chart under the user DEK
  (`test/pg-store.test.ts` checks that neither appears in the clear).
- It is never written into ChartFact and never sent to the AI provider. Only a reading's own life context (name if
  allowed) reaches the model, as before.
- It is returned only to the owner: with the chart, in history and with 一生运势报告.
- It is deleted with the account.
- Saved profiles (the birth details kept for re-use) stay on the device, as before.
- Charts made before v6.2.0 keep their names only on the device that labelled them.

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
