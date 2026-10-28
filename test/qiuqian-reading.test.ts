// 求籤 (tech plan WP6.1 + 6.2): the reading, its checks, and the API. Mock provider only.
import type { AddressInfo } from "node:net";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { checkFaithfulness, generateReport, MockProvider, type Report } from "../src/ai/index.js";
import { chineseNumeral, lotTitle } from "../src/ai/qiuqian.js";
import { createApiServer } from "../src/api/server.js";
import { loadGeoMatrix, methodsFor, resolveRegion } from "../src/compliance/index.js";
import { computeQiuqian, type QiuqianFacts } from "../src/engines/qiuqian/index.js";
import { lotSet } from "../src/engines/qiuqian/lots.js";
import { DRAW_KEY, FIXED_NOW, PEPPER } from "./helpers.js";

const chart = computeQiuqian(
  {},
  {
    drawKey: DRAW_KEY,
    digestPepper: PEPPER,
    now: FIXED_NOW,
    newDrawId: () => "00000000-0000-4000-8000-000000000001",
  },
);
const facts = chart.facts as unknown as QiuqianFacts;
const lot = lotSet("guandi_100").lots[facts.lot.n - 1]!;
const read = (mock: MockProvider, locale: "zh-Hant" | "zh-Hans" | "en" = "zh-Hans") =>
  generateReport(
    chart,
    { locale, country: "TW", question: "今年適合換工作嗎？" },
    { providers: { deepseek: mock, anthropic: mock }, now: FIXED_NOW },
  );

describe("the lot's title", () => {
  it("numbers lots the way temples do", () => {
    // 1 一, 10 十, 11 十一, 20 二十, 52 五十二, 100 一百.
    expect([1, 10, 11, 20, 52, 100].map(chineseNumeral)).toEqual([
      "一",
      "十",
      "十一",
      "二十",
      "五十二",
      "一百",
    ]);
    expect(lotTitle(52, "zh-Hant")).toBe("第五十二籤");
    expect(lotTitle(52, "zh-Hans")).toBe("第五十二签");
    expect(lotTitle(52, "en")).toBe("Lot 52");
  });
});

describe("a 求籤 reading", () => {
  it("reads the lot with its own prompts: the poem in the reader's script, no rounds, actions on the advice", async () => {
    const mock = new MockProvider();
    const report = await read(mock);
    expect(report.status).toBe("passed");
    expect(report.topics).toEqual(["qiuqian_poem", "qiuqian_answer", "qiuqian_advice"]);
    expect(report.ai_disclosure.prompt_version).toBe(
      "narrative_qiuqian@1,action_qiuqian@1,guard@2",
    );
    const narrative = mock.calls.find((c) => c.agent === "narrative")!;
    // <lot> carries the 简体 lines for a 简体 reader; <chart_facts> the lot without the rounds.
    for (const l of lot.poem["zh-Hans"]) expect(narrative.user).toContain(l);
    const factsTag = /<chart_facts>\n([\s\S]*?)\n<\/chart_facts>/.exec(narrative.user)![1]!;
    expect(JSON.parse(factsTag)).toEqual({ lot_set: "guandi_100", lot: facts.lot });
    expect(narrative.user).toContain("<user_question>\n今年適合換工作嗎？");
    // The facts layer: the set, the title and label, then the four lines.
    expect(report.layers!.facts).toEqual([
      `关圣帝君一百签 · ${lotTitle(lot.n, "zh-Hans")}（${lot.ganzhi}）`,
      ...lot.poem["zh-Hans"],
    ]);
    expect(report.layers!.actions.every((a) => a.topic === "qiuqian_advice")).toBe(true);
  });

  it("asks again when the poem section leaves a line unread", async () => {
    const short = {
      sections: [
        {
          topic: "qiuqian_poem",
          summary: "（示范）重点。",
          paragraphs: [
            {
              text: "（示范）第一句。",
              source_level: "traditional_text",
              fact_refs: ["/lot/poem/0"],
            },
          ],
        },
        ...(["qiuqian_answer", "qiuqian_advice"] as const).map((topic) => ({
          topic,
          summary: "（示范）重点。",
          paragraphs: [
            { text: "（示范）段落。", source_level: "derived", fact_refs: ["/lot/poem/1"] },
          ],
        })),
      ],
    };
    const mock = new MockProvider({ narrative: [{ kind: "ok", data: short }] });
    const report = await read(mock);
    const retry = mock.calls.filter((c) => c.agent === "narrative")[1]!;
    expect(retry.user).toContain(
      "qiuqian_poem must read all four lines; not cited: /lot/poem/1, /lot/poem/2, /lot/poem/3",
    );
    expect(report.status).toBe("passed");
  });
});

