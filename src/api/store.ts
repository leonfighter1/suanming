/**
 * Persistence boundary for the v1 API. In-memory for now; a PostgreSQL store
 * (db/schema_v0.sql + migrations, encrypted facts/report bodies) implements the
 * same interface later.
 */
import type {
  AgentTrace,
  FollowUp,
  InquiryTurn,
  LifeReport,
  Remedy,
  Report,
  UserContext,
} from "../ai/index.js";
import type { ChartFact } from "../chart-fact/index.js";
import type { Locale } from "../ai/terms.js";
import type { AgentName, TarotFocus, Topic } from "../ai/types.js";
import type { ChartPerson } from "../service/charts.js";
import type { UsageRow } from "../admin/usage.js";
import type { MessageKind } from "../notify/templates.js";
import type { TemplateRecord, TemplateStore } from "../notify/dispatch.js";
import type { ContentLocale } from "../content/catalog.js";
import type { ContentImageRecord, ContentStore, ContentTextRecord } from "../content/store.js";
import type { SettingRecord, SettingStore } from "../settings/index.js";
import {
  InMemoryLedger,
  type PointsCharge,
  type PointsCredit,
  type PointsFor,
  type PointsHold,
  type PointsLedger,
} from "../points/index.js";

export type { ChartPerson };

export interface ChartRecord {
  id: string;
  owner: string;
  fact: ChartFact;
  created_at: string;
  /** 每日一牌: the date it is the card of (YYYY-MM-DD). Not listed among the charts. */
  daily?: string;
  /**
   * Whose birth chart it is (v6.2.0, the owner's bug report 2026-10-28): the name and the birthplace as the app
   * labels them, so history and reports show them on every device and sign-in. Not part of ChartFact and never
   * sent to a model; sealed with the chart in the database store, and deleted with the account.
   */
  person?: ChartPerson;
  /**
   * What the draw was asked (v11.1.0, owner 2026-10-29: 「必须要有所求才能去求」): 塔罗, 求签 and 算卦 are drawn for a
   * question, which their readings then answer. Kept with the chart, sealed like it; never in its ChartFact.
   */
  question?: string;
}

export type ReportRecordStatus = "pending" | "passed" | "blocked" | "manual_review" | "failed";

/** A reviewer's decision on held content (内容审核). */
export interface ReviewDecision {
  decision: "approve" | "reject";
  by: string;
  at: string;
  note?: string;
}

export interface ReportRecord {
  id: string;
  owner: string;
  chart_id: string;
  status: ReportRecordStatus;
  locale: Locale;
  topics: Topic[];
  created_at: string;
  updated_at: string;
  report?: Report;
  error?: string;
  /** Live stage while pending (pipeline onProgress). */
  progress?: { stage: AgentName; attempt: number; updated_at: string };
  review?: ReviewDecision;
  /** What the user told us (kept for this report's 破除運勢 plans; deleted with the account). */
  context?: UserContext;
  /**
   * What the reading was asked for (v7.0.0), kept for its 追问: a tarot, 求籤 or 算卦 question, 风水's room
   * description, and a tarot reading's focus. Sealed with the report; deleted with the account.
   */
  question?: string;
  focus?: TarotFocus;
  /** 测算完成后发到邮箱 (v9.0.0): the last time the report was mailed when done, and how it went. */
  mail?: ReportMail;
  /** 深度分析 (v10.0.0): the conversation the reading read; deleted with the report. */
  inquiry_id?: string;
}

/**
 * Where a 深度分析 stands (v10.0.0): the master is writing its next turn (thinking), waits for an answer (asking), has
 * asked enough (ready), couldn't ask its first question (failed), or a reading has read it (closed).
 */
export type InquiryRecordStatus = "thinking" | "asking" | "ready" | "failed" | "closed";

/**
 * A 深度分析 (v10.0.0, S19): the master's questions before a reading and the user's answers. Sealed under the owner's
 * key like every body; deleted with its reading, and with the account.
 */
