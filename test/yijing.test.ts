import { describe, expect, it } from "vitest";
import { computeBazi, yearGanZhi } from "../src/engines/bazi/index.js";
import {
  bazhai,
  benmingGua,
  hexagram,
  kuaNumber,
  meihua,
  relationToTi,
  seasonalStrength,
  yijingFacts,
  zhouyiText,
} from "../src/engines/yijing/index.js";
import { placeCountry } from "../src/places/index.js";
import { FIXED_NOW, PEPPER } from "./helpers.js";

// Golden case: the owner's sample report (吴勇, male, 1987-11-23 03:30, 江苏靖江).
// Every expectation below is taken from that report, worked out independently.
const jingjiang = placeCountry("CN")!
  .regions.flatMap((r) => r.cities)
  .find((c) => c.names.en === "Jingjiang")!;
const wuyong = computeBazi(
  {
    local: "1987-11-23T03:30",
    timezone: jingjiang.tz,
    longitude: jingjiang.lon,
    gender: "male",
  },
  { digestPepper: PEPPER, now: FIXED_NOW },
);
const f = wuyong.facts as unknown as Parameters<typeof yijingFacts>[0] & {
  time_basis: { pillar_clock: string };
};
const facts = yijingFacts(f, 1987, yearGanZhi);

describe("golden case: the owner's sample 一生运势报告", () => {
  it("八字 and 农历 match the sample (丁卯 辛亥 丙子 庚寅, 十月初三, 真太阳时 ≈ 3:44 寅时)", () => {
    const p = f.pillars;
    expect(
      ["year", "month", "day", "hour"].map((k) => p[k as "year"].gan + p[k as "year"].zhi),
    ).toEqual(["丁卯", "辛亥", "丙子", "庚寅"]);
    expect([f.lunar.month, f.lunar.day]).toEqual([10, 3]);
    expect(f.time_basis.pillar_clock).toMatch(/^1987-11-23T03:4[3-5]/);
  });

  it("本命卦: 卯4 + 10 + 3 = 17 → 乾; + 寅3 = 20 → 震; 20 mod 6 = 2 → 天雷无妄 二爻, 之卦天泽履", () => {
    const b = facts.benming;
    expect(b.steps).toMatchObject({
      upper_sum: 17,
      upper_remainder: 1,
      lower_sum: 20,
      lower_remainder: 4,
    });
    expect(b.hexagram.full_name["zh-Hans"]).toBe("天雷无妄");
    expect(b.moving_line).toBe(2);
    expect(b.changed.full_name["zh-Hans"]).toBe("天泽履");
    expect(b.nuclear.full_name["zh-Hans"]).toBe("风山渐");
    expect(b.hexagram.gua_ci["zh-Hans"]).toMatch(/^无妄：元亨，利贞。其匪正有眚/);
    expect(b.lines[1]).toMatchObject({ line: 2, moving: true, age_from: 15, age_to: 29 });
    expect(b.lines[1]!.text["zh-Hans"]).toBe("六二：不耕获，不菑畬，则利有攸往。");
    expect(b.lines[2]!.text["zh-Hans"]).toMatch(/^六三：无妄之灾，或系之牛/);
    expect(b.lines[5]).toMatchObject({ age_from: 75, age_to: null });
  });

  it("梅花: 体乾金, 用震木 (体克用) 早年; 互卦渐: 巽木体克, 艮土生体; 变卦兑金比和; 亥月水旺金休", () => {
    const m = facts.meihua;
    expect(m.ti).toEqual({ trigram: "111", wuxing: "金" });
    expect(m.yong).toMatchObject({ trigram: "100", wuxing: "木", relation: "体克", stage: "早年" });
    expect(m.hu.trigrams.map((x) => [x.trigram, x.relation])).toEqual([
      ["011", "体克"],
      ["001", "生体"],
    ]);
    expect(m.bian).toMatchObject({ trigram: "110", wuxing: "金", relation: "比和", stage: "晚年" });
    expect(m.season).toEqual({ month_zhi: "亥", ruling: "水", ti_strength: "休" });
  });

  it("八宅: 1987 男命 → 巽卦 东四命, 木; 生气北 天医南 延年东 伏位东南 祸害西北 六煞西 五鬼西南 绝命东北", () => {
    const z = facts.bazhai;
    expect(z).toMatchObject({ kua: 4, trigram: "011", group: "东四命", wuxing: "木" });
    expect(Object.fromEntries(z.directions.map((d) => [d.star, d.direction["zh-Hans"]]))).toEqual({
      生气: "北",
      天医: "南",
      延年: "东",
      伏位: "东南",
      祸害: "西北",
      六煞: "西",
      五鬼: "西南",
      绝命: "东北",
    });
    expect(z.directions.find((d) => d.star === "绝命")!.luck).toBe("大凶");
  });
});

