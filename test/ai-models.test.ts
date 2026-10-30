import { mkdtempSync, rmSync, utimesSync, writeFileSync } from "node:fs";
import type { AddressInfo } from "node:net";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import {
  checkRouting,
  costUsd,
  generateReport,
  loadRouting,
  MockProvider,
  modelInfo,
  MODELS,
  withModel,
  type RoutingTable,
} from "../src/ai/index.js";
import { createApiServer } from "../src/api/server.js";
import { buildProviders, modelChoice, watchAi } from "../src/service/runtime.js";
import { DRAW_KEY, FIXED_NOW, PEPPER, sampleBazi } from "./helpers.js";

describe("the models to choose from (S17, v9.2.0)", () => {
  it("every route answers with Claude Opus 5.5 (owner, 2026-10-29), at medium effort but the 深度分析's", () => {
    const table = loadRouting();
    for (const [agent, routes] of Object.entries(table.routes)) {
      expect(routes.default, agent).toMatchObject({
        provider: "anthropic",
        model: "claude-opus-5-5",
        // v10.0.0: the user waits for each 深度分析 question, a short one, so it thinks briefly.
        effort: agent === "inquiry" ? "low" : "medium",
      });
    }
    // Its thinking counts toward max_tokens: twice what DeepSeek had (32,000 for the reading).
    expect(table.routes.narrative.default.max_tokens).toBe(64_000);
    expect(table.routes.inquiry.default.max_tokens).toBe(8_000);
    expect(checkRouting(table)).toEqual([]);
  });

  it("lists Anthropic's current models at their list prices, and DeepSeek V4 Pro", () => {
    // Anthropic's catalog (2026-10-29), $ per MTok: input, output, cache read.
    const prices = Object.fromEntries(
      MODELS.map((m) => [m.id, m.price && [m.price.input, m.price.output, m.price.cacheRead]]),
    );
    expect(prices).toEqual({
      "claude-opus-5-5": [4, 20, 0.2],
      "claude-fable-5-1": [10, 50, 0.25],
      "claude-sonnet-5-5": [2, 10, 0.2],
      "claude-haiku-5-5": [0.1, 0.5, 0.01],
      "deepseek-v4-pro": undefined,
    });
    // A 5-minute cache write is 1.25 × input for every Claude model.
    for (const m of MODELS)
      if (m.price) expect(m.price.cacheWrite).toBeCloseTo(m.price.input * 1.25, 10);
    // The server-side fallback: Claude only, and not Claude Haiku 5.5.
    expect(MODELS.filter((m) => m.fallback).map((m) => m.id)).toEqual([
      "claude-opus-5-5",
      "claude-fable-5-1",
      "claude-sonnet-5-5",
    ]);
    for (const m of MODELS.filter((x) => x.provider === "anthropic")) {
      expect(m.maxOutput).toBe(128_000);
    }
    expect(new Set(MODELS.map((m) => m.id)).size).toBe(MODELS.length);
    expect(modelInfo("claude-opus-4-1")).toBeUndefined(); // retired
  });

  it("checkRouting names what a table gets wrong", () => {
    const table = loadRouting();
    const broken: RoutingTable = {
      ...table,
      routes: {
        ...table.routes,
        narrative: {
          default: {
            provider: "anthropic",
            model: "claude-opus-55",
            effort: "medium",
            max_tokens: 1000,
          },
        },
        action: {
          default: {
            provider: "anthropic",
            model: "deepseek-v4-pro",
            effort: "high",
            max_tokens: 16_000,
          },
        },
        guard: {
          default: {
            provider: "anthropic",
            model: "claude-haiku-5-5",
            effort: "low",
            max_tokens: 200_000,
          },
          en: {
            provider: "deepseek",
            model: "deepseek-v4-pro",
            effort: "high",
            max_tokens: 64_000,
          },
        },
      },
    };
    expect(checkRouting(broken)).toEqual([
      "narrative: claude-opus-55 is not a usable model",
      "action: deepseek-v4-pro is served by deepseek, not anthropic",
      "guard: max_tokens 200000 is over Claude Haiku 5.5's 128000",
      "guard (en): max_tokens 64000 is over DeepSeek V4 Pro's 32000",
    ]);
  });

  it("withModel puts every route on one model, at its effort and within its limit, and leaves the table alone", () => {
    const table: RoutingTable = {
      version: "t",
      routes: {
        ...loadRouting().routes,
        narrative: {
          default: {
            provider: "anthropic",
            model: "claude-opus-5-5",
            effort: "medium",
            max_tokens: 64_000,
          },
          "zh-Hant": {
            provider: "anthropic",
            model: "claude-opus-5-5",
            effort: "high",
            max_tokens: 16_000,
          },
        },
      },
    };
    const before = JSON.stringify(table);
    const deepseek = withModel(table, modelInfo("deepseek-v4-pro")!);
    expect(deepseek.version).toBe("t");
    expect(deepseek.routes.narrative).toEqual({
      // 64,000 is over DeepSeek's 32,000: capped.
      default: {
        provider: "deepseek",
        model: "deepseek-v4-pro",
        effort: "high",
        max_tokens: 32_000,
      },
      // 16,000 is within it: kept. A locale's route follows the choice too.
      "zh-Hant": {
        provider: "deepseek",
        model: "deepseek-v4-pro",
        effort: "high",
        max_tokens: 16_000,
      },
    });
    expect(JSON.stringify(table)).toBe(before);
    // Any model in the list gives a table checkRouting accepts.
    for (const m of MODELS) expect(checkRouting(withModel(loadRouting(), m))).toEqual([]);
  });

  it("choosing the table's own model keeps each step's settings; another model brings its own effort", () => {
    // The owner's .env names claude-opus-5-5, the model every shipped route already has: the table stands as it is,
    // the 深度分析's questions at effort low among them (v10.0.0).
    const table = loadRouting();
    const same = withModel(table, modelInfo("claude-opus-5-5")!);
    expect(same.routes).toEqual(table.routes);
    expect(same.routes.inquiry.default.effort).toBe("low");
    // Another model answers every step at its own effort, the 深度分析 too.
    const sonnet = withModel(table, modelInfo("claude-sonnet-5-5")!);
    expect(sonnet.routes.inquiry.default).toEqual({
      provider: "anthropic",
      model: "claude-sonnet-5-5",
      effort: "medium",
      max_tokens: 8_000,
    });
  });

  it("costUsd prices a usage at list price, and nothing for a model without one", () => {
    const usage = {
      input_tokens: 2000,
      output_tokens: 8000,
      cache_read_input_tokens: 6000,
      cache_creation_input_tokens: 1500,
    };
    // Claude Opus 5.5: 2,000 × 4 + 8,000 × 20 + 6,000 × 0.2 + 1,500 × 5 = 8,000 + 160,000 + 1,200 + 7,500
    // = 176,700 per million tokens = $0.1767.
    expect(costUsd("claude-opus-5-5", usage)).toBeCloseTo(0.1767, 10);
    // Claude Haiku 5.5: 2,000 × 0.1 + 8,000 × 0.5 + 6,000 × 0.01 + 1,500 × 0.125 = 200 + 4,000 + 60 + 187.5
    // = 4,447.5 per million = $0.0044475.
    expect(costUsd("claude-haiku-5-5", usage)).toBeCloseTo(0.0044475, 10);
    // Without cache fields, input and output alone: 8,000 + 160,000 = $0.168.
    expect(costUsd("claude-opus-5-5", { input_tokens: 2000, output_tokens: 8000 })).toBeCloseTo(
      0.168,
      10,
    );
    for (const id of ["deepseek-v4-pro", "mock/claude-opus-5-5", "gpt-5"]) {
      expect(costUsd(id, usage)).toBeUndefined();
    }
  });

  it("modelChoice reads ACTIVE_AI_MODEL: unset, a usable model, or a typo", () => {
    expect(modelChoice({})).toEqual({});
    expect(modelChoice({ ACTIVE_AI_MODEL: "  " })).toEqual({});
    expect(modelChoice({ ACTIVE_AI_MODEL: " claude-sonnet-5-5 " }).model?.id).toBe(
      "claude-sonnet-5-5",
    );
    expect(modelChoice({ ACTIVE_AI_MODEL: "opus" })).toEqual({
      error:
        "ACTIVE_AI_MODEL=opus is not a usable model, so config/model_routing.json answers " +
        "(usable: claude-opus-5-5, claude-fable-5-1, claude-sonnet-5-5, claude-haiku-5-5, deepseek-v4-pro)",
    });
    // The owner's first value (2026-10-29): Claude 1's old name, long retired.
    expect(modelChoice({ ACTIVE_AI_MODEL: "claude-v1" }).model).toBeUndefined();
  });

  it("a reading on the chosen model asks only that model's provider, at its effort", async () => {
    const chart = sampleBazi();
    const claude = new MockProvider();
    const deepseek = new MockProvider();
    const r = await generateReport(
      chart,
      { locale: "zh-Hant", country: "HK" },
      {
        providers: { anthropic: claude, deepseek },
        routing: withModel(loadRouting(), modelInfo("deepseek-v4-pro")!),
        now: FIXED_NOW,
      },
    );
    expect(r.status).toBe("passed");
    expect(claude.calls).toEqual([]);
    expect(deepseek.calls.map((c) => c.agent).sort()).toEqual(["guard", "narrative"]);
    for (const c of deepseek.calls)
      expect([c.model, c.effort]).toEqual(["deepseek-v4-pro", "high"]);
    expect(r.ai_disclosure.model).toBe("mock/deepseek-v4-pro");
  });

  it("a running API follows ACTIVE_AI_MODEL in .env from the next reading, with no restart", async () => {
    const dir = mkdtempSync(join(tmpdir(), "mingli-env-"));
    const file = join(dir, ".env");
    const write = (text: string, at: number) => {
      writeFileSync(file, text);
      utimesSync(file, at, at);
    };
    write("IS_AI_MOCK=TRUE\n", 1_000_000);
    // As scripts/api-server.ts wires it; under the test suite every provider is the mock.
    const ai = watchAi(file, {});
    const providers = buildProviders(ai.mode, ai.choice);
    const api = createApiServer({
      secrets: { digestPepper: PEPPER, drawKey: DRAW_KEY },
      providers: providers.map,
      routing: providers.routing,
      devMode: true,
      preloadRemedies: false,
      log: () => {},
    });
    await new Promise<void>((r) => api.listen(0, "127.0.0.1", r));
    const base = `http://127.0.0.1:${(api.address() as AddressInfo).port}`;
    const h = { "content-type": "application/json", "x-dev-user": "u1", "x-dev-country": "HK" };
    const reading = async () => {
      const chart = await (
        await fetch(base + "/v1/charts", {
          method: "POST",
          headers: h,
          body: JSON.stringify({
            system: "tarot",
            spread: "three_card",
            question: "最近的工作会顺利吗？",
          }),
        })
      ).json();
      const created = await fetch(base + "/v1/reports", {
        method: "POST",
        headers: h,
        body: JSON.stringify({ chart_id: chart.chart_id, locale: "zh-Hans" }),
      });
      expect(created.status).toBe(202);
      const { report_id } = await created.json();
      await api.drain();
      const report = await (await fetch(`${base}/v1/reports/${report_id}`, { headers: h })).json();
      expect(report.status).toBe("passed");
      return report.ai_disclosure.model as string;
    };
    try {
      // Started with no choice: the table's model.
      expect(await reading()).toContain(loadRouting().routes.narrative.default.model);
      write("IS_AI_MOCK=TRUE\nACTIVE_AI_MODEL=claude-haiku-5-5\n", 1_000_100);
      expect(await reading()).toBe("mock/claude-haiku-5-5");
      write("IS_AI_MOCK=TRUE\nACTIVE_AI_MODEL=deepseek-v4-pro\n", 1_000_200);
      expect(await reading()).toBe("mock/deepseek-v4-pro");
    } finally {
      await new Promise<void>((r) => api.close(() => r()));
      rmSync(dir, { recursive: true });
    }
  });
});
