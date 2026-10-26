/**
 * Static files for the public test mode: the API server also serves the built
 * Flutter web app, so app and API share one https origin behind a tunnel.
 */
import { existsSync, readFileSync, statSync } from "node:fs";
import type { ServerResponse } from "node:http";
import { extname, join, resolve, sep } from "node:path";

const TYPES: Record<string, string> = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
  ".wasm": "application/wasm",
  ".ttf": "font/ttf",
  ".otf": "font/otf",
  ".woff2": "font/woff2",
  ".txt": "text/plain; charset=utf-8",
  ".map": "application/json; charset=utf-8",
  ".frag": "text/plain; charset=utf-8",
  ".bin": "application/octet-stream",
};

/**
 * Serves `urlPath` from `dir`. Paths without an extension fall back to index.html
 * (single-page app). Never serves outside `dir`. Every response is no-cache, so a
 * new build shows on the next open. Returns false when nothing was served.
 */
export function serveStatic(res: ServerResponse, dir: string, urlPath: string): boolean {
  const root = resolve(dir);
  let rel: string;
  try {
    rel = decodeURIComponent(urlPath);
  } catch {
    return false;
  }
  let file = resolve(join(root, rel));
  if (file !== root && !file.startsWith(root + sep)) return false;
  if (!existsSync(file) || statSync(file).isDirectory()) {
    if (extname(rel)) return false;
    file = join(root, "index.html");
    if (!existsSync(file)) return false;
  }
  res.writeHead(200, {
    "content-type": TYPES[extname(file).toLowerCase()] ?? "application/octet-stream",
    "cache-control": "no-cache",
    "x-content-type-options": "nosniff",
  });
  res.end(readFileSync(file));
  return true;
}
