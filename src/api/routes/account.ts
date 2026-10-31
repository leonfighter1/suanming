/**
 * The API's sign-in and account routes (S28 WP28.9): signing up and in, the tokens and signing out, before there is a
 * caller; then the caller's account: /v1/me, the logins and settings (v8.2.0), and deleting the account.
 */
import type { IncomingMessage, ServerResponse } from "node:http";
import { staffRoleOf } from "../../admin/roles.js";
import { publicUser, type UserRecord } from "../../auth/service.js";
import type { ContactKind } from "../../auth/verify.js";
import { HttpError, readJson, send } from "../../http/util.js";
import type { ApiContext, Caller } from "../context.js";

/** Signing up and in, the tokens and signing out (no caller yet); false for any other path. */
export async function authRoute(
  ctx: ApiContext,
  req: IncomingMessage,
  res: ServerResponse,
  path: string,
): Promise<boolean> {
  const { auth, clientIp } = ctx;
  if (req.method === "POST" && path.startsWith("/v1/auth/")) {
    if (!auth) throw new HttpError(404, "auth not configured");
    const body = (await readJson(req)) as Record<string, unknown>;
    const ip = clientIp(req);
    switch (path) {
      case "/v1/auth/register":
        send(res, 201, await auth.register(body as never));
        return true;
      case "/v1/auth/login":
        send(res, 200, await auth.login(body, ip));
        return true;
      case "/v1/auth/oauth":
        send(res, 200, await auth.socialSignIn(body));
        return true;
      case "/v1/auth/refresh":
        send(res, 200, await auth.refresh(body.refresh_token));
        return true;
      // ☰ → 管理后台 (S33): the one-time code the app handed the dashboard, for a session of its own.
      case "/v1/auth/handoff":
        send(res, 200, await auth.redeemHandoff(body.code));
        return true;
      case "/v1/auth/logout":
        await auth.logout(body.refresh_token);
        res.writeHead(204);
        res.end();
        return true;
    }
    throw new HttpError(404, "not found");
  }
  return false;
}

/** The caller's account: /v1/me, the logins and settings, and deleting it; false for any other path. */
export async function accountRoute(
  ctx: ApiContext,
  req: IncomingMessage,
  res: ServerResponse,
  path: string,
  c: Caller,
): Promise<boolean> {
  const { opts, store, now, auth, account, admins, idempotency, delivery, reviewer } = ctx;
  /** 后台角色 (S25): what the account is in the 管理后台, if anything (named in MINGLI_ADMINS, or given a role). */
  const staffOf = (u: UserRecord) =>
    staffRoleOf(
      u,
      [u.username, u.email].some((n) => !!n && admins.has(n.toLowerCase())),
    );
  /** The caller's account as /v1/me shows it. */
  const me = async () => {
    const u = (await auth!.users.get(c.user))!;
    // The app's ☰ shows 管理后台 to staff; `role` stays what it was, 内容审核's reviewer.
    const staff = staffOf(u);
    return {
      ...publicUser(u),
      role: opts.review !== false && (await reviewer(c)) ? "admin" : "user",
      ...(staff && { staff }),
    };
  };
  if (path === "/v1/me" && req.method === "GET") {
    if (!auth) throw new HttpError(404, "auth not configured");
    send(res, 200, await me());
    return true;
  }
  // The logins and settings (v8.2.0, tech plan WP15.3–15.4): a username; an email or a phone, each proved by a
  // code (POST sends it, POST …/verify brings it back, DELETE removes it); 测算完成后发到邮箱.
  if (path.startsWith("/v1/account/")) {
    if (!auth || !account) throw new HttpError(404, "auth not configured");
    // ☰ → 管理后台 without a second sign-in (S33): a one-time code the dashboard signs in with, for staff.
    if (path === "/v1/account/handoff" && req.method === "POST") {
      if (!staffOf((await auth.users.get(c.user))!)) {
        throw new HttpError(403, "only staff open the 管理后台", "not_staff");
      }
      send(res, 201, auth.handoff(c.user));
      return true;
    }
    if (path === "/v1/account/username" && req.method === "PUT") {
      const body = (await readJson(req)) as Record<string, unknown>;
      await account.setUsername(c.user, body.username);
      send(res, 200, await me());
      return true;
    }
    const contact = /^\/v1\/account\/(email|phone)(\/verify)?$/.exec(path);
    if (contact) {
      const kind = contact[1] as ContactKind;
      if (req.method === "POST" && !contact[2]) {
        const body = (await readJson(req)) as Record<string, unknown>;
        send(res, 202, await account.startContact(c.user, kind, body[kind]));
        return true;
      }
      if (req.method === "POST") {
        const body = (await readJson(req)) as Record<string, unknown>;
        await account.confirmContact(c.user, kind, body[kind], body.code);
        send(res, 200, await me());
        return true;
      }
      if (req.method === "DELETE" && !contact[2]) {
        await account.removeContact(c.user, kind);
        send(res, 200, await me());
        return true;
      }
    }
    if (path === "/v1/account/settings" && req.method === "GET") {
      send(res, 200, { settings: await account.settings(c.user), delivery: delivery() });
      return true;
    }
    if (path === "/v1/account/settings" && req.method === "PATCH") {
      const settings = await account.updateSettings(c.user, await readJson(req));
      send(res, 200, { settings, delivery: delivery() });
      return true;
    }
    throw new HttpError(404, "not found");
  }
  if (path === "/v1/account" && req.method === "DELETE") {
    if (!auth) throw new HttpError(404, "auth not configured");
    // PIPEDA / Québec Law 25: delete the account and everything it owns, now.
    const deleted = await store.deleteOwnerData(c.user);
    account?.forget(c.user);
    await auth.deleteAccount(c.user);
    for (const k of idempotency.keys()) if (k.startsWith(`${c.user}:`)) idempotency.delete(k);
    send(res, 200, {
      deleted: { account: true, ...deleted },
      completed_at: now().toISOString(),
    });
    return true;
  }
  return false;
}
