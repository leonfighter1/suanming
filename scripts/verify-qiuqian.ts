/**
 * 求籤 technical verification: statistical battery on the draw (sticks and blocks).
 *   npm run verify:qiuqian            # 100 000 draws
 *   npm run verify:qiuqian -- 300000
 * Writes docs/verification/qiuqian-results.json; exit 1 if any check fails.
 */
import { mkdirSync, writeFileSync } from "node:fs";
import { qiuqianBattery } from "../test/oracle/qiuqian-stats.js";

const n = Number(process.argv[2] ?? 100_000);
const started = Date.now();
const result = { generated_at: new Date().toISOString(), ...qiuqianBattery(n), seconds: 0 };
result.seconds = Math.round((Date.now() - started) / 1000);
mkdirSync(new URL("../docs/verification/", import.meta.url), { recursive: true });
writeFileSync(
  new URL("../docs/verification/qiuqian-results.json", import.meta.url),
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
