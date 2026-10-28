# Web test on GitHub Pages

URL: **https://leonfighter1.github.io/suanming/**

The workflow `.github/workflows/pages.yml` builds the Flutter app for the web on every
push to `main` that touches `app/`, and publishes it to Pages. You can also run it by
hand from the Actions tab (**pages → Run workflow**).

## One-time setup (repository owner)

1. Settings → Pages → Build and deployment → Source: **GitHub Actions**.
2. Optional: Settings → Secrets and variables → Actions → **Variables** →
   `API_BASE_URL` = the public URL of a hosted API. Then re-run the workflow.

## Which API the page calls

The page is static. It calls the v1 API; it never holds the DeepSeek key.

| `API_BASE_URL` variable                   | Who can test                                                                    |
| ----------------------------------------- | ------------------------------------------------------------------------------- |
| not set (default `http://127.0.0.1:8787`) | Only someone running the API on the same computer as the browser: `npm run api` |
| a hosted API URL (https)                  | Anyone with the link                                                            |

Local API with the Pages page (Chrome or Edge):

```
npm run api        # allows http://localhost and https://leonfighter1.github.io
```

Then open the Pages URL and sign in with a dev account (`admin`/`admin`,
`xumei`/`xumei`, `test@mingli.local`/`Test-12345678`). The API also answers Chrome's
Private Network Access preflight, so the https page may call the local http API.
Safari blocks this mixed content; for phones see below.
To allow other origins: `MINGLI_CORS_ORIGINS=https://a.example,https://b.example npm run api`.

## Public test URL from this computer: `npm run public`

```
npm run public            # --skip-build to reuse app/build/web
```

1. Builds the web app with `API_BASE_URL=origin`.
2. Starts the API in `--public` mode on 127.0.0.1:8787. It also serves the app, so app
   and API share one https origin (no CORS, no mixed content).
3. Opens a Cloudflare quick tunnel and prints `https://….trycloudflare.com`. Anyone can
   open it on any network. It works while the command runs; the URL changes each run.
   The first run downloads the official `cloudflared` release into `.cache/bin`.

Staying up:

- while it runs, the computer is kept awake (`scripts/keep-awake.ps1`, the standard
  Windows "system required" request; no admin, no settings changed). Before this, the
  30-minute sleep timer cut the tunnel and the URL died. Closing a laptop lid can still
  sleep it, depending on the lid setting;
- if the tunnel drops anyway (network change), a new one starts by itself and the new
  URL is printed. A quick tunnel's URL never comes back: share the new one;
- if the API stops, the command stops and says so.

A fixed address needs a named tunnel on your own domain (see below).

Public mode protections:

- the `X-Dev-User` shortcut is off: everyone signs in;
- login limits use the visitor's IP (`CF-Connecting-IP`), not the tunnel's 127.0.0.1;
- AI jobs (reports + 破除運勢) are capped per account and in total per day:
  `MINGLI_AI_DAILY_PER_USER` (default 10), `MINGLI_AI_DAILY_TOTAL` (default 100).
  This bounds DeepSeek spend;
- data is in memory: a restart clears accounts that testers registered, and their readings.

The dev accounts (`admin`/`admin`, `xumei`/`xumei`) exist in public mode too. Anyone who
knows them can use them, within the AI caps.

## Phone on the same Wi-Fi (no hosting needed)

`127.0.0.1` on a phone is the phone itself, so a phone can never reach the default
address. Serve both the app and the API on the computer's Wi-Fi address instead:

```
npm run api:lan                       # prints the address, e.g. http://192.168.1.5:5000
cd app && flutter run -d web-server --web-hostname 0.0.0.0 --web-port 5000
```

Open the printed `http://<computer's Wi-Fi address>:5000` on the phone. The app then
calls the API on the same host (port 8787) by itself. Windows may ask once to allow
Node.js and Dart on private networks: allow it. In this mode the `X-Dev-User`
shortcut is off, since other machines can reach the API: sign in with a dev account.

## Pages URL with any API: `?api=`

Add `?api=<API base URL>` to the page URL, e.g.
`https://leonfighter1.github.io/suanming/?api=https://xxxx.trycloudflare.com`.
An https page can only call an https API (browsers block http from https), so for
phones expose the local API through an https tunnel, or host it.

## The DeepSeek key

The key never goes into GitHub for this. The Pages build is public static files, so a
key in it would be readable by anyone. GitHub Actions doesn't need it either: CI runs
the mock provider. The key belongs only to whatever runs the API:

- local / LAN testing: `DEEPSEEK_API_KEY` in `.env` (git-ignored), already in place;
- a hosted API later (Render, Fly.io, Cloud Run, …): the host's secret / environment
  variable settings, then that API's https URL goes into `API_BASE_URL`.

## Mock or real AI: `IS_AI_MOCK`

To save tokens, the API can answer every AI step with the built-in mock: readings,
trend scores, 破除运势 plans and the 一生运势报告 come back at once, each line marked
（示范）. The switch is in `.env`:

| `.env`                                    | AI answers with               |
| ----------------------------------------- | ----------------------------- |
| `IS_AI_MOCK=TRUE`                         | the mock, no tokens spent     |
| `IS_AI_MOCK=FALSE` and `IS_AI_MODEL=TRUE` | the real model (DeepSeek key) |
| `IS_AI_MODEL=FALSE`                       | the mock as well              |

- The running API re-reads `.env` when it changes: the next reading follows, with no
  restart, so the public URL stays the same. The API console prints `AI switched: …`,
  and `/v1/health` shows `"ai": "mock"` or `"ai": "deepseek"`.
- Readings made while the mock was on keep their （示范） text, preloaded 破除运势
  plans included; make a new reading after switching.
- While the mock answers, the daily AI caps of public mode don't count.
- A variable set in the shell itself wins over `.env`. `npm run eval:ai -- --live`
  refuses to run while the switch says mock.

## Keep readings and accounts across restarts: `MINGLI_STORE` (v4.1.0)

By default the API keeps everything in memory: a restart loses every account and reading. The
database store keeps them, encrypted, in a folder on this computer. It is off until you turn it on:

1. `npm run keygen` prints five lines. Paste them into `.env`:
   - `MINGLI_STORE=pglite` turns the store on.
   - `MINGLI_DATA_KEY` is the key everything is encrypted under.
   - `MINGLI_DIGEST_PEPPER`, `MINGLI_TAROT_DRAW_KEY` and `MINGLI_JWT_SECRET` are fixed keys, so email
     sign-in, tarot replays and sign-in tokens survive a restart.
2. Restart the API. The console says `data: kept in .data, encrypted`. `MINGLI_DATA_DIR` picks
   another folder.

- **Back up `MINGLI_DATA_KEY`.** Without it, nothing in the folder can be read, by design. A
  wrong key fails loudly; it never shows garbage.
- The folder `.data/` is git-ignored. It holds no plain birth date, reading, life context or email:
  each is sealed under its owner's own key (docs/data-retention.md).
- With the store on, the `X-Dev-User` shortcut is off: records are kept only for accounts, so sign
  in (the dev accounts are created at every start, as before).
- Deleting an account in the app removes its records and its key, and keeps a deletion record
  without personal data.

## Cache

Every page open loads the current build, in debug as well:

- `web/index.html` sends no-cache meta tags, unregisters any service worker, clears
  Cache Storage and loads `flutter_bootstrap.js` with a fresh query string.
- `web/flutter_bootstrap.js` loads `main.dart.js` with a fresh query string.
