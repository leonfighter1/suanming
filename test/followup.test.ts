// WP13.2 (docs/tech-plan.md, the owner's request 2026-10-28): 追问 on every reading, answered from that reading alone
// (「不能胡编乱造，一定要基于之前的回答和各个卦象所表达的东西」).
import type { AddressInfo } from "node:net";
import { describe, expect, it } from "vitest";
import {
  FOLLOWUP_LIMIT,
  FollowUpInputError,
  GeoRefusedError,
  generateFollowUp,
  generateLifeReport,
  generateReport,
  METHOD_PROMPTS,
  MockProvider,
  PROMPTS,
  type FollowUpAnswer,
  type FollowUpParent,
} from "../src/ai/index.js";
import { createApiServer } from "../src/api/server.js";
import { computeBazi } from "../src/engines/bazi/index.js";
import { DECK } from "../src/engines/tarot/deck.js";
import { computeTarot } from "../src/engines/tarot/index.js";
import { DRAW_KEY, FIXED_NOW, PEPPER } from "./helpers.js";
import { testApi } from "./api.js";

const bazi = computeBazi(
  { local: "1990-03-15T14:30", timezone: "Asia/Hong_Kong", longitude: 114.17, gender: "male" },
  { digestPepper: PEPPER, now: FIXED_NOW },
);
const tarot = computeTarot(
  { spread: "three_card" },
  { drawKey: DRAW_KEY, digestPepper: PEPPER, now: FIXED_NOW, newDrawId: () => "draw-1" },
);
const deps = (mock: MockProvider) => ({
  providers: { deepseek: mock, anthropic: mock },
  now: FIXED_NOW,
});
const zh = { locale: "zh-Hans" as const, country: "HK" };
const reading = async (chart = bazi, question?: string) => ({
  kind: "report" as const,
  report: await generateReport(chart, { ...zh, question }, deps(new MockProvider())),
  ...(question && { question }),
});
const answer = (a: Partial<FollowUpAnswer> & Pick<FollowUpAnswer, "paragraphs">) => ({
  kind: "ok" as const,
  data: { in_scope: true, suggestions: [], ...a },
});
const userOf = (mock: MockProvider) => mock.calls.find((c) => c.agent === "followup")!.user;

