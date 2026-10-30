/**
 * The API's public routes (S28 WP28.8; docs/refactor-plan.md F1): the calendar lookups the date pickers use and the
 * birthplaces. Stateless: no caller, no store, so no context.
 */
import type { IncomingMessage, ServerResponse } from "node:http";
import {
  CalendarInputError,
  lunarDate,
  lunarMonths,
  lunarToSolar,
  shichenOptions,
} from "../../engines/bazi/index.js";
import { HttpError, send } from "../../http/util.js";
import { placeCountry, placeIndex } from "../../places/index.js";
import { InputError } from "../../service/charts.js";

/** Answers [path] when it is one of these routes; false when it isn't. */
export function publicRoute(req: IncomingMessage, res: ServerResponse, path: string): boolean {
  // ---- calendar lookup: public, stateless (date pickers show the 農曆 equivalent) ----
  if (req.method === "GET" && path === "/v1/calendar/lunar") {
    const date = new URL(req.url ?? "/", "http://localhost").searchParams.get("date") ?? "";
    const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(date);
    const [y, mo, d] = m ? [Number(m[1]), Number(m[2]), Number(m[3])] : [0, 0, 0];
    const valid =
      m && y >= 1900 && y <= 2100 && new Date(Date.UTC(y, mo - 1, d)).getUTCDate() === d;
    if (!valid) throw new InputError("date must be a valid YYYY-MM-DD between 1900 and 2100");
    send(res, 200, {
      date,
      lunar: lunarDate(y, mo, d),
      shichen: shichenOptions(y, mo, d),
    });
    return true;
  }
  // 農曆 date pickers: the months of a 農曆 year (incl. 閏月), and 農曆 → 公曆.
  if (req.method === "GET" && path === "/v1/calendar/lunar-months") {
    const year = Number(new URL(req.url ?? "/", "http://localhost").searchParams.get("year"));
    if (!Number.isInteger(year) || year < 1900 || year > 2100) {
      throw new InputError("year must be an integer between 1900 and 2100");
    }
    send(res, 200, { year, months: lunarMonths(year) });
    return true;
  }
  if (req.method === "GET" && path === "/v1/calendar/solar") {
    const q = new URL(req.url ?? "/", "http://localhost").searchParams;
    const [year, month, day] = ["year", "month", "day"].map((k) => Number(q.get(k)));
    if (![year, month, day].every(Number.isInteger) || year! < 1900 || year! > 2100) {
      throw new InputError("year, month and day must be integers (year 1900–2100)");
    }
    try {
      const solar = lunarToSolar(year!, month!, day!, q.get("leap") === "true");
      const [sy, sm, sd] = solar.split("-").map(Number) as [number, number, number];
      send(res, 200, { date: solar, lunar: lunarDate(sy, sm, sd) });
      return true;
    } catch (e) {
      if (e instanceof CalendarInputError) throw new InputError(e.message);
      throw e;
    }
  }

  // ---- birthplaces: public, static (country → region → city with timezone + longitude) ----
  if (req.method === "GET" && path === "/v1/places") {
    send(res, 200, placeIndex(), { "cache-control": "public, max-age=86400" });
    return true;
  }
  const pm = /^\/v1\/places\/([^/]+)$/.exec(path);
  if (req.method === "GET" && pm) {
    const data = placeCountry(pm[1]!.toUpperCase());
    if (!data) throw new HttpError(404, "unknown country code");
    send(res, 200, data, { "cache-control": "public, max-age=86400" });
    return true;
  }
  return false;
}