describe("faithfulness of a 求籤 reading", () => {
  const withText = (report: Report, text: string): Report => ({
    ...report,
    layers: {
      ...report.layers!,
      interpretation: [
        {
          topic: "qiuqian_poem",
          paragraphs: [{ text, source_level: "traditional_text", fact_refs: ["/lot/poem/0"] }],
        },
      ],
      actions: [],
    },
  });

  it("accepts the lot's own lines and number, and catches a misquote or another number", async () => {
    const report = await read(new MockProvider(), "zh-Hant");
    const [l1, l2] = lot.poem["zh-Hant"];
    const own = `${lotTitle(lot.n, "zh-Hant")}說：「${l1}，${l2}」`;
    expect(checkFaithfulness(chart, withText(report, own))).toEqual([]);

    const wrong = [...l1!].reverse().join("");
    const other = lot.n === 1 ? 2 : lot.n - 1;
    const issues = checkFaithfulness(
      chart,
      withText(report, `「${wrong}」 ${lotTitle(other, "zh-Hant")} 第${other}籤`),
    );
    expect(issues.map((i) => i.kind)).toEqual(["misquoted_line", "wrong_lot", "wrong_lot"]);

    const en = await read(new MockProvider(), "en");
    expect(
      checkFaithfulness(chart, withText(en, `“${l1}”: in Lot ${lot.n}, the first line`)),
    ).toEqual([]);
    expect(checkFaithfulness(chart, withText(en, `Lot ${other} says`)).map((i) => i.kind)).toEqual([
      "wrong_lot",
    ]);
  });
});

describe("the entry order (WP6.2)", () => {
  const order = (cc: string) =>
    methodsFor(resolveRegion(loadGeoMatrix(), cc)!).map((m) => m.system);

  it("puts 求籤 first in Taiwan and Hong Kong, and keeps the default order elsewhere", () => {
    // TW, HK: qiuqian 1.5 > bazi 1.2 > tarot 1 = astrology 1 (ties keep bazi, tarot, qiuqian, astrology).
    expect(order("TW")).toEqual(["qiuqian", "bazi", "tarot", "astrology"]);
    expect(order("HK")).toEqual(["qiuqian", "bazi", "tarot", "astrology"]);
    // SG: every weight 1, so the default order.
    expect(order("SG")).toEqual(["bazi", "tarot", "qiuqian", "astrology"]);
  });
});

describe("the API", () => {
  const api = createApiServer({
    secrets: { digestPepper: PEPPER, drawKey: DRAW_KEY },
    providers: { deepseek: new MockProvider(), anthropic: new MockProvider() },
    devMode: true,
    log: () => {},
  });
  let base = "";
  beforeAll(async () => {
    await new Promise<void>((r) => api.listen(0, "127.0.0.1", r));
    base = `http://127.0.0.1:${(api.address() as AddressInfo).port}`;
  });
  afterAll(() => new Promise<void>((r) => api.close(() => r())));
  const H = (country = "TW") => ({
    "content-type": "application/json",
    "x-dev-country": country,
    "x-dev-user": "q1",
  });
  const call = async (method: string, path: string, body?: unknown, country?: string) => {
    const res = await fetch(base + path, {
      method,
      headers: H(country),
      ...(body !== undefined && { body: JSON.stringify(body) }),
    });
    return { status: res.status, body: await res.json() };
  };

  it("draws a lot, reads it, and offers no focus and no plan", async () => {
    const chart = await call("POST", "/v1/charts", { system: "qiuqian" });
    expect(chart.status).toBe(201);
    expect(chart.body.chart_fact.system).toBe("qiuqian");
    expect(
      (await call("POST", "/v1/charts", { system: "qiuqian", lot_set: "mazu_60" })).status,
    ).toBe(400);

    const focus = await call("POST", "/v1/reports", {
      chart_id: chart.body.chart_id,
      locale: "zh-Hant",
      focus: "career_wealth",
    });
    expect(focus.status).toBe(400);
    const report = await call("POST", "/v1/reports", {
      chart_id: chart.body.chart_id,
      locale: "zh-Hant",
      question: "這次搬家順利嗎？",
    });
    await api.drain();
    const done = await call("GET", `/v1/reports/${report.body.report_id}`);
    expect(done.body.status).toBe("passed");
    expect(done.body.topics).toEqual(["qiuqian_poem", "qiuqian_answer", "qiuqian_advice"]);
    const plan = await call("POST", `/v1/reports/${report.body.report_id}/remedies`, {
      topic: "qiuqian_advice",
    });
    expect(plan.status).toBe(400);
  });

  it("lists the region's methods in its entry order", async () => {
    const tw = await call("GET", "/v1/methods");
    expect(tw.status).toBe(200);
    expect(tw.body.methods.map((m: { system: string }) => m.system)[0]).toBe("qiuqian");
    expect(tw.body.matrix_version).toBe("0.2.0");
    const sg = await call("GET", "/v1/methods", undefined, "SG");
    expect(sg.body.methods[0].system).toBe("bazi");
    expect((await call("GET", "/v1/methods", undefined, "CN")).status).toBe(451);
  });
});
