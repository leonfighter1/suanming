/**
 * 算卦 (tech plan S10, the owner's request of 2026-10-28): 六爻 by three coins (金錢卦). Its own method (rule 8):
 * it reads the 周易 text from the one source the 一生运势 report reads (data/yijing, rule 4) and changes
 * nothing there.
 *
 * - The coins, the classical rule: 背 counts 3 and 字 2 (漢典「單錢」: 擲三錢而成二面一背，象徵少陽之爻). One 背
 *   is 少陽 7, two 背 少陰 8, three 背 老陽 9 (moving ○), three 字 老陰 6 (moving ×). Six tosses, the first
 *   is the 初爻. Each coin falls either way with chance ½: a line is 6, 7, 8, 9 with 1/8, 3/8, 3/8, 1/8.
 * - Three ways to cast:
 *   - auto: the 18 coins come from HMAC-DRBG on the cast's own seed, so a cast replays like a tarot draw;
 *   - pick: 24 coins are laid out from the layout's seed before the reader picks 18 of them, one at a time
 *     (picks 1–3 make the 初爻, …, 16–18 the 上爻). The commitment, given out with the layout, shows it came
 *     first;
 *   - manual: the reader's own coins, or lines for readers who count the faces another way, and the time of
 *     the toss, which is required.
 * - The cast time gives the 年月日時 干支, by the 八字 engine's clock policy: the year and month from the
 *   instant's UTC+8 clock (lunar-javascript tabulates 節氣 in UTC+8), the day and hour from the local clock,
 *   子時 as sect 2.
 * - Which texts the reading rests on: 朱熹《易學啟蒙·考變占》 (focusOf).
 */
import { createHmac, randomUUID } from "node:crypto";
import lunar from "lunar-javascript";
import {
  canonicalJson,
  inputDigest,
  SCHEMA_VERSION,
  sha256Hex,
  type ChartFact,
} from "../../chart-fact/index.js";
import { beijingMs, localToUtc, parseLocal, tzOffsetMs, wallClockOf } from "../bazi/time.js";
import { HmacDrbg } from "../tarot/drbg.js";
import { hexagram, zhouyiText } from "../yijing/index.js";

const { Solar } = lunar;

export const LIUYAO_ENGINE_VERSION = "0.1.0+lunar-javascript.1.7.7";
/** Coins laid out for a pick cast, and how many the reader picks (three per line). */
export const LAYOUT_SIZE = 24;
export const PICKS = 18;
/** How far ahead of the server's clock a manual cast time may be (clock drift). */
const FUTURE_SLACK_MS = 2 * 60_000;

export type Face = "zi" | "bei";
export type LineValue = 6 | 7 | 8 | 9;
export type CastMode = "auto" | "pick" | "manual";
type Script2 = { "zh-Hant": string; "zh-Hans": string };

/** Errors the reader's input caused: the API answers them with 400. */
export class LiuyaoInputError extends Error {}

/** A line from its three coins: 背 3, 字 2. */
export const lineOf = (coins: readonly Face[]): LineValue =>
  coins.reduce<number>((sum, c) => sum + (c === "bei" ? 3 : 2), 0) as LineValue;
export const isYang = (v: LineValue) => v === 7 || v === 9;
export const isMoving = (v: LineValue) => v === 6 || v === 9;

export function deriveSeed(drawKey: Buffer, drawId: string): Buffer {
  return createHmac("sha256", drawKey).update(`liuyao-seed/v1:${drawId}`).digest();
}
export function deriveLayoutSeed(drawKey: Buffer, drawId: string): Buffer {
  return createHmac("sha256", drawKey).update(`liuyao-layout/v1:${drawId}`).digest();
}

const faces = (rng: HmacDrbg, n: number): Face[] =>
  Array.from({ length: n }, () => (rng.nextInt(2) === 0 ? "zi" : "bei"));

/** An auto cast's six tosses of three coins, 初爻 first. Pure: live casts and audit replay. */
export function tossWithSeed(seed: Buffer): Face[][] {
  const rng = new HmacDrbg(seed);
  return Array.from({ length: 6 }, () => faces(rng, 3));
}

/** A pick cast's coins as laid out, face down, before the reader picks. */
export function layoutWithSeed(seed: Buffer): Face[] {
  return faces(new HmacDrbg(seed), LAYOUT_SIZE);
}

export const commitmentOf = (drawId: string, layout: readonly Face[]) =>
  `sha256:${sha256Hex(canonicalJson({ draw_id: drawId, layout }))}`;

