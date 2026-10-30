# 重构计划：restructuring and refactoring (tech plan S28)

**Owner requests (2026-10-30):**

- 「Update SKill of coding, require coding using existing functionalities or mehtods as much as possible. refactoring
  the code structure，everytime make change, do little change as much as possible.」 That became the coding skill,
  [.claude/skills/coding](../.claude/skills/coding/SKILL.md) (S27).
- 「有没有根据skill进行代码重构？没有的画请继续」
- 「prepare tech documents to plan the restructuring and refactoring」

This document is the survey and the plan. The stage and its work packages are S28 in [tech-plan.md](tech-plan.md); the
status table there tracks them.

## Goal

- **One home for each thing:** every repeated block found below moves to one module, its callers point at it, and the
  copies go.
- **Structure where a file holds too much:** the API's routes leave `src/api/server.ts` for modules of their own, as
  the 管理后台's already did (`src/admin/routes.ts`).
- **No behaviour change.** Users see nothing new. The same API answers, the same screens, the same words sent to the
  model.

## Rules for every step

1. **The coding skill:** use what exists, one home for each thing, the smallest change, and read the diff.
2. **No behaviour change.** A step that changes behaviour is not a refactoring step: it waits for its own request.
   - API: every server test passes unchanged; `api/openapi.yaml` doesn't change.
   - App: every app test passes unchanged; the touched screens render the same (PNGs compared before and after).
   - AI:
     - released prompt texts stay as they are (`test/method-prompts.test.ts` pins their hashes);
     - every user message a builder makes stays byte for byte the same;
     - `npm run sync:app` leaves `app/test/fixtures` unchanged.
3. **One concern per commit.** A move and an extraction are separate commits; no test's expectations change, only its
   helpers move.
4. **The smallest diff.**
   - Move code verbatim and never reformat (rules P15, 45). `git diff -w --stat` lists only the step's files.
   - Keep public names. When one must change, change its callers in the same commit.
5. **Each method stands alone** (CLAUDE.md rule 8). Shared homes are only for mechanics: HTTP, routing to a model,
   envelopes, test set-up. A method's prompts, rules and engine stay its own.
6. **The 管理后台 looks as it does** (owner: 「管理员界面就不用改了」): internal moves only, and its tests' measurements
   unchanged.
7. **Generated and data files are never edited:** `app/lib/l10n/gen`, `app/test/fixtures`, `app/assets`, the tarot
   art, the verified texts.
8. **MODULES.md** gets a row for every new home in the step that makes it.
9. **Tests before and after each step:** the ones that cover it, then the whole suite. The harness runs at each
   release (dev-workflow).

## How the survey was done

A throwaway scan (`dupes.mjs`, in the scratchpad, not the repository) read 391 files in `src`, `test`, `scripts`,
`app/lib`, `app/test`, `admin/lib` and `admin/test`. It looked for blocks of six or more identical significant lines
(comments, imports and lone brackets left out) in two places or more, and found 260 such pairs:

| Area                        | Repeated blocks |
| --------------------------- | --------------- |
| Server tests (`test/`)      | 167             |
| Server code (`src/`)        | 37              |
| App tests (`app/test/`)     | 29              |
| App code (`app/lib/`)       | 18              |
| 管理后台 code (`admin/lib`) | 4               |
| Scripts                     | 3               |
| Across areas                | 2               |

Reading found more that differ too much for the scan, such as a helper copied with another frame count. The largest
files show where structure is missing:

| File                           | Lines | What it holds                                     |
| ------------------------------ | ----- | ------------------------------------------------- |
| `src/api/server.ts`            | 2647  | every route but the 管理后台's, in one closure    |
| `src/ai/prompts.ts`            | 1783  | every method's released prompts and user builders |
| `src/db/pg-store.ts`           | 949   | the database store                                |
| `src/ai/pipeline.ts`           | 838   | the reading pipeline                              |
| `app/lib/domain/models.dart`   | 901   | most of the app's models                          |
| `app/test/support.dart`        | 775   | the app's fake server and helpers                 |
| `admin/lib/domain/models.dart` | 684   | the 管理后台's models                             |