export interface InquiryRecord {
  id: string;
  owner: string;
  chart_id: string;
  locale: Locale;
  status: InquiryRecordStatus;
  /** What the user wants to know from the reading. */
  goal: string;
  /** What the reading is asked for (a tarot, 求籤 or 算卦 question; 风水's room description), and a tarot focus. */
  question?: string;
  focus?: TarotFocus;
  context?: UserContext;
  turns: InquiryTurn[];
  /** How many questions the master planned (1–6). */
  planned?: number;
  /** What the user most wants to know, as the master understands it now. */
  understanding?: string;
  /** The master's last words, once it asks nothing more. */
  closing?: string;
  /** The reading made from it. */
  report_id?: string;
  /** 积分 (v11.0.0): the 统一收费 it is paid with, which bounds what its turns may spend. */
  fee?: number;
  /** Who wrote the turns, as every AI output says (the last turn's). */
  ai_disclosure?: {
    generated: true;
    model: string;
    prompt_version: string;
    label_required: boolean;
    generated_at: string;
  };
  created_at: string;
  updated_at: string;
  /** Live stage while thinking. */
  progress?: { stage: AgentName; attempt: number; updated_at: string };
  /** Why the last turn didn't come, for the log; never shown. */
  error?: string;
  /** Each turn's model, prompt and token use (no text), for audit. */
  agents?: AgentTrace[];
}

/** How mailing a finished report went (v9.0.0, tech plan WP15.4). A failure is not retried on its own. */
export interface ReportMail {
  status: "sent" | "failed";
  at: string;
}

/** A paid 破除運勢 plan for one topic of a report (payment: Phase 4 TODO). */
export interface RemedyRecord {
  id: string;
  owner: string;
  report_id: string;
  topic: Topic;
  status: ReportRecordStatus;
  created_at: string;
  updated_at: string;
  /**
   * Preloaded plans are generated before purchase and stay locked (content
   * withheld) until bought; buying only unlocks them, so they open instantly.
   */
  unlocked: boolean;
  /** Set on purchase: a placeholder price, or (v11.0.0) paid in 积分, whose ledger says what it cost. */
  payment?: { status: "placeholder"; amount: number; currency: string } | { status: "points" };
  remedy?: Remedy;
  review?: ReviewDecision;
  error?: string;
  progress?: { stage: AgentName; attempt: number; updated_at: string };
}

/** A 一生运势报告 job. */
export interface LifeReportRecord {
  id: string;
  owner: string;
  chart_id: string;
  status: ReportRecordStatus;
  locale: Locale;
  created_at: string;
  updated_at: string;
  life?: LifeReport;
  review?: ReviewDecision;
  error?: string;
  progress?: { stage: AgentName; attempt: number; updated_at: string };
  /** What the user told us (v7.0.0), kept for the report's 追问; deleted with the account. */
  context?: UserContext;
  /** 测算完成后发到邮箱 (v9.0.0). */
  mail?: ReportMail;
}

/** A 追问 on a passed reading or 一生运势报告 (v7.0.0, S13 WP13.2): the question, then its answer. */
export interface FollowUpRecord {
  id: string;
  owner: string;
  /** What it asks about. */
  parent: { kind: "report" | "life_report"; id: string };
  question: string;
  status: ReportRecordStatus;
  created_at: string;
  updated_at: string;
  followup?: FollowUp;
  review?: ReviewDecision;
  error?: string;
  progress?: { stage: AgentName; attempt: number; updated_at: string };
}

/**
 * The records, and since v11.0.0 (S20) each account's 积分 (src/points/ledger.ts); since v13.1.0 (S25) the admins'
 * wordings of the messages (src/notify/dispatch.ts).
 */
