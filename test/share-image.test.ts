// S7 WP7.1 (docs/tech-plan.md): a passed tarot reading as a share image, made on the server (the owner's
// phase document: 分享图由服务端生成，带水印与免责声明). A CJK font must be there: CI installs
// fonts-noto-cjk; on Windows, Noto Sans SC or 微软雅黑 is found.
import type { AddressInfo } from "node:net";
import { randomUUID } from "node:crypto";
import sharp from "sharp";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { generateReport, MockProvider } from "../src/ai/index.js";
import { createApiServer } from "../src/api/server.js";
import { lotTitle } from "../src/ai/qiuqian.js";
import type { Locale } from "../src/ai/terms.js";
import { computeQiuqian } from "../src/engines/qiuqian/index.js";
import { computeTarot } from "../src/engines/tarot/index.js";
import { shareFont } from "../src/share/font.js";
import { qiuqianShareTexts, renderQiuqianShare } from "../src/share/qiuqian-image.js";
import { renderTarotShare, shareTexts } from "../src/share/tarot-image.js";
import { DRAW_KEY, FIXED_NOW, PEPPER } from "./helpers.js";

const QUESTION = "這份工作還要繼續嗎？";
const draw = (spread: "three_card" | "celtic_cross", id: string) =>
  computeTarot(
    { spread },
    { drawKey: DRAW_KEY, digestPepper: PEPPER, now: FIXED_NOW, newDrawId: () => id },
  );
const read = (chart: ReturnType<typeof draw>, locale: Locale) =>
  generateReport(
    chart,
    { locale, country: "HK", question: QUESTION },
    { providers: { deepseek: new MockProvider(), anthropic: new MockProvider() }, now: FIXED_NOW },
  );

describe("what the share image says", () => {
  it("the cards with their positions, 逆位 when reversed, the main point and the AI label; never the question", async () => {
    const chart = draw("three_card", "00000000-0000-4000-8000-000000000001");
    const report = await read(chart, "zh-Hant");
    const t = shareTexts(report, chart, "zh-Hant");
    expect(t.title).toBe("命理大師 · 塔羅");
    expect(t.cards.map((c) => c.position)).toEqual(["過去", "現在", "未來"]);
    const facts = chart.facts as { cards: { reversed: boolean }[] };
    for (const [i, c] of t.cards.entries()) {
      expect(c.name.endsWith(" · 逆位"), c.name).toBe(facts.cards[i]!.reversed);
    }
    const synthesis = report.layers!.interpretation.find((s) => s.topic === "tarot_synthesis")!;
    expect(t.point).toBe(synthesis.summary);
    expect(t.label).toBe(report.layers!.expectation.ai_label);
    expect(t.mark).toBe("命理大師 · 2026-10-25");
    // Private: the question, as asked, appears nowhere.
    expect(JSON.stringify(t)).not.toContain(QUESTION);
    expect(JSON.stringify(t)).not.toContain("工作");
  });
});

describe("what a 求籤 share image says (v4.3.0)", () => {
  it("the set, the lot's title and label, its four lines and the poem's point; never the question or the answer", async () => {
    const chart = computeQiuqian(
      {},
      { drawKey: DRAW_KEY, digestPepper: PEPPER, now: FIXED_NOW, newDrawId: () => randomUUID() },
    );
    const report = await read(chart, "zh-Hant");
    const t = qiuqianShareTexts(report, chart, "zh-Hant");
    const f = chart.facts as { lot: { n: number; ganzhi: string; poem: string[] } };
    expect(t.title).toBe("命理大師 · 求籤");
    expect(t.set).toBe("關聖帝君一百籤");
    expect(t.lot).toBe(`${lotTitle(f.lot.n, "zh-Hant")} · ${f.lot.ganzhi}`);
    expect(t.lines).toEqual(f.lot.poem);
    const poem = report.layers!.interpretation.find((s) => s.topic === "qiuqian_poem")!;
    expect(t.point).toBe(poem.summary);
    expect(t.label).toBe(report.layers!.expectation.ai_label);
    expect(JSON.stringify(t)).not.toContain(QUESTION);
    const answer = report.layers!.interpretation.find((s) => s.topic === "qiuqian_answer")!;
    expect(JSON.stringify(t)).not.toContain(answer.paragraphs[0]!.text);
  });
});

