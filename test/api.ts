// The API for a server test file (S28 WP28.1; docs/refactor-plan.md F9): one home for what thirty files repeated.
import type { AddressInfo } from "node:net";
import { afterAll, beforeAll } from "vitest";
import { MockProvider } from "../src/ai/index.js";
import { createApiServer, type ApiOptions } from "../src/api/server.js";
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
