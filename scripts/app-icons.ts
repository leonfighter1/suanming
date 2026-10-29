/**
 * The app icon (tech plan WP15.2): a 太极 inside the 先天八卦 ring, gold on the app's 赭红 accent
 * (AppColors.accent, #8A3B2E). This module draws it as SVG and renders every size each platform
 * needs; scripts/build-icons.ts writes them (npm run build:icons). test/app-icons.test.ts checks the
 * files in the app. To change the icon, change it here and run the script: never edit the PNGs.
 */
import { readFileSync } from "node:fs";
import sharp from "sharp";

const GOLD_LIGHT = "#F6DE9C";
const GOLD_DEEP = "#C8973B";
const RED_LIGHT = "#AA5440";
const RED = "#8A3B2E";
const RED_DEEP = "#5C1F16";
const YIN = "#4A1810";

/**
 * 先天八卦, clockwise from the top: south is at the top and east on the left, so 乾 is at the top,
 * then 巽, 坎, 艮, 坤 (at the bottom), 震, 离 and 兑. Each trigram's lines run from the inside out
 * (its bottom line nearest the centre); 1 is a yang line.
 */
export const TRIGRAMS: readonly (readonly [number, number, number])[] = [
  [1, 1, 1], // 乾
  [0, 1, 1], // 巽
  [0, 1, 0], // 坎
  [0, 0, 1], // 艮
  [0, 0, 0], // 坤
  [1, 0, 0], // 震
  [1, 0, 1], // 离
  [1, 1, 0], // 兑
];

export interface IconOptions {
  /** Pixels per side. */
  size: number;
  /**
   * square: full bleed (iOS, maskable web icons); rounded: a rounded square on transparency;
   * foreground and background: the two layers of Android's adaptive icon.
   */
  shape: "square" | "rounded" | "foreground" | "background";
  /** For tiny sizes: the 太极 alone, larger. */
  small?: boolean;
  /** The drawing's scale inside the square, for the safe zones of maskable and adaptive icons. */
  scale?: number;
  /** Margin around a rounded square, in 1024ths (Android's legacy icons keep one). */
  inset?: number;
}

const C = 512;
const f = (n: number) => Number(n.toFixed(2)).toString();

/** The 太极: yang (gold) on the left with its head at the top, as 震 → 乾 grows on the left of the ring. */
function taiji(r: number, stroke: number) {
  const light =
    `M ${C} ${f(C - r)} A ${f(r)} ${f(r)} 0 0 0 ${C} ${f(C + r)} ` +
    `A ${f(r / 2)} ${f(r / 2)} 0 0 1 ${C} ${C} A ${f(r / 2)} ${f(r / 2)} 0 0 0 ${C} ${f(C - r)} Z`;
  const dot = r / 7;
  return [
    `<circle cx="${C}" cy="${C}" r="${f(r)}" fill="${YIN}"/>`,
    `<path d="${light}" fill="url(#gold)"/>`,
    `<circle cx="${C}" cy="${f(C - r / 2)}" r="${f(dot)}" fill="${YIN}"/>`,
    `<circle cx="${C}" cy="${f(C + r / 2)}" r="${f(dot)}" fill="url(#gold)"/>`,
    `<circle cx="${C}" cy="${C}" r="${f(r)}" fill="none" stroke="url(#gold)" stroke-width="${f(stroke)}"/>`,
  ].join("");
}

/** One trigram drawn at the top of the ring, then turned to its place. */
function trigram(lines: readonly number[], index: number) {
  const bars: string[] = [];
  const thick = 24;
  lines.forEach((yang, i) => {
    const r = 262 + i * 42;
    const len = r * 0.6;
    const y = C - r - thick / 2;
    if (yang) {
      bars.push(rect(C - len / 2, y, len, thick));
    } else {
      const gap = len * 0.2;
      const half = (len - gap) / 2;
      bars.push(rect(C - len / 2, y, half, thick), rect(C + gap / 2, y, half, thick));
    }
  });
  return `<g transform="rotate(${index * 45} ${C} ${C})">${bars.join("")}</g>`;
}

const rect = (x: number, y: number, w: number, h: number) =>
  `<rect x="${f(x)}" y="${f(y)}" width="${f(w)}" height="${f(h)}" rx="4" fill="url(#gold)"/>`;

