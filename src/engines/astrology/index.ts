import * as Astronomy from "astronomy-engine";
import { inputDigest, SCHEMA_VERSION, type ChartFact } from "../../chart-fact/index.js";
import { localToUtc } from "../bazi/time.js";

/**
 * POC adapter on astronomy-engine (ADR-0001, proposed). Positions are within
 * 0.005° of Swiss Ephemeris; house systems are not implemented yet, so the tier
 * is "simplified": tropical longitudes, signs, retrograde flags, major aspects.
 */
export const ASTROLOGY_ENGINE_VERSION = "0.1.0-poc+astronomy-engine.2.1.19";

const BODIES = [
  "Sun",
  "Moon",
  "Mercury",
  "Venus",
  "Mars",
  "Jupiter",
  "Saturn",
  "Uranus",
  "Neptune",
  "Pluto",
] as const;
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
/** Major aspects and orbs (degrees). Orbs vary by school — common_consensus. */
const ASPECTS = [
  ["conjunction", 0, 8],
  ["sextile", 60, 5],
  ["square", 90, 7],
  ["trine", 120, 7],
  ["opposition", 180, 8],
] as const;

export interface AstrologyInput {
  local: string;
  timezone: string;
  latitude: number;
  longitude: number;
}

function eclipticLongitude(body: Astronomy.Body, utcMs: number): number {
  return Astronomy.Ecliptic(Astronomy.GeoVector(body, Astronomy.MakeTime(new Date(utcMs)), true))
    .elon;
}

export function computeAstrology(
  input: AstrologyInput,
  ctx: { digestPepper: Buffer; now?: () => Date },
): ChartFact {
  const { utcMs } = localToUtc(input.local, input.timezone);
  const HALF_DAY = 43_200_000;

  const bodies = BODIES.map((name) => {
    const body = Astronomy.Body[name];
    const lon = (Math.round(eclipticLongitude(body, utcMs) * 1e4) / 1e4) % 360;
    const motion =
      ((eclipticLongitude(body, utcMs + HALF_DAY) -
        eclipticLongitude(body, utcMs - HALF_DAY) +
        540) %
        360) -
      180;
    return {
      body: name.toLowerCase(),
      longitude: lon,
      sign: SIGNS[Math.floor(lon / 30)]!,
      retrograde: name !== "Sun" && name !== "Moon" && motion < 0,
    };
  });

  const aspects = [];
  for (let i = 0; i < bodies.length; i++) {
    for (let j = i + 1; j < bodies.length; j++) {
      const sep = Math.abs(((bodies[i]!.longitude - bodies[j]!.longitude + 540) % 360) - 180);
      for (const [type, angle, orb] of ASPECTS) {
        if (Math.abs(sep - angle) <= orb) {
          aspects.push({
            a: bodies[i]!.body,
            b: bodies[j]!.body,
            type,
            orb: Math.round(Math.abs(sep - angle) * 100) / 100,
          });
        }
      }
    }
  }

  const rule_versions = { tzdb: process.versions.tz ?? "unknown", aspect_orbs: "major-5/v1" };
  const normalized = {
    ...input,
    latitude: round4(input.latitude),
    longitude: round4(input.longitude),
  };

  return {
    schema_version: SCHEMA_VERSION,
    engine: { name: "astrology", version: ASTROLOGY_ENGINE_VERSION },
    system: "astrology",
    input_digest: inputDigest(
      { input: normalized, engine_version: ASTROLOGY_ENGINE_VERSION, rule_versions },
      ctx.digestPepper,
    ),
    rule_versions,
    computed_at: (ctx.now?.() ?? new Date()).toISOString(),
    facts: { zodiac: "tropical", precision_tier: "simplified", bodies, aspects },
    provenance: [
      {
        path: "/bodies",
        source_level: "derived",
        note: "astronomy-engine (VSOP87/ELP), ≤0.005° vs Swiss Ephemeris",
      },
      {
        path: "/aspects",
        source_level: "common_consensus",
        note: "五种主相位；容许度依通行西洋占星惯例",
      },
    ],
  };
}

const round4 = (x: number) => Math.round(x * 1e4) / 1e4;
