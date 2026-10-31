# 命理大师 管理后台

The admin dashboard (tech plan S22): a Flutter web app, separate from the app in `app/`, for the accounts, AI use and
money of 命理大师, and the mail and SMS it sends. Staff sign in (tech plan S25): an admin (the admin role, or a login in
the server's `MINGLI_ADMINS`) sees and does everything; a manager sees the numbers and the accounts and gives roles and
permissions, but never touches a user's data (no 增加积分, no signing out, no exports); an editor (网站编辑, the integrator
before v24.0.0) gets 消息 and 修改页面内容.
The server decides; each page leaves out what the role may not do.

- **概览**: the period's 充值 revenue, AI cost, gross profit and margin, accounts, active users, tokens and 积分, the
  revenue curve and what each kind of AI job cost.
- **用户**: every account, searched, filtered and sorted. Each account's page suspends it, gives it a role, turns its
  AI or 充值 off, adds 积分 (with a note), signs it out everywhere, and lists its 积分 ledger and AI jobs.
- **活跃**: who used the app in the last 15 minutes and 24 hours, refreshed every minute.
- **收益**: the revenue curve, each day or added up (PNG and CSV), and every day's numbers.
- **用量**: tokens and cost per day, per kind of job and per model.
- **导出**: the 经营报表 as PDF or Word, the revenue curve and the accounts as CSV.
- **消息**: each mail and SMS the server sends, per language: edited with its values as chips, checked as it is typed,
  previewed beside the editor (the mail's own page, light or dark as the dashboard is), saved or reset to its default,
  sent as a test to the dev outbox; and the latest sends.

On a wide window every page keeps to one centred container (1440 at most), its panel a card beside the main column.

It reuses the app's theme, cards and keyboard layer (`package:mingli_app`, a path dependency): Tab, Enter, Esc, ←/→
and Ctrl+/ work as in the app. The numbers come from the admin API (`/v1/admin/*`, api/openapi.yaml, tag admin).

## Running it

From the repository root: `npm run admin:build` builds it into `admin/build/served`, and `npm run api` serves that at
**http://127.0.0.1:8787/admin/** (sign in as `admin` / `admin`); docs/web-test.md has the details and the demo
accounts. `admin/build/web` is the harness's own build, for "/": it isn't served.

For development, `flutter run -d chrome` here, against `npm run api`. Flutter on this machine needs an ASCII path, so
run it through a junction to the repository root (CLAUDE.md rule 7), and don't leave the junction behind (MISTAKES
rule 74). Which API it calls: `?api=<url>` on the page, else `--dart-define=API_BASE_URL=<url>`, else the page's own
server when it is served under `/admin/`, else `http://127.0.0.1:8787`.

Tests: `flutter test` (a fake admin API, no server). The harness gate `scripts/check-admin.ps1` runs pub get,
analyze, the tests and a web build.
