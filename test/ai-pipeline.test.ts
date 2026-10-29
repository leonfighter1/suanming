import { describe, expect, it } from "vitest";
import Anthropic from "@anthropic-ai/sdk";
import {
  AnthropicProvider,
  CONCLUSION_PARTS,
  GeoRefusedError,
  generateReport,
  loadRouting,
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
    // 八字 since v9.3.0: a 总结 in its nine parts, in order, and no 行动建议.
    expect(Object.keys(r.layers!.conclusion!)).toEqual([...CONCLUSION_PARTS]);
    expect(r.layers!.actions).toEqual([]);
    expect(r.layers!.expectation.label_required).toBe(false); // HK: recommended
    expect(r.ai_disclosure.prompt_version).toBe("narrative_bazi@9,guard@2");
    // The routed model, as the mock reports it (mock/<model>); which model ships is pinned in ai-models.test.ts.
    expect(r.ai_disclosure.model).toContain(loadRouting().routes.narrative.default.model);
    // No trend agent: the engine scores the trend chart (v2.0.0). No action agent for 八字 (v9.3.0).
    expect(mock.calls.map((c) => c.agent).sort()).toEqual(["guard", "narrative"]);
    const trend = r.layers!.trend!;
    expect(trend.dayun.map((d) => d.index)).toEqual([1, 2, 3, 4, 5, 6, 7, 8]);
    expect(trend.liunian).toHaveLength(10);
    for (const p of [...trend.dayun, ...trend.liunian]) {
      const vals = r.topics.map((t) => p.scores[t]!);
      expect(vals.every((v) => v >= 0 && v <= 100)).toBe(true);
      expect(p.overall).toBe(Math.round(vals.reduce((a, b) => a + b, 0) / vals.length));
    }
    expect(trend.total).toBe(
      Math.round(trend.dayun.reduce((a, d) => a + d.overall, 0) / trend.dayun.length),
    );
    expect(trend.dayun[0]).toMatchObject({ ganzhi: "庚辰", start_age: 8, end_age: 17 });
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
    expect(mock.calls.filter((c) => c.agent === "narrative")[1]!.user).toContain("G003");
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
    expect(mock.calls.map((c) => c.agent).filter((a) => a !== "trend")).toEqual([
      "narrative",
      "narrative",
    ]); // no action/guard calls
  });

  it("sends review-level patterns (investment advice) to manual review: in a 八字 总结, and in actions", async () => {
    // 八字 writes no 行动建议 since v9.3.0: what it advises is in its 总结, scanned like every paragraph.
    const bazi = new MockProvider({
      narrative: [
        {
          kind: "ok",
          data: {
            ...narrativeWith("月柱為劫财，傳統上認為重視同伴。"),
            conclusion: Object.fromEntries(
              CONCLUSION_PARTS.map((p) => [
                p,
                {
                  text: p === "coping" ? "建議下月買入科技股。" : "整體平穩，按自己的節奏來。",
                  fact_refs: ["/day_master"],
                },
              ]),
            ),
          },
        },
      ],
    });
    const r = await generateReport(chart, { ...zhHantHK, topics: ["personality"] }, deps(bazi));
    expect(r.status).toBe("manual_review");
    expect(r.compliance.rule_violations.map((v) => v.rule_id)).toContain("G007");
    expect(r.held_layers!.conclusion!.coping!.text).toBe("建議下月買入科技股。");

    // A method with 行动建议 (塔罗): its actions are scanned too.
    const tarot = computeTarot(
      { spread: "three_card" },
      { drawKey: DRAW_KEY, digestPepper: PEPPER },
    );
    const withActions = new MockProvider({
      action: [
        {
          kind: "ok",
          data: {
            actions: [
              { topic: "tarot_advice", text: "建議下月買入科技股。", horizon: "this_month" },
            ],
          },
        },
      ],
    });
    const t = await generateReport(tarot, zhHantHK, deps(withActions));
    expect(t.status).toBe("manual_review");
    expect(t.compliance.rule_violations.map((v) => v.rule_id)).toContain("G007");
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
    // Facts are numbered in dealing order (v1.2.0), as a classic reading follows them.
    expect(r.layers!.facts[0]).toMatch(/^1\. 過去: /);
  });
});

