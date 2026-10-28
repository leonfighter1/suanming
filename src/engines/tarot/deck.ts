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
  // v2.8.0: 二选一 (five cards) and 关系牌阵 (six), in dealing order.
  two_paths: ["choice_now", "path_a", "path_b", "outcome_a", "outcome_b"],
  relationship: ["rel_you", "rel_them", "rel_bond", "rel_obstacle", "rel_help", "rel_direction"],
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
    choice_now: { en: "Where you stand", "zh-Hans": "现在的处境", "zh-Hant": "現在的處境" },
    path_a: { en: "Path A", "zh-Hans": "选择 A", "zh-Hant": "選擇 A" },
    path_b: { en: "Path B", "zh-Hans": "选择 B", "zh-Hant": "選擇 B" },
    outcome_a: { en: "Where A leads", "zh-Hans": "A 的结果", "zh-Hant": "A 的結果" },
    outcome_b: { en: "Where B leads", "zh-Hans": "B 的结果", "zh-Hant": "B 的結果" },
    rel_you: { en: "You", "zh-Hans": "你", "zh-Hant": "你" },
    rel_them: { en: "The other person", "zh-Hans": "对方", "zh-Hant": "對方" },
    rel_bond: { en: "The bond", "zh-Hans": "关系现状", "zh-Hant": "關係現狀" },
    rel_obstacle: { en: "What stands between", "zh-Hans": "阻碍", "zh-Hant": "阻礙" },
    rel_help: { en: "What helps", "zh-Hans": "助力", "zh-Hant": "助力" },
    rel_direction: { en: "Direction", "zh-Hans": "走向", "zh-Hant": "走向" },
  };

/**
 * What each position stands for in a classic reading (Celtic Cross after Rachel Pollack:
 * 1 centre, 2 across it, 3 below, 4 behind, 5 the crown, 6 ahead, 7–10 the staff).
 * Single source for the reading agent and the app (sync:app).
 */
export const POSITION_MEANINGS: Record<
  string,
  { en: string; "zh-Hans": string; "zh-Hant": string }
