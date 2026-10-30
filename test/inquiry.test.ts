// S19 WP19.1 (docs/tech-plan.md, the owner's requests 2026-10-29): 深度分析. Before a reading the master asks the
// user about their situation, one question at a time, from the result and their goal, and infers from each answer
// (「根据卦象或者推算结果再去问对方问题 … 要根据用户的输入做出合理推断」); 1–6 questions (「最多不超过6个问题」); it needs a goal
// (「使用这一功能一定要给出个明确的目标才行」); the reading then reads the conversation.
import type { AddressInfo } from "node:net";
import { describe, expect, it } from "vitest";
import {
  GeoRefusedError,
  generateInquiryTurn,
  generateReport,
  INQUIRY_MAX_QUESTIONS,
  inquiryAvailable,
  inquiryGoal,
  InquiryInputError,
  MockProvider,
  PROMPTS,
  ReportInputError,
  type InquiryTurn,
} from "../src/ai/index.js";
import { createApiServer } from "../src/api/server.js";
import { computeAstrology } from "../src/engines/astrology/index.js";
import { computeBazi } from "../src/engines/bazi/index.js";
import { computeFengshui } from "../src/engines/fengshui/index.js";
import { computeLiuyao } from "../src/engines/liuyao/index.js";
import { computeNaming } from "../src/engines/naming/index.js";
import { computeQiuqian } from "../src/engines/qiuqian/index.js";
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
const others = {
  tarot,
  qiuqian: computeQiuqian(
    {},
    {
      drawKey: DRAW_KEY,
      digestPepper: PEPPER,
      now: FIXED_NOW,
      newDrawId: () => "00000000-0000-4000-8000-000000000001",
    },
  ),
  liuyao: computeLiuyao(
    { mode: "auto", timezone: "Asia/Hong_Kong" },
    {
      drawKey: DRAW_KEY,
      digestPepper: PEPPER,
      now: FIXED_NOW,
      newDrawId: () => "00000000-0000-4000-8000-000000000002",
    },
  ),
  fengshui: computeFengshui({ room: "bedroom" }, { digestPepper: PEPPER, now: FIXED_NOW }),
};
const deps = (mock: MockProvider) => ({
  providers: { deepseek: mock, anthropic: mock },
  now: FIXED_NOW,
});
const zh = { locale: "zh-Hans" as const, country: "HK" };
const GOAL = "想知道明年适不适合换工作";
const turn = (data: Record<string, unknown>) => ({
  kind: "ok" as const,
  data: { say: "", question: "", done: false, planned: 3, focus: "换工作", fact_refs: [], ...data },
});
const answered = (n: number): InquiryTurn[] =>
  Array.from({ length: n }, (_, i) => ({
    say: `第${i + 1}句`,
    question: `第${i + 1}个问题是什么？`,
    fact_refs: [],
    answer: `第${i + 1}个回答`,
  }));
const inquiryCalls = (mock: MockProvider) => mock.calls.filter((c) => c.agent === "inquiry");

