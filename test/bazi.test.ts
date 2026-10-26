import lunar from "lunar-javascript";
import { describe, expect, it } from "vitest";
import { validateChartFact } from "../src/chart-fact/index.js";
import {
  computeBazi,
  diShi,
  tenGod,
  yearGanZhi,
  type BaziInput,
} from "../src/engines/bazi/index.js";
import { FIXED_NOW, PEPPER } from "./helpers.js";

const ctx = { digestPepper: PEPPER, now: FIXED_NOW };
type Facts = {
  pillars: Record<"year" | "month" | "day" | "hour", { gan: string; zhi: string }>;
  dayun: { direction: string };
};
const run = (i: BaziInput) => computeBazi(i, ctx).facts as unknown as Facts;
const gz = (p: { gan: string; zhi: string }) => p.gan + p.zhi;

const base: BaziInput = {
  local: "1990-03-15T14:30",
  timezone: "Asia/Hong_Kong",
  longitude: 114.17,
  gender: "male",
};

describe("BaziEngine output", () => {
  it("validates against ChartFact schema", () => {
    expect(validateChartFact(computeBazi(base, ctx))).toEqual({ ok: true });
  });
  it("is deterministic for identical input", () => {
    expect(computeBazi(base, ctx)).toEqual(computeBazi({ ...base }, ctx));
  });
});

/** UTC instant of a 节气 from lunar-javascript's own table (expressed in UTC+8). */
function jieqiUtc(year: number, name: string): number {
  const s = lunar.Solar.fromYmdHms(year, 6, 1, 12, 0, 0).getLunar().getJieQiTable()[name]!;
  const [d, t] = s.toYmdHms().split(" ") as [string, string];
  return Date.parse(`${d}T${t}+08:00`);
}

function localIn(tz: string, utcMs: number): string {
  const f = new Intl.DateTimeFormat("sv-SE", {
    timeZone: tz,
    hourCycle: "h23",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  });
  return f.format(new Date(utcMs)).replace(" ", "T");
}

describe("year/month boundary uses the birth instant, not the local wall clock", () => {
  const lichun = jieqiUtc(2024, "立春"); // 2024-02-04 ~16:27 UTC+8
  for (const [tz, lon] of [
    ["Asia/Hong_Kong", 114.17],
    ["America/New_York", -74.0],
    ["Europe/London", -0.13],
  ] as const) {
    it(`${tz}: 10 min before 立春 → 癸卯/乙丑, 10 min after → 甲辰/丙寅`, () => {
      const at = (dt: number) =>
        run({ ...base, timezone: tz, longitude: lon, local: localIn(tz, lichun + dt * 60_000) });
      const before = at(-10);
      const after = at(10);
      expect(gz(before.pillars.year)).toBe("癸卯");
      expect(gz(before.pillars.month)).toBe("乙丑");
      expect(gz(after.pillars.year)).toBe("甲辰");
      expect(gz(after.pillars.month)).toBe("丙寅");
    });
  }
});

describe("day pillar", () => {
  it("advances one step of the 60-cycle per day", () => {
    const JIAZI = Array.from(
      { length: 60 },
      (_, i) => "甲乙丙丁戊己庚辛壬癸"[i % 10]! + "子丑寅卯辰巳午未申酉戌亥"[i % 12]!,
    );
    let prev: number | undefined;
    for (let d = 1; d <= 120; d++) {
      const local = `${new Date(Date.UTC(2023, 0, d)).toISOString().slice(0, 10)}T12:00`;
      const idx = JIAZI.indexOf(
        gz(run({ ...base, local, options: { trueSolarTime: false } }).pillars.day),
      );
      if (prev !== undefined) expect(idx).toBe((prev + 1) % 60);
      prev = idx;
    }
  });

  it("子时 sect: 23:30 belongs to next day under sect 1, same day under sect 2", () => {
    const at = (local: string, ziHourSect: 1 | 2) =>
      run({ ...base, local, options: { trueSolarTime: false, ziHourSect } }).pillars;
    const s1 = at("2023-05-10T23:30", 1);
    const s2 = at("2023-05-10T23:30", 2);
    const nextDay = at("2023-05-11T12:00", 2);
    expect(gz(s1.day)).toBe(gz(nextDay.day));
    expect(gz(s2.day)).not.toBe(gz(nextDay.day));
    expect(s1.hour.zhi).toBe("子");
    expect(s2.hour.zhi).toBe("子");
  });

  it("true solar time can move the hour pillar", () => {
    // 13:05 civil in Urumqi (87.6°E, on UTC+8) is ~10:58 true solar → 巳, not 未
    const i: BaziInput = {
      ...base,
      timezone: "Asia/Shanghai",
      longitude: 87.6,
      local: "2023-05-10T13:05",
    };
    expect(run({ ...i, options: { trueSolarTime: false } }).pillars.hour.zhi).toBe("未");
    expect(run(i).pillars.hour.zhi).toBe("巳");
  });
});

