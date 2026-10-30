/**
 * 每日一牌 (tech plan WP3.3): one card a day per account. Its draw id comes from the account and
 * the date under the draw key, so the card stays the same all day, can't be guessed without the
 * key, and the audit replays it like any draw (the stored draw_id seeds the same shuffle).
 *
 * 今日一卦 / 今日一签 (S26) are dealt the same way, under labels of their own.
 */
import { createHmac } from "node:crypto";
import type { ChartFact } from "../chart-fact/index.js";
import { computeLiuyao } from "../engines/liuyao/index.js";
import { computeQiuqian } from "../engines/qiuqian/index.js";
import { computeTarot } from "../engines/tarot/index.js";
import { InputError, type EngineSecrets } from "./charts.js";

/** A UUID (version 8, RFC 9562) from an HMAC: the same for the same label, unguessable without the key. */
export function keyedUuid(key: Buffer, label: string): string {
  const b = createHmac("sha256", key).update(label).digest().subarray(0, 16);
  b[6] = (b[6]! & 0x0f) | 0x80; // version 8
  b[8] = (b[8]! & 0x3f) | 0x80; // RFC 9562 variant
  const h = b.toString("hex");
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20)}`;
}

/** The day's draw id and chart id for an account (separate labels, so the two never coincide). */
export function dailyIds(drawKey: Buffer, user: string, date: string) {
  return {
    drawId: keyedUuid(drawKey, `daily-draw|${user}|${date}`),
    chartId: keyedUuid(drawKey, `daily-chart|${user}|${date}`),
  };
}

const DAY_MS = 86_400_000;

/**
 * The reader's calendar date (YYYY-MM-DD). It must be within a day of the server's UTC date,
 * which covers every time zone's today, so no one reads ahead to tomorrow's card.
 */
export function dailyDate(raw: unknown, now: Date): string {
  if (typeof raw !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(raw)) {
    throw new InputError("date must be YYYY-MM-DD");
  }
  const day = Date.parse(`${raw}T00:00:00Z`);
  const today = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate());
  if (Number.isNaN(day) || new Date(day).toISOString().slice(0, 10) !== raw) {
    throw new InputError("date must be a real calendar date");
  }
  if (Math.abs(day - today) > DAY_MS) throw new InputError("date must be today's date");
  return raw;
}

/** The day's card: a single-card draw seeded by its draw id. */
export function drawDaily(secrets: EngineSecrets, drawId: string, now?: () => Date): ChartFact {
  return computeTarot({ spread: "single" }, { ...secrets, now, newDrawId: () => drawId });
}

/** The 东方 methods 今日一卦 / 今日一签 comes from (S26): 求签's 签 or 算卦's 卦. */
export const EAST_DAILY = ["qiuqian", "liuyao"] as const;
export type EastDailySystem = (typeof EAST_DAILY)[number];

/**
 * The account's 东方 draw of the day (S26; owner, 2026-10-30: 「东方系列，我们可以增加今日一卦或者今日一签功能，可以随机
 * 出现」): which of [systems] (the served ones of EAST_DAILY) it is, keyed from the account and the date, so it changes
 * at random from day to day and stays the same all day; and its draw id and chart id, under labels of their own,
 * never 每日一牌's.
 */
export function eastDaily(
  drawKey: Buffer,
  user: string,
  date: string,
  systems: readonly EastDailySystem[],
) {
  if (systems.length === 0) throw new Error("no 东方 method to deal from");
  const pick = createHmac("sha256", drawKey).update(`daily-east-pick|${user}|${date}`).digest()[0]!;
  return {
    system: systems[pick % systems.length]!,
    drawId: keyedUuid(drawKey, `daily-east-draw|${user}|${date}`),
    chartId: keyedUuid(drawKey, `daily-east-chart|${user}|${date}`),
  };
}

/** The reader's IANA time zone (a day's 卦 is cast on its clock). */
export function dailyZone(raw: unknown): string {
  const problem = "timezone must be an IANA time zone, e.g. Asia/Hong_Kong";
  if (typeof raw !== "string" || raw === "") throw new InputError(problem);
  try {
    new Intl.DateTimeFormat("en", { timeZone: raw });
  } catch {
    throw new InputError(problem);
  }
  return raw;
}

/**
 * The day's 签 (a lot of the 關聖帝君一百籤, confirmed by 擲筊 as on the 求签 page) or 卦 (an auto cast of three coins,
 * cast now on the reader's clock), seeded by its draw id so the audit replays it. Each from its own engine (rule 8).
 */
export function drawEastDaily(
  system: EastDailySystem,
  secrets: EngineSecrets,
  drawId: string,
  timezone: string,
  now?: () => Date,
): ChartFact {
  const ctx = { ...secrets, now, newDrawId: () => drawId };
  return system === "qiuqian"
    ? computeQiuqian({ lot_set: "guandi_100" }, ctx)
    : computeLiuyao({ mode: "auto", timezone }, ctx);
}