describe("追问, the pipeline (WP13.2)", () => {
  it("answers from the reading's own facts, in the reading's three parts, with next questions", async () => {
    const parent = await reading();
    const mock = new MockProvider();
    const f = await generateFollowUp(bazi, parent, "我适合什么样的工作？", [], zh, deps(mock));
    expect(f.status).toBe("passed");
    expect(f.ai_disclosure.prompt_version).toBe("followup_bazi@1,guard@2");
    const [p] = f.answer!.paragraphs;
    expect((p!.term ?? "").trim()).not.toBe("");
    expect(p!.text.trim()).not.toBe("");
    expect((p!.example ?? "").trim()).not.toBe("");
    expect(p!.fact_refs.length).toBeGreaterThan(0);
    expect(f.answer!.suggestions.length).toBeGreaterThan(0);
    // The model read the facts, the reading as written, and the question.
    const user = userOf(mock);
    expect(user).toContain("<chart_facts>");
    expect(user).toContain("<reading>");
    expect(user).toContain(parent.report.layers!.interpretation[0]!.paragraphs[0]!.text);
    expect(user).toContain("<follow_up_question>\n我适合什么样的工作？\n</follow_up_question>");
    expect(mock.calls.find((c) => c.agent === "followup")!.system).toBe(
      PROMPTS.followup_bazi.system,
    );
  });

  it("every method answers with its own follow-up prompt (rule 8)", () => {
    const ids = Object.entries(METHOD_PROMPTS).map(([system, own]) => [system, own.followup?.id]);
    for (const [system, id] of ids) expect(id).toBe(`followup_${system}@1`);
    expect(new Set(ids.map(([, id]) => id)).size).toBe(ids.length);
    expect(PROMPTS.followup_life.id).toBe("followup_life@1");
  });

  it("drops a paragraph that cites nothing and sends the answer back", async () => {
    const parent = await reading();
    const mock = new MockProvider({
      followup: [
        answer({
          paragraphs: [
            {
              term: "日主己土",
              text: "你做事踏实。",
              source_level: "traditional_text",
              fact_refs: ["/nope"],
            },
          ],
        }),
      ],
    });
    const f = await generateFollowUp(bazi, parent, "我的性格怎样？", [], zh, deps(mock));
    expect(f.agents[0]!.attempts).toBe(2);
    expect(mock.calls.filter((c) => c.agent === "followup")[1]!.user).toContain(
      "cited no existing chart_facts path",
    );
    expect(f.status).toBe("passed");
  });

  it("sends back an answer that names a card the reading never drew", async () => {
    const parent = await reading(tarot, "这份工作还要继续吗？");
    const drawn = new Set(
      (tarot.facts as { cards: { card_id: string }[] }).cards.map((c) => c.card_id),
    );
    const other = DECK.find((c) => !drawn.has(c.id))!.name["zh-Hans"];
    const mock = new MockProvider({
      followup: [
        answer({
          paragraphs: [
            {
              term: `第 1 张·过去：${other}（正位）`,
              text: "这张牌提醒你放慢脚步。",
              source_level: "traditional_text",
              fact_refs: ["/cards/0"],
            },
          ],
        }),
      ],
    });
    const f = await generateFollowUp(tarot, parent, "第一张牌是什么意思？", [], zh, deps(mock));
    expect(f.agents[0]!.attempts).toBe(2);
    expect(mock.calls.filter((c) => c.agent === "followup")[1]!.user).toContain(
      "card_not_in_spread",
    );
    expect(f.status).toBe("passed");
    expect(JSON.stringify(f.answer)).not.toContain(other);
  });

  it("a question the reading can't answer says so and makes no claim", async () => {
    const parent = await reading(tarot, "这份工作还要继续吗？");
    const mock = new MockProvider({
      followup: [
        answer({
          in_scope: false,
          paragraphs: [
            {
              term: "",
              text: "这组牌是为你问的工作抽的，它说不了你家猫的病，也替代不了兽医。",
              source_level: "derived",
              fact_refs: [],
            },
          ],
          suggestions: ["这份工作接下来该怎么做？"],
        }),
      ],
    });
    const f = await generateFollowUp(tarot, parent, "我家的猫会好起来吗？", [], zh, deps(mock));
    expect(f.status).toBe("passed");
    expect(f.answer).toEqual({
      in_scope: false,
      paragraphs: [
        {
          text: "这组牌是为你问的工作抽的，它说不了你家猫的病，也替代不了兽医。",
          source_level: "derived",
          fact_refs: [],
        },
      ],
      suggestions: ["这份工作接下来该怎么做？"],
    });
  });

  it("reads the last six earlier 追问 with a new one", async () => {
    const parent = await reading();
    const first = await generateFollowUp(bazi, parent, "问题一", [], zh, deps(new MockProvider()));
    const thread = Array.from({ length: 8 }, (_, i) => ({
      question: `第${i + 1}个问题`,
      answer: first.answer!,
    }));
    const mock = new MockProvider();
    await generateFollowUp(bazi, parent, "新问题", thread, zh, deps(mock));
    const user = userOf(mock);
    // 8 earlier questions: the first two are left out, the six after them are read.
    expect(user).not.toContain("第1个问题");
    expect(user).not.toContain("第2个问题");
    for (let i = 3; i <= 8; i++) expect(user).toContain(`第${i}个问题`);
  });

  it("a 八字 追问 that names a year reads that year in full", async () => {
    const parent = await reading();
    const mock = new MockProvider();
    await generateFollowUp(bazi, parent, "2030年我的事业怎么样？", [], zh, deps(mock));
    // The reading's own focus is 2026–2028 (FIXED_NOW is 2026); the question adds 2030.
    const facts = JSON.parse(/<chart_facts>\n([\s\S]*?)\n<\/chart_facts>/.exec(userOf(mock))![1]!);
    expect(facts.view.focus_years).toEqual([2026, 2027, 2028, 2030]);
  });

  it("drops suggestions already asked, overlong, or naming what the reading lacks", async () => {
    const parent = await reading();
    const mock = new MockProvider({
      followup: [
        answer({
          paragraphs: [
            {
              term: "日主己土",
              text: "你做事踏实。",
              source_level: "traditional_text",
              fact_refs: ["/day_master"],
            },
          ],
          suggestions: [
            "我适合什么样的工作？",
            "长".repeat(41),
            "甲子年对我好吗？",
            "明年要注意什么？",
          ],
        }),
      ],
    });
    const f = await generateFollowUp(bazi, parent, "我适合什么样的工作？", [], zh, deps(mock));
    // 甲子 is in no pillar, 大运 or 流年 of this chart (faithfulness: unknown_ganzhi).
    expect(f.answer!.suggestions).toEqual(["明年要注意什么？"]);
  });

  it("runs the Geo-Rule before any model call", async () => {
    const parent = await reading();
    const mock = new MockProvider();
    await expect(
      generateFollowUp(bazi, parent, "问题", [], { country: "CN" }, deps(mock)),
    ).rejects.toThrow(GeoRefusedError);
    expect(mock.calls).toEqual([]);
  });

  it("scans the answer with the rule layer", async () => {
    const parent = await reading();
    const mock = new MockProvider({
      followup: [
        answer({
          paragraphs: [
            {
              term: "日主己土",
              text: "你注定会失去这段感情。",
              source_level: "traditional_text",
              fact_refs: ["/day_master"],
            },
          ],
        }),
      ],
    });
    const f = await generateFollowUp(bazi, parent, "感情怎样？", [], zh, deps(mock));
    expect(mock.calls.filter((c) => c.agent === "followup")[1]!.user).toContain("G003");
    expect(f.status).toBe("passed");
  });

  it("asks only about a passed reading, with a question of 1–200 characters", async () => {
    const parent = await reading();
    const held = { ...parent, report: { ...parent.report, status: "manual_review" as const } };
    const run = (p: FollowUpParent, q: string) =>
      generateFollowUp(bazi, p, q, [], zh, deps(new MockProvider()));
    await expect(run(held, "问题")).rejects.toThrow(FollowUpInputError);
    await expect(run(parent, "   ")).rejects.toThrow(FollowUpInputError);
    await expect(run(parent, "问".repeat(201))).rejects.toThrow(FollowUpInputError);
    await expect(run(parent, "问".repeat(200))).resolves.toMatchObject({ status: "passed" });
  });

  it("a 一生运势报告 is asked about with its own prompt and its own facts", async () => {
    const life = await generateLifeReport(bazi, zh, deps(new MockProvider()));
    const mock = new MockProvider();
    const f = await generateFollowUp(
      bazi,
      { kind: "life_report", life },
      "我哪个阶段最需要用心？",
      [],
      zh,
      deps(mock),
    );
    expect(f.status).toBe("passed");
    expect(f.ai_disclosure.prompt_version).toBe("followup_life@1,guard@2");
    const user = userOf(mock);
    expect(user).toContain("<life_facts>");
    // No exact birth time in a 追问: the life facts go without their birth clock.
    expect(user).not.toContain("1990-03-15T14:30");
  });
});

