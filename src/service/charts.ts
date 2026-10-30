/**
 * Chart service: validates a chart request (OpenAPI ChartRequest) and runs the
 * matching engine. Shared by the v1 API and the demo.
 */
import type { ChartFact } from "../chart-fact/index.js";
import { computeAstrology } from "../engines/astrology/index.js";
import { computeBazi, type InputBasis } from "../engines/bazi/index.js";
import { computeFengshui } from "../engines/fengshui/index.js";
import {
  computeLiuyao,
  LiuyaoInputError,
  type CastMode,
  type ManualLine,
} from "../engines/liuyao/index.js";
import { computeNaming } from "../engines/naming/index.js";
import { FACINGS, ROOM_IDS, type Facing, type RoomId } from "../engines/fengshui/principles.js";
import { computeQiuqian } from "../engines/qiuqian/index.js";
import { LOT_SET_IDS, type LotSetId } from "../engines/qiuqian/lots.js";
import { SPREADS, type SpreadId } from "../engines/tarot/deck.js";
import { computeTarot, ritualProblem, type TarotRitual } from "../engines/tarot/index.js";

/** Bad user input (→ HTTP 400/422). */
export class InputError extends Error {}

export interface EngineSecrets {
  digestPepper: Buffer;
  drawKey: Buffer;
}

export type ChartRequest =
  | {
      system: "bazi";
      local: string;
      timezone: string;
      longitude: number;
      gender: "male" | "female";
      options?: { trueSolarTime?: boolean; ziHourSect?: 1 | 2; liunianFrom?: number };
    }
  | { system: "tarot"; spread: SpreadId; draw_id?: string; ritual?: TarotRitual }
  | { system: "astrology"; local: string; timezone: string; latitude: number; longitude: number }
  | { system: "qiuqian"; lot_set?: LotSetId; draw_id?: string }
  | { system: "fengshui"; room: RoomId; facing?: Facing }
  | {
      system: "liuyao";
      mode: CastMode;
      timezone: string;
      /** pick: the layout's id (POST /v1/liuyao/layouts) and the 18 coins picked, in order */
      draw_id?: string;
      picks?: number[];
      /** manual: the time of the toss, to the minute, and the six lines, 初爻 first */
      local?: string;
      lines?: ManualLine[];
    };

export function str(v: unknown, name: string): string {
  if (typeof v !== "string" || !v.trim()) throw new InputError(`${name} is required`);
  return v.trim();
}

export function num(v: unknown, name: string, min: number, max: number): number {
  const n = typeof v === "number" ? v : Number(v);
  if (!Number.isFinite(n) || n < min || n > max) {
    throw new InputError(`${name} must be a number in [${min}, ${max}]`);
  }
  return n;
}

export const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Whose birth chart it is: the name and the birthplace label the app shows (v6.2.0). */
export interface ChartPerson {
  name?: string;
  birthplace?: string;
}

/** The birth charts a person label belongs to; any other chart refuses one. */
export const PERSON_SYSTEMS: readonly string[] = ["bazi", "astrology"];

/**
 * A chart request's optional `person` (v6.2.0): trimmed, cut to 40 and 120 characters, and left out when empty.
 * Kept with the chart record, never in its ChartFact. Any chart may name its person (v8.0.0: 塔罗, 求签, 算卦 and 风水
 * too, so history can group by person); a birthplace belongs to a birth chart only.
 */
export function parsePerson(raw: unknown, system: unknown): ChartPerson | undefined {
  if (raw === undefined || raw === null) return undefined;
  if (typeof raw !== "object" || Array.isArray(raw))
    throw new InputError("person must be an object");
  const p = raw as Record<string, unknown>;
  const field = (key: "name" | "birthplace", max: number) => {
    const v = p[key];
    if (v === undefined || v === null) return undefined;
    if (typeof v !== "string") throw new InputError(`person.${key} must be a string`);
    return [...v.trim()].slice(0, max).join("") || undefined;
  };
  const name = field("name", 40);
  const birthplace = field("birthplace", 120);
  if (birthplace && !PERSON_SYSTEMS.includes(String(system))) {
    throw new InputError(`person.birthplace is for birth charts: ${PERSON_SYSTEMS.join(", ")}`);
  }
  return name || birthplace
    ? { ...(name && { name }), ...(birthplace && { birthplace }) }
    : undefined;
}

