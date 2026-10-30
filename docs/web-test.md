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

The page is static. It calls the v1 API; it never holds an AI key.

| `API_BASE_URL` variable                   | Who can test                                                                    |
| ----------------------------------------- | ------------------------------------------------------------------------------- |
| not set (default `http://127.0.0.1:8787`) | Only someone running the API on the same computer as the browser: `npm run api` |
| a hosted API URL (https)                  | Anyone with the link                                                            |

Local API with the Pages page (Chrome or Edge):

```
npm run api        # allows http://localhost and https://leonfighter1.github.io
```

Then open the Pages URL and sign in with a dev account (`admin`/`admin`,
`xumei`/`xumei`, `qianli`/`qianli`, `wuyong`/`wuyong`, `leonfighter`/`leonfighter`,
`test@mingli.local`/`Test-12345678`). The API also answers Chrome's
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
  This bounds AI spend;
- data is in memory: a restart clears accounts that testers registered, and their readings.

The dev accounts (`admin`/`admin`, `xumei`/`xumei`, and since v6.2.0 `qianli`/`qianli`, `wuyong`/`wuyong`
and `leonfighter`/`leonfighter`) exist in public mode too: each password is its login. Anyone who knows or
guesses them can use them, within the AI caps. They are created at every API start; with `MINGLI_STORE` on, they
are kept, with their readings.

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

## The AI keys

The keys never go into GitHub for this. The Pages build is public static files, so a
key in it would be readable by anyone. GitHub Actions doesn't need them either: CI runs
the mock provider. The keys belong only to whatever runs the API:

