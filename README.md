# 命理大师

Phase 0 (engines, ChartFact, compliance) and Phase 1 in progress (AI pipeline, v1 API, Flutter app).
**Start here: [docs/SUMMARY.md](docs/SUMMARY.md)** (what each phase delivered).
Details: [docs/phase-0-gate.md](docs/phase-0-gate.md) · [docs/phase-1-status.md](docs/phase-1-status.md) · [docs/phase-3-gate.md](docs/phase-3-gate.md) · agent instructions in [CLAUDE.md](CLAUDE.md).
Web test: **https://leonfighter1.github.io/suanming/** ([docs/web-test.md](docs/web-test.md)).
管理后台 (staff: admin, manager, integrator): `npm run admin:build`, then `npm run api` and **http://127.0.0.1:8787/admin/** ([admin/](admin/README.md)).

## 更新记录 (release notes)

Newest first. Every update adds an entry: version and date, then by area what changed for users, how to use it, and
how it was verified. Big updates (X.0.0) end a stage of the [tech plan](docs/tech-plan.md) and are the ones pushed;
medium (X.Y.0) and small (X.Y.Z) ones are listed here as they are made. The rules:
[.claude/skills/dev-workflow/SKILL.md](.claude/skills/dev-workflow/SKILL.md).

### v18.0.0 (2026-10-31): 内容管理, the welcome page, sessions of two days, 登出 and the interactions (S29 and S30 complete)

Your requests: the twelve interactions (「UI 改进 … 做以下的所有应该有的元素交互功能」, S30), then S29: 「create a CMS
system … store the values of the resources into database … autherize the roles … extract as much text as possible」,
the introduction page, 「登录者的登录消息存在服务器上，如果距离上次登录超过2天，那就需要重新登录」 and 「增加登出动画」. Both stages
end with this release, which is pushed.

- **内容管理, the CMS:**
  - **管理后台 → 内容** (for 管理员 and 集成人员): every text the app shows, 734 of them, in 简体中文 and 繁體中文, and
    two pictures: the banners' 命理罗盘 and the welcome page's mark.
  - **To change a text:** search for its words as the app shows them (or its key), click it, change 简体中文, 繁體中文
    or both, and 保存 (Ctrl+Enter). Each field shows the app's own words under it; ↺ puts them back, and saving the
    app's own words removes the change. 已修改 in the panel lists only the changed texts.
  - **Values the app fills in** ({balance} and the like) must stay: the editor names them, and the server refuses a
    change that drops or adds one, saying why.
  - **To change a picture:** 上传 (or 换一张) in the panel: a PNG, JPEG or WebP of at most 2 MB; 移除 puts the app's own
    back.
  - **In the app:** the changes show the next time the app opens, everything else stays the app's own. Without a
    network, or with an older server, the app shows its own words and pictures.
  - Kept in the database (migration 013). The app reads them without signing in, so the welcome and sign-in pages
    show them too.
- **欢迎, the welcome page:** what you see before signing in.
  - 欢迎来到命理大师 on 命理罗盘 with the app's mark (or the logo put in through 内容), the 加入我们 words, and 登录 /
    注册, which opens the sign-in page.
  - Then 我们的服务: 东方 (八字排盘, 求签, 算卦, 风水) and 西方 (塔罗), as on 首页, 2 × 2 on a desktop window.
  - Tapping a service opens the sign-in page; once signed in, that service opens, and ← goes to 首页. Signing up goes
    to 首页.
  - The language can be switched at the top. The page's words and logo can be changed in 内容.
- **Sessions:** kept on the server (migration 014), so restarting the server no longer signs anyone out. A session
  not used for two days ends, and the app asks to sign in again; an app opened at least every two days stays signed
  in. `MINGLI_SESSION_IDLE_DAYS` in .env changes the two days (S31 moves it into the 管理后台).
- **登出:** signing out, from the menu, by deleting the account or by a suspension: 首页 sinks back and fades as the
  welcome page comes forward, in half a second. With reduce motion on, it changes at once.
- **The interactions (S30):**
  - **按压回弹:** every button and tappable card shrinks to 96 % when pressed and springs back a little past its size.
  - **弹性开关:** a switch's thumb stretches into a capsule as it travels and rests round with a slight rebound.
  - **波纹跟手:** the ripple spreads from where your finger went down.
  - **勾选画出来:** a checkbox's tick draws from the bottom left to the top right (Material's own, kept).
  - **数字滚动:** figures roll to their new values, slower near the end: 我的积分, the menu's balance, the 管理后台's
    figures.
  - **骨架屏:** pages show their own frame while their data come, and nothing moves when the data arrive.
  - **卡片翻面:** a tarot card shows each side only while it faces you.
  - **汉堡变叉:** ☰ turns into ✕ as the menu opens, and back.
  - 点赞, 收藏, sliders, stacked cards and bottom sheets aren't in the app yet; each gets its interaction when it
    comes.
- **Also:**
  - 集成人员 see 消息 and 内容, with a rail (a bar on a phone); the role's line says so.
  - Fixed: a frame of spinner between 首页 and the next page on signing out; ☰ showing ✕ after signing out from the
    open menu and back in.
- **Verified:**
  - **Tests:** server 709, app 300, 管理后台 85.
  - **Renders:** 内容 at 1440 (light, dark) and 390, its editor refusing a change; 欢迎 at 390 and 1600 (light, dark).
  - **Harness:** PASS.
- **Stages S29 and S30 in sum:** the CMS, end to end, with the roles that may use it; the welcome page with the
  service you picked kept through signing in; sessions on the server ending after two days unused; the sign-out
  animation; and the eight interactions the app has elements for. Their summaries are in the
  [tech plan](docs/tech-plan.md).
- **Next:** S31, your request of today: the settings in their own files, read and changed in the 管理后台 (the two
  days, the AI model and its mock); the currencies (the accepted ones, today's rates from an online service plus a
  5 % service charge, the currency each user picks); purchase receipts to view and print; and the 管理后台's
  currency.

### v17.0.0 (2026-10-30): 命理罗盘 behind every banner; the API in modules (S28 complete)

Your requests of today: 「Update the banner background using this … luopan.svg for all pages」, and stage S28's
「有没有根据skill进行代码重构？没有的画请继续」. This release ends S28 and is pushed.

- **The banners' art (what you see):** every banner stands on 命理罗盘, your drawing from JingyaoPaint: 首页, the
  sign-in page, each method's page (塔罗, 求签, 算卦, 风水) and 八字's chart.
  - The art covers the banner. Its own night sky lies over the side the words are on, deepest under them, so the
    title and the line under it read on a phone, on a desktop and beside the sign-in form.
  - The art is night in both themes, so the banner looks the same in 浅色 and 深色. Its words, the sun or the moon,
    and 八字's day pillar in its 五行 colours take the dark theme's colours.
  - **When the art changes:** run `npm run mirror:banner`. It makes the app's picture from luopan.svg (1.4 MB, with
    glows the app can't draw itself) as a 1600 × 1600 WebP of 270 KB, and rewrites it only when the picture changed.
- **The API in modules (nothing changes for users):** phase D of [docs/refactor-plan.md](docs/refactor-plan.md).
  - `src/api/server.ts` went from 2650 lines to 659. It keeps what the routes share (the quotas, the 积分 holds, the
    background jobs, the Geo-Rule check, the report mail), the order the routes are tried in, CORS and the error
    answers.
  - Eleven route modules in `src/api/routes/`, one per group: the calendar and places, sign-in and the account, 积分,
    以往记录 and documents, the cards of the day, 破除运势, 一生运势报告, 深度分析, 追问, charts and readings, 内容审核.
  - Each module gets the shared state as one `ApiContext` (`src/api/context.ts`). What a response shows of a record
    is in `src/api/views.ts`.
- **Also:**
  - the 管理后台's side panel is built in one place, with no visible change;
  - the tests share the standard 八字 chart (`sampleBazi`) and the way to it (`openBaziChart`);
  - fixed: a test that sent a fixed date to a server on the real clock broke when the day turned (rule 83).
- **Verified:**
  - **Tests:** server 697, app 272 (seven new for the banner), 管理后台 75.
  - **Every moved block** has the same code as before, token for token, apart from the context and its answers; no
    import left unused.
  - **Renders** of the banner on 首页, the sign-in page and 塔罗, from 390 to 2560 wide, light and dark.
  - **Harness:** PASS.
- **Stage S28 in sum (v16.1.0–v17.0.0):** one home for each thing, by the coding skill. The repeated blocks went from
  260 to 59: the test servers, the app's shared widgets, the AI pipelines' mechanics and the API's modules. Nothing
  changed for users but the banner. Its summary is in the [tech plan](docs/tech-plan.md).
- **Next:** S29, the CMS, the introduction page, two-day sessions and the sign-out animation. Then S30, your twelve
  interactions: the ones the app has elements for (button bounce, switches, ripple, ticks, rolling numbers,
  skeletons, the tarot flip, ☰ → ✕). 点赞 and 收藏, sliders, stacked cards and bottom sheets don't exist in the app
  yet.

### v16.2.0 (2026-10-30): the AI pipelines share their mechanics (S28 phase C)

Phase C of the refactoring planned in [docs/refactor-plan.md](docs/refactor-plan.md). Nothing changes for users or
for the model: every reading is built and checked as before.

- **One home for the pipelines' mechanics:** `src/ai/envelope.ts` holds what the five AI entry points (reading,
  破除运势, 一生运势报告, 追问, 深度分析) each wrote:
  - which model an agent's step runs on;
  - the guard's verdict;
  - the AI disclosure a result carries.
    Each entry point keeps its own prompts, steps and checks.
- **The user messages' closing lines** (the sections in order, the language, the region's line, a check's feedback)
  are written once instead of in ten builders. No released prompt text changes.
- **Verified:**
  - **Fixtures:** `npm run sync:app` rewrote every app fixture byte for byte the same.
  - **User messages:** 69, from 23 builder calls in three languages, are byte for byte the same before and after.
  - **Tests:** the pinned prompt hashes and the 696 server tests pass.
  - **Counts:** repeated blocks 108 → 90.
  - **Harness:** PASS.

### v16.1.0 (2026-10-30): the code restructured, one home for each thing (S28 phases A and B)

Your requests of today: 「有没有根据skill进行代码重构？没有的画请继续」 and 「prepare tech documents to plan the restructuring and
refactoring」. Nothing changes for users: the same screens, the same answers. This release carries phases A and B of
stage S28, planned in [docs/refactor-plan.md](docs/refactor-plan.md).

- **The plan:** docs/refactor-plan.md surveys the code: 260 repeated blocks in 391 files, and the largest files. It
  sets the rules for every step (no behaviour change, the smallest diff, each method its own) and orders the work in
  four phases.
- **Phase A, tests and scripts:**
  - one `testApi` for twenty server test files that started the API by hand;
  - the app tests' 27 copies of `settle` call the existing `frames`, and four copies of `scrollAndTap` became one;
  - the statistical batteries and the verify scripts each share one home.
- **Phase B, code:**
  - **app:** one home each for dates (`ymd`, `localMinute`), the numbered badge (`StepNumber`), the cards of the day's
    tile (`DayCardTile`), 有所求's listener (`watchQuestion`), a new profile (`BirthProfile.blank`) and the reading
    page's export headings;
  - **server:** `chartRequest`, `dailyChart`, the 积分 hold and credit rules both stores wrote (`newHold`,
    `creditEntry`), the share images' common parts and the 管理后台's period sums.
- **Verified:**
  - **Every step:** the tests that cover it, before and after.
  - **Unchanged output:** the touched screens render byte for byte the same in light and dark, and so do the share
    images; the verify gates' results are unchanged.
  - **Counts:** repeated blocks 260 → 108. Server tests 696, app tests 265 and 管理后台 tests 75 all pass.
  - **Harness:** PASS.
- **Next:** phase C (the AI pipelines' shared mechanics) and phase D (the API's routes in modules). Then your new
  requests, as S29: the content system, the introduction page, two-day sessions and the sign-out animation.

### v16.0.0 (2026-10-30): the theme follows the time of day, with the sun and the moon on the banner (stage S27)

Your request of today: 「Theme加上太阳和月亮到banner上去, 表示时间，皮肤会跟随时间变化而变化。当地时间7点到第二天凌晨6点为深色，其余为
浅色。」, with every page in the container, the 充值 boxes and the coding skill of v15.1.0. This completes stage S27 of
the [tech plan](docs/tech-plan.md). Pushed, with v14.1.0 to v15.1.0.

- **跟随时间, the new default 外观:**
  - From 19:00 to 06:00 local time the app is dark; the rest of the day it is light.
  - The change comes by itself at 19:00 and at 06:00 while the app is open, fading over 0.3 s as any change of 外观
    does.
  - ☰ → 外观 lists 跟随时间 first, with its hours, then 跟随系统, 浅色 and 深色. If you picked one of those before, it
    is kept: choose 跟随时间 to switch.
- **The sun and the moon:** the banner on 首页 and on the sign-in page shows the sun by day (06:00 to 19:00) and the
  moon at night, whatever 外观 is.
- **The rest of the stage** (details in v15.1.0 below): every page in the 1620 container, the 充值 boxes one size,
  and the coding skill.
- **To try it:** docs/web-test.md, 「外观: light and dark」.
- **Verified:**
  - **App tests 261 → 265:** the hours at their edges and over the year's end; the theme and the banner turning at
    19:00 and at 06:00 in an open app; the moon at night on a light page; 跟随时间 picked from the menu and kept.
  - **Renders** with the real fonts: 首页 by day and at night.
  - **Harness:** PASS, and once more on the final tree before the push.

### v15.1.0 (2026-10-30): every page in the 1620 container; the 充值 boxes one size

Your requests of today: 「各自算法的大小container似乎没有加上大屏幕1620px的限制，现在挺小的。我的要求时对于所有的页面，基本框架在大屏时
都要有这个尺寸限制（包括设置页面）」 and 「充值页面十元的框跟其他的充值框大小不一」. This is work package WP27.2 of stage S27 in the
[tech plan](docs/tech-plan.md); the theme by the time of day follows in WP27.3.

- **Every page in the container:** every page of the app now keeps to the same container as 首页. That covers 八字,
  塔罗, 求签, 算卦, 风水, 起名, the readings, 历史记录, 个人资料, 我的积分, 设置, the birthplace picker and the rest.
  - On a phone and a tablet the page is fluid, as before.
  - On a wide window it is up to 1620 wide and centred. Before, it was 720 (1200 for 塔罗).
  - 设置's and the birthplace picker's rows keep their own inset, so on a phone they look as before.
  - The 管理后台 is unchanged.
- **充值:** the five packs' boxes are now one size. ¥10, which has no bonus, keeps the bonus line's room, every box is
  the same width, and each line stays on one line. A phone shows three to a row.
- **Coding rules:** a new project skill (`.claude/skills/coding`), named in CLAUDE.md: build from what exists, give each
  thing one home, and keep each change as small as it can be. This release follows it: one function, `pagePadding`,
  moved every page.
- **Verified:**
  - **Tests:** every page at 2560 (the methods, the birthplace picker, 设置, 我的积分); the packs one size on a phone
    and on a wide window. App tests 259 → 261.
  - **Renders** with the real fonts: 我的积分 on a phone; 八字, 塔罗 and 设置 at 1920.
  - **Harness:** PASS.

### v15.0.0 (2026-10-30): 今日一卦 / 今日一签 under 东方; the app's container (stage S26)

Your request of today: 「另外我看到西方有今日一牌功能， 那么东方系列，我们剋增加今日一卦或者今日一签功能，可以随机出现。」, with the
container and the 2 × 2 of v14.1.0. This completes stage S26 of the [tech plan](docs/tech-plan.md). Pushed, with
v14.1.0.

- **今日一卦 / 今日一签** sits under 东方, as 今日一牌 does under 西方.
  - **What it is:** the server's 东方 draw for your account for the day. On some days it is a 籤 of the 關聖帝君一百籤;
    on others a 卦 (three coins, six tosses, cast on your device's clock). Which one changes at random from day to
    day, and within a day it stays the same, on every device.
  - **On 首页:** 今日一籤 shows the lot's slip and title (第八十九籤 · 壬壬). 今日一卦 shows the hexagram's lines and
    names (第13卦 · 天火同人 → 乾為天).
  - **Open it:** the 籤 with its poem, as on the 求籤 page; or the hexagram with its moving lines and the texts it is
    read by, as on the 算卦 page. Then 生成 AI 解讀 or 深度分析, read as 求籤 or 算卦 reads and paid in 积分 as usual.
  - **No question:** you draw nothing for it, so, like 今日一牌, it needs no question. 求籤 and 算卦 themselves still
    wait for your question (your v11.1.0 rule).
  - **Where a region offers neither** 求籤 nor 算卦, the card isn't shown; where it offers one, every day is that one.
- **The rest of the stage** (details in v14.1.0 below): the sign-in page and 首页 in one container of at most 1620,
  fluid on phones and tablets. On a desktop window, 东方 is 2 × 2, 西方 1 × 1, and the sign-in page's banner sits
  beside its form. The 管理后台 is unchanged.
- **To try it:** docs/web-test.md, 「首页 on a wide screen, the sign-in page, 今日一卦 / 今日一签」.
- **Verified:**
  - **Server tests 690 → 696:** the same all day; another day or account gets its own; both kinds over the days;
    the date and time-zone checks; the Geo-Rule; not listed; replays; read without a question.
  - **App tests 254 → 259:** each kind on 首页 and on its page; Tab, Enter and Esc; hidden when there is none; its
    place under the 2 × 2.
  - **Renders** with the real fonts, light and dark: the day's 籤 and 卦 on a phone and a desktop, and their pages.
  - **Harness:** PASS, and once more on the final tree before the push.

### v14.1.0 (2026-10-30): the app's container; 首页 two to a row on a desktop

Your requests of today: 「登录界面也需要添加新的container… 大于 1620px 时要设置一个max-width 1620px. 本体可以是fluid…
在tablet和mobile device 可以不用有这限制了」 and 「在超大屏幕布局时可以采用2X2布局。如果只有一个那就采用1x1」. This is work package
WP26.1 of stage S26 in the [tech plan](docs/tech-plan.md); 今日一卦 / 今日一签 follow in WP26.2. The 管理后台 is unchanged,
as you said (「管理员界面就不用改了」).

- **The app's container:** the sign-in page and 首页 keep to one container.
  - On a phone and a tablet it is fluid: the window's margin at the sides (16 on a phone, 24 on a tablet), nothing
    else.
  - On a window wider than 1620 it is 1620 wide and centred, with the margin (32) inside it.
  - Pages of reading and forms keep their columns (720; 塔罗 1200).
- **首页 on a desktop window** (1200 and wider): each group's methods two to a row, the two in a row the same height.
  - 东方's four are 2 × 2: 八字排盘 and 求签, then 算卦 and 风水 (your region's order).
  - 西方's one, 塔罗, spans its row (1 × 1). 今日一牌 and 最近记录 follow, across the container.
  - Tab goes row by row.
- **The sign-in page on a desktop window:** the banner at the left, as tall as the form at the right (five of the
  twelve columns). When you sign up, the banner grows with the longer form. Phones and tablets keep one column.
