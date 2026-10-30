import type { AddressInfo } from "node:net";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { MockProvider } from "../src/ai/index.js";
import { createApiServer } from "../src/api/server.js";
import { DRAW_KEY, PEPPER } from "./helpers.js";

const mock = new MockProvider();
const api = createApiServer({
  secrets: { digestPepper: PEPPER, drawKey: DRAW_KEY },
  providers: { deepseek: mock, anthropic: mock },
  devMode: true,
  corsOrigins: ["https://leonfighter1.github.io"],
  log: () => {},
});
let base = "";
beforeAll(async () => {
  await new Promise<void>((r) => api.listen(0, "127.0.0.1", r));
  base = `http://127.0.0.1:${(api.address() as AddressInfo).port}`;
});
afterAll(() => new Promise<void>((r) => api.close(() => r())));

const preflight = (origin: string, extra: Record<string, string> = {}) =>
  fetch(base + "/v1/health", {
    method: "OPTIONS",
    headers: { origin, "access-control-request-method": "GET", ...extra },
  });

describe("CORS", () => {
  it("allows localhost in dev mode and the configured Pages origin", async () => {
    for (const o of ["http://127.0.0.1:5000", "https://leonfighter1.github.io"]) {
      const res = await preflight(o);
      expect(res.status).toBe(204);
      expect(res.headers.get("access-control-allow-origin")).toBe(o);
    }
  });

  it("answers Chrome's Private Network Access preflight from the https page", async () => {
    const res = await preflight("https://leonfighter1.github.io", {
      "access-control-request-private-network": "true",
    });
    expect(res.headers.get("access-control-allow-private-network")).toBe("true");
  });

  it("private-network origins only when LAN mode is on", async () => {
    // Off here (loopback server): a phone page at 192.168.x.x is refused.
    expect(
      (await preflight("http://192.168.1.20:5000")).headers.get("access-control-allow-origin"),
    ).toBeNull();

    const lan = createApiServer({
      secrets: { digestPepper: PEPPER, drawKey: DRAW_KEY },
      providers: { deepseek: mock, anthropic: mock },
      devMode: true,
      corsPrivateNetwork: true,
      devHeaders: false,
      log: () => {},
    });
    await new Promise<void>((r) => lan.listen(0, "127.0.0.1", r));
    const b = `http://127.0.0.1:${(lan.address() as AddressInfo).port}`;
    try {
      for (const o of ["http://192.168.1.20:5000", "http://10.0.0.7:5000", "http://172.20.1.2"]) {
        const res = await fetch(b + "/v1/health", { method: "OPTIONS", headers: { origin: o } });
        expect(res.headers.get("access-control-allow-origin")).toBe(o);
      }
      for (const o of ["http://172.32.0.1:5000", "http://8.8.8.8", "https://192.168.1.20"]) {
        const res = await fetch(b + "/v1/health", { method: "OPTIONS", headers: { origin: o } });
        expect(res.headers.get("access-control-allow-origin")).toBeNull();
      }
      // LAN mode turns off the X-Dev-User shortcut: other machines must sign in.
      const res = await fetch(b + "/v1/charts", {
        headers: { "x-dev-user": "u1", "x-dev-country": "HK" },
      });
      expect(res.status).toBe(401);
    } finally {
      await new Promise<void>((r) => lan.close(() => r()));
    }
  });

  it("lets a page from another origin read an export's file name (the 管理后台 in development)", async () => {
    const res = await fetch(base + "/v1/health", { headers: { origin: "http://localhost:5000" } });
    const exposed = res.headers.get("access-control-expose-headers")?.split(/,\s*/);
    expect(exposed).toContain("content-disposition");
    expect(exposed).toContain("x-ai-model");
  });

  it("does not allow other origins", async () => {
    const res = await fetch(base + "/v1/health", { headers: { origin: "https://evil.example" } });
    expect(res.headers.get("access-control-allow-origin")).toBeNull();
  });
});