- local / LAN testing: in `.env` (git-ignored), both in place: `CLAUDE_API_KEY` for Claude
  (since v9.2.0; `ANTHROPIC_API_KEY`, the SDK's own name, works too) and `DEEPSEEK_API_KEY`
  for DeepSeek;
- a hosted API later (Render, Fly.io, Cloud Run, …): the host's secret / environment
  variable settings, then that API's https URL goes into `API_BASE_URL`.

A key is read when the API starts: after adding or changing one, start the API again
(`npm run api`, or `npm run public`). The switch and the model below need no restart.

## Mock or real AI: `IS_AI_MOCK`

To save tokens, the API can answer every AI step with the built-in mock: readings,
trend scores, 破除运势 plans and the 一生运势报告 come back at once, each line marked
（示范）. The switch is in `.env`:

| `.env`                                    | AI answers with            |
| ----------------------------------------- | -------------------------- |
| `IS_AI_MOCK=TRUE`                         | the mock, no tokens spent  |
| `IS_AI_MOCK=FALSE` and `IS_AI_MODEL=TRUE` | the real model (see below) |
| `IS_AI_MODEL=FALSE`                       | the mock as well           |

- The running API re-reads `.env` when it changes: the next reading follows, with no
  restart, so the public URL stays the same. The API console prints `AI switched: …`,
  and `/v1/health` shows `"ai": "mock"`, or the provider (`"ai": "anthropic"`) with
  `"ai_model"`.
- Readings made while the mock was on keep their （示范） text, preloaded 破除运势
  plans included; make a new reading after switching.
- While the mock answers, the daily AI caps of public mode don't count.
- A variable set in the shell itself wins over `.env`. `npm run eval:ai -- --live`
  refuses to run while the switch says mock.

## Which model answers: `ACTIVE_AI_MODEL` (v9.2.0)

Every AI step answers with Claude Opus 5.5 (`config/model_routing.json`, the owner's choice of
2026-10-29). `ACTIVE_AI_MODEL=<id>` in `.env` puts every step on another usable model:

| `ACTIVE_AI_MODEL=`  | Model                                   | $ per million tokens, in / out |
| ------------------- | --------------------------------------- | ------------------------------ |
| `claude-opus-5-5`   | Claude Opus 5.5, the default            | 4 / 20                         |
| `claude-fable-5-1`  | Claude Fable 5.1, the most capable      | 10 / 50                        |
| `claude-sonnet-5-5` | Claude Sonnet 5.5, balanced             | 2 / 10                         |
| `claude-haiku-5-5`  | Claude Haiku 5.5, fastest and cheapest  | 0.10 / 0.50                    |
| `deepseek-v4-pro`   | DeepSeek V4 Pro, the model until v9.2.0 | DeepSeek's own price list      |

- `npm run ai:models` prints this list, which model answers now, and whether each provider's key
  is in `.env` (never the key itself).
- Another model answers every step at its own effort. Naming the model the table already uses
  (`claude-opus-5-5`) keeps each step's own settings (v10.0.0): the 深度分析's questions stay at effort low.
- Like `IS_AI_MOCK`, the running API follows a change from the next reading, with no restart, and
  the console prints `AI switched: …`.
- An id not in the list is ignored, and the console says so; the table's model answers.
- `IS_AI_MOCK=TRUE` still wins: the mock answers whichever model is chosen.
- Claude Fable 5.1: Anthropic keeps its requests for 30 days.
- To compare models on the evaluation cases: `npm run eval:ai -- --live --model claude-sonnet-5-5`.
  It costs money; each case's cost at list price goes into docs/verification/ai-eval-results.json.

## 八字's AI reading (v9.3.0)

On 八字排盘 the button under the chart says 用AI做更精确解读. The engine's own reading stays as it was: the 命盘事实
card and the trend chart. The AI's reading is its own:

- It reads the 排盘 and what the profile says about the person, not the engine's 身强 / 身弱, 喜用 or scores, and
  judges the chart itself. Fill in 为谁排盘's real situation (job, family, what you want to know) for a closer reading.
- It opens with a 总结 in nine parts (你是怎样的人, 过去, 现在, 可能遇到的问题, 得势与得失, 未来运势, 何时开始要注意,
  何时开始要发力, 遇到问题时怎么办), then the six sections, each as 术语 then 评论. There are no 比如 examples and no
  行动建议.
- While `IS_AI_MOCK=TRUE`, every part reads （示范）: switch to the real model for a real one.
- Readings made before keep their 行动建议 and examples.

## 深度分析, the mic, 同名重算 (v10.0.0)

- **深度分析:** on 八字, 塔罗, 求签, 算卦 and 风水, under the AI button. The master asks about your situation first, one
  question at a time (fewer for a smooth chart, more for a hard one, at most 6). The page says 大师现在有问题要问你;
  answer, or 跳过剩下的问题，直接解答; when it is done, 开始最终解答 makes the reading, which reads every answer. The
  reading shows the conversation at its top, folded.
- **It needs a goal:** the question asked before drawing, or for 八字 为谁排盘's 想了解的事. Without one, a dialog asks
  for it first.
- While `IS_AI_MOCK=TRUE` the master is a demo: two （示范） questions, then done. The real model judges the chart and
  plans 1–6 itself.
- **The mic:** beside the answer, the goal and the 追问 fields, where the browser can listen. Chrome sends what you say
  to Google, which mainland China can't reach: there use Edge or Safari, or the phone keyboard's own voice input.
  Firefox has none, and the button isn't shown there. The browser asks for the microphone the first time.
- **同名重算:** 排盘 again for a person with a 八字 reading, or ask a 塔罗, 求签, 算卦 or 风水 the same question for the same
  person, and the app asks 之前已经算过，是否还要重新再算一次？ with 查看之前的 and 重新再算. The person is 为谁排盘 for
  八字 and your default profile for the others.

## 积分 (v11.0.0)

- **On by default** in `npm run api`, `api:lan` and `public`; `MINGLI_POINTS=off` in `.env` (or the shell) makes every
  AI request free again. The console says which: `积分: on; 充值 is simulated …`. `/v1/health` says `points`.
- **The dev accounts** (admin, xumei, qianli, wuyong, leonfighter, test@mingli.local) start with **10,000 积分**,
  given once: with `MINGLI_STORE=pglite` a restart doesn't give them again. Anyone else starts with none.
- **我的积分** in ☰ shows what is available, what running requests hold, the packs (10元 = 1000, 20元 = 2200, 30元 =
  3450, 40元 = 4800, 50元 = 6250) and every change. **充值 is simulated**: tap a pack and its 积分 arrive, nothing is
  paid. Someone using the `X-Dev-User` shortcut tops up with the same header: `POST /v1/points/top-ups {"yuan": 50}`.
- **What each request costs** is under its button (约 N 积分; the 深度分析 its 统一收费, 747 at Claude Opus 5.5). The
  price is held while the request runs, and when it is done it is charged what it really cost: its tokens at the
  model's list price, at 1,953.96 积分 a dollar (a 50% margin on the cheapest 积分). Never more than was held; a failed
  or held request costs nothing; with too few available the app says 积分不足 and offers 去充值.
- **With the mock** (`IS_AI_MOCK=TRUE`) no tokens are used, so each request is charged its estimate (演示模式，按预估
  in 我的积分). **With the real model** each charge says 按实际用量 and its AI cost in dollars, which is how to see what
  a question really cost.
- **破除运势 plans** are made when bought (about a minute), no longer ahead of time: a plan made ahead costs tokens
  nobody pays for. With `MINGLI_POINTS=off` they are made ahead again.
- **The prices** are in `config/points.json` (packs, the margin, the CNY rate, each request's estimate); a change is
  read at the next start. `ACTIVE_AI_MODEL` moves every price with the model (Claude Sonnet 5.5 halves them).

## 管理后台 (v12.0.0)

The admin dashboard: every account, the tokens, the money, who is active, exports, and the mail and SMS the server
sends (v13.2.0). It is a web app of its own (`admin/`), served by the API beside the app's API.

1. `npm run admin:build` (once, and after each change to `admin/`): builds it into `admin/build/served`, about a
   minute. It needs Flutter, like the app; it runs through a junction itself, so the CJK path doesn't matter.
2. `npm run api`. The console says `管理后台: http://127.0.0.1:8787/admin/ (admins: admin)`; before a build it says
   `not built yet`.
3. Open **http://127.0.0.1:8787/admin/** and sign in as a staff account: **`admin` / `admin`** (everything),
   **`manager` / `manager`** or **`integrator` / `integrator`** (v13.1.0). Any other account is turned away
   (这个账号没有后台权限).

- **The roles (v13.1.0–v13.2.0):** the server decides what each may do; the dashboard shows only that.
  - **admin:** every page and action, and any role on an account's page.
  - **manager:** 概览, 用户, 活跃, 收益, 用量. On an account: 停用, AI and 充值, and its role (普通用户, 集成人员 or 经理).
    No 增加积分, no 在所有设备上退出, no exports, and nothing on an admin's account.
  - **integrator:** 消息 only, as the whole page.
  - The bar shows who is signed in and the role (「boss · 管理员」). A role changed while signed in shows at the next
    refused action (你的角色不能做这件事), and the pages change with it.
- **Who is an admin:** the logins in `MINGLI_ADMINS` (default `admin`; comma-separated, read at the start) and any
  account an admin makes one on its page. An admin named in `MINGLI_ADMINS` can't be demoted there, and nobody can
  suspend themselves or change their own role, so there is always a way in.
- **The demo accounts:** a new store gets 36 demo accounts with 90 days of history, so every page has numbers
  (`管理后台: 36 demo accounts …` in the console). They have no password. `MINGLI_ADMIN_DEMO=off` leaves them out
  of a new store; with `MINGLI_STORE=pglite` they are made once and kept. The 用户 page filters them (含演示 / 不含演示
  / 只看演示).
- **What changes take effect at once:** 停用账户 signs the account out everywhere and refuses its sign-in (the app
  says 这个账号已被管理员停用); 可以用 AI off refuses its AI requests; 可以充值 off refuses 充值; 增加积分 shows in its 我的积分
  as 管理员赠送 with the note.
- **Exports:** 导出 makes the 经营报表 as PDF or Word and the revenue curve or the user list as CSV; 收益 also saves
  the chart as a PNG. A PDF needs a Chinese font on the server, as share images do (below); without one, the page
  says so and Word still works.
- **Numbers:** days are Beijing time; 充值 is what was paid, its net after the payment fee (0.6%) and VAT (6%); AI cost
  is each request's tokens at the model's list price, at the CNY rate in `config/points.json`.
- **Another API or folder:** `MINGLI_ADMIN_DIR=<folder>` serves another build, `off` none. Run from `flutter run` in
  `admin/` (through an ASCII junction), the dashboard calls `http://127.0.0.1:8787`; `?api=<url>` on its address
  picks another API.
- The session lives in the browser tab: closing it signs out. The dashboard is web only; on a phone it puts the pages
  in a bar at the bottom.
- **The layout (v12.3.0):** on a window 1200 px wide or more, each page has a panel of its own at the right, which
  scrolls on its own. Each page leads with one big figure and its change against the period before (the same number
  of days just before it), and the supporting figures sit in a grid. On a narrower window the panel's parts follow
  the figures.
- **外观 (v12.1.0):** the ☀ / ☾ / Ⓐ button in the bar picks 跟随系统, 浅色 or 深色. The choice is kept in this browser.
- **消息 (v13.2.0):** every mail and SMS the server sends (验证码邮件, 报告完成邮件, 记录发送邮件, 验证码短信), for admins
  and integrators. To try it:
  1. Sign in as `integrator` / `integrator`: 消息 is the whole page.
  2. Open 报告完成邮件. Beside the editor, the preview shows the mail's own page with sample values (a sample 八字
     reading), light or dark as the dashboard is: switch 外观 to 深色 and open it again.
  3. Change the body: the preview follows a moment after you stop typing. Click `{{title}}` among the values: it goes
     in where the cursor is. Type `{{who}}`: 「没有 {{who}} 这个变量」 shows under the body, and 保存 waits.
  4. 发送测试 → an address → 发送: the draft goes through the server's dispatcher into `.outbox/mail/` (a `.eml` that
     opens in Outlook, Thunderbird or Windows Mail, light or dark as that program is), and 最近发送 lists it with the
     address masked.
  5. 保存 (or Ctrl+Enter): every later 报告完成邮件 in that language uses it, and the card says 「简体中文 · 已修改」.
     恢复默认 puts the default back.
  - The edits are kept in the store: in memory until a restart, or with `MINGLI_STORE=pglite` for good.
  - No third-party service yet: mail and SMS go to `.outbox/` (the 发送方式 panel says so).
