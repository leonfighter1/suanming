/**
 * 设置 (S31) for staff with the settings capability (roles.ts: admin): every setting with its value, its default and
 * when it was changed; a setting changed (within its range) or put back to its default. Each change is logged with its
 * value: settings hold no person's data.
 */
import type { IncomingMessage, ServerResponse } from "node:http";
import type { UserRecord } from "../auth/service.js";
import { HttpError, readJson, send } from "../http/util.js";
import { isSettingKey, SettingError } from "../settings/index.js";
import type { AdminContext } from "./routes.js";
import { loginOf } from "./stats.js";

/** The settings' routes; false for any other path. */
export async function settingsAdminRoute(
  ctx: AdminContext,
  req: IncomingMessage,
  res: ServerResponse,
  path: string,
  me: UserRecord,
): Promise<boolean> {
  if (path === "/v1/admin/settings" && req.method === "GET") {
    send(res, 200, { settings: ctx.settings.list() });
    return true;
  }
  const m = /^\/v1\/admin\/settings\/([a-z_]+\.[a-z_]+)$/.exec(path);
  if (!m) return false;
  const key = m[1]!;
  if (!isSettingKey(key)) throw new HttpError(404, "no such setting", "unknown_setting");
  if (req.method === "PUT") {
    const body = (await readJson(req)) as Record<string, unknown>;
    try {
      await ctx.settings.set(key, body.value, me.id, ctx.now().toISOString());
    } catch (e) {
      if (e instanceof SettingError) throw new HttpError(400, e.message, "invalid_setting");
      throw e;
    }
    ctx.log(`setting ${key} = ${JSON.stringify(body.value)} by ${loginOf(me)}`);
    send(res, 200, ctx.settings.view(key));
    return true;
  }
  if (req.method === "DELETE") {
    await ctx.settings.reset(key);
    ctx.log(`setting ${key} back to its default by ${loginOf(me)}`);
    send(res, 200, ctx.settings.view(key));
    return true;
  }
  throw new HttpError(405, "method not allowed");
}
