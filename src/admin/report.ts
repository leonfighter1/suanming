/**
 * 管理后台 (v11.2.0, tech plan S22): the exports (「导出收益曲线和report」). The revenue curve as CSV, day by day; the
 * accounts as CSV; and a period's report as the server's document (src/export/document.ts), which renders to PDF and
 * Word. Every money figure is in 元.
 */
import type { Doc, DocBlock } from "../export/document.js";
import type { BreakdownRow, DayRow, ModelRow, Overview, UserRow } from "./stats.js";

/** A CSV field: quoted when it holds a comma, a quote or a line break. */
const field = (v: string | number | boolean | null | undefined) => {
  const s = v === null || v === undefined ? "" : String(v);
  return /[",\r\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
};
const csv = (header: string[], rows: (string | number | boolean | null | undefined)[][]) =>
  // A byte-order mark, so a spreadsheet opens the Chinese headers as UTF-8.
  String.fromCharCode(0xfeff) +
  [header, ...rows].map((r) => r.map(field).join(",")).join("\r\n") +
  "\r\n";

/** The revenue curve, day by day. */
export function seriesCsv(days: DayRow[]): string {
  return csv(
    [
      "日期",
      "新账户",
      "活跃账户",
      "AI 次数",
      "输入 Token",
      "输出 Token",
      "Token 合计",
      "充值 (元)",
      "净收入 (元)",
      "AI 成本 (元)",
      "毛利 (元)",
      "积分售出",
      "积分赠送",
      "积分消耗",
    ],
    days.map((d) => [
      d.day,
      d.new_accounts,
      d.active_accounts,
      d.jobs,
      d.input_tokens,
      d.output_tokens,
      d.tokens,
      d.topup_cny.toFixed(2),
      d.net_cny.toFixed(2),
      d.cost_cny.toFixed(2),
      d.profit_cny.toFixed(2),
      d.points_sold,
      d.points_granted,
      d.points_used,
    ]),
  );
}

/** The accounts, as the 用户 table has them. */
export function usersCsv(users: UserRow[]): string {
  return csv(
    [
      "账户",
      "ID",
      "地区",
      "角色",
      "状态",
      "AI 权限",
      "充值权限",
      "演示",
      "注册时间",
      "最近活跃",
      "积分余额",
      "冻结中",
      "累计充值 (元)",
      "累计消耗积分",
      "AI 次数",
      "Token",
      "AI 成本 (元)",
    ],
    users.map((u) => [
      u.login,
      u.id,
      u.country,
      u.role,
      u.status,
      u.permissions.ai,
      u.permissions.top_up,
      u.demo,
      u.created_at,
      u.last_seen_at,
      u.balance,
      u.held,
      u.topup_cny.toFixed(2),
      u.points_used,
      u.jobs,
      u.tokens,
      u.cost_cny.toFixed(2),
    ]),
  );
}

const yuan = (x: number) => `¥${x.toFixed(2)}`;
const count = (x: number) => x.toLocaleString("en-US");
const percent = (x: number | null) => (x === null ? "—" : `${(x * 100).toFixed(1)}%`);
const KINDS: Record<string, string> = {
  report: "AI 解读",
  life_report: "一生运势报告",
  followup: "追问",
  inquiry: "深度分析",
  remedy: "破除运势方案",
};
const METHODS: Record<string, string> = {
  bazi: "八字",
  tarot: "塔罗",
  qiuqian: "求签",
  liuyao: "算卦",
  fengshui: "风水",
  naming: "起名",
  astrology: "占星",
};
export const breakdownLabel = (r: Pick<BreakdownRow, "kind" | "system">) =>
  [r.system && METHODS[r.system], KINDS[r.kind] ?? r.kind].filter(Boolean).join(" ");

/** A period's report: the figures, the AI use by method and by model, and every day. */
export function reportDoc(
  o: Overview,
  days: DayRow[],
  by: { byMethod: BreakdownRow[]; byModel: ModelRow[] },
  made: string,
): Doc {
  const blocks: DocBlock[] = [
    { type: "meta", text: `统计期间 ${o.from} 至 ${o.to}（${o.days} 天）· 生成于 ${made}` },
    { type: "h2", text: "经营概况" },
    {
      type: "kv",
      rows: [
        ["充值收入", yuan(o.money.topup_cny)],
        ["净收入（扣除支付手续费和增值税）", yuan(o.money.net_cny)],
        ["AI 成本", yuan(o.money.cost_cny)],
        ["毛利", yuan(o.money.profit_cny)],
        ["毛利率", percent(o.money.margin)],
      ],
    },
    { type: "h2", text: "账户与活跃" },
    {
      type: "kv",
      rows: [
        ["账户总数", count(o.accounts.total)],
        ["期间新增", count(o.accounts.new)],
        ["已停用", count(o.accounts.suspended)],
        ["15 分钟内活跃", count(o.active.now)],
        ["24 小时内活跃", count(o.active.day)],
        ["7 天内活跃", count(o.active.week)],
        ["30 天内活跃", count(o.active.month)],
      ],
    },
    { type: "h2", text: "AI 用量" },
    {
      type: "kv",
      rows: [
        ["AI 次数（交付）", `${count(o.ai.jobs)}（${count(o.ai.delivered_jobs)}）`],
        ["输入 Token", count(o.ai.input_tokens)],
        ["输出 Token", count(o.ai.output_tokens)],
        ["Token 合计", count(o.ai.tokens)],
        ["AI 成本（美元）", `$${o.ai.cost_usd.toFixed(2)}`],
      ],
    },
    { type: "h2", text: "积分" },
    {
      type: "kv",
      rows: [
        ["售出", count(o.points.sold)],
        ["赠送", count(o.points.granted)],
        ["消耗", count(o.points.used)],
        ["用户现有", count(o.points.outstanding)],
      ],
    },
  ];
  if (by.byMethod.length) {
    blocks.push(
      { type: "h2", text: "按测算" },
      {
        type: "kv",
        rows: by.byMethod
          .slice(0, 40)
          .map((r) => [
            breakdownLabel(r),
            `${count(r.jobs)} 次 · ${count(r.tokens)} Token · 成本 ${yuan(r.cost_cny)} · 消耗 ${count(r.points_used)} 积分`,
          ]),
      },
    );
  }
  if (by.byModel.length) {
    blocks.push(
      { type: "h2", text: "按模型" },
      {
        type: "kv",
        rows: by.byModel.map((r) => [
          r.model,
          `${count(r.jobs)} 次 · 输入 ${count(r.input_tokens)} · 输出 ${count(r.output_tokens)} · 成本 ${yuan(r.cost_cny)}`,
        ]),
      },
    );
  }
  // The days, in pieces of the document's 80 rows each.
  blocks.push({ type: "h2", text: "每日明细" });
  for (let i = 0; i < days.length; i += 80) {
    blocks.push({
      type: "kv",
      rows: days
        .slice(i, i + 80)
        .map((d) => [
          d.day,
          `充值 ${yuan(d.topup_cny)} · 成本 ${yuan(d.cost_cny)} · 毛利 ${yuan(d.profit_cny)} · ${count(d.jobs)} 次 · ${count(d.tokens)} Token · 活跃 ${d.active_accounts}`,
        ]),
    });
  }
  blocks.push({
    type: "note",
    text: "收入按充值金额计；净收入扣除支付手续费和增值税；AI 成本按各模型的公开价格和设定汇率折算。演示数据仅用于展示。",
  });
  return { title: "命理大师 经营报表", subtitle: `${o.from} 至 ${o.to}`, blocks };
}
