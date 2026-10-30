/**
 * What the draws' verification scripts share (S28 WP28.3; docs/refactor-plan.md F11): run a statistical battery on
 * the count the command names (100 000 by default), write docs/verification/<name>-results.json, print each check,
 * and exit 1 if any check fails.
 */
import { mkdirSync, writeFileSync } from "node:fs";
import type { Check } from "../test/oracle/stats.js";

export function runVerification(
  name: string,
  battery: (n: number) => { checks: Check[]; pass: boolean },
) {
  const n = Number(process.argv[2] ?? 100_000);
  const started = Date.now();
  const result = { generated_at: new Date().toISOString(), ...battery(n), seconds: 0 };
  result.seconds = Math.round((Date.now() - started) / 1000);
  mkdirSync(new URL("../docs/verification/", import.meta.url), { recursive: true });
  writeFileSync(
    new URL(`../docs/verification/${name}-results.json`, import.meta.url),
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
}
