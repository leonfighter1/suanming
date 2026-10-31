/**
 * npm run api      → http://127.0.0.1:8787 (dev mode: bearer tokens, or X-Dev-User / X-Dev-Country headers)
 * npm run api:lan  → all interfaces, for phones on the same Wi-Fi (docs/web-test.md).
 *                    Sign-in only: the X-Dev-User shortcut is off, since other machines can reach it.
 * npm run public   → web app + API behind a public https tunnel (scripts/public.ts).
 * The 管理后台, once built (npm run admin:build), at /admin/ on the same port.
 */
import { existsSync, watchFile } from "node:fs";
import { networkInterfaces } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { checkRouting, loadRouting } from "../src/ai/index.js";
import { adminDemoOn, seedAdminDemo } from "../src/admin/demo.js";
import { createApiServer } from "../src/api/server.js";
import { InMemoryStore } from "../src/api/store.js";
import { notifyFromEnv } from "../src/notify/index.js";
import { Settings } from "../src/settings/index.js";
import { OpenErApi, RateBook } from "../src/currency/index.js";
import { loadPointsConfig } from "../src/points/index.js";
import {
  buildAuth,
  buildProviders,
  describeAi,
  DEV_ACCOUNTS,
  grantDevPoints,
  loadSecrets,
  openStore,
  pointsOn,
  seedDevAccounts,
  watchAi,
  withPanel,
} from "../src/service/runtime.js";

// The shell's own variables, from before .env: they win over the file.
const shellEnv = { ...process.env };
try {
  process.loadEnvFile(".env");
} catch {
  // no .env: providers without credentials fall back to the mock
}

const lan = process.argv.includes("--lan");
/**
 * --public: for a tunnel (npm run public). Listens on loopback only (the tunnel
 * connects locally), serves the built web app on the same origin, trusts the
 * tunnel's client-IP header, turns the X-Dev-User shortcut off and caps AI jobs.
 */
const pub = process.argv.includes("--public");
const secrets = loadSecrets();
const port = Number(process.env.PORT ?? 8787);
const host = process.env.HOST ?? (lan ? "0.0.0.0" : "127.0.0.1");
const loopbackOnly = !pub && (host === "127.0.0.1" || host === "localhost");
// The web app npm run public builds for the same origin (the harness's own build is app/build/web).
const staticDir = fileURLToPath(new URL("../app/build/public/", import.meta.url));
// The 管理后台 (S22), once built (npm run admin:build): served at /admin/. MINGLI_ADMIN_DIR names another build;
// off serves none.
const adminEnv = process.env.MINGLI_ADMIN_DIR;
const adminDir =
  adminEnv === "off"
    ? undefined
    : adminEnv || fileURLToPath(new URL("../admin/build/served/", import.meta.url));
const adminBuilt = !!adminDir && existsSync(join(adminDir, "index.html"));
if (pub && !existsSync(staticDir)) {
  console.error(`--public needs the built web app in ${staticDir} (npm run public builds it)`);
  process.exit(2);
}
// Readings and accounts: in memory, or kept in the encrypted database (MINGLI_STORE=pglite, S5).
const persistence = await openStore(secrets);
const store = persistence.store ?? new InMemoryStore();
// 设置 (S31): config/settings.json and .env, with what the 管理后台's 设置 page changed (kept in the store).
const settings = await new Settings(store).load();
const auth = buildAuth(secrets, true, persistence.users, persistence.sessions, settings);
/**
 * The AI switch (IS_AI_MOCK / IS_AI_MODEL) and the model choice (ACTIVE_AI_MODEL) in .env, re-read when the file
 * changes, under what an admin chose in 设置 (S31). A change applies from the next AI call, with no restart (the
 * public URL stays).
 */
const ai = watchAi(".env", shellEnv, () => console.log(`AI switched: ${describeAi(providers)}`));
const panel = withPanel(settings, ai);
const providers = buildProviders(panel.mode, panel.choice);
// Notice a saved .env within a second, so the console confirms the change.
watchFile(".env", { persistent: false, interval: 1000 }, () => providers.mode());
// 货币 (S31): today's exchange rates from the online service (no person's data in the request), the last good table
// kept in the store for a start without it.
const rates = new RateBook(
  new OpenErApi(),
  () => new Date(),
  store,
  (m) => console.log(m),
);
// Public mode's AI caps, read from 设置 at each job: a change in the 管理后台 holds from the next one.
const aiQuota = {
  get perUserPerDay() {
    return settings.number("limits.ai_per_user_day");
  },
  get totalPerDay() {
    return settings.number("limits.ai_total_day");
  },
};
await seedDevAccounts(auth, true);
// 积分 (S20): on unless MINGLI_POINTS=off. 充值 is simulated here (development): no payment, the pack's 积分 arrive.
const points = pointsOn(process.env) ? loadPointsConfig() : undefined;
const granted = points ? await grantDevPoints(auth, store, points.dev_grant) : 0;
// 管理后台 (S22): demo accounts with 90 days of history for the dashboard, once, unless MINGLI_ADMIN_DEMO=off.
const demo = adminDemoOn(process.env)
  ? await seedAdminDemo({ auth, store, config: points ?? loadPointsConfig(), now: new Date() })
  : undefined;
// Mail and text messages (S15): the development outbox until the owner picks providers (MINGLI_MAIL / MINGLI_SMS).
const notify = notifyFromEnv(true);
// The GitHub Pages web test (docs/web-test.md) calls this API from its https origin.
const corsOrigins = (process.env.MINGLI_CORS_ORIGINS ?? "https://leonfighter1.github.io")
  .split(",")
  .map((o) => o.trim())
  .filter(Boolean);