/**
 * The methods drawn for a question (owner, 2026-10-29: 「求签和算卦 算法必须要有所问之问题之后才能去求 … 塔罗牌也是一样」):
 * their draw needs one, so nothing is drawn before something is asked. 每日一牌 is the day's card, dealt without a draw.
 */
export const QUESTION_SYSTEMS: readonly string[] = ["tarot", "qiuqian", "liuyao"];
export const QUESTION_MAX = 300;

export const asksQuestion = (system: unknown) => QUESTION_SYSTEMS.includes(String(system));

/** What was asked, trimmed and cut to QUESTION_MAX characters; undefined when it is empty or not a string. */
export function parseQuestion(raw: unknown): string | undefined {
  if (typeof raw !== "string") return undefined;
  return [...raw.trim()].slice(0, QUESTION_MAX).join("") || undefined;
}

/**
 * 归类到… (v8.0.0): a chart's person after a change. A field the change names is set (empty or null clears it); a
 * field it leaves out stays as it was.
 */
export function changePerson(
  current: ChartPerson | undefined,
  raw: unknown,
  system: string,
): ChartPerson | undefined {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
    throw new InputError("the body must be an object with name and/or birthplace");
  }
  const p = raw as Record<string, unknown>;
  return parsePerson(
    {
      name: "name" in p ? p.name : current?.name,
      birthplace: "birthplace" in p ? p.birthplace : current?.birthplace,
    },
    system,
  );
}

/** Engine errors caused by user input (bad format, DST gap, unknown zone) become InputError. */
function asInputError<T>(fn: () => T): T {
  try {
    return fn();
  } catch (e) {
    if (e instanceof InputError) throw e;
    const msg = e instanceof Error ? e.message : String(e);
    if (
      /invalid local datetime|DST gap|out of range|Invalid time zone|timeZone|inputBasis/i.test(msg)
    ) {
      throw new InputError(msg);
    }
    throw e;
  }
}

