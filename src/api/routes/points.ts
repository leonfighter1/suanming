/**
 * The 积分 routes (v11.0.0, tech plan S20; moved here in S28 WP28.9): the balance with its entries and holds, 充值,
 * and what each AI request on a chart costs.
 */
import type { IncomingMessage, ServerResponse } from "node:http";
import {
  INQUIRY_MAX_QUESTIONS,
  inquiryAvailable,
  TOPICS_BY_SYSTEM,
  type Topic,
} from "../../ai/index.js";
import { HttpError, readJson, send } from "../../http/util.js";
import { quoteFor } from "../../points/index.js";
import { InputError, UUID_RE } from "../../service/charts.js";
import type { ApiContext, Caller } from "../context.js";
import { publicPack, publicPointsEntry } from "../views.js";

/** The balance, 充值 and a chart's prices; false for any other path. */
export async function pointsRoute(
  ctx: ApiContext,
  req: IncomingMessage,
  res: ServerResponse,
  path: string,
  c: Caller,
): Promise<boolean> {
  const { store, now, pointsConfig, simulatedTopUp, priceOf, assertAllowed } = ctx;
  if (path === "/v1/points" && req.method === "GET") {
    if (!pointsConfig) {
      send(res, 200, { enabled: false });
      return true;
    }
    const { balance, held } = await store.pointsOf(c.user);
    const [entries, holds] = await Promise.all([
      store.listPoints(c.user, 50),
      store.listHolds(c.user),
    ]);
    send(res, 200, {
      enabled: true,
      balance,
      held,
      available: Math.max(0, balance - held),
      top_up: simulatedTopUp ? "simulated" : "unavailable",
      packs: pointsConfig.packs.map(publicPack),
      entries: entries.map((e) => publicPointsEntry(e, simulatedTopUp)),
      holds: holds.map((h) => ({ points: h.points, for: h.for, created_at: h.created_at })),
    });
    return true;
  }
  if (path === "/v1/points/top-ups" && req.method === "POST") {
    if (!pointsConfig) throw new HttpError(404, "积分 are off on this server", "points_off");
    await assertAllowed(c, "top_up");
    if (!simulatedTopUp) {
      throw new HttpError(
        501,
        "充值 needs real payments, which come with Phase 4",
        "payments_unavailable",
      );
    }
    const body = (await readJson(req)) as Record<string, unknown>;
    const pack = pointsConfig.packs.find((p) => p.yuan === body.yuan);
    if (!pack) {
      throw new InputError(
        `yuan must be one of the packs: ${pointsConfig.packs.map((p) => p.yuan).join(", ")}`,
      );
    }
    // Simulated (development): the pack's 积分 arrive without payment. TODO(Phase 4): a verified payment.
    const entry = await store.creditPoints(
      c.user,
      pack.points,
      { kind: "topup", pack },
      now().toISOString(),
    );
    const { balance, held } = await store.pointsOf(c.user);
    send(res, 201, {
      entry: publicPointsEntry(entry!, simulatedTopUp),
      balance,
      held,
      available: Math.max(0, balance - held),
    });
    return true;
  }
  const qm = /^\/v1\/charts\/([^/]+)\/quote$/.exec(path);
  if (qm && req.method === "GET") {
    if (!pointsConfig) throw new HttpError(404, "积分 are off on this server", "points_off");
    const ch = UUID_RE.test(qm[1]!) ? await store.getChart(qm[1]!) : undefined;
    if (!ch || ch.owner !== c.user) throw new HttpError(404, "chart not found");
    const allowed = TOPICS_BY_SYSTEM[ch.fact.system];
    const asked = new URL(req.url ?? "/", "http://localhost").searchParams.get("topics");
    const topics = asked
      ? asked.split(",").filter((t) => allowed.includes(t as Topic)).length
      : allowed.length;
    send(res, 200, {
      report: priceOf("report", quoteFor(ch.fact, topics)),
      ...(inquiryAvailable(ch.fact) && {
        inquiry: { ...priceOf("inquiry"), max_questions: INQUIRY_MAX_QUESTIONS },
      }),
      ...(ch.fact.system === "bazi" && { life_report: priceOf("life_report") }),
    });
    return true;
  }
  return false;
}
