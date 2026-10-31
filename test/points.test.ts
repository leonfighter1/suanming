// S20 (docs/tech-plan.md, the owner's requests 2026-10-29): 积分. 10元 = 1000 积分 and more per 元 in the larger packs
// (「50快不是1250积分。是增加25%」「每多10块加5%」); every AI request paid at what it cost, with a margin of at least 50%
// (「保证利润在50%基础以上 … 看看有没有办法知道当前的提交问题给花费了多少，以此反馈到积分上去」); simulated for now, with 积分 for
// the dev accounts (「为了节省预算，我们可以暂时采用模拟策略。给所有dev给个相应的分数去进行计算」); one fee for the 深度分析's
// conversation (「对话了解阶段给一个统一的收费」).
import { randomBytes, randomUUID } from "node:crypto";
import { mkdtempSync, rmSync } from "node:fs";
import type { AddressInfo } from "node:net";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import {
  loadRouting,
  MockProvider,
  modelInfo,
  TOPICS_BY_SYSTEM,
  withModel,
  type AgentName,
  type AgentTrace,
  type LLMJsonRequest,
  type LLMProvider,
  type Usage,
} from "../src/ai/index.js";
import { createApiServer } from "../src/api/server.js";
import { publicPack } from "../src/api/views.js";
import { InMemoryStore, type Store } from "../src/api/store.js";
import { AuthService, type UserRecord } from "../src/auth/service.js";
import { TokenService } from "../src/auth/tokens.js";
import type { ChartSystem } from "../src/chart-fact/index.js";
import { PgStore } from "../src/db/pg-store.js";
import {
  chargeFor,
  checkPointsConfig,
  inquiryFee,
  loadPointsConfig,
  measuredCost,
  pointsFor,
  pointsPerUsd,
  pointValueCny,
  quote,
  withPacks,
  type ChargeKind,
  type Pack,
  type PointsFor,
  type QuoteFor,
} from "../src/points/index.js";
import { DEV_ACCOUNTS, grantDevPoints, pointsOn, seedDevAccounts } from "../src/service/runtime.js";
import { DRAW_KEY, PEPPER } from "./helpers.js";

const config = loadPointsConfig();
const routing = loadRouting();
const PG = 30_000;
const at = (minute: number) => `2026-10-29T00:${String(minute).padStart(2, "0")}:00.000Z`;
const trace = (model: string, usage: Usage): AgentTrace => ({
  agent: "narrative",
  prompt_version: "narrative_bazi@9",
  model,
  attempts: 1,
  usage,
  problems: [],
});

