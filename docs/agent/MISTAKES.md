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
9. Anything meant to stay reachable from this computer must hold a keep-awake request and supervise its child processes (restart or fail loudly).
10. Validate external timezone data against the running Node tzdb at build time, and test every record, not a sample of countries.
11. Check a gazetteer against real sample addresses (the owner's examples) before calling coverage done.
12. Write the arithmetic for a hand-computed expectation into the test comment, so a wrong expectation is visible as such.
13. A picker never doubles as the only place a value is shown: make it read-only and give every value the user may change its own editable field.
14. When a field is deliberately kept off the server, check every screen and export that should show it still gets it from the device.
15. Never run dart format on whole directories in this app; format only files you created, or none.
16. Before scripting against the v1 API, read its response builder (publicReport, publicRemedy, publicLifeReport) for field names; reports use report_id, not id.
17. Store new state before notifying listeners, and test it with a listener that reads the state back.

## Log

### 2026-10-27: Listener notified before the new state was stored
- **Symptom:** watchAiMode called onChange before saving the new mode, so the AI switched console line would have printed the old mode
- **Root cause:** The listener reads the switch back, and the cached mode was assigned after the callback
- **Fix:** Store the mode first, then notify; the test listener now reads the switch back (checked by reverting the fix: the test fails)
- **Rule:** Store new state before notifying listeners, and test it with a listener that reads the state back. (Rule 17)

### 2026-10-27: Verify script guessed the report id field
- **Symptom:** The end-to-end check of the AI switch polled /v1/reports/undefined and got 404
- **Root cause:** The script assumed the POST /v1/reports body has id; publicReport returns report_id
- **Fix:** Read publicReport and used report_id
- **Rule:** Before scripting against the v1 API, read its response builder (publicReport, publicRemedy, publicLifeReport) for field names; reports use report_id, not id. (Rule 16)

### 2026-10-27: dart format restyled untouched files
- **Symptom:** After dart format lib, 26 files changed (106 lines in providers.dart for a 4-line edit)
- **Root cause:** The codebase is not dart-format clean in the current tall style; formatting the whole lib rewrote files nobody touched
- **Fix:** Backed up, restored committed versions and re-applied only the intended edits
- **Rule:** Never run dart format on whole directories in this app; format only files you created, or none. (Rule 15)

### 2026-10-27: Birthplace name never reached any report
- **Symptom:** Owner: the birthplace is not in the report
- **Root cause:** Only timezone and longitude were sent (privacy design) and nothing showed or remembered the place name, so readings and history had no birthplace
- **Fix:** birthplace label sent as reading context, shown first in the facts card and the life report header, and kept per chart on the device (chartPlaces) for history
- **Rule:** When a field is deliberately kept off the server, check every screen and export that should show it still gets it from the device. (Rule 14)

### 2026-10-27: Person picker looked like an editable name field
- **Symptom:** Owner: after picking a person in the profile picker the name could not be edited; the input stopped being editable
- **Root cause:** DropdownMenu shows its selection in a text field (filter/search on) while the form had no name field, so the only visible name was in a picker
- **Fix:** Picker is read-only (requestFocusOnTap/enableFilter/enableSearch false) with add/edit actions opening a pop-up; the form has its own editable name field, rebuilt when a person is loaded
- **Rule:** A picker never doubles as the only place a value is shown: make it read-only and give every value the user may change its own editable field. (Rule 13)

### 2026-10-26: Hand-computed test expectation was wrong (命卦 1985)
- **Symptom:** kuaNumber(1985, male) test expected 2, engine returned 6
- **Root cause:** I applied the 5→2 rule to the wrong year: 1985 male is 8+5=13→4, 10−4=6; the 5→2 case is 1986
- **Fix:** corrected the expectation with the written-out arithmetic, kept both years as cases
- **Rule:** Write the arithmetic for a hand-computed expectation into the test comment, so a wrong expectation is visible as such. (Rule 12)

### 2026-10-26: GeoNames cities15000 missed county-level cities
- **Symptom:** 靖江 (pop ~700k) was not selectable; 873 of 3718 Chinese places had no Chinese name
- **Root cause:** cities15000 skips places GeoNames lists without population; Chinese names often sit on the ADM3 division or are untagged
- **Fix:** add every PPLA..PPLA3 seat from the full CN/TW/HK/MO/MY/SG dumps; borrow the division name by parent codes + name prefix; accept untagged all-Han names
- **Rule:** Check a gazetteer against real sample addresses (the owner's examples) before calling coverage done. (Rule 11)

### 2026-10-26: New IANA zone unknown to Node (America/Coyhaique)
- **Symptom:** places test: RangeError Invalid time zone America/Coyhaique
- **Root cause:** GeoNames uses tzdb 2025b zones; this Node bundles tzdb 2024b, so a birth in Aysen would fail to compute
- **Fix:** build:places maps split zones to their parent (SPLIT_ZONES) and fails the build on any unknown zone
- **Rule:** Validate external timezone data against the running Node tzdb at build time, and test every record, not a sample of countries. (Rule 10)

### 2026-10-26: Public tunnel URL died after a while
- **Symptom:** The trycloudflare URL from npm run public stopped working after some time
- **Root cause:** Windows slept after 30 min idle, which cut the quick tunnel (its URL never returns); public.ts also exited when the tunnel dropped and ignored an API crash
- **Fix:** keep-awake.ps1 (SetThreadExecutionState) while public runs; tunnel restarts and prints the new URL; API exit stops everything with a message
- **Rule:** Anything meant to stay reachable from this computer must hold a keep-awake request and supervise its child processes (restart or fail loudly). (Rule 9)

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
