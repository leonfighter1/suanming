/**
 * The documents the server writes itself (tech plan WP15.4): a reading or a 一生运势报告 as mailed the moment it is
 * done, when no app is there to build one (测算完成后发到邮箱). They follow the app's documents (archive_actions.dart,
 * life_export.dart) as far as the stored report carries them: the same headings and labels, the reading in three
 * parts, the actions, the trend, the AI label and the disclaimer. The 一生运势报告's tables and figures, which the app
 * draws from the facts, stay in the app; the mail says where to find them.
 */
import type { LifeReport } from "../ai/life.js";
import type { Report } from "../ai/pipeline.js";
import type { Locale } from "../ai/terms.js";
import { TOPIC_LABELS, type Topic } from "../ai/types.js";
import type { Doc, DocBlock } from "./document.js";

type Script = "zh-Hans" | "zh-Hant";
/** The app reads in Chinese only (v5.4.0): an English report gets 简体 labels. */
const scriptOf = (l: Locale): Script => (l === "zh-Hant" ? "zh-Hant" : "zh-Hans");

/** The app's own words (app_zh.arb, app_zh_Hant.arb), so a mailed report reads like a downloaded one. */
const WORDS = {
  "zh-Hans": {
    methods: {
      bazi: "八字排盘",
      tarot: "塔罗",
      qiuqian: "求签",
      liuyao: "算卦",
      fengshui: "风水",
      naming: "起名",
      astrology: "星盘",
    } as Record<string, string>,
    chartOf: (n: string) => `${n} 的命盘`,
    life: "一生运势报告",
    lifeOf: (n: string) => `${n} 一生运势报告`,
    ai: "AI 解读",
    name: "姓名",
    city: "出生地",
    method: "类型",
    time: "时间",
    question: "所问",
    facts: "命盘事实 · 引擎计算，非 AI",
    interpretation: "解读 · AI 生成",
    actions: "行动建议 · AI 生成",
    trend: "运势走势",
    total: "总分",
    horizons: { this_week: "本周", this_month: "本月", this_year: "今年", ongoing: "持续" },
    lifeSubtitle: "易经本命卦　|　梅花易数　|　五行八卦",
    lifeNote:
      "说明：本报告依传统术数推演，仅供娱乐和玄学学习使用，不是科学预测。三种方法各自独立推演，最后再合看。",
    sec: [
      "一、易经本命卦",
      "二、梅花易数",
      "三、五行八卦",
      "四、分项运势",
      "五、人生阶段总览",
      "六、总评与建议",
    ],
    guaYi: "卦义：一生的底色",
    mingYao: "命爻",
    zhiGua: "之卦：人生归宿",
    sixLines: "六爻配人生阶段",
    season: "时令",
    early: "早年",
    middle: "中年",
    late: "晚年",
    conclusion: "梅花结论",
    favorable: "喜",
    unfavorable: "忌",
    bazhai: "八卦命卦（八宅）",
    daily: "日常宜用",
    ages: (from: number, to: number | null) => (to === null ? `${from}+ 岁` : `${from}–${to} 岁`),
    lifeTopics: {
      personality: "性格",
      career: "事业",
      wealth: "财运",
      relationships: "情感与婚姻",
      children: "家庭与子女",
      parents: "父母",
      health: "健康",
    } as Record<string, string>,
    figures: "卦图、六爻表和八宅方位图在 app 里看，也可以在“以往记录”里下载完整的 PDF。",
  },
  "zh-Hant": {
    methods: {
      bazi: "八字排盤",
      tarot: "塔羅",
      qiuqian: "求籤",
      liuyao: "算卦",
      fengshui: "風水",
      naming: "起名",
      astrology: "星盤",
    } as Record<string, string>,
    chartOf: (n: string) => `${n} 的命盤`,
    life: "一生運勢報告",
    lifeOf: (n: string) => `${n} 一生運勢報告`,
    ai: "AI 解讀",
    name: "姓名",
    city: "出生地",
    method: "類型",
    time: "時間",
    question: "所問",
    facts: "命盤事實 · 引擎計算，非 AI",
    interpretation: "解讀 · AI 生成",
    actions: "行動建議 · AI 生成",
    trend: "運勢走勢",
    total: "總分",
    horizons: { this_week: "本週", this_month: "本月", this_year: "今年", ongoing: "持續" },
    lifeSubtitle: "易經本命卦　|　梅花易數　|　五行八卦",
    lifeNote:
      "說明：本報告依傳統術數推演，僅供娛樂和玄學學習使用，不是科學預測。三種方法各自獨立推演，最後再合看。",
    sec: [
      "一、易經本命卦",
      "二、梅花易數",
      "三、五行八卦",
      "四、分項運勢",
      "五、人生階段總覽",
      "六、總評與建議",
    ],
    guaYi: "卦義：一生的底色",
    mingYao: "命爻",
    zhiGua: "之卦：人生歸宿",
    sixLines: "六爻配人生階段",
    season: "時令",
    early: "早年",
    middle: "中年",
    late: "晚年",
    conclusion: "梅花結論",
    favorable: "喜",
    unfavorable: "忌",
    bazhai: "八卦命卦（八宅）",
    daily: "日常宜用",
    ages: (from: number, to: number | null) => (to === null ? `${from}+ 歲` : `${from}–${to} 歲`),
    lifeTopics: {
      personality: "性格",
      career: "事業",
      wealth: "財運",
      relationships: "情感與婚姻",
      children: "家庭與子女",
      parents: "父母",
      health: "健康",
    } as Record<string, string>,
    figures: "卦圖、六爻表和八宅方位圖在 app 裡看，也可以在「以往紀錄」裡下載完整的 PDF。",
  },
};

