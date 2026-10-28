# 周易: the text of the 64 hexagrams (2026-10-28)

算卦 (tech plan WP10) shows the 卦辭 and 爻辭 of every cast, and the 一生运势 report quotes the 卦辭 and gives the
model the 大象. All of it comes from `data/yijing/hexagrams.json`, built by `npm run build:yijing`
(`scripts/build-yijing.ts`) from one digital source. This page records how the text was checked (G4: never trust
one source; rule 39: read the primary source, since modern copies can share an error) and what was corrected.

Reproduce: `npm run check:zhouyi` (`scripts/check-zhouyi.ts`). It needs the network on its first run (the pages
are cached in `.cache/zhouyi/`), so it is not a harness gate. `test/yijing.test.ts` pins the corrected text.

## Sources

|     | Source                                                                                                                                                                                                        | What it is                                                                                                                                                                                                         |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| A   | `@freizl/yijing` 2.1.0, zh-TW (MIT)                                                                                                                                                                           | Our source. It names no edition, and was converted from 简体 in places (兇 for 凶, 鹹 for 咸).                                                                                                                     |
| B   | 維基文庫《周易》 (`zh.wikisource.org/wiki/周易/乾` …, raw wikitext)                                                                                                                                           | A proofread 繁體 text. It marks variant readings with `{{另\|X\|Y}}`.                                                                                                                                              |
| C   | 維基文庫《周易正義》 (`…/周易正義/01乾` …)                                                                                                                                                                    | 王弼注, 孔穎達疏: the line of text the received text (通行本) comes from. It too was converted from 简体 in places: 系 for 繫 and 係, 巳 for 已, 幹 for 干, 機 for 机, 佔 for 占, 穀 for 谷, 屍 for 尸, 獲 for 穫. |
| P   | 《周易》 王弼注, 四部叢刊初編: 上海涵芬樓's photo-reprint of a 宋 print. Wikimedia Commons, `File:Sibu Congkan0001-王弼-周易-2-1.djvu` (146 pages) and `…0002-王弼-周易-2-2.djvu` (117 pages); public domain. | **The primary source.** The 經 is cut in large characters and the 注 in double small columns.                                                                                                                      |
| D   | 維基文庫's page transcription of P (`Page:Sibu Congkan0001-王弼-周易-2-1.djvu/N` …)                                                                                                                           | Line for line with the print, in the print's own glyph forms (爲, 徃, 顚). Most pages are marked not yet proofread (level 1), so D only finds what to read in P; it is never the evidence.                         |

## Method

1. **Compare A with B and C**, every 卦辭, 爻辭 and 大象: 514 texts (64 卦辭, 384 爻辭 plus 用九 and 用六, 64 大象).
   Character by character, with punctuation and wiki markup set aside and variant forms mapped together (无/無,
   于/於, 恒/恆, 彊/强/強, 説/說, 敘/敍, 艸/草, 禦/御). A B text with `{{另|X|Y}}` matches either reading.
2. **Look each text of A up in D.** D has no punctuation, so each text must occur in its hexagram's run of 經
   text, with the print's glyph forms mapped to ours.
3. **Read P.** Every text where D misses, and every reading where D and one of B, C disagree with A, was read in
   the scan itself: 16 pages, as page images at 1280 px, with 祇 / 祗 zoomed at 1920 px (vol. 1 pp. 35, 46, 55,
   58, 61, 65, 67, 80, 107, 117, 129, 130; vol. 2 pp. 3, 12, 14, 17).
4. **P decides.** Where P cuts two characters alike, its 注 decides: P has one glyph for 已 and 巳, and the 注
   reads 已 (below).
5. **Forms are not readings.** P's glyph forms (爲, 徃, 顚, 愼, 户, 内 …) are not taken; the text stays in standard
   繁體 forms. A character that is a different word is a reading, and P's word is taken (臘 là for 腊 xī).
6. **Layout.** Each 爻辭 opens with its line's name and 「：」, and each 卦辭 with 「名：」, also where the name is the
   first word of the text (「履：履虎尾」, as A already wrote 「艮：艮其背」).
7. **简体** by OpenCC (tw → cn), keeping 乾 (OpenCC would write 干), then 闚 → 窥. Checked for one-to-many
   characters (G18): every converted pair is the standard one (後→后, 於→于, 幾→几, 雲→云, 發→发, 彙→汇, 繫 and
   係→系, 獲 and 穫→获, 幹→干, 醜→丑, 齎→赍, 歷→历, 僕→仆).

