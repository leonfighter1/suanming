/**
 * Deterministic offline provider for tests and the demo when no API key is set.
 * Produces schema-valid, grounded output from the request payload. Tests can
 * script exact responses per agent (consumed in order) to exercise retries,
 * blocks, refusals and review failures.
 */
import type { Locale } from "../terms.js";
import {
  TOPIC_LABELS,
  type ActionOutput,
  type AgentName,
  type GuardOutput,
  type LLMJsonRequest,
  type LLMJsonResult,
  type LLMProvider,
  type NarrativeOutput,
  type Topic,
} from "../types.js";

export type Scripted = LLMJsonResult | { kind: "ok"; data: unknown };

const USAGE = { input_tokens: 0, output_tokens: 0, cache_read_input_tokens: 0 };

const REFS: Record<Topic, string[]> = {
  wuxing: ["/day_master", "/month_command", "/wuxing_weighted"],
  personality: ["/day_master", "/pillars/day"],
  career_wealth: ["/pillars/month"],
  relationships: ["/pillars/day"],
  dayun_liunian: ["/dayun", "/liunian/0"],
  health: ["/wuxing_weighted"],
};

const TEXT: Record<Locale, Record<Topic, string>> = {
  "zh-Hant": {
    wuxing:
      "（示範）依命盤的日主、月令與加權五行分數，傳統上會從五行的偏旺與偏弱來看整體平衡。此分數為簡化計分。",
    personality: "（示範）傳統上認為日主的五行屬性會反映處事風格，可作為自我觀察的參考。",
    career_wealth: "（示範）月柱的十神常被用來談工作方式與合作傾向，僅供規劃時參考。",
    relationships: "（示範）日支在傳統上與親密關係的相處模式有關，可多留意溝通節奏。",
    dayun_liunian: "（示範）目前大運與今年流年的十神組合，可視為這段時間值得關注的主題。",
    health: "（示範）傳統五行說法會把作息與情緒平衡連結起來。以上不構成醫療建議，如有不適請就醫。",
  },
  "zh-Hans": {
    wuxing:
      "（示范）依命盘的日主、月令与加权五行分数，传统上会从五行的偏旺与偏弱来看整体平衡。此分数为简化计分。",
    personality: "（示范）传统上认为日主的五行属性会反映处事风格，可作为自我观察的参考。",
    career_wealth: "（示范）月柱的十神常被用来谈工作方式与合作倾向，仅供规划时参考。",
    relationships: "（示范）日支在传统上与亲密关系的相处模式有关，可多留意沟通节奏。",
    dayun_liunian: "（示范）目前大运与今年流年的十神组合，可视为这段时间值得关注的主题。",
    health: "（示范）传统五行说法会把作息与情绪平衡联系起来。以上不构成医疗建议，如有不适请就医。",
  },
  en: {
    wuxing:
      "(Demo) Using the Day Master, Month Command and weighted element scores, tradition looks at which elements are strong or weak. The score is simplified.",
    personality:
      "(Demo) Tradition links the Day Master's element to a person's working style; use it as a prompt for self-reflection.",
    career_wealth:
      "(Demo) The month pillar's Ten God is often read for working style and collaboration; treat it as one input to planning.",
    relationships:
      "(Demo) The day branch is traditionally linked to how you relate to a partner; notice your communication rhythm.",
    dayun_liunian:
      "(Demo) The current luck pillar and this year's pillar suggest themes worth paying attention to.",
    health:
      "(Demo) Traditional five-element thinking links rest and emotional balance. This is not medical advice; see a doctor if unwell.",
  },
};

const ACTION: Record<Locale, string> = {
  "zh-Hant": "（示範）本週花十分鐘寫下與「{t}」相關的一個觀察。",
  "zh-Hans": "（示范）本周花十分钟写下与“{t}”相关的一个观察。",
  en: "(Demo) Spend ten minutes this week noting one observation about {t}.",
};

const SUMMARY: Record<Locale, string> = {
  "zh-Hant": "（示範）這一項的重點：照自己的節奏慢慢來。",
  "zh-Hans": "（示范）这一项的重点：照自己的节奏慢慢来。",
  en: "(Demo) The main point here: go at your own pace.",
};

const TREND_NOTE: Record<Locale, string> = {
  "zh-Hant": "（示範）依此期十神與原局刑沖合給出的參考分。",
  "zh-Hans": "（示范）依此期十神与原局刑冲合给出的参考分。",
  en: "(Demo) Reference score from this period's Ten God and branch relations.",
};

const REMEDY: Record<
  Locale,
  { target: string; summary: string; period: string; steps: [string, string][]; basis: string }
