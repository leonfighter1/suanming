import { describe, expect, it } from "vitest";
import {
  AnthropicProvider,
  GeoRefusedError,
  generateReport,
  MockProvider,
  ReportInputError,
  type AnthropicLike,
  type NarrativeOutput,
} from "../src/ai/index.js";
import { computeBazi } from "../src/engines/bazi/index.js";
import { computeTarot } from "../src/engines/tarot/index.js";
import { DRAW_KEY, FIXED_NOW, PEPPER } from "./helpers.js";

const chart = computeBazi(
  {
    local: "1990-03-15T14:30",
    timezone: "Asia/Hong_Kong",
    longitude: 114.17,
    gender: "male",
    options: { liunianFrom: 2026 },
  },
  { digestPepper: PEPPER, now: FIXED_NOW },
);
const deps = (mock: MockProvider) => ({
  providers: { deepseek: mock, anthropic: mock },
  now: FIXED_NOW,
});
const zhHantHK = { locale: "zh-Hant" as const, country: "HK" };

const narrativeWith = (text: string, refs = ["/day_master"]): NarrativeOutput => ({
  sections: [
    {
      topic: "personality",
      paragraphs: [{ text, source_level: "traditional_text", fact_refs: refs }],
    },
  ],
});

describe("generateReport — happy path", () => {
  it("passes with four layers, deterministic facts and AI disclosure", async () => {
    const mock = new MockProvider();
    const r = await generateReport(chart, zhHantHK, deps(mock));
    expect(r.status).toBe("passed");
    expect(r.topics).toEqual([
      "wuxing",
      "personality",
      "career_wealth",
      "relationships",
      "dayun_liunian",
      "health",
    ]);
    expect(r.layers!.facts[0]).toBe("四柱：庚午 己卯 己卯 辛未");
    expect(r.layers!.facts).toContain("流年 2026 丙午：正印 / 偏印；與時支六合");
    expect(r.layers!.interpretation.map((s) => s.topic)).toEqual(r.topics);
    expect(r.layers!.actions.length).toBeGreaterThan(0);
    expect(r.layers!.expectation.label_required).toBe(false); // HK: recommended
    expect(r.ai_disclosure.prompt_version).toBe("narrative@1,action@1,guard@1");
    expect(r.ai_disclosure.model).toContain("deepseek-v4-pro");
    expect(mock.calls.map((c) => c.agent)).toEqual(["narrative", "action", "guard"]);
  });

  it("requires the visible AI label for EU users", async () => {
    const r = await generateReport(
      chart,
      { locale: "en", country: "DE" },
      deps(new MockProvider()),
    );
    expect(r.status).toBe("passed");
    expect(r.layers!.expectation.label_required).toBe(true);
    expect(r.layers!.facts[0]).toBe("Four Pillars: 庚午 己卯 己卯 辛未");
  });

  it("never sends the exact birth time to the model", async () => {
    const mock = new MockProvider();
    await generateReport(chart, zhHantHK, deps(mock));
    for (const c of mock.calls) {
      expect(c.user).not.toContain("1990-03-15T14:30");
      expect(c.user).not.toContain("time_basis");
    }
  });

  it("forces protected terms into the locale's form", async () => {
    const mock = new MockProvider({
      narrative: [{ kind: "ok", data: narrativeWith("月柱為劫财，傳統上認為重視同伴。") }],
    });
    const r = await generateReport(chart, { ...zhHantHK, topics: ["personality"] }, deps(mock));
    expect(r.layers!.interpretation[0]!.paragraphs[0]!.text).toBe(
      "月柱為劫財，傳統上認為重視同伴。",
    );
    expect(r.compliance.term_fixes).toContain("劫财→劫財");
  });
});

