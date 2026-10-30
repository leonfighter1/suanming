/**
 * Statistical battery for the tarot draw (HMAC-DRBG + partial Fisher–Yates).
 * Each check is a chi-square or z test at α = 0.001 (Wilson–Hilferty critical
 * values), on deterministic draw ids so results are reproducible.
 */
import { DECK, SPREADS, type SpreadId } from "../../src/engines/tarot/deck.js";
import { deriveSeed, drawWithRitual, drawWithSeed } from "../../src/engines/tarot/index.js";
import { chi2, chi2Critical, drawId, independence, round, Z_999, type Check } from "./stats.js";

const IDS = DECK.map((c) => c.id);
const INDEX = new Map(IDS.map((id, i) => [id, i]));
/** 5 categories: major arcana, wands, cups, swords, pentacles. */
const category = (id: string) =>
  id.startsWith("major")
    ? 0
    : ["wands", "cups", "swords", "pentacles"].indexOf(id.split("_")[0]!) + 1;
const CAT_P = [22 / 78, 14 / 78, 14 / 78, 14 / 78, 14 / 78];

export type DrawFn = (drawId: string, spread: SpreadId) => ReturnType<typeof drawWithSeed>;

/** The production draw: seed = HMAC(drawKey, draw_id). Tests can inject a biased one. */
export const realDraw =
  (key = Buffer.alloc(32, 9)): DrawFn =>
  (id, spread) =>
    drawWithSeed(deriveSeed(key, id), spread);

export function tarotBattery(
  n: number,
  draw: DrawFn = realDraw(),
  ritualKey = Buffer.alloc(32, 9),
) {
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

  // The checks of one spread drawn by [drawOne], named after [label].
  const spreadChecks = (
    label: string,
    spread: SpreadId,
    drawOne: (id: string) => ReturnType<typeof drawWithSeed>,
  ) => {
    const k = SPREADS[spread].length;
    const perPos = Array.from({ length: k }, () => new Array<number>(78).fill(0));
    const revByCard = Array.from({ length: 78 }, () => [0, 0]);
    const pair = Array.from({ length: 5 }, () => new Array<number>(5).fill(0));
    const serial = Array.from({ length: 5 }, () => new Array<number>(5).fill(0));
    let duplicates = 0;
    let reversed = 0;
    let prevFirst: string | undefined;

    for (let i = 0; i < n; i++) {
      const cards = drawOne(drawId(i));
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
        `${label} · position ${p + 1} uniform over 78 cards`,
        chi2(counts, new Array(78).fill(n / 78)),
        77,
      ),
    );
    // Reversal: ~50 % overall, and independent of which card was drawn.
    const total = n * k;
    const z = Math.abs((reversed - total / 2) / Math.sqrt(total / 4));
    checks.push({
      name: `${label} · reversal rate 50 %`,
      statistic: round(z),
      critical: Z_999,
      pass: z < Z_999,
      detail: `${((reversed / total) * 100).toFixed(2)} %`,
    });
    const ind = independence(revByCard);
    add(`${label} · reversal independent of card`, ind.s, ind.df);
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
        `${label} · positions 1→2 match sampling without replacement`,
        chi2(observed, expected),
        24,
      );
    }
    // Consecutive draws independent (first card of draw i vs draw i+1).
    const sr = independence(serial);
    add(`${label} · consecutive draws independent`, sr.s, sr.df);
    // Category mix matches the deck (22 major / 56 minor).
    const catCounts = [0, 0, 0, 0, 0];
    perPos[0]!.forEach((c, i) => (catCounts[category(IDS[i]!)]! += c));
    add(
      `${label} · major/suit mix matches the deck`,
      chi2(
        catCounts,
        CAT_P.map((q) => q * n),
      ),
      4,
    );
    checks.push({
      name: `${label} · no repeated card within a spread`,
      statistic: duplicates,
      critical: 0,
      pass: duplicates === 0,
    });
  };

  for (const spread of Object.keys(SPREADS) as SpreadId[]) {
    spreadChecks(spread, spread, (id) => draw(id, spread));
  }
  // 洗牌 → 切牌 → 选牌 (v3.0.0): the whole deck is shuffled from the seed, so a fixed cut and
  // fixed picks give the same fair draw. One spread (a full shuffle costs more per draw).
  spreadChecks("ritual three_card (cut 26, picks 7·61·0)", "three_card", (id) =>
    drawWithRitual(deriveSeed(ritualKey, id), "three_card", { cut: 26, picks: [7, 61, 0] }),
  );

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
