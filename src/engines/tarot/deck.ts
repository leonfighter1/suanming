/**
 * Rider–Waite–Smith 78-card deck. RWS numbering: VIII = Strength, XI = Justice.
 * Display names here are defaults; the protected-term table (Phase 1
 * terms_zh-Hant.json) is the source of truth for UI copy. The Chinese names are
 * the ones painted on the card art (app/assets/tarot): 愚人, 皇后, 权杖一 …
 */
export const DECK_ID = "rws-78/v1";

export interface TarotCard {
  id: string;
  arcana: "major" | "minor";
  suit?: Suit;
  rank: number;
  name: { en: string; "zh-Hans": string; "zh-Hant": string };
}

export type Suit = "wands" | "cups" | "swords" | "pentacles";

const MAJORS: [string, string, string][] = [
  ["The Fool", "愚人", "愚人"],
  ["The Magician", "魔术师", "魔術師"],
  ["The High Priestess", "女祭司", "女祭司"],
  ["The Empress", "皇后", "皇后"],
  ["The Emperor", "皇帝", "皇帝"],
  ["The Hierophant", "教皇", "教皇"],
  ["The Lovers", "恋人", "戀人"],
  ["The Chariot", "战车", "戰車"],
  ["Strength", "力量", "力量"],
  ["The Hermit", "隐士", "隱士"],
  ["Wheel of Fortune", "命运之轮", "命運之輪"],
  ["Justice", "正义", "正義"],
  ["The Hanged Man", "倒吊人", "倒吊人"],
  ["Death", "死神", "死神"],
  ["Temperance", "节制", "節制"],
  ["The Devil", "恶魔", "惡魔"],
  ["The Tower", "高塔", "高塔"],
  ["The Star", "星星", "星星"],
  ["The Moon", "月亮", "月亮"],
  ["The Sun", "太阳", "太陽"],
  ["Judgement", "审判", "審判"],
  ["The World", "世界", "世界"],
];

const SUITS: Record<Suit, [string, string, string]> = {
  wands: ["Wands", "权杖", "權杖"],
  cups: ["Cups", "圣杯", "聖杯"],
  swords: ["Swords", "宝剑", "寶劍"],
  pentacles: ["Pentacles", "星币", "星幣"],
};

const RANKS: [string, string, string][] = [
  ["Ace", "一", "一"],
  ["Two", "二", "二"],
  ["Three", "三", "三"],
  ["Four", "四", "四"],
  ["Five", "五", "五"],
  ["Six", "六", "六"],
  ["Seven", "七", "七"],
  ["Eight", "八", "八"],
  ["Nine", "九", "九"],
  ["Ten", "十", "十"],
  ["Page", "侍从", "侍從"],
  ["Knight", "骑士", "騎士"],
  ["Queen", "王后", "王后"],
  ["King", "国王", "國王"],
];

const pad = (n: number) => String(n).padStart(2, "0");

export const DECK: readonly TarotCard[] = Object.freeze([
  ...MAJORS.map(([en, hans, hant], i) => ({
    id: `major_${pad(i)}`,
    arcana: "major" as const,
    rank: i,
    name: { en, "zh-Hans": hans, "zh-Hant": hant },
  })),
  ...(Object.keys(SUITS) as Suit[]).flatMap((suit) =>
    RANKS.map(([en, hans, hant], i) => ({
      id: `${suit}_${pad(i + 1)}`,
      arcana: "minor" as const,
      suit,
      rank: i + 1,
      name: {
        en: `${en} of ${SUITS[suit][0]}`,
        "zh-Hans": `${SUITS[suit][1]}${hans}`,
        "zh-Hant": `${SUITS[suit][2]}${hant}`,
      },
    })),
  ),
]);

/** Other names a card goes by (the deck's names before v1.1.2), so checks on readings still know them. */
export const NAME_ALIASES: Readonly<Record<string, readonly string[]>> = {
  major_00: ["愚者"],
  major_03: ["女皇"],
  ...Object.fromEntries(
    (Object.keys(SUITS) as Suit[]).map((s) => [
      `${s}_01`,
      [`${SUITS[s][1]}王牌`, `${SUITS[s][2]}王牌`],
    ]),
  ),
};

export const SPREADS = {
  single: ["focus"],
  three_card: ["past", "present", "future"],
  celtic_cross: [
    "present",
    "challenge",
    "foundation",
    "recent_past",
    "potential",
    "near_future",
    "self",
    "environment",
    "hopes_fears",
    "outcome",
  ],
} as const satisfies Record<string, readonly string[]>;

export type SpreadId = keyof typeof SPREADS;

/** Display names of spread positions. Single source for the server and the app (sync:app). */
export const POSITION_LABELS: Record<string, { en: string; "zh-Hans": string; "zh-Hant": string }> =
  {
    focus: { en: "Focus", "zh-Hans": "焦点", "zh-Hant": "焦點" },
    past: { en: "Past", "zh-Hans": "过去", "zh-Hant": "過去" },
    present: { en: "Present", "zh-Hans": "现在", "zh-Hant": "現在" },
    future: { en: "Future", "zh-Hans": "未来", "zh-Hant": "未來" },
    challenge: { en: "Challenge", "zh-Hans": "挑战", "zh-Hant": "挑戰" },
    foundation: { en: "Foundation", "zh-Hans": "根基", "zh-Hant": "根基" },
    recent_past: { en: "Recent past", "zh-Hans": "近期过去", "zh-Hant": "近期過去" },
    potential: { en: "Potential", "zh-Hans": "潜能", "zh-Hant": "潛能" },
    near_future: { en: "Near future", "zh-Hans": "近期未来", "zh-Hant": "近期未來" },
    self: { en: "Self", "zh-Hans": "自我", "zh-Hant": "自我" },
    environment: { en: "Environment", "zh-Hans": "环境", "zh-Hant": "環境" },
    hopes_fears: { en: "Hopes & fears", "zh-Hans": "希望与恐惧", "zh-Hant": "希望與恐懼" },
    outcome: { en: "Outcome", "zh-Hans": "结果", "zh-Hant": "結果" },
  };