describe("十神 / 十二长生 tables agree with lunar-javascript", () => {
  it("over 400 sampled charts", () => {
    for (let k = 0; k < 400; k++) {
      const t = new Date(Date.UTC(1940, 0, 1) + k * 86_400_000 * 73.3);
      const ec = lunar.Solar.fromYmdHms(
        t.getUTCFullYear(),
        t.getUTCMonth() + 1,
        t.getUTCDate(),
        t.getUTCHours(),
        0,
        0,
      )
        .getLunar()
        .getEightChar();
      const dm = ec.getDayGan();
      expect(tenGod(dm, ec.getYearGan())).toBe(ec.getYearShiShenGan());
      expect(tenGod(dm, ec.getMonthGan())).toBe(ec.getMonthShiShenGan());
      expect(tenGod(dm, ec.getTimeGan())).toBe(ec.getTimeShiShenGan());
      expect(ec.getYearHideGan().map((g) => tenGod(dm, g))).toEqual(ec.getYearShiShenZhi());
      expect(diShi(dm, ec.getYearZhi())).toBe(ec.getYearDiShi());
      expect(diShi(dm, ec.getTimeZhi())).toBe(ec.getTimeDiShi());
    }
  });
});

describe("大运", () => {
  it("yang year: male → forward, female → backward", () => {
    // 1990 庚午: 庚 is yang
    expect(run(base).dayun.direction).toBe("forward");
    expect(run({ ...base, gender: "female" }).dayun.direction).toBe("backward");
  });
});

describe("日主 / 月令 / 加权五行 / 流年", () => {
  // 1990-03-15 14:30 HK → 庚午 己卯 己卯 辛未 (true solar 13:57)
  const f = computeBazi({ ...base, options: { liunianFrom: 2026 } }, ctx).facts as unknown as {
    day_master: unknown;
    month_command: unknown;
    wuxing_weighted: { scores: Record<string, number> };
    liunian: {
      year: number;
      ganzhi: string;
      age: number;
      shishen_gan: string;
      shishen_zhi: string;
      dayun_index: number;
      branch_relations: unknown[];
    }[];
  };

  it("day master and month command", () => {
    expect(f.day_master).toEqual({ gan: "己", wuxing: "土", yin_yang: "阴" });
    expect(f.month_command).toEqual({ zhi: "卯", wuxing: "木" });
  });

  it("weighted 五行 (hand-computed)", () => {
    // stems 庚己己辛 → 金2 土2; 午[丁.7 己.3] 卯[乙1] 卯[乙1] 未[己.6 丁.3 乙.1]
    expect(f.wuxing_weighted.scores).toEqual({ 木: 2.1, 火: 1, 土: 2.9, 金: 2, 水: 0 });
  });

  it("流年 2026 丙午 and 2027 丁未", () => {
    expect(f.liunian).toHaveLength(10);
    expect(f.liunian[0]).toEqual({
      year: 2026,
      ganzhi: "丙午",
      age: 36,
      shishen_gan: "正印",
      shishen_zhi: "偏印",
      dayun_index: 3,
      branch_relations: [{ pillar: "hour", type: "六合" }],
    });
    expect(f.liunian[1]!.ganzhi).toBe("丁未");
    expect(f.liunian[1]!.dayun_index).toBe(4);
    expect(f.liunian[1]!.branch_relations).toEqual([{ pillar: "year", type: "六合" }]);
  });

  it("流年 base year is part of the input digest", () => {
    const a = computeBazi({ ...base, options: { liunianFrom: 2026 } }, ctx).input_digest;
    const b = computeBazi({ ...base, options: { liunianFrom: 2027 } }, ctx).input_digest;
    expect(a).not.toBe(b);
  });
});

it("yearGanZhi anchors", () => {
  expect(yearGanZhi(1984)).toBe("甲子");
  expect(yearGanZhi(1990)).toBe("庚午");
  expect(yearGanZhi(2024)).toBe("甲辰");
  expect(yearGanZhi(1900)).toBe("庚子");
});

describe("農曆 對照", () => {
  it("known dates (Spring Festival 1984, leap 2nd month 2023)", async () => {
    const { lunarDate } = await import("../src/engines/bazi/index.js");
    expect(lunarDate(1990, 3, 15)).toMatchObject({
      year_ganzhi: "庚午",
      shengxiao: "马",
      month: 2,
      month_name: "二月",
      day: 19,
      day_name: "十九",
      is_leap_month: false,
    });
    expect(lunarDate(1984, 2, 2)).toMatchObject({
      year_ganzhi: "甲子",
      month: 1,
      month_name: "正月",
      day_name: "初一",
    });
    expect(lunarDate(2023, 3, 22)).toMatchObject({
      month: 2,
      is_leap_month: true,
      month_name: "闰二月",
      day_name: "初一",
    });
  });

  it("農曆 year (春節) and 八字 year (立春) can differ", async () => {
    const { lunarDate } = await import("../src/engines/bazi/index.js");
    // 2024-02-05: after 立春 (Feb 4) but before 春節 (Feb 10)
    const f = computeBazi({ ...base, local: "2024-02-05T12:00" }, ctx).facts as unknown as Facts;
    expect(gz(f.pillars.year)).toBe("甲辰");
    expect(lunarDate(2024, 2, 5).year_ganzhi).toBe("癸卯");
  });
});