- **Verified:**
  - **Tests:** 首页 at 390, 700, 1024, 1280 and 2560 (the margins, the 1620 container, 2 × 2 and 1 × 1, the group
    titles on the cards' edge); the sign-in page at the same widths, signing in and signing up. App tests 253 → 254.
  - **Renders** with the real fonts, light and dark, at 390, 1024, 1280, 1920 and 2560.
  - **Harness:** PASS.

### v14.0.0 (2026-10-30): mail and SMS you can edit, staff roles, and the way in from the app

Your requests of today: the back office edits what each mail and SMS says, with the mail and its preview following
light and dark, tested on the server without a third-party service; three staff roles; a way into the back office
from the app's menu; and a container on wide screens. Stage S25 of the [tech plan](docs/tech-plan.md), complete.
Pushed, with v13.1.0 to v13.3.0.

- **What the stage brought** (details in the entries below):
  - **One way out for every message (v13.1.0):** the codes by mail and SMS, the report mail and the records mail go
    through one dispatcher: its wording (an admin's, else the default), its values, its channel, a masked note in
    the log. For now everything goes to the dev outbox (`.outbox/`); provider settings come later, as you asked.
  - **Mail in the app's colours, light and dark (v13.1.0):** every mail is a page in the app's own colours, dark when
    the reader's mail program is in dark mode.
  - **消息 in the 管理后台 (v13.2.0):** each message per language: edit it, see the preview (the mail's real page,
    light or dark as the dashboard is), check it as you type, save, reset, send a test, and see the latest sends.
  - **Roles (v13.1.0–v13.2.0):**
    - **admin:** everything.
    - **manager:** sees the numbers and the accounts and gives roles and permissions, but never touches a user's
      data.
    - **integrator:** 消息 only.
    - The server enforces it; every screen shows only what the role may do.
  - **A container on wide screens (v13.2.0):** every page of the 管理后台 stays at most 1440 wide, centred.
  - **The way in (v13.3.0):** staff see ☰ → 管理后台 in the app; it opens the dashboard with their login filled in.
- **To try it:** docs/web-test.md, 管理后台:
  - sign in as `integrator` / `integrator` (or `manager` / `manager`, `admin` / `admin`);
  - open 报告完成邮件, change it, watch the preview, switch 外观;
  - send a test and find it in `.outbox/mail/`.
- **Verified:**
  - **Tests:** server 676 → 690, app 250 → 253, 管理后台 56 → 75.
  - **A real browser:** the mail's frame, light and dark; an edit; a test send.
  - **Harness:** PASS at every release, and once more on the final tree before the push.

### v13.3.0 (2026-10-30): ☰ → 管理后台 for staff

Your request: a signed-in account with back-office rights can enter the back office from the menu on the home page
(「如果登陆者具备各项权限，在主页登陆时可以在下拉菜单设置中选择进入后台系统」). Stage S25, work package WP25.3b, committed
locally; it goes out with v14.0.0.

- **The way in:** an admin, manager or integrator sees **管理后台** in the app's ☰ menu, with their role
  (「以经理身份…」). Nobody else sees it. The server says who is staff (`GET /v1/me`'s `staff`), so a role given or
  taken away shows at the next sign-in.
- **On the web** it opens the dashboard (the API's `/admin/`) in a new tab with your login already filled in; you
  type only the password. The dashboard then takes the login out of its address, so a copied link doesn't carry it.
- **Off the web** (the Android app), there is no tab to open: the dashboard's address is copied, and a line at the
  bottom says so, for pasting into a browser.
- **Keys:** the entry is in the menu's Tab order; Enter opens it.
- **Also:** the 管理后台 screens from v13.2.0 now take every colour from the design tokens (the rule in CLAUDE.md); a
  manager's or an integrator's role label turns from a tint of the accent to the secondary text colour.
- **Verified:** 3 new app tests (hidden without a role; the role, the address with the login, the copy; 繁體, an
  email login encoded, Tab and Enter), 1 new 管理后台 test (the login filled in, the password next); harness PASS.

### v13.2.0 (2026-10-30): the 管理后台's 消息 page, roles on every screen, and one container on wide screens

Your requests: the back office edits what each mail and SMS says, with a preview that follows light and dark
(「让后台用户可以编辑各类发送邮件的前端页面…邮件的preview界面…也要符合当前app的跟随系统模式」); what each role may do
(「admin具备超级权限，manager可以进行权限分配…integrator…只能对邮件和短信系统进行操作」); and on a wide screen a container
instead of a fluid page (「make sure have a container to limit the size of it」). Stage S25, work package WP25.3,
committed locally; it goes out with v14.0.0.

- **消息 (new page in the rail):** every message the server sends, as cards under 邮件 and 短信: 验证码邮件,
  报告完成邮件, 记录发送邮件 and 验证码短信. Each card says when the message goes out and lists its languages, marking
  any language an admin has changed (「繁體中文 · 已修改」). The panel shows how messages leave this server (the dev
  outbox for now, no third-party service) and 最近发送, the latest sends: which message, the masked recipient, the
  language, how it went (已发出, 没有发送方式, 发送失败) and when.
- **The editor (open a card, or Tab to it and Enter):**
  - **Language:** one at a time (简体中文 / 繁體中文 / English, ← → between them). Switching with unsaved edits asks
    first.
  - **Subject (mail) and body:** in the markup from v13.1.0. 「正文的写法」 under the buttons lists the marks.
  - **Values as chips:** `{{code}}`, `{{title}}`… go in where the cursor is. A part such as `{{report}}` goes on a
    line of its own and only into the body.
  - **Checked as you type:** anything wrong shows under the body (「没有 {{who}} 这个变量」, 「需要用到 {{code}}」), and
    保存 waits until it is fixed.
  - **Buttons:** 保存 (or Ctrl+Enter), 撤销修改 (back to the saved wording), 恢复默认 (asks first), and 发送测试 (asks
    for an address or a number, then sends the draft, or the saved wording, with sample values through the server's
    dispatcher into the outbox; the send appears in 最近发送).
  - **Leaving:** leaving with unsaved edits asks first (Esc or ←).
- **The preview, beside the editor:**
  - **A mail:** the server's own page, in a frame, exactly as a mail program shows it, with sample values. It is light
    or dark as the dashboard is (外观: 跟随系统, 浅色 or 深色) and changes with it. The mail actually sent follows the
    reader's own system.
  - **An SMS:** its text, length and how many messages it takes (70 characters to one once there is Chinese in it).
  - **Updates:** the preview is made again a moment after you stop typing.
- **Roles on every screen** (the server decides; the screens leave out what it would refuse):
  - **Sign-in:** admins, managers and integrators can sign in; anyone else sees 「这个账号没有后台权限」. The bar
    shows who you are and your role (「boss · 管理员」).
  - **integrator:** 消息 only, as the whole page (no rail).
  - **manager:** 概览, 用户, 活跃, 收益, 用量; no 导出, no 消息, no CSV beside the revenue curve (the curve's picture
    stays). On an account:
    - the permissions (停用, AI, 充值) and the role, from 普通用户, 集成人员 or 经理;
    - no 增加积分, no 在所有设备上退出;
    - nothing on an admin's account, and the page says why.
  - **admin:** everything, and any role on an account's page, which replaces the old 管理员 switch. Every change asks
    first and says what the role may do.
  - **Role changed mid-session:** if another admin changes your role while you are signed in, the next refused action
    says 「你的角色不能做这件事」 and the pages change at once.
  - **用户:** the role filter has all four roles; staff show their role in the list.
- **A container on wide screens:** every page of the 管理后台 (its main column and its panel together) now stays at
  most 1440 wide, centred, with the window's margin inside it, instead of spreading across a wide window. The panel is
  a card of its own beside the column. 活跃 and 导出 keep the same left edge as the other pages. The bar and the rail
  stay at the window's edges. On a phone 保存 spans the column.
- **Verified:**
  - 18 new 管理后台 tests:
    - 消息: the list, editing and saving, 撤销修改 and 恢复默认, the chips, the checks, another language, test sends,
      leaving with edits, an SMS, the preview's dark, the keys;
    - each role's pages and actions, a role changed mid-session;
    - the container at 2560 wide.
  - 74 管理后台 tests pass; the server's 690 are unchanged.
  - Looked at in a real browser against a private server: the mail page in its frame, light and dark; an edit and a
    value chip by mouse; a test send into the outbox.
  - harness PASS.

### v13.1.0 (2026-10-30): message templates, one way out for mail and SMS, and staff roles (the server)

Your requests: design the sending of mail and SMS so the back office can edit what each message looks like, with mail
following the reader's light or dark mode, tested on the server without a third-party service
(「设计好邮件发送逻辑，让后台用户可以编辑各类发送邮件的前端页面…」); and three staff roles
(「针对后台设置不同的用户策略…admin, manager, integrator」). This is the server's part of stage S25; the 管理后台's pages
come next. It is committed locally and goes out with v14.0.0.

- **One way out for every message:** the verification code by mail and by SMS, the report mail (测算完成后发到邮箱) and
  the records mail (发到邮箱) now all go through one dispatcher. It does four things for each message:
  - picks its wording: an admin's edit if there is one, else the default;
  - fills in the values;
  - sends it on its channel;
  - notes the send.

  The log keeps the latest 200 sends with the recipient masked; a verification code is never written down.

- **Templates:** each message has its wording per language (简体 and 繁體; English for the codes). The defaults are the
  texts the app has sent until now. A mail's body is a small markup:
  - `# title`, `## heading`, paragraphs;
  - `> small note`, `---` for a line, `!! highlight` (the code shown large), `- list item`;
  - `{{code}}`-style values, and the report or the record list on a line of their own (`{{report}}`, `{{records}}`).

  A wording is checked before it is kept: no unknown values, the code mail must contain `{{code}}`, the lengths.

- **Mail follows light and dark:** every mail is now a page in the app's own colours. It is light by default and dark
  when the reader's mail program is in dark mode (Apple Mail, iOS, Outlook.com…). The plain-text version is still
  there for programs that show only text. A test holds the mail's colours to the app's colours.
- **No third-party service yet:** mail and SMS are written to the dev outbox (`.outbox/mail`, `.outbox/sms`). Provider
  settings come later, as you asked.
- **Staff roles** (enforced by the server, not just the screens):
  - **admin:** everything.
  - **manager:** sees the dashboard and assigns roles and permissions (user, integrator or manager; 停用, AI,
    充值). Can't make anyone admin or touch an admin's account, and can't operate on users' data (no 增加积分, no
    在所有设备上退出, no exports).
  - **integrator:** only the mail and SMS templates, previews, test sends and the send log.
  - **Everyone:** nobody changes their own role. Admins named in MINGLI_ADMINS stay admins.
- **For trying it:** two new dev accounts, `manager` / `manager` and `integrator` / `integrator`.
- **The API:** `GET /v1/admin/messages/templates`, saving and resetting a wording (`PUT` / `DELETE
/v1/admin/messages/templates/{kind}/{locale}`), `POST /v1/admin/messages/preview` (a draft with sample values, light
  or dark), `POST /v1/admin/messages/test` (a test send through the outbox), `GET /v1/admin/messages/log`.
  `GET /v1/admin/me` now says the role and what it may do; `GET /v1/me` says `staff` (for the app's menu, next).
- **Fixed on the way:** the database store would have dropped the manager and integrator roles at the next start (it
  only knew admin); caught by the new test.
- **Verified:**
  - 14 new server tests: the templates and the markup, the mail page light and dark, the colours against the app's,
    the SMS lengths, the dispatcher and its log, the database keeping an edit and the roles, every route against every
    role, the role rules, the 消息 API.
  - 690 server tests pass.
  - harness PASS.

### v13.0.0 (2026-10-30): one design system for the app and the 管理后台

Your request (「对于dashboard 可以采用非对称Dashboard布局…建立统一的浅色和深色主题系统…」), stage S24 of the
[tech plan](docs/tech-plan.md), complete. Pushed, with v12.0.1 to v12.3.0.

- **What the stage brought** (details in the entries below):
  - **Light and dark (v12.1.0):** each theme defines its background, card, text and accent, and with them the borders,
    the states, the 五行 and the chart colours, side by side in one file. 外观 (跟随系统 / 浅色 / 深色) is in the app's ☰
    menu and the 管理后台's bar. A change of theme fades every colour, border and state over 0.3 s, and nothing moves.
  - **One grid, spacing, type and alignment (v12.2.0):** every page is a centred column on a wide window, all spacing
    is on a scale of 4, there is one type ramp from 11 to 48, and the alignment rules hold everywhere. A test fails on
    any screen that breaks them.
  - **The 管理后台, asymmetric (v12.3.0):** each page leads with one big figure and its change against the period
    before, its supporting figures sit in a compact grid, and a panel of its own stands at the right.
- **For future work:** the ui-design skill (`.claude/skills/ui-design`) holds every rule: the colour tokens, light and
  dark, the grid, spacing, type, radii, alignment, motion and the dashboard. CLAUDE.md now points to it for any change
  to a colour, a size, a layout or the theme. docs/web-test.md says how to try 外观 and the new 管理后台.
- **Verified:**
  - 676 server tests, 250 app tests and 56 管理后台 tests pass.
  - The harness passed on the final tree before the push.

### v12.3.0 (2026-10-30): the 管理后台, asymmetric: a big figure, a compact grid, a panel at the right

You asked for an asymmetric dashboard with big numbers as the visual anchor, the supporting data in a compact grid, and
an independent vertical panel on the right, with hierarchy from the modules' proportions, type size and space
(「对于dashboard 可以采用非对称Dashboard布局…」). This is the third step of stage S24. It is committed locally and goes out
with v13.0.0.

- **Each page leads with one big figure** (48 px):
  - **概览:** 充值收入.
  - **收益:** 毛利.
  - **用量:** Tokens.
  - **活跃:** who is on now.
  - **An account's page:** its 积分余额.

  Under the figure is its change against the period before (for example "↑ +12.5% 较前 30 天") and a line on how it
  came about. Beside it, a small line of the period's days shows how the figure went; on a phone that line sits under
  the figure.

- **The supporting figures sit in one compact grid,** four to a row on a wide screen and two on a phone, with thin
  lines between them:
  - **概览:** AI 成本, 毛利, 毛利率, 新增账户, AI 请求, Tokens, 售出积分 and 消耗积分.
  - **Every figure** shows its change too:
    - **Direction:** an arrow and a sign.
    - **Colour:** green when the change is good and red when it's bad. AI cost going down is good, so it shows green.
    - **Flat:** grey, marked 持平.
    - **No earlier data:** marked 无数据.
    - **毛利率:** its change is in 个百分点.
- **A panel of its own on the right** with its own scrollbar, on windows 1200 px and wider:
  - **概览:** 此刻在线 (who used the app in the last 15 minutes, each opening their account), 活跃 as bars against all
    accounts, 账户 and 积分.
  - **收益:** the exports (the curve as a PNG, the days as CSV) and how each figure is worked out.
  - **用量:** each model's requests, tokens and cost.
  - **用户:** the search and filters, beside the table.
  - **An account's page:** its permissions, 增加积分 and 在所有设备上退出, beside its numbers and records.

  On narrower windows the panel's content comes after the page's figures, and on 用户 before the table.

- **Hierarchy:** the main column is wider than the panel (about 3 : 1). Text runs from 48 for the big figure to 24 for
  the grid's figures to 14 and 12 for labels, with the same spacing steps as the app.
- **The server:** 概览's data now carries the period before with the same sums (new accounts, AI requests, tokens and
  cost, money, 积分), which the changes are measured against.
- **Keyboard:** Tab reaches every row and control in the panel; Enter on someone in 此刻在线 opens their account; Esc
  goes back.
- **Verified:**
  - 1 new server test (the period before, worked out by hand on one day and on two).
  - 7 new 管理后台 tests:
    - the panel at the right on a wide window, with its own scroll both ways;
    - the panel after the content on a narrower one;
    - the big figure at 48 px or more;
    - four figures to a row;
    - 用户's filters and an account's actions in the panel;
    - Tab and Enter to someone online;
    - every figure's change with its sign, arrow and colour.
  - 676 server tests and 56 管理后台 tests pass.
  - Screenshots in light and dark at 1440, 1024 and phone width.
  - harness PASS.

### v12.2.0 (2026-10-30): one grid, spacing scale, type ramp and alignment rules across the app

You asked to unify the grid, the spacing between components, the type scale and the alignment rules across the whole
app, so every page is more orderly (「对整个app进一步统一网格系统，组件间距，字体比例和对齐规则」). This is the second step
of stage S24. It is committed locally and goes out with v13.0.0.

- **On a computer or tablet the pages sit in a centred column:**
  - **Before:** on a wide window the cards stretched across the whole screen, 1,200 px and more.
  - **Now:** every page is a column at most 720 px wide, centred, with margins by window size: 16 on a phone, 24 on a
    tablet, 32 on a desktop.
  - **The tarot page** gets a wider column (1,200), so the spreads keep their full-size cards.
  - **Phones** look as before.
- **One spacing scale:** every gap and padding is a step of 4 (2, 4, 8, 12, 16, 24, 32, 48) or one of a few named
  uses, such as a card's inside (20) and a field's height (52, as tall as the main button). About 75 odd values (6, 7,
  9, 10, 14, 3.5, "16 + 4" …) are gone.
- **One type ramp:** twelve roles in eight sizes from 11 to 48, with line heights set for Chinese text and no letter
  spacing; titles semibold. Long text has its own fixed styles:
  - **A reading's paragraphs:** 16 / 28.
  - **Notes and examples:** 14 / 24.
  - **Small notes:** 12 / 20.

  These replace about 25 one-off line heights (1.5, 1.6, 1.65, 1.7, 1.75, 1.8). Chart labels now use the ramp's
  smallest size.

- **Alignment rules:**
  - **Section titles:** 首页's 东方 and 西方 now start on the cards' left edge (they were 4 px in).
  - **Bullets and icons** before text that wraps now sit centred on the text's first line, worked out from the text's
    size instead of a guessed nudge.
  - **In the 四柱 grid,** a row's label sits level with the middle of its 干支 instead of at the top.
  - **Empty pages** (以往记录, 内容审核) have one look: icon, message, the same room above.
  - **Corners:** one scale (2, 4, 8, 12, 16, 20, 24).
- **Fixed:**
  - **A long label could run off the screen.** A label pill (喜 / 忌 on the 一生运势报告, which the AI may write as a
    sentence) ran past the page's edge; it now wraps.
  - **Colours:** the 一生运势 page's 喜 and the 八宅 grid's good directions used a fixed green that read badly in dark
    mode; they now take the theme's success colours.
- **For future work:** the rules are in the ui-design skill (`.claude/skills/ui-design`), and a test now fails on any
  screen that breaks them, in the app or the 管理后台. It checks for a colour written in a widget, a font size, a bare
  number as a gap, padding or corner, and a line height of its own. Drawn objects (coins, the 签, tarot backs) keep
  their own.
- **Verified:**
  - 5 new tests: window classes; the type ramp; 首页 at phone, tablet and desktop widths (margins, the 720 column,
    titles on the cards' edge); the rules, against good and bad examples; every screen of the app (and, in the
    管理后台, every page) clean.
  - 250 app tests and 49 管理后台 tests pass.
  - Screenshots checked with the real Chinese font.
  - harness PASS.

### v12.1.0 (2026-10-30): one light and dark theme system, and 外观 to switch it

You asked for a unified light and dark theme system that defines the background, card, text and accent of each, keeps
the layout when the theme changes, and lets colours, borders and states fade naturally (「建立统一的浅色和深色主题系统…」).
This is the first step of stage S24 of the [tech plan](docs/tech-plan.md). It is committed locally and goes out with
v13.0.0.

- **One set of colours per theme:** each theme now defines the same tokens: page background, card, raised (dialogs),
  inset (fields and tiles inside a card), hairline and strong borders, text, secondary and muted text, the accent (朱砂)
  with its soft fill, success, warning, danger and info with their fills, the 五行 and the chart colours. They are in
  one file, light and dark side by side (`app/lib/presentation/tokens.dart`). The app and the 管理后台 both take their
  colours only from there.
  - **Light:** warm paper (`#F6F3EE`) with white cards.
  - **Dark:** warm near-black (`#121010`) with dark brown cards.
  - **Readable:** every text colour, the accent, the states and the 五行 are at least 4.5 : 1 on every surface in both
    themes.
- **外观 (new):**
  - **In the app:** ☰ → 外观 → 跟随系统, 浅色 or 深色. The choice is kept on the device like the language.
  - **In the 管理后台:** the new button in the top bar. The choice is kept in the browser.
  - **Keyboard:** Tab reaches it, Enter opens it, the arrows move through the choices and Enter picks one.
- **A change of theme fades:** every colour, border and state moves to the other theme over 0.3 s. This includes the
  五行, the 签 paper, the title's mark, the 求签 altar's shadows and the chart lines, which used to switch abruptly
  half-way. Nothing moves or changes size. The keyboard focus outline now fades in and out too.
- **Fixed:** a change of light and dark while the app was open (the system switching at sunset, say) crashed the theme
  animation in Flutter's chip theme, so the page stopped redrawing. The new 外观 switch would have hit the same crash.
- **Verified:**
  - 8 new tests:
    - colour contrast in both themes;
    - Material's colours are the tokens;
    - the home page and the menu laid out identically in light and dark;
    - a switch from the menu, with colours checked half-way;
    - the theme the app starts in;
    - 外观 in the 管理后台 by mouse and keyboard.
  - 245 app tests and 48 管理后台 tests pass.
  - Screenshots of both themes were checked with the real Chinese font.
  - harness PASS.

### v12.0.1 (2026-10-30): a card's focus ring only for the card itself

Found while checking the 管理后台 in a browser (tech plan S23). Committed locally; it goes out with the next big
update.

- **Fixed, in the app and the 管理后台:** a card drew its keyboard focus ring round itself while a field or button
  inside it had the focus, so two rings showed at once (on the 管理后台's sign-in card, as the page opened). Now a
  card rings only when Tab reaches the card itself (a card that opens something, such as 每日一牌); a field or button
  inside shows its own outline alone.
- **Verified:** 1 new app test (a field in a card, a button in a tappable card, Shift+Tab back to the card), which
  failed before the fix; 240 app tests in all; harness PASS.

### v12.0.0 (2026-10-30): 管理后台 — the admin dashboard, served at /admin/

Your request (「新建一个新的project folder- admin dashboard，这个专门用来管理app下的所有账户…」), stage S22 of the
[tech plan](docs/tech-plan.md), complete. Pushed.

- **Open it:** `npm run admin:build` (once, and again after a change to `admin/`; about a minute), then `npm run api`,
  then **http://127.0.0.1:8787/admin/**, and sign in as `admin` / `admin`. The console says where it is
  (`管理后台: http://127.0.0.1:8787/admin/`), or that it isn't built yet. Details: docs/web-test.md, 管理后台.
- **What the stage brought:**
  - **The server's part (v11.2.0):** every AI job's tokens and cost are recorded; accounts have a role, a status,
    permissions and their last activity; suspension and permissions take effect at once; the admin API.
  - **Demo data (v11.3.0):** 36 demo accounts with 90 days of history fill every page (filter them on 用户).
  - **The dashboard (v11.4.0):** 概览 (revenue, AI cost, gross profit and margin, accounts, active users, tokens,
    积分), 用户 and each account's page (停用账户, 管理员, AI and 充值 permissions, 增加积分 with a note, 在所有设备上退出, its
    积分 ledger and AI jobs), 活跃, 收益 (the revenue curve each day or added up, PNG and CSV), 用量 (tokens by day,
    by kind of job, by model), 导出 (the 经营报表 as PDF or Word, CSV).
- **New in this release:** the API serves the dashboard itself on its own address, so the dashboard needs no
  settings, and CanvasKit (Flutter's drawing engine) comes from the API too, not from Google's servers.
  `MINGLI_ADMIN_DIR` serves another build, `off` none. The harness now checks the dashboard at every update: its
  analysis, its 45 tests and a web build.
- **Verified:** 5 new server tests (the page and each file by its type, `/admin` sent to `/admin/`, no file from
  outside its folder, nothing served without a build, the public mode's app leaves `/admin/` alone), 675 in all; a
  private API on a spare port served the built dashboard, the admin API answered the `admin` account, and headless
  Chrome showed the dashboard's sign-in page; harness PASS with the dashboard's gate.

### v11.4.0 (2026-10-29): 管理后台 — the dashboard

Your request for an admin dashboard, step WP22.4 of stage S22: the dashboard itself, in its own project folder,
`admin/`. Pushed after its tests, as you said (你测试完成了可以push).

- **What it is:** a web app of its own for admins only: an account with the admin role, or a login in the server's
  `MINGLI_ADMINS` (in development `admin`/`admin`). Any other account is turned away (这个账号不是管理员), and so is
  a suspended one. It looks and works like the app: the same theme, cards and keys. The session lives in the browser
  tab only; closing the tab signs out.
- **Six pages**, in a rail on the left (on a phone, a bar at the bottom). 概览, 收益, 用量 and 导出 show the last 7, 30
  or 90 days (Beijing time).
  - **概览:** 充值收入 with its net (after the payment fee and VAT), AI 成本, 毛利 and its margin, accounts (new,
    suspended, admins, demo), who is active, tokens, and 积分 sold, granted, used and still unused. Under them the
    revenue curve and what each kind of AI job cost (八字 AI 解读, 塔罗 追问, 一生运势报告 …).
  - **用户:** every account with its status, 积分 balance, 充值, 积分 used, AI requests, AI cost, last activity and
    sign-up day. Search by username or the start of the account ID; filter by status, role and demo; click a column
    to sort (the largest first, again for the other way); 25 to a page.
  - **An account's page** (click its name): its details; switches for **停用账户** (asks first; it is signed out
    everywhere at once), **管理员** (asks first), **可以用 AI** and **可以充值**; **增加积分** with a note (asks first;
    100, 1,000 or 5,000 at a tap); **在所有设备上退出**; its 积分 ledger, its latest AI jobs and its use by kind. You
    can't suspend yourself or take your own admin role, nor take the role from an admin the server names.
  - **活跃:** who used the app in the last 15 minutes and 24 hours, and how many in 7 and 30 days; it fetches itself
    again every minute. Each name opens the account's page, to sign it out or suspend it.
  - **收益:** the revenue curve (充值, AI 成本, 毛利), each day or added up (累计); **导出图片（PNG）** saves the chart,
    **导出数据（CSV）** its numbers; under it every day's money, accounts and AI jobs below the period's sums.
  - **用量:** tokens, AI requests, their cost and the average per request; tokens per day (input and output); use by
    kind of job and by model.
  - **导出:** the 经营报表 as PDF or Word, the revenue curve and the user list as CSV. The browser downloads them.
- **The curve:** point at it, tap it, or Tab to it and press ← / → (Home, End): the day's numbers show under it.
  Its three colours stay apart for colour-blind readers too, in light and dark mode.
- **Keys:** Tab reaches every control; Enter or Space presses; Esc closes a question, then goes back a page; ← / →
  change the period and the filters; Ctrl+Enter signs in and 增加积分; Ctrl+/ lists the keys; a table wider than the
  screen scrolls with ← / → once Tab has reached it.
- **When something fails:** a part that couldn't load is asked for again a few times (about 3 s), then says why, with
  **重试**; the rest of the page still shows. An expired session is renewed once for all the page's requests; a
  session that has ended (suspended, no longer an admin) goes back to sign-in.
- **To try it now:** `npm run api`, then, through an ASCII junction to the repository (Flutter needs an ASCII path
  here), `flutter run -d chrome` in `admin/`, and sign in as `admin`/`admin`: the 36 demo accounts fill every page.
  From v12.0.0 the API serves it at `/admin/` (`npm run admin:build`).
- **Server:** a page on another origin (the dashboard under `flutter run`) can now read an export's file name.
- **Verified:** 45 dashboard tests (sign-in and the session, every page against a fake API, the account's actions,
  phone and wide layouts, the keyboard, no bare tap targets), analyze clean, a web build; the pages rendered with a
  Chinese font and looked at, in light and dark; one new server test (670 in all); harness PASS.

### v11.3.0 (2026-10-29): 管理后台 preset data — demo accounts with 90 days of history

Your request (「为了展示效果，可以设置一些preset的data 到各个用户」), step WP22.3 of stage S22. Pushed.

- **36 demo accounts** (`demo-01` … `demo-36`, marked demo) are made at a development start when a store has none,
  each with 90 days of history: they sign up (more as the weeks go on), 充值 by the packs when they run low, and ask
  for readings across 八字, 塔罗, 求签, 算卦 and 风水, with 追问, 深度分析, plans and 一生运势报告. Each request's tokens
  lie near its estimate at Claude Opus 5.5's prices, and its 积分 are charged as the server charges them; a few
  requests fail and cost nothing. Some got a welcome grant with a note, two are suspended, one has AI turned off,
  and some were active minutes ago, so every table and list has something in it.
- **What it adds up to** (at the time of a start): about 570 AI jobs (49, then 156, then 365 in each 30 days), 108
  top-ups, ¥2,720 of 充值, ¥917 of AI cost, ¥1,623 gross profit (a 63.9% margin).
- They have no password, so nobody can sign in as them. The same seed gives the same history; with
  `MINGLI_STORE=pglite` they are made once and kept. `MINGLI_ADMIN_DEMO=off` leaves them out of a new store.
- **Verified:** 4 new server tests (the same every time; every charge its job's measured cost or the 深度分析's fee;
  balances never below nothing; a growing curve; the database store takes the same history), 669 in all; a dev
  start read back through the admin API; harness PASS.

### v11.2.0 (2026-10-29): 管理后台, the server — accounts, AI use, money and the admin API

Your request for an admin dashboard, as stage S22 of the [tech plan](docs/tech-plan.md); this first step is the
server it reads (the dashboard itself, `admin/`, comes in v11.4.0). Pushed, as you said (做完了可以直接push).

- **Every AI job's use is recorded:** each step of every reading, 一生运势报告, 追问, plan and 深度分析, with its
  model, input, output and cache tokens, its cost at list price and whether it delivered. Numbers only, never a text;
  kept when an account is deleted, without its owner, so the totals stay.
- **Accounts gain** a role (user or admin), a status (active or suspended), two permissions (AI readings, 充值), the
  time of their last request (to the minute) and a demo mark.
  - A **suspended** account can't sign in, its sessions end at once, and the app signs it out with the message
    这个账号已被管理员停用.
  - With **AI readings off**, every AI request is refused (`ai_not_allowed`); with **充值 off**, 充值 is.
- **Admins** are the logins in `MINGLI_ADMINS` (by default `admin`) and any account an admin gives the role; an admin
  also reviews in 内容审核. An admin can't suspend or demote themselves, so there is always a way in.
- **The admin API** (`/v1/admin/*`, admins only): the KPIs; day by day (the revenue curve: 充值, its net after the
  payment fee and VAT, the AI cost in 元, gross profit and margin, tokens, AI jobs, new and active accounts, 积分
  sold, granted and used); AI use by method and by model; every account with its balance, spending, AI use and last
  activity (search, filters, sorting, pages); one account's details; suspend or reactivate, the role, permissions,
  sign out everywhere, 增加积分 with a note; the active accounts (15 minutes, 24 hours, 7 and 30 days); and exports:
  the revenue curve and the accounts as CSV, a period's report as PDF or Word. Days are counted in Shanghai time.
- **In the app:** 我的积分 shows an admin's grant as 管理员赠送 with its note.
- **Verified:** 18 new server tests (every figure worked out by hand, the API, suspension, permissions, the database
  store), 665 in all; 2 new app tests, 239 in all; harness PASS.

### v11.1.0 (2026-10-29): 有所求才能去求 — 塔罗, 求签 and 算卦 are drawn only for a question

Your requests (「求签和算卦 算法必须要有所问之问题之后才能去求 … 是必须要有所求才能去求」, 「塔罗牌也是一样」), as stage S21 of
the [tech plan](docs/tech-plan.md). A medium update: committed and tagged here, pushed with the next big one.

- **In the app:** on 塔罗, 求签 and 算卦 the draw waits for the question. 抽牌, 求签, and 算卦's 掷币, 摆好硬币, 看卦 and
  起卦 stay grey until something is written (spaces alone don't count), and a line says 先写下你想问的问题，才能抽牌 /
  先写下所求之事，才能求签 / 先写下想问的事，才能起卦. Enter in the field and Ctrl+Enter wait too. The labels no longer
  say （可选）. An example question fills the field with one touch.
- **塔罗:** once 抽牌 is pressed the question can't change until the cards are out, so the cards are drawn for the
  question asked.
- **On the server:** a 塔罗, 求签 or 算卦 draw without a question is refused before anything is drawn
  (`question_required`). The question is kept with the draw, sealed like it, and the reading (and a 深度分析)
  answers that question, whatever a later request says. A draw made before this update reads with the question
  sent with the reading, as before.
- **Not changed:** 每日一牌 is the day's card, dealt without a draw, so it needs no question; 八字 and 风水 aren't
  drawn either.
- **Verified:** 8 new server tests (no draw without a question, the question kept and answered, older draws, the
  深度分析, 每日一牌), 647 in all; 3 new app tests (each page waits for the question by button, Enter and Ctrl+Enter,
  and sends it), 237 in all; the older tests now ask before they draw; harness PASS.

### v11.0.0 (2026-10-29): 积分 — every AI request paid at what it really cost

Your request (「GO AND BUILD THE POINTS SYSTEM NOW」), as stage S20 of the [tech plan](docs/tech-plan.md). A big update:
pushed. Payments stay simulated for now, as you asked (暂时采用模拟策略).

- **Packs (充值):** 10元 = 1000 积分, 20元 = 2200, 30元 = 3450, 40元 = 4800, 50元 = 6250: 5% more for each 10元 from
  20元 up, 25% more at 50元. They are in `config/points.json`, so you can change them.
- **What a request costs is measured (「看看有没有办法知道当前的提交问题给花费了多少」):** every AI call reports the tokens
  it used, and the server prices them at the model's list price (Claude Opus 5.5: $4 / $20 per million input / output
  tokens). That cost is the charge, turned into 积分 at 1,953.96 积分 a dollar: the price that keeps a 50% margin even
  on the cheapest 积分 (the 50元 pack's, after the 0.6% payment fee and 6% VAT, at 7.3 CNY a dollar).
- **How a request is charged:**
  - Before it runs, its estimated price is held (1.5 times the estimate, never more than you have); two requests at
    once can't use the same 积分.
  - When it has finished, it is charged what it really used, at most what was held; the rest is released.
  - A request that failed or gave no result costs nothing.
  - With too few 积分, the app says 积分不足 (这次约需 688 积分，你现在可用 100 积分) and offers 去充值; nothing is made.
- **What things cost now, at Claude Opus 5.5** (estimates; each is then charged what it really used):

  | Request                                     | 积分            |
  | ------------------------------------------- | --------------- |
  | 八字 AI 解读 (six topics; fewer cost less)  | 688             |
  | 塔罗 (one card / three / ten)               | 419 / 470 / 647 |
  | 求签 / 算卦 / 风水                          | 329 / 376 / 327 |
  | 一生运势报告                                | 1,208           |
  | 追问 (八字 / 一生运势报告 / the others)     | 270 / 333 / 180 |
  | 破除运势 plan (八字 / 塔罗)                 | 303 / 231       |
  | 深度分析 (统一收费, however many questions) | 747             |

  `ACTIVE_AI_MODEL` moves every price with the model: Claude Sonnet 5.5 halves them.

- **深度分析's 统一收费 (「对话了解阶段给一个统一的收费」):** one fee for the whole conversation, however many questions
  the master asks (1–6). It is charged once the first question has come, and nothing if it never comes; the final
  reading after it is paid as any reading. If a conversation's AI use would pass what its fee covers at the 50%
  margin, the master asks no further question and you go on to the reading.
- **模拟 (「为了节省预算，我们可以暂时采用模拟策略。给所有dev给个相应的分数去进行计算」):** 充值 is simulated: tap a pack and
  its 积分 arrive, nothing is paid. The dev accounts (admin, xumei, qianli, wuyong, leonfighter, test@mingli.local)
  start with 10,000 积分 each, given once. While `IS_AI_MOCK=TRUE` no tokens are used, so each request is charged its
  estimate; with the real model each charge shows 按实际用量 and its AI cost in dollars.
- **In the app:**
  - ☰ → **我的积分** with what is available, beside it in the menu.
  - Its page shows what is available and what running requests hold, the packs (模拟充值), how charging works, and
    every change: what it was for, how it was priced, the AI cost, and the balance after.
  - Under every AI button its price: 约 688 积分 · 完成后按实际用量扣除 · 可用 10000; under 深度分析 its 统一收费; under
    一生运势报告 its price. 追问 says 每问约 270 积分; a plan says 解锁 · 约 303 积分.
- **破除运势 plans are now made when bought** (about a minute), no longer made ahead after every reading: a plan made
  ahead costs tokens nobody pays for, which a 50% margin can't carry. With 积分 off they are made ahead again.
- **Switch:** `MINGLI_POINTS=off` in `.env` makes every AI request free, as before. The console says which is on.
- **Verified:** 26 new server tests (the packs and the margin worked out by hand, every price, the model choice, the
  ledger in memory and in the database, two requests at once, a restart, every request charged or not, the
  深度分析's fee and its guard, 充值, the dev accounts), 639 in all; 9 new app tests (我的积分 on a 360 × 740 phone, the
  prices, 积分不足 → 去充值, 追问, plans, keyboard, 繁體), 234 in all; harness PASS. Not tried: a charge from the real
  model, which waits for your run with it.

### v10.0.0 (2026-10-29): 深度分析 — the master asks first; the mic; 同名重算

Your requests of today, as stage S19 of the [tech plan](docs/tech-plan.md). A big update: pushed, with v9.1.0–v9.3.0.
积分 is planned for later, as you asked (S20 in the tech plan, with what each reading costs at Opus 5.5's prices).

- **深度分析 (细节对话):** on 八字, 塔罗, 求签, 算卦 and 风水, a second button under the AI button. Before the reading,
  the master asks about your situation, one question at a time, from what the chart or the cards show and what you
  want to know.
  - Each question comes with what the master sees, or what it makes of your last answer (合理推断). What you most want
    to know may change with your answers (your example: from whether to break up, to whether you will find someone
    after): the master follows it, and the final reading answers that.
  - Fewer questions for a smooth chart, more for a hard one, never more than 6. The master decides on its first
    turn, and the page shows which question it is: 第 2 个问题 · 大师打算问 3 个（最多 6 个）.
  - The page says 大师现在有问题要问你 and 回答完这些问题，大师才能给你最终解答. 跳过剩下的问题，直接解答 goes straight to the
    reading with what was said. When the master is done, it says what it understood and 开始最终解答 makes the reading.
  - The final reading reads every question and answer, answers what you most want to know first (八字: in the 总结
    too), and shows the conversation at its top, folded.
  - It needs a clear goal: the question asked before drawing, or for 八字 为谁排盘's 想了解的事. Without one, a dialog
    asks for it first: 使用深度分析，一定要先给出一个明确的目标.
  - The master asks about you and what you know, never hints that someone cheats or lies: your example
    「可能是她在外面有了别的什么事」 becomes 「她那边最近有没有什么你还不清楚的情况？」.
- **麦克风:** a mic button beside the 深度分析 answer, the goal and the 追问 fields: tap, speak, and the words appear in
  the field. It uses the browser's speech recognition. Chrome sends speech to Google, which mainland China can't
  reach: there Edge and Safari work, or the phone keyboard's own voice input. Where the browser can't listen
  (Firefox), there is no button.
- **同名重算:** before a new 测算, if the same person already has a finished one, the app asks
  之前已经算过，是否还要重新再算一次？ with 查看之前的 and 重新再算. For 八字 (and 一生运势) the same person counts; for a 卦
  (塔罗, 求签, 算卦, 风水) the same person with the same question, since a new question is a new 卦.
- **How to try it:** restart `npm run public`. While `IS_AI_MOCK=TRUE` the master is a demo (two （示范） questions);
  with the real model it judges the chart and plans its own questions. The questions use Claude Opus 5.5 at effort
  low, so each comes quickly; the readings stay at medium.
- **Fixed on the way:** `ACTIVE_AI_MODEL=claude-opus-5-5`, the model every step already uses, put every step at the
  model's default effort, so the questions would have run at medium. Naming the table's own model now keeps each
  step's settings; another model still answers every step at its own effort.
- **Verified:** 19 new server tests (the pipeline, each method's own prompt, the reading reading the conversation, the
  API, the model choice keeping each step's settings), 613 in all; 12 new app tests (the page, the goal reminder, the
  mic, 同名重算, keyboard, a 360 × 740 phone), 225 in all; harness PASS, run again before the push as you asked. Not
  tried: a real conversation with the real model.

### v9.3.0 (2026-10-29): 八字's AI reading is the AI's own, with a 总结; no 行动建议 or 比如 examples

Your two requests of today, as stage S18 of the [tech plan](docs/tech-plan.md). A medium update: kept locally until
the next big one.

- **Two readings, side by side:** the engine's reading stays as it was: the 命盘事实 card, the trend chart and the
  破除运势 plans. The button for the AI's reading now says 用AI做更精确解读.
- **What the AI reads (「尽量不采用引擎数据」):**
  - the person's 排盘: pillars, 十神, 合冲刑害, 神煞, 大运 and 流年;
  - what the profile says about them: name, residence, marriage, children, work, family, what they want to know;
  - their question and today's date.

  Not the engine's own judgements: its 身强 / 身弱 count, its 喜用 and 忌, its weighted 五行 or its trend scores. The
  AI judges 旺衰, 格局, 调候, 喜用 and each 大运 and 流年 itself, and says how. The 排盘 itself is still the
  engine's: models get 干支 and years wrong (one run called 2027 丙午; it is 丁未), and the reading must match the
  chart on its page.

- **What the AI writes:**
  - It opens with a **总结** in nine parts, written to the person by name: 你是怎样的人, 过去, 现在, 可能遇到的问题,
    得势与得失, 未来运势, 何时开始要注意, 何时开始要发力, 遇到问题时怎么办. Each is 150–400 characters, with
    years and 虚岁 where they matter.
  - Then the six sections, each in detail: 术语 first, then 评论 (the conclusion, why, how it shows, what to do).
    大运流年 is the most detailed: a paragraph for the current 大运, the next one, and each year in focus.
  - It says things straight, without piled-up hedges. A hard period is named as a warning with what to do about
    it, never as fate.
  - No 比如 examples and no 行动建议: the 总结 says what to do.
- **On the page:** the 总结 card comes first in the AI part, after the engine's facts, and the jump list has a 总结
  chip. The 行动建议 card shows only for readings that have actions (older 八字 readings, the other methods).
- **Everywhere a reading goes:** Word / PDF and Markdown exports, the report email and 追问 carry the 总结.
- **Other methods are unchanged:** 塔罗, 求签, 算卦, 风水 and 起名 keep their examples and 行动建议.
- **The rules, kept:** a new project skill, [ai-reading](.claude/skills/ai-reading/SKILL.md), holds your
  requirements for AI readings and how each is checked. CLAUDE.md points to it.
- **How to try it:**
  1. Restart with `npm run public`.
  2. On 八字排盘, compute a chart and press 用AI做更精确解读.
  3. While `IS_AI_MOCK=TRUE`, every part reads （示范）. With the real model, the 总结 is the AI's.

  `npm run eval:ai -- --live` records each 八字 case's 总结 and how many of its nine parts came back.

- Verified:
  - 9 new server tests:
    - what the AI reads: no engine judgements, while a plan still has the engine's 喜用;
    - the 总结: all nine parts, in order; a part that cites nothing is sent back, then left out;
    - 大运流年 keeps up to six paragraphs;
    - the faithfulness check reads the 总结: a year with the wrong 干支 is caught;
    - 追问 and the email carry the 总结;
    - the new prompt's rules.

    The view tests fail when the engine's judgements are sent again.

  - 5 new app tests: the button label; the 总结 card first and in order; no 行动建议 on 八字 and still on 塔罗; a 八字
    paragraph without an example; the export.
  - 594 server tests and 213 app tests pass; harness PASS.
  - Not tried: a real reading (your switch says mock).

### v9.2.0 (2026-10-29): Claude as the AI service, Claude Opus 5.5 by default, and the models to choose from

Your request of today (a Claude AI service besides DeepSeek, 可以用的 models, Claude Opus 5.5 from now on), as stage
S17 of the [tech plan](docs/tech-plan.md). A medium update: kept locally until the next big one.

- **Claude Opus 5.5 answers every AI step:** readings, their advice, 破除运势 plans, the 一生运势报告, 追问, and the
  content review when it is on. DeepSeek stays, one setting away. A reading names the model that wrote it
  (`claude-opus-5-5`), as before in its Word / PDF export.
- **Your keys:** `CLAUDE_API_KEY` in `.env` (your name for it; `ANTHROPIC_API_KEY`, the SDK's own, works too), and
  `DEEPSEEK_API_KEY` as before. Your Claude key was checked once against Anthropic's model list (free, no tokens): it is
  accepted from this computer, and all four Claude models below are open to your account.
- **The models to choose from:** `ACTIVE_AI_MODEL=<id>` in `.env` (your name for it) puts every step on one model:
  - `claude-opus-5-5`: Claude Opus 5.5, the default ($4 / $20 per million tokens, in / out);
  - `claude-fable-5-1`: Claude Fable 5.1, the most capable ($10 / $50; Anthropic keeps its requests for 30 days);
  - `claude-sonnet-5-5`: Claude Sonnet 5.5, balanced ($2 / $10);
  - `claude-haiku-5-5`: Claude Haiku 5.5, the fastest and cheapest ($0.10 / $0.50);
  - `deepseek-v4-pro`: DeepSeek V4 Pro, the model until now.
  - Your `.env` said `ACTIVE_AI_MODEL=claude-v1`, the name of Claude 1, which the API no longer serves; it now says
    `claude-opus-5-5`. An id that isn't in the list is ignored, and the console says so and lists the usable ones.
- **How to use it:**
  - `npm run ai:models` lists the models, which one answers now, and whether each provider's key is in `.env` (never
    the key itself).
  - The running API follows a change to `ACTIVE_AI_MODEL` from the next reading, with no restart, as it does for
    `IS_AI_MOCK`. A new key needs a restart.
  - The AI switch is unchanged: `IS_AI_MOCK=TRUE` (as now) keeps the mock; `IS_AI_MOCK=FALSE` brings Claude Opus 5.5.
    The console line says which model would answer and what is still missing, and `/v1/health` adds `ai_model` while a
    real model answers.
  - `npm run eval:ai -- --live --model claude-sonnet-5-5` runs the evaluation cases on any model in the list and records
    each case's cost at list price.
- **Fixed on the way:**
  - The Claude provider, kept since Phase 1 but never used, could not have sent a reading: the SDK refuses a request
    that isn't streamed above about 21,000 tokens, and a reading asks for 32,000. Every request is now streamed.
  - Claude Opus 5.5 thinks before it answers, and its thinking counts toward the limit, so a reading may now use up to
    64,000 tokens (the other steps 32,000), at Opus 5.5's own default effort, medium. Claude Haiku 5.5 is sent without
    the refusal fallback it doesn't have.
  - Five tests that had put their scripted provider under DeepSeek's name now cover whichever provider answers.
- Verified:
  - 14 new server tests: the provider through the real SDK over a stubbed network (a 64,000-token request goes out as
    a stream; the answer is read after a thinking block), your key being the one sent, the model list and its prices,
    the routing check, a reading on a chosen model, and a running API following `ACTIVE_AI_MODEL` from the next
    reading.
  - The API started once with your `.env`: its console line, `/v1/health`, and one (mock) reading.
  - 585 server tests and 208 app tests pass (the app's fixtures now name `mock/claude-opus-5-5`); harness PASS.
  - Not tried: a real Claude reading. Your switch says mock; once you flip it, `npm run eval:ai -- --live` tries the
    cases, and costs money.

### v9.1.0 (2026-10-29): a cleaner home bar; what a tap brings up comes into view; the 求签 altar

Your four requests of today, as stage S16 of the [tech plan](docs/tech-plan.md). A medium update: kept locally until
the next big one.

- **首页's bar:**
  - 历史记录 moved into the ☰ menu, first in it. The bar now holds only the app's mark and name on the left and ☰ on
    the right.
  - ☰ is framed (a 赭红 outline on a light tint), and the menu now slides in from the right, where ☰ is.
  - Before 命理大师: the app's mark, the 太极 in the 先天八卦 as on the icon. It is drawn in code, so it stays sharp at
    any size and takes the theme's colours, light and dark. The name is bold and spaced, shading from 赭红 to gold.
- **What a tap brings up comes into view by itself** (your rule: 这类新生成的component 要避免用户下滑后再点击):
  - 塔罗: 抽牌 brings up 洗牌 · 切牌 · 选牌, also when it is open already. After 切牌, the 78 cards come up from their
    top. Then the drawn spread, and, once the last card has turned, 生成解读.
  - 风水: 看布局 brings up the room's principles.
  - 求签: the altar as the lot is drawn. It stays in view as each step adds a row, and the lot comes up once the 圣筊
    lands.
  - 算卦: the tosses (each 擲下一爻 keeps the card and its button in view), the coins laid out for 自己挑币, and the
    hexagram once the coins that make it have landed or turned.
  - 起名 (still off): the names.
  - The page scrolls only as far as it must: a new part ends just inside the bottom of the screen, with what you
    tapped still above it. One taller than the screen comes to the top. Nothing moves when it is in view already. With
    the system's reduce-motion setting on, it jumps instead of gliding.
  - Taps work while the page moves. Flutter normally ignores them during a scroll animation, which would have lost
    the tap on a button that had just come up.
- **求签's new animation (甩签):**
  - A 签筒 full of sticks tilts forward and is shaken. One stick works its way out, drops to the floor in front and
    glows; then 摇出第…签.
  - 掷筊: the two 筊杯 are thrown, tumble in the air and land on their faces beside the stick; then what they mean.
  - 放回再摇 puts the stick back and shakes again. 直接看结果 still shows everything at once, and with reduce-motion on
    each step ends at once.
  - While it moves, the card says 摇签中…… or 掷筊中……; the next step's button comes when it is done.
- **Fixed on the way:** the `.vscode/` and `build/` folders that VS Code's CMake extension made at the top of the
  project are now git-ignored. Prettier read them, and the lint gate would have failed.
- Verified:
  - 12 new app tests:
    - the scroll on its own: a part below the fold, one taller than the screen, one in view already, one that grows,
      and reduce-motion;
    - each page on a 360 × 740 phone (塔罗 through to 生成解读, 风水, 求签 through to the lot, 算卦 through to the
      hexagram). These fail with the scroll turned off: before, the tarot ritual started 3 px above the screen's
      bottom edge;
    - the 求签 stage: when it says the stick lies still and the blocks have landed, 直接看结果 halfway, reduce-motion.
  - The home bar's tests now check the mark, the name, the framed ☰ at the right end, the menu from the right and
    历史记录 in it.
  - Looked at rendered with the real font: the bar in light and dark, the menu, the shake and the throw frame by
    frame, and the tarot ritual and 风水 principles after the tap.
  - 571 server tests and 208 app tests pass; harness PASS.

### v9.0.0 (2026-10-29): reports by email; stage S15 complete (menu, icon, logins, email)

Stage S15 of the [tech plan](docs/tech-plan.md) is complete, and its summary is there. It covers your whole request:
the ☰ menu and the icon (v8.1.0), signing in with a username, email or phone (v8.2.0), and now reports by email. A big
update: pushed. As you asked, this is the framework: no mail or SMS service is connected yet. Choosing them is the next
step; until then the server writes everything to the `.outbox/` folder instead of sending it.

- **设置 → 报告 → 测算完成后发到邮箱:** 否 by default.
  - It can be turned on once your email is verified (设置 → 邮箱, with a code).
  - When on, every reading (八字, 塔罗, 求签, 算卦, 风水, 起名) and every 一生运势报告 is mailed to that email when it
    is done. The report is in the message itself, and attached as a PDF named as a download is.
  - A report held for review goes when a reviewer releases it. A failed one never goes.
  - The mail ends by saying why it came and where to turn it off. It carries the AI label and the disclaimer, as
    every export does.
  - A mailed 一生运势报告 has all its text, with the 卦辭 and 爻辭. The 卦图 and tables stay in the app, and the mail
    says so.
- **以往记录 → ⋮ → 发到邮箱**, or **选择 → 发邮箱** for several: asks PDF or Word, then mails the files in one message to
  your verified email. It's the same document as 下载, and goes to your own email only.
- **The reading page** shows 这份报告已发到你的邮箱, or that it could not be sent. You can send it again from 以往记录.
- **The 选择 bar** now has four actions, 下载 · 发送 · 发邮箱 · 删除, each an icon over its label, so they fit a phone.
- **Without a mail service yet:**
  - 设置 says so under the switch.
  - Each mail is written to `.outbox/mail/` as an .eml file (open it in Outlook, Thunderbird or Windows Mail to see
    the report as the reader would, PDF attached), with a .txt beside it.
  - docs/web-test.md has the steps to try it.
- **Limits:** a message holds at most 10 records; 20 messages a day per account; a failed mail is noted on the record
  and not retried on its own.
- **The whole stage, for users:**
  - a clean home bar with the ☰ menu;
  - the app icon and the name 命理大师 on every platform;
  - sign-in by username, email or bound phone, with codes;
  - reports by email.
- Verified:
  - 15 new server tests:
    - times in each region's zone;
    - the reading and 一生运势 documents in 简体 and 繁體;
    - the HTML (everything escaped) and the text;
    - the MIME: the subject decodes back, lines within 78, the file name in RFC 2231 pieces;
    - mailed when done, not when off, a failing provider noted, a held report mailed on release, a 一生运势报告;
    - 发到邮箱 with two Word files, too many, no verified email, and no mail service (503).
  - 8 new app tests: the switch (否, waits for a verified email, turns on, back to 否 when the email goes), 发到邮箱
    without and with a verified email, the select bar at 360 wide, the reading page's mail line, and its absence.
  - Looked at rendered: a real reading's mail in headless Chrome, the select bar on a 360-wide phone, and 设置 → 报告
    with the real font.
  - 571 server tests and 196 app tests pass; harness PASS before the push.

### v8.2.0 (2026-10-29): sign in with a username, an email or a phone; codes that bind a phone to its owner

The third part of stage S15 (your request: 用户名、邮箱或手机号登录，手机号需要绑定用户本人). A medium update, kept
locally until v9.0.0. As you asked, this is the framework. No mail or SMS service is connected yet: that is the next
step, your choice.

- **Signing in:** one field, 用户名 / 邮箱 / 手机号, and the password.
  - The app tells them apart: with an @ it's an email; digits (or a leading +) a phone; anything else a username.
  - A phone counts only once bound. Written without its country code it is read in each region where it fits, and
    signs in when exactly one of those is bound.
  - A wrong login says 账号或密码不正确, the same for all three, in Chinese. It used to show the server's English.
- **Signing up:** a 用户名 and a password. The email is optional.
  - A username is 2–24 letters, digits, Chinese characters, `_ . -`, starting with a letter or a Chinese character.
    It is unique: Admin, admin and full-width ａｄｍｉｎ are the same name.
  - A taken name or email says so in Chinese.
- **设置 → 账号与登录:**
  - **用户名:** set or change it in a dialog.
  - **邮箱:** shown with 已验证 or 未验证. A tap verifies it, or changes it, by a 6-digit code sent there. A new email
    replaces the old one for signing in.
  - **手机号:** 绑定 sends a 6-digit code to the number, and only the code coming back binds it: that is what proves
    the number is the user's own. Type a local number for the account's region (9123 4567 in 香港), or any number with
    its country code (+65 9123 4567). 解绑 asks first.
  - A number bound to one account can't be bound to another. An account always keeps one way to sign in.
- **Codes:**
  - valid 10 minutes, 5 tries;
  - one a minute at most, five an hour to one number or address, ten a day per account;
  - kept only in memory, as hashes.
- **For now, nothing is really sent.** The server writes every code and mail to the `.outbox/` folder instead:
  - The console prints each text message: `sms (dev outbox): …: 【命理大师】你的验证码是 123456…`.
  - Mail goes to `.outbox/mail/` as .eml files (they open in Outlook or Thunderbird), each with a .txt beside it.
  - The app's dialog says so under the code.
  - Plugging in a provider later changes only the delivery code (`src/notify`).
- **The dev accounts** are usernames now: admin / admin, xumei / xumei, qianli / qianli, wuyong / wuyong, leonfighter
  / leonfighter. Readings kept in the database stay with them.
- Kept private: the username and the phone are encrypted with the account's key, and found for login by a keyed
  hash, as the email has been.
- Verified:
  - 22 new server tests:
    - telling a login apart, usernames, phone numbers for HK, TW and MY, local numbers at login, masks;
    - codes (once only, expiry, 5 tries, every limit);
    - sign-up by username, binding and unbinding a phone, signing in with it written four ways, a number bound
      elsewhere;
    - verifying and changing an email, the setting needing a verified email, renaming, no provider (503), moving an
      old dev seed, a reviewer by username;
    - the database across a restart, with the plaintext check.
  - 9 new app tests: sign-in sends the login, sign-up with and without an email and with a taken name, renaming,
    binding a phone (a wrong code, then the right one), a number bound elsewhere, verifying the email, the keyboard
    (Enter sends, Enter binds), no 测试环境 notice when a provider delivers, unbinding.
  - Looked at rendered with the real font: the sign-in and sign-up pages, 设置, and the binding dialog.
  - 556 server tests and 188 app tests pass; harness PASS.

### v8.1.0 (2026-10-29): the ☰ menu, and an app icon

The first two parts of stage S15 (your request: settings in one menu, an icon for the app). A medium update, kept
locally until the stage's v9.0.0.

- **The home bar is clean:** ☰ on the left, the title, and 历史记录 on the right.
- **☰ opens the menu**, which holds everything that sat on the bar:
  - at the top: the app icon, 命理大师 and the account you're signed in with;
  - then 历史记录, 个人资料, 语言, 设置, 内容审核 (reviewers only), 键盘快捷键 and 退出登录.
  - **语言** shows the current language, and a tap opens 简体中文 / 繁體中文 with the current one ticked.
  - Each item closes the menu and opens its page.
  - Keyboard: Tab reaches ☰ and Enter opens it. Tab then stays inside the menu, and Esc closes it.
- **设置** now holds only settings, under 账号与登录: the account, its region and how it signs in, then 退出登录 and
  注销账号. 内容审核 and 键盘快捷键 moved to the menu.
- **The sign-in page keeps 语言 on its bar**, since there is no menu before you sign in.
- **The app icon:** a 太极 inside the eight trigrams (先天八卦: 乾 at the top, 坤 at the bottom), gold on the app's
  赭红.
  - It is used everywhere: Android (with an adaptive icon for current phones), iOS, the web (the browser tab, the
    installed app and the iPhone home screen) and Windows.
  - At 32 px and below it shows the 太极 alone, so it stays clear on a browser tab.
  - Under the icon the app is now called 命理大师 everywhere. It was "mingli_app", or "Mingli App" on iOS.
  - One script draws every size: `npm run build:icons`. To change the icon, change the drawing in
    `scripts/app-icons.ts` and run it.
- **This reverses an earlier decision:** on 2026-10-27 you asked for 个人资料, 语言 and 设置 each to have its own button
  on the bar.
- Verified:
  - 6 new server tests: every icon file at its size, opaque where iOS needs it, the Windows .ico, the trigram order
    and the names.
  - The app tests rewritten for the menu: the bar's two buttons, the menu's order, each item, 语言, 退出登录, the
    keyboard (Tab stays inside, Esc closes), and both languages on a 360-wide phone. The tests that reached 设置,
    个人资料, 内容审核 or 语言 now go through the menu.
  - Looked at rendered with the real font: the bar, the menu and the 语言 dialog on a phone, and the icon at
    16–1024 px.
  - 534 server tests and 179 app tests pass; harness PASS.

### v8.0.0 (2026-10-28): 以往记录 — by month and by person; Word and PDF; send; file under a person; delete

Stage S14 of the [tech plan](docs/tech-plan.md) is complete (its summary is there): your request for organising,
downloading, sending and deleting past records. A big update: pushed.

- **History (历史记录) is now an archive of every reading and 一生运势报告.**
  - **按时间:** years, then months, newest first. 一生运势报告 now sit among the readings by date, not above them.
  - **按人:** one group per person, with the person whose latest record is newest first. Records filed under
    nobody come last, under 未归类.
  - Up to 100 readings are listed.
- **Whose record it is:**
  - a 八字 or 一生运势 record: its chart's person;
  - a new 塔罗, 求签, 算卦 or 风水 reading: your default profile at the time;
  - 起名: its 八字 chart's person.
  - **归类到…** in a record's menu files it under one of your profiles, a name you type, or nobody. This also gives
    older records back a name.
- **Each record's ⋮ menu:**
  - **下载 PDF** and **下载 Word**: the whole record as a document, the same as on screen. Its chart summary, the
    reading in three parts (term, commentary, example), the actions and the 追问 are all there. The AI label and the
    disclaimer come at the end, as on every export.
  - **发送**: asks PDF or Word, then opens the share sheet. On a phone you can send to WeChat, mail and so on. A
    computer's browser that can't share files downloads them instead.
  - **删除**: asks first, because it can't be undone. The reading goes with its 破除运势 plans and its 追问, and its
    chart too once nothing else reads it.
- **选择** (top right, or a long press on a record): tick several, then 下载, 发送 or 删除 all of them from the bar at
  the bottom.
- **Also:** the reading page's ⋮ and the 一生运势 page's 下载 offer PDF and Word too.
- **How the files are made:**
  - The server renders them from what the app shows. Nothing is kept on the server.
  - The PDF carries the server's Chinese font, so it reads the same anywhere; about 85 KB for a reading.
  - The Word file uses Word's own font (Microsoft YaHei).
  - PDF needs a Chinese font on the server, as share images do: on this computer it finds Noto Sans SC.
  - I tested three PDF libraries' handling of Chinese before choosing. One would have produced PDFs with blank
    Chinese text.
- Verified:
  - 13 new server tests:
    - documents: their checks, Word and PDF, a font collection's face;
    - deleting: a reading with its plans and 追问, a 一生运势报告, a chart kept while another record reads it, and a
      reading deleted mid-generation, in both stores;
    - filing and clearing a person, and 起名 taking its 八字 chart's person.
  - 10 new app tests:
    - the two views and their order;
    - one download as PDF;
    - several sent as Word;
    - deleting (cancelled, then confirmed);
    - filing under a typed name;
    - a record not finished;
    - the reading and 一生运势 menus;
    - the keyboard.
  - I looked at a PDF rendered with every kind of block, over two pages.
  - All 528 server tests and 175 app tests pass; harness PASS.

### v7.0.0 (2026-10-28): 追问, follow-up questions on every reading, answered from that reading alone

Stage S13 of the [tech plan](docs/tech-plan.md) is complete (its summary is there): your request for 追问 on every
method, after the three-part readings of v6.2.0. A big update: pushed.

- **Every finished reading can be asked about further:** 八字, 塔罗, 求签, 算卦, 风水, 起名 (still off) and the 一生运势报告.
  - **Easy to find** (you: 显眼的位置): a 「继续追问」 button floats at the bottom right as soon as the reading is ready.
    It brings up the 追问 card, with the cursor in its field.
    - On a reading page the card comes right after the reading, before 行动建议, in the accent colour.
    - The jump list at the top starts with 「追问」.
    - While the field is on screen, the floating button steps aside, so it never covers 发送.
  - **Asking:** type a question and press Enter (or 发送), or tap one of the suggested questions. Before the first
    question each method offers two of its own (八字: 「我适合什么样的工作？」; 算卦: 「动爻在提醒我什么？」…).
  - **The answer** comes in the same three parts as the reading: the term, the commentary, an everyday example.
    Under it come two or three next questions to tap (you: 持续给出后续问题).
  - Each question stays on the card with its answer, so you can read the whole thread.
- **No making things up** (you: 不能胡编乱造).
  - The answer reads only this reading: the same chart, cards, lot, hexagram or room, what the reading said, and the
    earlier 追问 on it.
  - Every paragraph must cite the facts it rests on. One that cites nothing is thrown out, and the answer is
    written again.
  - The answer is checked automatically against the reading's own facts:
    - no card that wasn't drawn, and no orientation it didn't have;
    - no lot line it doesn't have, and no hexagram or text from another cast;
    - no 干支 the chart doesn't have.
      A paragraph that fails is thrown out too, and the answer written again.
  - **A question the reading can't answer is said to be so,** with what it can answer instead. Examples: another
    matter than the one a lot or a cast was for (一事一占); someone else's chart; an exact date or amount; a
    diagnosis.
  - The same safety rules as the readings: tendency language, no fear, no medical, legal or money advice, and the
    rule layer on every answer.
- **Limits:**
  - one question at a time, and up to 20 per reading;
  - each 追问 counts against the daily AI caps of `npm run public`, like a reading;
  - with `IS_AI_MOCK=TRUE` the answers and suggestions are the mock's （示范） text: switch the real model on to see
    real ones.
- **For you to try with the real model:** `npm run eval:ai -- --live` now also asks one 追问 per case and records
  whether the answer stayed with the reading (docs/verification/ai-eval-results.json, `followup`). It costs tokens,
  as before.
- **Kept on the server:** each question and its answer, sealed under your account's key in the database (migration
  007), deleted with the account. The reading's own question is kept with it now, so a 追问 knows what was asked.
- Verified:
  - 20 new server tests:
    - the answer rests on the reading's own facts, in three parts;
    - a paragraph citing nothing, or naming a card never drawn, is sent back;
    - an out-of-scope reply makes no claim;
    - the last six 追问 are read, and a 八字 追问 that names a year reads that year in full;
    - suggestions are checked;
    - Geo-Rule comes first, and the rule layer scans the answer;
    - the API: one at a time, the limit, the daily caps, the 一生运势报告, the review console and the database
      store.
  - 9 new app tests:
    - the floating button brings the field into view and steps aside;
    - the card sits after the reading;
    - asking with Enter, the three-part answer, and a suggestion asking the next;
    - the out-of-scope reply;
    - the busy, limit and daily-cap messages;
    - the limit;
    - Tab;
    - every method's reading, and the 一生运势报告.
  - All 515 server tests and 165 app tests pass; harness PASS.

### v6.2.0 (2026-10-28): readings in three parts (术语 → 评论 → 例子), names kept with the chart, three accounts

The first part of stage S13 of the [tech plan](docs/tech-plan.md), plus your bug report and your three new
accounts. A medium update, pushed as you said I could. 追问 comes next, in v7.0.0.

- **Every AI reading now comes in three parts** (you: 术语在前，评论在后，评论要尽量详细，举个例子).
  - **The term first, in bold:** the facts the paragraph rests on, said the tradition's way. Examples:
    「日主甲木，生于寅月（得令）」, 「第 3 张·根基：宝剑七（正位）」, a quoted 爻辞, 「床头靠墙」.
  - **Then the commentary:** what it means for you, in plain words and in detail. The conclusion comes first, then
    why.
  - **Then an example, in a tinted box:** one everyday scene. For a kind nature: 「比如同事临时找你帮忙改方案，你嘴
    上说“没事”，其实已经开始帮他想办法了」.
  - It covers every method: 八字, 塔罗, 求签, 算卦, 风水 and 起名 (still off). In the 一生运势报告, each text opens
    with its basis, then the commentary and a 比如 example.
  - Copy and download keep the three parts. Readings made before show as they were.
  - Each method got its own new prompt (narrative_bazi@7 … narrative_liuyao@2, life_methods@3, life_topics@3).
  - **To see real readings in the new form, switch the real model on** in `.env` (`IS_AI_MOCK=FALSE`,
    `IS_AI_MODEL=TRUE`). While the mock answers, the three parts are its （示范） text. Only real readings show how
    well the model follows the new instructions, so please read a few.
- **Fixed: names and birthplaces missing from stored readings** (your bug report).
  - **Cause:** the name and the birthplace were kept only in the browser that made the chart. A browser keeps such
    data per web address, and `npm run public` gives the app a new address on every run. Another device or browser
    starts empty too. So the database kept the readings, but not whose they were.
  - **Now:** the app sends them with the chart, and the server keeps them on the chart record.
    - With `MINGLI_STORE` on, they are sealed with the chart in the database.
    - They are never in the chart's facts and never sent to the AI.
  - History (「xxx 的命盘」, 「xxx 一生运势报告」), the reading's 出生地 line and the 一生运势报告 header now show them
    on any device, after any restart.
  - **Readings made before this update:** the server never had their names, so only the browser that made them can
    still show them. Readings from now on keep them everywhere.
  - This changes the 2026-10-26 rule that names never reach the server. docs/data-retention.md says what is kept
    now. Saved profiles (birth details for re-use) still stay on the device.
  - **Also fixed:** a 一生运势报告 opened from history could hit a "duplicate keys" error while its chart was
    loading.
- **Three more accounts:** `qianli` / `qianli`, `wuyong` / `wuyong` and `leonfighter` / `leonfighter`.
  - Each password is its login, as with admin and xumei. I read 「密码都用一样的」 that way; say if you meant one
    shared password.
  - They are created at the next API start (`npm run api` or `npm run public`), in region HK. With `MINGLI_STORE`
    on, they are kept.
  - They exist in public mode too: anyone who guesses one can use it, within the daily AI caps.
- Verified:
  - 8 new server tests:
    - the three parts are kept, normalised, scanned and checked;
    - the person is kept with the chart and returned with history and the 一生运势报告;
    - the person is never sent to the model and never stored in the clear;
    - the three accounts sign in.
  - New app tests:
    - the three parts on screen, in order, and in the export;
    - an older paragraph shown as before;
    - the 八字 form sends the person;
    - a device with no labels shows the name and birthplace in history and the 一生运势报告.
  - All 495 server tests and 156 app tests (151 → 156) pass; harness PASS.

### v6.1.0 (2026-10-28): your three updates: coins that turn over, tarot spreads three to a row, 东方 and 西方

Stage S12 of the [tech plan](docs/tech-plan.md), the three things you asked for after v6.0.0. A medium update,
pushed as you said I could.

- **算卦's coins are real 銅錢 now, and they turn over like the tarot cards.**
  - Each coin is round with a square hole. The 字 side reads 乾隆通寶 round the hole, and the 背 side is plain.
  - **自動擲幣**: each time you press 擲下一爻, the three coins are thrown. They spin up from their other side and
    land on what the toss gave, one just after another, and then the line (「初爻：背 字 字 → 少陽」) shows.
  - **自己挑幣**: the 24 coins lie covered, in the same navy and gold as the back of a tarot card. A coin you pick
    glows and shows its number.
    - After 看卦, the coins you picked turn over one by one in the order you picked them, as the tarot cards do,
      each keeping its number in a corner.
    - The coins you didn't pick dim.
  - If your phone or computer is set to reduce motion, the coins show their faces straight away.
- **塔羅's spreads sit three to a row on a phone** (单张 · 三张 · 凯尔特十字, then 二选一 · 关系牌阵). Every name is shown
  in full. On a wider screen all five stay in one row.
- **The home page has two groups:**
  - **东方**: 八字排盘, 求签, 算卦, 风水.
  - **西方**: 塔罗, for now; new ones can join either group.
  - Each group keeps your region's order (求签 first in Taiwan and Hong Kong, 风水 first in Malaysia).
  - A group the region offers nothing from isn't shown.
  - Tab follows the groups: 东方 top to bottom, then 西方.
- Verified:
  - 4 new app tests, which check:
    - the toss starts on the other face and lands on the toss, and its line shows only after landing;
    - the picks turn over in order (the first after 300 ms, the 18th still covered), and the unpicked dim;
    - with reduce motion, the faces show at once;
    - the spread choices sit three to a row at 320, 360 and 412 px (also with a chip keyboard-focused), and five in
      one row at 1000 px;
    - the home groups and their order, and a region without 塔羅 shows no 西方.
  - I looked at it rendered with a real Chinese font: the toss rows, the covered coins, the coins mid-turn and
    turned, the home groups, and the spreads at 360 px.
  - All 487 server tests and 151 app tests pass; harness PASS.

### v6.0.0 (2026-10-28): 算卦 complete: its pages in the app, and the 周易 text checked against a 宋 print

Stage S10 of the [tech plan](docs/tech-plan.md) is complete (its summary is there). A big update: pushed, together
with v5.3.0 and v5.4.0.

- **算卦 is in the app** (首页 → 算卦).
  - Type what you want to ask: one thing, as concretely as you can. A reminder comes before any cast: be calm,
    ask one thing, don't ask it again and again.
  - Then choose how to cast:
    - **自動擲幣**: tap 擲幣. The six tosses come one at a time, 擲下一爻 for the next, or 直接看卦.
    - **自己挑幣**: tap 擺好硬幣, and 24 coins are laid out face down before you choose.
      - Pick 18 by feel, one by one: each picked coin shows its number, and 重新挑 starts over.
      - After the 18th, 看卦 turns them over in the order you picked them; the first three make the 初爻.
    - **自擲自填**: first set the exact time (選擇時間, or 用現在的時間). Nothing is cast without it.
      - Then fill in six rows, 上爻 at the top: 按硬幣, as the three coins fell (字 / 背), or 按爻, as the line itself.
      - Then 起卦.
  - The hexagram comes at once, with no AI. The card shows:
    - the six lines, with the moving ones marked;
    - 本卦 → 變卦, with their 上卦 and 下卦;
    - the time and its 干支;
    - the 卦辭 or 爻辭 the reading rests on, each with its 直說 underneath.
  - 生成 AI 解讀 then reads the cast for your question. History lists it by its hexagram (「算卦 · 天雷無妄」).
  - Keyboard: Tab reaches every coin and Enter picks it. Once a hexagram is cast, Esc or 返回 asks first, since the
    cast is not kept (a reading you generated stays in history).
- **The 周易 text is corrected.** 算卦 quotes it, and so does the 一生运势 report, so both now read right.
  - The text came from one digital copy. I compared all 514 texts (卦辭, 爻辭, 用九, 用六 and 大象) with two other
    transcriptions. Then I compared them with a transcription of a 宋 print: 四部叢刊, 王弼注. Wherever anything
    differed, I read the scan of the print itself, on 16 pages.
  - 125 of 578 strings were wrong.
    - **A line in the wrong hexagram:** 大有 九二 read 「同人於宗，吝」, which is 同人's line. It is now
      「大車以載，有攸往，無咎」.
    - **A line written twice:** 姤 九五.
    - **Words missing or out of order:**
      - 復 初九 「不遠復」 (it read 不復遠);
      - 明夷 六四 「於出門庭」;
      - 大過 九五 「老婦得其士夫」;
      - 家人 九五 「勿恤，吉」;
      - 損 上九 and 巽 「利有攸往」.
    - **Wrong characters:** 兇 for 凶 (58 times), 鹹 for 咸 (the name of hexagram 31 too), 鬥 for 斗, 後 for 后
      (the sovereign), 屍 for 尸, and more.
    - **In the 大象:** 震's read 「虩雷…修身」, not 「洊雷…修省」.
  - Some errors were in all three digital copies, and only the print shows them: 姤 初六 「繫于金柅」 (all had 系),
    噬嗑 六三 「噬腊肉」 (all had 臘) and 復 初九 「无祇悔」.
  - Every 卦辭 now opens with the hexagram's name, also where the name is its first word: 「履：履虎尾，不咥人，亨。」
  - The evidence for every correction, and what was kept, is in
    [docs/verification/zhouyi.md](docs/verification/zhouyi.md).
  - Not done: the print read page by page where its transcription already agrees with our text. Say if you want
    that.
- Verified:
  - 8 new app tests:
    - the reminder comes before any cast;
    - each of the three ways: the server tosses; the picks go in the order picked; nothing manual without the time;
      by coins or by line;
    - the reading and its history title;
    - Tab and Enter on a coin.
  - 4 new server tests on the 周易 text:
    - every line opens with its own name, by place and 陰陽;
    - every 卦辭 opens with its name;
    - none of the mis-converted characters is left, nor a doubled line;
    - the hand-checked lines and 大象.
    - They fail on the old text.
  - `npm run check:zhouyi` reproduces the comparison: all 514 texts read as the print does.
  - All 487 server tests and 147 app tests pass; `verify:liuyao` 10 of 10; harness PASS.
- Still waiting for you:
  - whether a 八字 share card may show the four pillars;
  - the 起名 字义库 review;
  - Indonesia's sign-off;
  - whether to strip the server's English;
  - the Phase 3 gate items.

### v5.4.0 (2026-10-28): your three updates: even tarot spread choices, Chinese only, the admin in Beijing

Stage S11 of the [tech plan](docs/tech-plan.md), what you asked for while 算卦 was being built. A medium update:
committed locally, and pushed with 算卦's big update (v6.0.0).

- **The tarot spread choices are all the same size** (单张, 三张, 凯尔特十字, 二选一, 关系牌阵).
  - Each has the same square icon, its cards drawn as large as the square allows, and its name underneath on one
    line.
  - Checked in a test, which measures every choice's size and keeps each name uncut. I also looked at the page
    rendered with a real Chinese font.
- **The app is in Chinese only: 简体中文 and 繁體中文.**
  - English is gone from the 语言 menu, and so is the English text file (简体 is now the main one).
  - Readings, tips and timelines take the Chinese layout everywhere.
  - Anyone who had chosen English opens in 简体.
  - The server still accepts English requests, but nothing in the app sends one. Say if you want it stripped there
    too: it touches every method's texts, so I've left it for your word.
- **The 管理员 test profile is born in 北京** (中国 · 北京市 · 北京), with the place stored the way the place picker
  stores it.
  - A device that still has the old, untouched Taipei version gets moved to Beijing.
  - A profile someone has edited keeps what they chose.
  - Because the birthplace moved, its chart changes: true solar time is now taken at Beijing's longitude, with
    China's 1988 summer time.
- Verified:
  - App tests:
    - the spread choices are one size, each with its icon over its name;
    - the admin is seeded in 北京, and an untouched old seed moves while an edited one stays;
    - the app is Chinese only: no English file or locale, and English saved earlier starts in 简体;
    - a picked 繁體 survives a restart.
  - The English-only tests are rewritten for Chinese or removed.
  - All 483 server tests and 139 app tests pass; harness PASS.

### v5.3.0 (2026-10-28): 算卦, the server half: the coins, the hexagrams, 直說 and the AI reading

Your request (算卦: coins cast automatically, half-automatically or by your own hand, with the time, the 八卦 and
the texts at once, or an AI reading). Stage S10 of the [tech plan](docs/tech-plan.md), the server half. The app's
pages come in v6.0.0. A medium update: committed locally.

- **The coins**, by the classical rule: three coins, six tosses, from the bottom (初爻) up.
  - 背 counts 3 and 字 2. One 背 is 少陽, two 少陰, three 老陽 (moving), three 字 老陰 (moving). Reference: 漢典
    「單錢」.
  - Each coin falls either way half the time.
- **Three ways to cast**, as you asked:
  - **自動**: the server tosses all 18 coins, and the cast replays from the server's key.
  - **半自動 (挑幣)**: the server lays out 24 coins face down _before_ you pick.
    - The coins stay hidden, and you get a commitment (a fingerprint of the layout).
    - You pick 18, one at a time, and the order is kept: picks 1–3 make the 初爻.
    - Anyone with the key can check afterwards that the coins were laid out before the picking.
  - **自己擲、自己填**: you toss real coins and enter each line, as three coins (字 / 背) or as the line itself, for
    anyone who counts the faces another way.
    - The **exact time is required**, to the minute. A time in the future, or one a clock change skips, is
      refused.
- **What comes out at once**, with no AI:
  - the 本卦 and, when lines move, the 變卦;
  - the 上卦 and 下卦 (八卦 with their images), the King Wen number, and the 年月日時 干支 of the cast time;
  - the 卦辭 and 爻辭 the reading rests on, chosen by 朱熹's rule (one moving line: its 爻辭; none: the 卦辭;
    and so on to six).
- **直說, your 「直抒胸臆，不用绕」**: every 卦辭, every 爻辭, and 用九 and 用六 (450 in all) has one plain sentence
  saying straight out what it means.
  - For example, 無妄 六二 「不耕穫，不菑畬」: 「別只想收穫，把眼前該做的做好，往前走就順。」
  - They are written in 繁體 by hand, after the common readings, and converted to 简体. None is longer than 38
    characters.
  - Tendency, never fate: the compliance rules find nothing in any of them.
- **The AI reading** has its own prompts, and the AI is told to say it straight:
  - 卦象: what came up, each text quoted with its meaning;
  - 所問之事: the answer comes in the first sentence (go ahead, wait, or change course), then why;
  - 建議: what to keep doing, what to stop, what to watch for.
  - It never claims 纳甲, 六亲, 世应 or 用神, which the app doesn't compute.
  - A check catches a reading that names another hexagram, quotes another's text, or names a 干支 the cast doesn't
    have.
  - Chinese only, since you've removed English (that part of the app comes next).
- 算卦 is on everywhere, after 求籤 in the home order. The Geo-Rule matrix is now 0.6.0, and the glossary 1.7.0
  (本卦, 變卦, 動爻, 卦辭, 爻辭, 老陽 …).
- For whoever runs the server: nothing to do. The database, if on, adds the method at the next start (migration 006).
- Verified:
  - 34 new server tests:
    - the coin rule, the hexagrams and numbers, and 朱熹's rule for 0–6 moving lines;
    - the cast time's 干支, worked by hand (立春 counted by the instant, the day by the local date);
    - the three ways to cast, with replay and a tampered cast refused;
    - the 450 直說 checked;
    - the reading, its checks, and the API (the layout, the picks, the refusals).
  - A new harness gate, `npm run verify:liuyao`: 100 000 casts pass 10 of 10 statistical checks, and biased coins
    are caught.
  - All 483 server tests pass; harness PASS.

### v5.2.0 (2026-10-28): 起名's own compliance rules, and the Phase 3 gate record

Stage S9 of the [tech plan](docs/tech-plan.md) (Phase 3 门禁). Your documents end with 「Gate 未通过不进入下一阶段」,
so before anything of Phase 4 this update closes what it can of Phase 3's gate and records the rest for your
review. A medium update: committed locally, and pushed with the next big update.

- **起名 has its own rules now**, the gate's 「起名/风水输出全部通过 Compliance Guard 专项规则」. 风水 had F001 / F002
  since v4.4.0. 起名 readings now get N001–N003, in both scripts and English:
  - N001: a name said to decide fate (「名字決定一生的命運」, "your name determines your fate");
  - N002: a name as a cure or a charm (「改名就能轉運」, 旺夫名, 招財名, "change your name to fix your luck");
  - N003: a 吉凶 verdict on a name (「此名大吉」, 「這個名字大凶」).
  - They apply to 起名 readings only. The same sentence in a tarot reading is left alone.
  - Negations are allowed, so 起名's AI label and the names card's 「不決定任何人的命運」 pass in all three
    languages.
- **[docs/phase-3-gate.md](docs/phase-3-gate.md)**, the Phase 3 gate record, written like the Phase 0 one:
  - the six deliverables, with where each lives and its state;
  - the test standards, each with its test or what it waits for;
  - the five gate items, two passed: the 专项规则 and the five-region test.
  - The other three wait for you: the Action Kit audio, the WhatsApp templates, and the fine-tuning ADR. So
    **Phase 4 has not started**.
  - A table at the end lists your decisions and what each one opens.
- Two tests now pin English coverage:
  - the app's three languages have the same strings, and English shows Chinese only in its listed terms;
  - every glossary term has its 繁體, 简体 and English.
- Verified:
  - 20 new server tests: 17 rule cases, the 起名 reading held while the same text in tarot is not, and 2 on the
    glossary;
  - 1 new app test (English coverage);
  - All 449 server tests and 140 app tests pass; harness PASS.

### v5.1.0 (2026-10-28): regions in detail: Indonesia's blocks, five regions tested, your language remembered

Stage S8 of the [tech plan](docs/tech-plan.md) (地区精细化), from what your Phase 3 document still lists (§2.4,
§2.5). A medium update: committed locally, and pushed with the next big update.

- **Indonesia** is in the Geo-Rule matrix (now 0.5.0), with your document's blocks: 前世, 通灵 and 降头 (past
  lives, spirit mediums, black magic).
  - **It is not served yet.** Like every region, it opens after your sign-off. Then, for `ID` in
    `compliance/geo_rule_matrix.json`, set `service_available` to true and `legal_review` to provisional, and raise
    the matrix version ([docs/web-test.md](docs/web-test.md), Indonesia).
  - Its readings stay off the three topics in two ways:
    - every model call in the region is told: readings, 破除運勢 plans and 一生运势;
    - a new rule group, `id` (I001–I003), records any that slip through, and holds them once review is on.
  - Other regions are unchanged: what the model receives there is byte for byte what it was.
- **Singapore**: English joins 简体 among its languages, for your 「英语/中文双语权重」.
  - The app still starts in 简体, as you decided on 2026-10-26.
  - Anything more the weight should change is your call.
- **The five regions are tested together**, your Phase 3 gate 「Geo-Rule 五地区规则路由测试通过」. Indonesia,
  Malaysia, Singapore, Taiwan and Hong Kong each get their own rules, blocks, entry order and languages.
- **The app remembers your language.** Pick 繁體中文 or English once in the 语言 menu, and the app opens in it next
  time, on the web after a reload too. Without a choice it starts in 简体中文.
- **Fixed: a matrix change needed a server restart.**
  - The server read the Geo-Rule matrix only when it started, so switching 起名 on needed a restart, although
    docs/web-test.md said it didn't.
  - The server and sign-up now read the matrix on every request, as your 「矩阵支持热更新」 asks.
  - A test checks this on a server that was already running.
- Glossary 1.6.0 adds 双声 and 叠韵, the sound notes on 起名's names, in three languages.
- The rest of Phase 3 waits for you; the tech plan (S8, "Phase 3, the rest") lists it:
  - Action Kit;
  - TikTok support (`/link`, the email list, WhatsApp);
  - RAG and the fine-tuning evaluation;
  - an English model route;
  - the store listing.
- Verified:
  - 28 new server tests:
    - 17 rule cases (block and allow for I001–I003, and the same sentence left alone outside Indonesia);
    - 7 on the content blocks: the matrix, the sign-off invariant, refusal before any model call, the line in
      every call, byte-for-byte messages elsewhere, a hit recorded, and held while review is on;
    - 4 on the five regions, the hot update among them.
  - 2 new app tests: a picked language survives a restart; without one, or without storage, the app starts in 简体.
  - All 429 server tests and 139 app tests pass; harness PASS.

### v5.0.0 (2026-10-28): 新玩法, three new methods (stage S6 complete)

The big update that ends stage S6 of the [tech plan](docs/tech-plan.md). It brings the three methods your phase
document plans, each standing alone, with its own engine, prompts and page. The stage summary is in the tech plan
(阶段总结, S6). This push also carries v4.1.0–v4.5.0, below.

- **求籤 · 擲筊** (v4.3.0), on the home page.
  - Shake out a stick, then 擲筊 until a 聖筊 confirms it.
  - The lot is the 關聖帝君一百籤, its poem checked line by line against two modern copies and a Qing print.
  - The AI reads the poem for your question, with no fixed fate and no offerings. The lot can be shared as an image.
  - In Taiwan and Hong Kong, 求籤 is the first entry.
- **風水** (v4.4.0), on the home page.
  - Choose a room, and optionally its facing and how it is now.
  - You get general principles of light, air, rest and movement, and the AI relates them to your room.
  - Never 吉凶, and never buying a cure.
  - In Malaysia, 風水 is the first entry.
- **起名** (v4.5.0), from a 八字 chart: 12 candidate names that serve the chart's 喜用 and sound well with the surname,
  with each character's 五行 and meaning, and an AI reading of them. It is **off until you review its 字义库**. How
  to review it and turn it on: [docs/web-test.md](docs/web-test.md) (起名).
- What waits for you:
  - the 起名 review;
  - whether a 八字 reading may have a share image, since its four pillars would show the birth date (WP7.2).
- Verified: a fresh harness run on the final tree passes every gate:
  - 401 server tests;
  - 137 app tests and the web build;
  - the 7000-chart 八字 check against the oracle;
  - 100 000 tarot draws and 100 000 求籤 draws.

### v4.5.0 (2026-10-28): 起名, candidate names from a 八字 chart (off until you review its 字义库)

Stage S6 of the [tech plan](docs/tech-plan.md) (新玩法), work package 6.4, built to your phase document's 起名 spec:
五行补益 from the 八字 chart, a 字义库 with 繁 and 简 forms, and 音律 rules. A medium update: committed locally, and
pushed with S6's big update.

- **It is off for everyone until you have checked the 字义库.**
  - Your spec asks for a 字义库 checked by hand (人工校订). The one here is a draft I wrote:
    - 100 characters, 20 per element, each with its 繁 and 简 forms, pinyin, 五行 by its radical, and a short
      meaning in three languages;
    - 83 common surnames with their readings as surnames, 3 of them double (such as 歐陽).
  - Until then the Geo-Rule matrix (now 0.4.0) keeps 起名 off (`defaults.systems.naming.available: false`), so no
    one sees it.
  - To turn it on, see [docs/web-test.md](docs/web-test.md) (起名):
    1. check `src/engines/naming/characters.ts`;
    2. mark the 字义库 reviewed in `src/engines/naming/index.ts`, then `npm run sync:app`;
    3. switch `naming` on in the matrix and raise its version.
  - I tried these steps (then undid them): every test still passes. Drop any character you disagree with; the tests
    only ask that each element keep at least 12.
- How to use it, once it's on:
  1. 八字排盘 → compute a chart → 「為這個命盤起名」 at the end of the chart page.
  2. Type the surname (one or two Chinese characters, 繁 or 简), and choose 單字名 or 雙字名.
  3. 起名 (or Ctrl+Enter) shows 12 candidate names. Each comes with its pinyin, and with each character's 五行 and
     meaning.
     - The names serve the chart's 喜用, e.g. 「名字所補：火、土」.
     - A chart with no clear 喜用 gets names that keep a balance, from its two weakest elements. That is a 中和
       chart, or one flagged for a closer look.
  4. 生成 AI 解讀 reads the names in two parts:
     - 候選名字: the strongest few, one paragraph each, on meaning, 五行 and sound;
     - 建議: how to choose (say it aloud, write it, hear it in the family's dialect).
- The rules:
  - 音律, each rule its own unit test:
    - never a character of the surname, and never two like syllables side by side;
    - three syllables never all in one tone;
    - points for tones that rise and fall (平仄) and for a level-tone ending;
    - deductions for 双声 and 叠韵.
  - The same surname always gives the same list, in either script: 張 and 张 give the same names. No character
    appears in more than two of them.
  - The reading never says a name decides fate or fortune, and never asks for a fee or a ritual. Its AI label:
    「名字的字義與聲調僅供參考，不決定任何人的命運」.
  - No gender filter: every character is open to everyone.
  - The card says 「這些名字所用的字義庫仍待專家校訂」 while the 字义库 is a draft, and stops once you mark it
    reviewed.
  - No share image for 起名: your spec asks for none.
- Privacy:
  - The naming chart keeps the surname, the elements the names serve and the 八字 chart's digest. It never keeps
    the birth data.
  - You can name only from your own 八字 charts: anyone else's is answered as if it weren't there (404).
- The 字义库 checks:
  - each character's pinyin against pinyin-pro, an independent reference;
  - its 简体 against OpenCC;
  - its element against the radical rule.
- For whoever runs the server: nothing to do. The database, if on, adds the method at the next start (migration 005).
- Found on the way: turning 起名 on would have broken 7 tests that pinned the switch as shipped. 3 were 起名's own,
  two pinned the matrix version, and two pinned each region's method list.
  - Each now sets the switch itself, reads the version from the matrix, or leaves 起名 out of the order.
  - One new test holds the gate itself: 起名 can be on only with a reviewed 字义库.
- Verified:
  - 13 new server tests:
    - the 字义库: each character once, enough per element, meanings in three languages, the radical rule, the pinyin
      against pinyin-pro (and every surname's reading as a surname), 简体 against OpenCC;
    - 起名 is on in no region until the 字义库 is reviewed;
    - 音律: syllables, the two rejections, and the scores, worked by hand;
    - the elements (喜用, or the balance);
    - the candidates: serving the 喜用, avoiding the surname, varied, in score order, for a known and an unknown
      surname;
    - a mock reading with its own prompts, refused while 起名 is off;
    - the API: only the caller's own 八字 chart; 451 and absent from `/v1/methods` while off.
  - 3 new sync checks: the 字义库 and the two 起名 fixtures match what the server makes.
  - 6 new app tests:
    - the button is hidden while the region has 起名 off;
    - the page sends the surname, the length and the 八字 chart, then shows the card and starts the reading;
    - Ctrl+Enter asks for names, and a new surname puts the old ones away;
    - the draft note goes once the 字义库 is reviewed;
    - 简体 names in 简体;
    - the reading page and history (「起名 · 陳」).
  - All 401 server tests and 137 app tests pass; harness PASS.

### v4.4.0 (2026-10-28): 风水, general principles for a room, first in Malaysia

Stage S6 of the [tech plan](docs/tech-plan.md) (新玩法), work package 6.3, built to your phase document's 风水 spec:
general principles of direction and space only, never a 吉凶 judgement of a home. A medium update: committed locally,
and pushed with S6's big update.

- New on the home page: 「風水」. How to use it:
  1. Choose the room: 臥室, 書房 · 工作桌, 客廳, 廚房, 玄關, 餐廳 or 兒童房.
  2. Optionally choose the way its main window faces, eight directions or 不確定.
  3. Optionally say how the room is now (「床在窗下，門在左邊」). It is private like a question, and no address or
     floor plan is asked for.
  4. 看佈局 shows the room's principles, each with its everyday reason.
     - The reasons are light, air, sleep, safety, privacy, and how people move around.
     - Some carry the tradition behind them, said without 吉凶, such as 「背後有靠」 or letting the 「氣」 flow.
     - A facing adds its traditional association, e.g. 「傳統上：東 · 震 · 木」.
  5. 生成 AI 解讀 relates the principles to your room: 佈局, 光線與動線 and 建議, then a few small changes, the
     easiest first.
- In Malaysia 風水 is the first entry, as your phase document asks (「马来西亚（风水内容权重提升）」). Elsewhere the
  order is 八字, 塔羅, 求籤, 風水. The order still comes from the Geo-Rule matrix (now 0.3.0).
- Your spec, kept:
  - Every principle, and every paragraph of the reading, is marked `simplified_rule`.
  - The reading never says 吉 or 凶, lucky or unlucky; never uses 煞, 旺 or 衰; and never ties a layout to wealth,
    health, marriage, children or luck.
  - It never suggests buying objects as a cure (charms, crystals, 八卦鏡), rituals, renovation or moving: only
    moving, tidying and lighting with what you have.
  - A 风水-only compliance rule group (F001, F002) holds 吉凶 phrasing such as 凶宅, 犯煞, 招財 and 破財. It applies
    to 风水 readings only, so other methods are untouched.
  - The reading's AI label says it gives general advice on space, not a judgement of your home.
- Your three choices are what decide the principles. They come from a fixed table of 30 general principles for the
  seven rooms; the 简体 text is checked against OpenCC, and the facings follow the 後天八卦.
- For whoever runs the server: nothing to do. The database, if on, adds the method at the next start (migration 004).
- Verified:
  - 9 new server tests:
    - the table: every room has principles, the texts in three languages, 简体 against OpenCC, no 吉凶 wording,
      and the 後天八卦 directions;
    - the engine: schema-valid and deterministic for every room and facing;
    - a mock reading, every paragraph `simplified_rule`;
    - the 风水 rule group: it holds 犯煞 in a 风水 reading but not in a tarot one;
    - Malaysia's order, and the API (an unknown room or facing gives a 400; no plan).
  - 4 new app tests: Malaysia's order; 看佈局 with the request it sends, the principles card and the facing, and
    the description going with the reading; a new choice puts the room away; the reading page and history.
  - All 385 server tests and 131 app tests pass; harness PASS.

### v4.3.0 (2026-10-28): 求籤 · 擲筊, the first new method, first in Taiwan and Hong Kong

Stage S6 of the [tech plan](docs/tech-plan.md) (新玩法), work packages 6.1 and 6.2. You said 「继续吧不要停」 without
choosing, so S6 follows your phase document:

- 擲筊 / 求签 first, the entry for Taiwan and Hong Kong;
- then 风水;
- then 起名.

六爻 and 合婚 were only this plan's proposals, and they are parked. A medium update: committed locally, and pushed with
S6's big update.

- New on the home page: 「求籤」. How to use it:
  1. Type what you ask about (optional), then tap 求籤. A stick falls (「搖出第三十四籤」).
  2. Tap 擲筊 and the two blocks land:
     - 聖筊 (one flat, one round) confirms the stick;
     - 笑筊 or 陰筊 sends it back, and you tap 放回再搖.
  3. 「直接看結果」 shows every round at once. On a keyboard, Enter throws.
  4. Then your lot, on its slip: 關聖帝君一百籤, the lot (e.g. 第八十九籤 · 壬壬) and its four lines.
  5. 「生成 AI 解讀」 reads it in three parts: 籤詩 (couplet by couplet), 所問之事 and 建議, then actions.
- In Taiwan and Hong Kong, 求籤 is the first entry, as your phase document asks (「台湾/香港（擲筊/求签入口前置）」).
  Elsewhere the order is 八字, 塔羅, 求籤. The order comes from the server's Geo-Rule matrix, so it can change without
  an app update.
- 分享图片 works for 求籤 readings too.
  - The image shows the slip and the poem's main point, with the AI label and the watermark.
  - It never shows your question, nor the part of the reading that answers it.
- History lists 求籤 readings with the lot and the poem's first line.
- The lot set is the 關聖帝君一百籤 (雷雨師一百籤), used at 臺北行天宮, 日月潭文武廟 and 新竹城隍廟. How its text was
  checked ([docs/verification/qiuqian-guandi-100.md](docs/verification/qiuqian-guandi-100.md)):
  - Two transcriptions online, compared character by character: 85 of the 100 lots are the same in both.
  - All 100 lots then read in a Qing woodblock print, the 關帝靈籤 (姑蘇鈕氏藏板; Harvard, public domain).
  - The print settled the 16 lines where the transcriptions disagree, and 5 errors both share: 寅午戍 → 寅午戌,
    敵圖 → 敵國, 咨嘆 → 咨嗟, 步多 → 步步, 祗 → 祇.
  - Otherwise the text stays as temples print it. The 38 places where the Qing print reads differently are listed in
    that file.
  - No 吉凶 grade (上上, 下下): editions disagree on them, and many Taiwanese temples print none. The reading follows
    the poem.
- The reading's own rules:
  - Tendency language. A sad lot asks for patience, never a fixed fate.
  - Never 添香油錢, 點光明燈, 安太歲, 祭改 or a second lot to "undo" one.
  - No health, money or legal predictions.
  - A new compliance rule (G008) holds such upsell phrasing. A check catches a misquoted line or a wrong lot number.
- For whoever runs the server: nothing to do. With the database on, it adds the new method itself at the next start
  (migration 003).
- Verified:
  - 35 new server tests:
    - the text: shape, the decisions, 简体;
    - the draw: replay, audit, 4000-draw statistics, and a battery that catches biased draws;
    - the reading: its own prompts, faithfulness;
    - the entry order, the API, the share image, the database, the compliance rule.
  - A new harness gate, `npm run verify:qiuqian`: 100 000 draws, 8 of 8 checks pass. Sticks are uniform, the blocks
    fair, 聖筊 comes half the time, and the rounds are geometric.
  - 5 new app tests:
    - the entry order, in Taiwan / Hong Kong and elsewhere;
    - the ritual round by round;
    - Enter and 直接看結果;
    - the reading page with its lot, the history, and 分享图片.
  - All 364 server tests and 127 app tests pass; harness PASS.

### v4.2.0 (2026-10-28): share a tarot reading as an image

Stage S7 of the [tech plan](docs/tech-plan.md) (分享图), work package 7.1. A medium update: committed locally, pushed
with the next big update.

- Tarot reading page, ⋮ menu: 「分享图片」 opens the share sheet with an image of the reading. On a computer's browser
  it downloads.
- On the image, as your phase document asks (made on the server, with a watermark and the disclaimer):
  - 「命理大師 · 塔羅」 at the top, in the reader's script;
  - every card with its position and name, and 逆位 when reversed (the card is drawn upside down);
  - the reading's main point;
  - at the foot, the reading's AI label (「仅供娱乐和玄学学习使用」), and the watermark with the date.
- Private by design: the image never shows your question, your 个人情况 or a name.
- For whoever runs the server: it needs a Chinese font. On Windows, Noto Sans SC or 微软雅黑 is found; on Linux,
  install `fonts-noto-cjk`. Otherwise set `MINGLI_SHARE_FONT`. Without one, the app says the image can't be made
  just now.
- 八字 readings get their own share card later (WP7.2). The link back into the app waits until the app is in the
  stores.
- Also in the plan: S6 (new methods) waits for your choice. Your phase document plans 起名 and 风水, and puts 擲筊 /
  求签 first for Taiwan and Hong Kong. This plan had proposed 六爻 and 合婚. Which should come first?
- Verified:
  - 4 new server tests: what the image says, and that the question isn't on it; the image for three cards in 繁體
    and a Celtic Cross in English; who may fetch it.
  - 1 new app test: the menu shares the server's image; a 八字 reading has no such item.
  - All 329 server tests and 122 app tests pass; harness PASS.

### v4.1.0 (2026-10-28): readings and accounts can survive a restart, encrypted

Stage S5 of the [tech plan](docs/tech-plan.md) (数据持久化), complete: work packages 5.1 and 5.2. A medium update:
committed locally, pushed with the next big update.

- New, off until you turn it on: the API can keep accounts, readings, 破除运势 plans and 一生运势报告 in a database on
  this computer, so a restart no longer loses them. How to turn it on: docs/web-test.md, 「Keep readings and accounts
  across restarts」.
  - `npm run keygen` prints the lines for `.env`. Then restart the API.
  - The data folder is `.data/` (never committed). **Back up `MINGLI_DATA_KEY`**: without it the data can't be read.
- Privacy, as your documents ask:
  - Each account has its own key. Every chart, reading, plan, life report, the 个人情况 sent with a reading, and the
    email are encrypted with it.
  - No birth date, reading or email is stored in the clear; a test checks that every row holds none.
  - Deleting an account deletes its key with it, so nothing of it can be read again. A deletion record without
    personal data stays as proof.
- Without the setting nothing changes: everything stays in memory, as before.
- Also fixed:
  - A background job that fails while saving is now logged instead of stopping the server.
  - Since v3.2.0 the server had loaded a development-only tool (OpenCC) at start; it no longer does, and a test keeps
    it so.
- Verified:
  - 13 new server tests:
    - the same checks on both stores;
    - a restart, and a wrong key;
    - no plaintext anywhere;
    - deletion;
    - the real API end to end on the database;
    - the server's dependencies.
  - All 325 server tests and 121 app tests pass; harness PASS.

### v4.0.0 (2026-10-28): 八字与全局 UI, complete: the English 命盘 reads cleanly

Stage S4 of the [tech plan](docs/tech-plan.md) is complete: work package 4.8 here, 4.1–4.7 in v3.1.0–v3.5.0. The
stage summary is in the plan under 阶段总结. A big update: pushed, together with every update since v3.1.0.

- English 命盘: names no longer break in the middle of a word.
  - The 四柱 table and the strips show each name without its pinyin: Hurting Officer, not Hurting Officer (Shang
    Guan). Tap it, and the explanation's title gives the full name.
  - A name of one word (Companion, Conception) shrinks a little to fit its cell.
  - The 大运, 流年 and 流月 strips are wider in English. A 流年 shows its year, its nominal age and each 十神 on a
    line of their own, so none is cut off.
  - The 刑冲合害 labels drop the pinyin too.
- Chinese pages are unchanged.
- Stage S4 in short (v3.1.0–v4.0.0):
  - 五行 colours you can read, in light and dark mode. The 四柱 table opens on what matters first.
  - Tap any dotted term of the 命盘 for what it means, in plain words.
  - The timeline:
    - 当前 marks the 大运 you are in, and 今年 this year;
    - any 大运 opens its ten years;
    - 流月 for the year.
  - A reading opens with your chart, and a jump list leads to each section.
  - Behind the scenes: the two largest pages split up, and every test scrolls the same careful way.
  - Not built, at your word: a separate 首页 entry for the 一生运势报告 (it stays inside 八字排盘, as you asked).
  - Moved to a later stage: sharing a reading as an image, made on the server with a watermark and the disclaimer,
    as your phase document asks.
- Readings did not change in this stage: the AI reads the same facts as before, and its prompts are unchanged.
- Verified:
  - 2 new app tests: the English strips (wider items, a line per part) and the brief form of a name.
  - All 312 server tests and 121 app tests pass; harness PASS on the final tree.

### v3.5.0 (2026-10-28): code health, no visible change

Stage S4 of the [tech plan](docs/tech-plan.md) (八字与全局 UI), work packages 4.6 and 4.7. A medium update:
committed locally, pushed with v4.0.0. The app looks and works as before.

- The two largest app pages are split into smaller pieces:
  - 一生运势报告: the page file is down from about 1,030 lines to 460. Its text blocks, its figures (卦, 梅花,
    八宅) and its stage chart are in three widget files.
  - 个人资料: down from 640 lines to 315. The birth date, time and place inputs, shared with the 八字 form, are
    in a widget file of their own.
- Tests: every widget test now scrolls through one helper that waits a frame before and after each scroll. Leaving
  that wait out made earlier tests tap where a card used to be. A new check fails if any test scrolls on its own.
- Plan change: the term tips planned for the 一生运势报告 were dropped. The report follows your sample template
  and has few 八字 terms. Its 喜用 / 忌 come from the reading, not from the simplified count the tip explains.
- Verified:
  - all 119 app tests pass, unchanged except for the scrolling (one new: the check);
  - all 312 server tests pass;
  - harness PASS.

### v3.4.0 (2026-10-28): a reading opens with your chart and a jump list

Stage S4 of the [tech plan](docs/tech-plan.md) (八字与全局 UI), work package 4.5. A medium update: committed
locally, pushed with v4.0.0.

- Reading page, at the top: 「跳到」 and a chip for every section (五行, 性格, 事业财运 …) and for 行动建议. Tap one
  to open that section, if it was closed, and bring it into view. On a phone the chips are one row that scrolls
  sideways.
- 八字 readings now open with your chart: the four pillars, coloured by 五行, and your 日主. Tarot readings keep
  their spread there.
- Keyboard: Tab reaches every chip (the row scrolls along). Enter jumps, and the next Tab continues inside that
  section, not back at the top.
- Plan changes, no app change:
  - The 首页 entry for the 一生运势报告 that the plan listed (WP4.4) is not built. You asked on 2026-10-27 for the
    report to live inside 八字排盘 as a second option, and that stays. 首页 already shows 今日 (每日一牌) and your
    recent readings.
  - Sharing a reading as an image moved to its own work package (WP4.9). Your phase document asks for the share
    image to be made on the server, with a watermark and the disclaimer, so it is not a screenshot of the app.
- Verified:
  - 4 new app tests: the pillars on top; a chip opens and reveals its section, 行动建议 too; on a phone Tab reaches
    the last chip; Enter jumps and Tab goes on inside.
  - All 312 server tests and 118 app tests pass; harness PASS.

### v3.3.0 (2026-10-28): the 命盘 timeline: where you are now, any 大运's ten years, and 流月

Stage S4 of the [tech plan](docs/tech-plan.md) (八字与全局 UI), work package 4.3. A medium update: committed
locally, pushed with v4.0.0.

- 命盘 page, 大运:
  - The 大运 you are in now carries a 当前 badge.
  - Tap any 大运 to open its ten years under the strip, e.g. 「辛巳大运 · 2007–2016年」. Each year shows its 干支,
    虚岁, 十神 and any 冲 / 合 with your chart. Tap it again to close them, or tap another one to switch.
- 流年: this year carries a 今年 badge, in the 流年 strip and in an opened 大运.
- 流月, new: 「2026年流月」 lists the twelve months from 立春. Each shows its 干支, the date it begins (北京时间), its
  节 (立春, 惊蛰 …) and its 十神.
- Keyboard: Tab reaches each 大运 and Enter opens or closes it. ←/→ still scroll the strip.
- English page:
  - The 节 have English names (Start of Spring, Awakening of Insects …).
  - A year's relation reads 「Hour Six Harmonies」; it used to run together as 「HourSix Harmonies」.
- Readings are unchanged: the new facts (the years of every 大运) are for the page only, and no AI prompt reads them.
- Verified:
  - 4 new server tests:
    - every 大运 has its ten years, and two years are worked out by hand (2007 丁亥 偏印 / 正财, 2029 己酉 比肩 /
      食神 with 卯酉 冲);
    - the years match the 流年 list where they meet;
    - every 节 has its names.
  - Prompt checks: no reading, plan or life report prompt contains the new facts.
  - 6 new app tests: the badges, opening and closing a 大运, the keyboard path, 流月, the English line, and a chart
    made before this update.
  - All 312 server tests and 114 app tests pass; harness PASS.

### v3.2.0 (2026-10-28): tap a term on the 命盘 to see what it means

Stage S4 of the [tech plan](docs/tech-plan.md) (八字与全局 UI), work package 4.2. A medium update: committed
locally, pushed with v4.0.0.

- 命盘 page: terms underlined with dots can be tapped. Each opens a short, plain explanation in the reader's script
  (简体, 繁體 or English), for someone who has never studied 命理. Close it with 关闭 or Esc.
  - The 四柱 table: each row's name (十神, 天干, 地支, 藏干, 十二长生, 纳音) and every 十神 and 十二长生 in it.
  - 旺衰: 身强 / 身弱 / 中和, 得令, and 喜用 and 忌 (one tip explains both).
  - 神煞 (天乙贵人, 文昌, 禄神, 羊刃, 桃花, 驿马, 华盖), 空亡 and 胎元.
  - 原局刑冲合害: each type, from 天干五合 to 相破.
  - The 五行, 神煞, 大运 and 流年 cards have a ? button that explains the card's subject.
- Tone: the tips describe tendencies and never frighten. 羊刃 is drive, not danger. 桃花 is charm, not an affair. 空亡
  is a quieter area, not loss. 死 is strength at rest, not death.
- English page: the 十二长生 stages 衰, 病, 死, 墓 and 胎 had no English name and showed in Chinese. They now read
  Decline, Sickness, Death, Tomb and Conception.
- Keyboard: Tab reaches each term, Enter opens it, and Esc closes it and returns to the same term.
- How it was made: one source on the server (`src/ai/term-tips.ts`), copied to the app by `npm run sync:app`. The
  繁體 is converted from the 简体 and every tip was checked by hand. Five conversion slips are fixed, among them
  丑 (not 醜) and 剋. Readings and prompts are unchanged.
- Verified:
  - 6 new server tests:
    - every term the page can show has a tip, derived from the engine;
    - quotes and characters are right for each script;
    - the reviewed text is pinned;
    - the compliance rules find nothing.
  - 3 new app tests: tapping in 繁體, the English page, and the keyboard path.
  - All 308 server tests and 108 app tests pass; harness PASS.

### v3.1.0 (2026-10-28): 五行 colours you can read, and a calmer 四柱 table

Stage S4 of the [tech plan](docs/tech-plan.md) (八字与全局 UI), work package 4.1. A medium update: committed
locally, pushed with v4.0.0.

- 命盘 page, 四柱 table: it opens on what matters first, 十神, 天干 and 地支. 「更多：藏干、长生、纳音」 under it opens
  the rest (藏干 with their 十神, 十二长生 and 纳音); 「收起」 folds them away again.
- 五行 colours, everywhere 干支 and 五行 are coloured:
  - Light mode: 木, 土 and 金 are a little darker, so even the small 藏干 read clearly on a card.
  - Dark mode: a lighter set of its own. Before, 水 blue was hard to read on a dark background.
  - The 一生运势报告 uses the same colours as the rest of the app (its 金 was gold, and hard to read).
- How it was checked: a test measures the contrast of every 五行 colour on the page and on a card, in light and dark
  mode, and requires at least 4.5 : 1, the level for small text.
- Verified:
  - 2 new app tests: the contrast of every colour in both themes; the 四柱 table with and without 更多.
  - All 301 server tests and 105 app tests pass; harness PASS.

### v3.0.0 (2026-10-28): 塔罗体验, complete: shuffle, cut and pick your own cards

Stage S3 of the [tech plan](docs/tech-plan.md) is complete: work package 3.6 here, 3.1–3.5 in v2.4.0–v2.8.0. The stage
summary is in the plan under 阶段总结. A big update: pushed, together with every update since v2.1.0.

- 塔罗 page: 「抽牌」 now opens the ritual: 洗牌 · 切牌 · 选牌.
  - 洗牌: hold your question in mind and press 洗牌.
  - 切牌: choose one of three piles to go on top.
  - 选牌: pick the cards yourself from the 78 lying face down, as many as the spread has. Each picked card shows its
    number.
  - The spread then lies face down as before, to be turned card by card.
  - 「让牌组替我选」 at every step draws the way it always has.
- Fairness: the system still shuffles the deck, fairly and the same way every time from the draw's own number. You
  only choose where to cut and which places to take. Your cut and picks are kept with the draw, so every draw can be
  checked afterwards. Checked over 100,000 draws: the cards and their orientation come out as evenly as without the
  ritual.
- Keyboard: Enter shuffles; Tab and Enter cut and pick.
- Stage S3 in short (v2.4.0–v3.0.0):
  - A reading shows its spread, and 历史记录 its cards' art.
  - The picker draws every spread small, with its positions and example questions.
  - 每日一牌 on 首页.
  - 牌义图鉴: the 78 cards with the keywords on their art.
  - Two more spreads, 二选一 and 关系牌阵.
  - The ritual.
- Verified:
  - 3 new server tests: the cards lie where the cut and picks say; the ritual kept and replayed, a draw without it
    unchanged; bad picks refused. 9 new checks in the 100,000-draw battery.
  - 3 new app tests: shuffle, cut and pick into the request; 「让牌组替我选」; the ritual by keyboard.
  - All 301 server tests and 103 app tests pass; harness PASS.

### v2.8.0 (2026-10-28): two more spreads, 二选一 and 关系牌阵

Stage S3 of the [tech plan](docs/tech-plan.md) (塔罗体验), work package 3.5. A medium update: committed locally,
pushed with v3.0.0.

- 二选一 (five cards), for a choice between two paths.
  - Card 1 at the bottom is where you stand. Path A rises on the left (how it tends to go, then where it tends to
    lead), path B on the right.
  - The reading weighs both paths fairly. It never chooses for you, and never calls either path doomed.
- 关系牌阵 (six cards), for any relationship: a partner, family, a friend, a colleague.
  - The top row is you, the bond and the other person; below are what stands between you, where it is going and
    what helps.
  - The other person's card is read as a tendency, never as a claim about what they think. There is never a
    prediction of a breakup.
- Both are drawn small in the picker, their positions listed before the draw, laid out as their spread prescribes
  after it, and read in the classic order (逐张解读 card by card, then the whole spread and the advice).
- The spread picker now wraps onto two lines on a phone, so all five fit. It works with Tab, Enter and Space like
  the other chips.
- Verified:
  - 1 new server test: both spreads dealt in position order, with their places and meanings, and their methods in
    the instructions. Every draw check (100,000 draws per spread) now runs on all five spreads.
  - 1 new app test: the V and the two rows. The picker test covers all five drawings.
  - All 298 server tests and 100 app tests pass; harness PASS.

### v2.7.0 (2026-10-28): 牌义图鉴, the whole deck

Stage S3 of the [tech plan](docs/tech-plan.md) (塔罗体验), work package 3.4. A medium update: committed locally,
pushed with v3.0.0.

- 塔罗 page: a new button 「牌义图鉴」 in the top bar opens the whole deck.
  - The 78 cards, in the deck's order: the 22 of the major arcana, then 权杖, 圣杯, 宝剑 and 星币, 14 each, every one
    with its art and name.
  - Touching a card opens it large with the three keywords painted on it (for example 星星: 希望、信心、疗愈).
- The keywords
  - In 简体 they are exactly the ones on the card art.
  - The 繁體 is converted and then checked by hand, as with the card names. One was corrected: 疗愈 is 療癒.
  - English is written to the classic Rider–Waite–Smith meanings (the Star: hope, faith, healing).
- Keyboard: every card is a Tab stop; Enter opens it and Esc closes it.
- Fixed: a server test that checks every city of the place list could fail when the whole suite ran at once (it
  took 10 s instead of 2.5 s); it now has its own time limit.
- Verified:
  - 3 new server tests: 3 keywords for every card in every script; the 繁體 as converted except the reviewed fix;
    a few cards as painted.
  - 2 new app tests: the deck in its groups, a card's keywords in 繁體; Tab, Enter and Esc.
  - All 295 server tests and 99 app tests pass; harness PASS.

### v2.6.0 (2026-10-28): 每日一牌, a card for the day

Stage S3 of the [tech plan](docs/tech-plan.md) (塔罗体验), work package 3.3. A medium update: committed locally,
pushed with v3.0.0.

- 首页: a new card 「今日一牌」 after the 八字 and 塔罗 entries.
  - It shows today's card with its art and name, upside down and marked 逆位 when it came reversed.
  - It is the same card all day. Tomorrow brings a new one. Every account has its own.
  - Touching it opens the card large; from there you can ask the AI to read it (a one-card tarot reading).
  - Where tarot isn't offered, or when the server can't be reached, the card simply isn't shown.
- How it works: the day's card comes from your account and the date, under the app's secret draw key. It can't be
  guessed in advance or read ahead of its day (only today's date is accepted, for any time zone), and like every
  draw it can be checked afterwards. It is kept as your chart but not listed among the charts you made.
- Keyboard: the card is a Tab stop after the 塔罗 entry; Enter opens it and Esc comes back.
- API: `GET /v1/tarot/daily?date=YYYY-MM-DD`.
- Verified:
  - 5 new server tests:
    - the same card all day, replaying from its draw id, and opened as the account's chart;
    - another day or account gets its own card, and others can't open yours;
    - only today's real date;
    - the Geo-Rule first, and not listed among the charts;
    - the id format.
  - 2 new app tests: the card on 首页 and its page; Tab, Enter and Esc. The home Tab-order test includes it.
  - All 292 server tests and 97 app tests pass; harness PASS.

### v2.5.0 (2026-10-28): choosing a spread, and asking

Stage S3 of the [tech plan](docs/tech-plan.md) (塔罗体验), work package 3.2. A medium update: committed locally,
pushed with v3.0.0.

- 塔罗 page
  - The spread picker shows each spread drawn small: one card, three in a row, or the Celtic Cross with card 2
    across card 1 and the staff beside it. Under it, the chosen spread's positions in dealing order, before you
    draw (for example 「1 过去 · 2 现在 · 3 未来」).
  - Four example questions as chips under the question field; a touch puts one in the field, to use or change.
  - The Celtic Cross list under the spread (each position with what it stands for) is at least 1.5× text, also on a
    phone. On wide screens it stays at 2×.
- Keyboard: the picker is one control, as elsewhere in the app. Tab reaches it, ←/→ switch the spread, and the focus
  ring shows. The example chips come right after the question.
- Data: each spread's positions now reach the app from the server's deck (one source).
- Verified:
  - 2 new app tests: the picker's drawings (1, 3 and 10 cards) and position lists against the server's spreads; an
    example question filling the field.
  - The phone test checks the 1.5× list.
  - All 287 server tests and 95 app tests pass; harness PASS.

### v2.4.0 (2026-10-28): a tarot reading shows its cards

Stage S3 of the [tech plan](docs/tech-plan.md) (塔罗体验), work package 3.1. A medium update: committed locally,
pushed with v3.0.0.

- Reading page: a tarot reading opens with its spread at the top, as it was laid out, every card turned and drawn
  with its art. On a phone a Celtic Cross shows as thumbnails, and touching one opens it large, as on the 塔罗 page.
  八字 reading pages are unchanged.
- 历史记录: a tarot reading shows its cards' art in small (up to five, then 「+5」 for a Celtic Cross), a reversed
  card upside down as it was drawn, above the card names.
- API: a report now carries its `chart_id`, so a reading page can show its chart (GET /v1/charts/{chart_id}).
- Verified:
  - The API test checks `chart_id` on a pending and a passed report.
  - The tarot reading test now also checks the spread on top of the reading, every card turned.
  - 1 new app test: the art in 历史记录, a reversed card upside down.
  - All 287 server tests and 93 app tests pass; harness PASS.

### v2.3.0 (2026-10-28): 塔罗 reads like a tarot reading

Stage S2 of the [tech plan](docs/tech-plan.md), work package 2.2, which completes the stage (v2.1.0–v2.3.0). A medium
update: committed locally, pushed with the next big update.

- 塔罗 page
  - Under the question, a new row 「想看哪方面（可选）」: 不限, 事业, 感情, 健康 or 自我. It is taken when the cards
    are drawn, like the question, and the reading looks at that part of life. 不限 is the default.
  - Before the reading, the request card says the reading has three parts, instead of offering topic chips.
- The tarot reading
  - It has three parts, in the order of a classic reading:
    - 逐张解读: every card in dealing order, one paragraph each (all ten of a Celtic Cross).
    - 综合解读: the spread as one story, answering the question.
    - 建议: what the cards suggest doing.
  - Before, the spread was read four times over, for 性格, 事业财运, 婚姻感情 and 健康, which is 八字's way.
  - The actions follow the 建议.
  - One 破除运势 plan per reading, on 建议; 逐张解读 and 综合解读 have none. Readings made before keep their four
    plans.
  - If the AI leaves a card out, it is asked again and told which card.
- Keyboard: Tab reaches the focus chips right after the question, in order; Space or Enter picks one.
- API: POST /v1/reports takes `focus` for a tarot reading (400 for any other method), and the tarot sections are new
  topic values.
- Verified:
  - 4 new server tests: the three sections with every card read, the focus reaching the AI, a skipped card asked
    again, and focus refused for 八字 and for unknown values. Others now expect one tarot plan.
  - 2 new app tests: the focus in the request, with the three parts and one plan on the report page; Tab and Space
    on the focus chips. Two phone tests needed a frame after `ensureVisible` (rule 27, widened).
  - All 287 server tests and 92 app tests pass; harness PASS.
- S2 in short (v2.1.0–v2.3.0): every method has its own instructions; the AI reads a focused copy of a 八字 chart
  (about half the characters); 塔罗 reads like a tarot reading.

### v2.2.0 (2026-10-28): the AI reads less, and what it reads matters

Stage S2 of the [tech plan](docs/tech-plan.md), work package 2.3. A medium update: committed locally, pushed with the
next big update.

- Nothing changes on screen. A 八字 reading, its 破除运势 plans and the 一生运势报告 are now written from a shorter,
  focused copy of the chart. They cost about half the tokens when the real AI is on, and the AI keeps to the periods
  that matter:
  - A reading sees the full detail (刑冲合害, 神煞, the reasons behind each score) of the current 大运 and the next,
    this year and the next two, and any year named in the question. Every other 大运 and 流年 it sees by name, age
    and 十神 only.
  - A 破除运势 plan sees in full the periods where its topic scores lowest from now on (two 大运, three 流年). Before,
    a plan could target a 大运 that was already over.
  - The 一生运势报告 no longer gets the 流月 and the 流年 scores, which it never used. No agent gets the 流月 now: no
    instruction used them.
- Measured on the sample chart: characters sent to the AI for a reading with all six topics, its six plans and the
  life report.

  | Agent (calls)                        | v2.1.0  | v2.2.0  |
  | ------------------------------------ | ------- | ------- |
  | Reading (1)                          | 32,418  | 17,524  |
  | Actions (1)                          | 2,628   | 2,576   |
  | 破除运势 plans (6)                   | 195,813 | 85,338  |
  | 一生运势报告 (2)                     | 73,681  | 62,743  |
  | Total                                | 304,540 | 168,181 |
  | Reviewer (8, only when review is on) | 267,738 | 137,098 |

  These are characters, not tokens: the JSON's spacing counts too.

- Fixed: the AI-evaluation check (`checkFaithfulness`) now knows the 干支 of 胎元 and of the 流月, so a reading that
  names them is no longer flagged as unknown.
- Verified:
  - 5 new server tests: a reading's focus (with a year asked about, and before the first 大运); every period keeps
    its place and only the focus ones keep their detail; a plan's focus is its topic's lowest from now on, never a
    past 大运; each 八字 agent reads its own view; the faithfulness check knows 胎元 and the 流月.
  - All 283 server tests and 90 app tests pass; harness PASS.

### v2.1.0 (2026-10-27): every method writes with its own instructions

Stage S2 of the [tech plan](docs/tech-plan.md), work package 2.1. A medium update: committed locally, pushed with the
next big update.

- 八字 readings
  - The 命盘事实 list of a report gains a line with the engine's 日主旺衰 and 喜用, as on the 五行 card:
    「日主旺衰（简化扶抑）：身弱；不得令；喜用：火、土；忌：金、水、木」.
  - An action that uses an element (a colour, a direction, a season) uses only the engine's 喜用. A balanced chart
    gets advice on balance, not on pushing one element.
  - 破除运势 plans base every 补 / 泄 step, colour and direction on the engine's 喜用 and 忌, and label ages 虚岁.
    Before, the AI chose the elements itself and wrote plain 岁.
- 塔罗 readings
  - Actions and 破除运势 plans have their own instructions. They rest on the cards drawn and their positions, with no
    五行, lucky colours, directions or other 八字 ideas.
  - A tarot plan names the cards it rests on, and ends with its own note
    (「以上建议依据所抽塔罗牌的牌义整理……」) instead of the 命理 one.
- Astrology (API only)
  - Readings and actions have their own instructions: the planets in their signs and their aspects, never houses or
    the ascendant, which the simplified chart doesn't compute. Before, astrology was read with 八字-style rules (for
    example health as 五行).
  - An astrology reading has no 破除运势 plan. None is prepared in the background, and a purchase is refused (400)
    before anything is charged.
- Behind the scenes: one table (`METHOD_PROMPTS`) says which instructions each method uses, and no two methods share
  them. A released prompt version never changes: a test pins all 15.
- Verified:
  - 7 new server tests: each method's prompts in every report; the hash of every prompt version; no 八字 rules in
    the tarot and astrology prompts; the tarot plan and its note; no astrology plan, in the pipeline and in the API;
    the 旺衰 line in three languages.
  - All 278 server tests and 90 app tests pass; harness PASS.

### v2.0.0 (2026-10-27): 八字 engine, complete: 日主旺衰, 喜用, and 运势 scores from the engine

Stage S1 of the [tech plan](docs/tech-plan.md) is complete: work packages 1.6–1.7 here, 1.1–1.5 in v1.3.0. The
stage summary is in the plan under 阶段总结. A big update: pushed, together with v1.3.0.

- 命盘 page, 五行 card: how strong the day master is, worked out by the engine.
  - It shows 身强, 身弱 or 中和, and 得令 or 不得令.
  - It lists the elements that help (「喜用：火、土」) and those to watch (「忌：金、水、木」).
  - An extreme chart (almost all support, or almost none) shows 专旺候选 or 从格候选 with 「宜请有经验的师傅细看」,
    and no 喜用.
- 运势走势 (in a 八字 reading): the engine computes the scores now, not the AI.
  - The same chart always gets the same scores, and scoring no longer costs a model call.
  - Every 大运 and 流年 has six scores from 20 to 85: 五行, 性格, 事业财运, 婚姻感情, 大运流年, 健康.
  - Each one has a one-line reason in 简体, 繁體 or English, for example
    「丙午：印星当头（学习和支持你的人）；五行多为对你有利的一方，与日支相破，宜多沟通。」
- 一生运势报告: each life stage is labelled with its 虚岁 and years (「虚岁 18–27（2007–2016）」). Its score is the
  engine's, so the report and the 运势走势 chart agree.
- AI readings of a 八字 chart have their own instructions (`narrative_bazi@5`). The AI explains the engine's 虚岁,
  旺衰 and 喜用, 刑冲合害, 神煞 and scores; it doesn't work them out again. Tarot and astrology readings are
  unchanged.
- How the engine decides:
  - 旺衰: a simplified 扶抑法 on the widely used 100-point scheme. 月支 counts 40; 日支, 时支, 月干 and 时干 12 each;
    年干 8; 年支 4. A branch's points go to its hidden stems (本气 / 中气 / 余气). The day master's own element and
    the one that generates it are its support: 55 or more is 身强, 45 or less 身弱.
  - 喜用 by 扶抑: a weak day master is helped by 印 and 比劫, a strong one by 食伤, 财 and 官杀. 调候, 合化 and the
    从格 itself are not considered.
  - Scores weigh three things: the period's elements against 喜用 and 忌, its 十神 for each topic, and its relations
    with the chart. A 冲 to the day or month branch lowers a score; a 合 raises it a little; 刑, 害 and 破 lower it a
    little. Gender doesn't change a score.
- Stage S1 in short (v1.3.0 + v2.0.0):
  - One age convention (虚岁) everywhere.
  - The 本命卦 on the same day as its hour.
  - All 合冲刑害破; 神煞, 空亡, 胎元 and 流月; the 子时 setting.
  - 旺衰 and 喜用, and scores from the engine.
  - Not yet: 命宫 / 身宫, waiting for a reference.
- Verified:
  - 7 new server tests: strength worked out by hand for 身弱, 身强 and both flags; the 2026 丙午 scores and note
    worked out by hand; the same chart always scores the same, within 20–85; a favourable period scores above an
    unfavourable one.
  - The 命盘 page test checks the strength pills.
  - All 271 server tests and 90 app tests pass; harness PASS.

### v1.3.0 (2026-10-27): 八字 engine, part 1: ages, the pillar day, 合冲刑害破, 神煞

Stage S1 of the [tech plan](docs/tech-plan.md), work packages 1.1–1.5. A medium update: committed locally, pushed
with v2.0.0.

- 命盘 page
  - Ages are 虚岁 everywhere and labelled 虚岁: the 大运 and 流年 strips, the 运势走势 chart and 破除运势. Before,
    流年 showed 周岁 and 大运 虚岁 under the same 「岁」, one year apart.
  - New card 神煞 · 空亡 · 胎元: 天乙贵人, 文昌, 禄神, 羊刃, 桃花, 驿马 and 华盖 with the pillars that hold them; 空亡
    from the day pillar and the pillars that fall in it; 胎元.
  - New card 原局刑冲合害: every 天干五合 / 相冲, and every 六合, 六冲, 三合, 半合, 三会, 相刑, 自刑, 六害 and 相破 between
    the four pillars.
- 个人资料: a new switch 「23:00–24:00 出生，日柱算次日」 for the other 子时 school. It is off by default, so a birth after
  23:00 keeps the same day, as before.
- 八字 engine (new facts only; nothing existing changed):
  - 虚岁 on every 大运 and 流年.
  - The 农历 of the day the pillars are read on. The 一生运势报告's 本命卦 now takes its date from it, so date and hour
    come from the same day even when 真太阳时 crosses midnight (far-west China, Spain in summer).
  - 合冲刑害破 for the chart, for every 大运 (with the chart) and every 流年 (with the chart and its 大运); 神煞 for the
    chart and each period; 空亡; 胎元; 流月 (the twelve months of the current year from 立春, with 干支, start time and
    十神; shown in a later update).
  - 20 new protected terms (the relation types, the 神煞, 空亡, 胎元, 流月, 虚岁) in 简体, 繁體 and English.
- Not yet: 命宫 / 身宫. Two textbook formulas disagree, and there is no reference at hand to settle it (WP1.8).
- Verified: 11 new server tests (each relation type, full 三合 / 三刑 without their pairs, the sample chart's relations
  and 神煞 worked out by hand, 空亡 across the 旬, 胎元 and 日空亡 against lunar-javascript, 流月 against the library's
  month pillar, 虚岁, the Kashgar pillar day and its 本命卦) and 2 app tests (虚岁 on both strips, the two new cards,
  the 子时 switch in the request); all 265 server tests and 90 app tests pass; harness PASS.

### v1.2.0 (2026-10-27): 塔罗 the classic way

Checked against the classic method (owner request). Already right: a fair shuffle dealt into the positions in order,
and the Celtic Cross positions and their order (after Rachel Pollack: 1 现在, 2 挑战 across it, 3 根基 below, 4 近期过去
behind, 5 潜能 above, 6 近期未来 ahead, 7–10 the staff). Not right before, fixed now:

- 塔罗 page
  - The question first: an optional 你想问的问题 box before the draw. It shows above the cards and goes with the
    reading.
  - Each spread lies as it prescribes: one card in the middle; three cards in one row, 过去 → 现在 → 未来 from left to
    right; the Celtic Cross as the cross (1 in the centre, 2 lying across 1, 3 below, 4 left, 5 above, 6 right) and the
    staff (7 at the bottom up to 10 at the top). Before, every spread was a grid of cards.
  - Cards are numbered and turned in dealing order: touching any face-down card turns the next one, which glows
    gold, and the line above the cards names it (按牌阵顺序翻牌，下一张：第 3 张 · 根基).
  - Phones: the Celtic Cross (and three cards on a narrow phone) are thumbnails; touching one opens it large, and it is
    turned there. iPad and desktop show the whole spread on one screen, and cards turn where they lie.
  - A turned card opens large with its position and what that position means. Under the Celtic Cross every position
    is listed with its meaning; a turned card's row opens it too (card 1 lies under card 2).
  - Keyboard: Tab reaches the turned cards and the next one, Enter or Space turns it; in the enlarged view Enter
    turns the card and Esc closes it; Enter in the question box or Ctrl+Enter draws.
- 塔罗 readings (AI)
  - Tarot reads with its own prompt, `narrative_tarot@1`, written for tarot alone: the cards in dealing order, each in
    the light of its position; the spread's own method (three cards past → present → future; Celtic Cross: 1 with 2,
    then the lines 3 → 5 and 4 → 6, then the staff 7 → 10, comparing 10 with 5 and 1); upright and reversed; major and
    minor arcana and the four suits; the user's question answered.
  - The model now gets the spread ready to read (`<spread>`): each position's number, name and meaning, where it lies,
    the card's name in the user's language, upright or reversed, and the path to cite. Before, it saw only ids such
    as `major_09`.
  - The facts in a reading are numbered in dealing order (1. 过去: 隐士).
  - Each method stays separate (owner rule): 八字 and astrology still read with `narrative@4`, unchanged byte for byte
    (a test pins it); nothing in this update reaches another method.
- For developers: `app/lib/presentation/widgets/tarot_spread.dart` (`TarotSpread`, `celticRects`), `src/ai/tarot.ts`
  (`spreadBrief`), `POSITION_MEANINGS` in `deck.ts` (synced to the app), fixtures `chart_tarot_celtic` and
  `chart_tarot_single`, CLAUDE.md hard rule 8.
- Verified: new server tests (the spread in dealing order, tarot on its own prompt with `<spread>` and the question,
  `narrative@4` unchanged, numbered facts) and app tests (three in a row; the Celtic Cross on a desktop; turning in
  order; phone thumbnails turned large; Enter and Esc in the enlarged view; the question sent with the reading); all 88
  app tests and 254 server tests pass; harness PASS. Rendered on a phone, a laptop and a desktop.

### v1.1.2 (2026-10-27): tarot names match the art; two cards to a row on phones

- 塔罗
  - On a phone the cards are as large as two side by side allow, 137 pt on a 360-wide phone (208 left room for
    only one per row), and the text in the card area scales with them. Screens from about 500 pt wide keep twice
    the first size (208-pt cards, 28-pt text).
  - Card names now match the names painted on the art: 愚人 (was 愚者), 皇后 (was 女皇), 权杖一 / 圣杯一 / 宝剑一 /
    星币一 (were …王牌); in 繁體 the same (權杖一 …). 塔罗 readings use the new names too.
- For developers
  - `src/engines/tarot/deck.ts` has the new names, and `NAME_ALIASES` keeps the earlier ones, so the faithfulness
    check still catches a reading that writes 愚者 or 权杖王牌 for a card that wasn't drawn. The check no longer
    reads 「宝剑一样」 ("like a sword") as the Ace of Swords.
  - `npm run mirror:tarot` no longer reports names that differ.
- Verified: new tests for the phone layout (two 137-pt cards to a row at 360 wide, 208 at 1000), the earlier names
  and 「寶劍一樣」; all 83 app tests and 248 server tests pass; harness PASS. Rendered on a 360-wide phone in 简体 and
  English.

### v1.1.1 (2026-10-27): tarot cards twice as large

- 塔罗 (owner request: the cards and their text twice as large)
  - Cards are twice the size: 208 × 357 instead of 104 × 178. The text in the card area is doubled with them: the
    hint 点击卡牌翻开 and each card's position and name (28 instead of 14), and 逆位 (24 instead of 12). The back's
    gold frame and star grow too.
  - At this size the name, English name and keywords painted on a card can be read on the card itself.
  - Wide screens (tablet, desktop) show a three-card spread in one row. A phone has room for one card per row, so the
    cards stack and the page scrolls.
  - The rest of the page (牌阵, 抽牌, the reading request) keeps its size.
- For developers
  - The pictures are now 700×1200, the size the art was painted at and enough for the 208-pt card on a 3× screen:
    4.4 MB for all 78, made again with `npm run mirror:tarot`.
  - One constant, `_scale` in `app/lib/presentation/tarot_page.dart`, sets the size of the cards and their text.
- Verified: all 82 app tests and 247 server tests pass (the bundle test now checks 700×1200); harness PASS. The page
  was rendered at phone and desktop width and looked at.

### v1.1.0 (2026-10-27): tarot card art

**塔罗 cards with pictures** (new): every card of the 78-card deck now has its own picture, painted in
JingyaoPaint.

- 塔罗
  - Turning a card shows its picture: the scene, its number, its name (简体 and English) and three keywords, in the
    deck's navy and gold. A reversed card lies upside down, with 逆位 under it, as with a real deck.
  - Under each card: the position, and once the card is turned, its name in the chosen language (the name painted on
    the picture is small and always 简体).
  - Cards have the pictures' shape (7:12, 104 × 178) with small rounded corners. The back is the deck's navy and gold
    in light and dark mode alike (before: the app's red-to-green gradient).
  - The pictures load while the cards lie face down, so each card shows its picture as it turns. A card whose picture
    can't load shows its name, as before.
  - Keyboard and screen readers work as before: Tab to a card, Enter or Space turns it; the card is read out as its
    position, then its name and 逆位.
- For developers
  - `app/assets/tarot/`: one picture per card, named by card id (`major_00.webp` … `pentacles_14.webp`), 350×600
    WebP, 1.7 MB for all 78.
  - `npm run mirror:tarot` makes that folder from JingyaoPaint's `local_art/out/tarot` (1400×2400 PNG, about 2.4 MB
    each). It checks every file against the deck by its number and English name, fits it to 350×600 (enough for the
    104-pt card on a 3× screen), and makes the folder match: changed cards are rewritten, unchanged ones left alone,
    anything else removed. Run it again whenever the art changes (another folder: `npm run mirror:tarot -- <folder>`).
    Never edit the folder by hand.
  - New dev dependency: sharp 0.35.5 (image resizing; only the mirror script uses it).
- Verified: new server test (the folder holds exactly the deck's 78 cards, each a 350×600 WebP; file names map to
  cards by number and English name) and app test (all 78 pictures in the app bundle decode in Flutter at 350×600;
  turned cards show their picture and name); all 82 app tests and 247 server tests pass; harness PASS. The page was
  checked on rendered images in light and dark. The text painted on the cards (names and keywords, 367 in all) hits no
  compliance rule.
- Note: six cards are named differently on the picture and in the app (the deck in `src/engines/tarot/deck.ts`):
  愚人 (app: 愚者), 皇后 (女皇), 权杖一 / 圣杯一 / 宝剑一 / 星币一 (app: …王牌). The app shows its own name under the
  card.

### v1.0.0 (2026-10-27): keyboard access; first numbered release

The first numbered version. It contains everything delivered so far ([docs/SUMMARY.md](docs/SUMMARY.md)) and the
updates below.

**Keyboard access for web users** (new): the whole app works without a mouse.

- Every page
  - **Esc goes back one level.** An open dropdown or menu closes first, then a dialog, then the page. On 首页 it
    does nothing.
  - **Leaving a reading asks first.** On the 八字 form once you have changed something (or while it computes), on the
    命盘 page, and on 塔罗 once cards are drawn, going back asks 返回将重新开始 with 继续测算 / 返回. Enter = 返回,
    Esc = stay. The ← button, the browser's Back and a phone's back button ask the same. The profile editor and the
    为谁排盘 pop-up ask 放弃未保存的修改？ when edited.
  - **Tab / Shift+Tab** reach every control in reading order; **Enter / Space** press it and open or close a section.
  - **A clear focus outline** shows where you are while you use the keyboard: buttons, chips, cards, tarot cards,
    charts, option rows. It never shows for mouse or touch.
  - **Ctrl+/** (⌘/ on a Mac), or **?** outside a text field: the 键盘快捷键 list. Also in 设置 → 键盘快捷键.
  - **Ctrl+Enter** (⌘+Enter): the main button of the page: 登录, 排盘, 保存.
  - **Ctrl+Tab / Ctrl+Shift+Tab** stay the browser's (switching browser tabs; browsers never pass them to a page),
    as do Ctrl+W/T/L, F5 and Alt+←/→. Switching between options inside the app is **← / →**.
- 登录: Enter in 邮箱 moves to 密码; Enter in 密码 signs in.
- 八字排盘
  - 为谁排盘 from the keyboard: Tab to its arrow, Enter or ↓ opens, ↑ / ↓ move, Enter picks.
  - ← / → switch 排盘解读 / 一生运势报告, 公历 / 农历, 精确时间 / 时辰 and 男 / 女.
  - The 公历 date and the time, opened from the keyboard, start in typing mode (type 1990-03-15 instead of arrowing
    back through the years).
  - On the 命盘 page the 大运 / 流年 strips take focus: ← / → scroll, Home / End jump to the ends.
- 塔罗: every card is a Tab stop; Enter or Space turns it over. Screen readers hear the position, and the card once
  turned.
- 解读报告: the 运势走势 chart takes focus: ← / → previous / next period, Home / End first / last; ← / → switch
  大运 / 流年; Enter opens or closes each topic.
- 出生地: opened from the keyboard, type straight away; Enter takes the first match; Esc clears the search, then
  steps back 城市 → 省 → 国家.
- Fixed on the way: a chart or tarot draw that finishes after you have left no longer opens on top of 首页 or
  touches a closed page.
- For developers: `app/lib/presentation/keyboard.dart` (`KeyboardShell`, `LeaveGuard`, `SubmitShortcut`,
  `Pressable`, `SegmentKeys`), the focus look in `design.dart` / `theme.dart`, and the rules for new screens in the
  keyboard-access skill. A test fails if a screen adds a tap target without keyboard support.
- Verified: 20 new app tests (7 for the keyboard layer, 13 across every area above); all 81 app tests and 244
  server tests pass; harness PASS (lint, typecheck, tests, OpenAPI, schemas, audit, 八字 7000 cases vs the oracle,
  塔罗 100k draws, app analyze + tests + web build). The focus outline was checked on rendered images in light and
  dark. Not run: browser-based tests, which don't load on this machine.

**Also in v1.0.0** (earlier updates of this release):

- Top bar: 历史记录 · 个人资料 · 语言 (简 / 繁 / EN) · 设置 gear instead of the ⋮ menu; 语言 also on the sign-in page.
- Mock or real AI: `IS_AI_MOCK=TRUE` in `.env` answers every AI step with the mock (（示范）, no tokens);
  `IS_AI_MOCK=FALSE` with `IS_AI_MODEL=TRUE` uses DeepSeek. The API follows `.env` without a restart
  ([docs/web-test.md](docs/web-test.md)).
- 为谁排盘: pick, add or edit a person in a pop-up; 一生运势报告 is a mode of 八字排盘; the birthplace appears in
  readings.
- 一生运势报告: 易经本命卦, 梅花易数, 五行, 八卦; download (HTML + Markdown in a ZIP), print / PDF, copy.
- Content review paused by owner decision (`MINGLI_REVIEW=on` turns it back on); new disclaimer wording.
- 简体中文 is the main language, alongside 繁體中文 and English.

```
src/chart-fact/      ChartFact types, canonical JSON, keyed input digest, schema validator
src/engines/bazi/    BaziEngine (lunar-javascript + tz/DST + true solar time)
src/engines/tarot/   78-card RWS deck, spreads, HMAC-DRBG, audit replay
src/engines/astrology/  POC adapter on astronomy-engine
src/compliance/      rule-layer scanner + Geo-Rule resolver
src/ai/              AI Interp pipeline, providers (Claude, DeepSeek, mock), usable models, prompts, terms
src/api/             v1 API server (auth, account, charts, async reports)
src/auth/            passwords, tokens, Apple/Google ID tokens, login limits
src/service/         chart validation + runtime wiring shared by API and demo
app/                 Flutter app (Riverpod, zh-Hant/zh-Hans/en)
compliance/          prohibited_patterns.yaml, geo_rule_matrix.json, ai_disclosure_spec.md
schemas/             JSON Schemas (ChartFact v0.1, geo matrix)
api/openapi.yaml     OpenAPI 3.1 skeleton
db/schema_v0.sql     PostgreSQL schema v0
docs/                ADRs, POC report, security baseline, data retention, agent records
MODULES.md           reusable module registry. Check it before adding code.
```

Requires Node ≥ 20.

```
npm ci
npm run lint && npm test && npm run validate:schemas && npm run validate:openapi
```

Or run the full harness:
`powershell -ExecutionPolicy Bypass -File C:\Users\AgentSkills\harness-check\scripts\check.ps1 -Project .`
