/**
 * 每日一牌 (tech plan WP3.3): one card a day per account. Its draw id comes from the account and
 * the date under the draw key, so the card stays the same all day, can't be guessed without the
 * key, and the audit replays it like any draw (the stored draw_id seeds the same shuffle).
 */
import { createHmac } from "node:crypto";
import type { ChartFact } from "../chart-fact/index.js";
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
