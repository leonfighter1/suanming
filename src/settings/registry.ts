/**
 * 设置 (S31; the owner, 2026-10-31: 「Move all the configurations into separate files, CMS controlling panel is able to
 * read and adjust those values. Extract as much configurations as possible, for instance, identify the users idle
 * time, rightnow, 2 days, but we should be able to change it in the dashboard controlling panel」): what the
 * 管理后台's 设置 page reads and changes, each with its group, type, range and words. A setting's default is in
 * config/settings.json, or in the env variable it names when that is set; a change made in the panel wins over both
 * (src/settings/index.ts).
 */
import { readFileSync } from "node:fs";
import { MODELS } from "../ai/models.js";
import { CURRENCY_CODES } from "../currency/catalog.js";
import { loadPointsConfig, packFits, type Pack } from "../points/pricing.js";

export type SettingGroup =
  "maintenance" | "sessions" | "codes" | "ai" | "limits" | "content" | "currencies" | "points";

interface Common {
  /** `group.name`, as config/settings.json nests it. */
  key: string;
  group: SettingGroup;
  /** What the panel calls it, and a line on what it does. */
  label: string;
  about: string;
  /** An env variable that, when set, is the default instead of the file's (the deployment's). */
  env?: string;
  /** The default's home when it is not config/settings.json (the packs': config/points.json, S32). */
  fallback?: { from: string; value: () => unknown };
}

export type SettingSpec = Common &
  (
    | { type: "number"; min: number; max: number; integer?: boolean; unit?: string }
    | { type: "boolean"; optional?: boolean }
    | { type: "choice"; options: () => readonly string[]; optional?: boolean }
    | { type: "choices"; options: () => readonly string[] }
    // 充值 packs (S32): 1 to max of them, each its 元 and its 积分.
    | { type: "packs"; max: number }
    // A time (S35, 维护's end): an ISO date and time, or none where optional.
    | { type: "time"; optional?: boolean }
  );