## Findings

### Server code

- **F1 One closure for every route.** `createApiServer` (`src/api/server.ts:524`) holds:
  - the helpers: the quotas, the points holds, the jobs, the Geo-Rule check;
  - and the dispatch: an `if` chain over the route groups (calendar, places, auth, methods, account, 积分, 内容审核,
    一生运势报告, 以往记录, 深度分析, 追问, 破除运势, the cards of the day, reports and charts).

  Only the 管理后台's routes have a module (`adminRoute(ctx, req, res, path, user)` with an `AdminContext`).

- **F2 The AI entry points repeat their mechanics.** These are not method logic:
  - choosing a model for an agent (`providerFor`): `followup.ts:157-167`, `inquiry.ts:164-174`;
  - the guard's verdict: `followup.ts:339-356`, `inquiry.ts:347-364`, `pipeline.ts:761-778`, `remedy.ts:261-272`,
    `life.ts:436-441`;
  - the disclosure and compliance envelope: `followup.ts:369-381`, `inquiry.ts:380-391`, `pipeline.ts:801-813`,
    `life.ts:457-464`.
- **F3 Requests on a chart repeat their preamble:** read the body, check `chart_id`, load the chart, check whose it is
  (`server.ts` `createInquiry`, `createLifeReport` and `createReport`, at 1380, 1535 and 1733).
- **F4 The two cards of the day repeat their get-or-create** (`server.ts`: `/v1/tarot/daily`, `/v1/east/daily`).
- **F5 Both ledgers do a points hold's arithmetic:** `src/points/ledger.ts:118-126` and `164-171`, and
  `src/db/pg-store.ts:646-654` and `704-709`.
- **F6 The share images repeat their text rendering:** `src/share/qiuqian-image.ts:55-66`, `tarot-image.ts:63-74`.
- **F7 The user-message builders repeat their closing lines** (the sections, the language, the region line, the
  feedback): `prompts.ts:1481-1487`, `1514-1520`, `1547-1553` and `1580-1586`; also `1413-1421`/`1451-1459` and
  `1604-1610`/`1635-1641`.
- **F8 The 管理后台's numbers repeat a sum:** `src/admin/stats.ts:222-228`, `280-286`.

### Server tests and scripts

- **F9 Thirty test files start the API by hand.** Each one creates the server with the test secrets and the mock under
  both provider keys, listens on port 0, builds the base address, closes it after, and writes its own `get` and `post`.
  Examples: `api-server.test.ts:10-23`, then followup, inquiry, life-report, places, trend-remedy, archive, fengshui,
  qiuqian-reading, share-image, daily-card, east-daily, auth, logins, report-mail, ask-first and cors.
- **F10 The AI tests repeat their set-up:** `ai-pipeline.test.ts:20-32`, `trend-remedy.test.ts:12-24`,
  `bazi-ai-reading.test.ts:23-33`.
- **F11 The verification statistics and scripts repeat their helpers:**
  - `test/oracle/liuyao-stats.ts:24-39`, `qiuqian-stats.ts:14-29`, `tarot-stats.ts:34-50`;
  - `scripts/verify-liuyao.ts`, `verify-qiuqian.ts`, `verify-tarot.ts`, at 17-27.

### App code

- **F12 塔罗, 求签 and 算卦 repeat 有所求:**
  - the question's listener: `tarot_page.dart:60-72`, `qiuqian_page.dart:50-62`, `liuyao_page.dart:68-80`;
  - the start of a draw: `liuyao_page.dart:93-98`, `qiuqian_page.dart:70-75`.
- **F13 A numbered step repeats:** `qiuqian_page.dart:315-327` (the rounds) and `widgets/principles_card.dart:44-56`.
- **F14 Busy, error and SnackBar handling repeats** around a request: `bazi_form_page.dart:90-99`,
  `naming_page.dart:52-61`, `review_page.dart:137-146`, `settings_page.dart:234-242` and more.
