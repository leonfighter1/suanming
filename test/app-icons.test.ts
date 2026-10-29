/**
 * The app icon (tech plan WP15.2): every file scripts/app-icons.ts plans is in the app, at its size,
 * opaque where the platform needs it, and the app is called 命理大师 under its icon.
 */
import { existsSync, readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { ICO_SIZES, iconPlan, iconSvg, TRIGRAMS } from "../scripts/app-icons.js";

/** A PNG's side and colour type, from its IHDR chunk (2 = RGB, 6 = RGBA). */
function pngInfo(b: Buffer) {
  expect(b.subarray(1, 4).toString("latin1")).toBe("PNG");
  return { width: b.readUInt32BE(16), height: b.readUInt32BE(20), colorType: b[25] };
}

describe("the app icon", () => {
  const plan = iconPlan();

  it("plans every platform: web, Android (legacy and adaptive), iOS and Windows", () => {
    const paths = plan.map((e) => e.path);
    for (const needle of [
      "app/web/favicon.png",
      "app/web/icons/Icon-maskable-512.png",
      "app/web/icons/apple-touch-icon.png",
      "mipmap-xxxhdpi/ic_launcher.png",
      "mipmap-xxxhdpi/ic_launcher_foreground.png",
      "mipmap-anydpi-v26/ic_launcher.xml",
      "AppIcon.appiconset/Icon-App-1024x1024@1x.png",
      "app/windows/runner/resources/app_icon.ico",
      "app/assets/icon/app_icon.png",
    ]) {
      expect(
        paths.some((p) => p.endsWith(needle)),
        needle,
      ).toBe(true);
    }
    // iOS: each file Contents.json names, once (19 entries share 15 files in Flutter's template).
    expect(paths.filter((p) => p.includes("AppIcon.appiconset")).length).toBe(15);
    expect(new Set(paths).size).toBe(paths.length);
  });

  it("each PNG is in the app at its size, and opaque where it must be", () => {
    for (const e of plan) {
      if (!("png" in e)) continue;
      expect(existsSync(e.path), e.path).toBe(true);
      const info = pngInfo(readFileSync(e.path));
      expect([info.width, info.height], e.path).toEqual([e.png.size, e.png.size]);
      // iOS and the apple-touch icon carry no alpha channel at all; the rest keep theirs.
      expect(info.colorType, e.path).toBe(e.opaque ? 2 : 6);
    }
  });

  it("the .ico holds each Windows size, smallest first", () => {
    const ico = readFileSync("app/windows/runner/resources/app_icon.ico");
    expect(ico.readUInt16LE(2)).toBe(1);
    expect(ico.readUInt16LE(4)).toBe(ICO_SIZES.length);
    ICO_SIZES.forEach((size, i) => {
      const e = 6 + 16 * i;
      expect(ico[e] === 0 ? 256 : ico[e]).toBe(size);
      const offset = ico.readUInt32LE(e + 12);
      const length = ico.readUInt32LE(e + 8);
      const png = ico.subarray(offset, offset + length);
      expect(pngInfo(png).width).toBe(size);
    });
  });

  it("the text files are as the script writes them", () => {
    for (const e of plan) {
      if ("text" in e) expect(readFileSync(e.path, "utf8"), e.path).toBe(e.text);
    }
    expect(iconSvg({ size: 64, shape: "rounded" })).toContain('width="64"');
  });

  it("draws the eight trigrams of the 先天 order, 乾 at the top and 坤 at the bottom", () => {
    expect(TRIGRAMS).toHaveLength(8);
    expect(TRIGRAMS[0]).toEqual([1, 1, 1]); // 乾
    expect(TRIGRAMS[4]).toEqual([0, 0, 0]); // 坤
    expect(TRIGRAMS[2]).toEqual([0, 1, 0]); // 坎, on the right (west)
    expect(TRIGRAMS[6]).toEqual([1, 0, 1]); // 离, on the left (east)
    // Opposite trigrams mirror each other line for line (乾/坤, 巽/震, 坎/离, 艮/兑).
    for (let i = 0; i < 4; i++) {
      expect(TRIGRAMS[i]!.map((l) => 1 - l)).toEqual([...TRIGRAMS[i + 4]!]);
    }
    // The small drawing (16–32 px) has no trigrams; the full one has all 24 lines (12 yang + 12 yin halves × 2).
    const small = iconSvg({ size: 32, shape: "rounded", small: true });
    expect(small).not.toContain("rotate(");
    const full = iconSvg({ size: 1024, shape: "rounded" });
    expect(full.match(/rotate\(/g)).toHaveLength(8);
    expect(full.match(/<rect x=/g)).toHaveLength(12 + 12 * 2 + 1);
  });

  it("the app is called 命理大师 under its icon on every platform", () => {
    expect(readFileSync("app/android/app/src/main/AndroidManifest.xml", "utf8")).toContain(
      'android:label="命理大师"',
    );
    expect(readFileSync("app/ios/Runner/Info.plist", "utf8")).toMatch(
      /<key>CFBundleDisplayName<\/key>\s*<string>命理大师<\/string>/,
    );
    const manifest = JSON.parse(readFileSync("app/web/manifest.json", "utf8")) as Record<
      string,
      unknown
    >;
    expect([manifest.name, manifest.short_name]).toEqual(["命理大师", "命理大师"]);
    expect(manifest.theme_color).toBe("#8A3B2E");
    const index = readFileSync("app/web/index.html", "utf8");
    expect(index).toContain('href="icons/apple-touch-icon.png"');
    // The Windows title, as UTF-16 code units of 命理大师, in a file that stays ASCII.
    const runner = readFileSync("app/windows/runner/main.cpp", "utf8");
    expect(runner).toContain("{0x547D, 0x7406, 0x5927, 0x5E08, 0}");
    expect(String.fromCodePoint(0x547d, 0x7406, 0x5927, 0x5e08)).toBe("命理大师");
    expect([...runner].every((ch) => ch.charCodeAt(0) < 128)).toBe(true);
  });
});
