/**
 * The banners' art (owner, 2026-10-30: 「Update the banner background using this … luopan.svg for all pages」): 命理罗盘,
 * drawn in the JingyaoPaint project and rendered once into the app.
 *
 *   app/assets/art/luopan.webp  ← JingyaoPaint local_art/out/fortune/luopan.svg
 *
 * The SVG is 1200 units square and 1.4 MB: 4625 paths, their glows drawn by 245 blur filters, more than the app should
 * parse on every start. `npm run mirror:banner` renders it at BANNER_ART_SIZE, enough for the widest banner (the 1620
 * container) at a pixel a point, as a WebP of about 260 KB. This module only names things: test/banner-art.test.ts
 * uses it without the image library.
 */
import { fileURLToPath } from "node:url";

export const BANNER_ART = fileURLToPath(new URL("../app/assets/art/luopan.webp", import.meta.url));
/** Where JingyaoPaint writes the drawing (another file: npm run mirror:banner -- <file>). */
export const BANNER_SOURCE = "C:\\AIProjects\\JingyaoPaint\\local_art\\out\\fortune\\luopan.svg";
export const BANNER_ART_SIZE = { width: 1600, height: 1600 } as const;
