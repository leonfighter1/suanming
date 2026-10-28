# 求籤: the text of the 關聖帝君一百籤 (2026-10-28)

The 求籤 method (tech plan WP6.1) shows the poem of the lot drawn. Its text is in `data/qiuqian/guandi-100.json`,
built by `npm run build:qiuqian` (`scripts/build-qiuqian.ts`). This page records how the text was checked (G4: never
trust one source).

## The set

**關聖帝君一百籤** (also 雷雨師一百籤 or 關帝籤): 100 lots, labelled 甲甲 … 癸癸. temples.tw lists it as used at
臺北行天宮, 日月潭文武廟 and 新竹城隍廟, and gives it as Taiwan's second most used set (六十甲子籤 first, 觀音一百籤
third).

## Sources

|     | Source                                                                                                                                                            | What it is                                                                                                                               |
| --- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| A   | 維基文庫 「關聖帝君靈籤」 (`zh.wikisource.org/wiki/關聖帝君靈籤/1` … `/100`, raw wikitext)                                                                        | Lots 1–10 are transcribed from the Qing print below. Lots 11–100 come from another transcription, with Hong Kong wording in their notes. |
| B   | temples.tw 「關聖帝君一百籤」 (`temples.tw/stick/fs100/1`, all 100 poems)                                                                                         | The set as the Taiwanese temples above print it.                                                                                         |
| P   | 「關帝靈籤」, 姑蘇鈕氏藏板, a Qing woodblock print. Harvard DRS 53239458, scanned on Wikimedia Commons (`File:Harvard drs 53239458 關帝靈籤.pdf`), public domain. | The primary source. Scan page = lot + 2.                                                                                                 |

Only the four-line poem and the lot's 干支 are taken. The 吉凶 grade, 聖意, 東坡解, 碧仙註 and the stories are left out:
editions disagree on the grades (A and P differ on 2 of the 14 lots compared), and many Taiwanese temples print none.
Modern commentary is not copied.

## Method

1. Compare A and B character by character. They agree on all four lines of **85 lots**.
2. Where they disagree (**16 lines in 15 lots**), read P. Its reading wins, written in the modern form: the print's
   孝弟 is 孝悌.
3. Read all 100 lots in P against the agreed text. Zoom in on every difference.
4. Where A and B agree on a reading that is **plainly wrong**, take P's reading (**5 lines**). Plainly wrong means a
   misprinted branch, a non-word, a broken rhyme, or a look-alike character with another meaning.
5. Every other difference from P is a **variant** (**38 lines**). The poem stays as the temples print it, and P's
   reading is listed below.
6. 干支: lot n = 天干[(n − 1) ÷ 10] + 天干[(n − 1) mod 10]. All 100 headings in P follow it.
7. 简体: OpenCC (tw → cn), keeping 乾 in 乾坤 and 乾亥. Then three fixes:
   - 祇欲 → 只欲;
   - 斲 → 斫;
   - 𫗴 → 饘, since common fonts lack 𫗴.

   Every character whose 简体 form does not convert back was checked by hand (G18). For example, 晴乾 (dry) is 晴干,
   and 乾坤 stays.

Not listed: variant forms that differ only in how a character is written (爲/為, 裡/裏, 嘆/歎, 着/著, 却/卻, 岩/巖,
烟/煙, 碍/礙, 閑/閒, 沾/霑, 大/太, 弟/悌). The data uses the modern forms.

The variant list comes from one full read of P plus a zoom on each difference. A word difference missed in that read
would stay in the text as the temples print it.

## Where A and B disagree: P decides (16 lines)

| Lot | Line | Scan page | A              | B              | P and the data |
| --- | ---- | --------- | -------------- | -------------- | -------------- |
| 3   | 3    | 5         | 但能孝悌存忠信 | 但能孝梯存忠信 | 但能孝悌存忠信 |
| 13  | 4    | 15        | 萬人頭上逞英雄 | 萬上頭上逞英雄 | 萬人頭上逞英雄 |
| 35  | 3    | 37        | 誰料半途分折去 | 誰料半途分析去 | 誰料半途分拆去 |
| 38  | 4    | 40        | 秋冬括括雨靡靡 | 秋冬括括雨霏霏 | 秋冬括括雨霏霏 |
| 52  | 1    | 54        | 兀坐幽居歎寂寥 | 兀坐幽居歎寂廖 | 兀坐幽居歎寂寥 |
| 67  | 1    | 69        | 纔發君心天已知 | 纔發君心天己知 | 纔發君心天已知 |
| 68  | 2    | 70        | 年來幾倍貨財添 | 年來幾倍偵財掭 | 年來幾倍貨財添 |
| 72  | 2    | 74        | 可歎長途日已西 | 可歎長途日山西 | 可歎長途日已西 |
| 74  | 1    | 76        | 崔巍崔魏復崔巍 | 崔巍崔巍復崔巍 | 崔巍崔巍復崔巍 |
| 76  | 2    | 78        | 此事何如說與君 | 此事如何說與君 | 此事如何說與君 |
| 78  | 1    | 80        | 家道豊腴自飽溫 | 家道豐腴自飽溫 | 家道豐腴自飽溫 |
| 84  | 1    | 86        | 箇中事緒更紛然 | 箇中事緒更粉然 | 箇中事緒更紛然 |
| 94  | 2    | 96        | 巧斲輪輿梓匠工 | 巧斵輪輿梓匠工 | 巧斲輪輿梓匠工 |
| 95  | 2    | 97        | 生不逢辰亦強圖 | 笁不逢辰亦強圖 | 生不逢辰亦強圖 |
| 95  | 3    | 97        | 可歎頭顱已如許 | 可歎頭顱己如許 | 可歎頭顱已如許 |
| 99  | 4    | 101       | 驊騮應得驟康莊 | 驊騮應時驟康莊 | 驊騮應得驟康莊 |

