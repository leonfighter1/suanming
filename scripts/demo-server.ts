/** npm run demo:ui → http://127.0.0.1:4173 (PORT env to change) */
import { createDemoServer } from "../src/demo/server.js";

// Local secrets (DEEPSEEK_API_KEY, ...) from the git-ignored .env, if present.
try {
  process.loadEnvFile(".env");
} catch {
  // no .env: providers without credentials fall back to the mock
}

const port = Number(process.env.PORT ?? 4173);
createDemoServer().listen(port, "127.0.0.1", () => {
  console.log(`命理大师 Phase 0 demo: http://127.0.0.1:${port}`);
});
