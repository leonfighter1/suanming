/**
 * 求籤 (tech plan WP6.1): a lot of the 關聖帝君一百籤, drawn and confirmed by 擲筊 as temples commonly do it.
 * Its own method (rule 8): nothing here is used by 八字, tarot or astrology.
 *
 * - 搖籤筒: a stick falls, one of the set's lots with equal chance.
 * - 擲筊: two blocks, each landing flat face up or round face up with probability ½ (a simplification of real
 *   blocks). One of each is 聖筊: the stick is confirmed. Both flat is 笑筊 and both round is 陰筊: the stick
 *   goes back and the user draws again.
 * - One stick and one throw per round. A 聖筊 comes half the time, so the engine stops at 64 rounds (2⁻⁶⁴).
 *
 * Deterministic from the seed, so a draw replays from the draw key and its id, like a tarot draw.
 */
import { createHmac, randomUUID } from "node:crypto";
import {
  canonicalJson,
  inputDigest,
  SCHEMA_VERSION,
  sha256Hex,
  type ChartFact,
} from "../../chart-fact/index.js";
import { HmacDrbg } from "../tarot/drbg.js";
import { LOT_SET_IDS, lotSet, type LotSetId } from "./lots.js";

export const QIUQIAN_ENGINE_VERSION = "0.1.0";
export const MAX_ROUNDS = 64;

export type BlockFace = "flat" | "round";
/** 聖筊 (one of each), 笑筊 (both flat), 陰筊 (both round) */
export type Throw = "sheng" | "xiao" | "yin";

export interface Round {
  /** The stick that fell */
  lot: number;
  blocks: [BlockFace, BlockFace];
  result: Throw;
}

export interface QiuqianFacts {
  lot_set: LotSetId;
  lot: { n: number; ganzhi: string; poem: string[] };
  rounds: Round[];
  audit: { draw_id: string; drawn_at: string; rng: string; result_digest: string };
}

export interface QiuqianContext {
  /** The server's draw key, as for tarot; seed = HMAC(drawKey, "qiuqian-seed/v1:" + draw id). */
  drawKey: Buffer;
  digestPepper: Buffer;
  now?: () => Date;
  newDrawId?: () => string;
}

export const throwOf = ([a, b]: [BlockFace, BlockFace]): Throw =>
  a !== b ? "sheng" : a === "flat" ? "xiao" : "yin";

export function deriveSeed(drawKey: Buffer, drawId: string): Buffer {
  return createHmac("sha256", drawKey).update(`qiuqian-seed/v1:${drawId}`).digest();
}

/** The rounds of a draw, from its seed. Pure: live draws and audit replay. */
export function drawWithSeed(seed: Buffer, lots: number): Round[] {
  const rng = new HmacDrbg(seed);
  const face = (): BlockFace => (rng.nextInt(2) === 0 ? "flat" : "round");
  const rounds: Round[] = [];
  while (rounds.length < MAX_ROUNDS) {
    const lot = rng.nextInt(lots) + 1;
    const blocks: [BlockFace, BlockFace] = [face(), face()];
    const result = throwOf(blocks);
    rounds.push({ lot, blocks, result });
    if (result === "sheng") return rounds;
  }
  throw new Error(`no 聖筊 in ${MAX_ROUNDS} rounds`);
}

const digestOf = (drawId: string, set: LotSetId, rounds: Round[]) =>
  `sha256:${sha256Hex(canonicalJson({ draw_id: drawId, lot_set: set, rounds }))}`;

export function computeQiuqian(input: { lot_set?: LotSetId }, ctx: QiuqianContext): ChartFact {
  const setId = input.lot_set ?? "guandi_100";
  if (!LOT_SET_IDS.includes(setId)) throw new Error(`unknown lot set ${setId}`);
  const set = lotSet(setId);
  const draw_id = ctx.newDrawId?.() ?? randomUUID();
  const drawn_at = (ctx.now?.() ?? new Date()).toISOString();
  const rounds = drawWithSeed(deriveSeed(ctx.drawKey, draw_id), set.lots.length);
  const lot = set.lots[rounds.at(-1)!.lot - 1]!;
  const rng = "hmac-sha256-drbg/v1";
  const rule_versions = { lot_set: `${set.id}@${set.version}`, rng };

  return {
    schema_version: SCHEMA_VERSION,
    engine: { name: "qiuqian", version: QIUQIAN_ENGINE_VERSION },
    system: "qiuqian",
    input_digest: inputDigest(
      {
        input: { lot_set: setId, draw_id },
        engine_version: QIUQIAN_ENGINE_VERSION,
        rule_versions,
      },
      ctx.digestPepper,
    ),
    rule_versions,
    computed_at: drawn_at,
    facts: {
      lot_set: setId,
      lot: { n: lot.n, ganzhi: lot.ganzhi, poem: [...lot.poem["zh-Hant"]] },
      rounds,
      audit: { draw_id, drawn_at, rng, result_digest: digestOf(draw_id, setId, rounds) },
    } satisfies QiuqianFacts,
    provenance: [
      {
        path: "/lot/poem",
        source_level: "traditional_text",
        note: "關聖帝君一百籤（雷雨師一百籤），臺灣廟宇通行文本，以清刊本《關帝靈籤》校（docs/verification/qiuqian-guandi-100.md）",
      },
      {
        path: "/rounds",
        source_level: "common_consensus",
        note: "得聖筊即為此籤，笑筊、陰筊則放回重抽；每塊筊正反各半（簡化）",
      },
    ],
  };
}

/**
 * Audit replay: recompute a past draw from the key and its draw id. Passes only if the replayed rounds, the
 * stored rounds and the stored digest agree, and the lot shown is the confirmed stick.
 */
export function verifyDraw(fact: ChartFact, drawKey: Buffer): boolean {
  const f = fact.facts as unknown as QiuqianFacts;
  const set = lotSet(f.lot_set);
  const replayed = drawWithSeed(deriveSeed(drawKey, f.audit.draw_id), set.lots.length);
  const stored = digestOf(f.audit.draw_id, f.lot_set, f.rounds);
  return (
    digestOf(f.audit.draw_id, f.lot_set, replayed) === f.audit.result_digest &&
    stored === f.audit.result_digest &&
    f.lot.n === replayed.at(-1)!.lot
  );
}