- **On a wide window (v13.2.0):** every page keeps to one centred container, 1440 px at most, its panel a card beside
  the main column; the bar and the rail stay at the window's edges.
- **From the app (v13.3.0):** a staff account sees ☰ → 管理后台 in the app. On the web it opens the dashboard in a new
  tab with the login filled in (the password is still asked; the login leaves the address bar once read). Off the web
  the address is copied instead.

## 外观: light and dark (v12.1.0)

In the app, ☰ → 外观 picks 跟随时间, 跟随系统, 浅色 or 深色. The choice is kept on the device like the language, so it
survives a reload. The page fades into the other theme over 0.3 s, and nothing moves. To try it:

1. Open the app, ☰ → 外观 → 深色: the page fades to dark; ☰ → 外观 shows 深色.
2. Reload: the app opens dark.
3. 外观 → 跟随系统: the app follows the system's light or dark. Switching the system (Windows: Settings →
   Personalisation → Colours) while the app is open fades it over too.
4. 外观 → 跟随时间 (since v16.0.0, and the default for a reader who never picked): dark from 19:00 to 06:00 local
   time, light otherwise. It turns by itself at 19:00 and 06:00 with the app open. To see the other side, change the
   computer's clock or time zone and reload.
5. 首页's banner (and the sign-in page's) shows the sun by day and the moon at night, whatever 外观 is.

