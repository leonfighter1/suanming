// S26 WP26.2 (owner, 2026-10-30): 「我看到西方有今日一牌功能， 那么东方系列，我们剋增加今日一卦或者今日一签功能，可以随机出现」.
// The account's 东方 draw of the day, a 签 or a 卦, keyed from the account and the date and the same all day, dealt as
// 每日一牌 is (src/service/daily.ts).
import { describe, expect, it } from "vitest";
import { InMemoryStore } from "../src/api/store.js";
import { verifyCast } from "../src/engines/liuyao/index.js";
import { verifyDraw } from "../src/engines/qiuqian/index.js";
import { dailyIds, EAST_DAILY, eastDaily } from "../src/service/daily.js";
import { DRAW_KEY, withMatrix } from "./helpers.js";
import { testApi } from "./api.js";

// 15:00 UTC on 2026-10-25: already 2026-10-26 east of UTC+9, still 2026-10-25 elsewhere; 23:00 in Hong Kong.
const NOW = new Date("2026-10-25T15:00:00Z");
const store = new InMemoryStore();
let base = "";
const api = testApi(
  {
    store,
    review: false,
    now: () => NOW,
  },
  (b) => (base = b),
);
const H = (user: string, country: string) => ({
  "content-type": "application/json",
  "x-dev-country": country,
  "x-dev-user": user,
});
const get = (path: string, user = "u1", country = "HK") =>
  fetch(base + path, { headers: H(user, country) });
const post = (path: string, body: unknown, user: string) =>
  fetch(base + path, { method: "POST", headers: H(user, "HK"), body: JSON.stringify(body) });
const DAY = "2026-10-25";
const eastPath = (date: string, zone = "Asia/Hong_Kong") =>
  `/v1/east/daily?date=${date}&timezone=${encodeURIComponent(zone)}`;
const east = async (date: string, user = "u1") => (await get(eastPath(date), user)).json();

/** An account among [users] whose 东方 draw on [DAY] is a [kind], with both served: worked out from the key. */
const whose = (kind: string, users: string[]) =>
  users.find((u) => eastDaily(DRAW_KEY, u, DAY, EAST_DAILY).system === kind)!;
const USERS = Array.from({ length: 12 }, (_, i) => `u${i + 1}`);

describe("今日一卦 / 今日一签", () => {
  it("is the same draw all day for an account, kept as its chart, and replays from its draw id", async () => {
    for (const kind of EAST_DAILY) {
      const u = whose(kind, USERS);
      const a = await east(DAY, u);
      expect(await east(DAY, u)).toEqual(a);
      const ids = eastDaily(DRAW_KEY, u, DAY, EAST_DAILY);
      expect([a.chart_id, a.chart_fact.system, a.chart_fact.facts.audit.draw_id, a.date]).toEqual([
        ids.chartId,
        kind,
        ids.drawId,
        DAY,
      ]);
      // The audit replays it as any draw of its method: the stored draw id seeds the same lot or coins.
      expect((kind === "qiuqian" ? verifyDraw : verifyCast)(a.chart_fact, DRAW_KEY), kind).toBe(
        true,
      );
      // Stored once, as the account's own chart, and opened like one.
      expect((await store.getChart(a.chart_id))?.daily).toBe(DAY);
      const opened = await (await get(`/v1/charts/${a.chart_id}`, u)).json();
      expect(opened.chart_fact.facts).toEqual(a.chart_fact.facts);
    }
  });

  it("a 签 on some days and a 卦 on others: which one is keyed from the account and the date", async () => {
    const days = Array.from({ length: 30 }, (_, i) => `2026-11-${String(i + 1).padStart(2, "0")}`);
    for (const u of ["u1", "u2"]) {
      const kinds = new Set(days.map((d) => eastDaily(DRAW_KEY, u, d, EAST_DAILY).system));
      expect([...kinds].sort(), u).toEqual(["liuyao", "qiuqian"]);
    }
    // With one method served, every day is that one.
    for (const d of days) expect(eastDaily(DRAW_KEY, "u1", d, ["qiuqian"]).system).toBe("qiuqian");
    // The day's 卦: an auto cast on the reader's clock (15:00 UTC is 23:00 in Hong Kong, UTC+8).
    const cast = (await east(DAY, whose("liuyao", USERS))).chart_fact.facts;
    expect([cast.mode, cast.cast.timezone, cast.cast.local]).toEqual([
      "auto",
      "Asia/Hong_Kong",
      "2026-10-25T23:00",
    ]);
    // The day's 签: a lot of the 關聖帝君一百籤, confirmed by a 聖筊 as on the 求签 page.
    const lot = (await east(DAY, whose("qiuqian", USERS))).chart_fact.facts;
    expect([lot.lot_set, lot.rounds.at(-1).result]).toEqual(["guandi_100", "sheng"]);
  });

  it("another day or another account draws its own, apart from 每日一牌", async () => {
    const a = await east(DAY);
    const tomorrowEast = await east("2026-10-26"); // already today east of UTC+9
    const other = await east(DAY, "u2");
    expect(new Set([a.chart_id, tomorrowEast.chart_id, other.chart_id]).size).toBe(3);
    // 每日一牌's ids come from other labels: the two draws never share one.
    const card = dailyIds(DRAW_KEY, "u1", DAY);
    expect([card.chartId, card.drawId]).not.toContain(a.chart_id);
    expect([card.chartId, card.drawId]).not.toContain(a.chart_fact.facts.audit.draw_id);
    // Another account can't open it.
    expect((await get(`/v1/charts/${a.chart_id}`, "u2")).status).toBe(404);
  });

  it("only today's date, and a real time zone", async () => {
    for (const bad of ["2026-10-27", "2026-10-23", "2026-02-30", "today", ""]) {
      expect((await get(eastPath(bad))).status, bad).toBe(400);
    }
    for (const zone of ["", "Mars/Olympus"]) {
      expect((await get(eastPath(DAY, zone))).status, zone).toBe(400);
    }
    expect((await get(`/v1/east/daily?date=${DAY}`)).status).toBe(400);
  });

  it("Geo-Rule first: none where neither 求签 nor 算卦 is served, only the one that is; never listed", async () => {
    expect((await get(eastPath(DAY, "Asia/Shanghai"), "u-cn", "CN")).status).toBe(451);
    // An account whose draw today would be a 卦: with 算卦 off in its region, it is a 签.
    const fresh = whose("liuyao", ["w1", "w2", "w3", "w4", "w5", "w6", "w7", "w8", "w9", "w10"]);
    await withMatrix(
      (m) => {
        m.regions.HK!.systems!.liuyao = { available: false, entry_weight: 1 };
      },
      async () => expect((await east(DAY, fresh)).chart_fact.system).toBe("qiuqian"),
    );
    await withMatrix(
      (m) => {
        m.regions.HK!.systems!.liuyao = { available: false, entry_weight: 1 };
        m.regions.HK!.systems!.qiuqian = { available: false, entry_weight: 1 };
      },
      async () => expect((await get(eastPath(DAY), "w-none")).status).toBe(451),
    );
    // The day's draw isn't a chart the user made.
    expect((await (await get("/v1/charts", fresh)).json()).items).toEqual([]);
  });

  it("is read without a question, as 每日一牌 is: nothing was drawn for one", async () => {
    for (const kind of EAST_DAILY) {
      const u = whose(kind, USERS);
      const { chart_id } = await east(DAY, u);
      expect((await post("/v1/reports", { chart_id, locale: "zh-Hans" }, u)).status, kind).toBe(
        202,
      );
    }
    await api.drain();
  });
});
