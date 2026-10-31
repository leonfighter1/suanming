/**
 * npm run mirror:banner: renders the banners' art from JingyaoPaint into app/assets/art (see scripts/banner-art.ts).
 *   npm run mirror:banner                    # from JingyaoPaint's local_art/out/fortune/luopan.svg
 *   npm run mirror:banner -- D:\other.svg    # from another file
 * The file is rewritten only when the picture changed. Run it again whenever the art changes.
 */
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname } from "node:path";
import sharp from "sharp";
import { BANNER_ART, BANNER_ART_SIZE, BANNER_SOURCE } from "./banner-art.js";

const from = process.argv[2] ?? BANNER_SOURCE;
const { width = 0, height = 0 } = await sharp(from).metadata();
if (width !== height) throw new Error(`${from} is ${width}×${height}: the banners' art is square`);
const { width: size } = BANNER_ART_SIZE;
// An SVG is drawn at 72 dpi: this density draws it at the art's size, so nothing is scaled after.
const webp = await sharp(from, { density: (72 * size) / width })
  .resize(size, size)
  .removeAlpha() // the drawing is opaque: its sky fills the square
  .webp({ quality: 80, effort: 6, smartSubsample: true })
  .toBuffer();
mkdirSync(dirname(BANNER_ART), { recursive: true });
if (existsSync(BANNER_ART) && readFileSync(BANNER_ART).equals(webp)) {
  console.log("app/assets/art/luopan.webp is up to date");
} else {
  writeFileSync(BANNER_ART, webp);
  console.log(
    `wrote app/assets/art/luopan.webp (${size}×${size}, ${Math.round(webp.length / 1024)} KB) ← ${from}`,
  );
}
