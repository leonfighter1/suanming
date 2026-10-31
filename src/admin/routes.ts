/**
 * 管理后台 (v11.2.0, tech plan S22): the admin API, `/v1/admin/*` beside 内容审核's reviews. Admins only: an account
 * with the admin role, or one of the server's MINGLI_ADMINS logins. The numbers are read from the store and the
 * accounts and worked out in stats.ts; the exports are made in report.ts.
 */
import { randomUUID } from "node:crypto";
import type { IncomingMessage, ServerResponse } from "node:http";
import type { Store } from "../api/store.js";
import {
  permissionsOf,
  type AccountRole,
  type AuthService,
  type UserRecord,
} from "../auth/service.js";
import type { Dispatcher } from "../notify/dispatch.js";
import { contentAdminRoute } from "./content.js";
import { messagesRoute } from "./messages.js";
import {
  ACCOUNT_ROLES,
  assignableRoles,
  can,
  CAPABILITIES,
  staffRoleOf,
  type Capability,
  type StaffRole,
} from "./roles.js";
import { contentDisposition, documentName } from "../export/document.js";
import { renderDocx } from "../export/render-docx.js";
import { renderPdf } from "../export/render-pdf.js";
import { HttpError, readJson, send } from "../http/util.js";
import type { PointsConfig, PointsEntry } from "../points/index.js";
import { shareFont } from "../share/font.js";
import { reportDoc, seriesCsv, usersCsv } from "./report.js";
import {
  ACTIVE_WINDOWS,
  activeUsers,
  breakdown,
  jobsOf,
  loginOf,
  overview,
  queryUsers,
  series,
  USER_SORTS,
  userRows,
  type AdminData,
  type UserQuery,
} from "./stats.js";

export interface AdminContext {
  store: Store;
  auth: AuthService;
  config: PointsConfig;
  /** MINGLI_ADMINS, lower case: admins whatever their record says. */
  admins: Set<string>;
  /** The server's dispatcher: the messages' templates, previews, test sends and log (S25). */
  messages?: Dispatcher;
  now: () => Date;
  log: (msg: string) => void;
}

/** Whose calendar a day is, unless a request names a time zone: the owner's markets are all at UTC+8. */
export const ADMIN_TZ = "Asia/Shanghai";
export const GRANT_MAX = 1_000_000;

const byConfig = (ctx: AdminContext, u: UserRecord) =>
  [u.username, u.email].some((n) => !!n && ctx.admins.has(n.toLowerCase()));

/** The caller and their staff role (admin, manager, integrator: roles.ts), or 403 admin_only. */
async function staffOf(ctx: AdminContext, userId: string): Promise<{ me: UserRecord; role: StaffRole }> {
  const u = await ctx.auth.users.get(userId);
  const role = u && staffRoleOf(u, byConfig(ctx, u));
  if (!u || !role) throw new HttpError(403, "staff only", "admin_only");
  return { me: u, role };
}

/**
 * What a request needs (roles.ts): the messages, a user's data (增加积分, 在所有设备上退出, the exports), roles and
 * permissions (an account's PATCH), else the view. One place, so no route goes unchecked.
 */
function capabilityOf(path: string, method: string): Capability {
  if (path.startsWith("/v1/admin/messages/")) return "messages";
  if (path === "/v1/admin/content" || path.startsWith("/v1/admin/content/")) return "content";
  if (path === "/v1/admin/reports") return "user_data";
  if (/^\/v1\/admin\/users\/[^/]+\/(points|sign-out)$/.test(path)) return "user_data";
  if (/^\/v1\/admin\/users\/[^/]+$/.test(path) && method === "PATCH") return "assign";
  return "view";
}

function daysOf(raw: string | null): number {
  if (raw === null) return 30;
  const n = Number(raw);
  if (!Number.isInteger(n) || n < 1 || n > 366) throw new HttpError(400, "days must be 1–366");
  return n;
}

