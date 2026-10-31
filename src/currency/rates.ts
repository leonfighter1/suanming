/**
 * 汇率 (S31; the owner, 2026-10-31: 「Verify currencies from active online's today's currency rate P.S. based on the online
 * api call」): how many of each currency one 元 buys, from an online service once a day, kept so a restart without the
 * service still has the last good table. A request to the service names only the base currency: no person's data.
 */

/** One day's table: 1 元 = rates[code] of each currency. */
export interface Rates {
  base: "CNY";
  /** The day the service last updated it (UTC). */
  date: string;
  /** When this server got it. */
  fetched_at: string;
  rates: Record<string, number>;
}

/** Where a day's table comes from. */
export interface RatesSource {
  name: string;
  fetch(): Promise<Rates>;
}

/** Where the last good table is kept: the database (migration 016), or the memory store. */
export interface RatesStore {
  getRates(): Promise<Rates | undefined>;
  putRates(r: Rates): Promise<void>;
}

/**
 * ExchangeRate-API's open access (open.er-api.com): no key, updated once a day, every currency the catalog has (新台币
 * among them). MINGLI_RATES_URL names another address of the same shape.
 */
export class OpenErApi implements RatesSource {
  readonly name = "open.er-api.com";

  constructor(
    private readonly url = process.env.MINGLI_RATES_URL?.trim() ||
      "https://open.er-api.com/v6/latest/CNY",
    private readonly get: typeof fetch = fetch,
    private readonly now: () => Date = () => new Date(),
  ) {}

  async fetch(): Promise<Rates> {
    const res = await this.get(this.url, { signal: AbortSignal.timeout(10_000) });
    if (!res.ok) throw new Error(`${this.name}: HTTP ${res.status}`);
    const j = (await res.json()) as {
      result?: string;
      base_code?: string;
      time_last_update_unix?: number;
      rates?: Record<string, unknown>;
    };
    if (j.result !== "success" || j.base_code !== "CNY" || !j.rates) {
      throw new Error(`${this.name}: not a table of 元`);
    }
    const rates = Object.fromEntries(
      Object.entries(j.rates).filter(
        (e): e is [string, number] => typeof e[1] === "number" && e[1] > 0,
      ),
    );
    const updated = j.time_last_update_unix ? new Date(j.time_last_update_unix * 1000) : this.now();
    return {
      base: "CNY",
      date: updated.toISOString().slice(0, 10),
      fetched_at: this.now().toISOString(),
      rates,
    };
  }
}

/** After a fetch that failed, how long the last good table answers before the service is tried again. */
export const RETRY_MS = 10 * 60_000;

/**
 * Today's table: fetched once a day (UTC) and kept; while the service can't be reached, the last good table (said so
 * by `stale`), the service tried again after RETRY_MS. Requests at once share one fetch.
 */
export class RateBook {
  private current?: Rates;
  private pending?: Promise<Rates | undefined>;
  private failedAt?: number;

  constructor(
    private readonly source: RatesSource,
    private readonly now: () => Date = () => new Date(),
    private readonly store?: RatesStore,
    private readonly log: (msg: string) => void = () => {},
  ) {}

  /** Today's table, or the last good one; undefined when there never was one. */
  async today(): Promise<Rates | undefined> {
    if (this.current?.fetched_at.slice(0, 10) === this.day()) return this.current;
    if (this.failedAt !== undefined && this.now().getTime() - this.failedAt < RETRY_MS) {
      return this.current;
    }
    return (this.pending ??= this.refresh().finally(() => (this.pending = undefined)));
  }

  /** The table is not today's: the service couldn't be reached since it was fetched. */
  stale(r: Rates): boolean {
    return r.fetched_at.slice(0, 10) !== this.day();
  }

  private day() {
    return this.now().toISOString().slice(0, 10);
  }

  private async refresh(): Promise<Rates | undefined> {
    try {
      const r = await this.source.fetch();
      this.current = r;
      this.failedAt = undefined;
      await this.store?.putRates(r);
      return r;
    } catch (e) {
      this.failedAt = this.now().getTime();
      this.log(`rates: ${(e as Error).message}; the last good table is kept`);
      this.current ??= await this.store?.getRates();
      return this.current;
    }
  }
}
