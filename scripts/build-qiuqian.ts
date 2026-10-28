/**
 * Builds data/qiuqian/guandi-100.json: the 關聖帝君一百籤 (雷雨師一百籤, 關帝籤) as Taiwanese temples print it
 * (臺北行天宮, 日月潭文武廟, 新竹城隍廟), in 繁體 and 简体.
 *
 *   npm run build:qiuqian
 *
 * How the text was checked (2026-10-28; the evidence is docs/verification/qiuqian-guandi-100.md):
 * - LOTS: each poem as two transcriptions give it where they agree, character for character: A 維基文庫
 *   「關聖帝君靈籤」 and B temples.tw 「關聖帝君一百籤」. They agree on 85 lots in full.
 * - Where A and B disagree (16 lines in 15 lots), the Qing print 「關帝靈籤」 decides (姑蘇鈕氏藏板, Harvard DRS
 *   53239458 on Wikimedia Commons, scan page = lot + 2). The comment on each such lot says what was read and which
 *   transcription had it.
 * - CORRECTIONS: 5 lines where A and B agree on a reading that is plainly wrong take the print's reading: a
 *   misprinted branch, a non-word, a broken rhyme, a look-alike character with another meaning.
 * - Every other difference from the print (38 lines, listed in the evidence) is a variant: the poem stays as the
 *   temples print it.
 * - 干支 labels: 甲甲 … 癸癸, lot n = 天干[(n − 1) ÷ 10] + 天干[(n − 1) mod 10] (all 100 headings in the print follow
 *   it).
 * - 简体 by OpenCC (tw → cn) with KEEP and HANS_FIXES below, checked for one-to-many characters (G18).
 * No 吉凶 grade, 聖意 or 典故: editions disagree on them, and many Taiwanese temples print no grade.
 */
import { mkdirSync, writeFileSync } from "node:fs";
import OpenCC from "opencc-js";

const toHans = OpenCC.Converter({ from: "tw", to: "cn" });

