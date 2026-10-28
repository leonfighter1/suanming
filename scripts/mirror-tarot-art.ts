/**
 * npm run mirror:tarot: fits the tarot card art from JingyaoPaint into app/assets/tarot
 * (see scripts/tarot-art.ts).
 *   npm run mirror:tarot                     # from JingyaoPaint's local_art/out/tarot
 *   npm run mirror:tarot -- D:\other\folder  # from another folder
 * The folder ends up matching the source: changed cards are rewritten, unchanged ones
 * left alone, and files that are no card of the deck removed. Run it again whenever the
 * art changes.
 */
import { existsSync, mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import sharp from "sharp";
import { DECK } from "../src/engines/tarot/deck.js";
import { ART_DIR, ART_SIZE, artFile, cardForFile, DEFAULT_SOURCE } from "./tarot-art.js";

const from = process.argv[2] ?? DEFAULT_SOURCE;
const cards = readdirSync(from)
  .filter((f) => f.endsWith(".png"))
  .flatMap((file) => {
    const found = cardForFile(file);
    if (!found) console.log(`skipped ${file}: not named like a card ("NN 名字 Name.png")`);
    return found ? [{ file, ...found }] : [];
  });
const missing = DECK.filter((c) => !cards.some((a) => a.card.id === c.id));
if (missing.length || cards.length !== DECK.length) {
  throw new Error(
    `${from}: expected one picture per card of the deck (${DECK.length}), found ${cards.length}` +
      (missing.length ? `; missing ${missing.map((c) => c.name.en).join(", ")}` : ""),
  );
}

mkdirSync(ART_DIR, { recursive: true });
let changed = 0;
for (const { file, card } of cards) {
  const source = sharp(join(from, file));
  const { width = 0, height = 0 } = await source.metadata();
  if (Math.abs(width / height - ART_SIZE.width / ART_SIZE.height) > 0.01)
    console.log(`note: ${file} is ${width}×${height}, not 7:12; cropped to the card's shape`);
  const webp = await source
    .resize(ART_SIZE.width, ART_SIZE.height, { fit: "cover", kernel: "lanczos3" })
    .removeAlpha() // the cards are opaque
    .webp({ quality: 85, effort: 6, smartSubsample: true })
    .toBuffer();
  const target = join(ART_DIR, artFile(card));
  if (existsSync(target) && readFileSync(target).equals(webp)) continue;
  writeFileSync(target, webp);
  console.log(`wrote app/assets/tarot/${artFile(card)} ← ${file}`);
  changed++;
}
const keep = new Set(DECK.map(artFile));
for (const f of readdirSync(ART_DIR).filter((f) => !keep.has(f))) {
  rmSync(join(ART_DIR, f));
  console.log(`removed app/assets/tarot/${f}`);
}
// The app labels a card with the deck's name; the art has its own painted on.
for (const { file, card, zh } of cards) {
  if (zh !== card.name["zh-Hans"])
    console.log(`note: ${file} reads ${zh}; the app calls it ${card.name["zh-Hans"]}`);
}
console.log(`${changed} of ${cards.length} cards changed`);
