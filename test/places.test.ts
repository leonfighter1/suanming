import type { AddressInfo } from "node:net";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { MockProvider } from "../src/ai/index.js";
import { createApiServer } from "../src/api/server.js";
import { computeBazi } from "../src/engines/bazi/index.js";
import { placeCountry, placeIndex } from "../src/places/index.js";
import { DRAW_KEY, FIXED_NOW, PEPPER } from "./helpers.js";

describe("birthplace gazetteer (data/places)", () => {
  const codes = placeIndex().countries.map((c) => c.code);

  it("covers the launch markets and common birthplaces, with GeoNames attribution", () => {
    for (const c of ["CN", "HK", "MO", "TW", "SG", "MY", "US", "CA", "GB", "AU"]) {
      expect(codes).toContain(c);
    }
    expect(placeIndex().source).toMatch(/GeoNames.*CC BY 4\.0/);
    const hk = placeIndex().countries.find((c) => c.code === "HK")!;
    expect(hk.names).toEqual({ "zh-Hant": "香港", "zh-Hans": "香港", en: "Hong Kong" });
  });

  it("has provinces and cities with names in both scripts", () => {
    const gd = placeCountry("CN")!.regions.find((r) => r.names.en === "Guangdong")!;
    expect(gd.names).toMatchObject({ "zh-Hant": "廣東", "zh-Hans": "广东" });
    const gz = gd.cities.find((c) => c.names.en === "Guangzhou")!;
    expect(gz).toMatchObject({
      tz: "Asia/Shanghai",
      names: { "zh-Hant": "廣州市", "zh-Hans": "广州市" },
    });
    // Guangzhou is at 113.26°E, 23.13°N.
    expect(Math.abs(gz.lon - 113.26)).toBeLessThan(0.1);
    expect(Math.abs(gz.lat - 23.13)).toBeLessThan(0.1);
  });

  it("groups Taiwan by 直轄市 / 縣市, not the old four-way admin1", () => {
    const tw = placeCountry("TW")!.regions.map((r) => r.names["zh-Hant"]);
    expect(tw.length).toBeGreaterThanOrEqual(18);
    for (const n of ["台北市", "新北市", "高雄市", "臺中市", "花蓮縣"]) expect(tw).toContain(n);
  });

  it("every city has a timezone the engine accepts and a valid longitude", () => {
    const zones = new Set<string>();
    for (const { code } of placeIndex().countries) {
      for (const r of placeCountry(code)!.regions) {
        for (const c of r.cities) {
          zones.add(c.tz);
          expect(Math.abs(c.lon)).toBeLessThanOrEqual(180);
        }
      }
    }
    // Each distinct zone once (constructing a formatter per city is slow).
    for (const tz of zones) {
      expect(() => new Intl.DateTimeFormat("en", { timeZone: tz }), tz).not.toThrow();
    }
  });

  it("a picked city computes a chart (timezone + longitude flow into 真太陽時)", () => {
    const gz = placeCountry("CN")!
      .regions.flatMap((r) => r.cities)
      .find((c) => c.names.en === "Guangzhou")!;
    const chart = computeBazi(
      { local: "1990-03-15T14:30", timezone: gz.tz, longitude: gz.lon, gender: "male" },
      { digestPepper: PEPPER, now: FIXED_NOW },
    );
    // 113.25°E is 27 min behind the 120°E zone meridian; equation of time adds about −9 min.
    expect(
      (chart.facts as { time_basis: { pillar_clock: string } }).time_basis.pillar_clock,
    ).toMatch(/^1990-03-15T13:5\d/);
  });

  it("rejects unknown and malformed country codes", () => {
    expect(placeCountry("XX")).toBeUndefined();
    expect(placeCountry("../index")).toBeUndefined();
    expect(placeCountry("cn")).toBeUndefined(); // callers upper-case first
  });
});

describe("GET /v1/places", () => {
  const mock = new MockProvider();
  const api = createApiServer({
    secrets: { digestPepper: PEPPER, drawKey: DRAW_KEY },
    providers: { deepseek: mock, anthropic: mock },
    devMode: true,
    log: () => {},
  });
  let base = "";
  beforeAll(async () => {
    await new Promise<void>((r) => api.listen(0, "127.0.0.1", r));
    base = `http://127.0.0.1:${(api.address() as AddressInfo).port}`;
  });
  afterAll(() => new Promise<void>((r) => api.close(() => r())));

  it("lists countries and serves one country's regions, publicly and cacheably", async () => {
    const list = await fetch(base + "/v1/places");
    expect(list.status).toBe(200);
    expect(list.headers.get("cache-control")).toContain("max-age");
    expect((await list.json()).countries.length).toBeGreaterThan(200);

    const cn = await fetch(base + "/v1/places/cn");
    expect(cn.status).toBe(200);
    const body = await cn.json();
    expect(body.country).toBe("CN");
    expect(body.regions[0].cities[0]).toHaveProperty("tz");

    expect((await fetch(base + "/v1/places/XX")).status).toBe(404);
  });
});
