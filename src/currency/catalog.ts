/**
 * 货币 (S31; the owner, 2026-10-31: 「checkbox on different accepted currencies by admin. have a rate conversions on the
 * currencies. user is able to pick what ever currencies they like」): the currencies 积分 can be bought in, with their
 * names, symbols and the decimals a price shows. The packs are priced in 元 (config/points.json); which of these are
 * accepted is 设置's currencies.accepted.
 */
export interface Currency {
  code: string;
  names: { "zh-Hans": string; "zh-Hant": string };
  symbol: string;
  /** The decimals of its smallest unit, as prices are shown (a 新台币 or a 日元 price is whole). */
  decimals: number;
}

export const CURRENCIES: readonly Currency[] = [
  { code: "CNY", names: { "zh-Hans": "人民币", "zh-Hant": "人民幣" }, symbol: "¥", decimals: 2 },
  { code: "HKD", names: { "zh-Hans": "港币", "zh-Hant": "港幣" }, symbol: "HK$", decimals: 2 },
  { code: "TWD", names: { "zh-Hans": "新台币", "zh-Hant": "新臺幣" }, symbol: "NT$", decimals: 0 },
  { code: "MOP", names: { "zh-Hans": "澳门元", "zh-Hant": "澳門元" }, symbol: "MOP$", decimals: 2 },
  {
    code: "SGD",
    names: { "zh-Hans": "新加坡元", "zh-Hant": "新加坡元" },
    symbol: "S$",
    decimals: 2,
  },
  {
    code: "MYR",
    names: { "zh-Hans": "马来西亚令吉", "zh-Hant": "馬來西亞令吉" },
    symbol: "RM",
    decimals: 2,
  },
  { code: "USD", names: { "zh-Hans": "美元", "zh-Hant": "美元" }, symbol: "US$", decimals: 2 },
  {
    code: "CAD",
    names: { "zh-Hans": "加拿大元", "zh-Hant": "加拿大元" },
    symbol: "C$",
    decimals: 2,
  },
  {
    code: "AUD",
    names: { "zh-Hans": "澳大利亚元", "zh-Hant": "澳洲元" },
    symbol: "A$",
    decimals: 2,
  },
  { code: "GBP", names: { "zh-Hans": "英镑", "zh-Hant": "英鎊" }, symbol: "£", decimals: 2 },
  { code: "EUR", names: { "zh-Hans": "欧元", "zh-Hant": "歐元" }, symbol: "€", decimals: 2 },
  { code: "JPY", names: { "zh-Hans": "日元", "zh-Hant": "日圓" }, symbol: "JP¥", decimals: 0 },
];

export const CURRENCY_CODES = CURRENCIES.map((c) => c.code);

export const currencyOf = (code: string) => CURRENCIES.find((c) => c.code === code);