describe("深度分析, the pipeline (WP19.1)", () => {
  it("asks its first question from the reading's own view of the chart, the goal and the person", async () => {
    const mock = new MockProvider();
    const step = await generateInquiryTurn(
      bazi,
      { goal: GOAL, context: { name: "徐梅", occupation: "会计" } as never, turns: [] },
      zh,
      deps(mock),
    );
    expect(step.status).toBe("passed");
    expect(step.ai_disclosure.prompt_version).toBe("inquiry_bazi@1,guard@2");
    expect(step.done).toBe(false);
    expect(step.turn!.question.trim()).not.toBe("");
    expect(step.turn!.say.trim()).not.toBe("");
    expect(step.planned).toBe(2); // the demo master plans two
    expect(step.focus.trim()).not.toBe("");
    expect(step.turn!.fact_refs.length).toBeGreaterThan(0);
    const [call] = inquiryCalls(mock);
    expect(call!.system).toBe(PROMPTS.inquiry_bazi.system);
    expect(call!.user).toContain(`<goal>\n${GOAL}\n</goal>`);
    expect(call!.user).toContain("<user_context>");
    expect(call!.user).toContain("Questions asked: 0. Planned: not set yet");
    expect(call!.user).not.toContain("<conversation>");
    // The 排盘 alone, as the reading reads it (v9.3.0): no engine judgement, no exact birth time.
    expect(call!.user).not.toContain("wuxing_weighted");
    expect(call!.user).not.toContain('"strength"');
    expect(call!.user).not.toContain("1990-03-15T14:30");
  });

  it("asks with each method's own prompt; 起名 and astrology have none", async () => {
    for (const [system, chart] of Object.entries(others)) {
      expect(inquiryAvailable(chart), system).toBe(true);
      const mock = new MockProvider();
      const step = await generateInquiryTurn(chart, { goal: GOAL, turns: [] }, zh, deps(mock));
      expect(step.ai_disclosure.prompt_version, system).toBe(`inquiry_${system}@1,guard@2`);
      expect(step.turn!.fact_refs.length, system).toBeGreaterThan(0);
    }
    const naming = computeNaming(
      bazi,
      { surname: "陳", length: 2 },
      { digestPepper: PEPPER, now: FIXED_NOW },
    );
    const astrology = computeAstrology(
      { local: "1990-03-15T14:30", timezone: "Asia/Hong_Kong", latitude: 22.3, longitude: 114.17 },
      { digestPepper: PEPPER, now: FIXED_NOW },
    );
    for (const chart of [naming, astrology]) {
      expect(inquiryAvailable(chart)).toBe(false);
      await expect(
        generateInquiryTurn(chart, { goal: GOAL, turns: [] }, zh, deps(new MockProvider())),
      ).rejects.toThrow(InquiryInputError);
    }
  });

  it("needs a clear goal: at least four characters (the owner: 一定要给出个明确的目标)", async () => {
    expect(inquiryGoal(" 想换工作 ")).toBe("想换工作");
    for (const goal of ["看看", "   ", "问".repeat(301), undefined]) {
      expect(inquiryGoal(goal)).toBeUndefined();
      await expect(
        generateInquiryTurn(
          bazi,
          { goal: goal as string, turns: [] },
          zh,
          deps(new MockProvider()),
        ),
      ).rejects.toThrow(InquiryInputError);
    }
  });

  it("reads the conversation so far, oldest first, with where it stands, and closes when it knows enough", async () => {
    const mock = new MockProvider();
    const step = await generateInquiryTurn(
      bazi,
      { goal: GOAL, turns: answered(2), planned: 3 },
      zh,
      deps(mock),
    );
    const user = inquiryCalls(mock)[0]!.user;
    expect(user).toContain("<conversation>");
    expect(user.indexOf("第1个回答")).toBeLessThan(user.indexOf("第2个回答"));
    expect(user).toContain("Questions asked: 2. Planned: 3. At most: 6.");
    // The demo master is done after two: no question, its closing words.
    expect(step.done).toBe(true);
    expect(step.turn!.question).toBe("");
    expect(step.turn!.say.trim()).not.toBe("");
  });

  it("asks nothing more after the sixth answer, and never plans more than six", async () => {
    const mock = new MockProvider({
      inquiry: [turn({ say: "还有一点想问。", question: "还有别的吗？", planned: 7 })],
    });
    const step = await generateInquiryTurn(
      bazi,
      { goal: GOAL, turns: answered(INQUIRY_MAX_QUESTIONS), planned: 6 },
      zh,
      deps(mock),
    );
    expect(step.done).toBe(true);
    expect(step.turn!.question).toBe("");
    expect(step.planned).toBe(6);
    await expect(
      generateInquiryTurn(bazi, { goal: GOAL, turns: answered(7) }, zh, deps(new MockProvider())),
    ).rejects.toThrow(InquiryInputError);
    // Every earlier question needs its answer first.
    const open = [...answered(1), { say: "", question: "还没回答？", fact_refs: [] }];
    await expect(
      generateInquiryTurn(bazi, { goal: GOAL, turns: open }, zh, deps(new MockProvider())),
    ).rejects.toThrow(InquiryInputError);
  });

  it("plans 1–6 questions, never fewer than it is about to have asked", async () => {
    // Hand-worked: a first turn that asks has asked 1, so planned 0 becomes 1; 9 becomes 6; after three answers a
    // fourth question makes 4, so planned 2 becomes 4.
    const cases: [number, InquiryTurn[], number][] = [
      [0, [], 1],
      [9, [], 6],
      [2, answered(3), 4],
    ];
    for (const [planned, turns, expected] of cases) {
      const mock = new MockProvider({
        inquiry: [turn({ say: "看起来是这样。", question: `新的问题${planned}？`, planned })],
      });
      const step = await generateInquiryTurn(bazi, { goal: GOAL, turns }, zh, deps(mock));
      expect(step.planned, `planned ${planned}`).toBe(expected);
    }
  });

  it("sends back a turn naming a card the draw doesn't have, and drops a path that isn't there", async () => {
    const drawn = new Set(
      (tarot.facts as { cards: { card_id: string }[] }).cards.map((c) => c.card_id),
    );
    const other = DECK.find((c) => !drawn.has(c.id))!.name["zh-Hans"];
    const mock = new MockProvider({
      inquiry: [
        turn({
          say: `你抽到的${other}（正位）说明你想换个环境。`,
          question: "你最担心的是什么？",
          fact_refs: ["/cards/0"],
        }),
      ],
    });
    const step = await generateInquiryTurn(tarot, { goal: GOAL, turns: [] }, zh, deps(mock));
    expect(step.agents[0]!.attempts).toBe(2);
    expect(inquiryCalls(mock)[1]!.user).toContain("card_not_in_spread");
    expect(step.status).toBe("passed");
    expect(JSON.stringify(step.turn)).not.toContain(other);

    const paths = new MockProvider({
      inquiry: [
        turn({
          say: "第一张牌说明你已经想走了。",
          question: "你最担心的是什么？",
          fact_refs: ["/cards/0", "/cards/9"],
        }),
      ],
    });
    const cited = await generateInquiryTurn(tarot, { goal: GOAL, turns: [] }, zh, deps(paths));
    expect(cited.turn!.fact_refs).toEqual(["/cards/0"]);
    expect(cited.compliance.dropped_refs).toBe(1);
  });

  it("asks something new each time, and always asks on its first turn", async () => {
    const again = new MockProvider({
      inquiry: [turn({ say: "嗯。", question: "第1个问题是什么?" })],
    });
    const step = await generateInquiryTurn(
      bazi,
      { goal: GOAL, turns: answered(1) },
      zh,
      deps(again),
    );
    expect(step.agents[0]!.attempts).toBe(2);
    expect(inquiryCalls(again)[1]!.user).toContain("already asked");
    expect(step.turn!.question).not.toBe("第1个问题是什么?");

    const silent = new MockProvider({ inquiry: [turn({ say: "我明白了。", done: true })] });
    const first = await generateInquiryTurn(bazi, { goal: GOAL, turns: [] }, zh, deps(silent));
    expect(first.agents[0]!.attempts).toBe(2);
    expect(inquiryCalls(silent)[1]!.user).toContain("this is the first turn");
    expect(first.done).toBe(false);
    expect(first.turn!.question.trim()).not.toBe("");
  });

  it("applies the Geo-Rule before any model call", async () => {
    const mock = new MockProvider();
    await expect(
      generateInquiryTurn(
        bazi,
        { goal: GOAL, turns: [] },
        { locale: "zh-Hans", country: "CN" },
        deps(mock),
      ),
    ).rejects.toThrow(GeoRefusedError);
    expect(mock.calls).toEqual([]);
  });
});

