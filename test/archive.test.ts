// S14 (docs/tech-plan.md, the owner's request 2026-10-28): 以往记录 — a record as Word or PDF, deleting one record,
// and filing a record under a person.
import { existsSync } from "node:fs";
import type { AddressInfo } from "node:net";
import { inflateRawSync } from "node:zlib";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { MockProvider } from "../src/ai/index.js";
import { createApiServer } from "../src/api/server.js";
import { InMemoryStore } from "../src/api/store.js";
import {
  contentDisposition,
  documentName,
  parseDocument,
  type Doc,
} from "../src/export/document.js";
import { renderDocx } from "../src/export/render-docx.js";
import { renderPdf } from "../src/export/render-pdf.js";
import { shareFont } from "../src/share/font.js";
import { DRAW_KEY, PEPPER, withNamingOn } from "./helpers.js";

/** The entries of a zip (a .docx is one), inflated: enough of the format to read what Word would. */
function unzip(buf: Buffer): Record<string, string> {
  const out: Record<string, string> = {};
  for (let at = buf.indexOf("PK\x03\x04"); at >= 0; at = buf.indexOf("PK\x03\x04", at + 4)) {
    const method = buf.readUInt16LE(at + 8);
    const size = buf.readUInt32LE(at + 18);
    const nameLen = buf.readUInt16LE(at + 26);
    const extra = buf.readUInt16LE(at + 28);
    const name = buf.subarray(at + 30, at + 30 + nameLen).toString("utf8");
    const data = buf.subarray(at + 30 + nameLen + extra, at + 30 + nameLen + extra + size);
    out[name] = (method === 8 ? inflateRawSync(data) : data).toString("utf8");
  }
  return out;
}

const sample: Doc = {
  title: "徐梅 的命盘 · AI 解读",
  subtitle: "2026-10-28 14:30",
  blocks: [
    { type: "kv", rows: [["出生地", "中国 · 上海市 · 上海"]] },
    { type: "h2", text: "性格" },
    { type: "summary", text: "你做事踏实，也乐于帮人。" },
    { type: "term", text: "日主己土，生于卯月（失令）" },
    { type: "p", text: "你像一块田地，踏实、能包容。" },
    {
      type: "example",
      text: "比如同事临时找你帮忙改方案，你嘴上说“没事”，其实已经开始帮他想办法了。",
    },
    { type: "quote", text: "「急水灘頭放艇時」" },
    { type: "bullet", text: "本周花十分钟写下一个观察。" },
    { type: "question", text: "问：明年我的事业怎么样？" },
    { type: "divider" },
    { type: "note", text: "本解读由 AI 依据命盘资料生成，仅供娱乐和玄学学习使用。" },
  ],
};

describe("documents (WP14.1)", () => {
  it("checks a document: known blocks only, within the limits", () => {
    expect(parseDocument(sample)).toEqual(sample);
    expect(() => parseDocument({ ...sample, title: " " })).toThrow(/title is required/);
    expect(() => parseDocument({ ...sample, blocks: [{ type: "script", text: "x" }] })).toThrow(
      /type must be one of/,
    );
    expect(() =>
      parseDocument({ ...sample, blocks: [{ type: "p", text: "长".repeat(6001) }] }),
    ).toThrow(/longer than 6000/);
    expect(() =>
      parseDocument({ ...sample, blocks: [{ type: "kv", rows: [["only one"]] }] }),
    ).toThrow(/a label and a value/);
  });

  it("names the file safely, in UTF-8 with an ASCII fallback", () => {
    expect(documentName("命理大师-八字排盘-徐梅-2026-10-28", "pdf")).toBe(
      "命理大师-八字排盘-徐梅-2026-10-28.pdf",
    );
    expect(documentName("../../etc/passwd\n", "docx")).toBe(".. .. etc passwd.docx");
    expect(documentName("", "pdf")).toBe("命理大师.pdf");
    expect(contentDisposition("徐梅.pdf")).toBe(
      `attachment; filename="__.pdf"; filename*=UTF-8''${encodeURIComponent("徐梅.pdf")}`,
    );
  });

  it("writes Word with every block's text, in an East Asian font", async () => {
    const files = unzip(await renderDocx(sample, "zh-Hans"));
    const body = files["word/document.xml"]!;
    for (const b of sample.blocks) if (b.text) expect(body).toContain(b.text.replace("“", "“"));
    expect(body).toContain("中国 · 上海市 · 上海");
    expect(files["word/styles.xml"]).toContain("Microsoft YaHei");
    expect(files["word/styles.xml"]).toContain('w:eastAsia="zh-CN"');
  });

  it("writes PDF with the server's Chinese font embedded as a subset", async () => {
    const font = shareFont("zh-Hans", {});
    if (!font)
      throw new Error("no CJK font: install fonts-noto-cjk (Linux) or set MINGLI_SHARE_FONT");
    const pdf = await renderPdf(sample, font);
    const raw = pdf.toString("latin1");
    expect(raw.startsWith("%PDF-")).toBe(true);
    // A subset font: its name carries the six-letter tag PDF uses for subsets.
    expect(raw).toMatch(/\/BaseFont \/[A-Z]{6}\+/);
    expect(pdf.length).toBeLessThan(300_000);
  });

  it.skipIf(!existsSync("C:/Windows/Fonts/msyh.ttc"))(
    "embeds a face of a font collection by its name",
    async () => {
      const pdf = await renderPdf(sample, {
        file: "C:/Windows/Fonts/msyh.ttc",
        family: "Microsoft YaHei",
        face: "MicrosoftYaHei",
      });
      expect(pdf.toString("latin1")).toMatch(/\/BaseFont \/[A-Z]{6}\+MicrosoftYaHei/);
    },
  );
});

