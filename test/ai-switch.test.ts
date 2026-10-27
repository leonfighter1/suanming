import { mkdtempSync, rmSync, utimesSync, writeFileSync } from "node:fs";
import type { AddressInfo } from "node:net";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import {
  MockProvider,
  type LLMJsonRequest,
  type LLMJsonResult,
  type LLMProvider,
} from "../src/ai/index.js";
import { createApiServer } from "../src/api/server.js";
import {
  aiMode,
  buildProviders,
  describeAi,
  envFlag,
  SwitchedProvider,
  watchAiMode,
  type AiMode,
} from "../src/service/runtime.js";
import { DRAW_KEY, PEPPER } from "./helpers.js";

/** Runs fn with these environment variables (undefined = unset), then restores them. */
function withEnv(vars: Record<string, string | undefined>, fn: () => void) {
  const saved = Object.fromEntries(Object.keys(vars).map((k) => [k, process.env[k]]));
  const apply = (v: Record<string, string | undefined>) => {
    for (const [k, x] of Object.entries(v)) {
      if (x === undefined) delete process.env[k];
      else process.env[k] = x;
    }
  };
  apply(vars);
  try {
    fn();
  } finally {
    apply(saved);
  }
}

/** A provider that only records that it was asked. */
const fake = (name: string, log: string[]): LLMProvider => ({
  name,
  generateJson: async () => {
    log.push(name);
    return { kind: "ok", data: {}, model: name } as unknown as LLMJsonResult;
  },
});

