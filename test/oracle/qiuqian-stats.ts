/**
 * Statistical battery for the 求籤 draw (HMAC-DRBG: a stick, then two blocks, per round, until a 聖筊).
 * Each check is a chi-square or z test at α = 0.001 on deterministic draw ids, so results are reproducible.
 * Null hypothesis: fair, independent sticks and blocks; every stick is one of 100 with equal chance, each block
 * lands flat with p = ½, so a round is 聖筊 ½, 笑筊 ¼, 陰筊 ¼ and the rounds per draw are geometric (½).
 */
import { deriveSeed, drawWithSeed, type Round } from "../../src/engines/qiuqian/index.js";
import { chi2Critical, type Check } from "./tarot-stats.js";

const Z_999 = 3.09;
const LOTS = 100;
const drawId = (i: number) => `00000000-0000-4000-8000-${i.toString(16).padStart(12, "0")}`;

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

export type QiuqianDrawFn = (drawId: string) => Round[];

/** The production draw: seed = HMAC(drawKey, "qiuqian-seed/v1:" + draw id). Tests can inject a biased one. */
export const realQiuqianDraw =
  (key = Buffer.alloc(32, 9)): QiuqianDrawFn =>
  (id) =>
    drawWithSeed(deriveSeed(key, id), LOTS);

export function qiuqianBattery(n: number, draw: QiuqianDrawFn = realQiuqianDraw()) {
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
  const decile = (lot: number) => Math.floor((lot - 1) / 10);

  const first = new Array<number>(LOTS).fill(0);
  const confirmed = new Array<number>(LOTS).fill(0);
  const outcomes = { sheng: 0, xiao: 0, yin: 0 };
  const faces = [
    [0, 0],
    [0, 0],
  ]; // [block 1 flat?][block 2 flat?]
  const length = new Array<number>(7).fill(0); // rounds 1–6, then 7 or more
  const serial = Array.from({ length: 10 }, () => new Array<number>(10).fill(0));
  const within = Array.from({ length: 10 }, () => new Array<number>(10).fill(0));
  let rounds = 0;
  let prev: number | undefined;

  for (let i = 0; i < n; i++) {
    const rs = draw(drawId(i));
    rounds += rs.length;
    length[Math.min(rs.length, 7) - 1]!++;
    first[rs[0]!.lot - 1]!++;
    const lot = rs.at(-1)!.lot;
    confirmed[lot - 1]!++;
    for (const r of rs) {
      outcomes[r.result]++;
      faces[r.blocks[0] === "flat" ? 1 : 0]![r.blocks[1] === "flat" ? 1 : 0]!++;
    }
    if (rs.length >= 2) within[decile(rs[0]!.lot)]![decile(rs[1]!.lot)]!++;
    if (prev !== undefined) serial[decile(prev)]![decile(lot)]!++;
    prev = lot;
  }

  const uniform = new Array<number>(LOTS).fill(n / LOTS);
  add("the first stick is uniform over 100 lots", chi2(first, uniform), 99);
  add("the confirmed lot is uniform over 100 lots", chi2(confirmed, uniform), 99);

  const blocks = rounds * 2;
  const flat = faces[1]![0]! + faces[1]![1]! + faces[0]![1]! + faces[1]![1]!;
  const z = Math.abs((flat - blocks / 2) / Math.sqrt(blocks / 4));
  checks.push({
    name: "each block lands flat half the time",
    statistic: round(z),
    critical: Z_999,
    pass: z < Z_999,
    detail: `${((flat / blocks) * 100).toFixed(2)} %`,
  });
  const ind = independence(faces);
  add("the two blocks land independently", ind.s, ind.df);
  add(
    "throws are 聖筊 ½, 笑筊 ¼, 陰筊 ¼",
    chi2([outcomes.sheng, outcomes.xiao, outcomes.yin], [rounds / 2, rounds / 4, rounds / 4]),
    2,
    `${outcomes.sheng} / ${outcomes.xiao} / ${outcomes.yin}`,
  );
  // P(k rounds) = 2^−k; P(7 or more) = 2^−6.
  add(
    "rounds per draw are geometric (½)",
    chi2(
      length,
      length.map((_, k) => n * 2 ** -(k < 6 ? k + 1 : 6)),
    ),
    6,
    `mean ${(rounds / n).toFixed(3)} (expected 2)`,
  );
  const w = independence(within);
  add("the second stick is independent of the first (deciles)", w.s, w.df);
  const s = independence(serial);
  add("consecutive draws are independent (deciles)", s.s, s.df);

  return { draws: n, checks, pass: checks.every((c) => c.pass) };
}

const round = (x: number) => Math.round(x * 100) / 100;