> = {
  "zh-Hant": {
    target: "（示範）針對「{t}」分數最低的時期所作的調和方案。",
    summary: "（示範）傳統上認為可透過作息、顏色與環境安排，平衡此期偏弱的五行。",
    period: "（示範）分數最低的大運",
    steps: [
      ["（示範）調整作息", "（示範）每天固定時間起床，傳統上認為有助穩定節奏。"],
      ["（示範）善用顏色", "（示範）選擇家中已有、屬喜用五行的顏色衣物或擺設。"],
      ["（示範）整理書桌", "（示範）每週整理一次工作區，保持動線清爽。"],
      ["（示範）記錄觀察", "（示範）每週寫下一個與此項目相關的觀察。"],
    ],
    basis: "（示範）依日主與加權五行分數判斷偏弱的五行。",
  },
  "zh-Hans": {
    target: "（示范）针对“{t}”分数最低的时期所作的调和方案。",
    summary: "（示范）传统上认为可透过作息、颜色与环境安排，平衡此期偏弱的五行。",
    period: "（示范）分数最低的大运",
    steps: [
      ["（示范）调整作息", "（示范）每天固定时间起床，传统上认为有助稳定节奏。"],
      ["（示范）善用颜色", "（示范）选择家中已有、属喜用五行的颜色衣物或摆设。"],
      ["（示范）整理书桌", "（示范）每周整理一次工作区，保持动线清爽。"],
      ["（示范）记录观察", "（示范）每周写下一个与此项目相关的观察。"],
    ],
    basis: "（示范）依日主与加权五行分数判断偏弱的五行。",
  },
  en: {
    target: "(Demo) A balancing plan for the lowest-scoring periods of {t}.",
    summary:
      "(Demo) Tradition holds that routines, colours and surroundings can balance a weak element.",
    period: "(Demo) The lowest-scoring luck pillar",
    steps: [
      [
        "(Demo) Steady routine",
        "(Demo) Wake at the same time each day; tradition links this to steadiness.",
      ],
      [
        "(Demo) Use colour",
        "(Demo) Wear or display colours you already own that match the supportive element.",
      ],
      ["(Demo) Clear the desk", "(Demo) Tidy your work area once a week."],
      ["(Demo) Keep notes", "(Demo) Write down one observation about this area each week."],
    ],
    basis: "(Demo) Based on the Day Master and the weighted element scores.",
  },
};

function localeOf(req: LLMJsonRequest): Locale {
  const m = /Write in (Traditional|Simplified|English)/.exec(req.user);
  return m?.[1] === "Traditional" ? "zh-Hant" : m?.[1] === "Simplified" ? "zh-Hans" : "en";
}

export class MockProvider implements LLMProvider {
  readonly name = "mock";
  readonly calls: LLMJsonRequest[] = [];
  private readonly script: Partial<Record<AgentName, Scripted[]>>;

  constructor(script: Partial<Record<AgentName, Scripted[]>> = {}) {
    this.script = structuredClone(script);
  }

  async generateJson(req: LLMJsonRequest): Promise<LLMJsonResult> {
    this.calls.push(req);
    const next = this.script[req.agent]?.shift();
    if (next) return { model: `mock/${req.model}`, usage: USAGE, ...next } as LLMJsonResult;
    const locale = localeOf(req);
    const model = `mock/${req.model}`;

    if (req.agent === "narrative") {
      const p = req.payload as { topics: Topic[]; system: string };
      const data: NarrativeOutput = {
        sections: p.topics.map((topic) => ({
          topic,
          summary: SUMMARY[locale],
          paragraphs: [
            {
              text: TEXT[locale][topic],
              source_level:
                topic === "wuxing" || topic === "health" ? "simplified_rule" : "traditional_text",
              fact_refs:
                p.system === "bazi"
                  ? REFS[topic]
                  : p.system === "tarot"
                    ? ["/cards/0"]
                    : ["/bodies/0"],
            },
          ],
        })),
      };
      return { kind: "ok", data, model, usage: USAGE };
    }
    if (req.agent === "action") {
      const p = req.payload as { topics: Topic[] };
      const data: ActionOutput = {
        actions: p.topics.map((topic) => ({
          topic,
          text: ACTION[locale].replace("{t}", TOPIC_LABELS[topic][locale]),
          horizon: "this_week",
        })),
      };
      return { kind: "ok", data, model, usage: USAGE };
    }
    if (req.agent === "trend") {
      const p = req.payload as { topics: Topic[]; dayun: number[]; liunian: number[] };
      // Deterministic, varied scores in 35–79 so charts have shape.
      const scores = (seed: number) =>
        Object.fromEntries(p.topics.map((t, i) => [t, 35 + ((seed * 7 + i * 13) % 45)]));
      const data = {
        dayun: p.dayun.map((index) => ({ index, scores: scores(index), note: TREND_NOTE[locale] })),
        liunian: p.liunian.map((year) => ({
          year,
          scores: scores(year),
          note: TREND_NOTE[locale],
        })),
      };
      return { kind: "ok", data, model, usage: USAGE };
    }
    if (req.agent === "remedy") {
      const p = req.payload as { topic: Topic; system: string };
      const r = REMEDY[locale];
      const label = TOPIC_LABELS[p.topic][locale];
      const data = {
        target: r.target.replace("{t}", label),
        summary: r.summary,
        focus_periods: p.system === "bazi" ? [r.period] : [],
        steps: r.steps.map(([title, text], i) => ({
          title,
          text,
          horizon: i === 0 ? "this_week" : "ongoing",
        })),
        basis: r.basis,
        fact_refs: p.system === "bazi" ? ["/day_master", "/wuxing_weighted"] : ["/cards/0"],
      };
      return { kind: "ok", data, model, usage: USAGE };
    }
    const data: GuardOutput = { pass: true, violations: [] };
    return { kind: "ok", data, model, usage: USAGE };
  }
}