/** Lot n's poem, its four lines joined by "，". */
const LOTS: string[] = [
  "巍巍獨步向雲間，玉殿千官第一班，富貴榮華天付汝，福如東海壽如山",
  "盈虛消息總天時，自此君當百事宜，若問前程歸縮地，更須方寸好修為",
  "衣食自然生處有，勸君不用苦勞心，但能孝悌存忠信，福祿來成禍不侵", // #3: l3 print p5 = A (print 孝弟, the old form of 悌; B 孝梯)
  "去年百事頗相宜，若較今年時運衰，好把瓣香告神佛，莫教福謝悔無追",
  "子有三般不自由，門庭蕭索冷如秋，若逢牛鼠交承日，萬事回春不用憂",
  "何勞鼓瑟更吹笙，寸步如登萬里程，彼此懷疑不相信，休將私意憶濃情",
  "仙風道骨本天生，又遇仙宗為主盟，指日丹成謝巖谷，一朝引領向天行",
  "年來耕稼苦無收，今歲田疇定有秋，況遇太平無事日，士農工賈百無憂",
  "望渠消息向長安，常把菱花仔細看，見說文書將入境，今朝喜色上眉端",
  "病患時時命蹇衰，何須打瓦共鑽龜，宜教重見一陽復，始可求神仗佛持",
  "今年好事一番新，富貴榮華萃汝身，誰道機關難料處，到頭獨立轉傷神",
  "營為期望在春前，誰料秋來又不然，直遇清江貴公子，一生活計始安全",
  "君今庚甲未亨通，且向江頭作釣翁，玉兔重生應發跡，萬人頭上逞英雄", // #13: l4 print p15 = A (B 萬上頭上)
  "一見佳人便喜歡，誰知去後有多般，人情冷暖君休訝，歷涉應知行路難",
  "兩家門戶各相當，不是姻緣莫較量，直待春風好消息，卻調琴瑟向蘭房",
  "官事悠悠難辨明，不如息了且歸耕，傍人煽惑君休信，此事當謀親弟兄",
  "田園價貫好商量，事到公庭彼此傷，縱使機關圖得勝，定為後世子孫殃",
  "知君指擬是空華，底事茫茫未有涯，牢把腳根踏實地，善為善應永無差",
  "嗟子從來未得時，今年星運頗相宜，營求動作都如意，和合婚姻誕貴兒",
  "一生心事向誰論，十八灘頭說與君，世事盡從流水去，功名富貴等浮雲",
  "與君夙昔結成冤，今日相逢那得緣，好把經文多諷誦，祈求戶內保嬋娟",
  "碧玉池中開白蓮，莊嚴色相自天然，生來骨格超凡俗，正是人間第一仙",
  "花開花謝在春風，貴賤窮通百歲中，羨子榮華今已矣，到頭萬事總成空",
  "一春萬事苦憂煎，夏裏營求始帖然，更遇秋成冬至後，恰如騎鶴與腰纏",
  "寅午戍年多阻滯，亥子丑月漸亨嘉，更逢玉兔金雞會，枯木逢春自放花",
  "年來豐歉皆天數，自是今年旱較多，與子定期三日內，田疇霑足雨滂沱",
  "世間萬物各有主，一粒一毫君莫取，英雄豪傑自天生，也須步步循規矩",
  "公侯將相本無種，好把勤勞契上天，人事盡從天理見，才高豈得困林泉",
  "祖宗積德幾多年，源遠流長慶自然，若更操修無倦已，天須還汝舊青氈",
  "奉公謹守莫欺心，自有亨通吉利臨，目下營求且休矣，秋期與子定佳音",
  "秋冬作事只尋常，春到門庭漸吉昌，千里信音符遠望，萱堂快樂未渠央",
  "勞心汨汨竟何歸，疾病兼多是與非，事到頭來渾似夢，何如休要用心機",
  "不分南北與西東，眼底昏昏耳似聾，熟讀黃庭經一卷，不論貴賤與窮通",
  "春夏纔過秋又冬，紛紛謀慮攪心胸，貴人垂手來相援，休把私心情意濃",
  "一山如畫對清江，門裏團圓事事雙，誰料半途分拆去，空幃無語對銀缸", // #35: l3 print p37 (A 分折, B 分析)
  "功名富貴自能為，偶著仙鞭莫問伊，萬里鵬程君有分，吳山頂上好鑽龜",
  "焚香來告復何辭，善惡平分汝自知，屏卻昧公心裏事，出門無礙是通時",
  "蛩吟唧唧守孤幃，千里懸懸望信歸，等得榮華公子到，秋冬括括雨霏霏", // #38: l4 print p40 = B (A 雨靡靡)
  "北山門下好安居，若問終時慎厥初，堪笑包藏許多事，鱗鴻雖便莫修書",
  "新來換得好規模，何用隨他步與趨，只聽耳邊消息到，崎嶇歷盡見亨衢",
  "自南自北自東西，欲到天涯誰作梯，遇鼠逢牛三弄笛，好將名姓榜頭題",
  "我曾許汝事和諧，誰料修為汝自乖，但改新圖莫依舊，營謀應得稱心懷",
  "一紙官書火急催，扁舟速下浪如雷，雖然目下多驚險，保汝平安去復回",
  "汝是人中最吉人，誤為誤作損精神，堅牢一念酬香願，富貴榮華萃汝身",
  "好將心地力耕耘，彼此山頭總是墳，陰地不如心地好，修為到底卻輸君",
  "君是山中萬戶侯，信知騎馬勝騎牛，今朝馬上看山色，爭似騎牛得自由",
  "與君萬語復千言，祗欲平和雪爾冤，訟則終凶君記取，試於清夜把心捫",
  "登山涉水正天寒，兄弟姻親那得安，幸遇虎頭人一喚，全家遂保汝重歡",
  "彼此家居只一山，如何似隔鬼門關，日月如梭人易老，許多勞碌不如閒",
  "人說今年勝舊年，也須步多要周旋，一家和氣多生福，萋菲讒言莫聽偏",
  "君今百事且隨緣，水到渠成聽自然，莫嘆年來不如意，喜逢新運稱心田",
  "兀坐幽居歎寂寥，孤燈掩映度清宵，萬金忽報秋光好，活計扁舟渡北朝", // #52: l1 print p54 = A (B 寂廖)
  "艱難險阻路蹊蹺，南鳥孤飛依北巢，今日貴人曾識面，相逢卻在夏秋交",
  "萬人叢裏逞英豪，便欲飛騰霄漢高，爭奈承流風未便，青燈黃卷且勤勞",
  "勤耕力作莫蹉跎，衣食隨時安分過，縱使經商收倍利，不如逐歲廩禾多",
  "心頭理曲強詞遮，直欲欺官行路斜，一旦醜形臨月鏡，身投憲網莫咨嗟",
  "事端百出慮雖長，莫聽人言自主張，一著仙機君記取，紛紛鬧裏更思量",
  "蘇秦三寸足平生，富貴功名在此行，更好修為陰騭事，前程萬里自通亨",
  "門衰戶冷苦伶仃，自嘆祈求不一靈，幸有祖宗陰騭在，香煙未斷續螟蛉",
  "羨君兄弟好名聲，只管謙撝莫自矜，丹詔槐黃相逼近，巍巍科甲兩同登",
  "嘯聚山林兇惡儔，善良無事苦煎憂，主人大笑出門去，不用干戈盜賊休",
  "百千人面虎狼心，賴汝干戈用力深，得勝回時秋漸老，虎頭城裏喜相尋",
  "曩時敗北且圖南，筋力雖衰尚一堪，欲識生前君大數，前三三與後三三",
  "吉人相遇本和同，況有持謀天水翁，人力不勞公論協，事成功倍笑談中",
  "朔風凜凜正窮冬，多羨門庭喜氣濃，更入新春人事後，衷言方得信先容",
  "耕耘只可在鄉邦，何用求謀向外方，見說今年新運好，門闌喜氣事雙雙",
  "纔發君心天已知，何須問我決狐疑，願子改圖從孝悌，不愁家室不相宜", // #67: l1 print p69 = A (B 天己知)
  "南販珍珠北販鹽，年來幾倍貨財添，勸君止此求田舍，心欲多時何日厭", // #68: l2 print p70 = A (B 偵財掭)
  "捨舟遵路總相宜，慎勿嬉遊逐貴兒，一夜樽前兄與弟，明朝仇敵又相隨",
  "雷雨風雲各有司，至誠禱告莫生疑，與君定約為霖日，正是蘊隆中伏時",
  "喜鵲簷前報好音，知君千里欲歸心，繡幃重結鴛鴦帶，葉落霜飛寒色侵",
  "河渠傍路有高低，可歎長途日已西，縱有榮華好時節，直須猴犬換金雞", // #72: l2 print p74 = A (B 日山西)
  "憶昔蘭房分半釵，而今忽把信音乖，痴心指望成連理，到底誰知事不諧",
  "崔巍崔巍復崔巍，履險如夷去復來，身似菩提心似鏡，長安一道放春回", // #74: l1 print p76 = B (A 崔魏)
  "生前結得好緣姻，一笑相逢情自親，相當人物無高下，得意休論富與貧",
  "三千法律八千文，此事如何說與君，善惡兩途君自作，一生禍福此中分", // #76: l2 print p78 = B (A 何如)
  "木有根荄水有源，君當自此究其原，莫隨道路人閒話，訟到終凶是至言",
  "家道豐腴自飽溫，也須肚裏立乾坤，財多害己君當省，福有胚胎禍有門", // #78: l1 print p80 = B (A 豊, a variant)
  "乾亥來龍仔細看，坎居午向自當安，若移丑艮陰陽逆，門戶凋零家道難",
  "一朝無事忽遭官，也是門衰墳未安，改換陰陽移禍福，勸君莫作等閒看",
  "假君財物自當還，謀賴心欺他自奸，幸有高臺明月鏡，請來對照破機關",
  "彼亦儔中一輩賢，勸君特達與周旋，此時賓主歡相會，他日王侯卻並肩",
  "隨分堂前赴粥饘，何須妄想苦憂煎，主張門戶誠難事，百歲安閒得幾年",
  "箇中事緒更紛然，當局須知一著先，長舌婦人休酷聽，力行禮義要心堅", // #84: l1 print p86 = A (B 粉然)
  "一春風雨正瀟瀟，千里行人去路遙，移寡就多君得計，如何歸路轉無聊",
  "一舟行貨好招邀，積少成多自富饒，常把他人比自己，管須日後勝今朝",
  "陰裏詳看怪爾曹，舟中敵圖笑中刀，藩籬剖破渾無事，一種天生惜羽毛",
  "從前作事總徒勞，纔見新春時漸遭，百計營求都得意，更須守己莫心高",
  "樽前無事且高歌，時未來時奈若何，白馬渡江嘶日暮，虎頭城裏看巍峨",
  "崆峒城裏事如麻，無事如君有幾家，勸汝不須勤致禱，徒勞生事苦咨嘆",
  "佛說淘沙始見金，只緣君子不勞心，榮華總得詩書效，妙裏工夫仔細尋",
  "今年禾穀不如前，物價喧騰倍百年，災數流行多疫癘，一陽復後始安全",
  "春來雨水太連綿，入夏晴乾雨又愆，節氣直交三伏始，喜逢滂沛足田園",
  "一般器用與人同，巧斲輪輿梓匠工，凡事有緣且隨分，秋冬方遇主人翁", // #94: l2 print p96 = A (B 斵, a variant)
  "知君袖內有驪珠，生不逢辰亦強圖，可歎頭顱已如許，而今方得貴人扶", // #95: l2 print p97 = A (B 笁不逢辰); l3 print p97 = A (B 己如許)
  "婚姻子息莫嫌遲，但把精神仗佛持，四十年前須報應，功圓行滿育馨兒",
  "五十功名心已灰，那知富貴逼人來，更行好事存方寸，壽比岡陵位鼎台",
  "經營百出費精神，南北奔馳運未新，玉兔交時當得意，恰如枯木再逢春",
  "貴人遭遇水雲鄉，冷淡交情滋味長，黃閣開時延故客，驊騮應得驟康莊", // #99: l4 print p101 = A (B 應時)
  "我本天仙雷雨師，吉凶禍福我先知，至誠禱祝皆靈應，抽得終籤百事宜",
];

