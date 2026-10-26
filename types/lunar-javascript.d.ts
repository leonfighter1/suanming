// Minimal surface of lunar-javascript 1.7.x used by BaziEngine. Upstream ships no types.
declare module "lunar-javascript" {
  export class Solar {
    static fromYmdHms(y: number, m: number, d: number, h: number, mi: number, s: number): Solar;
    getLunar(): Lunar;
    toYmd(): string;
    toYmdHms(): string;
  }
  export class Lunar {
    getEightChar(): EightChar;
    getJieQiTable(): Record<string, Solar>;
  }
  export class EightChar {
    setSect(sect: 1 | 2): void;
    getYear(): string;
    getMonth(): string;
    getDay(): string;
    getTime(): string;
    getYearGan(): string;
    getMonthGan(): string;
    getDayGan(): string;
    getTimeGan(): string;
    getYearZhi(): string;
    getMonthZhi(): string;
    getDayZhi(): string;
    getTimeZhi(): string;
    getYearHideGan(): string[];
    getMonthHideGan(): string[];
    getDayHideGan(): string[];
    getTimeHideGan(): string[];
    getYearShiShenGan(): string;
    getMonthShiShenGan(): string;
    getDayShiShenGan(): string;
    getTimeShiShenGan(): string;
    getYearShiShenZhi(): string[];
    getMonthShiShenZhi(): string[];
    getDayShiShenZhi(): string[];
    getTimeShiShenZhi(): string[];
    getYearDiShi(): string;
    getMonthDiShi(): string;
    getDayDiShi(): string;
    getTimeDiShi(): string;
    getYearNaYin(): string;
    getMonthNaYin(): string;
    getDayNaYin(): string;
    getTimeNaYin(): string;
    getYun(gender: 0 | 1, sect?: 1 | 2): Yun;
  }
  export class Yun {
    isForward(): boolean;
    getStartYear(): number;
    getStartMonth(): number;
    getStartDay(): number;
    getStartHour(): number;
    getStartSolar(): Solar;
    getDaYun(n?: number): DaYun[];
  }
  export class DaYun {
    getIndex(): number;
    getGanZhi(): string;
    getStartYear(): number;
    getStartAge(): number;
  }
  export const LunarUtil: Record<string, unknown>;
  const _default: { Solar: typeof Solar; Lunar: typeof Lunar; LunarUtil: typeof LunarUtil };
  export default _default;
}