export const SETTINGS = [
  {
    key: "sessions.idle_days",
    group: "sessions",
    type: "number",
    min: 0.01,
    max: 365,
    unit: "天",
    env: "MINGLI_SESSION_IDLE_DAYS",
    label: "登录有效期",
    about:
      "账户多久没用之后要重新登录；可以是小数（0.5 是 12 小时）。改了以后，下一次登录或刷新起算。",
  },
  // 登录保护 (S32 WP32.1): failures count per account and per IP, over the window's minutes (src/auth/limits.ts).
  {
    key: "sessions.captcha_after",
    group: "sessions",
    type: "number",
    integer: true,
    min: 1,
    max: 100,
    unit: "次",
    label: "登录失败几次后要人机验证",
    about: "同一个账户或同一个 IP 在计算时长里登录失败这么多次后，再登录要先通过人机验证。",
  },
  {
    key: "sessions.lock_after",
    group: "sessions",
    type: "number",
    integer: true,
    min: 1,
    max: 1000,
    unit: "次",
    label: "登录失败几次后暂停登录",
    about:
      "失败这么多次后，这个账户或 IP 暂停登录，等最早的一次失败过了计算时长才能再试。不比上一项多，就不会要人机验证。",
  },
  {
    key: "sessions.failure_window_minutes",
    group: "sessions",
    type: "number",
    integer: true,
    min: 1,
    max: 1440,
    unit: "分钟",
    label: "登录失败的计算时长",
    about: "登录失败只算最近这么多分钟里的；暂停登录最长也是这么久。",
  },
  // 验证码 (S32 WP32.2): the codes that bind a phone or verify an email (src/auth/verify.ts).
  {
    key: "codes.minutes",
    group: "codes",
    type: "number",
    integer: true,
    min: 1,
    max: 1440,
    unit: "分钟",
    label: "验证码有效期",
    about: "发到手机或邮箱的验证码多久内有效；短信和邮件里写的分钟数也跟着它。",
  },
  {
    key: "codes.tries",
    group: "codes",
    type: "number",
    integer: true,
    min: 1,
    max: 20,
    unit: "次",
    label: "验证码可以输错几次",
    about: "输错这么多次，这个验证码就作废，要重新获取。",
  },
  {
    key: "codes.resend_seconds",
    group: "codes",
    type: "number",
    integer: true,
    min: 0,
    max: 3600,
    unit: "秒",
    label: "再次获取验证码的间隔",
    about: "同一个账户要同一种验证码（短信或邮件），两次之间至少隔这么久；0 是不用等。",
  },
  {
    key: "codes.per_destination_hour",
    group: "codes",
    type: "number",
    integer: true,
    min: 1,
    max: 100,
    unit: "个",
    label: "每个手机号或邮箱每小时的验证码",
    about: "一个小时里，最多给同一个手机号或邮箱发这么多个验证码。",
  },
  {
    key: "codes.per_account_day",
    group: "codes",
    type: "number",
    integer: true,
    min: 1,
    max: 1000,
    unit: "个",
    label: "每个账户每天的验证码",
    about: "一个账户 24 小时里最多要这么多个验证码，短信和邮件合计。",
  },
  {
    key: "limits.ai_per_user_day",
    group: "limits",
    type: "number",
    integer: true,
    min: 1,
    max: 100_000,
    unit: "次",
    env: "MINGLI_AI_DAILY_PER_USER",
    label: "每个账户每天的 AI 次数",
    about: "公开模式下，一个账户一天最多开始的 AI 解读和方案；AI 模拟时不计。",
  },
  {
    key: "limits.ai_total_day",
    group: "limits",
    type: "number",
    integer: true,
    min: 1,
    max: 10_000_000,
    unit: "次",
    env: "MINGLI_AI_DAILY_TOTAL",
    label: "每天的 AI 总次数",
    about: "公开模式下，所有账户一天合计最多开始的 AI 解读和方案；AI 模拟时不计。",
  },
  {
    key: "limits.mail_per_user_day",
    group: "limits",
    type: "number",
    integer: true,
    min: 0,
    max: 1000,
    unit: "封",
    label: "每个账户每天发到邮箱的次数",
    about: "报告和以往记录发到邮箱，一个账户一天最多几封；0 是不发。",
  },
  // S32 WP32.3: the limits beside the daily ones.
  {
    key: "limits.documents_per_mail",
    group: "limits",
    type: "number",
    integer: true,
    // A message's request holds at most 4 MB of documents (archive.ts), and providers limit a mail's size.
    min: 1,
    max: 20,
    unit: "份",
    label: "一封邮件最多带几份记录",
    about: "以往记录发到邮箱时，一封邮件最多附几份。",
  },
  {
    key: "limits.followups_per_reading",
    group: "limits",
    type: "number",
    integer: true,
    min: 1,
    max: 1000,
    unit: "次",
    label: "每份结果的追问次数",
    about: "一份解读或一生运势报告最多可以追问几次；答不出来的不算。",
  },
  {
    key: "limits.grant_max",
    group: "limits",
    type: "number",
    integer: true,
    min: 1,
    max: 100_000_000,
    unit: "积分",
    label: "一次最多增加的积分",
    about: "管理后台给一个账户增加积分时，一次最多加这么多。",
  },
  // 内容 (S32 WP32.4): what 内容管理 takes (src/admin/content.ts).
  {
    key: "content.text_max",
    group: "content",
    type: "number",
    integer: true,
    min: 50,
    max: 20_000,
    unit: "字",
    label: "一段文字最长几个字",
    about: "在内容里改一段文字时，最多这么多个字。",
  },
  {
    key: "content.image_max_mb",
    group: "content",
    type: "number",
    min: 0.1,
    max: 10,
    unit: "MB",
    label: "一张图片最大多少",
    about: "在内容里换的横幅和标志图片，一张最大这么多 MB；图片越大，应用打开时显示得越慢。",
  },
  // The owner's AI switches (CLAUDE.md rule 5): unset, .env's, read live (src/service/runtime.ts withPanel).
  {
    key: "ai.mock",
    group: "ai",
    type: "boolean",
    optional: true,
    label: "AI 模拟",
    about:
      "开：每一步 AI 都用模拟的示范回答（标着“示范”），不花 token；关：用真实模型。不选就跟随 .env 的 IS_AI_MOCK。",
  },
  {
    key: "ai.model",
    group: "ai",
    type: "choice",
    options: () => MODELS.map((m) => m.id),
    optional: true,
    label: "AI 模型",
    about:
      "每一步 AI 都用这个模型，价格跟着它算。不选就跟随 .env 的 ACTIVE_AI_MODEL，没有的话按 config/model_routing.json。",
  },
  // 货币 (WP31.5, WP31.7; the owner: 「checkbox on different accepted currencies by admin」, 「always get 5% service
  // charge from the conversion」, 「Admin can choose the main displayed currencies for dashboard」).
  {
    key: "currencies.accepted",
    group: "currencies",
    type: "choices",
    options: () => CURRENCY_CODES,
    label: "收的货币",
    about: "用户充值时可以选的货币。元以外的，按当天的汇率换算，再加换算服务费。",
  },
  {
    key: "currencies.service_charge_percent",
    group: "currencies",
    type: "number",
    min: 0,
    max: 50,
    unit: "%",
    label: "换算服务费",
    about: "用元以外的货币充值时，在按当天汇率换算的价钱上加收的百分比。",
  },
  {
    key: "currencies.dashboard",
    group: "currencies",
    type: "choice",
    options: () => CURRENCY_CODES,
    label: "管理后台的货币",
    about: "管理后台的金额（充值、成本、毛利）用这个货币显示，按当天的汇率从元换算。",
  },
  // 积分 (S32 WP32.5): the 充值 packs. Their default stays in config/points.json beside the pricing terms, which the
  // panel doesn't change; a request's price follows the best pack (pricing.ts pointsPerUsd).
  {
    key: "points.packs",
    group: "points",
    type: "packs",
    max: 8,
    fallback: { from: "config/points.json packs", value: () => loadPointsConfig().packs },
    label: "充值套餐",
    about:
      "用户充值时可以选的套餐：付几元，得几积分，每元至少 100 积分。AI 的积分价格按最划算的套餐算，好保证利润：每元给的积分越多，每次 AI 要的积分也越多。",
  },
  // 维护 (S35; the owner: 「添加正在维护的通知，admin可以toggle 告知用户何时能够登录 by default 3-4 小时，可以自己定时」):
  // while it is on, anyone but staff waits, told until when (src/settings/maintenance.ts).
  {
    key: "maintenance.on",
    group: "maintenance",
    type: "boolean",
    label: "维护中",
    about:
      "打开后，除了后台人员，用户不能登录、注册或使用应用，应用会告诉他们大约什么时候可以再登录。后台人员照常使用。",
  },
  {
    key: "maintenance.until",
    group: "maintenance",
    type: "time",
    optional: true,
    label: "预计结束",
    about: "用户看到的可以再登录的时间。不设：从打开维护时起 3 到 4 小时。",
  },
] as const satisfies readonly SettingSpec[];

