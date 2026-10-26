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

  it("does not allow other origins", async () => {
    const res = await fetch(base + "/v1/health", { headers: { origin: "https://evil.example" } });
    expect(res.headers.get("access-control-allow-origin")).toBeNull();
  });
});
