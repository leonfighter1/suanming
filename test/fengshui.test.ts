// 风水 (tech plan WP6.3, the owner's Phase 3 spec): general principles of direction and space, never a 吉凶
// judgement of a home, every one a simplified_rule; its own rule group; Malaysia gives it more weight.
import OpenCC from "opencc-js";
import { describe, expect, it } from "vitest";
import { generateReport, MockProvider } from "../src/ai/index.js";
import { validateChartFact } from "../src/chart-fact/index.js";
import {
  compileRules,
  loadGeoMatrix,
  loadRuleSet,
  methodsFor,
  resolveRegion,
  scan,
} from "../src/compliance/index.js";
import { computeFengshui, type FengshuiFacts } from "../src/engines/fengshui/index.js";
import { DIRECTIONS, FACINGS, ROOM_IDS, ROOMS } from "../src/engines/fengshui/principles.js";
import { computeTarot } from "../src/engines/tarot/index.js";
import { DRAW_KEY, FIXED_NOW, PEPPER } from "./helpers.js";
import { testApi } from "./api.js";

const all = ROOM_IDS.flatMap((r) => ROOMS[r].principles.map((p) => ({ room: r, ...p })));
const texts = all.flatMap((p) => [p.text, p.why]);

describe("the principles", () => {
  it("give every room at least three, with unique ids and no empty text in any language", () => {
    for (const r of ROOM_IDS) expect(ROOMS[r].principles.length, r).toBeGreaterThanOrEqual(3);
    expect(new Set(all.map((p) => p.id)).size).toBe(all.length);
    for (const t of texts) {
      for (const l of ["zh-Hant", "zh-Hans", "en"] as const) expect(t[l].trim()).not.toBe("");
    }
  });

  it("are written in 简体 as OpenCC writes them, apart from mainland words and quotes (G18, rule 31)", () => {
    const toHans = OpenCC.Converter({ from: "tw", to: "cn" });
    // Kept apart on purpose: mainland wording and 简体 quotes.
    const MAINLAND: [string, string][] = [
      ["萤幕", "屏幕"],
      ["「", "“"],
      ["」", "”"],
    ];
    for (const t of [...texts, ...ROOM_IDS.map((r) => ROOMS[r].name)]) {
      const converted = MAINLAND.reduce((s, [a, b]) => s.split(a).join(b), toHans(t["zh-Hant"]));
      expect(t["zh-Hans"], t["zh-Hant"]).toBe(converted);
    }
  });

  it("judge nothing: no 吉 or 凶, and no phrase the 风水 rule group holds", () => {
    const rules = compileRules(loadRuleSet(), ["fengshui"]);
    for (const t of texts) {
      for (const l of ["zh-Hant", "zh-Hans"] as const) {
        expect(t[l], t[l]).not.toMatch(/[吉凶煞]/);
        expect(scan(t[l], rules)).toEqual([]);
      }
      expect(t.en).not.toMatch(/\b(lucky|unlucky|bad luck|good luck|fortune)\b/i);
    }
  });

  it("place each facing's trigram and 五行 as the 後天八卦 does", () => {
    // 後天八卦 (文王八卦): 離 south, 坎 north, 震 east, 兌 west, 乾 northwest, 坤 southwest, 艮 northeast,
    // 巽 southeast; 五行 坎水, 艮坤土, 震巽木, 離火, 兌乾金.
    const want = {
      north: ["坎", "水"],
      northeast: ["艮", "土"],
      east: ["震", "木"],
      southeast: ["巽", "木"],
      south: ["離", "火"],
      southwest: ["坤", "土"],
      west: ["兌", "金"],
      northwest: ["乾", "金"],
    };
    expect(Object.keys(DIRECTIONS)).toEqual([...FACINGS]);
    for (const f of FACINGS) {
      expect([DIRECTIONS[f].trigram["zh-Hant"], DIRECTIONS[f].element["zh-Hant"]], f).toEqual(
        want[f],
      );
    }
  });
});

describe("the engine", () => {
  it("gives a schema-valid chart of the room's principles, every fact a simplified_rule", () => {
    for (const room of ROOM_IDS) {
      for (const facing of [undefined, ...FACINGS]) {
        const chart = computeFengshui(
          { room, ...(facing && { facing }) },
          { digestPepper: PEPPER, now: FIXED_NOW },
        );
        expect(validateChartFact(chart)).toEqual({ ok: true });
        const f = chart.facts as unknown as FengshuiFacts;
        expect(f.principles.map((p) => p.id)).toEqual(ROOMS[room].principles.map((p) => p.id));
        expect(f.facing).toBe(facing);
        expect(f.direction === undefined).toBe(facing === undefined);
        expect(chart.provenance.every((p) => p.source_level === "simplified_rule")).toBe(true);
      }
    }
    // The same room and facing, the same facts.
    const again = () =>
      computeFengshui({ room: "study", facing: "south" }, { digestPepper: PEPPER, now: FIXED_NOW });
    expect(again()).toEqual(again());
    expect((again().facts as unknown as FengshuiFacts).direction).toEqual({
      trigram: "li",
      element: "fire",
    });
  });
});