/** A layout to pick from: its id and the commitment to its coins, which stay on the server. */
export function newLayout(drawKey: Buffer, newDrawId?: () => string) {
  const draw_id = newDrawId?.() ?? randomUUID();
  const layout = layoutWithSeed(deriveLayoutSeed(drawKey, draw_id));
  return { draw_id, size: LAYOUT_SIZE, picks: PICKS, commitment: commitmentOf(draw_id, layout) };
}

// ---- the cast time ----

export interface CastTime {
  /** The local wall clock, to the minute */
  local: string;
  timezone: string;
  utc: string;
  ganzhi: { year: string; month: string; day: string; hour: string };
}

const pad = (n: number) => String(n).padStart(2, "0");
const minuteOf = (w: { y: number; m: number; d: number; h: number; mi: number }) =>
  `${w.y}-${pad(w.m)}-${pad(w.d)}T${pad(w.h)}:${pad(w.mi)}`;

function eightChar(w: { y: number; m: number; d: number; h: number; mi: number }) {
  const ec = Solar.fromYmdHms(w.y, w.m, w.d, w.h, w.mi, 0).getLunar().getEightChar();
  ec.setSect(2);
  return ec;
}

/** The time of a cast: the reader's own for a manual one, else the server's now, in the reader's zone. */
export function castTime(input: { local?: string; timezone: string }, now: Date): CastTime {
  try {
    new Intl.DateTimeFormat("en", { timeZone: input.timezone });
  } catch {
    throw new LiuyaoInputError(`unknown time zone ${input.timezone}`);
  }
  let utcMs: number;
  let local: string;
  if (input.local !== undefined) {
    if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(input.local)) {
      throw new LiuyaoInputError("cast time must be YYYY-MM-DDTHH:mm, to the minute");
    }
    try {
      utcMs = localToUtc(input.local, input.timezone).utcMs;
    } catch (e) {
      throw new LiuyaoInputError(e instanceof Error ? e.message : String(e));
    }
    if (utcMs > now.getTime() + FUTURE_SLACK_MS)
      throw new LiuyaoInputError("cast time is in the future");
    local = input.local;
  } else {
    utcMs = now.getTime() - (now.getTime() % 60_000);
    local = minuteOf(wallClockOf(utcMs + tzOffsetMs(input.timezone, utcMs)));
  }
  const at = eightChar(parseLocal(local));
  const instant = eightChar(wallClockOf(beijingMs(utcMs)));
  return {
    local,
    timezone: input.timezone,
    utc: new Date(utcMs).toISOString(),
    ganzhi: {
      year: instant.getYear(),
      month: instant.getMonth(),
      day: at.getDay(),
      hour: at.getTime(),
    },
  };
}

// ---- the hexagrams and the texts read ----

export interface Hex {
  /** Six lines bottom (初爻) first, 1 = yang, as in data/yijing */
  id: string;
  /** King Wen number */
  number: number;
  name: Script2;
  full_name: Script2;
  /** Trigram ids, lines bottom first */
  upper: string;
  lower: string;
  gua_ci: Script2;
}

export function hexOf(id: string): Hex {
  const h = hexagram(id);
  return {
    id,
    number: zhouyiText(id).number,
    name: h.name,
    full_name: h.full_name,
    upper: h.upper,
    lower: h.lower,
    gua_ci: h.gua_ci,
  };
}

export interface FocusText {
  hexagram: "primary" | "changed";
  /** 1–6 a line (初 to 上), 7 用九 / 用六; absent: the 卦辭 */
  line?: number;
  role: "main" | "also";
  text: Script2;
}

const textOf = (id: string, line?: number): Script2 =>
  line === undefined ? zhouyiText(id).gua_ci : zhouyiText(id).yao_ci[line - 1]!;

/**
 * The texts a cast is read by (朱熹《易學啟蒙·考變占》):
 * - 0 moving: 本卦 卦辭; 1: that line; 2: both lines, the upper first;
 * - 3: 本卦 and 變卦 卦辭, 本卦 first; 4: the 變卦's two still lines, the lower first;
 * - 5: the 變卦's one still line; 6: 乾 用九, 坤 用六, any other the 變卦 卦辭.
 */
