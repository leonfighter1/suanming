# 命理大师 管理后台

The admin dashboard (tech plan S22): a Flutter web app, separate from the app in `app/`, for the accounts, AI use and
money of 命理大师. Only an admin signs in: an account with the admin role, or a login in the server's `MINGLI_ADMINS`.

- **概览**: the period's 充值 revenue, AI cost, gross profit and margin, accounts, active users, tokens and 积分, the
  revenue curve and what each kind of AI job cost.
- **用户**: every account, searched, filtered and sorted. Each account's page suspends it, makes it an admin, turns its
  AI or 充值 off, adds 积分 (with a note), signs it out everywhere, and lists its 积分 ledger and AI jobs.
- **活跃**: who used the app in the last 15 minutes and 24 hours, refreshed every minute.
- **收益**: the revenue curve, each day or added up (PNG and CSV), and every day's numbers.
- **用量**: tokens and cost per day, per kind of job and per model.
- **导出**: the 经营报表 as PDF or Word, the revenue curve and the accounts as CSV.

It reuses the app's theme, cards and keyboard layer (`package:mingli_app`, a path dependency): Tab, Enter, Esc, ←/→
and Ctrl+/ work as in the app. The numbers come from the admin API (`/v1/admin/*`, api/openapi.yaml, tag admin).

## Running it

The API serves the built dashboard at `/admin/` (`npm run admin:build`, then `npm run dev:api`); docs/web-test.md has
the steps and the demo accounts. Flutter on this machine needs an ASCII path, so run it through a junction to the repo
root (CLAUDE.md rule 7). Which API it calls: `?api=<url>` on the page, else `--dart-define=API_BASE_URL=<url>`, else
the page's own server when it is served under `/admin/`, else `http://127.0.0.1:8787`.

Tests: `flutter test` (a fake admin API, no server); the harness runs analyze, the tests and a web build.
