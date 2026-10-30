/**
 * 管理后台 (v11.3.0, tech plan S22 WP22.3): preset data for the dashboard (the owner: 「为了展示效果，可以设置一些preset的
 * data 到各个用户，这样我们可以只管的再数据表里看见」). Demo accounts with 90 days of history, made from a fixed seed: they
 * sign up (more as the days go on), 充值 by the packs when they run low, and ask for readings across the methods, with
 * 追问, 深度分析, plans and 一生运势报告. Each request's tokens lie near its estimate, priced at Claude Opus 5.5, and its
 * 积分 are charged as the server charges them. Everything is marked demo; the accounts have no password, so they
 * can't sign in. Development only (scripts/api-server.ts), once: a store that has demo accounts gets none again.
 */
import { costUsd, loadRouting } from "../ai/index.js";
import type { Store } from "../api/store.js";
import type { AuthService, UserRecord } from "../auth/service.js";
import type { ChartSystem } from "../chart-fact/index.js";
import {
  estimateTokens,
  pointsFor,
  quote,
  type ChargeKind,
  type Pack,
  type PointsConfig,
  type Tokens,
} from "../points/index.js";
import type { UsageRow } from "./usage.js";

export const DEMO_MODEL = "claude-opus-5-5";

export interface DemoOptions {
  accounts?: number;
  days?: number;
  seed?: number;
}

export interface DemoSummary {
  accounts: number;
  jobs: number;
  topups: number;
}