/** Where an account's region keeps its clocks, for the time a report was made. */
const ZONES: Record<string, string> = {
  HK: "Asia/Hong_Kong",
  MO: "Asia/Macau",
  TW: "Asia/Taipei",
  SG: "Asia/Singapore",
  MY: "Asia/Kuala_Lumpur",
  CN: "Asia/Shanghai",
  ID: "Asia/Jakarta",
  US: "America/New_York",
  CA: "America/Toronto",
  AU: "Australia/Sydney",
  GB: "Europe/London",
};

/** 2026-10-29 09:30, in the region's time (as the app shows local time). */
export function localTime(iso: string, region: string): string {
  const parts = new Intl.DateTimeFormat("en-GB", {
    timeZone: ZONES[region] ?? "UTC",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  }).formatToParts(new Date(iso));
  const v = (t: string) => parts.find((p) => p.type === t)?.value ?? "";
  return `${v("year")}-${v("month")}-${v("day")} ${v("hour")}:${v("minute")}`;
}

export interface ReadingContext {
  system: string;
  locale: Locale;
  /** The account's region: its clock for the time. */
  region: string;
  created_at: string;
  person?: { name?: string; birthplace?: string };
  question?: string;
}

/** A reading's title, as the app's record title gives it. */
export function readingTitle(c: ReadingContext): string {
  const w = WORDS[scriptOf(c.locale)];
  const method = w.methods[c.system] ?? c.system;
  if (c.system === "bazi" && c.person?.name) return w.chartOf(c.person.name);
  return method;
}

/** A passed reading as the document its mail carries. */
export function readingDocument(report: Report, c: ReadingContext): Doc {
  const w = WORDS[scriptOf(c.locale)];
  const s = scriptOf(c.locale);
  const l = report.layers!;
  const at = localTime(c.created_at, c.region);
  const topic = (t: Topic) => TOPIC_LABELS[t][s];
  const blocks: DocBlock[] = [
    {
      type: "kv",
      rows: [
        ...(c.person?.name ? ([[w.name, c.person.name]] as [string, string][]) : []),
        ...(c.person?.birthplace ? ([[w.city, c.person.birthplace]] as [string, string][]) : []),
        [w.method, w.methods[c.system] ?? c.system],
        [w.time, at],
        ...(c.question ? ([[w.question, c.question]] as [string, string][]) : []),
      ],
    },
    { type: "h2", text: w.facts },
    ...l.facts.map((f): DocBlock => ({ type: "bullet", text: f })),
  ];
  if (l.trend) {
    blocks.push({ type: "h2", text: `${w.trend}（${w.total} ${l.trend.total}/100）` });
    for (const p of l.trend.dayun) {
      const label = `${p.start_age}–${p.end_age}`;
      blocks.push({ type: "bullet", text: `${label} ${p.ganzhi}：${p.overall} · ${p.note}` });
    }
    for (const p of l.trend.liunian) {
      blocks.push({ type: "bullet", text: `${p.year} ${p.ganzhi}：${p.overall} · ${p.note}` });
    }
    blocks.push({ type: "note", text: l.trend.method_note });
  }
  blocks.push({ type: "h2", text: w.interpretation });
  for (const section of l.interpretation) {
    blocks.push({ type: "h3", text: topic(section.topic) });
    if (section.summary) blocks.push({ type: "summary", text: section.summary });
    for (const p of section.paragraphs) {
      if (p.term) blocks.push({ type: "term", text: p.term });
      blocks.push({ type: "p", text: p.text });
      if (p.example) blocks.push({ type: "example", text: p.example });
    }
  }
  if (l.actions.length) {
    blocks.push({ type: "h2", text: w.actions });
    for (const a of l.actions) {
      blocks.push({
        type: "bullet",
        text: `${topic(a.topic)} · ${w.horizons[a.horizon]}：${a.text}`,
      });
    }
  }
  blocks.push(
    { type: "divider" },
    { type: "note", text: l.expectation.text },
    { type: "note", text: `${l.expectation.ai_label}（${report.ai_disclosure.model}）` },
  );
  return { title: readingTitle(c), subtitle: `${w.ai} · ${at}`, blocks };
}

