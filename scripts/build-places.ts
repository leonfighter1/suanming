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
function chineseNames(text: string): Map<string, { hant?: string; hans?: string; any?: string }> {
  const out = new Map<
    string,
    { hant?: string; hans?: string; any?: string; pref: Record<string, boolean> }
  >();
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
function namesFor(
  cc: string,
  en: string,
  zh?: { hant?: string; hans?: string; any?: string },
): Names {
  if (!zh || !(zh.hant || zh.hans || zh.any)) return { "zh-Hant": en, "zh-Hans": en, en };
  if (HANT_FIRST.has(cc)) {
    const hant = zh.hant ?? toHant(zh.any ?? zh.hans!);
    return { "zh-Hant": hant, "zh-Hans": toHans(hant), en };
  }
  const hans = zh.hans ?? toHans(zh.any ?? zh.hant!);
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
    names: namesFor(cc, name!, zh.get(cc)?.get(id!)),
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
