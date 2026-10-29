// 算卦 (tech plan WP10.3): the reading, its checks, and the API. Mock provider only. The cast is 天雷無妄 with
// 六二 moving (lines 7 6 8 7 7 7, 初爻 first), turning into 天澤履: one moving line, so the reading rests on 六二.
import type { AddressInfo } from "node:net";
import { describe, expect, it } from "vitest";
import {
  checkFaithfulness,
  generateReport,
  MockProvider,
  ReportInputError,
  type Report,
} from "../src/ai/index.js";
import { lineName } from "../src/ai/liuyao.js";
import { createApiServer } from "../src/api/server.js";
import { computeLiuyao, type LineValue } from "../src/engines/liuyao/index.js";
import { plainOf } from "../src/engines/liuyao/plain.js";
import { zhouyiText } from "../src/engines/yijing/index.js";
import { DRAW_KEY, FIXED_NOW, PEPPER } from "./helpers.js";

const chart = computeLiuyao(
  {
    mode: "manual",
    timezone: "Asia/Hong_Kong",
    local: "2026-10-24T21:05",
    lines: ([7, 6, 8, 7, 7, 7] as LineValue[]).map((value) => ({ value })),
  },
  { drawKey: DRAW_KEY, digestPepper: PEPPER, now: FIXED_NOW },
);
const read = (mock: MockProvider, locale: "zh-Hant" | "zh-Hans" | "en" = "zh-Hant") =>
  generateReport(
    chart,
    { locale, country: "HK", question: "要不要換工作？" },
    { providers: { deepseek: mock, anthropic: mock }, now: FIXED_NOW },
  );
const liuer = zhouyiText("100111").yao_ci[1]!;

describe("the lines' names", () => {
  it("are 初九 … 上六, with 用九 and 用六", () => {
    expect([lineName(1, true), lineName(2, false), lineName(5, true), lineName(6, false)]).toEqual([
      "初九",
      "六二",
      "九五",
      "上六",
    ]);
    expect([lineName(7, true), lineName(7, false)]).toEqual(["用九", "用六"]);
  });
});

describe("a 算卦 reading", () => {
  it("reads the cast with its own prompts: the focus text with its 直說, no coins, actions on the advice", async () => {
    const mock = new MockProvider();
    const report = await read(mock);
    expect(report.status).toBe("passed");
    expect(report.topics).toEqual(["liuyao_hexagram", "liuyao_answer", "liuyao_advice"]);
    expect(report.ai_disclosure.prompt_version).toBe("narrative_liuyao@3,action_liuyao@1,guard@2");
    const narrative = mock.calls.find((c) => c.agent === "narrative")!;
    expect(narrative.user).toContain(liuer["zh-Hant"]);
    expect(narrative.user).toContain(plainOf("100111", 2)["zh-Hant"]);
    expect(narrative.user).toContain('"name": "六二"');
    const factsTag = /<chart_facts>\n([\s\S]*?)\n<\/chart_facts>/.exec(narrative.user)![1]!;
    expect(Object.keys(JSON.parse(factsTag)).sort()).toEqual(
      ["cast", "changed", "focus", "lines", "mode", "primary"].sort(),
    );
    expect(report.layers!.facts[0]).toBe("天雷無妄 → 天澤履 · 六二");
    expect(report.layers!.facts[1]).toBe(liuer["zh-Hant"]);
    expect(report.layers!.expectation.ai_label).toContain("卦象只指出傾向");
    expect(report.layers!.actions.every((a) => a.topic === "liuyao_advice")).toBe(true);
    // 简体 readers get 简体 texts.
    const hans = new MockProvider();
    await read(hans, "zh-Hans");
    expect(hans.calls.find((c) => c.agent === "narrative")!.user).toContain(liuer["zh-Hans"]);
  });

  it("is read in Chinese only (the owner removed English support)", async () => {
    await expect(read(new MockProvider(), "en")).rejects.toThrow(ReportInputError);
  });

  it("names only its own hexagrams, quotes no other's text, and names only the cast's 干支", async () => {
    const report = await read(new MockProvider());
    const withText = (text: string): Report => ({
      ...report,
      layers: {
        ...report.layers!,
        interpretation: [
          {
            topic: "liuyao_hexagram",
            summary: "重點。",
            paragraphs: [{ text, source_level: "traditional_text", fact_refs: ["/focus/texts/0"] }],
          },
        ],
        actions: [],
      },
    });
    const kinds = (text: string) => checkFaithfulness(chart, withText(text)).map((i) => i.kind);
    // Its own: 天雷無妄, 天澤履, a phrase of 無妄's 卦辭, the day it was cast on (2026-10-28 is 乙亥, 11 in the
    // 甲子 cycle; four days before, 7, is 辛未), the user's own words in quotes, and a three-character phrase.
    expect(chart.facts.cast).toMatchObject({ ganzhi: { day: "辛未" } });
    expect(
      kinds("天雷無妄變天澤履，「其匪正有眚」，辛未日起卦。你問「要不要換工作」，「不耕穫」。"),
    ).toEqual([]);
    // Another hexagram's name, a phrase only other hexagrams have, a 干支 that isn't the cast's.
    expect(kinds("這是乾為天。")).toEqual(["wrong_hexagram"]);
    expect(kinds("卦辭說「利涉大川」。")).toEqual(["misquoted_text"]);
    expect(kinds("甲子日最好。")).toEqual(["unknown_ganzhi"]);
  });
});

