/**
 * 货币 (S31): what a pack costs in each accepted currency. Another currency's price is the pack's 元 at today's rate
 * plus the service charge (the owner: 「always get 5% service charge from the conversion」), rounded up to the currency's
 * smallest unit so the charge is never short; 元 is not converted and takes no charge.
 */
import type { Pack } from "../points/index.js";
import { currencyOf, type Currency } from "./catalog.js";
import type { Rates } from "./rates.js";

export * from "./catalog.js";
export * from "./rates.js";

/** [yuan] in [c] at [rate] (1 元 = rate of it), with [chargePercent] on top, rounded up to its smallest unit. */
export function priceIn(yuan: number, c: Currency, rate: number, chargePercent: number): number {
  if (c.code === "CNY") return yuan;
  const unit = 10 ** c.decimals;
  // A hair under, so a price that is whole after the float's error isn't rounded a unit up.
  return Math.ceil(yuan * rate * (1 + chargePercent / 100) * unit - 1e-6) / unit;
}

/** An accepted currency as 充值 offers it: what it is, its rate today and each pack's price in it. */
export interface CurrencyOffer extends Currency {
  /** 1 元 = this many (1 for 元). */
  rate: number;
  /** The service charge it takes (none for 元). */
  service_charge_percent: number;
  prices: { yuan: number; amount: number }[];
}

/**
 * The accepted currencies, in [accepted]'s order, that can be priced: 元 always, another once [rates] has it (none
 * without a table: the service never answered).
 */
export function offerOf(
  packs: readonly Pack[],
  accepted: readonly string[],
  rates: Rates | undefined,
  chargePercent: number,
): CurrencyOffer[] {
  return accepted.flatMap((code) => {
    const c = currencyOf(code);
    const rate = code === "CNY" ? 1 : rates?.rates[code];
    if (!c || !rate) return [];
    const charge = code === "CNY" ? 0 : chargePercent;
    return [
      {
        ...c,
        rate,
        service_charge_percent: charge,
        prices: packs.map((p) => ({ yuan: p.yuan, amount: priceIn(p.yuan, c, rate, charge) })),
      },
    ];
  });
}
