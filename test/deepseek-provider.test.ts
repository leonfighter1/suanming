import { describe, expect, it } from "vitest";
import { DeepSeekProvider, ProviderHttpError, type LLMJsonRequest } from "../src/ai/index.js";

const req: LLMJsonRequest = {
  agent: "narrative",
  model: "deepseek-v4-pro",
  effort: "medium",
  maxTokens: 32000,
  system: "SYS",
  user: "USER",
  schema: { type: "object", required: ["a"] },
  payload: {},
};

function fakeFetch(responses: (() => Response)[]) {
  const calls: { url: string; init: RequestInit }[] = [];
  const fn = (async (url: string, init: RequestInit) => {
    calls.push({ url, init });
    const next = responses.shift();
    if (!next) throw new Error("unexpected call");
    return next();
  }) as unknown as typeof fetch;
  return { fn, calls };
}

const completion =
  (content: string | null, finish = "stop") =>
  () =>
    new Response(
      JSON.stringify({
        model: "deepseek-v4-pro",
        choices: [{ finish_reason: finish, message: { content } }],
        usage: { prompt_tokens: 100, completion_tokens: 20, prompt_cache_hit_tokens: 64 },
      }),
      { status: 200 },
    );
const status = (code: number) => () => new Response("err", { status: code });

const provider = (f: typeof fetch) =>
  new DeepSeekProvider({ apiKey: "sk-test", fetch: f, maxRetries: 2 });

describe("DeepSeekProvider", () => {
  it("sends JSON mode, mapped effort, schema in the user turn and bearer auth", async () => {
    const { fn, calls } = fakeFetch([completion('{"a":1}')]);
    const r = await provider(fn).generateJson(req);
    expect(r).toEqual({
      kind: "ok",
      data: { a: 1 },
      model: "deepseek-v4-pro",
      usage: { input_tokens: 100, output_tokens: 20, cache_read_input_tokens: 64 },
    });
    expect(calls[0]!.url).toBe("https://api.deepseek.com/chat/completions");
    expect((calls[0]!.init.headers as Record<string, string>).authorization).toBe("Bearer sk-test");
    const body = JSON.parse(calls[0]!.init.body as string);
    expect(body).toMatchObject({
      model: "deepseek-v4-pro",
      max_tokens: 32000,
      reasoning_effort: "low", // medium → low (DeepSeek supports low | high | max)
      response_format: { type: "json_object" },
    });
    expect(body.messages[0]).toEqual({ role: "system", content: "SYS" });
    expect(body.messages[1].content).toMatch(/^USER\n\nReturn only one json object/);
    expect(body.messages[1].content).toContain('{"type":"object","required":["a"]}');
  });

  it("maps truncation, empty content, bad JSON and content filter", async () => {
    for (const [resp, expected] of [
      [completion('{"a"', "length"), { kind: "invalid", error: "output truncated at max_tokens" }],
      [completion(""), { kind: "invalid", error: "empty content" }],
      [completion("not json"), { kind: "invalid", error: "response was not valid JSON" }],
      [completion(null, "content_filter"), { kind: "refusal", category: "content_filter" }],
    ] as const) {
      const { fn } = fakeFetch([resp]);
      expect(await provider(fn).generateJson(req)).toMatchObject(expected);
    }
  });

  it("retries 429 and 5xx, then succeeds", async () => {
    const { fn, calls } = fakeFetch([status(429), status(503), completion('{"a":2}')]);
    const r = await provider(fn).generateJson(req);
    expect(r).toMatchObject({ kind: "ok", data: { a: 2 } });
    expect(calls).toHaveLength(3);
  }, 10_000);

  it("does not retry auth errors and raises ProviderHttpError", async () => {
    const { fn, calls } = fakeFetch([status(401)]);
    await expect(provider(fn).generateJson(req)).rejects.toMatchObject({
      constructor: ProviderHttpError,
      status: 401,
      provider: "deepseek",
    });
    expect(calls).toHaveLength(1);
  });

  it("requires a key", () => {
    const saved = process.env.DEEPSEEK_API_KEY;
    delete process.env.DEEPSEEK_API_KEY;
    try {
      expect(() => new DeepSeekProvider()).toThrow(/DEEPSEEK_API_KEY/);
    } finally {
      if (saved !== undefined) process.env.DEEPSEEK_API_KEY = saved;
    }
  });
});
