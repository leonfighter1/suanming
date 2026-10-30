// S15 WP15.4 (v9.0.0), the owner: 每当一个算法AI算完成后，可以选择给邮箱发送报告结果（…默认为否，改为是后自动发送）.
// The documents the server writes itself, their HTML and text, the MIME, and the mails: on completion, and by hand.
import type { AddressInfo } from "node:net";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { generateLifeReport, generateReport, MockProvider } from "../src/ai/index.js";
import { createApiServer, MAIL_DOCUMENTS } from "../src/api/server.js";
import { InMemoryStore } from "../src/api/store.js";
import { noCaptcha } from "../src/auth/limits.js";
import { AuthService, InMemoryUserStore } from "../src/auth/service.js";
import { TokenService } from "../src/auth/tokens.js";
import { computeBazi } from "../src/engines/bazi/index.js";
import type { Doc } from "../src/export/document.js";
import { renderHtml, renderText } from "../src/export/render-html.js";
import { lifeDocument, localTime, readingDocument } from "../src/export/report-doc.js";
import { buildMime, MemoryMail, MemorySms, type MailMessage } from "../src/notify/index.js";
import { shareFont } from "../src/share/font.js";
import { DRAW_KEY, FIXED_NOW, PEPPER } from "./helpers.js";

const providers = (mock = new MockProvider()) => ({ deepseek: mock, anthropic: mock });
const bazi = computeBazi(
  { local: "1990-03-15T14:30", timezone: "Asia/Hong_Kong", longitude: 114.17, gender: "female" },
  { digestPepper: PEPPER, now: FIXED_NOW },
);
const report = await generateReport(
  bazi,
  { locale: "zh-Hans", country: "HK", topics: ["wuxing", "career_wealth"] },
  { providers: providers(), now: FIXED_NOW },
);
const life = await generateLifeReport(
  bazi,
  { locale: "zh-Hans", country: "HK" },
  { providers: providers(), now: FIXED_NOW },
);
const person = { name: "徐梅", birthplace: "香港" };
const at = "2026-10-29T01:30:00.000Z";

describe("the documents the server writes itself", () => {
  it("a time in the account's region: 01:30 UTC is 09:30 in 香港 and 台北, the evening before in New York", () => {
    // HK and TW: UTC+8. London: GMT again after 25 Oct 2026. New York: EDT (UTC−4) until 1 Nov 2026.
    expect(localTime(at, "HK")).toBe("2026-10-29 09:30");
    expect(localTime(at, "TW")).toBe("2026-10-29 09:30");
    expect(localTime(at, "GB")).toBe("2026-10-29 01:30");
    expect(localTime(at, "US")).toBe("2026-10-28 21:30");
    expect(localTime(at, "XX")).toBe("2026-10-29 01:30"); // unknown: UTC
  });

  it("a reading: the app's headings, the reading in three parts, the actions, the AI label last", () => {
    const doc = readingDocument(report, {
      system: "bazi",
      locale: "zh-Hans",
      region: "HK",
      created_at: at,
      person,
    });
    expect(doc.title).toBe("徐梅 的命盘");
    expect(doc.subtitle).toBe("AI 解读 · 2026-10-29 09:30");
    expect(doc.blocks[0]).toEqual({
      type: "kv",
      rows: [
        ["姓名", "徐梅"],
        ["出生地", "香港"],
        ["类型", "八字排盘"],
        ["时间", "2026-10-29 09:30"],
      ],
    });
    const texts = doc.blocks.map((b) => `${b.type}:${b.text ?? ""}`);
    expect(texts).toContain("h2:命盘事实 · 引擎计算，非 AI");
    expect(texts).toContain("h2:解读 · AI 生成");
    expect(texts).toContain("h3:五行");
    expect(texts).toContain("h3:事业财运");
    const first = report.layers!.interpretation[0]!.paragraphs[0]!;
    expect(texts).toContain(`p:${first.text}`);
    if (first.term) expect(texts).toContain(`term:${first.term}`);
    if (first.example) expect(texts).toContain(`example:${first.example}`);
    // The facts layer, one line each, and the trend (八字).
    for (const f of report.layers!.facts) expect(texts).toContain(`bullet:${f}`);
    expect(texts.some((t) => t.startsWith("h2:运势走势（总分 "))).toBe(true);
    // Every export ends with the expectation and the AI label (compliance/ai_disclosure_spec.md §4).
    const [, expectation, label] = doc.blocks.slice(-3);
    expect(expectation).toEqual({ type: "note", text: report.layers!.expectation.text });
    expect(label!.text).toBe(
      `${report.layers!.expectation.ai_label}（${report.ai_disclosure.model}）`,
    );
  });

  it("in 繁體 the labels are the app's 繁體 ones; a tarot reading shows what was asked", () => {
    const doc = readingDocument(report, {
      system: "tarot",
      locale: "zh-Hant",
      region: "TW",
      created_at: at,
      question: "我和同事的相處會好轉嗎？",
    });
    expect(doc.title).toBe("塔羅");
    expect(doc.blocks[0]!.rows).toEqual([
      ["類型", "塔羅"],
      ["時間", "2026-10-29 09:30"],
      ["所問", "我和同事的相處會好轉嗎？"],
    ]);
    expect(doc.blocks.map((b) => b.text)).toContain("命盤事實 · 引擎計算，非 AI");
  });

  it("a 一生运势报告: the six sections with the 卦辭, every text of the report, and where the figures are", () => {
    const doc = lifeDocument(life, { locale: "zh-Hans", region: "HK", created_at: at, person });
    expect(doc.title).toBe("徐梅 一生运势报告");
    const h2 = doc.blocks.filter((b) => b.type === "h2").map((b) => b.text);
    expect(h2).toEqual([
      "一、易经本命卦",
      "二、梅花易数",
      "三、五行八卦",
      "四、分项运势",
      "五、人生阶段总览",
      "六、总评与建议",
    ]);
    const texts = doc.blocks.map((b) => b.text);
    expect(texts).toContain(life.facts.benming.hexagram.gua_ci);
    expect(texts).toContain(life.layers!.methods.yijing.meaning);
    expect(texts).toContain(life.layers!.summary.closing);
    for (const t of life.layers!.topics) expect(texts).toContain(t.summary);
    // Six lines, one per 爻, the last one open-ended (75+).
    const lines = doc.blocks.filter(
      (b) => b.type === "bullet" && /（\d+(–\d+|\+) 岁）/.test(b.text ?? ""),
    );
    expect(lines).toHaveLength(6);
    expect(lines[5]!.text).toContain("（75+ 岁）");
    expect(texts).toContain(
      "卦图、六爻表和八宅方位图在 app 里看，也可以在“以往记录”里下载完整的 PDF。",
    );
    expect(doc.blocks.at(-1)!.text).toBe(
      `${life.layers!.expectation.ai_label}（${life.ai_disclosure.model}）`,
    );
  });
});