const server = createApiServer({
  secrets,
  providers: providers.map,
  auth,
  devMode: true,
  corsOrigins,
  corsPrivateNetwork: lan,
  // The database keeps records only for accounts: no X-Dev-User shortcut with it.
  devHeaders: loopbackOnly && !persistence.store,
  store,
  settings,
  rates,
  ...(points && { points: { config: points, simulateTopUp: true } }),
  // Content review is paused by owner decision (2026-10-26) until the legal &
  // obligations work: MINGLI_REVIEW=on turns holds, the guard and 内容审核 back on.
  review: process.env.MINGLI_REVIEW === "on",
  // 内容审核 reviewers: logins allowed to read and decide held content.
  admins: (process.env.MINGLI_ADMINS ?? "admin").split(","),
  mail: notify.mail,
  sms: notify.sms,
  aiServing: providers.serving,
  aiModel: providers.models,
  routing: providers.routing,
  ...(adminBuilt && { adminDir }),
  ...(pub && { trustProxy: true, staticDir, aiQuota }),
});

/** This machine's private IPv4 addresses (what a phone on the same Wi-Fi uses). */
const lanAddresses = () =>
  Object.values(networkInterfaces())
    .flat()
    .filter((a) => a && a.family === "IPv4" && !a.internal)
    .map((a) => a!.address)
    .filter((ip) => /^(10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)/.test(ip));

server.listen(port, host, () => {
  console.log(`命理大师 API v1 (dev mode) on http://${host}:${port}`);
  if (pub) {
    console.log(
      `  public mode: web app + API on this port; AI cap ${aiQuota.perUserPerDay}/account/day, ${aiQuota.totalPerDay}/day total`,
    );
  } else if (!loopbackOnly) {
    for (const ip of lanAddresses()) {
      console.log(`  phone on the same Wi-Fi: app http://${ip}:5000  (API http://${ip}:${port})`);
    }
    console.log("  X-Dev-User shortcut is off (reachable from other machines); sign in instead.");
  }
  console.log(`AI: ${describeAi(providers)}`);
  // Today's rates fetched now, so the first 我的积分 doesn't wait for them.
  void rates
    .today()
    .then((r) =>
      console.log(
        r
          ? `rates: ${r.date} (open.er-api.com); 充值 in ${settings.choices("currencies.accepted").join(", ")}`
          : "rates: none yet (the service didn't answer); 充值 in 元 alone",
      ),
    );
  // Anything in config/model_routing.json that src/ai/models.ts doesn't allow, said before a reading fails on it.
  for (const problem of checkRouting(loadRouting())) console.log(`  routing: ${problem}`);
  console.log(
    process.env.MINGLI_REVIEW === "on"
      ? "content review: ON (holds, guard, 内容审核)"
      : "content review: PAUSED (hits recorded, nothing held; MINGLI_REVIEW=on to enable)",
  );
  console.log(
    `CORS origins: localhost${loopbackOnly ? "" : ", private-network http"}, ${corsOrigins.join(", ")}`,
  );
  console.log(`dev accounts: ${DEV_ACCOUNTS.map((a) => `${a.login} / ${a.password}`).join(", ")}`);
  console.log(
    points
      ? `积分: on; 充值 is simulated (no payment); each dev account starts with ${points.dev_grant}` +
          (granted ? ` (given now to ${granted})` : " (given before)") +
          "; MINGLI_POINTS=off makes AI requests free"
      : "积分: off (MINGLI_POINTS=off): AI requests are free",
  );
  console.log(
    !adminDemoOn(process.env)
      ? "管理后台: no demo accounts (MINGLI_ADMIN_DEMO=off)"
      : demo
        ? `管理后台: ${demo.accounts} demo accounts with 90 days of history (${demo.jobs} AI jobs); MINGLI_ADMIN_DEMO=off leaves them out`
        : "管理后台: the demo accounts are there from before; MINGLI_ADMIN_DEMO=off leaves new stores without them",
  );
  console.log(
    adminBuilt
      ? `管理后台: http://${host === "0.0.0.0" ? "127.0.0.1" : host}:${port}/admin/ (admins: ${(process.env.MINGLI_ADMINS ?? "admin").split(",").join(", ")})`
      : adminDir
        ? "管理后台: not built yet (npm run admin:build, then start the API again)"
        : "管理后台: not served (MINGLI_ADMIN_DIR=off)",
  );
  console.log(
    `mail: ${notify.mail.name}, sms: ${notify.sms.name}` +
      (notify.outbox
        ? ` (nothing is sent: codes and reports are written to ${notify.outbox}/, no provider yet)`
        : ""),
  );
  console.log(
    persistence.dataDir
      ? `data: kept in ${persistence.dataDir}, encrypted (MINGLI_STORE=pglite); the X-Dev-User shortcut is off`
      : "data: in memory, gone at the next start (MINGLI_STORE=pglite keeps it; docs/web-test.md)",
  );
  if (secrets.ephemeral) {
    console.log(
      "warning: MINGLI_DIGEST_PEPPER / MINGLI_TAROT_DRAW_KEY not set; using per-process keys",
    );
  }
});

for (const sig of ["SIGINT", "SIGTERM"] as const) {
  process.on(sig, () => {
    server.close();
    // Let in-flight reports finish (and write their results) before the database closes.
    void server
      .drain()
      .then(() => persistence.close())
      .then(() => process.exit(0));
  });
}
