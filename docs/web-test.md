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

## Share images: a Chinese font on the server (v4.2.0)

「分享图片」 on a tarot or (v4.3.0) 求籤 reading asks the API for an image it makes itself. The API needs a font with
Chinese characters. On Windows it finds Noto Sans SC or 微软雅黑; on Linux, install
`fonts-noto-cjk`; on a Mac it finds PingFang. Any other font: `MINGLI_SHARE_FONT=<file>` and
`MINGLI_SHARE_FONT_FAMILY=<its family name>`. Without one, the app says the image can't be made.

## 求籤 and the home order (v4.3.0)

- 首页 → 求籤: type a question (optional), then 求籤.
- Each round is a stick, then 擲筊. 聖筊 confirms it; 笑筊 or 陰筊 sends it back (放回再搖). 直接看結果 skips to the
  lot.
- 生成 AI 解讀 reads the lot. With `IS_AI_MOCK=TRUE` the reading is the mock's demo text.
- The home order follows the account's region (`GET /v1/methods`): an account registered in Taiwan or Hong Kong sees
  求籤 first. In dev mode, `X-Dev-Country: TW` does the same.

## 风水 (v4.4.0)

- 首页 → 風水: choose the room, and optionally the facing and a description; then 看佈局.
- The principles card shows the room's principles (and 「傳統上：…」 for a facing). 生成 AI 解讀 reads them for the
  room.
- An account registered in Malaysia (or `X-Dev-Country: MY` in dev mode) sees 風水 first.

## 起名 (v4.5.0): off until the 字义库 is reviewed

起名 ships off for everyone: its 字义库 is a draft awaiting the owner's 人工校订. To turn it on:

1. Check `src/engines/naming/characters.ts`: each character's 繁 and 简 forms, pinyin, 五行 and meaning, and the
   surnames. `npm test -- naming` says what each entry must satisfy.
2. In `src/engines/naming/index.ts`, set `LIBRARY` to `{ version: "1.0.0", reviewed: true }`, then
   `npm run sync:app`. The names card then stops calling the 字义库 a draft.
3. In `compliance/geo_rule_matrix.json`, set `defaults.systems.naming.available` to `true` and raise
   `matrix_version` by one minor step (e.g. 0.5.0 → 0.6.0). Since v5.1.0 the server reads the matrix on each
   request, so no restart is needed. Before v5.1.0 it read it once at start: restart it.
4. Run the harness. Every test still passes after these steps (tried on 2026-10-28, then undone).

Then: 八字排盘 → compute a chart → 為這個命盤起名 at the end of the chart page. Type the surname, choose 單字名 or
雙字名, then 起名. To try it before the review, point `MINGLI_GEO_MATRIX` at a copy of the matrix with `naming` on.

## Indonesia (v5.1.0): not served until the owner signs off

`ID` is in the matrix with its content blocks (前世, 通灵, 降头) but `service_available: false` and
`legal_review: "pending"`, so sign-up and every reading there answer 451. After the owner's sign-off, in
`compliance/geo_rule_matrix.json`:

1. for `ID`, set `service_available` to `true` and `legal_review` to `"provisional"`;
2. raise `matrix_version` by one minor step.

No restart is needed. In dev mode, `X-Dev-Country: ID` then shows the region. Its readings carry the content-block
line in every model call, and the `id` rule group records any hit.

## Cache

Every page open loads the current build, in debug as well:

- `web/index.html` sends no-cache meta tags, unregisters any service worker, clears
  Cache Storage and loads `flutter_bootstrap.js` with a fresh query string.
- `web/flutter_bootstrap.js` loads `main.dart.js` with a fresh query string.
