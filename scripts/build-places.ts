/**
 * Builds the birthplace gazetteer served by /v1/places (country → region → city).
 *
 *   npm run build:places      # downloads GeoNames once into .cache/geonames
 *
 * Source: GeoNames (CC BY 4.0, https://www.geonames.org): cities15000 (every place
 * with ≥15 000 people, or a seat of government), admin1 codes, and Chinese
 * alternate names for the countries in ZH_NAMES. Country names come from the ICU
 * data bundled with Node (Intl.DisplayNames). Where GeoNames has a name in only one
 * Chinese script, the other is converted with OpenCC (cn ↔ hk).
 *
 * Output (committed; the API and `npm run sync:app` read it, never GeoNames):
 *   data/places/index.json    countries with names
 *   data/places/<CC>.json     regions (admin1) with cities: names, IANA timezone, lon, lat
 */
import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import OpenCC from "opencc-js";

const CACHE = new URL("../.cache/geonames/", import.meta.url);
const OUT = new URL("../data/places/", import.meta.url);
const BASE = "https://download.geonames.org/export/dump/";

/** Countries whose provinces and cities get Chinese names (launch markets + common birthplaces). */
const ZH_NAMES = [
  "CN",
  "HK",
  "MO",
  "TW",
  "SG",
  "MY",
  "US",
  "CA",
  "GB",
  "AU",
  "NZ",
  "JP",
  "KR",
  "TH",
  "VN",
  "PH",
  "ID",
  "FR",
  "DE",
  "IT",
];

/**
 * Zones newer than the tzdb in older Node builds, mapped to the zone they split
 * from. Births before the split have identical local time in both, so 八字 results
 * don't change; the parent works on every Node. America/Coyhaique: split from
 * America/Santiago in tzdb 2025b (Aysén stopped following Chile's DST in 2025).
 */
const SPLIT_ZONES: Record<string, string> = {
  "America/Coyhaique": "America/Santiago",
};

function checkedZone(tz: string): string {
  const zone = SPLIT_ZONES[tz] ?? tz;
  try {
    new Intl.DateTimeFormat("en", { timeZone: zone });
  } catch {
    throw new Error(
      `timezone ${tz} is unknown to this Node (tzdb ${process.versions.tz}); add it to SPLIT_ZONES`,
    );
  }
  return zone;
}

/** Feature codes left out: city sections, historical, abandoned, destroyed, religious sites. */
const SKIP_FEATURES = new Set(["PPLX", "PPLH", "PPLQ", "PPLW", "PPLCH"]);

/** Countries whose every administrative seat is included, whatever its population. */
const FULL_DUMP = ["CN", "TW", "HK", "MO", "MY", "SG"];
/** Capital and seats of first/second/third-order divisions (省 / 地级 / 县级 in China). */
const SEAT_FEATURES = new Set(["PPLC", "PPLA", "PPLA2", "PPLA3"]);

type Names = { "zh-Hant": string; "zh-Hans": string; en: string };
const toHant = OpenCC.Converter({ from: "cn", to: "hk" });
const toHans = OpenCC.Converter({ from: "hk", to: "cn" });

async function cached(file: string): Promise<URL> {
  const url = new URL(file, CACHE);
  if (existsSync(url)) return url;
  mkdirSync(new URL(".", url), { recursive: true });
  for (let attempt = 1; ; attempt++) {
    console.log(`downloading ${file}${attempt > 1 ? ` (attempt ${attempt})` : ""}`);
    try {
      const res = await fetch(BASE + file);
      if (!res.ok) throw new Error(`${file}: HTTP ${res.status}`);
      writeFileSync(url, Buffer.from(await res.arrayBuffer()));
      return url;
    } catch (e) {
      if (attempt >= 4) throw e;
      await new Promise((r) => setTimeout(r, 3000 * attempt));
    }
  }
}

/** Text of the .txt inside a GeoNames zip (unzip, or bsdtar on Windows). */
function unzipText(zip: URL, entry: string): string {
  const dir = new URL(`x-${entry}/`, CACHE);
  rmSync(dir, { recursive: true, force: true });
  mkdirSync(dir, { recursive: true });
  const [zipPath, dirPath] = [fileURLToPath(zip), fileURLToPath(dir)];
  try {
    execFileSync("unzip", ["-o", "-q", zipPath, entry, "-d", dirPath]);
  } catch {
    execFileSync("tar", ["-xf", zipPath, "-C", dirPath, entry]);
  }
  const text = readFileSync(new URL(entry, dir), "utf8");
  rmSync(dir, { recursive: true, force: true });
  return text;
}

const rows = (text: string) =>
  text
    .split("\n")
    .filter((l) => l && !l.startsWith("#"))
    .map((l) => l.split("\t"));