type Spec = (typeof SETTINGS)[number];
export type SettingKey = Spec["key"];
export type NumberKey = Extract<Spec, { type: "number" }>["key"];
export type ChoiceKey = Extract<Spec, { type: "choice" }>["key"];
export type ChoicesKey = Extract<Spec, { type: "choices" }>["key"];

export const settingSpec = (key: string): SettingSpec | undefined =>
  (SETTINGS as readonly SettingSpec[]).find((s) => s.key === key);

export const isSettingKey = (key: string): key is SettingKey => settingSpec(key) !== undefined;

/** config/settings.json: the defaults by group and name (and its `_readme`). */
export type SettingsFile = Record<string, unknown>;

export function loadSettingsFile(
  path = new URL("../../config/settings.json", import.meta.url),
): SettingsFile {
  return JSON.parse(readFileSync(path, "utf8")) as SettingsFile;
}

/** The file's value for [key], undefined where it has none. */
export function fileValue(file: SettingsFile, key: string): unknown {
  const [group, name] = key.split(".") as [string, string];
  const g = file[group];
  return g && typeof g === "object" ? (g as Record<string, unknown>)[name] : undefined;
}

/** An env variable's text as [spec]'s value: a number, true / false, a choice, or choices by commas. */
export function fromEnv(spec: SettingSpec, raw: string): unknown {
  switch (spec.type) {
    case "number":
      return Number(raw);
    case "boolean": {
      const s = raw.toLowerCase();
      if (["true", "1", "yes", "on"].includes(s)) return true;
      if (["false", "0", "no", "off"].includes(s)) return false;
      return raw;
    }
    case "choice":
      return raw;
    case "choices":
      return raw
        .split(",")
        .map((x) => x.trim())
        .filter(Boolean);
    case "packs":
    case "time":
      // No env variable names the packs or a time: their text is refused, or taken as it is.
      return raw;
  }
}