> = {
  focus: {
    en: "The heart of your question: the one card to reflect on.",
    "zh-Hans": "你所问之事的核心：这次最值得细想的一张牌。",
    "zh-Hant": "你所問之事的核心：這次最值得細想的一張牌。",
  },
  past: {
    en: "What led here: the background and experience behind the question.",
    "zh-Hans": "走到今天的背景和经历。",
    "zh-Hant": "走到今天的背景和經歷。",
  },
  present: {
    en: "Where things stand now: the heart of the matter.",
    "zh-Hans": "事情现在的状态，也是这件事的核心。",
    "zh-Hant": "事情現在的狀態，也是這件事的核心。",
  },
  future: {
    en: "Where things tend to go if nothing changes; not a fixed fate.",
    "zh-Hans": "照现在的方向，事情可能的走向（不是定数）。",
    "zh-Hant": "照現在的方向，事情可能的走向（不是定數）。",
  },
  challenge: {
    en: "What crosses the matter: the obstacle, or the force at work on it, which can also help.",
    "zh-Hans": "横在现状上的阻力，或正在起作用的力量，也可能是助力。",
    "zh-Hant": "橫在現狀上的阻力，或正在起作用的力量，也可能是助力。",
  },
  foundation: {
    en: "The root beneath the matter: what it rests on, often from further back.",
    "zh-Hans": "事情的根源和基础，往往来自更早以前。",
    "zh-Hant": "事情的根源和基礎，往往來自更早以前。",
  },
  recent_past: {
    en: "What is just passing: recent events whose influence is fading.",
    "zh-Hans": "刚刚过去、影响正在减弱的事。",
    "zh-Hant": "剛剛過去、影響正在減弱的事。",
  },
  potential: {
    en: "The crown: what you aim for, the best that can come of it.",
    "zh-Hans": "你心里追求的目标，事情可能达到的最好结果。",
    "zh-Hant": "你心裡追求的目標，事情可能達到的最好結果。",
  },
  near_future: {
    en: "What is likely to come next, in the weeks or months ahead.",
    "zh-Hans": "接下来几周到几个月可能出现的情况。",
    "zh-Hant": "接下來幾週到幾個月可能出現的情況。",
  },
  self: {
    en: "You: your attitude and how you stand in the matter.",
    "zh-Hans": "你自己的心态，以及你在这件事里的位置。",
    "zh-Hant": "你自己的心態，以及你在這件事裡的位置。",
  },
  environment: {
    en: "Around you: the people and circumstances that bear on it.",
    "zh-Hans": "身边的人和外部环境对这件事的影响。",
    "zh-Hant": "身邊的人和外部環境對這件事的影響。",
  },
  hopes_fears: {
    en: "What you hope for or fear; often the same thing.",
    "zh-Hans": "你期待或担心的事，两者常常是同一件事。",
    "zh-Hant": "你期待或擔心的事，兩者常常是同一件事。",
  },
  outcome: {
    en: "Where things tend to lead if they go on as they are; not a fixed fate.",
    "zh-Hans": "照目前的趋势，事情最可能的结局（不是定数）。",
    "zh-Hant": "照目前的趨勢，事情最可能的結局（不是定數）。",
  },
  // 二选一 (two paths, v2.8.0): the present at the bottom, each path rising to where it leads.
  choice_now: {
    en: "Where you stand as you choose: what weighs on the decision now.",
    "zh-Hans": "做选择时的处境：此刻影响这个决定的状况。",
    "zh-Hant": "做選擇時的處境：此刻影響這個決定的狀況。",
  },
  path_a: {
    en: "How things tend to unfold if you take the first path.",
    "zh-Hans": "走第一条路时，事情倾向如何发展。",
    "zh-Hant": "走第一條路時，事情傾向如何發展。",
  },
  path_b: {
    en: "How things tend to unfold if you take the second path.",
    "zh-Hans": "走第二条路时，事情倾向如何发展。",
    "zh-Hant": "走第二條路時，事情傾向如何發展。",
  },
  outcome_a: {
    en: "Where the first path tends to lead if nothing changes; not a fixed fate.",
    "zh-Hans": "若一切照旧，第一条路倾向带你去哪里（不是定数）。",
    "zh-Hant": "若一切照舊，第一條路傾向帶你去哪裡（不是定數）。",
  },
  outcome_b: {
    en: "Where the second path tends to lead if nothing changes; not a fixed fate.",
    "zh-Hans": "若一切照旧，第二条路倾向带你去哪里（不是定数）。",
    "zh-Hant": "若一切照舊，第二條路傾向帶你去哪裡（不是定數）。",
  },
  // 关系牌阵 (relationship, v2.8.0): you, the bond and the other person; what stands between
  // you, what helps, and where it is going.
  rel_you: {
    en: "You: how you feel and what you bring to the relationship.",
    "zh-Hans": "你：你在这段关系里的感受和付出。",
    "zh-Hant": "你：你在這段關係裡的感受和付出。",
  },
  rel_them: {
    en: "The other person, as the cards show their side: a tendency, never a fact about them.",
    "zh-Hans": "对方：牌面所见对方的一面（是一种倾向，不是对方的事实）。",
    "zh-Hant": "對方：牌面所見對方的一面（是一種傾向，不是對方的事實）。",
  },
  rel_bond: {
    en: "The bond: where the relationship stands now, what connects you.",
    "zh-Hans": "关系现状：这段关系目前的状态，把你们连在一起的东西。",
    "zh-Hant": "關係現狀：這段關係目前的狀態，把你們連在一起的東西。",
  },
  rel_obstacle: {
    en: "What stands between you: what makes things harder now.",
    "zh-Hans": "阻碍：此刻让关系变难的因素。",
    "zh-Hant": "阻礙：此刻讓關係變難的因素。",
  },
  rel_help: {
    en: "What helps: what you can lean on, or do, for the relationship.",
    "zh-Hans": "助力：可以借力、可以去做的事。",
    "zh-Hant": "助力：可以借力、可以去做的事。",
  },
  rel_direction: {
    en: "Where it is going if things go on as they are: a direction, never a fixed fate.",
    "zh-Hans": "走向：若一切照旧，关系倾向的方向（是方向，不是定数）。",
    "zh-Hant": "走向：若一切照舊，關係傾向的方向（是方向，不是定數）。",
  },
};