export interface Store extends PointsLedger, TemplateStore, ContentStore, SettingStore {
  putChart(c: ChartRecord): Promise<void>;
  getChart(id: string): Promise<ChartRecord | undefined>;
  putReport(r: ReportRecord): Promise<void>;
  getReport(id: string): Promise<ReportRecord | undefined>;
  /** Newest first. */
  listCharts(owner: string, limit: number): Promise<ChartRecord[]>;
  /** Newest first. */
  listReports(owner: string, limit: number): Promise<ReportRecord[]>;
  putRemedy(r: RemedyRecord): Promise<void>;
  getRemedy(id: string): Promise<RemedyRecord | undefined>;
  /** Oldest first. */
  listRemedies(reportId: string): Promise<RemedyRecord[]>;
  /** Everything held for review (manual_review / blocked), newest first, all owners. */
  listHeld(): Promise<{
    reports: ReportRecord[];
    remedies: RemedyRecord[];
    life: LifeReportRecord[];
    followups: FollowUpRecord[];
  }>;
  putLifeReport(r: LifeReportRecord): Promise<void>;
  getLifeReport(id: string): Promise<LifeReportRecord | undefined>;
  /** Newest first. */
  listLifeReports(owner: string, limit: number): Promise<LifeReportRecord[]>;
  putFollowUp(f: FollowUpRecord): Promise<void>;
  getFollowUp(id: string): Promise<FollowUpRecord | undefined>;
  /** A reading's 追问, oldest first. */
  listFollowUps(parentId: string): Promise<FollowUpRecord[]>;
  putInquiry(i: InquiryRecord): Promise<void>;
  getInquiry(id: string): Promise<InquiryRecord | undefined>;
  /**
   * 删除 (v8.0.0): one reading with its 破除運勢 plans, its 追问 and (v10.0.0) its 深度分析. Counts for the receipt.
   */
  deleteReport(
    id: string,
  ): Promise<{ reports: number; remedies: number; followups: number; inquiries: number }>;
  /** 删除 (v8.0.0): one 一生运势报告 with its 追问. */
  deleteLifeReport(id: string): Promise<{ life_reports: number; followups: number }>;
  /** A chart, unless a reading or a 一生运势报告 still reads it, or it is a 每日一牌's; true when it went. */
  deleteChartIfUnused(id: string): Promise<boolean>;
  /** 管理后台 (v11.2.0): an AI job's steps, as it ends. */
  recordUsage(rows: UsageRow[]): Promise<void>;
  /** Every AI job's steps since `since` (all without it), oldest first. */
  listUsage(since?: string): Promise<UsageRow[]>;
  /**
   * Account deletion: remove everything the user owns. Returns counts for the receipt (`points`: its 积分 entries).
   * Its AI use stays, without its owner, so the totals don't change.
   */
  deleteOwnerData(owner: string): Promise<{
    charts: number;
    reports: number;
    remedies: number;
    life_reports: number;
    followups: number;
    inquiries: number;
    points: number;
  }>;
}

