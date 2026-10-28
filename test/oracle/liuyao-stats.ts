/**
 * Statistical battery for 算卦's coins (tech plan WP10.1): the auto cast (18 coins from HMAC-DRBG) and the
 * pick layout (24 coins). Each check is a chi-square or z test at α = 0.001 on deterministic draw ids, so
 * results are reproducible.
 * Null hypothesis: every coin falls 背 or 字 with chance ½, independently. So a line (背 3, 字 2) is 6, 7, 8, 9
 * with 1/8, 3/8, 3/8, 1/8 at every position, each of the 64 hexagrams comes with 1/64, and the number of
 * moving lines is Binomial(6, ¼).
 */
import {
  deriveLayoutSeed,
  deriveSeed,
  layoutWithSeed,
  lineOf,
  tossWithSeed,
  type Face,
} from "../../src/engines/liuyao/index.js";
import { chi2Critical, type Check } from "./tarot-stats.js";

const Z_999 = 3.09;
const drawId = (i: number) => `00000000-0000-4000-8000-${i.toString(16).padStart(12, "0")}`;
const VALUES = [6, 7, 8, 9] as const;
const LINE_P = [1 / 8, 3 / 8, 3 / 8, 1 / 8];

function chi2(observed: number[], expected: number[]) {
  return observed.reduce((s, o, i) => s + (o - expected[i]!) ** 2 / expected[i]!, 0);
}

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

const choose = (n: number, k: number): number =>
  k === 0 ? 1 : (choose(n, k - 1) * (n - k + 1)) / k;

export type TossFn = (drawId: string) => Face[][];
export type LayoutFn = (drawId: string) => Face[];

/** The production casts: seeds from HMAC(drawKey, "liuyao-seed/v1:" / "liuyao-layout/v1:" + id). */
export const realToss =
  (key = Buffer.alloc(32, 9)): TossFn =>
  (id) =>
    tossWithSeed(deriveSeed(key, id));
export const realLayout =
  (key = Buffer.alloc(32, 9)): LayoutFn =>
  (id) =>
    layoutWithSeed(deriveLayoutSeed(key, id));

export function liuyaoBattery(
  n: number,
  toss: TossFn = realToss(),
  layout: LayoutFn = realLayout(),
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
  const z = (name: string, hits: number, trials: number) => {
    const s = Math.abs((hits - trials / 2) / Math.sqrt(trials / 4));
    checks.push({
      name,
      statistic: round(s),
      critical: Z_999,
      pass: s < Z_999,
      detail: `${((hits / trials) * 100).toFixed(2)} %`,
    });
  };

  let bei = 0;
  const lines = new Array<number>(4).fill(0);
  const byPosition = Array.from({ length: 6 }, () => new Array<number>(4).fill(0));
  const serial = Array.from({ length: 4 }, () => new Array<number>(4).fill(0));
  const coinPair = [
    [0, 0],
    [0, 0],
  ];
  const hexagrams = new Array<number>(64).fill(0);
  const moving = new Array<number>(7).fill(0);
  let layoutBei = 0;
  const layoutByPosition = Array.from({ length: 24 }, () => [0, 0]);
  const picked = new Array<number>(4).fill(0);

  for (let i = 0; i < n; i++) {
    const cast = toss(drawId(i));
    let hex = 0;
    let moves = 0;
    let prev: number | undefined;
    cast.forEach((coins, pos) => {
      bei += coins.filter((c) => c === "bei").length;
      coinPair[coins[0] === "bei" ? 1 : 0]![coins[1] === "bei" ? 1 : 0]!++;
      const v = VALUES.indexOf(lineOf(coins) as (typeof VALUES)[number]);
      lines[v]!++;
      byPosition[pos]![v]!++;
      if (prev !== undefined) serial[prev]![v]!++;
      prev = v;
      if (v === 1 || v === 3) hex |= 1 << pos; // 7 and 9 are yang
      if (v === 0 || v === 3) moves++;
    });
    hexagrams[hex]!++;
    moving[moves]!++;

    const coins = layout(drawId(i));
    coins.forEach((c, pos) => {
      if (c === "bei") layoutBei++;
      layoutByPosition[pos]![c === "bei" ? 1 : 0]!++;
    });
    // A pick cast always turning over the first three coins gets a fair line all the same.
    picked[VALUES.indexOf(lineOf(coins.slice(0, 3)) as (typeof VALUES)[number])]!++;
  }

  z("each coin falls 背 half the time", bei, n * 18);
  add("the coins of a toss fall independently", independence(coinPair).s, 1);
  add(
    "lines are 老陰 1/8, 少陽 3/8, 少陰 3/8, 老陽 1/8",
    chi2(
      lines,
      LINE_P.map((p) => p * n * 6),
    ),
    3,
    lines.join(" / "),
  );
  const pos = independence(byPosition);
  add("a line doesn't depend on its position", pos.s, pos.df);
  const ser = independence(serial);
  add("each line is independent of the one below", ser.s, ser.df);
  add("the 64 hexagrams are uniform", chi2(hexagrams, new Array<number>(64).fill(n / 64)), 63);
  add(
    "moving lines per cast are Binomial(6, ¼)",
    chi2(
      moving,
      moving.map((_, k) => n * choose(6, k) * 0.25 ** k * 0.75 ** (6 - k)),
    ),
    6,
    `mean ${(moving.reduce((s, c, k) => s + c * k, 0) / n).toFixed(3)} (expected 1.5)`,
  );
  z("each laid-out coin is 背 half the time", layoutBei, n * 24);
  add(
    "a laid-out coin doesn't depend on its place",
    independence(layoutByPosition).s,
    independence(layoutByPosition).df,
  );
  add(
    "a picked line is 1/8, 3/8, 3/8, 1/8",
    chi2(
      picked,
      LINE_P.map((p) => p * n),
    ),
    3,
  );

  return { casts: n, checks, pass: checks.every((c) => c.pass) };
}

const round = (x: number) => Math.round(x * 100) / 100;
