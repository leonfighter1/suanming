// WP1.1–1.4 (docs/tech-plan.md): 虚岁, the pillar day, 合冲刑害破, 神煞, 空亡, 胎元, 流月.
// Every expected value is worked out by hand from the tables in relations.ts / shensha.ts.
import lunar from "lunar-javascript";
import { describe, expect, it } from "vitest";
import { computeBazi, lunarDate } from "../src/engines/bazi/index.js";
import { natalRelations, periodRelations, relationsAmong } from "../src/engines/bazi/relations.js";
import {
  kongWang,
  liuyue,
  natalShensha,
  periodShensha,
  taiYuan,
  xunKong,
} from "../src/engines/bazi/shensha.js";
import { yijingFacts } from "../src/engines/yijing/index.js";
import { yearGanZhi } from "../src/engines/bazi/index.js";
import { PEPPER } from "./helpers.js";

const ctx = { digestPepper: PEPPER, now: () => new Date("2026-10-25T00:00:00Z") };
const chart = (
  local: string,
  timezone: string,
  longitude: number,
  gender: "male" | "female" = "male",
) =>
  computeBazi({ local, timezone, longitude, gender, options: { liunianFrom: 2026 } }, ctx)
    .facts as any;
// 庚午 己卯 己卯 辛未 (the project's sample chart)
const sample = chart("1990-03-15T14:30", "Asia/Hong_Kong", 114.17);
const P = (gz: string) => ({ gan: gz[0]!, zhi: gz[1]! });
const natal = (y: string, m: string, d: string, h: string) => ({
  year: P(y),
  month: P(m),
  day: P(d),
  hour: P(h),
});
const types = (rs: { type: string }[]) => rs.map((r) => r.type);

describe("合冲刑害破", () => {
  const s = (pillar: any, char: string) => ({ pillar, char });
  it("each pair type", () => {
    expect(relationsAmong([s("year", "甲"), s("month", "己")], [])).toEqual([
      { type: "天干五合", element: "土", members: [s("year", "甲"), s("month", "己")] },
    ]);
    expect(types(relationsAmong([s("year", "甲"), s("month", "庚")], []))).toEqual(["天干相冲"]);
    expect(types(relationsAmong([s("year", "戊"), s("month", "己")], []))).toEqual([]); // 戊己 no 冲
    const b = (x: string, y: string) => types(relationsAmong([], [s("year", x), s("month", y)]));
    expect(b("子", "丑")).toEqual(["六合"]);
    expect(b("子", "午")).toEqual(["六冲"]);
    expect(b("申", "子")).toEqual(["半合"]); // includes the middle 子
    expect(b("申", "辰")).toEqual([]); // 生 + 墓 without 子 is no 半合
    expect(b("子", "卯")).toEqual(["相刑"]);
    expect(b("寅", "巳")).toEqual(["相刑", "六害"]); // both
    expect(b("巳", "申")).toEqual(["六合", "相刑", "相破"]); // all three
    expect(b("辰", "辰")).toEqual(["自刑"]);
    expect(b("子", "子")).toEqual([]); // 子 is no 自刑
    expect(b("子", "未")).toEqual(["六害"]);
    expect(b("子", "酉")).toEqual(["相破"]);
  });

  it("a full 三合 or 三刑 is one relation, without its pairs; 三会 too", () => {
    const three = (x: string, y: string, z: string) =>
      relationsAmong([], [s("year", x), s("month", y), s("day", z)]);
    expect(types(three("申", "子", "辰"))).toEqual(["三合"]); // no 半合 申子 / 子辰 on top
    expect(three("申", "子", "辰")[0]!.element).toBe("水");
    // 三刑 once (no 刑 pairs on top), then 寅巳 害, 寅申 冲, 巳申 合 and 破.
    expect(types(three("寅", "巳", "申"))).toEqual(["相刑", "六害", "六冲", "六合", "相破"]);
    expect(types(three("寅", "卯", "辰"))).toEqual(["三会", "六害"]); // and 卯辰 害
  });

  it("the sample chart 庚午 己卯 己卯 辛未", () => {
    // 午卯 破 (twice), 午未 合 土, 卯未 半合 木 (twice: 亥卯未 with the middle 卯).
    expect(
      sample.relations.map(
        (r: any) => `${r.type}${r.element ?? ""}:${r.members.map((m: any) => m.pillar).join("-")}`,
      ),
    ).toEqual([
      "相破:year-month",
      "相破:year-day",
      "六合土:year-hour",
      "半合木:month-hour",
      "半合木:day-hour",
    ]);
    expect(natalRelations(natal("庚午", "己卯", "己卯", "辛未"))).toEqual(sample.relations);
  });

  it("a period keeps only what involves it, its 大运 included", () => {
    const n = natal("甲子", "丙寅", "戊辰", "庚申");
    // 流年 戊子 under 大运 壬午: 子 completes 申子辰 三合 with 时支 申 and 日支 辰; 子 with 大运 午 冲;
    // 戊 with 大运 壬? no (丙壬 冲 is 月干 and 大运, not the 流年).
    const rs = periodRelations(n, { place: "liunian", ganzhi: "戊子" }, "壬午");
    expect(rs.every((r) => r.members.some((m) => m.pillar === "liunian"))).toBe(true);
    expect(types(rs)).toContain("三合");
    expect(rs.find((r) => r.type === "六冲")!.members).toEqual([
      s("dayun", "午"),
      s("liunian", "子"),
    ]);
  });
});