- **F15 The cards of the day repeat their layout:** `DailyCard` in `daily_card.dart`, `EastDailyCard` in
  `daily_east.dart`. The device's date key repeats too: `dailyCardProvider` and `eastDailyProvider` in
  `providers.dart`, and `_two`/`_local` in `liuyao_page.dart`.
- **F16 Smaller repeats inside one file:**
  - `life_export.dart` 102-107, 247-252 and 373-378;
  - `profiles_page.dart` 114-122 and 216-224;
  - `archive_actions.dart:26-31` and `report_page.dart:47-52`.

### App and 管理后台 tests

- **F17 Twenty-seven app test files define their own `settle`** (10, 12 or 14 frames of 100 ms), and four their own
  `scrollAndTap`. Other set-up repeats too: `term_tips_test`/`timeline_test`, `reading_page_test`/`tarot_spread_test`,
  `locale_test`/`theme_test`.

### 管理后台 code

- **F18 Two repeats:**
  - `widgets/dashboard.dart` builds the panel's card twice (64-71, 98-105);
  - `overview_page.dart:73-80` and `usage_page.dart:29-36` repeat a block.

## Where things go

| Home                                               | Takes                                                                                                |
| -------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `src/api/routes/<group>.ts`                        | each route group, as `<group>Route(ctx, req, res, path, caller): Promise<boolean>` (F1)              |
| `ApiContext` (`src/api/context.ts`)                | what the groups share: store, options, now, log, quotas, holds, jobs, the Geo-Rule check             |
| `src/ai/envelope.ts`                               | `providerFor`, the guard's verdict, the disclosure and compliance envelope (F2)                      |
| `test/api.ts`                                      | `testApi(options, onBase)`: the server for a file or a describe, its address, closed after (F9, F10) |
| `test/oracle/stats.ts`, `scripts/verify-common.ts` | the statistics and the scripts' shared parts (F11)                                                   |
| `app/test/support.dart`                            | `settle(tester, [frames])`, `scrollAndTap` (F17)                                                     |
| App widgets and helpers                            | a numbered step, the card of the day's tile, the date key, 有所求's listener (F12, F13, F15)         |

## Phases and work packages

The safest and most repeated go first. Each WP is one commit, or one per group for a long one. Each release runs the
harness.

### Phase A: test helpers (no version: tests and scripts only)

No app or server code changes.

- **WP28.1 `testApi` for the server tests (F9, F10).** The helper serves the file, or the describe it is called in.
  A file whose slow steps come before its HTTP tests keeps its own late start (rule 81). Move the files over a few at
  a time, each file's assertions unchanged; a server of another shape stays as it is.
  - Accept: the 696 server tests pass; the scan's server-test count falls from 167 to under 40.
  - Done: 20 files, 260 → 123 blocks in all, server tests 167 → 30.
- **WP28.2 The app tests' `settle` and `scrollAndTap` (F17).** `settle` was a copy of `keys.dart`'s
  `frames(tester, n)`, so each file now calls `frames` with its own count, and no test's timing changes.
  `scrollAndTap` goes to `support.dart`, with `after` and `n` for the copies that differed.
  - Accept: the 265 app tests pass.
- **WP28.3 The statistics' and verify scripts' shared helpers (F11):** `test/oracle/stats.ts` and
  `scripts/verify-run.ts`.
  - Accept: the verify gates pass with the same results; their JSON differs only in its time and seconds.

### Phase B: small code homes (→ v16.1.0)

- **WP28.4 App (F12, F13, F15, F16):**
  - the numbered step widget;
  - one tile for the cards of the day;
  - `dateKey(DateTime)`;
  - 有所求's listener as one helper the three pages use;
  - the repeats inside `life_export`, `profiles_page` and `archive_actions`.
  - F14's error handling is shared only where the blocks are the same; where pages differ, they stay as they are.
  - Accept: the app tests pass; the touched screens render the same (PNGs before and after, both themes).