/** Lines where A and B agree on a plainly wrong reading; the print's reading replaces it. */
const CORRECTIONS: [lot: number, line: number, from: string, to: string, why: string][] = [
  [25, 1, "戍", "戌", "the branch 戌 (寅午戌, a 三合); 戍 is no branch"],
  [47, 2, "祗欲", "祇欲", "祇 is only; 祗 (reverent) is a look-alike"],
  [50, 2, "步多", "步步", "步多 is no word"],
  [87, 2, "敵圖", "敵國", "舟中敵國, the 史記 phrase"],
  [90, 4, "咨嘆", "咨嗟", "咨嗟 rhymes with 麻 and 家, as in #56"],
];

/**
 * OpenCC turns 乾 into 干. Where 乾 is the trigram (乾坤) or a direction (乾亥) Mainland editions keep it; 晴乾
 * (#93) is "dry" and becomes 干.
 */
const KEEP = ["乾坤", "乾亥"] as const;

/** After OpenCC: what it leaves or writes in a way 简体 readers and fonts don't use. */
const HANS_FIXES: [from: string, to: string][] = [
  ["祇欲", "只欲"], // #47: 祇 is "only", which 简体 writes 只
  ["斲", "斫"], // #94: 简体 merged 斲 into 斫
  ["𫗴", "饘"], // #83: OpenCC's 𫗴 (Ext-C) is missing from common fonts
];

