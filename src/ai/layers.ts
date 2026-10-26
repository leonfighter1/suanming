/**
 * The two report layers that are NOT model-generated:
 * - facts: a deterministic restatement of the ChartFact;
 * - expectation: fixed expectation-management copy plus the AI label
 *   (compliance/ai_disclosure_spec.md §3).
 */
import type { ChartFact } from "../chart-fact/index.js";
import { DECK, POSITION_LABELS } from "../engines/tarot/deck.js";
import { term, termChars, type Locale } from "./terms.js";

type Pillar = { gan: string; zhi: string };
interface BaziFacts {
  pillars: Record<"year" | "month" | "day" | "hour", Pillar>;
  lunar: {
    year_ganzhi: string;
    shengxiao: string;
    month: number;
    is_leap_month: boolean;
    month_name: string;
    day: number;
    day_name: string;
  };
  input_basis: {
    date: "gregorian" | "lunar";
    time: "exact" | "shichen";
    shichen?: string;
    shichen_after_correction?: string;
  };
  day_master: { gan: string; wuxing: string; yin_yang: string };
  month_command: { zhi: string; wuxing: string };
  wuxing_weighted: { scores: Record<string, number> };
  dayun: {
    direction: string;
    start_date: string;
    cycles: { ganzhi: string; start_year: number }[];
  };
  liunian: {
    year: number;
    ganzhi: string;
    shishen_gan: string;
    shishen_zhi: string;
    branch_relations: { pillar: string; type: string }[];
  }[];
}

const L = {
  "zh-Hant": {
    pillars: "四柱",
    dm: "日主",
    mc: "月令",
    wx: "五行（加權，簡化計分）",
    dy: "大運",
    start: "起運",
    current: "目前大運",
    since: "起",
    ly: "流年",
    pillarName: { year: "年支", month: "月支", day: "日支", hour: "時支" },
    with: "與",
    none: "與原局無六沖六合",
    sep: "；",
    sign: "星座",
  },
  "zh-Hans": {
    pillars: "四柱",
    dm: "日主",
    mc: "月令",
    wx: "五行（加权，简化计分）",
    dy: "大运",
    start: "起运",
    current: "目前大运",
    since: "起",
    ly: "流年",
    pillarName: { year: "年支", month: "月支", day: "日支", hour: "时支" },
    with: "与",
    none: "与原局无六冲六合",
    sep: "；",
    sign: "星座",
  },
  en: {
    pillars: "Four Pillars",
    dm: "Day Master",
    mc: "Month Command",
    wx: "Five Elements (weighted, simplified score)",
    dy: "Luck Pillars",
    start: "start",
    current: "Current luck pillar",
    since: "from",
    ly: "Year",
    pillarName: {
      year: "year branch",
      month: "month branch",
      day: "day branch",
      hour: "hour branch",
    },
    with: "with",
    none: "no clash or harmony with the natal chart",
    sep: "; ",
    sign: "sign",
  },
} as const;

const SIGN_ZH: Record<string, [string, string]> = {
  aries: ["白羊", "白羊"],
  taurus: ["金牛", "金牛"],
  gemini: ["雙子", "双子"],
  cancer: ["巨蟹", "巨蟹"],
  leo: ["獅子", "狮子"],
  virgo: ["處女", "处女"],
  libra: ["天秤", "天秤"],
  scorpio: ["天蠍", "天蝎"],
  sagittarius: ["射手", "射手"],
  capricorn: ["摩羯", "摩羯"],
  aquarius: ["水瓶", "水瓶"],
  pisces: ["雙魚", "双鱼"],
};
const BODY_ZH: Record<string, [string, string]> = {
  sun: ["太陽", "太阳"],
  moon: ["月亮", "月亮"],
  mercury: ["水星", "水星"],
  venus: ["金星", "金星"],
  mars: ["火星", "火星"],
  jupiter: ["木星", "木星"],
  saturn: ["土星", "土星"],
  uranus: ["天王星", "天王星"],
  neptune: ["海王星", "海王星"],
  pluto: ["冥王星", "冥王星"],
};
const zh = (pair: [string, string] | undefined, locale: Locale, en: string) =>
  locale === "en" || !pair ? en : locale === "zh-Hant" ? pair[0] : pair[1];

/** How the birth moment was entered — only when it's not the exact 公曆 default. */
function inputBasisLines(b: BaziFacts["input_basis"], locale: Locale): string[] {
  const out: string[] = [];
  const zh = (hant: string, hans: string, en: string) =>
    locale === "en" ? en : locale === "zh-Hant" ? hant : hans;
  const shi = (z: string) => `${z}${term("时", locale)}`;
  if (b.date === "lunar")
    out.push(
      zh(
        "出生日期：依農曆輸入",
        "出生日期：依农历输入",
        "Birth date: entered in the lunar calendar",
      ),
    );
  if (b.time === "shichen" && b.shichen) {
    const moved = b.shichen_after_correction && b.shichen_after_correction !== b.shichen;
    out.push(
      zh(
        `出生時間：依時辰輸入（${shi(b.shichen)}），時柱只精確到兩小時${moved ? `；經真太陽時校正後落在${shi(b.shichen_after_correction!)}` : ""}`,
        `出生时间：依时辰输入（${shi(b.shichen)}），时柱只精确到两小时${moved ? `；经真太阳时校正后落在${shi(b.shichen_after_correction!)}` : ""}`,
        `Birth time: entered as a two-hour period (${b.shichen}${moved ? `; true solar time moves it to ${b.shichen_after_correction}` : ""}), so the hour pillar is approximate`,
      ),
    );
  }
  return out;
}