describe("AnthropicProvider", () => {
  /** A client that answers stream() with `response` and records what it was sent. It has no create(). */
  function fakeClient(response: unknown) {
    const seen: unknown[] = [];
    const client = {
      beta: {
        messages: {
          stream: (params: unknown) => (seen.push(params), { finalMessage: async () => response }),
        },
      },
    } as unknown as AnthropicLike;
    return { client, seen };
  }
  const req = {
    agent: "narrative" as const,
    model: "claude-opus-5-5",
    effort: "medium" as const,
    maxTokens: 64000,
    system: "SYS",
    user: "USER",
    schema: { type: "object" },
    payload: {},
  };
  const usage = {
    input_tokens: 10,
    output_tokens: 5,
    cache_read_input_tokens: 0,
    cache_creation_input_tokens: 0,
  };

  it("streams structured-output, fallback and caching params; no prefill, sampling or thinking params", async () => {
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
      max_tokens: 64000,
      betas: ["server-side-fallback-2026-07-01"],
      fallbacks: "default",
      output_config: {
        effort: "medium",
        format: { type: "json_schema", schema: { type: "object" } },
      },
      system: [{ type: "text", text: "SYS", cache_control: { type: "ephemeral" } }],
      messages: [{ role: "user", content: "USER" }],
    });
    // Thinking is the model's own: adaptive, and Claude Opus 5.5 can't turn it off.
    for (const k of ["temperature", "top_p", "top_k", "thinking"]) expect(p).not.toHaveProperty(k);
  });

  it("leaves the fallback out for Claude Haiku 5.5, which has none, and for a model not in the list", async () => {
    for (const model of ["claude-haiku-5-5", "claude-opus-4-8"]) {
      const { client, seen } = fakeClient({
        model,
        stop_reason: "end_turn",
        content: [{ type: "text", text: "{}" }],
        usage,
      });
      expect(await new AnthropicProvider(client).generateJson({ ...req, model })).toMatchObject({
        kind: "ok",
        model,
      });
      expect(seen[0]).toMatchObject({ model, output_config: { effort: "medium" } });
      expect(seen[0]).not.toHaveProperty("fallbacks");
      expect(seen[0]).not.toHaveProperty("betas");
    }
  });

  it("reads the answer by block type, after a thinking block, and keeps cache reads and writes", async () => {
    const counted = {
      input_tokens: 40,
      output_tokens: 900,
      cache_read_input_tokens: 3000,
      cache_creation_input_tokens: 1200,
    };
    const { client } = fakeClient({
      model: "claude-opus-5-5",
      stop_reason: "end_turn",
      content: [
        { type: "thinking", thinking: "", signature: "sig" },
        { type: "text", text: '{"a":' },
        { type: "text", text: "1}" },
      ],
      usage: counted,
    });
    expect(await new AnthropicProvider(client).generateJson(req)).toEqual({
      kind: "ok",
      data: { a: 1 },
      model: "claude-opus-5-5",
      usage: counted,
    });
  });

  it("goes through the real SDK as a stream, so a 64,000-token route is sent at all", async () => {
    // What a streamed answer arrives as: a thinking block first (empty, as Claude Opus 5.5 returns it), then the JSON.
    const events: [string, unknown][] = [
      [
        "message_start",
        {
          type: "message_start",
          message: {
            id: "msg_1",
            type: "message",
            role: "assistant",
            model: "claude-opus-5-5",
            content: [],
            stop_reason: null,
            stop_sequence: null,
            usage: {
              input_tokens: 120,
              output_tokens: 1,
              cache_read_input_tokens: 2500,
              cache_creation_input_tokens: 0,
            },
          },
        },
      ],
      [
        "content_block_start",
        {
          type: "content_block_start",
          index: 0,
          content_block: { type: "thinking", thinking: "", signature: "" },
        },
      ],
      [
        "content_block_delta",
        {
          type: "content_block_delta",
          index: 0,
          delta: { type: "signature_delta", signature: "sig" },
        },
      ],
      ["content_block_stop", { type: "content_block_stop", index: 0 }],
      [
        "content_block_start",
        { type: "content_block_start", index: 1, content_block: { type: "text", text: "" } },
      ],
      [
        "content_block_delta",
        { type: "content_block_delta", index: 1, delta: { type: "text_delta", text: '{"ok":' } },
      ],
      [
        "content_block_delta",
        { type: "content_block_delta", index: 1, delta: { type: "text_delta", text: "true}" } },
      ],
      ["content_block_stop", { type: "content_block_stop", index: 1 }],
      [
        "message_delta",
        {
          type: "message_delta",
          delta: { stop_reason: "end_turn", stop_sequence: null },
          usage: { output_tokens: 640 },
        },
      ],
      ["message_stop", { type: "message_stop" }],
    ];
    const sse = events
      .map(([event, data]) => `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`)
      .join("");
    const sent: { url: string; headers: Headers; body: Record<string, unknown> }[] = [];
    const fetch = async (url: string | URL | Request, init?: RequestInit) => {
      sent.push({
        url: String(url),
        headers: new Headers(init?.headers),
        body: JSON.parse(String(init?.body)) as Record<string, unknown>,
      });
      return new Response(sse, { status: 200, headers: { "content-type": "text/event-stream" } });
    };
    const client = new Anthropic({ apiKey: "sk-ant-test", fetch, maxRetries: 0 });

    expect(await new AnthropicProvider(client).generateJson(req)).toEqual({
      kind: "ok",
      data: { ok: true },
      model: "claude-opus-5-5",
      // output_tokens from message_delta (640), the rest from message_start.
      usage: {
        input_tokens: 120,
        output_tokens: 640,
        cache_read_input_tokens: 2500,
        cache_creation_input_tokens: 0,
      },
    });
    expect(sent).toHaveLength(1);
    expect(sent[0]!.url).toMatch(/\/v1\/messages\?beta=true$/);
    expect(sent[0]!.headers.get("anthropic-beta")).toBe("server-side-fallback-2026-07-01");
    expect(sent[0]!.body).toMatchObject({
      stream: true,
      model: "claude-opus-5-5",
      max_tokens: 64000,
      fallbacks: "default",
      output_config: { effort: "medium", format: { type: "json_schema" } },
    });
    expect(sent[0]!.body).not.toHaveProperty("betas"); // a header, not a body field
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
  // All twelve since v3.2.0: 衰 病 死 墓 胎 read the same in both scripts but need an English name.
  const stages = ["长生", "沐浴", "冠带", "临官", "帝旺", "衰", "病", "死", "墓", "绝", "胎", "养"];
  expect([...nayin, ...tenGods, ...stages].filter((k) => !terms[k])).toEqual([]);
});

