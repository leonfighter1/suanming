/**
 * Deterministic offline provider for tests and the demo when no API key is set.
 * Produces schema-valid, grounded output from the request payload. Tests can
 * script exact responses per agent (consumed in order) to exercise retries,
 * blocks, refusals and review failures.
 */
import type { Locale } from "../terms.js";
import {
  CONCLUSION_LABELS,
  CONCLUSION_PARTS,
  TOPIC_LABELS,
  type ActionOutput,
  type AgentName,
  type Conclusion,
  type ConclusionPart,
  type GuardOutput,
  type LLMJsonRequest,
  type LLMJsonResult,
  type LLMProvider,
  type NarrativeOutput,
  type Topic,
} from "../types.js";

export type Scripted = LLMJsonResult | { kind: "ok"; data: unknown };

/** The chart paths each part of the demo 总结 cites (八字, v9.3.0). */
const CONCLUSION_REFS: Record<ConclusionPart, string[]> = {
  portrait: ["/day_master", "/month_command"],
  past: ["/dayun/cycles/0"],
  present: ["/dayun/cycles/1"],
  challenges: ["/relations"],
  gains: ["/pillars/month"],
  future: ["/dayun/cycles/2"],
  caution: ["/liunian/1"],
  momentum: ["/liunian/2"],
  coping: ["/day_master"],
};

const CONCLUSION: Record<Locale, string> = {
  "zh-Hant": "（示範）{p}：這是總結的這一部分，真實解讀會依你的命盤詳細寫出。",
  "zh-Hans": "（示范）{p}：这是总结的这一部分，真实解读会依你的命盘详细写出。",
  en: "(Demo) {p}: this part of the summary. A real reading writes it out in detail from your chart.",
};

function demoConclusion(locale: Locale): Conclusion {
  return Object.fromEntries(
    CONCLUSION_PARTS.map((p) => [
      p,
      {
        text: CONCLUSION[locale].replace("{p}", CONCLUSION_LABELS[p][locale]),
        fact_refs: CONCLUSION_REFS[p],
      },
    ]),
  );
}

/** Whether the request's schema asks for a 总结 (八字's narrative_bazi@8). */
const asksConclusion = (req: LLMJsonRequest) =>
  ((req.schema as { required?: string[] }).required ?? []).includes("conclusion");

/**
 * A scripted 八字 narrative written before v9.3.0 has no 总结. When the request asks for one, the mock adds its demo
 * 总结, so the script's sections are still what the pipeline reads; a test that scripts `conclusion` gets its own.
 */
function withConclusion(req: LLMJsonRequest, s: Scripted): Scripted {
  if (req.agent !== "narrative" || s.kind !== "ok" || !asksConclusion(req)) return s;
  const data = s.data;
  if (!data || typeof data !== "object" || "conclusion" in data) return s;
  return { ...s, data: { ...data, conclusion: demoConclusion(localeOf(req)) } };
}

const USAGE = { input_tokens: 0, output_tokens: 0, cache_read_input_tokens: 0 };