export function computeChart(raw: unknown, secrets: EngineSecrets, now?: () => Date): ChartFact {
  if (!raw || typeof raw !== "object") throw new InputError("body must be an object");
  const req = raw as Record<string, unknown>;
  switch (req.system) {
    case "bazi": {
      const gender = str(req.gender, "gender");
      if (gender !== "male" && gender !== "female") {
        throw new InputError("gender must be male | female");
      }
      const o = (req.options ?? {}) as Record<string, unknown>;
      if (o.liunianFrom !== undefined && !Number.isInteger(o.liunianFrom)) {
        throw new InputError("options.liunianFrom must be an integer year");
      }
      return asInputError(() =>
        computeBazi(
          {
            local: str(req.local, "local"),
            timezone: str(req.timezone, "timezone"),
            longitude: num(req.longitude, "longitude", -180, 180),
            gender,
            options: {
              trueSolarTime: o.trueSolarTime === undefined ? true : o.trueSolarTime === true,
              ziHourSect: o.ziHourSect === 1 ? 1 : 2,
              ...(o.liunianFrom !== undefined && { liunianFrom: o.liunianFrom as number }),
              ...(o.inputBasis !== undefined && { inputBasis: o.inputBasis as InputBasis }),
            },
          },
          { digestPepper: secrets.digestPepper, now },
        ),
      );
    }
    case "tarot": {
      const spread = (req.spread ?? "three_card") as SpreadId;
      if (!(spread in SPREADS)) {
        throw new InputError(`spread must be one of ${Object.keys(SPREADS).join(", ")}`);
      }
      const drawId = req.draw_id;
      if (drawId !== undefined && (typeof drawId !== "string" || !UUID_RE.test(drawId))) {
        throw new InputError("draw_id must be a UUID");
      }
      // 洗牌 → 切牌 → 选牌 (v3.0.0): the user's cut and picks in the deck the engine shuffles.
      const ritual = req.ritual;
      if (ritual !== undefined) {
        const problem = ritualProblem(spread, ritual);
        if (problem) throw new InputError(problem);
      }
      return computeTarot(
        { spread, ...(ritual !== undefined && { ritual: ritual as TarotRitual }) },
        { ...secrets, now, ...(drawId && { newDrawId: () => drawId as string }) },
      );
    }
    case "astrology":
      return asInputError(() =>
        computeAstrology(
          {
            local: str(req.local, "local"),
            timezone: str(req.timezone, "timezone"),
            latitude: num(req.latitude, "latitude", -90, 90),
            longitude: num(req.longitude, "longitude", -180, 180),
          },
          { digestPepper: secrets.digestPepper, now },
        ),
      );
    case "qiuqian": {
      // 求籤 (v4.3.0): the engine draws the stick and throws the blocks; the app shows the rounds.
      const lotSetId = (req.lot_set ?? "guandi_100") as LotSetId;
      if (!LOT_SET_IDS.includes(lotSetId)) {
        throw new InputError(`lot_set must be one of ${LOT_SET_IDS.join(", ")}`);
      }
      const drawId = req.draw_id;
      if (drawId !== undefined && (typeof drawId !== "string" || !UUID_RE.test(drawId))) {
        throw new InputError("draw_id must be a UUID");
      }
      return computeQiuqian(
        { lot_set: lotSetId },
        { ...secrets, now, ...(drawId && { newDrawId: () => drawId as string }) },
      );
    }
    case "fengshui": {
      // 风水 (v4.4.0): a room and, optionally, the way its main window faces. Nothing else.
      const room = req.room as RoomId;
      if (!ROOM_IDS.includes(room))
        throw new InputError(`room must be one of ${ROOM_IDS.join(", ")}`);
      const facing = req.facing as Facing | undefined;
      if (facing !== undefined && !FACINGS.includes(facing)) {
        throw new InputError(`facing must be one of ${FACINGS.join(", ")}`);
      }
      return computeFengshui(
        { room, ...(facing && { facing }) },
        { digestPepper: secrets.digestPepper, now },
      );
    }
    case "naming":
      // 起名 reads one of the caller's 八字 charts: the API loads it and calls computeNamingChart.
      throw new InputError("a 起名 chart needs bazi_chart_id, one of your 八字 charts");
    case "liuyao": {
      // 算卦 (v5.3.0): the server tosses (auto), the reader picks from coins laid out before (pick), or the
      // reader tosses and enters the lines and the time (manual).
      const mode = req.mode as CastMode;
      if (!["auto", "pick", "manual"].includes(mode))
        throw new InputError("mode must be auto | pick | manual");
      const timezone = str(req.timezone, "timezone");
      const run = <T>(fn: () => T): T => {
        try {
          return fn();
        } catch (e) {
          if (e instanceof LiuyaoInputError) throw new InputError(e.message);
          throw e;
        }
      };
      const engine = { ...secrets, now };
      if (mode === "auto") return run(() => computeLiuyao({ mode, timezone }, engine));
      if (mode === "pick") {
        const drawId = req.draw_id;
        if (typeof drawId !== "string" || !UUID_RE.test(drawId))
          throw new InputError("draw_id must be the UUID of a layout (POST /v1/liuyao/layouts)");
        if (!Array.isArray(req.picks)) throw new InputError("picks must be an array");
        return run(() =>
          computeLiuyao({ mode, timezone, draw_id: drawId, picks: req.picks as number[] }, engine),
        );
      }
      const local = str(req.local, "local");
      if (!Array.isArray(req.lines)) throw new InputError("lines must be an array of six lines");
      const lines = (req.lines as unknown[]).map((l) => {
        if (!l || typeof l !== "object")
          throw new InputError("each line is { coins } or { value }");
        return l as ManualLine;
      });
      return run(() => computeLiuyao({ mode, timezone, local, lines }, engine));
    }
    default:
      throw new InputError(
        "system must be bazi | tarot | astrology | qiuqian | fengshui | naming | liuyao",
      );
  }
}

/**
 * 起名 (v4.5.0): candidate names for a surname, from the caller's own 八字 chart (the API loads it and checks
 * whose it is). The request names the surname (one or two Chinese characters) and the given name's length.
 */
export function computeNamingChart(
  raw: Record<string, unknown>,
  bazi: ChartFact,
  secrets: EngineSecrets,
  now?: () => Date,
): ChartFact {
  if (bazi.system !== "bazi") throw new InputError("bazi_chart_id must be a 八字 chart");
  const surname = str(raw.surname, "surname");
  if (!/^\p{Script=Han}{1,2}$/u.test(surname)) {
    throw new InputError("surname must be one or two Chinese characters");
  }
  const length = raw.length ?? 2;
  if (length !== 1 && length !== 2) throw new InputError("length must be 1 or 2");
  return computeNaming(bazi, { surname, length }, { digestPepper: secrets.digestPepper, now });
}