describe("the price of a request (WP20.1)", () => {
  it("the packs are the owner's: 100 积分 a 元, 5% more for each 10元 from 20元 up, 25% at 50元", () => {
    // 10元 = 1000; 20元 = 2000 × 1.10 = 2200; 30元 = 3000 × 1.15 = 3450; 40元 = 4000 × 1.20 = 4800;
    // 50元 = 5000 × 1.25 = 6250 (the owner corrected 1250 to +25%).
    expect(config.packs).toEqual([
      { yuan: 10, points: 1000 },
      { yuan: 20, points: 2200 },
      { yuan: 30, points: 3450 },
      { yuan: 40, points: 4800 },
      { yuan: 50, points: 6250 },
    ]);
    expect(config.packs.map((p) => publicPack(p).bonus_percent)).toEqual([0, 10, 15, 20, 25]);
    expect(checkPointsConfig(config, Object.keys(TOPICS_BY_SYSTEM) as ChartSystem[])).toEqual([]);
    expect(config.dev_grant).toBe(10_000);
  });

  it("1,953.96 积分 a dollar of tokens keeps a 50% margin even on the cheapest 积分", () => {
    // The 50元 pack's 积分, after the 0.6% payment fee and 6% VAT: 50 × (1 − 0.006 − 0.06) / 6250 = 46.7 / 6250 =
    // 0.007472 元. A dollar of tokens is 7.3 元; at a 50% margin it must bring 7.3 / 0.5 = 14.6 元: 14.6 / 0.007472 =
    // 1,953.96 积分.
    expect(pointValueCny(config)).toBeCloseTo(0.007472, 9);
    expect(pointsPerUsd(config)).toBeCloseTo(1953.9615, 3);
    for (const usd of [0.0001, 0.05, 0.352, 1, 7.77]) {
      const revenue = pointsFor(config, usd) * pointValueCny(config);
      expect(revenue, String(usd)).toBeGreaterThanOrEqual(usd * 7.3 * 2 - 1e-9);
    }
    // Rounded up, and a whole number stays whole: 1 积分's worth of dollars is 1 积分.
    expect(pointsFor(config, 1 / pointsPerUsd(config))).toBe(1);
  });

  it("设置's packs (S32): read at each use, the config's own while the panel has none; the margin follows the best", () => {
    let panel: Pack[] | undefined;
    const c = withPacks(config, () => panel);
    expect(c.packs).toEqual(config.packs);
    expect(pointsPerUsd(c)).toBe(pointsPerUsd(config));
    // A pack of 150 积分 a 元: each 积分 is worth less, so a dollar of tokens takes more of them, the margin kept.
    panel = [
      { yuan: 10, points: 1000 },
      { yuan: 100, points: 15_000 },
    ];
    expect(c.packs).toEqual(panel);
    expect(pointValueCny(c)).toBeCloseTo((1 - 0.006 - 0.06) / 150, 9);
    expect(pointsPerUsd(c)).toBeGreaterThan(pointsPerUsd(config));
    const usd = 0.352;
    expect(pointsFor(c, usd) * pointValueCny(c)).toBeGreaterThanOrEqual(usd * 7.3 * 2 - 1e-9);
    panel = undefined;
    expect(c.packs).toEqual(config.packs);
  });

  it("prices each request from its estimate at Claude Opus 5.5 ($4 / $20 a million), and holds 1.5 times that", () => {
    const q = (kind: ChargeKind, what?: QuoteFor) => quote(config, routing, kind, what);
    // 八字, six topics: 8,000 in, 5,500 + 6 × 1,750 = 16,000 out: $0.032 + $0.32 = $0.352 × 1953.96 = 687.79 → 688;
    // held 688 × 1.5 = 1032.
    expect(q("report", { system: "bazi", topics: 6 })).toEqual({ points: 688, hold: 1032 });
    // One topic: 8,000 in, 7,250 out: $0.032 + $0.145 = $0.177 → 345.85 → 346; held 519.
    expect(q("report", { system: "bazi", topics: 1 })).toEqual({ points: 346, hold: 519 });
    // 塔罗 grows with its cards: one card 9,440 in / 8,820 out = $0.03776 + $0.1764 = $0.21416 → 418.46 → 419;
    // three 10,720 / 9,860 = $0.24008 → 469.11 → 470; ten 15,200 / 13,500 = $0.3308 → 646.37 → 647.
    expect(q("report", { system: "tarot", cards: 1 }).points).toBe(419);
    expect(q("report", { system: "tarot", cards: 3 })).toEqual({ points: 470, hold: 705 });
    expect(q("report", { system: "tarot", cards: 10 }).points).toBe(647);
    // 求签 7,000 / 7,000 = $0.168 → 328.27 → 329; 算卦 8,000 / 8,000 = $0.192 → 375.16 → 376; 风水 6,800 / 7,000 =
    // $0.1672 → 326.70 → 327.
    expect(q("report", { system: "qiuqian" }).points).toBe(329);
    expect(q("report", { system: "liuyao" }).points).toBe(376);
    expect(q("report", { system: "fengshui" }).points).toBe(327);
    // 一生运势报告 24,500 / 26,000 = $0.098 + $0.52 = $0.618 → 1207.55 → 1208; held 1812.
    expect(q("life_report")).toEqual({ points: 1208, hold: 1812 });
    // 追问 on 八字 17,000 / 3,500 = $0.138 → 269.65 → 270 (held 405); on a 一生运势报告 25,000 / 3,500 = $0.17 → 332.17
    // → 333 (held 499.5 → 500); on 塔罗 8,000 / 3,000 = $0.092 → 179.76 → 180.
    expect(q("followup", { system: "bazi", parent: "report" })).toEqual({ points: 270, hold: 405 });
    expect(q("followup", { system: "bazi", parent: "life_report" })).toEqual({
      points: 333,
      hold: 500,
    });
    expect(q("followup", { system: "tarot", parent: "report" }).points).toBe(180);
    // 破除运势 plans: 八字 8,700 / 6,000 = $0.1548 → 302.47 → 303 (held 454.5 → 455); 塔罗 4,500 / 5,000 = $0.118 →
    // 230.57 → 231.
    expect(q("remedy", { system: "bazi" })).toEqual({ points: 303, hold: 455 });
    expect(q("remedy", { system: "tarot" }).points).toBe(231);
  });

  it("the 深度分析's 统一收费: five typical turns and one at its largest, held as it is", () => {
    // A turn 6,200 in / 1,500 out = $0.0248 + $0.03 = $0.0548; the largest 7,000 / 4,000 = $0.028 + $0.08 = $0.108;
    // 5 × 0.0548 + 0.108 = $0.382 → 746.41 → 747. What its turns may spend: 747 / 1953.96 = $0.3823.
    expect(quote(config, routing, "inquiry")).toEqual({ points: 747, hold: 747 });
    const fee = inquiryFee(config, routing);
    expect(fee.turnUsd).toBeCloseTo(0.0548, 9);
    expect(fee.budgetUsd).toBeCloseTo(0.3823, 4);
  });

  it("follows the model the routing names now: ACTIVE_AI_MODEL moves every price (rule 66)", () => {
    const bazi = { system: "bazi" as const, topics: 6 };
    // Claude Sonnet 5.5, $2 / $10: 8,000 × 2 + 16,000 × 10 = $0.176 → 343.90 → 344.
    const sonnet = withModel(routing, modelInfo("claude-sonnet-5-5")!);
    expect(quote(config, sonnet, "report", bazi).points).toBe(344);
    // Claude Haiku 5.5, $0.10 / $0.50: $0.0008 + $0.008 = $0.0088 → 17.19 → 18.
    expect(
      quote(config, withModel(routing, modelInfo("claude-haiku-5-5")!), "report", bazi).points,
    ).toBe(18);
    // The owner's .env names claude-opus-5-5, the table's own model: the prices stay.
    expect(
      quote(config, withModel(routing, modelInfo("claude-opus-5-5")!), "report", bazi).points,
    ).toBe(688);
    // A model without a list price is priced as Claude Opus 5.5.
    expect(
      quote(config, withModel(routing, modelInfo("deepseek-v4-pro")!), "report", bazi).points,
    ).toBe(688);
  });

  it("measures what a job cost, and charges that, never more than was held", () => {
    const opus = trace("claude-opus-5-5", { input_tokens: 10_000, output_tokens: 15_000 });
    // $0.04 + $0.30 = $0.34 → 664.35 → 665.
    expect(measuredCost(config, [opus])).toEqual({ usd: 0.34, tokens: 25_000 });
    expect(chargeFor(config, { points: 1032, quote: 688 }, [opus])).toEqual({
      points: 665,
      basis: "measured",
      usd: 0.34,
    });
    // Cache reads at $0.20 and writes at $5: 2,000 × 4 + 1,000 × 20 + 50,000 × 0.2 + 4,000 × 5 = 58,000 → $0.058.
    const cached = trace("claude-opus-5-5", {
      input_tokens: 2_000,
      output_tokens: 1_000,
      cache_read_input_tokens: 50_000,
      cache_creation_input_tokens: 4_000,
    });
    expect(measuredCost(config, [cached]).usd).toBeCloseTo(0.058, 9);
    // A model without a price is priced as the reference model; steps add up.
    const deepseek = trace("deepseek-v4-pro", { input_tokens: 10_000, output_tokens: 15_000 });
    expect(measuredCost(config, [opus, deepseek]).usd).toBeCloseTo(0.68, 9);
    // More than was held: the hold is the most it is charged.
    expect(chargeFor(config, { points: 500, quote: 400 }, [opus]).points).toBe(500);
    // The mock reports no tokens: its quote is charged (模拟), never more than was held.
    const mock = trace("mock/claude-opus-5-5", { input_tokens: 0, output_tokens: 0 });
    expect(chargeFor(config, { points: 1032, quote: 688 }, [mock])).toEqual({
      points: 688,
      basis: "estimate",
    });
    expect(chargeFor(config, { points: 600, quote: 688 }, [mock]).points).toBe(600);
  });
});

