import type { AddressInfo } from "node:net";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import {
  generateLifeReport,
  generateRemedy,
  generateReport,
  LIFE_TOPICS,
  MockProvider,
  type NarrativeOutput,
} from "../src/ai/index.js";
import { createApiServer } from "../src/api/server.js";
import { computeBazi } from "../src/engines/bazi/index.js";
import { buildAuth } from "../src/service/runtime.js";
import { DRAW_KEY, FIXED_NOW, PEPPER } from "./helpers.js";

// Owner decision 2026-10-26: content review is paused until the legal & obligations work.
const chart = computeBazi(
  { local: "1990-03-15T14:30", timezone: "Asia/Hong_Kong", longitude: 114.17, gender: "male" },
  { digestPepper: PEPPER, now: FIXED_NOW },
);
const opts = { locale: "zh-Hant" as const, country: "HK" };
const paused = (mock: MockProvider) => ({
  providers: { deepseek: mock, anthropic: mock },
  now: FIXED_NOW,
  review: false,
});
const fatalist: NarrativeOutput = {
  sections: [
    {
      topic: "personality",
      paragraphs: [
        { text: "你注定會失去這段感情。", source_level: "derived", fact_refs: ["/day_master"] },
      ],
    },
  ],
};

describe("content review paused", () => {
  it("a report with a rule hit is released, the hit recorded, no rewrite and no guard call", async () => {
    const mock = new MockProvider({ narrative: [{ kind: "ok", data: fatalist }] });
    const r = await generateReport(chart, { ...opts, topics: ["personality"] }, paused(mock));
    expect(r.status).toBe("passed");
    expect(r.layers!.interpretation[0]!.paragraphs[0]!.text).toBe("你注定會失去這段感情。");
    expect(r.compliance.rule_violations.map((v) => v.rule_id)).toContain("G003"); // audit trail
    expect(mock.calls.filter((c) => c.agent === "narrative")).toHaveLength(1);
    expect(mock.calls.some((c) => c.agent === "guard")).toBe(false);
  });

  it("the same report is still held when review is on (the default)", async () => {
    const bad = { kind: "ok" as const, data: fatalist };
    const mock = new MockProvider({ narrative: [bad, bad] });
    const r = await generateReport(
      chart,
      { ...opts, topics: ["personality"] },
      { providers: { deepseek: mock, anthropic: mock }, now: FIXED_NOW },
    );
    expect(r.status).toBe("blocked");
  });

  it("破除运势 plans and life reports skip the guard too", async () => {
    const mock = new MockProvider();
    const report = await generateReport(chart, opts, paused(mock));
    const plan = await generateRemedy(chart, report, "health", { country: "HK" }, paused(mock));
    expect(plan.status).toBe("passed");
    expect(plan.agents.map((a) => a.agent)).toEqual(["remedy"]);
    const life = await generateLifeReport(
      chart,
      { locale: "zh-Hans", country: "HK" },
      paused(mock),
    );
    expect(life.status).toBe("passed");
    expect(life.agents.map((a) => a.agent).sort()).toEqual(["life_methods", "life_topics"]);
    expect(life.layers!.topics.map((t) => t.key)).toEqual([...LIFE_TOPICS]);
    expect(mock.calls.some((c) => c.agent === "guard")).toBe(false);
  });
});

describe("API with review paused", () => {
  const mock = new MockProvider();
  const secrets = { digestPepper: PEPPER, drawKey: DRAW_KEY };
  const auth = buildAuth({ ...secrets, ephemeral: true } as never, true);
  const api = createApiServer({
    secrets,
    providers: { deepseek: mock, anthropic: mock },
    auth,
    devMode: true,
    devHeaders: false,
    review: false,
    admins: ["boss"],
    log: () => {},
  });
  let base = "";
  let token = "";
  beforeAll(async () => {
    await auth.seedDevUser({ login: "boss", password: "boss", country: "HK", locale: "zh-Hans" });
    await new Promise<void>((r) => api.listen(0, "127.0.0.1", r));
    base = `http://127.0.0.1:${(api.address() as AddressInfo).port}`;
    token = (
      await (
        await fetch(base + "/v1/auth/login", {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify({ email: "boss", password: "boss" }),
        })
      ).json()
    ).access_token;
  });
  afterAll(() => new Promise<void>((r) => api.close(() => r())));

  it("health says so, nobody is a reviewer, and the console is closed", async () => {
    expect((await (await fetch(base + "/v1/health")).json()).content_review).toBe("paused");
    const H = { authorization: `Bearer ${token}` };
    expect((await (await fetch(base + "/v1/me", { headers: H })).json()).role).toBe("user");
    expect((await fetch(base + "/v1/admin/reviews", { headers: H })).status).toBe(404);
  });
});
