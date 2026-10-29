---
name: ai-reading
description: The owner's requirements for the AI readings of 命理大师 - what the model reads, what it writes, how a prompt is written and how the output is checked. Use when writing or changing an AI prompt, what a reading sends the model, a reading's output shape, a pipeline step, or a reading's page, export or email; above all 八字's AI reading. The finishing steps are in the dev-workflow skill.
---

# AI readings (命理大师): the owner's requirements

Set by the owner on 2026-10-29 (tech plan S18, v9.3.0). Where a requirement is quoted, the quote is the owner's.

## Two readings, kept apart

「一个是引擎解读，一个是ai解读」.

- **The engine reading** is deterministic: the chart page, the 命盘事实 card (labelled 引擎计算，非 AI), the trend chart
  and the 破除运势 plans, which rest on the engine's 喜用. No model writes any of it.
- **The AI reading** is the model's own analysis. On 八字 the button that asks for it says 用AI做更精确解读.
- The two may differ: the engine's 旺衰 is a simplified 扶抑 count, the AI judges the chart as a practitioner would.
  Don't make one quote the other.

## What the AI reads

「当给AI去运算时，只需要给出当前人的资料和具体背景和问题」, 「ai解读时尽量不采用引擎数据」.

- **The person:** `<user_context>` (name, residence, marital status, children, occupation, family, what they want to
  know) from the profile, `<user_question>` when they asked, `<today>`.
- **The 排盘, from the engine:** the pillars with 藏干, 十神, 十二长生 and 纳音; 日主, 月令, the five-element count;
  合冲刑害破, 神煞, 空亡, 胎元; every 大运 and 流年 with its years, 干支 and 虚岁. The model never reckons a 干支, a year
  or an age itself (models get them wrong: an early run called 2027 丙午), and the reading must match the chart on its
  page (CLAUDE.md rule 1).
- **Not the engine's judgements:** `strength` (its 扶抑 count, 得令, 喜用 and 忌), `wuxing_weighted` and `trend`.
  `readingInputs` builds the 八字 view with `baziView(…, { trend: false, judgements: false })`; 追问 reads the same.
- **Never:** the exact birth time or audit ids (`modelFacts`). A name is used only to address the reader.

## What the AI writes (八字: narrative_bazi@8)

- **Every section the page shows**, in its order: 五行, 性格, 事业财运, 婚姻感情, 大运流年, 健康. Each opens with a
  one-sentence summary, then 2–4 paragraphs.
- **A paragraph** is the term (术语: the facts it rests on, the tradition's way), then the text (评论): the conclusion,
  why, how it shows in their life, what to do.
- **No 比如 example** (「比如XXX 这样的例子可以不用做了」). The schema has no `example` field for 八字.
- **大运流年 is the most detailed** (「运势要尽量详实具体」): one paragraph per period in focus, by 干支, years and
  虚岁. Up to six paragraphs are kept; other sections keep four.
- **Said straight** (「不绕弯子直接说就行了」): each paragraph's first sentence is its point, with no stacked hedges.
  Direct is not fatalistic: a hard period is a warning with what to do about it.
- **Always a 总结** (「一定要给出总结 … 越详尽越好」), in nine parts, each 150–400 characters, written to the person
  by name:
  - `portrait`: who they are;
  - `past`: the past;
  - `present`: now;
  - `challenges`: what may go wrong;
  - `gains`: 得势与得失;
  - `future`: the years ahead;
  - `caution`: from when to take care, by year or 大运;
  - `momentum`: from when to push;
  - `coping`: what to do when trouble comes.

  The parts are `CONCLUSION_PARTS` in src/ai/types.ts, synced to the app as `conclusionParts`.

- **No 行动建议** (「行动建议可以不用做了」): `METHOD_PROMPTS.bazi` has no action prompt, and the pipeline skips that
  step for a method without one.
- **Other methods keep their format** (rule 8): 塔罗, 求签, 算卦, 风水 and 起名 still write 举例 and 行动建议. Change
  them only when the owner asks for that method.

## Writing a prompt well

「ai prompt要做好规范」.

- **One version per change.** Never edit a released text: write the next version. Pin its hash in
  test/method-prompts.test.ts. A version no new reading uses moves to `RETIRED_PROMPTS` with its pin, so a stored
  reading's prompt id still names its exact text.
- **Prefer a self-contained text** when the rules change, as narrative_bazi@8 is. Stacks of `swap()` hide what the
  model is told.
- **Say, in this order:**
  1. who the model is;
  2. what it gets (each tag and field);
  3. what it decides itself;
  4. what it writes (each field, length and order);
  5. how to write;
  6. grounding (`fact_refs`, `source_level`);
  7. precision (虚岁, 时辰, 今年 / 明年 from `<today>`).
- **The safety basics stay in every prompt, even while review is paused:**
  - no 注定 or 一定会;
  - no prediction of death, lifespan, divorce, bankruptcy, a disaster, an accident, an illness or a lawsuit;
  - no disease names or treatment;
  - no investment advice or amounts;
  - no fear or paywall;
  - no judging the reader.
- **Keep the system prompt static** (it is cached). Everything that changes per request goes in the user message.
- **The schema says what is required**, in the structured-outputs subset (type, enum, required,
  additionalProperties, items). Counts and lengths are checked after parsing, in pipeline.ts.

## The output must be complete

「回馈数据要完整符合用户需求」.

- **Checked by the pipeline:**
  - every section asked for is there;
  - every paragraph and every 总结 part cites an existing chart path. If one doesn't, the reading is sent back once;
    if it still doesn't, that part is left out and counted in `dropped_ungrounded`;
  - all nine 总结 parts are there, or the reading is sent back;
  - protected terms are normalised;
  - every text (term, text, summary, 总结) is scanned by the rule layer;
  - `checkFaithfulness` (干支 and years) reads the 总结 too.
- **Where the 总结 goes:**
  - the reading page: first in the AI part, after the engine's facts, with a 总结 chip in the jump list;
  - Word, PDF and Markdown exports;
  - the report email (src/export/report-doc.ts);
  - 追问's `<reading>`.

## Checking a change

- **Server tests:**
  - test/bazi-ai-reading.test.ts: what is read and written;
  - test/method-prompts.test.ts: the pins, and each method's own prompts;
  - test/plain-reading.test.ts: term and example.
- **App tests:** reading_page_test, report_ui_test, features_test (exports) and archive_test.
- **After the reading's shape changes,** run `npm run sync:app`: the app's fixtures come from the mock pipeline.
- **A real reading runs only on the owner's switch.** `IS_AI_MOCK` is the owner's and is never flipped by an agent.
  `npm run eval:ai -- --live` costs money. When a real reading exists, read it against the lists above: all nine parts,
  years named, no 比如, no stacks of hedges.