const hansOf = (hant: string) => {
  let s = hant;
  KEEP.forEach((w, i) => (s = s.split(w).join(String.fromCodePoint(0xf0000 + i))));
  s = toHans(s);
  KEEP.forEach((w, i) => (s = s.split(String.fromCodePoint(0xf0000 + i)).join(w)));
  return HANS_FIXES.reduce((t, [a, b]) => t.split(a).join(b), s);
};

const STEMS = "甲乙丙丁戊己庚辛壬癸";
const ganzhiOf = (n: number) => STEMS[Math.floor((n - 1) / 10)]! + STEMS[(n - 1) % 10]!;

if (LOTS.length !== 100) throw new Error(`expected 100 lots, got ${LOTS.length}`);
const poems = LOTS.map((s) => s.split("，"));
for (const [lot, line, from, to] of CORRECTIONS) {
  const text = poems[lot - 1]![line - 1]!;
  if (!text.includes(from)) throw new Error(`#${lot} line ${line} has no 「${from}」: 「${text}」`);
  poems[lot - 1]![line - 1] = text.replace(from, to);
}
for (const [i, p] of poems.entries()) {
  if (p.length !== 4 || !p.every((l) => /^\p{Script=Han}{7}$/u.test(l)))
    throw new Error(`#${i + 1}: expected four lines of seven characters: ${p.join("，")}`);
}

const out = {
  id: "guandi_100",
  // A reading records this in its rule_versions: bump it whenever a poem's text changes.
  version: "1.0.0",
  name: {
    "zh-Hant": "關聖帝君一百籤",
    "zh-Hans": "关圣帝君一百签",
    en: "Lord Guan's hundred lots",
  },
  source:
    "關聖帝君一百籤 as Taiwanese temples print it: poems where 維基文庫 and temples.tw agree; their disagreements and five plain errors settled from the Qing print 關帝靈籤 (姑蘇鈕氏藏板, Harvard DRS 53239458); 简体 by OpenCC. Built by scripts/build-qiuqian.ts (docs/verification/qiuqian-guandi-100.md).",
  lots: poems.map((p, i) => ({
    n: i + 1,
    ganzhi: ganzhiOf(i + 1),
    poem: { "zh-Hant": p, "zh-Hans": p.map(hansOf) },
  })),
};

const dir = new URL("../data/qiuqian/", import.meta.url);
mkdirSync(dir, { recursive: true });
writeFileSync(new URL("guandi-100.json", dir), JSON.stringify(out, null, 1) + "\n");
console.log(`wrote ${out.lots.length} lots`);