describe("the reading reads its 深度分析 (WP19.1)", () => {
  const inquiry = {
    goal: "想知道和她还有没有可能",
    turns: [
      {
        say: "结果里你们之间的确有隔阂。",
        question: "你说想分手，她知道吗？",
        answer: "知道，我已经跟她说过了",
      },
      {
        say: "她已经知道，说明问题摆到明面上了。",
        question: "她那边最近有没有什么你还不清楚的情况？",
        answer: "不知道，也不想知道，我只想知道分开以后还能不能找到对象",
      },
    ],
    understanding: "分开以后还能不能找到合适的人",
  };

  it("gives the conversation to the method's new reading prompt, every answer in order", async () => {
    for (const [chart, id] of [
      [bazi, "narrative_bazi@9"],
      [tarot, "narrative_tarot@5"],
      [others.qiuqian, "narrative_qiuqian@3"],
      [others.liuyao, "narrative_liuyao@3"],
      [others.fengshui, "narrative_fengshui@3"],
    ] as const) {
      const mock = new MockProvider();
      const report = await generateReport(chart, { ...zh, inquiry }, deps(mock));
      expect(report.ai_disclosure.prompt_version.split(",")[0]).toBe(id);
      const call = mock.calls.find((c) => c.agent === "narrative")!;
      expect(call.system, id).toContain("<inquiry>, when present");
      const user = call.user;
      expect(user).toContain("<inquiry>");
      expect(user).toContain(inquiry.goal);
      expect(user).toContain(inquiry.understanding);
      expect(user.indexOf("知道，我已经跟她说过了")).toBeLessThan(
        user.indexOf("分开以后还能不能找到对象"),
      );
      expect(user).toContain('"said"');
    }
    // 八字 also brings the answer into its 总结.
    expect(PROMPTS.narrative_bazi.system).toContain("and again in the 总结");
  });

  it("reads without it as before, and refuses it for a method with no 深度分析", async () => {
    const mock = new MockProvider();
    await generateReport(bazi, zh, deps(mock));
    expect(mock.calls.find((c) => c.agent === "narrative")!.user).not.toContain("<inquiry>");
    const astrology = computeAstrology(
      { local: "1990-03-15T14:30", timezone: "Asia/Hong_Kong", latitude: 22.3, longitude: 114.17 },
      { digestPepper: PEPPER, now: FIXED_NOW },
    );
    await expect(
      generateReport(astrology, { ...zh, inquiry }, deps(new MockProvider())),
    ).rejects.toThrow(ReportInputError);
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

const H = (user = "iq-user") => ({
  "content-type": "application/json",
  "x-dev-country": "HK",
  "x-dev-user": user,
});
const at = (url: string) => (path: string, body: unknown, user?: string) =>
  fetch(url + path, { method: "POST", headers: H(user), body: JSON.stringify(body) });
const post = (path: string, body: unknown, user?: string) => at(base)(path, body, user);
const get = (path: string, user?: string) => fetch(base + path, { headers: H(user) });
const birth = {
  system: "bazi",
  local: "1990-03-15T14:30",
  timezone: "Asia/Hong_Kong",
  longitude: 114.17,
  gender: "male",
};
const chartOf = async (user: string, url = base) =>
  ((await (await at(url)("/v1/charts", birth, user)).json()) as { chart_id: string }).chart_id;
const lastNarrative = () => mock.calls.filter((c) => c.agent === "narrative").at(-1)!.user;

/** A server whose inquiry turns go through [inquiry] first. */
async function serverWith(
  inquiry: (req: Parameters<MockProvider["generateJson"]>[0]) => Promise<void>,
) {
  const own = new MockProvider();
  const provider = {
    name: "scripted",
    generateJson: async (req: Parameters<MockProvider["generateJson"]>[0]) => {
      if (req.agent === "inquiry") await inquiry(req);
      return own.generateJson(req);
    },
  };
  const s = createApiServer({
    secrets: { digestPepper: PEPPER, drawKey: DRAW_KEY },
    providers: { deepseek: provider, anthropic: provider },
    devMode: true,
    log: () => {},
  });
  await new Promise<void>((r) => s.listen(0, "127.0.0.1", r));
  const url = `http://127.0.0.1:${(s.address() as AddressInfo).port}`;
  return {
    s,
    url,
    close: () => new Promise<void>((r) => s.close(() => r())),
  };
}

describe("深度分析, the API (WP19.1)", () => {
  it("needs a clear goal: 400 goal_required without one", async () => {
    const chart_id = await chartOf("iq-goal");
    for (const goal of [undefined, "", "看看"]) {
      const res = await post("/v1/inquiries", { chart_id, locale: "zh-Hans", goal }, "iq-goal");
      expect(res.status, String(goal)).toBe(400);
      expect((await res.json()).code).toBe("goal_required");
    }
  });

  it("asks, takes each answer, closes, and the reading reads the whole conversation", async () => {
    const u = "iq-flow";
    const chart_id = await chartOf(u);
    const started = await post("/v1/inquiries", { chart_id, locale: "zh-Hans", goal: GOAL }, u);
    expect(started.status).toBe(202);
    expect(started.headers.get("location")).toMatch(/^\/v1\/inquiries\//);
    const { inquiry_id, status } = await started.json();
    expect(status).toBe("thinking");
    await api.drain();

    const first = await get(`/v1/inquiries/${inquiry_id}`, u);
    expect(first.headers.get("x-ai-generated")).toBe("true");
    const asking = await first.json();
    expect(asking).toMatchObject({ status: "asking", goal: GOAL, max_questions: 6, planned: 2 });
    expect(asking.turns).toHaveLength(1);
    expect(asking.turns[0].question.trim()).not.toBe("");
    expect(asking.turns[0].answer).toBeUndefined();
    // Not shown until the master is done.
    expect(asking.understanding).toBeUndefined();

    const answers = `/v1/inquiries/${inquiry_id}/answers`;
    expect((await post(answers, { answer: "  " }, u)).status).toBe(400);
    expect((await post(answers, { answer: "答".repeat(301) }, u)).status).toBe(400);
    expect((await post(answers, { answer: "老板一直不给加薪" }, u)).status).toBe(202);
    await api.drain();
    const second = await (await get(`/v1/inquiries/${inquiry_id}`, u)).json();
    expect(second.status).toBe("asking");
    expect(second.turns.map((t: { answer?: string }) => t.answer)).toEqual([
      "老板一直不给加薪",
      undefined,
    ]);
    expect((await post(answers, { answer: "想找一份能多学东西的工作" }, u)).status).toBe(202);
    await api.drain();
    const ready = await (await get(`/v1/inquiries/${inquiry_id}`, u)).json();
    expect(ready.status).toBe("ready");
    expect(ready.turns).toHaveLength(2);
    expect(ready.closing.trim()).not.toBe("");
    expect(ready.understanding.trim()).not.toBe("");
    const over = await post(answers, { answer: "还有" }, u);
    expect(over.status).toBe(409);
    expect((await over.json()).code).toBe("inquiry_not_asking");

    const r = await post("/v1/reports", { chart_id, locale: "zh-Hans", inquiry_id }, u);
    expect(r.status).toBe(202);
    const { report_id } = await r.json();
    await api.drain();
    const view = await (await get(`/v1/reports/${report_id}`, u)).json();
    expect(view.status).toBe("passed");
    expect(view.inquiry_id).toBe(inquiry_id);
    const user = lastNarrative();
    expect(user).toContain("<inquiry>");
    expect(user.indexOf("老板一直不给加薪")).toBeLessThan(user.indexOf("想找一份能多学东西的工作"));
    expect(user).toContain(ready.understanding);

    const closed = await (await get(`/v1/inquiries/${inquiry_id}`, u)).json();
    expect(closed).toMatchObject({ status: "closed", report_id });
    const again = await post("/v1/reports", { chart_id, locale: "zh-Hans", inquiry_id }, u);
    expect(again.status).toBe(409);
    expect((await again.json()).code).toBe("inquiry_used");
    // Nobody else's.
    expect((await get(`/v1/inquiries/${inquiry_id}`, "iq-other")).status).toBe(404);
    // Deleting the reading deletes its conversation.
    const gone = await fetch(`${base}/v1/reports/${report_id}`, {
      method: "DELETE",
      headers: H(u),
    });
    expect((await gone.json()).deleted).toMatchObject({ reports: 1, inquiries: 1 });
    expect((await get(`/v1/inquiries/${inquiry_id}`, u)).status).toBe(404);
  });

  it("lets the user skip the rest: the unanswered question stays out of the reading", async () => {
    const u = "iq-skip";
    const chart_id = await chartOf(u);
    const { inquiry_id } = await (
      await post("/v1/inquiries", { chart_id, locale: "zh-Hans", goal: GOAL }, u)
    ).json();
    await api.drain();
    const { turns } = await (await get(`/v1/inquiries/${inquiry_id}`, u)).json();
    const r = await post("/v1/reports", { chart_id, locale: "zh-Hans", inquiry_id }, u);
    expect(r.status).toBe(202);
    await api.drain();
    const user = lastNarrative();
    expect(user).toContain(`<inquiry>`);
    expect(user).toContain(GOAL);
    expect(user).not.toContain(turns[0].question);
  });

  it("reads a conversation only with its own chart", async () => {
    const u = "iq-chart";
    const chart_id = await chartOf(u);
    const other = await chartOf(u);
    const { inquiry_id } = await (
      await post("/v1/inquiries", { chart_id, locale: "zh-Hans", goal: GOAL }, u)
    ).json();
    await api.drain();
    expect(
      (await post("/v1/reports", { chart_id: other, locale: "zh-Hans", inquiry_id }, u)).status,
    ).toBe(400);
    expect(
      (await post("/v1/reports", { chart_id, locale: "zh-Hans", inquiry_id }, "iq-stranger"))
        .status,
    ).toBe(404);
  });

  it("waits while the master thinks: 409 for an answer or a reading until its turn is in", async () => {
    // The mock answers at once (rule 37): this server's turns wait until released.
    let release!: () => void;
    const gate = new Promise<void>((r) => (release = r));
    const { s, url, close } = await serverWith(() => gate);
    const p = at(url);
    const chart_id = await chartOf("iq-slow", url);
    const { inquiry_id } = await (
      await p("/v1/inquiries", { chart_id, locale: "zh-Hans", goal: GOAL }, "iq-slow")
    ).json();
    const early = await p(`/v1/inquiries/${inquiry_id}/answers`, { answer: "嗯" }, "iq-slow");
    expect(early.status).toBe(409);
    expect((await early.json()).code).toBe("inquiry_thinking");
    const reading = await p("/v1/reports", { chart_id, locale: "zh-Hans", inquiry_id }, "iq-slow");
    expect(reading.status).toBe(409);
    expect((await reading.json()).code).toBe("inquiry_thinking");
    release();
    await s.drain();
    expect(
      (await p(`/v1/inquiries/${inquiry_id}/answers`, { answer: "嗯" }, "iq-slow")).status,
    ).toBe(202);
    await s.drain();
    await close();
  });

  it("fails when the first question can't come; a later failure only ends the questions", async () => {
    let calls = 0;
    const { s, url, close } = await serverWith(async () => {
      calls++;
      // The first inquiry's first turn, then the second inquiry's second turn.
      if (calls === 1 || calls === 3) throw new Error("boom");
    });
    const p = at(url);
    const g = (path: string) => fetch(url + path, { headers: H("iq-fail") });
    const chart_id = await chartOf("iq-fail", url);
    const failed = await (
      await p("/v1/inquiries", { chart_id, locale: "zh-Hans", goal: GOAL }, "iq-fail")
    ).json();
    await s.drain();
    const view = await (await g(`/v1/inquiries/${failed.inquiry_id}`)).json();
    expect(view.status).toBe("failed");
    expect(view.message).toContain("try again");
    const refused = await p(
      "/v1/reports",
      { chart_id, locale: "zh-Hans", inquiry_id: failed.inquiry_id },
      "iq-fail",
    );
    expect((await refused.json()).code).toBe("inquiry_failed");

    const later = await (
      await p("/v1/inquiries", { chart_id, locale: "zh-Hans", goal: GOAL }, "iq-fail")
    ).json();
    await s.drain();
    expect(
      (await p(`/v1/inquiries/${later.inquiry_id}/answers`, { answer: "嗯，是的" }, "iq-fail"))
        .status,
    ).toBe(202);
    await s.drain();
    const ended = await (await g(`/v1/inquiries/${later.inquiry_id}`)).json();
    // Ready with the one question it had: the reading goes on with what was said.
    expect(ended.status).toBe("ready");
    expect(ended.turns).toHaveLength(1);
    expect(calls).toBe(3);
    await close();
  });

  it("lists each reading with the question it was asked (同名重算)", async () => {
    const u = "iq-history";
    const chart = await (
      await post(
        "/v1/charts",
        { system: "tarot", spread: "three_card", question: "要不要换工作？" },
        u,
      )
    ).json();
    await post(
      "/v1/reports",
      { chart_id: chart.chart_id, locale: "zh-Hans", question: "要不要换工作？" },
      u,
    );
    await api.drain();
    const { items } = await (await get("/v1/reports", u)).json();
    expect(items[0].question).toBe("要不要换工作？");
  });
});
