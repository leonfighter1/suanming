import { existsSync, readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { at, buildAppAssets, serialize } from "../scripts/app-assets.js";

describe("Flutter app assets are in sync with their server-side source", async () => {
  const assets = await buildAppAssets();
  it.each(Object.keys(assets))("%s (run `npm run sync:app` if this fails)", (p) => {
    expect(existsSync(at(p))).toBe(true);
    // Normalise CRLF so a Windows checkout doesn't read as drift.
    expect(readFileSync(at(p), "utf8").replace(/\r\n/g, "\n")).toBe(serialize(assets[p]));
  });
});
