// 算卦 (tech plan WP10.1): the coins, the hexagrams, 朱熹's rule for the texts read, the cast time and its 干支,
// the three ways to cast and their audit. Expected values are worked by hand (G7), each in its comment.
import { describe, expect, it } from "vitest";
import { validateChartFact, type ChartFact } from "../src/chart-fact/index.js";
import {
  castTime,
  commitmentOf,
  computeLiuyao,
  deriveLayoutSeed,
  focusOf,
  hexOf,
  layoutWithSeed,
  lineOf,
  LiuyaoInputError,
  newLayout,
  verifyCast,
  type LineValue,
  type LiuyaoFacts,
} from "../src/engines/liuyao/index.js";
import { DRAW_KEY, FIXED_NOW, PEPPER } from "./helpers.js";

const ctx = { drawKey: DRAW_KEY, digestPepper: PEPPER, now: FIXED_NOW };
const facts = (c: ChartFact) => c.facts as unknown as LiuyaoFacts;
const ID = "11111111-1111-4111-8111-111111111111";
const LATER = new Date("2026-10-29T00:00:00Z");

describe("the coins", () => {
  it("count 背 3 and 字 2: one 背 is 少陽 7, two 少陰 8, three 老陽 9, none 老陰 6", () => {
    expect(lineOf(["bei", "zi", "zi"])).toBe(7); // 3 + 2 + 2
    expect(lineOf(["zi", "bei", "bei"])).toBe(8); // 2 + 3 + 3
    expect(lineOf(["bei", "bei", "bei"])).toBe(9);
    expect(lineOf(["zi", "zi", "zi"])).toBe(6);
  });
});

describe("the hexagrams", () => {
  it("come from the lines, 初爻 first, with their King Wen number and trigrams", () => {
    expect(hexOf("111111")).toMatchObject({ number: 1, full_name: { "zh-Hant": "乾為天" } });
    expect(hexOf("000000").number).toBe(2);
    // 天雷無妄, 25: 下卦 震 (初 yang, 二 三 yin: "100"), 上卦 乾 ("111").
    expect(hexOf("100111")).toMatchObject({
      number: 25,
      lower: "100",
      upper: "111",
      full_name: { "zh-Hant": "天雷無妄", "zh-Hans": "天雷无妄" },
    });
  });
});

describe("the texts read (朱熹《易學啟蒙·考變占》)", () => {
  const cast = (values: LineValue[]) =>
    facts(
      computeLiuyao(
        {
          mode: "manual",
          timezone: "Asia/Hong_Kong",
          local: "2026-10-28T14:30",
          lines: values.map((value) => ({ value })),
        },
        { ...ctx, now: () => LATER },
      ),
    );
  const read = (f: LiuyaoFacts) =>
    f.focus.texts.map((t) => `${t.role} ${t.hexagram} ${t.line ?? "卦辭"}`);

  it("no moving line: the 卦辭", () => {
    const f = cast([7, 8, 8, 7, 7, 7]); // 無妄, still
    expect(f.changed).toBeUndefined();
    expect(read(f)).toEqual(["main primary 卦辭"]);
    expect(f.focus.texts[0]!.text["zh-Hant"]).toBe(f.primary.gua_ci["zh-Hant"]);
  });

  it("one: that line, and the 變卦 has it turned", () => {
    // 無妄 with 六二 moving (6) turns into 110111: 下卦 兌, 上卦 乾, 天澤履 (10).
    const f = cast([7, 6, 8, 7, 7, 7]);
    expect(f.primary.number).toBe(25);
    expect(f.changed).toMatchObject({
      id: "110111",
      number: 10,
      full_name: { "zh-Hant": "天澤履" },
    });
    expect(read(f)).toEqual(["main primary 2"]);
    expect(f.focus.texts[0]!.text["zh-Hant"]).toMatch(/^六二：不耕/);
  });

  it("two: both lines, the upper first", () => {
    expect(read(cast([7, 6, 8, 7, 9, 7]))).toEqual(["main primary 5", "also primary 2"]);
  });

  it("three: the 本卦 and 變卦 卦辭, 本卦 first", () => {
    expect(read(cast([9, 6, 8, 7, 7, 9]))).toEqual(["main primary 卦辭", "also changed 卦辭"]);
  });

  it("four: the 變卦's two still lines, the lower first", () => {
    expect(read(cast([9, 6, 6, 9, 7, 8]))).toEqual(["main changed 5", "also changed 6"]);
  });

  it("five: the 變卦's one still line", () => {
    expect(read(cast([9, 6, 8, 9, 6, 9]))).toEqual(["main changed 3"]);
  });

  it("six: 乾 用九, 坤 用六, any other the 變卦 卦辭", () => {
    const qian = cast([9, 9, 9, 9, 9, 9]);
    expect(read(qian)).toEqual(["main primary 7"]);
    expect(qian.focus.texts[0]!.text["zh-Hant"]).toBe("用九：見群龍無首，吉。");
    expect(cast([6, 6, 6, 6, 6, 6]).focus.texts[0]!.text["zh-Hant"]).toBe("用六：利永貞。");
    // 9 6 9 6 9 6 is 101010, 水火既濟 (63); all turned, 010101, 火水未濟 (64).
    const jiji = cast([9, 6, 9, 6, 9, 6]);
    expect([jiji.primary.number, jiji.changed!.number]).toEqual([63, 64]);
    expect(read(jiji)).toEqual(["main changed 卦辭"]);
  });

  it("is a pure function of the lines", () => {
    expect(focusOf([7, 8, 8, 7, 7, 7], "100111").moving).toBe(0);
  });
});

