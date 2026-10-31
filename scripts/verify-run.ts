/**
 * What the draws' verification scripts share (S28 WP28.3; docs/refactor-plan.md F11): run a statistical battery on
 * the count the command names (100 000 by default), write docs/verification/<name>-results.json, print each check,
 * and exit 1 if any check fails.
 */
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import type { Check } from "../test/oracle/stats.js";

/**
 * Writes docs/verification/<name>-results.json, unless only its time (generated_at, seconds) would change: the results
 * are deterministic, and a rewrite at every harness run left the tree changed for nothing (owner, 2026-10-30).
 */
export function writeResults(name: string, result: { generated_at: string; seconds: number }) {
  const file = new URL(`../docs/verification/${name}-results.json`, import.meta.url);
  const text = JSON.stringify(result, null, 2) + "\n";
  const timeless = (json: string) => {
    const { generated_at: _at, seconds: _s, ...rest } = JSON.parse(json) as Record<string, unknown>;
    return JSON.stringify(rest);
  };
  try {
    if (existsSync(file) && timeless(readFileSync(file, "utf8")) === timeless(text)) return;
  } catch {
    // A file that doesn't parse is written afresh.
  }
  mkdirSync(new URL("../docs/verification/", import.meta.url), { recursive: true });
  writeFileSync(file, text);
}

export function runVerification(
  name: string,
  battery: (n: number) => { checks: Check[]; pass: boolean },
) {
  const n = Number(process.argv[2] ?? 100_000);
  const started = Date.now();
  const result = { generated_at: new Date().toISOString(), ...battery(n), seconds: 0 };
  result.seconds = Math.round((Date.now() - started) / 1000);
  writeResults(name, result);
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
