/**
 * 设置 (S31): the value each setting has now. The panel's change (kept in the database) wins; else the env variable
 * the setting names, when set; else config/settings.json. Read synchronously wherever the server needs one, so a
 * change in the 管理后台 holds from the next request on.
 */
import {
  fileValue,
  fromEnv,
  loadSettingsFile,
  problemOf,
  settingSpec,
  SETTINGS,
  type ChoiceKey,
  type ChoicesKey,
  type NumberKey,
  type SettingSpec,
  type SettingsFile,
} from "./registry.js";

export * from "./registry.js";

/** A change made in the panel. */
export interface SettingRecord {
  key: string;
  value: unknown;
  updated_at: string;
  updated_by?: string;
}

/** Where the panel's changes are kept: the database (migration 015), or the memory store. */
export interface SettingStore {
  listSettings(): Promise<SettingRecord[]>;
  putSetting(r: SettingRecord): Promise<void>;
  deleteSetting(key: string): Promise<boolean>;
}

/** A value refused: not a setting, or out of its range (the panel's words). */
export class SettingError extends Error {}

/** A setting as the panel shows it: what it is, its value now, its default, and when it was changed. */
export type SettingView = Omit<SettingSpec, "options" | "env" | "fallback"> & {
  options?: readonly string[];
  /** The env variable the default comes from, when it is set. */
  env?: string;
  value: unknown;
  default: unknown;
  changed?: { updated_at: string };
};

export class Settings {
  private readonly changed = new Map<string, SettingRecord>();
  private readonly defaults = new Map<string, { value: unknown; env?: string }>();

  /**
   * The defaults are read now, from [env] and [file]: one that doesn't fit its setting (a mistyped env variable)
   * stops the server here, with what is wrong.
   */
  constructor(
    private readonly store?: SettingStore,
    env: Record<string, string | undefined> = process.env,
    file: SettingsFile = loadSettingsFile(),
  ) {
    for (const spec of SETTINGS as readonly SettingSpec[]) {
      const raw = spec.env && env[spec.env]?.trim();
      const inFile = fileValue(file, spec.key);
      const value = raw ? fromEnv(spec, raw) : (inFile ?? spec.fallback?.value() ?? null);
      const where = raw
        ? spec.env!
        : inFile === undefined && spec.fallback
          ? spec.fallback.from
          : `config/settings.json ${spec.key}`;
      const problem = problemOf(spec, value);
      if (problem) throw new Error(`${where}: ${problem} (${String(raw ?? value)})`);
      this.defaults.set(spec.key, { value, ...(raw && { env: spec.env }) });
    }
  }

  /** The panel's changes, from the store; one that no longer fits its setting (renamed, out of range) is left out. */
  async load(): Promise<this> {
    for (const r of (await this.store?.listSettings()) ?? []) {
      const spec = settingSpec(r.key);
      if (spec && !problemOf(spec, r.value)) this.changed.set(r.key, r);
    }
    return this;
  }

  /** The value in use: the panel's, else the default. */
  value(key: string): unknown {
    return this.changed.has(key) ? this.changed.get(key)!.value : this.defaults.get(key)?.value;
  }

  /** The panel's value alone; undefined while it has none, so the server's own holds (its 积分 config's packs). */
  panelValue(key: string): unknown {
    return this.changed.get(key)?.value;
  }

  number(key: NumberKey): number {
    return this.value(key) as number;
  }

  /** A choice's value; null when an optional one is unset. */
  choice(key: ChoiceKey): string | null {
    return this.value(key) as string | null;
  }

  choices(key: ChoicesKey): string[] {
    return this.value(key) as string[];
  }

  /** Keeps [value] as [key]'s, from the panel; SettingError when it isn't a setting or doesn't fit. */
  async set(
    key: string,
    value: unknown,
    by: string | undefined,
    at: string,
  ): Promise<SettingRecord> {
    const spec = settingSpec(key);
    if (!spec) throw new SettingError(`没有这个设置：${key}`);
    const problem = problemOf(spec, value);
    if (problem) throw new SettingError(problem);
    const r: SettingRecord = { key, value, updated_at: at, ...(by && { updated_by: by }) };
    await this.store?.putSetting(r);
    this.changed.set(key, r);
    return r;
  }

  /** [key] back to its default. */
  async reset(key: string): Promise<void> {
    await this.store?.deleteSetting(key);
    this.changed.delete(key);
  }

  view(key: string): SettingView {
    const {
      options,
      env: _env,
      fallback: _fallback,
      ...spec
    } = settingSpec(key) as SettingSpec & { options?: () => readonly string[] };
    const d = this.defaults.get(key)!;
    const c = this.changed.get(key);
    return {
      ...spec,
      ...(options && { options: options() }),
      ...(d.env && { env: d.env }),
      value: this.value(key),
      default: d.value,
      ...(c && { changed: { updated_at: c.updated_at } }),
    };
  }

  /** Every setting, in the registry's order. */
  list(): SettingView[] {
    return SETTINGS.map((s) => this.view(s.key));
  }
}

let fallback: Settings | undefined;

/** The defaults alone (no panel), for code that runs without a server's settings: tests, scripts. */
export function defaultSettings(): Settings {
  return (fallback ??= new Settings());
}
