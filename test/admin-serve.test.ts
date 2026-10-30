import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import type { Server } from "node:http";
import type { AddressInfo } from "node:net";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterAll, describe, expect, it } from "vitest";
import { MockProvider } from "../src/ai/index.js";
import { createApiServer, type ApiOptions } from "../src/api/server.js";
import { DRAW_KEY, PEPPER } from "./helpers.js";

// The built 管理后台 served at /admin/ beside the API (tech plan S22, WP22.5).

const mock = new MockProvider();

const admin = mkdtempSync(join(tmpdir(), "admin-web-"));
writeFileSync(
  join(admin, "index.html"),
  '<!doctype html><base href="/admin/"><title>命理大师 管理后台</title>',
);
writeFileSync(join(admin, "main.dart.js"), "console.log('admin');");
mkdirSync(join(admin, "canvaskit"));
writeFileSync(join(admin, "canvaskit", "canvaskit.wasm"), Buffer.from([0, 97, 115, 109]));
const app = mkdtempSync(join(tmpdir(), "app-web-"));
writeFileSync(join(app, "index.html"), "<!doctype html><title>命理大师</title>");

const open: Server[] = [];
afterAll(async () => {
  await Promise.all(open.map((s) => new Promise<void>((r) => s.close(() => r()))));
  // The two folders this file made (mkdtemp: plain folders, never links).
  for (const dir of [admin, app]) rmSync(dir, { recursive: true, force: true });
});

async function start(extra: Partial<ApiOptions>) {
  const api = createApiServer({
    secrets: { digestPepper: PEPPER, drawKey: DRAW_KEY },
    providers: { deepseek: mock, anthropic: mock },
    devMode: true,
    log: () => {},
    ...extra,
  });
  open.push(api);
  await new Promise<void>((r) => api.listen(0, "127.0.0.1", r));
  return `http://127.0.0.1:${(api.address() as AddressInfo).port}`;
}

describe("the 管理后台 at /admin/", () => {
  it("serves the built dashboard, each file by its type, and its page for a path without one", async () => {
    const base = await start({ adminDir: admin });
    const page = await fetch(base + "/admin/");
    expect(page.status).toBe(200);
    expect(page.headers.get("content-type")).toBe("text/html; charset=utf-8");
    expect(page.headers.get("cache-control")).toBe("no-cache");
    expect(await page.text()).toContain("命理大师 管理后台");
    const js = await fetch(base + "/admin/main.dart.js");
    expect(js.headers.get("content-type")).toBe("text/javascript; charset=utf-8");
    expect(await js.text()).toBe("console.log('admin');");
    const wasm = await fetch(base + "/admin/canvaskit/canvaskit.wasm");
    expect(wasm.headers.get("content-type")).toBe("application/wasm");
    expect((await fetch(base + "/admin/users")).headers.get("content-type")).toContain("text/html");
    expect((await fetch(base + "/admin/missing.js")).status).toBe(404);
    // The API itself is unchanged.
    expect((await fetch(base + "/v1/health")).status).toBe(200);
  });

  it("sends /admin to /admin/, so the page's relative files resolve", async () => {
    const base = await start({ adminDir: admin });
    const res = await fetch(base + "/admin", { redirect: "manual" });
    expect(res.status).toBe(301);
    expect(res.headers.get("location")).toBe("/admin/");
  });

  it("never serves a file outside its folder", async () => {
    const base = await start({ adminDir: admin });
    for (const path of [
      "/admin/..%2f..%2fpackage.json",
      "/admin/..%5c..%5cpackage.json",
      "/admin/%2e%2e%2f" + "app-web/index.html",
    ]) {
      expect((await fetch(base + path)).status, path).toBe(404);
    }
  });

  it("without a built dashboard, /admin/ is no page: the API answers it as any path it doesn't know", async () => {
    const base = await start({});
    const res = await fetch(base + "/admin/");
    expect(res.status).toBeGreaterThanOrEqual(400);
    expect(res.headers.get("content-type")).toContain("application/problem+json");
    const other = await fetch(base + "/no-such-page/");
    expect(res.status).toBe(other.status);
  });

  it("in the public mode the app's folder doesn't take /admin/ from it", async () => {
    const base = await start({ adminDir: admin, staticDir: app });
    expect(await (await fetch(base + "/admin/")).text()).toContain("管理后台");
    const root = await (await fetch(base + "/")).text();
    expect(root).toContain("<title>命理大师</title>");
  });
});