describe("the image", () => {
  const font = (l: Locale) => {
    const f = shareFont(l, {});
    if (!f) throw new Error("no CJK font: install fonts-noto-cjk (Linux) or set MINGLI_SHARE_FONT");
    return f;
  };

  it("is a 1080 × 1350 JPEG, for three cards in 繁體 and a Celtic Cross in English", async () => {
    for (const [spread, locale] of [
      ["three_card", "zh-Hant"],
      ["celtic_cross", "en"],
    ] as const) {
      const chart = draw(spread, randomUUID());
      const jpg = await renderTarotShare(await read(chart, locale), chart, {
        font: font(locale),
        locale,
      });
      expect([...jpg.subarray(0, 3)]).toEqual([0xff, 0xd8, 0xff]);
      expect(await sharp(jpg).metadata()).toMatchObject({
        format: "jpeg",
        width: 1080,
        height: 1350,
      });
    }
  }, 30_000);

  it("is a 1080 × 1350 JPEG for a 求籤 reading in 简体 and in English", async () => {
    for (const locale of ["zh-Hans", "en"] as const) {
      const chart = computeQiuqian(
        {},
        { drawKey: DRAW_KEY, digestPepper: PEPPER, now: FIXED_NOW, newDrawId: () => randomUUID() },
      );
      const jpg = await renderQiuqianShare(await read(chart, locale), chart, {
        font: font(locale),
        locale,
      });
      expect(await sharp(jpg).metadata()).toMatchObject({
        format: "jpeg",
        width: 1080,
        height: 1350,
      });
    }
  }, 30_000);
});

describe("GET /v1/reports/{id}/share.jpg", () => {
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
  const H = (user = "u1") => ({
    "content-type": "application/json",
    "x-dev-country": "HK",
    "x-dev-user": user,
  });
  const post = async (path: string, body: unknown) =>
    (await fetch(base + path, { method: "POST", headers: H(), body: JSON.stringify(body) })).json();
  const reading = async (chart: unknown) => {
    const { chart_id } = await post("/v1/charts", chart);
    return post("/v1/reports", { chart_id, locale: "zh-Hant" });
  };

  it("gives the owner the image of a passed tarot reading, with the AI headers; nobody else, nothing else", async () => {
    const tarot = await reading({
      system: "tarot",
      spread: "three_card",
      question: "最近的工作会顺利吗？",
    });
    await api.drain();
    const ok = await fetch(`${base}/v1/reports/${tarot.report_id}/share.jpg`, { headers: H() });
    expect(ok.status).toBe(200);
    expect(ok.headers.get("content-type")).toBe("image/jpeg");
    expect(ok.headers.get("x-ai-generated")).toBe("true");
    expect((await sharp(Buffer.from(await ok.arrayBuffer())).metadata()).width).toBe(1080);
    // Another account: as if it weren't there.
    expect(
      (await fetch(`${base}/v1/reports/${tarot.report_id}/share.jpg`, { headers: H("u2") })).status,
    ).toBe(404);
    // A 求籤 reading has one too (v4.3.0).
    const lot = await reading({ system: "qiuqian", question: "明年事业如何？" });
    await api.drain();
    const lotImage = await fetch(`${base}/v1/reports/${lot.report_id}/share.jpg`, { headers: H() });
    expect(lotImage.status).toBe(200);
    expect(lotImage.headers.get("content-type")).toBe("image/jpeg");
    // A 八字 reading has no share image yet.
    const bazi = await reading({
      system: "bazi",
      local: "1990-03-15T14:30",
      timezone: "Asia/Hong_Kong",
      longitude: 114.17,
      gender: "male",
    });
    await api.drain();
    expect(
      (await fetch(`${base}/v1/reports/${bazi.report_id}/share.jpg`, { headers: H() })).status,
    ).toBe(409);
  }, 30_000);

  it("says what to install when the server has no CJK font", async () => {
    const tarot = await reading({
      system: "tarot",
      spread: "single",
      question: "最近的工作会顺利吗？",
    });
    await api.drain();
    process.env.MINGLI_SHARE_FONT = "/no/such/font.ttf";
    try {
      const res = await fetch(`${base}/v1/reports/${tarot.report_id}/share.jpg`, { headers: H() });
      expect(res.status).toBe(503);
      expect((await res.json()).title).toMatch(/fonts-noto-cjk|MINGLI_SHARE_FONT/);
    } finally {
      delete process.env.MINGLI_SHARE_FONT;
    }
  });
});