/** Best Chinese names per geonameid from a country's alternate-names file. */
type ZhNames = { hant?: string; hans?: string; any?: string; bare?: string };
/** Untagged names written only in Chinese characters (GeoNames often leaves 靖江 untagged). */
const ALL_HAN = /^[一-鿿]+$/;

function chineseNames(text: string): Map<string, ZhNames> {
  const out = new Map<string, ZhNames & { pref: Record<string, boolean> }>();
  for (const r of rows(text)) {
    const [, id, lang, name, preferred, , colloquial, historic] = r;
    if (!id || !name || colloquial === "1" || historic === "1") continue;
    const slot =
      lang === "zh-TW" || lang === "zh-Hant" || lang === "zh-HK"
        ? "hant"
        : lang === "zh-CN" || lang === "zh-Hans"
          ? "hans"
          : lang === "zh"
            ? "any"
            : !lang && ALL_HAN.test(name)
              ? "bare"
              : undefined;
    if (!slot) continue;
    const e = out.get(id) ?? { pref: {} };
    // Keep the first name per slot unless a later one is marked preferred.
    if (!e[slot] || (preferred === "1" && !e.pref[slot])) {
      e[slot] = name;
      e.pref[slot] = preferred === "1";
    }
    out.set(id, e);
  }
  return out;
}

/** Places whose own usage is 繁體: their 简体 name is converted from it, never taken from zh-CN. */
const HANT_FIRST = new Set(["TW", "HK", "MO"]);

/**
 * One Chinese name, then the other script by conversion, so 繁/简 always agree
 * (GeoNames' zh-CN and zh-TW entries often differ in more than script, e.g. 广州市 vs 廣州).
 */
function namesFor(cc: string, en: string, zh?: ZhNames): Names {
  // Untagged Chinese only for the countries whose full dump we read (not e.g. JP kanji).
  const any = zh?.any ?? (FULL_DUMP.includes(cc) ? zh?.bare : undefined);
  if (!zh || !(zh.hant || zh.hans || any)) return { "zh-Hant": en, "zh-Hans": en, en };
  if (HANT_FIRST.has(cc)) {
    const hant = zh.hant ?? toHant(any ?? zh.hans!);
    return { "zh-Hant": hant, "zh-Hans": toHans(hant), en };
  }
  const hans = zh.hans ?? toHans(any ?? zh.hant!);
  return { "zh-Hant": toHant(hans), "zh-Hans": hans, en };
}

const display = {
  "zh-Hant": new Intl.DisplayNames(["zh-Hant-HK"], { type: "region" }),
  "zh-Hans": new Intl.DisplayNames(["zh-Hans"], { type: "region" }),
  en: new Intl.DisplayNames(["en"], { type: "region" }),
};
/** Short names where ICU's are long for a picker ("中國香港特別行政區"). */
const SHORT: Record<string, Names> = {
  HK: { "zh-Hant": "香港", "zh-Hans": "香港", en: "Hong Kong" },
  MO: { "zh-Hant": "澳門", "zh-Hans": "澳门", en: "Macao" },
};
const countryNames = (cc: string): Names =>
  SHORT[cc] ?? {
    "zh-Hant": display["zh-Hant"].of(cc) ?? cc,
    "zh-Hans": display["zh-Hans"].of(cc) ?? cc,
    en: display.en.of(cc) ?? cc,
  };

/**
 * Countries whose GeoNames admin1 is too coarse for a 省/市 picker: group by admin2.
 * Taiwan's admin1 is the old 4-way split; admin2 is the 直轄市 / 縣市 level.
 */
const REGION_BY_ADMIN2 = new Set(["TW"]);

const round = (n: number, d = 4) => Math.round(n * 10 ** d) / 10 ** d;

// ---- build ----

const cities = rows(unzipText(await cached("cities15000.zip"), "cities15000.txt"));
// cities15000 misses many county-level cities that GeoNames lists without a
// population (e.g. 靖江, ~700k people). For the main Chinese-speaking countries add
// every seat of administration (capital, 省/地级/县级 seats) from the full dump.
const seen = new Set(cities.map((r) => r[0]));
/**
 * Divisions by parent codes ("CN.04.3212.3" → ADM3 rows under 江苏 / 泰州). A seat's
 * own lower codes are often empty (靖江 PPLA3 has no admin3), so a seat is matched to
 * the division under the same parents whose name starts with the seat's name
 * ("Jingjiang" → "Jingjiang Shi").
 */
const divisions = new Map<string, { id: string; name: string }[]>();
const parentKey = (cc: string, a1: string, a2: string, level: number) =>
  [cc, a1, level >= 2 ? a2 : "", level].join(".");