The colours are the tokens in `app/lib/presentation/tokens.dart`, both themes side by side; the rules are in the
ui-design skill.

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

- 首页 → 求籤: type the question first, then 求籤 (since v11.1.0 a lot is drawn only for a question: 求籤 stays grey
  until there is one; 塔罗 and 算卦 too).
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

## 算卦 (v6.0.0; the coins turn over since v6.1.0)

- 首页 → 東方 → 算卦: type the question (one thing), read the reminder, then choose how to cast:
  - **自動擲幣**: 擲幣. The six tosses come one at a time (擲下一爻, or 直接看卦). Each toss's three 銅錢 are thrown:
    they spin and land, 字 (乾隆通寶) or 背 (plain), and then the line shows.
  - **自己挑幣**: 擺好硬幣 lays out 24 face-down coins on the server. Pick 18, one by one (click, or Tab and Enter);
    each glows and gets its number, and 重新挑 starts over. After the 18th, 看卦 turns them over one by one in the
    order picked, like the tarot cards; the coins not picked dim.
  - With the system's reduce-motion setting on, the coins show their faces at once.
  - **自擲自填**: set the exact time first (選擇時間, or 用現在的時間). Then enter six rows from 初爻 (bottom) up, 按硬幣
    (字 / 背) or 按爻, and 起卦.
- The card shows the hexagram at once, with no AI: the six lines (moving ones marked), 本卦 → 變卦, the trigrams, the
  time's 干支, and the texts it is read by, each with its 直說.