- **WP28.5 Server (F3–F6, F8):**
  - `ownedChart(body, caller)`;
  - one get-or-create for the cards of the day;
  - one function for a hold's arithmetic that both ledgers call;
  - the share images' text;
  - the 管理后台's sums.
  - Accept: the server tests pass. The share images' bytes are the same for the tests' readings, since sharp
    renders deterministically with the same font.

### Phase C: the AI mechanics (→ v16.2.0)

- **WP28.6 `src/ai/envelope.ts` (F2).** Every entry point (`generateReport`, `generateRemedy`, `generateLifeReport`,
  `generateFollowUp`, `generateInquiryTurn`) keeps its name, prompts and steps (CLAUDE.md rule 2), and takes the
  mechanics from one home.
  - Accept: the AI tests pass unchanged; `npm run sync:app` leaves the fixtures unchanged; the pinned prompt hashes
    are unchanged.
- **WP28.7 The builders' closing lines (F7).** One helper writes the closing lines; each builder keeps its own tags.
  - First, a test records every builder's output for fixed inputs, for every method and locale. It must pass before
    the change and after.

### Phase D: the API's structure (→ v17.0.0, the stage's end, pushed)

- **WP28.8 `ApiContext` and the first route group.** The calendar and places routes are stateless, so they go first.
  - Accept: the server tests pass; the dispatch order is unchanged.
- **WP28.9 The other groups, one commit each,** in this order: auth and account; 积分; 以往记录 and documents; the
  cards of the day; charts and reports; 深度分析; 追问; 破除运势; 一生运势报告; 内容审核.
  - Accept: each commit passes the server tests; `server.ts` ends under 900 lines; `api/openapi.yaml` is unchanged.
- **WP28.10 The 管理后台's panel card (F18):** one builder for its two places. Accept: `dashboard_test`'s measurements
  are unchanged.
- **WP28.11 Records:** MODULES.md, the scan's counts, the stage summary, the README entry (users see no change).
  Pushed after a fresh harness PASS.

## Measures

| Measure                    | Now  | After A | After B | After C | After D |
| -------------------------- | ---- | ------- | ------- | ------- | ------- |
| Repeated blocks (the scan) | 260  | < 110   | < 80    | < 60    | < 60    |
| `src/api/server.ts` lines  | 2647 | 2647    | < 2550  | < 2550  | < 900   |
| Server tests passing       | 696  | 696     | 696     | 696     | 696     |
| App tests passing          | 265  | 265     | 265+    | 265+    | 265+    |

App tests may only grow: a new home can get a test of its own.

## Not in this stage

- **Released prompt texts.** A new text is a new version, and this stage makes none.
- **Merging any method's prompts, rules or engine** with another's (rule 8).
- **The 管理后台's look.**
- **Generated and data files.**
- **Formatting-only edits, or renames for taste.**
- **The engines' algorithms.**
- **Later candidates,** each a move with no change: splitting `prompts.ts` per method (its texts are pinned), and
  `app/lib/domain/models.dart` by method. They are listed here, not planned.

## Risks

| Risk                                                                | Guard                                                                                       |
| ------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| A moved route matches in another order                              | keep the dispatch order exactly; one group per commit; the route's tests run on each commit |
| A route group needs state the closure held (quotas, jobs, holds)    | `ApiContext` passes the same objects, never copies                                          |
| A shared test helper hides what a test checks                       | the helper only starts and stops; each test keeps its own assertions                        |
| An app helper changes a page's widget tree (keys, focus, Tab order) | the keyboard tests and the renders before and after                                         |
| A model sees a different message                                    | the byte-for-byte test of every builder (WP28.7); the fixtures from `sync:app` unchanged    |
| The harness meets rule 23                                           | bump the version before the last manual Flutter run                                         |
