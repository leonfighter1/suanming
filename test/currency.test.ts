// 货币 and 收据 (S31; owner, 2026-10-31: 「checkbox on different accepted currencies by admin. have a rate conversions on
// the currencies. user is able to pick what ever currencies they like - Verify currencies from active online's today's
// currency rate … - always get 5% service charge from the conversion. - Generate a purchase receipt for user … (need to
// have an email address.). Admin's adding points shouldn't reflect on the money print. Admin can choose the main
// displayed currencies for dashboard.」). No test reaches the network: the rates come from a fake source.
import { randomBytes, randomUUID } from "node:crypto";
import { beforeAll, describe, expect, it } from "vitest";
import { InMemoryStore } from "../src/api/store.js";
import {
  currencyOf,
  offerOf,
  OpenErApi,
  priceIn,
  RateBook,
  RETRY_MS,
  type Rates,
  type RatesSource,
} from "../src/currency/index.js";
import { PgStore } from "../src/db/pg-store.js";
import { loadPointsConfig } from "../src/points/index.js";
import { buildAuth } from "../src/service/runtime.js";
import { Settings } from "../src/settings/index.js";
import { staffApi } from "./api.js";
import { DRAW_KEY, PEPPER } from "./helpers.js";

const TODAY = "2026-10-31";
const now = () => new Date(`${TODAY}T08:00:00.000Z`);

/** A source that answers [rates] at [at]'s time (or fails while `fail`), counting its calls. */
function fakeSource(rates: Record<string, number>, at: () => Date = now) {
  const s = {
    name: "fake",
    calls: 0,
    fail: false as boolean,
    async fetch(): Promise<Rates> {
      s.calls++;
      if (s.fail) throw new Error("offline");
      return {
        base: "CNY",
        date: at().toISOString().slice(0, 10),
        fetched_at: at().toISOString(),
        rates,
      };
    },
  } satisfies RatesSource & { calls: number; fail: boolean };
  return s;
}

const RATES = { CNY: 1, HKD: 1.0876, TWD: 4.4918, USD: 0.1392, SGD: 0.1817 };

describe("prices in another currency", () => {
  it("are the 元 at the rate plus the charge, rounded up to the currency's smallest unit; 元 as they are", () => {
    expect(priceIn(10, currencyOf("HKD")!, 1.0876, 5)).toBe(11.42); // 11.4198
    expect(priceIn(50, currencyOf("TWD")!, 4.4918, 5)).toBe(236); // 235.82, a whole 新台币
    expect(priceIn(10, currencyOf("USD")!, 0.1, 0)).toBe(1); // exactly 1, not a cent more
    expect(priceIn(10, currencyOf("CNY")!, 1, 5)).toBe(10);
  });

  it("are offered in the accepted currencies' order, 元 always, one without a rate left out", () => {
    const packs = loadPointsConfig().packs;
    const rates: Rates = {
      base: "CNY",
      date: TODAY,
      fetched_at: `${TODAY}T08:00:00Z`,
      rates: RATES,
    };
    const offer = offerOf(packs, ["HKD", "CNY", "JPY", "TWD"], rates, 5);
    expect(offer.map((c) => c.code)).toEqual(["HKD", "CNY", "TWD"]);
    expect(offer[0]).toMatchObject({ rate: 1.0876, service_charge_percent: 5, symbol: "HK$" });
    expect(offer[0]!.prices[0]).toEqual({ yuan: 10, amount: 11.42 });
    expect(offer[1]).toMatchObject({ rate: 1, service_charge_percent: 0 });
    expect(offer[1]!.prices.map((p) => p.amount)).toEqual(packs.map((p) => p.yuan));
    expect(offerOf(packs, ["HKD", "CNY"], undefined, 5).map((c) => c.code)).toEqual(["CNY"]);
  });
});