describe("a document as a mail's body", () => {
  const doc: Doc = {
    title: "A <b>title</b>",
    subtitle: "sub",
    blocks: [
      { type: "p", text: "1 < 2 & <script>alert(1)</script>\nsecond line" },
      { type: "bullet", text: "one" },
      { type: "bullet", text: "two" },
      { type: "kv", rows: [["类型", "八字排盘"]] },
      { type: "divider" },
      { type: "note", text: "note" },
    ],
  };

  it("HTML: everything escaped, the light styles inline and the dark ones in a style block (S25), lists and rows", () => {
    const html = renderHtml(doc);
    expect(html).not.toContain("<script>");
    expect(html).toContain("1 &lt; 2 &amp; &lt;script&gt;alert(1)&lt;/script&gt;<br>second line");
    expect(html).toContain("<title>A &lt;b&gt;title&lt;/b&gt;</title>");
    expect(html.match(/<ul /g)).toHaveLength(1);
    expect(html.match(/<li /g)).toHaveLength(2);
    // Inline, the light theme (a mail program may drop the style block): the app's text colour on its card.
    expect(html).toContain(
      '<td class="m-ink" style="color:#1F1A16;padding:4px 0;vertical-align:top">八字排盘</td>',
    );
    // The dark theme follows the reader's system: one style block, the dark text colour under the media query.
    expect(html.match(/<style>/g)).toHaveLength(1);
    expect(html).toContain('<meta name="color-scheme" content="light dark">');
    const dark = html.slice(html.indexOf("@media (prefers-color-scheme:dark){"));
    expect(dark).toContain(':root:not([data-scheme="light"]) .m-ink{color:#F2EDE7 !important}');
  });

  it("text: the title and subtitle, then blocks a blank line apart, list items together", () => {
    expect(renderText(doc)).toBe(
      [
        "A <b>title</b>",
        "sub",
        "",
        "1 < 2 & <script>alert(1)</script>",
        "second line",
        "",
        "· one",
        "· two",
        "",
        "类型：八字排盘",
        "",
        "────────────",
        "",
        "note",
        "",
      ].join("\n"),
    );
  });
});