describe("the owner's AI switch (IS_AI_MOCK / IS_AI_MODEL in .env)", () => {
  it("reads TRUE/FALSE loosely and ignores anything unclear", () => {
    for (const v of ["TRUE", "true", " True ", "1", "yes", "ON"]) expect(envFlag(v)).toBe(true);
    for (const v of ["FALSE", "false", "0", "no", "off"]) expect(envFlag(v)).toBe(false);
    for (const v of [undefined, "", "maybe"]) expect(envFlag(v)).toBeUndefined();
  });

  it("the real model runs only when nothing asks for the mock", () => {
    // The owner's .env today (both TRUE): the mock, to save tokens.
    expect(aiMode({ IS_AI_MODEL: "TRUE", IS_AI_MOCK: "TRUE" })).toEqual({
      mock: true,
      reason: "IS_AI_MOCK=TRUE",
    });
    // ...until IS_AI_MOCK is flipped.
    expect(aiMode({ IS_AI_MODEL: "TRUE", IS_AI_MOCK: "FALSE" })).toEqual({ mock: false });
    expect(aiMode({ IS_AI_MODEL: "FALSE", IS_AI_MOCK: "FALSE" })).toEqual({
      mock: true,
      reason: "IS_AI_MODEL=FALSE",
    });
    // No switches: as before (the real model when its key is set).
    expect(aiMode({})).toEqual({ mock: false });
    // The test suite's own switch beats .env.
    expect(aiMode({ MINGLI_AI_PROVIDER: "mock", IS_AI_MOCK: "FALSE" }).mock).toBe(true);
  });

  it("follows .env as it is edited, with no restart; the shell wins over the file", () => {
    const dir = mkdtempSync(join(tmpdir(), "mingli-env-"));
    const file = join(dir, ".env");
    // Explicit, distinct mtimes (seconds), whatever the filesystem's resolution.
    const write = (text: string, at: number) => {
      writeFileSync(file, text);
      utimesSync(file, at, at);
    };
    const flips: boolean[] = [];
    write("DEEPSEEK_API_KEY=sk-x\nIS_AI_MODEL=TRUE\nIS_AI_MOCK=TRUE\n", 1_000_000);
    // The listener reads the switch back, as the console line does: it must see the new mode.
    const mode: () => AiMode = watchAiMode(file, {}, () => flips.push(mode().mock));
    expect(mode().mock).toBe(true);

    write("DEEPSEEK_API_KEY=sk-x\nIS_AI_MODEL=TRUE\nIS_AI_MOCK=FALSE\n", 1_000_100);
    expect(mode()).toEqual({ mock: false });
    write("IS_AI_MOCK=TRUE\n", 1_000_200);
    expect(mode().reason).toBe("IS_AI_MOCK=TRUE");
    expect(mode().reason).toBe("IS_AI_MOCK=TRUE"); // unchanged file: no new flip
    expect(flips).toEqual([false, true]);

    // A variable set in the shell beats the file, as process.loadEnvFile does.
    expect(watchAiMode(file, { IS_AI_MOCK: "FALSE" })().mock).toBe(false);
    // No .env at all: the shell alone.
    rmSync(dir, { recursive: true });
    expect(mode()).toEqual({ mock: false });
    expect(flips).toEqual([false, true, false]);
  });

  it("a real provider hands each call to the mock while the switch says so", async () => {
    const log: string[] = [];
    let useMock = true;
    const p = new SwitchedProvider(fake("deepseek", log), fake("mock", log), () => useMock);
    await p.generateJson({} as LLMJsonRequest);
    expect(p.name).toBe("mock");
    useMock = false;
    await p.generateJson({} as LLMJsonRequest);
    expect(p.name).toBe("deepseek");
    expect(log).toEqual(["mock", "deepseek"]);
  });

  it("under the test suite no real provider is built, whatever the switch or keys say", () => {
    withEnv({ DEEPSEEK_API_KEY: "sk-never-used" }, () => {
      const p = buildProviders(() => ({ mock: false }));
      expect(p.live).toEqual([]);
      expect(p.map.deepseek).toBeInstanceOf(MockProvider);
      expect(p.serving()).toBe("mock");
    });
  });

  it("with a key, the switch picks mock or real per call (built here, never called)", () => {
    const env = {
      MINGLI_AI_PROVIDER: undefined,
      DEEPSEEK_API_KEY: "sk-never-used",
      ANTHROPIC_API_KEY: undefined,
      ANTHROPIC_AUTH_TOKEN: undefined,
    };
    withEnv(env, () => {
      let mode: AiMode = { mock: true, reason: "IS_AI_MOCK=TRUE" };
      const p = buildProviders(() => mode);
      expect(p.live).toEqual(["deepseek"]);
      expect(p.map.deepseek).toBeInstanceOf(SwitchedProvider);
      expect(p.map.deepseek!.name).toBe("mock");
      expect(p.serving()).toBe("mock");
      expect(describeAi(p)).toContain(
        "no tokens spent; IS_AI_MOCK=FALSE in .env for the real model",
      );

      mode = { mock: false }; // the owner flips IS_AI_MOCK=FALSE
      expect(p.map.deepseek!.name).toBe("deepseek");
      expect(p.serving()).toBe("deepseek");
      expect(describeAi(p)).toMatch(/^deepseek \(real model/);
    });
  });

  it("while the mock answers, /v1/health says so and the daily AI caps don't count", async () => {
    let serving = "mock";
    const mock = new MockProvider();
    const api = createApiServer({
      secrets: { digestPepper: PEPPER, drawKey: DRAW_KEY },
      providers: { deepseek: mock, anthropic: mock },
      devMode: true,
      aiQuota: { perUserPerDay: 1, totalPerDay: 1 },
      aiServing: () => serving,
      preloadRemedies: false,
      log: () => {},
    });
    await new Promise<void>((r) => api.listen(0, "127.0.0.1", r));
    const base = `http://127.0.0.1:${(api.address() as AddressInfo).port}`;
    const h = { "content-type": "application/json", "x-dev-user": "u1", "x-dev-country": "HK" };
    const health = async () => (await (await fetch(base + "/v1/health")).json()).ai;
    const report = async () => {
      const c = await (
        await fetch(base + "/v1/charts", {
          method: "POST",
          headers: h,
          body: JSON.stringify({ system: "tarot", spread: "three_card" }),
        })
      ).json();
      const r = await fetch(base + "/v1/reports", {
        method: "POST",
        headers: h,
        body: JSON.stringify({ chart_id: c.chart_id, locale: "zh-Hans" }),
      });
      return r.status;
    };
    try {
      expect(await health()).toBe("mock");
      expect([await report(), await report(), await report()]).toEqual([202, 202, 202]);

      serving = "deepseek"; // the owner flips IS_AI_MOCK=FALSE: real calls count again
      expect(await health()).toBe("deepseek");
      expect([await report(), await report()]).toEqual([202, 429]);
      await api.drain();
    } finally {
      await new Promise<void>((r) => api.close(() => r()));
    }
  });
});
