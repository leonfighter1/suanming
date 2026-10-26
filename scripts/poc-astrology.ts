/**
 * Astrology engine POC: candidates vs Swiss Ephemeris (Moshier, no data files).
 * Candidates: @gitstrology/engine 0.1.0 (doc's choice), astronomy-engine 2.1.19 (MIT).
 * Gate (Phase 0 §2.1): ecliptic longitude error ≤ 0.01°; houses consistent on known cases.
 * Output: docs/poc/astrology-results.json
 */
import { writeFileSync } from "node:fs";
import { natalChart } from "@gitstrology/engine";
import * as Astronomy from "astronomy-engine";
import sweph from "sweph";

const C = sweph.constants;
const BODIES = {
  sun: C.SE_SUN,
  moon: C.SE_MOON,
  mercury: C.SE_MERCURY,
  venus: C.SE_VENUS,
  mars: C.SE_MARS,
  jupiter: C.SE_JUPITER,
  saturn: C.SE_SATURN,
  uranus: C.SE_URANUS,
  neptune: C.SE_NEPTUNE,
  pluto: C.SE_PLUTO,
} as const;
const SIGNS = [
  "aries",
  "taurus",
  "gemini",
  "cancer",
  "leo",
  "virgo",
  "libra",
  "scorpio",
  "sagittarius",
  "capricorn",
  "aquarius",
  "pisces",
];
const GATE_DEG = 0.01;

// 20 cases: spread over 1940–2030, all seasons, both hemispheres, the launch cities.
const PLACES = [
  ["Hong Kong", 22.3193, 114.1694],
  ["Taipei", 25.033, 121.5654],
  ["Singapore", 1.3521, 103.8198],
  ["Kuala Lumpur", 3.139, 101.6869],
  ["New York", 40.7128, -74.006],
  ["Vancouver", 49.2827, -123.1207],
  ["Sydney", -33.8688, 151.2093],
  ["London", 51.5074, -0.1278],
  ["Toronto", 43.6532, -79.3832],
  ["Reykjavik", 64.1466, -21.9426],
] as const;
const cases = Array.from({ length: 20 }, (_, i) => {
  const [place, lat, lon] = PLACES[i % PLACES.length]!;
  const utc = new Date(
    Date.UTC(1940 + i * 4.5, (i * 5) % 12, 1 + ((i * 11) % 27), (i * 7) % 24, (i * 13) % 60),
  );
  return { place, lat, lon, utc };
});

const diff = (a: number, b: number) => ((a - b + 540) % 360) - 180;
const CANDIDATES = ["@gitstrology/engine@0.1.0", "astronomy-engine@2.1.19"] as const;
const perBody: Record<string, Record<string, number[]>> = Object.fromEntries(
  CANDIDATES.map((c) => [c, Object.fromEntries(Object.keys(BODIES).map((b) => [b, []]))]),
);
const aeLongitude = (body: string, utc: Date) =>
  Astronomy.Ecliptic(
    Astronomy.GeoVector(
      Astronomy.Body[(body[0]!.toUpperCase() + body.slice(1)) as "Sun"],
      Astronomy.MakeTime(utc),
      true,
    ),
  ).elon;
const rows: unknown[] = [];
let ascSignAgree = 0;

for (const c of cases) {
  const iso = c.utc.toISOString();
  const chart = natalChart({
    date: iso.slice(0, 10),
    time: iso.slice(11, 16),
    latitude: c.lat,
    longitude: c.lon,
  });
  const jd = sweph.utc_to_jd(
    c.utc.getUTCFullYear(),
    c.utc.getUTCMonth() + 1,
    c.utc.getUTCDate(),
    c.utc.getUTCHours(),
    c.utc.getUTCMinutes(),
    0,
    C.SE_GREG_CAL,
  ).data[1];
  const errors: Record<string, Record<string, number>> = {};
  for (const [body, id] of Object.entries(BODIES)) {
    const ref = sweph.calc_ut(jd, id, C.SEFLG_MOSEPH).data[0];
    const got = {
      [CANDIDATES[0]]: chart.planets.find((p) => p.planet === body)!.longitude,
      [CANDIDATES[1]]: aeLongitude(body, c.utc),
    };
    for (const cand of CANDIDATES) {
      (errors[cand] ??= {})[body] = Math.round(diff(got[cand]!, ref) * 1e4) / 1e4;
      perBody[cand]![body]!.push(Math.abs(diff(got[cand]!, ref)));
    }
  }
  const asc = sweph.houses(jd, c.lat, c.lon, "P").data.points[0]!;
  const refAscSign = SIGNS[Math.floor(asc / 30)];
  if (refAscSign === chart.risingSign) ascSignAgree++;
  rows.push({
    place: c.place,
    utc: iso,
    errors_deg: errors,
    asc_ref_sign: refAscSign,
    asc_lib_sign: chart.risingSign,
  });
}

const summarize = (pb: Record<string, number[]>) =>
  Object.fromEntries(
    Object.entries(pb).map(([b, e]) => [
      b,
      {
        max_abs_deg: Math.round(Math.max(...e) * 1e4) / 1e4,
        mean_abs_deg: Math.round((e.reduce((s, x) => s + x, 0) / e.length) * 1e4) / 1e4,
        pass: Math.max(...e) <= GATE_DEG,
      },
    ]),
  );
const summary = Object.fromEntries(CANDIDATES.map((c) => [c, summarize(perBody[c]!)]));
const result = {
  generated_at: new Date().toISOString(),
  reference:
    "Swiss Ephemeris 2.10 via sweph, Moshier ephemeris (SEFLG_MOSEPH), geocentric apparent tropical",
  candidates: CANDIDATES,
  gate_deg: GATE_DEG,
  cases: cases.length,
  summary,
  gitstrology_ascendant_sign_agreement: `${ascSignAgree}/${cases.length}`,
  houses_note:
    "gitstrology: whole-sign houses only, ascendant ~1° per its docs. astronomy-engine: no house systems (must be implemented in-house).",
  gate_pass: Object.fromEntries(
    CANDIDATES.map((c) => [c, Object.values(summary[c]!).every((s) => s.pass)]),
  ),
  rows,
};
writeFileSync(
  new URL("../docs/poc/astrology-results.json", import.meta.url),
  JSON.stringify(result, null, 2) + "\n",
);

for (const c of CANDIDATES) {
  console.log(c);
  console.table(summary[c]);
  console.log(`GATE (≤ ${GATE_DEG}° all bodies): ${result.gate_pass[c] ? "PASS" : "FAIL"}
`);
}
console.log(`gitstrology ascendant sign agreement: ${result.gitstrology_ascendant_sign_agreement}`);