/** A small seeded generator (mulberry32): the same seed, the same history. */
export function seeded(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function pick<T>(rand: () => number, weighted: readonly (readonly [T, number])[]): T {
  const total = weighted.reduce((n, [, w]) => n + w, 0);
  let r = rand() * total;
  for (const [v, w] of weighted) {
    r -= w;
    if (r < 0) return v;
  }
  return weighted.at(-1)![0];
}

/** A version-4 UUID from the generator: the same seed, the same ids. */
function uuid(rand: () => number): string {
  const b = Array.from({ length: 16 }, () => Math.floor(rand() * 256));
  b[6] = (b[6]! & 0x0f) | 0x40;
  b[8] = (b[8]! & 0x3f) | 0x80;
  const h = b.map((x) => x.toString(16).padStart(2, "0")).join("");
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20)}`;
}

const COUNTRIES = [
  ["HK", 35],
  ["TW", 25],
  ["MY", 20],
  ["SG", 15],
  ["CA", 5],
] as const;
const METHODS: readonly (readonly [ChartSystem, number])[] = [
  ["bazi", 36],
  ["tarot", 30],
  ["qiuqian", 14],
  ["liuyao", 12],
  ["fengshui", 8],
];
const CARDS = [
  [1, 25],
  [3, 45],
  [5, 10],
  [6, 10],
  [10, 10],
] as const;
const NOTES = ["新用户礼包", "活动奖励", "客服补偿", "老用户回馈"];

/** How a request's tokens split between its steps (input share, output share). */
const STEPS: Record<string, readonly (readonly [string, number, number])[]> = {
  bazi: [["narrative", 1, 1]],
  method: [
    ["narrative", 0.6, 0.7],
    ["action", 0.4, 0.3],
  ],
  life_report: [
    ["life_methods", 0.5, 0.5],
    ["life_topics", 0.5, 0.5],
  ],
  followup: [["followup", 1, 1]],
  remedy: [["remedy", 1, 1]],
};

/**
 * Seeds the demo accounts and their history into [store] and [auth]'s accounts, ending at [now]; undefined when demo
 * accounts are there already.
 */
export async function seedAdminDemo(
  deps: { auth: AuthService; store: Store; config: PointsConfig; now: Date },
  o: DemoOptions = {},
): Promise<DemoSummary | undefined> {
  const { auth, store, config, now } = deps;
  if ((await auth.users.list()).some((u) => u.demo)) return undefined;
  const rand = seeded(o.seed ?? 20261029);
  const days = o.days ?? 90;
  const accounts = o.accounts ?? 36;
  const fee = quote(config, loadRouting(), "inquiry").points;
  const packs: readonly (readonly [Pack, number])[] = config.packs.map((p) => [
    p,
    ({ 10: 35, 20: 25, 30: 15, 40: 10, 50: 15 } as Record<number, number>)[p.yuan] ?? 10,
  ]);
  const start = now.getTime() - days * 86_400_000;
  const usage: UsageRow[] = [];
  let jobs = 0;
  let topups = 0;

  for (let i = 0; i < accounts; i++) {
    const id = uuid(rand);
    const username = `demo-${String(i + 1).padStart(2, "0")}`;
    const country = pick(rand, COUNTRIES);
    // More sign-ups as the days go on: a square root's density grows toward the end.
    const joined = start + Math.floor(Math.sqrt(rand()) * days * 86_400_000);
    const at = (t: number) => new Date(Math.min(t, now.getTime() - 60_000)).toISOString();
    const keen = 0.12 + 0.45 * rand();
    const churned = rand() < 0.15;
    let balance = 0;
    let last = joined;
    const account: UserRecord = {
      id,
      username,
      username_lookup: auth.usernameLookup(username),
      social: {},
      country,
      locale: country === "MY" || country === "SG" ? "zh-Hans" : "zh-Hant",
      age_confirmed_at: at(joined),
      created_at: at(joined),
      demo: true,
    };
    await auth.users.put(account);

    /** Enough 积分 for [points] at [t]: a pack bought just before, as often as it takes. */
    const afford = async (points: number, t: number) => {
      while (balance < points) {
        const pack = pick(rand, packs);
        const e = await store.creditPoints(
          id,
          pack.points,
          { kind: "topup", pack },
          at(t - 30_000),
        );
        balance = e!.balance;
        topups++;
      }
    };
    /** One AI job: its steps recorded and, when it delivered, its 积分 charged. */
    const job = async (
      kind: ChargeKind,
      system: ChartSystem,
      steps: readonly (readonly [string, number, number])[],
      tokens: Tokens,
      t: number,
      flat?: number,
    ) => {
      const jobId = uuid(rand);
      const delivered = rand() > 0.03;
      let usd = 0;
      for (const [agent, inShare, outShare] of steps) {
        const usage1 = {
          input_tokens: Math.round(tokens.input * inShare * (0.65 + 0.7 * rand())),
          output_tokens: Math.round(tokens.output * outShare * (0.65 + 0.7 * rand())),
        };
        const cost = costUsd(DEMO_MODEL, usage1)!;
        usd += cost;
        usage.push({
          job_id: jobId,
          owner: id,
          kind,
          system,
          agent,
          model: DEMO_MODEL,
          input_tokens: usage1.input_tokens,
          output_tokens: usage1.output_tokens,
          cache_read_tokens: 0,
          cache_write_tokens: 0,
          usd: cost,
          delivered,
          demo: true,
          created_at: at(t),
        });
      }
      jobs++;
      last = Math.max(last, t);
      if (!delivered) return;
      const points = flat ?? pointsFor(config, usd);
      await afford(points, t);
      const hold = await store.holdPoints(id, points, points, { kind, id: jobId, system }, at(t));
      const e = await store.settlePoints(
        hold!,
        flat !== undefined
          ? { points, basis: "flat" }
          : { points, basis: "measured", usd: Math.round(usd * 1e6) / 1e6 },
        at(t),
      );
      balance = e!.balance;
    };

    // The first day's welcome gift for some, as an admin gives it.
    if (rand() < 0.15) {
      const e = await store.creditPoints(
        id,
        [500, 1000, 2000][Math.floor(rand() * 3)]!,
        {
          kind: "grant",
          reason: `admin:demo-${i}`,
          note: NOTES[Math.floor(rand() * NOTES.length)]!,
        },
        at(joined + 60_000),
      );
      balance = e!.balance;
    }
    // Each account's events in time order, so every "balance after" follows the one before.
    let cursor = joined + 120_000;
    if (!churned) {
      for (let day = Math.floor((joined - start) / 86_400_000); day < days; day++) {
        if (rand() > keen) continue;
        const n = 1 + (rand() < 0.35 ? 1 : 0) + (rand() < 0.1 ? 1 : 0);
        // Between 09:00 and 23:59 in UTC+8, in order.
        const times = Array.from(
          { length: n },
          () => start + day * 86_400_000 + Math.floor((1 + 15 * rand()) * 3_600_000),
        ).sort((a, b) => a - b);
        for (const drawn of times) {
          let t = Math.max(drawn, cursor + 60_000);
          if (t > now.getTime() - 120_000) continue;
          const system = pick(rand, METHODS);
          const cards = system === "tarot" ? pick(rand, CARDS) : undefined;
          const topics =
            system === "bazi" ? (rand() < 0.7 ? 6 : 3 + Math.floor(rand() * 3)) : undefined;
          if (rand() < 0.12) {
            // A 深度分析 first: its turns, paid once.
            const turns = 2 + Math.floor(rand() * 4);
            const turn = estimateTokens(config, "inquiry");
            await job(
              "inquiry",
              system,
              Array.from({ length: turns }, () => ["inquiry", 1, 1] as const),
              turn,
              t,
              fee,
            );
            t += turns * 90_000;
          }
          const about = { system, ...(cards && { cards }), ...(topics && { topics }) };
          await job(
            "report",
            system,
            system === "bazi" ? STEPS.bazi! : STEPS.method!,
            estimateTokens(config, "report", about),
            t,
          );
          if (rand() < 0.3) {
            for (let f = 1 + (rand() < 0.4 ? 1 : 0); f > 0; f--) {
              t += 180_000 + Math.floor(rand() * 600_000);
              await job(
                "followup",
                system,
                STEPS.followup!,
                estimateTokens(config, "followup", { system, parent: "report" }),
                t,
              );
            }
          }
          if ((system === "bazi" || system === "tarot") && rand() < 0.08) {
            t += 240_000;
            await job(
              "remedy",
              system,
              STEPS.remedy!,
              estimateTokens(config, "remedy", { system }),
              t,
            );
          }
          if (system === "bazi" && rand() < 0.1) {
            t += 300_000;
            await job(
              "life_report",
              "bazi",
              STEPS.life_report!,
              estimateTokens(config, "life_report"),
              t,
            );
          }
          cursor = t;
        }
      }
    }
    // Some were here a moment ago, others today: the 活跃用户 lists have someone in them.
    const seen =
      i < 3
        ? now.getTime() - (2 + 4 * i) * 60_000
        : i < 9
          ? now.getTime() - (1 + 3 * (i - 3)) * 3_600_000
          : last;
    await auth.users.put({
      ...account,
      last_seen_at: new Date(
        Math.floor(Math.min(seen, now.getTime()) / 60_000) * 60_000,
      ).toISOString(),
      // A few the admins have acted on.
      ...(i === accounts - 1 || i === accounts - 2 ? { status: "suspended" as const } : {}),
      ...(i === accounts - 3 ? { permissions: { ai: false, top_up: true } } : {}),
    });
  }
  await store.recordUsage(usage);
  return { accounts, jobs, topups };
}

/** The owner's switch for the preset data: on unless MINGLI_ADMIN_DEMO=off. */
export const adminDemoOn = (env: Record<string, string | undefined>) =>
  !["off", "false", "0", "no"].includes((env.MINGLI_ADMIN_DEMO ?? "").trim().toLowerCase());