it("facts layer shows the 農曆 date in the reader's script", async () => {
  const { factsLayer } = await import("../src/ai/index.js");
  expect(factsLayer(chart, "zh-Hant", 2026)[1]).toBe("農曆：庚午年二月十九（生肖馬）");
  expect(factsLayer(chart, "zh-Hans", 2026)[1]).toBe("农历：庚午年二月十九（生肖马）");
  expect(factsLayer(chart, "en", 2026)[1]).toBe("Lunar date: month 2, day 19, 庚午 year (Horse)");
});

it("facts layer shows the engine's 旺衰 and 喜用 as the 命盘 page does (v2.1.0)", async () => {
  const { factsLayer } = await import("../src/ai/index.js");
  // 庚午 己卯 己卯 辛未 (test/bazi-strength.test.ts): 26.8 support points → 身弱; 卯 month is 木 →
  // 不得令; 喜用 = 印 火, 比劫 土; 忌 = 食伤 金, 财 水, 官杀 木.
  expect(factsLayer(chart, "zh-Hans", 2026)).toContain(
    "日主旺衰（简化扶抑）：身弱；不得令；喜用：火、土；忌：金、水、木",
  );
  expect(factsLayer(chart, "zh-Hant", 2026)).toContain(
    "日主旺衰（簡化扶抑）：身弱；不得令；喜用：火、土；忌：金、水、木",
  );
  expect(factsLayer(chart, "en", 2026)).toContain(
    "Day Master strength (simplified): Weak Day Master (Shen Ruo); not in season; favourable: Fire, Earth; unfavourable: Metal, Water, Wood",
  );
});

it("facts layer and narrative prompt carry the 農曆 / 時辰 input basis to the AI", async () => {
  const { factsLayer, MockProvider: M, generateReport: gen } = await import("../src/ai/index.js");
  const shichenChart = computeBazi(
    {
      local: "1990-03-15T14:00",
      timezone: "Asia/Hong_Kong",
      longitude: 114.17,
      gender: "male",
      options: { liunianFrom: 2026, inputBasis: { date: "lunar", time: "shichen", shichen: "未" } },
    },
    { digestPepper: PEPPER, now: FIXED_NOW },
  );
  const lines = factsLayer(shichenChart, "zh-Hant", 2026);
  expect(lines).toContain("出生日期：依農曆輸入");
  expect(lines).toContain("出生時間：依時辰輸入（未時），時柱只精確到兩小時");
  const mock = new M();
  await gen(
    shichenChart,
    { locale: "zh-Hant", country: "HK", topics: ["personality"] },
    { providers: { deepseek: mock, anthropic: mock }, now: FIXED_NOW },
  );
  const narrative = mock.calls.find((c) => c.agent === "narrative")!;
  expect(narrative.system).toContain("input_basis");
  expect(narrative.user).toContain('"time": "shichen"');
  expect(narrative.user).toContain('"shichen": "未"');
});