// ---- the ledger, in both stores ----

const KEK = randomBytes(32);
const account = (id: string): UserRecord => ({
  id,
  email: `${id.slice(0, 8)}@example.com`,
  email_lookup: randomBytes(32).toString("hex"),
  password_hash: "$argon2id$v=19$m=19456,t=2,p=1$test",
  social: {},
  country: "HK",
  locale: "zh-Hans",
  age_confirmed_at: at(0),
  created_at: at(0),
});
const STORES: [
  string,
  () => Promise<{ store: Store; owner: () => Promise<string>; close: () => Promise<void> }>,
][] = [
  [
    "memory",
    async () => ({
      store: new InMemoryStore(),
      owner: async () => randomUUID(),
      close: async () => {},
    }),
  ],
  [
    "database",
    async () => {
      const pg = await PgStore.open({ kek: KEK, pepper: PEPPER });
      return {
        store: pg,
        // A row needs its account.
        owner: async () => {
          const id = randomUUID();
          await pg.put(account(id));
          return id;
        },
        close: () => pg.close(),
      };
    },
  ],
];
const forReading = (system = "bazi"): PointsFor => ({ kind: "report", id: randomUUID(), system });

describe.each(STORES)("the ledger in %s (WP20.2)", (_name, make) => {
  it(
    "holds what a request may cost, charges what it cost, and frees the rest",
    async () => {
      const { store, owner, close } = await make();
      const o = await owner();
      expect(await store.pointsOf(o)).toEqual({ balance: 0, held: 0 });
      expect(await store.holdPoints(o, 100, 150, forReading(), at(1))).toBeUndefined();
      const topUp = await store.creditPoints(
        o,
        1000,
        { kind: "topup", pack: { yuan: 10, points: 1000 } },
        at(2),
      );
      expect(topUp).toMatchObject({
        kind: "topup",
        points: 1000,
        balance: 1000,
        pack: { yuan: 10 },
      });
      const what = forReading();
      const first = (await store.holdPoints(o, 300, 450, what, at(3)))!;
      expect(first).toMatchObject({ owner: o, points: 450, quote: 300, for: what });
      expect(await store.pointsOf(o)).toEqual({ balance: 1000, held: 450 });
      // 1000 − 450 = 550 available: not enough for 600, enough for 500 (which takes all 550, not its 750).
      expect(await store.holdPoints(o, 600, 900, forReading(), at(4))).toBeUndefined();
      const second = (await store.holdPoints(o, 500, 750, forReading(), at(5)))!;
      expect(second.points).toBe(550);
      expect(await store.pointsOf(o)).toEqual({ balance: 1000, held: 1000 });
      expect((await store.listHolds(o)).map((h) => h.id).sort()).toEqual(
        [first.id, second.id].sort(),
      );

      const charged = await store.settlePoints(
        first,
        { points: 320, basis: "measured", usd: 0.1638 },
        at(6),
      );
      expect(charged).toMatchObject({
        kind: "charge",
        points: -320,
        balance: 680,
        for: what,
        basis: "measured",
        usd: 0.1638,
      });
      // Settled once: again, nothing happens.
      expect(
        await store.settlePoints(first, { points: 320, basis: "measured" }, at(7)),
      ).toBeUndefined();
      // A job that delivered nothing frees all it held.
      expect(await store.settlePoints(second, undefined, at(8))).toBeUndefined();
      expect(await store.pointsOf(o)).toEqual({ balance: 680, held: 0 });
      expect(await store.listHolds(o)).toEqual([]);
      expect((await store.listPoints(o, 10)).map((e) => [e.kind, e.points, e.balance])).toEqual([
        ["charge", -320, 680],
        ["topup", 1000, 1000],
      ]);
      await close();
    },
    PG,
  );

  it(
    "two requests at once never hold the same 积分",
    async () => {
      const { store, owner, close } = await make();
      const o = await owner();
      await store.creditPoints(o, 1000, { kind: "topup", pack: { yuan: 10, points: 1000 } }, at(1));
      const pair = await Promise.all([
        store.holdPoints(o, 600, 600, forReading(), at(2)),
        store.holdPoints(o, 600, 600, forReading(), at(2)),
      ]);
      expect(pair.filter(Boolean)).toHaveLength(1);
      await store.settlePoints(pair.find(Boolean)!, undefined, at(3));
      // Ten at once, 100 each, from 1000: all ten, and then nothing is left.
      const ten = await Promise.all(
        Array.from({ length: 10 }, () => store.holdPoints(o, 100, 100, forReading(), at(4))),
      );
      expect(ten.every(Boolean)).toBe(true);
      expect(await store.pointsOf(o)).toEqual({ balance: 1000, held: 1000 });
      expect(await store.holdPoints(o, 1, 1, forReading(), at(5))).toBeUndefined();
      await close();
    },
    PG,
  );

  it(
    "a grant is given once per reason; deleting the account takes every change and hold",
    async () => {
      const { store, owner, close } = await make();
      const [o, other] = [await owner(), await owner()];
      const grant = { kind: "grant" as const, reason: "dev" };
      expect(await store.creditPoints(o, 10_000, grant, at(1))).toMatchObject({
        kind: "grant",
        points: 10_000,
        balance: 10_000,
        reason: "dev",
      });
      expect(await store.creditPoints(o, 10_000, grant, at(2))).toBeUndefined();
      await store.creditPoints(other, 10_000, grant, at(2));
      await store.holdPoints(o, 688, 1032, forReading(), at(3));
      expect(await store.pointsOf(o)).toEqual({ balance: 10_000, held: 1032 });
      expect((await store.deleteOwnerData(o)).points).toBe(1);
      expect(await store.pointsOf(o)).toEqual({ balance: 0, held: 0 });
      expect(await store.listPoints(o, 10)).toEqual([]);
      expect(await store.listHolds(o)).toEqual([]);
      // Another account's stay.
      expect(await store.pointsOf(other)).toEqual({ balance: 10_000, held: 0 });
      await close();
    },
    PG,
  );
});

