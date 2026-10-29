import { mkdtempSync, rmSync, utimesSync, writeFileSync } from "node:fs";
import type { AddressInfo } from "node:net";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, it, vi } from "vitest";
import {
  loadRouting,
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
  modelChoice,
  SwitchedProvider,
  watchAi,
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
    const ai = watchAi(file, {}, () => flips.push(ai.mode().mock));
    const mode: () => AiMode = ai.mode;
    expect(mode().mock).toBe(true);

    write("DEEPSEEK_API_KEY=sk-x\nIS_AI_MODEL=TRUE\nIS_AI_MOCK=FALSE\n", 1_000_100);
    expect(mode()).toEqual({ mock: false });
    write("IS_AI_MOCK=TRUE\n", 1_000_200);
    expect(mode().reason).toBe("IS_AI_MOCK=TRUE");
    expect(mode().reason).toBe("IS_AI_MOCK=TRUE"); // unchanged file: no new flip
    expect(flips).toEqual([false, true]);

    // A variable set in the shell beats the file, as process.loadEnvFile does.
    expect(watchAi(file, { IS_AI_MOCK: "FALSE" }).mode().mock).toBe(false);
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
      CLAUDE_API_KEY: undefined,
      ANTHROPIC_API_KEY: undefined,
      ANTHROPIC_AUTH_TOKEN: undefined,
    };
    withEnv(env, () => {
      let mode: AiMode = { mock: true, reason: "IS_AI_MOCK=TRUE" };
      // The model is named here, not taken from the shipped table (rule 42).
      const p = buildProviders(
        () => mode,
        () => modelChoice({ ACTIVE_AI_MODEL: "deepseek-v4-pro" }),
      );
      expect(p.live).toEqual(["deepseek"]);
      expect(p.map.deepseek).toBeInstanceOf(SwitchedProvider);
      expect(p.map.deepseek!.name).toBe("mock");
      expect(p.serving()).toBe("mock");
      expect(describeAi(p)).toContain(
        "no tokens spent; IS_AI_MOCK=FALSE in .env for the real model (deepseek-v4-pro)",
      );

      mode = { mock: false }; // the owner flips IS_AI_MOCK=FALSE
      expect(p.map.deepseek!.name).toBe("deepseek");
      expect(p.serving()).toBe("deepseek");
      expect(describeAi(p)).toMatch(/^deepseek deepseek-v4-pro \(real model/);
    });
  });

  it("a model whose provider has no key leaves the mock answering, and the console names the key", () => {
    const keys = (deepseek?: string, claude?: string, anthropic?: string) => ({
      MINGLI_AI_PROVIDER: undefined,
      DEEPSEEK_API_KEY: deepseek,
      CLAUDE_API_KEY: claude,
      ANTHROPIC_API_KEY: anthropic,
      ANTHROPIC_AUTH_TOKEN: undefined,
    });
    const sonnet = () => modelChoice({ ACTIVE_AI_MODEL: "claude-sonnet-5-5" });
    withEnv(keys("sk-never-used"), () => {
      const p = buildProviders(() => ({ mock: false }), sonnet);
      expect(p.map.anthropic).toBeInstanceOf(MockProvider);
      expect(p.serving()).toBe("mock");
      expect(describeAi(p)).toBe("mock (no CLAUDE_API_KEY in .env for claude-sonnet-5-5)");
      // With the switch on as well, flipping it alone is not enough: the line says both.
      const switched = buildProviders(() => ({ mock: true, reason: "IS_AI_MOCK=TRUE" }), sonnet);
      expect(describeAi(switched)).toBe(
        "mock (IS_AI_MOCK=TRUE): demo answers marked （示范）, no tokens spent; " +
          "for the real model (claude-sonnet-5-5): IS_AI_MOCK=FALSE and CLAUDE_API_KEY in .env",
      );
    });
    // The owner's name for the key, and the SDK's own: either turns Claude on.
    for (const env of [
      keys(undefined, "sk-ant-never-used"),
      keys(undefined, undefined, "sk-ant-x"),
    ]) {
      withEnv(env, () => {
        const p = buildProviders(() => ({ mock: false }), sonnet);
        expect(p.live).toEqual(["anthropic"]);
        expect(p.map.anthropic).toBeInstanceOf(SwitchedProvider);
        expect(p.serving()).toBe("anthropic");
        expect(p.models()).toBe("claude-sonnet-5-5");
        expect(describeAi(p)).toMatch(/^anthropic claude-sonnet-5-5 \(real model/);
      });
    }
  });

  it("Claude gets the owner's CLAUDE_API_KEY, whatever else the shell has (network stubbed)", async () => {
    const sent: Headers[] = [];
    const sse = [
      {
        type: "message_start",
        message: {
          id: "msg_1",
          type: "message",
          role: "assistant",
          model: "claude-opus-5-5",
          content: [],
          stop_reason: null,
          stop_sequence: null,
          usage: { input_tokens: 1, output_tokens: 1 },
        },
      },
      { type: "content_block_start", index: 0, content_block: { type: "text", text: "" } },
      { type: "content_block_delta", index: 0, delta: { type: "text_delta", text: "{}" } },
      { type: "content_block_stop", index: 0 },
      {
        type: "message_delta",
        delta: { stop_reason: "end_turn", stop_sequence: null },
        usage: { output_tokens: 2 },
      },
      { type: "message_stop" },
    ]
      .map((e) => `event: ${e.type}\ndata: ${JSON.stringify(e)}\n\n`)
      .join("");
    // The SDK takes fetch when its client is made: stub it first.
    vi.stubGlobal("fetch", async (_url: unknown, init?: RequestInit) => {
      sent.push(new Headers(init?.headers));
      return new Response(sse, { status: 200, headers: { "content-type": "text/event-stream" } });
    });
    try {
      let p: ReturnType<typeof buildProviders> | undefined;
      const env = {
        MINGLI_AI_PROVIDER: undefined,
        DEEPSEEK_API_KEY: undefined,
        CLAUDE_API_KEY: "sk-ant-owner",
        ANTHROPIC_API_KEY: "sk-ant-someone-else",
        ANTHROPIC_AUTH_TOKEN: "token-someone-else",
      };
      withEnv(env, () => {
        p = buildProviders(
          () => ({ mock: false }),
          () => modelChoice({ ACTIVE_AI_MODEL: "claude-opus-5-5" }),
        );
      });
      const r = await p!.map.anthropic!.generateJson({
        agent: "narrative",
        model: "claude-opus-5-5",
        effort: "medium",
        maxTokens: 64_000,
        system: "SYS",
        user: "USER",
        schema: { type: "object" },
        payload: {},
      });
      expect(r).toMatchObject({ kind: "ok", data: {}, model: "claude-opus-5-5" });
      expect(sent).toHaveLength(1);
      expect(sent[0]!.get("x-api-key")).toBe("sk-ant-owner");
      expect(sent[0]!.get("authorization")).toBeNull();
    } finally {
      vi.unstubAllGlobals();
    }
  });

  it("ACTIVE_AI_MODEL is followed like the switch: every route on that model, a typo said and ignored", () => {
    const dir = mkdtempSync(join(tmpdir(), "mingli-env-"));
    const file = join(dir, ".env");
    const write = (text: string, at: number) => {
      writeFileSync(file, text);
      utimesSync(file, at, at);
    };
    const notices: string[] = [];
    write("IS_AI_MOCK=TRUE\n", 1_000_000);
    const ai = watchAi(file, {}, () => notices.push(describeAi(p)));
    const p = buildProviders(ai.mode, ai.choice);
    const table = loadRouting();
    const narrative = () => p.routing().routes.narrative.default;
    try {
      expect(narrative()).toEqual(table.routes.narrative.default); // unset: the table as it is

      // One save with the flip and a model: one notice, and the next job sees both.
      write("IS_AI_MOCK=FALSE\nACTIVE_AI_MODEL=deepseek-v4-pro\n", 1_000_100);
      expect(narrative()).toEqual({
        provider: "deepseek",
        model: "deepseek-v4-pro",
        effort: "high",
        max_tokens: Math.min(table.routes.narrative.default.max_tokens, 32_000),
      });
      expect(ai.mode()).toEqual({ mock: false });
      expect(notices).toHaveLength(1);
      // Every agent, each within DeepSeek's 32,000, whatever the table asks.
      for (const r of Object.values(p.routing().routes)) {
        expect(r.default.model).toBe("deepseek-v4-pro");
        expect(r.default.max_tokens).toBeLessThanOrEqual(32_000);
      }

      write("IS_AI_MOCK=FALSE\nACTIVE_AI_MODEL=claude-opus-55\n", 1_000_200);
      expect(narrative()).toEqual(table.routes.narrative.default); // a typo: the table answers
      expect(notices).toHaveLength(2);
      expect(notices[1]).toContain(
        "ACTIVE_AI_MODEL=claude-opus-55 is not a usable model, so config/model_routing.json answers",
      );
      expect(narrative()).toEqual(table.routes.narrative.default);
      expect(notices).toHaveLength(2); // unchanged file: no new notice
    } finally {
      rmSync(dir, { recursive: true });
    }
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
      aiModel: () => "claude-opus-5-5",
      preloadRemedies: false,
      log: () => {},
    });
    await new Promise<void>((r) => api.listen(0, "127.0.0.1", r));
    const base = `http://127.0.0.1:${(api.address() as AddressInfo).port}`;
    const h = { "content-type": "application/json", "x-dev-user": "u1", "x-dev-country": "HK" };
    const status = async () => (await fetch(base + "/v1/health")).json();
    const health = async () => (await status()).ai;
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
      // The model's name only while it answers (v9.2.0): the mock's answers are no model's.
      expect(await status()).not.toHaveProperty("ai_model");
      expect([await report(), await report(), await report()]).toEqual([202, 202, 202]);

      serving = "anthropic"; // the owner flips IS_AI_MOCK=FALSE: real calls count again
      expect(await health()).toBe("anthropic");
      expect((await status()).ai_model).toBe("claude-opus-5-5");
      expect([await report(), await report()]).toEqual([202, 429]);
      await api.drain();
    } finally {
      await new Promise<void>((r) => api.close(() => r()));
    }
  });
});