describe("the API", () => {
  const serve = async () => {
    const api = createApiServer({
      secrets: { digestPepper: PEPPER, drawKey: DRAW_KEY },
      providers: { deepseek: new MockProvider(), anthropic: new MockProvider() },
      devMode: true,
      log: () => {},
    });
    await new Promise<void>((r) => api.listen(0, "127.0.0.1", r));
    const base = `http://127.0.0.1:${(api.address() as AddressInfo).port}`;
    const H = { "content-type": "application/json", "x-dev-country": "HK", "x-dev-user": "ly" };
    const post = (path: string, body: unknown) =>
      fetch(base + path, { method: "POST", headers: H, body: JSON.stringify(body) });
    return { api, base, H, post };
  };

  it("lays out coins with their commitment, then casts from the picks; auto and manual too", async () => {
    const { api, base, H, post } = await serve();
    try {
      const layout = await (await post("/v1/liuyao/layouts", {})).json();
      expect(layout).toMatchObject({ size: 24, picks: 18 });
      expect(layout.commitment).toMatch(/^sha256:[0-9a-f]{64}$/);
      expect(layout).not.toHaveProperty("layout"); // the coins stay on the server
      const picks = Array.from({ length: 18 }, (_, i) => 23 - i);
      const res = await post("/v1/charts", {
        system: "liuyao",
        mode: "pick",
        timezone: "Asia/Hong_Kong",
        draw_id: layout.draw_id,
        picks,
      });
      expect(res.status).toBe(201);
      const fact = (await res.json()).chart_fact;
      expect(fact.facts.pick).toMatchObject({ picks, commitment: layout.commitment });

      expect(
        (await post("/v1/charts", { system: "liuyao", mode: "auto", timezone: "Asia/Hong_Kong" }))
          .status,
      ).toBe(201);
      // A manual cast needs its time; picks must be 18 different coins.
      expect(
        (
          await post("/v1/charts", {
            system: "liuyao",
            mode: "manual",
            timezone: "Asia/Hong_Kong",
            lines: Array(6).fill({ value: 7 }),
          })
        ).status,
      ).toBe(400);
      expect(
        (
          await post("/v1/charts", {
            system: "liuyao",
            mode: "pick",
            timezone: "Asia/Hong_Kong",
            draw_id: layout.draw_id,
            picks: picks.slice(1),
          })
        ).status,
      ).toBe(400);
      // History names each cast by its hexagrams.
      const list = await (await fetch(`${base}/v1/charts`, { headers: H })).json();
      const casts = list.items.map((i: { chart: Record<string, unknown> }) => i.chart);
      expect(casts.map((c: { mode: string }) => c.mode).sort()).toEqual(["auto", "pick"]);
      for (const c of casts) {
        expect(c).toMatchObject({ system: "liuyao", primary: { "zh-Hant": expect.any(String) } });
      }
    } finally {
      await new Promise<void>((r) => api.close(() => r()));
    }
  });
});