- 生成 AI 解讀 then reads the cast for the question. With `IS_AI_MOCK=TRUE` the reading is the mock's demo text.
- 算卦 is offered everywhere, after 求籤 in the home order. History names a reading by its hexagram (「算卦 · 天雷無妄」).
- Since v6.1.0 the home page has two groups: 東方 (八字, 求籤, 算卦, 風水, in the region's order) and 西方 (塔羅).
  On a phone, 塔羅's spread choices sit three to a row.

## 首页 on a wide screen, the sign-in page, 今日一卦 / 今日一签 (v14.1.0, v15.0.0)

- **A wide window:** widen the browser past 1200.
  - 東方's four methods sit two to a row (2 × 2); 西方's 塔羅 spans its row (1 × 1).
  - Past 1620 the content stays 1620 wide, in the middle.
  - Signed out, the sign-in page shows its banner at the left, as tall as the form at the right.
  - Below 1200 (a tablet, a phone) everything is one column, as before.
- **今日一卦 / 今日一籤** sits under 東方, as 今日一牌 does under 西方:
  - It is the server's draw for your account for the day: a 籤 on some days, a 卦 on others, the same all day.
  - Open it to see the 籤 with its poem, or the hexagram with its texts.
  - 生成 AI 解讀 reads it without a question. With `IS_AI_MOCK=TRUE` the reading is the mock's demo text.
  - The draw is per account and day: another account, or tomorrow, may show the other kind.

## Readings in three parts, and whose chart it is (v6.2.0)

- Every AI paragraph shows, in order:
  - the term in bold (the facts it rests on, said the tradition's way);
  - the commentary in plain words;
  - an everyday example in a tinted box.

  With `IS_AI_MOCK=TRUE` all three are the mock's （示範） text. Switch the real model on to read real ones.

- A 八字 chart now carries its person's name and birthplace label to the server. History (「xxx 的命盘」,
  「xxx 一生运势报告」), the reading's 出生地 line and the 一生运势报告 header show them on any device, also after
  `npm run public` starts with a new address.
  - Charts made before v6.2.0 keep their names only in the browser that made them.
- To check: sign in, make a 八字 reading, then open the page in a private window (or from another device) and sign
  in again. History still names the person.

## 追问 (v7.0.0)

- Open any finished reading (八字, 塔罗, 求签, 算卦, 风水) or a 一生运势报告. 「继续追问」 floats at the bottom right; it
  brings up the 追问 card and puts the cursor in its field. On a reading page the card sits right after the reading,
  and the jump list starts with 追问.
- Type a question and press Enter (or 发送), or tap a suggested question. The answer comes in the reading's three
  parts (term, commentary, example), with next questions under it.
- The answer rests only on this reading. A question it can't answer (another matter for a lot or a cast, someone
  else's chart, a date or an amount) is answered with 「超出这次结果能回答的范围」 and what can be asked instead.
- One at a time, up to 20 per reading. Each 追问 counts against the daily AI caps of public mode, like a reading.
- With `IS_AI_MOCK=TRUE` the answers and suggestions are the mock's （示范） text.
- `npm run eval:ai -- --live` also asks one 追问 per case and records whether its answer stayed with the reading
  (`followup.unfaithful` in docs/verification/ai-eval-results.json).

## 以往记录 (v8.0.0)

- 首页 → 历史记录 (or 最近记录 → 查看全部):
  - **按时间**: years, then months, newest first. 一生运势报告 sit among the readings by date.
  - **按人**: one group per person, the person with the latest record first; records filed under nobody under 未归类,
    last. A 八字 or 一生运势 record is filed under its chart's person; a 塔罗, 求签, 算卦 or 风水 reading under the
    default profile at the time it was made; 起名 under its 八字 chart's person.
- Each record's ⋮: 下载 PDF, 下载 Word, 发送 (asks PDF or Word), 归类到… (a profile's name, a name typed in, or 不归类),
  删除 (asks first; it can't be undone).
- 选择 (top right, or a long press): tick several, then 下载 / 发送 / 删除 at the bottom.
- 发送 opens the share sheet. On a computer's browser that can't share files, it downloads them.
- The reading page's ⋮ and the 一生运势 page's 下载 offer PDF and Word too.
- PDF needs a Chinese font on the server, as share images do (Noto Sans SC or 微软雅黑 on Windows; `fonts-noto-cjk` on
  Linux). Word needs none: Word uses its own font (Microsoft YaHei).
- Only finished records can be downloaded or sent.

## The ☰ menu, and signing in with a username, an email or a phone (v8.1.0–v8.2.0)

- 首页's bar holds the mark and the title, and ☰ on the right (v9.1.0; before, ☰ was on the left with 历史记录 beside
  the title). ☰ opens the menu from the right: 历史记录, 个人资料, 语言, 设置, 内容审核 (reviewers), 键盘快捷键,
  退出登录.