/** What is wrong with [value] for [spec], in the panel's words; undefined when it fits. */
export function problemOf(spec: SettingSpec, value: unknown): string | undefined {
  switch (spec.type) {
    case "number": {
      if (typeof value !== "number" || !Number.isFinite(value)) return "要一个数字";
      if (spec.integer && !Number.isInteger(value)) return "要一个整数";
      if (value < spec.min || value > spec.max) return `要在 ${spec.min} 到 ${spec.max} 之间`;
      return undefined;
    }
    case "boolean":
      if (value === null && spec.optional) return undefined;
      return typeof value === "boolean" ? undefined : "要开或关";
    case "choice":
      if (value === null && spec.optional) return undefined;
      return typeof value === "string" && spec.options().includes(value)
        ? undefined
        : `要是其中一个：${spec.options().join("、")}`;
    case "choices": {
      const options = spec.options();
      if (!Array.isArray(value) || value.length === 0) return "至少选一个";
      if (value.some((v) => typeof v !== "string" || !options.includes(v))) {
        return `只能从这些里选：${options.join("、")}`;
      }
      return new Set(value).size === value.length ? undefined : "不能重复";
    }
    case "packs": {
      if (!Array.isArray(value) || value.length === 0) return "至少要一个套餐";
      if (value.length > spec.max) return `最多 ${spec.max} 个套餐`;
      for (const p of value as unknown[]) {
        if (
          !p ||
          typeof p !== "object" ||
          Object.keys(p).some((k) => k !== "yuan" && k !== "points")
        )
          return "每个套餐只写元和积分";
        const { yuan, points } = p as Partial<Pack>;
        if (typeof yuan !== "number" || typeof points !== "number") return "每个套餐都要写元和积分";
        // A price in 分 at most, as 充值 takes it.
        if (
          !(yuan >= 0.01 && yuan <= 100_000) ||
          Math.abs(yuan * 100 - Math.round(yuan * 100)) > 1e-6
        )
          return `${yuan} 元：要在 0.01 到 100000 元之间，最多两位小数`;
        if (!packFits({ yuan, points })) return `${yuan} 元的套餐：积分要是整数，每元至少 100 积分`;
      }
      const prices = value.map((p) => (p as Pack).yuan);
      return new Set(prices).size === prices.length ? undefined : "两个套餐不能同一个价钱";
    }
    case "time":
      if (value === null && spec.optional) return undefined;
      return typeof value === "string" &&
        /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/.test(value) &&
        !Number.isNaN(Date.parse(value))
        ? undefined
        : "要一个时间（日期和几点几分）";
  }
}
