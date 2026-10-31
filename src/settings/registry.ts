/**
 * 设置 (S31; the owner, 2026-10-31: 「Move all the configurations into separate files, CMS controlling panel is able to
 * read and adjust those values. Extract as much configurations as possible, for instance, identify the users idle
 * time, rightnow, 2 days, but we should be able to change it in the dashboard controlling panel」): what the
 * 管理后台's 设置 page reads and changes, each with its group, type, range and words. A setting's default is in
 * config/settings.json, or in the env variable it names when that is set; a change made in the panel wins over both
 * (src/settings/index.ts).
 */
import { readFileSync } from "node:fs";

export type SettingGroup = "sessions" | "ai" | "limits" | "currencies";

interface Common {
  /** `group.name`, as config/settings.json nests it. */
  key: string;
  group: SettingGroup;
  /** What the panel calls it, and a line on what it does. */
  label: string;
  about: string;
  /** An env variable that, when set, is the default instead of the file's (the deployment's). */
  env?: string;
}

export type SettingSpec = Common &
  (
    | { type: "number"; min: number; max: number; integer?: boolean; unit?: string }
    | { type: "boolean" }
    | { type: "choice"; options: () => readonly string[]; optional?: boolean }
    | { type: "choices"; options: () => readonly string[] }
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
] as const satisfies readonly SettingSpec[];

type Spec = (typeof SETTINGS)[number];
export type SettingKey = Spec["key"];
export type NumberKey = Extract<Spec, { type: "number" }>["key"];

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
  }
}