describe("today's rates", () => {
  it("reads the online service's table of 元, and refuses anything else", async () => {
    const answer = (body: unknown, status = 200) =>
      (async () => new Response(JSON.stringify(body), { status })) as typeof fetch;
    const table = {
      result: "success",
      base_code: "CNY",
      time_last_update_unix: Date.parse("2026-10-31T00:02:31Z") / 1000,
      rates: { CNY: 1, HKD: 1.0876, XYZ: "n/a" },
    };
    const r = await new OpenErApi("http://rates.test", answer(table), now).fetch();
    expect(r).toEqual({
      base: "CNY",
      date: TODAY,
      fetched_at: now().toISOString(),
      rates: { CNY: 1, HKD: 1.0876 },
    });
    await expect(
      new OpenErApi("http://rates.test", answer({ ...table, base_code: "USD" })).fetch(),
    ).rejects.toThrow("not a table of 元");
    await expect(new OpenErApi("http://rates.test", answer({}, 503)).fetch()).rejects.toThrow(
      "HTTP 503",
    );
  });

  it("fetches once a day; while the service fails, the last good table (stale), tried again after a while", async () => {
    // A clock of its own: the API tests below stay on TODAY.
    let t = Date.parse(`${TODAY}T08:00:00.000Z`);
    const at = () => new Date(t);
    const source = fakeSource(RATES, at);
    const store = new InMemoryStore();
    const book = new RateBook(source, at, store);
    const [a, b] = await Promise.all([book.today(), book.today()]);
    expect(a).toBe(b);
    expect(source.calls).toBe(1);
    await book.today();
    expect(source.calls).toBe(1);

    t += 24 * 3600_000;
    source.fail = true;
    const old = await book.today();
    expect(old!.rates.HKD).toBe(1.0876);
    expect(book.stale(old!)).toBe(true);
    expect(source.calls).toBe(2);
    await book.today();
    expect(source.calls).toBe(2);
    t += RETRY_MS;
    source.fail = false;
    expect(book.stale((await book.today())!)).toBe(false);
    expect(source.calls).toBe(3);

    // Another start, the service down: the stored table.
    const down = fakeSource(RATES, at);
    down.fail = true;
    expect((await new RateBook(down, at, store).today())!.rates.USD).toBe(0.1392);
  });
});

// ---- 充值, receipts and the dashboard's currency, through the API ----

const store = new InMemoryStore();
const settings = new Settings(store, {});
const source = fakeSource(RATES);
const auth = buildAuth({ digestPepper: PEPPER, drawKey: DRAW_KEY, ephemeral: true } as never, true);
const { start, call, ids } = staffApi(
  {
    auth,
    store,
    settings,
    rates: new RateBook(source, now, store),
    points: { simulateTopUp: true },
    admins: ["boss"],
    now,
  },
  ["boss", "buyer", "nomail"],
);
const json = async (who: string, path: string, method = "GET", body?: unknown) =>
  (await call(who, path, method, body)).json();

describe("充值 in the accepted currencies, with receipts", () => {
  beforeAll(async () => {
    await start();
    const u = (await auth.findLogin("username", "buyer"))!;
    await auth.users.put({
      ...u,
      email: "buyer@example.com",
      email_lookup: auth.emailLookup("buyer@example.com"),
    });
  });

  it("我的积分 offers each pack in the accepted currencies at today's rates", async () => {
    const p = await json("buyer", "/v1/points");
    expect(p.currencies.map((c: { code: string }) => c.code)).toEqual([
      "CNY",
      "HKD",
      "TWD",
      "SGD",
      "USD",
    ]);
    expect(p.currencies[1]).toMatchObject({ code: "HKD", rate: 1.0876, service_charge_percent: 5 });
    expect(p.currencies[1].names).toEqual({ "zh-Hans": "港币", "zh-Hant": "港幣" });
    expect(p.rates).toEqual({ date: TODAY, stale: false });
  });

  it("a pack bought in 港币: its 积分, and a receipt with the money, the rate, the charge and the email", async () => {
    const before = (await json("buyer", "/v1/points")).balance;
    const res = await call("buyer", "/v1/points/top-ups", "POST", { yuan: 10, currency: "HKD" });
    expect(res.status).toBe(201);
    const { receipt, balance } = await res.json();
    expect(balance).toBe(before + 1000);
    expect(receipt).toMatchObject({
      number: "MLDS-2026-000001",
      email: "buyer@example.com",
      pack: { yuan: 10, points: 1000 },
      currency: "HKD",
      amount: 11.42,
      rate: 1.0876,
      rates_date: TODAY,
      service_charge_percent: 5,
      simulated: true,
    });
    expect(receipt.owner).toBeUndefined();

    const { items } = await json("buyer", "/v1/receipts");
    expect(items.map((r: { id: string }) => r.id)).toEqual([receipt.id]);
    expect(await json("buyer", `/v1/receipts/${receipt.id}`)).toEqual(receipt);
    expect((await call("nomail", `/v1/receipts/${receipt.id}`)).status).toBe(404);
  });

  it("元 when none is named (an app from before); refused in a currency not accepted, or without an email", async () => {
    const yuan = await json("buyer", "/v1/points/top-ups", "POST", { yuan: 20 });
    expect(yuan.receipt).toMatchObject({
      currency: "CNY",
      amount: 20,
      rate: 1,
      service_charge_percent: 0,
    });
    expect(yuan.receipt.rates_date).toBeUndefined();

    const jpy = await call("buyer", "/v1/points/top-ups", "POST", { yuan: 10, currency: "JPY" });
    expect([jpy.status, (await jpy.json()).code]).toEqual([400, "currency_unavailable"]);

    const before = (await json("nomail", "/v1/points")).balance;
    const nomail = await call("nomail", "/v1/points/top-ups", "POST", { yuan: 10 });
    expect([nomail.status, (await nomail.json()).code]).toEqual([409, "email_required"]);
    expect((await json("nomail", "/v1/points")).balance).toBe(before);
  });

  it("an admin's 增加积分 is no purchase: no receipt", async () => {
    const before = (await json("buyer", "/v1/receipts")).items.length;
    const grant = await call("boss", `/v1/admin/users/${ids.buyer}/points`, "POST", {
      points: 500,
      note: "补偿",
    });
    expect(grant.status).toBe(201);
    expect((await json("buyer", "/v1/receipts")).items).toHaveLength(before);
  });

  it("设置 moves with it: the service charge, and the dashboard's currency at today's rate", async () => {
    await settings.set("currencies.service_charge_percent", 10, undefined, now().toISOString());
    const hkd = (await json("buyer", "/v1/points")).currencies.find(
      (c: { code: string }) => c.code === "HKD",
    );
    expect(hkd.prices[0]).toEqual({ yuan: 10, amount: 11.97 }); // 10 × 1.0876 × 1.10 = 11.9636
    await settings.reset("currencies.service_charge_percent");

    expect((await json("boss", "/v1/admin/me")).currency).toEqual({
      code: "CNY",
      symbol: "¥",
      decimals: 2,
      rate: 1,
    });
    await settings.set("currencies.dashboard", "HKD", undefined, now().toISOString());
    expect((await json("boss", "/v1/admin/me")).currency).toEqual({
      code: "HKD",
      symbol: "HK$",
      decimals: 2,
      rate: 1.0876,
      rates_date: TODAY,
    });
    // A currency without a rate today: the dashboard stays in 元.
    await settings.set("currencies.dashboard", "JPY", undefined, now().toISOString());
    expect((await json("boss", "/v1/admin/me")).currency.code).toBe("CNY");
    await settings.reset("currencies.dashboard");
    expect((await json("boss", "/v1/admin/settings")).rates).toEqual({ date: TODAY, stale: false });
  });
});

