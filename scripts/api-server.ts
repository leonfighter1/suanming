/**
 * npm run api      → http://127.0.0.1:8787 (dev mode: bearer tokens, or X-Dev-User / X-Dev-Country headers)
 * npm run api:lan  → all interfaces, for phones on the same Wi-Fi (docs/web-test.md).
 *                    Sign-in only: the X-Dev-User shortcut is off, since other machines can reach it.
 * npm run public   → web app + API behind a public https tunnel (scripts/public.ts).
 */
import { existsSync, watchFile } from "node:fs";
import { networkInterfaces } from "node:os";
import { fileURLToPath } from "node:url";
import { createApiServer } from "../src/api/server.js";
import { notifyFromEnv } from "../src/notify/index.js";
import {
  buildAuth,
  buildProviders,
  describeAi,
  DEV_ACCOUNTS,
  loadSecrets,
  openStore,
  seedDevAccounts,
  watchAiMode,
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
/**
 * The AI switch: IS_AI_MOCK / IS_AI_MODEL in .env, re-read when the file changes.
 * A flip applies from the next AI call, with no restart (the public URL stays).
 */
const providers = buildProviders(
  watchAiMode(".env", shellEnv, () => console.log(`AI switched: ${describeAi(providers)}`)),
);
// Notice a saved .env within a second, so the console confirms the flip.
watchFile(".env", { persistent: false, interval: 1000 }, () => providers.mode());
const port = Number(process.env.PORT ?? 8787);
const host = process.env.HOST ?? (lan ? "0.0.0.0" : "127.0.0.1");
const loopbackOnly = !pub && (host === "127.0.0.1" || host === "localhost");
const staticDir = fileURLToPath(new URL("../app/build/web/", import.meta.url));
if (pub && !existsSync(staticDir)) {
  console.error(`--public needs the built web app in ${staticDir} (npm run public builds it)`);
  process.exit(2);
}
const aiQuota = {
  perUserPerDay: Number(process.env.MINGLI_AI_DAILY_PER_USER ?? 10),
  totalPerDay: Number(process.env.MINGLI_AI_DAILY_TOTAL ?? 100),
};

// Readings and accounts: in memory, or kept in the encrypted database (MINGLI_STORE=pglite, S5).
const persistence = await openStore(secrets);
const auth = buildAuth(secrets, true, persistence.users);
await seedDevAccounts(auth, true);
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
  ...(persistence.store && { store: persistence.store }),
  // Content review is paused by owner decision (2026-10-26) until the legal &
  // obligations work: MINGLI_REVIEW=on turns holds, the guard and 内容审核 back on.
  review: process.env.MINGLI_REVIEW === "on",
  // 内容审核 reviewers: logins allowed to read and decide held content.
  admins: (process.env.MINGLI_ADMINS ?? "admin").split(","),
  mail: notify.mail,
  sms: notify.sms,
  aiServing: providers.serving,
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
