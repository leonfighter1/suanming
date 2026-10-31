/**
 * 维护 (S35; the owner, 2026-10-31: 「添加正在维护的通知，admin可以toggle 告知用户何时能够登录 by default 3-4 小时，可以自己
 * 定时」): while 设置's maintenance.on is on, anyone but staff waits (the server answers 503 `maintenance`), told when
 * they may sign in again: 预计结束 where an admin set it, else three to four hours from when it was switched on.
 */
import type { Settings } from "./index.js";

/** The window users are told, from the moment it was switched on, when no end is set: 3 to 4 hours. */
export const MAINTENANCE_HOURS = { from: 3, to: 4 } as const;

export interface Maintenance {
  /** When it was switched on (ISO). */
  since: string;
  /** The earliest and the latest it is expected to end (ISO); the same time where an admin set it. */
  ends_from: string;
  ends_by: string;
}

/**
 * The maintenance on now, or undefined. [startedAt]: when this server started, the switch's time where the panel
 * never changed it (switched on in config/settings.json).
 */
export function maintenanceOf(settings: Settings, startedAt: Date): Maintenance | undefined {
  if (settings.value("maintenance.on") !== true) return undefined;
  const since = settings.changedAt("maintenance.on") ?? startedAt.toISOString();
  const until = settings.value("maintenance.until");
  if (typeof until === "string") {
    const end = new Date(until).toISOString();
    return { since, ends_from: end, ends_by: end };
  }
  const hours = (h: number) => new Date(Date.parse(since) + h * 3_600_000).toISOString();
  return { since, ends_from: hours(MAINTENANCE_HOURS.from), ends_by: hours(MAINTENANCE_HOURS.to) };
}
