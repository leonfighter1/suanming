/**
 * Term tips (tech plan WP4.2): a plain explanation of each 八字 term the app shows, one or two
 * sentences for a reader who has never studied 命理. Keyed by the protected term (i18n/terms.json,
 * 简体). 简体 and English are written here; 繁體 is built from the 简体 at sync (protected terms
 * first, then OpenCC cn → tw, then the reviewed fixes below, rule G18). Tendency language only,
 * as in the readings: 羊刃 is drive, never danger; 桃花 is charm, never an affair; 空亡 is a
 * quieter area, never loss.
 */
import OpenCC from "opencc-js";
import { normalizeTerms } from "./terms.js";

export const TERM_TIPS: Readonly<Record<string, { "zh-Hans": string; en: string }>> = {
  // The chart itself.
  天干: {
    "zh-Hans": "十个天干（甲乙丙丁戊己庚辛壬癸），各有五行和阴阳，写在每一柱的上面一行。",
    en: "The ten Heavenly Stems (甲 to 癸), each with an element and a yin or yang side: the top character of each pillar.",
  },
  地支: {
    "zh-Hans": "十二地支（子丑寅卯……亥），对应月份和时辰，也各有五行，写在每一柱的下面一行。",
    en: "The twelve Earthly Branches (子 to 亥), tied to the months and the hours, each with an element: the bottom character of each pillar.",
  },
  藏干: {
    "zh-Hans": "地支里含着的天干：一个地支含一到三个，主气最强。传统上用来看一柱更细的五行。",
    en: "The stems held inside a branch, one to three, the main one strongest. Tradition uses them for a pillar's finer elements.",
  },
  十神: {
    "zh-Hans":
      "以日主（你自己）为中心，按其他天干和它的生克关系分成十种角色，例如正印代表照顾你的人和学习。",
    en: "Ten roles, from how each stem relates to your Day Master (you): the Direct Resource, for example, stands for people who look after you, and for study.",
  },
  十二长生: {
    "zh-Hans":
      "日主在各个地支里的“生命阶段”，从长生、沐浴到墓、绝、胎、养，像一个循环，传统上用来看力量的起落。",
    en: "Your Day Master's twelve life stages across the branches, from Birth to Nurture: a cycle tradition reads for the rise and fall of strength.",
  },
  纳音: {
    "zh-Hans":
      "把六十个干支两两配成三十种五行意象（如海中金、炉中火），是传统的象征说法，不参与计分。",
    en: "The sixty stem-branch pairs grouped into thirty elemental images (such as Gold in the Sea): a traditional symbol, not part of any score.",
  },
  日主: {
    "zh-Hans": "你出生那天的天干，代表你自己；命盘的其他部分都围绕它来解读。",
    en: "The stem of your birth day, standing for you; the rest of the chart is read around it.",
  },
  月令: {
    "zh-Hans": "出生月份的地支，传统上最能决定五行旺衰的一柱。",
    en: "The branch of your birth month: the pillar tradition weighs most in judging strength.",
  },
  五行: {
    "zh-Hans": "木、火、土、金、水五种元素，彼此相生相克；命盘看它们的多少和平衡。",
    en: "Wood, Fire, Earth, Metal and Water, which feed and check one another; a chart is read for their balance.",
  },
  大运: {
    "zh-Hans": "每十年换一段的运势阶段，由月柱推出，看这十年的主旋律。",
    en: "Ten-year luck periods, worked out from the month pillar: the main theme of each decade.",
  },
  流年: {
    "zh-Hans": "每一年的干支，和你的命盘相互作用，看这一年的主题。",
    en: "Each year's stem and branch, working with your chart: the theme of that year.",
  },
  流月: {
    "zh-Hans": "一年中每个月的干支，从立春开始算，看当月的小主题。",
    en: "Each month's stem and branch, counted from 立春 (the start of spring): the small theme of that month.",
  },
  空亡: {
    "zh-Hans": "按日柱推出的两个“空”的地支，传统上指比较安静、不必用力的地方，不代表失去。",
    en: "Two branches left “empty” by your day pillar; tradition reads them as quieter areas that need less effort, never as loss.",
  },
  胎元: {
    "zh-Hans": "由月柱推出的“受孕之月”的干支，是传统的辅助参考。",
    en: "The stem and branch of the month of conception, worked out from the month pillar: a traditional extra reference.",
  },
  神煞: {
    "zh-Hans": "传统上附在某些干支组合上的标记，只是参考，不是吉凶判决。",
    en: "Traditional markers that come with certain stem-branch combinations: a reference, never a verdict of good or bad luck.",
  },
  // 十神.
  比肩: {
    "zh-Hans": "和日主同五行、同阴阳：同伴和兄弟姐妹，也代表自信与独立。",
    en: "Same element and side as you: peers and siblings, and self-reliance.",
  },
  劫财: {
    "zh-Hans": "和日主同五行、阴阳相反：竞争中的伙伴，代表行动力，也提醒分寸。",
    en: "Same element, opposite side: partners in competition; drive, with a reminder of balance.",
  },
  食神: {
    "zh-Hans": "日主所生、同阴阳：才华、享受和温和的表达。",
    en: "What you produce, same side: talent, enjoyment and gentle self-expression.",
  },
  伤官: {
    "zh-Hans": "日主所生、阴阳相反：创意和锋芒，敢说敢做，也提醒说话的方式。",
    en: "What you produce, opposite side: creativity and an edge, speaking up, with care for how you say it.",
  },
  偏财: {
    "zh-Hans": "日主所克、同阴阳：机会和流动的收入，也代表人缘和外向。",
    en: "What you control, same side: opportunities and changing income, and an outgoing nature.",
  },
  正财: {
    "zh-Hans": "日主所克、阴阳相反：稳定的收入和踏实的经营。",
    en: "What you control, opposite side: steady income and careful management.",
  },
  七杀: {
    "zh-Hans": "克日主、同阴阳：压力和挑战，也代表魄力和执行力。",
    en: "What checks you, same side: pressure and challenge, and also boldness in getting things done.",
  },
  正官: {
    "zh-Hans": "克日主、阴阳相反：规则、责任和事业上的认可。",
    en: "What checks you, opposite side: rules, responsibility and recognition at work.",
  },
  偏印: {
    "zh-Hans": "生日主、同阴阳：独特的学问、灵感和独处的思考。",
    en: "What supports you, same side: unusual learning, insight and time alone to think.",
  },
  正印: {
    "zh-Hans": "生日主、阴阳相反：照顾你的人、学习和证书。",
    en: "What supports you, opposite side: people who look after you, study and qualifications.",
  },
  // 十二长生.
  长生: { "zh-Hans": "力量刚开始生长，像新生。", en: "Strength beginning to grow, like birth." },
  沐浴: {
    "zh-Hans": "成长中尝试和变化，像孩子学步。",
    en: "Trying and changing while it grows, like a child learning to walk.",
  },
  冠带: { "zh-Hans": "渐渐成形，开始有模有样。", en: "Taking shape and coming into form." },
  临官: { "zh-Hans": "成熟独立，可以担当。", en: "Mature and independent, ready to take charge." },
  帝旺: {
    "zh-Hans": "力量最旺的时候，也提醒盛极而缓。",
    en: "Strength at its peak, with the reminder that a peak passes.",
  },
  衰: { "zh-Hans": "力量开始回落，宜稳健。", en: "Strength easing off: a time for steadiness." },
  病: {
    "zh-Hans": "力量较弱，宜休整（不是指身体生病）。",
    en: "Strength low: a time to rest (not illness).",
  },
  死: {
    "zh-Hans": "力量沉寂，像冬眠（不是指死亡）。",
    en: "Strength at rest, like hibernation (not death).",
  },
  墓: {
    "zh-Hans": "力量收藏起来，像入库保存。",
    en: "Strength stored away, like goods kept in a storehouse.",
  },
  绝: {
    "zh-Hans": "旧的结束、新的未起，处在转折点。",
    en: "The old has ended and the new has not begun: a turning point.",
  },
  胎: { "zh-Hans": "新的力量开始孕育。", en: "New strength being conceived." },
  养: {
    "zh-Hans": "新的力量被养育，等待出生。",
    en: "New strength being nurtured, waiting to be born.",
  },
  // 神煞.
  天乙贵人: {
    "zh-Hans": "传统上的贵人星，代表遇到帮助和提携的机会。",
    en: "The traditional star of helpful people: chances of support and good mentors.",
  },
  文昌: {
    "zh-Hans": "传统上主学习和文字的星，利于读书、考试和写作。",
    en: "The traditional star of learning and writing: good for study, exams and words.",
  },
  禄神: {
    "zh-Hans": "日主得“俸禄”的地支，代表踏实的收获和自给能力。",
    en: "Where your Day Master finds its “salary”: steady gains and self-sufficiency.",
  },
  羊刃: {
    "zh-Hans": "日主力量最集中的地支，代表冲劲和魄力，也提醒保持节制（不是危险）。",
    en: "Where your Day Master's force is most concentrated: drive and boldness, with a reminder to keep measure (never danger).",
  },
  桃花: {
    "zh-Hans": "代表魅力、人缘和社交上的轻松（不是指感情纠纷）。",
    en: "Charm, likeability and ease with people (never an affair).",
  },
  驿马: {
    "zh-Hans": "代表走动、出行和变动，适合开拓。",
    en: "Movement, travel and change: good for exploring.",
  },
  华盖: {
    "zh-Hans": "代表独处、思考、艺术和精神追求。",
    en: "Solitude, reflection, art and the life of the mind.",
  },
  // 旺衰 and 喜用 (the engine's simplified 扶抑 count).
  身强: {
    "zh-Hans": "按简化的扶抑计分，支持日主的五行占多数：自身力量充足。",
    en: "By a simplified support count, the elements that support your Day Master are the majority: plenty of strength of your own.",
  },
  身弱: {
    "zh-Hans": "按简化的扶抑计分，支持日主的五行占少数：适合借助外力和资源。",
    en: "By a simplified support count, the supporting elements are the minority: help and resources from outside suit you.",
  },
  中和: {
    "zh-Hans": "支持和消耗大致平衡，没有明显的偏向。",
    en: "Support and drain are about even: no strong lean either way.",
  },
  得令: {
    "zh-Hans": "日主在出生的月份当令：月令的主气和日主同类或生它，力量更足。",
    en: "Your Day Master is in season: the month's main element is its own or feeds it.",
  },
  通根: {
    "zh-Hans": "日主的五行在地支（藏干）里也有，像树有根，更稳。",
    en: "Your Day Master's element also appears in the branches, like a tree with roots: steadier.",
  },
  喜用: {
    "zh-Hans":
      "喜用是按简化扶抑法对你有利、宜多接触的五行；忌是宜少接触的五行。都是简化判断，不是定论。",
    en: "Favourable: the elements that help you most by the simplified support count; unfavourable: the ones to go easy on. A simplified judgement, not a final one.",
  },
  专旺候选: {
    "zh-Hans": "几乎全部五行都在支持日主，可能是特殊格局，宜请有经验的师傅细看。",
    en: "Almost everything supports your Day Master: possibly a special pattern, best looked at by an experienced practitioner.",
  },
  从格候选: {
    "zh-Hans": "几乎没有五行支持日主，可能是特殊格局，宜请有经验的师傅细看。",
    en: "Almost nothing supports your Day Master: possibly a special pattern, best looked at by an experienced practitioner.",
  },
  // 合冲刑害破.
  天干五合: {
    "zh-Hans": "两个天干相合（如甲己合土），传统上代表吸引和合作。",
    en: "Two stems combine (甲 with 己 into Earth): attraction and cooperation.",
  },
  天干相冲: {
    "zh-Hans": "两个天干相对（如甲庚），代表拉扯，需要协调。",
    en: "Two stems oppose (甲 and 庚): a pull either way that asks for coordination.",
  },
  六合: {
    "zh-Hans": "两个地支相合，代表亲近、默契和互助。",
    en: "Two branches combine: closeness, understanding and mutual help.",
  },
  六冲: {
    "zh-Hans": "两个地支相冲，代表变动和碰撞，也带来转变的契机。",
    en: "Two branches clash: change and friction, which also open the way to something new.",
  },
  三合: {
    "zh-Hans": "三个地支合成一局五行，代表强大的合力。",
    en: "Three branches form one element together: a strong combined force.",
  },
  半合: {
    "zh-Hans": "三合中的两个（含中间那个），合力较轻。",
    en: "Two of a three-branch combination, with its middle one: a lighter combined force.",
  },
  三会: {
    "zh-Hans": "同一季节的三个地支会成一方五行，力量集中。",
    en: "Three branches of one season gather into one element: concentrated strength.",
  },
  相刑: {
    "zh-Hans": "地支之间相刑，提醒处事的分寸和关系的磨合。",
    en: "Branches that punish each other: a reminder of measure, and of working relationships out.",
  },
  自刑: {
    "zh-Hans": "两个相同的地支相刑，提醒不要对自己太苛刻。",
    en: "Two of the same branch: a reminder not to be too hard on yourself.",
  },
  六害: {
    "zh-Hans": "两个地支相害，代表小摩擦和误会，宜多沟通。",
    en: "Two branches harm each other: small frictions and misunderstandings; talk things through.",
  },
  相破: {
    "zh-Hans": "两个地支相破，代表计划被打断，宜灵活调整。",
    en: "Two branches break each other: plans interrupted; stay flexible.",
  },
};

