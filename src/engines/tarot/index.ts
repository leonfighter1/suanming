import { createHmac, randomUUID } from "node:crypto";
import {
  canonicalJson,
  inputDigest,
  SCHEMA_VERSION,
  sha256Hex,
  type ChartFact,
} from "../../chart-fact/index.js";
import { DECK, DECK_ID, SPREADS, type SpreadId } from "./deck.js";
import { HmacDrbg } from "./drbg.js";

export const TAROT_ENGINE_VERSION = "0.1.0";

export interface TarotContext {
  /**
   * Server-side draw key (>= 32 bytes, secrets manager). seed = HMAC(drawKey, draw_id).
   * The seed itself is never persisted (Phase 1 §2.1); holding the key + draw_id
   * reproduces the spread (Phase 0 §2.1 auditability).
   */
  drawKey: Buffer;
  digestPepper: Buffer;
  now?: () => Date;
  newDrawId?: () => string;
}

export interface TarotInput {
  spread: SpreadId;
  /** Probability a card is reversed. Default 0.5. */
  reversedRate?: number;
}

export function deriveSeed(drawKey: Buffer, drawId: string): Buffer {
  return createHmac("sha256", drawKey).update(`tarot-seed/v1:${drawId}`).digest();
}

/** Draw a spread from a seed. Pure function — used both for live draws and audit replay. */
export function drawWithSeed(seed: Buffer, spread: SpreadId, reversedRate = 0.5) {
  const rng = new HmacDrbg(seed);
  const order = DECK.map((c) => c.id);
  const positions = SPREADS[spread];
  // Partial Fisher–Yates: only shuffle the first k slots.
  for (let i = 0; i < positions.length; i++) {
    const j = i + rng.nextInt(order.length - i);
    [order[i], order[j]] = [order[j]!, order[i]!];
  }
  const threshold = Math.round(reversedRate * 2 ** 32);
  return positions.map((key, i) => ({
    position: i + 1,
    position_key: key,
    card_id: order[i]!,
    reversed: rng.nextUint32() < threshold,
  }));
}

export function computeTarot(input: TarotInput, ctx: TarotContext): ChartFact {
  const reversedRate = input.reversedRate ?? 0.5;
  const draw_id = ctx.newDrawId?.() ?? randomUUID();
  const drawn_at = (ctx.now?.() ?? new Date()).toISOString();
  const cards = drawWithSeed(deriveSeed(ctx.drawKey, draw_id), input.spread, reversedRate);
  const rule_versions = { deck: DECK_ID, rng: "hmac-sha256-drbg/v1" };
  const normalized = { spread: input.spread, reversed_rate: reversedRate, draw_id };

  return {
    schema_version: SCHEMA_VERSION,
    engine: { name: "tarot", version: TAROT_ENGINE_VERSION },
    system: "tarot",
    input_digest: inputDigest(
      { input: normalized, engine_version: TAROT_ENGINE_VERSION, rule_versions },
      ctx.digestPepper,
    ),
    rule_versions,
    computed_at: drawn_at,
    facts: {
      deck_id: DECK_ID,
      spread_id: input.spread,
      reversed_rate: reversedRate,
      cards,
      audit: {
        draw_id,
        drawn_at,
        rng: "hmac-sha256-drbg/v1",
        result_digest: `sha256:${sha256Hex(canonicalJson({ draw_id, spread: input.spread, cards }))}`,
      },
    },
    provenance: [
      { path: "/cards", source_level: "traditional_text", note: "RWS 78 张；牌阵位置义为通行版本" },
      {
        path: "/cards/reversed",
        source_level: "common_consensus",
        note: `逆位概率 ${reversedRate}`,
      },
    ],
  };
}

/**
 * Audit replay: recompute a past draw from key + draw_id. Passes only if the
 * recomputed cards, the stored cards and the stored digest all agree.
 */
export function verifyDraw(fact: ChartFact, drawKey: Buffer): boolean {
  const f = fact.facts as {
    spread_id: SpreadId;
    reversed_rate: number;
    cards: unknown[];
    audit: { draw_id: string; result_digest: string };
  };
  const digestOf = (cards: unknown[]) =>
    `sha256:${sha256Hex(canonicalJson({ draw_id: f.audit.draw_id, spread: f.spread_id, cards }))}`;
  const replayed = drawWithSeed(deriveSeed(drawKey, f.audit.draw_id), f.spread_id, f.reversed_rate);
  return (
    digestOf(replayed) === f.audit.result_digest && digestOf(f.cards) === f.audit.result_digest
  );
}
