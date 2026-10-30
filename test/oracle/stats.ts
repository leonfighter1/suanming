/**
 * What the statistical batteries share (S28 WP28.3; docs/refactor-plan.md F11): the tarot, 求签 and 算卦 batteries
 * each test their draw with chi-square or z tests at α = 0.001 (Wilson–Hilferty critical values), on deterministic
 * draw ids so results are reproducible.
 */

export const Z_999 = 3.09;
export const chi2Critical = (df: number, z = Z_999) => {
  const a = 2 / (9 * df);
  return df * (1 - a + z * Math.sqrt(a)) ** 3;
};

/** The [i]th deterministic draw id. */
export const drawId = (i: number) => `00000000-0000-4000-8000-${i.toString(16).padStart(12, "0")}`;

export interface Check {
  name: string;
  statistic: number;
  critical: number;
  pass: boolean;
  detail?: string;
}

export function chi2(observed: number[], expected: number[]) {
  return observed.reduce((s, o, i) => s + (o - expected[i]!) ** 2 / expected[i]!, 0);
}

/** Chi-square test of independence on a contingency table. */
export function independence(table: number[][]) {
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

export const round = (x: number) => Math.round(x * 100) / 100;
