# Mistakes and lessons: 命理大师

## Rules (read before every task)

1. Audit verification must check the stored record itself, not only a fresh recomputation.
2. Exclude script-generated files from formatters and linters when the script that creates them is added.
3. Size fixed-height cells for the maximum number of lines they can show, and cap every line with maxLines + ellipsis. When a fixed-size box gains a border, take the border out of its padding: an ellipsis hides the lost room from widget tests (their font is not the real one), so look at a rendered screenshot (v3.3.0: 「2026 · 虛歲 37」 lost its age).
4. Give heavy tests (WASM or browser start-up, sweeps over a whole dataset) an explicit timeout instead of relying on the 5 s default: a synchronous test can't be stopped, so it fails after finishing late under parallel load (the places sweep, v2.7.0: 2.5 s alone, 9.8 s in the full suite).
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
18. Esc handling must look past a focused text field's own DismissIntent (keyboard.dart _layerAt); test Esc from inside a field.
19. In widget tests, pump a frame between enterText (or any setState) and the next key press; use press() from test/keys.dart.
20. Check whether a DropdownMenu is open with find.text(entry).hitTestable(), never a plain find.text.
21. Don't rely on flutter test --platform chrome here; if tried, time-box it and end only its own processes (command line contains flutter_tools_chrome_device).
22. matchesGoldenFile captures at 1x logical pixels whatever tester.view.devicePixelRatio is; to inspect high-DPI detail, render with RenderRepaintBoundary.toImage(pixelRatio:) instead. A dialog lies in the overlay, above the page's first RepaintBoundary: to include it, render the root layer, `(tester.binding.renderViews.first.debugLayer as OffsetLayer).toImage(...)` (v3.2.0).
23. Flutter deletes lib/l10n/gen as stale when pub get, test or build runs from another path than its last run and that path still exists (the IDE on the real path, a kept junction). Do manual Flutter runs through a junction you remove afterwards; the guard blocks `cmd /c rmdir` on a junction that points at the repo, so when it can't be removed, leave it. Before the harness after manual runs, delete `app/.dart_tool/flutter_build` on the real path (Flutter's record of the last run; rule 74). That helps (v12.1.0: the second run passed) but does not always prevent it: v14.1.0's first harness after a version bump in app/pubspec.yaml still failed at analyze, with both records deleted and the old junction still there. After a pubspec edit or manual runs, if the harness fails at analyze with app_localizations missing, run it once more (v14.1.0 and v15.0.0: each time the first run after the version bump; the rerun passed that gate).
24. To start a fresh app within one widget test, pump an empty widget first; pumping testApp again keeps the old Navigator and state.
25. In a lazily built page, look for widgets in page order (top to bottom) with scrollUntilVisible; to go back up, use a negative delta.
26. After editing anything sync:app copies (i18n/terms.json, deck.ts, engine output behind fixtures), run npm run sync:app before running app tests.
27. Pump a frame after scrollUntilVisible or tester.ensureVisible, before the next finder, tap or scroll: both jump without a frame, so the next step sees the old layout (a tap goes to the old position). Use scrollTo() from test/support.dart for each card, or scrollToFinder() for any other finder; since v3.5.0 test_rules_test.dart fails on a scrollUntilVisible anywhere else.
28. In user-visible text, name each 合冲刑害破 relation by its own type, never several types under one name; pin generated notes in a test, and take release-note examples from real output.
29. When the engine adds a fact that holds 干支, extend knownGanzhi in src/ai/faithfulness.ts in the same change, with a test that names one. The exception is a fact no prompt reads that would make the check toothless: dayun_years (v3.3.0, 80 years, so every 干支) stays out, and the 甲子 test pins that.
30. Write scratch tsx scripts as .ts with an async main() in the project root, importing with relative paths (`./src/…`, `./test/helpers.js`): inside the package tsx loads them as ESM, where an absolute `C:/` import fails with ERR_UNSUPPORTED_ESM_URL_SCHEME (corrected v4.3.0). Never `tsx -e` (Git Bash passes the newlines as `\n`), take test constants (PEPPER, FIXED_NOW) from test/helpers.ts instead of making them up, and delete the script after use. Check CJK text in such a script or with the Grep tool: Git Bash's grep here is not UTF-8 (`-P` refuses, `-o` splits characters) (v3.2.0).
31. In 简体 copy (app_zh.arb, 简体 prompts), quote with “”, never 「」; write each script on its own instead of converting, and let locale_test check.
32. To check that text is not empty, assert `expect(text.trim()).not.toBe('')`: `expect.any(String)` also matches `''`. Read each new assertion once for what it would let through.
33. Give widget keys an explicit type, ValueKey<String>(id), never ValueKey(x) on a nullable value: a ValueKey<String?> matches no find.byKey(Key(...)) and focusedKey() ignores it.
34. Before building a plan item, search the DEVLOG, the README and git log for an owner decision on the same thing (owner, Owner request); a plan item never overrides one. Label owner requests as such in the DEVLOG.
35. With PGlite, pass a JS array only for a column of a known array type such as text[]; for an enum array, write constant values into the SQL or pass text[] and cast it there. Probe a new parameter type in a scratch script before relying on it.
36. Code that only scripts need (sync, review, build) is imported from its own module, never re-exported from an index the server imports; runtime-deps.test.ts holds the server to its dependencies.
37. Against the mock provider, never assert that a report is still pending: drain the jobs and assert the end state, or give the test a provider that waits until released. This covers any job, not only reports (recurred v7.0.0: a 追问's 409 "still being answered" check needed a gated provider).
38. Copy the project path from the environment or an earlier tool call; never retype a path with CJK characters. The folder is `C:\命理大师` (简体 师); `C:\命理大師` is a stray folder the guard won't let go of (v4.3.0).
39. To verify a traditional text, read the primary source for every item; agreement between modern copies can hide a shared error. v4.3.0: both modern 籤詩 copies had 寅午戍 (no such branch), 敵圖, 咨嘆 and 步多; the Qing print had 戌, 敵國, 咨嗟 and 步步.
40. Never put the owner email or any personal data in a request to an outside service, not even in a User-Agent; use a generic agent string.
41. For exact text, download the raw source (action=raw, the API with continue, the file itself) into its own folder; never take verbatim text from a summarising fetch.
42. When a feature ships behind a switch the owner will flip, no test may pin the switch's shipped value: test both states with an explicit override, assert the gate as an invariant (on => reviewed), and make every on-screen trace of the gate follow its flag. Try the documented steps once, run the tests, then undo them.
43. A findsNothing needs a positive anchor: first find the neighbour the missing widget would sit beside, and pair it with a test that finds the widget there when it should exist. Never use off-screen or scrolled-past as evidence of absence (lists cache children).
44. Before stating how something behaves at runtime (no restart, hot update), grep every reader of it and test it the way the owner meets it: a server started before the change. A fresh process per test proves nothing about a running one.
45. To change a hand-formatted JSON file (schemas, configs, the matrix), insert or replace text with Edit; never round-trip it through JSON.stringify. Check git diff --stat right after: a change much larger than intended means the file was reformatted.
46. In app/, FilledButton and OutlinedButton are full width by the theme: never put one straight into a Row; give it Expanded/SizedBox or stack it in a Column. A layout exception in a widget test can surface as an unrelated failure (focus, taps): fix the first exception first.
47. In a traditional text that passed through 简体, treat every character 简体 merges (系/繫/係, 腊/臘, 后/後, 干/幹, 机/機, 斗/鬥, 里/裏, 仆/僕, 凶/兇, 志/誌) as unverified until a print or the sense settles it, even when every digital copy agrees. Find a page transcription of a scanned print (維基文庫 Page: namespace) to map the scan, then read the scan where anything differs.
48. Fetch Wikimedia page renders (DjVu/PDF thumbnails) one at a time, at least 5 s apart, with retry and backoff on a non-JSON answer; ask only for the pages the check needs, and cache them.
49. Before laying out by a Material widget's size (a chip, a button), measure it in a test at the sizes that matter: its outline, density and focus side can add to label plus padding. Then pin the layout in a test at those sizes, focused too.
50. A CustomPainter that draws text takes its font from the page: pass DefaultTextStyle.of(context).style (or the theme text style) into the painter and use its fontFamily and fallback. Look at a render with the real font loaded, not only the test font, whose boxes hide this.
51. A test opens a method from the home page through openEntry (scroll, then tap), never a bare tap on entry-*, so a change in the home order or grouping cannot leave an entry off the first screen. Run every test that taps a moved entry before calling a home change done.
52. Anything a stored record must show on every device or after a restart (a name, a label, a choice) is kept with the record on the server, sealed like it. Browser storage is per origin, and npm run public changes the origin every run: keep only per-device conveniences there.
53. Give every child an AnimatedSwitcher can show its own key, whenever two of them can follow each other: two unkeyed children at once are duplicate keys. Test a page along every way users reach it (from history as well as right after making it).
54. Run npx prettier --check . as the very last step before the harness, after the final edit to any Markdown, YAML or TypeScript file; a check made before a later edit proves nothing about it.
55. A floating control must never cover what it leads to: hide it (out of the hit test and the Tab order too) while its target is on screen, and test the target with hitTestable after opening it at a phone size. When code both scrolls to a field and focuses it, await the scroll first.
56. The Write/Edit tools turn a \uXXXX in new_string or content into the character itself. For a literal \u escape, use numeric code units instead, or build it in a script with String.fromCharCode(92), and check the bytes afterwards (od -c, or a test). (G16 recurred 2026-10-29: a `node -e` edit turned `/\s+/g` into `/s+/g` in server.ts; caught by grepping the line after the edit. A regex goes in with the Edit tool, never through a shell string.)
57. When an action shows a 'working' SnackBar and then its result, hide the current SnackBar before showing the result: SnackBars queue, and the result would wait out the first one's duration.
58. After adding anything to a page, run every test that opens it (grep for its open key) before the harness, not only the new ones. A test that finds a row below the new content must scroll to it: lazily built lists drop what lies past the fold.
59. Whatever a tap makes below its button (a result, a step, a card) goes inside BringIntoView, outside its FadeSlideIn, with a trigger when it grows a row per tap. Test it on a 360 x 740 phone with a test that fails when the scroll is off (owner, 2026-10-29: 新生成的component 要避免用户下滑后再点击).
60. Never move the page with animateTo or ensureVisible while the user may tap (a button that has just come up): use bringIntoView, whose scroll lets taps through. When one tap starts two automatic scrolls, decide which part wins (the newest) and test where the page ends.
61. In a widget test, pump at least 700 ms (BringIntoView.settle and its 400 ms scroll) after a tap that adds content before tapping or measuring that content; compare a rect measured through a transform with closeTo, never exactly.
62. Test a provider through its real SDK client with a fake fetch (an SSE body for streams), at the largest max_tokens a route uses, not only with a fake client object. Call Claude through messages.stream(...).finalMessage(): the SDK refuses unstreamed requests over about 21,000 max_tokens, and thinking counts toward max_tokens.
63. A test that scripts or breaks a provider puts it under every provider key (or passes its own routing), never only the key the shipped routes use. Check that a failure test fails for its own reason (the logged error), not only that something failed.
64. On a page that builds cards past the screen, a finder for one below the fold needs skipOffstage: false, whether it checks that the card exists, measures its position or asserts findsNothing (rule 43). Scroll to it first only when the test is about what the user sees.
65. In a list whose parts replace each other (a field, then a card), give each BringIntoView its own key: an unkeyed one at the same place takes over the old state and never brings its part into view. Prove it on a 360 x 740 phone with content past the fold, and check the test fails with the keys removed.
66. A new or changed route's settings reach the model only through the server's routing: test it through withModel with the owner's ACTIVE_AI_MODEL (read its name from .env, never a key) as well as the bare table, before saying how it behaves.
67. In api/openapi.yaml, quote every description inside a flow mapping { ... } that contains a comma, a colon or starts with true/false/null, and run npm run validate:openapi right after editing the spec.
68. In app tests, find the request you check by its method and path (lastWhere / singleWhere), never api.requests.last: any page may add a background call (a balance, a price) after it.
69. To stop a server you started in the background, stop the process that owns its port (Get-NetTCPConnection -LocalPort N -State Listen, check its command line is yours), never only the launcher's PID, and confirm the port is free afterwards. Start such checks on a spare port with MINGLI_STORE=memory so the owner's server and data are never touched.
70. With Riverpod 3, give the ProviderScope a retry policy (a few quick tries, none for a 4xx): its default retries for about 45 s while showing loading. In a test of an error state, pump past the retries, and assert the request each tap should send, so a missed tap cannot pass.
71. When several requests can meet an expired token at once, share one refresh (an in-flight future) and retry without refreshing when the token already changed: the server rotates refresh tokens, so a second refresh with the same one fails.
72. A focus check must name the focused control itself (its key, or a focused element inside the widget it belongs to), never just an ancestor of a label: before the first Tab the primary focus is a scope above everything.
73. In Git Bash, an argument that starts with / (a base href, a URL path, a /flag) reaches the program as a Windows path: prefix the command with MSYS_NO_PATHCONV=1, or run it from PowerShell or a script. Through powershell -File, an argument with a double quote inside is split: keep double quotes out of such arguments.
74. A Flutter build script clears .dart_tool/flutter_build first (real path), builds through a junction it removes afterwards, writes a build that is served to its own --output folder (the harness builds build/web), and checks the output has its files: rule 23's stale-path deletion hits web build output too, through any junction still there.
75. A widget that shows its own focus must ask its own node for hasPrimaryFocus: Focus.onFocusChange (and InkWell's) report hasFocus, which is true while anything inside has the focus. Test it with a focusable child inside.
76. Every WidgetState property in a component theme must resolve to a value for the empty state set: ChipThemeData.lerp, run by every change of theme, fails on null. Give each state Material's own default (a chosen flat chip keeps a transparent 1 px side, so `BorderSide.none` shrinks it by 2 px; rule 49), and test a theme change itself (switch, pump half the animation, check colours between the two themes), not only each theme on its own.
77. A label that can hold model or user text (a pill, a chip, a badge) lets it wrap: a loose Flexible inside a MainAxisSize.min row, never a bare Text in a Row. Test it with a long text in a narrow column.
78. When a stored field gains values (an enum, a role, a status), grep every reader and writer of it in both stores (memory and PGlite, put and get, SQL checks) and round-trip each new value through PGlite in a test.
79. In Dart, never assign arrow closures inside a cascade: one statement per callback, or a block body for the closure.
80. Write a test of what a server check reports from the check itself (read it, e.g. templateProblems reads subject and body), and when a fake mirrors it, cite the server function it mirrors.
81. Start a test server and its sign-ins in the describe whose tests call it (its beforeAll, or a shared start() each such describe calls), never in a top-level beforeAll ahead of slow tests: an idle keep-alive connection meets the server 5 s timeout. A failure seen twice is a cause to find, not a flake: name the test with --reporter=verbose.

## Log

### 2026-10-30: A slow test between the sign-ins and the first API call reset the connection
- **Symptom:** messages.test.ts: the first test of the 后台 roles failed with fetch failed, ECONNRESET, under the full suite only (twice in five harness runs, then three runs out of three); alone it passed.
- **Root cause:** The file signed in over HTTP in a top-level beforeAll, then ran the PGlite test for seconds before its HTTP tests. The sign-ins keep-alive connections sat idle past the server 5 s keep-alive, and the next request reused one just as the server closed it.
- **Fix:** The server and its sessions start in a shared start() that each API describe calls in its own beforeAll, so they begin right before the API tests. Three full runs passed.
- **Rule:** Start a test server and its sign-ins in the describe whose tests call it (its beforeAll, or a shared start() each such describe calls), never in a top-level beforeAll ahead of slow tests: an idle keep-alive connection meets the server 5 s timeout. A failure seen twice is a cause to find, not a flake: name the test with --reporter=verbose. (Rule 81)

### 2026-10-30: A test expected a server check to report what it does not
- **Symptom:** messages_test: 需要用到 {{code}} not shown after the body lost {{code}}
- **Root cause:** The test was written from memory: templateProblems reads the subject too, and the default subject still held {{code}}; FakeAdmin mirrored the server correctly
- **Fix:** The test clears the subject first, then checks both problems
- **Rule:** Write a test of what a server check reports from the check itself (read it, e.g. templateProblems reads subject and body), and when a fake mirrors it, cite the server function it mirrors. (Rule 80)

### 2026-10-30: A Dart cascade swallowed the next assignment into an arrow closure
- **Symptom:** flutter analyze: this expression has a type of void so its value cannot be used, on api..onSignedOut = () => notifier.ended()..onNotAllowed = () => notifier.recheck()
- **Root cause:** An arrow body is an expression, so the next ..onNotAllowed cascaded on the closure body (ended(), void) instead of on api
- **Fix:** Two plain statements: api.onSignedOut = ...; api.onNotAllowed = ...; (admin/lib/application/providers.dart)
- **Rule:** In Dart, never assign arrow closures inside a cascade: one statement per callback, or a block body for the closure. (Rule 79)

### 2026-10-30: The database dropped the new roles
- **Symptom:** messages.test: an account put into PGlite as manager came back without a role; in pglite mode every manager and integrator would have lost the role at the next read.
- **Root cause:** The PgStore read mapped the role column with a check written for the two values of v11.2.0 (role === admin), so any other value read back as none. The column check and the type had been widened; this reader had not.
- **Fix:** The reader keeps any role but the default; the S25 test round-trips manager and integrator through PGlite.
- **Rule:** When a stored field gains values (an enum, a role, a status), grep every reader and writer of it in both stores (memory and PGlite, put and get, SQL checks) and round-trip each new value through PGlite in a test. (Rule 78)

### 2026-10-30: A label pill overflowed with a long text
- **Symptom:** life_report_test: a RenderFlex overflowed by 71 px in a Pill (喜 · a full sentence) once pages sat in the 720 column, narrower than the test window.
- **Root cause:** Pill put its Text straight into a Row, so it could never wrap; the old full-width page only hid it. The 喜 and 忌 lists are model text and can be sentences.
- **Fix:** The text is a loose Flexible in the pill's MainAxisSize.min row: it wraps when the parent is bounded and keeps one line in an unbounded row (Flex asserts only for a tight fit or a max-size row; checked in the SDK).
- **Rule:** A label that can hold model or user text (a pill, a chip, a badge) lets it wrap: a loose Flexible inside a MainAxisSize.min row, never a bare Text in a Row. Test it with a long text in a narrow column. (Rule 77)

### 2026-10-30: A change of theme crashed in the chip theme lerp
- **Symptom:** Switching 浅色 to 深色 (and the system switching light and dark while the app runs) threw a null check in ChipThemeData._lerpSides inside AnimatedTheme; the page stopped rebuilding.
- **Root cause:** The chip theme side was a WidgetStateBorderSide that resolved to null outside the focused state. ChipThemeData.lerp resolves both sides for the empty state set and fails when both are null. Every test built one theme at a time, so no test ran a theme change.
- **Fix:** The chip side resolves to the chip own outline for every state (focus outline, transparent once selected, a faint one when disabled, outlineVariant otherwise). theme_test switches the theme from the menu and checks the colours half-way. A first try returned BorderSide.none once selected: tarot_spread_test caught the chosen spread chip 2 px smaller than the others.
- **Rule:** Every WidgetState property in a component theme must resolve to a value for the empty state set: ChipThemeData.lerp, run by every change of theme, fails on null. Give each state Material's own default (a chosen flat chip keeps a transparent 1 px side, so `BorderSide.none` shrinks it by 2 px; rule 49), and test a theme change itself (switch, pump half the animation, check colours between the two themes), not only each theme on its own. (Rule 76)

### 2026-10-30: AppCard ringed itself while a field inside it had the focus
- **Symptom:** The 管理后台 sign-in page, rendered in headless Chrome, showed a focus ring round the whole card besides the focused field
- **Root cause:** AppCard set its ring from InkWell.onFocusChange, which Focus calls with hasFocus: true while any descendant has the focus
- **Fix:** AppCard keeps its own FocusNode and rings only while that node hasPrimaryFocus; a keyboard_shell_test case (a field in a card, a button in a tappable card, Shift+Tab back) failed before the fix
- **Rule:** A widget that shows its own focus must ask its own node for hasPrimaryFocus: Focus.onFocusChange (and InkWell's) report hasFocus, which is true while anything inside has the focus. Test it with a focusable child inside. (Rule 75)

### 2026-10-30: A web build through a new junction deleted its own files
- **Symptom:** npm run admin:build produced admin/build/web without favicon.png and manifest.json
- **Root cause:** Flutter records a build's files by the path it used (.dart_tool/flutter_build/*/outputs.json) and deletes them as stale from the next build through another path: the earlier manual junction still existed, so the deletes hit the same physical files. Also, the harness gate's plain flutter build web writes build/web with base href /, which would replace the build served at /admin/
- **Fix:** admin-build.ts clears admin/.dart_tool/flutter_build on the real path, builds through a junction it removes afterwards into its own folder (--output admin/build/served), and checks the output has its files; check-admin.ps1 clears the record too
- **Rule:** A Flutter build script clears .dart_tool/flutter_build first (real path), builds through a junction it removes afterwards, writes a build that is served to its own --output folder (the harness builds build/web), and checks the output has its files: rule 23's stale-path deletion hits web build output too, through any junction still there. (Rule 74)

### 2026-10-29: Git Bash rewrote --base-href /admin/ into a Windows path
- **Symptom:** flutter build web --base-href /admin/ failed: it received the base href C:/Program Files/Git/admin/
- **Root cause:** Git Bash (MSYS) converts any argument that starts with / into a Windows path before the program sees it
- **Fix:** Ran it as MSYS_NO_PATHCONV=1 flutter build web --base-href /admin/; the npm script and the harness gate run it from Node or PowerShell, where nothing is converted
- **Rule:** In Git Bash, an argument that starts with / (a base href, a URL path, a /flag) reaches the program as a Windows path: prefix the command with MSYS_NO_PATHCONV=1, or run it from PowerShell or a script. Through powershell -File, an argument with a double quote inside is split: keep double quotes out of such arguments. (Rule 73)

### 2026-10-29: A focus check matched the app-wide focus scope
- **Symptom:** Tab reaches a rail entry: the loop stopped at once, and Enter opened nothing
- **Root cause:** The check asked whether the focused element is an ancestor of the label; before the first Tab the primary focus is a scope above the whole app, which is an ancestor of everything
- **Fix:** railFocusOn: the focused element must sit inside the NavigationRail and contain the label
- **Rule:** A focus check must name the focused control itself (its key, or a focused element inside the widget it belongs to), never just an ancestor of a label: before the first Tab the primary focus is a scope above everything. (Rule 72)

### 2026-10-29: Concurrent requests each refreshed an expired token
- **Symptom:** Writing the session test: a page asks for three things at once, and each 401 started its own refresh
- **Root cause:** The client refreshed per request; the server rotates refresh tokens (TokenService.rotate), so every refresh after the first would fail and sign the admin out
- **Fix:** AdminApi shares one in-flight refresh (_refreshing) and retries without refreshing when the access token changed meanwhile; the test expects exactly one /v1/auth/refresh
- **Rule:** When several requests can meet an expired token at once, share one refresh (an in-flight future) and retry without refreshing when the token already changed: the server rotates refresh tokens, so a second refresh with the same one fails. (Rule 71)

### 2026-10-29: Riverpod 3 retried a failed provider by itself and hid the error
- **Symptom:** The dashboard test for a failed part found no 重试 button: by the time it looked, the part had loaded; an earlier version passed although its tap on 重试 missed (off screen)
- **Root cause:** Riverpod 3 retries a failing provider on its own (200 ms doubling to 6.4 s, 10 times, about 45 s) and reports it as loading meanwhile; a real outage would show a spinner for 45 s
- **Fix:** ProviderScope(retry: retryAdmin): four quick retries (0.2 to 1.6 s) for a 5xx or no connection, none for a 4xx; the test pumps past them, counts the requests, then taps 重试 after ensureVisible and checks the new request
- **Rule:** With Riverpod 3, give the ProviderScope a retry policy (a few quick tries, none for a 4xx): its default retries for about 45 s while showing loading. In a test of an error state, pump past the retries, and assert the request each tap should send, so a missed tap cannot pass. (Rule 70)

### 2026-10-29: Killing a background npx tsx start left its server running
- **Symptom:** After kill of the PID saved from 'npx tsx scripts/api-server.ts &', port 8799 was still listening.
- **Root cause:** The saved PID was npx's; the node process running tsx is its child and kept the port.
- **Fix:** Stopped the process that owns the port (Get-NetTCPConnection -LocalPort 8799 -> OwningProcess, its command line checked first), then checked the port was free.
- **Rule:** To stop a server you started in the background, stop the process that owns its port (Get-NetTCPConnection -LocalPort N -State Listen, check its command line is yours), never only the launcher's PID, and confirm the port is free afterwards. Start such checks on a spare port with MINGLI_STORE=memory so the owner's server and data are never touched. (Rule 69)

### 2026-10-29: A test read api.requests.last and met a new background request
- **Symptom:** fengshui_test failed with FormatException: Unexpected end of input after 积分 came in; naming_test and qiuqian_test used the same pattern and passed only by timing.
- **Root cause:** The test took the chart request to be the last one sent. The reading card shown after the chart now asks for the balance (GET /v1/points, empty body), so the last request was that GET.
- **Fix:** The tests find the request by method and path: api.requests.lastWhere((r) => r.method == 'POST' && r.url.path == '/v1/charts'); the expected bodies are unchanged.
- **Rule:** In app tests, find the request you check by its method and path (lastWhere / singleWhere), never api.requests.last: any page may add a background call (a balance, a price) after it. (Rule 68)

### 2026-10-29: OpenAPI flow-mapping comma split a description (recurred from S19)
- **Symptom:** npm run validate:openapi failed: Property 'in 积分' is not expected here, at PointsShort need.
- **Root cause:** In a YAML flow mapping { type: integer, description: What the request costs, in 积分 } an unquoted comma ends the value, so the rest became a key. S19 hit the same thing and fixed it without a rule.
- **Fix:** Quoted the description; also quoted one that began with the word false.
- **Rule:** In api/openapi.yaml, quote every description inside a flow mapping { ... } that contains a comma, a colon or starts with true/false/null, and run npm run validate:openapi right after editing the spec. (Rule 67)

### 2026-10-29: A new route's effort never reached the model through ACTIVE_AI_MODEL
- **Symptom:** The 深度分析 route was set to effort low and documented so, but the owner's .env names ACTIVE_AI_MODEL=claude-opus-5-5, and withModel put every route, this one too, at the model's catalog effort (medium).
- **Root cause:** The route was tested against the bare routing table only, never through the routing the running server uses with the owner's model choice (rule 44's lesson, met again).
- **Fix:** withModel leaves a route alone when the chosen model is the one it already has; a test runs the shipped table through withModel with claude-opus-5-5 and with another model, and fails on the old code.
- **Rule:** A new or changed route's settings reach the model only through the server's routing: test it through withModel with the owner's ACTIVE_AI_MODEL (read its name from .env, never a key) as well as the bare table, before saying how it behaves. (Rule 66)

### 2026-10-29: A new BringIntoView took over the one it replaced and never scrolled
- **Symptom:** On a 360 x 740 phone the 深度分析 start button stayed below the screen after the last answer; every earlier question came into view.
- **Root cause:** The start card's BringIntoView sat where the answer field's had been in the ListView's children. Unkeyed, Flutter reused the old state, so initState never ran and nothing asked to scroll.
- **Fix:** A ValueKey on each BringIntoView of the page (bring-thinking, bring-composer, bring-ready); a test answers five questions on a 360 x 740 phone and fails with the keys removed.
- **Rule:** In a list whose parts replace each other (a field, then a card), give each BringIntoView its own key: an unkeyed one at the same place takes over the old state and never brings its part into view. Prove it on a 360 x 740 phone with content past the fold, and check the test fails with the keys removed. (Rule 65)

### 2026-10-29: A card below the screen is offstage to find() (v9.3.0)
- **Symptom:** The new reading-page tests found no 总结 card (find.byKey(conclusion) found 0) and getRect threw, though the card was built: FourLayerReport builds every card (scrollCacheExtent 100000), and those below the screen are offstage to the default finder.
- **Root cause:** find() skips offstage widgets by default, and a scrollable reports the children in its cache area as offstage.
- **Fix:** skipOffstage: false on every finder that checks a below-the-fold card exists, measures where it sits, or asserts findsNothing there.
- **Rule:** On a page that builds cards past the screen, a finder for one below the fold needs skipOffstage: false, whether it checks that the card exists, measures its position or asserts findsNothing (rule 43). Scroll to it first only when the test is about what the user sees. (Rule 64)

### 2026-10-29: Scripted providers under one key (v9.2.0)
- **Symptom:** When every route moved from deepseek to anthropic, five tests that passed a scripted or failing provider only as deepseek either failed with provider anthropic not configured or kept passing for the wrong reason: the provider-down test still saw a failed report, caused by the missing provider instead of its error.
- **Root cause:** The tests named the provider the shipped routes happened to use, so their provider was chosen by config/model_routing.json, not by the test.
- **Fix:** The same provider under both keys (deepseek and anthropic) in those tests; the provider-down test also checks that the logged error is the provider's own.
- **Rule:** A test that scripts or breaks a provider puts it under every provider key (or passes its own routing), never only the key the shipped routes use. Check that a failure test fails for its own reason (the logged error), not only that something failed. (Rule 63)

### 2026-10-29: Claude provider never sent a long reading (v9.2.0)
- **Symptom:** AnthropicProvider used beta.messages.create. Routed to Claude, the narrative and life routes (max_tokens 32,000) would have failed before any request: the SDK refuses an unstreamed request above 21,333 max_tokens (Streaming is required for operations that may take longer than 10 minutes). Its tests used a fake client with create(), which never applies that guard.
- **Root cause:** The provider was kept since Phase 1 but never routed, and was only tested against a hand-made fake of the SDK client, so the SDK request checks never ran.
- **Fix:** Stream every request (beta.messages.stream(...).finalMessage()); a test drives the real SDK client over a fake fetch at 64,000 max_tokens and checks the request on the wire.
- **Rule:** Test a provider through its real SDK client with a fake fetch (an SSE body for streams), at the largest max_tokens a route uses, not only with a fake client object. Call Claude through messages.stream(...).finalMessage(): the SDK refuses unstreamed requests over about 21,000 max_tokens, and thinking counts toward max_tokens. (Rule 62)

### 2026-10-29: Tests tapped what a growing card still clipped
- **Symptom:** A tap on a button just added to an AppCard missed (no hit), and a turned tarot card measured 103.00000000000006 once the page scrolled by itself.
- **Root cause:** AppCard's AnimatedSize clips its content and its hit test to the animating size for 250 ms; a rect measured through a rotation picks up floating error at a fractional scroll offset.
- **Fix:** Tests pump past BringIntoView.settle and the 400 ms scroll before tapping what was just added; the turned card is compared with closeTo.
- **Rule:** In a widget test, pump at least 700 ms (BringIntoView.settle and its 400 ms scroll) after a tap that adds content before tapping or measuring that content; compare a rect measured through a transform with closeTo, never exactly. (Rule 61)

### 2026-10-29: The automatic scroll swallowed taps, and two reveals fought
- **Symptom:** On a phone, a tap on 擲筊 or 擲下一爻 right after it came up did nothing; and the lot card, once brought into view, was scrolled away again.
- **Root cause:** Flutter ignores taps on a list during an animated scroll (DrivenScrollActivity.shouldIgnorePointer); and the rounds card, grown by the same throw, asked for its reveal 300 ms later than the lot card.
- **Fix:** bringIntoView scrolls with its own activity that lets taps through; when several parts ask at once, the last to ask wins.
- **Rule:** Never move the page with animateTo or ensureVisible while the user may tap (a button that has just come up): use bringIntoView, whose scroll lets taps through. When one tap starts two automatic scrolls, decide which part wins (the newest) and test where the page ends. (Rule 60)

### 2026-10-29: New parts opened below the fold (tarot ritual, 风水 principles)
- **Symptom:** The owner had to scroll to find what 抽牌, 看布局 and 求签 had made: on a phone the new card opened below the fold, and nothing showed that the page had changed.
- **Root cause:** Pages added a result under the button without moving the view, and no test looked at a phone-sized screen after the tap.
- **Fix:** BringIntoView (design.dart) wraps every part a tap makes; bring_into_view_test.dart checks each page on a 360 x 740 phone and fails with the scroll turned off.
- **Rule:** Whatever a tap makes below its button (a result, a step, a card) goes inside BringIntoView, outside its FadeSlideIn, with a trigger when it grows a row per tap. Test it on a 360 x 740 phone with a test that fails when the scroll is off (owner, 2026-10-29: 新生成的component 要避免用户下滑后再点击). (Rule 59)

### 2026-10-29: New rows in 设置 pushed tested rows out of the built list
- **Symptom:** The v9.0.0 harness failed in auth_test and top_bar_test: sign-out and delete-account were not found after 设置 gained its 报告 group.
- **Root cause:** Only the new tests were run after adding the group; older tests found the rows at the foot of 设置 without scrolling, and the new content moved them below what a lazily built ListView builds on a test screen.
- **Fix:** Both tests scroll to the rows first (scrollTo, in page order); every test that opens 设置 was run before the next harness. (Recording it, add-mistake.ps1 ran with `-Project .` while the shell stood in app/ and wrote a new app/docs/agent/MISTAKES.md: it was moved here and the stray file deleted. Pass the repository root, not `.`, after any command that may have moved the shell.)
- **Rule:** After adding anything to a page, run every test that opens it (grep for its open key) before the harness, not only the new ones. A test that finds a row below the new content must scroll to it: lazily built lists drop what lies past the fold. (Rule 58)

### 2026-10-29: A result SnackBar queued behind a working one
- **Symptom:** After 发到邮箱 the test found no 已发到 message: it was waiting behind the 2-second 正在生成 SnackBar.
- **Root cause:** ScaffoldMessenger queues SnackBars: a second one shows only when the first has run its time, so the reader (and the test) waited seconds for the result.
- **Fix:** The result calls hideCurrentSnackBar() before showSnackBar(), so it takes the place of 正在生成 at once.
- **Rule:** When an action shows a 'working' SnackBar and then its result, hide the current SnackBar before showing the result: SnackBars queue, and the result would wait out the first one's duration. (Rule 57)

### 2026-10-28: Edit tool decoded \u escapes (meant for the global list: access denied)
- **Symptom:** A C++ title written as L\u547D\u7406\u5927\u5E08 through the Edit tool landed in main.cpp as the raw UTF-8 characters.
- **Root cause:** The Write/Edit tools decode a \uXXXX sequence in the text they are given; a double backslash survives.
- **Fix:** Wrote the title as UTF-16 code units, {0x547D, 0x7406, 0x5927, 0x5E08, 0}, so the file stays ASCII; test/app-icons.test.ts checks it.
- **Rule:** The Write/Edit tools turn a \uXXXX in new_string or content into the character itself. For a literal \u escape, use numeric code units instead, or build it in a script with String.fromCharCode(92), and check the bytes afterwards (od -c, or a test). (Rule 56)

### 2026-10-28: A floating button over the controls it leads to
- **Symptom:** On a 412x900 phone the floating 继续追问 sat on top of the 发送 button it had just scrolled into view, so a tap went to the floating button (v7.0.0, found by a hitTestable check).
- **Root cause:** A Positioned button over a scroll view covers whatever scrolls under its corner, its own target included; and focusing the field scrolled it into view at once, racing the animated scroll to the field and button together.
- **Fix:** The button steps aside (scale 0, IgnorePointer, ExcludeFocus) while the field and 发送 are on screen, measured on every scroll and size change (FollowUpScope); open() awaits the scroll, then focuses.
- **Rule:** A floating control must never cover what it leads to: hide it (out of the hit test and the Tab order too) while its target is on screen, and test the target with hitTestable after opening it at a phone size. When code both scrolls to a field and focuses it, await the scroll first. (Rule 55)

### 2026-10-28: A doc edited after the format check
- **Symptom:** The v6.2.0 harness failed at lint: docs/web-test.md was not Prettier-clean.
- **Root cause:** I ran prettier --check on the changed files, then added a section to docs/web-test.md and started the harness without checking again.
- **Fix:** prettier --write docs/web-test.md (it only added a blank line in a list), then the harness again.
- **Rule:** Run npx prettier --check . as the very last step before the harness, after the final edit to any Markdown, YAML or TypeScript file; a check made before a later edit proves nothing about it. (Rule 54)

### 2026-10-28: Unkeyed states in an AnimatedSwitcher
- **Symptom:** Opening a 一生运势 report from history threw Duplicate keys found in the page's AnimatedSwitcher (debug), found by the first test that took that path (v6.2.0).
- **Root cause:** From history the page goes waiting, then loading the chart, then the report; the waiting and loading states had no key, so the switcher held two unkeyed children at once. The tests only opened a report right after making it, with the chart in hand.
- **Fix:** Every state the switcher can show has its own ValueKey (waiting, loading, failed, held, error).
- **Rule:** Give every child an AnimatedSwitcher can show its own key, whenever two of them can follow each other: two unkeyed children at once are duplicate keys. Test a page along every way users reach it (from history as well as right after making it). (Rule 53)

### 2026-10-28: Names and birthplaces lived only in the browser
- **Symptom:** Signed in elsewhere, or after npm run public gave the app a new address, history and the 一生运势 report showed no name or birthplace for readings the database still kept (owner bug report, v6.2.0).
- **Root cause:** The person label was saved only in the device's profile book. Browser storage belongs to one origin, and a quick tunnel's origin changes on every run, so each run started with an empty book.
- **Fix:** The app sends the person (name, birthplace label) with the chart; the server keeps it on the chart record, sealed in the database store, out of ChartFact and away from the model, and returns it with charts, history and life reports; the app falls back to it.
- **Rule:** Anything a stored record must show on every device or after a restart (a name, a label, a choice) is kept with the record on the server, sealed like it. Browser storage is per origin, and npm run public changes the origin every run: keep only per-device conveniences there. (Rule 52)

### 2026-10-28: Grouping the home page broke the tests that tapped 塔羅 unscrolled
- **Symptom:** After 塔羅 moved into the 西方 group below 東方, five app tests failed: taps and finds on entry-tarot at phone sizes found nothing (the entry was past the list cache).
- **Root cause:** The tests tapped home entries straight after start, relying on them being in the first screen; the new order put 塔羅 sixth, below the fold of an 800x600 or phone-sized view.
- **Fix:** Added openEntry (test/support.dart): scroll the home list to the entry, then tap it; every 塔羅 entry tap goes through it, and the order tests use a tall view.
- **Rule:** A test opens a method from the home page through openEntry (scroll, then tap), never a bare tap on entry-*, so a change in the home order or grouping cannot leave an entry off the first screen. Run every test that taps a moved entry before calling a home change done. (Rule 51)

### 2026-10-28: A painted inscription came out as boxes: TextPainter has no font of its own
- **Symptom:** Rendered with Noto Sans SC loaded, the 乾隆通寶 on the 算卦 coin showed four boxes, while all the page text read right.
- **Root cause:** The coin painter built its TextStyle without a font family, so its TextPainter took the engine default (FlutterTest in tests, the platform font in the app) instead of the page font the theme gives every Text.
- **Fix:** The coin passes DefaultTextStyle.of(context).style into the painter, which draws with its fontFamily and fontFamilyFallback; the render then showed 乾 隆 通 寶 round the hole.
- **Rule:** A CustomPainter that draws text takes its font from the page: pass DefaultTextStyle.of(context).style (or the theme text style) into the painter and use its fontFamily and fallback. Look at a render with the real font loaded, not only the test font, whose boxes hide this. (Rule 50)

### 2026-10-28: Spread chips still wrapped two to a row: a chip is wider than label plus padding
- **Symptom:** With the chips given zero padding and labels of (width - 2 gaps) / 3, the tarot spread choices still went two to a row at 360 px (tops 769, 769, 879).
- **Root cause:** A chip draws its 1 px outline inside its shape, and its Ink pads the content by that inset, so a chip is its label plus 2 px. I computed the widths from the padding alone, without measuring.
- **Fix:** Measured the chips in a throwaway test (label 96 → chip 98), subtracted the 2 px edges from each label, and tested 320, 360 and 412 px plus a keyboard-focused chip (focus draws its outline outside, so it never widens a chip).
- **Rule:** Before laying out by a Material widget's size (a chip, a button), measure it in a test at the sizes that matter: its outline, density and focus side can add to label plus padding. Then pin the layout in a test at those sizes, focused too. (Rule 49)

### 2026-10-28: Commons API refused page renders after ten quick requests
- **Symptom:** Downloading scan pages of a DjVu on Wikimedia Commons: after about ten pages the API answered 「You are making too many requests to the API」 (not JSON), and every later page failed.
- **Root cause:** One imageinfo request and one thumbnail render per page, 400 ms apart: rendering DjVu pages is costly for Commons, and it rate-limits clients that ask faster than that.
- **Fix:** A downloader that waits 3 s after the API call and 5 s after each image, and on a non-JSON or failed answer waits 20 s, 40 s and so on before retrying (up to five times). The rest came through on one run.
- **Rule:** Fetch Wikimedia page renders (DjVu/PDF thumbnails) one at a time, at least 5 s apart, with retry and backoff on a non-JSON answer; ask only for the pages the check needs, and cache them. (Rule 48)

### 2026-10-28: Three 周易 transcriptions shared a 简繁 slip the print did not have
- **Symptom:** The 周易 data and both 維基文庫 copies read 系于金柅 (姤 初六) and 噬臘肉 (噬嗑 六三); the 四部叢刊 宋 print reads 繫 and 腊. Our source also had 兇, 鹹, 鬥, 後 for 后, 誌 for 志, and a line copied from the wrong hexagram (大有 九二).
- **Root cause:** Each copy was converted from 简体 at some point. Where 简体 merges two 繁體 characters (系 for 繫/係, 腊 for 臘, 后 for 後, 干 for 幹, 机 for 機), a converter picks one, and copies converted the same way pick the same wrong one, so their agreement proves nothing.
- **Fix:** Compared all 514 texts with two transcriptions and with the page transcription of a 宋 print, read the disputed readings in the scan (16 pages), and corrected 125 strings in build-yijing ERRATA, each pinned to its match count (docs/verification/zhouyi.md).
- **Rule:** In a traditional text that passed through 简体, treat every character 简体 merges (系/繫/係, 腊/臘, 后/後, 干/幹, 机/機, 斗/鬥, 里/裏, 仆/僕, 凶/兇, 志/誌) as unverified until a print or the sense settles it, even when every digital copy agrees. Find a page transcription of a scanned print (維基文庫 Page: namespace) to map the scan, then read the scan where anything differs. (Rule 47)

### 2026-10-28: A FilledButton in a Row took infinite width
- **Symptom:** liuyao_test: BoxConstraints forces an infinite width at FilledButton liuyao-reveal, and then Tab traversal failed on an inactive Focus element
- **Root cause:** The app theme gives FilledButton minimumSize Size.fromHeight(52) and OutlinedButton Size.fromHeight(48): full width. Inside a Row (beside a Spacer) that is infinite
- **Fix:** Stacked the buttons in the card's Column (the main button full width, the secondary TextButton below), as the 求籤 page does
- **Rule:** In app/, FilledButton and OutlinedButton are full width by the theme: never put one straight into a Row; give it Expanded/SizedBox or stack it in a Column. A layout exception in a widget test can surface as an unrelated failure (focus, taps): fix the first exception first. (Rule 46)

### 2026-10-28: Rewrote a formatted JSON file through JSON.stringify
- **Symptom:** Adding liuyao to schemas/chart-fact.v0.1.schema.json turned a 180-line change into 1,186 changed lines; the same happened to .harness.json
- **Root cause:** JSON.parse + JSON.stringify(…, 2) expands every compact object and array, and prettier keeps objects expanded once they are, so the whole file is reformatted
- **Fix:** Restored both from git and inserted the new parts as text (Edit, or a string insert); checked git diff --stat before going on
- **Rule:** To change a hand-formatted JSON file (schemas, configs, the matrix), insert or replace text with Edit; never round-trip it through JSON.stringify. Check git diff --stat right after: a change much larger than intended means the file was reformatted. (Rule 45)

### 2026-10-28: Documented 'no restart needed' from one code path
- **Symptom:** docs/web-test.md (v4.5.0/v5.0.0) told the owner a matrix change needs no restart; the API server (assertServed, /v1/methods, health) and AuthService sign-up loaded the matrix once at start, so switching 起名 on would have kept answering 451 until a restart
- **Root cause:** I read the pipeline's per-call loadGeoMatrix and tested the owner's steps with tests that each start a fresh server, never a server started before the change
- **Fix:** v5.1.0: the server and sign-up read the matrix per request; geo-regions.test.ts registers in ID on one running server before and after the change (fails against the cached code)
- **Rule:** Before stating how something behaves at runtime (no restart, hot update), grep every reader of it and test it the way the owner meets it: a server started before the change. A fresh process per test proves nothing about a running one. (Rule 44)

### 2026-10-28: A findsNothing proved by scrolling away
- **Symptom:** naming_test: expect(find.byKey('pillar-grid'), findsNothing) after scrolling to the page end failed: the grid was still built
- **Root cause:** I took 'scrolled down' as proof the end was reached; a ListView keeps a cache extent of built children, so widgets just off screen still exist
- **Fix:** Anchor the negative on the widget right next to where the missing one would be: scroll to life-generate (the last button above open-naming), then expect open-naming findsNothing; the paired test finds it in the same place once naming is on
- **Rule:** A findsNothing needs a positive anchor: first find the neighbour the missing widget would sit beside, and pair it with a test that finds the widget there when it should exist. Never use off-screen or scrolled-past as evidence of absence (lists cache children). (Rule 43)

### 2026-10-28: Tests pinned the state the owner's switch changes
- **Symptom:** Turning 起名 on as the owner's steps say (matrix available + version bump, LIBRARY.reviewed) would have failed 7 tests (3 of 起名's own that read the shipped matrix or LIBRARY, two matrix_version pins, two region method-list pins), and the card would still have said 仍待專家校訂
- **Root cause:** Tests asserted the shipped values of a switch meant to be flipped (reviewed:false, 0.4.0, lists without naming), and the draft note was unconditional instead of following library.reviewed
- **Fix:** withNaming(available) sets the state per test; an invariant test (on in a region => LIBRARY.reviewed); version tests read the matrix; order tests leave naming out; the note follows the chart's library.reviewed. Tried the owner's steps once, ran every test, undid them
- **Rule:** When a feature ships behind a switch the owner will flip, no test may pin the switch's shipped value: test both states with an explicit override, assert the gate as an invariant (on => reviewed), and make every on-screen trace of the gate follow its flag. Try the documented steps once, run the tests, then undo them. (Rule 42)

### 2026-10-28: Fetch tools did not return verbatim text
- **Symptom:** WebFetch declined to reproduce a page word for word; the MediaWiki query API returned content for only 10 of 50 titles
- **Root cause:** WebFetch answers through a summarising model; the query API batches page content and expects continuation
- **Fix:** Downloaded each page with action=raw into its own folder and parsed it locally
- **Rule:** For exact text, download the raw source (action=raw, the API with continue, the file itself) into its own folder; never take verbatim text from a summarising fetch. (Rule 41)

### 2026-10-28: Sent the owner email in a User-Agent header
- **Symptom:** One curl request to Wikisource carried the owner email address in its User-Agent
- **Root cause:** Followed the Wikimedia User-Agent etiquette with the owner address
- **Fix:** Every later request used a generic agent string; the owner was told
- **Rule:** Never put the owner email or any personal data in a request to an outside service, not even in a User-Agent; use a generic agent string. (Rule 40)

### 2026-10-28: Two transcriptions agreed on the same errors
- **Symptom:** A and B matched on 85 of 100 lots, yet both carried misprints (a wrong branch, non-words, a broken rhyme) that only the Qing print revealed
- **Root cause:** Both modern copies descend from one upstream text, so their agreement is not independent evidence
- **Fix:** Read all 100 lots in the primary source and settled every difference; documented in docs/verification/qiuqian-guandi-100.md
- **Rule:** To verify a traditional text, read the primary source for every item; agreement between modern copies can hide a shared error. (Rule 39)

### 2026-10-28: Wrote a file to a mistyped project folder
- **Symptom:** lots.ts landed in a new top-level folder whose name used the traditional form of the last character; the guard keeps that empty stray folder
- **Root cause:** Retyped the project path by hand instead of copying it
- **Fix:** Removed the stray contents and wrote the file at the real path
- **Rule:** Copy the project path from the environment or an earlier tool call; never retype a path with CJK characters. (Rule 38)

### 2026-10-28: A test expected a reading to be still pending
- **Symptom:** The share image endpoint test asserted 409 for a pending tarot reading and got 200: the reading had already passed.
- **Root cause:** The mock provider answers at once, so by the next request the background job has finished; a pending state is a race, not a state the test controls.
- **Fix:** The racy check was dropped; the test drains the jobs and asserts the end states (passed, another owner, another method).
- **Rule:** Against the mock provider, never assert that a report is still pending: drain the jobs and assert the end state, or give the test a provider that waits until released. (Rule 37)

### 2026-10-28: A sync-only module reached the server through the ai index
- **Symptom:** Found in v4.1.0: since v3.2.0 the ai index re-exported the term tips, and with them opencc-js, a devDependency, so every API server process loaded a dev tool; a production install without devDependencies would not have started.
- **Root cause:** An export added for one script (the app sync) to the index that the server also imports.
- **Fix:** The tips are imported from their own module by the scripts and tests that need them; test/runtime-deps.test.ts walks the server import graph and fails on any devDependency.
- **Rule:** Code that only scripts need (sync, review, build) is imported from its own module, never re-exported from an index the server imports; runtime-deps.test.ts holds the server to its dependencies. (Rule 36)

### 2026-10-28: PGlite sent an enum array parameter as a,b
- **Symptom:** The database store held list failed with malformed array literal: manual_review,blocked.
- **Root cause:** PGlite serializes a JS array only for array types it knows (text[]); for an enum array (report_status[]) it sends String(array), which PostgreSQL refuses.
- **Fix:** The held statuses are constants, written into the query.
- **Rule:** With PGlite, pass a JS array only for a column of a known array type such as text[]; for an enum array, write constant values into the SQL or pass text[] and cast it there. Probe a new parameter type in a scratch script before relying on it. (Rule 35)

### 2026-10-28: A plan item would have undone an owner decision
- **Symptom:** WP4.4 asked for a separate home entry for the life report. The owner had asked on 2026-10-27 to move it inside the bazi form, and the home card was removed then. Caught before any code, from the commit history.
- **Root cause:** The plan was written from a review of the app as it was, without checking why it was that way; the DEVLOG line read Improve, not Improve (owner).
- **Fix:** WP4.4 closed with the reason; the DEVLOG line now names the owner request.
- **Rule:** Before building a plan item, search the DEVLOG, the README and git log for an owner decision on the same thing (owner, Owner request); a plan item never overrides one. Label owner requests as such in the DEVLOG. (Rule 34)

### 2026-10-28: A key built from a nullable id matched nothing
- **Symptom:** The new timeline tests found no item by its key, and tabTo never reached it: Tab ran 60 stops and ended elsewhere.
- **Root cause:** ValueKey(s.id) with a String? id is a ValueKey<String?>; it equals no ValueKey<String>, and focusedKey() only names ValueKey<String>.
- **Fix:** The item key is built as ValueKey<String>(s.id!).
- **Rule:** Give widget keys an explicit type, ValueKey<String>(id), never ValueKey(x) on a nullable value: a ValueKey<String?> matches no find.byKey(Key(...)) and focusedKey() ignores it. (Rule 33)

### 2026-10-28: A non-empty check accepted an empty string
- **Symptom:** The new term tips test checked that every tip has text with expect.any(String); an empty tip would have passed. Caught on review, before any tip was empty.
- **Root cause:** expect.any(String) checks only the type, and an empty string is a String.
- **Fix:** Each script is checked with `expect(text.trim(), name).not.toBe('')`.
- **Rule:** To check that text is not empty, assert `expect(text.trim()).not.toBe('')`: `expect.any(String)` also matches `''`. Read each new assertion once for what it would let through. (Rule 32)

### 2026-10-28: 简体 copy quoted with 「」
- **Symptom:** locale_test failed: the new 简体 ritual hint read 按「洗牌」
- **Root cause:** I wrote the 简体 string by changing the 繁體 one, which quotes with 「」; Mainland copy uses “”
- **Fix:** The 简体 string quotes with “洗牌”; the 繁體 keeps 「洗牌」
- **Rule:** In 简体 copy (app_zh.arb, 简体 prompts), quote with “”, never 「」; write each script on its own instead of converting, and let locale_test check. (Rule 31)

### 2026-10-28: A tsx scratch script failed three times before it ran
- **Symptom:** A measuring script in the scratchpad failed with top-level await in cjs, then ERR_UNSUPPORTED_ESM_URL_SCHEME as .mts, then digest pepper must be >= 32 bytes
- **Root cause:** Outside the package tsx runs a .ts file as CommonJS; as ESM, absolute Windows paths need file:// URLs; the pepper was a made-up short string
- **Fix:** A .ts file with an async main(), absolute C:/ imports of src, and PEPPER imported from test/helpers.ts
- **Rule:** Write scratch tsx scripts as .ts with an async main() in the project root with relative imports, and take test constants (PEPPER, FIXED_NOW) from test/helpers.ts instead of making them up. (Rule 30; corrected in v4.3.0: absolute C:/ imports fail there as ESM)

### 2026-10-28: The faithfulness check did not know the new 干支 facts
- **Symptom:** Since v1.3.0 the model saw 胎元 and the 流月 (both 干支), but checkFaithfulness would flag either as unknown_ganzhi; found while measuring what the model reads (WP2.3)
- **Root cause:** knownGanzhi in faithfulness.ts lists pillars, 大运, 流年 and the 农历 year; nobody extended it when the engine added 干支-valued facts
- **Fix:** knownGanzhi adds taiyuan and every liuyue month; a test names 庚寅 (2026 寅月) and 胎元 庚午
- **Rule:** When the engine adds a fact that holds 干支, extend knownGanzhi in src/ai/faithfulness.ts in the same change, with a test that names one. (Rule 29)

### 2026-10-27: Trend notes called every 刑, 害 and 破 「刑害」
- **Symptom:** The 2026 丙午 note for the sample chart said 「与日支有刑害」, but 卯午 is 相破; found while taking a release-note example from real output
- **Root cause:** The day-branch template grouped 相刑, 自刑, 六害 and 相破 under one wording, and no test read a note
- **Fix:** The template names the relation itself (六害 reads 相害); a test pins the 相破 and 相害 notes
- **Rule:** In user-visible text, name each 合冲刑害破 relation by its own type, never several types under one name; pin generated notes in a test, and take release-note examples from real output. (Rule 28)

### 2026-10-27: Back-to-back scrollUntilVisible skipped the next card
- **Symptom:** A chart-page test found the strength pills, then scrollUntilVisible for the 神煞 card right below them dragged to the end of the list: Bad state: No element
- **Root cause:** scrollUntilVisible ends on Scrollable.ensureVisible without a frame; the next call checked the layout of the old offset (card not on screen yet) and its first 300 px drag carried the list past the card before it was ever laid out (finders only see sliver children on screen). Probe: px 907 after the jump, 1207 after one drag, card never found
- **Fix:** scrollTo() in app/test/support.dart pumps a frame before and after scrollUntilVisible. In v2.3.0 the same gap broke two phone tests: ensureVisible, then a tap that went to y 873 on an 800-px screen (the card's place before the jump, once the focus chips made the page taller); a pump after ensureVisible fixed it
- **Rule:** Pump a frame after scrollUntilVisible or tester.ensureVisible, before the next finder, tap or scroll: both jump without a frame, so the next step sees the old layout (a tap goes to the old position). Use scrollTo() from test/support.dart for each card. (Rule 27)

### 2026-10-27: Edits to synced sources need sync:app before app tests
- **Symptom:** New 神煞 terms showed untranslated (禄神 instead of 祿神) in an app test
- **Root cause:** i18n/terms.json was edited after the last npm run sync:app, so app/assets/i18n/terms.json was stale
- **Fix:** npm run sync:app, then the test passed
- **Rule:** After editing anything sync:app copies (i18n/terms.json, deck.ts, engine output behind fixtures), run npm run sync:app before running app tests. (Rule 26)

### 2026-10-27: scrollUntilVisible only scrolls one way
- **Symptom:** A chart-page test checked the 流年 strip, then looked for the 神煞 card above it: Bad state: No element
- **Root cause:** scrollUntilVisible with a positive delta only scrolls down; the card above had been scrolled past (and disposed by the lazy list)
- **Fix:** Check the cards in page order, top to bottom
- **Rule:** In a lazily built page, look for widgets in page order (top to bottom) with scrollUntilVisible; to go back up, use a negative delta. (Rule 25)

### 2026-10-27: A second pumpWidget of the same app keeps its state
- **Symptom:** A layout test drew cards at 360 wide, then pumped testApp again at 1000 wide; the tap on 首页 entry-tarot found nothing
- **Root cause:** pumpWidget with the same widget types updates the tree in place, so the Navigator (and the tarot page on top) survived
- **Fix:** pumpWidget(const SizedBox.shrink()) before pumping the new app
- **Rule:** To start a fresh app within one widget test, pump an empty widget first; pumping testApp again keeps the old Navigator and state. (Rule 24)

### 2026-10-27: Flutter deletes the l10n files after a run from another path
- **Symptom:** The harness app gate failed at analyze with lib/l10n/gen/app_localizations*.dart missing, in v1.1.0 and again in v1.1.1, each time after app/pubspec.yaml changed
- **Root cause:** Flutter's build records where it last generated the l10n files; a run from another path (the app gate's fresh junction) deletes the files recorded under the old path as stale. That only bites when the old path still exists: the IDE's automatic pub get on the real path after a pubspec edit, or the kept scratchpad junction. A first guess (the first pub get after a pubspec change) was wrong: pub get + gen-l10n right after the edit did not prevent the v1.1.1 failure
- **Fix:** flutter gen-l10n restored the files unchanged each time; a second harness run passed each time, because the last recorded path was then the first run's junction, already removed. In v2.0.0 the guard refused to remove the scratchpad junction (it resolves to the repo); the first harness run failed at analyze and the second passed, as before
- **Rule:** Flutter deletes lib/l10n/gen as stale when pub get, test or build runs from another path than its last run and that path still exists (the IDE on the real path, a kept junction). Do manual Flutter runs through a junction you remove afterwards; the guard blocks `cmd /c rmdir` on a junction that points at the repo, so when it can't be removed, leave it and expect the next harness run to need a second try. After a pubspec edit or manual runs, if the harness fails at analyze with app_localizations missing, run it once more. (Rule 23)

### 2026-10-27: Golden images are captured at logical size
- **Symptom:** Cropping a tarot golden at 2x coordinates failed (bad extract area): the PNG was 400x1250, not 800x2500
- **Root cause:** Assumed matchesGoldenFile renders at tester.view.devicePixelRatio; it captures the repaint boundary at 1x logical pixels
- **Fix:** Cropped at logical coordinates; the art had already been checked at full size on its own
- **Rule:** matchesGoldenFile captures at 1x logical pixels whatever tester.view.devicePixelRatio is; to inspect high-DPI detail, render with RenderRepaintBoundary.toImage(pixelRatio:) instead. (Rule 22)

### 2026-10-27: flutter test --platform chrome never loads on this machine
- **Symptom:** Failed to load: Connection closed before test suite loaded, then the run hung until the timeout; an untouched existing test failed the same way.
- **Root cause:** The browser test runner cannot load suites here (environment, not the code). Meant for the global list, which this session could not write.
- **Fix:** Web key handling verified through VM tests, explicit ButtonActivateIntent and ActivateIntent handling, and the web build gate.
- **Rule:** Don't rely on flutter test --platform chrome here; if tried, time-box it and end only its own processes (command line contains flutter_tools_chrome_device). (Rule 21)

### 2026-10-27: A closed DropdownMenu still had its entries in the tree
- **Symptom:** find.text(entry) found a widget after Esc closed the dropdown.
- **Root cause:** DropdownMenu keeps an invisible copy of its entries to size itself.
- **Fix:** Check open menu entries with find.text(...).hitTestable().
- **Rule:** Check whether a DropdownMenu is open with find.text(entry).hitTestable(), never a plain find.text. (Rule 20)

### 2026-10-27: Key pressed right after enterText met the old page
- **Symptom:** Esc right after tester.enterText left the page without the 返回将重新开始 question.
- **Root cause:** enterText doesn't pump: the setState that switches the guard on had not rebuilt PopScope when the key arrived.
- **Fix:** test/keys.dart press() pumps a frame before sending the key, as real time always passes between inputs.
- **Rule:** In widget tests, pump a frame between enterText (or any setState) and the next key press; use press() from test/keys.dart. (Rule 19)

### 2026-10-27: Esc in a text field did nothing on a page
- **Symptom:** With focus in a TextField, Esc neither went back nor closed anything.
- **Root cause:** EditableText answers DismissIntent itself (to hide its toolbar) and is always enabled, so Esc stopped there; the route's own Esc action is disabled on full pages.
- **Fix:** keyboard.dart _layerAt looks for an open layer above the focused text field, then falls back to popping the page.
- **Rule:** Esc handling must look past a focused text field's own DismissIntent (keyboard.dart _layerAt); test Esc from inside a field. (Rule 18)

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