describe("神煞, 空亡, 胎元", () => {
  it("the sample chart", () => {
    // 己 日: 天乙 子申 (none), 文昌 酉 (none), 禄 午 = 年支. 年支 午 (寅午戌): 桃花 卯 = 月, 日;
    // 驿马 申, 华盖 戌 (none). 日支 卯 (亥卯未): 华盖 未 = 时支; 桃花 子, 驿马 巳 (none).
    expect(sample.shensha).toEqual([
      { name: "禄神", basis: "day_gan", targets: "午", pillars: ["year"] },
      { name: "桃花", basis: "year_zhi", targets: "卯", pillars: ["month", "day"] },
      { name: "华盖", basis: "day_zhi", targets: "未", pillars: ["hour"] },
    ]);
    // 己卯 is in 甲戌旬 (甲戌…癸未): 申酉 空; 庚午 in 甲子旬: 戌亥. No natal branch is 申 or 酉.
    expect(sample.kongwang).toEqual({ by_day: "申酉", by_year: "戌亥", pillars: [] });
    // 月 己卯: 己 + 1 = 庚, 卯 + 3 = 午.
    expect(sample.taiyuan).toBe("庚午");
  });

  it("羊刃 and 天乙 for a 甲 day; 空亡 across the 旬", () => {
    const n = natal("癸丑", "乙卯", "甲寅", "辛未");
    // 甲: 羊刃 卯 = 月支; 天乙 丑未 = 年, 时; 禄 寅 = 日.
    const names = natalShensha(n).map((x) => `${x.name}:${x.pillars.join("-")}`);
    expect(names).toEqual(expect.arrayContaining(["羊刃:month", "天乙贵人:year-hour", "禄神:day"]));
    expect(periodShensha(n, "卯")).toContain("羊刃");
    // 甲子旬 → 戌亥, 甲戌旬 → 申酉, 甲午旬 → 辰巳, and 癸酉 is still 甲子旬.
    expect([xunKong("甲子"), xunKong("甲戌"), xunKong("甲午"), xunKong("癸酉")]).toEqual([
      "戌亥",
      "申酉",
      "辰巳",
      "戌亥",
    ]);
    expect(kongWang(natal("甲子", "丙戌", "甲子", "乙亥")).pillars).toEqual(["month", "hour"]);
    expect(taiYuan({ gan: "癸", zhi: "亥" })).toBe("甲寅"); // 癸 + 1 wraps to 甲, 亥 + 3 to 寅
  });

  it("agrees with lunar-javascript on 胎元 and 日空亡 (an independent check, G4)", () => {
    for (const [y, m, d, h] of [
      [1990, 3, 15, 14],
      [1975, 11, 2, 6],
      [2001, 7, 30, 22],
      [1958, 1, 20, 3],
    ] as const) {
      const ec = (lunar as any).Solar.fromYmdHms(y, m, d, h, 0, 0).getLunar().getEightChar();
      ec.setSect(2);
      expect(taiYuan({ gan: ec.getMonthGan(), zhi: ec.getMonthZhi() })).toBe(ec.getTaiYuan());
      expect(xunKong(ec.getDay())).toBe(ec.getDayXunKong());
    }
  });
});

describe("流月 and ages", () => {
  it("流月 2026 (丙午): 寅月 庚寅 by 五虎遁 (丙辛 → 庚), then month by month to 辛丑", () => {
    const ms = liuyue(2026, "丙");
    expect(ms.map((x) => x.ganzhi)).toEqual([
      "庚寅",
      "辛卯",
      "壬辰",
      "癸巳",
      "甲午",
      "乙未",
      "丙申",
      "丁酉",
      "戊戌",
      "己亥",
      "庚子",
      "辛丑",
    ]);
    expect([ms[0]!.jie, ms[11]!.jie]).toEqual(["立春", "小寒"]);
    expect(ms[11]!.starts.startsWith("2027-01")).toBe(true);
    // Each month's 干支 is the library's month pillar a day after its 节.
    for (const x of ms) {
      const [date] = x.starts.split(" ");
      const [y, mo, d] = date!.split("-").map(Number);
      const day = new Date(Date.UTC(y!, mo! - 1, d! + 1));
      const ec = (lunar as any).Solar.fromYmdHms(
        day.getUTCFullYear(),
        day.getUTCMonth() + 1,
        day.getUTCDate(),
        12,
        0,
        0,
      )
        .getLunar()
        .getEightChar();
      expect(ec.getMonth(), x.jie).toBe(x.ganzhi);
    }
    expect(sample.liuyue.year).toBe(2026);
    // 日主 己 (阴土): 庚 阳金 is what 土 generates, opposite polarity → 伤官; 寅 本气 甲 阳木
    // controls 土, opposite polarity → 正官.
    expect(sample.liuyue.months[0]).toMatchObject({
      ganzhi: "庚寅",
      shishen_gan: "伤官",
      shishen_zhi: "正官",
    });
  });

  it("every 节 the 流月 can begin on is in the protected-term table (v3.3.0)", async () => {
    const { loadTerms } = await import("../src/ai/index.js");
    const terms = loadTerms().terms;
    // The twelve 节, 立春 to 小寒, the same names every year.
    for (const year of [1990, 2026, 2045]) {
      const jie = liuyue(year, yearGanZhi(year)[0]!).map((m) => m.jie);
      expect(new Set(jie).size).toBe(12);
      expect(jie.filter((j) => !terms[j])).toEqual([]);
    }
  });

  it("虚岁 on every 流年 and 大运, from the same civil birth year", () => {
    for (const y of sample.liunian) expect(y.age_xu).toBe(y.year - 1990 + 1);
    for (const c of sample.dayun.cycles) expect(c.start_age_xu).toBe(c.start_year - 1990 + 1);
    // For a Hong Kong birth the library's 虚岁 agrees.
    for (const c of sample.dayun.cycles) expect(c.start_age_xu).toBe(c.start_age);
  });
});

