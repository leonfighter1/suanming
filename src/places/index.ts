/**
 * Birthplace gazetteer (country → region → city), read from data/places, which
 * `npm run build:places` generates from GeoNames (CC BY 4.0). Each city carries
 * its IANA timezone (historical DST) and longitude (真太陽時).
 */
import { existsSync, readFileSync } from "node:fs";

export type PlaceNames = { "zh-Hant": string; "zh-Hans": string; en: string };

export interface PlaceCity {
  id: number;
  names: PlaceNames;
  tz: string;
  lon: number;
  lat: number;
}

export interface PlaceRegion {
  code: string;
  names: PlaceNames;
  cities: PlaceCity[];
}

export interface PlaceCountry {
  country: string;
  regions: PlaceRegion[];
}

export interface PlaceIndex {
  source: string;
  countries: { code: string; names: PlaceNames; cities: number }[];
}

const DIR = new URL("../../data/places/", import.meta.url);
let index: PlaceIndex | undefined;
const countries = new Map<string, PlaceCountry>();

export function placeIndex(): PlaceIndex {
  index ??= JSON.parse(readFileSync(new URL("index.json", DIR), "utf8")) as PlaceIndex;
  return index;
}

/** Regions and cities of one country (ISO 3166-1 alpha-2), or undefined if unknown. */
export function placeCountry(code: string): PlaceCountry | undefined {
  if (!/^[A-Z]{2}$/.test(code)) return undefined;
  const hit = countries.get(code);
  if (hit) return hit;
  const file = new URL(`${code}.json`, DIR);
  if (!existsSync(file)) return undefined;
  const data = JSON.parse(readFileSync(file, "utf8")) as PlaceCountry;
  countries.set(code, data);
  return data;
}