for (const cc of FULL_DUMP) {
  for (const r of rows(unzipText(await cached(`${cc}.zip`), `${cc}.txt`))) {
    const [id, name, , , , , cls, feature, , , a1, a2] = r;
    if (cls === "A" && /^ADM[123]$/.test(feature!)) {
      const k = parentKey(cc, a1!, a2!, Number(feature!.slice(3)));
      divisions.set(k, [...(divisions.get(k) ?? []), { id: id!, name: name! }]);
    }
    if (cls === "P" && SEAT_FEATURES.has(feature!) && !seen.has(id)) {
      cities.push(r);
      seen.add(id);
    }
  }
}
/** A seat's own Chinese name, else the name of the division it is the seat of (靖江 → 靖江市). */
function seatChinese(cc: string, r: string[]) {
  const own = zh.get(cc)?.get(r[0]!);
  if ((own && (own.hans || own.hant || own.any)) || !FULL_DUMP.includes(cc)) return own;
  // A seat's own level first; any other place (cities15000 lists many county cities
  // as plain PPL) tries the county, then the prefecture division of the same name.
  const own_level = { PPLA: 1, PPLA2: 2, PPLA3: 3 }[r[7]!];
  const seatName = r[1]!.replace(/ (City|Shi|Xian|Qu|Town)$/, "");
  for (const level of own_level ? [own_level] : [3, 2]) {
    const div = divisions
      .get(parentKey(cc, r[10]!, r[11]!, level))
      ?.find((d) => d.name === seatName || d.name.startsWith(seatName + " "));
    const fromDivision = div ? zh.get(cc)?.get(div.id) : undefined;
    if (fromDivision && (fromDivision.hans || fromDivision.hant || fromDivision.any))
      return fromDivision;
  }
  return own;
}
const admin1 = new Map(
  rows(readFileSync(await cached("admin1CodesASCII.txt"), "utf8")).map(([code, name, , id]) => [
    code!,
    { name: name!, id: id! },
  ]),
);
const admin2 = new Map(
  rows(readFileSync(await cached("admin2Codes.txt"), "utf8"))
    .filter(([code]) => REGION_BY_ADMIN2.has(code!.slice(0, 2)))
    .map(([code, name, , id]) => [code!, { name: name!, id: id! }]),
);
const zh = new Map<string, ReturnType<typeof chineseNames>>();
for (const cc of ZH_NAMES) {
  zh.set(cc, chineseNames(unzipText(await cached(`alternatenames/${cc}.zip`), `${cc}.txt`)));
}

interface City {
  id: number;
  names: Names;
  tz: string;
  lon: number;
  lat: number;
  pop: number;
}
const byCountry = new Map<string, Map<string, City[]>>();
for (const r of cities) {
  const [id, name, , , lat, lon, , feature, cc, , a1, a2, , , pop, , , tz] = r;
  if (!cc || !tz || SKIP_FEATURES.has(feature!)) continue;
  const regions = byCountry.get(cc) ?? new Map<string, City[]>();
  const key = REGION_BY_ADMIN2.has(cc) && a2 ? `${a1}.${a2}` : a1!;
  const list = regions.get(key) ?? [];
  list.push({
    id: Number(id),
    names: namesFor(cc, name!, seatChinese(cc, r)),
    tz: checkedZone(tz),
    lon: round(Number(lon)),
    lat: round(Number(lat)),
    pop: Number(pop),
  });
  regions.set(key, list);
  byCountry.set(cc, regions);
}

rmSync(OUT, { recursive: true, force: true });
mkdirSync(OUT, { recursive: true });
const OTHER: Names = { "zh-Hant": "其他地區", "zh-Hans": "其他地区", en: "Other" };
const index = [];
for (const [cc, regions] of [...byCountry].sort(([a], [b]) => a.localeCompare(b))) {
  const list = [...regions].map(([code, list]) => {
    const a = code.includes(".") ? admin2.get(`${cc}.${code}`) : admin1.get(`${cc}.${code}`);
    return {
      code,
      names: a ? namesFor(cc, a.name, zh.get(cc)?.get(a.id)) : OTHER,
      cities: list.sort((x, y) => y.pop - x.pop).map(({ pop: _p, ...c }) => c),
      pop: a ? list.reduce((s, c) => s + c.pop, 0) : -1,
    };
  });
  // Most populous regions first, "Other" last; the app also offers search.
  list.sort((x, y) => y.pop - x.pop);
  const regionsOut = list.map(({ pop: _p, ...r }) => r);
  writeFileSync(
    new URL(`${cc}.json`, OUT),
    JSON.stringify({ country: cc, regions: regionsOut }) + "\n",
  );
  index.push({
    code: cc,
    names: countryNames(cc),
    cities: list.reduce((s, r) => s + r.cities.length, 0),
  });
}
writeFileSync(
  new URL("index.json", OUT),
  JSON.stringify(
    {
      source:
        "GeoNames cities15000 (CC BY 4.0, https://www.geonames.org), built by scripts/build-places.ts",
      countries: index,
    },
    null,
    1,
  ) + "\n",
);
console.log(
  `wrote ${index.length} countries, ${index.reduce((s, c) => s + c.cities, 0)} cities; files: ${readdirSync(OUT).length}`,
);
