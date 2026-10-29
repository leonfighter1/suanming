/**
 * npm run ai:models: the models the AI steps can use (src/ai/models.ts), which one the routes use now, and whether
 * its provider's key is in .env (never the key itself). ACTIVE_AI_MODEL=<id> in .env picks one for every step (S17).
 */
import { MODELS } from "../src/ai/index.js";
import { buildProviders, describeAi } from "../src/service/runtime.js";

try {
  process.loadEnvFile(".env");
} catch {
  // no .env: no keys
}

const providers = buildProviders();
const routed = new Set(providers.models().split(","));
const header = ["", "id", "provider", "$ in / out per MTok", "key in .env", "what for"];
const rows = MODELS.map((m) => [
  routed.has(m.id) ? "*" : "",
  m.id,
  m.provider,
  m.price ? `${m.price.input} / ${m.price.output}` : "-",
  providers.live.includes(m.provider) ? "set" : "missing",
  `${m.label}, ${m.use}${m.note ? ` (${m.note})` : ""}`,
]);
const table = [header, ...rows];
const widths = header.map((_, i) => Math.max(...table.map((r) => r[i]!.length)));

console.log(
  "Models the AI steps can use. ACTIVE_AI_MODEL=<id> in .env answers every step with one of them.\n",
);
for (const r of table)
  console.log(
    r
      .map((cell, i) => cell.padEnd(widths[i]!))
      .join("  ")
      .trimEnd(),
  );
const source = providers.choice().model ? "ACTIVE_AI_MODEL" : "config/model_routing.json";
console.log(`\n* the routes' model now (${source}). AI: ${describeAi(providers)}`);
