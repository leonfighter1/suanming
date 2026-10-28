import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { DECK } from "../src/engines/tarot/deck.js";
import { ART_DIR, ART_SIZE, artFile, cardForFile, webpSize } from "../scripts/tarot-art.js";

describe("tarot card art in app/assets/tarot (run `npm run mirror:tarot` if this fails)", () => {
  it("has one picture per card of the deck and nothing else", () => {
    expect(readdirSync(ART_DIR).sort()).toEqual(DECK.map(artFile).sort());
  });

  it("every picture is a 700×1200 WebP, the card's 7:12", () => {
    for (const card of DECK) {
      expect(webpSize(readFileSync(join(ART_DIR, artFile(card)))), card.id).toEqual(ART_SIZE);
    }
  });

  it("reads the card from a JingyaoPaint file name by its place in the deck and English name", () => {
    expect(cardForFile("00 愚人 The Fool.png")?.card.id).toBe("major_00");
    expect(cardForFile("22 权杖一 Ace of Wands.png")).toMatchObject({
      card: { id: "wands_01" },
      zh: "权杖一",
    });
    expect(cardForFile("77 星币国王 King of Pentacles.png")?.card.id).toBe("pentacles_14");
    // RWS numbering: VIII is Strength, XI Justice.
    expect(() => cardForFile("08 正义 Justice.png")).toThrow(/Strength/);
    expect(() => cardForFile("78 牌背 Back.png")).toThrow(/missing/);
    expect(cardForFile("sheet.png")).toBeNull();
  });
});