describe("the cast time", () => {
  it("gives the 年月日時 干支 of the local time", () => {
    // 2026-10-28: 9797 days after 2000-01-01 (戊午, 54 in the 甲子 cycle); 54 + 17 = 71 → 11, 乙亥.
    // 寒露 to 立冬 is 戌月; 丙午 year, so 戊戌. 14:30 is 未; an 乙 day starts 子 at 丙, 丙 + 7 = 癸: 癸未.
    expect(castTime({ local: "2026-10-28T14:30", timezone: "Asia/Hong_Kong" }, LATER)).toEqual({
      local: "2026-10-28T14:30",
      timezone: "Asia/Hong_Kong",
      utc: "2026-10-28T06:30:00.000Z",
      ganzhi: { year: "丙午", month: "戊戌", day: "乙亥", hour: "癸未" },
    });
  });

  it("turns the year at 立春 by the instant (UTC+8), and the day by the local date", () => {
    // 立春 2026 falls on 4 Feb about 04:02 in UTC+8. New York 3 Feb 13:00 is 02:00 there (乙巳 年, 己丑 月);
    // 17:00 is 06:00 (丙午 年, 庚寅 月). The local date stays 3 Feb: 2000-01-01 + 9530 days, 54 + 50 → 44, 戊申.
    const before = castTime({ local: "2026-02-03T13:00", timezone: "America/New_York" }, LATER);
    const after = castTime({ local: "2026-02-03T17:00", timezone: "America/New_York" }, LATER);
    expect([before.ganzhi.year, before.ganzhi.month, before.ganzhi.day]).toEqual([
      "乙巳",
      "己丑",
      "戊申",
    ]);
    expect([after.ganzhi.year, after.ganzhi.month, after.ganzhi.day]).toEqual([
      "丙午",
      "庚寅",
      "戊申",
    ]);
    // A 戊 day starts 子 at 壬: 未 (13:00) is 壬 + 7 = 己未, 酉 (17:00) 壬 + 9 = 辛酉.
    expect([before.ganzhi.hour, after.ganzhi.hour]).toEqual(["己未", "辛酉"]);
  });

  it("is the server's now in the reader's zone when the server casts", () => {
    // 2026-10-25T00:00Z is 08:00 in Hong Kong. 25 Oct is 乙亥 − 3 → 8, 壬申; 辰 hour on a 壬 day: 庚 + 4 = 甲辰.
    expect(castTime({ timezone: "Asia/Hong_Kong" }, FIXED_NOW())).toMatchObject({
      local: "2026-10-25T08:00",
      ganzhi: { year: "丙午", month: "戊戌", day: "壬申", hour: "甲辰" },
    });
  });

  it("refuses a time in the future, one a DST gap skips, a malformed one and an unknown zone", () => {
    const at =
      (local: string, timezone = "Asia/Hong_Kong") =>
      () =>
        castTime({ local, timezone }, FIXED_NOW());
    expect(at("2026-10-26T08:00")).toThrow(LiuyaoInputError);
    expect(at("2026-03-08T02:30", "America/New_York")).toThrow(LiuyaoInputError);
    expect(at("2026-10-24 14:30")).toThrow(LiuyaoInputError);
    expect(at("2026-10-24T14:30", "Mars/Olympus")).toThrow(LiuyaoInputError);
  });
});

