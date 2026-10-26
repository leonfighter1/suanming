/** npm run api → http://127.0.0.1:8787 (dev mode: bearer tokens, or X-Dev-User / X-Dev-Country headers) */
import { createApiServer } from "../src/api/server.js";
import { buildAuth, buildProviders, loadSecrets, servingProvider } from "../src/service/runtime.js";

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
const server = createApiServer({ secrets, providers: providers.map, auth, devMode: true });
server.listen(port, host, () => {
  console.log(`命理大师 API v1 (dev mode) on http://${host}:${port}`);
  console.log(`AI provider: ${servingProvider(providers.live)}`);
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
