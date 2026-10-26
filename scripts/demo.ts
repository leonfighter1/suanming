/**
 * Manual Phase 0 testing from the terminal. Same handlers as the web UI (npm run demo:ui).
 *
 *   npm run demo -- bazi 1990-03-15T14:30 Asia/Hong_Kong 114.17 male [--civil] [--sect1]
 *   npm run demo -- tarot three_card            (single | three_card | celtic_cross)
 *   npm run demo -- astro 1990-03-15T14:30 Asia/Hong_Kong 22.32 114.17
 *   npm run demo -- guard US "No outcome is guaranteed."
 *   npm run demo -- report 1990-03-15T14:30 Asia/Hong_Kong 114.17 male HK zh-Hant [topic,...]
 *     (AI report; uses the provider in config/model_routing.json if its key is in .env)
 */
import { writeFileSync } from "node:fs";
import { runAstro, runBazi, runGuard, runReport, runTarot } from "../src/demo/handlers.js";

try {
  process.loadEnvFile(".env");
} catch {
  // no .env: AI commands fall back to the mock provider
}

const [cmd, ...args] = process.argv.slice(2);
const flags = new Set(args.filter((a) => a.startsWith("--")));
const pos = args.filter((a) => !a.startsWith("--"));

function show(r: { fact: unknown; schema: { ok: boolean; errors?: unknown } }) {
  console.log(JSON.stringify(r.fact, null, 2));
  console.log(`\nschema: ${r.schema.ok ? "valid" : "INVALID " + JSON.stringify(r.schema.errors)}`);
}

switch (cmd) {
  case "bazi": {
    const [local, timezone, lon, gender] = pos;
    const r = runBazi({
      local: local!,
      timezone: timezone!,
      longitude: Number(lon),
      gender: gender as "male" | "female",
      trueSolarTime: !flags.has("--civil"),
      ziHourSect: flags.has("--sect1") ? 1 : 2,
    });
    show(r);
    const p = (r.fact.facts as { pillars: Record<string, { gan: string; zhi: string }> }).pillars;
    console.log(
      `四柱: ${["year", "month", "day", "hour"].map((k) => p[k]!.gan + p[k]!.zhi).join(" ")}`,
    );
    break;
  }
  case "tarot": {
    const r = runTarot({ spread: pos[0] });
    show(r);
    for (const c of r.cards) {
      console.log(
        `${c.position_key.padEnd(12)} ${c.card.name["zh-Hant"]} / ${c.card.name.en}${c.reversed ? "（逆位）" : ""}`,
      );
    }
    console.log(`audit replay: ${r.audit_verified ? "verified" : "FAILED"}`);
    break;
  }
  case "astro": {
    const [local, timezone, lat, lon] = pos;
    show(
      runAstro({
        local: local!,
        timezone: timezone!,
        latitude: Number(lat),
        longitude: Number(lon),
      }),
    );
    break;
  }
  case "guard": {
    const [country, ...words] = pos;
    const r = runGuard({ country: country!, text: words.join(" ") });
    if (r.refused) {
      console.log(`${r.country}: service refused (451) by Geo-Rule`);
      break;
    }
    console.log(
      `region: ${r.region.name}  groups: ${r.region.rule_groups.join(",")}  AI label: ${r.region.ai_disclosure.visible_label}`,
    );
    console.log(
      r.pass ? "PASS: no violations" : `BLOCKED: ${JSON.stringify(r.violations, null, 2)}`,
    );
    break;
  }
  case "report": {
    const [local, timezone, lon, gender, country = "HK", locale = "zh-Hant", topics] = pos;
    const started = Date.now();
    const r = await runReport({
      system: "bazi",
      input: { local, timezone, longitude: Number(lon), gender },
      locale: locale as "zh-Hant",
      country,
      topics: topics?.split(",") as never,
    });
    if ("refused" in r) {
      console.log(`451: ${r.error}`);
      break;
    }
    const out = "report.json";
    writeFileSync(out, JSON.stringify(r.report, null, 2));
    const rep = r.report;
    console.log(
      `provider: ${r.provider}  status: ${rep.status}  ${((Date.now() - started) / 1000).toFixed(1)}s`,
    );
    if (rep.reasons.length) console.log(`reasons: ${rep.reasons.join("; ")}`);
    for (const a of rep.agents) {
      console.log(
        `  ${a.agent.padEnd(9)} ${a.model} attempts=${a.attempts} in=${a.usage.input_tokens} out=${a.usage.output_tokens} cache=${a.usage.cache_read_input_tokens ?? 0}${a.problems.length ? ` problems=${a.problems.join(" | ")}` : ""}`,
      );
    }
    console.log(
      `rule hits: ${rep.compliance.rule_violations.map((v) => v.rule_id).join(",") || "none"}  term fixes: ${rep.compliance.term_fixes.join(",") || "none"}`,
    );
    console.log(`full report → ${out}`);
    break;
  }
  default:
    console.log(
      "usage: npm run demo -- bazi|tarot|astro|guard|report ...  (see scripts/demo.ts header)",
    );
}