describe("the three ways to cast", () => {
  it("auto: the server tosses, and the cast replays from the key", () => {
    const fact = computeLiuyao(
      { mode: "auto", timezone: "Asia/Hong_Kong" },
      { ...ctx, newDrawId: () => ID },
    );
    const again = computeLiuyao(
      { mode: "auto", timezone: "Asia/Hong_Kong" },
      { ...ctx, newDrawId: () => ID },
    );
    expect(facts(again).tosses).toEqual(facts(fact).tosses);
    expect(facts(fact).tosses.every((t) => t.coins?.length === 3)).toBe(true);
    expect(validateChartFact(fact)).toEqual({ ok: true });
    expect(verifyCast(fact, DRAW_KEY)).toBe(true);
    expect(verifyCast(fact, Buffer.alloc(32, 1))).toBe(false);
    const tampered = structuredClone(fact);
    const t0 = facts(tampered).tosses[0]!;
    t0.coins![0] = t0.coins![0] === "bei" ? "zi" : "bei";
    expect(verifyCast(tampered, DRAW_KEY)).toBe(false);
  });

  it("pick: the coins are laid out and committed before the reader picks 18 in order", () => {
    const layout = newLayout(DRAW_KEY, () => ID);
    const coins = layoutWithSeed(deriveLayoutSeed(DRAW_KEY, ID));
    expect(layout).toEqual({
      draw_id: ID,
      size: 24,
      picks: 18,
      commitment: commitmentOf(ID, coins),
    });
    const picks = [23, 5, 0, 7, 9, 11, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 1];
    const fact = computeLiuyao(
      { mode: "pick", timezone: "Asia/Hong_Kong", draw_id: ID, picks },
      ctx,
    );
    const f = facts(fact);
    // Picks 1–3 make the 初爻: coins 23, 5 and 0 as laid out.
    expect(f.tosses[0]!.coins).toEqual([coins[23], coins[5], coins[0]]);
    expect(f.tosses[5]!.coins).toEqual([coins[20], coins[22], coins[1]]);
    expect(f.pick).toEqual({ size: 24, picks, layout: coins, commitment: layout.commitment });
    expect(validateChartFact(fact)).toEqual({ ok: true });
    expect(verifyCast(fact, DRAW_KEY)).toBe(true);
    const moved = structuredClone(fact);
    const l = facts(moved).pick!.layout;
    l[23] = l[23] === "bei" ? "zi" : "bei";
    expect(verifyCast(moved, DRAW_KEY)).toBe(false);
  });

  it("pick: refuses anything but 18 different coins of the 24", () => {
    const pick = (picks: number[]) => () =>
      computeLiuyao({ mode: "pick", timezone: "Asia/Hong_Kong", draw_id: ID, picks }, ctx);
    const ok = Array.from({ length: 18 }, (_, i) => i);
    expect(pick(ok.slice(1))).toThrow(LiuyaoInputError);
    expect(pick([...ok.slice(1), 1])).toThrow(LiuyaoInputError);
    expect(pick([...ok.slice(1), 24])).toThrow(LiuyaoInputError);
  });

  it("manual: the reader's coins or lines, and the time, required", () => {
    const fact = computeLiuyao(
      {
        mode: "manual",
        timezone: "Asia/Hong_Kong",
        local: "2026-10-24T21:05",
        lines: [
          { coins: ["bei", "zi", "zi"] },
          { value: 6 },
          { coins: ["zi", "bei", "bei"] },
          { value: 9 },
          { coins: ["bei", "bei", "bei"] },
          { coins: ["zi", "zi", "zi"] },
        ],
      },
      ctx,
    );
    const f = facts(fact);
    expect(f.tosses.map((t) => t.value)).toEqual([7, 6, 8, 9, 9, 6]);
    expect(f.tosses[1]!.coins).toBeNull();
    expect(f.cast.local).toBe("2026-10-24T21:05");
    expect(f.audit).toBeUndefined();
    expect(validateChartFact(fact)).toEqual({ ok: true });
    const bad = (lines: unknown[]) => () =>
      computeLiuyao(
        { mode: "manual", timezone: "Asia/Hong_Kong", local: "2026-10-24T21:05", lines } as never,
        ctx,
      );
    expect(bad([{ value: 7 }])).toThrow(LiuyaoInputError);
    expect(bad(Array(6).fill({ coins: ["zi", "zi"] }))).toThrow(LiuyaoInputError);
    expect(bad(Array(6).fill({ value: 5 }))).toThrow(LiuyaoInputError);
  });
});