/** The icon as an SVG document, at `size` pixels. */
export function iconSvg(o: IconOptions): string {
  const defs =
    `<defs>` +
    `<linearGradient id="gold" x1="0" y1="0" x2="1" y2="1">` +
    `<stop offset="0" stop-color="${GOLD_LIGHT}"/><stop offset="1" stop-color="${GOLD_DEEP}"/></linearGradient>` +
    `<radialGradient id="bg" cx="0.38" cy="0.32" r="0.8">` +
    `<stop offset="0" stop-color="${RED_LIGHT}"/><stop offset="0.5" stop-color="${RED}"/>` +
    `<stop offset="1" stop-color="${RED_DEEP}"/></radialGradient>` +
    `</defs>`;
  let ground = "";
  if (o.shape === "square" || o.shape === "background") {
    ground = `<rect width="1024" height="1024" fill="url(#bg)"/>`;
  } else if (o.shape === "rounded") {
    const inset = o.inset ?? 0;
    const side = 1024 - 2 * inset;
    // The corner of Apple's and Material's rounded squares: about 22% of the side.
    ground = `<rect x="${inset}" y="${inset}" width="${side}" height="${side}" rx="${f(side * 0.2237)}" fill="url(#bg)"/>`;
  }
  let art = "";
  if (o.shape !== "background") {
    art = o.small
      ? taiji(330, 28)
      : [
          taiji(196, 12),
          ...TRIGRAMS.map((t, i) => trigram(t, i)),
          `<circle cx="${C}" cy="${C}" r="404" fill="none" stroke="url(#gold)" stroke-width="10" opacity="0.85"/>`,
        ].join("");
    const scale = o.scale ?? 1;
    if (scale !== 1) {
      art = `<g transform="translate(${C} ${C}) scale(${scale}) translate(-${C} -${C})">${art}</g>`;
    }
  }
  return (
    `<svg xmlns="http://www.w3.org/2000/svg" width="${o.size}" height="${o.size}" viewBox="0 0 1024 1024">` +
    `${defs}${ground}${art}</svg>`
  );
}

/** One PNG, rendered at its size (never scaled from another), opaque where the platform needs it. */
export async function iconPng(o: IconOptions, opaque = false): Promise<Buffer> {
  const img = sharp(Buffer.from(iconSvg(o)));
  return (opaque ? img.flatten({ background: RED }).removeAlpha() : img).png().toBuffer();
}

/** A Windows .ico holding PNG images (Windows Vista and later read them). */
export function icoFile(pngs: { size: number; data: Buffer }[]): Buffer {
  const header = Buffer.alloc(6 + 16 * pngs.length);
  header.writeUInt16LE(0, 0);
  header.writeUInt16LE(1, 2); // 1 = icon
  header.writeUInt16LE(pngs.length, 4);
  let offset = header.length;
  pngs.forEach((p, i) => {
    const e = 6 + 16 * i;
    header.writeUInt8(p.size >= 256 ? 0 : p.size, e); // 0 means 256
    header.writeUInt8(p.size >= 256 ? 0 : p.size, e + 1);
    header.writeUInt8(0, e + 2); // no palette
    header.writeUInt8(0, e + 3);
    header.writeUInt16LE(1, e + 4); // colour planes
    header.writeUInt16LE(32, e + 6); // bits per pixel
    header.writeUInt32LE(p.data.length, e + 8);
    header.writeUInt32LE(offset, e + 12);
    offset += p.data.length;
  });
  return Buffer.concat([header, ...pngs.map((p) => p.data)]);
}

/** Android's density buckets: the legacy icon's side (48 dp) and the adaptive layers' (108 dp). */
export const ANDROID_DENSITIES = { mdpi: 1, hdpi: 1.5, xhdpi: 2, xxhdpi: 3, xxxhdpi: 4 } as const;

const ANDROID_RES = "app/android/app/src/main/res";
const IOS_SET = "app/ios/Runner/Assets.xcassets/AppIcon.appiconset";

/** Windows's icon sizes; up to 32 px the small drawing. */
export const ICO_SIZES = [16, 24, 32, 48, 64, 128, 256];