/** The parts of a MIME message: headers, then each body part's headers and decoded content. */
function parseMime(raw: string) {
  const [head, ...rest] = raw.split("\r\n\r\n");
  const headers = head!.split("\r\n");
  // Unfolding keeps the space (RFC 5322 §2.2.3), except between two encoded words (RFC 2047 §6.2).
  const decodeWords = (v: string) =>
    v
      .replace(/\r\n /g, " ")
      .replace(/\?=\s+=\?/g, "?==?")
      .replace(/=\?UTF-8\?B\?([^?]*)\?=/g, (_, b64: string) =>
        Buffer.from(b64, "base64").toString("utf8"),
      );
  const header = (name: string) => {
    const at = headers.findIndex((h) => h.startsWith(`${name}: `));
    let v = headers[at]!.slice(name.length + 2);
    for (let i = at + 1; i < headers.length && headers[i]!.startsWith(" "); i++) {
      v += `\r\n${headers[i]}`;
    }
    return decodeWords(v);
  };
  return { header, body: rest.join("\r\n\r\n"), raw };
}

describe("the MIME", () => {
  const pdf = Buffer.from("%PDF-1.7 fake bytes ".repeat(40));
  const message: MailMessage = {
    to: "someone@example.com",
    // Long enough to be split into several encoded words.
    subject: "命理大师：徐梅 的命盘，一份很长很长很长很长很长很长的标题",
    text: "正文\n第二行",
    html: "<p>正文</p>",
    attachments: [
      {
        filename: "命理大师-徐梅 的命盘-2026-10-29.pdf",
        contentType: "application/pdf",
        content: pdf,
      },
    ],
  };
  const raw = buildMime(message, {
    from: "x <no-reply@mingli.local>",
    date: new Date(at),
    id: "abc",
  });
  const mime = parseMime(raw);

  it("headers: the subject comes back whole from its encoded words; the date in RFC 5322 form", () => {
    expect(mime.header("Subject")).toBe(message.subject);
    expect(mime.header("To")).toBe("someone@example.com");
    expect(mime.header("Date")).toBe("Thu, 29 Oct 2026 01:30:00 +0000");
    expect(mime.header("Content-Type")).toBe('multipart/mixed; boundary="=_mixed_abc"');
  });

  it("every line within MIME's limits; the text, the HTML and the file decode back", () => {
    for (const line of raw.split("\r\n")) expect(line.length).toBeLessThanOrEqual(78);
    const parts = raw.split(/--=_(?:mixed|alt)_abc/);
    const decoded = (p: string) =>
      Buffer.from(p.split("\r\n\r\n")[1]!.replace(/\s/g, ""), "base64");
    const text = parts.find((p) => p.includes("text/plain"))!;
    expect(decoded(text).toString("utf8")).toBe("正文\n第二行");
    const html = parts.find((p) => p.includes("text/html"))!;
    expect(decoded(html).toString("utf8")).toBe("<p>正文</p>");
    const file = parts.find((p) => p.includes("application/pdf"))!;
    expect(decoded(file).equals(pdf)).toBe(true);
    // RFC 2231: the name in numbered pieces, the first with its charset.
    const pieces = [...file.matchAll(/filename\*(\d+)\*=(?:UTF-8'')?([^;\r\n]+)/g)];
    expect(pieces.map((p) => Number(p[1]))).toEqual(pieces.map((_, i) => i));
    expect(pieces.length).toBeGreaterThan(1);
    expect(decodeURIComponent(pieces.map((p) => p[2]).join(""))).toBe(
      "命理大师-徐梅 的命盘-2026-10-29.pdf",
    );
    // And an ASCII stand-in for old mail programs.
    expect(file).toContain('filename="attachment.pdf"');
  });
});

// ---- the mails ----

let clock = Date.parse("2026-10-29T01:30:00Z");
const now = () => new Date(clock);
const users = new InMemoryUserStore();
const auth = new AuthService({
  pepper: PEPPER,
  tokens: new TokenService(Buffer.alloc(32, 3), now),
  captcha: noCaptcha,
  users,
  now,
});
const mail = new MemoryMail();
const held = {
  kind: "ok" as const,
  data: {
    pass: false,
    violations: [{ quote: "你今年一定发财。", category: "fatalism", reason: "certainty" }],
  },
};
const guarded = new MockProvider();
const api = createApiServer({
  secrets: { digestPepper: PEPPER, drawKey: DRAW_KEY },
  providers: providers(guarded),
  store: new InMemoryStore(),
  auth,
  mail,
  sms: new MemorySms(),
  admins: ["reviewer"],
  preloadRemedies: false,
  now,
  log: () => {},
});
let base = "";
beforeAll(async () => {
  await new Promise<void>((r) => api.listen(0, "127.0.0.1", r));
  base = `http://127.0.0.1:${(api.address() as AddressInfo).port}`;
});
afterAll(() => new Promise<void>((r) => api.close(() => r())));

