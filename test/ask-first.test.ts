// v11.1.0 (the owner, 2026-10-29): 「求签和算卦 算法必须要有所问之问题之后才能去求。也就是说问题不能为空 是必须要有所求才能去求」,
// then 「塔罗牌也是一样」. 塔罗, 求签 and 算卦 are drawn only for a question; the reading answers that question. 每日一牌
// is the day's card, dealt without a draw; 八字 and 风水 are not drawn.
import { describe, expect, it } from "vitest";
import { MockProvider } from "../src/ai/index.js";
import { InMemoryStore } from "../src/api/store.js";
import { computeChart } from "../src/service/charts.js";
import { DRAW_KEY, FIXED_NOW, PEPPER } from "./helpers.js";
import { testApi } from "./api.js";

const mock = new MockProvider();
const store = new InMemoryStore();
let base = "";
const api = testApi(
  {
    providers: { deepseek: mock, anthropic: mock },
    store,
    review: false,
  },
  (b) => (base = b),
);

const H = (user: string, country = "HK") => ({
  "content-type": "application/json",
  "x-dev-country": country,
  "x-dev-user": user,
});
const post = (path: string, body: unknown, user: string, country?: string) =>
  fetch(base + path, { method: "POST", headers: H(user, country), body: JSON.stringify(body) });
const get = async (path: string, user: string) =>
  (await fetch(base + path, { headers: H(user) })).json();

const DRAWS = {
  tarot: { system: "tarot", spread: "three_card" },
  qiuqian: { system: "qiuqian" },
  liuyao: { system: "liuyao", mode: "auto", timezone: "Asia/Hong_Kong" },
} as const;
const ASKED = "明年要不要换工作？";

describe("塔罗, 求签 and 算卦 are drawn only for a question", () => {
  it("without one nothing is drawn: 400 question_required", async () => {
    const u = "no-question";
    for (const [system, draw] of Object.entries(DRAWS)) {
      for (const question of [undefined, "", "   \n ", 42]) {
        const res = await post("/v1/charts", { ...draw, question }, u);
        expect(res.status, `${system} ${JSON.stringify(question)}`).toBe(400);
        expect((await res.json()).code).toBe("question_required");
      }
    }
    // Nothing was drawn.
    expect((await get("/v1/charts", u)).items).toEqual([]);
  });

  it("with one, the draw keeps it (cut to 300 characters) and gives it back", async () => {
    const u = "asked";
    for (const draw of Object.values(DRAWS)) {
      const res = await post("/v1/charts", { ...draw, question: `  ${ASKED}  ` }, u);
      expect(res.status).toBe(201);
      const made = await res.json();
      expect(made.question).toBe(ASKED);
      expect((await get(`/v1/charts/${made.chart_id}`, u)).question).toBe(ASKED);
      // Never in the facts the model reads as the chart.
      expect(JSON.stringify(made.chart_fact)).not.toContain(ASKED);
    }
    // 350 characters asked: 300 kept.
    const long = await (
      await post("/v1/charts", { ...DRAWS.qiuqian, question: "问".repeat(350) }, u)
    ).json();
    expect([...long.question]).toHaveLength(300);
  });

  it("the Geo-Rule comes first: an unserved region is refused before the question is looked at", async () => {
    expect((await post("/v1/charts", DRAWS.tarot, "geo", "CN")).status).toBe(451);
  });

  it("八字 and 风水 aren't drawn: they need no question", async () => {
    const u = "not-drawn";
    const bazi = {
      system: "bazi",
      local: "1990-03-15T14:30",
      timezone: "Asia/Hong_Kong",
      longitude: 114.17,
      gender: "male",
    };
    const made = await post("/v1/charts", bazi, u);
    expect(made.status).toBe(201);
    expect((await made.json()).question).toBeUndefined();
    expect((await post("/v1/charts", { system: "fengshui", room: "bedroom" }, u)).status).toBe(201);
  });
});

describe("the reading answers the question the draw was asked", () => {
  it("whatever the reading request says", async () => {
    const u = "reads-asked";
    const { chart_id } = await (
      await post("/v1/charts", { ...DRAWS.tarot, question: ASKED }, u)
    ).json();
    const res = await post(
      "/v1/reports",
      { chart_id, locale: "zh-Hans", question: "另一个问题？" },
      u,
    );
    expect(res.status).toBe(202);
    await api.drain();
    expect((await get("/v1/reports", u)).items[0].question).toBe(ASKED);
    const narrative = mock.calls.filter((c) => c.agent === "narrative").at(-1)!;
    expect(narrative.user).toContain(ASKED);
    expect(narrative.user).not.toContain("另一个问题");
  });

  it("a chart drawn before v11.1.0, which kept none, reads with the request's question, and not without one", async () => {
    const u = "older-draw";
    const old = {
      id: "0a0a0a0a-0000-4000-8000-000000000001",
      owner: u,
      fact: computeChart(
        { system: "qiuqian" },
        { digestPepper: PEPPER, drawKey: DRAW_KEY },
        FIXED_NOW,
      ),
      created_at: FIXED_NOW().toISOString(),
    };
    await store.putChart(old);
    const without = await post("/v1/reports", { chart_id: old.id, locale: "zh-Hans" }, u);
    expect(without.status).toBe(400);
    expect((await without.json()).code).toBe("question_required");
    // A 深度分析 on it needs one too: its reading would.
    const talk = await post(
      "/v1/inquiries",
      { chart_id: old.id, locale: "zh-Hans", goal: "看看明年的事业" },
      u,
    );
    expect(talk.status).toBe(400);
    expect((await talk.json()).code).toBe("question_required");
    expect(
      (await post("/v1/reports", { chart_id: old.id, locale: "zh-Hans", question: ASKED }, u))
        .status,
    ).toBe(202);
    await api.drain();
    expect((await get("/v1/reports", u)).items[0].question).toBe(ASKED);
  });

  it("a 深度分析 on a drawn chart takes the question it was drawn for", async () => {
    const u = "talks-asked";
    const { chart_id } = await (
      await post("/v1/charts", { ...DRAWS.liuyao, question: ASKED }, u)
    ).json();
    const res = await post(
      "/v1/inquiries",
      { chart_id, locale: "zh-Hans", goal: "想知道该不该跳槽" },
      u,
    );
    expect(res.status).toBe(202);
    await api.drain();
    const inquiry = mock.calls.filter((c) => c.agent === "inquiry").at(-1)!;
    expect(inquiry.user).toContain(ASKED);
  });

  it("每日一牌 is the day's card, dealt without a draw: it is read without a question", async () => {
    const u = "daily";
    // This server keeps the real clock, and a card is dealt only for its today (within a day, by UTC).
    const today = new Date().toISOString().slice(0, 10);
    const { chart_id } = await get(`/v1/tarot/daily?date=${today}`, u);
    expect((await post("/v1/reports", { chart_id, locale: "zh-Hans" }, u)).status).toBe(202);
    await api.drain();
  });
});