const REFS: Record<Topic, string[]> = {
  // The AI reading's view has no wuxing_weighted since v9.3.0: the plain count stands in.
  wuxing: ["/day_master", "/month_command", "/wuxing_count"],
  personality: ["/day_master", "/pillars/day"],
  career_wealth: ["/pillars/month"],
  relationships: ["/pillars/day"],
  dayun_liunian: ["/dayun", "/liunian/0"],
  health: ["/wuxing_count"],
  // Tarot's sections cite cards (tarot_cards: one paragraph per card, see generateJson).
  tarot_cards: ["/cards/0"],
  tarot_synthesis: ["/cards/0"],
  tarot_advice: ["/cards/0"],
  // 求籤's sections cite the poem's lines (qiuqian_poem: one paragraph per couplet, see generateJson).
  qiuqian_poem: ["/lot/poem/0", "/lot/poem/1"],
  qiuqian_answer: ["/lot/poem/0"],
  qiuqian_advice: ["/lot/poem/3"],
  // 风水's sections cite the room's principles (every room has at least three).
  fengshui_layout: ["/principles/0"],
  fengshui_flow: ["/principles/1"],
  fengshui_advice: ["/principles/2"],
  // 起名's sections cite the candidates.
  naming_candidates: ["/candidates/0"],
  naming_advice: ["/candidates/0"],
  // 算卦's sections cite the texts the cast rests on (the main one is /focus/texts/0).
  liuyao_hexagram: ["/focus/texts/0", "/primary"],
  liuyao_answer: ["/focus/texts/0"],
  liuyao_advice: ["/focus/texts/0"],
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
    tarot_cards:
      "（示範）這張牌在這個位置上，傳統上被看作與問題相關的一個面向，可作為自我觀察的參考。",
    tarot_synthesis: "（示範）把幾張牌連起來看，傳統上可以讀成一段變化的過程，供你參考。",
    tarot_advice: "（示範）牌面傳統上提示可以先放慢腳步，整理想法後再做決定。",
    qiuqian_poem:
      "（示範）這兩句籤詩描繪的景象，傳統上被讀作一段心境的變化，可作為自我觀察的參考。",
    qiuqian_answer: "（示範）就你所問的事，這支籤傳統上提示先看清情勢，再一步步來。",
    qiuqian_advice: "（示範）籤詩傳統上提示可以放慢腳步，先做眼前做得到的事。",
    fengshui_layout: "（示範）這個房間的佈局可以從主要家具的位置看起，先讓坐臥的地方背後有靠。",
    fengshui_flow: "（示範）讓光線與空氣進得來、走道不被擋住，房間會更舒適。",
    fengshui_advice: "（示範）可以先從最容易的一步做起，例如整理門口或調整燈光。",
    naming_candidates: "（示範）這個名字的字義與聲調相配，五行也合所需，可作為參考。",
    naming_advice: "（示範）把名字連同姓氏念出聲、寫下來，再聽聽家人的意見。",
    liuyao_hexagram: "（示範）這一卦的重點在主要的那句卦爻辭：先看清它說的處境，再看動爻往哪裡變。",
    liuyao_answer: "（示範）就你所問的事，這一卦傾向先穩住、把眼前的事做好，時機成熟再往前。",
    liuyao_advice: "（示範）把要做的事拆成一小步，這週先做第一步，做完再看下一步。",
  },
  "zh-Hans": {
    wuxing:
      "（示范）依命盘的日主、月令与加权五行分数，传统上会从五行的偏旺与偏弱来看整体平衡。此分数为简化计分。",
    personality: "（示范）传统上认为日主的五行属性会反映处事风格，可作为自我观察的参考。",
    career_wealth: "（示范）月柱的十神常被用来谈工作方式与合作倾向，仅供规划时参考。",
    relationships: "（示范）日支在传统上与亲密关系的相处模式有关，可多留意沟通节奏。",
    dayun_liunian: "（示范）目前大运与今年流年的十神组合，可视为这段时间值得关注的主题。",
    health: "（示范）传统五行说法会把作息与情绪平衡联系起来。以上不构成医疗建议，如有不适请就医。",
    tarot_cards:
      "（示范）这张牌在这个位置上，传统上被看作与问题相关的一个面向，可作为自我观察的参考。",
    tarot_synthesis: "（示范）把几张牌连起来看，传统上可以读成一段变化的过程，供你参考。",
    tarot_advice: "（示范）牌面传统上提示可以先放慢脚步，整理想法后再做决定。",
    qiuqian_poem:
      "（示范）这两句签诗描绘的景象，传统上被读作一段心境的变化，可作为自我观察的参考。",
    qiuqian_answer: "（示范）就你所问的事，这支签传统上提示先看清情势，再一步步来。",
    qiuqian_advice: "（示范）签诗传统上提示可以放慢脚步，先做眼前做得到的事。",
    fengshui_layout: "（示范）这个房间的布局可以从主要家具的位置看起，先让坐卧的地方背后有靠。",
    fengshui_flow: "（示范）让光线与空气进得来、走道不被挡住，房间会更舒适。",
    fengshui_advice: "（示范）可以先从最容易的一步做起，例如整理门口或调整灯光。",
    naming_candidates: "（示范）这个名字的字义与声调相配，五行也合所需，可作为参考。",
    naming_advice: "（示范）把名字连同姓氏念出声、写下来，再听听家人的意见。",
    liuyao_hexagram: "（示范）这一卦的重点在主要的那句卦爻辞：先看清它说的处境，再看动爻往哪里变。",
    liuyao_answer: "（示范）就你所问的事，这一卦倾向先稳住、把眼前的事做好，时机成熟再往前。",
    liuyao_advice: "（示范）把要做的事拆成一小步，这周先做第一步，做完再看下一步。",
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
    tarot_cards:
      "(Demo) In this position the card is traditionally read as one side of the question; use it as a prompt for reflection.",
    tarot_synthesis:
      "(Demo) Read together, the cards traditionally tell a story of change; take it as one view to consider.",
    tarot_advice:
      "(Demo) The cards traditionally suggest slowing down and sorting your thoughts before deciding.",
    qiuqian_poem:
      "(Demo) These two lines traditionally picture a change of mood; take them as a prompt for reflection.",
    qiuqian_answer:
      "(Demo) For what you asked, the lot traditionally suggests seeing the situation clearly first, then going step by step.",
    qiuqian_advice:
      "(Demo) The poem traditionally suggests slowing down and starting with what you can do now.",
    fengshui_layout:
      "(Demo) Start with where the main furniture stands: give the places you sit and sleep a wall behind them.",
    fengshui_flow:
      "(Demo) Let light and air in and keep walkways clear, and the room becomes more comfortable.",
    fengshui_advice:
      "(Demo) Begin with the easiest step, such as clearing the doorway or adjusting the light.",
    naming_candidates:
      "(Demo) This name's meaning and sound go well together, and its elements serve the chart; take it as one option.",
    naming_advice:
      "(Demo) Say each name aloud with the surname, write it down, and ask the family what they think.",
    // 算卦 is read in Chinese only; the type wants an entry.
    liuyao_hexagram: "(Demo) The cast.",
    liuyao_answer: "(Demo) The answer.",
    liuyao_advice: "(Demo) The advice.",
  },
};