function tzOf(raw: string | null): string {
  if (!raw) return ADMIN_TZ;
  try {
    new Intl.DateTimeFormat("en", { timeZone: raw });
    return raw;
  } catch {
    throw new HttpError(400, "tz must be an IANA time zone, e.g. Asia/Shanghai");
  }
}

async function load(ctx: AdminContext, tz: string): Promise<AdminData> {
  const [users, entries, usage, balances] = await Promise.all([
    ctx.auth.users.list(),
    ctx.store.allPoints(),
    ctx.store.listUsage(),
    ctx.store.allBalances(),
  ]);
  return {
    users,
    entries,
    usage,
    balances,
    config: ctx.config,
    now: ctx.now(),
    tz,
    configAdmin: (u) => byConfig(ctx, u),
  };
}

/** A 积分 change as an admin sees it: with its cost and its note. */
const adminEntry = (e: PointsEntry) => {
  const { owner: _o, ...rest } = e;
  return rest;
};

function file(res: ServerResponse, name: string, type: string, body: Buffer | string) {
  const bytes = typeof body === "string" ? Buffer.from(body, "utf8") : body;
  res.writeHead(200, {
    "content-type": type,
    "content-length": String(bytes.length),
    "content-disposition": contentDisposition(name),
    "cache-control": "no-store",
  });
  res.end(bytes);
}