describe("generateReport — compliance outcomes", () => {
  it("retries once with rule feedback, then passes", async () => {
    const mock = new MockProvider({
      narrative: [{ kind: "ok", data: narrativeWith("你注定會失去這段感情。") }],
    });
    const r = await generateReport(chart, { ...zhHantHK, topics: ["personality"] }, deps(mock));
    expect(r.status).toBe("passed");
    expect(r.agents[0]!.attempts).toBe(2);
    expect(mock.calls[1]!.user).toContain("G003");
  });

  it("blocks when the rule layer is still violated after retries", async () => {
    const bad = { kind: "ok" as const, data: narrativeWith("不轉運的話，下半年就會出事。") };
    const mock = new MockProvider({ narrative: [bad, bad] });
    const r = await generateReport(
      chart,
      { ...zhHantHK, topics: ["personality"], includeDraft: true },
      deps(mock),
    );
    expect(r.status).toBe("blocked");
    expect(r.layers).toBeUndefined();
    expect(r.compliance.rule_violations.map((v) => v.rule_id)).toContain("G001");
    expect(r.draft!.interpretation).toBeDefined();
    expect(mock.calls.map((c) => c.agent)).toEqual(["narrative", "narrative"]); // no action/guard calls
  });

  it("sends review-level patterns (investment advice) to manual review", async () => {
    const mock = new MockProvider({
      action: [
        {
          kind: "ok",
          data: {
            actions: [
              { topic: "career_wealth", text: "建議下月買入科技股。", horizon: "this_month" },
            ],
          },
        },
      ],
    });
    const r = await generateReport(chart, { ...zhHantHK, topics: ["career_wealth"] }, deps(mock));
    expect(r.status).toBe("manual_review");
    expect(r.compliance.rule_violations.map((v) => v.rule_id)).toContain("G007");
  });

  it("sends a failed model review to manual review", async () => {
    const mock = new MockProvider({
      guard: [
        {
          kind: "ok",
          data: { pass: false, violations: [{ quote: "x", category: "medical", reason: "y" }] },
        },
      ],
    });
    const r = await generateReport(chart, zhHantHK, deps(mock));
    expect(r.status).toBe("manual_review");
    expect(r.compliance.review!.pass).toBe(false);
    expect(r.layers).toBeUndefined();
  });

  it("treats a refusal as manual review", async () => {
    const mock = new MockProvider({
      narrative: [
        {
          kind: "refusal",
          model: "m",
          category: null,
          usage: { input_tokens: 1, output_tokens: 0 },
        },
      ],
    });
    const r = await generateReport(chart, zhHantHK, deps(mock));
    expect(r.status).toBe("manual_review");
    expect(r.reasons[0]).toMatch(/refusal/);
  });

  it("drops paragraphs whose fact_refs don't exist, after one retry", async () => {
    const ungrounded = {
      kind: "ok" as const,
      data: narrativeWith("憑空說法。", ["/no_such_fact"]),
    };
    const mock = new MockProvider({ narrative: [ungrounded, ungrounded] });
    const r = await generateReport(chart, { ...zhHantHK, topics: ["personality"] }, deps(mock));
    expect(r.status).toBe("manual_review");
    expect(r.reasons).toContain("narrative: no grounded paragraphs");
  });

  it("retries on schema-invalid output", async () => {
    const mock = new MockProvider({ narrative: [{ kind: "ok", data: { sections: "nope" } }] });
    const r = await generateReport(chart, { ...zhHantHK, topics: ["wuxing"] }, deps(mock));
    expect(r.status).toBe("passed");
    expect(r.agents[0]!.attempts).toBe(2);
  });
});

