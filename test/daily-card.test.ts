// WP3.3 (docs/tech-plan.md): 每日一牌, one card a day per account, the same all day.
import type { AddressInfo } from "node:net";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { MockProvider } from "../src/ai/index.js";
import { createApiServer } from "../src/api/server.js";
import { InMemoryStore } from "../src/api/store.js";
import { computeTarot } from "../src/engines/tarot/index.js";
import { dailyDate, dailyIds, keyedUuid } from "../src/service/daily.js";
import { DRAW_KEY, PEPPER } from "./helpers.js";

// 15:00 UTC on 2026-10-25: already 2026-10-26 east of UTC+9, still 2026-10-25 elsewhere.
const NOW = new Date("2026-10-25T15:00:00Z");
const store = new InMemoryStore();
const mock = new MockProvider();
const api = createApiServer({
  secrets: { digestPepper: PEPPER, drawKey: DRAW_KEY },
  providers: { deepseek: mock, anthropic: mock },
  store,
  devMode: true,
  now: () => NOW,
  log: () => {},
});
let base = "";
beforeAll(async () => {
  await new Promise<void>((r) => api.listen(0, "127.0.0.1", r));
  base = `http://127.0.0.1:${(api.address() as AddressInfo).port}`;
});
afterAll(() => new Promise<void>((r) => api.close(() => r())));
const get = (path: string, user = "u1", country = "HK") =>
  fetch(base + path, {
    headers: { "content-type": "application/json", "x-dev-country": country, "x-dev-user": user },
  });
const daily = async (date: string, user = "u1") =>
  (await get(`/v1/tarot/daily?date=${date}`, user)).json();

describe("每日一牌", () => {
  it("is the same card all day for an account, and replays from its draw id", async () => {
    const a = await daily("2026-10-25");
    expect(await daily("2026-10-25")).toEqual(a);
    expect(a.date).toBe("2026-10-25");
    expect(a.chart_fact.facts.spread_id).toBe("single");
    expect(a.chart_fact.facts.cards).toHaveLength(1);
    const ids = dailyIds(DRAW_KEY, "u1", "2026-10-25");
    expect(a.chart_id).toBe(ids.chartId);
    expect(a.chart_fact.facts.audit.draw_id).toBe(ids.drawId);
    // The audit replays it like any draw: the stored draw id seeds the same shuffle.
    const replay = computeTarot(
      { spread: "single" },
      { drawKey: DRAW_KEY, digestPepper: PEPPER, newDrawId: () => ids.drawId },
    );
    expect(replay.facts).toMatchObject({ cards: a.chart_fact.facts.cards });
    // Stored once, as the account's own chart, and readable like one.
    expect((await store.getChart(a.chart_id))?.daily).toBe("2026-10-25");
    const opened = await (await get(`/v1/charts/${a.chart_id}`)).json();
    expect(opened.chart_fact.facts.cards).toEqual(a.chart_fact.facts.cards);
  });

  it("another day or another account draws its own card", async () => {
    const a = await daily("2026-10-25");
    const tomorrowEast = await daily("2026-10-26"); // already today east of UTC+9
    const other = await daily("2026-10-25", "u2");
    expect(new Set([a.chart_id, tomorrowEast.chart_id, other.chart_id]).size).toBe(3);
    expect(
      new Set([a, tomorrowEast, other].map((d) => d.chart_fact.facts.audit.draw_id)).size,
    ).toBe(3);
    // Another account can't open this account's card.
    expect((await get(`/v1/charts/${a.chart_id}`, "u2")).status).toBe(404);
  });

  it("only today's date (within a day of the server), and real dates only", async () => {
    for (const bad of ["2026-10-27", "2026-10-23", "2026-13-01", "2026-02-30", "today", ""]) {
      expect((await get(`/v1/tarot/daily?date=${bad}`)).status, bad).toBe(400);
    }
    expect(() => dailyDate("2026-10-24", NOW)).not.toThrow(); // still today west of UTC−9
  });

  it("not served where tarot isn't (Geo-Rule before drawing), and not listed among the charts", async () => {
    const before = (await store.listCharts("u3", 100)).length;
    expect((await get("/v1/tarot/daily?date=2026-10-25", "u3", "CN")).status).toBe(451);
    await daily("2026-10-25", "u3");
    const listed = await (await get("/v1/charts", "u3")).json();
    expect(listed.items).toHaveLength(before); // the day's card isn't a chart the user made
  });

  it("keyed ids are version-8 UUIDs, fixed for a label and different across labels", () => {
    const id = keyedUuid(DRAW_KEY, "daily-draw|u1|2026-10-25");
    expect(id).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-8[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
    expect(keyedUuid(DRAW_KEY, "daily-draw|u1|2026-10-25")).toBe(id);
    expect(keyedUuid(DRAW_KEY, "daily-chart|u1|2026-10-25")).not.toBe(id);
    expect(keyedUuid(Buffer.alloc(32, 1), "daily-draw|u1|2026-10-25")).not.toBe(id);
  });
});