describe("hand-checked cases", () => {
  it("子1 + 1 + 1 = 3 → 离; + 子1 = 4 → 震; 4 mod 6 = 4: 火雷噬嗑, 之卦山雷颐, 互卦水山蹇", () => {
    const b = benmingGua({ yearZhi: "子", lunarMonth: 1, lunarDay: 1, hourZhi: "子" });
    expect(b.hexagram.full_name["zh-Hans"]).toBe("火雷噬嗑");
    expect(b.moving_line).toBe(4);
    expect(b.changed.full_name["zh-Hans"]).toBe("山雷颐");
    expect(b.nuclear.full_name["zh-Hans"]).toBe("水山蹇");
    // Moving line in the upper trigram: 体 is the lower one.
    expect(meihua(b, "寅").ti).toEqual({ trigram: "100", wuxing: "木" });
  });

  it("pure hexagrams are named X为Y; 繁體 uses 為", () => {
    expect(hexagram("111111").full_name).toEqual({ "zh-Hans": "乾为天", "zh-Hant": "乾為天" });
    expect(hexagram("000000").full_name["zh-Hans"]).toBe("坤为地");
    expect(hexagram("111000").full_name["zh-Hans"]).toBe("地天泰");
  });

  it("命卦 numbers (published tables): 1990 男坎1 女艮8, 2000 男离9 女乾6, 1987 女坤2", () => {
    expect(kuaNumber(1990, "male")).toBe(1);
    expect(kuaNumber(1990, "female")).toBe(8); // 5 → 8 for women
    expect(kuaNumber(2000, "male")).toBe(9);
    expect(kuaNumber(2000, "female")).toBe(6);
    expect(kuaNumber(1987, "female")).toBe(2);
    expect(kuaNumber(1985, "male")).toBe(6); // 8+5=13→4, 10−4=6
    expect(kuaNumber(1986, "male")).toBe(2); // 8+6=14→5, 10−5=5 → 2 for men
  });

  it("八宅 坎命 (independent table): 生气东南 天医东 延年南 伏位北 绝命西南 五鬼东北 六煞西北 祸害西", () => {
    const z = bazhai(1990, "male");
    expect(Object.fromEntries(z.directions.map((d) => [d.star, d.direction["zh-Hans"]]))).toEqual({
      生气: "东南",
      天医: "东",
      延年: "南",
      伏位: "北",
      祸害: "西",
      六煞: "西北",
      五鬼: "东北",
      绝命: "西南",
    });
  });

  it("五行 relations and 旺相休囚死", () => {
    expect(relationToTi("金", "土")).toBe("生体");
    expect(relationToTi("金", "水")).toBe("体生");
    expect(relationToTi("金", "火")).toBe("克体");
    expect(seasonalStrength("木", "木")).toBe("旺");
    expect(seasonalStrength("火", "木")).toBe("相");
    expect(seasonalStrength("水", "木")).toBe("休");
    expect(seasonalStrength("金", "木")).toBe("囚");
    expect(seasonalStrength("土", "木")).toBe("死");
  });

  it("born before 立春: 八宅 uses the previous 干支 year", () => {
    const early = computeBazi(
      { local: "1988-01-20T12:00", timezone: "Asia/Shanghai", longitude: 121.47, gender: "male" },
      { digestPepper: PEPPER, now: FIXED_NOW },
    );
    const y = yijingFacts(early.facts as never, 1988, yearGanZhi);
    expect(y.bazhai.year).toBe(1987); // still 丁卯 until 立春 1988-02-04
  });
});