- **Signing in:** the one field takes a 用户名, an 邮箱 or a bound 手机号, with the same password. The dev accounts are
  usernames now: admin / admin, xumei / xumei, qianli / qianli, wuyong / wuyong, leonfighter / leonfighter;
  test@mingli.local stays an email. Accounts the database kept from before keep their records.
- **Signing up:** a 用户名 (2–24 letters, digits, Chinese characters, `_ . -`, starting with a letter or a Chinese
  character) and a password; the email is optional.
- **设置 → 账号与登录:** change the 用户名; verify or change the 邮箱; bind or unbind the 手机号. A local number is read
  in the account's region (`9123 4567` in 香港); any other needs its country code (`+65 9123 4567`).
- **No mail or SMS provider yet** (the owner's next step). The server writes every code and mail to `.outbox/`
  (git-ignored) instead of sending it, and the dialog says so:
  - text messages: the console prints `sms (dev outbox): …: 【命理大师】你的验证码是 123456…`, and
    `.outbox/sms/*.txt` keeps each one;
  - mail: `.outbox/mail/*.eml` opens in any mail program (Outlook, Thunderbird, Windows Mail), and the `.txt` beside
    it holds the address, the subject (with the code) and the text.
  - `MINGLI_MAIL=off` / `MINGLI_SMS=off` turn them off (the default outside dev mode); `MINGLI_OUTBOX_DIR` moves the
    folder; `MINGLI_MAIL_FROM` sets the sender.
- A code is valid 10 minutes, 5 tries. A new code at most once a minute; five an hour to one number or address; ten
  a day per account. Codes live in memory only: after a restart, ask for a new one.

## Reports by email (v9.0.0)

- **设置 → 报告 → 测算完成后发到邮箱**, 否 by default. It turns on only once the email is verified (设置 → 邮箱, a
  code). When on, every reading (any method) and every 一生运势报告 that passes is mailed when it is done: the report
  in the message, and the PDF attached. A held report goes when a reviewer releases it.
- **以往记录 → ⋮ → 发到邮箱**, or 选择 → 发邮箱: the chosen records as PDF or Word, in one mail to the verified email
  (at most 10 records a message, 20 messages a day).
- The reading page says 这份报告已发到你的邮箱, or that it could not be sent.
- **To try it now, with no provider:**
  1. Sign in, then 设置 → 邮箱: type any address and 发送验证码. The code is in the subject of the newest
     `.outbox/mail/*.txt`.
  2. Turn on 测算完成后发到邮箱, then make a reading.
  3. The report arrives as a new `.outbox/mail/*.eml`. Open it in Outlook, Thunderbird or Windows Mail to see it as
     the reader would, PDF attached.
- PDF attachments need the Chinese font on the server, as downloads do. Without it the report still goes, in the
  message alone.

## New parts come into view; the 求签 altar (v9.1.0)

Best tried on a phone, or a narrow browser window:

- **塔罗:** choose a spread, scroll to 抽牌 and press it. 洗牌 · 切牌 · 选牌 comes up under the button. After 切牌 the 78
  cards come up from their top; after the draw, the spread; after the last card turns, 生成解读.
- **风水:** 看布局 brings up the room's principles. **算卦:** each 擲下一爻 keeps its card in view, and the hexagram
  comes up once the last coins land. 自己挑币's coins come up as they are laid out.
- **求签:** 求签 brings up the altar. The 签筒 leans and is shaken, a stick drops out and glows, then 摇出第…签 and 掷筊.
  掷筊 throws the two blocks, which land on their faces; then what they mean. 直接看结果 skips it all.
- With the system's reduce-motion setting on (Windows: 设置 → 辅助功能 → 视觉效果 → 动画效果), the page jumps
  instead of gliding, and each 求签 step ends at once.

## Cache

Every page open loads the current build, in debug as well:

- `web/index.html` sends no-cache meta tags, unregisters any service worker, clears
  Cache Storage and loads `flutter_bootstrap.js` with a fresh query string.
- `web/flutter_bootstrap.js` loads `main.dart.js` with a fresh query string.