// ---- the API ----

const mock = new MockProvider();
const store = new InMemoryStore();
const api = createApiServer({
  secrets: { digestPepper: PEPPER, drawKey: DRAW_KEY },
  providers: { deepseek: mock, anthropic: mock },
  store,
  devMode: true,
  log: () => {},
});
let base = "";
beforeAll(async () => {
  await new Promise<void>((r) => api.listen(0, "127.0.0.1", r));
  base = `http://127.0.0.1:${(api.address() as AddressInfo).port}`;
});
afterAll(() => new Promise<void>((r) => api.close(() => r())));
const H = (user: string) => ({
  "content-type": "application/json",
  "x-dev-country": "HK",
  "x-dev-user": user,
});
const post = (path: string, body: unknown, user: string) =>
  fetch(base + path, { method: "POST", headers: H(user), body: JSON.stringify(body) });
const get = (path: string, user: string) => fetch(base + path, { headers: H(user) });
const del = (path: string, user: string) =>
  fetch(base + path, { method: "DELETE", headers: H(user) });
const birth = {
  system: "bazi",
  local: "1990-03-15T14:30",
  timezone: "Asia/Hong_Kong",
  longitude: 114.17,
  gender: "male",
};

describe("以往记录, the API (WP14.1–14.2)", () => {
  it("renders a record's document as PDF or Word for a signed-in caller", async () => {
    const pdf = await post(
      "/v1/documents",
      { format: "pdf", filename: "命理大师-徐梅", document: sample },
      "doc-u",
    );
    expect(pdf.status).toBe(200);
    expect(pdf.headers.get("content-type")).toBe("application/pdf");
    expect(pdf.headers.get("content-disposition")).toContain(
      encodeURIComponent("命理大师-徐梅.pdf"),
    );
    expect(
      Buffer.from(await pdf.arrayBuffer())
        .subarray(0, 5)
        .toString(),
    ).toBe("%PDF-");
    const docx = await post(
      "/v1/documents",
      { format: "docx", locale: "zh-Hant", document: sample },
      "doc-u",
    );
    expect(docx.headers.get("content-type")).toContain("wordprocessingml");
    expect(unzip(Buffer.from(await docx.arrayBuffer()))["word/styles.xml"]).toContain(
      'w:eastAsia="zh-TW"',
    );
    expect((await post("/v1/documents", { format: "txt", document: sample }, "doc-u")).status).toBe(
      400,
    );
    expect(
      (
        await post(
          "/v1/documents",
          { format: "pdf", document: { title: "x", blocks: [{ type: "img" }] } },
          "doc-u",
        )
      ).status,
    ).toBe(400);
  });

  it("deletes one reading with its plans and 追问, and its chart when nothing else reads it", async () => {
    const u = "del-a";
    const { chart_id } = await (await post("/v1/charts", birth, u)).json();
    const { report_id } = await (
      await post("/v1/reports", { chart_id, locale: "zh-Hans" }, u)
    ).json();
    await api.drain(); // the reading passes and its 破除運勢 plans are preloaded
    await post(`/v1/reports/${report_id}/followups`, { question: "我适合什么工作？" }, u);
    await api.drain();
    expect((await store.listRemedies(report_id)).length).toBeGreaterThan(0);
    const plans = (await store.listRemedies(report_id)).length;

    expect((await del(`/v1/reports/${report_id}`, "someone-else")).status).toBe(404);
    const gone = await del(`/v1/reports/${report_id}`, u);
    expect(gone.status).toBe(200);
    expect((await gone.json()).deleted).toEqual({
      reports: 1,
      remedies: plans,
      followups: 1,
      inquiries: 0,
      charts: 1,
    });
    expect((await get(`/v1/reports/${report_id}`, u)).status).toBe(404);
    expect((await get(`/v1/charts/${chart_id}`, u)).status).toBe(404);
    expect(await store.listFollowUps(report_id)).toEqual([]);
    expect((await (await get("/v1/reports", u)).json()).items).toEqual([]);
  });

  it("keeps a chart another record still reads; deletes a 一生运势报告 with its 追问", async () => {
    const u = "del-b";
    const { chart_id } = await (await post("/v1/charts", birth, u)).json();
    const { report_id } = await (
      await post("/v1/reports", { chart_id, locale: "zh-Hans" }, u)
    ).json();
    const life = await (await post("/v1/life-reports", { chart_id, locale: "zh-Hans" }, u)).json();
    await api.drain();
    await post(
      `/v1/life-reports/${life.life_report_id}/followups`,
      { question: "我哪个阶段最需要用心？" },
      u,
    );
    await api.drain();
    const first = await (await del(`/v1/reports/${report_id}`, u)).json();
    expect(first.deleted.charts).toBe(0); // the 一生运势报告 still reads it
    expect((await get(`/v1/charts/${chart_id}`, u)).status).toBe(200);
    const second = await (await del(`/v1/life-reports/${life.life_report_id}`, u)).json();
    expect(second.deleted).toEqual({ life_reports: 1, followups: 1, charts: 1 });
    expect((await get(`/v1/charts/${chart_id}`, u)).status).toBe(404);
  });

  it("a reading deleted while it is written is never written back", async () => {
    const u = "del-c";
    const { chart_id } = await (
      await post(
        "/v1/charts",
        { system: "tarot", spread: "single", question: "最近的工作会顺利吗？" },
        u,
      )
    ).json();
    const { report_id } = await (
      await post("/v1/reports", { chart_id, locale: "zh-Hans" }, u)
    ).json();
    await del(`/v1/reports/${report_id}`, u); // before its job has finished
    await api.drain();
    expect(await store.getReport(report_id)).toBeUndefined();
    expect(await store.listRemedies(report_id)).toEqual([]);
  });

  it("files any record under a person: set, rename or clear; a birth chart keeps its birthplace", async () => {
    const u = "file-a";
    const tarot = await (
      await post(
        "/v1/charts",
        {
          system: "tarot",
          spread: "single",
          question: "最近的工作会顺利吗？",
          person: { name: "我" },
        },
        u,
      )
    ).json();
    expect(tarot.person).toEqual({ name: "我" }); // since v8.0.0 any chart may name its person
    const set = await post(`/v1/charts/${tarot.chart_id}/person`, { name: "小明" }, u);
    expect(await set.json()).toEqual({ chart_id: tarot.chart_id, person: { name: "小明" } });
    expect((await (await get(`/v1/charts/${tarot.chart_id}`, u)).json()).person).toEqual({
      name: "小明",
    });
    const cleared = await (
      await post(`/v1/charts/${tarot.chart_id}/person`, { name: "" }, u)
    ).json();
    expect(cleared).toEqual({ chart_id: tarot.chart_id });
    expect(
      (await post(`/v1/charts/${tarot.chart_id}/person`, { birthplace: "上海" }, u)).status,
    ).toBe(400);
    expect(
      (await post(`/v1/charts/${tarot.chart_id}/person`, { name: "x" }, "someone-else")).status,
    ).toBe(404);

    const bazi = await (
      await post(
        "/v1/charts",
        { ...birth, person: { name: "徐梅", birthplace: "中国 · 上海市 · 上海" } },
        u,
      )
    ).json();
    const renamed = await (
      await post(`/v1/charts/${bazi.chart_id}/person`, { name: "徐小梅" }, u)
    ).json();
    expect(renamed.person).toEqual({ name: "徐小梅", birthplace: "中国 · 上海市 · 上海" });
  });

  it("a 起名 chart is filed under its 八字 chart's person", async () => {
    const u = "file-b";
    const bazi = await (
      await post("/v1/charts", { ...birth, person: { name: "徐梅", birthplace: "上海" } }, u)
    ).json();
    // 起名 ships off until the owner's review: switched on here, whatever the shipped matrix says (rule 42).
    const naming = await withNamingOn(() =>
      post(
        "/v1/charts",
        { system: "naming", bazi_chart_id: bazi.chart_id, surname: "陳", length: 2 },
        u,
      ),
    );
    expect(naming.status).toBe(201);
    // A name, not the birthplace: a 起名 chart isn't a birth chart.
    expect((await naming.json()).person).toEqual({ name: "徐梅" });
  });
});
