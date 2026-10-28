/**
 * Chart service: validates a chart request (OpenAPI ChartRequest) and runs the
 * matching engine. Shared by the v1 API and the demo.
 */
import type { ChartFact } from "../chart-fact/index.js";
import { computeAstrology } from "../engines/astrology/index.js";
import { computeBazi, type InputBasis } from "../engines/bazi/index.js";
import { computeFengshui } from "../engines/fengshui/index.js";
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
  | { system: "fengshui"; room: RoomId; facing?: Facing };

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
    default:
      throw new InputError("system must be bazi | tarot | astrology | qiuqian | fengshui | naming");
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