describe("generateReport — input and Geo-Rule", () => {
  it("refuses unserved regions before any model call", async () => {
    const mock = new MockProvider();
    await expect(
      generateReport(chart, { locale: "zh-Hans", country: "CN" }, deps(mock)),
    ).rejects.toBeInstanceOf(GeoRefusedError);
    await expect(
      generateReport(chart, { locale: "en", country: "ZZ" }, deps(mock)),
    ).rejects.toBeInstanceOf(GeoRefusedError);
    expect(mock.calls).toHaveLength(0);
  });

  it("rejects bazi-only topics for tarot", async () => {
    const tarot = computeTarot(
      { spread: "three_card" },
      { drawKey: DRAW_KEY, digestPepper: PEPPER },
    );
    await expect(
      generateReport(tarot, { ...zhHantHK, topics: ["wuxing"] }, deps(new MockProvider())),
    ).rejects.toBeInstanceOf(ReportInputError);
    const r = await generateReport(tarot, zhHantHK, deps(new MockProvider()));
    expect(r.status).toBe("passed");
    expect(r.layers!.facts[0]).toMatch(/^過去: /);
  });
});

describe("AnthropicProvider", () => {
  function fakeClient(response: unknown) {
    const seen: unknown[] = [];
    const client = {
      beta: { messages: { create: async (params: unknown) => (seen.push(params), response) } },
    } as unknown as AnthropicLike;
    return { client, seen };
  }
  const req = {
    agent: "narrative" as const,
    model: "claude-opus-5-5",
    effort: "high" as const,
    maxTokens: 16000,
    system: "SYS",
    user: "USER",
    schema: { type: "object" },
    payload: {},
  };
  const usage = { input_tokens: 10, output_tokens: 5, cache_read_input_tokens: 0 };

  it("sends structured-output, fallback and caching params; no prefill or sampling params", async () => {
    const { client, seen } = fakeClient({
      model: "claude-opus-5-5",
      stop_reason: "end_turn",
      content: [{ type: "text", text: '{"ok":true}' }],
      usage,
    });
    const r = await new AnthropicProvider(client).generateJson(req);
    expect(r).toMatchObject({ kind: "ok", data: { ok: true }, model: "claude-opus-5-5" });
    const p = seen[0] as Record<string, unknown>;
    expect(p).toMatchObject({
      model: "claude-opus-5-5",
      max_tokens: 16000,
      betas: ["server-side-fallback-2026-07-01"],
      fallbacks: "default",
      output_config: {
        effort: "high",
        format: { type: "json_schema", schema: { type: "object" } },
      },
      system: [{ type: "text", text: "SYS", cache_control: { type: "ephemeral" } }],
      messages: [{ role: "user", content: "USER" }],
    });
    for (const k of ["temperature", "top_p", "top_k", "thinking"]) expect(p).not.toHaveProperty(k);
  });

  it("maps refusal and truncation", async () => {
    const refused = fakeClient({
      model: "m",
      stop_reason: "refusal",
      stop_details: { category: "cyber" },
      content: [],
      usage,
    });
    expect(await new AnthropicProvider(refused.client).generateJson(req)).toMatchObject({
      kind: "refusal",
      category: "cyber",
    });
    const cut = fakeClient({
      model: "m",
      stop_reason: "max_tokens",
      content: [{ type: "text", text: "{" }],
      usage,
    });
    expect(await new AnthropicProvider(cut.client).generateJson(req)).toMatchObject({
      kind: "invalid",
    });
  });
});

it("every 纳音 and 十神/十二长生 name the engine can emit is in the protected-term table", async () => {
  const { default: lunar } = await import("lunar-javascript");
  const { loadTerms } = await import("../src/ai/index.js");
  const terms = loadTerms().terms;
  const nayin = [...new Set(Object.values(lunar.LunarUtil.NAYIN as Record<string, string>))].filter(
    (n) => !n.startsWith("{"),
  );
  expect(nayin).toHaveLength(30);
  const tenGods = ["比肩", "劫财", "食神", "伤官", "偏财", "正财", "七杀", "正官", "偏印", "正印"];
  const stages = ["长生", "沐浴", "冠带", "临官", "帝旺", "绝", "养"];
  expect([...nayin, ...tenGods, ...stages].filter((k) => !terms[k])).toEqual([]);
});
