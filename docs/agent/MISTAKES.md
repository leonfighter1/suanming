# Mistakes and lessons: 命理大师

## Rules (read before every task)

1. Audit verification must check the stored record itself, not only a fresh recomputation.
2. Exclude script-generated files from formatters and linters when the script that creates them is added.
3. Size fixed-height cells for the maximum number of lines they can show, and cap every line with maxLines + ellipsis.
4. Give tests with heavy runtime start-up (WASM, browsers) an explicit timeout instead of relying on the 5 s default.
5. Before treating a statistical test failure as a bug, check the test's null hypothesis matches how the process is supposed to behave.
6. After touching a web-only (js_interop) file, run flutter build web before calling it done; the harness app gate does this.
7. Buttons placed in a Row, Wrap or dialog action bar must use compactButtons() (or an explicit minimumSize); the app theme makes them full-width.
8. Never default a client to 127.0.0.1 for anything another device may open; derive the API host from where the page was served and test the phone path.

## Log

### 2026-10-26: Phone browser could not log in (127.0.0.1)
- **Symptom:** ClientException: Load failed uri=http://127.0.0.1:8787/v1/auth/login on a phone browser
- **Root cause:** The web app defaulted to http://127.0.0.1:8787, which on a phone is the phone itself; the API also listened on loopback only and dev CORS allowed only localhost
- **Fix:** resolveApiBase(): ?api= > dart-define > same host :8787 for http pages; npm run api:lan (0.0.0.0, private-network CORS, X-Dev-User off); ApiUnreachable shows the address and the fix
- **Rule:** Never default a client to 127.0.0.1 for anything another device may open; derive the API host from where the page was served and test the phone path. (Rule 8)

### 2026-10-26: Full-width theme buttons crashed inside Row
- **Symptom:** BoxConstraints forces an infinite width at OutlinedButton remedy-buy-* in a Row
- **Root cause:** theme.dart sets Filled/OutlinedButton minimumSize to Size.fromHeight (infinite width)
- **Fix:** compactButtons() wraps rows, wraps and dialogs with minimumSize Size(0, 40)
- **Rule:** Buttons placed in a Row, Wrap or dialog action bar must use compactButtons() (or an explicit minimumSize); the app theme makes them full-width. (Rule 7)

### 2026-10-26: flutter analyze passed but the web build failed
- **Symptom:** flutter build web: Tear-offs of external extension type interop member remove are disallowed (printer_web.dart)
- **Root cause:** Web-only files (conditional imports for dart.library.js_interop) are only fully checked by dart2js; analyze and VM tests never compile them
- **Fix:** Used a closure () => frame.remove() instead of the tear-off
- **Rule:** After touching a web-only (js_interop) file, run flutter build web before calling it done; the harness app gate does this. (Rule 6)

### 2026-10-26: Tarot battery tested the wrong statistical property
- **Symptom:** 'position 1 vs 2 independent' failed (chi2 51.9 > 39.4) on a correct draw
- **Root cause:** Positions in a spread are drawn without replacement, so they are not independent; the test assumed sampling with replacement
- **Fix:** Test against the without-replacement expectation P(j|i) = (N_j - [i=j]) / 77; equally strict, now passes
- **Rule:** Before treating a statistical test failure as a bug, check the test's null hypothesis matches how the process is supposed to behave. (Rule 5)

### 2026-10-26: PGlite test timed out under parallel load
- **Symptom:** db-schema test: Test timed out in 5000ms (took 8 s) after the Argon2 auth tests were added
- **Root cause:** PGlite boots Postgres in WASM and competes for CPU with Argon2 hashing in parallel test files
- **Fix:** 30 s timeout on the PGlite tests only; assertions unchanged
- **Rule:** Give tests with heavy runtime start-up (WASM, browsers) an explicit timeout instead of relying on the 5 s default. (Rule 4)

### 2026-10-26: 流年 timeline cells overflowed
- **Symptom:** RenderFlex overflowed by 31 pixels in the 流年 timeline (widget test)
- **Root cause:** A fixed 112 px cell held 干支 plus three caption lines
- **Fix:** Cell height 140 px; each caption line maxLines 1 with ellipsis
- **Rule:** Size fixed-height cells for the maximum number of lines they can show, and cap every line with maxLines + ellipsis. (Rule 3)

### 2026-10-25: POC scripts broke the lint gate
- **Symptom:** HARNESS: FAIL at lint right after running npm run poc:astrology
- **Root cause:** POC scripts rewrite docs/poc/*-results.json with JSON.stringify formatting, which prettier --check rejects
- **Fix:** Added docs/poc/*-results.json to .prettierignore
- **Rule:** Exclude script-generated files from formatters and linters when the script that creates them is added. (Rule 2)

### 2026-10-25: Tarot audit replay ignored the stored cards

- **Symptom:** First verifyDraw recomputed the draw and compared it only to the stored digest, so a row with edited cards but the original digest still verified
- **Root cause:** Checked that the recomputation matched the digest, not that the stored data matched it
- **Fix:** verifyDraw now requires digest(replayed) == digest(stored cards) == audit.result_digest; covered by test 'audit replay rejects tampered stored cards'
- **Rule:** Audit verification must check the stored record itself, not only a fresh recomputation. (Rule 1)
