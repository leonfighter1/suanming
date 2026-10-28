/**
 * The tarot card art: one picture per card of the deck, fitted to the app's card.
 *
 *   app/assets/tarot/<card id>.webp  ← JingyaoPaint local_art/out/tarot/"NN 名字 Name.png"
 *
 * The cards are painted by code in the JingyaoPaint project (local_art/tarot, kept on
 * that computer only) at 700×1200 and exported at 1400×2400, 2.5 MB each. The app shows
 * a card 104 pt wide in the same 7:12 shape, so 350×600 covers a 3× screen; WebP keeps
 * one at about 25 KB. `npm run mirror:tarot` writes the folder; this module only names
 * and checks things (test/tarot-art.test.ts uses it without the image library).
 */
import { fileURLToPath } from "node:url";
import { DECK, type TarotCard } from "../src/engines/tarot/deck.js";

export const ART_DIR = fileURLToPath(new URL("../app/assets/tarot/", import.meta.url));
/** Where JingyaoPaint writes the cards (another folder: npm run mirror:tarot -- <folder>). */
export const DEFAULT_SOURCE = "C:\\AIProjects\\JingyaoPaint\\local_art\\out\\tarot";
export const ART_SIZE = { width: 350, height: 600 } as const;

export const artFile = (card: TarotCard) => `${card.id}.webp`;

/**
 * "00 愚人 The Fool.png" → the card it shows: NN is its place in the deck, checked
 * against the English name. Null for a file that isn't named like a card.
 */
export function cardForFile(file: string): { card: TarotCard; zh: string } | null {
  const [, nn, zh, en] = /^(\d{2}) (\S+) (.+)\.png$/u.exec(file) ?? [];
  if (nn === undefined || zh === undefined || en === undefined) return null;
  const card = DECK[Number(nn)];
  if (card?.name.en.toLowerCase() !== en.toLowerCase())
    throw new Error(`${file}: card ${nn} of the deck is ${card?.name.en ?? "missing"}`);
  return { card, zh };
}

/** Width and height of a lossy WebP (the "VP8 " frame header), or null for anything else. */
export function webpSize(buf: Buffer): { width: number; height: number } | null {
  const lossy =
    buf.toString("latin1", 0, 4) === "RIFF" &&
    buf.toString("latin1", 8, 16) === "WEBPVP8 " &&
    buf.readUIntBE(23, 3) === 0x9d012a;
  if (!lossy) return null;
  return { width: buf.readUInt16LE(26) & 0x3fff, height: buf.readUInt16LE(28) & 0x3fff };
}
