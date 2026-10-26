/**
 * Statistical battery for the tarot draw (HMAC-DRBG + partial Fisher–Yates).
 * Each check is a chi-square or z test at α = 0.001 (Wilson–Hilferty critical
 * values), on deterministic draw ids so results are reproducible.
 */
import { DECK, SPREADS, type SpreadId } from "../../src/engines/tarot/deck.js";
import { deriveSeed, drawWithSeed } from "../../src/engines/tarot/index.js";

const Z_999 = 3.09;
export const chi2Critical = (df: number, z = Z_999) => {
  const a = 2 / (9 * df);
  return df * (1 - a + z * Math.sqrt(a)) ** 3;
};

const IDS = DECK.map((c) => c.id);
const INDEX = new Map(IDS.map((id, i) => [id, i]));
/** 5 categories: major arcana, wands, cups, swords, pentacles. */
const category = (id: string) =>
  id.startsWith("major")
    ? 0
    : ["wands", "cups", "swords", "pentacles"].indexOf(id.split("_")[0]!) + 1;
const CAT_P = [22 / 78, 14 / 78, 14 / 78, 14 / 78, 14 / 78];

const drawId = (i: number) => `00000000-0000-4000-8000-${i.toString(16).padStart(12, "0")}`;

export interface Check {
  name: string;
  statistic: number;
  critical: number;
  pass: boolean;
  detail?: string;
}

function chi2(observed: number[], expected: number[]) {
  return observed.reduce((s, o, i) => s + (o - expected[i]!) ** 2 / expected[i]!, 0);
}

/** Chi-square test of independence on a contingency table. */
function independence(table: number[][]) {
  const rows = table.map((r) => r.reduce((a, b) => a + b, 0));
  const cols = table[0]!.map((_, j) => table.reduce((a, r) => a + r[j]!, 0));
  const n = rows.reduce((a, b) => a + b, 0);
  let s = 0;
  table.forEach((r, i) =>
    r.forEach((o, j) => {
      const e = (rows[i]! * cols[j]!) / n;
      if (e > 0) s += (o - e) ** 2 / e;
    }),
  );
  return { s, df: (table.length - 1) * (table[0]!.length - 1) };
}

export type DrawFn = (drawId: string, spread: SpreadId) => ReturnType<typeof drawWithSeed>;

/** The production draw: seed = HMAC(drawKey, draw_id). Tests can inject a biased one. */
export const realDraw =
  (key = Buffer.alloc(32, 9)): DrawFn =>
  (id, spread) =>
    drawWithSeed(deriveSeed(key, id), spread);

export function tarotBattery(n: number, draw: DrawFn = realDraw()) {
  const checks: Check[] = [];
  const add = (name: string, statistic: number, df: number, detail?: string) => {
    const critical = chi2Critical(df);
    checks.push({
      name,
      statistic: round(statistic),
      critical: round(critical),
      pass: statistic < critical,
      detail,
    });
  };

  for (const spread of Object.keys(SPREADS) as SpreadId[]) {
    const k = SPREADS[spread].length;
    const perPos = Array.from({ length: k }, () => new Array<number>(78).fill(0));
    const revByCard = Array.from({ length: 78 }, () => [0, 0]);
    const pair = Array.from({ length: 5 }, () => new Array<number>(5).fill(0));
    const serial = Array.from({ length: 5 }, () => new Array<number>(5).fill(0));
    let duplicates = 0;
    let reversed = 0;
    let prevFirst: string | undefined;

    for (let i = 0; i < n; i++) {
      const cards = draw(drawId(i), spread);
      if (new Set(cards.map((c) => c.card_id)).size !== cards.length) duplicates++;
      cards.forEach((c, p) => {
        perPos[p]![INDEX.get(c.card_id)!]!++;
        revByCard[INDEX.get(c.card_id)!]![c.reversed ? 1 : 0]!++;
        if (c.reversed) reversed++;
      });
      if (k >= 2) pair[category(cards[0]!.card_id)]![category(cards[1]!.card_id)]!++;
      if (prevFirst) serial[category(prevFirst)]![category(cards[0]!.card_id)]!++;
      prevFirst = cards[0]!.card_id;
    }

    // Uniformity: every position is uniform over the 78 cards.
    perPos.forEach((counts, p) =>
      add(
        `${spread} · position ${p + 1} uniform over 78 cards`,
        chi2(counts, new Array(78).fill(n / 78)),
        77,
      ),
    );
    // Reversal: ~50 % overall, and independent of which card was drawn.
    const total = n * k;
    const z = Math.abs((reversed - total / 2) / Math.sqrt(total / 4));
    checks.push({
      name: `${spread} · reversal rate 50 %`,
      statistic: round(z),
      critical: Z_999,
      pass: z < Z_999,
      detail: `${((reversed / total) * 100).toFixed(2)} %`,
    });
    const ind = independence(revByCard);
    add(`${spread} · reversal independent of card`, ind.s, ind.df);
    // Positions 1 and 2 follow sampling WITHOUT replacement (not independence: card 2
    // can't repeat card 1). Expected P(c2 = j | c1 = i) = (N_j − [i = j]) / 77.
    if (k >= 2) {
      const N = [22, 14, 14, 14, 14];
      const observed: number[] = [];
      const expected: number[] = [];
      for (let i = 0; i < 5; i++) {
        for (let j = 0; j < 5; j++) {
          observed.push(pair[i]![j]!);
          expected.push(n * (N[i]! / 78) * ((N[j]! - (i === j ? 1 : 0)) / 77));
        }
      }
      add(
        `${spread} · positions 1→2 match sampling without replacement`,
        chi2(observed, expected),
        24,
      );
    }
    // Consecutive draws independent (first card of draw i vs draw i+1).
    const sr = independence(serial);
    add(`${spread} · consecutive draws independent`, sr.s, sr.df);
    // Category mix matches the deck (22 major / 56 minor).
    const catCounts = [0, 0, 0, 0, 0];
    perPos[0]!.forEach((c, i) => (catCounts[category(IDS[i]!)]! += c));
    add(
      `${spread} · major/suit mix matches the deck`,
      chi2(
        catCounts,
        CAT_P.map((q) => q * n),
      ),
      4,
    );
    checks.push({
      name: `${spread} · no repeated card within a spread`,
      statistic: duplicates,
      critical: 0,
      pass: duplicates === 0,
    });
  }

  // Seed sensitivity: ids that differ in one character give unrelated spreads.
  let sameFirst = 0;
  for (let i = 0; i < n; i++) {
    const a = draw(drawId(2 * i), "single")[0]!.card_id;
    const b = draw(drawId(2 * i + 1), "single")[0]!.card_id;
    if (a === b) sameFirst++;
  }
  const expectSame = n / 78;
  const zs = Math.abs((sameFirst - expectSame) / Math.sqrt(expectSame * (1 - 1 / 78)));
  checks.push({
    name: "adjacent draw ids: same card at chance rate (1/78)",
    statistic: round(zs),
    critical: Z_999,
    pass: zs < Z_999,
    detail: `${sameFirst} of ${n}`,
  });

  return { draws_per_spread: n, checks, pass: checks.every((c) => c.pass) };
}

const round = (x: number) => Math.round(x * 100) / 100;