Punctuation is not compared: A's stays. The 彖, 小象 and 文言 are not in the data and were not checked.

## Result

| A against B and C         | Before | After   |
| ------------------------- | ------ | ------- |
| All three agree           | 381    | 456     |
| A = C, B differs          | 21     | 20      |
| A = B, C differs          | 18     | 33      |
| B = C, ours differs       | 77     | 4       |
| None agree                | 17     | 1       |
| **A against D, then P**   |        |         |
| Found in D                | —      | 504     |
| Not found in D, read in P | —      | 10      |
| **A against P (via D)**   |        | **514** |

All 514 texts now read as P does, forms aside: 504 as D transcribes P, and the other 10 as read in P itself. 125 of the 578 繁體 strings changed (the names, 卦辭, 爻辭 and 大象);
56 of them only 兇 → 凶 or a stray space. 51 简体 strings changed: OpenCC had already undone most of the 繁體 slips.

The five that B and C read otherwise after correction are P's readings: 噬嗑 六三 腊 (B 昔 or 臘, C 臘), 坎 九五 祇 (B
禔 or 祗, C 祗), 姤 初六 繫 (B and C 系), 坎's 卦辭 (layout only: ours 「坎：習坎，…」, theirs 「習坎：…」) and 井 九二 甕
(B 瓮; C's 穀 for 谷 is its conversion slip).

## Corrections

In `scripts/build-yijing.ts`: `ERRATA` (each must match the source an exact number of times, or the build stops),
`LINES` and the layout rules.

**A line in the wrong place, a line written twice**

- 大有 九二 held 同人 六二's text 「六二：同人於宗，吝。」. It is 「九二：大車以載，有攸往，無咎。」 (P; its 小象
  「大車以載，積中不敗也」).
- 姤 九五 was written twice.

**Characters mis-converted to 繁體** (the 简体 character stands for two 繁體 ones, and the wrong one was taken)