/** Handles `/v1/admin/*` (but not reviews); false when the path is someone else's. */
export async function adminRoute(
  ctx: AdminContext,
  req: IncomingMessage,
  res: ServerResponse,
  path: string,
  userId: string,
): Promise<boolean> {
  if (!path.startsWith("/v1/admin/") || path.startsWith("/v1/admin/reviews")) return false;
  const { me, role } = await staffOf(ctx, userId);
  const url = new URL(req.url ?? "/", "http://localhost");
  const q = url.searchParams;
  const get = req.method === "GET";

  if (path === "/v1/admin/me" && get) {
    send(res, 200, {
      id: me.id,
      login: loginOf(me),
      role,
      admin_by_config: byConfig(ctx, me),
      can: CAPABILITIES[role],
      assignable_roles: assignableRoles(role),
    });
    return true;
  }
  if (!can(role, capabilityOf(path, req.method ?? "GET"))) {
    throw new HttpError(403, `the ${role} role may not do this`, "not_allowed");
  }
  if (path === "/v1/admin/content" || path.startsWith("/v1/admin/content/")) {
    if (await contentAdminRoute(ctx, req, res, path, me)) return true;
    throw new HttpError(404, "not found");
  }
  if (path.startsWith("/v1/admin/messages/")) {
    if (!ctx.messages) throw new HttpError(404, "messages are not set up on this server");
    if (await messagesRoute({ ...ctx, messages: ctx.messages }, req, res, path, me)) return true;
    throw new HttpError(404, "not found");
  }
  const days = daysOf(q.get("days"));
  const tz = tzOf(q.get("tz"));

  if (path === "/v1/admin/overview" && get) {
    send(res, 200, overview(await load(ctx, tz), days));
    return true;
  }
  if (path === "/v1/admin/series" && get) {
    send(res, 200, { days, tz, items: series(await load(ctx, tz), days) });
    return true;
  }
  if (path === "/v1/admin/breakdown" && get) {
    send(res, 200, { days, tz, ...breakdown(await load(ctx, tz), days) });
    return true;
  }
  if (path === "/v1/admin/users" && get) {
    const sort = q.get("sort");
    if (sort && !(USER_SORTS as readonly string[]).includes(sort)) {
      throw new HttpError(400, `sort must be one of ${USER_SORTS.join(", ")}`);
    }
    const query: UserQuery = {
      ...(q.get("q") && { q: q.get("q")! }),
      ...(q.get("status") === "active" || q.get("status") === "suspended"
        ? { status: q.get("status") as "active" | "suspended" }
        : {}),
      ...(ACCOUNT_ROLES.includes(q.get("role") as AccountRole)
        ? { role: q.get("role") as AccountRole }
        : {}),
      ...(["include", "exclude", "only"].includes(q.get("demo") ?? "")
        ? { demo: q.get("demo") as "include" | "exclude" | "only" }
        : {}),
      ...(sort && { sort: sort as UserQuery["sort"] }),
      asc: q.get("order") === "asc",
      page: Number(q.get("page") ?? 1) || 1,
      per_page: Number(q.get("per_page") ?? 25) || 25,
    };
    send(res, 200, queryUsers(userRows(await load(ctx, tz)), query));
    return true;
  }
  if (path === "/v1/admin/active" && get) {
    const d = await load(ctx, tz);
    const rows = userRows(d);
    send(res, 200, {
      counts: overview(d, 1).active,
      now: activeUsers(d, rows, ACTIVE_WINDOWS.now),
      day: activeUsers(d, rows, ACTIVE_WINDOWS.day),
    });
    return true;
  }

  const um = /^\/v1\/admin\/users\/([^/]+)(\/points|\/sign-out)?$/.exec(path);
  if (um) {
    const id = um[1]!;
    const target = await ctx.auth.users.get(id);
    if (!target) throw new HttpError(404, "account not found");
    const action = um[2];
    if (!action && get) {
      const d = await load(ctx, tz);
      const mine = {
        ...d,
        usage: d.usage.filter((u) => u.owner === id),
        entries: d.entries.filter((e) => e.owner === id),
      };
      send(res, 200, {
        user: userRows(d).find((r) => r.id === id),
        entries: mine.entries.slice(-50).reverse().map(adminEntry),
        jobs: jobsOf(d, id, 30),
        by_method: breakdown(mine, 3650).byMethod,
      });
      return true;
    }
    if (!action && req.method === "PATCH") {
      const body = (await readJson(req)) as Record<string, unknown>;
      const next: UserRecord = { ...target };
      const changed: string[] = [];
      // A manager assigns roles and permissions, but never to or on an admin.
      if (role !== "admin" && staffRoleOf(target, byConfig(ctx, target)) === "admin") {
        throw new HttpError(403, "only an admin changes an admin's account", "not_allowed");
      }
      if (body.status !== undefined) {
        if (body.status !== "active" && body.status !== "suspended") {
          throw new HttpError(400, "status must be active | suspended");
        }
        if (id === me.id && body.status === "suspended") {
          throw new HttpError(409, "an admin can't suspend themselves", "admin_self");
        }
        if (body.status === "suspended") next.status = "suspended";
        else delete next.status;
        changed.push(`status ${body.status}`);
      }
      if (body.role !== undefined) {
        const wanted = body.role as AccountRole;
        if (!ACCOUNT_ROLES.includes(wanted)) {
          throw new HttpError(400, `role must be ${ACCOUNT_ROLES.join(" | ")}`);
        }
        if (!assignableRoles(role).includes(wanted)) {
          throw new HttpError(403, `the ${role} role can't give the ${wanted} role`, "not_allowed");
        }
        if (id === me.id && wanted !== (staffRoleOf(me, byConfig(ctx, me)) ?? "user")) {
          throw new HttpError(409, "nobody changes their own role", "admin_self");
        }
        if (wanted !== "admin" && byConfig(ctx, target)) {
          throw new HttpError(
            409,
            "an admin by the server's MINGLI_ADMINS stays one",
            "admin_by_config",
          );
        }
        if (wanted === "user") delete next.role;
        else next.role = wanted;
        changed.push(`role ${wanted}`);
      }
      if (body.permissions !== undefined) {
        const p = body.permissions as Record<string, unknown> | null;
        if (!p || typeof p !== "object" || Array.isArray(p)) {
          throw new HttpError(400, "permissions must be an object");
        }
        for (const k of Object.keys(p)) {
          if ((k !== "ai" && k !== "top_up") || typeof p[k] !== "boolean") {
            throw new HttpError(400, "permissions take ai and top_up, each true or false");
          }
        }
        next.permissions = {
          ...permissionsOf(target),
          ...(p as { ai?: boolean; top_up?: boolean }),
        };
        changed.push(`permissions ${JSON.stringify(next.permissions)}`);
      }
      await ctx.auth.users.put(next);
      // A suspension ends every session at once.
      if (next.status === "suspended" && target.status !== "suspended") {
        await ctx.auth.signOutEverywhere(id);
      }
      ctx.log(
        `admin ${loginOf(me)}: account ${id.slice(0, 8)} ${changed.join(", ") || "unchanged"}`,
      );
      const d = await load(ctx, tz);
      send(
        res,
        200,
        userRows(d).find((r) => r.id === id),
      );
      return true;
    }
    if (action === "/points" && req.method === "POST") {
      const body = (await readJson(req)) as Record<string, unknown>;
      const points = body.points;
      if (!Number.isInteger(points) || (points as number) < 1 || (points as number) > GRANT_MAX) {
        throw new HttpError(400, `points must be a whole number from 1 to ${GRANT_MAX}`);
      }
      const note =
        typeof body.note === "string" && body.note.trim()
          ? [...body.note.trim()].slice(0, 200).join("")
          : undefined;
      const entry = await ctx.store.creditPoints(
        id,
        points as number,
        { kind: "grant", reason: `admin:${randomUUID()}`, ...(note && { note }) },
        ctx.now().toISOString(),
      );
      ctx.log(`admin ${loginOf(me)}: granted ${points} 积分 to ${id.slice(0, 8)}`);
      const { balance, held } = await ctx.store.pointsOf(id);
      send(res, 201, {
        entry: adminEntry(entry!),
        balance,
        held,
        available: Math.max(0, balance - held),
      });
      return true;
    }
    if (action === "/sign-out" && req.method === "POST") {
      await ctx.auth.signOutEverywhere(id);
      ctx.log(`admin ${loginOf(me)}: signed ${id.slice(0, 8)} out everywhere`);
      send(res, 200, { signed_out: true });
      return true;
    }
  }

  if (path === "/v1/admin/reports" && get) {
    const format = q.get("format") ?? "csv";
    const d = await load(ctx, tz);
    const day = series(d, days);
    const span = `${day[0]!.day}_${day.at(-1)!.day}`;
    if (format === "csv") {
      if (q.get("kind") === "users") {
        file(
          res,
          documentName(`命理大师-用户-${span}`, "csv"),
          "text/csv; charset=utf-8",
          usersCsv(userRows(d)),
        );
      } else {
        file(
          res,
          documentName(`命理大师-收益曲线-${span}`, "csv"),
          "text/csv; charset=utf-8",
          seriesCsv(day),
        );
      }
      return true;
    }
    if (format !== "pdf" && format !== "docx") {
      throw new HttpError(400, "format must be csv, pdf or docx");
    }
    const doc = reportDoc(
      overview(d, days),
      day,
      breakdown(d, days),
      d.now.toISOString().slice(0, 16).replace("T", " "),
    );
    if (format === "pdf") {
      const font = shareFont("zh-Hans");
      if (!font) {
        throw new HttpError(
          503,
          "PDF reports need a CJK font on the server: install fonts-noto-cjk or set MINGLI_SHARE_FONT",
        );
      }
      file(
        res,
        documentName(`命理大师-经营报表-${span}`, "pdf"),
        "application/pdf",
        await renderPdf(doc, font),
      );
    } else {
      file(
        res,
        documentName(`命理大师-经营报表-${span}`, "docx"),
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        await renderDocx(doc, "zh-Hans"),
      );
    }
    return true;
  }
  throw new HttpError(404, "not found");
}
