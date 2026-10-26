# Phase 1 status (2026-10-26)

| Segment                                                        | State                                                                                                                                         | Where                                                 |
| -------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------- |
| 1. AI Interp pipeline (Narrative → Action → Guard)             | done, live on DeepSeek `deepseek-v4-pro`                                                                                                      | `src/ai/`, [phase-1-ai.md](phase-1-ai.md)             |
| 2a. v1 API (charts, async reports, health)                     | done, dev-mode identity                                                                                                                       | `src/api/`, `api/openapi.yaml`                        |
| 2b. Flutter App skeleton                                       | done: 八字 (form → 四柱/五行/大運/流年 → AI reading), 塔羅 (draw → flip → AI reading), four-layer report with fixed AI-label footer, 繁/简/EN | `app/`                                                |
| 3. Auth (email+password, Apple, Google) + `DELETE /v1/account` | done: backend complete; App has email sign-in, account page and deletion. Apple/Google buttons wait on platform SDKs and client ids           | `src/auth/`, `app/lib/presentation/sign_in_page.dart` |
| 4. Payments (RevenueCat + Stripe Checkout, single purchase)    | not started                                                                                                                                   | —                                                     |
| 5. OneSignal (transactional push: report ready)                | not started                                                                                                                                   | —                                                     |
| 6. Website (Next.js, 7 pages)                                  | not started                                                                                                                                   | —                                                     |
| 7. Store review materials (App Store 4.3(b))                   | not started                                                                                                                                   | —                                                     |

## Verification (2026-10-26)

`HARNESS: PASS` from `.harness.json`:

- backend: lint, typecheck, 147 tests, OpenAPI, schemas, `npm audit` (0)
- app: `flutter pub get`, `flutter analyze` (no issues), 13 tests, `flutter build web`

End-to-end smoke test against the running API server: health, CORS preflight,
chart 201, report 202 → poll → passed with `x-ai-generated`, CN → 451.

## How to run

```
npm run api                     # v1 API on :8787 (reads .env; DeepSeek if DEEPSEEK_API_KEY is set)
cd app && flutter run -d chrome # or -d windows / an Android emulator (uses 10.0.2.2:8787)
npm run sync:app                # after changing terms, deck, topics or the report shape
```

On this machine Flutter tooling must run from an ASCII path (the Dart analysis
server crashes on `C:\命理大师`). The harness handles this automatically; for
manual runs use a junction, e.g. `mklink /J C:\mingli C:\命理大师`.

## Known gaps

- Dev headers (`X-Dev-User`, `X-Dev-Country`) still work in dev mode without a bearer token, for local tools.
- Store is in-memory; the PostgreSQL store (encrypted facts and reports) comes with auth.
- No rate limiting yet.
- Node's bundled tzdb is 2024b; pin a newer Node or ICU before launch.
- Report generation takes about 4 minutes on v4-pro at high effort; push
  notification (segment 5) is how users learn it's ready.
