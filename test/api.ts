// The API for a server test file (S28 WP28.1; docs/refactor-plan.md F9): one home for what thirty files repeated.
import type { AddressInfo } from "node:net";
import { afterAll, beforeAll } from "vitest";
import { MockProvider } from "../src/ai/index.js";
import { createApiServer, type ApiOptions } from "../src/api/server.js";
import type { AccountRole, AuthService } from "../src/auth/service.js";
import { DRAW_KEY, PEPPER } from "./helpers.js";

/**
 * The API for a test file: the test secrets, the mock provider under every provider key (rule 63), dev mode and a
 * silent log, then [options] over them. It listens on a free port for the file's tests, tells [onBase] its address,
 * and closes after them. A file whose slow steps come before its HTTP tests starts its own server in the describe that
 * calls it instead (rule 81).
 */
export function testApi(
  options: Partial<ApiOptions> = {},
  onBase: (base: string) => void = () => {},
) {
  const mock = new MockProvider();
  const api = createApiServer({
    secrets: { digestPepper: PEPPER, drawKey: DRAW_KEY },
    providers: { deepseek: mock, anthropic: mock },
    devMode: true,
    log: () => {},
    ...options,
  });
  beforeAll(async () => {
    await new Promise<void>((r) => api.listen(0, "127.0.0.1", r));
    onBase(`http://127.0.0.1:${(api.address() as AddressInfo).port}`);
  });
  afterAll(() => new Promise<void>((r) => api.close(() => r())));
  return api;
}

/**
 * The API with its staff signed in (S29, S31: one home for what the 管理后台's server tests repeated): [logins] seeded
 * with their login as their password, each given its role from [roles], then signed in. `start` listens and signs them
 * in, once: call it in the beforeAll of each describe whose tests call the API, so no connection waits idle through
 * slow steps before them (rule 81).
 */
export function staffApi(
  options: Partial<ApiOptions> & { auth: AuthService },
  logins: readonly string[],
  roles: Readonly<Record<string, AccountRole>> = {},
) {
  const { auth } = options;
  const mock = new MockProvider();
  const api = createApiServer({
    secrets: { digestPepper: PEPPER, drawKey: DRAW_KEY },
    providers: { deepseek: mock, anthropic: mock },
    devMode: true,
    devHeaders: false,
    log: () => {},
    ...options,
  });
  let base = "";
  const sessions: Record<string, { access_token: string; refresh_token: string }> = {};
  const ids: Record<string, string> = {};
  let started: Promise<void> | undefined;
  const start = () =>
    (started ??= (async () => {
      for (const login of logins) {
        await auth.seedDevUser({ login, password: login, country: "HK", locale: "zh-Hans" });
      }
      for (const [login, role] of Object.entries(roles)) {
        const u = (await auth.findLogin("username", login))!;
        await auth.users.put({ ...u, role });
      }
      await new Promise<void>((r) => api.listen(0, "127.0.0.1", r));
      base = `http://127.0.0.1:${(api.address() as AddressInfo).port}`;
      for (const login of logins) {
        const res = await fetch(base + "/v1/auth/login", {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify({ login, password: login }),
        });
        sessions[login] = await res.json();
        ids[login] = (await auth.findLogin("username", login))!.id;
      }
    })());
  afterAll(() => new Promise<void>((r) => api.close(() => r())));
  /** A request as [who] (null: signed out); a Buffer body goes as it is, under [type]. */
  const call = (
    who: string | null,
    path: string,
    method = "GET",
    body?: unknown,
    type = "application/json",
  ) =>
    fetch(base + path, {
      method,
      headers: {
        "content-type": type,
        ...(who && { authorization: `Bearer ${sessions[who]!.access_token}` }),
      },
      ...(body !== undefined && {
        body: Buffer.isBuffer(body) ? new Uint8Array(body) : JSON.stringify(body),
      }),
    });
  return { api, start, call, sessions, ids };
}
