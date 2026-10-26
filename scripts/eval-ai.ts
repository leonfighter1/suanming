/**
 * AI technical verification: run real reports for 八字 and 塔羅 cases and check
 * each automatically (status, attempts, latency, tokens, rule hits, faithfulness).
 *
 *   npm run eval:ai             # mock provider (free, checks the harness itself)
 *   npm run eval:ai -- --live   # real provider from .env (DeepSeek); costs money
 * Writes docs/verification/ai-eval-results.json.
 */
import { mkdirSync, writeFileSync } from "node:fs";
import {
  checkFaithfulness,
  generateReport,
  MockProvider,
  type Locale,
  type Topic,
} from "../src/ai/index.js";
import type { ChartFact } from "../src/chart-fact/index.js";
import { computeChart } from "../src/service/charts.js";
import { buildProviders, loadSecrets, servingProvider } from "../src/service/runtime.js";

try {
  process.loadEnvFile(".env");
} catch {
  // no .env
}

const live = process.argv.includes("--live");
if (!live) process.env.MINGLI_AI_PROVIDER = "mock";
const providers = buildProviders();
if (live && providers.live.length === 0) {
  console.error("--live needs DEEPSEEK_API_KEY (or another provider key) in .env");
  process.exit(2);
}

interface EvalCase {
  name: string;
  chart: Record<string, unknown>;
  locale: Locale;
  country: string;
  topics?: Topic[];
}

const CASES: EvalCase[] = [
  {
    name: "八字 · 香港 · 精確時間 · 繁體 · 六方面",
    chart: {
      system: "bazi",
      local: "1990-03-15T14:30",
      timezone: "Asia/Hong_Kong",
      longitude: 114.17,
      gender: "male",
    },
    locale: "zh-Hant",
    country: "HK",
  },
  {
    name: "八字 · 台北 · 農曆 + 時辰 · 繁體",
    chart: {
      system: "bazi",
      local: "1988-08-08T08:00",
      timezone: "Asia/Taipei",
      longitude: 121.56,
      gender: "female",
      options: { inputBasis: { date: "lunar", time: "shichen", shichen: "辰" } },
    },
    locale: "zh-Hant",
    country: "TW",
    topics: ["personality", "dayun_liunian", "health"],
  },
  {
    name: "八字 · 上海 · 简体 · 立春後春節前",
    chart: {
      system: "bazi",
      local: "2024-02-06T09:15",
      timezone: "Asia/Shanghai",
      longitude: 121.47,
      gender: "male",
    },
    locale: "zh-Hans",
    country: "SG",
    topics: ["wuxing", "career_wealth", "relationships"],
  },
  {
    name: "八字 · London · English",
    chart: {
      system: "bazi",
      local: "1975-11-02T23:40",
      timezone: "Europe/London",
      longitude: -0.13,
      gender: "female",
    },
    locale: "en",
    country: "GB",
    topics: ["personality", "wuxing"],
  },
  {
    name: "塔羅 · 三張 · 繁體",
    chart: { system: "tarot", spread: "three_card" },
    locale: "zh-Hant",
    country: "HK",
  },
  {
    name: "塔羅 · 凱爾特十字 · 简体",
    chart: { system: "tarot", spread: "celtic_cross" },
    locale: "zh-Hans",
    country: "MY",
  },
];

const secrets = loadSecrets();
const started = Date.now();
console.log(
  `provider: ${live ? servingProvider(providers.live) : "mock"} · ${CASES.length} cases defined`,
);

// --only <text>: run just the cases whose name contains <text>.
const only = process.argv[process.argv.indexOf("--only") + 1];
const selected =
  process.argv.includes("--only") && only ? CASES.filter((c) => c.name.includes(only)) : CASES;

/** For 時辰 input, the text must tell the reader the hour is a two-hour window. */
const SHICHEN_MENTION = /時辰|时辰|兩小時|两小时|two-hour|2-hour|時柱只|时柱只/;

const results = await Promise.all(
  selected.map(async (c) => {
    const t0 = Date.now();
    const chart: ChartFact = computeChart(c.chart, secrets);
    try {
      const report = await generateReport(
        chart,
        { locale: c.locale, country: c.country, topics: c.topics },
        {
          providers: live
            ? providers.map
            : { deepseek: new MockProvider(), anthropic: new MockProvider() },
        },
      );
      const issues = report.status === "passed" ? checkFaithfulness(chart, report) : [];
      const shichenInput =
        (chart.facts as { input_basis?: { time?: string } }).input_basis?.time === "shichen";
      const text = (report.layers?.interpretation ?? [])
        .flatMap((s) => s.paragraphs.map((p) => p.text))
        .join("\n");
      if (shichenInput && report.status === "passed" && !SHICHEN_MENTION.test(text)) {
        issues.push({
          kind: "unknown_ganzhi",
          detail: "時辰 input but the reading never mentions the two-hour precision",
          quote: text.slice(0, 120),
        });
      }
      return {
        case: c.name,
        status: report.status,
        reasons: report.reasons,
        seconds: Math.round((Date.now() - t0) / 1000),
        attempts: Object.fromEntries(report.agents.map((a) => [a.agent, a.attempts])),
        tokens: report.agents.reduce((s, a) => s + a.usage.input_tokens + a.usage.output_tokens, 0),
        rule_hits: report.compliance.rule_violations.map((v) => v.rule_id),
        review_pass: report.compliance.review?.pass ?? null,
        term_fixes: report.compliance.term_fixes,
        dropped_ungrounded: report.compliance.dropped_ungrounded,
        faithfulness_issues: issues,
        paragraphs: report.layers?.interpretation.reduce((s, x) => s + x.paragraphs.length, 0) ?? 0,
        // Kept for the human review the Phase 1 gate requires.
        facts_layer: report.layers?.facts,
        interpretation: report.layers?.interpretation,
        actions: report.layers?.actions,
      };
    } catch (e) {
      return {
        case: c.name,
        status: "error",
        error: (e as Error).message,
        seconds: Math.round((Date.now() - t0) / 1000),
      };
    }
  }),
);

const passed = results.filter((r) => r.status === "passed");
const summary = {
  cases: results.length,
  passed: passed.length,
  faithful: passed.filter(
    (r) => "faithfulness_issues" in r && (r.faithfulness_issues ?? []).length === 0,
  ).length,
  max_seconds: Math.max(...results.map((r) => r.seconds)),
  total_tokens: results.reduce((s, r) => s + ("tokens" in r ? (r.tokens as number) : 0), 0),
};
mkdirSync(new URL("../docs/verification/", import.meta.url), { recursive: true });
writeFileSync(
  new URL("../docs/verification/ai-eval-results.json", import.meta.url),
  JSON.stringify({ generated_at: new Date().toISOString(), live, summary, results }, null, 2) +
    "\n",
);
for (const r of results) {
  const issues = "faithfulness_issues" in r ? (r.faithfulness_issues ?? []).length : "-";
  console.log(
    `${r.status.padEnd(13)} ${String(r.seconds).padStart(4)}s  faithfulness issues: ${issues}  ${r.case}`,
  );
}
console.log(JSON.stringify(summary), `· ${Math.round((Date.now() - started) / 1000)}s total`);