describe("the ledger in the database, across a restart (WP20.2)", () => {
  it(
    "keeps every balance and change, and opens with nothing held: no job survives a restart",
    async () => {
      const dataDir = mkdtempSync(join(tmpdir(), "mingli-points-"));
      try {
        const first = await PgStore.open({ dataDir, kek: KEK, pepper: PEPPER });
        const o = randomUUID();
        await first.put(account(o));
        await first.creditPoints(
          o,
          6250,
          { kind: "topup", pack: { yuan: 50, points: 6250 } },
          at(1),
        );
        await first.holdPoints(o, 688, 1032, forReading(), at(2));
        expect(await first.pointsOf(o)).toEqual({ balance: 6250, held: 1032 });
        await first.close();

        const again = await PgStore.open({ dataDir, kek: KEK, pepper: PEPPER });
        expect(await again.pointsOf(o)).toEqual({ balance: 6250, held: 0 });
        expect(await again.listHolds(o)).toEqual([]);
        expect((await again.listPoints(o, 10)).map((e) => e.points)).toEqual([6250]);
        await again.close();
      } finally {
        rmSync(dataDir, { recursive: true, force: true });
      }
    },
    PG,
  );
});

// ---- the API ----

/** Answers as the mock does; the steps named in [usage] report those tokens on Claude Opus 5.5. */
function billed(usage: Partial<Record<AgentName, Usage>>, inner = new MockProvider()): LLMProvider {
  return {
    name: "billed",
    async generateJson(req: LLMJsonRequest) {
      const r = await inner.generateJson(req);
      const u = usage[req.agent];
      return u ? { ...r, model: "claude-opus-5-5", usage: u } : r;
    },
  };
}

const birth = {
  system: "bazi",
  local: "1990-03-15T14:30",
  timezone: "Asia/Hong_Kong",
  longitude: 114.17,
  gender: "male",
};
const GOAL = "明年要不要换工作，感情上要注意什么";

