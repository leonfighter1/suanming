import type { AddressInfo } from "node:net";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { createDemoServer } from "../src/demo/server.js";

const server = createDemoServer();
let base = "";

beforeAll(async () => {
  await new Promise<void>((r) => server.listen(0, "127.0.0.1", r));
  base = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
});
afterAll(() => new Promise<void>((r) => server.close(() => r())));

const post = (path: string, body: unknown) =>
  fetch(base + path, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
  });

describe("demo server", () => {
  it("serves the UI page", async () => {
    const res = await fetch(base + "/");
    expect(res.status).toBe(200);
    expect(await res.text()).toContain("命理大師 · Phase 0 Demo");
  });

  it("bazi returns a schema-valid chart", async () => {
    const res = await post("/api/bazi", {
      local: "1990-03-15T14:30",
      timezone: "Asia/Hong_Kong",
      longitude: 114.17,
      gender: "male",
    });
    const data = await res.json();
    expect(res.status).toBe(200);
    expect(data.schema.ok).toBe(true);
    expect(data.fact.facts.pillars.year.gan + data.fact.facts.pillars.year.zhi).toBe("庚午");
  });

  it("bazi reports a DST gap as a 400 input error", async () => {
    const res = await post("/api/bazi", {
      local: "2021-03-14T02:30",
      timezone: "America/New_York",
      longitude: -74,
      gender: "male",
    });
    expect(res.status).toBe(400);
    expect((await res.json()).error).toMatch(/DST gap/);
  });

  it("tarot draws verify in audit replay", async () => {
    const data = await (await post("/api/tarot", { spread: "celtic_cross" })).json();
    expect(data.cards).toHaveLength(10);
    expect(data.audit_verified).toBe(true);
  });

  it("astro returns ten bodies", async () => {
    const data = await (
      await post("/api/astro", {
        local: "1990-03-15T14:30",
        timezone: "Asia/Hong_Kong",
        latitude: 22.32,
        longitude: 114.17,
      })
    ).json();
    expect(data.fact.facts.bodies).toHaveLength(10);
  });

  it("guard blocks, passes, and refuses by region", async () => {
    const blocked = await (
      await post("/api/guard", { country: "TW", text: "不轉運的話，下半年就會出事。" })
    ).json();
    expect(blocked.pass).toBe(false);
    const ok = await (
      await post("/api/guard", { country: "us", text: "No outcome is guaranteed." })
    ).json();
    expect(ok.pass).toBe(true);
    expect((await post("/api/guard", { country: "CN", text: "x" })).status).toBe(451);
  });
  it("ai-status reports the mock provider in tests", async () => {
    const s = await (await fetch(base + "/api/ai-status")).json();
    expect(s.provider).toBe("mock");
    expect(s.routes.narrative).toContain("deepseek-v4-pro");
  });

  it("report: passed bazi report with AI disclosure headers", async () => {
    const res = await post("/api/report", {
      system: "bazi",
      input: {
        local: "1990-03-15T14:30",
        timezone: "Asia/Hong_Kong",
        longitude: 114.17,
        gender: "female",
      },
      locale: "zh-Hant",
      country: "HK",
      topics: ["wuxing", "health"],
    });
    expect(res.status).toBe(200);
    expect(res.headers.get("x-ai-generated")).toBe("true");
    expect(res.headers.get("x-ai-model")).toMatch(/deepseek-v4-pro;prompt=narrative@3/);
    const data = await res.json();
    expect(data.report.status).toBe("passed");
    expect(data.report.layers.interpretation.map((s: { topic: string }) => s.topic)).toEqual([
      "wuxing",
      "health",
    ]);
  });

  it("report: 451 for unserved region, 400 for bad topic", async () => {
    const tarot = { system: "tarot", input: { spread: "single" }, locale: "en" };
    expect((await post("/api/report", { ...tarot, country: "CN" })).status).toBe(451);
    expect(
      (await post("/api/report", { ...tarot, country: "US", topics: ["wuxing"] })).status,
    ).toBe(400);
  });

  it("rejects bad JSON and unknown routes", async () => {
    const bad = await fetch(base + "/api/bazi", { method: "POST", body: "{" });
    expect(bad.status).toBe(400);
    expect((await fetch(base + "/../package.json")).status).toBe(404);
  });
});