describe("the database keeps receipts sealed and numbered, and the last table of rates (rule 78)", () => {
  it("round-trips both", async () => {
    const pg = await PgStore.open({ kek: randomBytes(32), pepper: PEPPER });
    const owner = randomUUID();
    await pg.put({
      id: owner,
      email: "pg@example.com",
      email_lookup: Buffer.alloc(32, 1).toString("base64"),
      password_hash: "x",
      social: {},
      country: "HK",
      locale: "zh-Hans",
      created_at: `${TODAY}T08:00:00.000Z`,
    } as never);
    const base = {
      owner,
      email: "pg@example.com",
      pack: { yuan: 10, points: 1000 },
      currency: "HKD",
      amount: 11.42,
      rate: 1.0876,
      rates_date: TODAY,
      service_charge_percent: 5,
      simulated: true,
    };
    const one = await pg.putReceipt({
      ...base,
      id: randomUUID(),
      entry_id: randomUUID(),
      created_at: `${TODAY}T08:00:00.000Z`,
    });
    const two = await pg.putReceipt({
      ...base,
      id: randomUUID(),
      entry_id: randomUUID(),
      created_at: `${TODAY}T09:00:00.000Z`,
    });
    expect([one.number, two.number]).toEqual(["MLDS-2026-000001", "MLDS-2026-000002"]);
    expect((await pg.listReceipts(owner, 10)).map((r) => r.number)).toEqual([
      two.number,
      one.number,
    ]);
    expect(await pg.getReceipt(one.id)).toEqual(one);
    // Sealed: no email nor amount in the row as stored.
    const raw = JSON.stringify(await pg.rawRows("receipts"));
    expect(raw).not.toContain("pg@example.com");
    expect(raw).not.toContain("11.42");

    const rates: Rates = {
      base: "CNY",
      date: TODAY,
      fetched_at: `${TODAY}T08:00:00.000Z`,
      rates: RATES,
    };
    await pg.putRates(rates);
    await pg.putRates({ ...rates, rates: { ...RATES, HKD: 1.09 } });
    expect((await pg.getRates())!.rates.HKD).toBe(1.09);
    await pg.close();
  }, 30_000);
});