export function factsLayer(chart: ChartFact, locale: Locale, nowYear: number): string[] {
  const t = L[locale];
  const tr = (k: string) => term(k, locale);
  if (chart.system === "bazi") {
    const f = chart.facts as unknown as BaziFacts;
    const p = f.pillars;
    const gz = (x: Pillar) => x.gan + x.zhi;
    const current = [...f.dayun.cycles].reverse().find((c) => c.start_year <= nowYear);
    const lu = f.lunar;
    const lunarLine =
      locale === "en"
        ? `Lunar date: month ${lu.is_leap_month ? `${lu.month} (leap)` : lu.month}, day ${lu.day}, ${lu.year_ganzhi} year (${tr(lu.shengxiao)})`
        : `${tr("农历")}：${lu.year_ganzhi}年${termChars(lu.month_name, locale)}${lu.day_name}（${tr("生肖")}${tr(lu.shengxiao)}）`;
    const lines = [
      `${t.pillars}：${[p.year, p.month, p.day, p.hour].map(gz).join(" ")}`,
      lunarLine,
      ...inputBasisLines(f.input_basis, locale),
      `${t.dm}：${f.day_master.gan}${tr(f.day_master.wuxing)}（${tr(f.day_master.yin_yang)}）${t.sep}${t.mc}：${f.month_command.zhi}${tr(f.month_command.wuxing)}`,
      `${t.wx}：${Object.entries(f.wuxing_weighted.scores)
        .map(([k, v]) => `${tr(k)} ${v}`)
        .join(" · ")}`,
      `${t.dy}：${tr(f.dayun.direction === "forward" ? "顺行" : "逆行")}${t.sep}${t.start} ${f.dayun.start_date}` +
        (current
          ? `${t.sep}${t.current} ${current.ganzhi}（${current.start_year} ${t.since}）`
          : ""),
    ];
    for (const y of f.liunian.slice(0, 3)) {
      const rel = y.branch_relations.length
        ? y.branch_relations
            .map(
              (r) => `${t.with}${t.pillarName[r.pillar as keyof typeof t.pillarName]}${tr(r.type)}`,
            )
            .join("、")
        : t.none;
      lines.push(
        `${t.ly} ${y.year} ${y.ganzhi}：${tr(y.shishen_gan)} / ${tr(y.shishen_zhi)}${t.sep}${rel}`,
      );
    }
    return locale === "en"
      ? lines.map((l) => l.replace(/：/g, ": ").replace(/（/g, " (").replace(/）/g, ")"))
      : lines;
  }
  if (chart.system === "tarot") {
    const f = chart.facts as {
      cards: { position_key: string; card_id: string; reversed: boolean }[];
    };
    return f.cards.map((c) => {
      const card = DECK.find((d) => d.id === c.card_id)!;
      const pos = POSITION_LABELS[c.position_key]?.[locale] ?? c.position_key;
      return `${pos}: ${card.name[locale]}${c.reversed ? ` (${tr("逆位")})` : ""}`;
    });
  }
  const f = chart.facts as { bodies: { body: string; sign: string; longitude: number }[] };
  return f.bodies
    .filter((b) => ["sun", "moon", "mercury", "venus", "mars"].includes(b.body))
    .map((b) => {
      const deg = `${Math.floor(b.longitude % 30)}°${String(Math.floor(((b.longitude % 30) % 1) * 60)).padStart(2, "0")}′`;
      return `${zh(BODY_ZH[b.body], locale, b.body)}: ${zh(SIGN_ZH[b.sign], locale, b.sign)} ${deg}`;
    });
}

const EXPECTATION: Record<Locale, { text: string; ai_label: string }> = {
  "zh-Hant": {
    text: "命理內容屬文化參考與自我反思，不是對未來的預測，也不構成醫療、財務、法律或心理專業意見。重要決定請諮詢相關專業人士。",
    ai_label: "本解讀由 AI 依據命盤資料生成，僅供參考與自我反思。",
  },
  "zh-Hans": {
    text: "命理内容属文化参考与自我反思，不是对未来的预测，也不构成医疗、财务、法律或心理专业意见。重要决定请咨询相关专业人士。",
    ai_label: "本解读由 AI 根据命盘数据生成，仅供参考与自我反思。",
  },
  en: {
    text: "This content is cultural reference for self-reflection. It is not a prediction of the future and not medical, financial, legal or psychological advice. Please consult a qualified professional for important decisions.",
    ai_label:
      "This interpretation was generated by AI from your chart data. It is for reflection only.",
  },
};

export function expectationLayer(locale: Locale, labelRequired: boolean) {
  return { ...EXPECTATION[locale], label_required: labelRequired };
}
