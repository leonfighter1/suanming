/**
 * The 积分 routes (v11.0.0, tech plan S20; moved here in S28 WP28.9): the balance with its entries and holds, 充值,
 * and what each AI request on a chart costs. 货币 and 收据 (S31): 充值 in the accepted currencies at today's rates plus
 * the service charge, each with a receipt, and the account's receipts.
 */
import { randomUUID } from "node:crypto";
import type { IncomingMessage, ServerResponse } from "node:http";
import {
  INQUIRY_MAX_QUESTIONS,
  inquiryAvailable,
  TOPICS_BY_SYSTEM,
  type Topic,
} from "../../ai/index.js";
import { HttpError, readJson, send } from "../../http/util.js";
import { offerOf } from "../../currency/index.js";
import { quoteFor } from "../../points/index.js";
import { InputError, UUID_RE } from "../../service/charts.js";
import type { ApiContext, Caller } from "../context.js";
import { publicPack, publicPointsEntry, publicReceipt } from "../views.js";

/** The accepted currencies 充值 can price now (S31), and the day's table it priced them by. */
async function currencyOffer(ctx: ApiContext) {
  const table = await ctx.rates?.today();
  const currencies = offerOf(
    ctx.pointsConfig!.packs,
    ctx.settings.choices("currencies.accepted"),
    table,
    ctx.settings.number("currencies.service_charge_percent"),
  );
  return { currencies, rates: table && { date: table.date, stale: ctx.rates!.stale(table) } };
}

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
    const [entries, holds, offer] = await Promise.all([
      store.listPoints(c.user, 50),
      store.listHolds(c.user),
      currencyOffer(ctx),
    ]);
    send(res, 200, {
      enabled: true,
      balance,
      held,
      available: Math.max(0, balance - held),
      top_up: simulatedTopUp ? "simulated" : "unavailable",
      packs: pointsConfig.packs.map(publicPack),
      // 货币 (S31): each pack's price in the accepted currencies today, and which day's rates.
      currencies: offer.currencies,
      ...(offer.rates && { rates: offer.rates }),
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
    // 货币 (S31): paid in one of today's accepted currencies; 元 when none is named (an app from before).
    const code = typeof body.currency === "string" ? body.currency : "CNY";
    const { currencies, rates } = await currencyOffer(ctx);
    const currency = currencies.find((x) => x.code === code);
    if (!currency) {
      throw new HttpError(
        400,
        `currency must be one of today's: ${currencies.map((x) => x.code).join(", ") || "none"}`,
        "currency_unavailable",
      );
    }
    // 收据 (S31; the owner: 「need to have an email address」): the receipt carries the account's email.
    const account = ctx.auth && (await ctx.auth.users.get(c.user));
    if (account && !account.email) {
      throw new HttpError(
        409,
        "an email address is needed first: the receipt carries it (设置 → 邮箱)",
        "email_required",
      );
    }
    // Simulated (development): the pack's 积分 arrive without payment. TODO(Phase 4): a verified payment.
    const entry = (await store.creditPoints(
      c.user,
      pack.points,
      { kind: "topup", pack },
      now().toISOString(),
    ))!;
    const receipt = await store.putReceipt({
      id: randomUUID(),
      owner: c.user,
      entry_id: entry.id,
      created_at: entry.created_at,
      email: account?.email ?? "",
      pack: { yuan: pack.yuan, points: pack.points },
      currency: currency.code,
      amount: currency.prices.find((p) => p.yuan === pack.yuan)!.amount,
      rate: currency.rate,
      ...(rates && currency.code !== "CNY" && { rates_date: rates.date }),
      service_charge_percent: currency.service_charge_percent,
      simulated: true,
    });
    const { balance, held } = await store.pointsOf(c.user);
    send(res, 201, {
      entry: publicPointsEntry(entry, simulatedTopUp),
      receipt: publicReceipt(receipt),
      balance,
      held,
      available: Math.max(0, balance - held),
    });
    return true;
  }
  // ---- 收据 (S31): the account's own, newest first, and one by its id ----
  if (path === "/v1/receipts" && req.method === "GET") {
    send(res, 200, { items: (await store.listReceipts(c.user, 100)).map(publicReceipt) });
    return true;
  }
  const rm = /^\/v1\/receipts\/([^/]+)$/.exec(path);
  if (rm && req.method === "GET") {
    const r = UUID_RE.test(rm[1]!) ? await store.getReceipt(rm[1]!) : undefined;
    if (!r || r.owner !== c.user) throw new HttpError(404, "receipt not found");
    send(res, 200, publicReceipt(r));
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
