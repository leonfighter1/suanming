/**
 * CI schema gate: every schema compiles in strict mode, the geo matrix and rule set
 * are valid, and each engine's output validates against ChartFact.
 */
import { readFileSync } from "node:fs";
import { Ajv2020 } from "ajv/dist/2020.js";
import addFormatsModule from "ajv-formats";
import { validateChartFact } from "../src/chart-fact/index.js";
import { compileRules, loadGeoMatrix, loadRuleSet } from "../src/compliance/index.js";
import { computeAstrology } from "../src/engines/astrology/index.js";
import { computeBazi } from "../src/engines/bazi/index.js";
import { computeFengshui } from "../src/engines/fengshui/index.js";
import { computeNaming } from "../src/engines/naming/index.js";
import { computeQiuqian } from "../src/engines/qiuqian/index.js";
import { computeTarot } from "../src/engines/tarot/index.js";

const addFormats = addFormatsModule as unknown as (ajv: Ajv2020) => Ajv2020;
const read = (p: string) => JSON.parse(readFileSync(new URL(`../${p}`, import.meta.url), "utf8"));
let failed = false;
const check = (name: string, ok: boolean, detail?: unknown) => {
  console.log(`${ok ? "✓" : "✗"} ${name}`);
  if (!ok) {
    failed = true;
    console.log(JSON.stringify(detail, null, 2));
  }
};

const ajv = addFormats(new Ajv2020({ allErrors: true, strict: true }));
const geo = ajv.compile(read("schemas/geo-rule-matrix.schema.json"));
check("geo_rule_matrix.json", geo(loadGeoMatrix()) as boolean, geo.errors);

const rules = loadRuleSet();
try {
  compileRules(rules, Object.keys(rules.groups));
  check("prohibited_patterns.yaml compiles", true);
} catch (e) {
  check("prohibited_patterns.yaml compiles", false, String(e));
}

const ctx = { digestPepper: Buffer.alloc(32, 1), drawKey: Buffer.alloc(32, 2) };
const samples = {
  bazi: computeBazi(
    { local: "1990-03-15T14:30", timezone: "Asia/Hong_Kong", longitude: 114.17, gender: "female" },
    ctx,
  ),
  tarot: computeTarot({ spread: "celtic_cross" }, ctx),
  astrology: computeAstrology(
    { local: "1990-03-15T14:30", timezone: "Asia/Hong_Kong", latitude: 22.32, longitude: 114.17 },
    ctx,
  ),
  qiuqian: computeQiuqian({}, ctx),
  fengshui: computeFengshui({ room: "study", facing: "south" }, ctx),
};
// 起名 reads a 八字 chart.
const samplesWithNaming = {
  ...samples,
  naming: computeNaming(samples.bazi, { surname: "陳", length: 2 }, ctx),
};
for (const [name, fact] of Object.entries(samplesWithNaming)) {
  const r = validateChartFact(fact);
  check(`ChartFact(${name})`, r.ok, r.ok ? undefined : r.errors);
}

process.exit(failed ? 1 : 0);
