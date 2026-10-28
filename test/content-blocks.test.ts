// Indonesia's content blocks (tech plan WP8.1, the owner's Phase 3 §2.4: 印尼屏蔽前世/通灵/降头). The matrix
// names them; every model call in the region is told (review is paused, so a recorded hit would still reach
// the reader); the region's `id` rule group records them, and holds them when review is on. Indonesia ships
// unserved until the owner's sign-off, so the tests switch it on themselves (rule 42).
import { describe, expect, it } from "vitest";
import {
  GeoRefusedError,
  generateLifeReport,
  generateRemedy,
  generateReport,
  MockProvider,
  narrativeUser,
  tarotUser,
} from "../src/ai/index.js";
import {
  CONTENT_BLOCK_TEXT,
  contentBlockLine,
  loadGeoMatrix,
  resolveRegion,
} from "../src/compliance/geo.js";
import { computeBazi } from "../src/engines/bazi/index.js";
import { computeTarot } from "../src/engines/tarot/index.js";
import { DRAW_KEY, FIXED_NOW, PEPPER, withIndonesiaOn, withMatrix } from "./helpers.js";

const SHIPPED = loadGeoMatrix("compliance/geo_rule_matrix.json");
const LINE = contentBlockLine({ content_blocks: ["past_lives", "mediumship", "black_magic"] });
const deps = (mock: MockProvider, review = true) => ({
  providers: { deepseek: mock, anthropic: mock },
  now: FIXED_NOW,
  review,
});
const tarot = computeTarot(
  { spread: "three_card" },
  { drawKey: DRAW_KEY, digestPepper: PEPPER, now: FIXED_NOW, newDrawId: () => "draw-id" },
);
const bazi = computeBazi(
  { local: "1990-03-15T14:30", timezone: "Asia/Hong_Kong", longitude: 114.17, gender: "male" },
  { digestPepper: PEPPER, now: FIXED_NOW },
);
/** A three-card tarot narrative whose every paragraph says [text] (逐张解读: one paragraph per card). */
const saying = (text: string) => ({
  sections: ["tarot_cards", "tarot_synthesis", "tarot_advice"].map((topic) => ({
    topic,
    summary: "（示範）重點。",
    paragraphs: (topic === "tarot_cards" ? [0, 1, 2] : [0]).map((i) => ({
      text,
      source_level: "traditional_text",
      fact_refs: [`/cards/${i}`],
    })),
  })),
});

describe("the matrix", () => {
  it("blocks 前世, 通灵 and 降头 in Indonesia, with its own rule group, and no other region blocks anything", () => {
    const id = resolveRegion(SHIPPED, "ID")!;
    expect(id.name).toBe("Indonesia");
    expect(id.content_blocks).toEqual(["past_lives", "mediumship", "black_magic"]);
    expect(id.rule_groups).toEqual(["global", "en_common", "id"]);
    for (const block of id.content_blocks!) expect(LINE).toContain(CONTENT_BLOCK_TEXT[block]);
    for (const cc of Object.keys(SHIPPED.regions).filter((c) => c !== "ID")) {
      expect(contentBlockLine(resolveRegion(SHIPPED, cc)!), cc).toBe("");
    }
  });

  it("serves no region whose legal review is still pending (Indonesia waits for the owner's sign-off)", () => {
    for (const cc of Object.keys(SHIPPED.regions)) {
      const r = resolveRegion(SHIPPED, cc)!;
      if (r.legal_review === "pending") expect(r.service_available, cc).toBe(false);
    }
  });

  it("refuses a region that isn't served before any model call", async () => {
    const mock = new MockProvider();
    await expect(
      withMatrix(
        (m) => {
          m.regions.ID!.service_available = false;
        },
        () => generateReport(tarot, { locale: "en", country: "ID" }, deps(mock)),
      ),
    ).rejects.toThrow(GeoRefusedError);
    expect(mock.calls).toEqual([]);
  });
});

describe("an Indonesian reading", () => {
  it("tells the model in every call; Hong Kong's messages are unchanged", async () => {
    const mock = new MockProvider();
    const report = await withIndonesiaOn(() =>
      generateReport(tarot, { locale: "zh-Hant", country: "ID" }, deps(mock)),
    );
    expect(report.status).toBe("passed");
    const writers = mock.calls.filter((c) => c.agent === "narrative" || c.agent === "action");
    expect(writers.map((c) => c.agent)).toEqual(["narrative", "action"]);
    for (const c of writers) expect(c.user, c.agent).toContain(LINE);
    const guard = mock.calls.find((c) => c.agent === "guard")!;
    expect(guard.user).toContain('"content_blocks": [\n  "past_lives",');

    const hk = new MockProvider();
    await generateReport(tarot, { locale: "zh-Hant", country: "HK" }, deps(hk));
    for (const c of hk.calls) {
      expect(c.user, c.agent).not.toContain("rules out these topics");
      expect(c.user, c.agent).not.toContain("content_blocks");
    }
  });

  it("leaves a message byte for byte as before when the region has no blocks", () => {
    const args = {
      facts: { cards: [] },
      spread: { cards: [] },
      topics: ["tarot_cards"] as const,
      locale: "en" as const,
      glossary: {},
      today: "2026-10-25.",
    };
    expect(tarotUser({ ...args, regionLine: "" })).toBe(tarotUser(args));
    const reading = {
      system: "bazi" as const,
      facts: {},
      provenance: [],
      topics: ["wuxing"] as const,
      locale: "zh-Hans" as const,
      glossary: {},
    };
    expect(narrativeUser({ ...reading, regionLine: contentBlockLine({}) })).toBe(
      narrativeUser(reading),
    );
  });

  it("records 前世 that slips through, holds it while review is on, and only in Indonesia", async () => {
    const script = () => ({
      narrative: [
        { kind: "ok" as const, data: saying("這張牌說你們前世有緣。") },
        { kind: "ok" as const, data: saying("這張牌說你們前世有緣。") },
      ],
    });
    const held = await withIndonesiaOn(() =>
      generateReport(tarot, { locale: "zh-Hant", country: "ID" }, deps(new MockProvider(script()))),
    );
    expect(held.status).toBe("blocked");
    expect(held.compliance.rule_violations.map((v) => v.rule_id)).toContain("I001");

    // Review paused (the owner's decision, 2026-10-26): recorded, not held.
    const paused = await withIndonesiaOn(() =>
      generateReport(
        tarot,
        { locale: "zh-Hant", country: "ID" },
        deps(new MockProvider(script()), false),
      ),
    );
    expect(paused.status).toBe("passed");
    expect(paused.compliance.rule_violations.map((v) => v.rule_id)).toContain("I001");

    const hk = await generateReport(
      tarot,
      { locale: "zh-Hant", country: "HK" },
      deps(new MockProvider(script())),
    );
    expect(hk.compliance.rule_violations.map((v) => v.rule_id)).not.toContain("I001");
  });

  it("tells the model in a 破除運勢 plan and in the 一生运势 report too", async () => {
    const mock = new MockProvider();
    await withIndonesiaOn(async () => {
      const report = await generateReport(bazi, { locale: "en", country: "ID" }, deps(mock));
      await generateRemedy(bazi, report, "health", { country: "ID" }, deps(mock));
      await generateLifeReport(bazi, { locale: "en", country: "ID" }, deps(mock));
    });
    for (const agent of ["narrative", "action", "remedy", "life_methods", "life_topics"]) {
      const calls = mock.calls.filter((c) => c.agent === agent);
      expect(calls.length, agent).toBeGreaterThan(0);
      for (const c of calls) expect(c.user, agent).toContain(LINE);
    }
  });
});
