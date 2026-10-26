# 八字 / 塔羅 technical verification (2026-10-26)

Reproduce: `npm run verify:bazi`, `npm run verify:tarot`, `npm run eval:ai -- --live`.
The first two are harness and CI gates.

## 八字: engine vs an independent oracle

The oracle (`test/oracle/bazi-oracle.ts`) shares no code with lunar-javascript.
It uses Swiss Ephemeris for 節, the sun and the equation of time; the JDN for the
日柱 (anchors 1900-01-01 甲戌 and 2000-01-01 戊午); and 五虎遁 / 五鼠遁.

| Set                                                               | Cases | Match | Boundary | Error |
| ----------------------------------------------------------------- | ----- | ----- | -------- | ----- |
| Random 1901–2099, 9 locations, 真太陽時 on/off, both 子時 schools | 5000  | 4999  | 1        | **0** |
| Edge: ±30 min of real 節 instants, 23:00–01:00                    | 2000  | 2000  | 0        | **0** |

The one boundary case: London 1924-01-04 05:05 with 真太陽時 is about 04:59.5, on
the 寅/卯 edge. The two equation-of-time formulas differ by under 0.1 min.

**Non-vacuity (mutation tests):** the comparison catches a one-hour time shift,
flipped 真太陽時, flipped gender (200 of 200 大運 directions) and a flipped 子時
school (every late-子 case).

## 塔羅: statistical battery, 100 000 draws per spread, α = 0.001

32 of 32 checks pass:

- every position uniform over 78 cards;
- reversal rate 50 % (49.94–50.06 %) and independent of the card;
- positions 1 → 2 follow sampling without replacement;
- consecutive draws independent;
- major/suit mix matches the deck;
- no repeated card in 100 000 Celtic Crosses;
- adjacent draw ids collide at the 1/78 chance rate.

**Non-vacuity:** a never-reversed draw, a 4 % bias toward one card, and repeated
cards are each caught.

## AI faithfulness (DeepSeek `deepseek-v4-pro`, live)

6 cases: 4 八字 (繁 / 简 / English / 農曆 + 時辰 input) and 2 塔羅 (three-card, Celtic Cross).

- 6 of 6 `passed`; 0 rule hits; model review passed for all.
- **0 faithfulness issues.** Every 干支, year–干支 pairing, card name and 正逆位
  claim in the text exists in the chart, and the zh-Hant text has no simplified
  protected terms.
- 89–154 s per report; about 121k tokens for all six.
- 時辰 case (`ai-eval-shichen-results.json`): the facts layer and the AI text both
  state the two-hour precision (「時辰為辰時（兩小時窗口），時柱訊息只作輔助…」).

Not automated: whether 十神 / 五行 reasoning is sound. That stays with the human
review of 100 zh-Hant and 100 zh-Hans outputs (Phase 1 gate).
