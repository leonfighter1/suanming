/**
 * 塔羅 technical verification: statistical battery on the draw.
 *   npm run verify:tarot            # 100 000 draws per spread
 *   npm run verify:tarot -- 300000
 * Writes docs/verification/tarot-results.json; exit 1 if any check fails.
 */
import { mkdirSync, writeFileSync } from "node:fs";
import { tarotBattery } from "../test/oracle/tarot-stats.js";

const n = Number(process.argv[2] ?? 100_000);
const started = Date.now();
const result = { generated_at: new Date().toISOString(), ...tarotBattery(n), seconds: 0 };
result.seconds = Math.round((Date.now() - started) / 1000);
mkdirSync(new URL("../docs/verification/", import.meta.url), { recursive: true });
writeFileSync(
  new URL("../docs/verification/tarot-results.json", import.meta.url),
  JSON.stringify(result, null, 2) + "\n",
);
for (const c of result.checks) {
  console.log(
    `${c.pass ? "PASS" : "FAIL"}  ${c.name}  (${c.statistic} < ${c.critical}${c.detail ? `; ${c.detail}` : ""})`,
  );
}
console.log(
  `\n${result.checks.filter((c) => c.pass).length}/${result.checks.length} checks passed in ${result.seconds}s`,
);
process.exit(result.pass ? 0 : 1);