/** A server with 积分 on (simulated 充值) unless `points: false`; content review paused, as the owner runs it. */
async function serve(
  o: {
    provider?: LLMProvider;
    points?: false | { simulateTopUp?: boolean };
    aiQuota?: { perUserPerDay: number; totalPerDay: number };
  } = {},
) {
  const provider = o.provider ?? new MockProvider();
  const store = new InMemoryStore();
  const s = createApiServer({
    secrets: { digestPepper: PEPPER, drawKey: DRAW_KEY },
    // Under every provider key (rule 63).
    providers: { deepseek: provider, anthropic: provider },
    devMode: true,
    store,
    review: false,
    ...(o.points !== false && { points: { simulateTopUp: true, ...o.points } }),
    ...(o.aiQuota && { aiQuota: o.aiQuota }),
    log: () => {},
  });
  await new Promise<void>((r) => s.listen(0, "127.0.0.1", r));
  const url = `http://127.0.0.1:${(s.address() as AddressInfo).port}`;
  const H = (user: string) => ({
    "content-type": "application/json",
    "x-dev-country": "HK",
    "x-dev-user": user,
  });
  const post = (path: string, body: unknown, user: string) =>
    fetch(url + path, { method: "POST", headers: H(user), body: JSON.stringify(body) });
  const get = async (path: string, user: string) =>
    (await fetch(url + path, { headers: H(user) })).json();
  const chart = async (user: string, body: unknown = birth) =>
    ((await (await post("/v1/charts", body, user)).json()) as { chart_id: string }).chart_id;
  const topUp = (user: string, yuan: number) => post("/v1/points/top-ups", { yuan }, user);
  const points = (user: string) => get("/v1/points", user);
  return {
    s,
    store,
    url,
    post,
    get,
    chart,
    topUp,
    points,
    close: () => new Promise<void>((r) => s.close(() => r())),
  };
}

const bazi6 = { locale: "zh-Hans" };