const toHant = OpenCC.Converter({ from: "cn", to: "tw" });

/**
 * Reviewed 2026-10-28 (v3.2.0) against 繁體 命理 usage, all 63 tips (G18): OpenCC turns the
 * branch 丑 into 醜 and 合 into 閤, leaves 藏干 as 藏幹 once, keeps 克 where 命理 writes 剋, and
 * keeps the 简体 “” where 繁體 quotes with 「」.
 */
export const TERM_TIP_HANT_FIXES: ReadonlyArray<readonly [string, string]> = [
  ["子醜寅卯", "子丑寅卯"],
  ["三閤", "三合"],
  ["藏幹", "藏干"],
  ["生克", "生剋"],
  ["所克", "所剋"],
  ["“", "「"],
  ["”", "」"],
];

/** A tip's 繁體: protected terms first (六冲 → 六沖), then OpenCC, then the reviewed fixes. */
export function tipHant(hans: string): string {
  const converted = toHant(normalizeTerms(hans, "zh-Hant").text);
  return TERM_TIP_HANT_FIXES.reduce((t, [from, to]) => t.split(from).join(to), converted);
}

/** All tips in the three scripts, as the app gets them (sync:app). */
export function termTips(): Record<string, Record<"zh-Hans" | "zh-Hant" | "en", string>> {
  return Object.fromEntries(
    Object.entries(TERM_TIPS).map(([k, v]) => [
      k,
      { "zh-Hans": v["zh-Hans"], "zh-Hant": tipHant(v["zh-Hans"]), en: v.en },
    ]),
  );
}
