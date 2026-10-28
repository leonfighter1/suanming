# Phase 3 Gate status (updated 2026-10-28, v5.2.0)

> The owner's documents: 「建议每个阶段结束前做一次 Gate 评审，评审材料即该阶段技术文档的“交付物清单”与“阶段门禁”勾选结果。Gate
> 未通过不进入下一阶段」. **Phase 3's gate has not passed**: three of its five items wait for the owner. So Phase 4
> (monitoring, the audit tool, A/B tests, the content back office) has not started. This page is the material for
> the owner's gate review. How the work was planned is in [tech-plan.md](tech-plan.md) (S6, S8, S9).

Payment and login have been out of scope since the owner's decision of 2026-10-27, so everything here that sells
or charges waits for that decision too.

## Deliverables (Phase 3 §6)

| #   | Deliverable                                 | Where                                                              | State                                                                                                                                                                                          |
| --- | ------------------------------------------- | ------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | 起名引擎 + 风水规则化模块                   | `src/engines/naming/`, `src/engines/fengshui/`                     | done. 风水 live since v4.4.0. 起名 (v4.5.0) is **off until the owner's 人工校订** of its draft 字义库 ([web-test.md](web-test.md), 起名)                                                       |
| 2   | Action Kit 三级产品交付管线                 | —                                                                  | **not started**: the tiers are products (payment out of scope); the audio tier needs a TTS vendor and its human review; the 大师包 needs teachers (Phase 2 真人)                               |
| 3   | `/link` 页面 + 邮件列表 + WhatsApp Business | share images: `src/share/` (tarot v4.2.0, 求籤 v4.3.0)             | **partly**. The Pick-a-Pile share image is done; its deep link waits for the stores (WP7.3). `/link`, the email list and WhatsApp wait for consent wording, a mail provider and a Meta account |
| 4   | Geo-Rule 精细化矩阵                         | `compliance/geo_rule_matrix.json` (0.5.0), `src/compliance/geo.ts` | done: TW / HK 求籤 first (v4.3.0), MY 风水 first (v4.4.0), ID content blocks and SG's English (v5.1.0); read on every request, so it updates without a release or a restart (v5.1.0)           |
| 5   | 英语全量界面 + 英语术语表扩展               | `app/lib/l10n/app_en.arb`, `i18n/terms.json` (1.6.0)               | done for the app and the glossary; the language is kept (v5.1.0). Open: an English model route (the owner chose `deepseek-v4-pro` for every agent) and the store listing (WP7.3)               |
| 6   | RAG 知识库扩展 + Fine-tuning 评估报告       | —                                                                  | **not started**: a vector store and an embeddings provider, with their cost; the evaluation spends on the real model (the owner's `IS_AI_MOCK` switch)                                         |

Interfaces (§3): ChartFact `system='naming'` and `system='fengshui'` are in (additive, migrations 004–005). The
tables `action_kits`, `action_kit_deliveries`, `email_subscribers`, `whatsapp_sessions` and the APIs
`/v1/action-kits`, `/v1/link/subscribe`, `/v1/webhooks/whatsapp` wait with their features.

## Tests (Phase 3 §4)

| Test       | Standard                                            | State                                                                                                                                                                                                                                   |
| ---------- | --------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 起名引擎   | 字义库覆盖率 100%；音律规则单测；繁体字形正确性抽检 | `test/naming.test.ts`: every character with forms, pinyin (pinyin-pro), element (radical rule) and meanings in three languages; each 音律 rule unit-tested; 简体 against OpenCC. The hand check of the 繁 forms is the owner's 人工校订 |
| 风水输出   | 100% `simplified_rule`；无吉凶断言句式              | `test/fengshui.test.ts`: every paragraph pinned to `simplified_rule`; F001 / F002 hold 吉凶 phrasing in 风水 only                                                                                                                       |
| Action Kit | 模板变量注入；音频审核流程                          | waits (deliverable 2)                                                                                                                                                                                                                   |
| 深链       | 分享图深链回落正确率 100%                           | waits for the stores (WP7.3)                                                                                                                                                                                                            |
| Geo-Rule   | 印尼/马来西亚/新加坡/台湾/香港规则路由              | `test/geo-regions.test.ts` (v5.1.0)                                                                                                                                                                                                     |
| 英语扩展   | 全量页面英语资源覆盖；术语表抽检                    | `app/test/locale_test.dart`: all three languages have the same strings, English has Chinese only in its listed terms; `test/glossary.test.ts`: every term in three languages, spot checks                                               |

## Gate checklist (Phase 3 §7)

- [x] **起名/风水输出全部通过 Compliance Guard 专项规则**: 风水 F001 / F002 (v4.4.0); 起名 N001–N003 (v5.2.0: a name
      deciding fate, a name as a cure or a charm, a 吉凶 verdict on a name). Each applies to its own method only
      (`METHOD_RULE_GROUPS`), with block and allow cases. Review is paused by the owner (2026-10-26): hits are
      recorded, and held once `MINGLI_REVIEW=on`.
- [ ] **Action Kit 音频审核流程跑通并留痕**: waits for the owner (deliverable 2).
- [ ] **WhatsApp 模板消息审核通过**: waits for the owner (a Meta account, templates submitted for approval).
- [x] **Geo-Rule 五地区规则路由测试通过**: `test/geo-regions.test.ts`. Indonesia is tested switched on; it ships
      unserved until the owner's sign-off.
- [ ] **Fine-tuning 评估结论写入 ADR**: waits for the owner (spend on the real model).

## What the owner decides

| Decision                                                  | What it opens                                   |
| --------------------------------------------------------- | ----------------------------------------------- |
| Review the 起名 字义库 (src/engines/naming/characters.ts) | 起名 for users (three steps in web-test.md)     |
| Sign off Indonesia                                        | `ID` served (two steps in web-test.md)          |
| Payment back in scope, and a TTS vendor                   | Action Kit (gate item 2)                        |
| A Meta account, consent wording, a mail provider          | WhatsApp, `/link`, the email list (gate item 3) |
| A budget for the real model                               | The fine-tuning evaluation and its ADR (item 5) |
| Whether a 八字 share image may show the four pillars      | WP7.2                                           |
| The app in the stores                                     | Deep links and the English listing (WP7.3)      |