export function focusOf(values: readonly LineValue[], primary: string, changed?: string) {
  const moving = values.flatMap((v, i) => (isMoving(v) ? [i + 1] : []));
  const still = values.flatMap((v, i) => (isMoving(v) ? [] : [i + 1]));
  const item = (hex: "primary" | "changed", role: "main" | "also", line?: number): FocusText => ({
    hexagram: hex,
    ...(line !== undefined && { line }),
    role,
    text: textOf(hex === "primary" ? primary : changed!, line),
  });
  const n = moving.length;
  const texts: FocusText[] =
    n === 0
      ? [item("primary", "main")]
      : n === 1
        ? [item("primary", "main", moving[0])]
        : n === 2
          ? [item("primary", "main", moving[1]), item("primary", "also", moving[0])]
          : n === 3
            ? [item("primary", "main"), item("changed", "also")]
            : n === 4
              ? [item("changed", "main", still[0]), item("changed", "also", still[1])]
              : n === 5
                ? [item("changed", "main", still[0])]
                : primary === "111111" || primary === "000000"
                  ? [item("primary", "main", 7)]
                  : [item("changed", "main")];
  return { moving: n, texts };
}

// ---- the cast ----

export interface Toss {
  /** The three coins; null when the reader entered the line itself */
  coins: Face[] | null;
  value: LineValue;
}

export interface LiuyaoFacts {
  mode: CastMode;
  cast: CastTime;
  /** 初爻 first */
  tosses: Toss[];
  lines: { position: number; value: LineValue; yang: boolean; moving: boolean }[];
  primary: Hex;
  changed?: Hex;
  focus: { moving: number; texts: FocusText[] };
  pick?: { size: number; picks: number[]; layout: Face[]; commitment: string };
  audit?: { draw_id: string; cast_at: string; rng: string; result_digest: string };
}

export type ManualLine = { coins: Face[] } | { value: LineValue };

export type LiuyaoInput =
  | { mode: "auto"; timezone: string }
  | { mode: "pick"; timezone: string; draw_id: string; picks: number[] }
  | { mode: "manual"; timezone: string; local: string; lines: ManualLine[] };

export interface LiuyaoContext {
  /** The server's draw key, as for tarot and 求籤 */
  drawKey: Buffer;
  digestPepper: Buffer;
  now?: () => Date;
  newDrawId?: () => string;
}

const RNG = "hmac-sha256-drbg/v1";
const autoDigest = (drawId: string, tosses: Face[][]) =>
  `sha256:${sha256Hex(canonicalJson({ draw_id: drawId, tosses }))}`;
const pickDigest = (drawId: string, layout: Face[], picks: number[]) =>
  `sha256:${sha256Hex(canonicalJson({ draw_id: drawId, layout, picks }))}`;

function manualToss(line: ManualLine): Toss {
  if ("coins" in line) {
    const coins = line.coins;
    if (!Array.isArray(coins) || coins.length !== 3 || coins.some((c) => c !== "zi" && c !== "bei"))
      throw new LiuyaoInputError("each line's coins must be three of zi | bei");
    return { coins: [...coins], value: lineOf(coins) };
  }
  if (![6, 7, 8, 9].includes(line.value))
    throw new LiuyaoInputError("a line's value must be 6, 7, 8 or 9");
  return { coins: null, value: line.value };
}

