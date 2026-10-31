/**
 * 八字 technical verification: BaziEngine vs an independent oracle
 * (test/oracle/bazi-oracle.ts) on random births 1901–2099 and on edge cases
 * (±60 min around 節, 23:00–01:00). Writes docs/verification/bazi-results.json.
 *
 *   npm run verify:bazi            # 5000 random + 2000 edge
 *   npm run verify:bazi -- 20000   # more random cases
 * Exit code 1 if any case is an unexplained mismatch ("error").
 */
import { compareOne, edgeCases, randomCases, summarize } from "../test/oracle/compare.js";
import { writeResults } from "./verify-run.js";

const n = Number(process.argv[2] ?? 5000);
const started = Date.now();
const random = randomCases(n, 20261026).map((c) => compareOne(c));
const edge = edgeCases(424242, 1000).map((c) => compareOne(c));
const all = [...random, ...edge];

const fieldCounts: Record<string, number> = {};
for (const r of all)
  for (const d of r.diffs) fieldCounts[d.split(":")[0]!] = (fieldCounts[d.split(":")[0]!] ?? 0) + 1;

const result = {
  generated_at: new Date().toISOString(),
  oracle:
    "Swiss Ephemeris 2.10 (Moshier) for 節 / sun / equation of time; JDN day pillar (1900-01-01 甲戌); 五虎遁 / 五鼠遁",
  engine: "BaziEngine (lunar-javascript 1.7.7 + tzdb + true solar time)",
  random: summarize(random),
  edge: summarize(edge),
  mismatched_fields: fieldCounts,
  errors: all.filter((r) => r.status === "error").slice(0, 50),
  boundary_examples: all.filter((r) => r.status === "boundary").slice(0, 10),
  seconds: Math.round((Date.now() - started) / 1000),
};
writeResults("bazi", result);
console.log(
  JSON.stringify({
    random: result.random,
    edge: result.edge,
    mismatched_fields: fieldCounts,
    seconds: result.seconds,
  }),
);
for (const e of result.errors.slice(0, 10))
  console.log("ERROR", JSON.stringify(e.input), "|", e.diffs.join(" | "));
process.exit(result.random.error + result.edge.error > 0 ? 1 : 0);