/** 术语 and 举例 (v6.2.0): every demo paragraph has both, so the app shows the reading's three parts. */
const TERM: Record<Locale, string> = {
  "zh-Hant": "（示範）本段依據：{t}",
  "zh-Hans": "（示范）本段依据：{t}",
  en: "(Demo) Basis: {t}",
};
const EXAMPLE: Record<Locale, string> = {
  "zh-Hant": "（示範）比如這週遇到一件小事時，你可以先停一下，再按自己的節奏處理。",
  "zh-Hans": "（示范）比如这周遇到一件小事时，你可以先停一下，再按自己的节奏处理。",
  en: "(Demo) For example, when something small comes up this week, pause first, then handle it at your own pace.",
};

/** 追问 (v7.0.0): one grounded paragraph in three parts, and two next questions. */
const FOLLOWUP: Record<
  Locale,
  { term: string; text: string; example: string; suggestions: string[] }
> = {
  "zh-Hant": {
    term: "（示範）本次解讀的依據",
    text: "（示範）就你追問的這一點，傳統上仍要回到這次的結果本身來看：照解讀裡說的節奏，一步一步來。",
    example: "（示範）比如這週先把最在意的一件事寫下來，再對照解讀想想下一步。",
    suggestions: ["（示範）這對我的工作意味著什麼？", "（示範）接下來一個月要留意什麼？"],
  },
  "zh-Hans": {
    term: "（示范）本次解读的依据",
    text: "（示范）就你追问的这一点，传统上仍要回到这次的结果本身来看：照解读里说的节奏，一步一步来。",
    example: "（示范）比如这周先把最在意的一件事写下来，再对照解读想想下一步。",
    suggestions: ["（示范）这对我的工作意味着什么？", "（示范）接下来一个月要留意什么？"],
  },
  en: {
    term: "(Demo) What this reading rests on",
    text: "(Demo) For what you asked, tradition goes back to this reading itself: take it step by step, at the pace the reading describes.",
    example:
      "(Demo) For example, write down the one thing you care about most this week, then reread the reading for the next step.",
    suggestions: [
      "(Demo) What does this mean for my work?",
      "(Demo) What should I watch for next month?",
    ],
  },
};

const ACTION: Record<Locale, string> = {
  "zh-Hant": "（示範）本週花十分鐘寫下與「{t}」相關的一個觀察。",
  "zh-Hans": "（示范）本周花十分钟写下与“{t}”相关的一个观察。",
  en: "(Demo) Spend ten minutes this week noting one observation about {t}.",
};