export function computeLiuyao(input: LiuyaoInput, ctx: LiuyaoContext): ChartFact {
  const now = ctx.now?.() ?? new Date();
  let tosses: Toss[];
  let pick: LiuyaoFacts["pick"];
  let audit: LiuyaoFacts["audit"];
  let digestInput: Record<string, unknown>;
  const cast = castTime(input.mode === "manual" ? input : { timezone: input.timezone }, now);

  if (input.mode === "auto") {
    const draw_id = ctx.newDrawId?.() ?? randomUUID();
    const coins = tossWithSeed(deriveSeed(ctx.drawKey, draw_id));
    tosses = coins.map((c) => ({ coins: c, value: lineOf(c) }));
    audit = { draw_id, cast_at: cast.utc, rng: RNG, result_digest: autoDigest(draw_id, coins) };
    digestInput = { mode: "auto", draw_id, timezone: input.timezone };
  } else if (input.mode === "pick") {
    const { draw_id, picks } = input;
    if (
      !Array.isArray(picks) ||
      picks.length !== PICKS ||
      picks.some((p) => !Number.isInteger(p) || p < 0 || p >= LAYOUT_SIZE) ||
      new Set(picks).size !== PICKS
    ) {
      throw new LiuyaoInputError(
        `picks must be ${PICKS} different coins, each 0–${LAYOUT_SIZE - 1}, in the order picked`,
      );
    }
    const layout = layoutWithSeed(deriveLayoutSeed(ctx.drawKey, draw_id));
    tosses = Array.from({ length: 6 }, (_, i) => {
      const coins = picks.slice(i * 3, i * 3 + 3).map((p) => layout[p]!);
      return { coins, value: lineOf(coins) };
    });
    pick = {
      size: LAYOUT_SIZE,
      picks: [...picks],
      layout,
      commitment: commitmentOf(draw_id, layout),
    };
    audit = {
      draw_id,
      cast_at: cast.utc,
      rng: RNG,
      result_digest: pickDigest(draw_id, layout, picks),
    };
    digestInput = { mode: "pick", draw_id, picks, timezone: input.timezone };
  } else {
    if (!Array.isArray(input.lines) || input.lines.length !== 6)
      throw new LiuyaoInputError("a manual cast needs six lines, 初爻 first");
    tosses = input.lines.map(manualToss);
    digestInput = {
      mode: "manual",
      local: input.local,
      timezone: input.timezone,
      lines: tosses,
    };
  }

  const values = tosses.map((t) => t.value);
  const primaryId = values.map((v) => (isYang(v) ? "1" : "0")).join("");
  const anyMoving = values.some(isMoving);
  const changedId = anyMoving
    ? values.map((v) => (isYang(v) !== isMoving(v) ? "1" : "0")).join("")
    : undefined;
  const rule_versions = { zhouyi: "data/yijing@1", rng: RNG };

  const facts: LiuyaoFacts = {
    mode: input.mode,
    cast,
    tosses,
    lines: values.map((v, i) => ({
      position: i + 1,
      value: v,
      yang: isYang(v),
      moving: isMoving(v),
    })),
    primary: hexOf(primaryId),
    ...(changedId && { changed: hexOf(changedId) }),
    focus: focusOf(values, primaryId, changedId),
    ...(pick && { pick }),
    ...(audit && { audit }),
  };
  return {
    schema_version: SCHEMA_VERSION,
    engine: { name: "liuyao", version: LIUYAO_ENGINE_VERSION },
    system: "liuyao",
    input_digest: inputDigest(
      { input: digestInput, engine_version: LIUYAO_ENGINE_VERSION, rule_versions },
      ctx.digestPepper,
    ),
    rule_versions,
    computed_at: now.toISOString(),
    facts: facts as unknown as Record<string, unknown>,
    provenance: [
      {
        path: "/tosses",
        source_level: "common_consensus",
        note: "金錢卦：背三字二，一背為單（少陽）、二背為拆（少陰）、三背為重（老陽）、三字為交（老陰）",
      },
      {
        path: "/primary/gua_ci",
        source_level: "traditional_text",
        note: "周易通行本（data/yijing/hexagrams.json）",
      },
      {
        path: "/focus",
        source_level: "common_consensus",
        note: "朱熹《易學啟蒙·考變占》：依動爻多少取本卦、之卦之辭",
      },
      {
        path: "/cast/ganzhi",
        source_level: "derived",
        note: "年以立春、月以節氣（東八區），日時以當地時間；子時以晚子時為當日",
      },
    ],
  };
}

/**
 * Audit replay of an auto or pick cast from the key: passes only if the replayed coins, the stored coins and
 * the stored digest agree, and (pick) the stored layout is the committed one.
 */
export function verifyCast(fact: ChartFact, drawKey: Buffer): boolean {
  const f = fact.facts as unknown as LiuyaoFacts;
  if (!f.audit) return false;
  const id = f.audit.draw_id;
  if (f.mode === "auto") {
    const replayed = tossWithSeed(deriveSeed(drawKey, id));
    const stored = f.tosses.map((t) => t.coins ?? []);
    return (
      autoDigest(id, replayed) === f.audit.result_digest &&
      autoDigest(id, stored) === f.audit.result_digest
    );
  }
  if (f.mode === "pick" && f.pick) {
    const layout = layoutWithSeed(deriveLayoutSeed(drawKey, id));
    const coins = f.tosses.map((t) => t.coins ?? []);
    const fromPicks = Array.from({ length: 6 }, (_, i) =>
      f.pick!.picks.slice(i * 3, i * 3 + 3).map((p) => layout[p]!),
    );
    return (
      commitmentOf(id, layout) === f.pick.commitment &&
      pickDigest(id, layout, f.pick.picks) === f.audit.result_digest &&
      pickDigest(id, f.pick.layout, f.pick.picks) === f.audit.result_digest &&
      canonicalJson(fromPicks) === canonicalJson(coins)
    );
  }
  return false;
}
