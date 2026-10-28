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
  /** The user's cut and picks (洗牌 → 切牌 → 选牌, v3.0.0); without it the engine picks. */
  ritual?: TarotRitual;
}

/**
 * The user's part of a draw (tech plan WP3.6): where they cut the shuffled deck, and the
 * places they picked from it, face down. Stored in the draw's audit so the draw replays.
 */
export interface TarotRitual {
  /** 0–77: the cards from this place on go to the top (0: not cut). */
  cut: number;
  /** One place (0–77) in the cut deck per card of the spread, in the order picked. */
  picks: number[];
}

/** A ritual that fits [spread]: an error message, or null. */
export function ritualProblem(spread: SpreadId, r: unknown): string | null {
  if (!r || typeof r !== "object") return "ritual must be { cut, picks }";
  const { cut, picks } = r as Record<string, unknown>;
  const place = (v: unknown) =>
    Number.isInteger(v) && (v as number) >= 0 && (v as number) < DECK.length;
  if (!place(cut)) return `ritual.cut must be an integer from 0 to ${DECK.length - 1}`;
  const k = SPREADS[spread].length;
  if (!Array.isArray(picks) || picks.length !== k) return `ritual.picks must hold ${k} places`;
  if (!picks.every(place)) return `ritual.picks must be integers from 0 to ${DECK.length - 1}`;
  if (new Set(picks).size !== k) return "ritual.picks must all be different";
  return null;
}

/**
 * A draw the user takes part in (WP3.6). The engine still shuffles: the whole deck from the
 * seed (full Fisher–Yates), each place with its orientation, also from the seed. The user cuts
 * that deck and picks places; the cards are the ones lying there. Pure: live draws and replay.
 */
export function drawWithRitual(
  seed: Buffer,
  spread: SpreadId,
  ritual: TarotRitual,
  reversedRate = 0.5,
) {
  const rng = new HmacDrbg(seed);
  const order = DECK.map((c) => c.id);
  for (let i = 0; i < order.length - 1; i++) {
    const j = i + rng.nextInt(order.length - i);
    [order[i], order[j]] = [order[j]!, order[i]!];
  }
  const threshold = Math.round(reversedRate * 2 ** 32);
  const reversed = order.map(() => rng.nextUint32() < threshold);
  // The cut: the cards from `cut` on go on top, each keeping its orientation.
  const at = (place: number) => (place + ritual.cut) % order.length;
  return SPREADS[spread].map((key, i) => ({
    position: i + 1,
    position_key: key,
    card_id: order[at(ritual.picks[i]!)]!,
    reversed: reversed[at(ritual.picks[i]!)]!,
  }));
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
  const ritual = input.ritual && { cut: input.ritual.cut, picks: [...input.ritual.picks] };
  if (ritual) {
    const problem = ritualProblem(input.spread, ritual);
    if (problem) throw new Error(problem);
  }
  const seed = deriveSeed(ctx.drawKey, draw_id);
  const cards = ritual
    ? drawWithRitual(seed, input.spread, ritual, reversedRate)
    : drawWithSeed(seed, input.spread, reversedRate);
  const rule_versions = { deck: DECK_ID, rng: "hmac-sha256-drbg/v1" };
  const normalized = {
    spread: input.spread,
    reversed_rate: reversedRate,
    draw_id,
    ...(ritual && { ritual }),
  };

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
        // The user's cut and picks (v3.0.0): with the draw id, they replay the draw.
        ...(ritual && { ritual }),
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
    audit: { draw_id: string; result_digest: string; ritual?: TarotRitual };
  };
  const digestOf = (cards: unknown[]) =>
    `sha256:${sha256Hex(canonicalJson({ draw_id: f.audit.draw_id, spread: f.spread_id, cards }))}`;
  const seed = deriveSeed(drawKey, f.audit.draw_id);
  const replayed = f.audit.ritual
    ? drawWithRitual(seed, f.spread_id, f.audit.ritual, f.reversed_rate)
    : drawWithSeed(seed, f.spread_id, f.reversed_rate);
  return (
    digestOf(replayed) === f.audit.result_digest && digestOf(f.cards) === f.audit.result_digest
  );
}
