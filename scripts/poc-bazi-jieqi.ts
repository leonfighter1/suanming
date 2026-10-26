/**
 * 八字 POC, 节气 precision: lunar-javascript's 节气 instants vs Swiss Ephemeris
 * solar-longitude crossings, 1900–2100. Month/year pillars flip exactly at these
 * instants, so this bounds the boundary error of BaziEngine independently of any
 * third-party 排盘 tool.
 * Output: docs/poc/bazi-jieqi-results.json
 */
import { writeFileSync } from "node:fs";
import lunar from "lunar-javascript";
import sweph from "sweph";

const C = sweph.constants;
// 节 (month-starting terms) and their solar longitudes. Only 节 move pillars.
const JIE: Record<string, number> = {
  小寒: 285,
  立春: 315,
  惊蛰: 345,
  清明: 15,
  立夏: 45,
  芒种: 75,
  小暑: 105,
  立秋: 135,
  白露: 165,
  寒露: 195,
  立冬: 225,
  大雪: 255,
};

const errorsMin: number[] = [];
let worst = { min: 0, year: 0, name: "" };

for (let year = 1900; year <= 2100; year++) {
  const table = lunar.Solar.fromYmdHms(year, 6, 15, 12, 0, 0).getLunar().getJieQiTable();
  for (const [name, lon] of Object.entries(JIE)) {
    const s = table[name];
    if (!s) continue;
    const [d, t] = s.toYmdHms().split(" ") as [string, string];
    const libUtcMs = Date.parse(`${d}T${t}+08:00`);
    if (new Date(libUtcMs).getUTCFullYear() !== year) continue; // table spans adjacent years
    const startJd = libUtcMs / 86_400_000 + 2440587.5 - 2;
    const ref = sweph.solcross_ut(lon, startJd, C.SEFLG_MOSEPH);
    const refUtcMs = (ref.date - 2440587.5) * 86_400_000;
    const e = (libUtcMs - refUtcMs) / 60_000;
    errorsMin.push(Math.abs(e));
    if (Math.abs(e) > Math.abs(worst.min)) worst = { min: Math.round(e * 100) / 100, year, name };
  }
}

const sorted = [...errorsMin].sort((a, b) => a - b);
const pct = (p: number) => Math.round(sorted[Math.floor(p * (sorted.length - 1))]! * 100) / 100;
const result = {
  generated_at: new Date().toISOString(),
  reference: "Swiss Ephemeris 2.10 swe_solcross_ut, Moshier",
  library: "lunar-javascript 1.7.7 getJieQiTable (UTC+8, second resolution)",
  samples: errorsMin.length,
  abs_error_minutes: { p50: pct(0.5), p99: pct(0.99), max: pct(1) },
  worst,
  note: "Errors are in minutes. lunar-javascript truncates to whole seconds.",
};
writeFileSync(
  new URL("../docs/poc/bazi-jieqi-results.json", import.meta.url),
  JSON.stringify(result, null, 2) + "\n",
);
console.log(result);
