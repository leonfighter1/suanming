import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { BANNER_ART, BANNER_ART_SIZE } from "../scripts/banner-art.js";
import { webpSize } from "../scripts/tarot-art.js";

describe("the banners' art in app/assets/art (run `npm run mirror:banner` if this fails)", () => {
  it("is 命理罗盘 as a 1600×1600 WebP", () => {
    expect(webpSize(readFileSync(BANNER_ART))).toEqual(BANNER_ART_SIZE);
  });
});