describe("charging every AI request (WP20.3)", () => {
  it("with 积分 off nothing is charged, nothing is offered, and plans are preloaded as before", async () => {
    const api = await serve({ points: false });
    expect(await api.points("off")).toEqual({ enabled: false });
    expect((await api.get("/v1/health", "off")).points).toBe("off");
    const chart_id = await api.chart("off");
    const r = await api.post("/v1/reports", { chart_id, ...bazi6 }, "off");
    expect(r.status).toBe(202);
    const { report_id } = await r.json();
    await api.s.drain();
    // Positive anchor for the next test's "no preload" (rule 43).
    expect((await api.store.listRemedies(report_id)).length).toBeGreaterThan(0);
    expect((await api.topUp("off", 50)).status).toBe(404);
    expect(
      (
        await fetch(`${api.url}/v1/charts/${chart_id}/quote`, {
          headers: { "x-dev-country": "HK", "x-dev-user": "off" },
        })
      ).status,
    ).toBe(404);
    await api.close();
  });

  it("a request needs its price: 402 points_short before anything is made or any daily cap taken", async () => {
    const api = await serve({ aiQuota: { perUserPerDay: 1, totalPerDay: 10 } });
    const u = "short";
    const chart_id = await api.chart(u);
    const refused = await api.post("/v1/reports", { chart_id, ...bazi6 }, u);
    expect(refused.status).toBe(402);
    expect(await refused.json()).toMatchObject({ code: "points_short", need: 688, available: 0 });
    expect((await api.get("/v1/reports", u)).items).toEqual([]);
    // The cap is still whole: after a 10元 top-up the one reading a day goes ahead.
    expect((await api.topUp(u, 10)).status).toBe(201);
    expect((await api.post("/v1/reports", { chart_id, ...bazi6 }, u)).status).toBe(202);
    await api.s.drain();
    // The cap refuses the next: what it would have held is free again.
    await api.topUp(u, 50);
    const before = await api.points(u);
    expect((await api.post("/v1/reports", { chart_id, ...bazi6 }, u)).status).toBe(429);
    expect(await api.points(u)).toMatchObject({ balance: before.balance, held: 0 });
    await api.close();
  });

  it("charges what the reading cost, measured from its tokens; the cost shows while 充值 is simulated", async () => {
    // The 八字 reading's one step reports 10,000 in and 15,000 out: $0.34 → 665 of the 6250 a 50元 pack brings.
    const api = await serve({
      provider: billed({ narrative: { input_tokens: 10_000, output_tokens: 15_000 } }),
    });
    const u = "measured";
    await api.topUp(u, 50);
    const chart_id = await api.chart(u);
    const { report_id } = await (await api.post("/v1/reports", { chart_id, ...bazi6 }, u)).json();
    await api.s.drain();
    const p = await api.points(u);
    // 6250 − 665 = 5585.
    expect(p).toMatchObject({
      enabled: true,
      balance: 5585,
      held: 0,
      available: 5585,
      top_up: "simulated",
    });
    expect(p.entries[0]).toMatchObject({
      kind: "charge",
      points: -665,
      balance: 5585,
      for: { kind: "report", id: report_id, system: "bazi" },
      basis: "measured",
      usd: 0.34,
    });
    expect(p.entries[1]).toMatchObject({
      kind: "topup",
      points: 6250,
      pack: { yuan: 50, points: 6250 },
    });
    expect(p.packs.map((x: { bonus_percent: number }) => x.bonus_percent)).toEqual([
      0, 10, 15, 20, 25,
    ]);
    expect((await api.get("/v1/health", u)).points).toBe("simulated");
    await api.close();
  });

  it("while the mock answers, a reading is charged its estimate (模拟); never more than was held", async () => {
    const mock = await serve();
    await mock.topUp("sim", 50);
    const chart_id = await mock.chart("sim");
    await mock.post("/v1/reports", { chart_id, ...bazi6 }, "sim");
    await mock.s.drain();
    // 6250 − 688 = 5562.
    const p = await mock.points("sim");
    expect(p.balance).toBe(5562);
    expect(p.entries[0]).toMatchObject({ points: -688, basis: "estimate" });
    expect(p.entries[0].usd).toBeUndefined();
    await mock.close();

    // 100,000 in and out: $0.4 + $2 = $2.40 → 4690, more than the 1032 held: 1032 is charged.
    const big = await serve({
      provider: billed({ narrative: { input_tokens: 100_000, output_tokens: 100_000 } }),
    });
    await big.topUp("big", 50);
    await big.post("/v1/reports", { chart_id: await big.chart("big"), ...bazi6 }, "big");
    await big.s.drain();
    expect((await big.points("big")).balance).toBe(6250 - 1032);
    await big.close();
  });

  it("a reading that failed, or was deleted while it ran, costs nothing", async () => {
    const failing: LLMProvider = {
      name: "down",
      generateJson: async () => {
        throw new Error("upstream down");
      },
    };
    const api = await serve({ provider: failing });
    await api.topUp("fail", 10);
    const chart_id = await api.chart("fail");
    const { report_id } = await (
      await api.post("/v1/reports", { chart_id, ...bazi6 }, "fail")
    ).json();
    await api.s.drain();
    expect((await api.get(`/v1/reports/${report_id}`, "fail")).status).toBe("failed");
    const p = await api.points("fail");
    expect(p).toMatchObject({ balance: 1000, held: 0 });
    expect(p.entries.map((e: { kind: string }) => e.kind)).toEqual(["topup"]);
    await api.close();

    // Rule 37: the mock answers at once, so this one waits until released.
    let release!: () => void;
    const gate = new Promise<void>((r) => (release = r));
    const mock = new MockProvider();
    const slow = await serve({
      provider: {
        name: "gated",
        generateJson: async (req) => {
          await gate;
          return mock.generateJson(req);
        },
      },
    });
    await slow.topUp("gone", 10);
    const c2 = await slow.chart("gone");
    const r2 = await (await slow.post("/v1/reports", { chart_id: c2, ...bazi6 }, "gone")).json();
    // Held while it runs: all of the 1000, since 1032 is more than there is.
    expect(await slow.points("gone")).toMatchObject({ balance: 1000, held: 1000, available: 0 });
    expect((await slow.points("gone")).holds).toEqual([
      expect.objectContaining({
        points: 1000,
        for: { kind: "report", id: r2.report_id, system: "bazi" },
      }),
    ]);
    // Nothing is left for a second request meanwhile.
    expect((await slow.post("/v1/reports", { chart_id: c2, ...bazi6 }, "gone")).status).toBe(402);
    const del = await fetch(`${slow.url}/v1/reports/${r2.report_id}`, {
      method: "DELETE",
      headers: { "x-dev-country": "HK", "x-dev-user": "gone" },
    });
    expect(del.status).toBe(200);
    release();
    await slow.s.drain();
    expect(await slow.points("gone")).toMatchObject({ balance: 1000, held: 0 });
    await slow.close();
  });

  it("追问, 一生运势报告 and plans are charged too; with 积分 a plan is made when bought, never preloaded", async () => {
    const api = await serve();
    const u = "all";
    await api.topUp(u, 50);
    const chart_id = await api.chart(u);
    const { report_id } = await (await api.post("/v1/reports", { chart_id, ...bazi6 }, u)).json();
    await api.s.drain();
    // No preload: the plans list is empty until one is bought, and says what one costs.
    const plans = await api.get(`/v1/reports/${report_id}/remedies`, u);
    expect(plans.items).toEqual([]);
    expect(plans.points).toEqual({ points: 303, hold: 455 });
    expect(await api.store.listRemedies(report_id)).toEqual([]);
    const bought = await api.post(
      `/v1/reports/${report_id}/remedies`,
      { topic: "career_wealth" },
      u,
    );
    expect(bought.status).toBe(202);
    expect((await bought.json()).payment).toEqual({ status: "points" });
    await api.s.drain();

    const asked = await api.get(`/v1/reports/${report_id}/followups`, u);
    expect(asked.price).toEqual({ points: 270, hold: 405 });
    expect(
      (
        await api.post(
          `/v1/reports/${report_id}/followups`,
          { question: "我适合什么样的工作？" },
          u,
        )
      ).status,
    ).toBe(202);
    await api.s.drain();
    const life = await api.post("/v1/life-reports", { chart_id, locale: "zh-Hans" }, u);
    expect(life.status).toBe(202);
    const { life_report_id } = await life.json();
    await api.s.drain();
    expect((await api.get(`/v1/life-reports/${life_report_id}/followups`, u)).price).toEqual({
      points: 333,
      hold: 500,
    });

    // 6250 − 688 − 303 − 270 − 1208 = 3781.
    const p = await api.points(u);
    expect(p.balance).toBe(3781);
    expect(
      p.entries.map((e: { for?: { kind: string }; points: number }) => [e.for?.kind, e.points]),
    ).toEqual([
      ["life_report", -1208],
      ["followup", -270],
      ["remedy", -303],
      ["report", -688],
      [undefined, 6250],
    ]);
    await api.close();
  });

  it("the 深度分析 is paid once, its 统一收费, after its first question; the reading after it as any reading", async () => {
    const api = await serve();
    const u = "talk";
    await api.topUp(u, 10);
    const chart_id = await api.chart(u);
    const started = await api.post("/v1/inquiries", { chart_id, locale: "zh-Hans", goal: GOAL }, u);
    expect(started.status).toBe(202);
    const { inquiry_id } = await started.json();
    await api.s.drain();
    // 1000 − 747 = 253.
    expect((await api.points(u)).balance).toBe(253);
    for (const answer of ["想换，但怕不稳定", "最近和太太常吵架"]) {
      expect((await api.post(`/v1/inquiries/${inquiry_id}/answers`, { answer }, u)).status).toBe(
        202,
      );
      await api.s.drain();
    }
    expect((await api.get(`/v1/inquiries/${inquiry_id}`, u)).status).toBe("ready");
    const p = await api.points(u);
    expect(p.balance).toBe(253);
    expect(p.entries[0]).toMatchObject({
      points: -747,
      basis: "flat",
      for: { kind: "inquiry", id: inquiry_id, system: "bazi" },
    });
    // The reading is paid on its own: 253 doesn't cover its 688.
    const reading = await api.post("/v1/reports", { chart_id, ...bazi6, inquiry_id }, u);
    expect(reading.status).toBe(402);
    await api.topUp(u, 10);
    expect((await api.post("/v1/reports", { chart_id, ...bazi6, inquiry_id }, u)).status).toBe(202);
    await api.s.drain();
    // 253 + 1000 − 688 = 565.
    expect((await api.points(u)).balance).toBe(565);
    await api.close();
  });

  it("a 深度分析 whose first question never came costs nothing", async () => {
    const inner = new MockProvider();
    const api = await serve({
      provider: {
        name: "no-questions",
        generateJson: async (req) => {
          if (req.agent === "inquiry") throw new Error("upstream down");
          return inner.generateJson(req);
        },
      },
    });
    await api.topUp("nq", 10);
    const chart_id = await api.chart("nq");
    const { inquiry_id } = await (
      await api.post("/v1/inquiries", { chart_id, locale: "zh-Hans", goal: GOAL }, "nq")
    ).json();
    await api.s.drain();
    expect((await api.get(`/v1/inquiries/${inquiry_id}`, "nq")).status).toBe("failed");
    expect(await api.points("nq")).toMatchObject({ balance: 1000, held: 0 });
    await api.close();
  });

  it("a turn its fee can't carry at the margin is not asked for: the conversation closes and the reading goes on", async () => {
    // Each question 30,000 in and 10,000 out: $0.12 + $0.20 = $0.32. The fee, 747, allows $0.3823 at the margin:
    // after the first, $0.32 + another $0.32 would pass it, so the master asks no second question.
    const inner = new MockProvider();
    const calls: string[] = [];
    const costly = billed({ inquiry: { input_tokens: 30_000, output_tokens: 10_000 } }, inner);
    const api = await serve({
      provider: {
        name: "costly",
        generateJson: (req) => {
          calls.push(req.agent);
          return costly.generateJson(req);
        },
      },
    });
    const u = "costly";
    await api.topUp(u, 50);
    const chart_id = await api.chart(u);
    const { inquiry_id } = await (
      await api.post("/v1/inquiries", { chart_id, locale: "zh-Hans", goal: GOAL }, u)
    ).json();
    await api.s.drain();
    expect((await api.get(`/v1/inquiries/${inquiry_id}`, u)).status).toBe("asking");
    await api.post(`/v1/inquiries/${inquiry_id}/answers`, { answer: "想换，但怕不稳定" }, u);
    await api.s.drain();
    const closed = await api.get(`/v1/inquiries/${inquiry_id}`, u);
    expect(closed.status).toBe("ready");
    expect(closed.turns).toHaveLength(1);
    expect(calls.filter((a) => a === "inquiry")).toHaveLength(1);
    // Paid once: 6250 − 747 = 5503, and the reading goes ahead.
    expect((await api.points(u)).balance).toBe(5503);
    expect((await api.post("/v1/reports", { chart_id, ...bazi6, inquiry_id }, u)).status).toBe(202);
    await api.s.drain();
    await api.close();

    // A cheap question ($0.02 + $0.02 = $0.04) leaves room: the master asks its second, then closes (three turns).
    const cheapCalls: string[] = [];
    const cheap = billed({ inquiry: { input_tokens: 5_000, output_tokens: 1_000 } });
    const ok = await serve({
      provider: {
        name: "cheap",
        generateJson: (req) => {
          cheapCalls.push(req.agent);
          return cheap.generateJson(req);
        },
      },
    });
    await ok.topUp(u, 10);
    const c2 = await ok.chart(u);
    const { inquiry_id: id2 } = await (
      await ok.post("/v1/inquiries", { chart_id: c2, locale: "zh-Hans", goal: GOAL }, u)
    ).json();
    await ok.s.drain();
    for (const answer of ["想换，但怕不稳定", "最近和太太常吵架"]) {
      await ok.post(`/v1/inquiries/${id2}/answers`, { answer }, u);
      await ok.s.drain();
    }
    const done = await ok.get(`/v1/inquiries/${id2}`, u);
    expect(done.status).toBe("ready");
    expect(done.turns).toHaveLength(2);
    expect(cheapCalls.filter((a) => a === "inquiry")).toHaveLength(3);
    await ok.close();
  });

  it("a chart's quote says what each request on it costs", async () => {
    const api = await serve();
    const u = "quote";
    const bazi = await api.chart(u);
    expect(await api.get(`/v1/charts/${bazi}/quote`, u)).toEqual({
      report: { points: 688, hold: 1032 },
      inquiry: { points: 747, hold: 747, max_questions: 6 },
      life_report: { points: 1208, hold: 1812 },
    });
    // The topics asked: one is 346 (held 519); an unknown one counts for nothing.
    expect((await api.get(`/v1/charts/${bazi}/quote?topics=wuxing,nonsense`, u)).report).toEqual({
      points: 346,
      hold: 519,
    });
    const tarot = await api.chart(u, {
      system: "tarot",
      spread: "three_card",
      question: "最近的工作会顺利吗？",
    });
    const t = await api.get(`/v1/charts/${tarot}/quote`, u);
    expect(t.report).toEqual({ points: 470, hold: 705 });
    expect(t.inquiry.points).toBe(747);
    expect(t.life_report).toBeUndefined();
    // Someone else's chart is not there.
    expect((await api.get(`/v1/charts/${bazi}/quote`, "stranger")).status).toBe(404);
    await api.close();
  });

  it("充值: the owner's packs, simulated in development only", async () => {
    const api = await serve();
    const res = await api.topUp("pay", 50);
    expect(res.status).toBe(201);
    expect(await res.json()).toMatchObject({
      entry: { kind: "topup", points: 6250, balance: 6250, pack: { yuan: 50, points: 6250 } },
      balance: 6250,
      held: 0,
      available: 6250,
    });
    expect((await api.topUp("pay", 15)).status).toBe(400);
    await api.close();

    // Without simulation (real payments come with Phase 4): 501; a measured charge's dollars stay private.
    const real = await serve({
      points: { simulateTopUp: false },
      provider: billed({ narrative: { input_tokens: 10_000, output_tokens: 15_000 } }),
    });
    const refused = await real.topUp("real", 50);
    expect(refused.status).toBe(501);
    expect((await refused.json()).code).toBe("payments_unavailable");
    await real.store.creditPoints("real", 2000, { kind: "grant", reason: "test" }, at(1));
    await real.post("/v1/reports", { chart_id: await real.chart("real"), ...bazi6 }, "real");
    await real.s.drain();
    const p = await real.points("real");
    expect(p).toMatchObject({ balance: 2000 - 665, top_up: "unavailable" });
    expect(p.entries[0]).toMatchObject({ points: -665, basis: "measured" });
    expect(p.entries[0].usd).toBeUndefined();
    expect((await real.get("/v1/health", "real")).points).toBe("on");
    await real.close();
  });
});

describe("the dev accounts and the owner's switch (WP20.3)", () => {
  it(
    "every dev account starts with 10,000 积分, given once",
    async () => {
      const auth = new AuthService({ pepper: PEPPER, tokens: new TokenService(randomBytes(32)) });
      await seedDevAccounts(auth, true);
      const store = new InMemoryStore();
      expect(await grantDevPoints(auth, store, config.dev_grant)).toBe(DEV_ACCOUNTS.length);
      expect(await grantDevPoints(auth, store, config.dev_grant)).toBe(0);
      const admin = (await auth.findLogin("username", "admin"))!;
      expect(await store.pointsOf(admin.id)).toEqual({ balance: 10_000, held: 0 });
      expect((await store.listPoints(admin.id, 10)).map((e) => e.reason)).toEqual(["dev"]);
    },
    PG,
  );

  it("MINGLI_POINTS=off turns 积分 off; anything else leaves them on", () => {
    expect(pointsOn({})).toBe(true);
    expect(pointsOn({ MINGLI_POINTS: "on" })).toBe(true);
    expect(pointsOn({ MINGLI_POINTS: "off" })).toBe(false);
    expect(pointsOn({ MINGLI_POINTS: "FALSE" })).toBe(false);
  });
});
