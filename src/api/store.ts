/**
 * Persistence boundary for the v1 API. In-memory for now; a PostgreSQL store
 * (db/schema_v0.sql + migrations, encrypted facts/report bodies) implements the
 * same interface later.
 */
import type { LifeReport, Remedy, Report, UserContext } from "../ai/index.js";
import type { ChartFact } from "../chart-fact/index.js";
import type { Locale } from "../ai/terms.js";
import type { AgentName, Topic } from "../ai/types.js";

export interface ChartRecord {
  id: string;
  owner: string;
  fact: ChartFact;
  created_at: string;
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
  /** Set on purchase. */
  payment?: { status: "placeholder"; amount: number; currency: string };
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
}

export interface Store {
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
  }>;
  putLifeReport(r: LifeReportRecord): Promise<void>;
  getLifeReport(id: string): Promise<LifeReportRecord | undefined>;
  /** Newest first. */
  listLifeReports(owner: string, limit: number): Promise<LifeReportRecord[]>;
  /** Account deletion: remove everything the user owns. Returns counts for the receipt. */
  deleteOwnerData(
    owner: string,
  ): Promise<{ charts: number; reports: number; remedies: number; life_reports: number }>;
}

export class InMemoryStore implements Store {
  private charts = new Map<string, ChartRecord>();
  private reports = new Map<string, ReportRecord>();
  private remedies = new Map<string, RemedyRecord>();
  private lifeReports = new Map<string, LifeReportRecord>();
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
    };
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
      [...this.charts.values()].filter((c) => c.owner === owner),
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
    return { charts, reports, remedies, life_reports };
  }
}

function newest<T extends { created_at: string }>(rows: T[], limit: number): T[] {
  return rows
    .sort((a, b) => (a.created_at < b.created_at ? 1 : a.created_at > b.created_at ? -1 : 0))
    .slice(0, limit)
    .map((r) => structuredClone(r));
}
