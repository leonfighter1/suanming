/**
 * Local demo server (Phase 0 engines + Phase 1 AI reports). Serves demo/index.html
 * and a JSON API over the shared demo handlers. Binds to 127.0.0.1 only; the
 * product API is src/api/server.ts.
 */
import { readFileSync } from "node:fs";
import { createServer, type Server } from "node:http";
import { loadTerms } from "../ai/index.js";
import { aiHeaders, HttpError, readJson, send } from "../http/util.js";
import {
  aiStatus,
  DemoInputError,
  DemoUpstreamError,
  listRegions,
  runAstro,
  runBazi,
  runGuard,
  runReport,
  runTarot,
} from "./handlers.js";

const PAGE = new URL("../../demo/index.html", import.meta.url);

const ROUTES: Record<string, (body: never) => unknown> = {
  "/api/bazi": runBazi,
  "/api/tarot": runTarot,
  "/api/astro": runAstro,
  "/api/guard": runGuard,
  "/api/report": runReport,
};

export function createDemoServer(): Server {
  return createServer(async (req, res) => {
    const path = new URL(req.url ?? "/", "http://localhost").pathname;
    try {
      if (req.method === "GET" && (path === "/" || path === "/index.html")) {
        // Read per request so edits to the page show up on refresh.
        return send(res, 200, readFileSync(PAGE, "utf8"), {}, "text/html; charset=utf-8");
      }
      if (req.method === "GET" && path === "/api/regions") return send(res, 200, listRegions());
      if (req.method === "GET" && path === "/api/ai-status") return send(res, 200, aiStatus());
      if (req.method === "GET" && path === "/api/terms") return send(res, 200, loadTerms());
      const handler = ROUTES[path];
      if (handler && req.method === "POST") {
        const result = (await handler((await readJson(req)) as never)) as {
          refused?: boolean;
          report?: { ai_disclosure: { model: string; prompt_version: string } };
        };
        return send(
          res,
          result?.refused ? 451 : 200,
          result,
          aiHeaders(result?.report?.ai_disclosure),
        );
      }
      return send(res, 404, { error: "not found" });
    } catch (e) {
      if (e instanceof HttpError) return send(res, e.status, { error: e.message });
      if (e instanceof DemoInputError) return send(res, 400, { error: e.message });
      if (e instanceof DemoUpstreamError) return send(res, 502, { error: e.message });
      console.error(e);
      return send(res, 500, { error: "internal error" });
    }
  });
}
