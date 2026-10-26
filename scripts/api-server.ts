/** npm run api → http://127.0.0.1:8787 (dev mode: bearer tokens, or X-Dev-User / X-Dev-Country headers) */
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

const secrets = loadSecrets();
const providers = buildProviders();
const port = Number(process.env.PORT ?? 8787);
const host = process.env.HOST ?? "127.0.0.1";

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
});
server.listen(port, host, () => {
  console.log(`命理大师 API v1 (dev mode) on http://${host}:${port}`);
  console.log(`AI provider: ${servingProvider(providers.live)}`);
  console.log(`CORS origins: localhost, ${corsOrigins.join(", ")}`);
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
