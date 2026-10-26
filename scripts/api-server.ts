/**
 * npm run api      → http://127.0.0.1:8787 (dev mode: bearer tokens, or X-Dev-User / X-Dev-Country headers)
 * npm run api:lan  → all interfaces, for phones on the same Wi-Fi (docs/web-test.md).
 *                    Sign-in only: the X-Dev-User shortcut is off, since other machines can reach it.
 */
import { networkInterfaces } from "node:os";
import { createApiServer } from "../src/api/server.js";
import {
  buildAuth,
  buildProviders,
  DEV_ACCOUNTS,
  loadSecrets,
  seedDevAccounts,
  servingProvider,
} from "../src/service/runtime.js";

try {
  process.loadEnvFile(".env");
} catch {
  // no .env: providers without credentials fall back to the mock
}

const lan = process.argv.includes("--lan");
const secrets = loadSecrets();
const providers = buildProviders();
const port = Number(process.env.PORT ?? 8787);
const host = process.env.HOST ?? (lan ? "0.0.0.0" : "127.0.0.1");
const loopbackOnly = host === "127.0.0.1" || host === "localhost";

const auth = buildAuth(secrets, true);
await seedDevAccounts(auth, true);
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
  corsPrivateNetwork: !loopbackOnly,
  devHeaders: loopbackOnly,
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
  if (!loopbackOnly) {
    for (const ip of lanAddresses()) {
      console.log(`  phone on the same Wi-Fi: app http://${ip}:5000  (API http://${ip}:${port})`);
    }
    console.log("  X-Dev-User shortcut is off (reachable from other machines); sign in instead.");
  }
  console.log(`AI provider: ${servingProvider(providers.live)}`);
  console.log(
    `CORS origins: localhost${loopbackOnly ? "" : ", private-network http"}, ${corsOrigins.join(", ")}`,
  );
  console.log(`dev accounts: ${DEV_ACCOUNTS.map((a) => `${a.login} / ${a.password}`).join(", ")}`);
  if (secrets.ephemeral) {
    console.log(
      "warning: MINGLI_DIGEST_PEPPER / MINGLI_TAROT_DRAW_KEY not set; using per-process keys",
    );
  }
});

for (const sig of ["SIGINT", "SIGTERM"] as const) {
  process.on(sig, () => {
    server.close();
    // Let in-flight reports finish before exiting.
    void server.drain().then(() => process.exit(0));
  });
}
