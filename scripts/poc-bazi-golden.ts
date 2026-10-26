/**
 * 八字 golden cases vs authoritative 排盘 tools (Phase 0 gate: 50 cases, 四柱 100%,
 * 大运起运 ≤ 1 day). Cases are added by the 算法 owner from a named reference tool;
 * never generate expected values from this engine.
 *
 * Usage: npm run poc:bazi-golden   (exit 1 on any mismatch or if < 50 cases)
 */
import { readFileSync } from "node:fs";
import { computeBazi, type BaziInput } from "../src/engines/bazi/index.js";

interface GoldenCase {
  id: string;
  category: "jieqi_boundary" | "zi_hour" | "true_solar_time" | "dst" | "ordinary";
  input: BaziInput;
  expected: {
    /** "庚午 己卯 己卯 辛未" */
    pillars: string;
    /** YYYY-MM-DD; optional when the reference tool does not show it */
    dayun_start_date?: string;
  };
  /** Reference tool + version + how it was configured (真太阳时/子时流派) */
  source: string;
}

const REQUIRED = 50;
const file = JSON.parse(
  readFileSync(new URL("../test/fixtures/bazi-golden.json", import.meta.url), "utf8"),
) as { cases: GoldenCase[] };

const ctx = { digestPepper: Buffer.alloc(32), now: () => new Date(0) };
let fail = 0;
for (const c of file.cases) {
  const f = computeBazi(c.input, ctx).facts as unknown as {
    pillars: Record<string, { gan: string; zhi: string }>;
    dayun: { start_date: string };
  };
  const got = (["year", "month", "day", "hour"] as const)
    .map((k) => f.pillars[k]!.gan + f.pillars[k]!.zhi)
    .join(" ");
  const problems: string[] = [];
  if (got !== c.expected.pillars) problems.push(`pillars ${got} ≠ ${c.expected.pillars}`);
  if (c.expected.dayun_start_date) {
    const days =
      Math.abs(Date.parse(f.dayun.start_date) - Date.parse(c.expected.dayun_start_date)) /
      86_400_000;
    if (days > 1)
      problems.push(
        `dayun start ${f.dayun.start_date} vs ${c.expected.dayun_start_date} (${days}d)`,
      );
  }
  if (problems.length) {
    fail++;
    console.log(`✗ ${c.id} [${c.category}] ${problems.join("; ")}`);
  }
}

const byCat = file.cases.reduce<Record<string, number>>(
  (m, c) => ((m[c.category] = (m[c.category] ?? 0) + 1), m),
  {},
);
console.log(`\n${file.cases.length - fail}/${file.cases.length} pass; by category:`, byCat);
if (file.cases.length < REQUIRED) {
  console.log(`GATE NOT MET: ${file.cases.length}/${REQUIRED} golden cases present`);
  process.exit(1);
}
process.exit(fail ? 1 : 0);
