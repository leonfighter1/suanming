/**
 * The cards of the day (moved here in S28 WP28.9): 每日一牌, and 今日一卦 / 今日一签 (S26), each the account's own and
 * the same all day. The draws are src/service/daily.ts's; each route keeps its own (rule 8).
 */
import type { IncomingMessage, ServerResponse } from "node:http";
import { GeoRefusedError } from "../../ai/index.js";
import type { ChartFact } from "../../chart-fact/index.js";
import { loadGeoMatrix, methodsFor, resolveRegion } from "../../compliance/index.js";
import { send } from "../../http/util.js";
import {
  dailyDate,
  dailyIds,
  dailyZone,
  drawDaily,
  drawEastDaily,
  EAST_DAILY,
  eastDaily,
} from "../../service/daily.js";
import type { ApiContext, Caller } from "../context.js";

/**
 * The account's draw of the day (每日一牌, 今日一卦 / 今日一签; S28): the chart kept under [chartId], else [draw] kept
 * now as that day's chart. Each route keeps its own draw (rule 8).
 */
async function dailyChart(
  ctx: ApiContext,
  c: Caller,
  chartId: string,
  date: string,
  draw: () => ChartFact,
) {
  const { store, now } = ctx;
  let chart = await store.getChart(chartId);
  if (!chart) {
    chart = {
      id: chartId,
      owner: c.user,
      fact: draw(),
      created_at: now().toISOString(),
      daily: date,
    };
    await store.putChart(chart);
  }
  return { chart_id: chart.id, chart_fact: chart.fact, date };
}

/** 每日一牌 and 今日一卦 / 今日一签; false for any other path. */
export async function dailyRoute(
  ctx: ApiContext,
  req: IncomingMessage,
  res: ServerResponse,
  path: string,
  c: Caller,
): Promise<boolean> {
  const { opts, now, assertServed } = ctx;
  // 每日一牌: the account's card of the day, the same all day (src/service/daily.ts).
  if (req.method === "GET" && path === "/v1/tarot/daily") {
    assertServed(c.country, "tarot");
    const date = dailyDate(
      new URL(req.url ?? "/", "http://localhost").searchParams.get("date"),
      now(),
    );
    const { drawId, chartId } = dailyIds(opts.secrets.drawKey, c.user, date);
    send(
      res,
      200,
      await dailyChart(ctx, c, chartId, date, () => drawDaily(opts.secrets, drawId, now)),
    );
    return true;
  }
  // 今日一卦 / 今日一签 (S26): the account's 东方 draw of the day, a 签 or a 卦 at random, the same all day
  // (src/service/daily.ts). Only the 东方 methods served in the region take part; none, and it isn't served.
  if (req.method === "GET" && path === "/v1/east/daily") {
    assertServed(c.country);
    const served = methodsFor(resolveRegion(loadGeoMatrix(), c.country)!).map((m) => m.system);
    const systems = EAST_DAILY.filter((s) => served.includes(s));
    if (systems.length === 0) {
      throw new GeoRefusedError(`neither 求签 nor 算卦 is available in ${c.country}`);
    }
    const query = new URL(req.url ?? "/", "http://localhost").searchParams;
    const date = dailyDate(query.get("date"), now());
    const timezone = dailyZone(query.get("timezone"));
    const { system, drawId, chartId } = eastDaily(opts.secrets.drawKey, c.user, date, systems);
    send(
      res,
      200,
      await dailyChart(ctx, c, chartId, date, () =>
        drawEastDaily(system, opts.secrets, drawId, timezone, now),
      ),
    );
    return true;
  }
  return false;
}
