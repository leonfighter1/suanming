/**
 * The font share images are set in (tech plan S7): a system dependency, as libvips is for sharp.
 * MINGLI_SHARE_FONT (a font file) and MINGLI_SHARE_FONT_FAMILY name it; otherwise the first one found
 * in the usual places. Noto Sans CJK (Linux: fonts-noto-cjk) has a TC face, used for 繁體 readers.
 */
import { existsSync } from "node:fs";
import type { Locale } from "../ai/terms.js";

export interface ShareFont {
  file: string;
  family: string;
  /** In a font collection (.ttc), the face's PostScript name: PDF documents (v8.0.0) embed that face. */
  face?: string;
}

const KNOWN: {
  file: string;
  family: (locale: Locale) => string;
  face?: (locale: Locale) => string;
}[] = [
  {
    file: "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
    family: (l) => (l === "zh-Hant" ? "Noto Sans CJK TC" : "Noto Sans CJK SC"),
    face: (l) => (l === "zh-Hant" ? "NotoSansCJKtc-Regular" : "NotoSansCJKsc-Regular"),
  },
  { file: "C:/Windows/Fonts/Noto Sans SC (TrueType).otf", family: () => "Noto Sans SC" },
  { file: "C:/Windows/Fonts/NotoSansSC-VF.ttf", family: () => "Noto Sans SC" },
  {
    file: "C:/Windows/Fonts/msyh.ttc",
    family: () => "Microsoft YaHei",
    face: () => "MicrosoftYaHei",
  },
  {
    file: "/System/Library/Fonts/PingFang.ttc",
    family: (l) => (l === "zh-Hant" ? "PingFang TC" : "PingFang SC"),
    face: (l) => (l === "zh-Hant" ? "PingFangTC-Regular" : "PingFangSC-Regular"),
  },
];

/** The font for a reader's script, or undefined when the server has none (the image can't be made). */
export function shareFont(
  locale: Locale,
  env: Record<string, string | undefined> = process.env,
): ShareFont | undefined {
  const file = env.MINGLI_SHARE_FONT?.trim();
  if (file) {
    if (!existsSync(file)) return undefined;
    const face = env.MINGLI_SHARE_FONT_FACE?.trim();
    return { file, family: env.MINGLI_SHARE_FONT_FAMILY?.trim() || "sans", ...(face && { face }) };
  }
  const known = KNOWN.find((k) => existsSync(k.file));
  return (
    known && {
      file: known.file,
      family: known.family(locale),
      ...(known.face && { face: known.face(locale) }),
    }
  );
}
