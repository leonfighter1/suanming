// The Phase 3 gate 「Geo-Rule 五地区规则路由测试通过」 (tech plan WP8.2, the owner's Phase 3 §2.4): Indonesia,
// Malaysia, Singapore, Taiwan and Hong Kong each get their rules, content blocks, entry order and languages.
// Indonesia is checked switched on (it ships unserved until the owner's sign-off), and 起名 is left out of
// the orders (it ships off until its review): neither shipped switch is pinned here (rule 42).
import type { AddressInfo } from "node:net";
import { describe, expect, it } from "vitest";
import { generateReport, MockProvider } from "../src/ai/index.js";
import { createApiServer } from "../src/api/server.js";
import { AuthService } from "../src/auth/service.js";
import { TokenService } from "../src/auth/tokens.js";
import { loadGeoMatrix, resolveRegion } from "../src/compliance/geo.js";
import { computeTarot } from "../src/engines/tarot/index.js";
import { DRAW_KEY, FIXED_NOW, PEPPER, withIndonesiaOn, withMatrix } from "./helpers.js";

const FIVE = ["ID", "MY", "SG", "TW", "HK"] as const;
const shipped = () => loadGeoMatrix("compliance/geo_rule_matrix.json");
const tarot = computeTarot(
  { spread: "three_card" },
  { drawKey: DRAW_KEY, digestPepper: PEPPER, now: FIXED_NOW, newDrawId: () => "draw-id" },
);

describe("the five regions of Phase 3 §2.4", () => {
  it("each has its rule groups, content blocks and languages", () => {
    const m = shipped();
    const r = (cc: string) => resolveRegion(m, cc)!;
    expect(Object.fromEntries(FIVE.map((cc) => [cc, r(cc).rule_groups]))).toEqual({
      ID: ["global", "en_common", "id"],
      MY: ["global", "en_common"],
      SG: ["global", "en_common"],
      TW: ["global"],
      HK: ["global"],
    });
    expect(Object.fromEntries(FIVE.map((cc) => [cc, r(cc).content_blocks ?? []]))).toEqual({
      ID: ["past_lives", "mediumship", "black_magic"],
      MY: [],
      SG: [],
      TW: [],
      HK: [],
    });
    // Singapore: English and 简体 both (英语 / 中文双语权重); Indonesia: English and Chinese.
    expect(r("SG").locales).toEqual(expect.arrayContaining(["en", "zh-Hans"]));
    expect(r("ID").locales).toEqual(expect.arrayContaining(["en", "zh-Hans"]));
    expect(r("TW").locales).toEqual(["zh-Hant"]);
    expect(r("HK").locales).toEqual(expect.arrayContaining(["zh-Hant", "zh-Hans"]));
    expect(r("MY").locales).toEqual(expect.arrayContaining(["zh-Hans", "zh-Hant"]));
  });

  it("routes a reading's text through each region's own rules", async () => {
    // One sentence for each region-specific group: `id` (past life) and `en_common` (guaranteed).
    const text = "This card hints at a past life. Success is guaranteed.";
    // 逐张解读 needs one paragraph per card: three for a three-card spread.
    const narrative = {
      sections: ["tarot_cards", "tarot_synthesis", "tarot_advice"].map((topic) => ({
        topic,
        summary: "The point.",
        paragraphs: (topic === "tarot_cards" ? [0, 1, 2] : [0]).map((i) => ({
          text,
          source_level: "traditional_text",
          fact_refs: [`/cards/${i}`],
        })),
      })),
    };
    const hits = async (cc: string) => {
      // Review paused, as the dev server runs: every hit is recorded and nothing is held.
      const report = await generateReport(
        tarot,
        { locale: "en", country: cc },
        {
          providers: {
            deepseek: new MockProvider({ narrative: [{ kind: "ok", data: narrative }] }),
            anthropic: new MockProvider(),
          },
          now: FIXED_NOW,
          review: false,
        },
      );
      return [...new Set(report.compliance.rule_violations.map((v) => v.rule_id))].sort();
    };
    const found = await withIndonesiaOn(async () => {
      const out: Record<string, string[]> = {};
      for (const cc of FIVE) out[cc] = await hits(cc);
      return out;
    });
    expect(found).toEqual({ ID: ["E001", "I001"], MY: ["E001"], SG: ["E001"], TW: [], HK: [] });
  });

  it("orders each region's methods for the home page", async () => {
    const api = createApiServer({
      secrets: { digestPepper: PEPPER, drawKey: DRAW_KEY },
      providers: { deepseek: new MockProvider(), anthropic: new MockProvider() },
      devMode: true,
      log: () => {},
    });
    await new Promise<void>((r) => api.listen(0, "127.0.0.1", r));
    const base = `http://127.0.0.1:${(api.address() as AddressInfo).port}`;
    try {
      const order = async (cc: string) => {
        const res = await fetch(`${base}/v1/methods`, {
          headers: { "x-dev-country": cc, "x-dev-user": "geo" },
        });
        expect(res.status, cc).toBe(200);
        const body = (await res.json()) as { methods: { system: string }[] };
        return body.methods.map((x) => x.system).filter((s) => s !== "naming");
      };
      const orders = await withIndonesiaOn(async () => {
        const out: Record<string, string[]> = {};
        for (const cc of FIVE) out[cc] = await order(cc);
        return out;
      });
      expect(orders).toEqual({
        ID: ["bazi", "tarot", "qiuqian", "fengshui", "astrology"],
        MY: ["fengshui", "bazi", "tarot", "qiuqian", "astrology"],
        SG: ["bazi", "tarot", "qiuqian", "fengshui", "astrology"],
        TW: ["qiuqian", "bazi", "tarot", "fengshui", "astrology"],
        HK: ["qiuqian", "bazi", "tarot", "fengshui", "astrology"],
      });
    } finally {
      await new Promise<void>((r) => api.close(() => r()));
    }
  });

  it("a running server follows a matrix change, with no restart (矩阵支持热更新)", async () => {
    // Started before the change, as the owner's server would be when a region is signed off.
    const api = createApiServer({
      secrets: { digestPepper: PEPPER, drawKey: DRAW_KEY },
      providers: { deepseek: new MockProvider(), anthropic: new MockProvider() },
      auth: new AuthService({ pepper: PEPPER, tokens: new TokenService(PEPPER) }),
      log: () => {},
    });
    await new Promise<void>((r) => api.listen(0, "127.0.0.1", r));
    const base = `http://127.0.0.1:${(api.address() as AddressInfo).port}`;
    const register = (email: string) =>
      fetch(`${base}/v1/auth/register`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          email,
          password: "long enough pw",
          country: "ID",
          locale: "en",
          age_confirmed: true,
        }),
      });
    try {
      const off = await withMatrix(
        (m) => {
          m.regions.ID!.service_available = false;
        },
        () => register("before@example.com"),
      );
      expect(off.status).toBe(451);
      const on = await withIndonesiaOn(() => register("after@example.com"));
      expect(on.status).toBe(201);
    } finally {
      await new Promise<void>((r) => api.close(() => r()));
    }
  });
});