## Plain errors in the agreed text: P's reading taken (5 lines)

| Lot | Line | A and B        | P and the data | Why                                            |
| --- | ---- | -------------- | -------------- | ---------------------------------------------- |
| 25  | 1    | 寅午戍年多阻滯 | 寅午戌年多阻滯 | 寅午戌 is a 三合; 戍 is no branch              |
| 47  | 2    | 祗欲平和雪爾冤 | 祇欲平和雪爾冤 | 祇 means "only"; 祗 (reverent) is a look-alike |
| 50  | 2    | 也須步多要周旋 | 也須步步要周旋 | 步多 is no word                                |
| 87  | 2    | 舟中敵圖笑中刀 | 舟中敵國笑中刀 | 舟中敵國 (史記)                                |
| 90  | 4    | 徒勞生事苦咨嘆 | 徒勞生事苦咨嗟 | 咨嗟 rhymes with 麻 and 家, as in #56          |

## Variants: the temples' text kept, P's reading noted (38 lines)

| Lot | Line | Data (the temples) | P              | Differs at  |
| --- | ---- | ------------------ | -------------- | ----------- |
| 1   | 2    | 玉殿千官第一班     | 玉殿仙官第一班 | 千→仙       |
| 7   | 1    | 仙風道骨本天生     | 仙風道骨本天成 | 生→成       |
| 8   | 4    | 士農工賈百無憂     | 士農商賈百無憂 | 工→商       |
| 10  | 1    | 病患時時命蹇衰     | 病患時時命蹇乖 | 衰→乖       |
| 10  | 3    | 宜教重見一陽復     | 直教重見一陽復 | 宜→直       |
| 16  | 1    | 官事悠悠難辨明     | 官事悠悠難辯明 | 辨→辯       |
| 16  | 3    | 傍人煽惑君休信     | 旁人煽惑君休信 | 傍→旁       |
| 17  | 3    | 縱使機關圖得勝     | 縱是機關圖得勝 | 使→是       |
| 18  | 1    | 知君指擬是空華     | 知君指擬似空華 | 是→似       |
| 22  | 2    | 莊嚴色相自天然     | 莊嚴色像自天然 | 相→像       |
| 24  | 2    | 夏裏營求始帖然     | 夏裏營求始貼然 | 帖→貼       |
| 28  | 3    | 人事盡從天理見     | 人事即從天理見 | 盡→即       |
| 29  | 3    | 若更操修無倦已     | 更若操修無倦已 | 若→更 更→若 |
| 31  | 2    | 春到門庭漸吉昌     | 春到門庭大吉昌 | 漸→大       |
| 35  | 4    | 空幃無語對銀缸     | 空幃無語對銀釭 | 缸→釭       |
| 39  | 1    | 北山門下好安居     | 北山門外好安居 | 下→外       |
| 40  | 4    | 崎嶇歷盡見亨衢     | 崎嶇歷過見亨衢 | 盡→過       |
| 43  | 3    | 雖然目下多驚險     | 雖然目下多驚懼 | 險→懼       |
| 48  | 3    | 幸遇虎頭人一喚     | 不遇虎頭人一喚 | 幸→不       |
| 48  | 4    | 全家遂保汝重歡     | 全家誰保汝重歡 | 遂→誰       |
| 50  | 1    | 人說今年勝舊年     | 人說今年盛舊年 | 勝→盛       |
| 52  | 2    | 孤燈掩映度清宵     | 孤燈隱映度清宵 | 掩→隱       |
| 52  | 4    | 活計扁舟渡北朝     | 決許扁舟渡北朝 | 活→決 計→許 |
| 54  | 3    | 爭奈承流風未便     | 爭奈乘流風未便 | 承→乘       |
| 74  | 4    | 長安一道放春回     | 長江一道放春回 | 安→江       |
| 75  | 1    | 生前結得好緣姻     | 生前結得好姻緣 | 緣→姻 姻→緣 |
| 81  | 3    | 幸有高臺明月鏡     | 幸有當堂明月鏡 | 高→當 臺→堂 |
| 82  | 3    | 此時賓主歡相會     | 此時賓主歡相得 | 會→得       |
| 83  | 3    | 主張門戶誠難事     | 主張門戶成難事 | 誠→成       |
| 83  | 4    | 百歲安閒得幾年     | 百歲寬閒得幾年 | 安→寬       |
| 86  | 1    | 一舟行貨好招邀     | 一般行貨好招邀 | 舟→般       |
| 87  | 1    | 陰裏詳看怪爾曹     | 陰裏詳稱怪爾曹 | 看→稱       |
| 89  | 3    | 白馬渡江嘶日暮     | 白馬渡江雖日暮 | 嘶→雖       |
| 92  | 2    | 物價喧騰倍百年     | 物價喧騰倍昔年 | 百→昔       |
| 93  | 2    | 入夏晴乾雨又愆     | 入夏晴時雨又愆 | 乾→時       |
| 93  | 3    | 節氣直交三伏始     | 節氣直交三伏後 | 始→後       |
| 95  | 1    | 知君袖內有驪珠     | 知君袖裏有驪珠 | 內→裏       |
| 99  | 1    | 貴人遭遇水雲鄉     | 貴人相遇水雲鄉 | 遭→相       |