/** A passed 一生运势报告 as the document its mail carries: every text of the report, without the figures. */
export function lifeDocument(
  life: LifeReport,
  c: Omit<ReadingContext, "system" | "question">,
): Doc {
  const w = WORDS[scriptOf(c.locale)];
  const l = life.layers!;
  const f = life.facts.benming;
  const m = l.methods;
  const name = c.person?.name;
  const at = localTime(c.created_at, c.region);
  const blocks: DocBlock[] = [
    {
      type: "kv",
      rows: [
        ...(name ? ([[w.name, name]] as [string, string][]) : []),
        ...(c.person?.birthplace ? ([[w.city, c.person.birthplace]] as [string, string][]) : []),
        [w.time, at],
      ],
    },
    { type: "note", text: w.lifeNote },
    // 一、易经本命卦
    { type: "h2", text: w.sec[0]! },
    { type: "h3", text: `${w.guaYi}（${f.hexagram.full_name}）` },
    { type: "quote", text: f.hexagram.gua_ci },
    { type: "p", text: m.yijing.meaning },
    { type: "h3", text: w.mingYao },
    { type: "quote", text: f.lines[f.moving_line - 1]?.text ?? "" },
    { type: "p", text: m.yijing.ming_yao },
    { type: "h3", text: `${w.zhiGua}（${f.changed.full_name}）` },
    { type: "quote", text: f.changed.gua_ci },
    { type: "p", text: m.yijing.zhi_gua },
    { type: "h3", text: w.sixLines },
    ...f.lines.map((x): DocBlock => {
      const reading = m.yijing.stages.find((s) => s.line === x.line)?.reading;
      const ages = w.ages(x.age_from, x.age_to);
      return {
        type: "bullet",
        text: `${x.text}${x.moving ? "★" : ""}（${ages}）${reading ? `——${reading}` : ""}`,
      };
    }),
    // 二、梅花易数
    { type: "h2", text: w.sec[1]! },
    { type: "bullet", text: `${w.season}：${m.meihua.season}` },
    { type: "bullet", text: `${w.early}：${m.meihua.early}` },
    { type: "bullet", text: `${w.middle}：${m.meihua.middle}` },
    { type: "bullet", text: `${w.late}：${m.meihua.late}` },
    { type: "summary", text: `${w.conclusion}：${m.meihua.conclusion}` },
    // 三、五行八卦
    { type: "h2", text: w.sec[2]! },
    { type: "p", text: m.wuxing.analysis },
    {
      type: "p",
      text: `${w.favorable}：${m.wuxing.favorable.join("、")}；${w.unfavorable}：${m.wuxing.unfavorable.join("、")}`,
    },
    { type: "h3", text: w.bazhai },
    { type: "p", text: m.bazhai.summary },
    { type: "p", text: `${w.daily}：${m.bazhai.daily}` },
    // 四、分项运势
    { type: "h2", text: w.sec[3]! },
  ];
  for (const t of l.topics) {
    blocks.push({ type: "h3", text: w.lifeTopics[t.key] ?? t.key });
    blocks.push({ type: "summary", text: t.summary });
    for (const p of t.points) {
      blocks.push({ type: "bullet", text: `${p.period ? `${p.period}：` : ""}${p.text}` });
    }
  }
  // 五、人生阶段总览
  blocks.push({ type: "h2", text: w.sec[4]! });
  for (const s of l.stages) {
    blocks.push({
      type: "bullet",
      text: `${w.ages(s.start_age, s.end_age)} · ${s.start_year}–${s.start_year + 9}（${s.ganzhi}） · ${s.label}（${s.score}）：${s.focus}`,
    });
  }
  // 六、总评与建议
  blocks.push({ type: "h2", text: w.sec[5]! }, { type: "p", text: l.summary.verdict });
  for (const a of l.summary.advice) blocks.push({ type: "bullet", text: `${a.area}：${a.text}` });
  blocks.push(
    { type: "summary", text: l.summary.closing },
    { type: "note", text: w.figures },
    { type: "divider" },
    { type: "note", text: l.expectation.text },
    { type: "note", text: `${l.expectation.ai_label}（${life.ai_disclosure.model}）` },
  );
  return { title: name ? w.lifeOf(name) : w.life, subtitle: w.lifeSubtitle, blocks };
}
