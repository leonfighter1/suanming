import Anthropic from "@anthropic-ai/sdk";
import type { LLMJsonRequest, LLMJsonResult, LLMProvider, Usage } from "../types.js";

/** The slice of the SDK client this provider uses, so tests can inject a fake. */
export type AnthropicLike = { beta: { messages: Pick<Anthropic["beta"]["messages"], "create"> } };

/**
 * Claude via the official SDK.
 * - Structured outputs: output_config.format = json_schema (no prefill; removed on current models).
 * - Server-side refusal fallback: fallbacks "default" (beta server-side-fallback-2026-07-01).
 * - System prompt is static per prompt version and marked cacheable.
 * Credentials: the zero-arg client resolves ANTHROPIC_API_KEY, ANTHROPIC_AUTH_TOKEN
 * or an `ant auth login` profile.
 */
export class AnthropicProvider implements LLMProvider {
  readonly name = "anthropic";
  constructor(private readonly client: AnthropicLike = new Anthropic()) {}

  async generateJson(req: LLMJsonRequest): Promise<LLMJsonResult> {
    const res = await this.client.beta.messages.create({
      model: req.model,
      max_tokens: req.maxTokens,
      betas: ["server-side-fallback-2026-07-01"],
      fallbacks: "default",
      system: [{ type: "text", text: req.system, cache_control: { type: "ephemeral" } }],
      messages: [{ role: "user", content: req.user }],
      output_config: { effort: req.effort, format: { type: "json_schema", schema: req.schema } },
    });

    const usage: Usage = {
      input_tokens: res.usage.input_tokens,
      output_tokens: res.usage.output_tokens,
      cache_read_input_tokens: res.usage.cache_read_input_tokens ?? 0,
    };
    // Check stop_reason before reading content.
    if (res.stop_reason === "refusal") {
      return {
        kind: "refusal",
        model: res.model,
        category: res.stop_details?.category ?? null,
        usage,
      };
    }
    if (res.stop_reason === "max_tokens") {
      return { kind: "invalid", model: res.model, error: "output truncated at max_tokens", usage };
    }
    const text = res.content
      .filter((b): b is Anthropic.Beta.BetaTextBlock => b.type === "text")
      .map((b) => b.text)
      .join("");
    try {
      return { kind: "ok", data: JSON.parse(text), model: res.model, usage };
    } catch {
      return { kind: "invalid", model: res.model, error: "response was not valid JSON", usage };
    }
  }
}