describe("a 风水 reading", () => {
  const providers = (m: MockProvider) => ({ deepseek: m, anthropic: m });
  const chart = computeFengshui(
    { room: "bedroom", facing: "east" },
    { digestPepper: PEPPER, now: FIXED_NOW },
  );
  const DESCRIPTION = "床在窗下，門在床的左邊。";

  it("reads the room with its own prompts and the description, every paragraph a simplified_rule", async () => {
    const mock = new MockProvider();
    const report = await generateReport(
      chart,
      { locale: "zh-Hant", country: "MY", question: DESCRIPTION },
      { providers: providers(mock), now: FIXED_NOW },
    );
    expect(report.status).toBe("passed");
    expect(report.topics).toEqual(["fengshui_layout", "fengshui_flow", "fengshui_advice"]);
    expect(report.ai_disclosure.prompt_version).toBe(
      "narrative_fengshui@3,action_fengshui@1,guard@2",
    );
    const narrative = mock.calls.find((c) => c.agent === "narrative")!;
    expect(narrative.user).toContain(`<user_description>\n${DESCRIPTION}`);
    expect(narrative.user).toContain(ROOMS.bedroom.principles[0]!.text["zh-Hant"]);
    // The mock answers traditional_text; 风水 keeps to simplified rules all the same.
    const levels = report.layers!.interpretation.flatMap((s) =>
      s.paragraphs.map((p) => p.source_level),
    );
    expect(levels.length).toBeGreaterThan(0);
    expect(new Set(levels)).toEqual(new Set(["simplified_rule"]));
    expect(report.layers!.facts[0]).toBe("臥室 · 東 · 震 · 木");
    expect(report.layers!.expectation.ai_label).toContain("不是住宅吉凶的判斷");
    expect(report.layers!.actions.every((a) => a.topic === "fengshui_advice")).toBe(true);
  });

  it("holds 吉凶 phrasing about a home in a 风水 reading, and only there (rule 8)", async () => {
    const bad = (topics: string[]) => ({
      sections: topics.map((topic) => ({
        topic,
        summary: "（示範）重點。",
        paragraphs: [
          {
            text: "床正對房門會犯煞。",
            source_level: "traditional_text",
            fact_refs: topic.startsWith("tarot") ? ["/cards/0"] : ["/principles/0"],
          },
        ],
      })),
    });
    const fengshui = await generateReport(
      chart,
      { locale: "zh-Hant", country: "HK" },
      {
        providers: providers(
          new MockProvider({
            narrative: [
              { kind: "ok", data: bad(["fengshui_layout", "fengshui_flow", "fengshui_advice"]) },
              { kind: "ok", data: bad(["fengshui_layout", "fengshui_flow", "fengshui_advice"]) },
            ],
          }),
        ),
        now: FIXED_NOW,
      },
    );
    expect(fengshui.status).toBe("blocked");
    expect(fengshui.compliance.rule_violations.map((v) => v.rule_id)).toContain("F001");

    const tarotChart = computeTarot(
      { spread: "three_card" },
      { drawKey: DRAW_KEY, digestPepper: PEPPER, now: FIXED_NOW, newDrawId: () => "draw-1" },
    );
    const tarot = await generateReport(
      tarotChart,
      { locale: "zh-Hant", country: "HK" },
      {
        providers: providers(
          new MockProvider({
            narrative: [
              { kind: "ok", data: bad(["tarot_cards", "tarot_synthesis", "tarot_advice"]) },
            ],
          }),
        ),
        now: FIXED_NOW,
      },
    );
    expect(tarot.compliance.rule_violations.map((v) => v.rule_id)).not.toContain("F001");
  });
});

describe("the entry order and the API", () => {
  it("leads with 风水 in Malaysia (§2.4) and keeps the default order elsewhere", () => {
    // 起名 is left out: it is off until the owner's review, and naming.test.ts covers its switch.
    const order = (cc: string) =>
      methodsFor(resolveRegion(loadGeoMatrix(), cc)!)
        .map((m) => m.system)
        .filter((s) => s !== "naming");
    // MY: fengshui 1.3 > every other 1 (ties keep bazi, tarot, qiuqian, liuyao, fengshui, astrology).
    expect(order("MY")).toEqual(["fengshui", "bazi", "tarot", "qiuqian", "liuyao", "astrology"]);
    expect(order("SG")).toEqual(["bazi", "tarot", "qiuqian", "liuyao", "fengshui", "astrology"]);
  });

  let base = "";
  const api = testApi(
    {
      providers: { deepseek: new MockProvider(), anthropic: new MockProvider() },
    },
    (b) => (base = b),
  );
  const post = (path: string, body: unknown) =>
    fetch(base + path, {
      method: "POST",
      headers: { "content-type": "application/json", "x-dev-country": "MY", "x-dev-user": "f1" },
      body: JSON.stringify(body),
    });

  it("looks a room up, refuses an unknown one, and reads it with no plan", async () => {
    const res = await post("/v1/charts", { system: "fengshui", room: "kitchen", facing: "west" });
    expect(res.status).toBe(201);
    const chart = await res.json();
    expect(chart.chart_fact.facts.room).toBe("kitchen");
    expect((await post("/v1/charts", { system: "fengshui", room: "garage" })).status).toBe(400);
    expect(
      (await post("/v1/charts", { system: "fengshui", room: "kitchen", facing: "up" })).status,
    ).toBe(400);
    const report = await (
      await post("/v1/reports", { chart_id: chart.chart_id, locale: "zh-Hans" })
    ).json();
    await api.drain();
    const plan = await post(`/v1/reports/${report.report_id}/remedies`, {
      topic: "fengshui_advice",
    });
    expect(plan.status).toBe(400);
  });
});