const call = async (method: string, path: string, body: unknown, token: string) => {
  const res = await fetch(base + path, {
    method,
    headers: { "content-type": "application/json", authorization: `Bearer ${token}` },
    ...(body !== undefined && { body: JSON.stringify(body) }),
  });
  const text = await res.text();
  return { status: res.status, body: text ? JSON.parse(text) : undefined };
};

/** An account; with `email`, verified by its code; with `on`, 测算完成后发到邮箱 turned on. */
async function account(username: string, o: { email?: string; on?: boolean } = {}) {
  const res = await fetch(base + "/v1/auth/register", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      username,
      password: "long enough pw",
      country: "HK",
      locale: "zh-Hans",
      age_confirmed: true,
    }),
  });
  const token = (await res.json()).access_token as string;
  if (o.email) {
    await call("POST", "/v1/account/email", { email: o.email }, token);
    const code = /(\d{6})/.exec(mail.sent.at(-1)!.subject)![1];
    await call("POST", "/v1/account/email/verify", { email: o.email, code }, token);
  }
  if (o.on) await call("PATCH", "/v1/account/settings", { email_reports: true }, token);
  return token;
}

const birth = {
  system: "bazi",
  local: "1990-03-15T14:30",
  timezone: "Asia/Hong_Kong",
  longitude: 114.17,
  gender: "female",
  person,
};
async function reading(token: string) {
  const chart = await call("POST", "/v1/charts", birth, token);
  const made = await call(
    "POST",
    "/v1/reports",
    { chart_id: chart.body.chart_id, locale: "zh-Hans" },
    token,
  );
  await api.drain();
  return { chartId: chart.body.chart_id as string, reportId: made.body.report_id as string };
}
const reportMails = () => mail.sent.filter((m) => !/验证码/.test(m.subject));

describe("测算完成后发到邮箱", () => {
  it("on: a passed reading goes to the verified email, in the message and as a PDF, and the record notes it", async () => {
    const token = await account("mail_on", { email: "on@example.com", on: true });
    const before = reportMails().length;
    const { reportId } = await reading(token);
    const sent = reportMails().slice(before);
    expect(sent).toHaveLength(1);
    const m = sent[0]!;
    expect(m.to).toBe("on@example.com");
    expect(m.subject).toBe("命理大师：徐梅 的命盘");
    const view = (await call("GET", `/v1/reports/${reportId}`, undefined, token)).body;
    const paragraph = view.layers.interpretation[0].paragraphs[0].text as string;
    expect(m.html).toContain(paragraph.slice(0, 20));
    expect(m.text).toContain("你在命理大师开启了“测算完成后发到邮箱”");
    // The PDF goes along wherever the server has a Chinese font (this computer, CI's Noto); else the message alone.
    const font = shareFont("zh-Hans");
    expect(m.attachments?.length ?? 0).toBe(font ? 1 : 0);
    if (font) {
      expect(m.attachments![0]!.filename).toBe("命理大师-徐梅-的命盘-2026-10-29.pdf");
      expect(m.attachments![0]!.content.subarray(0, 5).toString("latin1")).toBe("%PDF-");
    }
    expect(view.mail).toEqual({ status: "sent", at: now().toISOString() });
  }, 30_000);

  it("off (the default): nothing is mailed, and the record says nothing", async () => {
    const token = await account("mail_off", { email: "off@example.com" });
    const before = reportMails().length;
    const { reportId } = await reading(token);
    expect(reportMails().length).toBe(before);
    const view = (await call("GET", `/v1/reports/${reportId}`, undefined, token)).body;
    expect(view.status).toBe("passed");
    expect(view).not.toHaveProperty("mail");
  });

  it("a failing provider: the reading stands, the record notes the failure", async () => {
    const token = await account("mail_fails", { email: "fails@example.com", on: true });
    mail.failing = true;
    try {
      const { reportId } = await reading(token);
      const view = (await call("GET", `/v1/reports/${reportId}`, undefined, token)).body;
      expect(view.status).toBe("passed");
      expect(view.mail).toEqual({ status: "failed", at: now().toISOString() });
    } finally {
      mail.failing = false;
    }
  });

  it("a held reading is not mailed; released by a reviewer, it goes", async () => {
    await auth.seedDevUser({
      login: "reviewer",
      password: "reviewer",
      country: "HK",
      locale: "zh-Hans",
    });
    const login = await fetch(base + "/v1/auth/login", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ login: "reviewer", password: "reviewer" }),
    });
    const boss = (await login.json()).access_token as string;
    const token = await account("mail_held", { email: "held@example.com", on: true });
    const before = reportMails().length;
    (guarded as unknown as { script: Record<string, unknown[]> }).script.guard = [held];
    const { reportId } = await reading(token);
    const view = (await call("GET", `/v1/reports/${reportId}`, undefined, token)).body;
    expect(view.status).toBe("manual_review");
    expect(reportMails().length).toBe(before);
    const released = await call(
      "POST",
      `/v1/admin/reviews/report/${reportId}`,
      { decision: "approve" },
      boss,
    );
    expect(released.status).toBe(200);
    await api.drain();
    expect(
      reportMails()
        .slice(before)
        .map((m) => m.to),
    ).toEqual(["held@example.com"]);
  });

  it("a 一生运势报告 that passes goes too, under its own title", async () => {
    const token = await account("mail_life", { email: "life@example.com", on: true });
    const chart = await call("POST", "/v1/charts", birth, token);
    const before = reportMails().length;
    const made = await call(
      "POST",
      "/v1/life-reports",
      { chart_id: chart.body.chart_id, locale: "zh-Hans" },
      token,
    );
    expect(made.status).toBe(202);
    await api.drain();
    const sent = reportMails().slice(before);
    expect(sent.map((m) => m.subject)).toEqual(["命理大师：徐梅 一生运势报告"]);
    expect(sent[0]!.text).toContain("一、易经本命卦");
  }, 30_000);
});