// The text as corrected against 維基文庫《周易》 and 《周易正義》 (docs/verification/zhouyi.md).
describe("the 周易 text", () => {
  const ids = Array.from({ length: 64 }, (_, n) => n.toString(2).padStart(6, "0"));
  const all = ids.map(zhouyiText);
  const scripts = ["zh-Hant", "zh-Hans"] as const;

  it("each 爻辭 opens with its own line's name, by place and 陰陽 (初九 … 上六), then 用九 / 用六", () => {
    const place = ["初", "二", "三", "四", "五", "上"];
    for (const [i, t] of all.entries()) {
      const names = [...ids[i]!].map((bit, k) => {
        const n = bit === "1" ? "九" : "六";
        return k === 0 || k === 5 ? place[k] + n : n + place[k];
      });
      if (ids[i] === "111111") names.push("用九");
      if (ids[i] === "000000") names.push("用六");
      for (const s of scripts) expect(t.yao_ci.map((y) => y[s].split("：")[0])).toEqual(names);
    }
  });

  it("each 卦辭 opens with 「名：」, also where the name is its first word (「履：履虎尾」)", () => {
    for (const t of all)
      for (const s of scripts)
        expect(t.gua_ci[s].startsWith(`${t.name[s]}：`), t.gua_ci[s]).toBe(true);
    expect(zhouyiText("110111").gua_ci["zh-Hant"]).toBe("履：履虎尾，不咥人，亨。");
  });

  it("the source's slips stay corrected: no 繁體 mis-conversion, doubled line or stray space", () => {
    const hant = all
      .flatMap((t) => [t.name, t.gua_ci, ...t.yao_ci].map((x) => x["zh-Hant"]))
      .concat(ids.map((id) => hexagram(id).da_xiang["zh-Hant"]));
    for (const bad of [
      "兇",
      "鹹",
      "鬥",
      "屍",
      "裏",
      "仆",
      "巳",
      "啕",
      "踟躅",
      "賫",
      "誌",
      "臘",
      "祗",
    ])
      expect(hant.filter((x) => x.includes(bad))).toEqual([]);
    for (const x of hant) {
      expect(x).toBe(x.trim());
      expect(x.length % 2 === 0 && x.slice(0, x.length / 2) === x.slice(x.length / 2)).toBe(false);
    }
  });

  it("hand-checked lines: 大有 九二, 姤 初六 and 九五, 復 初九, 損 上九 and 咸's name", () => {
    expect(zhouyiText("111101").yao_ci[1]!["zh-Hant"]).toBe("九二：大車以載，有攸往，無咎。");
    // The print reads 繫 and 祇 where all three digital copies have 系 and 祗.
    expect(zhouyiText("011111").yao_ci[0]!["zh-Hant"]).toMatch(/^初六：繫於金柅/);
    expect(zhouyiText("011111").yao_ci[4]!["zh-Hant"]).toBe("九五：以杞包瓜，含章，有隕自天。");
    expect(zhouyiText("100000").yao_ci[0]!["zh-Hans"]).toBe("初九：不远复，无祇悔，元吉。");
    expect(zhouyiText("110001").yao_ci[5]!["zh-Hant"]).toBe(
      "上九：弗損益之，無咎，貞吉，利有攸往，得臣無家。",
    );
    expect(zhouyiText("001110").name).toEqual({ "zh-Hant": "咸", "zh-Hans": "咸" });
    // 大象 (the 一生运势 brief reads it): 后 is the sovereign, not 後; 震's was misworded.
    expect(hexagram("111000").da_xiang["zh-Hant"]).toBe(
      "天地交，泰；后以財成天地之道，輔相天地之宜，以左右民。",
    );
    expect(hexagram("100100").da_xiang["zh-Hans"]).toBe("洊雷，震；君子以恐惧修省。");
  });
});