export class InMemoryStore implements Store {
  private charts = new Map<string, ChartRecord>();
  private reports = new Map<string, ReportRecord>();
  private remedies = new Map<string, RemedyRecord>();
  private lifeReports = new Map<string, LifeReportRecord>();
  private followUps = new Map<string, FollowUpRecord>();
  private inquiries = new Map<string, InquiryRecord>();
  private readonly ledger = new InMemoryLedger();
  pointsOf(owner: string) {
    return this.ledger.pointsOf(owner);
  }
  holdPoints(owner: string, need: number, want: number, what: PointsFor, at: string) {
    return this.ledger.holdPoints(owner, need, want, what, at);
  }
  settlePoints(hold: PointsHold, charge: PointsCharge | undefined, at: string) {
    return this.ledger.settlePoints(hold, charge, at);
  }
  creditPoints(owner: string, points: number, credit: PointsCredit, at: string) {
    return this.ledger.creditPoints(owner, points, credit, at);
  }
  listPoints(owner: string, limit: number) {
    return this.ledger.listPoints(owner, limit);
  }
  listHolds(owner: string) {
    return this.ledger.listHolds(owner);
  }
  allPoints(since?: string) {
    return this.ledger.allPoints(since);
  }
  allBalances() {
    return this.ledger.allBalances();
  }
  private usage: UsageRow[] = [];
  async recordUsage(rows: UsageRow[]) {
    this.usage.push(...rows.map((r) => structuredClone(r)));
  }
  async listUsage(since?: string) {
    return this.usage
      .filter((r) => !since || r.created_at >= since)
      .sort((a, b) => (a.created_at < b.created_at ? -1 : a.created_at > b.created_at ? 1 : 0))
      .map((r) => structuredClone(r));
  }
  private templates = new Map<string, TemplateRecord>();
  async listMessageTemplates() {
    return [...this.templates.values()].map((t) => structuredClone(t));
  }
  async putMessageTemplate(t: TemplateRecord) {
    this.templates.set(`${t.kind}/${t.locale}`, structuredClone(t));
  }
  async deleteMessageTemplate(kind: MessageKind, locale: Locale) {
    return this.templates.delete(`${kind}/${locale}`);
  }
  private contentTexts = new Map<string, ContentTextRecord>();
  private contentImages = new Map<string, ContentImageRecord>();
  async listContentTexts() {
    return [...this.contentTexts.values()].map((t) => structuredClone(t));
  }
  async putContentText(t: ContentTextRecord) {
    this.contentTexts.set(`${t.key}/${t.locale}`, structuredClone(t));
  }
  async deleteContentText(key: string, locale: ContentLocale) {
    return this.contentTexts.delete(`${key}/${locale}`);
  }
  async listContentImages() {
    return [...this.contentImages.values()].map(({ data: _d, ...info }) => ({ ...info }));
  }
  async getContentImage(key: string) {
    const i = this.contentImages.get(key);
    return i && { ...i, data: Buffer.from(i.data) };
  }
  async putContentImage(i: ContentImageRecord) {
    this.contentImages.set(i.key, { ...i, data: Buffer.from(i.data) });
  }
  async deleteContentImage(key: string) {
    return this.contentImages.delete(key);
  }
  private settings = new Map<string, SettingRecord>();
  async listSettings() {
    return [...this.settings.values()].map((r) => structuredClone(r));
  }
  async putSetting(r: SettingRecord) {
    this.settings.set(r.key, structuredClone(r));
  }
  async deleteSetting(key: string) {
    return this.settings.delete(key);
  }
  async putInquiry(i: InquiryRecord) {
    this.inquiries.set(i.id, structuredClone(i));
  }
  async getInquiry(id: string) {
    const i = this.inquiries.get(id);
    return i && structuredClone(i);
  }
  async listHeld() {
    const held = (s: ReportRecordStatus) => s === "manual_review" || s === "blocked";
    return {
      reports: newest(
        [...this.reports.values()].filter((r) => held(r.status)),
        500,
      ),
      remedies: newest(
        [...this.remedies.values()].filter((r) => held(r.status)),
        500,
      ),
      life: newest(
        [...this.lifeReports.values()].filter((r) => held(r.status)),
        500,
      ),
      followups: newest(
        [...this.followUps.values()].filter((f) => held(f.status)),
        500,
      ),
    };
  }
  async putFollowUp(f: FollowUpRecord) {
    this.followUps.set(f.id, structuredClone(f));
  }
  async getFollowUp(id: string) {
    const f = this.followUps.get(id);
    return f && structuredClone(f);
  }
  async listFollowUps(parentId: string) {
    return newest(
      [...this.followUps.values()].filter((f) => f.parent.id === parentId),
      100,
    ).reverse();
  }
  private dropFollowUps(parentId: string) {
    let n = 0;
    for (const [id, f] of this.followUps)
      if (f.parent.id === parentId && this.followUps.delete(id)) n++;
    return n;
  }
  async deleteReport(id: string) {
    let remedies = 0;
    for (const [k, r] of this.remedies)
      if (r.report_id === id && this.remedies.delete(k)) remedies++;
    const followups = this.dropFollowUps(id);
    let inquiries = 0;
    for (const [k, i] of this.inquiries)
      if (i.report_id === id && this.inquiries.delete(k)) inquiries++;
    return { reports: this.reports.delete(id) ? 1 : 0, remedies, followups, inquiries };
  }
  async deleteLifeReport(id: string) {
    const followups = this.dropFollowUps(id);
    return { life_reports: this.lifeReports.delete(id) ? 1 : 0, followups };
  }
  async deleteChartIfUnused(id: string) {
    const chart = this.charts.get(id);
    if (!chart || chart.daily) return false;
    const read =
      [...this.reports.values()].some((r) => r.chart_id === id) ||
      [...this.lifeReports.values()].some((r) => r.chart_id === id);
    return !read && this.charts.delete(id);
  }
  async putLifeReport(r: LifeReportRecord) {
    this.lifeReports.set(r.id, structuredClone(r));
  }
  async getLifeReport(id: string) {
    const r = this.lifeReports.get(id);
    return r && structuredClone(r);
  }
  async listLifeReports(owner: string, limit: number) {
    return newest(
      [...this.lifeReports.values()].filter((r) => r.owner === owner),
      limit,
    );
  }
  async putChart(c: ChartRecord) {
    this.charts.set(c.id, structuredClone(c));
  }
  async getChart(id: string) {
    const c = this.charts.get(id);
    return c && structuredClone(c);
  }
  async putReport(r: ReportRecord) {
    this.reports.set(r.id, structuredClone(r));
  }
  async getReport(id: string) {
    const r = this.reports.get(id);
    return r && structuredClone(r);
  }
  async putRemedy(r: RemedyRecord) {
    this.remedies.set(r.id, structuredClone(r));
  }
  async getRemedy(id: string) {
    const r = this.remedies.get(id);
    return r && structuredClone(r);
  }
  async listRemedies(reportId: string) {
    return newest(
      [...this.remedies.values()].filter((r) => r.report_id === reportId),
      100,
    ).reverse();
  }
  async listCharts(owner: string, limit: number) {
    return newest(
      // A 每日一牌 isn't a chart the user made: one a day would bury the rest.
      [...this.charts.values()].filter((c) => c.owner === owner && !c.daily),
      limit,
    );
  }
  async listReports(owner: string, limit: number) {
    return newest(
      [...this.reports.values()].filter((r) => r.owner === owner),
      limit,
    );
  }
  async deleteOwnerData(owner: string) {
    let charts = 0;
    let reports = 0;
    for (const [id, c] of this.charts) if (c.owner === owner && this.charts.delete(id)) charts++;
    for (const [id, r] of this.reports) if (r.owner === owner && this.reports.delete(id)) reports++;
    let remedies = 0;
    for (const [id, r] of this.remedies)
      if (r.owner === owner && this.remedies.delete(id)) remedies++;
    let life_reports = 0;
    for (const [id, r] of this.lifeReports)
      if (r.owner === owner && this.lifeReports.delete(id)) life_reports++;
    let followups = 0;
    for (const [id, f] of this.followUps)
      if (f.owner === owner && this.followUps.delete(id)) followups++;
    let inquiries = 0;
    for (const [id, i] of this.inquiries)
      if (i.owner === owner && this.inquiries.delete(id)) inquiries++;
    const points = this.ledger.deleteOwner(owner);
    for (const r of this.usage) if (r.owner === owner) delete r.owner;
    return { charts, reports, remedies, life_reports, followups, inquiries, points };
  }
}

function newest<T extends { created_at: string }>(rows: T[], limit: number): T[] {
  return rows
    .sort((a, b) => (a.created_at < b.created_at ? 1 : a.created_at > b.created_at ? -1 : 0))
    .slice(0, limit)
    .map((r) => structuredClone(r));
}