describe("the ten years of every 大运 (WP4.3)", () => {
  const years = sample.dayun_years as any[];

  it("ten per 大运, in order, from each start year", () => {
    // The 大运 start in 1997, 2007, …, 2067 (8 of them), so the years run 1997–2076.
    expect(sample.dayun.cycles.map((c: any) => c.start_year)).toEqual([
      1997, 2007, 2017, 2027, 2037, 2047, 2057, 2067,
    ]);
    expect(years.map((y) => y.year)).toEqual(Array.from({ length: 80 }, (_, i) => 1997 + i));
    for (const c of sample.dayun.cycles) {
      expect(years.filter((y) => y.dayun_index === c.index).map((y) => y.year)).toEqual(
        Array.from({ length: 10 }, (_, i) => c.start_year + i),
      );
    }
  });

  it("a year reads as worked out by hand", () => {
    // 2007 − 4 = 2003: 2003 mod 10 = 3 → 丁, 2003 mod 12 = 11 → 亥. 丁 阴火 generates 己 阴土, same
    // polarity → 偏印; 亥's 本气 壬 阳水 is what 土 controls, opposite polarity → 正财. 亥 neither
    // 合s nor 冲s 午 卯 卯 未. Age 2007 − 1990 = 17, 虚岁 18; the second 大运 (2007–2016).
    expect(years.find((y) => y.year === 2007)).toEqual({
      year: 2007,
      ganzhi: "丁亥",
      age: 17,
      age_xu: 18,
      shishen_gan: "偏印",
      shishen_zhi: "正财",
      dayun_index: 2,
      branch_relations: [],
    });
    // 2029 − 4 = 2025: 2025 mod 10 = 5 → 己, 2025 mod 12 = 9 → 酉. 己 against 己 → 比肩; 酉's 本气
    // 辛 阴金 is what 土 generates, same polarity → 食神. 卯酉 冲 the month and the day branch.
    expect(years.find((y) => y.year === 2029)).toEqual({
      year: 2029,
      ganzhi: "己酉",
      age: 39,
      age_xu: 40,
      shishen_gan: "比肩",
      shishen_zhi: "食神",
      dayun_index: 4,
      branch_relations: [
        { pillar: "month", type: "六冲" },
        { pillar: "day", type: "六冲" },
      ],
    });
  });

  it("where it meets the 流年 list, it says the same", () => {
    for (const { relations: _r, shensha: _s, ...entry } of sample.liunian) {
      expect(years.find((y) => y.year === entry.year)).toEqual(entry);
    }
  });
});

describe("the pillar day (WP1.2)", () => {
  // Kashgar runs on Beijing time 44° west of 120°E: 2000-06-15 01:00 civil is about
  // 01:00 − (120 − 75.99) × 4 min ≈ 22:04 true solar on 06-14, so the hour is 亥 of the 14th.
  const kashgar = chart("2000-06-15T01:00", "Asia/Shanghai", 75.99);
  it("is the true solar day; the 农历生日 stays the civil date", () => {
    expect(kashgar.pillars.hour.zhi).toBe("亥");
    expect(kashgar.lunar_pillar_day).toEqual({
      ...lunarDate(2000, 6, 14),
      basis: "pillar_clock_date",
    });
    expect(kashgar.lunar).toEqual(lunarDate(2000, 6, 15));
  });
  it("the 本命卦 takes its date from it", () => {
    const civil = yijingFacts({ ...kashgar, lunar_pillar_day: undefined }, 2000, yearGanZhi);
    const right = yijingFacts(kashgar, 2000, yearGanZhi);
    expect(right.benming.steps.lunar_day).toBe(kashgar.lunar_pillar_day.day);
    expect(civil.benming.steps.lunar_day).toBe(kashgar.lunar.day);
    expect(right.benming.steps.lunar_day).not.toBe(civil.benming.steps.lunar_day);
  });
});