describe("发到邮箱: chosen records, to the account's own verified email", () => {
  const doc = (title: string) => ({
    title,
    blocks: [
      { type: "p", text: "正文" },
      { type: "note", text: "AI 生成" },
    ],
  });

  it("one message with every file; refused without a verified email, past the limit, or with too many", async () => {
    const token = await account("sender", { email: "sender@example.com" });
    const res = await call(
      "POST",
      "/v1/documents/email",
      {
        format: "docx",
        documents: [
          { document: doc("徐梅 的命盘"), filename: "命理大师-徐梅 的命盘-2026-10-29" },
          { document: doc("塔罗"), filename: "命理大师-塔罗-2026-10-28" },
        ],
      },
      token,
    );
    expect(res.status).toBe(202);
    expect(res.body).toEqual({ sent_to: "s***@example.com", count: 2, delivery: "memory" });
    const m = mail.sent.at(-1)!;
    expect(m.to).toBe("sender@example.com");
    expect(m.subject).toBe("命理大师：2 份记录");
    expect(m.attachments!.map((a) => a.filename)).toEqual([
      "命理大师-徐梅 的命盘-2026-10-29.docx",
      "命理大师-塔罗-2026-10-28.docx",
    ]);
    // A Word file is a zip: it starts with PK.
    expect(m.attachments![0]!.content.subarray(0, 2).toString("latin1")).toBe("PK");
    expect(m.text).toContain("· 徐梅 的命盘");

    const many = Array.from({ length: MAIL_DOCUMENTS + 1 }, (_, i) => ({
      document: doc(`记录 ${i}`),
    }));
    const tooMany = await call(
      "POST",
      "/v1/documents/email",
      { format: "docx", documents: many },
      token,
    );
    expect(tooMany.status).toBe(400);

    const unverified = await account("no_email");
    const refused = await call(
      "POST",
      "/v1/documents/email",
      { format: "docx", documents: [{ document: doc("塔罗") }] },
      unverified,
    );
    expect([refused.status, refused.body.code]).toEqual([409, "email_unverified"]);
  });

  it("a server without mail says so (503) and renders nothing", async () => {
    const quiet = createApiServer({
      secrets: { digestPepper: PEPPER, drawKey: DRAW_KEY },
      providers: providers(),
      auth,
      log: () => {},
    });
    await new Promise<void>((r) => quiet.listen(0, "127.0.0.1", r));
    try {
      const token = await account("quiet_user", { email: "quiet@example.com" });
      const res = await fetch(
        `http://127.0.0.1:${(quiet.address() as AddressInfo).port}/v1/documents/email`,
        {
          method: "POST",
          headers: { "content-type": "application/json", authorization: `Bearer ${token}` },
          body: JSON.stringify({ format: "docx", documents: [{ document: doc("塔罗") }] }),
        },
      );
      expect(res.status).toBe(503);
      expect((await res.json()).code).toBe("delivery_unavailable");
    } finally {
      await new Promise<void>((r) => quiet.close(() => r()));
    }
  });
});