| Source → correct | Where                                                   |
| ---------------- | ------------------------------------------------------- |
| 兇 → 凶          | 58 places                                               |
| 鹹 → 咸          | 咸 (its name, 卦辭, 5 爻辭 and 大象), 臨 初九 and 九二  |
| 屍 → 尸          | 師 六三, 六五 (輿尸)                                    |
| 匯 → 彙          | 否 初六                                                 |
| 系 → 繫          | 否 九五, 無妄 六三; 姤 初六 (P: B and C also have 系)   |
| 系 → 係          | 隨 六二, 六三, 上六; 坎 上六; 遯 九三                   |
| 獲 → 穫          | 無妄 六二 (不耕穫)                                      |
| 巳 → 已          | 損 初九; 革 卦辭, 六二                                  |
| 裏 → 里          | 震 卦辭 (百里)                                          |
| 鬥 → 斗          | 豐 六二, 九四                                           |
| 仆 → 僕          | 旅 六二, 九三                                           |
| 機 → 机          | 渙 九二 (P's 注: 「机，承物者也」)                      |
| 幹 → 干          | 漸 初六 (鴻漸于干)                                      |
| 臘 → 腊          | 噬嗑 六三 (噬腊肉; P, where B, C and A had 臘 or 昔)    |
| 後 → 后          | 大象 of 泰, 復, 姤 (后, the sovereign; P: 「后以施命」) |
| 誌 → 志          | 大象 of 履, 困                                          |
| 向 → 嚮          | 隨 大象                                                 |

**Other wrong characters**

災 → 菑 (無妄 六二), 他 → 它 (比 初六), 訴訴 → 愬愬 (履 九四), 踟躅 → 蹢躅 (姤 初六), 賫 → 齎 (萃 上六), 沫 → 沬
(豐 九三), 啕 → 咷 (同人 九五, 旅 上九), 碩 → 鼫 (晉 九四), 娶 → 取 (蒙 六三, as in 咸 and 姤), 預 → 豫 (既濟 大象),
虩 → 洊 (震 大象), 置 → 寘 (坎 上六, P), 佑 → 祐 (大有 上九, P), 窺 → 闚 (觀 六二, P; as A had in 豐 上六), 辨 → 辯
(履 大象, P), 祗 → 祇 (復 初九, 坎 九五: P, zoomed; A and C had 祗).

**Missing, extra or misplaced words**

| Hexagram  | Source                   | Corrected (P)            |
| --------- | ------------------------ | ------------------------ |
| 復 初九   | 不復遠                   | 不遠復                   |
| 明夷 六四 | 出於門庭                 | 於出門庭                 |
| 大過 九五 | 老婦得士夫               | 老婦得其士夫             |
| 家人 九五 | 勿恤，往吉               | 勿恤，吉                 |
| 損 上九   | 貞吉，有攸往             | 貞吉，利有攸往           |
| 巽 卦辭   | 小亨，利攸往             | 小亨，利有攸往           |
| 履 大象   | 安民誌                   | 定民志                   |
| 大壯 大象 | 非禮勿履                 | 非禮弗履                 |
| 震 大象   | 虩雷，震；君子以恐懼修身 | 洊雷，震；君子以恐懼修省 |
| 剝 大象   | 山附地上                 | 山附於地                 |

**Layout:** trailing spaces on 9 lines; 咸's six 爻辭 opened 「初六，」; 屯, 師, 比, 履, 否, 同人 and 咸's 卦辭 lacked
「名：」.

## Kept: read in P

- **已, not 巳** (損 初九, 革 卦辭 and 六二). P cuts 已 and 巳 alike; it uses the same glyph in its 注 to 井 上六,
  「水已出井」. The 注 reads both lines with 已: 「事已則往」 (損), and 「即日不孚，已日乃孚」 (革), where 已日 ("once
  the day is past") answers 即日 ("that very day"). D and C write 巳, and C writes 己 in 革's 卦辭. Other
  readings of 革 (巳日, 己日) are argued; this text follows P's 注.
- **Kept against B, with C and D:** 萃 卦辭 opens 亨; 大畜 九三 曰閑 (B 「利艱貞，吉。日閑」); 履 上九 考祥 (B 詳);
  睽 上九 負塗 (B 涂); 困 九二 享祀 (B 亨祀); 中孚 六四 幾 (B 既 or 几); 豐 上六 闚其戶, 三歲不覿 (B 窺, 觌); 井 九二
  甕 (B 瓮); 乾 用九 群, 剝 and 巽 床, 師 大象 眾 (B 羣, 牀, 衆: forms). 渙 初六 has no 悔亡 (B adds it): read in P.
- **D's own slips, read in P** (ours is right): 蠱 六四 has 裕 (D drops it); 豐 六二 「有孚發若」 and 節 六三 「不節若，
  則嗟若」 have their 若 (D drops them); 中孚 九五 「九五有孚攣如」, 中孚 上九 「翰音」 and 小過 卦辭 「遺之音」 (D: 丸, 寜, 青,
  昔); 渙 初六 (D garbles 初).

## Forms (not taken)

P's glyph forms, here with ours first: 為/爲, 往/徃, 戶/户, 內/内, 顛/顚, 慎/愼, 彙/彚, 祿/禄, 類/𩔖, 遲/遟, 賓/賔, 宮/宫,
世/丗, 虛/虚, 茲/兹, 鼠/䑕, 出/岀, 蒞/莅, 曳/曵, 修/脩, 慍/愠, 菑/葘, 裕/𥙿, 冥/㝠, 藜/蔾, 薰/薫, 闃/閴, 陰/隂, 鼓/鼔,
敕/勑, 玄/𤣥, 昃/𣅳, 耋/耊, 杞/𣏌, 瓜/𤓰, 恒/𢘆, 久/乆, 喪/䘮, 婚/㛰, 涉/渉, 履/𡳐.

## Not done

- **P was read on 16 pages**, where D missed or the copies disagreed with A. The other texts rest on D, an
  unproofread transcription of P, agreeing with A character for character (forms aside), most of them with B and
  C as well. Each of D's 10 misses was D's own slip or P's one glyph for 已 / 巳, never a different reading in P.
  Reading P in full would close this.
- Punctuation, the 彖, 小象 and 文言.

## Effect

The corrections change the one source (rule 4), so 算卦 and the 一生运势 report both quote the corrected text; the
facts layer is unchanged. 算卦's 直說 were written for the meaning and needed no change: 大有 九二's reads
「能力夠、擔得起，可以往前推進」, which is 「大車以載，有攸往」, not the misplaced line.
