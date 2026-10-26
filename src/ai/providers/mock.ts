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
    const data: GuardOutput = { pass: true, violations: [] };
    return { kind: "ok", data, model, usage: USAGE };
  }
}
