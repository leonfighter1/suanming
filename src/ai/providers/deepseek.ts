/**
 * DeepSeek via its OpenAI-compatible Chat Completions API (https://api.deepseek.com).
 * Verified 2026-10-26 against GET /models: deepseek-flash (V4.1-Flash) and
 * deepseek-v4-pro, effort levels low | high | max, thinking on by default.
 *
 * DeepSeek's JSON mode (response_format json_object) guarantees valid JSON but not
 * a schema, so the schema is appended to the user message and the pipeline
 * validates the result (and retries) as for any provider. Appending at the end
 * keeps the system prompt as a stable prefix for DeepSeek's automatic context cache.
 */
import type { LLMJsonRequest, LLMJsonResult, LLMProvider, Usage } from "../types.js";

export class ProviderHttpError extends Error {
  constructor(
    readonly provider: string,
    readonly status: number,
    message: string,
  ) {
    super(message);
  }
}

const EFFORT: Record<LLMJsonRequest["effort"], "low" | "high" | "max"> = {
  low: "low",
  medium: "low",
  high: "high",
  xhigh: "max",
  max: "max",
};

interface ChatCompletion {
  model: string;
  choices: { finish_reason: string; message: { content: string | null } }[];
  usage?: { prompt_tokens: number; completion_tokens: number; prompt_cache_hit_tokens?: number };
}

export interface DeepSeekOptions {
  apiKey?: string;
  baseUrl?: string;
  timeoutMs?: number;
  maxRetries?: number;
  fetch?: typeof fetch;
}

export class DeepSeekProvider implements LLMProvider {
  readonly name = "deepseek";
  private readonly apiKey: string;
  private readonly baseUrl: string;
  private readonly timeoutMs: number;
  private readonly maxRetries: number;
  private readonly fetchFn: typeof fetch;

  constructor(opts: DeepSeekOptions = {}) {
    const key = opts.apiKey ?? process.env.DEEPSEEK_API_KEY;
    if (!key) throw new Error("DEEPSEEK_API_KEY is not set");
    this.apiKey = key;
    this.baseUrl = opts.baseUrl ?? process.env.DEEPSEEK_BASE_URL ?? "https://api.deepseek.com";
    this.timeoutMs = opts.timeoutMs ?? 300_000; // thinking turns can take minutes
    this.maxRetries = opts.maxRetries ?? 2;
    this.fetchFn = opts.fetch ?? fetch;
  }

  async generateJson(req: LLMJsonRequest): Promise<LLMJsonResult> {
    const body = {
      model: req.model,
      max_tokens: req.maxTokens,
      reasoning_effort: EFFORT[req.effort],
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: req.system },
        {
          role: "user",
          content: `${req.user}\n\nReturn only one json object that conforms to this JSON Schema:\n${JSON.stringify(req.schema)}`,
        },
      ],
    };
    const res = await this.post(body);
    const usage: Usage = {
      input_tokens: res.usage?.prompt_tokens ?? 0,
      output_tokens: res.usage?.completion_tokens ?? 0,
      cache_read_input_tokens: res.usage?.prompt_cache_hit_tokens ?? 0,
    };
    const choice = res.choices[0];
    if (!choice) return { kind: "invalid", model: res.model, error: "no choices returned", usage };
    if (choice.finish_reason === "content_filter") {
      return { kind: "refusal", model: res.model, category: "content_filter", usage };
    }
    if (choice.finish_reason === "length") {
      return { kind: "invalid", model: res.model, error: "output truncated at max_tokens", usage };
    }
    const text = choice.message.content?.trim() ?? "";
    // Known DeepSeek issue: JSON mode occasionally returns empty content.
    if (!text) return { kind: "invalid", model: res.model, error: "empty content", usage };
    try {
      return { kind: "ok", data: JSON.parse(text), model: res.model, usage };
    } catch {
      return { kind: "invalid", model: res.model, error: "response was not valid JSON", usage };
    }
  }

  private async post(body: unknown): Promise<ChatCompletion> {
    let lastError: ProviderHttpError | undefined;
    for (let attempt = 0; attempt <= this.maxRetries; attempt++) {
      if (attempt > 0) await new Promise((r) => setTimeout(r, 1000 * 2 ** (attempt - 1)));
      let res: Response;
      try {
        res = await this.fetchFn(`${this.baseUrl}/chat/completions`, {
          method: "POST",
          headers: { authorization: `Bearer ${this.apiKey}`, "content-type": "application/json" },
          body: JSON.stringify(body),
          signal: AbortSignal.timeout(this.timeoutMs),
        });
      } catch (e) {
        lastError = new ProviderHttpError(this.name, 0, `network error: ${(e as Error).message}`);
        continue;
      }
      if (res.ok) return (await res.json()) as ChatCompletion;
      const detail = await res.text().catch(() => "");
      lastError = new ProviderHttpError(
        this.name,
        res.status,
        `HTTP ${res.status}: ${detail.slice(0, 300)}`,
      );
      // Retry only what can succeed later: rate limits and server errors.
      if (res.status !== 429 && res.status < 500) break;
    }
    throw lastError!;
  }
}