const ADAPTIVE_XML = `<?xml version="1.0" encoding="utf-8"?>
<!-- Made by npm run build:icons (scripts/app-icons.ts). -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
`;

/** The iOS set's files, from its Contents.json: side in points × scale. */
export function iosIcons(root = "."): { file: string; size: number }[] {
  const contents = JSON.parse(readFileSync(`${root}/${IOS_SET}/Contents.json`, "utf8")) as {
    images: { size: string; scale: string; filename?: string }[];
  };
  // iPhone and iPad share some files (19 entries, 15 files in Flutter's template): one each.
  const files = new Map<string, number>();
  for (const i of contents.images) {
    if (!i.filename) continue;
    const size = Math.round(Number(i.size.split("x")[0]) * Number(i.scale.replace("x", "")));
    files.set(`${IOS_SET}/${i.filename}`, size);
  }
  return [...files].map(([file, size]) => ({ file, size }));
}

/** One file of the plan: a PNG drawn at its size, an .ico of several, or text. */
export type IconEntry =
  | { path: string; png: IconOptions; opaque?: boolean }
  | { path: string; ico: number[] }
  | { path: string; text: string };

/** Every icon file of the app, by path from the repository root, and how each is made. */
export function iconPlan(root = "."): IconEntry[] {
  const plan: IconEntry[] = [
    // The source, for anyone who wants to look at or reuse the drawing.
    { path: "app/assets/icon/icon.svg", text: iconSvg({ size: 1024, shape: "rounded" }) },
    // In the app: the menu header (WP15.1).
    { path: "app/assets/icon/app_icon.png", png: { size: 256, shape: "rounded" } },
    // Web: the tab icon, the installed app (any, and maskable in its 80% safe circle), iOS's home screen.
    { path: "app/web/favicon.png", png: { size: 32, shape: "rounded", small: true } },
  ];
  for (const s of [192, 512]) {
    plan.push(
      { path: `app/web/icons/Icon-${s}.png`, png: { size: s, shape: "rounded" } },
      {
        path: `app/web/icons/Icon-maskable-${s}.png`,
        png: { size: s, shape: "square", scale: 0.9 },
      },
    );
  }
  plan.push({
    path: "app/web/icons/apple-touch-icon.png",
    png: { size: 180, shape: "square" },
    opaque: true,
  });
  // Android: the legacy icon, and the adaptive one (its drawing inside the 66 dp safe zone).
  for (const [bucket, k] of Object.entries(ANDROID_DENSITIES)) {
    const dir = `${ANDROID_RES}/mipmap-${bucket}`;
    plan.push(
      { path: `${dir}/ic_launcher.png`, png: { size: 48 * k, shape: "rounded", inset: 40 } },
      {
        path: `${dir}/ic_launcher_foreground.png`,
        png: { size: 108 * k, shape: "foreground", scale: 0.72 },
      },
      { path: `${dir}/ic_launcher_background.png`, png: { size: 108 * k, shape: "background" } },
    );
  }
  plan.push({ path: `${ANDROID_RES}/mipmap-anydpi-v26/ic_launcher.xml`, text: ADAPTIVE_XML });
  // iOS: every size its set lists, opaque (Apple refuses an icon with transparency).
  for (const { file, size } of iosIcons(root)) {
    plan.push({ path: file, png: { size, shape: "square" }, opaque: true });
  }
  plan.push({ path: "app/windows/runner/resources/app_icon.ico", ico: ICO_SIZES });
  return plan;
}

/** The plan's files, rendered. */
export async function buildIcons(root = "."): Promise<Map<string, Buffer>> {
  const out = new Map<string, Buffer>();
  for (const e of iconPlan(root)) {
    if ("text" in e) {
      out.set(e.path, Buffer.from(e.text));
    } else if ("png" in e) {
      out.set(e.path, await iconPng(e.png, e.opaque));
    } else {
      const pngs: { size: number; data: Buffer }[] = [];
      for (const s of e.ico) {
        pngs.push({ size: s, data: await iconPng({ size: s, shape: "rounded", small: s <= 32 }) });
      }
      out.set(e.path, icoFile(pngs));
    }
  }
  return out;
}