// ---- the API ----

const mock = new MockProvider();
let base = "";
const api = testApi(
  {
    providers: { deepseek: mock, anthropic: mock },
  },
  (b) => (base = b),
);
const H = (user = "fu-user") => ({
  "content-type": "application/json",
  "x-dev-country": "HK",
  "x-dev-user": user,
});
const post = (path: string, body: unknown, user?: string) =>
  fetch(base + path, { method: "POST", headers: H(user), body: JSON.stringify(body) });
const get = (path: string, user?: string) => fetch(base + path, { headers: H(user) });
const birth = {
  system: "bazi",
  local: "1990-03-15T14:30",
  timezone: "Asia/Hong_Kong",
  longitude: 114.17,
  gender: "male",
};
async function passedReport(user: string) {
  const { chart_id } = await (await post("/v1/charts", birth, user)).json();
  const { report_id } = await (
    await post("/v1/reports", { chart_id, locale: "zh-Hans" }, user)
  ).json();
  await api.drain();
  return { chart_id, report_id };
}

describe("追问, the API (WP13.2)", () => {
  it("asks, waits and answers; the list keeps the thread oldest first", async () => {
    const { report_id } = await passedReport("fu-a");
    const asked = await post(
      `/v1/reports/${report_id}/followups`,
      { question: "我适合什么工作？" },
      "fu-a",
    );
    expect(asked.status).toBe(202);
    expect(asked.headers.get("location")).toMatch(/^\/v1\/followups\//);
    const pending = await asked.json();
    expect(pending).toMatchObject({
      status: "pending",
      question: "我适合什么工作？",
      parent: { kind: "report", id: report_id },
    });
    expect(pending).not.toHaveProperty("answer");
    await api.drain();
    const done = await get(`/v1/followups/${pending.followup_id}`, "fu-a");
    expect(done.headers.get("x-ai-generated")).toBe("true");
    const view = await done.json();
    expect(view.status).toBe("passed");
    expect(view.answer.paragraphs.length).toBeGreaterThan(0);
    await post(`/v1/reports/${report_id}/followups`, { question: "第二个问题" }, "fu-a");
    await api.drain();
    const list = await (await get(`/v1/reports/${report_id}/followups`, "fu-a")).json();
    expect(list.limit).toBe(FOLLOWUP_LIMIT);
    expect(list.items.map((f: { question: string }) => f.question)).toEqual([
      "我适合什么工作？",
      "第二个问题",
    ]);
    // Someone else sees none of it.
    expect((await get(`/v1/reports/${report_id}/followups`, "fu-other")).status).toBe(404);
    expect((await get(`/v1/followups/${pending.followup_id}`, "fu-other")).status).toBe(404);
  });

  it("checks the question and the reading", async () => {
    const { report_id } = await passedReport("fu-b");
    expect(
      (await post(`/v1/reports/${report_id}/followups`, { question: " " }, "fu-b")).status,
    ).toBe(400);
    expect(
      (await post(`/v1/reports/${report_id}/followups`, { question: "问".repeat(201) }, "fu-b"))
        .status,
    ).toBe(400);
    expect(
      (await post(`/v1/reports/${report_id}/followups`, { question: "问" }, "fu-c")).status,
    ).toBe(404);
  });

  it("answers one at a time", async () => {
    // The mock answers at once (rule 37): this server's 追问 waits until released.
    let release!: () => void;
    const gate = new Promise<void>((r) => (release = r));
    const slow = {
      name: "slow",
      generateJson: async (req: Parameters<MockProvider["generateJson"]>[0]) => {
        if (req.agent === "followup") await gate;
        return mock.generateJson(req);
      },
    };
    const s = createApiServer({
      secrets: { digestPepper: PEPPER, drawKey: DRAW_KEY },
      providers: { deepseek: slow, anthropic: slow },
      devMode: true,
      log: () => {},
    });
    await new Promise<void>((r) => s.listen(0, "127.0.0.1", r));
    const url = `http://127.0.0.1:${(s.address() as AddressInfo).port}`;
    const p = (path: string, body: unknown) =>
      fetch(url + path, { method: "POST", headers: H("fu-slow"), body: JSON.stringify(body) });
    const { chart_id } = await (await p("/v1/charts", birth)).json();
    const { report_id } = await (await p("/v1/reports", { chart_id, locale: "zh-Hans" })).json();
    await s.drain();
    const path = `/v1/reports/${report_id}/followups`;
    expect((await p(path, { question: "第1问" })).status).toBe(202);
    const busy = await p(path, { question: "又一问" });
    expect(busy.status).toBe(409);
    expect((await busy.json()).code).toBe("followup_pending");
    release();
    await s.drain();
    expect((await p(path, { question: "又一问" })).status).toBe(202);
    await s.drain();
    await new Promise<void>((r) => s.close(() => r()));
  });

  it("answers up to the limit, then says so", async () => {
    const { report_id } = await passedReport("fu-d");
    const path = `/v1/reports/${report_id}/followups`;
    for (let i = 1; i <= FOLLOWUP_LIMIT; i++) {
      expect((await post(path, { question: `第${i}问` }, "fu-d")).status).toBe(202);
      await api.drain();
    }
    const full = await post(path, { question: "再问" }, "fu-d");
    expect(full.status).toBe(409);
    expect((await full.json()).code).toBe("followup_limit");
  });

  it("each 追问 takes one from the daily AI caps", async () => {
    const s = createApiServer({
      secrets: { digestPepper: PEPPER, drawKey: DRAW_KEY },
      providers: { deepseek: mock, anthropic: mock },
      devMode: true,
      aiQuota: { perUserPerDay: 2, totalPerDay: 100 },
      preloadRemedies: false,
      log: () => {},
    });
    await new Promise<void>((r) => s.listen(0, "127.0.0.1", r));
    const url = `http://127.0.0.1:${(s.address() as AddressInfo).port}`;
    const p = (path: string, body: unknown) =>
      fetch(url + path, { method: "POST", headers: H("fu-capped"), body: JSON.stringify(body) });
    const { chart_id } = await (await p("/v1/charts", birth)).json();
    const { report_id } = await (await p("/v1/reports", { chart_id, locale: "zh-Hans" })).json();
    await s.drain();
    // 2 per account: the reading took one, the first 追问 the other.
    expect((await p(`/v1/reports/${report_id}/followups`, { question: "第一问" })).status).toBe(
      202,
    );
    await s.drain();
    expect((await p(`/v1/reports/${report_id}/followups`, { question: "第二问" })).status).toBe(
      429,
    );
    await new Promise<void>((r) => s.close(() => r()));
  });

  it("a 一生运势报告 can be asked about too", async () => {
    const { chart_id } = await (await post("/v1/charts", birth, "fu-e")).json();
    const life = await (
      await post("/v1/life-reports", { chart_id, locale: "zh-Hans" }, "fu-e")
    ).json();
    await api.drain();
    const asked = await (
      await post(
        `/v1/life-reports/${life.life_report_id}/followups`,
        { question: "我哪个阶段最需要用心？" },
        "fu-e",
      )
    ).json();
    await api.drain();
    const view = await (await get(`/v1/followups/${asked.followup_id}`, "fu-e")).json();
    expect(view).toMatchObject({
      status: "passed",
      parent: { kind: "life_report", id: life.life_report_id },
    });
  });
});