const LIFE_DEMO: Record<Locale, string> = {
  "zh-Hant": "（示範）傳統上認為這一點可作為自我觀察的參考。",
  "zh-Hans": "（示范）传统上认为这一点可以作为自我观察的参考。",
  en: "(Demo) Tradition offers this as a prompt for self-reflection.",
};
const LIFE_LABEL: Record<Locale, string> = { "zh-Hant": "平順", "zh-Hans": "平顺", en: "Steady" };

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
    if (next) {
      return {
        model: `mock/${req.model}`,
        usage: USAGE,
        ...withConclusion(req, next),
      } as LLMJsonResult;
    }
    const locale = localeOf(req);
    const model = `mock/${req.model}`;

    if (req.agent === "narrative") {
      const p = req.payload as { topics: Topic[]; system: string; cards?: number };
      // 八字 writes no 举例 and ends with a 总结 since narrative_bazi@8 (v9.3.0).
      const conclusion = asksConclusion(req);
      const paragraph = (topic: Topic, refs: string[]) => ({
        term: TERM[locale].replace("{t}", TOPIC_LABELS[topic][locale]),
        text: TEXT[locale][topic],
        ...(!conclusion && { example: EXAMPLE[locale] }),
        // 八字's 五行 and 健康 are the AI's own judgement since v9.3.0, no longer the engine's simplified score.
        source_level: (topic === "wuxing" || topic === "health"
          ? conclusion
            ? "derived"
            : "simplified_rule"
          : "traditional_text") as "simplified_rule" | "traditional_text" | "derived",
        fact_refs: refs,
      });
      const data: NarrativeOutput = {
        sections: p.topics.map((topic) => ({
          topic,
          summary: SUMMARY[locale],
          paragraphs:
            topic === "tarot_cards"
              ? // One paragraph per card, in dealing order, as narrative_tarot@2 asks.
                Array.from({ length: p.cards ?? 1 }, (_, i) => paragraph(topic, [`/cards/${i}`]))
              : topic === "qiuqian_poem"
                ? // One paragraph per couplet, as narrative_qiuqian@1 asks.
                  [
                    paragraph(topic, ["/lot/poem/0", "/lot/poem/1"]),
                    paragraph(topic, ["/lot/poem/2", "/lot/poem/3"]),
                  ]
                : [
                    paragraph(
                      topic,
                      p.system === "bazi" ||
                        p.system === "qiuqian" ||
                        p.system === "fengshui" ||
                        p.system === "naming" ||
                        p.system === "liuyao"
                        ? REFS[topic]
                        : p.system === "tarot"
                          ? ["/cards/0"]
                          : ["/bodies/0"],
                    ),
                  ],
        })),
        ...(conclusion && { conclusion: demoConclusion(locale) }),
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
    if (req.agent === "followup") {
      // The pipeline passes a path the reading itself cited, so the demo answer is grounded too.
      const p = req.payload as { refs: string[] };
      const f = FOLLOWUP[locale];
      const data = {
        in_scope: true,
        paragraphs: [
          {
            term: f.term,
            text: f.text,
            example: f.example,
            source_level: "derived",
            fact_refs: p.refs,
          },
        ],
        suggestions: f.suggestions,
      };
      return { kind: "ok", data, model, usage: USAGE };
    }
    if (req.agent === "life_methods") {
      const d = LIFE_DEMO[locale];
      const data = {
        yijing: {
          meaning: d,
          ming_yao: d,
          zhi_gua: d,
          stages: [1, 2, 3, 4, 5, 6].map((line) => ({ line, reading: d })),
        },
        meihua: { season: d, early: d, middle: d, late: d, conclusion: d },
        wuxing: { analysis: d, favorable: [d], unfavorable: [d], note: d },
        bazhai: { summary: d, daily: d },
        fact_refs: ["/benming/hexagram", "/meihua/ti", "/bazhai/kua"],
      };
      return { kind: "ok", data, model, usage: USAGE };
    }
    if (req.agent === "life_topics") {
      const p = req.payload as { dayun: number[] };
      const d = LIFE_DEMO[locale];
      const keys = [
        "personality",
        "career",
        "wealth",
        "relationships",
        "children",
        "parents",
        "health",
      ];
      const data = {
        topics: keys.map((key) => ({
          key,
          summary: d,
          points: [{ period: "", text: d }],
          fact_refs: ["/bazi/day_master"],
        })),
        stages: p.dayun.map((dayun_index) => ({
          dayun_index,
          label: LIFE_LABEL[locale],
          score: 40 + ((dayun_index * 17) % 41),
          focus: d,
        })),
        summary: { verdict: d, advice: [{ area: LIFE_LABEL[locale], text: d }], closing: d },
      };
      return { kind: "ok", data, model, usage: USAGE };
    }
    const data: GuardOutput = { pass: true, violations: [] };
    return { kind: "ok", data, model, usage: USAGE };
  }
}
